//
//  DataExtensions.swift
//
//  Created by Boris Polania on 2/16/18.
//

import UIKit

extension Data {

    var uint8: UInt8 {
        var number: UInt8 = 0
        self.copyBytes(to: &number, count: MemoryLayout<UInt8>.size)
        return number
    }

    var uint16: UInt16 {
        let i16array = self.withUnsafeBytes {
            UnsafeBufferPointer<UInt16>(start: $0, count: self.count/2).map(UInt16.init(littleEndian:))
        }
        return i16array[0]
    }

    var uint32: UInt32 {
        let i32array = self.withUnsafeBytes {
            UnsafeBufferPointer<UInt32>(start: $0, count: self.count/2).map(UInt32.init(littleEndian:))
        }
        return i32array[0]
    }

    var uint64: UInt64 {
        let i64array = self.withUnsafeBytes {
            UnsafeBufferPointer<UInt64>(start: $0, count: self.count/2).map(UInt64.init(littleEndian:))
        }
        return i64array[0]
    }

    var uuid: NSUUID? {
        var bytes = [UInt8](repeating: 0, count: self.count)
        self.copyBytes(to: &bytes, count: self.count * MemoryLayout<UInt32>.size)
        return NSUUID(uuidBytes: bytes)
    }
    var stringASCII: String? {
        return NSString(data: self, encoding: String.Encoding.ascii.rawValue) as String?
    }

    var stringUTF8: String? {
        return NSString(data: self, encoding: String.Encoding.utf8.rawValue) as String?
    }

    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }

}
