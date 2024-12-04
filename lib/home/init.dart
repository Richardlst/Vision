import 'package:camera/camera.dart';

late List<CameraDescription> _cameras;
late CameraController controller;

Future<void> appInit() async {
  _cameras = await availableCameras();
}

List<CameraDescription> getCameras() {
  return _cameras;
}

CameraController getCameraController() {
  return controller;  
}
