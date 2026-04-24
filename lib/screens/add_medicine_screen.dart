import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/medicine.dart';
import '../services/ai_service.dart';
import '../services/dose_calculator.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({
    super.key,
    this.initialMedicine,
  });

  final Medicine? initialMedicine;

  bool get isEditing => initialMedicine != null;

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _totalDaysController = TextEditingController();
  final _stockController = TextEditingController();
  final _noteController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  static const _uuid = Uuid();

  int _dailyFrequency = 1;
  List<TimeOfDay> _reminderTimes = const [TimeOfDay(hour: 8, minute: 0)];
  Color _selectedColor = AppTheme.medicineColors.first;
  MedicineForm _selectedForm = MedicineForm.pill;
  MedicineScheduleType _selectedScheduleType = MedicineScheduleType.daily;
  final Set<int> _selectedWeekdays = {DateTime.now().weekday};
  int _intervalDays = 2;
  int _stockCount = 30;
  int _lowStockThreshold = 7;
  bool _stockTrackingEnabled = true;
  bool _withFood = false;
  bool _isScanning = false;

  TimeOfDay get _firstDoseTime => _reminderTimes.isEmpty
      ? const TimeOfDay(hour: 8, minute: 0)
      : _reminderTimes.first;

  set _firstDoseTime(TimeOfDay value) {
    if (_reminderTimes.isEmpty) {
      _reminderTimes = [value];
    } else {
      _reminderTimes[0] = value;
    }
    _reminderTimes.sort(_compareTimes);
  }

  @override
  void initState() {
    super.initState();
    _hydrateInitialMedicine();
    if (!widget.isEditing) {
      _setDailyFrequency(_dailyFrequency);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _totalDaysController.dispose();
    _stockController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _hydrateInitialMedicine() {
    final medicine = widget.initialMedicine;
    if (medicine == null) {
      return;
    }

    _nameController.text = medicine.name;
    _dosageController.text = medicine.dosage ?? '';
    _totalDaysController.text = medicine.totalDays.toString();
    _noteController.text = medicine.note ?? '';

    _dailyFrequency = medicine.dailyFrequency;
    _reminderTimes = medicine.doseTimes.map(_timeFromString).toList();
    if (_reminderTimes.isEmpty) {
      _reminderTimes = [_timeFromString(medicine.firstDoseTime)];
    }
    _dailyFrequency = _reminderTimes.length;
    _selectedColor = Color(medicine.colorValue);
    _selectedForm = medicine.form;
    _selectedScheduleType = medicine.scheduleTypeValue;
    _selectedWeekdays
      ..clear()
      ..addAll(medicine.selectedWeekdaysValue.isEmpty
          ? {medicine.startDate.weekday}
          : medicine.selectedWeekdaysValue);
    _intervalDays = medicine.intervalDaysValue;
    _stockTrackingEnabled = medicine.lowStockThreshold != null;
    _stockCount = medicine.stockCount ?? 30;
    _lowStockThreshold = medicine.lowStockThreshold ?? 7;
    _withFood = medicine.withFood;
  }

  TimeOfDay _timeFromString(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return const TimeOfDay(hour: 8, minute: 0);
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return const TimeOfDay(hour: 8, minute: 0);
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  String _timeToString(TimeOfDay value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  List<TimeOfDay> _defaultReminderTimesForFrequency(int frequency) {
    const presets = <int, List<TimeOfDay>>{
      1: [TimeOfDay(hour: 8, minute: 0)],
      2: [
        TimeOfDay(hour: 8, minute: 0),
        TimeOfDay(hour: 20, minute: 0),
      ],
      3: [
        TimeOfDay(hour: 8, minute: 0),
        TimeOfDay(hour: 14, minute: 0),
        TimeOfDay(hour: 20, minute: 0),
      ],
      4: [
        TimeOfDay(hour: 8, minute: 0),
        TimeOfDay(hour: 12, minute: 0),
        TimeOfDay(hour: 16, minute: 0),
        TimeOfDay(hour: 20, minute: 0),
      ],
      6: [
        TimeOfDay(hour: 6, minute: 0),
        TimeOfDay(hour: 10, minute: 0),
        TimeOfDay(hour: 14, minute: 0),
        TimeOfDay(hour: 18, minute: 0),
        TimeOfDay(hour: 22, minute: 0),
        TimeOfDay(hour: 23, minute: 30),
      ],
    };

    return [...(presets[frequency] ?? presets[1]!)];
  }

  int _compareTimes(TimeOfDay a, TimeOfDay b) {
    final aTotal = (a.hour * 60) + a.minute;
    final bTotal = (b.hour * 60) + b.minute;
    return aTotal.compareTo(bTotal);
  }

  void _setDailyFrequency(int frequency) {
    final safeFrequency = frequency.clamp(1, 6);
    final defaults = _defaultReminderTimesForFrequency(safeFrequency);
    final current = [..._reminderTimes]..sort(_compareTimes);
    final updated = <TimeOfDay>[];

    for (var index = 0; index < safeFrequency; index++) {
      if (index < current.length) {
        updated.add(current[index]);
      } else {
        updated.add(defaults[index]);
      }
    }

    updated.sort(_compareTimes);
    _dailyFrequency = safeFrequency;
    _reminderTimes = updated;
  }

  Future<void> _scanMedicine() async {
    final image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) {
      return;
    }

    setState(() {
      _isScanning = true;
    });

    try {
      final result = await AIService.analyzeMedicineImage(File(image.path));
      if (!mounted) {
        return;
      }

      if (result == null || !result.hasData) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tarama sonucunda doldurulacak veri bulunamadi.',
              style: GoogleFonts.nunito(),
            ),
          ),
        );
        return;
      }

      final shouldApply = await _showScanReviewSheet(result);
      if (!mounted || shouldApply != true) {
        return;
      }

      _applyScanResult(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tarama sonucu forma uygulandi.',
            style: GoogleFonts.nunito(),
          ),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tarama hatasi: $e', style: GoogleFonts.nunito()),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _applyScanResult(MedicineScanResult result) {
    final name = result['name']?.value.trim();
    final dose = result['dose']?.value.trim();
    final note = result['usageNotes']?.value.trim();
    final frequency = int.tryParse(result['frequency']?.value ?? '');
    final meal = result['meal']?.value.toLowerCase() ?? '';
    final form = result['form']?.value.toLowerCase() ?? '';
    final weekdays = _extractWeekdaysFromUsage(note ?? '');

    if (name != null && name.isNotEmpty) {
      _nameController.text = name;
    }
    if (dose != null && dose.isNotEmpty) {
      _dosageController.text = dose;
    }
    if (note != null && note.isNotEmpty) {
      _noteController.text = note;
    }

    setState(() {
      if (form.contains('hap')) {
        _selectedForm = MedicineForm.pill;
      } else if (form.contains('surup') || form.contains('şurup')) {
        _selectedForm = MedicineForm.syrup;
      } else if (form.contains('igne') || form.contains('iğne')) {
        _selectedForm = MedicineForm.injection;
      } else if (form.contains('damla')) {
        _selectedForm = MedicineForm.drop;
      } else if (form.contains('krem')) {
        _selectedForm = MedicineForm.cream;
      } else if (form.contains('sprey') || form.contains('inhaler')) {
        _selectedForm = MedicineForm.inhaler;
      }

      if (frequency != null && frequency > 0) {
        _setDailyFrequency(frequency);
      }

      if (meal.contains('tok')) {
        _withFood = true;
      } else if (meal.contains('aç') ||
          meal.contains('ac') ||
          meal.contains('farketmez')) {
        _withFood = false;
      }

      final usageLower = (note ?? '').toLowerCase();
      if (usageLower.contains('haftada bir')) {
        _selectedScheduleType = MedicineScheduleType.interval;
        _intervalDays = 7;
        _setDailyFrequency(1);
      } else if (usageLower.contains('ayda bir')) {
        _selectedScheduleType = MedicineScheduleType.interval;
        _intervalDays = 30;
        _setDailyFrequency(1);
      } else if (weekdays.isNotEmpty) {
        _selectedScheduleType = MedicineScheduleType.specificDays;
        _selectedWeekdays
          ..clear()
          ..addAll(weekdays);
      }
    });
  }

  Future<bool?> _showScanReviewSheet(MedicineScanResult result) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final fields = _scanReviewFields(result);

        return FractionallySizedBox(
          heightFactor: 0.9,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 46,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryLight,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
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
                                    color: Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'AI tarama sonucu hazir',
                                        style: GoogleFonts.nunito(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${fields.length} alan bulundu. Forma uygulamadan once kontrol edin.',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white
                                              .withValues(alpha: 0.84),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildScanSummaryChip(
                                  icon: Icons.document_scanner_rounded,
                                  label: 'OCR + AI inceleme',
                                ),
                                if (result['frequency'] != null)
                                  _buildScanSummaryChip(
                                    icon: Icons.schedule_rounded,
                                    label:
                                        '${result['frequency']!.value} kez/gun',
                                  ),
                                if (result['meal'] != null)
                                  _buildScanSummaryChip(
                                    icon: Icons.restaurant_rounded,
                                    label: result['meal']!.value,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Onerilen alanlar',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...fields.map(
                        (field) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildScanReviewField(
                            field: field,
                            isDark: isDark,
                          ),
                        ),
                      ),
                      if (result.ocrText.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'OCR onizleme',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkCard
                                : AppTheme.backgroundSecondary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? AppTheme.darkBorder
                                  : AppTheme.borderColor,
                            ),
                          ),
                          child: Text(
                            result.ocrText.trim(),
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFD6D0E8)
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color:
                            isDark ? AppTheme.darkBorder : AppTheme.borderColor,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          child: const Text('Vazgec'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(true),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Forma uygula'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_ScanReviewField> _scanReviewFields(MedicineScanResult result) {
    final entries = <(String, String, IconData)>[
      ('name', 'Ilac adi', Icons.medication_rounded),
      ('form', 'Form', Icons.category_rounded),
      ('dose', 'Doz', Icons.straighten_rounded),
      ('frequency', 'Gunluk tekrar', Icons.schedule_rounded),
      ('meal', 'Yemek bilgisi', Icons.restaurant_rounded),
      ('usageNotes', 'Kullanim notu', Icons.notes_rounded),
    ];

    return entries
        .where((entry) => result[entry.$1] != null)
        .map(
          (entry) => _ScanReviewField(
            label: entry.$2,
            icon: entry.$3,
            suggestion: result[entry.$1]!,
            value: _formatScanFieldValue(entry.$1, result[entry.$1]!.value),
          ),
        )
        .toList(growable: false);
  }

  String _formatScanFieldValue(String key, String value) {
    switch (key) {
      case 'form':
        return _localizedFormName(_formFromScanValue(value));
      case 'frequency':
        final frequency = int.tryParse(value.trim());
        return frequency == null ? value : '$frequency kez / gun';
      case 'meal':
        if (value.toLowerCase().contains('tok')) {
          return 'Tok karnina';
        }
        if (value.toLowerCase().contains('ac')) {
          return 'Ac karnina';
        }
        return value;
      default:
        return value;
    }
  }

  MedicineForm _formFromScanValue(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('hap') || lower.contains('tablet')) {
      return MedicineForm.pill;
    }
    if (lower.contains('surup') || lower.contains('şurup')) {
      return MedicineForm.syrup;
    }
    if (lower.contains('igne') || lower.contains('iğne')) {
      return MedicineForm.injection;
    }
    if (lower.contains('damla')) {
      return MedicineForm.drop;
    }
    if (lower.contains('krem') || lower.contains('merhem')) {
      return MedicineForm.cream;
    }
    if (lower.contains('sprey') || lower.contains('inhaler')) {
      return MedicineForm.inhaler;
    }
    return MedicineForm.pill;
  }

  Widget _buildScanSummaryChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanReviewField({
    required _ScanReviewField field,
    required bool isDark,
  }) {
    final (confidenceLabel, confidenceColor, confidenceBackground) =
        _scanConfidenceMeta(field.suggestion.confidence);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.accentColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              field.icon,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        field.label,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: confidenceBackground,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        confidenceLabel,
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: confidenceColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  field.value,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  field.suggestion.source,
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
    );
  }

  (String, Color, Color) _scanConfidenceMeta(ScanFieldConfidence confidence) {
    switch (confidence) {
      case ScanFieldConfidence.high:
        return (
          'Yuksek guven',
          const Color(0xFF065F46),
          const Color(0xFFD1FAE5),
        );
      case ScanFieldConfidence.medium:
        return (
          'Orta guven',
          const Color(0xFF1D4ED8),
          const Color(0xFFDBEAFE),
        );
      case ScanFieldConfidence.low:
        return (
          'Kontrol et',
          const Color(0xFF92400E),
          const Color(0xFFFEF3C7),
        );
    }
  }

  Set<int> _extractWeekdaysFromUsage(String usage) {
    final lower = usage.toLowerCase();
    final weekdays = <int>{};

    if (lower.contains('pazartesi') || lower.contains('pzt')) {
      weekdays.add(DateTime.monday);
    }
    if (lower.contains('sali') || lower.contains('sal')) {
      weekdays.add(DateTime.tuesday);
    }
    if (lower.contains('carsamba') || lower.contains('car')) {
      weekdays.add(DateTime.wednesday);
    }
    if (lower.contains('persembe') || lower.contains('per')) {
      weekdays.add(DateTime.thursday);
    }
    if (lower.contains('cuma') || lower.contains('cum')) {
      weekdays.add(DateTime.friday);
    }
    if (lower.contains('cumartesi') || lower.contains('cmt')) {
      weekdays.add(DateTime.saturday);
    }
    if (lower.contains('pazar') || lower.contains('paz')) {
      weekdays.add(DateTime.sunday);
    }

    return weekdays;
  }

  List<String> get _previewDoseTimes {
    final times = _reminderTimes.map(_timeToString).toList()..sort();
    return times;
  }

  List<(int, String)> get _weekdayOptions => const [
        (DateTime.monday, 'Pzt'),
        (DateTime.tuesday, 'Sal'),
        (DateTime.wednesday, 'Car'),
        (DateTime.thursday, 'Per'),
        (DateTime.friday, 'Cum'),
        (DateTime.saturday, 'Cmt'),
        (DateTime.sunday, 'Paz'),
      ];

  String get _activeProfileName {
    return HiveService.getActiveProfile().name;
  }

  int get _stockValue => int.tryParse(_stockController.text.trim()) ?? 0;

  void _changeStock(int delta) {
    final value = (_stockValue + delta).clamp(0, 9999);
    setState(() {
      _stockController.text = '$value';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      appBar: AppBar(
        toolbarHeight: 76,
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.isEditing ? 'İlacı Düzenle' : 'İlaç Ekle',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '$_activeProfileName profili',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actions: [
          _isScanning
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton.icon(
                    onPressed: _scanMedicine,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text(
                      'AI Tara',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _buildAiBanner(),
            const SizedBox(height: 14),
            _buildPremiumSection(
              isDark: isDark,
              icon: Icons.medication_rounded,
              title: 'İlaç Bilgisi',
              subtitle: 'İsim, form ve doz bilgisini belirle',
              children: [
                _fieldLabel('İlaç adı'),
                TextFormField(
                  controller: _nameController,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Örn: Metformin 500 mg',
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen ilaç adını girin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _fieldLabel('Form'),
                _buildFormSelector(isDark),
                const SizedBox(height: 14),
                _fieldLabel('Doz'),
                TextFormField(
                  controller: _dosageController,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Örn: 500 mg',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildPremiumSection(
              isDark: isDark,
              icon: Icons.notifications_active_rounded,
              title: 'Hatırlatma Planı',
              subtitle: 'Saatleri, tekrar düzenini ve plan tipini seç',
              children: [
                _fieldLabel('Hatırlatmalar'),
                _buildTimeChips(isDark),
                const SizedBox(height: 14),
                _fieldLabel('Gün İçindeki Tekrar'),
                _buildFrequencySelector(isDark),
                const SizedBox(height: 8),
                Text(
                  DoseCalculator.getIntervalDescription(_dailyFrequency),
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                _fieldLabel('Plan'),
                _buildScheduleTypeSelector(isDark),
                const SizedBox(height: 12),
                _buildScheduleSettings(isDark),
              ],
            ),
            const SizedBox(height: 14),
            _buildPremiumSection(
              isDark: isDark,
              icon: Icons.tune_rounded,
              title: 'Tercihler',
              subtitle: 'Tedavi süresi, yemek bilgisi, renk ve not',
              children: [
                _fieldLabel('Tedavi süresi'),
                TextFormField(
                  controller: _totalDaysController,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Örn: 30',
                    suffixText: 'gün',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen gün sayısı girin';
                    }
                    final days = int.tryParse(value.trim());
                    if (days == null || days <= 0) {
                      return 'Geçerli bir gün sayısı girin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _fieldLabel('Yemek bilgisi'),
                _buildToggleTile(
                  icon: Icons.restaurant_rounded,
                  title: 'Tok Karnına',
                  subtitle: 'Yemekten sonra alınacak',
                  value: _withFood,
                  onChanged: (value) => setState(() => _withFood = value),
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                _fieldLabel('Kart rengi'),
                _buildColorPicker(),
                const SizedBox(height: 14),
                _fieldLabel('Not'),
                TextFormField(
                  controller: _noteController,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Örn: Doktor tavsiyesi',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStockTrackingSection(isDark),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveCurrentMedicine,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                widget.isEditing
                    ? 'Değişiklikleri Kaydet'
                    : 'Kaydet ve Hatırlatıcı Kur',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reçete veya kutu fotoğrafı çek',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Gemini alanları otomatik doldurur',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _scanMedicine,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.camera_alt_rounded, size: 14),
            label: Text(
              'Tara',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumSection({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color:
                AppTheme.primaryColor.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
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
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isDark ? const Color(0xFFC4B7E9) : AppTheme.primaryDark,
        ),
      ),
    );
  }

  String _localizedFormEmoji(MedicineForm form) {
    switch (form) {
      case MedicineForm.pill:
        return '💊';
      case MedicineForm.syrup:
        return '🥤';
      case MedicineForm.injection:
        return '💉';
      case MedicineForm.drop:
        return '💧';
      case MedicineForm.cream:
        return '🧴';
      case MedicineForm.inhaler:
        return '💨';
    }
  }

  String _localizedFormName(MedicineForm form) {
    switch (form) {
      case MedicineForm.pill:
        return 'Tablet';
      case MedicineForm.syrup:
        return 'Şurup';
      case MedicineForm.injection:
        return 'İğne';
      case MedicineForm.drop:
        return 'Damla';
      case MedicineForm.cream:
        return 'Krem';
      case MedicineForm.inhaler:
        return 'İnhaler';
    }
  }

  Future<void> _editReminderTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTimes[index],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _reminderTimes[index] = picked;
        _reminderTimes.sort(_compareTimes);
      });
    }
  }

  Future<void> _saveCurrentMedicine() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedScheduleType == MedicineScheduleType.specificDays &&
        _selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lütfen en az bir gün seçin.',
            style: GoogleFonts.nunito(),
          ),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    final reminderTimes = _previewDoseTimes;
    final firstDoseTime = reminderTimes.isEmpty ? '08:00' : reminderTimes.first;
    final note = _noteController.text.trim();
    final dosage = _dosageController.text.trim();
    final totalDays = int.parse(_totalDaysController.text.trim());

    final medicine = Medicine(
      id: widget.initialMedicine?.id ?? _uuid.v4(),
      name: _nameController.text.trim(),
      dailyFrequency: reminderTimes.length,
      totalDays: totalDays,
      firstDoseTime: firstDoseTime,
      startDate: widget.initialMedicine?.startDate ?? DateTime.now(),
      stockCount: _stockTrackingEnabled ? _stockCount : 0,
      lowStockThreshold: _stockTrackingEnabled ? _lowStockThreshold : null,
      colorValue: _selectedColor.toARGB32(),
      form: _selectedForm,
      note: note.isEmpty ? null : note,
      withFood: _withFood,
      profileId: widget.initialMedicine?.profileId ??
          HiveService.getActiveProfile().id,
      dosage: dosage.isEmpty ? null : dosage,
      scheduleType: _selectedScheduleType,
      selectedWeekdays: _selectedWeekdays.toList()..sort(),
      intervalDays: _selectedScheduleType == MedicineScheduleType.interval
          ? _intervalDays
          : 1,
      reminderTimes: reminderTimes,
    );

    if (widget.isEditing) {
      await NotificationService.cancelMedicineNotifications(
        widget.initialMedicine!,
      );
      await HiveService.updateMedicine(medicine);
    } else {
      await HiveService.addMedicine(medicine);
    }

    await NotificationService.scheduleMedicineNotifications(medicine);

    if (mounted) {
      Navigator.pop(context, <String, dynamic>{
        'name': medicine.name,
        'isEditing': widget.isEditing,
      });
    }
  }

  Widget _buildTimeChips(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._reminderTimes.asMap().entries.map(
              (entry) => InkWell(
                onTap: () => _editReminderTime(entry.key),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isDark ? AppTheme.darkBorder : AppTheme.borderColor,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${entry.key + 1}. doz',
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            entry.key == 0
                                ? Icons.wb_sunny_rounded
                                : Icons.schedule_rounded,
                            size: 14,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _timeToString(entry.value),
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.accentColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Bir saate dokunup düzenleyin',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormSelector(bool isDark) {
    const forms = MedicineForm.values;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: forms.map((form) {
        final isSelected = _selectedForm == form;
        return InkWell(
          onTap: () => setState(() => _selectedForm = form),
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
                color:
                    isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
              ),
            ),
            child: Text(
              '${_localizedFormEmoji(form)} ${_localizedFormName(form)}',
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
      }).toList(),
    );
  }

  Widget _buildColorPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppTheme.medicineColors.map((color) {
        final isSelected = _selectedColor.toARGB32() == color.toARGB32();
        return GestureDetector(
          onTap: () => setState(() => _selectedColor = color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border:
                  isSelected ? Border.all(color: Colors.white, width: 3) : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.55),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFrequencySelector(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [1, 2, 3, 4, 6].map((freq) {
        final isSelected = _dailyFrequency == freq;
        return InkWell(
          onTap: () => setState(() => _setDailyFrequency(freq)),
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
                color:
                    isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
              ),
            ),
            child: Text(
              '$freq kez',
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
      }).toList(),
    );
  }

  Widget _buildScheduleTypeSelector(bool isDark) {
    final options = <(MedicineScheduleType, String)>[
      (MedicineScheduleType.daily, 'Her Gün'),
      (MedicineScheduleType.specificDays, 'Belirli Günler'),
      (MedicineScheduleType.interval, 'Aralıklı'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = _selectedScheduleType == option.$1;
        return InkWell(
          onTap: () => setState(() => _selectedScheduleType = option.$1),
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
                color:
                    isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
              ),
            ),
            child: Text(
              option.$2,
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
      }).toList(),
    );
  }

  Widget _buildScheduleSettings(bool isDark) {
    switch (_selectedScheduleType) {
      case MedicineScheduleType.daily:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.backgroundSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Text(
            'Hatırlatmalar her gün çalışır.',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryDark,
            ),
          ),
        );
      case MedicineScheduleType.specificDays:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _weekdayOptions.map((weekday) {
                final isSelected = _selectedWeekdays.contains(weekday.$1);
                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedWeekdays.remove(weekday.$1);
                      } else {
                        _selectedWeekdays.add(weekday.$1);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : (isDark ? AppTheme.darkCard : Colors.white),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.borderColor,
                      ),
                    ),
                    child: Text(
                      weekday.$2,
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
              }).toList(),
            ),
            const SizedBox(height: 10),
            Text(
              'Örn: Pazartesi, Çarşamba, Cuma',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        );
      case MedicineScheduleType.interval:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kaç günde bir hatırlatılsın?',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [2, 3, 7, 14, 30].map((days) {
                final isSelected = _intervalDays == days;
                return InkWell(
                  onTap: () => setState(() => _intervalDays = days),
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : (isDark ? AppTheme.darkCard : Colors.white),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.borderColor,
                      ),
                    ),
                    child: Text(
                      _intervalChipLabel(days),
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
              }).toList(),
            ),
          ],
        );
    }
  }

  String _intervalChipLabel(int days) {
    switch (days) {
      case 7:
        return 'Haftada bir';
      case 14:
        return '2 haftada bir';
      case 30:
        return 'Ayda bir';
      default:
        return '$days günde bir';
    }
  }

  Widget _buildStockTrackingSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color:
                AppTheme.primaryColor.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.inventory_2_rounded,
                  size: 18,
                  color: Color(0xFF7C3AED),
                ),
                const SizedBox(width: 6),
                Text(
                  'Stok Takibi',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _stockTrackingEnabled,
                  activeThumbColor: const Color(0xFF7C3AED),
                  onChanged: (v) => setState(() => _stockTrackingEnabled = v),
                ),
              ],
            ),
          ),
          if (_stockTrackingEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mevcut Stok',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() {
                            if (_stockCount > 1) {
                              _stockCount--;
                            }
                          }),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                            ),
                            child: const Icon(
                              Icons.remove_rounded,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '$_stockCount',
                                style: GoogleFonts.nunito(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1f1f1f),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                _localizedFormName(_selectedForm).toLowerCase(),
                                style: GoogleFonts.nunito(
                                  fontSize: 10,
                                  color: isDark
                                      ? const Color(0xFFC4B7E9)
                                      : Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _stockCount++),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: Color(0xFF7C3AED),
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Uyarı Eşiği',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [5, 7, 10, 14].map((days) {
                      final isSelected = _lowStockThreshold == days;
                      return GestureDetector(
                        onTap: () => setState(() => _lowStockThreshold = days),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF7C3AED)
                                : (isDark
                                    ? AppTheme.darkSurface
                                    : Colors.white),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF7C3AED)
                                  : const Color(0xFFDDD6FE),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$days gün kala',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF6D28D9),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: Color(0xFF7C3AED),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Stok $_lowStockThreshold güne düşünce bildirim alacaksın.',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: const Color(0xFF6D28D9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.accentColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: AppTheme.primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildStockStepper(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
      ),
      child: Row(
        children: [
          _buildStepperButton(
            icon: Icons.remove_rounded,
            onTap: () => _changeStock(-1),
          ),
          Expanded(
            child: Column(
              children: [
                TextFormField(
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Örn: 30',
                    hintStyle: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ),
                Text(
                  _localizedFormName(_selectedForm).toLowerCase(),
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _buildStepperButton(
            icon: Icons.add_rounded,
            onTap: () => _changeStock(1),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppTheme.accentColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: AppTheme.primaryColor),
      ),
    );
  }

  // ignore: unused_element
  String _formEmoji(MedicineForm form) {
    switch (form) {
      case MedicineForm.pill:
        return '💊';
      case MedicineForm.syrup:
        return '🥤';
      case MedicineForm.injection:
        return '💉';
      case MedicineForm.drop:
        return '💧';
      case MedicineForm.cream:
        return '🧴';
      case MedicineForm.inhaler:
        return '💨';
    }
  }

  // ignore: unused_element
  String _formShortName(MedicineForm form) {
    switch (form) {
      case MedicineForm.pill:
        return 'Tablet';
      case MedicineForm.syrup:
        return 'Surup';
      case MedicineForm.injection:
        return 'Igne';
      case MedicineForm.drop:
        return 'Damla';
      case MedicineForm.cream:
        return 'Krem';
      case MedicineForm.inhaler:
        return 'Inhaler';
    }
  }

  // ignore: unused_element
  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _firstDoseTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _firstDoseTime = picked;
      });
    }
  }

  // ignore: unused_element
  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedScheduleType == MedicineScheduleType.specificDays &&
        _selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lutfen en az bir gun secin.',
            style: GoogleFonts.nunito(),
          ),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    final firstDoseTime =
        '${_firstDoseTime.hour.toString().padLeft(2, '0')}:${_firstDoseTime.minute.toString().padLeft(2, '0')}';
    final note = _noteController.text.trim();
    final dosage = _dosageController.text.trim();
    final totalDays = int.parse(_totalDaysController.text.trim());

    final medicine = Medicine(
      id: widget.initialMedicine?.id ?? _uuid.v4(),
      name: _nameController.text.trim(),
      dailyFrequency: _dailyFrequency,
      totalDays: totalDays,
      firstDoseTime: firstDoseTime,
      startDate: widget.initialMedicine?.startDate ?? DateTime.now(),
      stockCount: _stockTrackingEnabled ? _stockCount : 0,
      lowStockThreshold: _stockTrackingEnabled ? _lowStockThreshold : null,
      colorValue: _selectedColor.toARGB32(),
      form: _selectedForm,
      note: note.isEmpty ? null : note,
      withFood: _withFood,
      profileId: widget.initialMedicine?.profileId ??
          HiveService.activeProfileId.value,
      dosage: dosage.isEmpty ? null : dosage,
      scheduleType: _selectedScheduleType,
      selectedWeekdays: _selectedWeekdays.toList()..sort(),
      intervalDays: _selectedScheduleType == MedicineScheduleType.interval
          ? _intervalDays
          : 1,
      reminderTimes: _previewDoseTimes,
    );

    if (widget.isEditing) {
      await NotificationService.cancelMedicineNotifications(
        widget.initialMedicine!,
      );
      await HiveService.updateMedicine(medicine);
    } else {
      await HiveService.addMedicine(medicine);
    }

    await NotificationService.scheduleMedicineNotifications(medicine);

    if (mounted) {
      Navigator.pop(context, <String, dynamic>{
        'name': medicine.name,
        'isEditing': widget.isEditing,
      });
    }
  }
}

class _ScanReviewField {
  const _ScanReviewField({
    required this.label,
    required this.icon,
    required this.suggestion,
    required this.value,
  });

  final String label;
  final IconData icon;
  final ScanFieldSuggestion suggestion;
  final String value;
}
