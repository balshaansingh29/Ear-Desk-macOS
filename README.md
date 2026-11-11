# Nothing X for Mac

Native SwiftUI app (Apple silicon, macOS 13+) for Nothing / CMF earbuds. It speaks the same
Bluetooth Classic (SPP/RFCOMM) protocol as [ear-web](https://github.com/radiance-project/ear-web),
using IOBluetooth instead of the browser's Web Serial API.

## Build
    ./build.sh          # runs tests, builds arm64, bundles and ad-hoc signs "build/Nothing X.app"

First launch: macOS asks for Bluetooth permission. Pair + connect the earbuds in System Settings first.

## Features
Battery, noise control (ANC / transparency / strengths), EQ presets (classic and listening-mode
models), bass enhance, in-ear detection, low-latency mode, find my earbuds, menu-bar quick controls.
Not yet ported: custom/advanced EQ curves, gestures, dual connection, spatial audio, ear-tip fit test.

## Notes
- Model is detected from the Bluetooth name (macOS has no Fast Pair ID); use "Model override" if wrong.
- Licensed AGPL-3.0 as a derivative of ear-web. Unofficial; not affiliated with Nothing Technology.
