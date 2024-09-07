//
//  SettingsList.swift
//  Amperfy
//
//  Created by David Klopp on 07.09.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import Foundation
import SwiftUI

struct SettingsList<Content: View>: View, BehavioralStylable {    
    @State var preferredBehavioralStyle: UIBehavioralStyle = .defaultStyle
    let content: () -> Content
    
    init(@ViewBuilder content:  @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        if (self.behavioralStyle == .mac), #available(iOS 16, *) {
            List {
                self.content()
            }
            .background(Color.clear)
            .scrollContentBackground(.hidden)
        } else {
            List {
                self.content()
            }
            .background(Color.clear)
        }
    }
}
