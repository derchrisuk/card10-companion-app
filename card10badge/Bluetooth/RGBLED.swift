//
//  RGBLED.swift
//  card10badge
//
//  Created by Ruotger Deecke on 23.8.19.
//  Copyright © 2019 Brechler, Philip. All rights reserved.
//

import Foundation

struct RGBLED {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    public var data: Data {
        return Data([red, green, blue])
    }

    public static func randomRGB() -> RGBLED {
        var red: UInt8 = 0
        var green: UInt8 = 0
        var blue: UInt8 = 0

        while UInt64(red) + UInt64(green) + UInt64(blue) == UInt64(0) {
            red = UInt8.random(in: 0..<3) * 127 // 128 would overflow UInt 😬
            green = UInt8.random(in: 0..<3) * 127
            blue = UInt8.random(in: 0..<3) * 127
        }
        return RGBLED(red: red, green: green, blue: blue)
    }

}
