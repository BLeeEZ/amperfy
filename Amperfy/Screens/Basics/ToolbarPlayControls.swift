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

class ControlBarButton: UIBarButtonItem, MusicPlayable {
    var player: PlayerFacade?

    var inUIButton: UIButton? {
        self.customView as? UIButton
    }

    func updateImage(image: UIImage) {
        self.inUIButton?.setImage(image.styleForNavigationBar(), for: .normal)
    }

    fileprivate func createInUIButton(config: UIButton.Configuration, size: CGSize) -> UIButton? {
        let button = UIButton(configuration: config)
        button.imageView?.contentMode = .scaleAspectFit

        // influence the highlighted area
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: size.width).isActive = true
        button.heightAnchor.constraint(equalToConstant: size.height).isActive = true

        return button
    }

    init(player: PlayerFacade) {
        self.player = player
        super.init()

        var config = UIButton.Configuration.gray()
        config.macIdiomStyle = .borderless
        let button = createInUIButton(config: config, size: CGSize(width: 32, height: 22))
        button?.addTarget(self, action: #selector(self.clicked(_:)), for: .touchUpInside)

        self.customView = button
        self.player?.addNotifier(notifier: self)

        // Recreate the system button background highlight
        self.installHoverGestureRecognizer()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func installHoverGestureRecognizer() {
        let recognizer = UIHoverGestureRecognizer(target: self, action: #selector(self.hoverButton(_:)))
        self.inUIButton?.addGestureRecognizer(recognizer)
    }

    @objc private func hoverButton(_ recognizer: UIHoverGestureRecognizer) {
        switch recognizer.state {
        case .began:
            self.inUIButton?.backgroundColor = .systemGray2.withAlphaComponent(0.2)
            self.inUIButton?.layer.cornerRadius = 5
        case .ended, .cancelled, .failed:
            self.inUIButton?.backgroundColor = .clear
        default:
            break
        }
    }

    @objc func clicked(_ sender: UIButton) {

    }

    func didStartPlaying() {}
    func didPause() {}
    func didStopPlaying() {}
    func didStartPlayingFromBeginning() { }
    func didElapsedTimeChange() {}
    func didPlaylistChange() {}
    func didArtworkChange() {}
    func didShuffleChange() {}
    func didRepeatChange() {}
    func didPlaybackRateChange() {}
}


class PlayBarButton: ControlBarButton {

    override fileprivate func createInUIButton(config: UIButton.Configuration, size: CGSize) -> UIButton? {
        // We need an initial image, otherwise catalyst calculates the wrong button size
        var configuration = config
        configuration.image = .play.styleForNavigationBar()
        return super.createInUIButton(config: configuration, size: size)
    }

    override func clicked(_ sender: UIButton) {
        self.player?.togglePlayPause()
    }

    override func didStartPlaying() {
        self.updateImage(image: .pause)
    }

    override func didPause() {
        self.updateImage(image: .play)
    }

    override func didStopPlaying() {
        self.updateImage(image: .play)
    }
}

class NextBarButton: ControlBarButton {

    override fileprivate func createInUIButton(config: UIButton.Configuration, size: CGSize) -> UIButton? {
        var configuration = config
        configuration.image = .forwardFill.styleForNavigationBar(pointSize: 18)
        // Increase the highlighted area
        var newSize = size
        newSize.width = 38
        return super.createInUIButton(config: configuration, size: newSize)
    }

    override func clicked(_ sender: UIButton) {
        self.player?.playNext()
    }
}

class PreviousBarButton: ControlBarButton {
    
    override fileprivate func createInUIButton(config: UIButton.Configuration, size: CGSize) -> UIButton? {
        var configuration = config
        configuration.image = .backwardFill.styleForNavigationBar(pointSize: 18)
        var newSize = size
        newSize.width = 38
        return super.createInUIButton(config: configuration, size: newSize)
    }

    override func clicked(_ sender: UIButton) {
        self.player?.playPreviousOrReplay()
    }
}

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


fileprivate class NowPlayingInfoView: UIView {
    var player: PlayerFacade?

    lazy var artworkView: UIImageView = {
        let imageView: UIImageView = UIImageView()
        imageView.backgroundColor = .clear
        return imageView
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

        self.artworkView.translatesAutoresizingMaskIntoConstraints = false
        self.detailContainer.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(self.detailContainer)
        self.addSubview(self.artworkView)

        NSLayoutConstraint.activate([
            self.artworkView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 0),
            self.artworkView.heightAnchor.constraint(equalTo: self.heightAnchor),
            self.artworkView.widthAnchor.constraint(equalTo: self.heightAnchor),
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

    @objc func timeSliderChanged(_ slider: UISlider) {
        self.player?.seek(toSecond: Double(self.timeSlider.value))
    }
}

extension NowPlayingInfoView: MusicPlayable {
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


// Hack: built-in flexible space navigation bar item is not working, so we use this workaround
class FlexibleSpaceBarItem: UIBarButtonItem {
    init(minSpace: CGFloat = 0, maxSpace: CGFloat = 1000) {
        super.init()

        let clearView = UIView(frame: .zero)
        clearView.backgroundColor = .clear

        clearView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            clearView.widthAnchor.constraint(lessThanOrEqualToConstant: maxSpace),
            clearView.widthAnchor.constraint(greaterThanOrEqualToConstant: minSpace),
            // This allows us to still grab and move the window when clicking the empty space
            clearView.heightAnchor.constraint(equalToConstant: 0)
        ])

        self.customView = clearView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
