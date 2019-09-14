//
//  AppDelegate.swift
//  card10badge
//
//  Created by Brechler, Philip on 15.08.19.
//  Copyright © 2019 Brechler, Philip. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        window?.tintColor = UIColor(named: "tintColor")
        UITableView.appearance().backgroundColor = UIColor(named: "tableViewBackground")
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]

        return true
    }
}
