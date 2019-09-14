//
//  ScannerTableViewController.swift
//  card10badge
//
//  Created by Brechler, Philip on 15.08.19.
//  Copyright © 2019 Brechler, Philip. All rights reserved.
//

import UIKit
import CoreBluetooth

enum ScannerTableSection: Int, RawRepresentable, CaseIterable {
    case unpaired = 0
    case paired = 1

    init(rawValue: Int) {
        switch rawValue {
        case 0: self = .unpaired
        case 1: self = .paired
        default: preconditionFailure("Invalid section.")
        }
    }

    public var title: String {
        switch self {
        case .paired: return "Paired devices"
        case .unpaired: return "Unpaired devices"
        }
    }
}

class ScannerTableViewController: UITableViewController {

    private let card10Manager = BluetoothManager.sharedInstance()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.clearsSelectionOnViewWillAppear = false

        updateScanButtonState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tabBarController?.tabBar.tintColor = UIColor.init(named: "camp_color")
        self.navigationController?.navigationBar.tintColor = UIColor.init(named: "camp_color")

        BluetoothManager.sharedInstance().subscribe(self)
        BluetoothManager.sharedInstance().startScan()
        updateScanButtonState()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        BluetoothManager.sharedInstance().stopScan()
        BluetoothManager.sharedInstance().unsubscribe(self)
    }
}

// MARK: - Table view data source

extension ScannerTableViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return ScannerTableSection.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return BluetoothManager.sharedInstance().foundPeripheral.count
        case 1: return 0 // FIXME BluetoothManager.sharedInstance().connectedPeripheral != nil ? 1 : 0
        default:
            assertionFailure("Invalid section")
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch ScannerTableSection(rawValue: indexPath.section) {
        case .unpaired:
            let cell = tableView.dequeueReusableCell(withIdentifier: "scannerTableViewCell", for: indexPath)
            let peripheralForCell = BluetoothManager.sharedInstance().foundPeripheral[indexPath.row]
            cell.textLabel?.text = "\(peripheralForCell.advertisementName ?? "<nil>")"
            cell.detailTextLabel?.text = "\(peripheralForCell.peripheral.identifier.uuidString) - RSSI: \(peripheralForCell.rssi  ?? 0)"
            return cell
        case .paired:
            let cell = tableView.dequeueReusableCell(withIdentifier: "scannerTableViewCell", for: indexPath)
            let peripheralForCell = BluetoothManager.sharedInstance().connectedPeripheral
            cell.textLabel?.text = "\(peripheralForCell?.name ?? "<nil>") (paired)"
            cell.detailTextLabel?.text = peripheralForCell?.identifier.uuidString
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return ScannerTableSection(rawValue: section).title
    }
}

// MARK: - Table view delegate

extension ScannerTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // tapping a row -> connecting, in didConnectoToPeripheral we try to force pairing by setting the time
        let card10 = BluetoothManager.sharedInstance().foundPeripheral[indexPath.row]
        BluetoothManager.sharedInstance().connectToCard10Badge(peripheral: card10.peripheral)
    }
}

// MARK: - Bluetooth Manager Delegate

extension ScannerTableViewController: BluetoothManagerDelegate {

    func didFindNewPeripherals(_ peripherals: [FoundPeripheral]?) {
        self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
    }

    func didConnectToPeripheal(_ peripheral: FoundPeripheral?) {
        // FIXME: UI that indicated that we're connected
        print("ScannerTableViewController: connected to card10 \(peripheral?.peripheral.identifier.uuidString ?? "<nil>") ")
    }

    func didDisconnectFromPeripheral() {
        // FIXME: UI that indicated that we're connected
        print("ScannerTableViewController: disconnected")
    }

    // MARK: - Toolbar Actions

    @objc func scanBarButtonAction(sender: UIBarButtonItem) {
        let ble: BluetoothManager = BluetoothManager.sharedInstance()

        switch ble.isScanning {
        case true:
            ble.stopScan()
        case false:
            ble.startScan()
        }

        updateScanButtonState()
    }

    private func updateScanButtonState() {
        let ble: BluetoothManager = BluetoothManager.sharedInstance()
        let button = UIBarButtonItem(barButtonSystemItem: ble.isScanning ? .stop : .refresh, target: self, action: #selector(scanBarButtonAction(sender:)))
        self.navigationItem.setRightBarButton(button, animated: true)
    }
}
