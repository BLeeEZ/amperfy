//
//  SwipeCellView.swift
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

// MARK: - SwipeCellView

struct SwipeCellView: View {
  @Environment(\.colorScheme)
  var colorScheme: ColorScheme

  var swipe: SwipeActionType

  var body: some View {
    HStack {
      Image(uiImage: colorScheme == .light ? swipe.image : swipe.image.invertedImage())
      Text(swipe.settingsName)
      Spacer()
    }
    .contentShape(Rectangle())
  }
}

// MARK: - SwipeCellView_Previews

struct SwipeCellView_Previews: PreviewProvider {
  static var previews: some View {
    SwipeCellView(swipe: .addToPlaylist)
  }
}
