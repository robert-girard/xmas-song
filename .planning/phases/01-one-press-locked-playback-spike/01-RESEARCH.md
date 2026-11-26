# Phase 1: One-Press Locked Playback Spike - Research

**Researched:** 2026-11-25
**Domain:** ESP-IDF NimBLE peripheral plus Flutter/Android locked-screen offline playback
**Confidence:** MEDIUM — firmware and Android/package APIs are sourced; the target handset, Android API level, and the paused-but-ready foreground-service behavior require the required physical spike.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### the agent's Discretion

- Select the specific licensed recordings and the timing capture method. Choose the library and service details based on Phase 1 device compatibility and the physical test.

### Deferred Ideas (OUT OF SCOPE)

- Replace the temporary BOOT input with a separate momentary switch after the first playback test. Confirm the permanent GPIO and wiring before that change.
</user_constraints>

## Summary

Build the spike around one Android readiness service. After the visible permission grant, the service confirms foreground promotion, scans for the NimBLE service UUID, and confirms the GATT subscription. It prepares a packaged recording silently in Android `MediaPlayer` so the first press can start playback immediately. See [SKELETON.md](SKELETON.md) and [Android BLE background communication](https://developer.android.com/develop/connectivity/bluetooth/ble/background).

Use advertising data for Flags plus the complete 128-bit service UUID and put the recognizable, non-personal device name in the scan response. Legacy advertising is limited to 31 bytes: the installed NimBLE source defines `BLE_HCI_MAX_ADV_DATA_LEN` as `31`, and its `ble_hs_adv_fields` supports complete 128-bit UUID and name fields. [VERIFIED: /home/robert/.espressif/v6.1.1/esp-idf/components/bt/host/nimble/nimble/nimble/include/nimble/hci_common.h:311-314] [VERIFIED: /home/robert/.espressif/v6.1.1/esp-idf/components/bt/host/nimble/nimble/nimble/host/src/ble_hs_adv.c:358-375] This makes the service UUID available to a service-filtered app scan even when an active scanner must fetch the name from scan response. [VERIFIED: /home/robert/.espressif/v6.1.1/esp-idf/examples/bluetooth/nimble/bleprph/main/main.c:149-210]

**Primary recommendation:** Start foreground ownership of the BLE session during the visible setup action, preload bundled audio without playing it, and prove subscribed readiness during the 30-second locked interval. The `audio_service` 0.18.19 foreground transition requires its first playing state, so the Android readiness service must be able to start before playback. Keep one BLE connection and one playback owner. [CITED: https://pub.dev/api/archives/audio_service-0.18.19.tar.gz] [CITED: https://developer.android.com/develop/connectivity/bluetooth/ble/background]

**Observed target-device evidence (2026-11-25):** the authorized physical acceptance phone is a Samsung SM-G955W running Android 9 / API 28 on `arm64-v8a`. This was obtained by the parent agent through the explicitly authorized read-only ADB preflight; it is sufficient to select the legacy scan-permission path, not to claim locked-screen success. [VERIFIED: parent-agent approved ADB preflight, 2026-11-25]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| BOOT short press to semantic command | ESP32 firmware | — | GPIO0 input, debounce, and one-byte notification belong on the peripheral. [CITED: https://docs.espressif.com/projects/esptool/en/latest/esp32/advanced-topics/boot-mode-selection.html] |
| Custom service discovery and command subscription | Android foreground service | Flutter UI | A live GATT subscription needs a process/service owner; widgets only initiate setup and show state. [CITED: https://developer.android.com/develop/connectivity/bluetooth/ble/background] |
| Offline asset playback and transport action | Android readiness service | Android `MediaPlayer` | The same service owns CCCD completion, silent preparation, and playback. [MediaPlayer lifecycle](https://developer.android.com/reference/android/media/MediaPlayer) |
| Permission explanation, retry, and settings link | Flutter UI | Android OS | The UI explains and requests; Android owns the system permission decision. [CITED: https://developer.android.com/develop/connectivity/bluetooth/bt-permissions] |
| Locked-screen readiness experiment | Android foreground service | Physical device evidence | Background-start and OEM behavior cannot be inferred from a desktop build. [CITED: https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start] |

## Project Constraints (from AGENTS.md)

- Firmware uses ESP-IDF and NimBLE; retain the already verified Espressif Button component/version and its lock file when the component is introduced. [VERIFIED: AGENTS.md:13-15]
- Android uses Flutter and an Android foreground service; the BLE, audio, and permission package choice remains an implementation decision. [VERIFIED: AGENTS.md:14-14]
- The custom GATT command characteristic is notify-only; `PROTOCOL.md` owns generated UUIDs and the five one-byte commands, and protocol changes update both implementations in the same commit. [VERIFIED: AGENTS.md:15-15]
- Keep `firmware/` and `app/` together, commit reproducibility inputs and dependency locks, and exclude generated or machine-specific output. [VERIFIED: AGENTS.md:16-16]
- Bundle only distributable small audio assets and keep large files out of Git. [VERIFIED: AGENTS.md:17-17]
- Treat a working physical button, locked phone, and repeatable build as the demo baseline. [VERIFIED: AGENTS.md:18-18]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| BLE-01 | Scanner finds the recognizable name and custom service UUID. | Full UUID in legacy advertising; name in scan response; scanner evidence. |
| BLE-03 | App requests required Bluetooth permissions and explains denial. | API-level permission branch, explicit setup/retry/settings flow. |
| BLE-04 | App discovers by service UUID, connects, and subscribes. | Single client/subscription owner, service-filtered scan, readiness state. |
| AUD-01 | Offline small playlist has documented distribution rights. | Asset declaration/playback approach and per-track provenance gate. |
| BG-01 | Connected locked phone starts music in about one second and continues playing. | Preloaded player and user-started ready service; 30-second locked physical acceptance test. |
| DOC-01 | `PROTOCOL.md` contains matching UUIDs and command bytes. | UUID generation/representation checklist and canonical command quote below. |
</phase_requirements>

## Standard Stack

### Core

| Library / platform | Version | Purpose | Why standard for this phase |
|---|---:|---|---|
| ESP-IDF + NimBLE | 6.1.1 installed | ESP32 peripheral, GAP advertising, GATT server | The installed `bleprph` example sets GAP name/advertising fields, starts connectable advertising, and handles subscribe events. [VERIFIED: /home/robert/.espressif/v6.1.1/esp-idf/examples/bluetooth/nimble/bleprph/main/main.c:149-210] [VERIFIED: /home/robert/.espressif/v6.1.1/esp-idf/examples/bluetooth/nimble/bleprph/main/main.c:346-356] |
| `espressif/button` | `^4.2.3` | BOOT GPIO debounce/click event | The previous local SDK compatibility check recorded in project stack research resolved it for ESP-IDF 6.1.1/`esp32`; retain its lock when introduced. [VERIFIED: AGENTS.md:32-35] |
| Android `BluetoothGatt` | API 28 device path | Discovery, connection, and notification subscription | Its descriptor callback provides an observable CCCD write result. [BluetoothGattCallback](https://developer.android.com/reference/android/bluetooth/BluetoothGattCallback) |
| Android `MediaPlayer` | API 28 device path | Prepare and play packaged assets | Its prepared callback provides an observable player readiness result. [MediaPlayer](https://developer.android.com/reference/android/media/MediaPlayer) |
| `permission_handler` | `^13.0.2` | Flutter permission/status UX | Use only as the UI-facing requester; manifest declarations and OS-version behavior remain native Android responsibilities. [CITED: https://pub.dev/packages/permission_handler] [CITED: https://developer.android.com/develop/connectivity/bluetooth/bt-permissions] |

### Supporting

| Library / facility | Purpose | When to use |
|---|---|---|
| Android foreground-service declarations | Maintain the connected device session and audio lifecycle after locking. | Start from the visible setup action; inspect the merged manifest and service notification on the actual phone. [CITED: https://developer.android.com/develop/background-work/services/fgs/service-types] |
| Android Bluetooth APIs / OS permission prompt | Runtime grant for scanning and connecting on Android 12+. | Request only scan/connect, and use the legacy branch only on the actual older API level. [CITED: https://developer.android.com/develop/connectivity/bluetooth/bt-permissions] |
| ADB platform tools | Device model/API preflight and non-personal diagnostic logs. | Parent ADB preflight is available for the phone; this research shell did not expose `adb` on PATH. [VERIFIED: parent-agent approved ADB preflight, 2026-11-25] [VERIFIED: local `command -v adb` returned no path] |

### Installation

Use the selected stack above and commit `pubspec.lock` and the ESP-IDF component lock. The Flutter BLE and audio packages below were evaluated before selecting native readiness, GATT, and playback. See [SKELETON.md](SKELETON.md).

## Package Legitimacy Audit

| Package | Registry/source checked | Version evidence | Legitimacy-gate result | Disposition |
|---|---|---|---|---|
| `flutter_reactive_ble` | Official pub.dev package page | 5.6.0. [Package](https://pub.dev/packages/flutter_reactive_ble) | Registry gate was unavailable in the research shell. | Evaluated. Phase 1 uses the Android CCCD write callback. |
| `audio_service` | Official pub.dev package page | 0.18.19. [Package](https://pub.dev/packages/audio_service) | Registry gate was unavailable in the research shell. | Evaluated. Its first promotion follows playback, so Phase 1 starts the native readiness service during visible setup. |
| `just_audio` | Official pub.dev package page | 0.10.6. [Package](https://pub.dev/packages/just_audio) | Registry gate was unavailable in the research shell. | Evaluated. Phase 1 prepares and plays assets on the same native service using `MediaPlayer`. |
| `permission_handler` | Official pub.dev package page | Project stack pins `^13.0.2`. [VERIFIED: AGENTS.md:59-59] | Not run: same observed environment limit. | Use for the UI request/status path after manifest review. |

**Packages removed due to [SLOP] verdict:** none — no legitimacy verdict was produced.
**Packages flagged as suspicious [SUS]:** none — not assessed; absence of a verdict is not an approval.

## Architecture Patterns

### System Architecture Diagram

```text
BOOT short press
  -> GPIO0 verification + debounced button event
  -> one-byte notify-only GATT characteristic
  -> Android service-owned BLE subscription (ready)
  -> command validation (only the Phase 1 short-press action)
  -> prepared MediaPlayer in the readiness service
  -> audible note while display remains off

Flutter setup/status UI -> OS permission grant -> confirmed foreground promotion
                                                -> GATT and audio readiness state

Unknown byte -> ignore -> no playback state change
```

### Recommended Project Structure

```text
PROTOCOL.md                         # canonical UUID/command contract
firmware/main/                      # GPIO, protocol constants, NimBLE peripheral
app/lib/                            # Flutter setup and status UI
app/android/                        # activity bridge and readiness service
app/android/app/src/main/res/raw/   # small, rights-documented tracks
app/assets/AUDIO-LICENSES.md       # exact recording provenance
docs/phase-01-physical-evidence.md # observed test outcome
```

### Pattern 1: Pack advertising deliberately

**What:** Put Flags and the complete custom 128-bit service UUID in the advertising payload. Put the complete recognizable name in the scan-response payload, and start connectable general-discoverable advertising. [VERIFIED: /home/robert/.espressif/v6.1.1/esp-idf/components/bt/host/nimble/nimble/nimble/include/nimble/hci_common.h:311-314] [VERIFIED: /home/robert/.espressif/v6.1.1/esp-idf/examples/bluetooth/nimble/bleprph/main/main.c:196-207]

**Why:** The legacy 31-byte ceiling cannot safely accommodate Flags, a 128-bit UUID, and an arbitrarily long complete local name in one payload. With the UUID in advertising, the app can filter by service; active scanners can show the scan-response name. [VERIFIED: /home/robert/.espressif/v6.1.1/esp-idf/components/bt/host/nimble/nimble/nimble/include/nimble/hci_common.h:311-314]

**Verification:** Use a scanner to capture the advertised complete service UUID and the scan-response device name before adding Flutter. Treat a scanner that does not request scan responses as an observation limitation, not firmware failure. [ASSUMED]

### Pattern 2: BOOT is a gated temporary input

**What:** First verify that the KeeYees board's BOOT switch reaches GPIO0, then configure it as the temporary input with its normal inactive state preserved. Do not repurpose EN/reset. [VERIFIED: .planning/phases/01-one-press-locked-playback-spike/01-CONTEXT.md:19-21]

**Why:** ESP32 selects serial bootloader mode when GPIO0 is low during reset, and executes the app when GPIO0 is high. The BOOT switch must therefore be released during reset/power-up; test flashing and normal startup before treating a post-boot press as an application event. [CITED: https://docs.espressif.com/projects/esptool/en/latest/esp32/advanced-topics/boot-mode-selection.html]

### Pattern 3: Canonical protocol, no invented byte ordering

**What:** Record the two generated UUIDs from 01-01-PLAN.md in root `PROTOCOL.md`. Compare canonical strings with the Kotlin constants and the reversed NimBLE initializer bytes. The installed NimBLE macro stores the supplied initializer's bytes verbatim. [VERIFIED: /home/robert/.espressif/v6.1.1/esp-idf/components/bt/host/nimble/nimble/nimble/host/include/host/ble_uuid.h:133-139] [VERIFIED: AGENTS.md:15-15]

**Contract quote — values are locked and must be copied verbatim:**

> “0x01 | Play / pause toggle”
>
> “0x02 | Next song”
>
> “0x03 | Previous song”
>
> “0x04 | Stop”
>
> “0x05 | Shuffle on/off” [VERIFIED: PRD.md:84-98]

Phase 1 maps only the quoted play/pause byte to the short press; it still documents all five values in `PROTOCOL.md`. Unknown bytes are ignored, not queued or replayed. [VERIFIED: PRD.md:86-98] [VERIFIED: .planning/phases/01-one-press-locked-playback-spike/01-CONTEXT.md:80-82]

### Pattern 4: Ready-before-lock service spike

**What:** Start the readiness service after the visible permission grant and wait for its foreground acknowledgment. It owns one BLE client and subscription, confirms the CCCD write through `onDescriptorWrite`, and prepares one packaged recording without starting audio. It reports Ready after both CCCD success and `onPrepared`. [BluetoothGattCallback](https://developer.android.com/reference/android/bluetooth/BluetoothGattCallback) · [MediaPlayer](https://developer.android.com/reference/android/media/MediaPlayer)

**Foreground-service baseline:** The published `audio_service` 0.18.19 archive shows `AudioService.java` entering foreground from `enterPlayingState()` when playback first changes from false to true. `androidStopForegroundOnPause: false` preserves an existing foreground state. Entering the initial preloaded state does not trigger that path. Start an app-owned Android readiness foreground service from the visible setup flow with a truthful notification and the appropriate declaration. Give it a well-defined lifetime for the one BLE subscription and the preloaded playback owner. If `audio_service` handles later media playback, validate ownership and transitions without implying that its pause option establishes cold readiness. The 30-second acceptance test starts before any audio has played. [VERIFIED: published 0.18.19 archive, `AudioService.java:559-563,705-719`] [CITED: https://pub.dev/api/archives/audio_service-0.18.19.tar.gz] [CITED: https://developer.android.com/develop/connectivity/bluetooth/ble/background]

**Manifest/API rule:** The manifest must declare the foreground-service types actually used. Android 14+ requires an appropriate type and type-specific permission; `connectedDevice` has a Bluetooth runtime-prerequisite option, while `mediaPlayback` has its own foreground-service permission. Validate the merged manifest on the phone's actual Android release rather than assuming API 34+ rules apply to an older handset. [CITED: https://developer.android.com/develop/background-work/services/fgs/service-types] [CITED: https://developer.android.com/reference/android/content/pm/ServiceInfo]

**Narrow fallback, evidence-gated:** If lock loses the subscription, capture service/process/permission evidence and correct the app-owned readiness service or the lifetime of its BLE client. Use an API 28 compatible route on the target handset. `CompanionDeviceService` is an API 31+ option for future supported devices. [CITED: https://developer.android.com/develop/connectivity/bluetooth/ble/background] [CITED: https://developer.android.com/reference/android/companion/CompanionDeviceService]

### Android permission branches

| Device runtime | Manifest and runtime behavior | UI requirement |
|---|---|---|
| Android 12+ (API 31+) | Declare/request `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT`; mark scan as `neverForLocation` only if the app truthfully does not derive physical location. These are runtime Nearby Devices permissions. [CITED: https://developer.android.com/develop/connectivity/bluetooth/bt-permissions] | Explain Bluetooth use, request after **Set up**, show retry/settings on denial. |
| Android 11 and older | Retain legacy `BLUETOOTH`/`BLUETOOTH_ADMIN` declarations with max SDK 30. On Android 11 and lower, Android documents `ACCESS_FINE_LOCATION` as necessary for scanning and as a runtime grant. [CITED: https://developer.android.com/develop/connectivity/bluetooth/bt-permissions] | Explain why the older-system prompt differs; do not request Android 12 permissions blindly. |
| **Phase 1 target: Android 9 / API 28** | Request the legacy Bluetooth declarations plus runtime `ACCESS_FINE_LOCATION` for the visible setup scan; do the scan/connection while the user is present, then retain the connection rather than background-scanning. A single service-owned connection attempt is mandatory: Android documents that API 28 and lower queue subsequent connection requests. [VERIFIED: parent-agent approved ADB preflight, 2026-11-25] [CITED: https://developer.android.com/develop/connectivity/bluetooth/bt-permissions] [CITED: https://developer.android.com/develop/connectivity/bluetooth/ble/background] | The Phase 1 explanation should truthfully state that Android asks for location access on this older OS to permit Bluetooth scanning; retry/settings must address that grant. |

The app may remain compiled/targeted with the project's modern Android SDK. Keep the Android 12+ permissions in the manifest for future compatibility, bound the legacy declarations/location permission to API 30, and test the API 28 runtime branch on the actual phone. `connectedDevice` and `mediaPlayback` service-type constants were introduced in API 29; therefore API 28 acceptance proves the pre-API-29 foreground-service path, while the merged modern manifest is still a future-compatibility check rather than a target-phone requirement. [CITED: https://developer.android.com/develop/connectivity/bluetooth/bt-permissions] [CITED: https://developer.android.com/reference/android/content/pm/ServiceInfo]

## Don't Hand-Roll

| Problem | Do not build | Use instead | Why |
|---|---|---|---|
| BLE GATT host and CCCD notification handling | A raw controller/HCI protocol layer | ESP-IDF NimBLE and the installed `bleprph` architecture | It already provides advertisement field packing, GATT service definitions, and subscription events. [VERIFIED: /home/robert/.espressif/v6.1.1/esp-idf/examples/bluetooth/nimble/bleprph/main/main.c:149-210] [VERIFIED: /home/robert/.espressif/v6.1.1/esp-idf/examples/bluetooth/nimble/bleprph/main/main.c:346-356] |
| Foreground notification | Custom background scheduler | Android foreground-service notification | The visible setup starts the owner before scanning. [Android foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types) |
| Asset decoding and playlist state | Custom media decoder | Android `MediaPlayer` | The native player prepares and plays packaged raw resources. [MediaPlayer](https://developer.android.com/reference/android/media/MediaPlayer) |
| Background process resurrection | A timer, background callback, or unbounded scan loop | A user-started connected-device service for the spike; Companion Device APIs only after failed evidence | Android restricts background foreground-service starts and closes BLE on process death. [CITED: https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start] [CITED: https://developer.android.com/develop/connectivity/bluetooth/ble/background] |

## Common Pitfalls

### Pitfall 1: Treating BOOT as an ordinary switch at reset

**What goes wrong:** A pressed BOOT button puts GPIO0 low at reset and starts the serial bootloader instead of the firmware. [CITED: https://docs.espressif.com/projects/esptool/en/latest/esp32/advanced-topics/boot-mode-selection.html]

**Avoid:** Make board wiring verification and a released-during-reset normal-boot check a prerequisite, while keeping EN in its reset role. [VERIFIED: .planning/phases/01-one-press-locked-playback-spike/01-CONTEXT.md:19-21]

### Pitfall 2: Advertising name and UUID without packing discipline

**What goes wrong:** A long name plus a 128-bit UUID overflows the legacy advertisement, causing `ble_gap_adv_set_fields` failure or a non-discoverable service filter. [VERIFIED: /home/robert/.espressif/v6.1.1/esp-idf/components/bt/host/nimble/nimble/nimble/include/nimble/hci_common.h:311-314] [VERIFIED: /home/robert/.espressif/v6.1.1/esp-idf/examples/bluetooth/nimble/bleprph/main/main.c:196-210]

**Avoid:** Keep the UUID in advertising and name in scan response; test both payloads in a scanner before app integration. [ASSUMED]

### Pitfall 3: Testing permission only on one modern phone

**What goes wrong:** The app requests Android 12 Nearby Devices permissions on an older phone, or omits the older scan/location path. [CITED: https://developer.android.com/develop/connectivity/bluetooth/bt-permissions]

**Avoid:** Make model/API detection a preflight task, branch permissions at runtime, and exercise fresh-install grant, denial, retry, and settings-return paths. [VERIFIED: .planning/phases/01-one-press-locked-playback-spike/01-CONTEXT.md:21-26]

### Pitfall 4: Starting the foreground service after the phone is locked

**What goes wrong:** Android 12+ normally blocks background foreground-service starts, and a button notification cannot revive an absent GATT process. [CITED: https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start] [CITED: https://developer.android.com/develop/connectivity/bluetooth/ble/background]

**Avoid:** Start and subscribe while the setup activity is visible; lock only after `ready`; use the 30-second evidence test as the architecture gate. [VERIFIED: .planning/phases/01-one-press-locked-playback-spike/01-CONTEXT.md:34-35]

### Pitfall 5: Calling player stop before the expected press

**What goes wrong:** `MediaPlayer.stop` requires preparing the player again before starting playback. [MediaPlayer lifecycle](https://developer.android.com/reference/android/media/MediaPlayer)

**Avoid:** Leave the first track silently Prepared for the readiness test. Phase 2 covers the separate stop gesture.

### Pitfall 6: Assuming a public-domain composition makes every recording redistributable

**What goes wrong:** A recording may have rights distinct from the underlying song. [CITED: https://www.copyright.gov/engage/docs/recording.pdf]

**Avoid:** Store an asset manifest with exact source URL, recording license/public-domain claim, attribution text, duration/size, and verification date before copying any file. [VERIFIED: .planning/phases/01-one-press-locked-playback-spike/01-CONTEXT.md:28-30]

## Code Examples

### Installed NimBLE pattern to adapt

Use the local ESP-IDF 6.1.1 `bleprph` example as the direct API reference: it sets the GAP device name, assigns advertisement fields, starts general connectable advertising, and reports subscription events. Keep the Phase 1 GATT characteristic notify-only even though the example includes read/write for demonstration. [VERIFIED: /home/robert/.espressif/v6.1.1/esp-idf/examples/bluetooth/nimble/bleprph/main/main.c:149-210] [VERIFIED: /home/robert/.espressif/v6.1.1/esp-idf/examples/bluetooth/nimble/bleprph/main/gatt_svr.c:57-96]

### Android notifications and subscription pattern

Filter discovery by the advertised UUID and confirm the descriptor write on the current `BluetoothGatt` before publishing subscription readiness. Use only the **notify** value property on ESP32 with the standard CCCD. The installed NimBLE version requires a non-null value `access_cb` even when peer reads and writes are forbidden. Send the explicit one-byte payload through `ble_gatts_notify_custom`. [BluetoothGattCallback](https://developer.android.com/reference/android/bluetooth/BluetoothGattCallback) · Installed NimBLE `ble_gatts.c:512–520` and `ble_gatt.h:886–901`.

## State of the Art

| Old approach | Current approach for this phase | Impact |
|---|---|---|
| Activity/widget owns BLE stream | User-started service/handler owns the one live subscription | Makes the 30-second locked-state spike testable at the correct lifecycle boundary. [CITED: https://developer.android.com/develop/connectivity/bluetooth/ble/background] |
| Legacy Bluetooth install-time permission only | Runtime Nearby Devices scan/connect permissions on Android 12+, legacy compatibility branch below it | The phone API must be known before UX/manifest acceptance. [CITED: https://developer.android.com/develop/connectivity/bluetooth/bt-permissions] |
| Start service when a background event arrives | Establish service and GATT subscription while UI is visible | Avoids Android 12+ background-start restrictions. [CITED: https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | An active scanner will expose the scan-response local name alongside the advertising service UUID. | Advertising pattern | Scanner acceptance may need a shorter in-advertising name instead. |
| A2 | A foreground readiness service started during visible setup preserves the one subscription and preloaded player on the target handset for 30 seconds. | Ready-before-lock service spike | BG-01 remains open while the API 28 lifecycle failure is diagnosed. |
| A3 | A packaged track can remain silently Prepared through the locked interval. | Service spike | Capture a failure and correct the service-owned player lifecycle before accepting BG-01. |

## Open Questions

1. **[RESOLVED] Android service ownership and locked-idle verification.**
   - What we know: the acceptance device is Samsung SM-G955W, Android 9 / API 28, `arm64-v8a`; package and platform documentation cannot prove its OEM behavior. [VERIFIED: parent-agent approved ADB preflight, 2026-11-25] [CITED: https://developer.android.com/develop/connectivity/bluetooth/ble/background]
   - Planning resolution: [SKELETON.md](SKELETON.md) selects one foreground readiness service with native GATT and media preparation. Plans 01-01 and 01-04 require real-device verification. The observed 30-second result remains pending.

2. **[RESOLVED] BOOT GPIO verification method and prerequisite.**
   - What we know: BOOT-as-GPIO0 is a locked decision, but the board wiring is deliberately unverified. [VERIFIED: .planning/phases/01-one-press-locked-playback-spike/01-CONTEXT.md:19-21]
   - Planning resolution: [SKELETON.md](SKELETON.md) and Plan 01-01 require a matched board reference or direct measurement before configuring or flashing. The physical wiring observation remains pending.

3. **[RESOLVED] Criteria for selecting recordings.**
   - What we know: Wikimedia Commons currently labels `JingleBells-Instrumental-.ogg` with Public Domain Mark and identifies it as a 1 minute 58 second, 3.26 MB file, so it is a feasible *candidate*, not a pre-approved bundled asset. [CITED: https://commons.wikimedia.org/wiki/File:JingleBells-Instrumental-.ogg]
   - Planning resolution: [SKELETON.md](SKELETON.md) assigns one recording to Plan 01-01 and a second to Plan 01-03. Verify and record redistribution rights and the exact file hash before adding each recording. Final source selection and rights verification remain pending.

## Environment Availability

| Dependency | Required by | Available | Observed version/state | Fallback |
|---|---|---|---|---|
| Flutter SDK | App build | ✓ | Flutter 3.50.1; Dart 3.14.0. [VERIFIED: local `/home/robert/flutter/bin/flutter --version` output] | — |
| ESP-IDF activation | Firmware configure/build | ✓ | Activation script exists at `/home/robert/.espressif/tools/activate_idf_v6.1.1.sh`; `idf.py` was not on this unactivated shell PATH. [VERIFIED: local filesystem and `command -v idf.py`] | Activate the documented SDK shell first. |
| Android ADB platform-tools | Phone identification and logs | ✓ via parent preflight | One authorized device was read-only queried by the parent agent; this shell itself did not have `adb` on PATH. [VERIFIED: parent-agent approved ADB preflight, 2026-11-25] [VERIFIED: local `command -v adb` returned no path] | Make the same platform-tools installation available to the execution environment for non-personal diagnostics. |
| Target phone | BG-01 acceptance | ✓ available | Samsung SM-G955W, Android 9 / API 28, `arm64-v8a`; board is currently unplugged for the USB slot. [VERIFIED: parent-agent approved ADB preflight, 2026-11-25] | Physical locked-screen evidence is still mandatory; no emulator substitutes for acceptance. |
| Node/GSD research seam | Package legitimacy/cache tooling | ✗ | `node` command absent. [VERIFIED: local `command -v node` returned no path] | Use official pub.dev/docs evidence now; run package/lock resolution in the configured build environment. |

**Missing dependencies with no fallback:** the board and phone must be alternated on USB for their respective physical checks; target-phone access now exists, but the locked-screen behavior is not yet tested.
**Missing dependencies with fallback:** the GSD Node-based cache/legitimacy seam is unavailable; primary official package documentation supplies planning evidence but not a registry-gate verdict.

## Physical Evidence Plan

1. **Preflight complete:** one authorized read-only ADB preflight identified Samsung SM-G955W, Android 9 / API 28, `arm64-v8a`; use the API 28 legacy Bluetooth/location branch. No device serial or personal data belongs in phase evidence. [VERIFIED: parent-agent approved ADB preflight, 2026-11-25]
2. **Firmware visibility:** verify released BOOT yields normal boot, scan the board, and capture the custom UUID and recognizable name from advertising/scan response. [CITED: https://docs.espressif.com/projects/esptool/en/latest/esp32/advanced-topics/boot-mode-selection.html]
3. **Permission flow:** start from a clean install; capture grant, denial, retry, and settings-return outcomes on the actual API level. [CITED: https://developer.android.com/develop/connectivity/bluetooth/bt-permissions]
4. **Readiness:** Tap **Set up button** and wait for confirmed subscription and silently Prepared audio. Disable internet access with Bluetooth on, then lock the display for 30 seconds. Record the observed foreground readiness state. [VERIFIED: .planning/phases/01-one-press-locked-playback-spike/01-CONTEXT.md:34-35]
5. **Latency acceptance:** Use available timing equipment to measure physical BOOT actuation and the first audible note on one timeline. Record the method, elapsed time, and uncertainty where applicable. Compare the result with the agreed target of about one second.
6. **Continuation:** keep the display off after the audible start and confirm continued playback; record pass/fail, measured latency, device/API, app build, and whether the service/subscription survived. [VERIFIED: .planning/REQUIREMENTS.md:25-33]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard control |
|---|---|---|
| V2 Authentication | No for Phase 1 | The local demo does not introduce user accounts. [VERIFIED: .planning/REQUIREMENTS.md:47-52] |
| V3 Session Management | No user session; yes BLE lifecycle | Keep the service-owned BLE connection state explicit; do not mistake it for user authentication. [CITED: https://developer.android.com/develop/connectivity/bluetooth/ble/background] |
| V4 Access Control | Limited | The command characteristic remains notify-only; do not add writable control/state operations in this phase. [VERIFIED: AGENTS.md:15-15] |
| V5 Input Validation | Yes | Accept only the documented one-byte command set; ignore unknown command bytes without playback state change. [VERIFIED: PRD.md:86-98] |
| V6 Cryptography | No new cryptography | Do not invent encryption/keys; any future writable or sensitive BLE control needs its own pairing/authentication decision. [ASSUMED] |

### Known Threat Patterns

| Pattern | STRIDE | Standard mitigation |
|---|---|---|
| Nearby observers identify the household/device from advertising | Information disclosure | Use a generic recognizable name with no personal data; advertise only the required service identifier. [ASSUMED] |
| Unexpected or malformed notification changes playback | Tampering | Exact one-byte validation and unknown-byte no-op behavior. [VERIFIED: PRD.md:86-98] |
| Premature future write characteristic expands attack surface | Tampering | Keep Phase 1 characteristic notify-only; require a separate protocol/security decision before writes. [VERIFIED: AGENTS.md:15-15] |
| Unneeded location permission | Privacy | Request scan/connect only on modern Android and assert `neverForLocation` only when truthful. [CITED: https://developer.android.com/develop/connectivity/bluetooth/bt-permissions] |

## Sources

### Primary (official documentation / installed SDK)

- [Android Bluetooth permissions](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions) — modern and older permission paths.
- [Android BLE background communication](https://developer.android.com/develop/connectivity/bluetooth/ble/background) — connection/listening strategies and companion-device alternative.
- [Android foreground-service types](https://developer.android.com/develop/background-work/services/fgs/service-types) and [start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start) — service type/permission and start-time constraints.
- [ESP32 boot-mode selection](https://docs.espressif.com/projects/esptool/en/latest/esp32/advanced-topics/boot-mode-selection.html) — GPIO0/EN implications.
- Package alternatives evaluated during research. [audio_service](https://pub.dev/packages/audio_service) · [just_audio](https://pub.dev/packages/just_audio) · [flutter_reactive_ble](https://pub.dev/packages/flutter_reactive_ble)
- Installed ESP-IDF 6.1.1 source: NimBLE `bleprph`, `hci_common.h`, `ble_hs_adv.c`, `ble_uuid.h`, and `ble_gatt.h` paths cited inline.

### Secondary

- [Wikimedia Commons Jingle Bells candidate](https://commons.wikimedia.org/wiki/File:JingleBells-Instrumental-.ogg) — candidate-specific license claim; recheck at selection/download time.
- [U.S. Copyright Office: sound recordings](https://www.copyright.gov/engage/docs/recording.pdf) — composition and recording-right distinction.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH for installed ESP-IDF/official package APIs; registry-legitimacy seam unavailable.
- Architecture: MEDIUM — the ready-before-lock design is credible and sourced, but its actual idle behavior is the Phase 1 experiment.
- Pitfalls: HIGH for GPIO0, permissions, and foreground-service restrictions; MEDIUM for target-OEM/device behavior.

**Research limits:** No code, firmware flash, phone installation, personal-data inspection, or device wait was performed. The parent performed the subsequently authorized read-only phone preflight and supplied the model/API/ABI result; this shell's earlier ADB attempt was not dispatched. The Node-based GSD research-plan/classify-confidence/cache and package-legitimacy seams could not run because `node` is absent.
**Valid until:** Recheck Android and package docs immediately before implementation; target-phone evidence supersedes this research.
