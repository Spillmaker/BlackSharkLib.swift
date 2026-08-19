# Black Shark MagCooler 6 series protocol

The protocol details in this document were captured on 2026-08-16 from physical
Black Shark MagCooler 6 Max and MagCooler 6 Pro devices using Shark Arsenal
5.6.2. The original Android Bluetooth snoop logs are intentionally not stored in
the repository because they contain unrelated device traffic.

## MagCooler 6 Max

The device advertises as `Black Shark MagCooler 6MAX` and uses the established
Black Shark GATT transport:

- Service: `0000A0A0-3C17-D293-8E48-14FE2E4DA212`
- Write characteristic: `A001`
- Notify characteristic: `A002`

### Control commands

| Action | Payload |
| --- | --- |
| Overclock | `06 05 00 00 01 00` |
| Smart | `06 05 00 00 02 00` |
| Silent | `06 05 00 00 03 00` |
| Cooling off | `06 05 00 00 FB 00` |
| LEDs on | `05 01 00 00 00` |
| LEDs off | `05 01 00 00 03` |

All commands above are hardware-tested. In particular, the tester confirmed
that the cooling-off command stops the cooler completely.

### Telemetry

- Request: `05 06 20 00 00`
- Response: `8B 06 20 00 <cold> <hot> <rpm-lo> <rpm-hi> <power> <unknown> <unknown>`

Temperatures are signed 8-bit Celsius values. Fan speed is an unsigned 16-bit
little-endian RPM value and device power is reported in watts.

## Display-equipped MagCooler 6 Pro

The device advertises as `Black Shark MagCooler 6Pro`. Unlike the regular 6 and
6 Max, it uses a separate GATT service and A5-framed commands:

- Service: `0000F530-1212-EFDE-1523-785FEABCD123`
- Notify characteristic: `0000F531-1212-EFDE-1523-785FEABCD123`
- Write-without-response characteristic: `0000F532-1212-EFDE-1523-785FEABCD123`

Android discovery and connection were hardware-tested successfully on
2026-08-18 with pocketChat. A scan filtered only by F530 and the standard Black
Shark manufacturer block did not discover the tested device. Discovery
succeeded after adding an unfiltered foreground fallback that accepts the
complete local name `Black Shark MagCooler 6Pro`. BLE clients should also choose
the Pro transport from the F530 service found during GATT service discovery;
relying on a cached or truncated GAP name may select the wrong protocol.

An A5 frame contains `A5`, the total frame length, the command and its payload,
followed by an additive checksum of all preceding bytes modulo 256.

### Control commands

| Action | Payload | Verification |
| --- | --- | --- |
| Overclock | `A5 06 40 00 00 EB` | Captured from hardware |
| Smart | `A5 06 40 01 00 EC` | Captured from hardware |
| Silent | `A5 06 40 02 00 ED` | Captured from hardware |
| LEDs on | `A5 05 10 00 BA` | Captured from hardware |
| LEDs off | `A5 05 10 03 BD` | Captured from hardware |
| Cooling off candidate | `A5 06 40 FB 00 E6` | Rejected; had no effect in a hardware test |

The official app does not expose a complete cooling-off control for this model,
so no off frame appeared in either capture. Applying the `FB 00` value used by
other current models to the A5 mode frame had no effect in a physical-device
test and must not be treated as a supported off command.

The second capture also confirmed the mode frames through telemetry. Shortly
after each selection, Overclock reported approximately 4740 RPM / 26 W, Smart
approximately 4320 RPM / 15 W and Silent approximately 3840 RPM / 9 W.

### Custom power levels

Custom uses mode `03` followed by a zero-based power level. These are all active
cooling states; level 1 is not an off command.

| Custom level | Payload | Observed fan speed |
| --- | --- | --- |
| 1 (Low) | `A5 06 40 03 00 EE` | approximately 3300 RPM |
| 2 | `A5 06 40 03 01 EF` | approximately 3840 RPM |
| 3 | `A5 06 40 03 02 F0` | approximately 4500 RPM |
| 4 (OC) | `A5 06 40 03 03 F1` | approximately 4920 RPM |
| 5 (High) | `A5 06 40 03 04 F2` | approximately 6000 RPM |

### Telemetry

- Request: `A5 04 05 AE`
- Observed response: `A5 0A 05 <cold> <hot> <rpm-lo> <rpm-hi> <power> <unknown> <checksum>`

The captured response fields follow the same signed-temperature,
little-endian-RPM and watt conventions as the other current coolers.
