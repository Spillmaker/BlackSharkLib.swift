import Foundation

public class BlackSharkLib {
    
    
    private static let manufacturerDataIdentifier: Data = Data([0x8F, 0x03])
    public static func isBlackSharkDevice(_ manufacturerData: Data) -> Bool {
        return manufacturerData.starts(with: manufacturerDataIdentifier)
    }
    
   
    //
    // Read
    //
    private static let readCharacteristicsUUID   = Data([0xA0, 0x02])
    
    public protocol Message {
        var rawData: Data { get }
    }
    
    public struct CoolingState: Message {
        public let rawData: Data
        public let phoneTemperature: Int
        public let heatsinkTemperature: Int
    }
    
    public struct FanState: Message {
        public let rawData: Data
        public let speed: Int // 0-100%
    }
    
    public struct UnknownMessage: Message {
        public let rawData: Data
    }
    
    public static func getReadCharacteristicsUUID() -> Data {
        // Only one known characteristic for now
        return BlackSharkLib.readCharacteristicsUUID
    }
    
    public static func parseMessages(_ data: Data) -> Message {
        // data[0] is a split. First part of hex is always 8, second half is the lengthbit.
        // data[1-2] is the command (that it responds to)
        // data[3] is a spacer(?) seems to always be 0x00
        
        // 02 10 - Fan status
        if data[1] == 0x02 && data[2] == 0x10 {
            // Fan speed is either data[4] or data[5]
            // Both are identical. I suspect one of them are the cooling value, but i dont know how to adjust them independently yet.
            let speed = max(0, min(100, 100 - Int(data[4])))

            return FanState(rawData: data, speed: speed)
        }
        
        // 06 00 - Cooling status
        if data[1] == 0x06 && data[2] == 0x00 {
            // data[5] - Temperature on the Phone side
            let phoneTemperature = Int(Int8(bitPattern: UInt8(data[5])))
            
            // data[7] - Temperature on the heatsink
            let heatsinkTemperature = Int(Int8(bitPattern: UInt8(data[7])))
            
            return CoolingState(rawData: data, phoneTemperature: phoneTemperature, heatsinkTemperature: heatsinkTemperature)
        }
        
        // Return generig message
        return UnknownMessage(rawData: data)
    }
    
    
    //	
    // Write
    //
    private static let writeCharacteristicsUUID  = Data([0xA0, 0x01])
    
    public static func getWriteCharacteristicsUUID() -> Data {
        // Only one known characteristic for now
        return BlackSharkLib.writeCharacteristicsUUID
    }
    
    public static func getCoolingMetadataCommand() -> Data {
        // Makes the read-channel return metadata about the cooling. (Temp, etc)
        return Data([0x05, 0x06, 0x00, 0x00, 0x00])
    }
    
    public static func getEnableSmartModeCommand() -> Data {
        // Sets the load-value to special mode 250.
        // This mode attempts to balance cooling with exhaust air temperature,
        // making it "cooler" on the hands to cool the device down.
        // Cooling will be slower, but if you are holding the hands close to the exhaust this may be the
        // most comfortable aproach.
        return Data([0x05, 0x02, 0x00, 0x00, 0xfa])
    }
    
    public static func getSetFanSpeedCommand(_ percentage: Int) -> Data? {
                
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
    
    public static func getSetCoolingPowerCommand(_ percentage: Int) -> Data? {
        
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
    
    public static func getSetLEDColorCommand(_ red: Int, _ green: Int, _ blue: Int, brightness: Int) -> Data? {
        guard brightness >= 0 && brightness <= 100 else {
            print("ERROR: Invalid brightness value. Must be between 0 and 100")
            return nil
        }

        // We are putting a weight on the colors to simulate brightness
        let scale = Double(brightness) / 100.0
        let r = UInt8(Double(red) * scale)
        let g = UInt8(Double(green) * scale)
        let b = UInt8(Double(blue) * scale)
        
        
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
    
    public static func getTurnOffLEDCommand() -> Data {
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
