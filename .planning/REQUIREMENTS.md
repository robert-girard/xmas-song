# Requirements for Xmas Button

**Defined** 2026-11-25

**Core value** A single physical button starts Christmas music on a locked Android phone in about one second under normal connected conditions.

## v1 Requirements

### Hardware and Bluetooth

- [ ] **HW-01**: One debounced physical button recognizes five distinct gestures. Short press toggles play/pause, double press skips forward, and long press stops. Previous and shuffle use distinct gestures documented after physical testing.
- [ ] **BLE-01**: A BLE scanner can find the button by its recognizable name and custom service UUID.
- [ ] **BLE-02**: A subscribed phone receives exactly one matching command byte per recognized gesture while connected.
- [ ] **BLE-03**: The app requests the required Android Bluetooth permissions and explains how to proceed if access is denied.
- [ ] **BLE-04**: With permission granted, the app finds the button by service UUID, connects, and subscribes to command notifications.
- [ ] **BLE-05**: The app ignores unknown command bytes without changing playback.

### Recovery

- [ ] **REC-01**: The button resumes advertising after the BLE link drops.
- [ ] **REC-02**: After a link drop or extended idle, the phone reconnects automatically without reopening the app. A press after reconnection works.

### Playback and Android controls

- [ ] **AUD-01**: The app plays a small bundled Christmas playlist offline. The included tracks have documented distribution rights.
- [ ] **AUD-02**: The five button commands toggle play/pause, skip to the next or previous track, stop playback, and toggle shuffle.
- [ ] **BG-01**: On the physical target phone, a short press starts music in about one second under normal connected conditions. Button control and playback work with the screen locked.
- [ ] **BG-02**: While the media session is active, Android shows the current track and standard transport controls in its media notification and on the lock screen.
- [ ] **UI-01**: The app shows connection status, the current track, and the bundled song list.

### Protocol and setup

- [ ] **DOC-01**: `PROTOCOL.md` defines the service and characteristic UUIDs and command bytes used by both implementations.
- [ ] **DOC-02**: A fresh clone builds both projects by following the README. The README also documents how to run the physical demo checks.

## Deferred Requirements

- **PWR-01**: Measure and optimize battery-powered idle behavior after validating the USB-powered demo.
- **LED-01**: Show app playback state on a hardware LED using an explicitly defined feedback protocol.
- **OEM-01**: Document target-specific battery-management settings if physical testing identifies a need.
- **CI-01**: Add path-filtered CI checks for firmware and app builds.

## Out of Scope

| Feature | Reason |
|---------|--------|
| ESP32 audio, Bluetooth Classic audio, or I2S output | The phone stores and plays the music. |
| iOS, cloud services, accounts, streaming, or analytics | The demo is for one offline Android installation. |
| Multiple buttons, multiple phones, or mesh operation | A single household button owns all five gestures. |
| Music-folder selection, playlist editing, or a configurable gesture UI | The bundled playlist and fixed gestures keep setup simple. |
| Replay of commands pressed while disconnected | A new press after automatic reconnection meets the recovery requirement. |
| Consumer UI polish | The demo needs status, the current track, and a song list. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| HW-01 | Phase 2 | Pending |
| BLE-01 | Phase 1 | Pending |
| BLE-02 | Phase 2 | Pending |
| BLE-03 | Phase 1 | Pending |
| BLE-04 | Phase 1 | Pending |
| BLE-05 | Phase 2 | Pending |
| REC-01 | Phase 4 | Pending |
| REC-02 | Phase 4 | Pending |
| AUD-01 | Phase 1 | Pending |
| AUD-02 | Phase 2 | Pending |
| BG-01 | Phase 1 | Pending |
| BG-02 | Phase 3 | Pending |
| UI-01 | Phase 3 | Pending |
| DOC-01 | Phase 1 | Pending |
| DOC-02 | Phase 4 | Pending |

**Coverage**

- v1 requirements: 15 total
- Mapped to phases: 15
- Unmapped: 0

---
*Requirements approved 2026-11-25. Traceability added during roadmap creation.*
