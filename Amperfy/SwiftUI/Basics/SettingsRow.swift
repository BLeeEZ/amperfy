//
//  SettingsRow.swift
//  Amperfy
//
//  Created by David Klopp on 14.08.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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

import Foundation
import SwiftUI

struct SettingsRow<Content: View>: View, BehavioralStylable {   
    enum Orientation {
        case vertical
        case horizontal
    }

    let title: String?
    let detail: () -> Content
    let orientation: Orientation
    let splitPercentage: CGFloat
    @State var preferredBehavioralStyle: UIBehavioralStyle = .defaultStyle

    init(title: String? = nil, orientation: Orientation = .horizontal, splitPercentage: CGFloat = 0.4,  @ViewBuilder detail:  @escaping () -> Content) {
        self.title = title
        self.detail = detail
        self.orientation = orientation
        self.splitPercentage = min(max(splitPercentage, 0.0), 1.0)
    }

    var body: some View {
        if self.behavioralStyle == .mac {
            // we only support a horizontal style on macOS
            let lhsSplit = self.splitPercentage
            let rhsSplit = (1.0 - lhsSplit)
            GeometryReader { metrics in
                HStack(alignment: .center) {
                    HStack(spacing: 0) {
                        Spacer()
                        if let title {
                            Text("\(title):")
                        }
                    }
                    .frame(width: metrics.size.width*lhsSplit)
                    HStack(spacing: 0) {
                        self.detail()
                            .frame(maxWidth: metrics.size.width*rhsSplit)
                            .alignmentGuide(.leading, computeValue: {_ in 0} )
                            .fixedSize()
                            .lineLimit(1)
                        Spacer()
                    }
                    .frame(width: metrics.size.width*rhsSplit)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
            if self.orientation == .horizontal {
                HStack {
                    if let title {
                        Text(title)
                    }
                    Spacer()
                    self.detail()
                }
            } else {
                VStack(alignment: .leading) {
                    if let title {
                        Text(title)
                            .padding([.bottom], 2)
                    }
                    self.detail()
                }
            }
        }
    }
}

// Title is ignored on iOS. 
struct SettingsCheckBoxRow: View, BehavioralStylable {
    let title: String?
    let label: String
    let isOn: Binding<Bool>
    let splitPercentage: CGFloat
    @State var preferredBehavioralStyle: UIBehavioralStyle = .defaultStyle

    init(title: String? = nil, label: String, splitPercentage: CGFloat = 0.4, isOn: Binding<Bool>) {
        self.title = title
        self.label = label
        self.isOn = isOn
        self.splitPercentage = splitPercentage
    }

    var body: some View {
        if self.behavioralStyle == .mac {
            SettingsRow(title: self.title, splitPercentage: self.splitPercentage) {
                Toggle(isOn: self.isOn) {}
                Text(self.label)
                    .padding(.leading, 5)
            }.preferredBehavioralStyle(self.preferredBehavioralStyle)
        } else {
            SettingsRow(title: self.label, splitPercentage: self.splitPercentage) {
                Toggle(isOn: self.isOn) {}
            }.preferredBehavioralStyle(self.preferredBehavioralStyle)
        }
    }
}

struct SettingsButtonRow: View, BehavioralStylable {
    enum ActionType {
        case normal
        case destructive
        case done

        var foregroundColor: Color? {
            switch self {
            case .normal: nil
            case .destructive: Color.red
            case .done: Color.blue
            }
        }
    }

    let title: String?
    let label: String
    let actionType: ActionType
    let action: () -> Void
    let splitPercentage: CGFloat
    @State var preferredBehavioralStyle: UIBehavioralStyle = .defaultStyle

    init(title: String? = nil, label: String, actionType: ActionType = .normal, splitPercentage: CGFloat = 0.4, action: @escaping () -> Void) {
        self.title = title
        self.label = label
        self.actionType = actionType
        self.action = action
        self.splitPercentage = splitPercentage
    }

    var body: some View {
        if self.behavioralStyle == .mac {
            SettingsRow(title: self.title, splitPercentage: self.splitPercentage) {
                Button(action: action) {
                    Text(self.label)
                }
            }
            .preferredBehavioralStyle(self.preferredBehavioralStyle)
            .foregroundColor(self.actionType.foregroundColor)
            .buttonStyle(.bordered)
        } else {
            Button(action: action) {
                Text(self.label)
            }.foregroundColor(self.actionType.foregroundColor)
        }
    }
}

struct ListToolbar<Buttons: View>: ViewModifier {
    let buttons: () -> Buttons

    init(@ViewBuilder _ buttons: @escaping () -> Buttons) {
        self.buttons = buttons
    }

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
            HStack(spacing: 10) {
                Spacer().frame(width: 0.0)
                self.buttons()
                Spacer()
            }
            .frame(height: 30)
            .background(Color.systemBackground)
            .border(Color.separator, width: 1.0)
            .padding(.top, -1)
        }
        .listRowSeparator(.hidden)
    }
}

extension View {
    func listToolbar<Buttons: View>(@ViewBuilder with buttons: @escaping () -> Buttons) -> some View {
        modifier(ListToolbar(buttons))
    }
}
