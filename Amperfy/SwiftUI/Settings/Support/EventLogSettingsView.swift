//
//  EventLogSettingsView.swift
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

// MARK: - EventLogSettingsView

struct EventLogSettingsView: View {
  @FetchRequest(fetchRequest: LogEntryMO.creationDateSortedFetchRequest)
  var entries: FetchedResults<LogEntryMO>

  var body: some View {
    ZStack {
      List {
        ForEach(entries, id: \.self) { entry in
          EventLogCellView(entry: LogEntry(managedObject: entry))
        }
      }
      #if targetEnvironment(macCatalyst)
      .listStyle(.plain)
      #else
      .listStyle(.grouped)
      #endif
    }
    .navigationTitle("Event Log")
  }
}

// MARK: - EventLoggerSettingsView_Previews

struct EventLoggerSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    EventLogSettingsView()
  }
}
