# Phase 1: One-Press Locked Playback Spike - Pattern Map

**Mapped:** 2026-11-25

**In-repo implementation analogs found:** 0

## Scope Finding

This is a greenfield repository: `git ls-files` contains planning documents, `AGENTS.md`, and `PRD.md`, but no `firmware/` or `app/` implementation. Therefore there is no tracked in-repo source analog to copy, and none is invented below. The only tracked source-like contract is `PRD.md` (§6.3, lines 84-98), which fixes the notify-only, one-byte protocol and all five command values. Every implementation path below is **new**. External SDK/package paths are reference material, not in-repo analogs and must not be copied into plan edit targets.

## File Classification

| New/Modified File | Role | Data Flow | Closest tracked in-repo analog | Match quality |
|---|---|---|---|---|
| `PROTOCOL.md` | config / protocol contract | transform | `PRD.md` lines 84-98 | contract-source |
| `firmware/CMakeLists.txt` | config | build | none | no analog (new) |
| `firmware/sdkconfig.defaults` | config | build | none | no analog (new) |
| `firmware/dependencies.lock` | config / lockfile | dependency resolution | none | generated after resolution |
| `firmware/main/CMakeLists.txt` | config | build | none | no analog (new) |
| `firmware/main/idf_component.yml` | config | dependency resolution | none | no analog (new) |
| `firmware/main/main.c` | controller | event-driven | none | no analog (new) |
| `app/pubspec.yaml` + `app/pubspec.lock` | config / lockfile | dependency resolution | none | new / generated lock |
| `app/lib/main.dart` | component / composition root | request-response | none | no analog (new) |
| `app/android/app/src/main/kotlin/.../MainActivity.kt` | Flutter bridge | request-response | none | no analog (new) |
| `app/android/app/src/main/AndroidManifest.xml` | config | lifecycle / request-response | none | no analog (new) |
| `app/android/app/src/main/kotlin/.../ReadinessService.kt` | service | event-driven | none | no analog (new; exact package path follows generated app) |
| `app/android/app/src/main/res/raw/*.ogg` + `app/assets/AUDIO-LICENSES.md` | asset / documentation | file-I/O | none | no analog (new) |
| `docs/phase-01-physical-evidence.md` | test / verification evidence | batch | none | no analog (new) |

## Pattern Assignments

### `PROTOCOL.md` (protocol contract, transform)

**Tracked contract source:** `PRD.md` lines 84-98 (verified tracked).

**Copy these invariants:** one notify-only characteristic; canonical generated 128-bit service and characteristic UUID strings; five byte constants; app ignores unknown bytes. Phase 1 emits/maps only `0x01` for a short press.

```text
0x01 Play / pause toggle
0x02 Next song
0x03 Previous song
0x04 Stop
0x05 Shuffle on/off
```

Record the UUIDs chosen in 01-01-PLAN.md here, then derive the C and Kotlin constants from this contract in the same commit. Check NimBLE initializer byte order against the canonical UUID strings.

### `firmware/` project and component files (config, build/dependency resolution)

**In-repo analog:** none. **External reference only:** installed ESP-IDF 6.1.1 `examples/bluetooth/nimble/bleprph/CMakeLists.txt` lines 3-13 and `main/CMakeLists.txt` lines 1-5.

```cmake
set(srcs "main.c"
         "gatt_svr.c")
idf_component_register(SRCS "${srcs}"
                       INCLUDE_DIRS ".")
```

Use a normal ESP-IDF project rooted at `firmware/` with target `esp32` and `main` registered as the application component. Keep the small Phase 1 peripheral in `firmware/main/main.c`. Resolve the `espressif/button: ^4.2.3` component and commit `dependencies.lock` and `sdkconfig.defaults`.

### `firmware/main/main.c` (controller, event-driven)

**In-repo analog:** none. **External reference only:** installed ESP-IDF 6.1.1 `.../bleprph/main/main.c` lines 149-212, 528-574, and 576-650.

**Core lifecycle to adapt:** initialize NVS, initialize NimBLE, install reset/sync/GATT registration callbacks, initialize GATT server, name the GAP device, and run the NimBLE host on its FreeRTOS task. `sync_cb` obtains the address type and begins advertising.

```c
ble_hs_cfg.reset_cb = bleprph_on_reset;
ble_hs_cfg.sync_cb = bleprph_on_sync;
ble_hs_cfg.gatts_register_cb = gatt_svr_register_cb;

rc = gatt_svr_init();
assert(rc == 0);
rc = ble_svc_gap_device_name_set("nimble-bleprph");
assert(rc == 0);
nimble_port_freertos_init(bleprph_host_task);
```

**Advertising pattern:** set general-discoverable and BLE-only flags, put the complete custom 128-bit service UUID in the legacy advertising payload, put the recognizable non-personal name in scan response, then start undirected connectable advertising. Check every return code as the reference does; a 31-byte legacy payload cannot safely hold Flags, UUID, and arbitrary complete name together.

**Button boundary:** Verify the physical BOOT switch reaches GPIO0 first, keep EN as reset, and release BOOT during reset for normal startup. Register the short-click action after normal boot.

### GATT definition and notifications in `firmware/main/main.c`

**In-repo analog:** none. **External reference only:** installed ESP-IDF 6.1.1 `.../bleprph/main/gatt_svr.c` lines 35-95, 208-268; subscription event handling is in `main.c` lines 346-356.

**Definition pattern:** retain the static `ble_uuid128_t` / `ble_gatt_svc_def[]` shape and registration sequence:

```c
.type = BLE_GATT_SVC_TYPE_PRIMARY,
.uuid = &gatt_svr_svc_uuid.u,
.characteristics = (struct ble_gatt_chr_def[]) {{
  .uuid = &gatt_svr_chr_uuid.u,
  .access_cb = command_access,
  .flags = BLE_GATT_CHR_F_NOTIFY,
  .val_handle = &gatt_svr_chr_val_handle,
}, { 0 }}

rc = ble_gatts_count_cfg(gatt_svr_svcs);
if (rc != 0) return rc;
return ble_gatts_add_svcs(gatt_svr_svcs);
```

NimBLE validates that `access_cb` is non-null. Use `command_access` to reject reads and writes of the characteristic value. Keep `BLE_GATT_CHR_F_NOTIFY` as its sole property and retain the standard CCCD. Track the active connection and notification enablement from `BLE_GAP_EVENT_SUBSCRIBE`. Send one byte using an explicit mbuf and `ble_gatts_notify_custom` on the subscribed connection and characteristic value handle. That call consumes the mbuf. Drop unsent input after a disconnect. The implementation is in installed NimBLE `host/src/ble_gatts.c:512–520` and `host/include/host/ble_gatt.h:886–901`.

### Protocol constants in `firmware/main/main.c` and `ReadinessService.kt`

**In-repo analog:** none; derive from new root `PROTOCOL.md`. Keep the two UUID declarations and all five `uint8_t` command constants together. The byte order supplied to `BLE_UUID128_INIT` must be explicitly reviewed/tested against the canonical string in `PROTOCOL.md`.

### `app/pubspec.yaml`, `app/pubspec.lock`, and asset declarations (config, dependency/file-I/O)

**In-repo analog:** none. Flutter uses `permission_handler ^13.0.2` and the committed `pubspec.lock`. The Phase 1 design uses Android `BluetoothGatt` and `MediaPlayer` in the readiness service for BLE and playback. The evaluated Flutter BLE and audio packages remain research references. See [SKELETON.md](SKELETON.md).

### `app/lib/main.dart` and the native activity bridge (composition/UI, request-response)

**In-repo analog:** none. Flutter requests the OS-specific permission after **Set up button** and renders the state reported through `xmas_button/readiness`. Explain that the Android 9 location permission enables BLE scanning. Handle retry and settings return. Start the readiness service from the visible activity after the grant.

### `app/android/.../AndroidManifest.xml` and `ReadinessService.kt` (native service/config, lifecycle)

**In-repo analog:** none. **Official platform references:** Android Bluetooth permissions, BLE background communication, and foreground-service type documentation.

After the applicable permission grant, start the non-exported service and report successful foreground promotion before scanning. Match the advertised service UUID and keep one `BluetoothGatt` session. Confirm its CCCD write in `onDescriptorWrite`, then wait for the service's `MediaPlayer` to reach Prepared before reporting Ready. The first valid byte `0x01` starts or pauses that player. On Android 9 use the legacy foreground-service and scan-permission path. Validate modern declarations in the actual release APK and observe the notification on the real phone.

### `app/android/app/src/main/res/raw/*.ogg` and `app/assets/AUDIO-LICENSES.md` (asset/documentation, file-I/O)

**In-repo analog:** none. Every candidate recording needs documented redistribution rights independent of the public-domain composition. For each bundled small asset record: exact source URL, recording license/public-domain claim, attribution text, verification date, duration, and file size. Keep tracks small and suitable for distribution; do not add an unverified or large recording to Git.

### `docs/phase-01-physical-evidence.md` (verification, batch)

**In-repo analog:** none. Record the board and boot observation, advertisement, permission flow, Ready state, 30-second offline locked interval, measured time from physical press to first audible note, continued playback, builds, phone model/API, and verdict. Use available timing equipment that captures the two events on one timeline. Keep personal identifiers out of the record.

## Shared Patterns

### Protocol authority and validation

**Source:** tracked `PRD.md` lines 84-98; new `PROTOCOL.md` becomes the implementation authority.

- All five byte values exist in documentation and both implementations.
- Firmware Phase 1 emits only `0x01` on short press.
- App accepts known one-byte commands and ignores unknown or malformed payloads with no playback state change.
- Characteristic stays notify-only; no client writes in this phase.

### Ready-before-lock ownership

**Apply to:** setup UI, native activity bridge, readiness service.

Visible setup → OS grant → acknowledged service promotion → service-filtered scan → one connection → CCCD success → silent preparation → Ready → 30 seconds locked → notification → audible playback.

### Error and lifecycle handling

**Firmware reference:** installed `bleprph/main/main.c` lines 196-210 and 546-564 log return-code failures and only continue after successful setup.
**App rule:** expose permission, scan, connection, subscription, and service-start failures as explicit UI states; cancel/dispose owned streams/service cleanly; do not silently retry into multiple API-28 connection attempts.

### External reference provenance

- ESP-IDF v6.1.1 installed example: `/home/robert/.espressif/v6.1.1/esp-idf/examples/bluetooth/nimble/bleprph/` (read-only reference; not tracked by this repository).
- Flutter permission UI uses `permission_handler` 13.0.2.
- Android platform APIs cover Bluetooth permissions, `BluetoothGatt` callbacks, foreground service types, and `MediaPlayer`.

## No Analog Found

All anticipated implementation files have no eligible in-repo source analog because the project is greenfield. The planner should use the external references and constraints above, generate the Flutter/ESP-IDF scaffolds, and then establish project-local patterns for later phases.

## Metadata

**Analog search scope:** tracked repository root (`git ls-files`), with external installed ESP-IDF 6.1.1 reference inspection.

**Tracked implementation files scanned:** 0.

**Tracked contract files read:** `AGENTS.md`, `PRD.md`, Phase 1 context/research.

**Pattern extraction date:** 2026-11-25.
