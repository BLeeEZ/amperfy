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
enum NavigationTarget: String, CaseIterable {
  case general
  case displayAndInteraction
  case server
  case library
  case player
  case swipe
  case artwork
  case support
  case license
  case xcallback
  #if DEBUG
    case developer = "developer"
  #endif

  func view() -> any View {
    switch self {
    case .general: SettingsView()
    case .displayAndInteraction: DisplaySettingsView()
    case .server: ServerSettingsView()
    case .library: LibrarySettingsView()
    case .player: PlayerSettingsView()
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
    case .server: "Server"
    case .library: "Library"
    case .swipe: "Swipe"
    case .artwork: "Artwork"
    case .support: "Support"
    case .license: "License"
    #if targetEnvironment(macCatalyst)
      case .player: "Player"
      case .xcallback: "X-Callback"
    #else
      case .player: "Player, Stream & Scrobble"
      case .xcallback: "X-Callback-URL Documentation"
    #endif
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
    case .server: .server
    case .library: .musicLibrary
    case .player: .playCircle
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

  #if targetEnvironment(macCatalyst)
    var toolbarIdentifier: NSToolbarItem.Identifier { NSToolbarItem.Identifier(rawValue) }

    var fittingWindowSize: CGSize {
      let width = 680
      let height = switch self {
      case .general: 250
      case .displayAndInteraction: 320
      case .server: 480
      case .library: 620
      case .player: 350
      case .swipe: 450
      case .artwork: 300
      case .support: 400
      default: 400
      }
      return CGSize(width: width, height: height)
    }

    func hostingController(
      settings: Settings,
      managedObjectContext: NSManagedObjectContext
    )
      -> UIHostingController<AnyView> {
      UIHostingController(
        rootView: AnyView(
          view()
            .environmentObject(settings)
            .environment(\.managedObjectContext, managedObjectContext)
        )
      )
    }
  #endif
}
