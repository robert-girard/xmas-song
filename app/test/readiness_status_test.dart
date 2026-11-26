import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmas_button/main.dart';

const _readiness = MethodChannel('xmas_button/readiness');
const _permissions = MethodChannel('flutter.baseflow.com/permissions/methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('readiness status', () {
    late int startCount;
    late Map<String, dynamic>? startResult;
    late Object? startError;
    late Future<Map<String, dynamic>?> Function()? snapshotResult;

    setUp(() {
      startCount = 0;
      startResult = {
        'status': 'Starting',
        'detail': 'Starting readiness service',
      };
      startError = null;
      snapshotResult = () async => {
        'status': 'Inactive',
        'detail': 'Tap Set up button to begin',
      };

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(_permissions, (call) async {
          if (call.method == 'requestPermissions') {
            final requested = (call.arguments as List).cast<int>();
            return {for (final permission in requested) permission: 1};
          }
          if (call.method == 'checkPermissionStatus') return 1;
          return null;
        })
        ..setMockMethodCallHandler(_readiness, (call) async {
          switch (call.method) {
            case 'environment':
              return {'apiLevel': 28, 'locationServicesEnabled': true};
            case 'snapshot':
              return snapshotResult!();
            case 'start':
              startCount++;
              if (startError != null) throw startError!;
              return startResult;
            case 'openLocationSettings':
              return null;
            default:
              return null;
          }
        });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(_permissions, null)
        ..setMockMethodCallHandler(_readiness, null);
    });

    testWidgets(
      'does not mark a start acknowledgment or intermediate snapshots ready',
      (tester) async {
        await tester.pumpWidget(const XmasButtonApp());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set up button'));
        await tester.pumpAndSettle();

        expect(startCount, 1);
        expect(find.text('Starting'), findsOneWidget);
        expect(find.text('Ready'), findsNothing);

        for (final state in [
          {'status': 'Scanning', 'detail': 'Looking for Xmas Button'},
          {'status': 'Connecting', 'detail': 'Connecting to Xmas Button'},
          {
            'status': 'Subscribing',
            'detail': 'Confirming button notifications',
          },
          {'status': 'Preparing', 'detail': 'Preparing offline track'},
        ]) {
          await _emitState(state);
          await tester.pump();
          expect(find.text(state['status']!), findsOneWidget);
          expect(find.text('Ready'), findsNothing);
        }

        await _emitState({
          'status': 'Ready',
          'detail': 'Button connected · track ready offline',
        });
        await tester.pump();
        expect(find.text('Ready'), findsOneWidget);
      },
    );

    testWidgets('shows native start errors and allows an explicit retry', (
      tester,
    ) async {
      startError = PlatformException(
        code: 'service_start_failed',
        message: 'Foreground promotion failed',
      );
      await tester.pumpWidget(const XmasButtonApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set up button'));
      await tester.pumpAndSettle();

      expect(find.text('Setup failed'), findsOneWidget);
      expect(find.text('Foreground promotion failed'), findsOneWidget);
      expect(find.text('Ready'), findsNothing);

      startError = null;
      await tester.tap(find.text('Retry setup'));
      await tester.pumpAndSettle();
      expect(startCount, 2);
      expect(find.text('Starting'), findsOneWidget);
    });

    testWidgets('clears Ready after link loss and refreshes an attached page', (
      tester,
    ) async {
      snapshotResult = () async => {
        'status': 'Ready',
        'detail': 'Button connected · track ready offline',
      };
      await tester.pumpWidget(const XmasButtonApp());
      await tester.pumpAndSettle();
      expect(find.text('Ready'), findsOneWidget);
      expect(startCount, 0);

      await _emitState({'status': 'Error', 'detail': 'Button disconnected'});
      await tester.pump();
      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Ready'), findsNothing);
      expect(find.text('Button disconnected'), findsOneWidget);

      await tester.tap(find.text('Retry setup'));
      await tester.pumpAndSettle();
      expect(startCount, 1);
      expect(find.text('Starting'), findsOneWidget);
    });

    testWidgets(
      'does not let a late stale snapshot overwrite a newer native error',
      (tester) async {
        final snapshot = Completer<Map<String, dynamic>?>();
        snapshotResult = () => snapshot.future;
        await tester.pumpWidget(const XmasButtonApp());

        await _emitState({
          'status': 'Error',
          'detail': 'CCCD subscription failed',
        });
        await tester.pump();
        snapshot.complete({
          'status': 'Scanning',
          'detail': 'Looking for Xmas Button',
        });
        await tester.pumpAndSettle();

        expect(find.text('Error'), findsOneWidget);
        expect(find.text('CCCD subscription failed'), findsOneWidget);
        expect(find.text('Scanning'), findsNothing);
      },
    );

    testWidgets('treats a missing start result as a retryable failure', (
      tester,
    ) async {
      startResult = null;
      await tester.pumpWidget(const XmasButtonApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set up button'));
      await tester.pumpAndSettle();

      expect(find.text('Setup failed'), findsOneWidget);
      expect(find.text('Ready'), findsNothing);
      expect(find.text('Retry setup'), findsOneWidget);
    });
  });
}

Future<void> _emitState(Map<String, dynamic> state) async {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  await messenger.handlePlatformMessage(
    _readiness.name,
    _readiness.codec.encodeMethodCall(MethodCall('stateChanged', state)),
    null,
  );
}
