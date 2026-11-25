# Phase 1: One-Press Locked Playback Spike - Discussion Log

> This log is for human review. Use `01-CONTEXT.md` as the planning input.

**Date:** 2026-11-25

**Areas discussed:** Demo hardware, first-run setup, bundled music, locked-phone demo.

## Demo hardware

Robert offered a spare Android phone, approximately five to six years old, that can stay connected for the demo. Its Android version was unknown. The device list was empty during discussion. Robert identified the board as a KeeYees with dedicated EN/Reset and BOOT buttons.

| Option | Description | Selected |
|--------|-------------|----------|
| Separate momentary switch | Use a verified GPIO with a separate switch from the start. | |
| Onboard BOOT button for the first test | Verify BOOT wiring and use it for the first playback test. Move to a separate switch later. | ✓ |

## First-run setup

Robert preferred bringing the user directly to the Android permission screen. Both options included an **Open settings** action if Android can no longer show its prompt.

| Option | Description | Selected |
|--------|-------------|----------|
| After tapping **Set up button** | Show a one-sentence explanation and open the system prompt on tap. | ✓ |
| Immediately on first launch | Open the system prompt when the app first opens. | |

## Bundled music

| Option | Description | Selected |
|--------|-------------|----------|
| User-supplied recordings | Bundle suitable copies supplied by Robert. | |
| Source redistributable recordings | Find a few royalty-free recordings of familiar public-domain songs. | ✓ |

Robert suggested *Jingle Bells*. The exact recordings and their redistribution licenses will be checked during delivery.

## Locked-phone demo

Robert initially had no preference about timing. The proposed baseline was to keep Bluetooth connected and internet access off, leave the phone locked for 30 seconds, and measure from press to first audible note against the existing one-second target.

| Option | Description | Selected |
|--------|-------------|----------|
| Use the test and save the context | Use the proposed 30-second locked-screen baseline. | ✓ |
| Keep discussing | Change or further explore the setup. | |

## Planner Discretion

- Select recordings with documented rights and choose how to capture latency.
- Confirm the spare phone model and Android release/API, then validate the chosen libraries and service behavior on the phone.

## Deferred Ideas

- Move from BOOT to a separate button after the first playback test.
