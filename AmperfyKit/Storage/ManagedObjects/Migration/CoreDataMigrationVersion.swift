//
//  CoreDataVersion.swift
//  CoreDataMigration-Example
//
//  Created by William Boles on 02/01/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import CoreData
import Foundation

enum CoreDataMigrationVersion: String, CaseIterable {
  case v1 = "Amperfy"
  case v2 = "Amperfy v2"
  case v3 = "Amperfy v3"
  case v4 = "Amperfy v4"
  case v5 = "Amperfy v5"
  case v6 = "Amperfy v6"
  case v7 = "Amperfy v7"
  case v8 = "Amperfy v8"
  case v9 = "Amperfy v9"
  case v10 = "Amperfy v10"
  case v11 = "Amperfy v11"
  case v12 = "Amperfy v12"
  case v13 = "Amperfy v13"
  case v14 = "Amperfy v14"
  case v15 = "Amperfy v15"
  case v16 = "Amperfy v16"
  case v17 = "Amperfy v17"
  case v18 = "Amperfy v18"
  case v19 = "Amperfy v19"
  case v20 = "Amperfy v20"
  case v21 = "Amperfy v21"
  case v22 = "Amperfy v22"
  case v23 = "Amperfy v23"
  case v24 = "Amperfy v24"
  case v25 = "Amperfy v25"
  case v26 = "Amperfy v26"
  case v27 = "Amperfy v27"
  case v28 = "Amperfy v28"
  case v29 = "Amperfy v29"
  case v30 = "Amperfy v30"
  case v31 = "Amperfy v31"
  case v32 = "Amperfy v32"
  case v33 = "Amperfy v33"
  case v34 = "Amperfy v34"
  case v35 = "Amperfy v35"
  case v36 = "Amperfy v36"
  case v37 = "Amperfy v37"
  case v38 = "Amperfy v38"
  case v39 = "Amperfy v39"
  case v40 = "Amperfy v40"
  case v41 = "Amperfy v41"
  case v42 = "Amperfy v42" // Playlist uses ordered set of items, Adding delete rules for playlists
  case v43 = "Amperfy v43" // Add isCached, Increase duration for collections from Int16 to Int64
  case v44 = "Amperfy v44" // use Fetch Index
  case v45 = "Amperfy v45" // Download: id has default value "Empty String"
  case v46 = "Amperfy v46" // Add addedDate for songs
  case v47 = "Amperfy v47" // Add replay gain and peak for songs
  case v48 = "Amperfy v48" // Account support: add account (url + user)
  case v49 =
    "Amperfy v49" // Remove PlayableFile and Artwork data (they were already deprecated); Account: add apiType

  // MARK: - Current

  static var current: CoreDataMigrationVersion {
    guard let latest = allCases.last else {
      fatalError("no model versions found")
    }

    return latest
  }

  // MARK: - Migration

  func nextVersion() -> CoreDataMigrationVersion? {
    switch self {
    case .v1:
      return .v2
    case .v2:
      return .v3
    case .v3:
      return .v4
    case .v4:
      return .v5
    case .v5:
      return .v6
    case .v6:
      return .v7
    case .v7:
      return .v8
    case .v8:
      return .v9
    case .v9:
      return .v10
    case .v10:
      return .v11
    case .v11:
      return .v12
    case .v12:
      return .v13
    case .v13:
      return .v14
    case .v14:
      return .v15
    case .v15:
      return .v16
    case .v16:
      return .v17
    case .v17:
      return .v18
    case .v18:
      return .v19
    case .v19:
      return .v20
    case .v20:
      return .v21
    case .v21:
      return .v22
    case .v22:
      return .v23
    case .v23:
      return .v24
    case .v24:
      return .v25
    case .v25:
      return .v26
    case .v26:
      return .v27
    case .v27:
      return .v28
    case .v28:
      return .v29
    case .v29:
      return .v30
    case .v30:
      return .v31
    case .v31:
      return .v32
    case .v32:
      return .v33
    case .v33:
      return .v34
    case .v34:
      return .v35
    case .v35:
      return .v36
    case .v36:
      return .v37
    case .v37:
      return .v38
    case .v38:
      return .v39
    case .v39:
      return .v40
    case .v40:
      return .v41
    case .v41:
      return .v42
    case .v42:
      return .v43
    case .v43:
      return .v44
    case .v44:
      return .v45
    case .v45:
      return .v46
    case .v46:
      return .v47
    case .v47:
      return .v48
    case .v48:
      return .v49
    case .v49:
      return nil
    }
  }
}
