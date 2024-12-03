import 'dart:io';
import 'dart:io' as io;
import 'package:just_audio/just_audio.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart' as pathProvider;
import 'package:tflite/tflite.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/yolo_model.dart';
class PhotoScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const PhotoScreen(this.cameras, {super.key});
  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  late CameraController controller;
  late AudioPlayer _audioPlayer;
  bool isCapturing = false;
  late Interpreter interpreter;
  late ObjectDetector _objectDetector;
//For switching Camera
  int selectedCameraIndex = 0;
  bool isFrontCamera = false;

//For Flash
  bool _isFlashOn = false;

//For Focusing
  Offset? _focusPoint;

//For Zoom
  final double _currentZoom = 1.0;
  File? _capturedImage;

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();
    _audioPlayer= AudioPlayer();
    _loadModel();
    _initObjectDetectorWithLocalModel().then((detector) {
      setState(() {
        _objectDetector = detector; // Lưu detector vào biến
      });
    });
    controller = CameraController(widget.cameras[0], ResolutionPreset.max);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  Future<void> _loadModel() async {
    try {
      interpreter = await Interpreter.fromAsset('assets/yolo11n_float32.tflite');
      // await Tflite.loadModel(
      //   model: "assets/object_labeler.tflite"
      // );
      // var options = InterpreterOptions()..addDelegate(FlexDelegate());
      // final interpreter = await Interpreter.fromAsset('assets/yolov8n.tflite', options: options);
      print('Model loaded successfully');
    } catch (e) {
      print('Error loading model: $e');
    }
  }

  @override
  void dispose() async {
    _audioPlayer.dispose();
    controller.dispose();
    await Tflite.close();
    super.dispose();
  }

  void _toggleFlashLight() {
    if (_isFlashOn) {
      controller.setFlashMode(FlashMode.off);
      setState(() {
        _isFlashOn = false;
      });
    } else {
      controller.setFlashMode(FlashMode.torch);
      setState(() {
        _isFlashOn = true;
      });
    }
  }

  void capturePhoto() async{
    if(!controller.value.isInitialized){
      return;
    }
    final Directory appDir = await pathProvider.getApplicationSupportDirectory();
    final String capturePath = path.join(appDir.path, '${DateTime.now()}.jpg');
    if(controller.value.isTakingPicture){
      return;
    }
    try{
      setState(() {
        isCapturing = true;
      });
      // Play a sound
      _audioPlayer.setAsset('assets/Am_thanh_chup_Anh.mp3');
      _audioPlayer.play();
      // Capture image
      final XFile capturedImage = await controller.takePicture();
      final File imageFile = File(capturedImage.path);
      final img.Image image = img.decodeImage(await imageFile.readAsBytes())!;
      final img.Image resizedImage = img.copyResize(image, width: 416, height: 416);
      final input = _preprocessImage(resizedImage);
      final output = List.generate(1, (_) => List.filled(10, 0.0));
      interpreter.run(input, output);
      print('Model Output: $output');
    } catch(e){
      print("Error capturing photo: $e");
    } finally{
      setState(() {
        isCapturing=false;
      });
    }
  }
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
  Future<ImageClassifier> _initImageClassifierWithLocalModel() async {
    final modelPath = await _copy('assets/yolo11n_float32.tflite');
    final model = LocalYoloModel(
      id: '',
      task: Task.classify,
      format: Format.coreml,
      modelPath: modelPath,
    );
    return ImageClassifier(model: model);
  }

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
                            _toggleFlashLight();
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
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: (){
                                  capturePhoto();
                                },
                                child: Center(
                                  child: Container(
                                    height: 70,
                                    width: 70,
                                    decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(50),
                                        border: Border.all(
                                          width: 4,
                                          color: Colors.white,
                                          style: BorderStyle.solid,
                                        )),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
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

