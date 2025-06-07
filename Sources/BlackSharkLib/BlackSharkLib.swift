import Foundation

public class BlackSharkLib {
    
    
    private static let manufacturerDataIdentifier: Data = Data([0x8F, 0x03])
    
   
    //region: Read actions
    private static let readCharacteristicsUUID   = Data([0xA0, 0x02])
    
    public static func getReadCharacteristicsUUID() -> Data {
        // Only one known characteristic for now
        return BlackSharkLib.readCharacteristicsUUID
    }
    
    
    // Write actions
    private static let writeCharacteristicsUUID  = Data([0xA0, 0x01])
    
    public static func getWriteCharacteristicsUUID() -> Data {
        // Only one known characteristic for now
        return BlackSharkLib.writeCharacteristicsUUID
    }
    
    
    public static func getTurnCoolingOffCommand() -> Data {
        // Sets the load-value to special mode 251.
        // This mode turns off both cooling and the fan.
        // This is the only valid way of turning the cooling off.
        // Do not try to set mode to 100, as that only turns the fan off, risking overheating.
        return Data([0x05, 0x02, 0x00, 0x00, 0xfb])
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
    
    public static func getSetLoadValueCommand(_ percentage: Int) -> Data? {
        
        guard percentage >= 0 && percentage <= 100 else {
            print("ERROR: Invalid percentage value. Must be between 0 and 100")
            return nil
        }
        
        // Convert to hex value
        let hexVal = UInt8(100 - percentage) // Value needs to be inverted.
        
        return Data([0x05, 0x02, 0x00, 0x00, hexVal])
    }
    
    init(){
        print("Hello world!")
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
