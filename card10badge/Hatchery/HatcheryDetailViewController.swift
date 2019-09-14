//
//  HatcheryDetailViewController.swift
//  card10badge
//
//  Created by Brechler, Philip on 18.08.19.
//  Copyright © 2019 Brechler, Philip. All rights reserved.
//

import UIKit

private struct DataToTransfer: Hashable {
    let fileName: String
    let data: Data
}

class HatcheryDetailViewController: UIViewController, HatcheryClientDelegate, BluetoothManagerDelegate {

    public var eggToShow: HatcheryEgg?
    private var client: HatcheryClient?
    private var filesToTransfer: Array<DataToTransfer> = []
    private var uploadAlert: UIAlertController?
    private var progressBar: UIProgressView?

    @IBOutlet weak var descriptionTextView: UITextView?
    @IBOutlet weak var metaDataLabel: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()
        client = HatcheryClient(delegate: self)
        let installToolbarItem = UIBarButtonItem.init(barButtonSystemItem: .add, target: self, action: #selector(installBarButtonAction(sender:)))
        self.navigationItem.rightBarButtonItem = installToolbarItem
        // Do any additional setup after loading the view.
    }

    override func viewWillAppear(_ animated: Bool) {
        self.title = eggToShow?.name
        self.descriptionTextView?.text = eggToShow?.eggDescription
        self.metaDataLabel?.text =  String.init(format: "Revision %@ • %d Downloads • %@ • %.0f Bytes", (eggToShow?.revision)!, (eggToShow?.downloadCounter)!, (eggToShow?.category)!, (eggToShow?.sizeOfContent)!)
        super.viewWillAppear(animated)
    }

    @objc func installBarButtonAction(sender: UIBarButtonItem?) {
        let installAlert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        installAlert.view.tintColor = UIColor.init(named: "chaos_bright_color")

        let installAction = UIAlertAction.init(title: "Install on card10", style: .default, handler: { (_) in
            self.client?.downloadEgg(egg: self.eggToShow!)
        })
        installAlert.addAction(installAction)
        installAlert.addAction(UIAlertAction.init(title: "Cancel", style: .cancel, handler: nil))
        self.present(installAlert, animated: true)
    }

    // MARK: - HatcheryClientDelegate

    func didDownloadEggToPath(_ path: URL) {
        self.filesToTransfer.removeAll()
        let folderName = FileManager.default.displayName(atPath: path.path)
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                let fileContent = FileManager.default.contents(atPath: fileURL.path)
                let fileName = FileManager.default.displayName(atPath: fileURL.path)
                guard fileContent != nil else { return }
                self.filesToTransfer.append(DataToTransfer(fileName: String.init(format: "apps/%@/%@", folderName, fileName), data: fileContent!))
            }
            BluetoothManager.sharedInstance().subscribe(self)

            uploadAlert = UIAlertController(title: "Uploading", message: "Please wait", preferredStyle: .alert)
            progressBar = UIProgressView(progressViewStyle: .default)
            progressBar?.setProgress(0.0, animated: true)
            progressBar?.frame = CGRect(x: 10, y: 70, width: 250, height: 0)
            uploadAlert?.view.addSubview(progressBar!)

            self.present(uploadAlert!, animated: true, completion: nil)

            self.transferNextFile()

        } catch {
            print("Error while enumerating files \(path.path): \(error.localizedDescription)")
        }
    }

    func didFailToDownloadEgg() {
        let failedAlert = UIAlertController(title: "Error", message: "Failed to download egg", preferredStyle: .alert)

        failedAlert.addAction(UIAlertAction.init(title: "OK", style: .default, handler: nil))
        self.present(failedAlert, animated: true)
    }

    private func transferNextFile() {
        if filesToTransfer.count > 0 {
            let fileToTransfer = self.filesToTransfer[0]
            BluetoothManager.sharedInstance().sendFileData(data: fileToTransfer.data, fileName: fileToTransfer.fileName)
        } else {
            self.uploadAlert?.dismiss(animated: true, completion: {
                let finishedController = UIAlertController .init(title: "Uploaded", message: "Uploaded all files", preferredStyle: .alert)
                finishedController.addAction(UIAlertAction.init(title: "OK", style: .default, handler: nil))
                self.present(finishedController, animated: true, completion: nil)
            })
        }
    }

    // MARK: - BluetoothManagerDelegate

    func didFinishToSendFile() {
        guard self.filesToTransfer.count > 0 else {
            return
        }
        self.filesToTransfer.removeFirst()
        self.transferNextFile()
    }

    func didFailToSendFile() {
        self.filesToTransfer.removeAll()
        BluetoothManager.sharedInstance().unsubscribe(self)
        self.uploadAlert?.dismiss(animated: true, completion: {
            let finishedController = UIAlertController .init(title: "Error", message: "Failed to upload files. Please check if you are connected and if you are using the forked firmware", preferredStyle: .alert)
            finishedController.addAction(UIAlertAction.init(title: "OK", style: .default, handler: nil))
            self.present(finishedController, animated: true, completion: nil)
        })
    }

    func didUpdateProgressOnFile(_ progress: Double) {
        self.progressBar?.setProgress(Float(progress), animated: true)
    }
}
