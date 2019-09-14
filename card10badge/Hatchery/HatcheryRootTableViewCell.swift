//
//  HatcheryRootTableViewCell.swift
//  card10badge
//
//  Created by Brechler, Philip on 21.08.19.
//  Copyright © 2019 Brechler, Philip. All rights reserved.
//

import UIKit

class HatcheryRootTableViewCell: UITableViewCell {

    @IBOutlet weak var eggNameLabel: UILabel?
    @IBOutlet weak var metaDataLabel: UILabel?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
