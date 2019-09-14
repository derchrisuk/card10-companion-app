//
//  HatcheryClient.swift
//  card10badge
//
//  Created by Brechler, Philip on 18.08.19.
//  Copyright © 2019 Brechler, Philip. All rights reserved.
//

import UIKit
import SWCompression

protocol HatcheryClientDelegate: class {
    func didRefreshListOfEggs()
    func didFailToRefreshListOfEggs(_ error: Error?)
    func didDownloadEggToPath(_ path: URL)
    func didFailToDownloadEgg()
}

// Empty implementations to prevent errors
extension HatcheryClientDelegate {
    func didRefreshListOfEggs() {}
    func didFailToRefreshListOfEggs(_ error: Error?) {}
    func didDownloadEggToPath(_ path: URL) {}
    func didFailToDownloadEgg() {}
}

class HatcheryClient: NSObject, URLSessionDelegate {

    let hatcheryBaseURL: URL = URL(string: "https://badge.team/")!
    private(set) public var loadedEggs: [[HatcheryEgg]] = []

    weak var delegate: HatcheryClientDelegate?

    init(delegate: HatcheryClientDelegate) {
        self.delegate = delegate

    }

    public func updateListOfHatcheryEggs() {

        let session = URLSession.shared
        let hatcheryListURL = URL(string: "basket/card10/list/json", relativeTo: hatcheryBaseURL)!

        let task = session.dataTask(with: hatcheryListURL, completionHandler: { data, response, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    self.delegate?.didFailToRefreshListOfEggs(error)
                }
                return }
            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode) else {
                    DispatchQueue.main.async {
                        self.delegate?.didFailToRefreshListOfEggs(nil)
                    }
                    return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data!, options: [])
                if let jsonArray = json as? [Any] {
                    self.loadedEggs.removeAll()
                    var loadedEggsUncategorized: [HatcheryEgg] = []
                    for case let dictionary as [String: Any] in jsonArray {
                        loadedEggsUncategorized.append(HatcheryEgg.init(dictionary: dictionary))
                    }

                    let categories = (loadedEggsUncategorized).compactMap { $0.category }
                    var uniqueCategories = Array(Set(categories))
                    uniqueCategories = uniqueCategories.sorted { $0.lowercased() < $1.lowercased() }

                    for category in uniqueCategories {
                        var eggsForCategory: [HatcheryEgg] = []
                        for egg in loadedEggsUncategorized {
                            if egg.category == category {
                                eggsForCategory.append(egg)
                            }
                            eggsForCategory = eggsForCategory.sorted { $0.name!.lowercased() < $1.name!.lowercased() }
                        }
                        self.loadedEggs.append(eggsForCategory)
                    }
                    DispatchQueue.main.async {
                        self.delegate?.didRefreshListOfEggs()
                    }
                }

            } catch {
                print("JSON error: \(error.localizedDescription)")
            }
        })

        task.resume()
    }

    public func downloadEgg(egg: HatcheryEgg) {
        self.getReleaseUrlFor(slug: egg.slug!, revision: egg.revision!)
    }

    private func getReleaseUrlFor(slug: String, revision: String) {
        let session = URLSession.shared
        let hatcheryListURL = URL(string: String.init(format: "eggs/get/%@/json", slug), relativeTo: hatcheryBaseURL)!

        let task = session.dataTask(with: hatcheryListURL, completionHandler: { data, response, error in
            guard error == nil else { return }
            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode) else {
                    //self.handleServerError(response)
                    return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data!, options: [])
                if let eggDict = json as? [String: Any] {
                    if let releases = eggDict["releases"] as? [String: Any] {
                        if let latestRelease = releases[revision] as? [[String: String]] {
                            let releaseURL = latestRelease[0]["url"]
                            self.downloadRelease(fromURL: URL(string: releaseURL!)!)
                        }
                    }
                }

            } catch {
                print("JSON error: \(error.localizedDescription)")
            }
        })

        task.resume()
    }

    private func downloadRelease(fromURL: URL) {
        let session = URLSession.shared

        let task = session.downloadTask(with: fromURL, completionHandler: { tempLocalUrl, response, error in
            guard error == nil else { return }
            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode) else {
                    //self.handleServerError(response)
                    return
            }

            let documentsUrl =  FileManager.default.temporaryDirectory
            let destinationUrl = documentsUrl.appendingPathComponent(fromURL.lastPathComponent)

            if FileManager.default.fileExists(atPath: destinationUrl.path) {
                do {
                    try FileManager.default.removeItem(at: destinationUrl)
                } catch {

                }
            }

            do {
                try FileManager.default.copyItem(at: tempLocalUrl!, to: destinationUrl)
                self.unpackEgg(destinationUrl)
            } catch {
                // Handle fail
            }

        })
        task.resume()
    }

    private func unpackEgg(_ localFile: URL) {
        let data = try? Data.init(contentsOf: localFile)
        let unpackUrl = FileManager.default.temporaryDirectory.appendingPathComponent("downloaded_eggs")
        do {
            let decompressedTarData = try GzipArchive.unarchive(archive: data!)
            let unpackedTar = try TarContainer.open(container: decompressedTarData)

            var createdFileCount: Int = 0
            var folderNameForEgg: String?

            for tarEntry in unpackedTar {
                let fileName = unpackUrl.appendingPathComponent(tarEntry.info.name)
                let data = tarEntry.data
                if folderNameForEgg == nil {
                    folderNameForEgg = fileName.deletingLastPathComponent().path // Kind of betting on that there are no subfolders
                }
                try FileManager.default.createDirectory(at: fileName.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                if FileManager.default.createFile(atPath: fileName.path, contents: data, attributes: nil) {
                    createdFileCount += 1 //Increment so we know if we wrote all the files
                } else {
                    print("Failed to write file to path ", fileName)
                }
            }

            if createdFileCount == unpackedTar.count {
                //Success, we downloaded and stored all the files
                delegate?.didDownloadEggToPath(URL(string: folderNameForEgg!) ?? unpackUrl)
            } else {
                delegate?.didFailToDownloadEgg()
            }

        } catch let error {
            print(error)
            delegate?.didFailToDownloadEgg()
        }

    }
}
