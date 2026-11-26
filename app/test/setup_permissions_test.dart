import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:xmas_button/main.dart';

const _readiness = MethodChannel('xmas_button/readiness');
const _permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
const _denied = 0;
const _granted = 1;
const _permanentlyDenied = 4;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('setup permissions', () {
    late int apiLevel;
    late int permissionResult;
    late int checkResult;
    late int requestCount;
    late int startCount;
    late int openSettingsCount;
    late List<int> requestedPermissions;
    Completer<Map<int, int>>? pendingRequest;

    setUp(() {
      apiLevel = 28;
      permissionResult = _granted;
      checkResult = _granted;
      requestCount = 0;
      startCount = 0;
      openSettingsCount = 0;
      requestedPermissions = [];
      pendingRequest = null;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(_permissions, (call) async {
          switch (call.method) {
            case 'requestPermissions':
              requestCount++;
              requestedPermissions = (call.arguments as List).cast<int>();
              if (pendingRequest != null) return pendingRequest!.future;
              return _permissionResults(
                call.arguments as List,
                permissionResult,
              );
            case 'checkPermissionStatus':
              return checkResult;
            case 'openAppSettings':
              openSettingsCount++;
              return true;
            default:
              return null;
          }
        })
        ..setMockMethodCallHandler(_readiness, (call) async {
          switch (call.method) {
            case 'environment':
              return {'apiLevel': apiLevel, 'locationServicesEnabled': true};
            case 'snapshot':
              return {
                'status': 'Inactive',
                'detail': 'Tap Set up button to begin',
              };
            case 'start':
              startCount++;
              return {
                'status': 'Scanning',
                'detail': 'Looking for Xmas Button',
              };
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

    testWidgets('shows the rationale without prompting on clean launch', (
      tester,
    ) async {
      await tester.pumpWidget(const XmasButtonApp());

      expect(
        find.textContaining('Bluetooth access lets this phone'),
        findsOneWidget,
      );
      expect(find.text('Set up button'), findsOneWidget);
      expect(requestCount, 0);
      expect(startCount, 0);
    });

    testWidgets(
      'requests API 28 location and offers retry after a recoverable denial',
      (tester) async {
        permissionResult = _denied;
        await tester.pumpWidget(const XmasButtonApp());

        await tester.tap(find.text('Set up button'));
        await tester.pumpAndSettle();

        expect(requestCount, 1);
        expect(requestedPermissions, [Permission.locationWhenInUse.value]);
        expect(find.text('Permission needed'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('Open settings'), findsNothing);
        expect(startCount, 0);
      },
    );

    testWidgets(
      'requests both API 31 grants and offers settings after permanent denial',
      (tester) async {
        apiLevel = 31;
        permissionResult = _permanentlyDenied;
        await tester.pumpWidget(const XmasButtonApp());

        await tester.tap(find.text('Set up button'));
        await tester.pumpAndSettle();

        expect(requestCount, 1);
        expect(requestedPermissions, [
          Permission.bluetoothScan.value,
          Permission.bluetoothConnect.value,
        ]);
        expect(find.text('Open settings'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
        expect(startCount, 0);
      },
    );

    testWidgets(
      'starts once when permission is granted in settings and the app resumes',
      (tester) async {
        permissionResult = _permanentlyDenied;
        await tester.pumpWidget(const XmasButtonApp());
        await tester.tap(find.text('Set up button'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open settings'));
        await tester.pumpAndSettle();

        expect(openSettingsCount, 1);
        checkResult = _granted;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(requestCount, 1);
        expect(startCount, 1);
        expect(find.text('Scanning'), findsOneWidget);
      },
    );

    testWidgets(
      'stays non-ready when settings are opened but access remains denied',
      (tester) async {
        permissionResult = _permanentlyDenied;
        checkResult = _permanentlyDenied;
        await tester.pumpWidget(const XmasButtonApp());
        await tester.tap(find.text('Set up button'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open settings'));
        await tester.pumpAndSettle();

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(find.text('Permission needed'), findsOneWidget);
        expect(find.text('Open settings'), findsOneWidget);
        expect(startCount, 0);
      },
    );

    testWidgets(
      'collapses overlapping taps and resumes while a permission prompt is open',
      (tester) async {
        final answer = Completer<Map<int, int>>();
        pendingRequest = answer;
        await tester.pumpWidget(const XmasButtonApp());
        await tester.tap(find.text('Set up button'));
        await tester.pump();
        await tester.tap(find.text('Setting up…'), warnIfMissed: false);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        expect(requestCount, 1);
        expect(startCount, 0);

        answer.complete(
          _permissionResults([Permission.locationWhenInUse.value], _granted),
        );
        await tester.pumpAndSettle();

        expect(requestCount, 1);
        expect(startCount, 1);
      },
    );
  });
}

Map<int, int> _permissionResults(List<dynamic> requested, int status) => {
  for (final permission in requested.cast<int>()) permission: status,
};
