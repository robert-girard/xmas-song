<!-- GSD:project-start source:PROJECT.md -->

## Project

**Xmas Button**

Xmas Button is a physical ESP32 button and an Android companion app for Robert and the household. A press starts Christmas music from a small playlist bundled with the app, including while the phone is locked. The project is a holiday demo and a hands-on way to learn ESP-IDF, BLE GATT, Flutter, and Android background services.

**Core Value:** A single physical button starts Christmas music on a locked Android phone in about one second under normal connected conditions.

### Constraints

- **Firmware** uses ESP-IDF and NimBLE. Verify that Espressif's button component works with the installed SDK before depending on it.
- **Android** uses Flutter and an Android foreground service for background operation. The PRD proposes `flutter_reactive_ble` or `flutter_blue_plus` for BLE, `just_audio` and `audio_service` for playback, and `permission_handler` for permissions. Package selection and compatibility remain implementation decisions.
- **Protocol** uses a custom BLE GATT service and a notify-only command characteristic. `PROTOCOL.md` defines the generated 128-bit UUIDs and five one-byte commands. The app ignores unknown bytes. Update the protocol and both implementations in the same commit when the contract changes.
- **Repository** keeps `firmware/` and `app/` together with a VS Code multi-root workspace. Commit reproducibility inputs and dependency lock files. Keep generated files and machine-specific configuration out of version control.
- **Audio assets** must be suitable for distribution with the app. Use small tracks with appropriate rights for the bundled playlist and keep large audio files out of Git.
- **Schedule** prioritizes a working end-to-end holiday demo. A physical button, a locked phone, and a repeatable build are the demonstration baseline.

<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->

## Technology Stack

## Recommendation

## Local Validation (not an assumption)

| Check | Result | Consequence |
|---|---|---|
| ESP-IDF | `idf.py --version` reported **ESP-IDF v6.1.1**; the installed header defines 6.1.1. | Pin the firmware project to this installed SDK for the first demo. |
| BLE baseline | The installed tree contains the `examples/bluetooth/nimble/bleprph` peripheral example, whose README explicitly covers a GATT server, advertising, subscriptions, notifications, and ESP32 target support. | Fork its structure rather than a stale tutorial or a Bluedroid example. |
| Button component | A throwaway `esp32` project, configured with this IDF, successfully ran `idf.py add-dependency 'espressif/button^4.2.3'` and `idf.py reconfigure`. `dependencies.lock` resolved `espressif/button` 4.2.3. | `espressif/button ^4.2.3` is compatible with this exact SDK/target at configuration time. Commit the generated lock file. |
| Board silicon | Parent physical check: `esptool v5.6.0 --no-stub chip-id` identified **ESP32-D0WDQ6 rev v1.0**, 40 MHz, through `/dev/ttyUSB0`; udev identifies its bridge as CP2102. | Use `idf.py set-target esp32`. The development-board model, button wiring, and safe GPIO are still unverified. |
| Flutter | `/home/robert/flutter/bin/flutter --version` reported **Flutter 3.50.1**, Dart 3.14.0. Flutter Doctor found Android platform `android-36`, build-tools 35.0.0, and JDK 17. | This readily meets the selected packages' Flutter/Dart SDK floors. Add `/home/robert/flutter/bin` to the development PATH. |
| Phone | Flutter Doctor did not expose an Android device in this session. | The physical Android smoke test remains a Phase 1 gate; no claim is made here that a particular phone/OEM survives screen-off operation. |

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|---|---:|---|---|
| ESP-IDF | 6.1.1 (installed) | Firmware build, FreeRTOS, GPIO, power management, BLE integration | It is the project decision and locally installed, and it includes a maintained NimBLE peripheral example that matches the custom notify-only GATT design. |
| ESP-IDF NimBLE host | bundled with IDF 6.1.1 | BLE peripheral/GATT server | BLE-only is the correct scope: it avoids allocating/maintaining Classic Bluetooth audio functionality that v1 explicitly excludes. Enable the peripheral and GATT-server roles only. |
| Espressif Button | `^4.2.3` | GPIO debouncing plus click/double-click/long-press events | The official registry component supports GPIO buttons and power-save mode, and was locally resolved against IDF 6.1.1 / `esp32`. It lets firmware map gestures to the five protocol bytes without creating an ISR-driven gesture state machine first. |
| Flutter | 3.50.1 / Dart 3.14.0 (installed) | Android app UI and orchestration | The installed stable toolchain satisfies every selected package's published SDK constraint and keeps the simple status/song UI in Dart. Android is the only release target for v1. |
| Android app platform | compile/target SDK 36; min SDK chosen by generated Flutter template after device check | Android BLE, notification, media session, foreground-service integration | SDK 36 is locally installed. Android 14+ foreground-service declarations are a real compatibility constraint, so start with the modern manifest rather than treating screen-off behavior as a Flutter-only concern. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---|---:|---|---|
| `flutter_reactive_ble` | `^5.6.0` | BLE scan-by-service, connection state stream, characteristic notification subscription | **Use as the sole Flutter BLE client.** Its Android setup documents the required scan/connect permissions and its connection API has an explicit timeout/state stream, which fits a reconnecting single peripheral. |
| `just_audio` | `^0.10.6` | Decode and play the short bundled asset playlist | Use inside the app's one audio handler. The playlist is local assets, so do not request `INTERNET` merely for playback. |
| `audio_service` | `^0.18.19` | Background audio, `MediaSession`, notification and lock-screen/headset controls | **Use instead of `just_audio_background`** because this app has a nontrivial command source and connection state to coordinate with playback. Its `AudioHandler` is the one authority for queue, current item, shuffle, transport state, and UI state. Release 0.18 removed the old dedicated background-isolate requirement, improving compatibility with ordinary Flutter plugins. |
| `audio_session` | transitive through the audio stack; add explicitly only when configuring focus/noisy-audio behavior | Audio focus, duck/pause behavior, becoming-noisy handling | Add as a direct dependency if the app needs to set an explicit music-session configuration after all audio plugins initialize. Do not add another background-audio package. |
| `permission_handler` | `^13.0.2` | Runtime request/status flow for Nearby Devices/Bluetooth permissions | Use at onboarding to request the exact Android runtime grants before scanning/connecting; it does not replace manifest declarations or foreground-service prerequisites. |
| `flutter_lints` | Flutter template-compatible current release | Static analysis | Keep the default Flutter lint baseline; do not make this a separate architecture decision. |

### Android Service and Permission Contract

### Development Tools

| Tool | Purpose | Notes |
|---|---|---|
| `idf.py` from `/home/robert/.espressif/tools/activate_idf_v6.1.1.sh` | Configure, build, flash, monitor, manage components | Activate this exact environment in documented firmware commands; run `idf.py set-target esp32` before first configuration. |
| `esptool` 5.6.0 | Inspect/flash the connected ESP32 | It confirmed the chip family. Use `esptool --chip esp32 -p /dev/ttyUSB0 chip-id` syntax; do not infer a board pinout from CP2102 USB identity. |
| Flutter SDK at `/home/robert/flutter` | Create/build/test Android app | Add `bin` to PATH before project setup. The local SDK has Android API 36 available; preserve `pubspec.lock`. |
| VS Code multi-root workspace | Edit both sides without confusing extensions | Roots should be `firmware/` and `app/`; commit source, lockfiles, `sdkconfig.defaults`, and protocol constants, not build products or device-specific files. |

## Installation / Project Bootstrap

# Firmware (after activating ESP-IDF 6.1.1, from firmware/)

# Flutter (from app/; place these constraints in pubspec.yaml and commit pubspec.lock)

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|---|---|---|
| `flutter_reactive_ble` | `flutter_blue_plus` 2.3.15 | Choose it only if the implementation team prefers its API and first proves the same scan/connect/notify/reconnect and screen-off path on the target phone. It is Flutter/Dart-compatible locally, but it does not remove the Android foreground-service work. Do not use both BLE packages. |
| `audio_service` + `just_audio` | `just_audio_background` | Use the simpler package only for a conventional player with no need to route an independently managed BLE command stream/reconnect state through an application audio handler. `just_audio` itself directs advanced background requirements to `audio_service`. |
| `espressif/button` | Minimal hand-written GPIO debounce/timer FSM | Use custom code only if the final wiring/power design exposes a component limitation. For the demo, the verified component is less code and already represents click/long-press semantics. |
| `connectedDevice` foreground service | Companion Device Manager / `CompanionDeviceService` | Escalate to this Android-native approach only if long-lived notification listening is unreliable or power-expensive under the target OEM. Android documents it as a preferred option for persistent peripheral listening; it adds pairing/presence design work that is unnecessary before evidence demands it. |

## What Not to Use

| Avoid | Why | Use Instead |
|---|---|---|
| Bluedroid or ESP32 Classic/A2DP audio | It is unrelated to the chosen BLE-only controller and expands RAM/configuration/debug surface. | IDF NimBLE peripheral/GATT server. |
| A generic Flutter foreground-service package alongside `audio_service` | Two independently managed foreground notifications/services risk lifecycle conflicts and obscure who owns media state. | One audio-service-centered service/manifest design, validated with the physical phone. |
| `just_audio_background` *together with* `audio_service` | Both overlap on background media/notification responsibility. | `audio_service` + `just_audio` only. |
| `espressif/button:*` | Floating component resolution defeats reproducibility and can silently change gesture/power behavior. | `espressif/button ^4.2.3` plus committed `dependencies.lock`. |
| Board-specific GPIO/low-power defaults before inspection | The chip target is known, but module/dev-board routing, bootstrapping pins, button circuitry, and power source are not. | First identify the board and wire the external button to a confirmed safe GPIO. |

## Version Compatibility

| Package / SDK | Compatible With | Evidence and Notes |
|---|---|---|
| ESP-IDF 6.1.1 + target `esp32` | `espressif/button ^4.2.3` | Component manifest requires IDF `>=4.0`; a local IDF 6.1.1 `esp32` reconfigure resolved it successfully. This validates dependency/configuration compatibility, not the physical button circuit. |
| ESP-IDF 6.1.1 | NimBLE `bleprph` example structure | The installed example supports the ESP32 target and exercises a GATT server, advertising, subscription, and notification. Copy the current local pattern rather than an API from older IDF tutorials. |
| Flutter 3.50.1 / Dart 3.14 | `flutter_reactive_ble 5.6.0` | Pub metadata requires Dart `>=2.17.0 <4.0.0` and Flutter `>=2.0.0`. Local versions satisfy both. |
| Flutter 3.50.1 / Dart 3.14 | `just_audio 0.10.6`, `audio_service 0.18.19`, `permission_handler 13.0.2` | Their Pub metadata requires Dart `^3.6.0` and Flutter at least 3.27.0, 3.27.0, and 3.24.0 respectively. Local SDK exceeds those floors. |
| `just_audio 0.10.6` | `audio_service 0.18.19` | The projects' official documentation explicitly presents this pairing for advanced background audio. Put the player behind one `AudioHandler`. |
| Android 12+ | BLE scan/connect permission flow | `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT` are runtime permissions; scanning-by-service does not need location if the app truthfully asserts it does not derive physical location. |
| Android 14+ / target SDK 34+ | long-running BLE foreground service | The foreground service needs `connectedDevice` type and permission; multiple service types can be combined. Validate the merged manifest and start timing on the installed Android API level before declaring screen-off support complete. |

## Sources

### Primary documentation and registries — HIGH confidence

- [ESP-IDF v6.1.1 NimBLE BLE Peripheral example](https://github.com/espressif/esp-idf/tree/v6.1.1/examples/bluetooth/nimble/bleprph) — starting point and current example behavior.
- [Espressif Button v4.2.3 registry entry](https://components.espressif.com/components/espressif/button/versions/4.2.3/readme) and its [component manifest](https://github.com/espressif/esp-iot-solution/blob/be7379fd47a5c787ae50b3a0d6ce6d585ef65045/components/button/idf_component.yml) — events, GPIO/power-save support, and IDF `>=4.0` requirement.
- [flutter_reactive_ble 5.6.0](https://pub.dev/packages/flutter_reactive_ble) and [Android/connection setup](https://github.com/PhilipsHue/flutter_reactive_ble/blob/master/packages/flutter_reactive_ble/README.md) — package version, permissions, scanning, and connection status.
- [just_audio 0.10.6](https://pub.dev/packages/just_audio) and [audio_service 0.18.19](https://pub.dev/packages/audio_service) — version constraints and official background-audio integration direction.
- [permission_handler 13.0.2](https://pub.dev/packages/permission_handler) — runtime permission API and compile-SDK configuration guidance.
- [Android Bluetooth permissions](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions), [BLE background communication](https://developer.android.com/develop/connectivity/bluetooth/ble/background), and [foreground-service types](https://developer.android.com/develop/background-work/services/fgs/service-types) — permission and service requirements.

### Local evidence — HIGH confidence for what was tested

- Installed tool outputs on 2026-11-25: ESP-IDF 6.1.1; Flutter 3.50.1/Dart 3.14; Android SDK platform 36; esptool 5.6.0.
- Local temporary project `/tmp/xmas-button-compat-AOH1XY`: IDF component-manager resolution/reconfigure succeeded for `espressif/button ^4.2.3` with target `esp32` and emitted a locked `espressif__button` component.
- Parent physical hardware check: ESP32-D0WDQ6 revision 1.0 at 40 MHz via CP2102. This establishes chip target only, not board model or GPIO wiring.

### Research limitation

<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->

## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `$gsd-fast` for a trivial task inline, with no subagents and no PLAN.md
- `$gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `$gsd-debug` for investigation and bug fixing
- `$gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->

## Developer Profile

> Profile not yet configured. Run `$gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
