//
//  ArtworkDownloadSettingsView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 16.09.22.
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

// MARK: - ArtworkDownloadSettingsView

struct ArtworkDownloadSettingsView: View {
  @State
  var settingOptions = [ArtworkDownloadSetting]()
  @State
  var activeOption = ArtworkDownloadSetting.onlyOnce
  @EnvironmentObject
  var settings: Settings

  func updateValues() {
    settingOptions = ArtworkDownloadSetting.allCases
    activeOption = appDelegate.storage.settings.accounts.getSetting(settings.activeAccountInfo).read
      .artworkDownloadSetting
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
                    accountSettings.artworkDownloadSetting = option
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
    .navigationTitle("Artwork Download")
    .onAppear {
      updateValues()
    }
  }
}

// MARK: - ArtworkDownloadSettingsView_Previews

struct ArtworkDownloadSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    ArtworkDownloadSettingsView()
  }
}
