# Phase 1: One-Press Locked Playback Spike - Context

**Gathered:** 2026-11-25

**Status:** Ready for planning

<domain>
## Phase Boundary

Prove that one physical short press starts bundled Christmas music on a connected, locked Android phone in about one second and that playback continues with the screen off. Phase 1 covers permission setup, BLE discovery and subscription, the shared protocol, offline audio, and validation of the Android service design on the demo phone. The other four gestures, full app and system media controls, and automatic reconnect have their own roadmap phases.

</domain>

<decisions>
## Implementation Decisions

### Demo hardware

- **D-01:** Use the USB-powered KeeYees ESP32 development board. A serial probe confirmed ESP32-D0WDQ6 revision 1.0, so the ESP-IDF build target is `esp32`.
- **D-02:** Use the onboard BOOT button as the temporary Phase 1 input. Verify that it is wired to GPIO0 on the actual board before configuring it. Leave EN/Reset in its existing role. Release BOOT during reset and power-up for normal startup. Move to a separate momentary switch in a later slice.
- **D-03:** Use Robert’s spare older Android phone as the primary demo and acceptance device. Identify its model and Android release/API before settling the minimum supported SDK and permission path. The phone was not visible to ADB during discussion and its compatibility is still to be tested.

### First-run setup

- **D-04:** Show a short explanation of why the app needs Bluetooth access and a **Set up button** action. Tapping it requests the required permission via the Android system prompt for the device’s OS version.
- **D-05:** If access is denied, show the next step. Allow a retry when the system can still show the prompt and offer **Open settings** when permission must be changed in Android settings. After permission is granted, start service-UUID discovery and give a clear ready indication once subscribed.

### Bundled music

- **D-06:** Source a small offline playlist of short, royalty-free recordings of familiar public-domain Christmas songs. *Jingle Bells* is the preferred example. Verify redistribution rights for each actual recording and any applicable arrangement, and record source, license, and required attribution before bundling.

### Locked-phone demo

- **D-07:** Establish the BLE connection and subscription with playback stopped. Turn off internet connectivity while keeping Bluetooth enabled, then leave the phone locked with the display off for 30 seconds.
- **D-08:** Short press the physical button and measure elapsed time from the press to the first audible note against the existing target of about one second. Confirm that audio keeps playing with the screen off. Use the observed result to confirm or revise the Android service design before Phase 2.

### Planner Discretion

- Select the specific licensed recordings and the timing capture method. Choose the library and service details based on Phase 1 device compatibility and the physical test.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents must read these before planning or implementing.**

### Approved project scope

- `.planning/PROJECT.md` defines the product goals, USB-powered MVP, and verified chip.
- `.planning/ROADMAP.md` defines the Phase 1 boundary, acceptance criteria, and phase ownership.
- `.planning/REQUIREMENTS.md` defines BLE-01, BLE-03, BLE-04, AUD-01, BG-01, and DOC-01.
- `PRD.md` §6.3 defines the five command meanings and initial gesture mappings. Use the approved roadmap for phase ordering.

### Research inputs

- `.planning/research/SUMMARY.md` summarizes risks and evidence from project research.
- `.planning/research/STACK.md` records the locally checked firmware toolchain and candidate Flutter packages.
- `.planning/research/ARCHITECTURE.md` proposes BLE, command, and audio ownership for the real-device experiment.
- `.planning/research/PITFALLS.md` identifies failure modes for first-run permissions, gestures, and screen-off operation.

### Platform references

- [Espressif ESP32 boot-mode selection](https://docs.espressif.com/projects/esptool/en/latest/esp32/advanced-topics/boot-mode-selection.html) describes GPIO0 and EN behavior during reset.
- [Flutter supported deployment platforms](https://docs.flutter.dev/reference/supported-platforms) lists supported Android API levels.
- [Android Bluetooth permissions](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions) describes BLE permission branches for recent and older Android releases.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- The locally installed ESP-IDF 6.1.1 NimBLE peripheral example at `examples/bluetooth/nimble/bleprph` is a firmware reference for discovery and notify subscription.
- The repository contains planning and research docs. Phase 1 introduces the firmware, Android app, and audio assets.

### Established Patterns

- Keep ESP-IDF firmware and the Android-only Flutter app in `firmware/` and `app/`, respectively.
- Keep the generated UUIDs and all five byte meanings in `PROTOCOL.md`, with corresponding constants on both sides. Short press exercises `0x01` play/pause in this phase.

### Integration Points

- BOOT input to the ESP32 gesture handler, then the BLE GATT notification.
- Android permission and subscription to the BLE command handler, then the bundled playlist player.

</code_context>

<specifics>
## Specific Ideas

- Identify the demo phone by its actual model and Android release/API. Its approximate age is five to six years.
- Use a familiar tune such as *Jingle Bells* so the first audible response is recognizable during the demonstration.

</specifics>

<deferred>
## Deferred Ideas

- Replace the temporary BOOT input with a separate momentary switch after the first playback test. Confirm the permanent GPIO and wiring before that change.

</deferred>

---

*Phase 1 context gathered 2026-11-25.*
