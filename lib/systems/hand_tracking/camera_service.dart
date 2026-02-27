import 'dart:io' show Platform;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isProcessingFrame = false;

  /// Signature for the callback when a new frame is captured
  final void Function(CameraImage image)? onFrameCaptured;

  CameraService({this.onFrameCaptured});

  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        debugPrint("No cameras found.");
        return;
      }

      // Select the first available camera (usually the built-in webcam)
      _controller = CameraController(
        _cameras!.first,
        ResolutionPreset.medium, // Balance performance/resolution for hand tracking MVP
        enableAudio: false,
      );

      await _controller!.initialize();

      if (onFrameCaptured != null) {
        // camera_windows does not currently support startImageStream
        // We will skip this downcast to prevent an assertion error crash on Windows MVP
        if (!Platform.isWindows) {
          _controller!.startImageStream((CameraImage image) {
            if (_isProcessingFrame) return; // Drop frame if backend is busy
            _isProcessingFrame = true;
            
            try {
              onFrameCaptured!(image);
            } finally {
              // Unblock next frame
              _isProcessingFrame = false;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
  }

  /// Returns the CameraPreview widget
  Widget buildCameraPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: Text(
          "Camera starting...",
          style: TextStyle(color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
        ),
      );
    }
    
    // Scale the camera to take the full screen while maintaining aspect ratio
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.previewSize?.width ?? 1,
          height: _controller!.value.previewSize?.height ?? 1,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  void dispose() {
    _controller?.dispose();
  }
}
