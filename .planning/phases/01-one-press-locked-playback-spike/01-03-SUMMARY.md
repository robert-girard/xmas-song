---
phase: 01-one-press-locked-playback-spike
plan: 03
subsystem: android-playback
tags: [android, mediaplayer, audio-assets, licensing, vscode, gitignore]

requires:
  - phase: 01-01
    provides: [ReadinessService, first packaged recording, subscribed playback route]
  - phase: 01-02
    provides: [permission recovery and readiness status flow]
provides:
  - "Two exact, rights-documented offline Ogg resources for the Android app."
  - "Sequential playback and silent first-track re-prepare within the existing ReadinessService."
  - "A relative multi-root VS Code workspace and shared generated-file ignore rules."
affects: [01-04, android-playback, project-bootstrap]

actuals:
  tokens: 2907
  tasks: 2
  commits: 2
commits: 2
plan_head_before: d3e293b239d455a44a830ba0a5c1cc672cb53d4b
plan_head_after: 7d0aa750f686d5af106a9215ab6194ff5d388fac

tech-stack:
  added: []
  patterns:
    - "The readiness service owns one MediaPlayer and advances through ordered raw resource IDs on natural completion."
    - "Each asynchronous player callback checks both its service session and active player identity."
key-files:
  created:
    - app/android/app/src/main/res/raw/track_02.ogg
    - .gitignore
    - xmas-song.code-workspace
  modified:
    - app/android/app/src/main/kotlin/org/xmasbutton/phase01/xmas_button/ReadinessService.kt
    - app/android/app/src/main/res/raw/track_01.ogg
    - app/assets/AUDIO-LICENSES.md
key-decisions:
  - "Use the user-selected exact Wikimedia Commons Jingle Bells file as track 01, without trimming or transcoding."
  - "Use Ihaksi's compact Freesound CC0 Ogg preview for track 02 and retain courtesy attribution."
  - "Capture track index and auto-start intent per preparation callback instead of storing mutable playlist-transition state."
  - "Keep generated Android/Flutter and ESP-IDF output ignored while leaving both dependency lockfiles trackable."
patterns-established:
  - "A naturally completed track is released before its successor is prepared; the last completion silently prepares track 01 again."
  - "The same service owner handles silent initial readiness, automatic next-track start, and 0x01 play/pause."
requirements-completed: []
coverage:
  - id: D1
    description: "Track 01 and track 02 are the exact bundled audio files documented with source, recording rights, attribution, duration, size, and checksum."
    requirement: AUD-01
    verification:
      - kind: other
        ref: "sha256sum app/android/app/src/main/res/raw/track_01.ogg app/android/app/src/main/res/raw/track_02.ogg"
        status: pass
      - kind: other
        ref: "Reviewed the Commons and Freesound source pages and recorded exact-file provenance in app/assets/AUDIO-LICENSES.md."
        status: pass
    human_judgment: true
    rationale: "The source terms and final audible quality still merit human review during the Plan 01-04 release and physical playback check."
  - id: D2
    description: "The single readiness service advances from track 01 to track 02 and silently prepares track 01 again after the final track completes."
    requirement: BG-01
    verification: []
    human_judgment: true
    rationale: "The callback path was reviewed, but Android playback and the screen-off transition are reserved for the Plan 01-04 device run."
  - id: D3
    description: "VS Code opens firmware and app as relative project roots, while generated and machine-specific files are ignored and lockfiles stay trackable."
    verification:
      - kind: other
        ref: "python3 workspace JSON root assertion; git check-ignore for ESP-IDF build/sdkconfig/managed_components and Android local.properties; git check-ignore confirms both lockfiles are not ignored."
        status: pass
    human_judgment: false
duration: 7min
completed: 2026-11-26
status: complete
---

# Phase 1 Plan 03: Licensed Playlist and Workspace Summary

**The Android service now sequences two exact, documented offline recordings through one player owner, and the repository has relative firmware/app workspace roots with shared ignore rules.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-11-26T20:28:56Z
- **Completed:** 2026-11-26T20:35:54Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Replaced track 01 with the user-selected exact Robotchoir Commons recording. The file is untrimmed and untranscoded; the source SHA-1 and packaged SHA-256 match the documented values.
- Added Ihaksi's 7.595-second Ogg preview of “Deck the Halls” as track 02. Its sound-page recording terms are CC0; the local file is the exact preview, with no edits or transcoding.
- Extended the existing `ReadinessService` player lifecycle to prepare track 01 silently, release it at natural completion, prepare and start track 02, then silently re-prepare track 01 after the final cue. Completion and error callbacks validate both session and player identity.
- Added a two-root `xmas-song.code-workspace` with relative `firmware` and `app` folders and root ignore rules for generated/local project state.

## Task Commits

1. **Task 1: Play both licensed recordings in normal playlist order** — `5230052` (`feat(01-03): play the licensed two-track playlist`)
2. **Task 2: Open both projects in the shared VS Code workspace** — `7d0aa75` (`chore(01-03): add shared workspace and ignore rules`)

Plan metadata is recorded in the separate final documentation commit.

## Files Created/Modified

- `app/android/app/src/main/res/raw/track_01.ogg` — exact user-selected Commons replacement.
- `app/android/app/src/main/res/raw/track_02.ogg` — exact compact Freesound Ogg preview.
- `app/assets/AUDIO-LICENSES.md` — separate composition and recording provenance, rights, attribution, duration, size, and checksums for both resources.
- `app/android/app/src/main/kotlin/org/xmasbutton/phase01/xmas_button/ReadinessService.kt` — single-owner ordered playlist transition and silent reset.
- `.gitignore` — root exclusions for generated ESP-IDF, Flutter, and Android local state; dependency locks remain trackable.
- `xmas-song.code-workspace` — repository-relative `firmware` and `app` roots.

## Decisions Made

- Used the exact source recording selected by the user for track 01. Wikimedia Commons identifies Robotchoir as its creator, describes the Festival speech-synthesis and TiMidity/FreePats accompaniment, and records the worldwide public-domain release and unrestricted fallback. FreePats' licensing policy also documents that its sample licenses permit musical output to be distributed under the author's chosen license.
- Chose Ihaksi's very compact Deck the Halls bell recording for track 02. The Freesound page identifies the creator's own bell samples and arrangement and marks the sound CC0. The package uses its published low-quality Ogg preview rather than its larger WAV master.
- Kept preparation intent and track index in immutable callback parameters. The service still has one active player, and callbacks proceed only for the current session and player.
- Recorded both audio assets' provenance in the packaged rights file and retained courtesy credits even where attribution is not required.

## Deviations from Plan

None. Replacing track 01 was the documented Phase 1 decision carried into this plan. The FreePats musical-output reference adds provenance for the named accompaniment and does not change scope.

## Verification

- Both packaged SHA-256 checks passed: track 01 `9cef62c273dce5f05c8eacc8ddd6b6ba49544f90da29f284708074014d115599`; track 02 `197a340753f5584b94b02485e644e5877edf28309edc6166eaf6aa4a7162a174`.
- Workspace JSON assertion passed with exactly the relative roots `firmware` and `app`.
- `git check-ignore` matched ESP-IDF `build`, generated `sdkconfig`, `managed_components`, and Android `local.properties`; both `firmware/dependencies.lock` and `app/pubspec.lock` remain unignored.
- `git diff --check` passed for the implementation and documentation changes.
- No Android build or device playback was run in this plan. Plan 01-04 owns the release build, final APK resource check, sequential listening, and display-off timing run.

## Issues Encountered

None.

## User Setup Required

None.

## Next Phase Readiness

Plan 01-04 can build the release APK, verify both packaged resource hashes, and observe the full sequential playlist on the target phone with the display off. The track 01 source is ready for the first-audible latency measurement.

## Self-Check: PASSED

- All six planned deliverables exist.
- Task commits `5230052` and `7d0aa75` are ancestors of the current branch head.
- The recorded pre-plan base, post-task head, and two task commits match the persisted plan ledger and `git rev-list` measurement.

---
*Phase: 01-one-press-locked-playback-spike*
*Completed: 2026-11-26*
