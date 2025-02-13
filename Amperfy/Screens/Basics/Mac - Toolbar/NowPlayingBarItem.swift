//
//  NowPlayingBarItem.swift
//  Amperfy
//
//  Created by David Klopp on 20.08.24.
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

import AmperfyKit
import Foundation
import MarqueeLabel
import UIKit

#if targetEnvironment(macCatalyst)

  fileprivate class NowPlayingSlider: UISlider {
    static var sliderHeight: CGFloat = 5.0

    private var thumbTouchSize = CGSize(width: 50, height: 20)

    override init(frame: CGRect) {
      super.init(frame: frame)
      self.preferredBehavioralStyle = .pad
      refreshSliderDesign()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    fileprivate func refreshSliderDesign() {
      let tint = appDelegate.storage.settings.themePreference.asColor
      setUnicolorRectangularMinimumTrackImage(
        trackHeight: Self.sliderHeight,
        color: tint,
        for: .normal
      )
      setUnicolorRectangularMaximumTrackImage(
        trackHeight: Self.sliderHeight,
        color: .systemGray6,
        for: .normal
      )
      setUnicolorRectangularThumbImage(
        thumbSize: CGSize(width: 5, height: Self.sliderHeight * 2),
        color: .systemGray,
        for: .normal
      )
    }

    override func trackRect(forBounds bounds: CGRect) -> CGRect {
      let customBounds = CGRect(
        origin: bounds.origin,
        size: CGSize(width: bounds.size.width, height: 4.0)
      )
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
      let thumbSizeHeight = thumbRect(
        forBounds: bounds,
        trackRect: trackRect(forBounds: bounds),
        value: 0
      ).size.height
      let thumbPosition = thumbSizeHeight +
        (percentage * (bounds.size.width - (2 * thumbSizeHeight)))
      let touchLocation = touch.location(in: self)
      return touchLocation.x <= (thumbPosition + thumbTouchSize.width) && touchLocation
        .x >= (thumbPosition - thumbTouchSize.width)
    }
  }

  class NowPlayingInfoView: UIView {
    var player: PlayerFacade
    var rootViewController: UIViewController

    /// override this to allow snapshots: this is needed in macOS to show all tabs and create a new tab
    override func drawHierarchy(in rect: CGRect, afterScreenUpdates afterUpdates: Bool) -> Bool {
      true
    }

    fileprivate lazy var artworkView: UIImageView = {
      let imageView = UIImageView()
      imageView.backgroundColor = .clear
      return imageView
    }()

    fileprivate lazy var artworkOverlay: UIView = {
      let view = UIView()
      view.backgroundColor = .black.withAlphaComponent(0.4)
      view.isHidden = true

      let imageView = UIImageView()
      imageView.translatesAutoresizingMaskIntoConstraints = false
      imageView.contentMode = .scaleAspectFit
      imageView.tintColor = .white
      imageView.image = .miniPlayer.withRenderingMode(.alwaysTemplate)

      view.addSubview(imageView)
      NSLayoutConstraint.activate([
        imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        imageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
        imageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.8),
      ])

      return view
    }()

    fileprivate lazy var titleLabel: UILabel = {
      let label = MarqueeLabel(frame: .zero)
      label.applyAmperfyStyle()
      label.backgroundColor = .clear
      label.textAlignment = .center
      label.numberOfLines = 1
      label.textColor = .label
      return label
    }()

    var moreButtonWidthConstraint: NSLayoutConstraint?
    var moreButtonTrailingConstraint: NSLayoutConstraint?

    fileprivate lazy var moreButton: UIButton = {
      var config = UIButton.Configuration.borderless()
      config.image = .ellipsis
      config.background = .clear()
      let button = UIButton(configuration: config)
      button.preferredBehavioralStyle = .pad
      button.showsMenuAsPrimaryAction = true
      button.isHidden = true
      return button
    }()

    fileprivate lazy var subtitleLabel: UILabel = {
      let label = MarqueeLabel(frame: .zero)
      label.applyAmperfyStyle()
      label.backgroundColor = .clear
      label.textAlignment = .center
      label.numberOfLines = 1
      label.textColor = .secondaryLabel
      return label
    }()

    var elapsedTimeLabelWidthOnHover: CGFloat = 0.0
    var elapsedTimeLabelWidthConstraint: NSLayoutConstraint?
    var elapsedTimeLabelLeadingConstraint: NSLayoutConstraint?

    fileprivate lazy var elapsedTimeLabel: UILabel = {
      let label = UILabel()
      label.textColor = .tertiaryLabel
      label.textAlignment = .left
      label.numberOfLines = 1
      label.backgroundColor = .clear
      label.isHidden = true
      label.font = .systemFont(ofSize: 12.0)
      return label
    }()

    var remainingTimeLabelWidthOnHover: CGFloat = 0.0
    var remainingTimeLabelWidthConstraint: NSLayoutConstraint?
    var remainingTimeLabelTrailingConstraint: NSLayoutConstraint?

    fileprivate lazy var remainingTimeLabel: UILabel = {
      let label = UILabel()
      label.textColor = .tertiaryLabel
      label.textAlignment = .right
      label.numberOfLines = 1
      label.backgroundColor = .clear
      label.isHidden = true
      label.font = .systemFont(ofSize: 12.0)
      return label
    }()

    fileprivate lazy var liveLabel: UILabel = {
      let label = UILabel()
      label.textColor = .white
      label.textAlignment = .center
      label.numberOfLines = 1
      label.backgroundColor = .systemGray2
      label.isHidden = true
      label.font = .systemFont(ofSize: 10.0, weight: .bold)
      label.text = "LIVE"
      label.layer.cornerRadius = CornerRadius.verySmall.asCGFloat
      label.layer.masksToBounds = true
      return label
    }()

    fileprivate lazy var timeSlider: NowPlayingSlider = {
      let slider = NowPlayingSlider(frame: .zero)
      slider.addTarget(self, action: #selector(timeSliderChanged(_:)), for: .valueChanged)
      return slider
    }()

    private lazy var labelContainer: UIView = {
      self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
      self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
      self.moreButton.translatesAutoresizingMaskIntoConstraints = false
      self.elapsedTimeLabel.translatesAutoresizingMaskIntoConstraints = false
      self.remainingTimeLabel.translatesAutoresizingMaskIntoConstraints = false
      self.liveLabel.translatesAutoresizingMaskIntoConstraints = false

      let view = UIView()
      view.addSubview(self.titleLabel)
      view.addSubview(self.moreButton)
      view.addSubview(self.subtitleLabel)
      view.addSubview(self.elapsedTimeLabel)
      view.addSubview(self.remainingTimeLabel)
      view.addSubview(self.liveLabel)

      self.moreButtonWidthConstraint = self.moreButton.widthAnchor.constraint(equalToConstant: 0)
      self.moreButtonTrailingConstraint = self.moreButton.trailingAnchor.constraint(
        equalTo: view.trailingAnchor,
        constant: 0
      )

      self.elapsedTimeLabelWidthConstraint = self.elapsedTimeLabel.widthAnchor
        .constraint(equalToConstant: 0)
      self.elapsedTimeLabelLeadingConstraint = self.elapsedTimeLabel.leadingAnchor
        .constraint(equalTo: view.leadingAnchor)
      self.remainingTimeLabelWidthConstraint = self.remainingTimeLabel.widthAnchor
        .constraint(equalToConstant: 0)
      self.remainingTimeLabelTrailingConstraint = self.remainingTimeLabel.trailingAnchor
        .constraint(equalTo: view.trailingAnchor)

      NSLayoutConstraint.activate([
        self.moreButtonWidthConstraint!,
        self.moreButtonTrailingConstraint!,
        self.moreButton.centerYAnchor.constraint(equalTo: self.titleLabel.centerYAnchor),
        self.titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 5),
        self.titleLabel.heightAnchor.constraint(equalTo: self.subtitleLabel.heightAnchor),
        self.titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
        self.titleLabel.trailingAnchor.constraint(
          equalTo: self.moreButton.leadingAnchor,
          constant: -10
        ),
        self.subtitleLabel.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor),
        self.subtitleLabel.leadingAnchor.constraint(
          equalTo: self.elapsedTimeLabel.trailingAnchor,
          constant: 10
        ),
        self.subtitleLabel.trailingAnchor.constraint(
          equalTo: self.remainingTimeLabel.leadingAnchor,
          constant: -10
        ),
        self.elapsedTimeLabel.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor),
        self.elapsedTimeLabelWidthConstraint!,
        self.elapsedTimeLabelLeadingConstraint!,
        self.remainingTimeLabel.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor),
        self.remainingTimeLabelTrailingConstraint!,
        self.remainingTimeLabelWidthConstraint!,
        self.liveLabel.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor),
        self.liveLabel.widthAnchor.constraint(equalToConstant: 35),
        self.liveLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -5),
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
        self.timeSlider.heightAnchor.constraint(equalToConstant: NowPlayingSlider.sliderHeight),
      ])

      return container
    }()

    init(player: PlayerFacade, splitViewController: SplitVC) {
      self.player = player
      self.rootViewController = splitViewController
      super.init(frame: .zero)

      self.backgroundColor = UIColor(dynamicProvider: { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
          return .systemFill
        } else {
          return .systemBackground
        }
      })

      artworkOverlay.translatesAutoresizingMaskIntoConstraints = false
      artworkView.translatesAutoresizingMaskIntoConstraints = false
      detailContainer.translatesAutoresizingMaskIntoConstraints = false

      let detailsHoverGesture = UIHoverGestureRecognizer(
        target: self,
        action: #selector(detailsHovered(_:))
      )
      detailContainer.isUserInteractionEnabled = true
      detailContainer.addGestureRecognizer(detailsHoverGesture)

      addSubview(detailContainer)
      addSubview(artworkView)
      artworkView.addSubview(artworkOverlay)

      let miniPlayerHoverGesture = UIHoverGestureRecognizer(
        target: self,
        action: #selector(artworkHovered(_:))
      )
      let miniPlayerTapGesture = UITapGestureRecognizer(
        target: self,
        action: #selector(artworkClicked(_:))
      )

      artworkView.isUserInteractionEnabled = true
      artworkView.addGestureRecognizer(miniPlayerHoverGesture)
      artworkView.addGestureRecognizer(miniPlayerTapGesture)

      NSLayoutConstraint.activate([
        artworkView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
        artworkView.heightAnchor.constraint(equalTo: heightAnchor),
        artworkView.widthAnchor.constraint(equalTo: heightAnchor),
        artworkOverlay.topAnchor.constraint(equalTo: artworkView.topAnchor, constant: 0),
        artworkOverlay.bottomAnchor.constraint(equalTo: artworkView.bottomAnchor, constant: 0),
        artworkOverlay.leadingAnchor.constraint(equalTo: artworkView.leadingAnchor, constant: 0),
        artworkOverlay.trailingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: 0),
        detailContainer.topAnchor.constraint(equalTo: topAnchor),
        detailContainer.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor),
        detailContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
        detailContainer.heightAnchor.constraint(equalTo: heightAnchor, constant: 1),
      ])
      player.addNotifier(notifier: self)
      reload()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    var isUserHoveringOver = false

    @objc
    func detailsHovered(_ sender: UIHoverGestureRecognizer) {
      switch sender.state {
      case .began:
        isUserHoveringOver = true
        refreshTimeLabels(hovered: true)
        refreshMoreButton(hovered: true)
      case .cancelled, .ended, .failed:
        isUserHoveringOver = false
        refreshTimeLabels(hovered: false)
        refreshMoreButton(hovered: false)
      default:
        break
      }
    }

    @objc
    func artworkHovered(_ sender: UIHoverGestureRecognizer) {
      switch sender.state {
      case .began:
        artworkOverlay.isHidden = false
      case .cancelled, .ended, .failed:
        artworkOverlay.isHidden = true
      default:
        break
      }
    }

    @objc
    func artworkClicked(_ sender: UITapGestureRecognizer) {
      switch sender.state {
      case .ended:
        appDelegate.showMiniPlayer()
      default:
        break
      }
    }

    @objc
    func timeSliderChanged(_ slider: UISlider) {
      player.seek(toSecond: Double(timeSlider.value))
    }
  }

  extension NowPlayingInfoView: MusicPlayable, Refreshable {
    private func refreshTimeLabels(hovered: Bool = false) {
      let areTimeLablesVisible = hovered && !(player.currentlyPlaying?.isRadio ?? false)
      if areTimeLablesVisible {
        elapsedTimeLabelWidthConstraint?.constant = elapsedTimeLabelWidthOnHover
        remainingTimeLabelWidthConstraint?.constant = remainingTimeLabelWidthOnHover
        elapsedTimeLabelLeadingConstraint?.constant = 10
        remainingTimeLabelTrailingConstraint?.constant = -10
      } else {
        elapsedTimeLabelWidthConstraint?.constant = 0
        elapsedTimeLabelLeadingConstraint?.constant = 0
        remainingTimeLabelWidthConstraint?.constant = 0
        remainingTimeLabelTrailingConstraint?.constant = 0
      }

      elapsedTimeLabel.isHidden = !areTimeLablesVisible
      remainingTimeLabel.isHidden = !areTimeLablesVisible
    }

    private func refreshMoreButton(hovered: Bool = false) {
      moreButton.tintColor = appDelegate.storage.settings.themePreference.asColor

      let currentlyPlaying = player.currentlyPlaying
      let hasPlayable = currentlyPlaying != nil

      if hasPlayable, hovered {
        moreButton.isHidden = false
        moreButtonWidthConstraint?.constant = 10
        moreButtonTrailingConstraint?.constant = -10

        if let currentlyPlaying,
           let splitVC = rootViewController as? SplitVC,
           let navController = splitVC.slideOverHostingController
           .primaryViewController as? UINavigationController,
           let topVC = navController.topViewController {
          moreButton.menu = UIMenu.lazyMenu {
            EntityPreviewActionBuilder(container: currentlyPlaying, on: topVC).createMenu()
          }
        }
      } else {
        moreButton.isHidden = true
        moreButtonWidthConstraint?.constant = 0
        moreButtonTrailingConstraint?.constant = 0
        moreButton.menu = nil
      }
    }

    private func refreshTitle() {
      guard let currentPlaying = player.currentlyPlaying else {
        switch player.playerMode {
        case .music:
          titleLabel.text = "No music playing"
          subtitleLabel.text = ""
        case .podcast:
          titleLabel.text = "No podcast playing"
          subtitleLabel.text = ""
        }
        return
      }

      switch currentPlaying.derivedType {
      case .song:
        let song = currentPlaying.asSong
        let title = song?.title ?? ""
        let artist = song?.artist?.name ?? ""
        let album = song?.album?.name ?? ""
        let subtitle = switch (artist.isEmpty, album.isEmpty) {
        case (false, false): "\(artist) - \(album)"
        case (false, true): artist
        case (true, false): album
        case _: ""
        }
        titleLabel.text = title
        subtitleLabel.text = subtitle
        liveLabel.isHidden = true
      case .podcastEpisode:
        let podcast = currentPlaying.asPodcastEpisode
        let title = podcast?.title ?? ""
        let subtitle = podcast?.subtitle ?? ""
        titleLabel.text = title
        subtitleLabel.text = subtitle
        liveLabel.isHidden = true
      case .radio:
        let radio = currentPlaying.asRadio
        titleLabel.text = radio?.title ?? ""
        subtitleLabel.text = ""
        liveLabel.isHidden = false
      }
    }

    private var remainingTime: Int? {
      let duration = player.duration
      if player.currentlyPlaying != nil, duration.isNormal, !duration.isZero {
        return Int(player.elapsedTime - ceil(player.duration))
      }
      return nil
    }

    private func refreshElapsedTimeAndRemainingTime() {
      if let currentlyPlaying = player.currentlyPlaying {
        let supportTimeInteraction = !currentlyPlaying.isRadio
        timeSlider.isEnabled = supportTimeInteraction
        timeSlider.maximumValue = Float(player.duration)
        if !timeSlider.isTracking, supportTimeInteraction {
          timeSlider.value = Float(player.elapsedTime)
        }

        if supportTimeInteraction {
          if player.elapsedTime > 60 * 60 {
            elapsedTimeLabelWidthOnHover = 45.0
          } else if player.elapsedTime > 10 * 60 {
            elapsedTimeLabelWidthOnHover = 35.0
          } else {
            elapsedTimeLabelWidthOnHover = 30.0
          }

          let elapsedClockTime = ClockTime(timeInSeconds: Int(player.elapsedTime))
          elapsedTimeLabel.text = elapsedClockTime.asShortString()
          if let remainingTime = remainingTime {
            remainingTimeLabel.text = ClockTime(timeInSeconds: remainingTime).asShortString()
            if remainingTime < -60 * 60 {
              remainingTimeLabelWidthOnHover = 50.0
            } else if remainingTime < -10 * 60 {
              remainingTimeLabelWidthOnHover = 40.0
            } else {
              remainingTimeLabelWidthOnHover = 35.0
            }
          } else {
            remainingTimeLabel.text = "--:--"
            remainingTimeLabelWidthOnHover = 35.0
          }
        } else {
          timeSlider.minimumValue = 0.0
          timeSlider.maximumValue = 1.0
          timeSlider.value = 0.0
        }
      } else {
        elapsedTimeLabel.text = "--:--"
        elapsedTimeLabelWidthOnHover = 35.0
        remainingTimeLabel.text = "--:--"
        remainingTimeLabelWidthOnHover = 35.0
        timeSlider.isEnabled = false
        timeSlider.minimumValue = 0.0
        timeSlider.maximumValue = 1.0
        timeSlider.value = 0.0
      }
      refreshTimeLabels(hovered: isUserHoveringOver)
    }

    private func refreshArtwork() {
      var artwork: UIImage?
      if let playableInfo = player.currentlyPlaying {
        artwork = playableInfo.image(
          theme: appDelegate.storage.settings.themePreference,
          setting: appDelegate.storage.settings.artworkDisplayPreference
        )
      } else {
        switch player.playerMode {
        case .music:
          artwork = .getGeneratedArtwork(
            theme: appDelegate.storage.settings.themePreference,
            artworkType: .song
          )
        case .podcast:
          artwork = .getGeneratedArtwork(
            theme: appDelegate.storage.settings.themePreference,
            artworkType: .podcastEpisode
          )
        }
      }
      artworkView.image = artwork
    }

    private func fetchSongInfoAndReload() {
      guard appDelegate.storage.settings.isOnlineMode,
            let song = player.currentlyPlaying?.asSong
      else { return }

      Task { @MainActor in do {
        try await self.appDelegate.librarySyncer.sync(song: song)
        self.reload()
      } catch {
        self.appDelegate.eventLogger.report(topic: "Song Info", error: error)
      }}
    }

    func reload() {
      refreshTitle()
      refreshElapsedTimeAndRemainingTime()
      refreshArtwork()
      refreshMoreButton()
      timeSlider.refreshSliderDesign()
    }

    func didStartPlaying() {
      reload()
    }

    func didElapsedTimeChange() {
      refreshElapsedTimeAndRemainingTime()
    }

    func didArtworkChange() {
      refreshArtwork()
    }

    func didStartPlayingFromBeginning() {
      fetchSongInfoAndReload()
    }

    func didPause() {}
    func didStopPlaying() {
      refreshMoreButton()
    }

    func didPlaylistChange() {
      // Trigger the reload to correctly switch between podcast and music view
      reload()
    }

    func didShuffleChange() {}
    func didRepeatChange() {}
    func didPlaybackRateChange() {}
  }

  class NowPlayingBarItem: UIBarButtonItem, Refreshable {
    init(player: PlayerFacade, splitViewController: SplitVC) {
      super.init()

      self.title = "Now Playing"

      let height = toolbarSafeAreaTop - 8

      let nowPlayingView = NowPlayingInfoView(
        player: player,
        splitViewController: splitViewController
      )
      nowPlayingView.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        nowPlayingView.widthAnchor.constraint(equalToConstant: 300),
        nowPlayingView.heightAnchor.constraint(equalToConstant: height),
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

    func reload() {
      (customView as? NowPlayingInfoView)?.reload()
    }
  }

#endif
