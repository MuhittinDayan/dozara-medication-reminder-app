import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static Future<String> extractTextFromImage(File imageFile) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final recognizedText = await recognizer.processImage(inputImage);
      return recognizedText.text.trim();
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    } catch (_) {
      return '';
    } finally {
      await recognizer.close();
    }
  }
}
