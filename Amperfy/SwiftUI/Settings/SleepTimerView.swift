//
//  SleepTimerView.swift
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

struct SleepTimerView: View {
    
    @EnvironmentObject private var settings: Settings
    
    @State var data: [(String, [String])] = [
            ("Hours", Array(0...10).map { "\($0)" }),
            ("Minutes", Array(0...59).map { "\($0)" }),
        ]
    @State var selection: [String] = [0, 30].map { "\($0)" }
    
    var hours: Int {
        return Int(selection[0]) ?? 0
    }
    
    var minutes: Int {
        return Int(selection[1]) ?? 0
    }
    
    var timeInterval: TimeInterval {
        return TimeInterval(((hours * 60) + (minutes)) * 60)
    }
    
    var body: some View {
        List {
            if let fireDate = settings.sleepTimer?.fireDate {
                Section {
                    VStack {
                        Text("Playback will be paused at:")
                            .foregroundColor(.secondaryLabel)
                        Text(fireDate.asShortHrMinString)
                            .foregroundColor(.secondaryLabel)
                        Button(action: {
                            settings.sleepTimer?.invalidate()
                            settings.sleepTimer = nil
                        }) {
                            HStack {
                                Spacer()
                                Text("Deactivate Timer")
                                Spacer()
                            }
                        }
                        .buttonStyle(ErrorButtonStyle())
                    }
                }
            } else {
                Section {
                    Text("Set a time interval after which playback should be paused.")
                }
            }
            
            Section {
                VStack(alignment: .center, spacing: 0.0) {
                    HStack {
                        Spacer()
                        ForEach(0..<self.data.count, id: \.self) { column in
                            Text(data[column].0)
                                .foregroundColor(.secondaryLabel)
                            if column + 1 < self.data.count {
                                Spacer()
                                Spacer()
                            }
                        }
                        Spacer()
                    }
                    MultiPickerView(data: data, selection: $selection).frame(height: 200)
                }
            }
            .padding()
            
            Section {
                VStack {
                    Text("Sleep timer interval:")
                    Text("\(hours) hour\(hours > 0 ? (hours == 1 ? "" : "s") : "s") and \(minutes) minute\(minutes > 0 ? (minutes == 1 ? "" : "s") : "s") (\(Date().addingTimeInterval(timeInterval).asShortHrMinString))")
                    HStack(spacing: 8) {
                        Button(action: {
                            settings.sleepTimer?.invalidate()
                            settings.sleepTimerInterval = Int(timeInterval)
                            settings.sleepTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { (t) in
                                self.appDelegate.player.pause()
                                self.appDelegate.eventLogger.info(topic: "Sleep Timer", message: "Sleep timer paused playback.")
                                settings.sleepTimer?.invalidate()
                                settings.sleepTimer = nil
                            }
                        }) {
                            HStack {
                                Spacer()
                                if settings.sleepTimer == nil {
                                    Text("Activate Timer")
                                } else {
                                    Text("Change active interval")
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(DefaultButtonStyle())
                    }
                }
            }

        }
        .navigationTitle("Sleep Timer")
        .onAppear {
            let interval = settings.sleepTimerInterval > 0 ? settings.sleepTimerInterval : 30*60
            let intervalInMin = interval / 60
            selection[0] = String(intervalInMin / 60)
            selection[1] = String(intervalInMin % 60)
        }
    }
    
}

struct SleepTimerView_Previews: PreviewProvider {
    static var previews: some View {
        SleepTimerView()
    }
}
