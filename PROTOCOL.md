# Xmas Button BLE Protocol

The button exposes one notify-only command characteristic. Each notification is
exactly one byte; the phone ignores unknown or malformed values.

| Item | UUID / value |
|---|---|
| Service | `55f93b80-da2b-42f4-bad6-a4ec40e3ea7c` |
| Command characteristic | `2206a557-99b7-4176-98f4-d066c053335e` |

| Byte | Meaning |
|---|---|
| `0x01` | Play / pause toggle |
| `0x02` | Next song |
| `0x03` | Previous song |
| `0x04` | Stop |
| `0x05` | Shuffle on/off |

The characteristic has Notify and the standard Client Characteristic
Configuration Descriptor only. Clients cannot read or write its value. Phase 1
emits `0x01` for a single click.
