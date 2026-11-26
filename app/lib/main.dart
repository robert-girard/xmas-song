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
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xffa51d32)),
      useMaterial3: true,
    ),
    home: const SetupPage(),
  );
}

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> with WidgetsBindingObserver {
  Map<String, dynamic> _state = {
    'status': 'Inactive',
    'detail': 'Tap Set up button to begin',
  };
  bool _busy = false;
  bool _settingsRequired = false;
  bool _settingsVisitPending = false;
  int _nativeRevision = 0;
  int _snapshotRequest = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler(_handleNativeCall);
    _refreshSnapshot();
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'stateChanged' || call.arguments is! Map) return;
    final entries = (call.arguments as Map).entries.where(
      (entry) => entry.key is String,
    );
    _acceptNativeState({
      for (final entry in entries) entry.key as String: entry.value,
    });
  }

  void _acceptNativeState(Map<String, dynamic> state) {
    if (!mounted || state['status'] is! String || state['detail'] is! String) {
      return;
    }
    _nativeRevision++;
    setState(() {
      _state = state;
      if (state['status'] == 'Ready') _settingsRequired = false;
    });
  }

  Future<void> _refreshSnapshot() async {
    final request = ++_snapshotRequest;
    final revision = _nativeRevision;
    try {
      final state = await _channel.invokeMapMethod<String, dynamic>('snapshot');
      if (!mounted ||
          state == null ||
          request != _snapshotRequest ||
          revision != _nativeRevision) {
        return;
      }
      _acceptNativeState(state);
    } on PlatformException {
      // A missing native snapshot leaves the current screen state intact.
    } on MissingPluginException {
      // The Android bridge is unavailable in widget-only or unsupported builds.
    } catch (_) {
      // Ignore malformed or unavailable snapshots and keep the last known state.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    _refreshSnapshot();
    if (_settingsVisitPending) _resumeFromSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _setup() async {
    if (!mounted || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _settingsRequired = false;
    });
    try {
      final environment = await _readEnvironment();
      final apiLevel = environment['apiLevel'] as int;
      final access = await _requestPermissions(apiLevel);
      if (!mounted) return;
      if (!access.granted) {
        _showPermissionState(access, apiLevel);
        return;
      }
      await _continueSetup(environment);
    } on PlatformException catch (error) {
      if (mounted) _showStartError(error);
    } on MissingPluginException {
      if (mounted) {
        _showFailure(
          'Setup failed',
          'The Android setup service is unavailable.',
        );
      }
    } catch (error) {
      if (mounted) {
        _showFailure('Setup failed', 'Could not complete setup: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>> _readEnvironment() async {
    final environment = await _channel.invokeMapMethod<String, dynamic>(
      'environment',
    );
    if (environment == null || environment['apiLevel'] is! int) {
      throw PlatformException(
        code: 'environment_unavailable',
        message: 'Could not check Android permissions.',
      );
    }
    return environment;
  }

  Future<_PermissionAccess> _requestPermissions(int apiLevel) async {
    if (apiLevel <= 30) {
      final status = await Permission.locationWhenInUse.request();
      return _PermissionAccess(
        granted: status.isGranted,
        permanentlyDenied: status.isPermanentlyDenied,
      );
    }

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    return _PermissionAccess(
      granted: statuses.values.every((status) => status.isGranted),
      permanentlyDenied: statuses.values.any(
        (status) => status.isPermanentlyDenied,
      ),
    );
  }

  Future<_PermissionAccess> _checkPermissions(int apiLevel) async {
    if (apiLevel <= 30) {
      final status = await Permission.locationWhenInUse.status;
      return _PermissionAccess(
        granted: status.isGranted,
        permanentlyDenied: status.isPermanentlyDenied,
      );
    }

    final statuses = await Future.wait([
      Permission.bluetoothScan.status,
      Permission.bluetoothConnect.status,
    ]);
    return _PermissionAccess(
      granted: statuses.every((status) => status.isGranted),
      permanentlyDenied: statuses.any((status) => status.isPermanentlyDenied),
    );
  }

  void _showPermissionState(
    _PermissionAccess access,
    int apiLevel, {
    bool retainSettingsOption = false,
  }) {
    const status = 'Permission needed';
    final permissionName = apiLevel <= 30
        ? 'Location access'
        : 'Nearby Devices access';
    final detail = access.permanentlyDenied
        ? 'Allow $permissionName in Android settings so the app can find the button.'
        : 'Allow $permissionName for button setup, then try again.';
    _nativeRevision++;
    setState(() {
      _state = {'status': status, 'detail': detail};
      _settingsRequired = access.permanentlyDenied || retainSettingsOption;
    });
  }

  Future<void> _continueSetup(Map<String, dynamic> environment) async {
    final apiLevel = environment['apiLevel'] as int;
    if (apiLevel <= 30 && environment['locationServicesEnabled'] != true) {
      _showFailure(
        'Location services off',
        'Android BLE scanning requires Location services enabled. Turn them on, then return here.',
        settingsRequired: true,
      );
      return;
    }

    final result = await _channel.invokeMapMethod<String, dynamic>('start');
    if (!mounted) return;
    if (result == null ||
        result['status'] is! String ||
        result['detail'] is! String) {
      _showFailure(
        'Setup failed',
        'The readiness service did not return a current status. Try again.',
      );
      return;
    }
    _acceptNativeState(result);
  }

  Future<void> _resumeFromSettings() async {
    if (!mounted || _busy || !_settingsVisitPending) {
      return;
    }
    _settingsVisitPending = false;
    setState(() => _busy = true);
    try {
      final environment = await _readEnvironment();
      final apiLevel = environment['apiLevel'] as int;
      final access = await _checkPermissions(apiLevel);
      if (!mounted) return;
      if (!access.granted) {
        _showPermissionState(
          access,
          apiLevel,
          retainSettingsOption: _settingsRequired,
        );
        return;
      }
      setState(() => _settingsRequired = false);
      await _continueSetup(environment);
    } on PlatformException catch (error) {
      if (mounted) _showStartError(error);
    } on MissingPluginException {
      if (mounted) {
        _showFailure(
          'Setup failed',
          'The Android setup service is unavailable.',
        );
      }
    } catch (error) {
      if (mounted) {
        _showFailure('Setup failed', 'Could not complete setup: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showStartError(PlatformException error) {
    final status = error.code == 'location_services_off'
        ? 'Location services off'
        : 'Setup failed';
    _showFailure(
      status,
      error.message ?? 'Could not start button setup.',
      settingsRequired: error.code == 'location_services_off',
    );
  }

  void _showFailure(
    String status,
    String detail, {
    bool settingsRequired = false,
  }) {
    _nativeRevision++;
    setState(() {
      _state = {'status': status, 'detail': detail};
      _settingsRequired = settingsRequired;
    });
  }

  Future<void> _openSettings() async {
    if (_busy || _settingsVisitPending) {
      return;
    }
    final locationSettings = _state['status'] == 'Location services off';
    _settingsVisitPending = true;
    try {
      if (locationSettings) {
        await _channel.invokeMethod<void>('openLocationSettings');
      } else {
        final opened = await openAppSettings();
        if (!opened) {
          _settingsVisitPending = false;
          _showFailure(
            'Permission needed',
            'Android could not open app settings. You can retry the permission prompt.',
          );
        }
      }
    } catch (error) {
      _settingsVisitPending = false;
      if (mounted) {
        _showFailure('Permission needed', 'Could not open settings: $error');
      }
    }
  }

  bool get _nativeSessionActive => const {
    'Starting',
    'Scanning',
    'Connecting',
    'Discovering',
    'Subscribing',
    'Preparing',
    'Ready',
  }.contains(_state['status']);

  @override
  Widget build(BuildContext context) {
    final status = '${_state['status'] ?? 'Inactive'}';
    final detail = '${_state['detail'] ?? ''}';
    final buttonLabel = _busy || _nativeSessionActive
        ? (status == 'Ready' ? 'Button ready' : 'Setting up…')
        : status == 'Permission needed' && !_settingsRequired
        ? 'Retry'
        : status == 'Inactive'
        ? 'Set up button'
        : 'Retry setup';

    return Scaffold(
      appBar: AppBar(title: const Text('Xmas Button')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.music_note,
                    size: 64,
                    color: Color(0xffa51d32),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Ready for Christmas music?',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Bluetooth access lets this phone find the household button and keep it connected while the screen is off.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            status,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(detail, textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy || _nativeSessionActive ? null : _setup,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bluetooth_searching),
                    label: Text(buttonLabel),
                  ),
                  if (_settingsRequired)
                    TextButton(
                      onPressed: _busy ? null : _openSettings,
                      child: const Text('Open settings'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionAccess {
  const _PermissionAccess({
    required this.granted,
    required this.permanentlyDenied,
  });

  final bool granted;
  final bool permanentlyDenied;
}
