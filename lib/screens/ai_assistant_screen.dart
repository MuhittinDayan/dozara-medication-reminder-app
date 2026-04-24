import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/dose_log.dart';
import '../models/medicine.dart';
import '../services/ai_service.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({
    super.key,
    this.medicine,
  });

  final Medicine? medicine;

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final stt.SpeechToText _speech;

  Medicine? _focusedMedicine;
  List<Medicine> _activeMedicines = const [];
  AssistantContext? _assistantContext;
  List<_AssistantMessage> _messages = const [];
  List<_QuickPrompt> _quickPrompts = const [];
  _AssistantViewScenario _scenario = _AssistantViewScenario.interaction;
  _WeeklyInsight? _weeklyInsight;
  Map<String, List<_DayCompliance>> _weeklyRows = const {};
  bool _isListening = false;
  bool _isSending = false;
  bool _isApplyingInsight = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _scenario = widget.medicine != null
        ? _AssistantViewScenario.medicineInfo
        : _AssistantViewScenario.interaction;
    _refreshData();
  }

  @override
  void dispose() {
    _speech.stop();
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _refreshData({bool reseed = true}) {
    final liveMedicine = widget.medicine == null
        ? null
        : (HiveService.getMedicine(widget.medicine!.id) ?? widget.medicine);
    final activeMedicines = HiveService.getActiveMedicines();
    final recentHistory = HiveService.getRecentDoseLogs();
    final profile = HiveService.getActiveProfile();
    final assistantContext = AssistantContext.fromData(
      userName: profile.name,
      medicines: activeMedicines,
      history: recentHistory,
      focusedMedicineName: liveMedicine?.name,
    );
    final weeklyRows = _buildWeeklyRows(activeMedicines, recentHistory);
    final weeklyInsight = _buildWeeklyInsight(
      focusedMedicine: liveMedicine,
      medicines: activeMedicines,
      history: recentHistory,
    );

    setState(() {
      _focusedMedicine = liveMedicine;
      _activeMedicines = activeMedicines;
      _assistantContext = assistantContext;
      _weeklyRows = weeklyRows;
      _weeklyInsight = weeklyInsight;
      _quickPrompts = _quickPromptsForScenario(_scenario);
      if (reseed) {
        _messages = _seededMessages(_scenario);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  List<_AssistantMessage> _seededMessages(_AssistantViewScenario scenario) {
    final userName = HiveService.getActiveProfile().name;
    final focusedName = _focusedMedicine?.name;

    return switch (scenario) {
      _AssistantViewScenario.interaction => [
          _AssistantMessage.assistantText(
            'Merhaba $userName. Ilac kombinasyonlari, yan etki riski ve birlikte kullanim konularinda yardim edebilirim.',
          ),
        ],
      _AssistantViewScenario.personalAnalysis => [
          _AssistantMessage.assistantText(
            'Haftalik ilac uyum analizini hazirladim. Dilersen asagidaki icgoruyu uygulayabilir veya detay soru sorabilirsin.',
          ),
        ],
      _AssistantViewScenario.medicineInfo => [
          _AssistantMessage.assistantText(
            focusedName == null
                ? 'Aktif ilaclarin hakkinda kisa bilgi alabilirsin.'
                : '$focusedName icin kullanim, ac-tok bilgisi ve kacirilan doz kurallari konusunda yardim edebilirim.',
          ),
        ],
    };
  }

  List<_QuickPrompt> _quickPromptsForScenario(_AssistantViewScenario scenario) {
    final focusedName = _focusedMedicine?.name ?? 'bu ilac';
    String? secondaryMedicine;
    for (final medicine in _activeMedicines) {
      if (medicine.id != _focusedMedicine?.id) {
        secondaryMedicine = medicine.name;
        break;
      }
    }

    return switch (scenario) {
      _AssistantViewScenario.interaction => [
          _QuickPrompt(
            label: 'Etkilesim?',
            prompt: secondaryMedicine == null
                ? '$focusedName baska ilaclarla etkilesir mi?'
                : '$focusedName ile $secondaryMedicine birlikte alinabilir mi?',
          ),
          _QuickPrompt(
            label: 'Yan etki',
            prompt: '$focusedName yan etki riski tasir mi?',
          ),
          _QuickPrompt(
            label: 'Guvenli mi?',
            prompt: '$focusedName kullanirken nelere dikkat etmeliyim?',
          ),
        ],
      _AssistantViewScenario.personalAnalysis => [
          const _QuickPrompt(
            label: 'Haftayi ozetle',
            prompt: 'Bu haftaki ilac uyumumu kisaca ozetle.',
          ),
          const _QuickPrompt(
            label: 'Hangi saatler?',
            prompt: 'Hangi saatlerde doz kaciriyorum?',
          ),
          const _QuickPrompt(
            label: 'Alarm onerisi',
            prompt: 'Alarm saatlerim icin bir oneri ver.',
          ),
        ],
      _AssistantViewScenario.medicineInfo => [
          _QuickPrompt(
            label: 'Ne ise yarar?',
            prompt: '$focusedName ne ise yarar?',
          ),
          _QuickPrompt(
            label: 'Ac karnina?',
            prompt: '$focusedName ac karnina alinir mi?',
          ),
          _QuickPrompt(
            label: 'Doz atladim',
            prompt: '$focusedName dozunu atladim, ne yapmaliyim?',
          ),
        ],
    };
  }

  Map<String, List<_DayCompliance>> _buildWeeklyRows(
    List<Medicine> medicines,
    List<DoseLog> history,
  ) {
    final days = _lastSevenDays();
    final rows = <String, List<_DayCompliance>>{};

    for (final medicine in medicines) {
      rows[medicine.id] = days.map((day) {
        final dayLogs = history
            .where(
              (log) =>
                  log.medicineId == medicine.id &&
                  _isSameDay(log.scheduledTime, day),
            )
            .toList(growable: false);
        final hasDose = dayLogs.isNotEmpty;
        final fullyTaken =
            hasDose && dayLogs.every((log) => log.status == DoseStatus.taken);
        final hasMissed = dayLogs.any((log) => log.status == DoseStatus.missed);

        return _DayCompliance(
          date: day,
          hasDose: hasDose,
          fullyTaken: fullyTaken,
          hasMissed: hasMissed,
        );
      }).toList(growable: false);
    }

    return rows;
  }

  _WeeklyInsight? _buildWeeklyInsight({
    required Medicine? focusedMedicine,
    required List<Medicine> medicines,
    required List<DoseLog> history,
  }) {
    final orderedMedicines = <Medicine>[
      if (focusedMedicine != null) focusedMedicine,
      ...medicines.where((medicine) => medicine.id != focusedMedicine?.id),
    ];

    for (final medicine in orderedMedicines) {
      final recentMisses = history
          .where((log) => log.medicineId == medicine.id)
          .where((log) => log.status == DoseStatus.missed)
          .where(
            (log) => log.scheduledTime.isAfter(
              DateTime.now().subtract(const Duration(days: 14)),
            ),
          )
          .toList(growable: false);

      if (recentMisses.length < 2) {
        continue;
      }

      final weekdayCounts = <int, int>{};
      final slotCounts = <_DoseSlot, int>{};
      for (final log in recentMisses) {
        weekdayCounts.update(
          log.scheduledTime.weekday,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        final slot = _doseSlotFromDateTime(log.scheduledTime);
        slotCounts.update(slot, (value) => value + 1, ifAbsent: () => 1);
      }

      if (slotCounts.isEmpty) {
        continue;
      }

      final topSlotEntry = slotCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topSlot = topSlotEntry.first.key;
      final topDays = weekdayCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final repeatedDays =
          topDays.take(2).map((item) => _weekdayLabel(item.key));
      final currentTime = _preferredReminderForSlot(medicine, topSlot);
      final recommendedTime =
          currentTime == null ? null : _shiftTime(currentTime, minutes: -30);

      return _WeeklyInsight(
        targetMedicineId: medicine.id,
        medicineName: medicine.name,
        repeatedDaysLabel: repeatedDays.join(' ve '),
        slot: topSlot,
        currentTime: currentTime,
        recommendedTime: recommendedTime,
      );
    }

    return null;
  }

  List<DateTime> _lastSevenDays() {
    final today = DateTime.now();
    return List.generate(
      7,
      (index) => DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: 6 - index)),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Pazartesi';
      case DateTime.tuesday:
        return 'Sali';
      case DateTime.wednesday:
        return 'Carsamba';
      case DateTime.thursday:
        return 'Persembe';
      case DateTime.friday:
        return 'Cuma';
      case DateTime.saturday:
        return 'Cumartesi';
      case DateTime.sunday:
        return 'Pazar';
      default:
        return 'Bu gunler';
    }
  }

  _DoseSlot _doseSlotFromDateTime(DateTime dateTime) {
    final hour = dateTime.hour;
    if (hour < 11) {
      return _DoseSlot.morning;
    }
    if (hour < 17) {
      return _DoseSlot.noon;
    }
    return _DoseSlot.evening;
  }

  TimeOfDay? _preferredReminderForSlot(Medicine medicine, _DoseSlot slot) {
    for (final value in medicine.doseTimes) {
      final time = _timeFromString(value);
      if (_doseSlotFromTime(time) == slot) {
        return time;
      }
    }
    return medicine.doseTimes.isEmpty
        ? null
        : _timeFromString(medicine.doseTimes.first);
  }

  _DoseSlot _doseSlotFromTime(TimeOfDay time) {
    if (time.hour < 11) {
      return _DoseSlot.morning;
    }
    if (time.hour < 17) {
      return _DoseSlot.noon;
    }
    return _DoseSlot.evening;
  }

  TimeOfDay _timeFromString(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 8;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _timeToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  TimeOfDay _shiftTime(TimeOfDay time, {required int minutes}) {
    final totalMinutes = ((time.hour * 60) + time.minute + minutes).clamp(
      5 * 60,
      (23 * 60) + 59,
    );
    return TimeOfDay(
      hour: totalMinutes ~/ 60,
      minute: totalMinutes % 60,
    );
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      final available = await _speech.initialize();
      if (!available) {
        return;
      }
      setState(() => _isListening = true);
      await _speech.listen(
        localeId: 'tr_TR',
        onResult: (result) {
          setState(() {
            _promptController.text = result.recognizedWords;
            _promptController.selection = TextSelection.fromPosition(
              TextPosition(offset: _promptController.text.length),
            );
          });
        },
      );
      return;
    }

    await _speech.stop();
    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  Future<void> _submitPrompt([String? value]) async {
    final question = (value ?? _promptController.text).trim();
    final assistantContext = _assistantContext;
    if (question.isEmpty || assistantContext == null || _isSending) {
      return;
    }

    await _speech.stop();
    if (!mounted) {
      return;
    }

    setState(() {
      _isListening = false;
      _isSending = true;
      _messages = [
        ..._messages,
        _AssistantMessage.user(question),
      ];
      _promptController.clear();
    });
    _scrollToBottom();

    final response = await AIService.askAssistantStructured(
      question: question,
      context: assistantContext,
      scenario: _assistantScenarioFromView(_scenario),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _messages = [
        ..._messages,
        _AssistantMessage.assistantResponse(response),
      ];
      _isSending = false;
    });
    _scrollToBottom();
  }

  AssistantScenario _assistantScenarioFromView(
    _AssistantViewScenario scenario,
  ) {
    return switch (scenario) {
      _AssistantViewScenario.interaction => AssistantScenario.interactionCheck,
      _AssistantViewScenario.personalAnalysis =>
        AssistantScenario.personalAnalysis,
      _AssistantViewScenario.medicineInfo => AssistantScenario.medicineInfo,
    };
  }

  Future<void> _applyInsightSuggestion() async {
    final insight = _weeklyInsight;
    if (_isApplyingInsight ||
        insight == null ||
        insight.recommendedTime == null) {
      return;
    }

    final medicine = HiveService.getMedicine(insight.targetMedicineId);
    if (medicine == null) {
      return;
    }

    final updatedTimes = [...medicine.doseTimes];
    final targetIndex = updatedTimes.indexWhere(
      (value) => _doseSlotFromTime(_timeFromString(value)) == insight.slot,
    );
    if (targetIndex == -1) {
      return;
    }

    updatedTimes[targetIndex] = _timeToString(insight.recommendedTime!);
    final normalizedTimes = updatedTimes.toSet().toList()..sort();
    final updatedMedicine = medicine.copyWith(
      firstDoseTime: normalizedTimes.first,
      reminderTimes: normalizedTimes,
    );

    setState(() => _isApplyingInsight = true);
    await NotificationService.cancelMedicineNotifications(medicine);
    await HiveService.updateMedicine(updatedMedicine);
    await HiveService.clearGeminiManagedAlarmsForMedicine(medicine.id);
    await HiveService.setGeminiManagedAlarm(
      medicine.id,
      _timeToString(insight.recommendedTime!),
    );
    await NotificationService.scheduleMedicineNotifications(updatedMedicine);

    if (!mounted) {
      return;
    }

    setState(() => _isApplyingInsight = false);
    _refreshData(reseed: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${medicine.name} icin alarm ${_timeToString(insight.recommendedTime!)} saatine cekildi.',
          style: GoogleFonts.nunito(),
        ),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _setScenario(_AssistantViewScenario scenario) {
    if (_scenario == scenario) {
      return;
    }

    setState(() {
      _scenario = scenario;
      _quickPrompts = _quickPromptsForScenario(scenario);
      _messages = _seededMessages(scenario);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 160,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      appBar: AppBar(
        toolbarHeight: 78,
        titleSpacing: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _scenario == _AssistantViewScenario.personalAnalysis
                      ? 'Haftalik Analiz'
                      : 'AI Asistan',
                  style: GoogleFonts.nunito(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  AIService.assistantModelLabel,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _refreshData(reseed: false),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildScenarioStrip(isDark),
          _buildQuickPromptStrip(isDark),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                if (_scenario == _AssistantViewScenario.personalAnalysis) ...[
                  _buildWeeklyAnalysisCard(isDark),
                  const SizedBox(height: 12),
                ],
                ..._messages.map(
                  (message) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildMessageBubble(message, isDark),
                  ),
                ),
                if (_isSending) _buildTypingBubble(isDark),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildInputBar(isDark),
    );
  }

  Widget _buildScenarioStrip(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.backgroundSecondary,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
          ),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _AssistantViewScenario.values.map((scenario) {
          final isSelected = _scenario == scenario;
          return InkWell(
            onTap: () => _setScenario(scenario),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : (isDark ? AppTheme.darkCard : Colors.white),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : (isDark ? AppTheme.darkBorder : AppTheme.borderColor),
                ),
              ),
              child: Text(
                _viewScenarioLabel(scenario),
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white : AppTheme.primaryDark),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  String _viewScenarioLabel(_AssistantViewScenario scenario) {
    return switch (scenario) {
      _AssistantViewScenario.interaction => 'Etkilesim',
      _AssistantViewScenario.personalAnalysis => 'Kisisel analiz',
      _AssistantViewScenario.medicineInfo => 'Ilac bilgisi',
    };
  }

  Widget _buildQuickPromptStrip(bool isDark) {
    if (_quickPrompts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: isDark ? AppTheme.darkSurface : AppTheme.backgroundSecondary,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _quickPrompts.map((prompt) {
          return InkWell(
            onTap: () => _submitPrompt(prompt.prompt),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
                ),
              ),
              child: Text(
                prompt.label,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildWeeklyAnalysisCard(bool isDark) {
    final insight = _weeklyInsight;
    final complianceRate = _assistantContext?.complianceRate ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gemini haftalik rapor',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Son 7 gunluk uyum ve tekrar eden kacirma desenleri',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFC4B7E9)
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isDark ? AppTheme.darkSurface : AppTheme.backgroundSecondary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Genel uyum',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '%$complianceRate',
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: complianceRate / 100,
                    minHeight: 6,
                    backgroundColor:
                        isDark ? AppTheme.darkCard : AppTheme.borderColor,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ..._activeMedicines.map((medicine) {
            final rows = _weeklyRows[medicine.id] ?? const <_DayCompliance>[];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildWeeklyMedicineRow(
                medicine: medicine,
                rows: rows,
                isDark: isDark,
              ),
            );
          }),
          if (insight != null)
            _buildInsightCard(
              insight: insight,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildWeeklyMedicineRow({
    required Medicine medicine,
    required List<_DayCompliance> rows,
    required bool isDark,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            medicine.name,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Row(
          children: rows.map((row) {
            final color =
                switch ((row.hasDose, row.fullyTaken, row.hasMissed)) {
              (false, _, _) =>
                isDark ? AppTheme.darkBorder : AppTheme.borderColor,
              (true, true, _) => AppTheme.primaryColor,
              (true, false, true) => AppTheme.warningColor,
              _ => isDark ? const Color(0xFF6A5A95) : const Color(0xFFD7CCFF),
            };

            return Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required _WeeklyInsight insight,
    required bool isDark,
  }) {
    final recommendedTime = insight.recommendedTime == null
        ? null
        : _timeToString(insight.recommendedTime!);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gemini tespiti',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF92400E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${insight.repeatedDaysLabel} ${_slotLabel(insight.slot)} dozlarini daha sik kaciriyorsun. ${recommendedTime == null ? 'Alarmi yeniden gozden gecirelim mi?' : 'Alarmi $recommendedTime saatine cekeyim mi?'}',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.5,
              color: const Color(0xFF78350F),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton(
                onPressed: _isApplyingInsight ? null : _applyInsightSuggestion,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  minimumSize: const Size(0, 38),
                ),
                child: _isApplyingInsight
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        recommendedTime == null ? 'Tamam' : 'Evet, ayarla',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                      ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _weeklyInsight = null;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF92400E),
                  side: const BorderSide(color: Color(0xFFFDE68A)),
                  backgroundColor: Colors.white,
                ),
                child: Text(
                  'Hayir',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _slotLabel(_DoseSlot slot) {
    return switch (slot) {
      _DoseSlot.morning => 'sabah',
      _DoseSlot.noon => 'ogle',
      _DoseSlot.evening => 'aksam',
    };
  }

  Widget _buildMessageBubble(_AssistantMessage message, bool isDark) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(
            message.text,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.45,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'Gemini',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (message.response == null)
              Text(
                message.text,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              )
            else
              _buildResponseCard(message.response!, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseCard(AssistantStructuredResponse response, bool isDark) {
    return switch (response.type) {
      AssistantResponseType.safe => _buildTypedResponseCard(
          response: response,
          isDark: isDark,
          background: const Color(0xFFD1FAE5),
          border: const Color(0xFF6EE7B7),
          titleColor: const Color(0xFF065F46),
          bodyColor: const Color(0xFF064E3B),
        ),
      AssistantResponseType.warning => _buildTypedResponseCard(
          response: response,
          isDark: isDark,
          background: const Color(0xFFFEF3C7),
          border: const Color(0xFFFDE68A),
          titleColor: const Color(0xFF92400E),
          bodyColor: const Color(0xFF78350F),
        ),
      AssistantResponseType.danger => _buildTypedResponseCard(
          response: response,
          isDark: isDark,
          background: const Color(0xFFFEE2E2),
          border: const Color(0xFFFCA5A5),
          titleColor: const Color(0xFF991B1B),
          bodyColor: const Color(0xFF7F1D1D),
        ),
      AssistantResponseType.info => _buildTypedResponseCard(
          response: response,
          isDark: isDark,
          background: const Color(0xFFEDE9FE),
          border: const Color(0xFFDDD6FE),
          titleColor: const Color(0xFF5B21B6),
          bodyColor: const Color(0xFF4C1D95),
        ),
      AssistantResponseType.plain => _buildPlainResponseCard(
          response: response,
          isDark: isDark,
        ),
    };
  }

  Widget _buildTypedResponseCard({
    required AssistantStructuredResponse response,
    required bool isDark,
    required Color background,
    required Color border,
    required Color titleColor,
    required Color bodyColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (response.title.isNotEmpty)
            Text(
              response.title,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: titleColor,
              ),
            ),
          if (response.title.isNotEmpty) const SizedBox(height: 4),
          Text(
            response.summary,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.5,
              color: bodyColor,
            ),
          ),
          if (response.bullets.isNotEmpty) const SizedBox(height: 8),
          ...response.bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '- $bullet',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                  color: bodyColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            response.disclaimer,
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: bodyColor.withValues(alpha: 0.82),
            ),
          ),
          if (response.quickReplies.isNotEmpty) const SizedBox(height: 10),
          if (response.quickReplies.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: response.quickReplies.map((reply) {
                return InkWell(
                  onTap: () => _submitPrompt(reply),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      reply,
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
        ],
      ),
    );
  }

  Widget _buildPlainResponseCard({
    required AssistantStructuredResponse response,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          response.summary,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.45,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        if (response.bullets.isNotEmpty) const SizedBox(height: 8),
        ...response.bullets.map(
          (bullet) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '- $bullet',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.45,
                color:
                    isDark ? const Color(0xFFD6D0E8) : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          response.disclaimer,
          style: GoogleFonts.nunito(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFC4B7E9) : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTypingBubble(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (index) => Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withValues(
                  alpha: 0.45 + (index * 0.2),
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
            ),
          ),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: _toggleListening,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _isListening
                      ? AppTheme.errorColor.withValues(alpha: 0.15)
                      : AppTheme.accentColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none_rounded,
                  color: _isListening
                      ? AppTheme.errorColor
                      : AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppTheme.darkCard : AppTheme.backgroundSecondary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextField(
                  controller: _promptController,
                  minLines: 1,
                  maxLines: 3,
                  onSubmitted: (_) => _submitPrompt(),
                  decoration: const InputDecoration(
                    hintText: 'Soru sor...',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: _isSending ? null : _submitPrompt,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AssistantViewScenario {
  interaction,
  personalAnalysis,
  medicineInfo,
}

enum _DoseSlot {
  morning,
  noon,
  evening,
}

class _AssistantMessage {
  const _AssistantMessage({
    required this.isUser,
    required this.text,
    this.response,
  });

  final bool isUser;
  final String text;
  final AssistantStructuredResponse? response;

  factory _AssistantMessage.user(String text) {
    return _AssistantMessage(isUser: true, text: text);
  }

  factory _AssistantMessage.assistantText(String text) {
    return _AssistantMessage(isUser: false, text: text);
  }

  factory _AssistantMessage.assistantResponse(
    AssistantStructuredResponse response,
  ) {
    return _AssistantMessage(
      isUser: false,
      text: response.summary,
      response: response,
    );
  }
}

class _QuickPrompt {
  const _QuickPrompt({
    required this.label,
    required this.prompt,
  });

  final String label;
  final String prompt;
}

class _DayCompliance {
  const _DayCompliance({
    required this.date,
    required this.hasDose,
    required this.fullyTaken,
    required this.hasMissed,
  });

  final DateTime date;
  final bool hasDose;
  final bool fullyTaken;
  final bool hasMissed;
}

class _WeeklyInsight {
  const _WeeklyInsight({
    required this.targetMedicineId,
    required this.medicineName,
    required this.repeatedDaysLabel,
    required this.slot,
    required this.currentTime,
    required this.recommendedTime,
  });

  final String targetMedicineId;
  final String medicineName;
  final String repeatedDaysLabel;
  final _DoseSlot slot;
  final TimeOfDay? currentTime;
  final TimeOfDay? recommendedTime;
}
