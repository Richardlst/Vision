import 'package:flutter_tts/flutter_tts.dart';

FlutterTts flutterTts = FlutterTts();

Future<void> speak(String textToSpeak) async {
  await flutterTts.setLanguage("en-US");
  await flutterTts.setSpeechRate(0.5);
  await flutterTts.setVolume(1.0);
  await flutterTts.setPitch(1);

  try {
    var result = await flutterTts.speak(textToSpeak);
    if (result == 1) {
      print("Success");
    } else {
      print("Error");
    }
  } catch (e) {
    print('An error occurred: $e');
  }
}

