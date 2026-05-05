import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/backend/backend_service.dart';
import '../models/dose_log.dart';
import '../models/medicine.dart';
import 'hive_service.dart';
import 'ocr_service.dart';

enum ScanFieldConfidence {
  high,
  medium,
  low,
}

class ScanFieldSuggestion {
  const ScanFieldSuggestion({
    required this.value,
    required this.confidence,
    required this.source,
  });

  final String value;
  final ScanFieldConfidence confidence;
  final String source;
}

class MedicineScanResult {
  const MedicineScanResult({
    required this.ocrText,
    required this.fields,
  });

  final String ocrText;
  final Map<String, ScanFieldSuggestion> fields;

  bool get hasData => fields.isNotEmpty;

  ScanFieldSuggestion? operator [](String key) => fields[key];
}

enum AssistantScenario {
  interactionCheck,
  personalAnalysis,
  medicineInfo,
}

enum AssistantResponseType {
  plain,
  safe,
  warning,
  danger,
  info,
}

class AssistantContext {
  const AssistantContext({
    required this.userName,
    required this.medicines,
    required this.history,
    required this.complianceRate,
    required this.missedDoses,
    this.focusedMedicineName,
  });

  final String userName;
  final List<Medicine> medicines;
  final List<DoseLog> history;
  final int complianceRate;
  final int missedDoses;
  final String? focusedMedicineName;

  String get medicineList {
    if (medicines.isEmpty) {
      return 'Kayitli aktif ilac yok';
    }

    return medicines
        .map(
          (medicine) =>
              '${medicine.name}${medicine.dosage?.trim().isNotEmpty == true ? ' (${medicine.dosage!.trim()})' : ''}',
        )
        .join(', ');
  }

  static AssistantContext fromData({
    required String userName,
    required List<Medicine> medicines,
    required List<DoseLog> history,
    String? focusedMedicineName,
    int complianceDays = 7,
  }) {
    final cutoff = DateTime.now().subtract(Duration(days: complianceDays));
    final recentLogs = history
        .where((log) => log.scheduledTime.isAfter(cutoff))
        .toList(growable: false);
    final total = recentLogs.length;
    final taken =
        recentLogs.where((log) => log.status == DoseStatus.taken).length;
    final missed =
        recentLogs.where((log) => log.status == DoseStatus.missed).length;

    return AssistantContext(
      userName: userName,
      medicines: medicines,
      history: history,
      complianceRate: total == 0 ? 0 : ((taken / total) * 100).round(),
      missedDoses: missed,
      focusedMedicineName: focusedMedicineName,
    );
  }
}

class AssistantStructuredResponse {
  const AssistantStructuredResponse({
    required this.type,
    required this.title,
    required this.summary,
    required this.disclaimer,
    this.bullets = const <String>[],
    this.quickReplies = const <String>[],
  });

  final AssistantResponseType type;
  final String title;
  final String summary;
  final String disclaimer;
  final List<String> bullets;
  final List<String> quickReplies;

  bool get hasCard => type != AssistantResponseType.plain || title.isNotEmpty;
}

class AIQuotaExceededException implements Exception {
  const AIQuotaExceededException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AIService {
  static const int _scanDailyLimit = 10;
  static const int _assistantDailyLimit = 20;
  static const String _scanQuotaKey = 'geminiScan';
  static const String _assistantQuotaKey = 'geminiAssistant';
  static const String _proxyFunctionName = 'gemini-proxy';
  static const List<String> _supportedKeys = <String>[
    'name',
    'form',
    'dose',
    'frequency',
    'meal',
    'usageNotes',
  ];

  static bool _isInitialized = false;

  static String get assistantModelLabel => 'Gemini 3.1 Pro';

  static void init() {
    if (_isInitialized) {
      return;
    }

    _isInitialized = true;
  }

  static Future<MedicineScanResult?> analyzeMedicineImage(
    File imageFile,
  ) async {
    if (!BackendService.isInitialized || BackendService.currentUser == null) {
      throw Exception('AI tarama icin hesabinizla giris yapin.');
    }

    final hasQuota = await HiveService.tryConsumeDailyQuota(
      featureKey: _scanQuotaKey,
      dailyLimit: _scanDailyLimit,
    );
    if (!hasQuota) {
      throw const AIQuotaExceededException(
        'Gunluk ilac tarama limiti doldu (10/gun). Yarin tekrar deneyin.',
      );
    }

    try {
      final imageBytes = await imageFile.readAsBytes();
      final ocrText = await OcrService.extractTextFromImage(imageFile);
      final parsedFromOcr = _parseOcrText(ocrText);

      final responseText = await _invokeGeminiProxy({
        'type': 'scan',
        'imageBase64': base64Encode(imageBytes),
        'mimeType': 'image/jpeg',
        'ocrText': ocrText,
      });

      final parsedFromAi = _parseStructuredResponse(responseText);
      final fields = _mergeSuggestions(parsedFromOcr, parsedFromAi);

      return fields.isEmpty
          ? null
          : MedicineScanResult(ocrText: ocrText, fields: fields);
    } catch (e) {
      print('AI Image Analysis Error: $e');
      final friendlyMessage = _friendlyProxyError(e);
      if (friendlyMessage != null) {
        throw AIQuotaExceededException(friendlyMessage);
      }
      throw Exception('Ilac resmi analiz edilemedi: $e');
    }
  }

  static Future<String> _invokeGeminiProxy(Map<String, dynamic> body) async {
    final supabase = BackendService.client;
    if (supabase == null) {
      throw StateError(
        'AI servisi su an hazir degil. Lutfen daha sonra tekrar deneyin.',
      );
    }

    final response = await supabase.functions.invoke(
      _proxyFunctionName,
      body: body,
    );
    final data = response.data;
    if (data is Map && data['text'] is String) {
      return data['text'] as String;
    }
    if (data is String && data.trim().isNotEmpty) {
      return data;
    }
    throw StateError('Gemini proxy beklenen metin yanitini dondurmedi.');
  }

  static String? _friendlyProxyError(Object error) {
    if (error is! FunctionException) {
      return null;
    }

    final details = error.details;
    if (error.status == 401) {
      return 'AI ozellikleri icin hesabinizla giris yapin.';
    }

    if (error.status == 429 && details is Map) {
      final type = details['type'] == 'scan' ? 'tarama' : 'asistan';
      final limit = details['limit'];
      return 'Gunluk AI $type limiti doldu'
          '${limit is int ? ' ($limit/gun)' : ''}. Yarin tekrar deneyin.';
    }

    return null;
  }

  static Map<String, String> _parseStructuredResponse(String text) {
    final result = <String, String>{};

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.startsWith('ISIM:')) {
        result['name'] = line.replaceFirst('ISIM:', '').trim();
      } else if (line.startsWith('FORM:')) {
        result['form'] = _normalizeForm(line.replaceFirst('FORM:', '').trim());
      } else if (line.startsWith('DOZ:')) {
        result['dose'] = line.replaceFirst('DOZ:', '').trim();
      } else if (line.startsWith('SIKLIK:')) {
        result['frequency'] = line.replaceFirst('SIKLIK:', '').trim();
      } else if (line.startsWith('YEMEK:')) {
        result['meal'] = _normalizeMeal(line.replaceFirst('YEMEK:', '').trim());
      } else if (line.startsWith('KULLANIM:')) {
        result['usageNotes'] = line.replaceFirst('KULLANIM:', '').trim();
      }
    }

    return result;
  }

  static Map<String, String> _parseOcrText(String text) {
    final result = <String, String>{};
    final normalized = text.replaceAll('\r', ' ');
    final lower = normalized.toLowerCase();

    final doseMatch = RegExp(
      r'(\d+(?:[.,]\d+)?\s?(?:mg|mcg|g|ml|iu|unite))',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (doseMatch != null) {
      result['dose'] = doseMatch.group(1)!.trim();
    }

    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    for (final line in lines) {
      final lowerLine = line.toLowerCase();
      final looksLikeName = !lowerLine.contains('kullan') &&
          !lowerLine.contains('endikasyon') &&
          !lowerLine.contains('yardimci madde') &&
          !lowerLine.contains('film tablet') &&
          !lowerLine.contains('tablet') &&
          !lowerLine.contains('capsule') &&
          !RegExp(r'^\d').hasMatch(line) &&
          line.length >= 3;
      if (looksLikeName) {
        result.putIfAbsent('name', () => line);
        break;
      }
    }

    if (lower.contains('surup')) {
      result['form'] = 'Surup';
    } else if (lower.contains('tablet') || lower.contains('hap')) {
      result['form'] = 'Hap';
    } else if (lower.contains('igne') || lower.contains('enjeksiyon')) {
      result['form'] = 'Igne';
    } else if (lower.contains('damla')) {
      result['form'] = 'Damla';
    } else if (lower.contains('krem') || lower.contains('merhem')) {
      result['form'] = 'Krem';
    } else if (lower.contains('sprey') || lower.contains('inhaler')) {
      result['form'] = 'Sprey';
    }

    if (lower.contains('tok karn')) {
      result['meal'] = 'Tok';
    } else if (lower.contains('ac karn')) {
      result['meal'] = 'Ac';
    }

    if (lower.contains('sabah') &&
        lower.contains('ogle') &&
        lower.contains('aksam')) {
      result['frequency'] = '3';
      result['usageNotes'] = 'sabah, ogle, aksam';
    } else if (lower.contains('sabah') && lower.contains('aksam')) {
      result['frequency'] = '2';
      result['usageNotes'] = 'sabah, aksam';
    } else if (lower.contains('haftada 1') || lower.contains('haftada bir')) {
      result['frequency'] = '1';
      result['usageNotes'] = 'haftada bir';
    } else if (lower.contains('ayda 1') || lower.contains('ayda bir')) {
      result['frequency'] = '1';
      result['usageNotes'] = 'ayda bir';
    } else {
      final dailyMatch = RegExp(
        r'gunde\s*(\d+)|(\d+)\s*kez',
        caseSensitive: false,
      ).firstMatch(lower);
      final extracted = dailyMatch?.group(1) ?? dailyMatch?.group(2);
      if (extracted != null) {
        result['frequency'] = extracted;
      }
    }

    _normalizeUsageHints(result);
    _stripUnknownValues(result);
    return result;
  }

  static Map<String, ScanFieldSuggestion> _mergeSuggestions(
    Map<String, String> ocr,
    Map<String, String> ai,
  ) {
    final merged = <String, ScanFieldSuggestion>{};

    for (final key in _supportedKeys) {
      final ocrValue = _cleanFieldValue(ocr[key]);
      final aiValue = _cleanFieldValue(ai[key]);
      if (ocrValue == null && aiValue == null) {
        continue;
      }

      final chosenValue = aiValue ?? ocrValue!;
      if (ocrValue != null && aiValue != null) {
        final same = _normalizedCompare(ocrValue, aiValue);
        merged[key] = ScanFieldSuggestion(
          value: chosenValue,
          confidence: same ? ScanFieldConfidence.high : ScanFieldConfidence.low,
          source: same ? 'OCR + AI' : 'OCR / AI farkli',
        );
      } else if (ocrValue != null) {
        merged[key] = ScanFieldSuggestion(
          value: ocrValue,
          confidence: ScanFieldConfidence.medium,
          source: 'OCR',
        );
      } else if (aiValue != null) {
        merged[key] = ScanFieldSuggestion(
          value: aiValue,
          confidence: ScanFieldConfidence.low,
          source: 'AI',
        );
      }
    }

    return merged;
  }

  static String? _cleanFieldValue(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final lower = trimmed.toLowerCase();
    if (lower == 'belirsiz' || lower == 'yok' || lower == '-') {
      return null;
    }
    return trimmed;
  }

  static bool _normalizedCompare(String a, String b) {
    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

    return normalize(a) == normalize(b);
  }

  static String _normalizeForm(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('hap') || lower.contains('tablet')) {
      return 'Hap';
    }
    if (lower.contains('surup')) {
      return 'Surup';
    }
    if (lower.contains('igne')) {
      return 'Igne';
    }
    if (lower.contains('damla')) {
      return 'Damla';
    }
    if (lower.contains('krem') || lower.contains('merhem')) {
      return 'Krem';
    }
    if (lower.contains('sprey') || lower.contains('inhaler')) {
      return 'Sprey';
    }
    return value;
  }

  static String _normalizeMeal(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('tok')) {
      return 'Tok';
    }
    if (lower.contains('ac')) {
      return 'Ac';
    }
    if (lower.contains('farketmez')) {
      return 'Farketmez';
    }
    return value;
  }

  static void _normalizeUsageHints(Map<String, String> result) {
    final usage = (result['usageNotes'] ?? '').toLowerCase();
    final frequency = result['frequency']?.trim() ?? '';

    if (frequency.isEmpty || int.tryParse(frequency) == null) {
      if (usage.contains('sabah') &&
          usage.contains('ogle') &&
          usage.contains('aksam')) {
        result['frequency'] = '3';
      } else if (usage.contains('sabah') && usage.contains('aksam')) {
        result['frequency'] = '2';
      } else if (usage.contains('haftada bir')) {
        result['frequency'] = '1';
      } else if (usage.contains('ayda bir')) {
        result['frequency'] = '1';
      }
    }

    if ((result['meal'] ?? '').trim().isEmpty || result['meal'] == 'Belirsiz') {
      if (usage.contains('tok')) {
        result['meal'] = 'Tok';
      } else if (usage.contains('ac')) {
        result['meal'] = 'Ac';
      } else {
        result['meal'] = 'Farketmez';
      }
    }
  }

  static void _stripUnknownValues(Map<String, String> result) {
    final keysToRemove = <String>[];
    result.forEach((key, value) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty ||
          normalized == 'belirsiz' ||
          normalized == 'yok' ||
          normalized == '-') {
        keysToRemove.add(key);
      }
    });

    for (final key in keysToRemove) {
      result.remove(key);
    }
  }

  static String _buildAssistantPrompt({
    required String question,
    required AssistantContext context,
    required AssistantScenario scenario,
  }) {
    return '''
Sen Dozara uygulamasinin AI saglik asistanisin.

Kullanici profili:
- Isim: ${context.userName}
- Aktif ilaclar: ${context.medicineList}
- Bu haftaki uyum: ${context.complianceRate}%
- Kacirilan dozlar: ${context.missedDoses}
- Odak ilac: ${context.focusedMedicineName ?? 'Genel profil'}
- Senaryo: ${_assistantScenarioLabel(scenario)}

Kurallar:
1. Her yaniti kisa ve net tut.
2. Ilac etkilesimi veya riskli kullanim varsa TYPE alanini SAFE, WARNING veya DANGER sec.
3. Bilgilendirici ama risksiz cevaplarda INFO sec.
4. Karti olmayan cok kisa cevaplarda PLAIN sec.
5. Tibbi bilgi verirken kesin teshis koyma.
6. Her cevapta kisa bir sorumluluk reddi yaz.
7. Turkce cevap ver.
8. Sadece asagidaki formati kullan, ekstra aciklama ekleme.

Yanit formati:
TYPE: SAFE|WARNING|DANGER|INFO|PLAIN
TITLE: kisa baslik
SUMMARY: en onemli cevap
BULLETS:
- madde 1
- madde 2
DISCLAIMER: kisa sorumluluk reddi
QUICK_REPLIES: soru 1 | soru 2 | soru 3

KULLANICI SORUSU:
$question
''';
  }

  static String _assistantScenarioLabel(AssistantScenario scenario) {
    return switch (scenario) {
      AssistantScenario.interactionCheck => 'Etkilesim kontrolu',
      AssistantScenario.personalAnalysis => 'Kisisel analiz',
      AssistantScenario.medicineInfo => 'Ilac bilgisi',
    };
  }

  static AssistantResponseType _parseAssistantResponseType(String value) {
    return switch (value.trim().toUpperCase()) {
      'SAFE' => AssistantResponseType.safe,
      'WARNING' => AssistantResponseType.warning,
      'DANGER' => AssistantResponseType.danger,
      'INFO' => AssistantResponseType.info,
      _ => AssistantResponseType.plain,
    };
  }

  static AssistantStructuredResponse _parseAssistantResponse(String text) {
    AssistantResponseType type = AssistantResponseType.plain;
    var title = '';
    var summary = '';
    var disclaimer = '';
    final bullets = <String>[];
    final quickReplies = <String>[];
    var inBullets = false;

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      if (line.startsWith('TYPE:')) {
        inBullets = false;
        type = _parseAssistantResponseType(
          line.replaceFirst('TYPE:', '').trim(),
        );
      } else if (line.startsWith('TITLE:')) {
        inBullets = false;
        title = line.replaceFirst('TITLE:', '').trim();
      } else if (line.startsWith('SUMMARY:')) {
        inBullets = false;
        summary = line.replaceFirst('SUMMARY:', '').trim();
      } else if (line.startsWith('BULLETS:')) {
        inBullets = true;
      } else if (line.startsWith('DISCLAIMER:')) {
        inBullets = false;
        disclaimer = line.replaceFirst('DISCLAIMER:', '').trim();
      } else if (line.startsWith('QUICK_REPLIES:')) {
        inBullets = false;
        quickReplies.addAll(
          line
              .replaceFirst('QUICK_REPLIES:', '')
              .split('|')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty),
        );
      } else if (inBullets && line.startsWith('-')) {
        bullets.add(line.replaceFirst('-', '').trim());
      } else if (summary.isEmpty) {
        summary = line;
      }
    }

    if (summary.isEmpty && title.isEmpty) {
      return const AssistantStructuredResponse(
        type: AssistantResponseType.plain,
        title: '',
        summary: 'Su anda yapilandirilmis bir yanit alinamadi.',
        disclaimer: 'Tibbi sorular icin doktorunuza veya eczaciniza danisin.',
      );
    }

    return AssistantStructuredResponse(
      type: type,
      title: title,
      summary: summary,
      disclaimer: disclaimer.isEmpty
          ? 'Bu bilgi tibbi muayene yerine gecmez.'
          : disclaimer,
      bullets: bullets,
      quickReplies: quickReplies.take(3).toList(growable: false),
    );
  }

  static AssistantStructuredResponse _fallbackAssistantResponse(
    String question,
    AssistantContext context, {
    String? error,
  }) {
    final normalized = question.toLowerCase();
    final focusedName = context.focusedMedicineName ?? 'bu ilac';

    if (normalized.contains('doz') &&
        (normalized.contains('atl') || normalized.contains('unut'))) {
      return AssistantStructuredResponse(
        type: AssistantResponseType.info,
        title: 'Kacirilan doz kurali',
        summary:
            'Hatirlar hatirlamaz al; sonraki doza cok yakin ise atla; cift doz alma.',
        bullets: const [
          'Bulanti veya sersemlik olursa doktorunu ara.',
          'Planli saatleri not etmek tekrar kacirmayi azaltir.',
        ],
        disclaimer:
            'Kesin kullanim talimati icin prospektus ve doktor onerisi esastir.',
        quickReplies: [
          '$focusedName ac karnina alinir mi?',
          '$focusedName ne ise yarar?',
        ],
      );
    }

    if (normalized.contains('ac karn') || normalized.contains('tok karn')) {
      return AssistantStructuredResponse(
        type: AssistantResponseType.warning,
        title: 'Yemekle iliskiyi kontrol et',
        summary:
            '$focusedName icin ac veya tok kullanim bilgisi ilacin turune gore degisir; mide hassasiyeti varsa yemekle almak daha guvenli olabilir.',
        bullets: const [
          'Kutu veya prospektus bilgisini kontrol et.',
          'Mide yanmasi ya da bulanti olursa doktoruna danis.',
        ],
        disclaimer: 'Bu bilgi tibbi muayene yerine gecmez.',
        quickReplies: [
          '$focusedName yan etki yapar mi?',
          '$focusedName dozu atlanirsa ne yapmaliyim?',
        ],
      );
    }

    if (normalized.contains('etkiles') ||
        normalized.contains('birlikte') ||
        normalized.contains('kombin')) {
      return AssistantStructuredResponse(
        type: AssistantResponseType.warning,
        title: 'Etkilesim kontrolu gerekli',
        summary:
            'Profilindeki ilaclari baglam olarak ekledim, ancak bu cihazda dogrulanmis Gemini yaniti su anda alinamadi.',
        bullets: const [
          'Ozellikle kan sulandirici, seker ilaci ve tansiyon ilaclarinda dikkatli olun.',
          'Yeni ilac eklenince doktor veya eczaciya kombinasyonu sorun.',
        ],
        disclaimer: error ??
            'Kesin etkilesim degerlendirmesi icin doktorunuza veya eczaciniza danisin.',
        quickReplies: [
          'Yan etki riski var mi?',
          'Hangi ilaci hangi saatte almaliyim?',
        ],
      );
    }

    return AssistantStructuredResponse(
      type: AssistantResponseType.info,
      title: 'Kisa bilgi',
      summary:
          'Sorunu anladim. Profilindeki ilaclar ve son uyum verin baglam olarak hazir.',
      bullets: [
        'Aktif ilac sayisi: ${context.medicines.length}',
        'Bu haftaki uyum: %${context.complianceRate}',
      ],
      disclaimer: error ??
          'Detayli tibbi yonlendirme icin doktorunuza veya eczaciniza danisin.',
      quickReplies: [
        '$focusedName ne ise yarar?',
        'Bu haftayi ozetle',
      ],
    );
  }

  static Future<AssistantStructuredResponse> askAssistantStructured({
    required String question,
    required AssistantContext context,
    AssistantScenario scenario = AssistantScenario.medicineInfo,
  }) async {
    if (!BackendService.isInitialized || BackendService.currentUser == null) {
      return _fallbackAssistantResponse(
        question,
        context,
        error: 'AI asistani kullanmak icin hesabinizla giris yapin.',
      );
    }

    final hasQuota = await HiveService.tryConsumeDailyQuota(
      featureKey: _assistantQuotaKey,
      dailyLimit: _assistantDailyLimit,
    );
    if (!hasQuota) {
      return _fallbackAssistantResponse(
        question,
        context,
        error: 'Gunluk asistan limiti doldu (20/gun). Yarin tekrar deneyin.',
      );
    }

    try {
      final prompt = _buildAssistantPrompt(
        question: question,
        context: context,
        scenario: scenario,
      );
      final responseText = await _invokeGeminiProxy({
        'type': 'assistant',
        'prompt': prompt,
      });
      return _parseAssistantResponse(responseText);
    } catch (e) {
      print('AI Assistant Structured Error: $e');
      return _fallbackAssistantResponse(
        question,
        context,
        error: _friendlyProxyError(e) ?? 'Asistan yaniti alinamadi: $e',
      );
    }
  }

  static Future<String> askAssistant(
    String question,
    List<Medicine> medicines,
    List<DoseLog> history,
  ) async {
    final context = AssistantContext.fromData(
      userName: 'Kullanici',
      medicines: medicines,
      history: history,
    );
    final response = await askAssistantStructured(
      question: question,
      context: context,
      scenario: AssistantScenario.medicineInfo,
    );

    final buffer = StringBuffer();
    if (response.title.isNotEmpty) {
      buffer.writeln(response.title);
    }
    buffer.writeln(response.summary);
    for (final bullet in response.bullets) {
      buffer.writeln('- $bullet');
    }
    if (response.disclaimer.isNotEmpty) {
      buffer.writeln(response.disclaimer);
    }
    return buffer.toString().trim();
  }
}
