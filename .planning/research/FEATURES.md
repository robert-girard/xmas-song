# Feature Research

**Domain:** Single-purpose ESP32 BLE media controller with an offline Android player  
**Researched:** 2026-11-25  
**Confidence:** HIGH for Android/ESP-IDF platform constraints and the agreed product scope; MEDIUM for the recommended release slicing, which must be validated on the target phone and board.

## Feature Landscape

This is a household appliance-like demo, not a general music player or a programmable IoT platform. Its feature set should optimize one reliable loop: a user presses one physical button, the locked phone responds with bundled Christmas music, and control resumes without opening the app after ordinary link loss. The five transport commands are part of that loop, but the app should not become a library manager.

### Table Stakes (v1 Essentials)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| One physical button with five distinct, documented gestures | The confirmed interaction is a single household button; every advertised command must be reachable without a screen. | MEDIUM | Implement debounce and a finite gesture recognizer. Keep play/pause, next, and stop on short/double/long press; choose and document non-colliding previous and shuffle gestures after timing tests. Do not add buttons to solve gesture design. |
| BLE discovery, connection, and one-byte command subscription | The button is useless unless the phone finds its known service and receives all five commands. | MEDIUM | Scan by the custom service UUID, subscribe to the notify-only command characteristic, ignore unknown bytes, and show connection state. Android 12+ scan/connect permissions are runtime permissions. |
| Bundled, offline Christmas playlist | Music must work immediately with no account, network, or folder configuration. | MEDIUM | Ship a small rights-cleared playlist as app assets, with ordered metadata. Keep large files out of Git; the v1 playlist is fixed. |
| Correct command-to-playback mapping | A press must play/pause, next, previous, stop, or toggle shuffle predictably. | MEDIUM | Treat the protocol command table as the contract. Define edge behavior explicitly: stop clears active playback but retains the bundled playlist; shuffle state is visible in the app. |
| Screen-off playback and Android media controls | A physical controller is most valuable when the phone is locked. | HIGH | Use Android's media-session/foreground-service model through the Flutter audio stack. The media notification and lock-screen controls should expose standard transport actions and current track metadata. Test on the physical target phone. |
| Automatic recovery after a dropped link or idle | Household users should not have to relaunch the app after routine BLE loss. | HIGH | Retry scan/connect and re-subscribe with bounded backoff. The confirmed acceptance rule is that automatic recovery happens, while a first press during disconnection may be lost and the second press after reconnection must work. |
| Minimal status and read-only song list | The demo needs enough visibility to install, troubleshoot, and confirm what is playing. | LOW | Show Bluetooth permission state, connecting/connected/disconnected state, current track, shuffle state, and the bundled track list. This is diagnostic UX, not a music-library UI. |
| Reproducible setup and a shared protocol | Two independently built components need a contract and a repeatable demo. | MEDIUM | Commit `PROTOCOL.md`, SDK defaults/lock files, Flutter lock file, and build/test instructions. Changes to UUIDs or bytes update both implementations together. |

### Differentiators (Valuable, Not Needed to Prove the Core Loop)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Deliberate one-button gesture language | Makes five commands available from a pleasingly simple object rather than a remote control. | MEDIUM | Validate false-positive rate and command latency on the actual switch. Provide an in-app gesture reference, not configurable gesture remapping in v1. |
| Fast reconnect with clear recovery state | Makes the device feel appliance-like despite BLE links being transient. | HIGH | Surface “reconnecting” rather than falsely saying connected. Measure normal connected latency separately from recovery latency. |
| Optional playback LED feedback | Gives an at-a-glance physical cue that a command was accepted or music is playing. | HIGH | Defer until a reverse app-to-button state protocol and board/power behavior are designed. A local blink for a detected press is not playback-state feedback. |
| Battery-oriented hardware profile | Lets the button be placed away from a USB outlet. | HIGH | Defer as a measured hardware variant. ESP-IDF notes that ordinary light/deep sleep powers down wireless peripherals and does not retain BLE connections, so it cannot be casually combined with the connected-v1 promise. |

### Anti-Features (Intentional Exclusions)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Extra physical buttons | Avoids having to design two more gestures. | Violates the confirmed one-button interaction and adds enclosure/pinout work without validating the concept. | Define two additional distinct gestures and test their timing/usability. |
| ESP32 audio, A2DP, I2S amp, or Bluetooth Classic transport | It sounds like a self-contained speaker project. | Replaces a small BLE-control demo with a separate audio hardware, codec, power, and latency project. | Keep the phone as the audio source/player. |
| User music folders, media scanning, or a song picker | Makes the app look like a general music player. | Adds storage permissions, indexing, empty-library states, and support burden; conflicts with instant offline use. | Use the fixed, bundled rights-cleared playlist. |
| Accounts, cloud sync, streaming, analytics, or runtime network access | Familiar consumer-app conveniences. | Adds privacy, failure modes, and setup to a household demo whose defining property is offline operation. | Package assets and store only local playback preferences. |
| iOS or multi-phone/multi-button support | Broadens who can use it. | Multiplies background-BLE and product-state cases before Android core behavior is proven. | Support one named Android installation and one button in v1. |
| Per-OEM battery-optimization automation | It appears to guarantee background reliability. | Android/OEM settings vary and an app cannot reliably automate vendor-specific exclusions; it distracts from testing the actual target phone. | Test screen-off behavior on the target phone; provide a short, model-specific troubleshooting note only if that test reveals a need. |
| In-app battery-exemption flow in v1 | Seems like a proactive reliability fix. | It is invasive, vendor-dependent, and not justified until the physical target demonstrates service termination. | Keep a generic setup/troubleshooting note; add scoped guidance after evidence from the target device. |
| Full CI pipeline before the demo works | Gives process confidence. | Firmware hardware integration and phone-only BLE/lock-screen tests cannot be proven by a build-only workflow; it delays the core demonstration. | Make local builds and physical verification reproducible in v1, then add path-filtered firmware/app build checks in v1.x. |

## Scoping Decisions for the Roadmap

| Decision area | v1 decision | Deferred / conditional work | Why |
|---------------|-------------|----------------------------|-----|
| Power and battery use | Establish the board's actual power source and ship/test the demo on reliable USB power. Record idle current only as a baseline; make no battery-life promise. | A battery hardware profile, current budget, modem-sleep configuration, and long-idle measurement after the connected demo is stable. | Full light/deep sleep drops BLE on ESP32 unless a connection-preserving power-management approach is specifically designed and measured. USB removes a major variable from the first screen-off demo. |
| Media UX | Current track, connection state, shuffle state, static song list, foreground media notification, and lock-screen transport controls. | Playlist editor, folders, search, artwork-heavy browsing, remembering arbitrary library position. | This gives visibility and standard Android controls while keeping playback entirely offline and deterministic. |
| OEM background guidance | Test the named target phone under screen-off, idle, out-of-range, and reconnect scenarios. Include generic troubleshooting documentation only. | Model-specific battery-optimization instructions if the physical test proves the target OEM kills the service. | Reliability must be demonstrated on the phone that matters, not inferred from generic OEM advice. |
| LED | No playback-state LED in v1. At most, a local development-only press/advertising diagnostic indicator. | Define bidirectional state characteristic, LED semantics, and measured power impact after v1. | A meaningful playing/paused LED requires app state feedback, which is outside the notify-only command contract. |
| CI | No hosted CI is required for the v1 demo; require documented clean local firmware and app builds plus a physical verification checklist. | Add path-filtered ESP-IDF and Flutter build/lint jobs once the structure and toolchain versions settle. | A build job will not validate BLE recovery, lock-screen behavior, gestures, or real audio. It should automate stable checks, not substitute for the device demo. |

## Feature Dependencies

```text
Board pinout + power-source confirmation
    └──requires──> Button input and gesture recognizer
                           └──requires──> One-byte BLE command notification
                                                  └──requires──> Android permission flow
                                                                         └──requires──> Scan/connect/subscribe
                                                                                                └──requires──> Playback command mapping
                                                                                                                       └──requires──> Screen-off acceptance test

Bundled asset playlist ──requires──> Audio-player queue and metadata
Audio-player queue + MediaSession/foreground service ──enables──> notification and lock-screen controls
Reconnect state machine ──requires──> Scan/connect/subscribe and persisted device identity
Playback-state LED ──requires──> a new app-to-device state contract
Battery light/deep sleep ──conflicts──> a continuously maintained BLE connection
```

### Dependency Notes

- **Gesture recognition requires confirmed hardware:** the development-board button GPIO, pull configuration, and switch behavior determine reliable debounce and wake behavior.
- **BLE events require the protocol first:** firmware and app can be independently tested against a scanner/logging screen only when UUIDs and byte meanings are fixed in `PROTOCOL.md`.
- **Screen-off control requires both service lifecycles:** the media service keeps audio and controls visible; BLE connection/recovery must be observed in the same locked-phone test rather than presumed from foreground audio alone.
- **Reconnection does not make a disconnected press deliverable:** v1 should reconnect automatically, then accept the confirmed second press. Do not fabricate queued press delivery without a designed acknowledgement and buffering protocol.
- **Battery sleep conflicts with connected operation:** ESP-IDF documents that BLE links are not maintained through light or deep sleep. Treat battery optimization as a later, measured design—not a checkbox beside the initial connection loop.

## MVP Definition

### Launch With (v1)

- [ ] **Hardware and protocol baseline** — confirmed ESP32 board/button/power source; one documented GATT service, notify command characteristic, and the five-byte command table.
- [ ] **One-button five-command input** — debounced, deterministic gestures with timing selected from physical tests; all five actions are reachable from the single button.
- [ ] **Offline Android player** — a small bundled, rights-cleared playlist and command mappings for play/pause, next, previous, stop, and shuffle.
- [ ] **BLE control on a locked phone** — Android permission flow, service-UUID scanning, connection, notification subscription, current state UI, and physical screen-off testing.
- [ ] **Media-session UX** — current-track metadata, media notification, and lock-screen transport controls.
- [ ] **Automatic recovery** — reconnect/resubscribe after dropped link and extended idle; demonstrate the accepted second press after automatic reconnection.
- [ ] **Reproducible demo** — protocol/setup/build documentation, dependency locks, licensing record for included audio, and a manual physical acceptance checklist.

### Add After Validation (v1.x)

- [ ] **Path-filtered CI builds and linting** — add when both project skeletons build reproducibly in a clean local environment; retain device checks as manual acceptance tests.
- [ ] **Target-phone OEM guidance** — add a concise, evidence-based troubleshooting entry only if screen-off testing shows that the target phone requires a battery-management setting.
- [ ] **Measured battery profile** — pursue only if the intended deployment is actually battery powered; define standby/reconnect targets and compare modem-sleep/advertising strategies on the real board.
- [ ] **LED feedback** — add only with a deliberately versioned reverse state characteristic and a physical/power test plan.

### Future Consideration (v2+)

- [ ] **Configurable playlist or local music folders** — defer until the fixed asset playlist has been proven insufficient; this changes the product into a media-library app.
- [ ] **Gesture configuration and richer music UI** — defer until household use demonstrates that the fixed language is a problem; avoid creating a settings-heavy remote.
- [ ] **Multiple phones, multiple buttons, iOS, or cloud features** — defer because each expands connection ownership, background behavior, and support surface beyond the single-home demo.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Shared BLE protocol and one-byte notifications | HIGH | MEDIUM | P1 |
| Single-button five-command gestures | HIGH | MEDIUM | P1 |
| Bundled offline playlist and transport mapping | HIGH | MEDIUM | P1 |
| Locked-screen/background media controls | HIGH | HIGH | P1 |
| Reconnect and accepted second-press recovery | HIGH | HIGH | P1 |
| Status/current-track/static song list | MEDIUM | LOW | P1 |
| Reproducible setup and physical verification checklist | HIGH | MEDIUM | P1 |
| CI build/lint checks | MEDIUM | MEDIUM | P2 |
| Target-phone OEM guidance | MEDIUM | LOW | P2 |
| Measured battery hardware profile | MEDIUM | HIGH | P2 |
| Playback-state LED | LOW | HIGH | P2 |
| Folder scanning and playlist editing | LOW | HIGH | P3 |
| Extra buttons, iOS, cloud, multi-device support | LOW | HIGH | P3 |

**Priority key:** P1 = must have for the working holiday demo; P2 = add only after the core loop validates; P3 = future or intentionally excluded from this product shape.

## Evidence and Sources

- **HIGH — [Android Bluetooth permissions](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions):** Android 12+ scanning and connection use runtime Nearby Devices permissions; this makes an explicit permission state essential to v1.
- **HIGH — [Android: connect to a GATT server](https://developer.android.com/develop/connectivity/bluetooth/ble/connect-gatt-server) and [BluetoothDevice API](https://developer.android.com/reference/android/bluetooth/BluetoothDevice):** Android's GATT client flow is asynchronous; `autoConnect` is only an availability/reconnection mechanism and must be paired with real lifecycle testing.
- **HIGH — [Android Media3 background playback](https://developer.android.com/media/media3/session/background-playback) and [MediaSessionService reference](https://developer.android.com/reference/androidx/media3/session/MediaSessionService):** a media session service supplies the foreground media notification and background-playback model; stopped/idle service lifecycle must be considered in screen-off testing.
- **HIGH — [ESP-IDF 6.1 ESP32 sleep modes](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-reference/system/sleep_modes.html):** light/deep sleep does not retain Bluetooth connections; connection-preserving power work therefore requires a separate, measured design.
- **HIGH — [PROJECT.md](../PROJECT.md) and [PRD.md](../../PRD.md):** authoritative project decisions: one button for five commands, bundled offline playlist, Android-only phone playback, and acceptance of a second press after automatic reconnection.

## Research Gaps to Resolve During Delivery

- Confirm the exact development-board pinout, button electrical configuration, intended USB/battery power source, and physical enclosure before committing gesture timing or a battery plan.
- Test the selected Flutter BLE and audio packages together on the named phone; Android platform documentation verifies the required platform behavior, not package integration quality.
- Decide the two remaining gesture mappings from physical testing, considering accessibility and accidental activation.
- Establish permissible audio assets and their distribution/license record before bundling them.

---
*Feature research for: Xmas Button*  
*Researched: 2026-11-25*
