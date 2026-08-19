import Foundation

/// Protocol/codec for supported Black Shark phone coolers.
///
/// This library only builds the byte payloads you write to the device and parses the ones it
/// notifies back. You would need to build the CoreBluetooth workflow yourself, or implement it in your existing CoreBluetooth code.
public class BlackSharkLib {


    private static let manufacturerDataIdentifier: Data = Data([0x8F, 0x03])
    /// Returns `true` if the advertised manufacturer data belongs to a Black Shark cooler.
    public static func isBlackSharkDevice(_ manufacturerData: Data) -> Bool {
        return manufacturerData.starts(with: manufacturerDataIdentifier)
    }

    private static let serviceUUID: UUID = UUID(uuidString: "0000A0A0-3C17-D293-8E48-14FE2E4DA212")!
    private static let funCooler6ProServiceUUID: UUID = UUID(uuidString: "0000F530-1212-EFDE-1523-785FEABCD123")!
    private static let funCooler6ProNotifyUUID: UUID = UUID(uuidString: "0000F531-1212-EFDE-1523-785FEABCD123")!
    private static let funCooler6ProWriteUUID: UUID = UUID(uuidString: "0000F532-1212-EFDE-1523-785FEABCD123")!
    /// The GATT service used by the 4 Pro, 5 Pro, regular 6 and 6 Max.
    public static func getServiceUUID() -> UUID {
        return BlackSharkLib.serviceUUID
    }

    /// Returns the full GATT service UUID for a model.
    public static func getServiceUUID(model: Model) -> UUID {
        return model == .funCooler6Pro ? funCooler6ProServiceUUID : serviceUUID
    }

    /// The notify characteristic used by the display-equipped FunCooler 6 Pro.
    public static func getFunCooler6ProNotifyUUID() -> UUID {
        return funCooler6ProNotifyUUID
    }

    /// The write-without-response characteristic used by the display-equipped FunCooler 6 Pro.
    public static func getFunCooler6ProWriteUUID() -> UUID {
        return funCooler6ProWriteUUID
    }

    /// The cooler model, which the caller detects and passes back in.
    ///
    /// The 4 Pro and the 5 Pro share a PCB (`BR42`), the service UUID, both characteristics
    /// and the `05`-command family. What differs is firmware-level: the telemetry frame, the
    /// status-poll parameter and the whole light system. Everything
    /// 5 Pro-specific in this library is opt-in, so existing 4 Pro code keeps working untouched.
    public enum Model: Sendable, Equatable, CaseIterable {
        /// Black Shark MagCooler 4 Pro.
        case pro4
        /// Black Shark MagCooler 5 Pro.
        case pro5
        /// Black Shark FunCooler 6 (BR62), not the FunCooler 6 Pro.
        case funCooler6
        /// Black Shark FunCooler 6 Max.
        case funCooler6Max
        /// Display-equipped Black Shark FunCooler 6 Pro.
        case funCooler6Pro
    }

    /// Cooling presets exposed by the Black Shark app for the MagCooler 4 Pro.
    public enum Pro4CoolingMode: Sendable, Equatable, CaseIterable {
        case mute
        case overclocking
        case smart
    }

    /// Cooling modes supported by the regular FunCooler 6 (BR62).
    public enum FunCooler6CoolingMode: Sendable, Equatable, CaseIterable {
        case normal
        case silent
    }

    /// Cooling presets shared by the FunCooler 6 Max and display-equipped 6 Pro.
    public enum FunCooler6AdvancedCoolingMode: Sendable, Equatable, CaseIterable {
        case overclocking
        case smart
        case silent
    }

    /// Identifies which cooler you are talking to, from its advertised name.
    ///
    /// - Parameter advertisedName: The **Complete Local Name from the advertising packet**. On
    ///   iOS that means `advertisementData[CBAdvertisementDataLocalNameKey]` in the discovery
    ///   callback, captured while scanning.
    /// - Returns: The model, or `nil` if the name is missing or names a cooler this library
    ///   does not know.
    ///
    /// - Important: Do **not** pass `peripheral.name`. That is the GAP device name, which
    ///   CoreBluetooth caches and which these coolers set to a truncated version of the full name. effectively
    ///   removing the last part where the model is which is the important part.
    public static func detectModel(advertisedName: String? = nil) -> Model? {
        if let name = advertisedName?.lowercased() {
            let compactName = name.replacingOccurrences(of: " ", with: "")
            if compactName.contains("funcooler6pro") || compactName.contains("magcooler6pro") {
                return .funCooler6Pro
            }
            if compactName.contains("funcooler6max") || compactName.contains("magcooler6max") {
                return .funCooler6Max
            }
            if compactName.contains("funcooler6") || compactName.contains("magcooler6") || compactName.contains("br62") {
                return .funCooler6
            }
            if name.contains("5pro") {
                return .pro5
            }
            if name.contains("4pro") {
                return .pro4
            }
        }

        return nil
    }

    public protocol Message {
        var rawData: Data { get }
    }

    public struct CoolingState: Message {
        /// The frame exactly as it came off the wire.
        public let rawData: Data
        /// The model of the cooler
        public let model: Model
        /// Cold-side (phone-facing) temperature in °C. Signed.
        public let phoneTemperature: Int
        /// Hot-side / exhaust temperature in °C. Signed.
        public let heatsinkTemperature: Int
        /// Fan speed in RPM.
        public let fanRPM: Int?
        /// Device power reported by the cooler, in watts.
        ///
        /// The name is retained for source compatibility. New code may use
        /// ``devicePowerWatts`` for the same value.
        public let powerLevel: Int?

        /// Device power reported by the cooler, in watts.
        public var devicePowerWatts: Int? { powerLevel }
    }

    public struct FanState: Message {
        /// The frame exactly as it came off the wire.
        public let rawData: Data
        /// The model of the cooler (Identified by message-payload format)
        public let model: Model? = nil
        /// 0-100%.
        public let speed: Int
    }

    public struct UnknownMessage: Message {
        /// The frame exactly as it came off the wire.
        public let rawData: Data
    }

    private static let readCharacteristicsUUID   = Data([0xA0, 0x02])
    /// The A002 characteristic that notifies status frames on the standard transport.
    /// Subscribe to it and feed what arrives to ``parseMessages(_:)``.
    /// Use ``getFunCooler6ProNotifyUUID()`` for the display-equipped 6 Pro.
    public static func getReadCharacteristicsUUID() -> Data {
        // Only one known characteristic for now
        return BlackSharkLib.readCharacteristicsUUID
    }

    /// Decodes a frame received on the read characteristic.
    ///
    /// Recognises the fan report (``FanState``) and the telemetry frame of either model
    /// (``CoolingState``). Anything else, including malformed or truncated
    /// frames, comes back as ``UnknownMessage`` with `rawData` intact, so nothing is ever lost.
    public static func parseMessages(_ data: Data) -> Message {
        // Read through a plain byte array so the offsets below are relative to the start of
        // the frame. A Data slice keeps the indices of the buffer it was cut from, so parsing
        // something like buffer.dropFirst(2) would trap on bytes[0] even though the frame
        // itself is intact. rawData keeps the Data exactly as it was handed to us.
        let bytes = [UInt8](data)

        guard bytes.count > 2 else {
            return UnknownMessage(rawData: data)
        }
        // bytes[0] is a split. First part of hex is always 8, second half is the lengthbit.
        // bytes[1-2] is the command (that it responds to)
        // bytes[3] is a spacer(?) seems to always be 0x00

        // 02 10 - Fan status
        if bytes[1] == 0x02 && bytes[2] == 0x10 {
            guard bytes.count > 4 else {
                return UnknownMessage(rawData: data)
            }
            // Fan speed is either bytes[4] or bytes[5]
            // Both are identical. I suspect one of them are the cooling value, but i dont know how to adjust them independently yet.
            let speed = max(0, min(100, 100 - Int(bytes[4])))

            return FanState(rawData: data, speed: speed)
        }

        // 06 00 - Cooling status
        if bytes[1] == 0x06 && bytes[2] == 0x00 {
            guard bytes.count > 7 else {
                return UnknownMessage(rawData: data)
            }
            // bytes[5] - Temperature on the Phone side
            let phoneTemperature = Int(Int8(bitPattern: bytes[5]))

            // bytes[7] - Temperature on the heatsink
            let heatsinkTemperature = Int(Int8(bitPattern: bytes[7]))

            // A 4 Pro reports neither fan RPM nor power level.
            return CoolingState(rawData: data,
                model: .pro4,
                phoneTemperature: phoneTemperature,
                heatsinkTemperature: heatsinkTemperature,
                fanRPM: nil,
                powerLevel: nil
            )
        }

        // 89 06 - Cooling status (MagCooler 5 Pro)
        // The 5 Pro answers the status poll with its own 9-byte frame.
        // 89 06 20 00 <cold> <hot> <rpm-lo> <rpm-hi> <power>
        //  0  1  2  3    4     5      6        7        8
        if bytes.count > 3 && bytes[0] == 0x89 && bytes[1] == 0x06 && bytes[2] == 0x20 && bytes[3] == 0x00 {
            guard bytes.count > 8 else {
                return UnknownMessage(rawData: data)
            }
            // bytes[4] - Temperature on the Phone side (cold side of the Peltier plate)
            let phoneTemperature = Int(Int8(bitPattern: bytes[4]))

            // bytes[5] - Temperature on the heatsink (hot side / exhaust)
            let heatsinkTemperature = Int(Int8(bitPattern: bytes[5]))

            // bytes[6-7] - Fan speed in RPM, little-endian UInt16. (58 11 = 4440 rpm)
            let fanRPM = Int(bytes[6]) | (Int(bytes[7]) << 8)

            // bytes[8] - Device power in watts, matching Shark Arsenal's Device Power value
            let powerLevel = Int(bytes[8])

            return CoolingState(
                rawData: data,
                model: .pro5,
                phoneTemperature: phoneTemperature,
                heatsinkTemperature: heatsinkTemperature,
                fanRPM: fanRPM,
                powerLevel: powerLevel
            )
        }

        // 8B 06 - Cooling status (FunCooler 6 Max)
        // 8B 06 20 00 <cold> <hot> <rpm-lo> <rpm-hi> <power> <unknown> <unknown>
        if bytes.count > 3 && bytes[0] == 0x8b && bytes[1] == 0x06 && bytes[2] == 0x20 && bytes[3] == 0x00 {
            guard bytes.count > 10 else {
                return UnknownMessage(rawData: data)
            }

            return CoolingState(
                rawData: data,
                model: .funCooler6Max,
                phoneTemperature: Int(Int8(bitPattern: bytes[4])),
                heatsinkTemperature: Int(Int8(bitPattern: bytes[5])),
                fanRPM: Int(bytes[6]) | (Int(bytes[7]) << 8),
                powerLevel: Int(bytes[8])
            )
        }

        // A5-framed cooling status (display-equipped FunCooler 6 Pro)
        // A5 0A 05 <cold> <hot> <rpm-lo> <rpm-hi> <power> <unknown> <checksum>
        if bytes[0] == 0xa5 && bytes[2] == 0x05 {
            guard bytes.count == 10,
                  Int(bytes[1]) == bytes.count,
                  hasValidA5Checksum(bytes) else {
                return UnknownMessage(rawData: data)
            }

            return CoolingState(
                rawData: data,
                model: .funCooler6Pro,
                phoneTemperature: Int(Int8(bitPattern: bytes[3])),
                heatsinkTemperature: Int(Int8(bitPattern: bytes[4])),
                fanRPM: Int(bytes[5]) | (Int(bytes[6]) << 8),
                powerLevel: Int(bytes[7])
            )
        }

        // Return generig message
        return UnknownMessage(rawData: data)
    }


    //
    // Write
    //
    private static let writeCharacteristicsUUID  = Data([0xA0, 0x01])
    /// The A001 characteristic used for write-without-response commands on the standard transport.
    /// Use ``getFunCooler6ProWriteUUID()`` for the display-equipped 6 Pro.
    public static func getWriteCharacteristicsUUID() -> Data {
        // Only one known characteristic for now
        return BlackSharkLib.writeCharacteristicsUUID
    }

    /// Makes the read-channel return metadata about the cooling. (Temp, etc)
    ///
    /// This needs to be polled as the coolers dont send events. Reccomended: 2 seconds intervals.
    public static func getCoolingMetadataCommand(model: Model = .pro4) -> Data {
        switch model {
        case .pro4:
            return Data([0x05, 0x06, 0x00, 0x00, 0x00])
        case .pro5:
            return Data([0x05, 0x06, 0x20, 0x00, 0x00])
        case .funCooler6:
            // No FunCooler 6 telemetry frame has been verified yet. Keep the common
            // status request available so clients do not need a separate scan path.
            return Data([0x05, 0x06, 0x00, 0x00, 0x00])
        case .funCooler6Max:
            return Data([0x05, 0x06, 0x20, 0x00, 0x00])
        case .funCooler6Pro:
            return a5Frame(command: 0x05)
        }
    }

    /// Sets the fan speed.
    ///
    /// **4 Pro only.**
    public static func getSetFanSpeedCommand(_ percentage: Int, model: Model = .pro4) -> Data? {

        guard model == .pro4 else {
            print("ERROR: Fan speed is not controllable on a 5 Pro. Use getSetCustomModeCommand.")
            return nil
        }

        guard percentage >= 0 && percentage <= 100 else {
            print("ERROR: Invalid percentage value. Must be between 0 and 100")
            return nil
        }

        // Convert to hex value
        var hexVal = UInt8(100 - percentage) // Value needs to be inverted.

        if percentage == 0 {
            // Off is apparently a custom value
            hexVal = 0xfb
        }

        return Data([0x05, 0x02, 0x00, 0x00, hexVal])
    }

    /// Sets the cooling (Peltier) power as a percentage.
    ///
    /// **4 Pro only.**
    public static func getSetCoolingPowerCommand(_ percentage: Int, model: Model = .pro4) -> Data? {

        guard model == .pro4 else {
            print("ERROR: A 5 Pro takes an intensity, not a percentage. Use getSetCustomModeCommand.")
            return nil
        }

        guard percentage >= 0 && percentage <= 100 else {
            print("ERROR: Invalid percentage value. Must be between 0 and 100")
            return nil
        }

        // Convert to hex value
        var hexVal = UInt8(100 - percentage) // Value needs to be inverted.

        if percentage == 0 {
            // Off is apparently a custom value
            hexVal = 0xfb
        }

        return Data([0x05, 0x05, 0x00, 0x00, hexVal])
    }

    /// Selects one of the MagCooler 4 Pro cooling presets from the Black Shark app.
    ///
    /// The returned fan command must be written first, followed by the cooling command.
    /// These payloads were captured and verified on physical MagCooler 4 Pro hardware.
    /// Smart mode uses the device-specific value `fa`, which cannot be produced by the
    /// percentage-based command builders.
    ///
    /// - Parameters:
    ///   - mode: Mute, Overclocking or Smart.
    ///   - model: The connected cooler.
    /// - Returns: Two ordered payloads, or `nil` for devices other than the 4 Pro.
    public static func getSetCoolingModeCommands(_ mode: Pro4CoolingMode, model: Model = .pro4) -> [Data]? {
        guard model == .pro4 else {
            print("ERROR: Cooling presets are only supported on the 4 Pro")
            return nil
        }

        let fanValue: UInt8
        let coolingValue: UInt8
        switch mode {
        case .mute:
            fanValue = 0x2d
            coolingValue = 0x60
        case .overclocking:
            fanValue = 0x14
            coolingValue = 0x06
        case .smart:
            fanValue = 0xfa
            coolingValue = 0xfa
        }

        return [
            Data([0x05, 0x02, 0x00, 0x00, fanValue]),
            Data([0x05, 0x05, 0x00, 0x00, coolingValue]),
        ]
    }

    /// Builds the cooling command for the regular FunCooler 6 (BR62).
    ///
    /// Normal, Silent and cooling-off were captured and verified on physical hardware.
    /// The FunCooler 6 uses one command for the complete cooling system; fan and Peltier
    /// are not exposed as separate controls.
    public static func getSetFunCooler6CoolingCommand(
        _ enabled: Bool,
        mode: FunCooler6CoolingMode = .normal
    ) -> Data {
        let value: UInt8
        if !enabled {
            value = 0xfb
        } else {
            switch mode {
            case .normal:
                value = 0x02
            case .silent:
                value = 0x03
            }
        }
        return Data([0x06, 0x05, 0x00, 0x00, value, 0x00])
    }

    /// Enables or disables the LEDs on the regular FunCooler 6 (BR62).
    ///
    /// Both payloads were captured and verified on physical hardware.
    public static func getSetFunCooler6LEDCommand(_ enabled: Bool) -> Data {
        return Data([0x05, 0x01, 0x00, 0x00, enabled ? 0x00 : 0x03])
    }

    /// Builds a complete cooling-system command for the FunCooler 6 Max.
    ///
    /// Overclocking, Smart, Silent and complete cooling-off were captured and
    /// hardware-tested. Custom mode is deliberately not exposed.
    public static func getSetFunCooler6MaxCoolingCommand(
        _ enabled: Bool,
        mode: FunCooler6AdvancedCoolingMode = .smart
    ) -> Data {
        let value: UInt8
        if !enabled {
            value = 0xfb
        } else {
            switch mode {
            case .overclocking:
                value = 0x01
            case .smart:
                value = 0x02
            case .silent:
                value = 0x03
            }
        }
        return Data([0x06, 0x05, 0x00, 0x00, value, 0x00])
    }

    /// Enables or disables the LEDs on the FunCooler 6 Max.
    public static func getSetFunCooler6MaxLEDCommand(_ enabled: Bool) -> Data {
        return Data([0x05, 0x01, 0x00, 0x00, enabled ? 0x00 : 0x03])
    }

    /// Builds an A5-framed cooling-system command for the display-equipped FunCooler 6 Pro.
    ///
    /// Overclocking, Smart and Silent were captured from physical hardware. The off payload
    /// wraps the established `FB 00` complete-off value in the 6 Pro's valid A5 mode frame;
    /// it remains experimental until a physical-device test confirms fan and Peltier stop.
    /// Custom mode is deliberately not exposed.
    public static func getSetFunCooler6ProCoolingCommand(
        _ enabled: Bool,
        mode: FunCooler6AdvancedCoolingMode = .smart
    ) -> Data {
        if !enabled {
            return a5Frame(command: 0x40, payload: [0xfb, 0x00])
        }

        let value: UInt8
        switch mode {
        case .overclocking:
            value = 0x00
        case .smart:
            value = 0x01
        case .silent:
            value = 0x02
        }
        return a5Frame(command: 0x40, payload: [value, 0x00])
    }

    /// Enables or disables the LEDs on the display-equipped FunCooler 6 Pro.
    public static func getSetFunCooler6ProLEDCommand(_ enabled: Bool) -> Data {
        return a5Frame(command: 0x10, payload: [enabled ? 0x00 : 0x03])
    }

    /// Selects Custom mode at one of its five intensity steps.
    ///
    /// **5 Pro only.** This is that cooler's single cooling control: it has no percentage
    /// channel, and its fan is not separately settable but follows whichever step you pick.
    ///
    /// The intensity is a controller setting, not a fixed RPM or watt value. Hardware captures
    /// showed Custom Low around 3780-3810 RPM and Custom High around 5820-5940 RPM while the
    /// reported device power remained at 8 W. Temperatures and controller state affect the
    /// live telemetry, so clients should poll it instead of assigning fixed values to a step.
    ///
    /// Note that step 1 is a floor, not an off: the fan and Peltier remain active.
    ///
    /// - Parameters:
    ///   - intensity: 1-5.
    ///   - model: The connected cooler.
    /// - Returns: The payload, or `nil` if `intensity` is outside 1-5, or on a 4 Pro.
    public static func getSetCustomModeCommand(intensity: Int, model: Model = .pro4) -> Data? {
        guard model == .pro5 else {
            print("ERROR: Custom mode is only supported on the 5 Pro")
            return nil
        }

        guard intensity >= 1 && intensity <= 5 else {
            print("ERROR: Invalid intensity. Must be between 1 and 5")
            return nil
        }

        return Data([0x06, 0x05, 0x00, 0x00, 0x04, UInt8(intensity)])
    }

    /// Enables or disables the cooler's "desk mode" while leaving the fan running.
    ///
    /// **5 Pro only.** This is a separate channel from the intensity, which is why no intensity
    /// step ever reaches zero: the slider sets *how hard* to cool, while desk mode reduces the
    /// Peltier output without stopping the fan. On a
    /// 4 Pro use `getSetCoolingPowerCommand(0)` instead, and set a fan speed to keep air moving.
    ///
    /// - Parameters:
    ///   - enabled: `true` for normal cooling, `false` for reduced cooling with the fan still on.
    ///   - model: The connected cooler.
    /// - Returns: The payload, or `nil` on a 4 Pro.
    public static func getSetCoolingEnabledCommand(_ enabled: Bool, model: Model = .pro4) -> Data? {
        guard model == .pro5 else {
            print("ERROR: Switching cooling separately is only supported on the 5 Pro")
            return nil
        }

        // 01 engages desk mode, which is cooling off. 00 returns to normal cooling.
        return Data([0x05, 0x07, 0x00, 0x00, enabled ? 0x00 : 0x01])
    }

    /// Sets a solid LED colour.
    ///
    /// The two models use completely different light commands: the 4 Pro takes a 47-byte `2f`
    /// frame, the 5 Pro a 16-byte `10` frame (its Standard / Steady-Glow mode). Both are built
    /// from the same arguments, so only `model` changes at the call site.
    ///
    /// - Parameters:
    ///   - red: 0-255.
    ///   - green: 0-255.
    ///   - blue: 0-255.
    ///   - brightness: 0-100. Applied by weighting the colours towards black, since neither
    ///     device has a separate brightness field in these frames.
    ///   - model: The connected cooler.
    /// - Returns: The payload, or `nil` if `brightness` is outside 0-100. Colour components
    ///   outside 0-255 are clamped into range rather than rejected.
    public static func getSetLEDColorCommand(_ red: Int, _ green: Int, _ blue: Int, brightness: Int, model: Model = .pro4) -> Data? {
        guard brightness >= 0 && brightness <= 100 else {
            print("ERROR: Invalid brightness value. Must be between 0 and 100")
            return nil
        }

        // We are putting a weight on the colors to simulate brightness.
        let color = LEDColor(red: red, green: green, blue: blue).scaled(brightness: brightness)

        if model == .pro5 {
            return pro5SolidColorFrame(color)
        }

        guard model == .pro4 else {
            print("ERROR: Custom LED colours are not supported on the FunCooler 6")
            return nil
        }

        let r = color.red
        let g = color.green
        let b = color.blue


        let payload = Data([
            0x2f, 0x01, 0x20, 0x00,
            0x06, // Mode
            0x00, 0xff, 0xff, 0xff, 0x00, 0x01,
            r, g, b,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00
        ])

        return payload
    }

    /// Turns the LEDs off.
    public static func getTurnOffLEDCommand(model: Model = .pro4) -> Data {
        if model == .pro5 {
            return pro5SolidColorFrame(LEDColor(red: 0, green: 0, blue: 0))
        }
        if model == .funCooler6 {
            return getSetFunCooler6LEDCommand(false)
        }
        if model == .funCooler6Max {
            return getSetFunCooler6MaxLEDCommand(false)
        }
        if model == .funCooler6Pro {
            return getSetFunCooler6ProLEDCommand(false)
        }

        return Data([
            0x2f, 0x01, 0x20, 0x00,
            0x01, // Mode
            0x00, 0xff, 0xff, 0xff, 0x00, 0x01,
            0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00
        ])
    }

    /// Enables the MagCooler 4 Pro Streamer lighting effect.
    ///
    /// This payload was captured and verified on physical MagCooler 4 Pro hardware.
    /// - Returns: The Streamer payload, or `nil` for devices other than the 4 Pro.
    public static func getSetLEDStreamerCommand(model: Model = .pro4) -> Data? {
        guard model == .pro4 else {
            print("ERROR: The Streamer lighting effect is only supported on the 4 Pro")
            return nil
        }

        var payload = [UInt8](repeating: 0x00, count: 47)
        payload[0] = 0x2f
        payload[1] = 0x01
        payload[2] = 0x20
        payload[4] = 0x02
        payload[6] = 0xff
        payload[7] = 0xff
        payload[8] = 0x10
        payload[9] = 0x0e
        return Data(payload)
    }

    private static func pro5SolidColorFrame(_ color: LEDColor) -> Data {
        return Data([
            0x10, 0x01, 0x10, 0x00,
            0x00, 0x09, 0xff, 0x00,
            0x64, // constant in every capture, possibly brightness
            0x01,
            color.red, color.green, color.blue,
            0x00, 0x00, 0x00
        ])
    }

    private static func a5Frame(command: UInt8, payload: [UInt8] = []) -> Data {
        var bytes: [UInt8] = [0xa5, UInt8(payload.count + 4), command]
        bytes.append(contentsOf: payload)
        bytes.append(UInt8(bytes.reduce(0) { ($0 + Int($1)) & 0xff }))
        return Data(bytes)
    }

    private static func hasValidA5Checksum(_ bytes: [UInt8]) -> Bool {
        guard let checksum = bytes.last else { return false }
        let expected = UInt8(bytes.dropLast().reduce(0) { ($0 + Int($1)) & 0xff })
        return checksum == expected
    }

    struct LEDColor: Sendable, Equatable {
        let red: UInt8
        let green: UInt8
        let blue: UInt8

        // Clamps each component to 0-255.
        init(red: Int, green: Int, blue: Int) {
            self.red = UInt8(max(0, min(255, red)))
            self.green = UInt8(max(0, min(255, green)))
            self.blue = UInt8(max(0, min(255, blue)))
        }

        // Scales the colour towards black to approximate a brightness level (0-100), the same
        // way getSetLEDColorCommand does it for the 4 Pro.
        func scaled(brightness: Int) -> LEDColor {
            let scale = Double(max(0, min(100, brightness))) / 100.0
            return LEDColor(
                red: Int(Double(red) * scale),
                green: Int(Double(green) * scale),
                blue: Int(Double(blue) * scale)
            )
        }
    }

}

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return self.map { String(format: format, $0) }.joined(separator: " ")
    }
}
