# Roadmap: Xmas Button

## Overview

Xmas Button is delivered as four vertical slices. The first slice proves the core value on real hardware: one physical press starts bundled offline music on the locked target phone in about one second, while an explicit feasibility spike tests the Android service boundary before it becomes architectural commitment. The next slices complete the five-command controller, expose playback through the app and Android media surfaces, and then harden reconnect behavior and reproducibility into a repeatable holiday demo.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [ ] **Phase 1: One-Press Locked Playback Spike** - Prove a physical short press can start bundled offline music on the locked target phone and validate the Android service approach.
- [ ] **Phase 2: Complete Five-Command Control** - Turn the single-button prototype into a documented, exact, and safe five-command controller.
- [ ] **Phase 3: Visible Media Experience** - Make connection and playback state visible in the app and controllable from Android media surfaces.
- [ ] **Phase 4: Recovery and Repeatable Demo** - Recover from dropped or idle links and make the complete physical demo reproducible from a fresh clone.

## Phase Details

### Phase 1: One-Press Locked Playback Spike
**Goal**: A user can press the physical button once and hear bundled offline Christmas music start on the locked target phone in about one second, with real-device evidence establishing the viable Android service boundary.
**Mode**: mvp
**Depends on**: Nothing (first phase)
**Requirements**: BLE-01, BLE-03, BLE-04, AUD-01, BG-01, DOC-01
**Success Criteria** (what must be TRUE):
  1. A BLE scanner can identify the powered button by its recognizable name and custom service UUID, and the permitted app can find that service, connect, and subscribe.
  2. On a clean app install, the user is asked for the required Android Bluetooth permissions and sees a clear next step when access is denied.
  3. The app can play every track in a small rights-documented bundled playlist with the phone offline and without an account or external music setup.
  4. On the physical target phone, a short press while already connected starts audible music in about one second with the phone locked and screen off. Playback continues with the screen off. The result confirms or revises the proposed service ownership before Phase 2.
  5. `PROTOCOL.md` defines the service and characteristic UUIDs and all five command bytes. Both projects use matching protocol constants, starting with the short-press path in this phase.
**Plans**: TBD
**UI hint**: yes

### Phase 2: Complete Five-Command Control
**Goal**: A user can reliably control all required playback actions through five distinct gestures on the one physical button.
**Mode**: mvp
**Depends on**: Phase 1
**Requirements**: HW-01, BLE-02, BLE-05, AUD-02
**Success Criteria** (what must be TRUE):
  1. Physical testing demonstrates five distinct, documented gestures, including short press for play/pause, double press for next, long press for stop, and unambiguous choices for previous and shuffle.
  2. While connected and subscribed, each recognized gesture produces exactly one matching command byte and exactly one corresponding playback action with the phone locked.
  3. An unknown command byte leaves playback and shuffle state unchanged.
**Plans**: TBD

### Phase 3: Visible Media Experience
**Goal**: A user can see connection and playback state in the app and use standard Android controls without unlocking into the app.
**Mode**: mvp
**Depends on**: Phase 2
**Requirements**: BG-02, UI-01
**Success Criteria** (what must be TRUE):
  1. The app shows whether the button is connected, the current track, and the complete bundled song list.
  2. While the media session is active, Android shows the current track and standard transport controls in its media notification.
  3. The same track information and standard transport controls are available on the lock screen and stay consistent with button-initiated playback changes.
**Plans**: TBD
**UI hint**: yes

### Phase 4: Recovery and Repeatable Demo
**Goal**: The household demo recovers from ordinary BLE interruptions and can be rebuilt and verified by following the repository instructions.
**Mode**: mvp
**Depends on**: Phase 3
**Requirements**: REC-01, REC-02, DOC-02
**Success Criteria** (what must be TRUE):
  1. After the BLE link drops, the button resumes advertising and becomes discoverable again without a firmware reset.
  2. After a link drop or extended idle, the phone reconnects and re-subscribes without reopening the app, and a press made after reconnection controls playback; losing the initial disconnected press is acceptable.
  3. Starting from a fresh clone, a person can follow the README to build both firmware and app and run the documented physical checks for offline playback, locked-screen response, five commands, dropped-link recovery, and extended-idle recovery on the confirmed board and target phone.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. One-Press Locked Playback Spike | 0/TBD | Not started | - |
| 2. Complete Five-Command Control | 0/TBD | Not started | - |
| 3. Visible Media Experience | 0/TBD | Not started | - |
| 4. Recovery and Repeatable Demo | 0/TBD | Not started | - |
