# BlackSharkLib.swift

BlackSharkLib.swift is a Swift library that enables communication between your app and phone coolers sold under the Black Shark brand.

# Device support

## Supported and hardware-tested

- Black Shark MagCooler 4 Pro
  - Fan and Peltier power control
  - Mute, Overclocking and Smart cooling modes
  - Solid-colour, Streamer and off LED controls
- Black Shark FunCooler 6 (BR62, regular model without display)
  - Normal and Silent cooling modes
  - Complete cooling on/off control for fan and Peltier
  - LED on/off control
- Black Shark MagCooler 5 Pro
  - Five cooling intensity levels
  - Desk mode with reduced cooling and continued low fan speed
  - Solid-colour LED controls
  - Cold-side and hot-side temperature, fan RPM and device-power telemetry
- Black Shark FunCooler 6 Max
  - Overclocking, Smart and Silent cooling modes
  - Complete cooling on/off control for fan and Peltier
  - LED on/off control
  - Cold-side and hot-side temperature, fan RPM and device-power telemetry

The MagCooler 5 Pro telemetry protocol, including hardware-captured frames, is
documented in [docs/magcooler-5-pro-telemetry.md](docs/magcooler-5-pro-telemetry.md).

The MagCooler 6 Max and display-equipped 6 Pro transports, commands and
telemetry formats are documented in
[docs/magcooler-6-series.md](docs/magcooler-6-series.md).

## Implemented, hardware verification pending

- Black Shark FunCooler 6 Pro (display-equipped model)
  - Discovery and connection through its separate F530/F531/F532 GATT transport, hardware-tested on Android
  - Overclocking and Smart modes hardware-tested end to end
  - Silent command confirmed by a hardware capture; client retest pending after fixing mode persistence in pocketChat
  - LED on/off control
  - Cold-side and hot-side temperature, fan RPM and device-power telemetry
  - No verified complete cooling-off command; the experimental `FB 00` candidate had no effect on tested hardware
  - End-to-end verification of controls and telemetry is still pending

## Planned devices

- Black Shark FunCooler 4 Pro
- Black Shark MagCooler 3 Pro
- Black Shark FunCooler 3 Pro
- Black Shark FunCooler 2 Pro

Support for additional coolers is completely free and will remain open source. I will add the remaining devices step by step as I get access to the physical hardware and can reliably verify their protocol commands.

A device is moved to the hardware-tested section only after its commands have been captured and verified on the real device.

# Installation

In Xcode, open **Project → Package Dependencies**, add a new package and enter the following URL:

```
https://github.com/romestylez/BlackSharkLib.swift
```

# Usage

- Implement your own Bluetooth manager.
- Use the static functions to identify supported peripherals while scanning.
- Use the static functions to connect to the appropriate read and write characteristics.
- Create the required Bluetooth payloads using the static functions provided by the library and send them to the write characteristic.
- Use the static parsing function to process messages received from the read characteristic.
- See the comments on the individual functions for additional information.

# Support

The library and future device support are provided free of charge and remain open source.

If you would like to request support for another Black Shark cooler, feel free to open an issue. New devices will be added step by step when the required physical hardware is available for reliable testing.

Contributions, protocol findings and pull requests are always welcome.

# Known usages

The following apps are known to use this library:

- [pocketChat](https://github.com/romestylez/pocketChat) – Cross-platform streaming chat with integrated Black Shark cooler controls.
- [pocketSRT](https://github.com/romestylez/pocketSRT) – Mobile SRT streaming with integrated Black Shark cooler controls.
- [Moblin](https://github.com/eerimoq/moblin) – Automatically adjusts lighting, fan speed and cooling power based on device metrics to keep the cooler as quiet as possible during live broadcasts.

Is your app using BlackSharkLib.swift? Feel free to open an issue or pull request to have it added to this list.
