//
//  HatcheryRootTableViewController.swift
//  card10badge
//
//  Created by Brechler, Philip on 18.08.19.
//  Copyright © 2019 Brechler, Philip. All rights reserved.
//

import UIKit

extension HatcheryRootTableViewController: UISearchResultsUpdating {
    // MARK: - UISearchResultsUpdating Delegate
    func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchController.searchBar.text!)
    }
}

class HatcheryRootTableViewController: UITableViewController, HatcheryClientDelegate {

    var client: HatcheryClient?
    let searchController = UISearchController(searchResultsController: nil)
    var filteredEggs = [HatcheryEgg]()

    override func viewDidLoad() {
        super.viewDidLoad()

        client = HatcheryClient.init(delegate: self)
        self.clearsSelectionOnViewWillAppear = true
        self.tabBarItem = UITabBarItem.init(title: "Hatchery", image: UIImage(named: "hatchery_icon"), selectedImage: nil)

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Eggs"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    override func viewWillAppear(_ animated: Bool) {
        self.tabBarController?.tabBar.tintColor = UIColor.init(named: "chaos_bright_color")
        self.navigationController?.navigationBar.tintColor = UIColor.init(named: "chaos_bright_color")
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        if client?.loadedEggs.count == 0 {
            client?.updateListOfHatcheryEggs()
        }
        super.viewDidAppear(animated)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        if isFiltering() {
            return 1
        }
        return (client?.loadedEggs.count)!
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isFiltering() {
            return filteredEggs.count
        }
        let categoryArray = client?.loadedEggs[section]
        return (categoryArray?.count)!
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56.0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "HatcheryRootTableViewCell", for: indexPath) as? HatcheryRootTableViewCell else {
            preconditionFailure("wrong cell class!")
        }

        let eggForCell: HatcheryEgg
        if isFiltering() {
            eggForCell = self.filteredEggs[indexPath.row]
        } else {
            eggForCell = (self.client?.loadedEggs[indexPath.section][indexPath.row])!
        }

        cell.eggNameLabel?.text = eggForCell.name
        cell.metaDataLabel?.text = String.init(format: "Revision %@ • %d Downloads • %@ • %.0f Byte", (eggForCell.revision)!, (eggForCell.downloadCounter)!, (eggForCell.category)!, (eggForCell.sizeOfContent!))

        return cell
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if isFiltering() {
            return nil
        }

        let firstEggForCategory = client?.loadedEggs[section][0]

        let sectionHeader: UIVisualEffectView = UIVisualEffectView.init(frame: CGRect(x: 0, y: 0, width: self.tableView.frame.width, height: 44.0))
        sectionHeader.effect = UIBlurEffect.init(style: .dark)

        let sectionLabel: UILabel = UILabel.init(frame: CGRect(x: self.tableView.separatorInset.left, y: 0, width: self.tableView.frame.width-self.tableView.separatorInset.left, height: 44))
        sectionLabel.text = firstEggForCategory?.category
        sectionLabel.textColor = .lightGray
        sectionLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        sectionHeader.contentView.addSubview(sectionLabel)
        return sectionHeader
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if isFiltering() {
            return 0
        }
        return 44
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let indexPath = self.tableView.indexPathForSelectedRow!

        let eggForCell: HatcheryEgg
        if isFiltering() {
            eggForCell = self.filteredEggs[indexPath.row]
        } else {
            eggForCell = (self.client?.loadedEggs[indexPath.section][indexPath.row])!
        }
        let eggDetailViewController = segue.destination as? HatcheryDetailViewController
        eggDetailViewController?.eggToShow = eggForCell
    }

    // MARK: - HatcheryClientDelegate

    func didRefreshListOfEggs() {
        self.refreshControl?.endRefreshing()
        if self.tableView.numberOfSections > 0 {
            let rangeToReload = IndexSet.init(integersIn: 0..<(client?.loadedEggs.count)!)
            self.tableView.reloadSections(rangeToReload, with: .automatic)
        } else {
            self.tableView.reloadData()
        }
    }

    func didFailToRefreshListOfEggs(_ error: Error?) {
        self.refreshControl?.endRefreshing()
        var errorToShow: String = "Failed to download eggs"
        if error != nil {
            errorToShow.append(contentsOf: "\n")
            errorToShow.append(contentsOf: error!.localizedDescription)
        }
        let listError = UIAlertController.init(title: "Error", message: errorToShow, preferredStyle: .alert)
        listError.view.tintColor = UIColor.init(named: "chaos_bright_color")
        listError.addAction(UIAlertAction.init(title: "OK", style: .default, handler: nil))
        self.present(listError, animated: true, completion: nil)
    }

    // MARK: - Refresh Control

    @IBAction func refreshEggs(sender: UIRefreshControl) {
        self.client?.updateListOfHatcheryEggs()
    }

    // MARK: - Private instance methods

    func searchBarIsEmpty() -> Bool {
        // Returns true if the text is empty or nil
        return searchController.searchBar.text?.isEmpty ?? true
    }

    func isFiltering() -> Bool {
        return searchController.isActive && !searchBarIsEmpty()
    }

    func filterContentForSearchText(_ searchText: String) {
        let eggsToSearch = self.client?.loadedEggs.flatMap { $0 }
        filteredEggs = (eggsToSearch!.filter({( egg: HatcheryEgg) -> Bool in
            return (egg.name?.lowercased().contains(searchText.lowercased()))! || (egg.eggDescription?.lowercased().contains(searchText.lowercased()))!
        }))

        tableView.reloadData()
    }

}
