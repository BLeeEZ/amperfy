//
//  ArtworkDisplaySettings.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 18.09.22.
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

// MARK: - ArtworkDisplaySettings

struct ArtworkDisplaySettings: View {
  @State
  var settingOptions = [ArtworkDisplayPreference]()
  @State
  var activeOption = ArtworkDisplayPreference.serverArtworkOnly
  @EnvironmentObject
  var settings: Settings

  func updateValues() {
    settingOptions = ArtworkDisplayPreference.allCases
    activeOption = appDelegate.storage.settings.accounts.getSetting(settings.activeAccountInfo).read
      .artworkDisplayPreference
  }

  var body: some View {
    ZStack {
      List {
        Section {
          if let activeAccountInfo = settings.activeAccountInfo {
            ForEach(settingOptions, id: \.self) { option in
              Button(action: {
                appDelegate.storage.settings.accounts
                  .updateSetting(activeAccountInfo) { accountSettings in
                    accountSettings.artworkDisplayPreference = option
                  }
                updateValues()
              }) {
                HStack {
                  Text(option.description)
                  Spacer()
                  if option == activeOption {
                    AmperfyImage.check.asImage
                  }
                }
                .contentShape(Rectangle())
                .foregroundColor(.primary)
              }
            }
          }
        }
      }
    }
    .navigationTitle("Artwork Display")
    .onAppear {
      updateValues()
    }
  }
}

// MARK: - ArtworkDisplaySettings_Previews

struct ArtworkDisplaySettings_Previews: PreviewProvider {
  static var previews: some View {
    ArtworkDisplaySettings()
  }
}
