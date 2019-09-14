//
// Taken from this gist https://gist.github.com/antfarm/695fa78e0730b67eb094c77d53942216 by antfarm
//

class CRC32 {

    static var table: [UInt32] = {
        (0...255).map { idx -> UInt32 in
            (0..<8).reduce(UInt32(idx), { crc, _ in
                (crc % 2 == 0) ? (crc >> 1) : (0xEDB88320 ^ (crc >> 1))
            })
        }
    }()

    static func checksum(bytes: [UInt8]) -> UInt32 {
        return ~(bytes.reduce(~UInt32(0), { crc, byte in
            (crc >> 8) ^ table[(Int(crc) ^ Int(byte)) & 0xFF]
        }))
    }

}
