# ![Logo](https://github.com/BLeeEZ/amperfy/blob/master/Amperfy/Assets.xcassets/AppIcon.appiconset/Icon-40.png) Amperfy

## Basics

Amperfy is an iOS app written in Swift to interact with an [Ampache](http://ampache.github.io) or [Subsonic](http://www.subsonic.org) server.

<img src=".github/Screenshots/Player.png" width="250" alt="Screenshot of the Amperfy player" /> &nbsp;
<img src=".github/Screenshots/Search.png" width="250" alt="Screenshot of the Amperfy search" /> &nbsp;
<img src=".github/Screenshots/Artist.png" width="250" alt="Screenshot of the Amperfy artist" />

## Features

- Offline support
- Syncing the database after first login
- Background sync to keep database up to date
- Player interaction from lock screen
- Remote controlable
- Artwork sync from database
- Playlist download and upload
- Dark mode support

## Requirements

* Xcode 11, swift 5
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

Attributions
----------------
[Ampache](https://github.com/ampache/ampache) by [Ampache](https://github.com/ampache) is licensed under [AGPLv3](https://www.gnu.org/licenses/agpl-3.0.en.html)

[LNPopupController](https://github.com/LeoNatan/LNPopupController) by [LeoNatan](https://github.com/LeoNatan) is licensed under [MIT License](https://github.com/LeoNatan/LNPopupController/blob/master/LICENSE)

[MarqueeLabel](https://github.com/cbpowell/MarqueeLabel) by [Charles Powell](https://github.com/cbpowell) is licensed under [MIT License](https://github.com/cbpowell/MarqueeLabel/blob/master/LICENSE)

[Font Awesome Icons](https://fontawesome.com/) by [Font Awesome](https://fontawesome.com/) is licensed under [CC BY 4.0 License](https://creativecommons.org/licenses/by/4.0/)

[Font Awesome Fonts](https://fontawesome.com/) by [Font Awesome](https://fontawesome.com/) is licensed under [SIL OFL 1.1 License](https://scripts.sil.org/OFL)

[iOS 11 Glyphs](https://icons8.com/ios) by [Icons8](https://icons8.com) is licensed under [Good Boy License](https://icons8.com/good-boy-license/)

**Amperfy license:** [GPLv3](https://github.com/BLeeEZ/Amperfy/blob/master/LICENSE)
