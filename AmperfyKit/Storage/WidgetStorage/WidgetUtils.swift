//
//  WidgetStorage.swift
//  AmperfyKit
//
//  Created by daniele on 22/06/24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import Foundation
import WidgetKit

public class WidgetUtils {
    public static func saveCurrentSong(song: Song?){
        guard song != nil else { return }
        let currentEncodedData  = UserDefaults(suiteName: "group.de.familie-zimba.amperfy-music")!.object(forKey: "widgetData") as? Data
        if let playWidgetEncodedData = currentEncodedData {
            let playWidgetDataDecoded = try? JSONDecoder().decode(PlayWidgetData.self, from: playWidgetEncodedData)
            if let widgetData = playWidgetDataDecoded {
                let updatedWidgetData = PlayWidgetData(song: song, isPlaying: widgetData.isPlaying)
                let updatedWidgetDataEncoded = try! JSONEncoder().encode(updatedWidgetData)
                UserDefaults(suiteName: "group.de.familie-zimba.amperfy-music")!.set(updatedWidgetDataEncoded, forKey: "widgetData")
                WidgetCenter.shared.reloadTimelines(ofKind: "PlayWidgetSmall")
            }
        }
    }
    
    public static func setPlaybackStatus(isPlaying: Bool) {
        let currentEncodedData  = UserDefaults(suiteName: "group.de.familie-zimba.amperfy-music")!.object(forKey: "widgetData") as? Data
        if let playWidgetEncodedData = currentEncodedData {
            let playWidgetDataDecoded = try? JSONDecoder().decode(PlayWidgetData.self, from: playWidgetEncodedData)
            if let widgetData = playWidgetDataDecoded {
                widgetData.isPlaying = isPlaying
                let updatedWidgetDataEncoded = try! JSONEncoder().encode(widgetData)
                UserDefaults(suiteName: "group.de.familie-zimba.amperfy-music")!.set(updatedWidgetDataEncoded, forKey: "widgetData")
                WidgetCenter.shared.reloadTimelines(ofKind: "PlayWidgetSmall")
            }
        }
    }
}
