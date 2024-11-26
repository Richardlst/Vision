import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart' as pathProvider;

class PhotoScreen extends StatefulWidget {
  final List<CameraDescription> cameras;


  PhotoScreen(this.cameras);

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  late CameraController controller;
  late AudioPlayer _audioPlayer;
  bool isCapturing = false;

//For switching Camera
  int selectedCameraIndex = 0;
  bool isFrontCamera = false;

//For Flash
  bool _isFlashOn = false;

//For Focusing
  Offset? _focusPoint;

//For Zoom
  double _currentZoom = 1.0;
  File? _capturedImage;

  @override
  void initState() {
    super.initState();
    _audioPlayer= AudioPlayer();
    controller = CameraController(widget.cameras[0], ResolutionPreset.max);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    controller.dispose();
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
      _audioPlayer.setAsset('C:/Users/thinh/AndroidStudioProjects/thu4/assets/Am_thanh_chup_Anh.mp3');
      _audioPlayer.play();
      // Capture image
      final XFile capturedImage = await controller.takePicture();
      // String imagePath = capturedImage.path;
      // await GallerySaver.saveImage(imagePath);
      // Success announcement
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Photo is saved to the gallery")),
      // );
    } catch(e){
      print("Error capturing photo: $e");
    } finally{
      setState(() {
        isCapturing=false;
      });
    }
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

