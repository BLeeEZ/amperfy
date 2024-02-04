//
//  PodcastDescriptionVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 01.02.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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

import Foundation
import UIKit
import AmperfyKit
import MarqueeLabel

class PodcastDescriptionVC: UIViewController {
    
    @IBOutlet weak var titleLabel: MarqueeLabel!
    @IBOutlet weak var artistContainerView: UIView!
    @IBOutlet weak var artistLabel: MarqueeLabel!
    @IBOutlet weak var showArtistButton: UIButton!
    @IBOutlet weak var infoLabel: MarqueeLabel!
    @IBOutlet weak var entityImageView: EntityImageView!
    @IBOutlet weak var playButton: BasicButton!
    @IBOutlet weak var descriptionTextView: UITextView!
    
    private var rootView: UIViewController?
    private var appDelegate: AppDelegate!
    private var podcast: Podcast?
    private var podcastEpisode: PodcastEpisode?
    
    private var entityContainer: PlayableContainable? {
        if let podcast = podcast {
            return podcast
        } else if let podcastEpisode = podcastEpisode {
            return podcastEpisode
        }
        return nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.view.setBackgroundBlur(style: .prominent)
        titleLabel.applyAmperfyStyle()
        artistLabel.applyAmperfyStyle()
        infoLabel.applyAmperfyStyle()
        playButton.imageView?.contentMode = .scaleAspectFit
    }
    
    override func viewWillAppear(_ animated: Bool) {
        refresh()
    }

    func display(podcast: Podcast, on rootView: UIViewController) {
        self.rootView = rootView
        self.podcast = podcast
        self.podcastEpisode = nil
    }
    func display(podcastEpisode: PodcastEpisode, on rootView: UIViewController) {
        self.rootView = rootView
        self.podcast = nil
        self.podcastEpisode = podcastEpisode
    }

    func refresh() {
        guard let entityContainer = entityContainer else { return }
        entityImageView.display(container: entityContainer)
        titleLabel.text = entityContainer.name
        artistLabel.text = entityContainer.subtitle
        artistContainerView.isHidden = entityContainer.subtitle == nil
        
        infoLabel.text = entityContainer.info(for: appDelegate.backendApi.selectedApi, details: DetailInfoType(type: .long, settings: appDelegate.storage.settings))
        
        if let _ = self.rootView as? PopupPlayerVC {
            playButton.isHidden = true
        } else {
            playButton.isHidden = false
        }
        
        if let podcast = podcast {
            descriptionTextView.text = podcast.depiction
        } else if let podcastEpisode = podcastEpisode {
            descriptionTextView.text = podcastEpisode.depiction
        }
    }

    @IBAction func pressedShowArtist(_ sender: Any) {
        dismiss(animated: true) {
            let playable = self.entityContainer as? AbstractPlayable
            if let podcast = playable?.asPodcastEpisode?.podcast {
                self.appDelegate.userStatistics.usedAction(.alertGoToPodcast)
                let podcastDetailVC = PodcastDetailVC.instantiateFromAppStoryboard()
                podcastDetailVC.podcast = podcast
                podcastDetailVC.episodeToScrollTo = playable?.asPodcastEpisode
                if let popupPlayer = self.rootView as? PopupPlayerVC {
                    popupPlayer.closePopupPlayerAndDisplayInLibraryTab(vc: podcastDetailVC)
                } else if let navController = self.rootView?.navigationController {
                    navController.pushViewController(podcastDetailVC, animated: true)
                }
            }
        }
    }
    
    @IBAction func pressedPlayButton(_ sender: Any) {
        guard let entityContainer = entityContainer else { return }
        self.appDelegate.player.play(context: PlayContext(containable: entityContainer))
    }
    
    @IBAction func pressedCancel(_ sender: Any) {
        self.dismiss(animated: true)
    }

}
