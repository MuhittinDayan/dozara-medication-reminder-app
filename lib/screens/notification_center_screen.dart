import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/dose_log.dart';
import '../models/medicine.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

enum _NotificationTab { feed, alarms, lockscreen }

enum _DoseSlot { morning, noon, evening, night }

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen>
    with WidgetsBindingObserver {
  _NotificationTab _tab = _NotificationTab.feed;
  List<DoseLog> _todayLogs = [];
  List<DoseLog> _recentLogs = [];
  List<Medicine> _activeMedicines = [];
  List<Medicine> _lowStockMedicines = [];
  int _pendingNotificationCount = 0;
  bool _vibrationEnabled = true;
  bool _voiceReminderEnabled = true;
  bool _familyNotificationEnabled = false;
  bool _isLoading = true;
  bool _isPreviewSpeaking = false;
  bool _isApplyingSuggestion = false;
  Timer? _voicePreviewTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    _voicePreviewTimer?.cancel();
    NotificationService.stopReminderPreview();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    await HiveService.syncDoseLogs();
    final pending = await NotificationService.getPendingNotifications();
    if (!mounted) {
      return;
    }

    setState(() {
      _todayLogs = HiveService.getTodayDoseLogs();
      _recentLogs = HiveService.getRecentDoseLogs(days: 21);
      _activeMedicines = HiveService.getActiveMedicines();
      _lowStockMedicines = HiveService.getLowStockMedicines();
      _pendingNotificationCount = pending.length;
      _vibrationEnabled = HiveService.getNotificationVibrationEnabled();
      _voiceReminderEnabled = HiveService.getVoiceReminderEnabled();
      _familyNotificationEnabled = HiveService.getFamilyNotificationEnabled();
      _isLoading = false;
    });
  }

  List<DoseLog> get _actionableLogs {
    final now = DateTime.now();
    final items = _todayLogs
        .where(
          (log) =>
              (log.status == DoseStatus.pending ||
                  log.status == DoseStatus.snoozed) &&
              log.scheduledTime.isBefore(now.add(const Duration(hours: 2))),
        )
        .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return items;
  }

  List<DoseLog> get _completedLogs {
    final items = _todayLogs
        .where((log) => log.status == DoseStatus.taken)
        .toList()
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
    return items;
  }

  List<_AlarmEntry> get _alarmEntries {
    final entries = <_AlarmEntry>[];

    for (final medicine in _activeMedicines) {
      for (final time in medicine.doseTimes) {
        entries.add(
          _AlarmEntry(
            medicine: medicine,
            time: time,
            isEnabled: HiveService.isAlarmEnabled(medicine.id, time),
            isGeminiManaged:
                HiveService.isGeminiManagedAlarm(medicine.id, time),
          ),
        );
      }
    }

    entries.sort((a, b) => a.minutes.compareTo(b.minutes));
    return entries;
  }

  _GeminiSuggestion? get _geminiSuggestion {
    final now = DateTime.now();
    final patterns = <String, _MissPattern>{};

    for (final log in _recentLogs) {
      if (log.scheduledTime.isAfter(now)) {
        continue;
      }

      final medicine = HiveService.getMedicine(log.medicineId);
      if (medicine == null) {
        continue;
      }

      final time = _timeString(log.scheduledTime);
      final slot = _doseSlotFromTime(TimeOfDay.fromDateTime(log.scheduledTime));
      final key = '${log.medicineId}|${log.scheduledTime.weekday}|$slot|$time';
      final current = patterns[key] ??
          _MissPattern(
            medicine: medicine,
            weekday: log.scheduledTime.weekday,
            time: time,
            slot: slot,
          );

      current.total++;
      if (log.status == DoseStatus.missed || log.status == DoseStatus.pending) {
        current.missed++;
      }
      patterns[key] = current;
    }

    final ranked = patterns.values.where((pattern) {
      if (pattern.total < 2 || pattern.missed < 2) {
        return false;
      }
      return pattern.missed / pattern.total >= 0.5;
    }).toList()
      ..sort((a, b) {
        final rateCompare = b.rate.compareTo(a.rate);
        if (rateCompare != 0) {
          return rateCompare;
        }
        return b.missed.compareTo(a.missed);
      });

    if (ranked.isEmpty) {
      return null;
    }

    final pattern = ranked.first;
    final currentTime = _timeFromString(pattern.time);
    final recommended = _shiftTime(currentTime, 30);
    return _GeminiSuggestion(
      medicine: pattern.medicine,
      weekday: pattern.weekday,
      slot: pattern.slot,
      currentTime: currentTime,
      recommendedTime: recommended,
      summary:
          '${_weekdayLongLabel(pattern.weekday)} ${_slotLabel(pattern.slot).toLowerCase()} dozlarını son 3 haftada ${pattern.missed} kez kaçırdın.',
    );
  }

  Future<void> _markAsTaken(DoseLog dose) async {
    await HiveService.markDoseAsTaken(dose.id);
    await _loadData();
    if (!mounted) {
      return;
    }
    _showSnack('Doz alindi olarak isaretlendi.', AppTheme.takenColor);
  }

  Future<void> _snoozeDose(DoseLog dose) async {
    final snoozedLog = await HiveService.snoozeDose(dose.id);
    if (snoozedLog != null) {
      await NotificationService.scheduleDoseLogNotifications(snoozedLog);
    }
    await _loadData();
    if (!mounted) {
      return;
    }
    _showSnack('Doz 15 dakika ertelendi.', AppTheme.warningColor);
  }

  Future<void> _skipDose(DoseLog dose) async {
    await HiveService.markDoseAsMissed(dose.id);
    await _loadData();
    if (!mounted) {
      return;
    }
    _showSnack('Doz atlandi olarak isaretlendi.', AppTheme.errorColor);
  }

  Future<void> _toggleAlarm(_AlarmEntry entry, bool value) async {
    await HiveService.setAlarmEnabled(entry.medicine.id, entry.time, value);
    await NotificationService.cancelMedicineNotifications(entry.medicine);
    await NotificationService.scheduleMedicineNotifications(entry.medicine);
    await _loadData();

    if (!mounted) {
      return;
    }

    _showSnack(
      value
          ? '${entry.medicine.name} ${entry.time} alarmı açıldı.'
          : '${entry.medicine.name} ${entry.time} alarmı kapatıldı.',
      value ? AppTheme.primaryColor : AppTheme.textSecondary,
    );
  }

  Future<void> _setVibration(bool value) async {
    await HiveService.setNotificationVibrationEnabled(value);
    await NotificationService.rescheduleAllNotifications();
    await _loadData();
  }

  Future<void> _setVoiceReminder(bool value) async {
    await HiveService.setVoiceReminderEnabled(value);
    if (!value) {
      await NotificationService.stopReminderPreview();
      _voicePreviewTimer?.cancel();
      if (mounted) {
        setState(() => _isPreviewSpeaking = false);
      }
    }
    await _loadData();
  }

  Future<void> _setFamilyNotification(bool value) async {
    await HiveService.setFamilyNotificationEnabled(value);
    await _loadData();
  }

  Future<void> _playVoicePreview() async {
    final sampleEntry = _alarmEntries.isNotEmpty ? _alarmEntries.first : null;
    final sampleMedicine = sampleEntry?.medicine ??
        (_activeMedicines.isNotEmpty ? _activeMedicines.first : null);
    if (sampleMedicine == null) {
      return;
    }

    _voicePreviewTimer?.cancel();
    await NotificationService.stopReminderPreview();

    if (mounted) {
      setState(() => _isPreviewSpeaking = true);
    }

    await NotificationService.speakReminderPreview(
      sampleMedicine,
      doseLabel: sampleEntry == null
          ? 'İlaç'
          : _slotLabel(_doseSlotFromString(sampleEntry.time)),
      force: true,
    );

    _voicePreviewTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _isPreviewSpeaking = false);
      }
    });
  }

  Future<void> _applyGeminiSuggestion(_GeminiSuggestion suggestion) async {
    if (_isApplyingSuggestion) {
      return;
    }

    final medicine = suggestion.medicine;
    final updatedTimes = [...medicine.doseTimes];
    final slotIndex = updatedTimes.indexWhere(
      (time) => _doseSlotFromString(time) == suggestion.slot,
    );
    if (slotIndex == -1) {
      return;
    }

    updatedTimes[slotIndex] = _timeOfDayString(suggestion.recommendedTime);
    final normalizedTimes = updatedTimes.toSet().toList()..sort();
    final updatedMedicine = medicine.copyWith(
      firstDoseTime: normalizedTimes.first,
      reminderTimes: normalizedTimes,
    );

    setState(() => _isApplyingSuggestion = true);
    await NotificationService.cancelMedicineNotifications(medicine);
    await HiveService.updateMedicine(updatedMedicine);
    await HiveService.clearGeminiManagedAlarmsForMedicine(medicine.id);
    await HiveService.setGeminiManagedAlarm(
      medicine.id,
      _timeOfDayString(suggestion.recommendedTime),
    );
    await NotificationService.scheduleMedicineNotifications(updatedMedicine);

    if (!mounted) {
      return;
    }

    setState(() => _isApplyingSuggestion = false);
    await _loadData();
    if (!mounted) {
      return;
    }

    _showSnack(
      '${medicine.name} alarmı ${_timeOfDayString(suggestion.recommendedTime)} saatine çekildi.',
      AppTheme.primaryColor,
    );
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.nunito()),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      appBar: AppBar(
        toolbarHeight: 74,
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bildirimler',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            Text(
              'Aktif alarm, akış ve kilit ekranı deneyimini yönet.',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.84),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: () async {
                await NotificationService.showTestNotification();
                if (!mounted) {
                  return;
                }
                _showSnack('Test bildirimi gönderildi.', AppTheme.primaryColor);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.14),
              ),
              child: Text(
                'Test Et',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              color: AppTheme.primaryLight,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _buildTabSelector(isDark),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppTheme.primaryColor,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        children: [
                          _buildTopSummary(isDark),
                          const SizedBox(height: 16),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            child: switch (_tab) {
                              _NotificationTab.feed => _buildFeedTab(isDark),
                              _NotificationTab.alarms => _buildAlarmTab(isDark),
                              _NotificationTab.lockscreen =>
                                _buildLockScreenTab(),
                            },
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabChip(
              label: 'Akış',
              selected: _tab == _NotificationTab.feed,
              onTap: () => setState(() => _tab = _NotificationTab.feed),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildTabChip(
              label: 'Alarmlar',
              selected: _tab == _NotificationTab.alarms,
              onTap: () => setState(() => _tab = _NotificationTab.alarms),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildTabChip(
              label: 'Kilit Ekranı',
              selected: _tab == _NotificationTab.lockscreen,
              onTap: () => setState(() => _tab = _NotificationTab.lockscreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? AppTheme.primaryColor : Colors.white,
          ),
        ),
      ),
    );
  }

  List<BoxShadow> _premiumShadow(bool isDark, [Color? color]) {
    return [
      BoxShadow(
        color: (color ?? AppTheme.primaryColor)
            .withValues(alpha: isDark ? 0.14 : 0.08),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
    ];
  }

  Widget _buildTopSummary(bool isDark) {
    final activeCount = _alarmEntries.where((entry) => entry.isEnabled).length;
    final nextAlarm = _nextAlarmEntry();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white24,
        ),
        boxShadow: _premiumShadow(isDark, AppTheme.primaryColor),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aktif Hatırlatıcılar',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.76),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$activeCount alarm açık',
                  style: GoogleFonts.nunito(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Planlı bildirim: $_pendingNotificationCount',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.84),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 92,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              children: [
                Text(
                  nextAlarm?.time ?? '--:--',
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nextAlarm == null ? 'Sonraki yok' : nextAlarm.medicine.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedTab(bool isDark) {
    final suggestion = _geminiSuggestion;
    return Column(
      key: const ValueKey('feed'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
            'Şimdi · ${DateFormat('HH:mm').format(DateTime.now())}'),
        const SizedBox(height: 10),
        if (_actionableLogs.isEmpty)
          _buildEmptyCard(
            isDark,
            'Şu an aksiyon bekleyen doz yok. Bir sonraki alarm geldiğinde burada belirecek.',
            icon: Icons.notifications_paused_rounded,
            title: 'Aksiyon bekleyen doz yok',
          )
        else
          ..._actionableLogs.map((dose) => _buildActionableCard(dose, isDark)),
        const SizedBox(height: 18),
        _buildSectionLabel('Bugün · Tamamlandı'),
        const SizedBox(height: 10),
        if (_completedLogs.isEmpty)
          _buildEmptyCard(
            isDark,
            'Bugün tamamlanan doz henüz görünmüyor.',
            icon: Icons.check_circle_outline_rounded,
            title: 'Henüz tamamlanan doz yok',
          )
        else
          ..._completedLogs
              .take(4)
              .map((dose) => _buildCompletedCard(dose, isDark)),
        if (_lowStockMedicines.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildSectionLabel('Stok Uyarısı'),
          const SizedBox(height: 10),
          ..._lowStockMedicines
              .map((medicine) => _buildStockCard(medicine, isDark)),
        ],
        if (suggestion != null) ...[
          const SizedBox(height: 18),
          _buildGeminiCard(suggestion),
        ],
      ],
    );
  }

  Widget _buildAlarmTab(bool isDark) {
    final entries = _alarmEntries;
    return Column(
      key: const ValueKey('alarms'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entries.isEmpty)
          _buildEmptyCard(
            isDark,
            'Alarm gösterebilmek için önce aktif bir ilaç eklenmeli.',
            icon: Icons.alarm_add_rounded,
            title: 'Aktif alarm yok',
          )
        else
          ...entries.map((entry) => _buildAlarmRow(entry, isDark)),
        const SizedBox(height: 18),
        _buildSectionLabel('Bildirim Ayarları'),
        const SizedBox(height: 10),
        _buildSettingsCard(isDark),
      ],
    );
  }

  Widget _buildLockScreenTab() {
    final sampleDose = _actionableLogs.isNotEmpty
        ? _actionableLogs.first
        : (_todayLogs.isNotEmpty ? _todayLogs.first : null);
    final sampleMedicine = sampleDose == null
        ? (_activeMedicines.isNotEmpty ? _activeMedicines.first : null)
        : HiveService.getMedicine(sampleDose.medicineId);
    final now = DateTime.now();
    final title = sampleMedicine == null
        ? 'Hatırlatıcı'
        : '${sampleMedicine.name} · ${_slotLabel(_doseSlotFromTime(TimeOfDay.fromDateTime(sampleDose?.scheduledTime ?? now)))}';

    return Container(
      key: const ValueKey('lockscreen'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0A2E), Color(0xFF2D1F4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  DateFormat('HH:mm').format(now),
                  style: GoogleFonts.nunito(
                    fontSize: 34,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                  ),
                ),
                Text(
                  DateFormat('EEEE, d MMMM', 'tr_TR').format(now),
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.medication_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MediTrack',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'şimdi',
                          style: GoogleFonts.nunito(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.54),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Uygulamayı açmadan hızlıca Aldım, Ertele ya da Atla yanıtı verilebilir.',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.74),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildLockAction('Aldım', const Color(0xFF10B981))),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildLockAction('Ertele', const Color(0xFFF59E0B))),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLockAction(
                  'Atla',
                  Colors.white.withValues(alpha: 0.16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGlassCard(
            child: Row(
              children: [
                const Icon(Icons.volume_up_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sesli Hatırlatma',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _voiceReminderEnabled
                            ? '"İlacınızı almayı unutmayın."'
                            : 'Şu an kapalı, ama önizleme her zaman dinlenebilir.',
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.66),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _buildWaveBars(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _playVoicePreview,
              icon: Icon(
                _isPreviewSpeaking
                    ? Icons.graphic_eq_rounded
                    : Icons.play_arrow,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
              ),
              label: Text(
                _isPreviewSpeaking ? 'Ses Caliyor' : 'Sesli Onizleme',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          if (_lowStockMedicines.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildGlassCard(
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_lowStockMedicines.first.name} stogu azaliyor — ${_lowStockMedicines.first.stockCount ?? 0} adet kaldi',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionableCard(DoseLog dose, bool isDark) {
    final medicine = HiveService.getMedicine(dose.medicineId);
    if (medicine == null) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final isUrgent =
        dose.scheduledTime.isBefore(now.subtract(const Duration(minutes: 10)));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUrgent
              ? AppTheme.errorColor
              : (isDark ? AppTheme.darkBorder : AppTheme.borderColor),
          width: isUrgent ? 1.5 : 1,
        ),
        boxShadow: _premiumShadow(
          isDark,
          isUrgent ? AppTheme.errorColor : AppTheme.primaryColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                      (isUrgent ? AppTheme.errorColor : AppTheme.primaryColor)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(medicine.formEmoji,
                    style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${medicine.name} · ${_slotLabel(_doseSlotFromTime(TimeOfDay.fromDateTime(dose.scheduledTime)))}',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isUrgent
                            ? const Color(0xFF991B1B)
                            : (isDark ? Colors.white : AppTheme.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${DateFormat('HH:mm').format(dose.scheduledTime)} · Henüz onaylanmadı',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFD6D0E8)
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _markAsTaken(dose),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: Text(
                    'Aldım',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => _snoozeDose(dose),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF3C7),
                    foregroundColor: const Color(0xFF92400E),
                  ),
                  child: Text(
                    '15 dk',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _skipDose(dose),
                  child: Text(
                    'Atla',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(DoseLog dose, bool isDark) {
    final medicine = HiveService.getMedicine(dose.medicineId);
    if (medicine == null) {
      return const SizedBox.shrink();
    }

    return Opacity(
      opacity: 0.7,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
          ),
          boxShadow: _premiumShadow(isDark, AppTheme.takenColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF065F46),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.name,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('HH:mm').format(dose.actionTime ?? dose.scheduledTime)} · Alındı olarak işaretlendi',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFD6D0E8)
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockCard(Medicine medicine, bool isDark) {
    final remaining = medicine.stockCount ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.warningColor),
        boxShadow: _premiumShadow(isDark, AppTheme.warningColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Color(0xFF92400E),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${medicine.name} stoku azalıyor',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$remaining adet kaldı · Yaklaşık $remaining günlük stok',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFD6D0E8)
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              minimumSize: const Size(0, 36),
            ),
            child: Text(
              'Eczane',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeminiCard(_GeminiSuggestion suggestion) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: _premiumShadow(false, AppTheme.primaryColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                'Gemini Önerisi',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            suggestion.summary,
            style: GoogleFonts.nunito(
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${suggestion.medicine.name} alarmını ${_timeOfDayString(suggestion.recommendedTime)} saatine taşıyayım mı?',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: _isApplyingSuggestion
                    ? null
                    : () => _applyGeminiSuggestion(suggestion),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryColor,
                  minimumSize: const Size(0, 40),
                ),
                child: _isApplyingSuggestion
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Evet',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
                      ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => setState(() {}),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                ),
                child: Text(
                  'Hayır',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmRow(_AlarmEntry entry, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
        boxShadow: _premiumShadow(isDark),
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: entry.isEnabled
                  ? AppTheme.accentColor
                  : Colors.grey.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              entry.time,
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: entry.isEnabled
                    ? AppTheme.primaryDark
                    : AppTheme.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _slotLabel(_doseSlotFromString(entry.time)),
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.medicine.name} · ${entry.medicine.scheduleDescription}',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFD6D0E8)
                        : AppTheme.textSecondary,
                  ),
                ),
                if (entry.isGeminiManaged) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Gemini tarafından ayarlandı',
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: entry.isEnabled,
            activeTrackColor: AppTheme.primaryColor,
            onChanged: (value) => _toggleAlarm(entry, value),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
        boxShadow: _premiumShadow(isDark),
      ),
      child: Column(
        children: [
          _buildSettingTile(
            title: 'Titreşim',
            subtitle: 'Sessiz modda da çalışsın',
            value: _vibrationEnabled,
            onChanged: _setVibration,
            showDivider: true,
          ),
          _buildSettingTile(
            title: 'Sesli Hatırlatma',
            subtitle: 'Türkçe ses bildirimi',
            value: _voiceReminderEnabled,
            onChanged: _setVoiceReminder,
            trailing: IconButton(
              onPressed: _playVoicePreview,
              icon: Icon(
                _isPreviewSpeaking
                    ? Icons.graphic_eq_rounded
                    : Icons.play_circle_fill_rounded,
                color: AppTheme.primaryColor,
              ),
            ),
            showDivider: true,
          ),
          _buildSettingTile(
            title: 'Aile Bildirimi',
            subtitle: 'Doz alındığında ailem bilgilensin',
            value: _familyNotificationEnabled,
            onChanged: _setFamilyNotification,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showDivider = false,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(
                bottom: BorderSide(color: AppTheme.borderColor, width: 0.8),
              )
            : null,
      ),
      child: ListTile(
        title: Text(
          title,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null) trailing,
            Switch.adaptive(
              value: value,
              activeTrackColor: AppTheme.primaryColor,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildLockAction(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildWaveBars() {
    final heights = _isPreviewSpeaking
        ? const [6.0, 14.0, 10.0, 18.0, 8.0, 14.0, 6.0]
        : const [6.0, 8.0, 6.0, 10.0, 6.0, 8.0, 6.0];

    return Row(
      children: heights
          .map(
            (height) => AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(
    bool isDark,
    String message, {
    required IconData icon,
    required String title,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppTheme.darkBorder
              : AppTheme.primaryColor.withValues(alpha: 0.12),
        ),
        boxShadow: _premiumShadow(isDark),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFD6D0E8)
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _AlarmEntry? _nextAlarmEntry() {
    if (_alarmEntries.isEmpty) {
      return null;
    }

    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    final enabledEntries = _alarmEntries
        .where((entry) => entry.isEnabled)
        .toList()
      ..sort((a, b) => a.minutes.compareTo(b.minutes));
    if (enabledEntries.isEmpty) {
      return null;
    }

    for (final entry in enabledEntries) {
      if (entry.minutes >= nowMinutes) {
        return entry;
      }
    }
    return enabledEntries.first;
  }

  _DoseSlot _doseSlotFromString(String time) {
    return _doseSlotFromTime(_timeFromString(time));
  }

  _DoseSlot _doseSlotFromTime(TimeOfDay time) {
    final minutes = time.hour * 60 + time.minute;
    if (minutes < 11 * 60) {
      return _DoseSlot.morning;
    }
    if (minutes < 16 * 60) {
      return _DoseSlot.noon;
    }
    if (minutes < 21 * 60) {
      return _DoseSlot.evening;
    }
    return _DoseSlot.night;
  }

  String _slotLabel(_DoseSlot slot) {
    return switch (slot) {
      _DoseSlot.morning => 'Sabah Dozu',
      _DoseSlot.noon => 'Ogle Dozu',
      _DoseSlot.evening => 'Aksam Dozu',
      _DoseSlot.night => 'Gece Dozu',
    };
  }

  String _weekdayLongLabel(int weekday) {
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
        return 'Bugün';
    }
  }

  TimeOfDay _timeFromString(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.isEmpty ? '8' : parts.first) ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  String _timeString(DateTime value) => DateFormat('HH:mm').format(value);

  String _timeOfDayString(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeOfDay _shiftTime(TimeOfDay value, int minutes) {
    final total = value.hour * 60 + value.minute + minutes;
    final normalized = ((total % (24 * 60)) + (24 * 60)) % (24 * 60);
    return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
  }
}

class _AlarmEntry {
  const _AlarmEntry({
    required this.medicine,
    required this.time,
    required this.isEnabled,
    required this.isGeminiManaged,
  });

  final Medicine medicine;
  final String time;
  final bool isEnabled;
  final bool isGeminiManaged;

  int get minutes {
    final parts = time.split(':');
    final hour = int.tryParse(parts.isEmpty ? '0' : parts.first) ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return hour * 60 + minute;
  }
}

class _MissPattern {
  _MissPattern({
    required this.medicine,
    required this.weekday,
    required this.time,
    required this.slot,
  });

  final Medicine medicine;
  final int weekday;
  final String time;
  final _DoseSlot slot;
  int total = 0;
  int missed = 0;

  double get rate => total == 0 ? 0 : missed / total;
}

class _GeminiSuggestion {
  const _GeminiSuggestion({
    required this.medicine,
    required this.weekday,
    required this.slot,
    required this.currentTime,
    required this.recommendedTime,
    required this.summary,
  });

  final Medicine medicine;
  final int weekday;
  final _DoseSlot slot;
  final TimeOfDay currentTime;
  final TimeOfDay recommendedTime;
  final String summary;
}
