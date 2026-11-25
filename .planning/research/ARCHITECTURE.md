# Architecture Research

**Domain:** Offline ESP32 BLE media-controller with an Android companion app  
**Researched:** 2026-11-25  
**Confidence:** HIGH for Android lifecycle and BLE/GATT boundaries; MEDIUM for the final Flutter-to-native service integration, which must be proved on the target phone.

## Standard Architecture

### System Overview

```
┌──────────────────────── ESP32 peripheral ───────────────────────┐
│ GPIO/button → debounce + gesture recognizer → command encoder   │
│                                                   ↓              │
│                                  NimBLE GATT server + advertiser │
└───────────────────────────────────┬─────────────────────────────┘
                                    │ custom service; one-byte notify
┌───────────────────────────────────▼─────────────────────────────┐
│ Android operational owner (long-lived service, not Flutter UI)  │
│  BLE session state machine → command validator/router → player  │
│  scan/connect/discover/subscribe/retry       ↓                  │
│                                      MediaSession + notification │
└───────────────────────────┬───────────────────────┬─────────────┘
                            │ status stream         │ system controls
┌───────────────────────────▼──────────┐  ┌─────────▼─────────────┐
│ Flutter presentation                  │  │ Android system         │
│ permission/onboarding, connection     │  │ lock screen, Bluetooth,│
│ status, current track, song list      │  │ foreground notification│
└──────────────────────────────────────┘  └───────────────────────┘
```

The product requirements establish the ESP32 as a BLE peripheral/GATT server and the phone as its central and sole audio player. Keep the protocol intentionally asymmetric: firmware emits a command event; the phone owns every playback state transition. The one-byte notify characteristic is a transport for *current input*, not a durable command queue.

The board probe has confirmed a classic ESP32-D0WDQ6 rev 1.0 with CP2102 USB bridge, so the firmware project should target `esp32`. Its development-board pinout/button GPIO and the target phone model remain validation inputs; keep GPIO selection in board configuration and do not embed an assumed pin in the protocol or gesture layers.

### Recommended Component Responsibilities

| Component | Owns | Does not own | Communication |
|---|---|---|---|
| `firmware/button` | GPIO configuration, debounce, gesture timing | BLE details or music state | emits semantic `Command` values |
| `firmware/protocol` | UUID and byte constants copied from `PROTOCOL.md` | gesture policy | used by button and GATT layers |
| `firmware/ble` | advertising, GATT service, subscription state, sending a notification, restarting advertising after disconnect | retries on the Android side | NimBLE callbacks |
| `XmasControlService` (Android) | one BLE client session, reconnect scheduler, subscription, command serialization, lifecycle notification | widgets and gesture interpretation | platform BLE APIs and a Flutter bridge |
| `PlaybackEngine` | bundled playlist, play/pause/next/previous/stop/shuffle, audio focus | BLE and UI state | command interface plus player state stream |
| `MediaSession` host | Android media metadata, transport commands, lock-screen/notification integration | direct GATT work | delegates to `PlaybackEngine` |
| Flutter app | permission/onboarding UI, status/current-track/song-list rendering, explicit connect/disconnect controls | a second connection or player | typed method/event channel to service |

### Proposed Android Lifecycle Boundary (validate before making it final)

Use one native Android service, tentatively `XmasControlService`, as the operational owner of the GATT connection and the media session/player. Flutter remains the presentation layer and receives immutable connection/playback snapshots over a bridge. This avoids two common failure modes: a Flutter activity owning a GATT callback that disappears on screen-off, and separate BLE/audio services racing over lifecycle and notification ownership.

The service should be declared for `connectedDevice` and `mediaPlayback`; Android supports combining foreground-service types, but every declared active type must satisfy its own prerequisites. Start the connected-device service only while the user has opened/onboarded the app or under a documented exemption. Once music plays, add `mediaPlayback` and keep the `MediaSession` with its player in that same service. This is a **design proposal**, not a final project requirement: a spike must verify that the selected Flutter audio integration can share this service boundary cleanly. If it cannot, retain the same ownership rules with a thin native BLE service plus the audio package's native media service, connected through a small, explicit command/status contract.

Android's documented alternative for long notification listening is `CompanionDeviceService` with companion-device presence APIs. Do not add it to the MVP by default: it adds association/presence semantics that are not required for one household device. Reassess it only if the foreground-service baseline cannot remain alive reliably on the target OEM or the product later needs process-restart recovery without opening the app.

## Recommended Project Structure

```
xmas-song/
├── PROTOCOL.md                         # canonical UUIDs, byte table, compatibility rules
├── firmware/
│   ├── main/
│   │   ├── app_main.c                  # composition only
│   │   ├── button_input.[ch]           # debounce/gesture → Command
│   │   ├── protocol.[ch]               # generated/checked command constants
│   │   └── ble_peripheral.[ch]         # NimBLE GATT/advertising lifecycle
│   ├── CMakeLists.txt
│   └── sdkconfig.defaults
├── app/
│   ├── lib/
│   │   ├── app.dart                    # Flutter composition
│   │   ├── features/status/             # status/song-list UI only
│   │   ├── platform/control_gateway.dart# typed Flutter-facing facade
│   │   └── protocol.dart                # generated/checked constants
│   └── android/app/src/main/kotlin/.../
│       ├── XmasControlService.kt        # Android lifecycle/BLE/media owner
│       ├── BleSessionManager.kt         # one GATT state machine
│       ├── CommandRouter.kt             # byte validation → playback actions
│       ├── PlaybackEngine.kt            # player/session integration
│       └── FlutterControlBridge.kt      # method/event channel adapter
└── docs/
    └── verification.md                  # physical-device demo matrix
```

`PROTOCOL.md` is the contract, not a third independently maintained implementation. Generate or test both language constant modules against its table. Keep Android platform/lifecycle code under `android/`: it is intentionally not hidden in Flutter UI or generic Dart services because Android service declarations, foreground types, GATT callbacks, and `MediaSession` lifecycle are platform responsibilities.

## Architectural Patterns

### Pattern 1: Single-owner BLE state machine

**What:** One `BleSessionManager`, owned by the service, is the only code allowed to scan, call connect, retain the GATT handle, discover services, enable notification, or schedule reconnect. Its externally visible states are `permissionRequired`, `idle`, `scanning`, `connecting`, `subscribing`, `ready`, `retryWaiting`, and `unavailable`.

**When to use:** Always in this app. BLE callbacks are asynchronous and can arrive after an old connection has been superseded; a single owner can reject stale callbacks by connection generation.

**Trade-off:** More explicit state and tests than calling a BLE plugin directly from a button handler, but it makes duplicate connections, duplicate subscriptions, and reconnect storms preventable.

```kotlin
fun onDisconnected(generation: Long) {
    if (generation != activeGeneration) return // stale callback
    closeGattOnce()
    publish(BleState.RetryWaiting)
    scheduleBoundedRetry() // only this manager owns retry timing
}
```

Use a direct initial connection after discovery. For a previously known peripheral, Android documents `autoConnect=true` as a passive reconnection mode when the device becomes available; validate the selected Flutter BLE package's exact behavior and API-level support during the physical-device spike. The reconnection owner is the Android service, while the ESP32's complementary responsibility is simply to resume advertising after disconnect.

### Pattern 2: Serialize commands without replay

**What:** Convert a received byte to a closed `Command` enum, ignore unknown values, and serialize it through one command router to the player/session. Keep one active subscription. Toggle and track-skip commands change state on each execution, so keep repeated legitimate presses distinct and avoid application-level replay. Update UI state from player/session events.

**When to use:** Every BLE notification and every notification/lock-screen media action.

**Trade-off:** A notification sent during a disconnection is intentionally not replayed. This is the correct MVP behavior: the first press while disconnected may be lost, and the second press after automatic reconnection is acceptable. Do not add command persistence, acknowledgement/retry, or “last press” replay without a future protocol decision; such replay can unexpectedly start music later.

### Pattern 3: Media session co-located with its player

**What:** The service that owns the player also owns the Android `MediaSession`, publishes current metadata and playback state, and receives notification/lock-screen actions through the same playback command interface used by BLE.

**When to use:** From the first audio slice, not as later UI polish.

**Trade-off:** Requires native Android manifest/service work early, but produces system controls and accurate lock-screen state rather than a separate custom notification. Android recommends `MediaSessionService`/a foreground media-playback service for background playback.

## Event and State Flows

### Normal connected press

```
physical press
  → firmware gesture classifier
  → one-byte GATT notification
  → BleSessionManager validates active generation/subscription
  → CommandRouter validates byte
  → PlaybackEngine action
  → player state + MediaSession metadata
  → Android notification/lock-screen controls and Flutter status stream
```

Target the under-one-second response requirement by keeping the subscription active and doing no scan, service discovery, or asset indexing on this path. The player should preload the small, bundled playlist during service setup or first explicit connect, subject to memory measurement on the actual phone.

### Disconnect and recovery

```
link drop
  → BLE callback marks current generation disconnected
  → unsubscribe/close exactly once; publish retryWaiting
  → ESP32 resumes advertising
  → service performs bounded backoff reconnect / re-discovery / re-subscription
  → ready
  → next physical press is actionable
```

No module except `BleSessionManager` restarts the connection. The UI may display and request a user-initiated retry but never opens a GATT connection itself. While `retryWaiting`, a firmware notification has no receiver; document the intentionally lost first press in the demo behavior rather than masking it with optimistic UI.

### Locked-screen playback

```
user starts service while app is visible
  → connected-device foreground lifecycle sustains BLE listening
  → BLE command or MediaStyle/lock-screen command
  → shared CommandRouter → player
  → MediaSession publishes state/metadata → system controls remain accurate
```

Android 12+ generally prevents arbitrary foreground-service starts from the background. Therefore the baseline MVP must establish the service through deliberate foreground user setup, then verify screen-off behavior while it remains active. It must not promise that a terminated process can silently restart and honor a first button press. Companion-device APIs are the separately scoped route if that requirement changes.

## Build Order: Demonstrable Vertical Slices

1. **Protocol and observable peripheral** — Target the confirmed `esp32`, define UUIDs/bytes and compatibility rules in `PROTOCOL.md`, and implement a NimBLE GATT service and advertising. First identify the development-board button GPIO (or use a temporary configured test pin), then demonstrate service discovery in a scanner. Do not build audio or Flutter screens yet.
2. **Real input over BLE** — Add GPIO debounce/gestures and notify bytes. Demonstrate every defined byte in a scanner; prove re-advertising after a forced disconnect.
3. **Foreground-safe connection spine** — Build the Android permission/onboarding flow plus `XmasControlService` and `BleSessionManager`; render received byte and connection state in Flutter. Demonstrate locked-screen notification reception and a drop/reconnect, accepting a lost first press while disconnected.
4. **Offline playback and media session** — Add a legal small bundled playlist and map all five commands through the shared router. Demonstrate current track, Android notification, and lock-screen controls using the same player state.
5. **Recovery and acceptance matrix** — Test Bluetooth toggle, out-of-range recovery, extended idle, app task dismissal, permission denial/regrant, and target-phone OEM behavior. Capture which cases retain the service and which require reopening the app; do not claim process-death recovery without an observed test.
6. **Optional power/feedback** — Only after the connected behavior is stable, evaluate ESP32 light sleep/wake and app-to-device LED feedback as a protocol extension.

## Anti-Patterns

### Flutter activity owns the BLE connection

**What people do:** Start scanning/subscribing from a widget or app lifecycle callback and expect it to survive the screen turning off.

**Why it is wrong:** UI lifecycle and process priority are not a durable BLE-notification lifecycle. Android notes that a background connection is closed when its process is killed and imposes background foreground-service-start restrictions.

**Do this instead:** Bind the UI to a long-lived service-owned state stream; the service owns the connection and reconnect policy.

### Multiple reconnect loops

**What people do:** Let the BLE package's auto-connect, a widget listener, a service restart callback, and a generic timer all call connect.

**Why it is wrong:** Produces overlapping GATT clients, stale characteristic callbacks, drain, and nondeterministic subscription state.

**Do this instead:** Select one strategy in `BleSessionManager`, use a generation token, bounded exponential backoff, and a single cancellation path.

### Treating foreground service as a process resurrection guarantee

**What people do:** Assume foreground service means an app can always start itself after a button notification or can survive all OEM/process conditions.

**Why it is wrong:** Android 12+ limits background FGS starts; a disconnected notification cannot wake a process that no longer has a connection. OEM behavior also needs physical-device validation.

**Do this instead:** Start the service via explicit foreground setup, show its connection state, test the target device, and retain the documented second-press-after-reconnect contract.

### Splitting media state from the media session

**What people do:** Give Flutter its own “current track” state and separately update a custom notification.

**Why it is wrong:** Lock-screen controls and app UI drift from actual player state.

**Do this instead:** Make the player/session the source of truth; project its state into Flutter.

## Scale and Operational Boundaries

This is a single-phone, single-button offline demo. There is no backend, database, account, queue broker, or horizontal scaling concern. The first capacity constraint is Android lifecycle reliability on the target phone, not throughput. The next is firmware power/gesture correctness when the actual ESP32 variant and power source are known.

Avoid adding a repository-wide shared runtime library before both sides exist. The stable shared artifact is the small protocol document and contract tests. Maintain mono-repo atomicity by changing `PROTOCOL.md`, firmware constants, app constants, and integration tests together.

## Primary Sources

- [Android: communicate with BLE devices in the background](https://developer.android.com/develop/connectivity/bluetooth/ble/background) — HIGH: connection, notification-listening, foreground-service, companion-device, and reconnect guidance.
- [Android: Bluetooth permissions](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions) — HIGH: Android 12+ runtime `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT` requirements.
- [Android: foreground-service type requirements](https://developer.android.com/about/versions/14/changes/fgs-types-required) — HIGH: declared/combined foreground-service types and their enforcement.
- [Android: foreground-service background-start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start) — HIGH: Android 12+ restrictions.
- [Android Media3: background playback with `MediaSessionService`](https://developer.android.com/media/media3/session/background-playback) and [control playback with a `MediaSession`](https://developer.android.com/media/media3/session/control-playback) — HIGH: player/session/service co-location and lock-screen/system control path.
- [ESP-IDF v6.1 BLE data exchange](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-guides/ble/get-started/ble-data-exchange.html) — HIGH: NimBLE GATT server/service-table and notification-subscription model.

---
*Architecture research for Xmas Button. The service topology and Flutter integration are a proposed implementation boundary to validate in the Phase 3 physical-device slice; the BLE protocol and first-press-loss behavior follow the current project requirements.*
