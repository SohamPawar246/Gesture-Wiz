"""
MediaPipe Hand Tracker → UDP Bridge for FPV Magic Spellcasting Game.

Uses the modern HandLandmarker Tasks API (best accuracy).
Downloads the model automatically on first run.

Supports up to 2 hands simultaneously.
Sends:
  - Landmarks as JSON: {"hands": [{"id": 0, "landmarks": [...]}]}
  - Clean JPEG frames for Flutter video overlay

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
JPEG_QUALITY = 70
MAX_HANDS = 2

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
        min_hand_detection_confidence=0.7,
        min_hand_presence_confidence=0.7,
        min_tracking_confidence=0.6,
    )
    landmarker = vision.HandLandmarker.create_from_options(options)

    # --- Webcam ---
    cap = cv2.VideoCapture(CAMERA_INDEX)
    if not cap.isOpened():
        print(f"ERROR: Could not open camera index {CAMERA_INDEX}")
        sys.exit(1)

    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

    # --- UDP ---
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    print(f"[Tracker] Using HandLandmarker (Tasks API) — best model")
    print(f"[Tracker] Max hands: {MAX_HANDS}")
    print(f"[Tracker] Landmarks → {UDP_IP}:{LANDMARK_PORT}")
    print(f"[Tracker] Video     → {UDP_IP}:{VIDEO_PORT}")
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
                timestamp_ms = frame_count * 33  # Fallback: ~30fps

            # Convert to MediaPipe Image
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)

            # Detect
            result = landmarker.detect_for_video(mp_image, timestamp_ms)

            preview = frame.copy()

            if result.hand_landmarks:
                hands_data = []

                for hand_idx, hand_landmarks in enumerate(result.hand_landmarks):
                    landmarks = []
                    for lm in hand_landmarks:
                        landmarks.append({
                            "x": round(lm.x, 6),
                            "y": round(lm.y, 6),
                            "z": round(lm.z, 6),
                        })

                    hands_data.append({
                        "id": hand_idx,
                        "landmarks": landmarks,
                    })

                    # Draw on preview using normalized landmarks
                    # Convert to mp.solutions format for drawing
                    from mediapipe.framework.formats import landmark_pb2
                    hand_proto = landmark_pb2.NormalizedLandmarkList()
                    for lm in hand_landmarks:
                        hand_proto.landmark.append(
                            landmark_pb2.NormalizedLandmark(x=lm.x, y=lm.y, z=lm.z)
                        )
                    mp_drawing.draw_landmarks(
                        preview, hand_proto, mp_hands_connections.HAND_CONNECTIONS
                    )

                payload = json.dumps({"hands": hands_data}).encode("utf-8")
                sock.sendto(payload, (UDP_IP, LANDMARK_PORT))
            else:
                payload = json.dumps({"hands": []}).encode("utf-8")
                sock.sendto(payload, (UDP_IP, LANDMARK_PORT))

            # Video frame every 2nd frame
            if frame_count % 2 == 0:
                _, jpeg_buf = cv2.imencode(
                    '.jpg', frame,
                    [cv2.IMWRITE_JPEG_QUALITY, JPEG_QUALITY]
                )
                jpeg_bytes = jpeg_buf.tobytes()
                if len(jpeg_bytes) < 65000:
                    sock.sendto(jpeg_bytes, (UDP_IP, VIDEO_PORT))

            cv2.imshow("FPV Magic - Hand Tracker", preview)

            if cv2.waitKey(5) & 0xFF == ord("q"):
                break

    finally:
        cap.release()
        cv2.destroyAllWindows()
        landmarker.close()
        sock.close()
        print("[Tracker] Stopped.")


if __name__ == "__main__":
    main()
