# ![Logo](https://github.com/BLeeEZ/amperfy/blob/master/Amperfy/Assets.xcassets/AppIcon.appiconset/Icon-40.png) Amperfy

<a href="https://apps.apple.com/app/amperfy-music/id1530145038#?platform=iphone"><img src=".github/AppStore/Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917.svg" height="45" /></a>

## Basics

Amperfy is an iOS app written in Swift to interact with an [Ampache](http://ampache.github.io) or [Subsonic](http://www.subsonic.org) server.

<img src=".github/Screenshots/Player.jpg" width="250" alt="Screenshot of the Amperfy player" /> &nbsp;
<img src=".github/Screenshots/ArtistDetail.png" width="250" alt="Screenshot of the Amperfy artist detail view" /> &nbsp;
<img src=".github/Screenshots/Library.png" width="250" alt="Screenshot of the Amperfy library view" />

## Features

- Offline support
- Syncing the database after first login
- Update library via search API
- Player interaction from lock screen
- Remote controlable
- Dark mode support

## Requirements

* Xcode 12, swift 5
* [Carthage](https://github.com/Carthage/Carthage)

## Getting Started

1. Check out the latest version of the project:
  ```
  git clone https://github.com/BLeeEZ/amperfy.git
  ```

2. In the Amperfy directory, fetch and build the projects dependencies via Carthage:
  ```
  cd amperfy
  ./update-carthage.sh
  ```

3. Open the `Amperfy.xcodeproj` file.

4. Build and run the "Amperfy" scheme

  >Real device testing: Amperfy has Apple CarPlay support. To test it on a real device a developer certificate with granted access to `com.apple.developer.playable-content` is requiered. To test Amperfy without Apple CarPlay clear the entitlement signing entry under Amperfy -> Targets: Amperfy -> Build Settings -> Signing -> `Code Signing Entitlements` (clear `Amperfy/Entitlements.plist`)

## Beta test releases

For more information, and to participate in the public beta releases, please visit [Amperfy Beta](https://github.com/BLeeEZ/amperfy/issues/25).

## Attributions

- [LNPopupController](https://github.com/LeoNatan/LNPopupController) by [LeoNatan](https://github.com/LeoNatan) is licensed under [MIT License](https://github.com/LeoNatan/LNPopupController/blob/master/LICENSE)
- [MarqueeLabel](https://github.com/cbpowell/MarqueeLabel) by [Charles Powell](https://github.com/cbpowell) is licensed under [MIT License](https://github.com/cbpowell/MarqueeLabel/blob/master/LICENSE)
- [NotificationBanner](https://github.com/Daltron/NotificationBanner) by [Dalton Hinterscher](https://github.com/Daltron) is licensed under [MIT License](https://github.com/Daltron/NotificationBanner/blob/master/LICENSE)
- [ID3TagEditor](https://github.com/chicio/ID3TagEditor) by [Fabrizio Duroni](https://github.com/chicio) is licensed under [MIT License](https://github.com/chicio/ID3TagEditor/blob/master/LICENSE.md)
- [CoreDataMigrationRevised-Example](https://github.com/wibosco/CoreDataMigrationRevised-Example) by [William Boles](https://github.com/wibosco) is licensed under [MIT License](https://github.com/wibosco/CoreDataMigrationRevised-Example/blob/master/LICENSE)
- [VYPlayIndicator](https://github.com/obrhoff/VYPlayIndicator) by [Dennis Oberhoff](https://github.com/obrhoff) is licensed under [MIT License](https://github.com/obrhoff/VYPlayIndicator/blob/master/LICENSE)
- [Font Awesome](https://fontawesome.com/) by [Font Awesome](https://fontawesome.com/) is licensed under [Font Awesome Free License](https://github.com/FortAwesome/Font-Awesome/blob/master/LICENSE.txt)
- [iOS 11 Glyphs](https://icons8.com/ios) by [Icons8](https://icons8.com) is licensed under [Good Boy License](https://icons8.com/good-boy-license/)

**Amperfy license:** [GPLv3](https://github.com/BLeeEZ/Amperfy/blob/master/LICENSE)
