# ![Logo](https://github.com/BLeeEZ/amperfy/blob/master/Amperfy/Assets.xcassets/AppIcon.appiconset/Icon-40.png) Amperfy

## Basics

Amperfy is an iOs app written in Swift to interact with an [ampache](http://ampache.github.io) instance.

## Features

- Offline support
- Syncing the database after first login
- Background sync to keep database up to date
- Player interaction from lock screen
- Remote controlable
- Artwork sync from database
- Playlist download and upload

## Requirements

* XCode 10, swift 4.2

## Getting Started

1. Check out the latest version of the project:
  ```
  git clone https://github.com/bleeez/amperfy.git
  ```

2. In the Amperfy directory, check out the project's dependencies:
  ```
  cd Amperfy
  git submodule update --init --recursive
  ```

3. Open the `Amperfy.xcodeproj` file.

4. Build and run the "Amperfy" scheme

Acknowledgements
----------------
[LNPopupController](https://github.com/LeoNatan/LNPopupController) by LeoNatan

[Font Awesome](https://fontawesome.com/)

**License:** [GPLv3](https://github.com/BLeeEZ/Amperfy/blob/master/LICENSE)
