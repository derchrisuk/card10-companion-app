//
//  HatcheryEgg.swift
//  card10badge
//
//  Created by Brechler, Philip on 18.08.19.
//  Copyright © 2019 Brechler, Philip. All rights reserved.
//

import UIKit

class HatcheryEgg: NSObject {

    private(set) public var name: String?
    private(set) public var slug: String?
    private(set) public var eggDescription: String?
    private(set) public var downloadCounter: Int?
    private(set) public var status: String?
    private(set) public var revision: String?
    private(set) public var sizeOfZip: Double?
    private(set) public var sizeOfContent: Double?
    private(set) public var category: String?

    let dictionary: [String: Any]

    init(dictionary: [String: Any]) {
        self.dictionary = dictionary

        self.name = dictionary["name"] as? String
        self.slug = dictionary["slug"] as? String
        self.eggDescription = dictionary["description"] as? String
        self.downloadCounter = dictionary["download_counter"] as? Int
        self.status = dictionary["status"] as? String
        self.revision = dictionary["revision"] as? String
        self.sizeOfZip = dictionary["size_of_zip"] as? Double
        self.sizeOfContent = dictionary["size_of_content"] as? Double
        self.category = dictionary["category"] as? String
        self.category = self.category?.capitalized

    }
}
