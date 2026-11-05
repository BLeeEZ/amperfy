//
//  SupportSettingsView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 19.09.22.
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

// MARK: - SupportSettingsView

struct SupportSettingsView: View {
  let splitPercentage = 0.15

  var body: some View {
    ZStack {
      SettingsList {
        SettingsSection {
          SettingsButtonRow(
            title: "Report an issue on GitHub",
            splitPercentage: splitPercentage
          ) {
            if let url = URL(string: "https://github.com/DCM4711/amperfy/issues") {
              UIApplication.shared.open(url)
            }
          }
        }

        SettingsSection {
          NavigationLink(destination: EventLogSettingsView()) {
            Text("Event Log")
          }
        }
      }
    }
    .navigationTitle("Support")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      appDelegate.userStatistics.visited(.settingsSupport)
    }
  }
}

// MARK: - SupportSettingsView_Previews

struct SupportSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SupportSettingsView()
  }
}
