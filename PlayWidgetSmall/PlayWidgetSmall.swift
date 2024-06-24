//
//  PlayWidgetSmall.swift
//  PlayWidgetSmall
//
//  Created by daniele on 22/06/24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import WidgetKit
import SwiftUI
import AmperfyKit

struct Provider: TimelineProvider {
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let encodedData  = UserDefaults(suiteName: "group.de.familie-zimba.amperfy-music")!.object(forKey: "widgetData") as? Data
        if let playWidgetEncodedData = encodedData {
            let playWidgetDataDecoded = try? JSONDecoder().decode(PlayWidgetData.self, from: playWidgetEncodedData)
            if let playWidgetData = playWidgetDataDecoded {
                let timeline = Timeline(entries: [SimpleEntry(date: Date(), songName: playWidgetData.songName, songArtist: playWidgetData.songArtist, isPlaying: playWidgetData.isPlaying, artwork: playWidgetData.image)], policy: .never)
                completion(timeline)
            }
        }
    }
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), songName: "Song Name", songArtist: "Song Artist", isPlaying: true, artwork: UIImage(systemName: "music.note")?.pngData())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), songName: "Song Name", songArtist: "Song Artist", isPlaying: true, artwork: UIImage(systemName: "music.note")?.pngData())
        completion(entry)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let songName: String
    let songArtist: String
    let isPlaying: Bool
    let artwork: Data?
}

struct PlayWidgetSmallEntryView : View {
    var entry: Provider.Entry
    
    var body: some View {
        let artwork = UIImage(data: entry.artwork!)
        VStack(alignment: .leading, spacing: 0) {
            Image(uiImage: artwork ?? UIImage())
                .resizable()
                .frame(maxWidth: 70, maxHeight: 70)
                .aspectRatio(contentMode: .fill)
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Spacer()
            Text(entry.songName)
                .font(.caption)
                .bold()
                .lineLimit(1)
            Text(entry.songArtist)
                .font(.caption2)
                .lineLimit(1)
            if #available(iOS 17.0, *){
                Spacer()
                Button(intent: PlayWidgetIntent()){
                    HStack {
                        Image(systemName: entry.isPlaying ? "stop.fill" : "play.fill")
                            .foregroundStyle(.primary)
                        Text(entry.isPlaying ? "Stop" : "Play")
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(0)
            }
        }.tint(.primary)
    }
}

struct PlayWidgetSmall: Widget {
    let kind: String = "PlayWidgetSmall"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                PlayWidgetSmallEntryView(entry: entry)
                    .containerBackground(.windowBackground, for: .widget)
            } else {
                PlayWidgetSmallEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Amperfy Music")
        .description("Simple widget that allows to control music playback")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    PlayWidgetSmall()
} timeline: {
    SimpleEntry(date: .now, songName: "Perry Manson", songArtist: "MadMan", isPlaying: true, artwork: UIImage(systemName: "play.fill")!.pngData())
}
