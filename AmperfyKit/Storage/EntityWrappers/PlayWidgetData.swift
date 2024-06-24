//
//  PlayWidgetData.swift
//  AmperfyKit
//
//  Created by daniele on 22/06/24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import Foundation
import UIKit

public class PlayWidgetData: Codable {
    public let songName: String
    public let songArtist: String
    public let image: Data?
    public var isPlaying: Bool
    
    public init(song: Song?, isPlaying: Bool) {
        guard (song != nil) else {
            self.songName = "Song Name"
            self.songArtist = "Artist"
            self.image = UIImage.blueSong.pngData()
            self.isPlaying = false
            return
        }
        self.songName = song?.name ?? "Song Name"
        self.songArtist = song?.artist?.name ?? "Artist"
        self.image = song?.artwork?.image?.pngData() ?? UIImage.blueSong.pngData()
        self.isPlaying = isPlaying
    }
}
