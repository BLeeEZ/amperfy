//
//  DeveloperView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 14.06.24.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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

import AmperfyKit
import SwiftUI

// MARK: - DeveloperView

struct DeveloperView: View {
  @EnvironmentObject
  private var settings: Settings

  func generateDefaultArtworks() {
    for artworkType in ArtworkType.allCases {
      for lightDarkMode in LightDarkModeType.allCases {
        for theme in ThemePreference.allCases {
          let name = theme.description + artworkType.description + lightDarkMode
            .description + ".png"
          let img = UIImage.generateArtwork(
            theme: theme,
            lightDarkMode: lightDarkMode,
            artworkType: artworkType
          )
          let fileURL = URL(string: name)!
          let absFilePath = CacheFileManager.shared.getAbsoluteAmperfyPath(relFilePath: fileURL)!
          try? CacheFileManager.shared.writeDataExcludedFromBackup(
            data: img.pngData()!,
            to: absFilePath,
            accountInfo: nil
          )
        }
      }
    }
  }

  var body: some View {
    ZStack {
      SettingsList {
        SettingsSection(content: {
          SettingsButtonRow(title: "Generate Default Artworks") {
            generateDefaultArtworks()
          }
        })
      }
    }
    .navigationTitle("Developer")
    .navigationBarTitleDisplayMode(.inline)
  }
}

// MARK: - DeveloperView_Previews

struct DeveloperView_Previews: PreviewProvider {
  @State
  static var settings = Settings()

  static var previews: some View {
    DeveloperView().environmentObject(settings)
  }
}
