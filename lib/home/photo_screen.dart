import 'dart:io';
import 'dart:io' as io;
import 'package:just_audio/just_audio.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart' as pathProvider;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:tflite/tflite.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/yolo_model.dart';
import 'package:thu4/globals.dart' as globals;
import 'package:thu4/view/text_to_speech.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

class PhotoScreen extends StatefulWidget {
  final CustomPaint? customPaint;
  final Function(InputImage inputImage) onImage;
  final VoidCallback? onCameraFeedReady;
  final VoidCallback? onDetectorViewModeChanged;
  final Function(CameraLensDirection direction)? onCameraLensDirectionChanged;
  final CameraLensDirection initialCameraLensDirection;

  PhotoScreen({
    Key? key,
    required this.customPaint,
    required this.onImage,
    this.onCameraFeedReady,
    this.onDetectorViewModeChanged,
    this.onCameraLensDirectionChanged,
    this.initialCameraLensDirection = CameraLensDirection.back,
  }) : super(key: key);

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  static List<CameraDescription> _cameras = [];
  CameraController? _controller;
  late CameraController controller;
  late AudioPlayer _audioPlayer;
  bool isCapturing = false;
  late Interpreter interpreter;
  late ObjectDetector _objectDetector;
  bool _speechEnabled = false;

  int selectedCameraIndex = 0;
  bool isFrontCamera = false;
  bool _isFlashOn = false;
  bool _isModeActive = false;
  int _cameraIndex = -1;
  Offset? _focusPoint;
  String wordsSpoken = "";
  double confidenceLevel = 0;
  double _currentZoomLevel = 1.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _currentExposureOffset = 0.0;
  bool _changingCameraLens = false;
  final double _currentZoom = 1.0;
  File? _capturedImage;
  final SpeechToText _speechToText = SpeechToText();

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();
    _audioPlayer = AudioPlayer();
    // _loadModel();
    _initialize();
    // initSpeech();
    // _initObjectDetectorWithLocalModel().then((detector) {
    //   setState(() {
    //     _objectDetector = detector; // Lưu detector vào biến
    //   });
    // });
    // controller = CameraController(widget.cameras[0], ResolutionPreset.max);
    // controller.initialize().then((_) {
    //   if (!mounted) {
    //     return;
    //   }
    //   setState(() {});
    // });
  }

  void _initialize() async {
    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
      _speechEnabled = await _speechToText.initialize();
      await speak("Tap the microphone in the bottom to start listening");
    }
    for (var i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == widget.initialCameraLensDirection) {
        _cameraIndex = i;
        break;
      }
    }
    if (_cameraIndex != -1) {
      _startLiveFeed();
    }
  }

  Future _startLiveFeed() async {
    final camera = _cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      // Set to ResolutionPreset.high. Do NOT set it to ResolutionPreset.max because for some phones does NOT work.
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _controller?.getMinZoomLevel().then((value) {
        _currentZoomLevel = value;
        _minAvailableZoom = value;
      });
      _controller?.getMaxZoomLevel().then((value) {
        _maxAvailableZoom = value;
      });
      _currentExposureOffset = 0.0;
      _controller?.getMinExposureOffset().then((value) {
        _minAvailableExposureOffset = value;
      });
      _controller?.getMaxExposureOffset().then((value) {
        _maxAvailableExposureOffset = value;
      });
      _controller?.startImageStream(_processCameraImage).then((value) {
        if (widget.onCameraFeedReady != null) {
          widget.onCameraFeedReady!();
        }
        if (widget.onCameraLensDirectionChanged != null) {
          widget.onCameraLensDirectionChanged!(camera.lensDirection);
        }
      });
      setState(() {});
    });
  }

  void _processCameraImage(CameraImage image) {
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;
    widget.onImage(inputImage);
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/android/src/main/java/com/google_mlkit_commons/InputImageConverter.java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/ios/Classes/MLKVisionImage%2BFlutterPlugin.m
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/example/lib/vision_detector_views/painters/coordinates_translator.dart
    final camera = _cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    // print(
    //     'lensDirection: ${camera.lensDirection}, sensorOrientation: $sensorOrientation, ${_controller?.value.deviceOrientation} ${_controller?.value.lockedCaptureOrientation} ${_controller?.value.isCaptureOrientationLocked}');
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      // print('rotationCompensation: $rotationCompensation');
    }
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  Future<void> _loadModel() async {
    try {
      interpreter =
          await Interpreter.fromAsset('assets/yolo11n_float32.tflite');
      // await Tflite.loadModel(
      //
      // );
      // var options = InterpreterOptions()..addDelegate(FlexDelegate());
      // final interpreter = await Interpreter.fromAsset options: options);
      print('Model loaded successfully');
    } catch (e) {
      print('Error loading model: $e');
    }
  }

  Future _stopLiveFeed() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() async {
    _audioPlayer.dispose();
    _stopLiveFeed();
    // controller.dispose();
    await Tflite.close();
    super.dispose();
  }

  // void _toggleFlashLight() {
  //   if (_isFlashOn) {
  //     controller.setFlashMode(FlashMode.off);
  //     setState(() {
  //       _isFlashOn = false;
  //     });
  //   } else {
  //     controller.setFlashMode(FlashMode.torch);
  //     setState(() {
  //       _isFlashOn = true;
  //     });
  //   }
  // }

  // void capturePhoto() async {
  //   if (!controller.value.isInitialized) {
  //     return;
  //   }
  //   final Directory appDir =
  //       await pathProvider.getApplicationSupportDirectory();
  //   final String capturePath = path.join(appDir.path, '${DateTime.now()}.jpg');
  //   if (controller.value.isTakingPicture) {
  //     return;
  //   }
  //   try {
  //     setState(() {
  //       isCapturing = true;
  //     });
  //     // Play a sound
  //     _audioPlayer.setAsset('assets/Am_thanh_chup_Anh.mp3');
  //     _audioPlayer.play();
  //     // Capture image
  //     final XFile capturedImage = await controller.takePicture();
  //     final File imageFile = File(capturedImage.path);
  //     final img.Image image = img.decodeImage(await imageFile.readAsBytes())!;
  //     final img.Image resizedImage =
  //         img.copyResize(image, width: 416, height: 416);
  //     final input = _preprocessImage(resizedImage);
  //     final output = List.generate(1, (_) => List.filled(10, 0.0));
  //     interpreter.run(input, output);
  //     print('Model Output: $output');
  //   } catch (e) {
  //     print("Error capturing photo: $e");
  //   } finally {
  //     setState(() {
  //       isCapturing = false;
  //     });
  //   }
  // }

  List<List<List<double>>> _preprocessImage(img.Image image) {
    final input = List.generate(
      1,
      (_) => List.generate(
        416,
        (_) => List.generate(
          416,
          (_) => 0.0,
        ),
      ),
    );

    for (int y = 0; y < 416; y++) {
      for (int x = 0; x < 416; x++) {
        final pixel = image.getPixel(x, y);
        // input[0][y][x] = img.getRed(pixel) / 255.0;
      }
    }

    return input;
  }

  // Future<ImageClassifier> _initImageClassifierWithLocalModel() async {
  //   final modelPath = await _copy('assets/yolo11n_float32.tflite');
  //   final model = LocalYoloModel(
  //     id: '',
  //     task: Task.classify,
  //     format: Format.coreml,
  //     modelPath: modelPath,
  //   );
  //   return ImageClassifier(model: model);
  // }

  Future<String> _copy(String assetPath) async {
    final path = '${(await getApplicationSupportDirectory()).path}/$assetPath';
    await io.Directory(dirname(path)).create(recursive: true);
    final file = io.File(path);
    if (!await file.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    return file.path;
  }

  Future<ObjectDetector> _initObjectDetectorWithLocalModel() async {
    final modelPath = await _copy('assets/yolo11n_float32.tflite');
    final model = LocalYoloModel(
      id: '',
      task: Task.detect,
      format: Format.tflite,
      modelPath: modelPath,
    );
    return ObjectDetector(model: model);
  }

  void extractTargetObject(String spokenText) {
    String tmpText = spokenText.toLowerCase();
    String cleanedText = tmpText.replaceAll("tìm", "").trim();
    List<String> words = cleanedText.split(" ");
    setState(() {
      globals.targetSearch = words.join("");
    });
  }

  void onSpeechResult(result) {
    setState(() {
      wordsSpoken =
          _speechToText.isListening ? "${result.recognizedWords}" : "";
      confidenceLevel = result.confidence;
    });
    extractTargetObject(wordsSpoken);
  }

  void startListening() async {
    await _speechToText.listen(onResult: onSpeechResult);
    await speak("Listening");
    setState(() {
      confidenceLevel = 0;
    });
  }

  void stopListening() async {
    await _speechToText.stop();
    await speak("Stop listening, tap the microphone to start listening");
    setState(() {
      // globals.targetSearch = "";
      wordsSpoken = "";
    });
  }

  Widget _liveFeedBody() {
    if (_cameras.isEmpty) return Container();
    if (_controller == null) return Container();
    if (_controller?.value.isInitialized == false) return Container();
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(
            child: _changingCameraLens
                ? Center(
                    child: const Text('Changing camera lens'),
                  )
                : CameraPreview(
                    _controller!,
                    child: widget.customPaint,
                  ),
          ),
          // _backButton(),
          // _switchLiveCameraToggle(),
          // _detectionViewModeToggle(),
          // _zoomControl(),
          // _exposureControl(),
          _voiceButton(),
          _additionalText()
        ],
      ),
    );
  }

  Widget _additionalText() => Positioned(
        top: 64,
        left: 8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _speechToText.isListening
                  ? "Listening..."
                  : _speechEnabled
                      ? "Tap the microphone to start listening..."
                      : "Speech not available",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.0,
              ),
            ),
            // if (confidenceLevel > 0 && _speechToText.isNotListening)
            Text(
              globals.targetSearch,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.0,
              ),
            ),
          ],
        ),
      );

  Widget _voiceButton() {
    return Align(
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          // Toggle between starting and stopping speech recognition
          _speechToText.isListening ? stopListening() : startListening();
          if (_isModeActive) {
            globals.targetSearch = "";
          }
          setState(() {
            _isModeActive = !_isModeActive;
          });
        },
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    width: 4,
                    color: Colors.white,
                    style: BorderStyle.solid,
                  ),
                ),
              ),
              Icon(
                _speechToText.isNotListening ? Icons.mic_off : Icons.mic,
                size: 25,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(body: LayoutBuilder(
        builder: (BuildContext, BoxConstraints) {
          return Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: GestureDetector(
                          onTap: () {
                            // _toggleFlashLight();
                          },
                          child: _isFlashOn == false
                              ? Icon(
                                  Icons.flash_off,
                                  color: Colors.white,
                                )
                              : Icon(
                                  Icons.flash_on,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                top: 50,
                bottom: isFrontCamera == false ? 0 : 150,
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: CameraPreview(controller),
                ),
              ),
              Stack(
                children: [
                  _liveFeedBody(),
                ],
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color:
                        isFrontCamera == false ? Colors.black45 : Colors.black,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: Center(
                                child: Text(
                                  "Video",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  "Photo",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  "Pro Mode",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            _voiceButton(),
                            // Call the _voiceButton() widget here
                            // Other widgets can be added here
                          ],
                        ),
                      )
                      // Expanded(
                      //   child: Column(
                      //     mainAxisAlignment: MainAxisAlignment.center,
                      //     children: [
                      //       Expanded(
                      //         child: GestureDetector(
                      //           onTap: () {
                      //             // capturePhoto();
                      //             _speechToText.isListening
                      //                 ? stopListening()
                      //                 : startListening();
                      //             if (_isModeActive) {
                      //               globals.targetSearch = "";
                      //             }
                      //             setState(() {
                      //               _isModeActive = !_isModeActive;
                      //             });
                      //           },
                      //           child: Center(
                      //             child: Stack(
                      //               alignment: Alignment.center,
                      //               children: [
                      //                 Container(
                      //                   height: 70,
                      //                   width: 70,
                      //                   decoration: BoxDecoration(
                      //                     color: Colors.transparent,
                      //                     borderRadius:
                      //                         BorderRadius.circular(50),
                      //                     border: Border.all(
                      //                       width: 4,
                      //                       color: Colors.white,
                      //                       style: BorderStyle.solid,
                      //                     ),
                      //                   ),
                      //                 ),
                      //                 Icon(
                      //                   _speechToText.isNotListening
                      //                       ? Icons.mic_off
                      //                       : Icons.mic,
                      //                   size: 25,
                      //                   color: Colors.white,
                      //                 ),
                      //               ],
                      //             ),
                      //           ),
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // )
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      )),
    );
  }
}
