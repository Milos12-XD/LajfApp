import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lajf_app/vault.dart';
import 'package:lajf_app/vault_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'password is device-specific, persisted and never stored as plaintext',
    () async {
      const password = 'test-only passphrase 42';
      const storage = FlutterSecureStorage();
      final access = VaultAccess();
      expect(await access.requiresSetup(), isTrue);
      expect(await access.verify(password), isFalse);
      await access.setUp(password);
      final stored = (await storage.readAll()).values.single;
      expect(stored, isNot(contains(password)));
      expect(await VaultAccess().requiresSetup(), isFalse);
      expect(await VaultAccess().verify(password), isTrue);
      expect(await access.verify('different test passphrase'), isFalse);
      await expectLater(
        access.setUp('another test passphrase'),
        throwsStateError,
      );

      FlutterSecureStorage.setMockInitialValues({});
      await VaultAccess().setUp(password);
      expect((await storage.readAll()).values.single, isNot(stored));
    },
  );

  test('weak passwords cannot initialize a vault', () async {
    await expectLater(VaultAccess().setUp('short'), throwsArgumentError);
    await expectLater(VaultAccess().setUp('            '), throwsArgumentError);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
  });

  test(
    'existing private cards cannot be unlocked by first-run setup',
    () async {
      final legacy = jsonEncode([
        {'id': 'demo', 'name': 'Example', 'pin': '0000'},
      ]);
      FlutterSecureStorage.setMockInitialValues({
        'lajf_vault_cards_v1': legacy,
      });
      await expectLater(VaultAccess().requiresSetup(), throwsStateError);
      await expectLater(
        VaultAccess().setUp('test-only passphrase'),
        throwsStateError,
      );
      expect(await VaultAccess().verify('test-only passphrase'), isFalse);
      expect(
        await const FlutterSecureStorage().read(key: 'lajf_vault_cards_v1'),
        legacy,
      );
    },
  );

  test(
    'corrupt credentials fail closed without replacing the record',
    () async {
      FlutterSecureStorage.setMockInitialValues({'lajf_vault_access_v2': '{}'});
      await expectLater(VaultAccess().requiresSetup(), throwsFormatException);
      await expectLater(
        VaultAccess().verify('test-only passphrase'),
        throwsFormatException,
      );
      await expectLater(
        VaultAccess().setUp('test-only passphrase'),
        throwsFormatException,
      );
      expect(
        await const FlutterSecureStorage().read(key: 'lajf_vault_access_v2'),
        '{}',
      );
    },
  );

  testWidgets('setup requires a long password and matching confirmation', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => const VaultPasswordDialog(setup: true),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'short');
    await tester.tap(find.text('Create password'));
    await tester.pumpAndSettle();
    expect(find.text('Use at least 12 characters.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      'test-only passphrase',
    );
    await tester.enterText(
      find.byType(TextField).last,
      'different test passphrase',
    );
    await tester.tap(find.text('Create password'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(result, isNull);
    await tester.enterText(find.byType(TextField).last, 'test-only passphrase');
    await tester.tap(find.text('Create password'));
    await tester.pumpAndSettle();
    expect(result, 'test-only passphrase');
  });

  test('card comments and demo PIN serialize together', () {
    const card = VaultCard(
      id: 'one',
      name: 'Example bank',
      pin: '0000',
      comment: 'Demo only',
    );
    final loaded = VaultCard.fromJson(card.toJson());
    expect(loaded.name, 'Example bank');
    expect(loaded.pin, '0000');
    expect(loaded.comment, 'Demo only');
  });
}
