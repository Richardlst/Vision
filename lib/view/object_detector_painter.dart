import 'dart:async';
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:thu4/globals.dart' as globals;
import '../home/coordinates_translator.dart';
import './text_to_speech.dart';

class ObjectDetectorPainter extends CustomPainter {
  String lastSpokenWord = "";
  List<String> wordQueue = [];
  bool isSpeaking = false;
  Timer? _timer;
  bool _isModeActive = true;

  ObjectDetectorPainter(
      this._objects,
      this.imageSize,
      this.rotation,
      this.cameraLensDirection,
      ) {
    _timer = Timer.periodic(Duration(milliseconds: 800), (Timer timer) {
      handleQueueProcessing();
    }
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    // super.dispose();
  }

  void stopSpeaking() {
    isSpeaking = false;
    dispose();
  }


  void updateMode(bool mode) {
    if (mode) {
      _timer = Timer.periodic(Duration(milliseconds: 800), (Timer timer) {
        handleQueueProcessing();
      });
    } else {
      stopSpeaking();
      wordQueue.clear();
      _isModeActive = mode;
    }
  }



  void handleQueueProcessing() {
    if (!isSpeaking && wordQueue.isNotEmpty) {
      processQueue();
    }
  }

  Future<void> processQueue() async {
    if (globals.targetSearch =="") {
      updateMode(false);
      return;
    } else if (wordQueue.isEmpty || isSpeaking) {
      return;
    }
    var word = wordQueue.removeAt(0);
    isSpeaking = true;
    await speak(word);
    isSpeaking = false;
  }



  final List<DetectedObject> _objects;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.lightGreenAccent;

    final Paint background = Paint()..color = Color(0x99000000);

    for (final DetectedObject detectedObject in _objects) {
      final ParagraphBuilder builder = ParagraphBuilder(
        ParagraphStyle(
          textAlign: TextAlign.left,
          fontSize: 16,
          textDirection: TextDirection.ltr,
        ),
      );

      final left = translateX(
        detectedObject.boundingBox.left,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final top = translateY(
        detectedObject.boundingBox.top,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final right = translateX(
        detectedObject.boundingBox.right,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final bottom = translateY(
        detectedObject.boundingBox.bottom,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final centerX = (left + right) / 2;
      final matchingLabel =
      findMatchingLabel(globals.targetSearch, detectedObject.labels);
      if (matchingLabel != null) {
        builder.pushStyle(
          ui.TextStyle(color: Colors.red, background: background),
        );
        builder.addText('$matchingLabel ${calculatePosition(centerX, size.width)}\n');
        final text_to_speech = '$matchingLabel ${calculatePosition(centerX, size.width)}\n';
        if (text_to_speech != lastSpokenWord) {
          wordQueue.add(text_to_speech);
          lastSpokenWord = text_to_speech;
        }
        builder.pop();
      } else if (globals.targetSearch == "môtảxungquanh") {
        final label = detectedObject.labels
            .reduce((a, b) => a.confidence > b.confidence ? a : b);
        builder.pushStyle(
          ui.TextStyle(color: Colors.red, background: background),
        );

        builder.addText('${label.text} ${label.confidence} ${calculatePosition(centerX, size.width)}\n');
        final text_to_speech = '${label.text}';
        if (text_to_speech != lastSpokenWord) {
          wordQueue.add(text_to_speech);
          lastSpokenWord = text_to_speech;
        }
        builder.pop();
      } else {
        if (detectedObject.labels.isNotEmpty) {
          final label = detectedObject.labels
              .reduce((a, b) => a.confidence > b.confidence ? a : b);
          builder.pushStyle(
            ui.TextStyle(color: Colors.lightGreenAccent, background: background),
          );
          builder.addText('${label.text} ${label.confidence} ${calculatePosition(centerX, size.width)}\n');
          builder.pop();
        }
      }

      canvas.drawRect(
        Rect.fromLTRB(left, top, right, bottom),
        paint,
      );

      canvas.drawParagraph(
        builder.build()
          ..layout(
            ParagraphConstraints(width: (right - left).abs()),
          ),
        Offset(
          cameraLensDirection == CameraLensDirection.front ? right : left,
          top,
        ),
      );
    }
  }

  String? findMatchingLabel(String target, List<Label> labels) {
    for (final label in labels) {
      String labelLowerCase = label.text.toLowerCase();
      String cleanedText = labelLowerCase.replaceAll(" ", "").trim();
      if (cleanedText == target) {
        return label.text;
      }
    }
    return null;
  }

  String calculatePosition(double objectX, double screenWidth) {
    final screenWidthHalf = screenWidth / 2;
    if (objectX < screenWidthHalf) {
      return 'left';
    } else if (objectX > screenWidthHalf) {
      return 'right';
    } else {
      return 'center';
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;


}