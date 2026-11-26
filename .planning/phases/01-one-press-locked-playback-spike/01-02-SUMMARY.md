---
phase: 01-one-press-locked-playback-spike
plan: 02
subsystem: android-setup
tags: [flutter, dart, permission-handler, android, method-channel, widget-tests]

# Dependency graph
requires:
  - phase: 01-01
    provides: Native readiness MethodChannel, Android foreground service, and real BLE/audio owner.
provides:
  - API-aware permission recovery and setup status UI.
  - Widget coverage for permission, lifecycle, readiness, error, and retry flows.
affects: [01-03, 01-04, android-setup]

# Actuals: chars/4 over the realized source/test diff; commits measured from the plan ledger.
actuals:
  tokens: 9428
  tasks: 2
  commits: 5
commits: 5
plan_head_before: 6ee3e57073c2ab471dfea0ac8d6af564dfeeaace
plan_head_after: 3b67ebbceecb347290a34341d6b2a93580c6a02f

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Snapshot replies apply only when no newer native update has arrived.
    - Permission setup is single-flight across prompt and settings-return callbacks.

key-files:
  created:
    - app/test/setup_permissions_test.dart
    - app/test/readiness_status_test.dart
  modified:
    - app/lib/main.dart

key-decisions:
  - "Use permission_handler status checks after Settings return so the app does not issue a second prompt."
  - "Keep Android session state authoritative; Flutter displays native snapshots and stateChanged updates."
  - "Preserve the Settings action until grant is confirmed when Android reports an ambiguous legacy denial."

patterns-established:
  - "Ready is displayed only for the native Ready state; start acknowledgment and intermediate states remain non-ready."
  - "Widget tests mock Android MethodChannel and permission plugin calls at the platform boundary."

requirements-completed: []

coverage:
  - id: D1
    description: "The setup page requests API-appropriate permissions after a visible action and offers retry or settings recovery."
    requirement: BLE-03
    verification:
      - kind: unit
        ref: "app/test/setup_permissions_test.dart"
        status: pass
    human_judgment: true
    rationale: "The mocked widget tests cover API 28 and API 31 branches; the final system prompt and settings behavior remain for the Plan 01-04 device run."
  - id: D2
    description: "The setup page reflects service readiness and exposes retry after native failure or link loss."
    requirement: BLE-04
    verification:
      - kind: unit
        ref: "app/test/readiness_status_test.dart"
        status: pass
    human_judgment: true
    rationale: "The tests drive mocked native states; actual target-phone discovery and subscription evidence remains for Plan 01-04."

# Metrics
duration: 25min
completed: 2026-11-26
status: complete
---

# Phase 1 Plan 2: Permission Recovery and Readiness UI Summary

**The Flutter setup page now recovers from denied Android permissions and shows readiness only when the native service reports a subscribed, prepared session.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-11-26T20:06:00Z
- **Completed:** 2026-11-26T20:30:42Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Kept the clean-launch rationale prompt-free and requested legacy Location on API 28–30 or Bluetooth Scan and Connect on API 31+ only after tapping Set up button.
- Added retryable denial, permanent-denial settings guidance, location-services recovery, and one setup attempt after a granted settings return.
- Rendered native starting, scanning, connecting, subscribing, preparing, ready, and error states. Failed startup, missing state, and disconnects remain non-ready and allow an explicit retry.
- Preserved local recovery guidance across stale inactive/error snapshots, kept settings-only recovery actionable after permanent denial, and prevented setup reentry while a settings visit is unresolved.
- Protected the page from duplicate prompt/start calls and stale snapshot responses; made the screen scroll on shorter displays.

## Task Commits

1. **Task 1: Complete the permission denial and recovery path** — `506ca1e` (`feat(01-02): recover permission and readiness setup`)
2. **Task 2: Make the real readiness and explicit retry state visible** — `38d944e` (`test(01-02): cover native readiness and retry states`)
3. **Settings-resume correctness fix** — `bad71f3` (`fix(01-02): preserve settings recovery after denial`)
4. **Retry after a ready session disconnect** — `fcd5bb0` (`test(01-02): retry after native session disconnect`)
5. **Preserve local recovery across resume** — `3b67ebb` (`fix(01-02): preserve recovery actions through resume`)

## Files Created/Modified

- `app/lib/main.dart` — permission flow, settings resume, single-flight setup, and native readiness state rendering.
- `app/test/setup_permissions_test.dart` — clean launch, Android API 28/API 31 permission request, denial recovery, settings grant/denial, and overlap cases.
- `app/test/readiness_status_test.dart` — native state sequences, failure retry, disconnect, missing results, and stale snapshot handling.

## Decisions Made

- The native service remains authoritative for BLE subscription and prepared-audio readiness. The Flutter page requests `snapshot` on attachment/resume and displays the `stateChanged` stream.
- Settings return rechecks current permission status without opening another prompt. It proceeds to native start only for the user's already initiated setup flow after permission is granted.
- If the permission plugin reports ordinary denial while Android's activity state is ambiguous, preserve the already offered Settings action. Clear that action after a confirmed grant and prevent a pending stale snapshot from replacing the denial state.
- While local actionable recovery guidance is active, ignore terminal native Inactive/Error snapshots until explicit retry or real native session progress; only then let the service status replace the local route.
- BLE-03 and BLE-04 remain phase requirements pending their sibling plans and final target-device validation; this summary makes no new physical-device claim.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Prevented the settings recovery screen from overflowing on shorter displays**
- **Found during:** Task 1 (Complete the permission denial and recovery path)
- **Issue:** The extra settings action and denial copy overflowed the original fixed-height column in widget tests.
- **Fix:** Wrapped the setup content in a safe-area scroll view so every recovery action remains reachable.
- **Files modified:** `app/lib/main.dart`
- **Verification:** Permission widget suite passes at the default test viewport.
- **Committed in:** `506ca1e`

**2. [Rule 1 - Bug] Preserved settings recovery when permission status is ambiguous after resume**
- **Found during:** Task 1 (Complete the permission denial and recovery path)
- **Issue:** On a settings return, permission_handler can report ordinary denial when Android cannot classify permanent denial; a late native Inactive snapshot could also replace the local denial guidance, and a grant could leave Open settings visible.
- **Fix:** Retain the prior Settings action until a grant is confirmed, clear it on grant/Ready, and advance the UI revision for local state so stale snapshots cannot overwrite it.
- **Files modified:** `app/lib/main.dart`, `app/test/setup_permissions_test.dart`
- **Verification:** Permission widget suite covers an ambiguous denied status plus late Inactive snapshot and confirms Settings disappears after grant.
- **Committed in:** `bad71f3`

**3. [Rule 1 - Bug] Kept actionable local recovery through stale terminal snapshots and settings reentry**
- **Found during:** Task 2 (Make the real readiness and explicit retry state visible)
- **Issue:** Ordinary resume could replace Location services guidance with an older native Error, route to app permissions instead of Location settings, or allow setup reentry while an app settings visit remained unresolved.
- **Fix:** Keep local recovery UI authoritative until explicit retry or active native progress, disable setup/settings controls while settings is pending, and keep permanent denial limited to the Settings action.
- **Files modified:** `app/lib/main.dart`, `app/test/setup_permissions_test.dart`
- **Verification:** Widget cases start from a prior native scan-timeout Error, resume with stale state, assert Location settings routing, and cover an unresolved Settings visit plus retryable denial grant.
- **Committed in:** `3b67ebb`

**Total deviations:** 3 auto-fixed issues (Rule 1 - Bug).
**Impact on plan:** The recovery UI remains usable on constrained displays; no product scope was added.

## Issues Encountered

- The first test draft used a permission-status value accessor that the public package export does not provide. The fixture was corrected before recording the intended RED run.
- The valid RED run showed the expected missing Retry control and failed settings-resume start. Flutter's JSON reporter is not among the installed GSD RED evidence parsers. With `workflow.tdd_mode=false`, the parent executor directed continuation using those actual assertion failures; no parser adapter was added.
- `flutter analyze` reports the existing `package:flutter/material.dart` deprecation info from the installed Flutter SDK. `flutter analyze --no-fatal-infos` passes with that info reported.

## Verification

- `cd app && /home/robert/flutter/bin/flutter test --concurrency=1 test/setup_permissions_test.dart` — 8 tests passed, including denied settings return, stale terminal snapshots, location settings routing, and pending settings reentry.
- `cd app && /home/robert/flutter/bin/flutter test --concurrency=1 test/readiness_status_test.dart` — 5 tests passed.
- `cd app && /home/robert/flutter/bin/flutter analyze --no-fatal-infos` — passed; reports the existing Material library deprecation info.
- `git diff --check` — passed.

## User Setup Required

None for this plan. The real system prompt and service/GATT behavior remain part of Plan 01-04 device validation.

## Next Phase Readiness

Plan 01-03 can add the selected second recording and update the same native audio owner. Plan 01-04 must still verify the real API 28 permission/settings flow, final recording playback, and target-device discovery/subscription; no physical readiness or timing claim is made here.

## Self-Check: PASSED

- Summary file exists at the planned phase path.
- Task commits `506ca1e`, `38d944e`, `bad71f3`, `fcd5bb0`, and `3b67ebb` are ancestors of the current branch head.
- The plan ledger measures 5 commits from `6ee3e57` through `3b67ebb`.
- `requirements.ready-ids` reports BLE-03 and BLE-04 blocked until sibling plans 01-03 and 01-04 have summaries; no requirement was marked complete here.

---
*Phase: 01-one-press-locked-playback-spike*
*Completed: 2026-11-26*
