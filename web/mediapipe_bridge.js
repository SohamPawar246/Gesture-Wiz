/**
 * MediaPipe Vision JS Bridge for PYROMANCER
 *
 * Big Brother theme: the webcam feed is rendered as a surveillance camera
 * with green-tinted overlays, scan-lines, crosshair, and a "BB-CAM" indicator.
 *
 * Runs HandLandmarker + FaceDetector in-browser using MediaPipe Vision WASM.
 * Results are stored in global variables that Dart reads via js_interop.
 *
 * Features:
 * - Mirror-corrected coordinates (X flipped for selfie-mode natural movement)
 * - Surveillance-style camera preview with landmarks drawn in bottom-right corner
 * - Face detection — "target acquired" box overlay
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
window._mpHandResults = null; // Array of hand landmark arrays
window._mpFaceResult = null; // {x, y} face center (normalized)
window._mpReady = false;

// Big Brother detection level (set by Dart via js_interop, read by drawPreview)
// 0.0 = green (safe), 0.4+ = yellow (caution), 0.7+ = red (danger)
window._bbDetectionLevel = 0.0;

// Face smoothing (lightweight EMA for responsiveness)
let _smoothFaceX = 0.5;
let _smoothFaceY = 0.5;
let _faceSmoothing = 0.4; // Lower = more responsive (0.4 is fast but smooth)
let _hasFace = false;

const VISION_CDN =
  "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest/wasm";

// Hand connection pairs for drawing skeleton
const HAND_CONNECTIONS = [
  [0, 1],
  [1, 2],
  [2, 3],
  [3, 4], // Thumb
  [0, 5],
  [5, 6],
  [6, 7],
  [7, 8], // Index
  [0, 9],
  [9, 10],
  [10, 11],
  [11, 12], // Middle
  [0, 13],
  [13, 14],
  [14, 15],
  [15, 16], // Ring
  [0, 17],
  [17, 18],
  [18, 19],
  [19, 20], // Pinky
  [5, 9],
  [9, 13],
  [13, 17], // Palm
];

async function initMediaPipe() {
  const { HandLandmarker, FaceDetector, FilesetResolver } =
    await import("https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest");

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
    minDetectionConfidence: 0.4, // Lowered for faster pickup
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
          x: 1.0 - lm.x, // MIRROR: flip X for selfie-mode
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

function getBBColor(level) {
  if (level < 0.4) {
    return {
      stroke: "#00FF55",
      fill: "rgba(0, 255, 85, ",
      glow: "rgba(0, 180, 40, ",
    };
  } else if (level < 0.7) {
    const t = (level - 0.4) / 0.3;
    const r = Math.round(255 * t);
    const g = Math.round(255 - 55 * t);
    return {
      stroke: "rgb(" + r + ", " + g + ", 0)",
      fill: "rgba(" + r + ", " + g + ", 0, ",
      glow: "rgba(" + r + ", " + g + ", 0, ",
    };
  } else {
    const t = Math.min((level - 0.7) / 0.3, 1.0);
    const pulse = 0.7 + 0.3 * Math.sin(performance.now() / 150);
    const r = 255;
    const g = Math.round(200 * (1 - t) * pulse);
    return {
      stroke: "rgb(" + r + ", " + g + ", 0)",
      fill: "rgba(" + r + ", " + g + ", 0, ",
      glow: "rgba(255, 0, 0, ",
    };
  }
}

function drawPreview(rawHands, faceDetections) {
  if (!previewCtx || !previewCanvas) return;
  const cw = previewCanvas.width;
  const ch = previewCanvas.height;

  // Draw mirrored video frame with green-tinted surveillance look
  previewCtx.save();
  previewCtx.translate(cw, 0);
  previewCtx.scale(-1, 1);
  previewCtx.drawImage(video, 0, 0, cw, ch);
  previewCtx.restore();

  // Green surveillance tint overlay
  previewCtx.fillStyle = "rgba(0, 40, 0, 0.35)";
  previewCtx.fillRect(0, 0, cw, ch);

  // CRT scan-line effect (every 4 px)
  previewCtx.fillStyle = "rgba(0, 0, 0, 0.18)";
  for (let sy = 0; sy < ch; sy += 4) {
    previewCtx.fillRect(0, sy, cw, 2);
  }

  // Crosshair in centre
  const cx = cw / 2,
    cy = ch / 2,
    cr = 10;
  previewCtx.strokeStyle = "rgba(0, 255, 80, 0.35)";
  previewCtx.lineWidth = 1;
  previewCtx.beginPath();
  previewCtx.moveTo(cx - cr - 4, cy);
  previewCtx.lineTo(cx + cr + 4, cy);
  previewCtx.moveTo(cx, cy - cr - 4);
  previewCtx.lineTo(cx, cy + cr + 4);
  previewCtx.arc(cx, cy, cr, 0, Math.PI * 2);
  previewCtx.stroke();

  // Draw hand landmarks
  if (rawHands) {
    const colors = ["#00FF55", "#44DDFF"];
    for (let h = 0; h < rawHands.length; h++) {
      const lms = rawHands[h];
      const color = colors[h % 2];

      previewCtx.strokeStyle = color;
      previewCtx.lineWidth = 1.5;
      for (const [a, b] of HAND_CONNECTIONS) {
        const ax = (1.0 - lms[a].x) * cw;
        const ay = lms[a].y * ch;
        const bx = (1.0 - lms[b].x) * cw;
        const by = lms[b].y * ch;
        previewCtx.beginPath();
        previewCtx.moveTo(ax, ay);
        previewCtx.lineTo(bx, by);
        previewCtx.stroke();
      }

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

  // --- Big Brother detection level colors ---
  const bbLevel = window._bbDetectionLevel || 0;
  const bbColors = getBBColor(bbLevel);

  // Draw face bounding box — "TARGET ACQUIRED" style
  if (faceDetections && faceDetections.length > 0) {
    const det = faceDetections[0];
    const bb = det.boundingBox;
    const rx = cw - ((bb.originX + bb.width) / video.videoWidth) * cw;
    const ry = (bb.originY / video.videoHeight) * ch;
    const rw = (bb.width / video.videoWidth) * cw;
    const rh = (bb.height / video.videoHeight) * ch;

    // Corner brackets instead of full rectangle
    const blen = 8;
    previewCtx.strokeStyle = bbColors.stroke;
    previewCtx.lineWidth = 2;
    previewCtx.beginPath();
    // Top-left
    previewCtx.moveTo(rx, ry + blen);
    previewCtx.lineTo(rx, ry);
    previewCtx.lineTo(rx + blen, ry);
    // Top-right
    previewCtx.moveTo(rx + rw - blen, ry);
    previewCtx.lineTo(rx + rw, ry);
    previewCtx.lineTo(rx + rw, ry + blen);
    // Bottom-left
    previewCtx.moveTo(rx, ry + rh - blen);
    previewCtx.lineTo(rx, ry + rh);
    previewCtx.lineTo(rx + blen, ry + rh);
    // Bottom-right
    previewCtx.moveTo(rx + rw - blen, ry + rh);
    previewCtx.lineTo(rx + rw, ry + rh);
    previewCtx.lineTo(rx + rw, ry + rh - blen);
    previewCtx.stroke();

    // "TARGET" label
    previewCtx.fillStyle = bbColors.stroke;
    previewCtx.font = "bold 8px monospace";
    previewCtx.fillText("TARGET", rx, ry - 2);
  }

  // "BB-CAM" indicator
  previewCtx.fillStyle = bbColors.stroke;
  previewCtx.beginPath();
  previewCtx.arc(10, 10, 4, 0, Math.PI * 2);
  previewCtx.fill();
  previewCtx.font = "bold 10px monospace";
  previewCtx.fillText("BB-CAM", 18, 15);

  // Timestamp / ID string bottom-left
  previewCtx.fillStyle = bbColors.fill + "0.6)";
  previewCtx.font = "7px monospace";
  const ts = new Date().toISOString().substr(11, 8);
  previewCtx.fillText("REC " + ts, 4, ch - 4);

  // --- Update canvas border and label based on detection level ---
  if (previewCanvas) {
    previewCanvas.style.borderColor = bbColors.stroke;
    previewCanvas.style.boxShadow = "0 0 18px " + bbColors.glow + "0.35), inset 0 0 10px rgba(0,0,0,0.6)";
  }
  const bbLabel = document.getElementById("bb-label");
  if (bbLabel) {
    if (bbLevel >= 0.7) {
      bbLabel.textContent = "\u26A0 BIG BROTHER NOTICES YOU \u26A0";
      bbLabel.style.color = bbColors.stroke;
      bbLabel.style.fontWeight = "bold";
    } else if (bbLevel >= 0.4) {
      bbLabel.textContent = "\uD83D\uDC41 SUSPICIOUS ACTIVITY \uD83D\uDC41";
      bbLabel.style.color = bbColors.stroke;
      bbLabel.style.fontWeight = "normal";
    } else {
      bbLabel.textContent = "\uD83D\uDC41 BIG BROTHER IS WATCHING \uD83D\uDC41";
      bbLabel.style.color = "rgba(0, 200, 60, 0.75)";
      bbLabel.style.fontWeight = "normal";
    }
  }
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
