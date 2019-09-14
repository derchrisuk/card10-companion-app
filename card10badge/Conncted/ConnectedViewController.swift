//
//  ConnectedViewController.swift
//  card10badge
//
//  Created by Brechler, Philip on 15.08.19.
//  Copyright © 2019 Brechler, Philip. All rights reserved.
//

import UIKit
import CoreBluetooth

class ConnectedViewController: UIViewController, UIDocumentPickerDelegate, BluetoothManagerDelegate {

    @IBOutlet weak var peripheralName: UILabel?

    @IBOutlet weak var lightLabel: UILabel?

    @IBOutlet weak var rocket1Label: UILabel?
    @IBOutlet weak var rocket1Stepper: UIStepper?

    @IBOutlet weak var rocket2Label: UILabel?
    @IBOutlet weak var rocket2Stepper: UIStepper?

    @IBOutlet weak var rocket3Label: UILabel?
    @IBOutlet weak var rocket3Stepper: UIStepper?

    @IBOutlet weak var uploadFileButton: UIButton!
    @IBOutlet weak var vibrateButton: UIButton!
    @IBOutlet weak var vibrateSlider: UISlider!
    @IBOutlet weak var vibrateDurationLabel: UILabel!

    var progressBar: UIProgressView?
    var uploadAlert: UIAlertController?

    var documentBrowser: UIDocumentPickerViewController?

    public var peripheral: CBPeripheral!

    /// card10 does not support subscribing to characteristics atm, so we have to poll 🤷‍♂️
    let pollingQueue = DispatchQueue(label: "de.ccc.events.badge.card10.iOS.pollingQueue", attributes: .concurrent)
    var pollingTimer: DispatchSourceTimer?

    deinit {
        // better safe than sorry
        stopPolling()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tabBarItem = UITabBarItem.init(title: "Control", image: UIImage(named: "fd_communication"), selectedImage: nil)

        [uploadFileButton, vibrateButton].compactMap { $0 }.forEach {
            $0.layer.cornerRadius = 5
            $0.layer.borderColor = UIColor.init(named: "communication_color")?.cgColor
            $0.layer.borderWidth = 2
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        BluetoothManager.sharedInstance().subscribe(self)
        startPolling()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        stopPolling()
        BluetoothManager.sharedInstance().unsubscribe(self)
    }
}

// MARK: - IBActions

extension ConnectedViewController {

    @IBAction func uploadFileButtonAction(sender: UIButton) {
        if self.documentBrowser == nil {
            self.documentBrowser = UIDocumentPickerViewController(documentTypes: ["public.data"], in: .import)
            self.documentBrowser?.allowsMultipleSelection = false
            self.documentBrowser?.delegate = self
        }
        self.present(self.documentBrowser!, animated: true, completion: nil)
    }

    @IBAction func setTimeButtonAction(sender: UIButton) {
        BluetoothManager.sharedInstance().setTimeOnPeripheral()
        // FIXME: do we need a button? It's done on paring
    }

    @IBAction func rocketStepperChanged(sender: UIStepper) {

        let rocket1Value = UInt8(rocket1Stepper?.value ?? 0)
        let rocket2Value = UInt8(rocket2Stepper?.value ?? 0)
        let rocket3Value = UInt8(rocket3Stepper?.value ?? 0)

        rocket1Label?.text = String.init(format: "Blue Rocket: %d", rocket1Value)
        rocket2Label?.text = String.init(format: "Yellow Rocket: %d", rocket2Value)
        rocket3Label?.text = String.init(format: "Green Rocket: %d", rocket3Value)
        BluetoothManager.sharedInstance().illuminateRocketsWithBrightness(rocketOne: rocket1Value,
                                                                          rocketTwo: rocket2Value,
                                                                          rocketThree: rocket3Value)
    }

    @IBAction func lightSliderChanged(sender: UISlider) {
        let vibrateValue = UInt(sender.value)
        vibrateDurationLabel.text = String.init(format: "%d ms", vibrateValue)
    }

    @IBAction func vibrateButtonAction(sender: UIButton) {
        BluetoothManager.sharedInstance().setVibrate(milliseconds: UInt16(vibrateSlider.value))
    }

    @IBAction func disconnectButtonAction(sender: UIButton) {
        pollingTimer?.cancel()
        let rgbOff = RGBLED.init(red: 0, green: 0, blue: 0)
        BluetoothManager.sharedInstance().setBackgroundLEDs(topLeft: rgbOff, topRight: rgbOff, bottomRight: rgbOff, bottomLeft: rgbOff)
        BluetoothManager.sharedInstance().setLEDsAbove(AboveLEDs.off())
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            BluetoothManager.sharedInstance().disconnectFromCard10Badge()
        }
    }
}

// MARK: - UIDocumentPickerDelegate

extension ConnectedViewController {

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if controller.documentPickerMode == .import {
            for url in urls {
                do {
                    let data = try Data(contentsOf: url as URL)
                    let urlNameFromFile = url.lastPathComponent
                    BluetoothManager.sharedInstance().sendFileData(data: data, fileName: urlNameFromFile)

                    uploadAlert = UIAlertController(title: "Uploading", message: "Please wait", preferredStyle: .alert)
                    progressBar = UIProgressView(progressViewStyle: .default)
                    progressBar?.setProgress(0.0, animated: true)
                    progressBar?.frame = CGRect(x: 10, y: 70, width: 250, height: 0)
                    uploadAlert?.view.addSubview(progressBar!)

                    self.present(uploadAlert!, animated: true, completion: nil)

                } catch {
                    print("Unable to load data: \(error)")
                }
            }
        }
    }
}

// MARK: - poll values

extension ConnectedViewController {

    func startPolling() {
        print("startPolling values")

        if nil != pollingTimer { pollingTimer?.cancel() }
        pollingTimer = DispatchSource.makeTimerSource(queue: pollingQueue)
        pollingTimer?.schedule(deadline: .now(), repeating: .milliseconds(666), leeway: .milliseconds(100))
        pollingTimer?.setEventHandler { [weak self] in
            self?.pollValues()

            self?.setRandomBackgroundLedColors()
        }
        pollingTimer?.resume()
    }

    func stopPolling() {
        print("stopPolling")
        pollingTimer?.setEventHandler {}
        pollingTimer?.cancel()
    }

    func pollValues() {
        // sensor values are received via didGetNewLightSensorData(:)
        BluetoothManager.sharedInstance().getLightSensorData()
    }

    func setRandomBackgroundLedColors() {
        BluetoothManager.sharedInstance().setBackgroundLEDs(topLeft: RGBLED.randomRGB(),
                                                            topRight: RGBLED.randomRGB(),
                                                            bottomRight: RGBLED.randomRGB(),
                                                            bottomLeft: RGBLED.randomRGB())

        BluetoothManager.sharedInstance().setLEDsAbove(AboveLEDs.randomRGB())
    }

}

// MARK: - BluetoothManagerDelegate

extension ConnectedViewController {

    func didDisconnectFromPeripheral() {
        self.navigationController?.popViewController(animated: true)
    }

    func didGetNewLightSensorData(_ data: UInt16) {
        lightLabel?.text = String.init(format: "Light Sensor: %d", data)
    }

    func didFinishToSendFile() {
        uploadAlert?.dismiss(animated: true, completion: {
            self.uploadAlert = nil
            self.progressBar = nil
        })
    }

    func didFailToSendFile() {
        uploadAlert?.dismiss(animated: true, completion: {
            self.progressBar = nil
            self.uploadAlert = nil

            let failedAlertController = UIAlertController(title: "Error", message: "Failed to upload file", preferredStyle: .alert)
            failedAlertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(failedAlertController, animated: true, completion: nil)
        })
    }

    func didUpdateProgressOnFile(_ progress: Double) {
        progressBar?.setProgress(Float(progress), animated: true)
    }

}
