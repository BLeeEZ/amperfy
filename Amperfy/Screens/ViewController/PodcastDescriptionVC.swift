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
    
    @IBOutlet weak var descriptionTextView: UITextView!
    
    private var rootView: UIViewController?
    private var podcast: Podcast?
    private var podcastEpisode: PodcastEpisode?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.setBackgroundBlur(style: .prominent)
        
        if let presentationController = presentationController as? UISheetPresentationController {
            presentationController.detents = [
                .large()
            ]
            if traitCollection.userInterfaceIdiom == .phone {
                presentationController.detents.append(.medium())
            }
            presentationController.prefersGrabberVisible = true
        }
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
        if let podcast = podcast {
            descriptionTextView.text = podcast.depiction
        } else if let podcastEpisode = podcastEpisode {
            descriptionTextView.text = podcastEpisode.depiction
        }
    }
    
    @IBAction func pressedClose(_ sender: Any) {
        self.dismiss(animated: true)
    }

}
