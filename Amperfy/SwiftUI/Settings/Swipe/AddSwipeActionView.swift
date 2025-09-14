//
//  AddSwipeActionView.swift
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

// MARK: - AddSwipeActionView

struct AddSwipeActionView: View {
  @EnvironmentObject
  private var settings: Settings
  @Binding
  var isVisible: Bool

  @Binding
  var swipePosition: SwipePosition
  @State
  private var actionNotInUse = [SwipeActionType]()
  var addCB: (_ swipePosition: SwipePosition, _ elementToAdd: SwipeActionType) -> ()

  func reload() {
    actionNotInUse = settings.swipeActionSettings.notUsed
  }

  var body: some View {
    VStack {
      Text("Add \(swipePosition.description) swipe")
        .font(.headline)
        .fontWeight(.bold)
        .frame(alignment: .center)
        .padding()
        .padding([.top], 16)
      List {
        ForEach(actionNotInUse, id: \.self) { swipe in
          SwipeCellView(swipe: swipe)
            .onTapGesture {
              addCB(swipePosition, swipe)
              isVisible = false
            }
        }
      }
      #if targetEnvironment(macCatalyst) // ok
      .listStyle(.plain)
      #else
      .listStyle(.grouped)
      #endif

      Button(action: { isVisible = false }) {
        Text("Cancel")
          .fontWeight(.bold)
      }
      .padding()
    }
    #if targetEnvironment(macCatalyst) // ok
    .background { Color.clear }
    #endif
    .onAppear {
      reload()
    }
  }
}

// MARK: - AddSwipeActionView_Previews

struct AddSwipeActionView_Previews: PreviewProvider {
  @State
  static var settings = Settings()
  @State
  static var isVisible = true
  @State
  static var swipePosition: SwipePosition = .trailing

  static var previews: some View {
    AddSwipeActionView(isVisible: $isVisible, swipePosition: $swipePosition, addCB: { _, _ in })
      .environmentObject(settings)
  }
}
