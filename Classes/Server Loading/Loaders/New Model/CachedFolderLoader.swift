//
//  CachedFolderLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class CachedFolderLoader: CachedDatabaseLoader {
    fileprivate static var operationQueues = [OperationQueue]()
    
    let folderId: Int64
    
    var folders = [Folder]()
    var songs = [Song]()
    var songsDuration = 0
    
    override var items: [Item] {
        return folders as [Item] + songs as [Item]
    }
    
    override var associatedItem: Item? {
        return FolderRepository.si.folder(folderId: folderId, serverId: serverId)
    }
    
    init(folderId: Int64, serverId: Int64) {
        self.folderId = folderId
        super.init(serverId: serverId)
    }
    
    @discardableResult override func loadModelsFromDatabase() -> Bool {
        folders = FolderRepository.si.folders(parentFolderId: folderId, serverId: serverId, isCachedTable: true)
        songs = SongRepository.si.songs(folderId: folderId, serverId: serverId, isCachedTable: true)
        songsDuration = songs.reduce(0) { totalDuration, song -> Int in
            if let duration = song.duration {
                return totalDuration + duration
            }
            return totalDuration
        }
        return true
    }
}
