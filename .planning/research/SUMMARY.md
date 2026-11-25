# Project Research Summary

**Project:** Xmas Button  
**Domain:** ESP32 BLE single-button controller for offline Android music playback  
**Researched:** 2026-11-25  
**Confidence:** HIGH for stack, scope, and architecture; MEDIUM for real-device lifecycle behavior

## Executive Summary

Xmas Button is a small, deliberately appliance-like system: one ESP32 button sends five semantic commands over a custom BLE GATT service, while one Android phone owns a small bundled Christmas playlist. The research recommends ESP-IDF 6.1.1 with the NimBLE peripheral example and `espressif/button` 4.2.3 on the confirmed ESP32-D0WDQ6 rev 1.0, plus Flutter 3.50.1/Dart 3.14 using `flutter_reactive_ble`, `audio_service`, `just_audio`, and `permission_handler`.

The architecture should be service-centric: one Android control service owns the BLE session/reconnect state and the media player/session; Flutter is the status and onboarding UI. The v1 contract is five commands on one physical button, a small rights-cleared offline playlist, and automatic reconnect where a second press after reconnection is acceptable. The principal risks are gesture latency, Android foreground-service/permission lifecycle, stale GATT subscriptions, and assumptions about the target phone or board. Mitigate them with vertical slices and an early physical-device locked-screen check before committing to the final service boundary or power strategy.

## Key Findings

### Recommended Stack

Measured local results support the recommendation: ESP-IDF **6.1.1**, Flutter **3.50.1** / Dart **3.14.0**, Android SDK 36/JDK 17, and `espressif/button ^4.2.3` successfully resolved and reconfigured for target `esp32`. `esptool` identified **ESP32-D0WDQ6 revision 1.0**; this confirms the chip target, not the board pinout. No target Android phone was available to validate screen-off behavior.

**Core technologies:**

- ESP-IDF 6.1.1 + bundled NimBLE peripheral/GATT server — matches the installed SDK and BLE-only scope; avoid Bluedroid/Classic Audio.
- `espressif/button ^4.2.3` — verified against this SDK/target for debouncing and gesture events; commit the resolved lock file.
- Flutter 3.50.1 with `flutter_reactive_ble ^5.6.0` — Android UI plus service-filtered BLE scan, connection, and notification subscription.
- `audio_service ^0.18.19` + `just_audio ^0.10.6` — one authoritative player/media session for bundled assets, lock-screen controls, and notification state.
- `permission_handler ^13.0.2` — explicit Android Nearby Devices permission flow; it does not replace manifest/foreground-service declarations.

Use Android `mediaPlayback` and justified `connectedDevice` foreground-service types, with `BLUETOOTH_SCAN`/`BLUETOOTH_CONNECT` runtime permissions. Recheck package versions immediately before implementation.

### Expected Features

**Must have (table stakes):**

- One button with five distinct documented gestures: play/pause, next, previous, stop, and shuffle. Three mappings are proposed; choose the remaining two through timing/false-positive tests.
- Custom UUID-filtered BLE discovery, connection, notify-only one-byte command subscription, and visible connection status.
- Fixed, small, rights-cleared bundled playlist that works without network, account, folder setup, or `INTERNET` playback access.
- Correct command-to-playback mapping, current track/status/song list, Android media notification, and locked-screen controls.
- Bounded automatic reconnect and re-subscription after drops/idle; the first press while disconnected may be lost, and the second press after reconnection is acceptable.
- Reproducible firmware/app setup, `PROTOCOL.md`, dependency locks, asset provenance, and a physical acceptance checklist.

**Should have (differentiators):**

- Deliberate, discoverable one-button gesture language and clear reconnecting state.
- Fast normal connected response, targeting roughly one second, measured separately from recovery latency.

**Defer (v2+ or conditional v1.x):**

- Optional LED playback feedback, battery hardware profile/low-power tuning, target-OEM guidance, and CI build/lint checks; pursue only after core validation and user approval.
- Configurable playlists/folders, gesture remapping, richer library UI, multiple phones/buttons, iOS, cloud, accounts, and streaming are out of scope for v1.

### Architecture Approach

Keep `PROTOCOL.md` canonical and mirror/test its UUID and byte constants in both language implementations. Firmware separates button input, protocol constants, and NimBLE advertising/GATT; Android has one `BleSessionManager`/control service, command router, playback engine, and media session; Flutter only renders onboarding/status/song-list state and sends explicit UI actions. Notifications are non-durable and idempotently routed; stale callbacks are rejected by connection generation, subscriptions are reset on disconnect, and only the service owns reconnect timing.

**Major components:**

1. `firmware/button` — GPIO, debounce, gesture timing, semantic command emission.
2. `firmware/ble` — advertising, GATT service, subscription tracking, notification, post-disconnect advertising.
3. Android `XmasControlService`/`BleSessionManager` — permissions, one GATT lifecycle, bounded reconnect, command serialization.
4. `PlaybackEngine` + `MediaSession` — bundled playlist, all five actions, audio focus, metadata, notification/lock-screen controls.
5. Flutter UI/bridge — permission onboarding and immutable connection/playback snapshots; never a second BLE connection or player.

### Critical Pitfalls

1. **Gesture arbitration delays short press** — measure press-to-audible latency and false positives; select timings from real switch trials.
2. **Peripheral stops advertising or sends before subscription** — track CCCD/subscription state, restart advertising on every disconnect, and notify only after discovery/subscription.
3. **Background behavior is tested only on a pre-permitted phone** — clean-install Android permission tests and perform the early locked-screen check on the actual target phone.
4. **BLE/audio ownership is split across widgets/services** — use one service-owned state machine, player, media session, and reconnect loop; inspect the merged manifest and foreground types.
5. **Power or assets undermine the demo** — do not assume sleep preserves BLE; establish reliable USB power first, and verify a fresh release APK plays every licensed asset in airplane mode.

## Implications for Roadmap

### Phase 1: Hardware, Protocol, and Observable Peripheral
**Rationale:** Hardware identity is only partially measured; pinout, button circuit, power source, UUIDs, and gesture contract are dependencies for everything else.  
**Delivers:** `esp32` project pinned to IDF 6.1.1, safe GPIO confirmation, `PROTOCOL.md`, NimBLE advertising/GATT service, scanner-visible notifications, and setup docs.  
**Addresses:** Shared protocol, reproducible setup, hardware/protocol baseline.  
**Avoids:** Wrong GPIO/board assumptions, stale BLE examples, missing post-disconnect advertising, and protocol drift.

### Phase 2: One-Button Input and BLE Recovery
**Rationale:** Prove all five commands and the latency budget before coupling to Android playback.  
**Delivers:** Debounced gesture recognizer, five bytes, physical timing trials, subscription-aware notification path, disconnect/re-advertise tests.  
**Addresses:** Five-command one-button interaction and normal/recovery BLE behavior.  
**Avoids:** Ambiguous gestures, delayed short press, duplicate notifications, and sending during unsubscribed states.

### Phase 3: Android Connection Spine and Early Locked-Screen Spike
**Rationale:** Android lifecycle is the highest-risk integration and must be tested on the real target phone before the app is built around assumptions.  
**Delivers:** Clean-install permission/onboarding flow, one control service/`BleSessionManager`, service-filtered scan, subscription, reconnect state, Flutter status UI, and an early screen-off/locked-screen notification check.  
**Addresses:** BLE discovery, permission handling, connection status, and accepted second-press recovery behavior.  
**Avoids:** Activity-owned BLE, unbounded reconnect loops, wrong foreground-service types, and false process-death guarantees.

### Phase 4: Offline Playback and Media Session
**Rationale:** Once command delivery and service lifecycle are observable, add the player as the same service-owned command path.  
**Delivers:** Rights-cleared small asset playlist, all five playback actions, current metadata, media notification, lock-screen controls, and static song list.  
**Addresses:** Offline playback and complete v1 media UX.  
**Avoids:** Missing release assets, duplicate player/notification owners, incorrect stop/shuffle semantics, and unnecessary network permissions.

### Phase 5: Resilience and Physical Acceptance
**Rationale:** Recovery and OEM behavior require the complete vertical slice and cannot be inferred from emulators or package docs.  
**Delivers:** Matrix for Bluetooth toggle, out-of-range return, extended idle, task dismissal/process loss, permission revoke/regrant, screen off, and target-phone behavior; documented outcome and demo checklist.  
**Addresses:** Automatic recovery, physical verification, and reproducible holiday demo.  
**Avoids:** Claiming silent process resurrection, OEM assumptions, battery regressions, and unverified first-press behavior.

### Phase 6: Optional v1.x Experiments (Approval Required)
**Rationale:** These are valuable only after the core loop is validated and require explicit product approval.  
**Delivers:** Path-filtered CI, evidence-based OEM note, measured battery profile, or a versioned reverse LED/state protocol as individually approved.  
**Avoids:** Premature sleep that drops BLE, invasive battery-exemption UX, and protocol expansion without a need.

### Phase Ordering Rationale

- Protocol and physical pin/power facts precede all integration; the chip result is measured, while board wiring remains open.
- Firmware input and BLE recovery can be tested independently before Android complexity.
- The real-device locked-screen check comes before finalizing service integration because platform documentation cannot prove OEM/package behavior.
- Playback and media controls share one service owner, then resilience tests validate the whole path.
- Optional battery, LED, CI, and OEM work remains conditional and must not delay the holiday demo.

### Research Flags

Phases likely needing deeper research during planning:

- **Phase 1:** Board model, safe GPIO, switch electrical behavior, power source, and final gesture timing are unresolved.
- **Phase 3:** Validate the exact Flutter BLE/audio/native-service integration, merged manifest, Android API-level rules, and target OEM locked-screen behavior.
- **Phase 5:** Process death, Bluetooth toggle, idle, and OEM recovery outcomes are empirical.
- **Phase 6:** Research only if the user approves battery/LED/CI/OEM scope.

Phases with standard patterns (skip research-phase):

- **Phase 2:** NimBLE GATT peripheral, debounced GPIO, and notification subscription patterns are well documented, though physical timing still needs tests.
- **Phase 4:** Local Flutter assets and standard media-session transport are established patterns once Phase 3 proves the service boundary.

## Confidence Assessment

| Area | Confidence | Notes |
|---|---|---|
| Stack | HIGH | Local SDK/package resolution and official package/platform documentation support the selected versions; screen-off persistence remains MEDIUM until real-phone testing. |
| Features | HIGH | Scope and key decisions are explicit in `PROJECT.md`/PRD; release slicing is MEDIUM pending physical validation. |
| Architecture | HIGH | Ownership/state boundaries follow official Android, NimBLE, and audio-service patterns; exact Flutter/native service sharing is a validation spike. |
| Pitfalls | HIGH | Platform pitfalls are grounded in Android/ESP-IDF docs; OEM-specific behavior is MEDIUM until target-phone evidence. |

**Overall confidence:** HIGH for the recommended direction; MEDIUM for end-to-end behavioral claims.

### Gaps to Address

- Identify the development-board model, button GPIO/electrical circuit, enclosure assumptions, and reliable demo power source.
- Name and obtain the target Android phone; run the clean-install, screen-off, idle, reconnect, and task-dismissal checks early.
- Decide previous/shuffle gesture mappings from measured timing and accessibility/false-positive trials.
- Confirm the exact merged Android manifest and whether one service can cleanly own BLE plus `audio_service` media playback.
- Obtain rights-cleared audio and record provenance before bundling; verify a fresh release APK in airplane mode.
- Do not promise battery life, process-death recovery, or first-press delivery during reconnection until measured.

## Sources

### Primary documentation and registries

- [ESP-IDF v6.1.1 NimBLE peripheral example](https://github.com/espressif/esp-idf/tree/v6.1.1/examples/bluetooth/nimble/bleprph) — GATT server, advertising, notifications, ESP32 baseline.
- [Espressif Button 4.2.3](https://components.espressif.com/components/espressif/button/versions/4.2.3/readme) — GPIO events and compatibility.
- [`flutter_reactive_ble` 5.6.0](https://pub.dev/packages/flutter_reactive_ble), [`just_audio` 0.10.6](https://pub.dev/packages/just_audio), [`audio_service` 0.18.19](https://pub.dev/packages/audio_service), [`permission_handler` 13.0.2](https://pub.dev/packages/permission_handler) — package APIs and version constraints.
- [Android Bluetooth permissions](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions), [BLE background communication](https://developer.android.com/develop/connectivity/bluetooth/ble/background), and [foreground-service types](https://developer.android.com/develop/background-work/services/fgs/service-types) — runtime permission and lifecycle requirements.
- [Android Media3 background playback](https://developer.android.com/media/media3/session/background-playback) — media-session/foreground playback model.
- [ESP-IDF sleep modes](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-reference/system/sleep_modes.html) — sleep does not retain ordinary BLE connections.
- [Flutter assets](https://docs.flutter.dev/ui/assets/assets-and-images) — release asset bundling behavior.

### Local evidence

- ESP-IDF 6.1.1, Flutter 3.50.1/Dart 3.14.0, Android SDK 36/JDK 17, and esptool 5.6.0 outputs on 2026-11-25.
- Local temporary project successfully resolved `espressif/button ^4.2.3` for target `esp32`.
- Physical probe identified ESP32-D0WDQ6 rev 1.0 via CP2102; board model and GPIO remain unverified.

---
*Research completed: 2026-11-25*  
*Ready for roadmap: yes*
