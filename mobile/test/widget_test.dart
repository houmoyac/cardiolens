import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
// Not part of file_picker's public barrel export — needed to swap in a
// fake platform implementation for testing (see _FakeFilePicker).
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cardiolens_app/main.dart';
import 'package:cardiolens_app/screens/home_screen.dart';
import 'package:cardiolens_app/screens/login_screen.dart';
import 'package:cardiolens_app/screens/results_screen.dart';
import 'package:cardiolens_app/theme.dart';

/// Swaps the real platform channel (unavailable in a widget test — see
/// _FakeFilePicker's call sites below) for a deterministic fake, so
/// "Importer un ECG" can be exercised without a real OS file dialog.
class _FakeFilePicker extends FilePickerPlatform {
  _FakeFilePicker({this.throwOnPick = false, this.result});

  final bool throwOnPick;
  final FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    if (throwOnPick) {
      throw Exception('simulated platform failure');
    }
    return result;
  }
}

FilePickerResult _csvResult(String csv, {String name = 'ecg.csv'}) => FilePickerResult([
  PlatformFile(name: name, size: csv.length, bytes: Uint8List.fromList(csv.codeUnits)),
]);

/// These tests exercise HomeScreen directly (not through CardioLensApp) so
/// they don't depend on authentication state — see the AuthGate test below
/// for that. HomeScreen has no dependency on being logged in except the
/// account menu, which isn't touched here.
Widget _wrapped(Widget child) =>
    MaterialApp(theme: buildCardioLensTheme(), home: child);

void main() {
  testWidgets('Home screen shows title and sample cases', (tester) async {
    await tester.pumpWidget(_wrapped(const HomeScreen()));

    expect(find.text('CardioLens'), findsOneWidget);
    expect(find.text('Patient #A-2288'), findsOneWidget);
    expect(find.text('Patient #A-2291'), findsOneWidget);
    expect(find.text('Patient #A-2279'), findsOneWidget);
  });

  testWidgets('Tapping a recent case opens the results screen', (tester) async {
    await tester.pumpWidget(_wrapped(const HomeScreen()));

    await tester.tap(find.text('Patient #A-2291'));
    await tester.pumpAndSettle();

    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(find.textContaining('Bradycardie'), findsOneWidget);
  });

  testWidgets(
    'Importing shows a friendly error instead of crashing when the file '
    'picker plugin fails',
    (tester) async {
      FilePickerPlatform.instance = _FakeFilePicker(throwOnPick: true);

      await tester.pumpWidget(_wrapped(const HomeScreen()));
      await tester.tap(find.text('Importer un ECG'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text("Impossible d'ouvrir le sélecteur de fichiers."), findsOneWidget);
    },
  );

  testWidgets('Cancelling the file picker (null result) does nothing', (tester) async {
    FilePickerPlatform.instance = _FakeFilePicker(result: null);

    await tester.pumpWidget(_wrapped(const HomeScreen()));
    await tester.tap(find.text('Importer un ECG'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Détails du tracé'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets(
    'Picking a valid CSV file opens the import-details dialog asking for '
    'the sampling rate',
    (tester) async {
      FilePickerPlatform.instance = _FakeFilePicker(
        result: _csvResult('time,amplitude\n0.000,0.10\n0.002,0.20'),
      );

      await tester.pumpWidget(_wrapped(const HomeScreen()));
      await tester.tap(find.text('Importer un ECG'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Détails du tracé'), findsOneWidget);
      expect(find.text("Fréquence d'échantillonnage (Hz)"), findsOneWidget);
    },
  );

  testWidgets(
    'Picking a file with no numeric content shows an explicit error, not a '
    'silent no-op',
    (tester) async {
      FilePickerPlatform.instance = _FakeFilePicker(
        result: _csvResult('not,a,number\nalso not one'),
      );

      await tester.pumpWidget(_wrapped(const HomeScreen()));
      await tester.tap(find.text('Importer un ECG'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.textContaining('Aucune valeur numérique'), findsOneWidget);
    },
  );

  testWidgets(
    'With no stored session, the app opens on the login screen '
    '(secure storage is unavailable in the test env, which restoreSession '
    'treats the same as "nothing stored", not a crash)',
    (tester) async {
      await tester.pumpWidget(const CardioLensApp());
      // Not pumpAndSettle: the loading state is a CircularProgressIndicator,
      // an indefinite animation that never "settles" on its own. Advance
      // past AuthService.restoreSession's 3s secure-storage read timeout.
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));

      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );
}
