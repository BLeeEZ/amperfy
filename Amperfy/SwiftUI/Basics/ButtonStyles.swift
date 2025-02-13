//
//  ButtonStyles.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 20.09.22.
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

// MARK: - DefaultButtonStyle

struct DefaultButtonStyle: ButtonStyle {
  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .foregroundColor(.systemBackground)
      .padding([.top, .bottom], 8)
      .background(configuration.isPressed ? Color.blue.opacity(0.75) : Color.blue)
      .cornerRadius(15.0)
      .contentShape(Rectangle())
  }
}

// MARK: - ErrorButtonStyle

struct ErrorButtonStyle: ButtonStyle {
  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .foregroundColor(.systemBackground)
      .padding([.top, .bottom], 8)
      .background(configuration.isPressed ? Color.error.opacity(0.75) : Color.error)
      .cornerRadius(15.0)
      .contentShape(Rectangle())
  }
}
