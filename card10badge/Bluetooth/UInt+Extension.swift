//
//  UInt+Extension.swift
//  card10badge
//
//  Created by Thomas Mellenthin on 18.08.19.
//  Copyright © 2019 Brechler, Philip. All rights reserved.
//

import Foundation

protocol isDataInt: FixedWidthInteger, UnsignedInteger {
    var data: Data { get }
}

extension isDataInt {
    public var data: Data {
        var int = self
        return Data(bytes: &int, count: MemoryLayout<Self>.size)
    }
}

extension UInt16: isDataInt { }
extension UInt64: isDataInt { }
