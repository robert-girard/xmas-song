import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

const _channel = MethodChannel('xmas_button/readiness');

void main() => runApp(const XmasButtonApp());

class XmasButtonApp extends StatelessWidget {
  const XmasButtonApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Xmas Button',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xffa51d32)), useMaterial3: true),
        home: const SetupPage(),
      );
}

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  Map<String, dynamic> _state = {'status': 'Inactive', 'detail': 'Tap Set up button to begin'};
  bool _busy = false;
  bool _settingsRequired = false;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'stateChanged' && call.arguments is Map && mounted) {
        setState(() => _state = Map<String, dynamic>.from(call.arguments as Map));
      }
    });
    _channel.invokeMapMethod<String, dynamic>('snapshot').then((state) {
      if (mounted && state != null) setState(() => _state = state);
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _setup() async {
    setState(() { _busy = true; _settingsRequired = false; });
    try {
      final env = Map<String, dynamic>.from(await _channel.invokeMethod('environment') as Map);
      final api = env['apiLevel'] as int;
      if (api <= 30) {
        final permission = await Permission.locationWhenInUse.request();
        if (!permission.isGranted) {
          setState(() { _state = {'status': 'Permission needed', 'detail': permission.isPermanentlyDenied ? 'Allow Location access in Android settings so Android can scan for the button.' : 'Allow Location access for BLE scanning, then try again.'}; _settingsRequired = permission.isPermanentlyDenied; });
          return;
        }
        if (env['locationServicesEnabled'] != true) {
          setState(() { _state = {'status': 'Location services off', 'detail': 'Android 9 requires Location services enabled to scan for nearby BLE devices.'}; _settingsRequired = true; });
          return;
        }
      } else {
        final statuses = await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
        if (statuses.values.any((status) => !status.isGranted)) {
          final permanent = statuses.values.any((status) => status.isPermanentlyDenied);
          setState(() { _state = {'status': 'Permission needed', 'detail': permanent ? 'Allow Nearby Devices in Android settings, then try again.' : 'Allow Nearby Devices so the app can find and connect to the button.'}; _settingsRequired = permanent; });
          return;
        }
      }
      final result = await _channel.invokeMethod<Map>('start');
      if (result != null && mounted) setState(() => _state = Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      if (mounted) setState(() { _state = {'status': 'Setup failed', 'detail': e.message ?? 'Could not start setup.'}; _settingsRequired = e.code == 'location_services_off'; });
    } catch (e) {
      if (mounted) setState(() => _state = {'status': 'Setup failed', 'detail': 'Could not start setup: $e'});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSettings() async {
    if (_state['status'] == 'Location services off') {
      await _channel.invokeMethod('openLocationSettings');
    } else {
      await openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = '${_state['status'] ?? 'Inactive'}';
    final detail = '${_state['detail'] ?? ''}';
    return Scaffold(
      appBar: AppBar(title: const Text('Xmas Button')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Icon(Icons.music_note, size: 64, color: Color(0xffa51d32)),
              const SizedBox(height: 20),
              const Text('Ready for Christmas music?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text('Bluetooth access lets this phone find the household button and keep it connected while the screen is off.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [Text(status, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8), Text(detail, textAlign: TextAlign.center)]))),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _busy ? null : _setup, icon: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.bluetooth_searching), label: const Text('Set up button')),
              if (_settingsRequired) TextButton(onPressed: _openSettings, child: const Text('Open settings')),
            ]),
          ),
        ),
      ),
    );
  }
}
