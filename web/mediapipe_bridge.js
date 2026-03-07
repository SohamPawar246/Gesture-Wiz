/**
 * MediaPipe Vision JS Bridge for THE EYE
 * 
 * Runs HandLandmarker + FaceDetector in-browser using MediaPipe Vision WASM.
 * Webcam feed is processed via requestAnimationFrame.
 * Results are stored in global variables that Dart reads via js_interop.
 * 
 * Features:
 * - Mirror-corrected coordinates (X flipped for selfie-mode natural movement)
 * - Live camera preview with drawn landmarks in bottom-right corner
 * - Face detection with low-latency smoothing
 */

// --- State ---
let handLandmarker = null;
let faceDetector = null;
let video = null;
let previewCanvas = null;
let previewCtx = null;
let webcamRunning = false;
let lastVideoTime = -1;

// Latest results (read by Dart)
window._mpHandResults = null;  // Array of hand landmark arrays
window._mpFaceResult = null;   // {x, y} face center (normalized)
window._mpReady = false;

// Face smoothing (lightweight EMA for responsiveness)
let _smoothFaceX = 0.5;
let _smoothFaceY = 0.5;
let _faceSmoothing = 0.4; // Lower = more responsive (0.4 is fast but smooth)
let _hasFace = false;

const VISION_CDN = "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest/wasm";

// Hand connection pairs for drawing skeleton
const HAND_CONNECTIONS = [
  [0,1],[1,2],[2,3],[3,4],     // Thumb
  [0,5],[5,6],[6,7],[7,8],     // Index
  [0,9],[9,10],[10,11],[11,12],// Middle
  [0,13],[13,14],[14,15],[15,16],// Ring
  [0,17],[17,18],[18,19],[19,20],// Pinky
  [5,9],[9,13],[13,17]          // Palm
];

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
    minDetectionConfidence: 0.4,  // Lowered for faster pickup
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

  // Setup the preview canvas
  previewCanvas = document.getElementById("mp-preview-canvas");
  if (previewCanvas) {
    previewCtx = previewCanvas.getContext("2d");
  }

  const stream = await navigator.mediaDevices.getUserMedia({
    video: { width: 640, height: 480, facingMode: "user" },
    audio: false,
  });
  video.srcObject = stream;
  video.addEventListener("loadeddata", () => {
    webcamRunning = true;
    if (previewCanvas) {
      previewCanvas.width = 240;
      previewCanvas.height = 180;
    }
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
    let detectedHands = null;
    if (handResult.landmarks && handResult.landmarks.length > 0) {
      const hands = [];
      for (let i = 0; i < handResult.landmarks.length; i++) {
        const lms = handResult.landmarks[i].map((lm) => ({
          x: 1.0 - lm.x,  // MIRROR: flip X for selfie-mode
          y: lm.y,
          z: lm.z,
        }));
        hands.push(lms);
      }
      window._mpHandResults = hands;
      detectedHands = handResult.landmarks; // Raw (un-mirrored) for drawing
    } else {
      window._mpHandResults = null;
    }

    // --- Face detection ---
    const faceResult = faceDetector.detectForVideo(video, now);
    if (faceResult.detections && faceResult.detections.length > 0) {
      const det = faceResult.detections[0];
      const bb = det.boundingBox;
      // Normalize to 0-1 and MIRROR X
      const rawFx = 1.0 - (bb.originX + bb.width / 2) / video.videoWidth;
      const rawFy = (bb.originY + bb.height / 2) / video.videoHeight;
      
      // Lightweight EMA smoothing
      if (!_hasFace) {
        _smoothFaceX = rawFx;
        _smoothFaceY = rawFy;
        _hasFace = true;
      } else {
        _smoothFaceX += _faceSmoothing * (rawFx - _smoothFaceX);
        _smoothFaceY += _faceSmoothing * (rawFy - _smoothFaceY);
      }
      window._mpFaceResult = { x: _smoothFaceX, y: _smoothFaceY };
    } else {
      _hasFace = false;
      window._mpFaceResult = null;
    }

    // --- Draw preview ---
    drawPreview(detectedHands, faceResult.detections);
  }

  requestAnimationFrame(predictLoop);
}

function drawPreview(rawHands, faceDetections) {
  if (!previewCtx || !previewCanvas) return;
  const cw = previewCanvas.width;
  const ch = previewCanvas.height;

  // Draw mirrored video frame
  previewCtx.save();
  previewCtx.translate(cw, 0);
  previewCtx.scale(-1, 1); // Mirror the video
  previewCtx.drawImage(video, 0, 0, cw, ch);
  previewCtx.restore();

  // Dim overlay for contrast
  previewCtx.fillStyle = "rgba(0, 0, 0, 0.15)";
  previewCtx.fillRect(0, 0, cw, ch);

  // Draw hand landmarks (use raw/un-mirrored coords, but draw on mirrored canvas)
  if (rawHands) {
    const colors = ["#FF6622", "#44DDFF"]; // Orange for hand 0, cyan for hand 1
    for (let h = 0; h < rawHands.length; h++) {
      const lms = rawHands[h];
      const color = colors[h % 2];

      // Draw connections
      previewCtx.strokeStyle = color;
      previewCtx.lineWidth = 1.5;
      for (const [a, b] of HAND_CONNECTIONS) {
        const ax = (1.0 - lms[a].x) * cw; // Mirror X for drawing
        const ay = lms[a].y * ch;
        const bx = (1.0 - lms[b].x) * cw;
        const by = lms[b].y * ch;
        previewCtx.beginPath();
        previewCtx.moveTo(ax, ay);
        previewCtx.lineTo(bx, by);
        previewCtx.stroke();
      }

      // Draw landmark dots
      previewCtx.fillStyle = color;
      for (const lm of lms) {
        const px = (1.0 - lm.x) * cw;
        const py = lm.y * ch;
        previewCtx.beginPath();
        previewCtx.arc(px, py, 2.5, 0, Math.PI * 2);
        previewCtx.fill();
      }
    }
  }

  // Draw face bounding box
  if (faceDetections && faceDetections.length > 0) {
    const det = faceDetections[0];
    const bb = det.boundingBox;
    // Mirror the bounding box
    const rx = cw - ((bb.originX + bb.width) / video.videoWidth) * cw;
    const ry = (bb.originY / video.videoHeight) * ch;
    const rw = (bb.width / video.videoWidth) * cw;
    const rh = (bb.height / video.videoHeight) * ch;

    previewCtx.strokeStyle = "#00FF88";
    previewCtx.lineWidth = 2;
    previewCtx.strokeRect(rx, ry, rw, rh);

    // Face center dot
    previewCtx.fillStyle = "#00FF88";
    previewCtx.beginPath();
    previewCtx.arc(rx + rw / 2, ry + rh / 2, 4, 0, Math.PI * 2);
    previewCtx.fill();
  }

  // "LIVE" indicator
  previewCtx.fillStyle = "#FF3333";
  previewCtx.beginPath();
  previewCtx.arc(12, 12, 4, 0, Math.PI * 2);
  previewCtx.fill();
  previewCtx.fillStyle = "#FFFFFF";
  previewCtx.font = "bold 10px monospace";
  previewCtx.fillText("LIVE", 20, 16);
}

// --- Public API (called from Dart via js_interop) ---

/**
 * Returns JSON string of hand landmarks, or null.
 * Format: [[{x,y,z}, ...21 landmarks], ...per hand]
 * X coordinates are MIRRORED (1.0 - x) for natural selfie-mode movement.
 */
window.getHandLandmarks = function () {
  if (!window._mpHandResults) return null;
  return JSON.stringify(window._mpHandResults);
};

/**
 * Returns JSON string of face center, or null.
 * Format: {x: 0.5, y: 0.5}
 * X is MIRRORED and EMA-smoothed for responsive camera pan.
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
