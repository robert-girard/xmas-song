# Xmas Button: Product Requirements Document

| | |
|---|---|
| **Project** | xmas-song (ESP32 BLE button + Android companion app) |
| **Owner** | Robert |
| **Status** | Pre-development: toolchains installed, no application code yet |
| **Last updated** | 2026-11-25 |

---

## 1. Vision

A small, physical, battery-friendly button that sits on a shelf and controls Christmas music on a phone. Press it and the music starts; press it differently and it skips, goes back, or stops. No screen-fumbling, no voice assistant, just a satisfying tactile button that makes the house feel festive.

The project is also a learning and tinkering vehicle: it exercises ESP-IDF, BLE GATT design, Flutter, and background Android services in a single, small, finishable scope.

## 2. Goals

1. **One-press festive music.** A physical button reliably starts Christmas music on the phone.
2. **Rich control from one button.** Beyond play, the user can pause, skip to the next song, go to the previous song, stop, and toggle shuffle, using press patterns or additional buttons.
3. **Works with the screen off.** The phone keeps the BLE connection and playback alive in the background, with lock-screen and notification controls.
4. **Self-contained and reproducible.** Both sides live in one mono-repo, with a single documented protocol both sides follow.
5. **Finishable.** A working end-to-end demo before the holiday season peaks.

## 3. Non-Goals

- Streaming audio from the ESP32 to the phone, or from the phone to an ESP32 speaker (no A2DP, no I2S amp in v1).
- iOS support (Flutter keeps the door open, but v1 targets Android only).
- Cloud services, accounts, analytics, or any internet dependency.
- Multi-phone or multi-button mesh setups.
- A polished consumer UI. The app needs a status screen and a song list, nothing more.

## 4. Users and Use Cases

**Primary user:** Robert (and household members), in a home setting.

| # | Scenario |
|---|---|
| UC1 | Phone is in a pocket or on a table. User presses the button; Christmas music begins. |
| UC2 | Music is playing. User skips to the next song with a button gesture. |
| UC3 | User wants to stop the music entirely and have the system go quiet. |
| UC4 | The button was idle for hours. The first press still works, with the connection re-established automatically. |
| UC5 | Phone screen is off and locked; the button still controls playback. |

## 5. System Overview

Two components communicating over Bluetooth Low Energy:

- **ESP32 firmware (BLE peripheral / GATT server):** reads the button(s), interprets press patterns, and sends one-byte command notifications.
- **Android app (BLE central / GATT client):** scans for and connects to the device, subscribes to command notifications, and maps each command to a media-player action. The songs live on the phone.

The phone acts as the audio source and player. The ESP32 is purely a controller, which avoids classic Bluetooth audio entirely and works on any BLE-capable ESP32 variant.

## 6. Functional Requirements

### 6.1 Firmware

| ID | Requirement | Priority |
|----|-------------|----------|
| F1 | Advertise a custom BLE service with a recognizable device name so the app can find it. | Must |
| F2 | Expose a command characteristic that supports notifications; each button event sends a single command byte. | Must |
| F3 | Debounce the button and distinguish at least short press, double press, and long press. | Must |
| F4 | Resume advertising after a disconnect so the phone can reconnect without a reset. | Must |
| F5 | Support multiple physical buttons as an alternative to gesture detection. | Should |
| F6 | Accept state feedback from the app (for example, drive an LED while playing). | Could |
| F7 | Use light sleep with button wake to support battery operation. | Should |

### 6.2 Android app

| ID | Requirement | Priority |
|----|-------------|----------|
| A1 | Request and handle the required runtime Bluetooth permissions on current Android versions. | Must |
| A2 | Scan for the device by service identifier, connect, and subscribe to command notifications. | Must |
| A3 | Map commands to player actions: play/pause, next, previous, stop, shuffle toggle. | Must |
| A4 | Play bundled or locally stored Christmas songs as a playlist. | Must |
| A5 | Keep the BLE connection and playback alive with the screen off (foreground service). | Must |
| A6 | Automatically reconnect after a dropped connection. | Must |
| A7 | Show media notification and lock-screen controls. | Should |
| A8 | Display connection status and the current track. | Should |
| A9 | Let the user pick or rescan a music folder. | Could |
| A10 | Guide the user through battery-optimization exemptions on aggressive OEM builds. | Should |

### 6.3 Protocol

The protocol is deliberately tiny: one byte per event over a notify-only characteristic.

| Byte | Meaning |
|------|---------|
| 0x01 | Play / pause toggle |
| 0x02 | Next song |
| 0x03 | Previous song |
| 0x04 | Stop |
| 0x05 | Shuffle on/off |

Default single-button gesture mapping (adjustable): short press = play/pause, double press = next, long press = stop.

The service and characteristic identifiers are real, generated 128-bit UUIDs. They, together with the table above, are defined once in a `PROTOCOL.md` at the repo root, which is the single source of truth for both sides. Unknown command bytes must be ignored by the app, so the protocol can be extended later without breaking older firmware or app builds.

## 7. Non-Functional Requirements

- **Latency:** a press should produce an audible or visible reaction in well under a second in normal conditions.
- **Reliability:** reconnects should be automatic; the user should never have to restart the app to recover from a dropped link.
- **Power:** firmware should be able to idle in low-power states between presses when running from a battery.
- **Simplicity:** minimal dependencies on each side; no network access required.
- **Maintainability:** protocol changes are made in one commit across firmware, app, and `PROTOCOL.md`.

## 8. Technology Decisions

| Area | Decision | Rationale |
|------|----------|-----------|
| Firmware SDK | **ESP-IDF** (not PlatformIO) | Official SDK, built-in NimBLE host, proper power management. |
| Firmware BLE stack | **NimBLE** (BLE only) | Lower RAM than Bluedroid; classic BT not needed. |
| Button handling | Espressif's button component from the IDF Component Registry (to be verified on v6.1.1) | Provides debounce plus click, double-click and long-press events. |
| App framework | **Flutter** (Android target only) | Best VS Code experience; mature BLE and background-audio packages. |
| App BLE | `flutter_reactive_ble` (or `flutter_blue_plus`) | Well-used, supports reconnect handling. |
| App audio | `just_audio` + `audio_service` | Background playback, media notification, lock-screen controls. |
| Permissions | `permission_handler` | Runtime Bluetooth permission handling. |
| Editor | VS Code, multi-root workspace (`firmware/` and `app/`) | Each extension expects its project as a workspace root. |
| Repo | Mono-repo | One protocol, one history, atomic cross-side changes. |

## 9. Repository Layout

```
xmas-song/
├── README.md
├── PRD.md                 # this document
├── PROTOCOL.md            # UUIDs + command table (single source of truth)
├── .gitignore
├── xmas-song.code-workspace
├── firmware/              # ESP-IDF project
│   ├── CMakeLists.txt
│   ├── sdkconfig.defaults # committed
│   └── main/              # includes the protocol constants header
└── app/                   # Flutter project (Android only)
    ├── pubspec.yaml
    ├── lib/               # includes the protocol constants file
    └── android/
```

Source-control notes: ignore generated and machine-specific files (firmware build output, generated `sdkconfig`, managed components, Flutter build output, `local.properties`); commit `sdkconfig.defaults`, the IDF dependency lock file, and `pubspec.lock`. Keep large audio files out of git (use Git LFS or short royalty-free development clips).

## 10. Implementation Direction

Suggested order of work, each step leaving something demonstrable:

1. **Protocol first.** Write `PROTOCOL.md`, generate real UUIDs, and create the matching constants on each side.
2. **Firmware skeleton.** Start from a GATT server example shipped with your installed ESP-IDF version (so it matches v6.1.1), swap in the custom service and a notify-only command characteristic, and confirm it advertises using a generic BLE scanner app on the phone.
3. **Button gestures.** Add the button component and emit command bytes for short, double and long presses; verify the notifications arrive in the scanner app.
4. **App connection.** Build the Flutter app's permission flow, scan, connect and subscribe, logging received bytes on screen.
5. **Playback.** Add the playlist and map commands to player actions.
6. **Background operation.** Move BLE handling and playback into a foreground/audio service so it survives screen-off; add notification controls.
7. **Resilience.** Implement reconnect logic and test long idle periods, out-of-range, and phone restarts.
8. **Polish and power.** Add light sleep on the firmware, the optional LED feedback, and a battery-optimization hint in the app.

## 11. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| ESP-IDF v6.1.1 is newer than much available documentation and tutorials; NimBLE Kconfig names, APIs, and the button component may have changed. | Time lost on build or config errors. | Base the firmware on examples from the installed v6.1.1 tree; consult the 5.5-to-6.0 and 6.0-to-6.1 migration guides. |
| Android OEMs aggressively kill background services. | Button stops working with the screen off. | Foreground service, battery-exemption prompt, test on the real target phone early. |
| BLE connection drops while the button is idle. | First press after idle is lost. | Reconnect with auto-connect behavior; consider a short advertising wake window and verify behavior on the actual phone. |
| Android 12+ Bluetooth permission model. | Scan or connect fails silently. | Handle permissions explicitly in step 4; test on a clean install. |
| BLE is not usable in the Android emulator. | No emulator testing. | Test on a physical device throughout (already available). |
| Audio file licensing and repo size. | Legal or storage problems. | Use royalty-free or personally owned tracks; keep large files out of git. |
| Unknown ESP32 variant. | Wrong target or power assumptions. | Confirm the board variant before running `set-target`; any BLE-capable variant works for this design. |

## 12. Progress to Date

**Decisions made**
- Architecture: ESP32 as BLE controller, phone as player (no audio on the ESP32).
- Custom command protocol over a notify characteristic instead of BLE HID media keys.
- Flutter chosen over React Native; Android only.
- ESP-IDF chosen over PlatformIO and Arduino.
- Mono-repo with a multi-root VS Code workspace.

**Environment (Ubuntu 22.04)**
- [x] ESP-IDF v6.1.1 installed via the Espressif installer; `idf.py --version` reports v6.1.1. Activated per shell with the generated `activate_idf_v6.1.1.sh` script.
- [x] Flutter (stable channel) installed; `flutter doctor` reports no issues, with Android SDK 35 and two connected devices detected.
- [x] Local repo directory exists at `~/repos/xmas-song`.

**Not yet started**
- [ ] Repo scaffolding (Flutter app, ESP-IDF project, workspace file, `.gitignore`)
- [ ] `PROTOCOL.md` and UUID generation
- [ ] Firmware, app, and integration work

## 13. Open Questions

1. Which ESP32 variant(s) will be used? This determines the `set-target` value and the low-power options.
2. Single button with gestures, or multiple physical buttons?
3. Will the board be battery powered or USB powered? This affects how much effort goes into sleep modes.
4. Where do the songs come from: bundled in the app, or a folder on the phone?
5. Which phone model is the target? Some manufacturers need extra background-service handling.
6. Should the ESP32 receive state back from the app (LED feedback) in v1, or is that deferred?
7. Does CI (path-filtered firmware and app builds in the existing pipeline) belong in v1 or later?

## 14. Success Criteria

- Pressing the button starts Christmas music on the phone within about a second, with the screen off.
- All five commands (play/pause, next, previous, stop, shuffle) work from button input.
- After the phone and button are idle for an extended period, or the connection drops, a button press still works or the link recovers automatically without opening the app.
- A fresh clone of the repo can be built for both firmware and app by following the README.
