//
//  Card10TabBarController.swift
//  card10badge
//
//  Created by Thomas Mellenthin on 20.08.19.
//  Copyright © 2019 Brechler, Philip. All rights reserved.
//

import UIKit
import CoreBluetooth

public class Card10TabBarController: UITabBarController, UITabBarControllerDelegate, BluetoothManagerDelegate {

    var allViewControllers: [UIViewController]? = []

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
        allViewControllers = self.viewControllers
        // hide connected VC initially
        self.viewControllers = allViewControllers?.filter { false == ($0 is ConnectedViewController) }
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        BluetoothManager.sharedInstance().subscribe(self)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        BluetoothManager.sharedInstance().unsubscribe(self)
    }
}

// MARK: BluetoothManagerDelegate

extension Card10TabBarController {

    public func didConnectToPeripheal(_ peripheral: FoundPeripheral?) {
        // show and select connected VC
        self.viewControllers = allViewControllers
        selectedViewController = allViewControllers?.filter { $0 is ConnectedViewController }.first
    }

    public func didDisconnectFromPeripheral() {
        // hide connected VCm
        self.viewControllers = allViewControllers?.filter { false == ($0 is ConnectedViewController) }
        selectedViewController = viewControllers?.last
    }
}
