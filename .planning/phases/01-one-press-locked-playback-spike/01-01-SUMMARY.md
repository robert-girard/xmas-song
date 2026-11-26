---
phase: 01-one-press-locked-playback-spike
plan: 01
subsystem: firmware-and-android
tags: [esp32, esp-idf-6.1.1, nimble, flutter, android, bluetooth-le, mediaplayer, audio]

requires: []
provides:
  - "Canonical one-byte BLE protocol and matching ESP32 and Android implementations."
  - "GPIO0 button firmware and an Android foreground-owned BLE/audio readiness route."
  - "A rights-documented first track and physical smoke evidence on the KeeYees ESP32 and Samsung SM-G955W."
affects: [01-02, 01-03, 01-04]

actuals:
  tokens: 18354
  tasks: 2
  commits: 1
commits: 1
plan_head_before: a6114fae80356b932af7d4e4b4fab44718ab9aa2
plan_head_after: d3057bb6d47e35daa069699dc200ab3c4d27005b

tech-stack:
  added: ["espressif/button 4.2.3", "Flutter 3.50.1", "permission_handler 13.0.2", "Android BluetoothGatt", "Android MediaPlayer"]
  patterns:
    - "A generation-tagged subscription gates queued button events and NimBLE notifications."
    - "One Android service owns foreground readiness, BLE GATT, and prepared local playback."
    - "One MethodChannel carries setup requests and native stateChanged updates."
key-files:
  created:
    - PROTOCOL.md
    - firmware/main/main.c
    - firmware/main/Kconfig.projbuild
    - app/android/app/src/main/kotlin/org/xmasbutton/phase01/xmas_button/MainActivity.kt
    - app/android/app/src/main/kotlin/org/xmasbutton/phase01/xmas_button/ReadinessService.kt
    - app/android/app/src/main/res/raw/track_01.ogg
    - app/assets/AUDIO-LICENSES.md
  modified:
    - firmware/sdkconfig.defaults
    - app/lib/main.dart
    - app/pubspec.yaml
    - app/android/app/src/main/AndroidManifest.xml

key-decisions:
  - "The verified KeeYees ESP32-D0WDQ6 uses its BOOT switch on active-low GPIO0; the Kconfig guard remains for other boards."
  - "Android's single foreground service owns scanning, GATT subscription, and the prepared MediaPlayer."
  - "The current Jingle Bells recording stays unchanged for this smoke; its silent lead-in and the user-selected replacement candidate are carried into Plan 01-03 before Plan 01-04 timing."
patterns-established:
  - "Ready is reported only after successful CCCD confirmation and silent MediaPlayer preparation."
  - "Queued button events carry the active connection and subscription generation so stale clicks are discarded."
requirements-completed: []

coverage:
  - id: D1
    description: "ESP32 NimBLE image builds and the verified BOOT button is compiled on GPIO0."
    verification:
      - kind: other
        ref: "IDF 6.1.1: IDF_PY_BUILD_JOBS=1 idf.py -C firmware build"
        status: pass
      - kind: manual_procedural
        ref: "Serial capture after flash: boot:0x13, app load, GATT registration, NimBLE advertising"
        status: pass
    human_judgment: true
    rationale: "Board wiring and released-BOOT startup require physical evidence."
  - id: D2
    description: "The Android foreground service scans, subscribes, silently prepares audio, and handles the button command."
    verification:
      - kind: other
        ref: "Flutter debug APK build: arm64-v8a"
        status: pass
      - kind: manual_procedural
        ref: "Scoped XmasReadiness log: exact service match, CCCD success, silent preparation, then 0x01"
        status: pass
    human_judgment: true
    rationale: "BLE and MediaPlayer lifecycle behavior was checked on the target phone."
  - id: D3
    description: "The packaged first recording has an exact-file rights record and matching checksum."
    verification:
      - kind: other
        ref: "sha256sum app/android/app/src/main/res/raw/track_01.ogg; APK resource checksum"
        status: pass
    human_judgment: true
    rationale: "Recording attribution and audible behavior require human review."
  - id: D4
    description: "A physical press starts music with the phone locked and offline; a second press pauses it."
    verification:
      - kind: manual_procedural
        ref: "User-observed fresh SM-G955W/API 28 smoke: Wi-Fi/mobile data off, Bluetooth on, 30 seconds locked"
        status: pass
    human_judgment: true
    rationale: "Audible playback and lock-screen continuation require direct observation."

duration: 293min
completed: 2026-11-26
status: complete
---

# Phase 1 Plan 01: Verified Press-to-Audio Smoke Summary

**The verified GPIO0 BOOT button advertises the canonical NimBLE service, and the staged Android service reaches subscribed, silently prepared playback on the target phone.**

## Performance

- **Duration:** 293 min
- **Started:** 2026-11-26T15:07:51Z
- **Completed:** 2026-11-26T20:00:38Z
- **Tasks:** 2
- **Files modified:** 37 implementation and generated project files

## Accomplishments

- Built and flashed the ESP32-D0WDQ6 firmware with the verified active-low BOOT input on GPIO0. A post-flash serial capture confirmed normal released-BOOT startup, GATT registration, and NimBLE advertising.
- Built and installed the isolated Android debug APK. On the target phone, logs confirmed the advertised `Xmas Button` service UUID, successful CCCD subscription, silent audio preparation, and a later `0x01` command.
- Completed the physical offline smoke: the user observed playback unlocked and with the phone locked for more than 30 seconds; a second press paused playback. In the fresh run, Wi-Fi and mobile data were off, Bluetooth was on, and the phone stayed locked for 30 seconds before the press.
- Recorded exact-file rights and SHA-256 for the packaged Jingle Bells recording.

## Task Commits

1. **Task 1: Build one physical press-to-audio route** — `d3057bb` (`feat(01-01): build verified press-to-audio smoke route`)
2. **Task 2: Run the one-track smoke on the actual board and phone** — human-action checkpoint satisfied; no source changes.

Plan metadata is recorded in the separate final documentation commit.

## Files Created/Modified

- `PROTOCOL.md` — canonical service/characteristic UUIDs and five command bytes.
- `firmware/main/main.c` — NimBLE peripheral, notify-only characteristic, and generation-checked button event handling.
- `firmware/sdkconfig.defaults` and `firmware/main/Kconfig.projbuild` — verified KeeYees GPIO0 setting with an explicit guard for other boards.
- `app/android/app/src/main/kotlin/org/xmasbutton/phase01/xmas_button/MainActivity.kt` — resumed-activity checks and attempt-identified foreground-start acknowledgments.
- `app/android/app/src/main/kotlin/org/xmasbutton/phase01/xmas_button/ReadinessService.kt` — single GATT, foreground, and player owner.
- `app/lib/main.dart` — permission-gated setup and the shared readiness MethodChannel.
- `app/android/app/src/main/res/raw/track_01.ogg` and `app/assets/AUDIO-LICENSES.md` — packaged recording and its rights provenance.
- Flutter and ESP-IDF dependency locks and the planned generated Android shell files.

## Decisions Made

- The physical board is the identified KeeYees ESP32-D0WDQ6 revision 1.0. BOOT-to-GPIO0 was verified by serial boot-mode observation before enabling the button; other board configurations retain the Kconfig guard.
- Android's `ReadinessService` remains the sole owner of BLE scanning/GATT and local playback. The foreground start acknowledgment is tied to its request identity.
- The installed .smoke APK was kept isolated from the release application ID. No permissions were pregranted.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the Espressif Button callback and stale-click handling**
- **Found during:** Task 1
- **Issue:** The callback signature did not match button 4.2.3, and a queued click could outlive its notification subscription.
- **Fix:** Used the component's `void (*)(void *, void *)` signature and captured/revalidated the connection plus subscription generation around queued notifications.
- **Files modified:** `firmware/main/main.c`
- **Verification:** GPIO-enabled branch syntax check against pinned headers and normal one-job firmware build passed.
- **Committed in:** `d3057bb`

**2. [Rule 1 - Bug] Serialized Android GATT and playback lifecycle state**
- **Found during:** Task 1
- **Issue:** The old connection overload did not specify callback delivery, and immediate `MediaPlayer.isPlaying` reads could report stale state.
- **Fix:** Used the six-argument `connectGatt` overload with the main Handler; tracked play/pause state through successful operations, completion, error, and cleanup.
- **Files modified:** `app/android/app/src/main/kotlin/org/xmasbutton/phase01/xmas_button/ReadinessService.kt`
- **Verification:** Capped incremental Android debug build passed; device logs showed CCCD, preparation, and command order.
- **Committed in:** `d3057bb`

**3. [Rule 2 - Missing lifecycle handling] Bound native foreground startup and state delivery to one request and channel**
- **Found during:** Task 1
- **Issue:** A timed-out or duplicate start could be acknowledged before foreground promotion; a late cancelled service start needed to satisfy Android's foreground-start obligation without scanning.
- **Fix:** Added resumed-activity checks, attempt IDs, timeout cancellation, late-start promotion-then-stop handling, and a single MethodChannel `stateChanged` path shared with Dart.
- **Files modified:** `app/android/app/src/main/kotlin/org/xmasbutton/phase01/xmas_button/MainActivity.kt`, `app/android/app/src/main/kotlin/org/xmasbutton/phase01/xmas_button/ReadinessService.kt`, `app/lib/main.dart`
- **Verification:** Capped incremental Android debug build passed with one worker, a 1.5 GiB Gradle heap, 384 MiB metaspace, and in-process Kotlin compilation.
- **Committed in:** `d3057bb`

**Total deviations:** 3 auto-fixed issues (2 Rule 1, 1 Rule 2).
**Impact on plan:** Changes close correctness and lifecycle gaps discovered in the planned implementation; no extra product scope was added.

## Issues Encountered

- The user's informal timing report was 2–3 seconds on the first press and under one second on subsequent presses. An independent local decode found 4.5 seconds of exact digital silence at the head of the current Ogg, with sample activity beginning around 4.5–4.75 seconds. The report and file analysis do not provide a synchronized measurement of first audible onset. The user selected a replacement candidate for Wave 2: Wikimedia Commons `Jingle Bells Or The One Horse Open Sleigh Complete.ogg`, Robotchoir PD-self, SHA-256 `9cef62c273dce5f05c8eacc8ddd6b6ba49544f90da29f284708074014d115599`. It is not part of this plan's APK; Plan 01-03 should record its source, rights, duration, and checksum. Plan 01-04 must measure cold first-audible latency on the final asset before deciding whether the one-second target is met.
- The target phone's read-only state after the fresh run showed Wi-Fi off, mobile data off, and Bluetooth on. The fresh run remained locked for 30 seconds before BOOT was pressed.

## User Setup Required

For the direct smoke, the user granted Android 9's Location permission through the staged app's **Set up button** flow. No permission was pregranted by tooling.

## Next Phase Readiness

Wave 2 can proceed with permission-recovery coverage and playlist work. The functional one-track smoke passed, including locked playback and play/pause. The objective first-audible timing and replacement recording remain open for Plan 01-03 and the final Plan 01-04 acceptance run. All six phase requirement IDs remain pending because Plans 01-02, 01-03, and 01-04 also claim shared requirements; none are marked complete here.

## Self-Check: PASSED

- Summary file exists at the planned phase path.
- Task 1 commit `d3057bb6d47e35daa069699dc200ab3c4d27005b` is an ancestor of the current branch head.
- Summary records the measured plan commit count of 1 and the ledger base/head hashes.
- Shared phase requirements remain pending; the physical smoke is recorded as functional evidence without claiming the first-audible timing target.

---
*Phase: 01-one-press-locked-playback-spike*
*Completed: 2026-11-26*
