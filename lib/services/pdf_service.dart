import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/dose_log.dart';
import '../models/medicine.dart';
import 'hive_service.dart';

class PdfService {
  /// Son dönem verilerini alarak PDF raporu oluşturur ve paylaşır.
  static Future<void> generateAndShareReport({String? password}) async {
    final pdf = pw.Document();

    final activeProfile = HiveService.getActiveProfile();

    final activeMedicines = HiveService.getActiveMedicines();
    final todayLogs = HiveService.getTodayDoseLogs();
    final ttf = pw.Font.helvetica();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            _buildHeader(ttf, activeProfile.name),
            pw.SizedBox(height: 20),
            _buildSummaryInfo(ttf, activeMedicines.length, todayLogs),
            pw.SizedBox(height: 20),
            _buildMedicinesTable(ttf, activeMedicines),
            pw.SizedBox(height: 30),
            _buildFooter(ttf),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File(
      '${output.path}/ilac_raporu_${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf',
    );
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: '${activeProfile.name} İlaç Raporu',
    );
  }

  static pw.Widget _buildHeader(pw.Font ttf, String profileName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'İlaç Uyum Raporu',
          style: pw.TextStyle(
            font: ttf,
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Profil: $profileName',
              style: pw.TextStyle(font: ttf, fontSize: 16),
            ),
            pw.Text(
              'Tarih: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
              style: pw.TextStyle(
                font: ttf,
                fontSize: 14,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
        pw.Divider(color: PdfColors.grey400),
      ],
    );
  }

  static pw.Widget _buildSummaryInfo(
    pw.Font ttf,
    int activeCount,
    List<DoseLog> todayLogs,
  ) {
    final taken =
        todayLogs.where((log) => log.status == DoseStatus.taken).length;
    final total = todayLogs.length;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryBox(ttf, 'Aktif İlaçlar', '$activeCount adet'),
          _buildSummaryBox(ttf, 'Bugünkü Dozlar', '$taken / $total alındı'),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryBox(pw.Font ttf, String title, String value) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style:
              pw.TextStyle(font: ttf, fontSize: 12, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: ttf,
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildMedicinesTable(pw.Font ttf, List<Medicine> medicines) {
    return pw.TableHelper.fromTextArray(
      headers: ['İlaç Adı', 'Form', 'Günlük Doz', 'Kalan Stok', 'Not/Uyarı'],
      headerStyle: pw.TextStyle(
        font: ttf,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellStyle: pw.TextStyle(font: ttf, fontSize: 11),
      cellAlignment: pw.Alignment.centerLeft,
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      data: medicines.map((medicine) {
        return [
          medicine.name,
          '${medicine.formName}${medicine.dosage != null ? ' / ${medicine.dosage}' : ''}',
          '${medicine.remindersPerDay} kez',
          medicine.lowStockThreshold != null ? '${medicine.stockCount}' : '-',
          medicine.withFood ? 'Tok karnına' : (medicine.note ?? '-'),
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildFooter(pw.Font ttf) {
    return pw.Center(
      child: pw.Text(
        'Bu rapor İlaç Hatırlatıcı uygulaması tarafından otomatik oluşturulmuştur.',
        style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey500),
      ),
    );
  }
}
