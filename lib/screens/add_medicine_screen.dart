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
import '../utils/medicine_form_helper.dart';
import '../widgets/add_medicine/ai_scan_banner.dart';
import '../widgets/add_medicine/color_picker.dart';
import '../widgets/add_medicine/form_section.dart';
import '../widgets/add_medicine/form_selector.dart';
import '../widgets/add_medicine/frequency_selector.dart';
import '../widgets/add_medicine/scan_review_sheet.dart';
import '../widgets/add_medicine/schedule_settings.dart';
import '../widgets/add_medicine/stock_tracking_section.dart';
import '../widgets/add_medicine/time_chips.dart';

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
    if (medicine == null) return;

    _nameController.text = medicine.name;
    _dosageController.text = medicine.dosage ?? '';
    _totalDaysController.text = medicine.totalDays.toString();
    _noteController.text = medicine.note ?? '';

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

  String _timeToString(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  int _compareTimes(TimeOfDay a, TimeOfDay b) {
    final aTotal = (a.hour * 60) + a.minute;
    final bTotal = (b.hour * 60) + b.minute;
    return aTotal.compareTo(bTotal);
  }

  void _setDailyFrequency(int frequency) {
    final safeFrequency = frequency.clamp(1, 6);
    const presets = <int, List<TimeOfDay>>{
      1: [TimeOfDay(hour: 8, minute: 0)],
      2: [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 20, minute: 0)],
      3: [
        TimeOfDay(hour: 8, minute: 0),
        TimeOfDay(hour: 14, minute: 0),
        TimeOfDay(hour: 20, minute: 0)
      ],
      4: [
        TimeOfDay(hour: 8, minute: 0),
        TimeOfDay(hour: 12, minute: 0),
        TimeOfDay(hour: 16, minute: 0),
        TimeOfDay(hour: 20, minute: 0)
      ],
      6: [
        TimeOfDay(hour: 6, minute: 0),
        TimeOfDay(hour: 10, minute: 0),
        TimeOfDay(hour: 14, minute: 0),
        TimeOfDay(hour: 18, minute: 0),
        TimeOfDay(hour: 22, minute: 0),
        TimeOfDay(hour: 23, minute: 30)
      ],
    };

    final defaults = presets[safeFrequency] ?? presets[1]!;
    final current = [..._reminderTimes]..sort(_compareTimes);
    final updated = <TimeOfDay>[];

    for (var i = 0; i < safeFrequency; i++) {
      updated.add(i < current.length ? current[i] : defaults[i]);
    }

    updated.sort(_compareTimes);
    setState(() {
      _dailyFrequency = safeFrequency;
      _reminderTimes = updated;
    });
  }

  Future<void> _scanMedicine() async {
    final image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    setState(() => _isScanning = true);
    try {
      final result = await AIService.analyzeMedicineImage(File(image.path));
      if (!mounted) return;

      if (result == null || !result.hasData) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Veri bulunamadı.')));
        return;
      }

      final shouldApply = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ScanReviewSheet(result: result),
      );

      if (mounted && shouldApply == true) {
        _applyScanResult(result);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Forma uygulandı.')));
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
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

    if (name?.isNotEmpty == true) {
      _nameController.text = name!;
    }
    if (dose?.isNotEmpty == true) {
      _dosageController.text = dose!;
    }
    if (note?.isNotEmpty == true) {
      _noteController.text = note!;
    }

    setState(() {
      _selectedForm = MedicineFormHelper.formFromScanValue(form);
      if (frequency != null && frequency > 0) {
        _setDailyFrequency(frequency);
      }
      if (meal.contains('tok')) {
        _withFood = true;
      } else if (meal.contains('aç') || meal.contains('ac')) {
        _withFood = false;
      }

      final weekdays = MedicineFormHelper.extractWeekdaysFromUsage(note ?? '');
      if (weekdays.isNotEmpty) {
        _selectedScheduleType = MedicineScheduleType.specificDays;
        _selectedWeekdays
          ..clear()
          ..addAll(weekdays);
      }
    });
  }

  Future<void> _saveCurrentMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    // 1. Duplicate saat kontrolü
    final uniqueTimes = _reminderTimes.map(_timeToString).toSet();
    if (uniqueTimes.length != _reminderTimes.length) {
      _showWarning('Aynı saatte birden fazla hatırlatma olamaz.');
      return;
    }

    // 2. Interval değeri kontrolü
    if (_selectedScheduleType == MedicineScheduleType.interval &&
        _intervalDays < 1) {
      _showWarning('Lütfen geçerli bir aralık gün sayısı seçin.');
      return;
    }

    // 3. Stok tutarsızlık kontrolü
    if (_stockTrackingEnabled && _stockCount <= 0) {
      _showWarning('Stok takibi açıkken stok miktarı 0 olamaz.');
      return;
    }

    if (_selectedScheduleType == MedicineScheduleType.specificDays &&
        _selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Lütfen gün seçin.')));
      return;
    }

    final reminderTimesStr = _reminderTimes.map(_timeToString).toList()..sort();
    final medicine = Medicine(
      id: widget.initialMedicine?.id ?? _uuid.v4(),
      name: _nameController.text.trim(),
      dailyFrequency: reminderTimesStr.length,
      totalDays: int.parse(_totalDaysController.text.trim()),
      firstDoseTime:
          reminderTimesStr.isEmpty ? '08:00' : reminderTimesStr.first,
      startDate: widget.initialMedicine?.startDate ?? DateTime.now(),
      stockCount: _stockTrackingEnabled ? _stockCount : 0,
      lowStockThreshold: _stockTrackingEnabled ? _lowStockThreshold : null,
      colorValue: _selectedColor.toARGB32(),
      form: _selectedForm,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      withFood: _withFood,
      profileId: widget.initialMedicine?.profileId ??
          HiveService.getActiveProfile().id,
      dosage: _dosageController.text.trim().isEmpty
          ? null
          : _dosageController.text.trim(),
      scheduleType: _selectedScheduleType,
      selectedWeekdays: _selectedWeekdays.toList()..sort(),
      intervalDays: _selectedScheduleType == MedicineScheduleType.interval
          ? _intervalDays
          : 1,
      reminderTimes: reminderTimesStr,
    );

    if (widget.isEditing) {
      await NotificationService.cancelMedicineNotifications(
          widget.initialMedicine!);
      await HiveService.updateMedicine(medicine);
    } else {
      await HiveService.addMedicine(medicine);
    }

    await NotificationService.scheduleMedicineNotifications(medicine);
    if (mounted) {
      Navigator.pop(
          context, {'name': medicine.name, 'isEditing': widget.isEditing});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      appBar: AppBar(
        toolbarHeight: 76,
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
            Text(widget.isEditing ? 'İlacı Düzenle' : 'İlaç Ekle',
                style: GoogleFonts.nunito(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            Text('${HiveService.getActiveProfile().name} profili',
                style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.8))),
          ],
        ),
        actions: [
          if (_isScanning)
            const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)))
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _scanMedicine,
                style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.16)),
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text('AI Tara',
                    style: GoogleFonts.nunito(
                        fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            AiScanBanner(onScanPressed: _scanMedicine),
            const SizedBox(height: 14),
            FormSection(
              isDark: isDark,
              icon: Icons.medication_rounded,
              title: 'İlaç Bilgisi',
              subtitle: 'İsim, form ve doz bilgisini belirle',
              children: [
                _fieldLabel('İlaç adı'),
                TextFormField(
                  controller: _nameController,
                  style: GoogleFonts.nunito(
                      fontSize: 14, fontWeight: FontWeight.w700),
                  decoration:
                      const InputDecoration(hintText: 'Örn: Metformin 500 mg'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v?.trim().isEmpty == true
                      ? 'Lütfen ilaç adını girin'
                      : null,
                ),
                const SizedBox(height: 14),
                _fieldLabel('Form'),
                FormSelector(
                    selectedForm: _selectedForm,
                    onFormSelected: (f) => setState(() => _selectedForm = f),
                    isDark: isDark),
                const SizedBox(height: 14),
                _fieldLabel('Doz'),
                TextFormField(
                    controller: _dosageController,
                    style: GoogleFonts.nunito(
                        fontSize: 14, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(hintText: 'Örn: 500 mg')),
              ],
            ),
            const SizedBox(height: 14),
            FormSection(
              isDark: isDark,
              icon: Icons.notifications_active_rounded,
              title: 'Hatırlatma Planı',
              subtitle: 'Saatleri ve tekrar düzenini seç',
              children: [
                _fieldLabel('Hatırlatmalar'),
                TimeChips(
                  reminderTimes: _reminderTimes,
                  isDark: isDark,
                  onTimeTap: (index) async {
                    final picked = await showTimePicker(
                        context: context,
                        initialTime: _reminderTimes[index],
                        builder: (c, child) => MediaQuery(
                            data: MediaQuery.of(c)
                                .copyWith(alwaysUse24HourFormat: true),
                            child: child!));
                    if (picked != null) {
                      setState(() {
                        _reminderTimes[index] = picked;
                        _reminderTimes.sort(_compareTimes);
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),
                _fieldLabel('Gün İçindeki Tekrar'),
                FrequencySelector(
                    selectedFrequency: _dailyFrequency,
                    onFrequencySelected: _setDailyFrequency,
                    isDark: isDark),
                const SizedBox(height: 8),
                Text(DoseCalculator.getIntervalDescription(_dailyFrequency),
                    style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                _fieldLabel('Plan'),
                ScheduleTypeSelector(
                    selectedType: _selectedScheduleType,
                    onTypeSelected: (t) =>
                        setState(() => _selectedScheduleType = t),
                    isDark: isDark),
                const SizedBox(height: 12),
                ScheduleSettings(
                  selectedType: _selectedScheduleType,
                  selectedWeekdays: _selectedWeekdays,
                  onWeekdayToggle: (d) => setState(() =>
                      _selectedWeekdays.contains(d)
                          ? _selectedWeekdays.remove(d)
                          : _selectedWeekdays.add(d)),
                  intervalDays: _intervalDays,
                  onIntervalChanged: (days) =>
                      setState(() => _intervalDays = days),
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 14),
            FormSection(
              isDark: isDark,
              icon: Icons.tune_rounded,
              title: 'Tercihler',
              subtitle: 'Süre, yemek, renk ve not',
              children: [
                _fieldLabel('Tedavi süresi'),
                TextFormField(
                  controller: _totalDaysController,
                  style: GoogleFonts.nunito(
                      fontSize: 14, fontWeight: FontWeight.w700),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      hintText: 'Örn: 30', suffixText: 'gün'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Lütfen gün sayısı girin';
                    }
                    final d = int.tryParse(v.trim());
                    if (d == null || d <= 0) {
                      return 'Geçerli bir gün sayısı girin';
                    }
                    if (d > 365) {
                      return 'En fazla 365 gün girilebilir';
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
                    onChanged: (v) => setState(() => _withFood = v),
                    isDark: isDark),
                const SizedBox(height: 14),
                _fieldLabel('Kart rengi'),
                MedicineColorPicker(
                    selectedColor: _selectedColor,
                    onColorSelected: (c) => setState(() => _selectedColor = c)),
                const SizedBox(height: 14),
                _fieldLabel('Not'),
                TextFormField(
                    controller: _noteController,
                    style: GoogleFonts.nunito(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    maxLines: 2,
                    decoration: const InputDecoration(
                        hintText: 'Örn: Doktor tavsiyesi')),
              ],
            ),
            const SizedBox(height: 16),
            StockTrackingSection(
              isDark: isDark,
              isEnabled: _stockTrackingEnabled,
              onEnabledChanged: (v) =>
                  setState(() => _stockTrackingEnabled = v),
              stockCount: _stockCount,
              onStockCountChanged: (v) => setState(() => _stockCount = v),
              selectedForm: _selectedForm,
              lowStockThreshold: _lowStockThreshold,
              onThresholdChanged: (v) => setState(() => _lowStockThreshold = v),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveCurrentMedicine,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text(
                  widget.isEditing
                      ? 'Değişiklikleri Kaydet'
                      : 'Kaydet ve Hatırlatıcı Kur',
                  style: GoogleFonts.nunito(
                      fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFFC4B7E9) : AppTheme.primaryDark)),
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
              color: isDark ? AppTheme.darkBorder : AppTheme.borderColor)),
      child: Row(
        children: [
          Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppTheme.primaryColor, size: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textPrimary)),
                Text(subtitle,
                    style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500])),
              ],
            ),
          ),
          Switch.adaptive(
              value: value,
              activeThumbColor: AppTheme.primaryColor,
              onChanged: onChanged),
        ],
      ),
    );
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.nunito()),
        backgroundColor: AppTheme.warningColor,
      ),
    );
  }
}
