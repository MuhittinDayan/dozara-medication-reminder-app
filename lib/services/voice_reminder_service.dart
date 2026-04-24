import 'package:flutter_tts/flutter_tts.dart';

import 'hive_service.dart';

class VoiceReminderService {
  static final FlutterTts _tts = FlutterTts();
  static bool _configured = false;

  static Future<void> _configure() async {
    if (_configured) {
      return;
    }

    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    _configured = true;
  }

  static Future<void> speakReminder(
    String medicineName, {
    String? doseLabel,
    bool force = false,
  }) async {
    if (!force && !HiveService.getVoiceReminderEnabled()) {
      return;
    }

    await _configure();
    final detail = doseLabel == null || doseLabel.trim().isEmpty
        ? ''
        : ' $doseLabel zamani geldi.';
    await _tts.speak('$medicineName ilacinizi almayi unutmayin.$detail');
  }

  static Future<void> stop() async {
    if (!_configured) {
      return;
    }
    await _tts.stop();
  }
}
