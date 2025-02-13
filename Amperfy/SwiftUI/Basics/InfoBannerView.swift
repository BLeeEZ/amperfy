//
//  InfoBannerView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 15.09.22.
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

// MARK: - InfoBannerView

struct InfoBannerView: View {
  var message: String
  var color: Color

  var body: some View {
    Text(message)
      .padding()
      .frame(maxWidth: .infinity)
      .foregroundColor(.white)
      .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(1)))
  }
}

// MARK: - InfoBannerView_Previews

struct InfoBannerView_Previews: PreviewProvider {
  static var previews: some View {
    VStack {
      InfoBannerView(message: "Test error message", color: .error)
      InfoBannerView(message: "Test success message", color: .success)
    }
  }
}
