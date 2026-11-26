import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
    late int openLocationSettingsCount;
    late bool locationServicesEnabled;
    late Map<String, dynamic> nativeSnapshot;
    late List<int> requestedPermissions;
    Completer<Map<int, int>>? pendingRequest;
    Completer<Map<String, dynamic>?>? pendingSnapshot;
    Completer<bool>? pendingOpenSettings;

    setUp(() {
      apiLevel = 28;
      permissionResult = _granted;
      checkResult = _granted;
      requestCount = 0;
      startCount = 0;
      openSettingsCount = 0;
      openLocationSettingsCount = 0;
      locationServicesEnabled = true;
      nativeSnapshot = {
        'status': 'Inactive',
        'detail': 'Tap Set up button to begin',
      };
      requestedPermissions = [];
      pendingRequest = null;
      pendingSnapshot = null;
      pendingOpenSettings = null;

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
              if (pendingOpenSettings != null) {
                return pendingOpenSettings!.future;
              }
              return true;
            default:
              return null;
          }
        })
        ..setMockMethodCallHandler(_readiness, (call) async {
          switch (call.method) {
            case 'environment':
              return {
                'apiLevel': apiLevel,
                'locationServicesEnabled': locationServicesEnabled,
              };
            case 'snapshot':
              if (pendingSnapshot != null) return pendingSnapshot!.future;
              return nativeSnapshot;
            case 'start':
              startCount++;
              return {
                'status': 'Scanning',
                'detail': 'Looking for Xmas Button',
              };
            case 'openLocationSettings':
              openLocationSettingsCount++;
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

        permissionResult = _granted;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(requestCount, 2);
        expect(startCount, 1);
        expect(find.text('Scanning'), findsOneWidget);
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
        expect(find.text('Permission required'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
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
        expect(find.text('Open settings'), findsNothing);
      },
    );

    testWidgets(
      'keeps settings recovery after a denied, late inactive resume snapshot',
      (tester) async {
        permissionResult = _permanentlyDenied;
        // Android may report ordinary denial when its Activity is unavailable
        // for the status check after returning from settings.
        checkResult = _denied;
        await tester.pumpWidget(const XmasButtonApp());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set up button'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open settings'));
        await tester.pumpAndSettle();

        final staleSnapshot = Completer<Map<String, dynamic>?>();
        pendingSnapshot = staleSnapshot;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(find.text('Permission needed'), findsOneWidget);
        expect(find.text('Open settings'), findsOneWidget);
        expect(startCount, 0);

        staleSnapshot.complete({
          'status': 'Inactive',
          'detail': 'Readiness service stopped',
        });
        await tester.pumpAndSettle();

        expect(find.text('Permission needed'), findsOneWidget);
        expect(find.text('Open settings'), findsOneWidget);
        expect(startCount, 0);
      },
    );

    testWidgets(
      'keeps Location settings guidance after resume when a previous native error is stale',
      (tester) async {
        locationServicesEnabled = false;
        nativeSnapshot = {
          'status': 'Error',
          'detail': 'Button not found before scan timeout',
        };
        await tester.pumpWidget(const XmasButtonApp());
        await tester.pumpAndSettle();
        expect(
          find.text('Button not found before scan timeout'),
          findsOneWidget,
        );
        await tester.tap(find.text('Retry setup'));
        await tester.pumpAndSettle();

        expect(find.text('Location services off'), findsOneWidget);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(find.text('Location services off'), findsOneWidget);

        await tester.tap(find.text('Open settings'));
        await tester.pumpAndSettle();
        expect(openLocationSettingsCount, 1);
        expect(openSettingsCount, 0);
        expect(startCount, 0);
      },
    );

    testWidgets(
      'prevents setup reentry while an app settings visit is unresolved',
      (tester) async {
        permissionResult = _permanentlyDenied;
        final settingsResult = Completer<bool>();
        pendingOpenSettings = settingsResult;
        await tester.pumpWidget(const XmasButtonApp());
        await tester.tap(find.text('Set up button'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open settings'));
        await tester.pump();

        expect(requestCount, 1);
        expect(openSettingsCount, 1);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(
          tester.widget<TextButton>(find.byType(TextButton)).onPressed,
          isNull,
        );
        await tester.tap(find.text('Permission required'), warnIfMissed: false);
        expect(requestCount, 1);
        expect(startCount, 0);

        settingsResult.complete(true);
        await tester.pump();
        checkResult = _granted;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(startCount, 1);
        expect(find.text('Scanning'), findsOneWidget);
        expect(find.text('Open settings'), findsNothing);
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
