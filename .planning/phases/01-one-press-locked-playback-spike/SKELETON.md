# Walking Skeleton — Xmas Button

**Phase:** 1
**Planned:** 2026-11-25

## Capability to prove

One short press on the USB-powered ESP32 starts the first licensed bundled track in about one second on the already-connected, offline, locked Android phone. The Android service must retain readiness while playback has yet to begin and continue playback with the display off.

| Decision | Choice | Basis |
|---|---|---|
| Board and SDK | KeeYees ESP32-D0WDQ6 rev 1.0, ESP-IDF 6.1.1, NimBLE, locked Espressif Button 4.2.3 | Use target esp32 and the installed bleprph example. Verify the actual BOOT-to-GPIO0 circuit before configuring it. |
| Flutter shell | Android-only Flutter 3.50.1 / Dart 3.14, permission_handler ^13.0.2, toolchain SDK 36 with minSdk 28 | The verified spare phone is Samsung SM-G955W, Android 9/API 28, arm64-v8a. Flutter owns explanation, permission prompts, recovery and status. |
| Foreground ownership | One non-exported Android ReadinessService, started only by visible, permitted setup | Flutter calls start on xmas_button/readiness. A native acknowledgment follows successful foreground promotion, with failures returned to the setup UI. The same service owns the whole waiting and playback interval. |
| BLE client | Android BluetoothLeScanner and BluetoothGatt in the service | A real advertised service UUID match leads to one connection and a successful write to the expected CCCD, acknowledged via onDescriptorWrite. |
| Audio owner | One native MediaPlayer managed by ReadinessService | The service prepares a packaged raw Ogg file after CCCD success and uses the same ready player on the first press. Plan 03 adds the second track to the same owner. |
| Protocol | Service 55f93b80-da2b-42f4-bad6-a4ec40e3ea7c and notify-only characteristic 2206a557-99b7-4176-98f4-d066c053335e | PROTOCOL.md, firmware C and Android Kotlin share five one-byte meanings. Phase 1 exercises 0x01 play/pause. |
| Runtime data | One current in-memory session and packaged Android raw audio resources | The source and rights document travels with both verified recordings, and the release APK is offline. |
| Physical deployment | Documented esp32 USB flash and separately isolated debug and release APK installs | The smoke uses the debug .smoke ID. Final clean-install acceptance uses org.xmasbutton.phase01.xmas_button after checking availability. USB wall power can keep the flashed board on while the phone uses host USB. |
| Repository layout | firmware/, app/, PROTOCOL.md, xmas-song.code-workspace, and docs/phase-01-physical-evidence.md | Two reproducible project roots, a shared protocol and a durable acceptance record in one repo. |

## Route

```text
visible Flutter Set up button -> appropriate system permission granted
  -> MainActivity start of the one Android ReadinessService
  -> successful native startForeground -> native acknowledgment
  -> ScanFilter service UUID + ScanRecord.serviceUuids match -> one GATT connection
  -> known notify characteristic -> successful matching onDescriptorWrite
  -> bundled track prepared silently -> Ready in Flutter and notification

physical BOOT short press on verified GPIO0
  -> subscribed NimBLE notification [0x01]
  -> active ReadinessService validates current GATT and one byte
  -> already prepared MediaPlayer starts -> phone speaker with display off
```

The MethodChannel carries environment, start and snapshot requests and stateChanged updates. Snapshot states identify starting/scanning, connecting, subscribing, preparing, Ready, and a failed or inactive session. Neither a queued descriptor write nor a local listener registration establishes Ready. Android 28–32 use the Boolean descriptor API and Android 33+ use the value overload. Both advance only on the actual success callback. [Android foreground service launch](https://developer.android.com/develop/background-work/services/fgs/launch), [ScanRecord](https://developer.android.com/reference/android/bluetooth/le/ScanRecord#getServiceUuids()), [BluetoothGatt](https://developer.android.com/reference/android/bluetooth/BluetoothGatt), [BluetoothGattCallback](https://developer.android.com/reference/android/bluetooth/BluetoothGattCallback#onDescriptorWrite(android.bluetooth.BluetoothGatt,android.bluetooth.BluetoothGattDescriptor,int)).

Scope the Android 28–30 location grant to visible BLE scan. API 31+ requests Nearby Devices before the connectedDevice foreground service starts. API 28 uses the older foreground-promotion signature and later Android uses the appropriate service type flags. MediaPlayer is a native SDK player with an explicit Prepared state, leaving startup and Bluetooth ownership under the one service. [Android Bluetooth permissions](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions), [Foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types), [MediaPlayer](https://developer.android.com/reference/android/media/MediaPlayer).

## Research uncertainties and their resolution

| Uncertainty | Planned resolution |
|---|---|
| Handoff and ownership on the observed handset | One service owns concrete scan, GATT, CCCD and player state from visible setup through lock. Files hand off through stable paths and one bridge. Plan 01-01 proves the real first-asset route and records actual model, build and smoke outcome. Plan 01-02 consumes the bridge in Flutter while 01-03 changes the service's media queue. Plan 01-04 observes the final release, and the architecture decision stays provisional until a passing physical run. |
| Physical BOOT circuit | Plan 01-01 identifies the actual KeeYees board and verifies BOOT reaches GPIO0 by matched schematic/board evidence or a direct measurement before GPIO configuration/flashing. It records the method and observes normal released-BOOT boot. Plan 01-04 re-observes the relevant wiring and boot. |
| Exact recording rights and decode | Plan 01-01 checks actual recording and arrangement terms at source and records the first asset's exact packaged hash before adding it. Plan 01-03 repeats for a second recording, and 01-04 listens to both assets on the offline physical phone. |

The native BLE choice makes the CCCD result and service lifetime explicit on the API 28 acceptance device. The Flutter BLE package's stream registration is a different observable event. The published audio_service version first promotes its media service when playback becomes active. Android SDK MediaPlayer allows the same already-running service to prepare before first play, with one Android service and one Flutter UI engine. [flutter_reactive_ble 5.6.0](https://pub.dev/packages/flutter_reactive_ble/versions/5.6.0), [audio_service 0.18.19 source archive](https://pub.dev/api/archives/audio_service-0.18.19.tar.gz), [MediaPlayer prepared state](https://developer.android.com/reference/android/media/MediaPlayer).

## Waves

| Wave | Plan | Observable outcome |
|---|---|---|
| 1 | 01-01 | Verified BOOT circuit and single-track locked-phone physical smoke. |
| 2 | 01-02 | Permission denial recovery and trustworthy status in the setup UI. |
| 2 | 01-03 | Second packaged recording plays through the same service, and both projects open from the VS Code workspace. |
| 3 | 01-04 | Physical timing, rights-backed playback of both recordings and the service verdict on the isolated release acceptance install. |

Phase 2 adds command gestures and transport breadth, Phase 3 adds Android media controls and song status, and Phase 4 adds automatic reconnection and complete demo reproduction. The planned decision remains a single fixed BLE identity and one service-owned session.
