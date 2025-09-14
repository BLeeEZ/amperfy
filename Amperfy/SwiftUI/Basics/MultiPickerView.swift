//
//  MultiPickerView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 29.09.22.
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

import SwiftUI

// MARK: - MultiPickerView

struct MultiPickerView: View {
  typealias Label = String
  typealias Entry = String

  let data: [(Label, [Entry])]
  @Binding
  var selection: [Entry]

  var body: some View {
    GeometryReader { geometry in
      HStack {
        Spacer()
        ForEach(0 ..< data.count, id: \.self) { column in
          Picker(data[column].0, selection: $selection[column]) {
            ForEach(0 ..< data[column].1.count, id: \.self) { row in
              Text(verbatim: data[column].1[row])
                .tag(data[column].1[row])
            }
          }
          // Hack to get the picker to reload its data. Otherwise the picker is not updated with .menu style.
          .id(data[column].1.firstIndex(where: { entry in selection[column] == entry }))
          #if targetEnvironment(macCatalyst) // ok
            .pickerStyle(.menu) // wheel style crashes mac
          #else
            .pickerStyle(.wheel)
          #endif
            .frame(width: geometry.size.width / CGFloat(data.count), height: geometry.size.height)
            .clipped()
          Spacer()
        }
      }
    }
  }
}

// MARK: - MultiPickerView_Previews

struct MultiPickerView_Previews: PreviewProvider {
  @State
  static var selection = ["", ""]

  static var previews: some View {
    MultiPickerView(data: [("One", ["0", "1"]), ("Two", ["0", "1"])], selection: Self.$selection)
  }
}
