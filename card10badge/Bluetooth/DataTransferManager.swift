//
//  DataTransferManager.swift
//  card10badge
//
//  Created by Brechler, Philip on 16.08.19.
//  Copyright © 2019 Brechler, Philip. All rights reserved.
//

import CoreBluetooth

// To make those identifiers look more C-lick we'll make an exception here
// swiftlint:disable identifier_name
enum TransferState {
    case IDLE
    case START_SENT
    case READY_TO_SEND
    case CHUNK_SENT
    case FINISH_SENT
}

enum PackageType: String {
    case START = "s"
    case START_ACK = "S"
    case CHUNK = "c"
    case CHUNK_ACK = "C"
    case FINISH = "f"
    case FINISH_ACK = "F"
    case ERROR = "e"
    case ERROR_ACK = "E"
}
// swiftlint:enable identifier_name

protocol DataTransferManagerDelegate: class {
    func wantsToSendPackage(_ package: Data)
    func didUpdateState(_ state: TransferState)
    func didUpdateProgress(_ progress: Double)
    func didFailToSendFile()
}

class DataTransferManager: NSObject {

    weak var delegate: DataTransferManagerDelegate?

    var chunkedReader: ChunkedDataReader?
    var transferState: TransferState {
        didSet {
            delegate?.didUpdateState(self.transferState)
        }
    }

    var lastPackageSentAt: TimeInterval?
    var dataToSend: Data?
    var currentChunkToSend: Data?
    var retryCount: Int = 0

    init(_ delegateToUse: DataTransferManagerDelegate) {
        delegate = delegateToUse
        self.transferState = .IDLE
    }

    public func receivedNewPackage(_ package: Data) {
        let stringPackaage = String(data: package, encoding: String.Encoding.ascii)
        let firstChar = String(stringPackaage!.prefix(1))
        let packageType = PackageType(rawValue: firstChar)
        switch packageType {
        case .START?:
            break

        case .START_ACK?:
            self.transferState = .READY_TO_SEND
            let chunkToSend = self.chunkedReader?.nextChunk()
            guard chunkToSend!.count > 0 else { self.sendPackage(type: .ERROR, payload: nil, offset: 0); return }
            self.currentChunkToSend = chunkToSend
            sendPackage(type: .CHUNK, payload: chunkToSend, offset: 0)
        case .CHUNK?:
            break

        case .CHUNK_ACK?:
            self.transferState = .CHUNK_SENT
            // calculate CRC and send new chunk
            let range: Range<Data.Index> = 0..<1
            let crc = package.subdata(in: range)
            updateProgress()
            if checkChunkWithResponse(crc) {
                if currentChunkToSend!.count < chunkedReader!.packageSize {
                    // The last package arrived, we are done here
                    sendPackage(type: .FINISH, payload: nil, offset: 0)
                    break
                } else {
                    let chunkToSend = self.chunkedReader?.nextChunk()
                    guard chunkToSend != nil else { self.sendPackage(type: .ERROR, payload: nil, offset: 0); return }
                    self.currentChunkToSend = chunkToSend
                    sendPackage(type: .CHUNK, payload: chunkToSend, offset: self.chunkedReader!.currentOffset-20)
                }
            } else if retryCount < 9 {
                sendPackage(type: .CHUNK, payload: self.currentChunkToSend, offset: self.chunkedReader!.currentOffset-20)
                retryCount += 1
            } else {
                self.sendPackage(type: .ERROR, payload: nil, offset: 0)
            }

        case .FINISH?:
            break

        case .FINISH_ACK?:
            // finished, cleanup
            self.transferState = .FINISH_SENT
            self.chunkedReader = nil
            self.dataToSend = nil
            self.transferState = .IDLE

        case .ERROR?:
            // fucked up, send error ack
            print("Error from card10, message ", String(data: package, encoding: .ascii)!)
            self.sendPackage(type: .ERROR_ACK, payload: nil, offset: 0)
            delegate?.didFailToSendFile()
            break

        case .ERROR_ACK?:
            // device knows we aborted
            self.chunkedReader = nil
            self.dataToSend = nil
            self.transferState = .IDLE

        default:
            print("Broken Package ", firstChar)
        }
    }

    public func transferData(_ data: Data, filename: String) {
        guard let fileNameData = filename.data(using: .ascii) else { return } //TODO: Tell the user it failed

        chunkedReader = ChunkedDataReader(data)
        self.dataToSend = data
        self.transferState = .IDLE

        sendPackage(type: .START, payload: fileNameData, offset: 0)
        self.transferState = .START_SENT
    }

    func sendPackage(type: PackageType, payload: Data?, offset: Int) {

        var payloadToSend: Data?

        switch type {
        case .START:
            payloadToSend = PackageType.START.rawValue.data(using: .ascii)
            payloadToSend?.append(payload!)
            lastPackageSentAt = NSDate.init().timeIntervalSinceNow

        case .START_ACK:
            break

        case .CHUNK:
            payloadToSend = PackageType.CHUNK.rawValue.data(using: .ascii)
            var int = UInt32(bigEndian: UInt32(offset))
            payloadToSend?.append(Data(bytes: &int, count: MemoryLayout.size(ofValue: UInt32())))
            payloadToSend?.append(payload!)
            lastPackageSentAt = NSDate.init().timeIntervalSinceNow

        case .CHUNK_ACK:
            break

        case .FINISH:
            payloadToSend = PackageType.FINISH.rawValue.data(using: .ascii)

        case .FINISH_ACK:
            break

        case .ERROR:
            payloadToSend = PackageType.ERROR.rawValue.data(using: .ascii)
            delegate?.didFailToSendFile()

        case .ERROR_ACK:
            payloadToSend = PackageType.ERROR_ACK.rawValue.data(using: .ascii)
            delegate?.didFailToSendFile()
        }
        if payloadToSend != nil {
            delegate?.wantsToSendPackage(payloadToSend!)
        }
    }

    func checkChunkWithResponse(_ response: Data) -> Bool {

        return true

        //FIXME: This CRC32 implementation doesn't work. Disabled for now
        let responseInUInt32 = response.withUnsafeBytes { $0.load(as: UInt8.self) }
        let chunkInUInt8 = [UInt8](self.currentChunkToSend!)
        let checksum = CRC32.checksum(bytes: chunkInUInt8)
        if responseInUInt32 == checksum {
            return true
        }
        return false
    }

    func updateProgress() {
        guard chunkedReader != nil && dataToSend != nil else { return }

        let progress = Double(chunkedReader!.currentOffset) / Double(self.dataToSend!.count)
        print("Progress sending file: ", progress)
        delegate?.didUpdateProgress(progress)
    }
}
