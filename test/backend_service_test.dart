import 'package:flutter_test/flutter_test.dart';

import 'package:dozara/data/backend/backend_service.dart';

void main() {
  group('BackendService validation', () {
    test('rejects empty and malformed emails', () {
      expect(
        BackendService.validateEmailAndPassword(email: '', password: '123456'),
        contains('E-posta'),
      );
      expect(
        BackendService.validateEmailAndPassword(
          email: 'invalid',
          password: '123456',
        ),
        contains('hatali'),
      );
    });

    test('rejects short passwords and suggests common email typo fixes', () {
      expect(
        BackendService.validateEmailAndPassword(
          email: 'user@example.com',
          password: '123',
        ),
        contains('en az 6'),
      );
      expect(
        BackendService.validateEmailAndPassword(
          email: 'user@gmai.com',
          password: '123456',
        ),
        contains('gmail.com'),
      );
    });

    test('accepts valid email and password input', () {
      expect(
        BackendService.validateEmailAndPassword(
          email: 'user@example.com',
          password: '123456',
        ),
        isNull,
      );
    });

    test('maps common auth errors to friendly Turkish messages', () {
      expect(
        BackendService.friendlyAuthError(
            Exception('Invalid login credentials')),
        contains('sifre hatali'),
      );
      expect(
        BackendService.friendlyAuthError(Exception('Email not confirmed')),
        contains('E-posta onayi'),
      );
      expect(
        BackendService.friendlyAuthError(Exception('429')),
        contains('limit'),
      );
    });
  });
}
