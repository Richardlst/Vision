import 'package:flutter/material.dart';
import 'package:thu4/home/object_detection.dart';
import 'package:thu4/home/init.dart';
import 'package:wakelock/wakelock.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Wakelock.enable();
  await appInit();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vision',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: SafeArea(
        child: Stack(
          children: [
            ObjectDetectorView(),
          ],
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}



