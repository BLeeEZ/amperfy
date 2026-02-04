# ![App Icon](Assets/icon-64.png) Musify
Musify is a fork of the Amperfy project with adjustments for my personal needs. I want to thank BLeeEZ for the awesome work that Amperfy represents. My modifications to Amperfy will probably not be liked by most Amperfy users as I have even removed features/settings that I personally do not need. I am a big advocate of a simple UI and provide a minimal number of settings options.
I do not implement pull requests - please support the Amperfy project if you want features to be added. I will include Amperfy updates in Musify from time to time though.

### This is a list of changes I made to Amperfy:

- Changed the app icon to be more self explanatory of the app-type
- Slight modifications of the dark theme (use 90% black and 90% white instead of 100% black/white)
- Show star ratings in song lists (can be controlled by a setting)
- Show a star rating and favorite setting element in the currently-playing view (can be controlled by a setting)
- Show a Song Info view with details about the currently played song by clicking (i) button
- Show lyrics by just clicking on the album art in currently-playing view
- Show the total song duration in currently-playing view
- Redesign of the lyrics view and removed the 'Lyrics Smooth Scrolling' setting (enabled by default)
- Only show one settings button "..." in currently-playing view
  - Redesign of context menu
  - Removed 'Download' (can be done from Song Info view)
  - Removed Visualizer (Visualizer is slow and not impressive so hide it for now)
  - Removed 'Show Lyrics' (lyrics can be opened by click on album art)
  - Removed 'Favorite' (can be done at main view)
  - Removed 'Rating:' (can be done at main view)
  - Removed Copy ID to Clipboard' (can be done in Song Info view)
  - Renamed context queue to just queue (I will probably remove the user queue later and only have one queue)
- When streaming music, always temporarily cache the currently played song
  - This fixes an issue where scrubbing/seeking of streamed songs did not work
  - The cached song will be deleted as soon as the next song starts
  - Once the currently played/streamed song is cached, the little antenna icon turns green
- Show a 'Preamp' setting when ReplayGain is enabled. As ReplayGain will most often reduce the volume, this value can be used to have a general offset value and keep music 'louder'. Eg. ReplayGain for a song is -7.2 dB; Preamp is set to +6 dB; Final volume setting will be -1.2 dB.
- Show the currently applied song ReplayGain in currently-playing view
- Changed the general behavior of the 'Play', '>>' and '<<' buttons in currently-playing view
  - The play/pause status will not be changed by clicking '<<' or '>>'. If a song is paused and you click '>>' the next song will also be paused. When a song is currently playing and you click '>>' the next song will also be played automatically.
  - Removed the 'Manual Playback' setting
- When a song is starting, song data (eg. playcount) will be automatically fetched from server
  - Local playcounts are disabled as they increased as soon a song started.
  - Playcounts are only maintained by the server, no matter if a song is streamed or already downloaded
  - Removed the "Scrobble streamed Songs" setting (always enabled)
- Always remember the playback position of only the currently played song
  - When restarting the app the position of the previously played song will be remembered
  - Removed setting 'Song Playback Resume' as this will remember the playback position of all songs and you might end up with a playlist/album where songs just start anywhere in the middle.

### Changes to the Settings menu:
- Added 'Show Star Rating' setting in 'Display and Interaction'
- Removed 'Lyrics Smooth Scrolling' (always enabled) in 'Display and Interaction'
- Moved "Resync Library" to the 'Library' section
- Added 'Preamp' Setting to 'ReplayGain' in 'Player, Stream & Scrobble'
- Removed 'Manual Playback' in 'Player, Stream & Scrobble'
- Removed the "Scrobble streamed Songs" setting (always enabled) in 'Player, Stream & Scrobble'
- Removed setting 'Song Playback Resume' in 'Player, Stream & Scrobble'

## Comparision:

#### Grid view (Amperfy / Musify):
<img src="Assets/amperfy01.jpeg" width="400" alt="GridView Amperfy"> <img src="Assets/musify01.jpeg" width="400" alt="GridView Musify">

#### Star ratings in song lists (Amperfy / Musify):
<img src="Assets/amperfy02.jpeg" width="400" alt="Song-List Amperfy"> <img src="Assets/musify02.jpeg" width="400" alt="Song-List Musify">

#### Currently playing view (Amperfy / Musify):
<img src="Assets/amperfy03.jpeg" width="400" alt="Currently Playing Amperfy"> <img src="Assets/musify03.jpeg" width="400" alt="Currently Playing Musify">

#### Lyrics view (Amperfy / Musify):
<img src="Assets/amperfy04.jpeg" width="400" alt="Lyrics View Amperfy"> <img src="Assets/musify04.jpeg" width="400" alt="Lyrics View Musify">

#### Context Menu (Amperfy / Amperfy):
<img src="Assets/amperfy05a.jpeg" width="400" alt="Context Menu Amperfy"> <img src="Assets/amperfy05b.jpeg" width="400" alt="Context Menu Amperfy">

#### Context Menu & Song Info view (Musify / Musify):
<img src="Assets/musify05.jpeg" width="400" alt="Context Menu Musify"> <img src="Assets/musify06.jpeg" width="400" alt="Song Info Musify">

* * *

# THIS IS THE ORIGINAL AMPERFY README:

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
