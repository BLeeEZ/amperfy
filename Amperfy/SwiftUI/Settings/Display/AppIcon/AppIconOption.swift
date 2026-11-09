//
//  AppIconOption.swift
//  Amperfy
//
//  Created by David Klopp on 09.11.26.
//  Copyright © 2026 Maximilian Bauer. All rights reserved.
//
import Foundation

struct AppIconOption: Identifiable {
  let title: String
  let iconName: String?
  let previewName: String
  let category: AppIconCategory

  var id: String { iconName ?? "Default" }

  static let all: [AppIconOption] = [
    AppIconOption(
      title: "Default",
      iconName: nil,
      previewName: "AmperfyAppIconPreview",
      category: .amperfy
    ),
    AppIconOption(
      title: "Teal",
      iconName: "AmperfyTeal",
      previewName: "AmperfyTealPreview",
      category: .amperfy
    ),
    AppIconOption(
      title: "Green",
      iconName: "AmperfyGreen",
      previewName: "AmperfyGreenPreview",
      category: .amperfy
    ),
    AppIconOption(
      title: "Yellow",
      iconName: "AmperfyYellow",
      previewName: "AmperfyYellowPreview",
      category: .amperfy
    ),
    AppIconOption(
      title: "Orange",
      iconName: "AmperfyOrange",
      previewName: "AmperfyOrangePreview",
      category: .amperfy
    ),
    AppIconOption(
      title: "Red",
      iconName: "AmperfyRed",
      previewName: "AmperfyRedPreview",
      category: .amperfy
    ),
    AppIconOption(
      title: "Pink",
      iconName: "AmperfyPink",
      previewName: "AmperfyPinkPreview",
      category: .amperfy
    ),
    AppIconOption(
      title: "Purple",
      iconName: "AmperfyPurple",
      previewName: "AmperfyPurplePreview",
      category: .amperfy
    ),
    AppIconOption(
      title: "Music Blue",
      iconName: "AmperfyMusicBlue",
      previewName: "AmperfyMusicBluePreview",
      category: .music
    ),
    AppIconOption(
      title: "Music Teal",
      iconName: "AmperfyMusicTeal",
      previewName: "AmperfyMusicTealPreview",
      category: .music
    ),
    AppIconOption(
      title: "Music Green",
      iconName: "AmperfyMusicGreen",
      previewName: "AmperfyMusicGreenPreview",
      category: .music
    ),
    AppIconOption(
      title: "Music Yellow",
      iconName: "AmperfyMusicYellow",
      previewName: "AmperfyMusicYellowPreview",
      category: .music
    ),
    AppIconOption(
      title: "Music Orange",
      iconName: "AmperfyMusicOrange",
      previewName: "AmperfyMusicOrangePreview",
      category: .music
    ),
    AppIconOption(
      title: "Music Red",
      iconName: "AmperfyMusicRed",
      previewName: "AmperfyMusicRedPreview",
      category: .music
    ),
    AppIconOption(
      title: "Music Pink",
      iconName: "AmperfyMusicPink",
      previewName: "AmperfyMusicPinkPreview",
      category: .music
    ),
    AppIconOption(
      title: "Music Purple",
      iconName: "AmperfyMusicPurple",
      previewName: "AmperfyMusicPurplePreview",
      category: .music
    ),
    AppIconOption(
      title: "Music Single",
      iconName: "AmperfyMusicSingle",
      previewName: "AmperfyMusicSinglePreview",
      category: .music
    ),
    AppIconOption(
      title: "Music Single Gradient",
      iconName: "AmperfyMusicSingleGradient",
      previewName: "AmperfyMusicSingleGradientPreview",
      category: .music
    ),
  ]
}
