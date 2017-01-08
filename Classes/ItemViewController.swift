//
//  ItemViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

import Foundation
import UIKit

class ItemViewController: DraggableTableViewController {
    
    fileprivate let folderCellIdentifier = "Folder Cell"
    fileprivate let artistCellIdentifier = "Artist Cell"
    fileprivate let albumCellIdentifier = "Album Cell"
    fileprivate let songCellIdentifier = "Song Cell"
    fileprivate let playlistCellIdentifier = "Playlist Cell"
    
    fileprivate let foldersSectionIndex   = 0
    fileprivate let artistsSectionIndex   = 1
    fileprivate let albumsSectionIndex    = 2
    fileprivate let songsSectionIndex     = 3
    fileprivate let playlistsSectionIndex = 4
    
    fileprivate let viewModel: ItemViewModel
    fileprivate var reloading: Bool = false
    fileprivate var sectionIndexes: [SectionIndex]?
    
    init(viewModel: ItemViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.edgesForExtendedLayout = UIRectEdge()
        self.automaticallyAdjustsScrollViewInsets = false
        
        viewModel.delegate = self
        _ = viewModel.loadModelsFromDatabase()
        viewModel.loadModelsFromWeb(nil)
        
        self.tableView.tableFooterView = UIView(frame:CGRect(x: 0, y: 0, width: 320, height: 64))
    }
    
    override func customizeTableView(_ tableView: UITableView) {
        tableView.register(ItemTableViewCell.self, forCellReuseIdentifier: folderCellIdentifier)
        tableView.register(ItemTableViewCell.self, forCellReuseIdentifier: artistCellIdentifier)
        tableView.register(ItemTableViewCell.self, forCellReuseIdentifier: albumCellIdentifier)
        tableView.register(ItemTableViewCell.self, forCellReuseIdentifier: songCellIdentifier)
        tableView.register(ItemTableViewCell.self, forCellReuseIdentifier: playlistCellIdentifier)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.tableView.reloadData()
        
        registerForNotifications()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        unregisterForNotifications()
    }
    
    deinit {
        viewModel.cancelLoad()
        
        unregisterForNotifications()
    }
    
    override func setupLeftBarButton() -> UIBarButtonItem {
        if viewModel.topLevelController {
            return UIBarButtonItem(title: "Menu", style: .plain, target: self, action: #selector(showMenu))
        } else {
            return super.setupLeftBarButton()
        }
    }
    
    // MARK: - Notifications - 
    
    fileprivate func registerForNotifications() {
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(ItemViewController.currentPlaylistIndexChanged(_:)), name: ISMSNotification_CurrentPlaylistIndexChanged, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(ItemViewController.songPlaybackStarted(_:)), name: ISMSNotification_SongPlaybackStarted, object: nil)
    }
    
    fileprivate func unregisterForNotifications() {
        NotificationCenter.removeObserver(onMainThread: self, name: ISMSNotification_CurrentPlaylistIndexChanged, object: nil)
        NotificationCenter.removeObserver(onMainThread: self, name: ISMSNotification_SongPlaybackStarted, object: nil)
    }
    
    func currentPlaylistIndexChanged(_ notification: Notification?) {
        self.tableView.reloadData()
    }
    
    func songPlaybackStarted(_ notification: Notification?) {
        self.tableView.reloadData()
    }
    
    // MARK: - Loading -
    
    override func shouldSetupRefreshControl() -> Bool {
        return true
    }
    
    override func didPullToRefresh() {
        if !reloading {
            reloading = true
            viewModel.loadModelsFromWeb(nil)
        }
    }
    
    fileprivate func dataSourceDidFinishLoadingNewData() {
        reloading = false
        self.refreshControl?.endRefreshing()
    }
    
    func cancelLoad() {
        viewModel.cancelLoad()
        dataSourceDidFinishLoadingNewData()
    }
    
    // MARK: - Table View Delegate -
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        var titles: [String] = []
        
        if let sectionIndexes = sectionIndexes {
            for sectionIndex in sectionIndexes {
                titles.append(String(sectionIndex.letter))
            }
        }
        
        return titles;
    }
    
    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        if let sectionIndexes = sectionIndexes {
            let row = sectionIndexes[index].firstIndex
            
            // Find the section with items in it
            var section = -1
            if viewModel.folders.count > row {
                section = foldersSectionIndex
            } else if viewModel.artists.count > row {
                section = artistsSectionIndex
            } else if viewModel.albums.count > row {
                section = albumsSectionIndex
            } else if viewModel.songs.count > row {
                section = songsSectionIndex
            }
            
            if section >= 0 {
                let indexPath = IndexPath(row: row, section: section)
                tableView.scrollToRow(at: indexPath, at: UITableViewScrollPosition.top, animated: false)
            }
        }
        
        return -1;
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var count: Int? = nil
        
        switch section {
        case foldersSectionIndex:   count = viewModel.folders.count
        case artistsSectionIndex:   count = viewModel.artists.count
        case albumsSectionIndex:    count = viewModel.albums.count
        case songsSectionIndex:     count = viewModel.songs.count
        case playlistsSectionIndex: count = viewModel.playlists.count
        default: break
        }
        
        return count == nil ? 0 : count!
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var reuseIdentifier = ""
        switch indexPath.section {
        case foldersSectionIndex:   reuseIdentifier = folderCellIdentifier
        case artistsSectionIndex:   reuseIdentifier = artistCellIdentifier
        case albumsSectionIndex:    reuseIdentifier = albumCellIdentifier
        case songsSectionIndex:     reuseIdentifier = songCellIdentifier
        case playlistsSectionIndex: reuseIdentifier = playlistCellIdentifier
        default: break
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! ItemTableViewCell
        cell.cellHeight = self.tableView(tableView, heightForRowAt: indexPath)

        switch indexPath.section {
        case foldersSectionIndex:
            cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
            cell.alwaysShowCoverArt = true
            if sectionIndexes != nil {
                cell.indexShowing = true
            }
            
            let folder = viewModel.folders[indexPath.row]
            cell.associatedObject = folder
            cell.coverArtId = folder.coverArtId
            cell.title = folder.name
        case artistsSectionIndex:
            cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
            cell.alwaysShowCoverArt = true
            if sectionIndexes != nil {
                cell.indexShowing = true
            }
            
            let artist = viewModel.artists[indexPath.row]
            cell.associatedObject = artist
            cell.coverArtId = artist.coverArtId
            cell.title = artist.name
        case albumsSectionIndex:
            cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
            cell.alwaysShowCoverArt = true
            if sectionIndexes != nil {
                cell.indexShowing = true
            }
            
            let album = viewModel.albums[indexPath.row]
            cell.associatedObject = album
            cell.coverArtId = album.coverArtId
            cell.title = album.name
        case songsSectionIndex:
            cell.accessoryType = UITableViewCellAccessoryType.none
            cell.alwaysShowSubtitle = true
            
            let song = viewModel.songs[indexPath.row]
            cell.associatedObject = song
            cell.coverArtId = nil
            cell.title = song.title
            cell.trackNumber = song.trackNumber
            cell.subTitle = song.artistDisplayName
            cell.duration = song.duration
            cell.playing = (song == PlayQueue.sharedInstance.currentDisplaySong)
        default:
            break
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat = 0
        
        switch indexPath.section {
        case foldersSectionIndex:
            height = ISMSSubfolderCellHeight
        case artistsSectionIndex:
            height = ISMSArtistCellHeight
        case albumsSectionIndex:
            height = ISMSAlbumCellHeight
        case songsSectionIndex:
            height = ISMSSongCellHeight
        default:
            break
        }
        
        return ISMSNormalize(height)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if ViewObjectsSingleton.sharedInstance().isCellEnabled {
            switch indexPath.section {
            case foldersSectionIndex:
                let folder = self.viewModel.folders[indexPath.row]
                if let loader = viewModel.loaderForFolder(folder) {
                    pushItemController(loader: loader)
                }
            case artistsSectionIndex:
                let artist = self.viewModel.artists[indexPath.row]
                if let loader = viewModel.loaderForArtist(artist) {
                    pushItemController(loader: loader)
                }
            case albumsSectionIndex:
                let album = self.viewModel.albums[indexPath.row]
                if let loader = viewModel.loaderForAlbum(album) {
                    pushItemController(loader: loader)
                }
            case songsSectionIndex:
                // TODO: Implement a way to just switch play index when we're playing from the same array to save time
                //playAll(songs: viewModel.songs, playIndex: indexPath.row)
                PlayQueue.sharedInstance.playSongs(viewModel.songs, playIndex: indexPath.row)
                break
            default:
                break
            }
        }
        else
        {
            self.tableView.deselectRow(at: indexPath, animated: false)
        }
    }
    
    fileprivate func pushItemController(loader: ItemLoader) {
        let viewModel = ItemViewModel(loader: loader)
        let viewController = ItemViewController(viewModel: viewModel)
        self.pushCustom(viewController)
    }
}

extension ItemViewController : ItemViewModelDelegate {
    
    func itemsChanged() {
        self.tableView.reloadData()
        
        dataSourceDidFinishLoadingNewData()
    }
    
    func loadingError(_ error: String) {
        let message = "There was an error loading the folder.\n\nError \(error)"
        
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
        
        ViewObjectsSingleton.sharedInstance().hideLoadingScreen()
        
        dataSourceDidFinishLoadingNewData()
    }
}
