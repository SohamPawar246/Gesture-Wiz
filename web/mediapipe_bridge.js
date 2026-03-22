/**
 * MediaPipe Vision JS Bridge for THE EYE PROTOCOL
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
// 0.0 = green (safe), 0.30+ = yellow (caution), 0.62+ = red (danger)
window._bbDetectionLevel = 0.0;
const BB_YELLOW_THRESHOLD = 0.3;
const BB_RED_THRESHOLD = 0.62;

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
  if (level < BB_YELLOW_THRESHOLD) {
    return {
      stroke: "#00f06a",
      fill: "rgba(0, 240, 106, ",
      glow: "rgba(0, 210, 110, ",
      zone: "GREEN",
    };
  } else if (level < BB_RED_THRESHOLD) {
    const t =
      (level - BB_YELLOW_THRESHOLD) / (BB_RED_THRESHOLD - BB_YELLOW_THRESHOLD);
    const r = Math.round(255 * (0.85 + 0.15 * t));
    const g = Math.round(230 - 90 * t);
    return {
      stroke: "rgb(" + r + ", " + g + ", 0)",
      fill: "rgba(" + r + ", " + g + ", 0, ",
      glow: "rgba(" + r + ", " + g + ", 0, ",
      zone: "YELLOW",
    };
  } else {
    const t = Math.min(
      (level - BB_RED_THRESHOLD) / (1.0 - BB_RED_THRESHOLD),
      1.0,
    );
    const pulse = 0.75 + 0.25 * Math.sin(performance.now() / 120);
    const r = 255;
    const g = Math.round(120 * (1 - t) * pulse);
    return {
      stroke: "rgb(" + r + ", " + g + ", 0)",
      fill: "rgba(" + r + ", " + g + ", 0, ",
      glow: "rgba(255, 32, 0, ",
      zone: "RED",
    };
  }
}

function drawDetectionMeter(ctx, width, level, colors) {
  const meterX = 8;
  const meterY = 20;
  const meterW = width - 16;
  const meterH = 12;

  ctx.fillStyle = "rgba(0, 0, 0, 0.55)";
  ctx.fillRect(meterX, meterY, meterW, meterH);

  const fillW = Math.max(
    2,
    Math.floor(meterW * Math.min(Math.max(level, 0), 1)),
  );
  ctx.fillStyle = colors.fill + "0.92)";
  ctx.fillRect(meterX + 1, meterY + 1, Math.max(0, fillW - 2), meterH - 2);

  // Threshold markers
  const yX = meterX + meterW * BB_YELLOW_THRESHOLD;
  const rX = meterX + meterW * BB_RED_THRESHOLD;
  ctx.strokeStyle = "rgba(255, 255, 255, 0.35)";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(yX, meterY - 1);
  ctx.lineTo(yX, meterY + meterH + 1);
  ctx.moveTo(rX, meterY - 1);
  ctx.lineTo(rX, meterY + meterH + 1);
  ctx.stroke();

  ctx.strokeStyle = colors.stroke;
  ctx.lineWidth = 1.5;
  ctx.strokeRect(meterX, meterY, meterW, meterH);

  let statusText = "SAFE";
  if (colors.zone === "YELLOW") statusText = "ALERT";
  if (colors.zone === "RED") statusText = "CRITICAL";

  ctx.font = "bold 8px monospace";
  ctx.fillStyle = colors.stroke;
  ctx.fillText("THREAT " + statusText, meterX, meterY - 5);
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

  drawDetectionMeter(previewCtx, cw, bbLevel, bbColors);

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
    const borderWidth =
      bbLevel >= BB_RED_THRESHOLD ? 4 : bbLevel >= BB_YELLOW_THRESHOLD ? 3 : 2;
    previewCanvas.style.borderWidth = borderWidth + "px";
    previewCanvas.style.borderColor = bbColors.stroke;
    const pulse =
      bbLevel >= BB_RED_THRESHOLD
        ? 0.55 + 0.35 * Math.sin(performance.now() / 120)
        : 0.35;
    previewCanvas.style.boxShadow =
      "0 0 22px " +
      bbColors.glow +
      pulse +
      "), inset 0 0 12px rgba(0,0,0,0.65)";
  }
  const bbLabel = document.getElementById("bb-label");
  if (bbLabel) {
    bbLabel.style.textShadow = "0 0 8px " + bbColors.glow + "0.7)";
    bbLabel.style.letterSpacing = bbLevel >= BB_RED_THRESHOLD ? "2.4px" : "2px";
    bbLabel.style.fontSize = bbLevel >= BB_YELLOW_THRESHOLD ? "10px" : "9px";

    if (bbLevel >= BB_RED_THRESHOLD) {
      bbLabel.textContent = "BIG BROTHER NOTICES YOU";
      bbLabel.style.color = bbColors.stroke;
      bbLabel.style.fontWeight = "bold";
    } else if (bbLevel >= BB_YELLOW_THRESHOLD) {
      bbLabel.textContent = "SUSPICIOUS ACTIVITY";
      bbLabel.style.color = bbColors.stroke;
      bbLabel.style.fontWeight = "600";
    } else {
      bbLabel.textContent = "BIG BROTHER IS WATCHING";
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
initMediaPipe();

window.requestCameraPermission = async function () {
  try {
    await startWebcam();
    return true;
  } catch (e) {
    console.warn("[MediaPipe Bridge] Camera denied:", e);
    return false;
  }
};
