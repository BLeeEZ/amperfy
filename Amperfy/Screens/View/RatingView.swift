//
//  RatingView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 18.01.22.
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

import UIKit
import AmperfyKit
import PromiseKit

class RatingView: UIView {
    
    @IBOutlet weak var clearRatingButton: UIButton!
    @IBOutlet weak var starOne: UIButton!
    @IBOutlet weak var starTwo: UIButton!
    @IBOutlet weak var starThree: UIButton!
    @IBOutlet weak var starFour: UIButton!
    @IBOutlet weak var starFive: UIButton!
    @IBOutlet weak var favorite: UIButton!
    
    static let frameHeight: CGFloat = 35.0

    private var libraryEntity: AbstractLibraryEntity?
    
    var activeStarColor: UIColor = .gold
    var inactiveStarColor: UIColor = .secondaryLabelColor
    var activeFavoriteColor: UIColor = .systemRed
    
    lazy var stars: [UIButton] = {
        var stars = [UIButton]()
        stars.append(starOne)
        stars.append(starTwo)
        stars.append(starThree)
        stars.append(starFour)
        stars.append(starFive)
        return stars
    }()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func display(entity: AbstractLibraryEntity?) {
        libraryEntity = entity
        refresh()
    }
    
    private var ratingSong: Song? {
        if let entity = libraryEntity,
           let playable = entity as? AbstractPlayable,
           let song = playable.asSong {
            return song
        } else {
            return nil
        }
    }
    
    private var ratingAlbum: Album? {
        if let entity = libraryEntity,
           let album = entity as? Album {
            return album
        } else {
            return nil
        }
    }

    private var ratingArtist: Artist? {
        if let entity = libraryEntity,
           let artist = entity as? Artist {
            return artist
        } else {
            return nil
        }
    }
    
    private func refresh() {
        UIView.performWithoutAnimation {
            let rating = ratingSong?.rating ?? ratingAlbum?.rating ?? ratingArtist?.rating ?? 0
            let isFavorite = ratingSong?.isFavorite ?? ratingAlbum?.isFavorite ?? ratingArtist?.isFavorite ?? false
            for (index, button) in stars.enumerated() {
                if index < rating {
                    button.setImage(UIImage.starFill, for: .normal)
                } else {
                    button.setImage(UIImage.starEmpty, for: .normal)
                }
                button.isEnabled = self.appDelegate.storage.settings.isOnlineMode
                button.setTitleColor(self.appDelegate.storage.settings.isOnlineMode ? activeStarColor : inactiveStarColor, for: .normal)
                button.tintColor = self.appDelegate.storage.settings.isOnlineMode ? activeStarColor : inactiveStarColor
                button.layoutIfNeeded()
            }
            clearRatingButton.isEnabled = self.appDelegate.storage.settings.isOnlineMode
            
            let favoriteIcon = isFavorite ? UIImage.heartFill : UIImage.heartEmpty
            favorite.setImage(favoriteIcon, for: .normal)
            favorite.isEnabled = self.appDelegate.storage.settings.isOnlineMode
            favorite.setTitleColor(self.appDelegate.storage.settings.isOnlineMode ? activeFavoriteColor : inactiveStarColor, for: .normal)
            favorite.tintColor = self.appDelegate.storage.settings.isOnlineMode ? activeFavoriteColor : inactiveStarColor
            favorite.layoutIfNeeded()
        }
    }
    
    private func setRating(rating: Int) {
        guard self.appDelegate.storage.settings.isOnlineMode else { return }
        if let song = self.ratingSong {
            song.rating = rating
            self.appDelegate.storage.main.saveContext()
            firstly {
                self.appDelegate.librarySyncer.setRating(song: song, rating: rating)
            }.done {
                self.refresh()
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Song Rating Sync", error: error)
            }
        } else if let album = self.ratingAlbum {
            album.rating = rating
            self.appDelegate.storage.main.saveContext()
            firstly {
                self.appDelegate.librarySyncer.setRating(album: album, rating: rating)
            }.done {
                self.refresh()
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Album Rating Sync", error: error)
            }
        } else if let artist = self.ratingArtist {
            artist.rating = rating
            self.appDelegate.storage.main.saveContext()
            firstly {
                self.appDelegate.librarySyncer.setRating(artist: artist, rating: rating)
            }.done {
                self.refresh()
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Artist Rating Sync", error: error)
            }
        }
    }
    
    func toggleFavorite() {
        guard self.appDelegate.storage.settings.isOnlineMode,
              let containable: PlayableContainable = self.ratingSong ?? self.ratingAlbum ?? self.ratingArtist else {
            return
        }
        firstly {
            containable.remoteToggleFavorite(syncer: self.appDelegate.librarySyncer)
        }.catch { error in
            self.appDelegate.eventLogger.report(topic: "Toggle Favorite", error: error)
        }.finally {
            self.refresh()
        }
    }

    @IBAction func clearRatingPressed(_ sender: Any) {
        setRating(rating: 0)
    }
    
    @IBAction func starOnePressed(_ sender: Any) {
        setRating(rating: 1)
    }
    
    @IBAction func starTwoPressed(_ sender: Any) {
        setRating(rating: 2)
    }

    @IBAction func starThreePressed(_ sender: Any) {
        setRating(rating: 3)
    }

    @IBAction func starFourPressed(_ sender: Any) {
        setRating(rating: 4)
    }

    @IBAction func starFivePressed(_ sender: Any) {
        setRating(rating: 5)
    }
    
    @IBAction func favoritePressed(_ sender: Any) {
        toggleFavorite()
    }
    
}
