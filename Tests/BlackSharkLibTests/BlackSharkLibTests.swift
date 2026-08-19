import Testing
import Foundation

@testable import BlackSharkLib

@Suite("Device identification")
struct DeviceIdentificationTests {

    @Test func manufacturerDataIsRecognised() {
        let manufacturerData = Data([0x8F, 0x03, 0x01, 0x00] + Array("BSMC4PROBR42".utf8))
        #expect(BlackSharkLib.isBlackSharkDevice(manufacturerData) == true)
        #expect(BlackSharkLib.isBlackSharkDevice(Data([0x8F, 0x03])) == true)
    }

    @Test func foreignManufacturerDataIsRejected() {
        #expect(BlackSharkLib.isBlackSharkDevice(Data([0x4C, 0x00, 0x02])) == false)
        #expect(BlackSharkLib.isBlackSharkDevice(Data([0x8F])) == false)
        #expect(BlackSharkLib.isBlackSharkDevice(Data()) == false)
    }

    @Test func serviceUUIDIsUnchanged() {
        #expect(BlackSharkLib.getServiceUUID()
            == UUID(uuidString: "0000A0A0-3C17-D293-8E48-14FE2E4DA212")!)
        #expect(BlackSharkLib.getServiceUUID(model: .funCooler6Max)
            == BlackSharkLib.getServiceUUID())
    }

    @Test func displayProUsesSeparateTransport() {
        #expect(BlackSharkLib.getServiceUUID(model: .funCooler6Pro)
            == UUID(uuidString: "0000F530-1212-EFDE-1523-785FEABCD123")!)
        #expect(BlackSharkLib.getFunCooler6ProNotifyUUID()
            == UUID(uuidString: "0000F531-1212-EFDE-1523-785FEABCD123")!)
        #expect(BlackSharkLib.getFunCooler6ProWriteUUID()
            == UUID(uuidString: "0000F532-1212-EFDE-1523-785FEABCD123")!)
    }

    @Test func characteristicUUIDsAreUnchanged() {
        #expect(BlackSharkLib.getReadCharacteristicsUUID() == Data([0xA0, 0x02]))
        #expect(BlackSharkLib.getWriteCharacteristicsUUID() == Data([0xA0, 0x01]))
    }
}

@Suite("Model detection")
struct ModelDetectionTests {

    @Test func detectsModelFromAdvertisedName() {
        #expect(BlackSharkLib.detectModel(advertisedName: "Black Shark MagCooler 5pro") == .pro5)
        #expect(BlackSharkLib.detectModel(advertisedName: "Black Shark MagCooler 4pro") == .pro4)
        #expect(BlackSharkLib.detectModel(advertisedName: "BLACK SHARK MAGCOOLER 5PRO") == .pro5)
        #expect(BlackSharkLib.detectModel(advertisedName: "Black Shark FunCooler 6") == .funCooler6)
        #expect(BlackSharkLib.detectModel(advertisedName: "Black Shark Fun Cooler 6") == .funCooler6)
        #expect(BlackSharkLib.detectModel(advertisedName: "BR62") == .funCooler6)
        #expect(BlackSharkLib.detectModel(advertisedName: "Black Shark MagCooler 6MAX") == .funCooler6Max)
        #expect(BlackSharkLib.detectModel(advertisedName: "Black Shark FunCooler 6 Max") == .funCooler6Max)
        #expect(BlackSharkLib.detectModel(advertisedName: "Black Shark MagCooler 6Pro") == .funCooler6Pro)
        #expect(BlackSharkLib.detectModel(advertisedName: "Black Shark FunCooler 6 Pro") == .funCooler6Pro)
    }

    @Test func unknownOrMissingNameReturnsNil() {
        #expect(BlackSharkLib.detectModel(advertisedName: nil) == nil)
        #expect(BlackSharkLib.detectModel(advertisedName: "") == nil)
        #expect(BlackSharkLib.detectModel() == nil)
        #expect(BlackSharkLib.detectModel(advertisedName: "Black Shark MagCool") == nil)
    }
}

@Suite("parseMessages: 4 Pro")
struct FourProParseTests {

    @Test func coolingState() throws {
        let frame = Data([0x8a, 0x06, 0x00, 0x00, 0x01, 0x08, 0x00, 0x1c, 0x00, 0x00])
        let state = try #require(BlackSharkLib.parseMessages(frame) as? BlackSharkLib.CoolingState)
        #expect(state.model == .pro4)
        #expect(state.phoneTemperature == 8)
        #expect(state.heatsinkTemperature == 28)
        #expect(state.fanRPM == nil)
        #expect(state.powerLevel == nil)
        #expect(state.rawData == frame)
    }

    @Test func temperaturesAreSigned() throws {
        let frame = Data([0x8a, 0x06, 0x00, 0x00, 0x01, 0xff, 0x00, 0x3d, 0x00, 0x00])
        let state = try #require(BlackSharkLib.parseMessages(frame) as? BlackSharkLib.CoolingState)
        #expect(state.phoneTemperature == -1)
        #expect(state.heatsinkTemperature == 61)
    }

    @Test func fanState() throws {
        let frame = Data([0x86, 0x02, 0x10, 0x00, 0x14, 0x14])
        let state = try #require(BlackSharkLib.parseMessages(frame) as? BlackSharkLib.FanState)
        #expect(state.speed == 80)
        #expect(state.rawData == frame)
    }

    @Test func fanStateSpeedIsClamped() throws {
        let frame = Data([0x86, 0x02, 0x10, 0x00, 0xfa, 0x21])
        let state = try #require(BlackSharkLib.parseMessages(frame) as? BlackSharkLib.FanState)
        #expect(state.speed == 0)
    }
}

@Suite("parseMessages: 5 Pro")
struct FiveProParseTests {

    @Test(arguments: [
        // Hardware-captured with Shark Arsenal showing Custom Low.
        (Data([0x89, 0x06, 0x20, 0x00, 0xff, 0x25, 0xe2, 0x0e, 0x08]), -1, 37, 3810, 8),
        (Data([0x89, 0x06, 0x20, 0x00, 0xff, 0x25, 0xc4, 0x0e, 0x08]), -1, 37, 3780, 8),
        // Hardware-captured after Custom High had stabilised.
        (Data([0x89, 0x06, 0x20, 0x00, 0x00, 0x23, 0xbc, 0x16, 0x08]), 0, 35, 5820, 8),
        (Data([0x89, 0x06, 0x20, 0x00, 0x00, 0x23, 0xda, 0x16, 0x08]), 0, 35, 5850, 8),
        // Hardware-captured example confirming that the power field changes dynamically.
        (Data([0x89, 0x06, 0x20, 0x00, 0xf7, 0x2a, 0xa6, 0x0e, 0x13]), -9, 42, 3750, 19),
    ])
    func coolingState(frame: Data, cold: Int, hot: Int, rpm: Int, power: Int) throws {
        let state = try #require(BlackSharkLib.parseMessages(frame) as? BlackSharkLib.CoolingState)
        #expect(state.model == .pro5)
        #expect(state.phoneTemperature == cold)
        #expect(state.heatsinkTemperature == hot)
        #expect(state.fanRPM == rpm)
        #expect(state.powerLevel == power)
        #expect(state.devicePowerWatts == power)
        #expect(state.rawData == frame)
    }

    @Test func temperaturesAreSigned() throws {
        let frame = Data([0x89, 0x06, 0x20, 0x00, 0xec, 0x3d, 0x58, 0x11, 0x1c])
        let state = try #require(BlackSharkLib.parseMessages(frame) as? BlackSharkLib.CoolingState)
        #expect(state.phoneTemperature == -20)
        #expect(state.heatsinkTemperature == 61)
    }

    @Test func fanRPMIsLittleEndian() throws {
        let frame = Data([0x89, 0x06, 0x20, 0x00, 0x00, 0x32, 0xde, 0x12, 0x1c])
        let state = try #require(BlackSharkLib.parseMessages(frame) as? BlackSharkLib.CoolingState)
        #expect(state.fanRPM == 4830)
    }

    @Test func wrongTelemetryHeaderFallsThroughToUnknown() {
        let frame = Data([0x89, 0x06, 0x21, 0x00, 0x00, 0x23, 0xbc, 0x16, 0x08])
        #expect(BlackSharkLib.parseMessages(frame) is BlackSharkLib.UnknownMessage)
    }
}

@Suite("parseMessages: FunCooler 6 series")
struct FunCooler6SeriesParseTests {

    @Test func maxCoolingState() throws {
        let frame = Data([0x8b, 0x06, 0x20, 0x00, 0x05, 0x28, 0xec, 0x13, 0x19, 0x00, 0x00])
        let state = try #require(BlackSharkLib.parseMessages(frame) as? BlackSharkLib.CoolingState)
        #expect(state.model == .funCooler6Max)
        #expect(state.phoneTemperature == 5)
        #expect(state.heatsinkTemperature == 40)
        #expect(state.fanRPM == 5100)
        #expect(state.devicePowerWatts == 25)
    }

    @Test func displayProCoolingState() throws {
        let frame = Data([0xa5, 0x0a, 0x05, 0x0b, 0x34, 0x94, 0x11, 0x14, 0x0f, 0xbb])
        let state = try #require(BlackSharkLib.parseMessages(frame) as? BlackSharkLib.CoolingState)
        #expect(state.model == .funCooler6Pro)
        #expect(state.phoneTemperature == 11)
        #expect(state.heatsinkTemperature == 52)
        #expect(state.fanRPM == 4500)
        #expect(state.devicePowerWatts == 20)
    }

    @Test func displayProRejectsBadChecksum() {
        let frame = Data([0xa5, 0x0a, 0x05, 0x0b, 0x34, 0x94, 0x11, 0x14, 0x0f, 0xba])
        #expect(BlackSharkLib.parseMessages(frame) is BlackSharkLib.UnknownMessage)
    }
}

@Suite("parseMessages: malformed input")
struct MalformedParseTests {

    @Test func shortFramesFallThroughToUnknown() {
        let cases: [Data] = [
            Data(),
            Data([0x8a]),
            Data([0x8a, 0x06, 0x00]),
            Data([0x89, 0x06, 0x20]),
            Data([0x8a, 0x06, 0x00, 0x00, 0x01, 0x08, 0x00]),
            Data([0x86, 0x02, 0x10, 0x00]),
            Data([0x89, 0x06, 0x20, 0x00, 0x02, 0x32, 0x58, 0x11]),
        ]
        for frame in cases {
            let message = BlackSharkLib.parseMessages(frame)
            #expect(message is BlackSharkLib.UnknownMessage, "expected UnknownMessage for \(frame.hexEncodedString())")
            #expect(message.rawData == frame)
        }
    }

    @Test func unrecognisedCommandsFallThroughToUnknown() {
        let frame = Data([0xaf, 0x01, 0x20, 0x00, 0x01, 0x02, 0x03, 0x04])
        let message = BlackSharkLib.parseMessages(frame)
        #expect(message is BlackSharkLib.UnknownMessage)
        #expect(message.rawData == frame)
    }

    @Test func slicesParseTheSameAsWholeFrames() throws {
        let padding = Data([0xde, 0xad, 0xbe, 0xef])

        let cooling = Data([0x8a, 0x06, 0x00, 0x00, 0x01, 0x08, 0x00, 0x1c, 0x00, 0x00])
        let coolingState = try #require(
            BlackSharkLib.parseMessages((padding + cooling).dropFirst(padding.count))
                as? BlackSharkLib.CoolingState)
        #expect(coolingState.phoneTemperature == 8)
        #expect(coolingState.heatsinkTemperature == 28)

        let pro5 = Data([0x89, 0x06, 0x20, 0x00, 0x02, 0x32, 0x58, 0x11, 0x1c])
        let pro5State = try #require(
            BlackSharkLib.parseMessages((padding + pro5).dropFirst(padding.count))
                as? BlackSharkLib.CoolingState)
        #expect(pro5State.phoneTemperature == 2)
        #expect(pro5State.fanRPM == 4440)

        let fan = Data([0x86, 0x02, 0x10, 0x00, 0x14, 0x14])
        let fanState = try #require(
            BlackSharkLib.parseMessages((padding + fan).dropFirst(padding.count))
                as? BlackSharkLib.FanState)
        #expect(fanState.speed == 80)
    }

    @Test func shortSlicesFallThroughToUnknown() {
        let padding = Data([0xde, 0xad])
        let truncated = (padding + Data([0x8a, 0x06])).dropFirst(padding.count)
        #expect(BlackSharkLib.parseMessages(truncated) is BlackSharkLib.UnknownMessage)
    }
}

@Suite("Commands: 4 Pro")
struct FourProCommandTests {

    @Test func coolingMetadata() {
        #expect(BlackSharkLib.getCoolingMetadataCommand(model: .pro4)
            == Data([0x05, 0x06, 0x00, 0x00, 0x00]))
        #expect(BlackSharkLib.getCoolingMetadataCommand()
            == Data([0x05, 0x06, 0x00, 0x00, 0x00]))
    }

    @Test(arguments: [
        (100, UInt8(0x00)),
        (75,  UInt8(0x19)),
        (50,  UInt8(0x32)),
        (1,   UInt8(0x63)),
        (0,   UInt8(0xfb)),
    ])
    func fanSpeed(percentage: Int, expected: UInt8) {
        #expect(BlackSharkLib.getSetFanSpeedCommand(percentage)
            == Data([0x05, 0x02, 0x00, 0x00, expected]))
    }

    @Test(arguments: [
        (100, UInt8(0x00)),
        (75,  UInt8(0x19)),
        (50,  UInt8(0x32)),
        (1,   UInt8(0x63)),
        (0,   UInt8(0xfb)),
    ])
    func coolingPower(percentage: Int, expected: UInt8) {
        #expect(BlackSharkLib.getSetCoolingPowerCommand(percentage)
            == Data([0x05, 0x05, 0x00, 0x00, expected]))
    }

    @Test func outOfRangePercentagesReturnNil() {
        #expect(BlackSharkLib.getSetFanSpeedCommand(-1) == nil)
        #expect(BlackSharkLib.getSetFanSpeedCommand(101) == nil)
        #expect(BlackSharkLib.getSetCoolingPowerCommand(-1) == nil)
        #expect(BlackSharkLib.getSetCoolingPowerCommand(101) == nil)
    }

    @Test(arguments: [
        (BlackSharkLib.Pro4CoolingMode.mute, UInt8(0x2d), UInt8(0x60)),
        (BlackSharkLib.Pro4CoolingMode.overclocking, UInt8(0x14), UInt8(0x06)),
        (BlackSharkLib.Pro4CoolingMode.smart, UInt8(0xfa), UInt8(0xfa)),
    ])
    func coolingModes(mode: BlackSharkLib.Pro4CoolingMode, fanValue: UInt8, coolingValue: UInt8) throws {
        let commands = try #require(BlackSharkLib.getSetCoolingModeCommands(mode))
        #expect(commands == [
            Data([0x05, 0x02, 0x00, 0x00, fanValue]),
            Data([0x05, 0x05, 0x00, 0x00, coolingValue]),
        ])
    }

    @Test func ledColor() {
        let payload = BlackSharkLib.getSetLEDColorCommand(0x4D, 0xFF, 0x0C, brightness: 100)
        #expect(payload == Data([
            0x2f, 0x01, 0x20, 0x00,
            0x06,
            0x00, 0xff, 0xff, 0xff, 0x00, 0x01,
            0x4D, 0xFF, 0x0C,
        ] + [UInt8](repeating: 0x00, count: 33)))
        #expect(payload?.count == 47)
    }

    @Test func ledColorScalesByBrightness() {
        let payload = BlackSharkLib.getSetLEDColorCommand(255, 100, 0, brightness: 50)
        #expect(payload?[11] == 127)
        #expect(payload?[12] == 50)
        #expect(payload?[13] == 0)
    }

    @Test func turnOffLED() {
        let payload = BlackSharkLib.getTurnOffLEDCommand()
        #expect(payload == Data([
            0x2f, 0x01, 0x20, 0x00,
            0x01,
            0x00, 0xff, 0xff, 0xff, 0x00, 0x01,
            0x00, 0x00, 0x00,
        ] + [UInt8](repeating: 0x00, count: 33)))
        #expect(payload.count == 47)
    }

    @Test func streamerLED() throws {
        let payload = try #require(BlackSharkLib.getSetLEDStreamerCommand())
        var expected = [UInt8](repeating: 0x00, count: 47)
        expected[0] = 0x2f
        expected[1] = 0x01
        expected[2] = 0x20
        expected[4] = 0x02
        expected[6] = 0xff
        expected[7] = 0xff
        expected[8] = 0x10
        expected[9] = 0x0e
        #expect(payload == Data(expected))
    }
}

@Suite("Commands: 5 Pro")
struct FiveProCommandTests {

    @Test func coolingMetadata() {
        #expect(BlackSharkLib.getCoolingMetadataCommand(model: .pro5)
            == Data([0x05, 0x06, 0x20, 0x00, 0x00]))
    }

    @Test(arguments: [1, 2, 3, 4, 5])
    func customMode(intensity: Int) {
        #expect(BlackSharkLib.getSetCustomModeCommand(intensity: intensity, model: .pro5)
            == Data([0x06, 0x05, 0x00, 0x00, 0x04, UInt8(intensity)]))
    }

    @Test func outOfRangeIntensityReturnsNil() {
        #expect(BlackSharkLib.getSetCustomModeCommand(intensity: 0, model: .pro5) == nil)
        #expect(BlackSharkLib.getSetCustomModeCommand(intensity: 6, model: .pro5) == nil)
        #expect(BlackSharkLib.getSetCustomModeCommand(intensity: -1, model: .pro5) == nil)
    }

    @Test func coolingEnabled() {
        #expect(BlackSharkLib.getSetCoolingEnabledCommand(false, model: .pro5)
            == Data([0x05, 0x07, 0x00, 0x00, 0x01]))
        #expect(BlackSharkLib.getSetCoolingEnabledCommand(true, model: .pro5)
            == Data([0x05, 0x07, 0x00, 0x00, 0x00]))
    }

    @Test func ledColor() {
        let payload = BlackSharkLib.getSetLEDColorCommand(0x4D, 0xFF, 0x0C, brightness: 100, model: .pro5)
        #expect(payload == Data([
            0x10, 0x01, 0x10, 0x00, 0x00, 0x09, 0xff, 0x00, 0x64, 0x01,
            0x4D, 0xFF, 0x0C,
            0x00, 0x00, 0x00,
        ]))
        #expect(payload?.count == 16)
    }

    @Test func ledColorScalesByBrightness() {
        let payload = BlackSharkLib.getSetLEDColorCommand(255, 100, 0, brightness: 50, model: .pro5)
        #expect(payload?[10] == 127)
        #expect(payload?[11] == 50)
        #expect(payload?[12] == 0)
    }

    @Test func turnOffLEDSendsBlack() {
        #expect(BlackSharkLib.getTurnOffLEDCommand(model: .pro5) == Data([
            0x10, 0x01, 0x10, 0x00, 0x00, 0x09, 0xff, 0x00, 0x64, 0x01,
            0x00, 0x00, 0x00,
            0x00, 0x00, 0x00,
        ]))
    }
}

@Suite("Commands: FunCooler 6")
struct FunCooler6CommandTests {

    @Test func coolingModesAndPowerOff() {
        #expect(BlackSharkLib.getSetFunCooler6CoolingCommand(true, mode: .normal)
            == Data([0x06, 0x05, 0x00, 0x00, 0x02, 0x00]))
        #expect(BlackSharkLib.getSetFunCooler6CoolingCommand(true, mode: .silent)
            == Data([0x06, 0x05, 0x00, 0x00, 0x03, 0x00]))
        #expect(BlackSharkLib.getSetFunCooler6CoolingCommand(false, mode: .normal)
            == Data([0x06, 0x05, 0x00, 0x00, 0xfb, 0x00]))
        #expect(BlackSharkLib.getSetFunCooler6CoolingCommand(false, mode: .silent)
            == Data([0x06, 0x05, 0x00, 0x00, 0xfb, 0x00]))
    }

    @Test func ledCommands() {
        #expect(BlackSharkLib.getSetFunCooler6LEDCommand(true)
            == Data([0x05, 0x01, 0x00, 0x00, 0x00]))
        #expect(BlackSharkLib.getSetFunCooler6LEDCommand(false)
            == Data([0x05, 0x01, 0x00, 0x00, 0x03]))
        #expect(BlackSharkLib.getTurnOffLEDCommand(model: .funCooler6)
            == BlackSharkLib.getSetFunCooler6LEDCommand(false))
    }

    @Test func customColoursAreRejected() {
        #expect(BlackSharkLib.getSetLEDColorCommand(
            0x4d, 0xff, 0x0c, brightness: 100, model: .funCooler6) == nil)
    }
}

@Suite("Commands: FunCooler 6 Max")
struct FunCooler6MaxCommandTests {

    @Test func coolingModesAndPowerOff() {
        #expect(BlackSharkLib.getSetFunCooler6MaxCoolingCommand(true, mode: .overclocking)
            == Data([0x06, 0x05, 0x00, 0x00, 0x01, 0x00]))
        #expect(BlackSharkLib.getSetFunCooler6MaxCoolingCommand(true, mode: .smart)
            == Data([0x06, 0x05, 0x00, 0x00, 0x02, 0x00]))
        #expect(BlackSharkLib.getSetFunCooler6MaxCoolingCommand(true, mode: .silent)
            == Data([0x06, 0x05, 0x00, 0x00, 0x03, 0x00]))
        #expect(BlackSharkLib.getSetFunCooler6MaxCoolingCommand(false)
            == Data([0x06, 0x05, 0x00, 0x00, 0xfb, 0x00]))
    }

    @Test func metadataAndLEDCommands() {
        #expect(BlackSharkLib.getCoolingMetadataCommand(model: .funCooler6Max)
            == Data([0x05, 0x06, 0x20, 0x00, 0x00]))
        #expect(BlackSharkLib.getSetFunCooler6MaxLEDCommand(true)
            == Data([0x05, 0x01, 0x00, 0x00, 0x00]))
        #expect(BlackSharkLib.getSetFunCooler6MaxLEDCommand(false)
            == Data([0x05, 0x01, 0x00, 0x00, 0x03]))
        #expect(BlackSharkLib.getTurnOffLEDCommand(model: .funCooler6Max)
            == BlackSharkLib.getSetFunCooler6MaxLEDCommand(false))
    }
}

@Suite("Commands: display-equipped FunCooler 6 Pro")
struct FunCooler6ProCommandTests {

    @Test func coolingModesAndExperimentalPowerOff() {
        #expect(BlackSharkLib.getSetFunCooler6ProCoolingCommand(true, mode: .overclocking)
            == Data([0xa5, 0x06, 0x40, 0x00, 0x00, 0xeb]))
        #expect(BlackSharkLib.getSetFunCooler6ProCoolingCommand(true, mode: .smart)
            == Data([0xa5, 0x06, 0x40, 0x01, 0x00, 0xec]))
        #expect(BlackSharkLib.getSetFunCooler6ProCoolingCommand(true, mode: .silent)
            == Data([0xa5, 0x06, 0x40, 0x02, 0x00, 0xed]))
        #expect(BlackSharkLib.getSetFunCooler6ProCoolingCommand(false)
            == Data([0xa5, 0x06, 0x40, 0xfb, 0x00, 0xe6]))
    }

    @Test func metadataAndLEDCommands() {
        #expect(BlackSharkLib.getCoolingMetadataCommand(model: .funCooler6Pro)
            == Data([0xa5, 0x04, 0x05, 0xae]))
        #expect(BlackSharkLib.getSetFunCooler6ProLEDCommand(true)
            == Data([0xa5, 0x05, 0x10, 0x00, 0xba]))
        #expect(BlackSharkLib.getSetFunCooler6ProLEDCommand(false)
            == Data([0xa5, 0x05, 0x10, 0x03, 0xbd]))
        #expect(BlackSharkLib.getTurnOffLEDCommand(model: .funCooler6Pro)
            == BlackSharkLib.getSetFunCooler6ProLEDCommand(false))
    }
}

@Suite("Model gating")
struct ModelGatingTests {

    @Test func commandsDefaultToFourPro() {
        #expect(BlackSharkLib.getCoolingMetadataCommand()
            == BlackSharkLib.getCoolingMetadataCommand(model: .pro4))
        #expect(BlackSharkLib.getSetFanSpeedCommand(50)
            == BlackSharkLib.getSetFanSpeedCommand(50, model: .pro4))
        #expect(BlackSharkLib.getSetCoolingPowerCommand(50)
            == BlackSharkLib.getSetCoolingPowerCommand(50, model: .pro4))
        #expect(BlackSharkLib.getTurnOffLEDCommand()
            == BlackSharkLib.getTurnOffLEDCommand(model: .pro4))
        #expect(BlackSharkLib.getSetLEDColorCommand(1, 2, 3, brightness: 100)
            == BlackSharkLib.getSetLEDColorCommand(1, 2, 3, brightness: 100, model: .pro4))
    }

    @Test func fourProOnlyCommandsRejectFivePro() {
        #expect(BlackSharkLib.getSetFanSpeedCommand(50, model: .pro5) == nil)
        #expect(BlackSharkLib.getSetCoolingPowerCommand(50, model: .pro5) == nil)
        #expect(BlackSharkLib.getSetCoolingModeCommands(.smart, model: .pro5) == nil)
        #expect(BlackSharkLib.getSetLEDStreamerCommand(model: .pro5) == nil)
    }

    @Test func fiveProOnlyCommandsRejectFourPro() {
        #expect(BlackSharkLib.getSetCustomModeCommand(intensity: 3, model: .pro4) == nil)
        #expect(BlackSharkLib.getSetCoolingEnabledCommand(false, model: .pro4) == nil)
    }
}

@Suite("Input validation")
struct InputValidationTests {

    @Test func outOfRangeBrightnessReturnsNil() {
        #expect(BlackSharkLib.getSetLEDColorCommand(0, 0, 0, brightness: -1) == nil)
        #expect(BlackSharkLib.getSetLEDColorCommand(0, 0, 0, brightness: 101) == nil)
        #expect(BlackSharkLib.getSetLEDColorCommand(0, 0, 0, brightness: -1, model: .pro5) == nil)
        #expect(BlackSharkLib.getSetLEDColorCommand(0, 0, 0, brightness: 101, model: .pro5) == nil)
    }

    @Test func outOfRangeColourComponentsAreClamped() {
        let pro4 = BlackSharkLib.getSetLEDColorCommand(300, -20, 999, brightness: 100)
        #expect(pro4?[11] == 255)
        #expect(pro4?[12] == 0)
        #expect(pro4?[13] == 255)

        let pro5 = BlackSharkLib.getSetLEDColorCommand(300, -20, 999, brightness: 100, model: .pro5)
        #expect(pro5?[10] == 255)
        #expect(pro5?[11] == 0)
        #expect(pro5?[12] == 255)
    }

    @Test func extremeColourValuesDoNotCrash() {
        #expect(BlackSharkLib.getSetLEDColorCommand(Int.max, Int.min, 0, brightness: 100) != nil)
        #expect(BlackSharkLib.getSetLEDColorCommand(Int.max, Int.min, 0, brightness: 50, model: .pro5) != nil)
    }
}
