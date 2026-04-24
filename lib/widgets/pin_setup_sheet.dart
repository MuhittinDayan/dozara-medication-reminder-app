import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/security_service.dart';
import '../theme/app_theme.dart';

Future<bool> showPinSetupSheet(
  BuildContext context, {
  required bool isChangingPin,
  String? title,
  String? subtitle,
}) async {
  final currentPinController = TextEditingController();
  final newPinController = TextEditingController();
  final confirmPinController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String? errorText;
  var isSaving = false;

  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final isDark = Theme.of(sheetContext).brightness == Brightness.dark;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> submit() async {
            if (!formKey.currentState!.validate()) {
              return;
            }

            setSheetState(() {
              isSaving = true;
              errorText = null;
            });

            if (isChangingPin) {
              final currentValid = await SecurityService.verifyPin(
                currentPinController.text,
              );
              if (!currentValid) {
                setSheetState(() {
                  errorText = 'Mevcut PIN yanlis.';
                  isSaving = false;
                });
                return;
              }
            }

            await SecurityService.setPin(newPinController.text);

            if (sheetContext.mounted) {
              Navigator.of(sheetContext).pop(true);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryLight
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title ??
                                      (isChangingPin
                                          ? 'PIN Degistir'
                                          : 'PIN Olustur'),
                                  style: GoogleFonts.nunito(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle ??
                                      'Uygulama kilidinde kullanmak icin 4-6 haneli bir PIN belirleyin.',
                                  style: GoogleFonts.nunito(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                    color: Colors.white.withValues(alpha: 0.82),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isChangingPin) ...[
                      _buildLabel('Mevcut pin'),
                      TextFormField(
                        controller: currentPinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          hintText: 'Mevcut PIN',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                          counterText: '',
                        ),
                        validator: (value) {
                          final pin = value?.trim() ?? '';
                          if (pin.length < 4 || pin.length > 6) {
                            return 'PIN 4-6 hane olmali.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildLabel('Yeni pin'),
                    TextFormField(
                      controller: newPinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        hintText: 'Yeni PIN',
                        prefixIcon: Icon(Icons.pin_rounded),
                        counterText: '',
                      ),
                      validator: (value) {
                        final pin = value?.trim() ?? '';
                        if (pin.length < 4 || pin.length > 6) {
                          return 'PIN 4-6 hane olmali.';
                        }
                        if (!RegExp(r'^\d+$').hasMatch(pin)) {
                          return 'PIN sadece rakamlardan olusmali.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildLabel('Pin tekrar'),
                    TextFormField(
                      controller: confirmPinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        hintText: 'PIN tekrar',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                        counterText: '',
                      ),
                      validator: (value) {
                        final confirmPin = value?.trim() ?? '';
                        if (confirmPin != newPinController.text.trim()) {
                          return 'PIN eslesmiyor.';
                        }
                        return null;
                      },
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          errorText!,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.of(sheetContext).pop(false),
                            child: const Text('Vazgec'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: isSaving ? null : submit,
                            child: isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    isChangingPin
                                        ? 'PIN Guncelle'
                                        : 'PIN Kaydet',
                                    style: GoogleFonts.nunito(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  currentPinController.dispose();
  newPinController.dispose();
  confirmPinController.dispose();

  return result ?? false;
}

Widget _buildLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text.toUpperCase(),
      style: GoogleFonts.nunito(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: AppTheme.primaryDark,
      ),
    ),
  );
}
