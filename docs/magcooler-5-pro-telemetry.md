# Black Shark MagCooler 5 Pro telemetry

This protocol was verified on 2026-08-10 with a physical device advertised as
`Black Shark MagCooler 5pro`. The frames below were captured while the official
Shark Arsenal app displayed the same values. They are retained as protocol test
vectors; the original Android bugreport is intentionally not stored in this
repository because it contains unrelated private device data.

## GATT transport

- Service: `0000A0A0-3C17-D293-8E48-14FE2E4DA212`
- Write characteristic: `0000A001-3C17-D293-8E48-14FE2E4DA212`
- Notify/read characteristic: `0000A002-3C17-D293-8E48-14FE2E4DA212`
- Status request: `05 06 20 00 00`
- Observed polling interval in Shark Arsenal: approximately 2 seconds

Write the status request to A001 and parse the notification received from A002
with `BlackSharkLib.parseMessages(_:)`.

## Response format

The status notification is nine bytes:

`89 06 20 00 <cold> <hot> <rpm-lo> <rpm-hi> <power>`

| Offset | Meaning | Encoding |
| --- | --- | --- |
| 0-3 | Response header | Fixed `89 06 20 00` |
| 4 | Cold-side temperature | Signed 8-bit Celsius |
| 5 | Hot-side temperature | Signed 8-bit Celsius |
| 6-7 | Fan speed | Unsigned 16-bit RPM, little-endian |
| 8 | Device Power | Unsigned 8-bit watts |

## Hardware-captured examples

| Shark Arsenal state | Notification | Decoded values |
| --- | --- | --- |
| Custom Low | `89 06 20 00 FF 25 E2 0E 08` | -1 °C cold, 37 °C hot, 3810 RPM, 8 W |
| Custom Low | `89 06 20 00 FF 25 C4 0E 08` | -1 °C cold, 37 °C hot, 3780 RPM, 8 W |
| Custom High | `89 06 20 00 00 23 BC 16 08` | 0 °C cold, 35 °C hot, 5820 RPM, 8 W |
| Custom High | `89 06 20 00 00 23 DA 16 08` | 0 °C cold, 35 °C hot, 5850 RPM, 8 W |
| Dynamic power example | `89 06 20 00 F7 2A A6 0E 13` | -9 °C cold, 42 °C hot, 3750 RPM, 19 W |

During the Low/High comparison, Device Power remained at 8 W while fan speed
increased substantially. The power byte is therefore not a direct representation
of fan RPM. The 19 W capture confirms that this field does change dynamically.

The first Custom High selection did not immediately change the previously low
fan speed. After selecting another Custom level and returning to High, the fan
stabilised around 5820-5940 RPM. The stable High frames above are the canonical
test vectors.
