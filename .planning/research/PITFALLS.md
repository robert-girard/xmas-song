# Domain Pitfalls: ESP32 BLE Button + Locked-Phone Android Playback

**Domain:** ESP-IDF/NimBLE BLE peripheral with a Flutter Android companion and bundled offline audio  
**Researched:** 2026-11-25  
**Confidence:** HIGH for Android and ESP-IDF platform constraints; MEDIUM for device-specific OEM behavior until the target phone is tested.

## Critical Pitfalls

### Pitfall 1: Gesture recognition makes the primary action late or ambiguous

**What goes wrong:** A short press is held while firmware waits to learn whether it becomes a double press; music begins only after the double-click timeout, commonly missing the roughly one-second end-to-end expectation. Debounce, long-press, and click windows can also overlap so one physical press produces two commands or the wrong command.

**Why it happens:** Five actions are being encoded into one control, but command dispatch, gesture classification, and BLE notification are treated as independent concerns. Changing a timing constant late changes the product’s perceived latency.

**How to avoid:** Write a deterministic gesture state machine before connecting it to GATT. Set and document debounce, press-duration, multi-click window, and maximum single-press latency; emit exactly one command per completed gesture. For v1, keep short/double/long mappings and decide the remaining two commands only after a timed usability test—do not silently overload short press. Timestamp GPIO interrupt, classified gesture, notification enqueue, app receipt, and player state so the latency budget is observable.

**Warning signs:** The first press starts only after a noticeable pause; quick presses trigger both play/pause and next; a long press first toggles play; logs cannot correlate a physical press to one command byte.

**When to validate:** Firmware button phase, with real hardware, before Flutter playback is integrated; repeat end-to-end with the screen locked.

**Phase to address:** Protocol and firmware-input phase.

---

### Pitfall 2: The peripheral stops being discoverable after a failed connection or disconnect

**What goes wrong:** The phone falls out of range, Bluetooth is toggled, or the app is restarted; the ESP32 has stopped advertising, so automatic recovery never begins and the household user must reset hardware.

**Why it happens:** A GATT demo often handles only the successful-connect path. NimBLE requires the application to respond to both failed connection attempts and disconnect events. Espressif’s connection example explicitly restarts advertising in both cases. [Espressif NimBLE connection guide](https://docs.espressif.com/projects/esp-idf/en/v6.1-rc1/esp32/api-guides/ble/get-started/ble-connection.html)

**How to avoid:** Centralize peripheral state in `ADVERTISING`, `CONNECTED`, and `RECOVERING`. On GAP connect failure and disconnect, record the reason, clear connection/subscription state, and restart advertising; make restart failures visible and retry with bounded backoff. Do not notify before a connection exists and the client has enabled its CCCD. Test against the installed ESP-IDF v6.1.1 example/API rather than copying an older tutorial.

**Warning signs:** Advertisement disappears after the first phone connection; scanner sees it only after reset; reconnect works once but fails after airplane mode or an out-of-range interval; notifications return an error after reconnect.

**When to validate:** Firmware BLE skeleton, then the resilience phase with phone Bluetooth toggles, app force-stop/relaunch, 30-minute out-of-range, and peripheral reset.

**Phase to address:** Firmware BLE plus recovery phase.

---

### Pitfall 3: Android permission and pairing flow is tested only on a previously-permitted developer phone

**What goes wrong:** A clean install cannot scan or connect, presenting an empty device list or security exception; a background recovery path lacks permission after reinstall or denied Nearby Devices consent.

**Why it happens:** On Android 12+ scanning requires `BLUETOOTH_SCAN` and communicating requires `BLUETOOTH_CONNECT`; both are runtime “Nearby devices” permissions. Legacy Bluetooth permissions need API-30 caps for compatibility, and location is only appropriate when scan data derives physical location. [Android Bluetooth permissions](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions)

**How to avoid:** Make Bluetooth state and each permission an explicit UI state, request only the needed permissions from a visible activity, and show an actionable denial/retry path. Test denial, “don’t ask again,” Bluetooth-off, permission revocation, install/update, and a clean app-data reset. Evaluate `CompanionDeviceManager` for initial association only after confirming its filter and device-address constraints; it performs the setup scan but does not establish a persistent connection itself. [Android companion pairing](https://developer.android.com/develop/connectivity/bluetooth/companion-device-pairing)

**Warning signs:** It works on the development phone but not a newly installed build; scan callbacks are empty without a user-facing explanation; reconnect code receives a permission error after an update.

**When to validate:** First Android BLE connection on a physical phone, before audio/background work.

**Phase to address:** Android BLE and permission phase.

---

### Pitfall 4: BLE and playback live only in the Flutter activity or a service with the wrong foreground type

**What goes wrong:** Commands work while the app is visible but stop when the screen is locked, activity is swiped away, or memory pressure kills the process. On current Android, service startup can also fail due to an undeclared foreground-service type or permission.

**Why it happens:** A Flutter stream subscription tied to the UI is not a durable process owner. Android states that background BLE APIs require the app process to remain alive; a process kill closes the connection. From Android 14, foreground services must declare an appropriate type and type-specific permission. `mediaPlayback` is required for continued playback, while BLE device interaction may require `connectedDevice` when it is a long-running foreground-service responsibility. [Android BLE background guidance](https://developer.android.com/develop/connectivity/bluetooth/ble/background), [foreground-service types](https://developer.android.com/develop/background-work/services/fgs/service-types)

**How to avoid:** Treat the lock-screen flow as a native Android lifecycle design, not a Flutter UI feature. House player/session in the audio-service-backed Android service with `mediaPlayback`; declare the required foreground permissions and, if the selected service owns ongoing BLE work, the justified `connectedDevice` type and its prerequisites. Keep a persistent, truthful media notification. Start the service from a user-visible setup/play flow rather than assuming a background callback may always create it; Android 12+ restricts background foreground-service starts. [Background-start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start)

**Warning signs:** BLE subscription dies on screen-off; `ForegroundServiceStartNotAllowedException` or `MissingForegroundServiceTypeException` appears in Logcat; notification disappears while playback/connection is expected; the UI says connected but no service owns the connection.

**When to validate:** Before feature polish: lock the phone, leave it idle, navigate away, swipe the task, and test the button; repeat after app process kill and reboot. Capture Logcat and service state.

**Phase to address:** Background media/BLE lifecycle phase.

---

### Pitfall 5: Playback is detached from the Android media session and audio-focus lifecycle

**What goes wrong:** Music starts from the in-app view but lock-screen/notification controls lack accurate track state, system media controls cannot act, another audio app causes inconsistent playback, or a future target-SDK change makes focus/play attempts fail from the background.

**Why it happens:** Playing audio is treated as a one-off method call instead of a session with a foreground-service owner. Android recommends placing the player and `MediaSession` in a `MediaSessionService` for background playback; it supplies a media notification and owns lifecycle cleanup. Android 15+ rejects audio-focus requests unless the app is topmost or running a foreground service. [Background playback with MediaSessionService](https://developer.android.com/media/media3/session/background-playback), [audio focus](https://developer.android.com/media/optimize/audio-focus)

**How to avoid:** Use exactly one authoritative player/session owned by the background audio service; route both BLE commands and UI/notification/lock-screen commands through the same command reducer. Request/release audio focus with playback transitions, update media metadata, release the player/session on destruction, and make stop semantically distinct from pause. Test competing audio and headset/system controls.

**Warning signs:** Duplicate players, stale notification title, paused audio continues to reserve focus, lock screen shows no controls, or a BLE “stop” only hides the UI while audio remains audible.

**When to validate:** Playback phase and every target-SDK/plugin upgrade; test with the device locked and a competing media app.

**Phase to address:** Playback and background-media phase.

---

### Pitfall 6: “Automatic reconnect” is an unbounded scan loop or assumes a killed app can reconnect

**What goes wrong:** The app burns battery scanning continuously, duplicates GATT connections/subscriptions after several retries, or never recovers once Android has killed the process. A press during reconnection is silently lost without a clear, accepted product rule.

**Why it happens:** Reconnect is implemented as a timer in the UI isolate, with no connection state machine, cancellation policy, or distinct recovery mechanism for an alive versus absent process. Android explicitly discourages periodic scans; use a `PendingIntent` scan to wake for a matching device, or an appropriate companion-device presence approach when justified. [Android BLE background guidance](https://developer.android.com/develop/connectivity/bluetooth/ble/background)

**How to avoid:** Define one connection owner and an idempotent state machine: `DISCONNECTED → SCANNING → CONNECTING → DISCOVERING → SUBSCRIBED → READY`. Use service-UUID filters, one active attempt, bounded exponential backoff/jitter, cleanup before retry, and a visible connection-state reason. For process resurrection, prototype `PendingIntent` scanning or companion association on the target device; do not promise first-press recovery until measured. Keep the approved UX contract: a second press after reconnection is acceptable.

**Warning signs:** Battery/network Bluetooth activity remains high when the button is absent; repeated “already connected” or duplicate event logs; reconnect loops on a bad GATT state; first post-idle notification is dropped.

**When to validate:** Resilience phase: force disconnect, out-of-range return, Bluetooth toggle, phone restart, app process kill, and several hours idle, measuring recovery time and first/second press behavior.

**Phase to address:** Recovery/resilience phase.

---

### Pitfall 7: Battery “optimization” puts the ESP32 to sleep and silently breaks BLE responsiveness

**What goes wrong:** Battery tests look good, but the phone disconnects while the device sleeps; the next press only wakes the ESP32 and does not start music. Deep sleep additionally restarts most firmware state, which can expose uninitialized BLE/button logic.

**Why it happens:** Light sleep is assumed to preserve BLE. ESP-IDF v6.1.1 documents that Wi-Fi and Bluetooth are powered down and connections are not maintained in both light and deep sleep; retaining a connection instead requires modem sleep/automatic light sleep under the radio driver. [ESP-IDF sleep modes](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-reference/system/sleep_modes.html)

**How to avoid:** Decide which behavior is being optimized: always-connected shelf button (use supported BLE modem-sleep/power management and measure) versus wake-on-press button (expect reconnect and honor the second-press rule). The confirmed target is classic ESP32-D0WDQ6 revision 1.0 (`idf.py set-target esp32`); the development-board pinout remains unknown, so do not select a button pin yet. If deep-sleep wake is pursued, choose a board-exposed RTC-capable input: on ESP32, `ext0` accepts only GPIO 0, 2, 4, 12–15, 25–27, or 32–39. On rev. 1, `ext0` cannot be combined with touch or ULP wake, and wake pins must be returned from RTC IO to normal GPIO after wake. [ESP-IDF v6.1.1 sleep modes](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-reference/system/sleep_modes.html) On wake, restore button state, initialize NimBLE, advertise, and suppress stale/bounce input until ready.

**Warning signs:** Link drops exactly when sleep starts; current decreases as expected but the button is unresponsive; first press after sleep only makes the LED blink; deep-sleep wake loops or has unexplained boot resets.

**When to validate:** Board-identification and power phase, using the actual planned power source and an ammeter; rerun the locked-phone latency/recovery suite after each power-policy change.

**Phase to address:** Hardware foundation, then power optimization after end-to-end reliability passes.

---

### Pitfall 8: Bundled audio works in debug but is absent, unplayable, or legally unusable in the demo build

**What goes wrong:** The playlist is empty/offline playback fails in a release APK because source files were not declared in `pubspec.yaml` or the player was given a development-only path. Alternatively, full tracks bloat the repository and app or lack a distribution right.

**Why it happens:** Flutter assets are bundled from declared paths at build time into the asset bundle, not read from the developer filesystem. [Flutter assets documentation](https://docs.flutter.dev/ui/assets/assets-and-images) The demo’s offline promise is tested only while the device still has network access or old app storage.

**How to avoid:** Keep a small licensed/owned test playlist outside ordinary Git history if files are large; record provenance and distribution rights. Declare every final audio file in `pubspec.yaml`, build a release APK, install it fresh, turn on airplane mode, and exercise every playlist command. Use a single manifest/list of track IDs, metadata, asset paths, and order so shuffle/previous behavior is deterministic and testable.

**Warning signs:** Debug works but release has “asset not found”; no-network test has not occurred; source tracks are committed without rights metadata; binary repository growth dominates source history.

**When to validate:** Playback phase, again during release/demo rehearsal on a clean device with airplane mode enabled.

**Phase to address:** Playback asset pipeline and demo hardening phase.

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|---|---|---|---|
| Put BLE subscription/reconnect in a widget state object | Fast proof of notifications | Dies with activity/isolate lifecycle and cannot satisfy locked-phone behavior | Only a disposable scanner prototype; never the demo path |
| Send commands before subscription confirmation | Fewer state checks | First command after reconnect vanishes or produces notification errors | Never |
| Use fixed `delay()` reconnect loops | Quick happy-path recovery | Battery drain, duplicate GATT state, no process-death strategy | Only a logged, capped prototype while designing the state machine |
| Enter light/deep sleep immediately after inactivity | Lower measured current | Drops BLE connection and changes first-press semantics | Only after accepting wake-and-reconnect UX and measuring it |
| Keep test MP3s in normal Git | Simple clone | Repository bloat and unclear rights | Only very short, documented royalty-free test clips |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|---|---|---|
| NimBLE GATT notifications | Treat a characteristic declaration as evidence that the central subscribed | Track CCCD/subscription state; send only after discovery and subscription; reset it on disconnect |
| Android runtime permissions | Request legacy Bluetooth permissions only, or test with old grants | Manifest + runtime Nearby Devices flow for `BLUETOOTH_SCAN`/`BLUETOOTH_CONNECT`; clean-install test |
| Flutter audio packages / native Android service | Assume package defaults declare modern foreground-service types | Inspect generated manifest and release build; verify `mediaPlayback` and any justified `connectedDevice` declarations on the target SDK |
| BLE recovery | Use a raw MAC address as permanent identity | Discover by service filter; reassess identity/address strategy if privacy rotation or companion APIs are adopted |
| One-byte protocol | Treat byte values as self-documenting | Keep `PROTOCOL.md`, firmware constants, app constants, and unknown-byte handling in one atomic change |

## Performance and Power Traps

| Trap | Symptoms | Prevention | When It Breaks |
|---|---|---|---|
| Double-click window consumes the latency budget | Short press feels slow even on an already-connected phone | Measure press-to-audible latency and choose a gesture scheme from data | Immediately; human perception, not user scale, is the limit |
| Continuous background scan | High idle current and device warming | UUID-filtered scan only for recovery; use event-driven background wake mechanisms where needed | Within hours/days of shelf use |
| Aggressive advertising interval without power budget | Fast recovery but poor button battery life | Define connected/disconnected advertising policies and measure actual current | As soon as battery power is used |
| Light/deep sleep used to preserve connection | First post-idle command lost | Use modem-sleep/automatic light-sleep or explicitly reconnect after wake | Every sleep transition |
| Multiple player/service owners | Intermittent double playback and stale media controls | One service-owned player/session and serialized command handling | First background/lock-screen test |

## Security and Privacy Mistakes

| Mistake | Risk | Prevention |
|---|---|---|
| Open, writable command characteristic or no command authorization policy | Any nearby client can change device state; future state/LED writes become an attack surface | Keep v1 command characteristic notify-only as specified; if writes are added, define pairing/bonding/authentication first |
| Put static personal data in BLE name/advertising payload | Nearby observers can identify household/device | Use a generic non-personal device name and only the required service UUID |
| Request location unnecessarily for BLE | Avoidable privacy prompt and user distrust | Follow Android’s Bluetooth permission model; only request location when scan results derive location |
| Bundle music without documented rights | Demo redistribution may be unauthorized | Store source/license/provenance record before inclusion |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---|---|---|
| No feedback while disconnected/reconnecting | A press appears broken | Expose app connection state and give hardware feedback if added; document the accepted second-press behavior |
| Gestures are undiscoverable | Household members accidentally skip/stop music | Put a concise gesture legend in the app and choose mappings after timed trials |
| “Stop” behaves like pause | Music resumes unexpectedly from system controls | Define stop as clear/release-or-reset behavior and test the exact chosen semantics |
| OEM behavior assumed from emulator or one phone | Locked-screen demo fails on the actual household phone | Treat the target handset as the acceptance platform; document its battery-optimization steps only after observing a failure |

## Looks Done But Isn't Checklist

- [ ] **Firmware BLE:** A scanner sees the service, and disconnect/failed-connect paths restart advertising without reset.
- [ ] **Gestures:** Each physical gesture produces exactly one byte and single press meets a measured latency budget.
- [ ] **Permissions:** A fresh Android 12+ install handles grant, deny, revoke, Bluetooth-off, and clean reconnect paths.
- [ ] **Locked-phone operation:** With the screen off and app UI absent, the service owns BLE/playback and the button works on the target phone.
- [ ] **Media controls:** Notification and lock screen show current track and execute the same command path as BLE.
- [ ] **Recovery:** Out-of-range return, Bluetooth toggle, process kill, and long idle each have a measured, documented outcome.
- [ ] **Power:** The selected sleep policy’s current and first-press behavior have been measured on the actual board/power source.
- [ ] **Offline playlist:** A fresh release install plays all bundled tracks in airplane mode and license/provenance is recorded.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---|---|---|
| Peripheral no longer advertises | LOW | Inspect GAP reason/logs; reset connection state; restart advertising; add a regression test for failed connect and disconnect |
| Android process/service absent | MEDIUM | Reopen app once to re-establish a user-started service; inspect FGS manifest/types and process-death logs; prototype permitted background discovery/association path |
| GATT is stuck after retries | MEDIUM | Cancel scan/connect, close the GATT/client instance, clear subscriptions, back off, then reconnect once; retain reason-coded logs |
| Sleep breaks immediate action | MEDIUM | Disable unsupported sleep policy for demo; choose always-connected modem-sleep or wake/reconnect semantics and retest |
| Incorrect/release-missing audio assets | LOW | Rebuild from a verified asset manifest; reinstall fresh release APK; add offline release smoke test |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---|---|---|
| Gesture arbitration versus latency | Protocol + firmware input | GPIO-to-notification traces and timed human trials |
| NimBLE disconnect/advertising recovery | Firmware BLE | Force disconnect/failed connect and confirm advertising resumes |
| Android permissions and initial association | Android BLE | Fresh install on physical phone; grant/deny/revoke tests |
| Media/foreground-service lifecycle | Background playback | Locked-screen, task-dismissed, process-killed tests plus Logcat review |
| Reconnect versus idle battery | Resilience | Long-idle/out-of-range/BT-toggle recovery matrix with recovery times |
| ESP32-D0WDQ6 rev. 1 sleep/wake policy and final GPIO selection | Power optimization | Ammeter + wake/connection/first-press regression suite on the identified board pinout |
| Bundled offline assets | Playback/demo hardening | Fresh release APK in airplane mode with complete playlist controls |
| OEM lifecycle variation | Physical-device acceptance | Repeat locked-screen/idle test on the actual household phone after any OS update |

## Sources

- **HIGH** — [Android Bluetooth permissions](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions)
- **HIGH** — [Android BLE communication in the background](https://developer.android.com/develop/connectivity/bluetooth/ble/background)
- **HIGH** — [Android foreground-service types](https://developer.android.com/develop/background-work/services/fgs/service-types)
- **HIGH** — [Android background playback with MediaSessionService](https://developer.android.com/media/media3/session/background-playback)
- **HIGH** — [Android audio-focus guidance](https://developer.android.com/media/optimize/audio-focus)
- **HIGH** — [Android companion-device pairing](https://developer.android.com/develop/connectivity/bluetooth/companion-device-pairing)
- **HIGH** — [ESP-IDF v6.1.1 sleep modes](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-reference/system/sleep_modes.html)
- **HIGH** — [ESP-IDF NimBLE connection example](https://docs.espressif.com/projects/esp-idf/en/v6.1-rc1/esp32/api-guides/ble/get-started/ble-connection.html)
- **HIGH** — [Flutter assets and bundles](https://docs.flutter.dev/ui/assets/assets-and-images)

---
*Pitfalls research for: Xmas Button*  
*Researched: 2026-11-25*
