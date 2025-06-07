import Testing
import Foundation

@testable import BlackSharkLib



@Test func getReadCharacteristicsUUID() async throws {
    let test = BlackSharkLib.getReadCharacteristicsUUID()
    print("Read Characteristics ID: " + test.hexEncodedString())
    #expect(test == Data([0xA0, 0x02]))
}



@Test func getWriteCharacteristicsUUID() async throws {
    let test = BlackSharkLib.getWriteCharacteristicsUUID()
    print("Write Characteristics ID: " + test.hexEncodedString())
    #expect(test == Data([0xA0, 0x01]))
}
