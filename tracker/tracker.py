"""
MediaPipe Hand Tracker → UDP Bridge for FPV Magic Spellcasting Game.

Uses the modern HandLandmarker Tasks API (best accuracy).
Downloads the model automatically on first run.

Supports up to 2 hands simultaneously.
Sends:
  - Landmarks as JSON every frame: {"hands": [{"id": 0, "landmarks": [...]}]}
  - Clean JPEG frames for Flutter video overlay (throttled to every 3rd frame)

Usage:
    pip install -r requirements.txt
    python tracker.py

Press 'q' in the OpenCV window to quit.
"""

import cv2
import json
import socket
import sys
import os
import urllib.request

# MediaPipe Tasks API
import mediapipe as mp
from mediapipe.tasks import python as mp_tasks
from mediapipe.tasks.python import vision

# For drawing on preview
mp_drawing = mp.solutions.drawing_utils
mp_hands_connections = mp.solutions.hands

# --- Configuration ---
UDP_IP = "127.0.0.1"
LANDMARK_PORT = 5005
VIDEO_PORT = 5006
CAMERA_INDEX = 0
JPEG_QUALITY = 65      # Slightly lower to reduce encode time
MAX_HANDS = 2

# Lower resolution = dramatically faster processing per frame
CAMERA_WIDTH = 640
CAMERA_HEIGHT = 480
CAMERA_FPS = 60        # Request 60fps (webcam will cap at its max, usually 30–60)

MODEL_URL = "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/latest/hand_landmarker.task"
MODEL_PATH = os.path.join(os.path.dirname(__file__), "hand_landmarker.task")


def download_model():
    """Download the HandLandmarker model if not present."""
    if os.path.exists(MODEL_PATH):
        print(f"[Tracker] Model found: {MODEL_PATH}")
        return
    print(f"[Tracker] Downloading HandLandmarker model...")
    urllib.request.urlretrieve(MODEL_URL, MODEL_PATH)
    print(f"[Tracker] Model downloaded: {MODEL_PATH}")


def main():
    download_model()

    # --- Create HandLandmarker ---
    base_options = mp_tasks.BaseOptions(model_asset_path=MODEL_PATH)
    options = vision.HandLandmarkerOptions(
        base_options=base_options,
        running_mode=vision.RunningMode.VIDEO,
        num_hands=MAX_HANDS,
        min_hand_detection_confidence=0.65,   # Slightly relaxed for speed
        min_hand_presence_confidence=0.65,
        min_tracking_confidence=0.55,
    )
    landmarker = vision.HandLandmarker.create_from_options(options)

    # --- Create FaceDetector ---
    mp_face_detection = mp.solutions.face_detection
    face_detection = mp_face_detection.FaceDetection(
        model_selection=0, # 0 for fast/short-range
        min_detection_confidence=0.5
    )

    # --- Webcam ---
    cap = cv2.VideoCapture(CAMERA_INDEX)
    if not cap.isOpened():
        print(f"ERROR: Could not open camera index {CAMERA_INDEX}")
        sys.exit(1)

    # Lower resolution for faster processing — 640x480 is sufficient for hand tracking
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, CAMERA_WIDTH)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, CAMERA_HEIGHT)
    cap.set(cv2.CAP_PROP_FPS, CAMERA_FPS)   # Request high FPS from camera

    # --- UDP ---
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    actual_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    actual_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    actual_fps = cap.get(cv2.CAP_PROP_FPS)

    print(f"[Tracker] Using HandLandmarker (Tasks API) — best model")
    print(f"[Tracker] Camera: {actual_w}x{actual_h} @ {actual_fps:.0f}fps")
    print(f"[Tracker] Max hands: {MAX_HANDS}")
    print(f"[Tracker] Landmarks → {UDP_IP}:{LANDMARK_PORT}  (every frame)")
    print(f"[Tracker] Video     → {UDP_IP}:{VIDEO_PORT}  (every 3rd frame)")
    print(f"[Tracker] Press 'q' in the preview window to quit.")

    frame_count = 0
    timestamp_ms = 0

    try:
        while cap.isOpened():
            success, frame = cap.read()
            if not success:
                continue

            frame = cv2.flip(frame, 1)
            frame_count += 1
            timestamp_ms = int(cap.get(cv2.CAP_PROP_POS_MSEC))
            if timestamp_ms <= 0:
                timestamp_ms = frame_count * 16   # Fallback: ~60fps target

            # Convert to MediaPipe Image
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)

            # Detect Hands
            result = landmarker.detect_for_video(mp_image, timestamp_ms)

            preview = frame.copy()

            # Detect Face (for camera pan)
            face_result = face_detection.process(rgb_frame)
            face_data = None
            if face_result.detections:
                # Use the first detected face
                detection = face_result.detections[0]
                bbox = detection.location_data.relative_bounding_box
                # Calculate center of the face bounding box
                face_x = bbox.xmin + (bbox.width / 2.0)
                face_y = bbox.ymin + (bbox.height / 2.0)
                face_data = {"x": round(face_x, 5), "y": round(face_y, 5)}
                
                # Draw small circle on face center for debug
                cx = int(face_x * actual_w)
                cy = int(face_y * actual_h)
                cv2.circle(preview, (cx, cy), 8, (0, 255, 0), -1)

            # ----------------------------------------------------------------
            # LANDMARK UDP SEND — every single frame, no skipping
            # ----------------------------------------------------------------
            payload_dict = {"hands": []}
            if face_data:
                payload_dict["face"] = face_data

            if result.hand_landmarks:
                hands_data = []

                for hand_idx, hand_landmarks in enumerate(result.hand_landmarks):
                    landmarks = []
                    for lm in hand_landmarks:
                        landmarks.append({
                            "x": round(lm.x, 5),
                            "y": round(lm.y, 5),
                            "z": round(lm.z, 5),
                        })

                    hands_data.append({
                        "id": hand_idx,
                        "landmarks": landmarks,
                    })

                    # Draw on preview
                    from mediapipe.framework.formats import landmark_pb2
                    hand_proto = landmark_pb2.NormalizedLandmarkList()
                    for lm in hand_landmarks:
                        hand_proto.landmark.append(
                            landmark_pb2.NormalizedLandmark(x=lm.x, y=lm.y, z=lm.z)
                        )
                    mp_drawing.draw_landmarks(
                        preview, hand_proto, mp_hands_connections.HAND_CONNECTIONS
                    )

                payload_dict["hands"] = hands_data

            payload = json.dumps(payload_dict).encode("utf-8")
            sock.sendto(payload, (UDP_IP, LANDMARK_PORT))

            # ----------------------------------------------------------------
            # VIDEO UDP SEND — throttled to every 3rd frame to save bandwidth
            # ----------------------------------------------------------------
            if frame_count % 3 == 0:
                _, jpeg_buf = cv2.imencode(
                    '.jpg', frame,
                    [cv2.IMWRITE_JPEG_QUALITY, JPEG_QUALITY]
                )
                jpeg_bytes = jpeg_buf.tobytes()
                if len(jpeg_bytes) < 65000:
                    sock.sendto(jpeg_bytes, (UDP_IP, VIDEO_PORT))

            cv2.imshow("FPV Magic - Hand Tracker", preview)

            # waitKey(1) = minimum wait, no artificial 5ms sleep
            if cv2.waitKey(1) & 0xFF == ord("q"):
                break

    finally:
        cap.release()
        cv2.destroyAllWindows()
        landmarker.close()
        face_detection.close()
        sock.close()
        print("[Tracker] Stopped.")


if __name__ == "__main__":
    main()
