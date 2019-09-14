//
//  AboveLEDs.swift
//  card10badge
//
//  Created by Ruotger Deecke on 23.8.19.
//  Copyright © 2019 Brechler, Philip. All rights reserved.
//

import Foundation

struct AboveLEDs {
    let LEDs: [RGBLED]

    public var data: Data {
        assert(LEDs.count == 11)

        var result = Data()

        for led in LEDs {
            result.append(led.data)
        }

        return result
    }

    private static func combineValues(_ rgbValue: () -> RGBLED) -> AboveLEDs {

        var LEDs: [RGBLED] = []
        for _ in 0 ..< 11 {
            LEDs.append(rgbValue())
        }
        return AboveLEDs(LEDs: LEDs)
    }

    public static func randomRGB() -> AboveLEDs {
        return combineValues({ RGBLED.randomRGB() })
    }

    public static func off() -> AboveLEDs {
        return combineValues({ RGBLED(red: 0, green: 0, blue: 0) })
    }
}
