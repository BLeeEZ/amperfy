# ![Logo](https://github.com/BLeeEZ/amperfy/blob/master/AmperfyKit/Assets/Assets.xcassets/AppIcon.appiconset/Icon-40.png) Amperfy

<a href="https://apps.apple.com/app/amperfy-music/id1530145038#?platform=iphone"><img src=".github/AppStore/Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917.svg" height="45" /></a>

## Basics

Amperfy is an iOS app written in Swift to interact with an [Ampache](http://ampache.github.io) or [Subsonic](http://www.subsonic.org) server.

<img src=".github/Screenshots/Player.jpg" width="250" alt="Screenshot of the Amperfy player" /> &nbsp;
<img src=".github/Screenshots/ArtistDetail.jpg" width="250" alt="Screenshot of the Amperfy artist detail view" /> &nbsp;
<img src=".github/Screenshots/Library.jpg" width="250" alt="Screenshot of the Amperfy library view" />

## Features

- Offline support
- Support for music and podcasts
- CarPlay support
- Syncing the database after first login
- Update library in background
- Siri voice commands: "play \<example artist\> in Amperfy"
- Siri shortcuts: play id, search and play
- Player interaction from lock screen
- Sleep timer
- Adjustable playback rate
- Remote controlable
- Dark mode support

## Requirements

* Xcode 12, swift 5

## Getting Started

1. Check out the latest version of the project:
  ```
  git clone https://github.com/BLeeEZ/amperfy.git
  cd amperfy
  ```

3. Open the `Amperfy.xcodeproj` file.

4. Build and run the "Amperfy" scheme

  >Real device testing: Amperfy has Apple CarPlay and Siri support. To test it on a real device a developer certificate with granted access to `com.apple.developer.playable-content` and `com.apple.developer.siri` is requiered. To test Amperfy without Apple CarPlay and Siri clear all entries in `Amperfy/Amperfy.entitlements`.

## Beta test releases

For more information, and to participate in the public beta releases, please visit [Amperfy Beta](https://github.com/BLeeEZ/amperfy/issues/25).

## Attributions

- [LNPopupController](https://github.com/LeoNatan/LNPopupController) by [LeoNatan](https://github.com/LeoNatan) is licensed under [MIT License](https://github.com/LeoNatan/LNPopupController/blob/master/LICENSE)
- [MarqueeLabel](https://github.com/cbpowell/MarqueeLabel) by [Charles Powell](https://github.com/cbpowell) is licensed under [MIT License](https://github.com/cbpowell/MarqueeLabel/blob/master/LICENSE)
- [NotificationBanner](https://github.com/Daltron/NotificationBanner) by [Dalton Hinterscher](https://github.com/Daltron) is licensed under [MIT License](https://github.com/Daltron/NotificationBanner/blob/master/LICENSE)
- [ID3TagEditor](https://github.com/chicio/ID3TagEditor) by [Fabrizio Duroni](https://github.com/chicio) is licensed under [MIT License](https://github.com/chicio/ID3TagEditor/blob/master/LICENSE.md)
- [CoreDataMigrationRevised-Example](https://github.com/wibosco/CoreDataMigrationRevised-Example) by [William Boles](https://github.com/wibosco) is licensed under [MIT License](https://github.com/wibosco/CoreDataMigrationRevised-Example/blob/master/LICENSE)
- [VYPlayIndicator](https://github.com/obrhoff/VYPlayIndicator) by [Dennis Oberhoff](https://github.com/obrhoff) is licensed under [MIT License](https://github.com/obrhoff/VYPlayIndicator/blob/master/LICENSE)
- [CallbackURLKit](https://github.com/phimage/CallbackURLKit) by [Eric Marchand](https://github.com/phimage) is licensed under [MIT License](https://github.com/phimage/CallbackURLKit/blob/master/LICENSE)
- [Alamofire](https://github.com/Alamofire/Alamofire) by [Alamofire](https://github.com/Alamofire) is licensed under [MIT License](https://github.com/Alamofire/Alamofire/blob/master/LICENSE)
- [PromiseKit](https://github.com/mxcl/PromiseKit) by [Max Howell](https://github.com/mxcl) is licensed under [MIT License](https://github.com/mxcl/PromiseKit/blob/master/LICENSE)
- [PMKAlamofire](https://github.com/PromiseKit/PMKAlamofire) by [Max Howell](https://github.com/mxcl) is licensed under [MIT License](https://github.com/PromiseKit/PMKAlamofire/blob/master/LICENSE)
- [Fuse](https://github.com/krisk/fuse-swift) by [Kiro Risk](https://github.com/krisk) is licensed under [MIT License](https://github.com/krisk/fuse-swift/blob/master/LICENSE)

**Amperfy license:** [GPLv3](https://github.com/BLeeEZ/Amperfy/blob/master/LICENSE)

**Special thanks:** [Dirk Hildebrand](https://apps.apple.com/us/developer/dirk-hildebrand/id654444924)
