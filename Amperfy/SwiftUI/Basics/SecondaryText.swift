//
//  SecondaryText.swift
//  Amperfy
//
//  Created by David Klopp on 16.08.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import Foundation

import SwiftUI

struct SecondaryText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(self.text)
            .foregroundStyle(Color.secondaryLabel)
            .help(self.text)
    }
}
