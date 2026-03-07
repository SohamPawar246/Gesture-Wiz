/**
 * MediaPipe Vision JS Bridge for THE EYE
 * 
 * Runs HandLandmarker + FaceDetector in-browser using MediaPipe Vision WASM.
 * Webcam feed is processed via requestAnimationFrame.
 * Results are stored in global variables that Dart reads via js_interop.
 */

// --- State ---
let handLandmarker = null;
let faceDetector = null;
let video = null;
let webcamRunning = false;
let lastVideoTime = -1;

// Latest results (read by Dart)
window._mpHandResults = null;  // Array of hand landmark arrays
window._mpFaceResult = null;   // {x, y} face center (normalized)
window._mpReady = false;

const VISION_CDN = "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest/wasm";

async function initMediaPipe() {
  const { HandLandmarker, FaceDetector, FilesetResolver } = await import(
    "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest"
  );

  const vision = await FilesetResolver.forVisionTasks(VISION_CDN);

  handLandmarker = await HandLandmarker.createFromOptions(vision, {
    baseOptions: {
      modelAssetPath:
        "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/latest/hand_landmarker.task",
      delegate: "GPU",
    },
    runningMode: "VIDEO",
    numHands: 2,
    minHandDetectionConfidence: 0.65,
    minHandPresenceConfidence: 0.65,
    minTrackingConfidence: 0.55,
  });

  faceDetector = await FaceDetector.createFromOptions(vision, {
    baseOptions: {
      modelAssetPath:
        "https://storage.googleapis.com/mediapipe-models/face_detector/blaze_face_short_range/float16/latest/blaze_face_short_range.tflite",
      delegate: "GPU",
    },
    runningMode: "VIDEO",
    minDetectionConfidence: 0.5,
  });

  console.log("[MediaPipe Bridge] Models loaded.");
  window._mpReady = true;
}

async function startWebcam() {
  video = document.getElementById("mp-video");
  if (!video) {
    console.error("[MediaPipe Bridge] No #mp-video element found.");
    return;
  }

  const stream = await navigator.mediaDevices.getUserMedia({
    video: { width: 640, height: 480, facingMode: "user" },
    audio: false,
  });
  video.srcObject = stream;
  video.addEventListener("loadeddata", () => {
    webcamRunning = true;
    console.log("[MediaPipe Bridge] Webcam started.");
    predictLoop();
  });
}

function predictLoop() {
  if (!webcamRunning || !handLandmarker || !faceDetector) return;

  const now = performance.now();
  if (video.currentTime !== lastVideoTime) {
    lastVideoTime = video.currentTime;

    // --- Hand detection ---
    const handResult = handLandmarker.detectForVideo(video, now);
    if (handResult.landmarks && handResult.landmarks.length > 0) {
      const hands = [];
      for (let i = 0; i < handResult.landmarks.length; i++) {
        const lms = handResult.landmarks[i].map((lm) => ({
          x: lm.x,
          y: lm.y,
          z: lm.z,
        }));
        hands.push(lms);
      }
      window._mpHandResults = hands;
    } else {
      window._mpHandResults = null;
    }

    // --- Face detection ---
    const faceResult = faceDetector.detectForVideo(video, now);
    if (faceResult.detections && faceResult.detections.length > 0) {
      const det = faceResult.detections[0];
      const bb = det.boundingBox;
      // boundingBox is in pixel coords; normalize to 0-1
      const fx = (bb.originX + bb.width / 2) / video.videoWidth;
      const fy = (bb.originY + bb.height / 2) / video.videoHeight;
      window._mpFaceResult = { x: fx, y: fy };
    } else {
      window._mpFaceResult = null;
    }
  }

  requestAnimationFrame(predictLoop);
}

// --- Public API (called from Dart via js_interop) ---

/**
 * Returns JSON string of hand landmarks, or null.
 * Format: [[{x,y,z}, ...21 landmarks], ...per hand]
 */
window.getHandLandmarks = function () {
  if (!window._mpHandResults) return null;
  return JSON.stringify(window._mpHandResults);
};

/**
 * Returns JSON string of face center, or null.
 * Format: {x: 0.5, y: 0.5}
 */
window.getFacePosition = function () {
  if (!window._mpFaceResult) return null;
  return JSON.stringify(window._mpFaceResult);
};

/**
 * Returns true once models are loaded and ready.
 */
window.isMediaPipeReady = function () {
  return window._mpReady === true;
};

// --- Auto-init ---
initMediaPipe().then(() => startWebcam());
