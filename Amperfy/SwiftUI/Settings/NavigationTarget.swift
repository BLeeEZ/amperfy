//
//  NavigationTarget.swift
//  Amperfy
//
//  Created by David Klopp on 15.08.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
import SwiftUI

@MainActor
enum NavigationTarget: String, CaseIterable, @MainActor Identifiable {
  case general
  case account
  case displayAndInteraction
  case library
  case player
  case equalizer
  case swipe
  case artwork
  case support
  case license
  case xcallback
  #if DEBUG
    case developer = "developer"
  #endif

  var id: String { rawValue }

  func view() -> any View {
    switch self {
    case .general: SettingsView()
    case .displayAndInteraction: DisplaySettingsView()
    case .account: AccountSettingsView()
    case .library: LibrarySettingsView()
    case .player: PlayerSettingsView()
    case .equalizer: EqualizerSettingsView()
    case .swipe: SwipeSettingsView()
    case .artwork: ArtworkSettingsView()
    case .support: SupportSettingsView()
    case .license: LicenseSettingsView()
    case .xcallback: XCallbackURLsSetttingsView()
    #if DEBUG
      case .developer: DeveloperView()
    #endif
    }
  }

  var displayName: String {
    switch self {
    case .general: "General"
    case .displayAndInteraction: "Display & Interaction"
    case .account: "Account"
    case .library: "Library"
    case .swipe: "Swipe"
    case .artwork: "Artwork"
    case .support: "Support"
    case .license: "License"
    case .equalizer: "Equalizer"
    case .player: "Player, Stream & Scrobble"
    case .xcallback: "X-Callback-URL Documentation"
    #if DEBUG
      case .developer: "Developer"
    #endif
    }
  }

  @MainActor
  var icon: UIImage {
    switch self {
    case .general: .settings
    case .displayAndInteraction: .display
    case .account: .userPerson
    case .library: .musicLibrary
    case .player: .playCircle
    case .equalizer: .equalizer
    case .swipe: .arrowRight
    case .artwork: .photo
    case .support: .person
    case .license: .doc
    case .xcallback: .arrowTurnUp
    #if DEBUG
      case .developer: .hammer
    #endif
    }
  }

  var systemImage: String {
    switch self {
    case .general: "gear"
    case .displayAndInteraction: "display"
    case .account: "person.fill"
    case .library: "music.note.house"
    case .player: "play.circle.fill"
    case .equalizer: "chart.bar.xaxis"
    case .swipe: "arrow.right.circle.fill"
    case .artwork: "photo.fill"
    case .support: "person.circle"
    case .license: "doc.fill"
    case .xcallback: "arrowshape.turn.up.backward.circle.fill"
    #if DEBUG
      case .developer: "hammer.circle.fill"
    #endif
    }
  }
}
