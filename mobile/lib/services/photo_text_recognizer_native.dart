import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class PhotoTextRecognizer {
  static Future<String> extractFromPath(String path) async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      throw UnsupportedError('Photo OCR requires an installed Android or iOS app.');
    }
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(path));
      final text = result.text.trim();
      if (text.isEmpty) {
        throw const FormatException('No readable text detected. Try clearer lighting or type your notes.');
      }
      return text;
    } finally {
      await recognizer.close();
    }
  }
}
