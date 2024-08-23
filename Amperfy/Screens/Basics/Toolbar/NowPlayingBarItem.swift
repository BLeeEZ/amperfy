//
//  PlayButton.swift
//  Amperfy
//
//  Created by David Klopp on 20.08.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import Foundation
import UIKit
import AmperfyKit
import MarqueeLabel

#if targetEnvironment(macCatalyst)

fileprivate class NowPlayingSlider: UISlider {
    static var sliderHeight: CGFloat = 5.0

    private var thumbTouchSize = CGSize(width: 50, height: 20)

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.preferredBehavioralStyle = .pad
        self.refreshSliderDesign()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func refreshSliderDesign() {
        let tint = appDelegate.storage.settings.themePreference.asColor
        self.setUnicolorRectangularMinimumTrackImage(trackHeight: NowPlayingSlider.sliderHeight, color: tint, for: .normal)
        self.setUnicolorRectangularMaximumTrackImage(trackHeight: NowPlayingSlider.sliderHeight, color: .systemGray6, for: .normal)
        self.setUnicolorRectangularThumbImage(thumbSize: CGSize(width: 5, height: NowPlayingSlider.sliderHeight*2), color: .systemGray, for: .normal)
    }


    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        self.refreshSliderDesign()
        super.traitCollectionDidChange(previousTraitCollection)
    }

    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        let customBounds = CGRect(origin: bounds.origin, size: CGSize(width: bounds.size.width, height: 4.0))
        super.trackRect(forBounds: customBounds)
        return customBounds
    }

    // MARK: - Increase touch area for thumb

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let increasedBounds = bounds.insetBy(dx: -thumbTouchSize.width, dy: -thumbTouchSize.height)
        let containsPoint = increasedBounds.contains(point)
        return containsPoint
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let percentage = CGFloat((value - minimumValue) / (maximumValue - minimumValue))
        let thumbSizeHeight = thumbRect(forBounds: bounds, trackRect:trackRect(forBounds: bounds), value:0).size.height
        let thumbPosition = thumbSizeHeight + (percentage * (bounds.size.width - (2 * thumbSizeHeight)))
        let touchLocation = touch.location(in: self)
        return touchLocation.x <= (thumbPosition + thumbTouchSize.width) && touchLocation.x >= (thumbPosition - thumbTouchSize.width)
    }
}


class NowPlayingInfoView: UIView {
    var player: PlayerFacade?

    lazy var artworkView: UIImageView = {
        let imageView: UIImageView = UIImageView()
        imageView.backgroundColor = .clear
        return imageView
    }()

    lazy var artworkOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = .black.withAlphaComponent(0.4)
        view.isHidden = true

        let imageView: UIImageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        imageView.image = .miniPlayer.withRenderingMode(.alwaysTemplate)

        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            imageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.8)
        ])

        return view
    }()

    lazy var titleLabel: UILabel = {
        let label = MarqueeLabel(frame: .zero)
        label.applyAmperfyStyle()
        label.backgroundColor = .clear
        label.textAlignment = .center
        label.numberOfLines = 1
        label.textColor = .label
        return label
    }()

    lazy var subtitleLabel: UILabel = {
        let label = MarqueeLabel(frame: .zero)
        label.applyAmperfyStyle()
        label.backgroundColor = .clear
        label.textAlignment = .center
        label.numberOfLines = 1
        label.textColor = .secondaryLabel
        return label
    }()

    lazy var timeSlider: UISlider = {
        let slider = NowPlayingSlider(frame: .zero)
        slider.addTarget(self, action: #selector(timeSliderChanged(_:)), for: .valueChanged)
        return slider
    }()

    private lazy var labelContainer: UIView = {
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let view = UIView()
        view.addSubview(self.titleLabel)
        view.addSubview(self.subtitleLabel)

        NSLayoutConstraint.activate([
            self.titleLabel.heightAnchor.constraint(equalTo: self.subtitleLabel.heightAnchor),
            self.subtitleLabel.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor),
            self.titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            self.titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            self.subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            self.subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
        ])

        return view
    }()

    private lazy var detailContainer: UIStackView = {
        self.labelContainer.translatesAutoresizingMaskIntoConstraints = false
        self.timeSlider.translatesAutoresizingMaskIntoConstraints = false

        let container = UIStackView(arrangedSubviews: [self.labelContainer, self.timeSlider])
        container.spacing = 0
        container.axis = .vertical
        container.distribution = .fill
        container.alignment = .fill

        NSLayoutConstraint.activate([
            self.timeSlider.heightAnchor.constraint(equalToConstant: NowPlayingSlider.sliderHeight)
        ])

        return container
    }()

    init(player: PlayerFacade) {
        self.player = player
        super.init(frame: .zero)

        self.backgroundColor = UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return .systemFill
            } else {
                return .systemBackground
            }
        })

        self.artworkOverlay.translatesAutoresizingMaskIntoConstraints = false
        self.artworkView.translatesAutoresizingMaskIntoConstraints = false
        self.detailContainer.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(self.detailContainer)
        self.addSubview(self.artworkView)
        self.artworkView.addSubview(self.artworkOverlay)

        let miniPlayerHoverGesture = UIHoverGestureRecognizer(target: self, action: #selector(self.artworkHovered(_:)))
        let miniPlayerTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.artworkClicked(_:)))

        self.artworkView.isUserInteractionEnabled = true
        self.artworkView.addGestureRecognizer(miniPlayerHoverGesture)
        self.artworkView.addGestureRecognizer(miniPlayerTapGesture)

        NSLayoutConstraint.activate([
            self.artworkView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 0),
            self.artworkView.heightAnchor.constraint(equalTo: self.heightAnchor),
            self.artworkView.widthAnchor.constraint(equalTo: self.heightAnchor),
            self.artworkOverlay.topAnchor.constraint(equalTo: self.artworkView.topAnchor, constant: 0),
            self.artworkOverlay.bottomAnchor.constraint(equalTo: self.artworkView.bottomAnchor, constant: 0),
            self.artworkOverlay.leadingAnchor.constraint(equalTo: self.artworkView.leadingAnchor, constant: 0),
            self.artworkOverlay.trailingAnchor.constraint(equalTo: self.artworkView.trailingAnchor, constant: 0),
            self.detailContainer.topAnchor.constraint(equalTo: self.topAnchor),
            self.detailContainer.leadingAnchor.constraint(equalTo: self.artworkView.trailingAnchor),
            self.detailContainer.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.detailContainer.heightAnchor.constraint(equalTo: self.heightAnchor, constant: 1)
        ])
        player.addNotifier(notifier: self)
        self.reload()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func artworkHovered(_ sender: UIHoverGestureRecognizer) {
        switch sender.state {
        case .began:
            self.artworkOverlay.isHidden = false
        case .ended, .cancelled, .failed:
            self.artworkOverlay.isHidden = true
        default:
            break
        }
    }

    @objc func artworkClicked(_ sender: UITapGestureRecognizer) {
        switch sender.state {
        case .ended:
            print("Show mini player....")
            break
        default:
            break
        }
    }

    @objc func timeSliderChanged(_ slider: UISlider) {
        self.player?.seek(toSecond: Double(self.timeSlider.value))
    }
}

extension NowPlayingInfoView: MusicPlayable, Refreshable {
    private func refreshTitle() {
        let song = player?.currentlyPlaying?.asSong
        let title = song?.title
        let artist = song?.artist?.name ?? ""
        let album = song?.album?.name ?? ""
        let artistAlbum = "\(artist) - \(album)"
        self.titleLabel.text = title
        self.subtitleLabel.text = artistAlbum
    }

    private func refreshElapsedTime() {
        guard let player = self.player else { return }
        if player.currentlyPlaying != nil {
            self.timeSlider.minimumValue = 0.0
            self.timeSlider.maximumValue = Float(player.duration)
            if !self.timeSlider.isTracking {
                self.timeSlider.value = Float(player.elapsedTime)
            }
        } else {
            self.timeSlider.minimumValue = 0.0
            self.timeSlider.maximumValue = 1.0
            self.timeSlider.value = 0.0
        }
    }

    private func refreshArtwork() {
        var artwork: UIImage?
        if let playableInfo = player?.currentlyPlaying {
            artwork = playableInfo.image(theme: appDelegate.storage.settings.themePreference, setting: appDelegate.storage.settings.artworkDisplayPreference)
        } else {
            switch player?.playerMode {
            case .music:
                artwork = .getGeneratedArtwork(theme: appDelegate.storage.settings.themePreference, artworkType: .song)
            case .podcast:
                artwork = .getGeneratedArtwork(theme: appDelegate.storage.settings.themePreference, artworkType: .podcastEpisode)
            case .none:
                break
            }
        }
        self.artworkView.image = artwork
    }

    func reload() {
        self.refreshTitle()
        self.refreshElapsedTime()
        self.refreshArtwork()
    }

    func didStartPlaying() {
        self.reload()
    }

    func didElapsedTimeChange() {
        self.refreshElapsedTime()
    }

    func didArtworkChange() {
        self.refreshArtwork()
    }

    func didStartPlayingFromBeginning() {}
    func didPause() {}
    func didStopPlaying() {}
    func didPlaylistChange() {}
    func didShuffleChange() {}
    func didRepeatChange() {}
    func didPlaybackRateChange() {}
}

class NowPlayingBarItem: UIBarButtonItem {
    init(player: PlayerFacade) {
        super.init()

        self.title = "Now Playing"

        let height = toolbarSafeAreaTop - 8

        let nowPlayingView = NowPlayingInfoView(player: player)
        nowPlayingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            nowPlayingView.widthAnchor.constraint(equalToConstant: 300),
            nowPlayingView.heightAnchor.constraint(equalToConstant: height)
        ])

        nowPlayingView.layer.masksToBounds = true
        nowPlayingView.layer.cornerRadius = 5.0
        nowPlayingView.layer.borderWidth = 1.0
        nowPlayingView.layer.borderColor = UIColor.separator.cgColor

        self.customView = nowPlayingView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#endif
