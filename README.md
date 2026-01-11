# ![Logo](.github/Icon-40.png) Amperfy

## Basics

Amperfy is an iOS/iPadOS/macOS app written in Swift to interact with an [Ampache](http://ampache.github.io) or [Subsonic](http://www.subsonic.org) server.

### iOS

<a href="https://apps.apple.com/app/amperfy-music/id1530145038#?platform=iphone">
  <img src=".github/AppStore/Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917.svg" height="45" />
</a>

<img src=".github/Screenshots/Player.jpg" width="250" alt="Screenshot of the Amperfy player" /> &nbsp;
<img src=".github/Screenshots/AlbumDetail.jpg" width="250" alt="Screenshot of the Amperfy artist detail view" /> &nbsp;
<img src=".github/Screenshots/Library.jpg" width="250" alt="Screenshot of the Amperfy library view" />

### macOS

<a href="https://apps.apple.com/app/amperfy-music/id1530145038#?platform=mac">
  <img src=".github/AppStore/Download_on_the_Mac_App_Store_Badge_US-UK_RGB_blk_092917.svg" height="45" />
</a>

<img src=".github/Screenshots/macOS-Playlist.png" width="750" alt="Screenshot of the Amperfy playlist view in macOS" />

## Features

- Multi account
- Offline mode
- CarPlay
- Gapless playback for appropriate media file formats
- Music, Podcast and Radio support
- Siri play media command, Siri Shortcuts and App Intents
- Equalizer
- Replay gain
- Sleep timer
- 5 star song rating
- Favorite song
- Sleep Timer
- Scrobbling

## Requirements

* Xcode 26, Swift 6

## Getting Started

1. Check out the latest version of the project:
  ```
  git clone https://github.com/BLeeEZ/amperfy.git
  cd amperfy
  ```

3. Open the `Amperfy.xcodeproj` file.

4. Build and run the "Amperfy" scheme

  >Real device testing: Amperfy has Apple CarPlay and Siri support. To test it on a real device a developer certificate with granted access to `com.apple.developer.playable-content` and `com.apple.developer.siri` is required. To test Amperfy without Apple CarPlay and Siri clear all entries in `Amperfy/Amperfy.entitlements`.

## Beta test releases

For more information, and to participate in the public beta releases, please visit [Amperfy Beta](https://github.com/BLeeEZ/amperfy/issues/25).

## Contribution

Pull requests are always welcome. Please execute `AmperfyKitTests` to ensure code quality. Running tests will trigger [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) to apply the [Google Swift Style Guide](https://google.github.io/swift), as configured by [Google-SwiftFormat-Config](https://github.com/NoemiRozpara/Google-SwiftFormat-Config). You can also apply the code style manually by executing `./BuildTools/applyFormat.sh`.

## Attributions

- [AudioStreaming](https://github.com/dimitris-c/AudioStreaming) by [Dimitris C.](https://github.com/dimitris-c) is licensed under [MIT License](https://github.com/dimitris-c/AudioStreaming/blob/main/LICENSE)
- [MarqueeLabel](https://github.com/cbpowell/MarqueeLabel) by [Charles Powell](https://github.com/cbpowell) is licensed under [MIT License](https://github.com/cbpowell/MarqueeLabel/blob/master/LICENSE)
- [NotificationBanner](https://github.com/Daltron/NotificationBanner) by [Dalton Hinterscher](https://github.com/Daltron) is licensed under [MIT License](https://github.com/Daltron/NotificationBanner/blob/master/LICENSE)
- [ID3TagEditor](https://github.com/chicio/ID3TagEditor) by [Fabrizio Duroni](https://github.com/chicio) is licensed under [MIT License](https://github.com/chicio/ID3TagEditor/blob/master/LICENSE.md)
- [CoreDataMigrationRevised-Example](https://github.com/wibosco/CoreDataMigrationRevised-Example) by [William Boles](https://github.com/wibosco) is licensed under [MIT License](https://github.com/wibosco/CoreDataMigrationRevised-Example/blob/master/LICENSE)
- [VYPlayIndicator](https://github.com/obrhoff/VYPlayIndicator) by [Dennis Oberhoff](https://github.com/obrhoff) is licensed under [MIT License](https://github.com/obrhoff/VYPlayIndicator/blob/master/LICENSE)
- [CallbackURLKit](https://github.com/phimage/CallbackURLKit) by [Eric Marchand](https://github.com/phimage) is licensed under [MIT License](https://github.com/phimage/CallbackURLKit/blob/master/LICENSE)
- [DominantColors](https://github.com/DenDmitriev/DominantColors) by [Den Dmitriev](https://github.com/DenDmitriev) is licensed under [MIT License](https://github.com/DenDmitriev/DominantColors/blob/main/LICENSE)
- [AudioVisualizerKit](https://github.com/Kyome22/AudioVisualizerKit) by [Takuto NAKAMURA (Kyome)](https://github.com/Kyome22) is licensed under [MIT License](https://github.com/Kyome22/AudioVisualizerKit/blob/main/LICENSE)
- [Alamofire](https://github.com/Alamofire/Alamofire) by [Alamofire](https://github.com/Alamofire) is licensed under [MIT License](https://github.com/Alamofire/Alamofire/blob/master/LICENSE)
- [Ifrit](https://github.com/ukushu/Ifrit) by [Andrii Vynnychenko](https://github.com/ukushu) is licensed under [MIT License](https://github.com/ukushu/Ifrit/blob/main/LICENSE.md)
- [swift-collections](https://github.com/apple/swift-collections) by [Apple](https://github.com/apple) is licensed under [Apache License 2.0](https://github.com/apple/swift-collections/blob/main/LICENSE.txt)
- [iOS-swiftUI-spotify-equalizer](https://github.com/urvi-k/iOS-swiftUI-spotify-equalizer) by [urvi koladiya](https://github.com/urvi-k) is licensed under [MIT License](https://github.com/urvi-k/iOS-swiftUI-spotify-equalizer/blob/main/LICENSE)

**Amperfy license:** [GPLv3](https://github.com/BLeeEZ/Amperfy/blob/master/LICENSE)

**Special thanks:** [Dirk Hildebrand](https://apps.apple.com/us/developer/dirk-hildebrand/id654444924)
