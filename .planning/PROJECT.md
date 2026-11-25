# Xmas Button

## What This Is

Xmas Button is a physical ESP32 button and an Android companion app for Robert and the household. A press starts Christmas music from a small playlist bundled with the app, including while the phone is locked. The project is a holiday demo and a hands-on way to learn ESP-IDF, BLE GATT, Flutter, and Android background services.

## Core Value

A single physical button starts Christmas music on a locked Android phone in about one second under normal connected conditions.

## Requirements

### Validated

No product capabilities have shipped or been validated yet.

### Active

- [ ] Start or pause playback, skip forward or back, stop playback, and toggle shuffle using distinct gestures on one physical button.
- [ ] Play a small, bundled offline playlist without requiring network access, an account, or music-folder setup.
- [ ] Discover the button by BLE service identifier, connect, and subscribe to one-byte commands after handling Android Bluetooth permissions.
- [ ] Keep BLE control and playback available with the phone locked and the screen off. Provide connection and current-track status, a simple song list, and Android media controls.
- [ ] Reconnect automatically after a dropped link or extended idle. When the initial press occurs while disconnected, a second press after reconnection is acceptable.
- [ ] Document the shared protocol and provide reproducible setup, build, and verification instructions for the firmware and app.

### Out of Scope

- ESP32 audio playback or transport, including Bluetooth Classic audio and I2S. The phone stores and plays the music.
- iOS, cloud services, accounts, analytics, and runtime internet access. The first release targets one offline Android installation.
- Multiple physical buttons, multiple connected phones, and mesh operation. The five commands use one household button.
- Music-folder selection and rescanning. The bundled playlist is the v1 music source.
- Consumer UI polish. A simple status and song list are sufficient for the demo.

## Context

- [PRD.md](../PRD.md) records the product vision, original priorities, and initial implementation direction. The decisions in this brief capture the subsequent project discussion.
- The repository is greenfield. The PRD records an Ubuntu 22.04 development environment with ESP-IDF v6.1.1 and Flutter stable, plus an available physical Android device. A local serial probe identified the connected chip as an ESP32-D0WDQ6 revision 1.0, so the ESP-IDF target is `esp32`. Phase 1 will confirm the development-board pinout, button GPIO, target phone, and supported build configuration.
- The default gestures are short press for play/pause, double press for next, and long press for stop. Phase 1 will define distinct gestures for previous and shuffle and check that gesture timing supports the response target.
- Battery-friendly idle is a design goal. Confirm the demo power source and measure feasible low-power behavior on the development board. LED feedback, CI, and OEM-specific battery-optimization guidance still need a scope decision.
- Verify BLE, playback, and recovery on a physical phone. Include screen-off control, extended idle, and recovery from a dropped link in the demo checks.

## Constraints

- **Firmware** uses ESP-IDF and NimBLE. Verify that Espressif's button component works with the installed SDK before depending on it.
- **Android** uses Flutter and an Android foreground service for background operation. The PRD proposes `flutter_reactive_ble` or `flutter_blue_plus` for BLE, `just_audio` and `audio_service` for playback, and `permission_handler` for permissions. Package selection and compatibility remain implementation decisions.
- **Protocol** uses a custom BLE GATT service and a notify-only command characteristic. `PROTOCOL.md` defines the generated 128-bit UUIDs and five one-byte commands. The app ignores unknown bytes. Update the protocol and both implementations in the same commit when the contract changes.
- **Repository** keeps `firmware/` and `app/` together with a VS Code multi-root workspace. Commit reproducibility inputs and dependency lock files. Keep generated files and machine-specific configuration out of version control.
- **Audio assets** must be suitable for distribution with the app. Use small tracks with appropriate rights for the bundled playlist and keep large audio files out of Git.
- **Schedule** prioritizes a working end-to-end holiday demo. A physical button, a locked phone, and a repeatable build are the demonstration baseline.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| ESP32 BLE peripheral and Android BLE central | The phone owns playback and the hardware can focus on capturing input. | Pending validation |
| Custom GATT commands | The two components share an explicit contract for all five actions. | Pending validation |
| One physical button in v1 | The hardware keeps the intended single-button interaction. | Confirmed in project discussion |
| Second press acceptable after automatic reconnection | The user can resume control without reopening the app. | Confirmed in project discussion |
| Small bundled offline playlist | Playback works immediately after setup and has no runtime network dependency. | Confirmed in project discussion |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition**

1. Move invalidated requirements to Out of Scope and record the reason.
2. Move verified requirements to Validated and reference the phase.
3. Add newly identified requirements to Active.
4. Record decisions and update the project description if it changes.

**After each milestone**

1. Review every section and confirm that the core value still reflects the priority.
2. Recheck the scope exclusions and update the context with the current state.

---
*Last updated 2026-11-25 during initialization.*
