//
//  ChunkedDataReader.swift
//  card10badge
//
//  Created by Brechler, Philip on 16.08.19.
//  Copyright © 2019 Brechler, Philip. All rights reserved.
//

import UIKit

class ChunkedDataReader: NSObject {
    var dataToChunk: Data
    let packageSize = 20
    public var currentOffset: Int = 0

    init(_ data: Data) {
        dataToChunk = data
    }

    public func nextChunk() -> Data? {
        guard dataToChunk.count > 0 else { return nil }

        let dataToReturn = extractData(offset: currentOffset, length: packageSize)

        guard dataToReturn!.count > 0 else { return nil }

        currentOffset += packageSize

        return dataToReturn
    }

    func extractData(offset: Int, length: Int) -> Data? {

        guard dataToChunk.count > 0 else {
            return nil
        }

        var range: Range<Data.Index>
        // Create a range based on the length of data to return
        if dataToChunk.count >= offset+length {
            range = offset..<offset+length
        } else {
            range = offset..<dataToChunk.count
        }
        // Get a new copy of data
        let subData = dataToChunk.subdata(in: range)
        return subData
    }
}
