# API Coverage — ESP-IDF and Android Device SDKs

| capability | decision | reason |
|---|---|---|
| ESP-IDF NimBLE peripheral GAP advertising | INTEGRATE | Advertise the complete 128-bit service UUID and expose the generic name in scan response. |
| ESP-IDF NimBLE primary service and command notifications | INTEGRATE | Expose the notify-only characteristic, track the CCCD and notify the current subscriber. |
| ESP-IDF NimBLE characteristic reads, writes and indications | OPT-OUT | The approved BLE command protocol uses only notifications and its standard CCCD. |
| Espressif Button GPIO and debounced single click | INTEGRATE | Map the verified onboard BOOT GPIO to play/pause. |
| Espressif Button additional gesture callbacks | OPT-OUT | Phase 2 owns the remaining button gestures and commands. |
| permission_handler runtime grants and app settings | INTEGRATE | Flutter requests legacy scan location on API 28–30 or Bluetooth scan/connect on API 31+ and guides denial recovery. |
| Android visible foreground service promotion and notification | INTEGRATE | Own the waiting device session and actual audio in the same service on the approved API 28 handset and keep API-guarded type declarations. |
| Android BluetoothLeScanner advertised service UUID match | INTEGRATE | Use the exact UUID in both the filter and ScanRecord.serviceUuids. |
| Android BluetoothGatt connection and CCCD write completion | INTEGRATE | One service-owned connection; readiness waits for the actual successful descriptor callback. |
| Android MediaPlayer packaged-resource preparation and play/pause | INTEGRATE | Prepare and play the two exact local assets through the same service, including sequential completion. |
| Android automatic background scan and reconnect | OPT-OUT | Phase 4 owns idle and dropped-link recovery. |
| Android CompanionDeviceService | OPT-OUT | Its API 31 service cannot establish the acceptance path on the API 28 handset. |
| Android MediaSession transport surfaces | OPT-OUT | Phase 3 owns lock-screen and system media controls. |
| flutter_reactive_ble 5.6.0 discovery and notification stream | OPT-OUT | The native GATT path exposes actual CCCD completion and keeps ownership entirely inside the single Android service; stream listener registration does not prove descriptor success. |
| audio_service 0.18.19 background media service | OPT-OUT | Initial promotion follows a playing transition. This spike requires a single service that is foreground and prepared before any audio or secondary engine/service startup. |
| just_audio 0.10.6 asset player | OPT-OUT | Native MediaPlayer keeps preparation, playback and cleanup in the same Android service lifetime without Flutter engine ownership. |
