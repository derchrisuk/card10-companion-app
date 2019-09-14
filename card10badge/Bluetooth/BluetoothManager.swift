//
//  BluetoothManager.swift
//  card10badge
//
//  Created by Brechler, Philip on 15.08.19.
//  Copyright © 2019 Brechler, Philip. All rights reserved.
//

import CoreBluetooth

protocol BluetoothManagerDelegate: class {
    func didFindNewPeripherals(_ peripherals: [FoundPeripheral]?)
    func didConnectToPeripheal(_ peripheral: FoundPeripheral?)
    func didDisconnectFromPeripheral()
    func didGetNewLightSensorData(_ data: UInt16)
    func didFinishToSendFile()
    func didFailToSendFile()
    func didUpdateProgressOnFile(_ progress: Double)
}

// Provide default empty implementation to avoid empty boilerplate in the delegate
extension BluetoothManagerDelegate {
    func didFindNewPeripherals(_ peripherals: [FoundPeripheral]?) {}
    func didConnectToPeripheal(_ peripheral: FoundPeripheral?) {}
    func didDisconnectFromPeripheral() {}
    func didGetNewLightSensorData(_ data: UInt16) {}
    func didFinishToSendFile() {}
    func didFailToSendFile() {}
    func didUpdateProgressOnFile(_ progress: Double) {}
}

public struct FoundPeripheral: Hashable {
    let peripheral: CBPeripheral
    let advertisementName: String?
    let rssi: Int?
}

struct WeakDelegate {
    private(set) weak var value: BluetoothManagerDelegate?
    init (value: BluetoothManagerDelegate) {
        self.value = value
    }
}

class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, DataTransferManagerDelegate {

    static private let _sharedInstance =  BluetoothManager()
    public static func sharedInstance() -> BluetoothManager {
        // break reference cycles by turning shared instance into a method
        return BluetoothManager._sharedInstance
    }

    var dataTransferManager: DataTransferManager?

    var centralManager: CBCentralManager!

    /// card10 main service
    let card10ServiceUUID = CBUUID(string: "0x42230200-2342-2342-2342-234223422342")
    /// Time update characteristic (write)
    let card10TimeCharacteristic = CBUUID(string: "42230201-2342-2342-2342-234223422342")
    /// Vibra characteristic (write)
    let card10VibrateCharacteristic = CBUUID(string: "4223020f-2342-2342-2342-234223422342")
    /// Rockets characteristic (write)
    let card10RocketsCharacteristic = CBUUID(string: "42230210-2342-2342-2342-234223422342")
    /// Background LED Bottom Left characteristic (write)
    let card10BackgroundLedBottomLeftCharacteristic = CBUUID(string: "42230211-2342-2342-2342-234223422342")
    /// Background LED Bottom Right characteristic (write)
    let card10BackgroundLedBottomRightCharacteristic = CBUUID(string: "42230212-2342-2342-2342-234223422342")
    /// Background LED Top Right characteristic (write)
    let card10BackgroundLedTopRightCharacteristic = CBUUID(string: "42230213-2342-2342-2342-234223422342")
    /// Background LED Top Left characteristic (write)
    let card10BackgroundLedTopLeftCharacteristic = CBUUID(string: "42230214-2342-2342-2342-234223422342")
    /// LEDS dim bottom characteristic (write)
    let card10LedsDimBottomCharacteristic = CBUUID(string: "42230215-2342-2342-2342-234223422342")
    /// LEDS dim top characteristic (write)
    let card10LedsDimTopCharacteristic = CBUUID(string: "42230216-2342-2342-2342-234223422342")
    /// LEDs above characteristic (write)
    let card10LedsAboveCharacteristic = CBUUID(string: "42230220-2342-2342-2342-234223422342")
    /// Single rgb led characteristic (write)
    let card10SingleRgbLedCharacteristic = CBUUID(string: "422302ef-2342-2342-2342-234223422342")
    /// Light sensor characteristic
    let card10LightSensorCharacteristic = CBUUID(string: "422302f0-2342-2342-2342-234223422342")

    /// File transfer service.  The two channels are seen from the Central perspective (iOS device)
    /// and hence named Central TX and Central RX.
    let card10RxTxServiceUUID = CBUUID(string: "42230100-2342-2342-2342-234223422342")
    let card10TXWriteCharacteristicUUID = CBUUID(string: "42230101-2342-2342-2342-234223422342")
    let card10RXReadCharacteristicUUID = CBUUID(string: "42230102-2342-2342-2342-234223422342")

    private(set) public var foundPeripheral: [FoundPeripheral]
    public var connectedPeripheral: CBPeripheral?

    /// Holds BluetoothManagerDelegates weakly
    private var subscribers: [WeakDelegate] = []

    private(set) public var isScanning: Bool = false

    override init() {
        foundPeripheral = []
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Public Functions

    public func subscribe(_ subscriber: BluetoothManagerDelegate) {
        subscribers.append(WeakDelegate(value: subscriber))
    }

    public func unsubscribe(_ subscriber: BluetoothManagerDelegate) {
        subscribers.removeAll { (delegate) -> Bool in
            return delegate.value == nil || delegate.value === subscriber
        }
    }

    public func startScan() {
        guard isScanning == false, centralManager.state == .poweredOn else { return }
        isScanning = true

        foundPeripheral = []
        subscribers.forEach { $0.value?.didFindNewPeripherals(self.foundPeripheral) }

        let connectedDevices = centralManager.retrieveConnectedPeripherals(withServices: [card10ServiceUUID])
        for device in connectedDevices {
            foundPeripheral.append(FoundPeripheral.init(peripheral: device, advertisementName: "card10-connected", rssi: 100))
            centralManager.connect(device, options: nil)
        }
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        print("scan started")
    }

    public func stopScan() {
        guard isScanning == true else { return }
        isScanning = false

        centralManager.stopScan()
        print("scan stopped")
    }

    public var state: CBManagerState {
        return centralManager.state
    }

    public func connectToCard10Badge(peripheral: CBPeripheral) {
        print("connecting to \(peripheral.identifier)...")
        centralManager.connect(peripheral, options: nil)
    }

    public func disconnectFromCard10Badge() {
        guard self.connectedPeripheral != nil else { return }
        centralManager.cancelPeripheralConnection(self.connectedPeripheral!)
    }

    /// Starts BLE pairing process by writing the time characteristics. This triggers
    /// the pairing process. FIXME: not working due to FW disconnect after bonding glitch.
    public func pairWithCard10Badge(peripheral: CBPeripheral) {
        setTimeOnPeripheral()
    }

    public func sendFileData(data: Data, fileName: String) {

        guard self.connectedPeripheral != nil else {
            subscribers.forEach { $0.value?.didFailToSendFile() }
            return
        }

        self.dataTransferManager = DataTransferManager(self)
        self.subscribeToRxChannel()

        self.dataTransferManager?.transferData(data, filename: fileName)
    }

    public func setTimeOnPeripheral() {
        guard let peripheral = self.connectedPeripheral else {
            print("setTimeOnPeripheral() failed, self.connectedPeripheral is nil")
            return
        }

        guard let characteristic = self.findCharacteristic(on: peripheral,
                                                           forServiceUUID: card10ServiceUUID,
                                                           forCharacteristicUUID: card10TimeCharacteristic) else {
            print("could not find time characteristic!")
            return
        }
        let currentDate: Date = Date()

        let unixTimeWithTimeZoneOffset: Int = Int(Date().timeIntervalSince1970)
        let badgeTimeInMilliseconds: UInt64 = UInt64(unixTimeWithTimeZoneOffset * 1000 )

        let time = UInt64(bigEndian: badgeTimeInMilliseconds)

        print("setTimeOnPeripheral \(peripheral.identifier) to \(currentDate) (\(badgeTimeInMilliseconds))")
        self.connectedPeripheral?.writeValue(time.data, for: characteristic, type: .withoutResponse)
    }

    public func setVibrate(milliseconds: UInt16) {
        guard let peripheral = self.connectedPeripheral else { return } //TODO: Tell the delegate it failed?

        guard let characteristic = self.findCharacteristic(on: peripheral, forServiceUUID: card10ServiceUUID, forCharacteristicUUID: card10VibrateCharacteristic) else {
            print("could not find vibration characteristic!")
            return
        }

        print("setVibrate \(milliseconds) ms on \(peripheral.identifier)")
        self.connectedPeripheral?.writeValue(milliseconds.data, for: characteristic, type: .withoutResponse)
    }

    public func illuminateRocketsWithBrightness(rocketOne: UInt8, rocketTwo: UInt8, rocketThree: UInt8) {
        guard let peripheral = self.connectedPeripheral else { return } //TODO: Tell the delegate it failed?

        guard let characteristic = self.findCharacteristic(on: peripheral, forServiceUUID: card10ServiceUUID, forCharacteristicUUID: card10RocketsCharacteristic) else {
            print("could not find card10RocketsCharacteristic!")
            return
        }

        print("set rockets to \(rocketOne), \(rocketTwo), \(rocketThree) on \(peripheral.identifier)")
        self.connectedPeripheral?.writeValue(Data([rocketOne, rocketTwo, rocketThree]), for: characteristic, type: .withoutResponse)
    }

    public func setBackgroundLEDs (topLeft: RGBLED, topRight: RGBLED, bottomRight: RGBLED, bottomLeft: RGBLED) {
        guard let peripheral = self.connectedPeripheral else { return } //TODO: Tell the delegate it failed?

        guard let tlCharacteristic = self.findCharacteristic(on: peripheral,
                                                             forServiceUUID: card10ServiceUUID,
                                                             forCharacteristicUUID: card10BackgroundLedTopLeftCharacteristic),
            let trCharacteristic = self.findCharacteristic(on: peripheral,
                                                           forServiceUUID: card10ServiceUUID,
                                                           forCharacteristicUUID: card10BackgroundLedTopRightCharacteristic),
            let brCharacteristic = self.findCharacteristic(on: peripheral,
                                                           forServiceUUID: card10ServiceUUID,
                                                           forCharacteristicUUID: card10BackgroundLedBottomRightCharacteristic),
            let blCharacteristic = self.findCharacteristic(on: peripheral,
                                                           forServiceUUID: card10ServiceUUID,
                                                           forCharacteristicUUID: card10BackgroundLedBottomLeftCharacteristic) else {
            print("setBackgroundLEDs could not find card10RocketsCharacteristic!")
            return
        }

        self.connectedPeripheral?.writeValue(topLeft.data, for: tlCharacteristic, type: .withoutResponse)
        self.connectedPeripheral?.writeValue(topRight.data, for: trCharacteristic, type: .withoutResponse)
        self.connectedPeripheral?.writeValue(bottomRight.data, for: brCharacteristic, type: .withoutResponse)
        self.connectedPeripheral?.writeValue(bottomLeft.data, for: blCharacteristic, type: .withoutResponse)
    }

    /// Set's the 11 RGB leds at the top. Parameters are from left to right.
    public func setLEDsAbove(_ aboveLEDs: AboveLEDs) {
        guard let peripheral = self.connectedPeripheral else { return } //TODO: Tell the delegate it failed?

        guard let aboveCharacteristic = self.findCharacteristic(on: peripheral,
                                                                forServiceUUID: card10ServiceUUID,
                                                                forCharacteristicUUID: card10LedsAboveCharacteristic) else {
                                                                    print("setLEDsAbove could not find card10RocketsCharacteristic!")
                                                                    return
        }

        self.connectedPeripheral?.writeValue(aboveLEDs.data,
                                             for: aboveCharacteristic,
                                             type: .withoutResponse)
    }

    public func getLightSensorData() {
        guard let peripheral = self.connectedPeripheral else { return } //TODO: Tell the delegate it failed?

        guard let characteristic = self.findCharacteristic(on: peripheral, forServiceUUID: card10ServiceUUID, forCharacteristicUUID: card10LightSensorCharacteristic) else { return }

        self.connectedPeripheral?.readValue(for: characteristic)
    }

    // MARK: - File Transfer Helpers

    func subscribeToRxChannel() {
        guard let peripheral = self.connectedPeripheral else { return } //TODO: Tell the delegate it failed?

        guard let characteristic = self.findCharacteristic(on: peripheral, forServiceUUID: card10RxTxServiceUUID, forCharacteristicUUID: card10RXReadCharacteristicUUID) else { return }

        self.connectedPeripheral?.setNotifyValue(true, for: characteristic)
    }

    func unsubscrubeFromRxChannel() {
        guard let peripheral = self.connectedPeripheral else { return } //TODO: Tell the delegate it failed?

        guard let characteristic = self.findCharacteristic(on: peripheral, forServiceUUID: card10RxTxServiceUUID, forCharacteristicUUID: card10RXReadCharacteristicUUID) else { return }

        self.connectedPeripheral?.setNotifyValue(false, for: characteristic)
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            print("central.state is .unknown")
        case .resetting:
            print("central.state is .resetting")
        case .unsupported:
            print("central.state is .unsupported")
        case .unauthorized:
            print("central.state is .unauthorized")
        case .poweredOff:
            print("central.state is .poweredOff")
        case .poweredOn:
            print("central.state is .poweredOn")
        default:
            print("This shouldn't happen")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // I failed to scan for the CBUUD 42230100-2342-2342-2342-234223422342 :-/
        guard let name = peripheral.name, name.hasPrefix("card10") else { return }

        let advName = String("\(advertisementData[CBAdvertisementDataLocalNameKey] ?? "")")
        print("did discover: \(name) \(peripheral.identifier)), CBAdvertisementDataLocalNameKey: \(advName)")

        // sort & unique foundPeripherals
        foundPeripheral.append(FoundPeripheral.init(peripheral: peripheral, advertisementName: advName, rssi: RSSI.intValue))
        foundPeripheral = Array(Set(foundPeripheral)).sorted { $0.peripheral.identifier.uuidString > $1.peripheral.identifier.uuidString }
        subscribers.forEach { $0.value?.didFindNewPeripherals(self.foundPeripheral) }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("did connect: \(peripheral.name ?? "<nil>") \(peripheral.identifier))")

        self.connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([card10ServiceUUID, card10RxTxServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("did disconnect: \(peripheral.name ?? "<nil>") \(peripheral.identifier))")
        self.connectedPeripheral = nil
        subscribers.forEach { $0.value?.didDisconnectFromPeripheral() }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services! {
            print("found service: \(service.uuid)")
            if service.uuid.isEqual(card10ServiceUUID) {
                peripheral.discoverCharacteristics([card10TimeCharacteristic,
                                                    card10VibrateCharacteristic,
                                                    card10RocketsCharacteristic,
                                                    card10BackgroundLedBottomLeftCharacteristic,
                                                    card10BackgroundLedBottomRightCharacteristic,
                                                    card10BackgroundLedTopRightCharacteristic,
                                                    card10BackgroundLedTopLeftCharacteristic,
                                                    card10LedsDimBottomCharacteristic,
                                                    card10LedsDimTopCharacteristic,
                                                    card10LedsAboveCharacteristic,
                                                    card10SingleRgbLedCharacteristic,
                                                    card10LightSensorCharacteristic], for: service)
            }
            if service.uuid.isEqual(card10RxTxServiceUUID) {
                peripheral.discoverCharacteristics([card10TXWriteCharacteristicUUID,
                                                    card10RXReadCharacteristicUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("did didDiscoverCharacteristicsFor: \(service.uuid) \(service.characteristics!))")

        // make sure that all characteristic are discovered, if yes announce to subscribers
        let card10ServiceIsComplete = connectedPeripheral?
            .services?
            .filter { $0.uuid.uuidString == card10ServiceUUID.uuidString }
            .first?
            .characteristics?
            .allSatisfy { [card10TimeCharacteristic,
                           card10VibrateCharacteristic,
                           card10RocketsCharacteristic,
                           card10BackgroundLedBottomLeftCharacteristic,
                           card10BackgroundLedBottomRightCharacteristic,
                           card10BackgroundLedTopRightCharacteristic,
                           card10BackgroundLedTopLeftCharacteristic,
                           card10LedsDimBottomCharacteristic,
                           card10LedsDimTopCharacteristic,
                           card10LedsAboveCharacteristic,
                           card10SingleRgbLedCharacteristic,
                           card10LightSensorCharacteristic].contains($0.uuid) } ?? false
        let card10RxTxServiceIsComplete = connectedPeripheral?
            .services?
            .filter { $0.uuid.uuidString == card10RxTxServiceUUID.uuidString }
            .first?
            .characteristics?
            .allSatisfy { [card10TXWriteCharacteristicUUID,
                           card10RXReadCharacteristicUUID].contains($0.uuid) } ?? false

        if card10ServiceIsComplete && card10RxTxServiceIsComplete {
            subscribers.forEach { $0.value?.didConnectToPeripheal(FoundPeripheral(peripheral: peripheral, advertisementName: nil, rssi: nil)) }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        if characteristic.uuid.isEqual(card10LightSensorCharacteristic) {
            guard let data = characteristic.value else { return }
            var value: UInt16 = 0
            _ = withUnsafeMutableBytes(of: &value, { data.copyBytes(to: $0)})
            subscribers.forEach { $0.value?.didGetNewLightSensorData(value) }
        }

        if characteristic.uuid.isEqual(card10RXReadCharacteristicUUID) {
            guard let data = characteristic.value else { return }
            self.dataTransferManager?.receivedNewPackage(data)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        // only log errors
        error.map {
            print("periperal: \(peripheral.identifier) didWriteValueFor: \(characteristic.uuid) error: \($0.localizedDescription)")
        }
    }

    // MARK: - DataTransferManagerDelegate

    func wantsToSendPackage(_ package: Data) {
        guard let peripheral = self.connectedPeripheral else { return } //TODO: Tell the delegate it failed?

        guard let characteristic = self.findCharacteristic(on: peripheral, forServiceUUID: card10RxTxServiceUUID, forCharacteristicUUID: card10TXWriteCharacteristicUUID) else { return }

        self.connectedPeripheral?.writeValue(package, for: characteristic, type: .withoutResponse)
    }

    func didUpdateState(_ state: TransferState) {
        switch state {
        case .IDLE:
            print("Transfer Manager is idling")
        case .START_SENT:
            print("Transfer Manager started sending")
        case .READY_TO_SEND:
            print("Transfer Manager got response and will send")
        case .CHUNK_SENT:
            print("Transfer Manager sent chunk")
        case .FINISH_SENT:
            print("Transfer Manager sent file, inform the user")
            self.unsubscrubeFromRxChannel()
            subscribers.forEach { $0.value?.didFinishToSendFile() }
        }

    }

    func didFailToSendFile() {
        subscribers.forEach { $0.value?.didFailToSendFile() }
    }

    func didUpdateProgress(_ progress: Double) {
        subscribers.forEach { $0.value?.didUpdateProgressOnFile(progress) }
    }

    // MARK: - Helper methods

    func findCharacteristic(on peripheral: CBPeripheral, forServiceUUID: CBUUID, forCharacteristicUUID: CBUUID) -> CBCharacteristic? {
        return peripheral.services?
            .filter { $0.uuid.isEqual(forServiceUUID) }
            .first?
            .characteristics?
            .filter { $0.uuid.isEqual(forCharacteristicUUID) }
            .first
    }

}
