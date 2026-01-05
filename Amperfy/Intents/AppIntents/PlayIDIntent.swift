//
//  PlayIDIntent.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 24.12.25.
//  Copyright (c) 2025 Maximilian Bauer. All rights reserved.
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
import AppIntents
import Foundation
import SwiftUI

extension PlayableContainable {
  var spokenString: String {
    var spoken = "Now playing"
    spoken += " \(name)"
    if let subtitle, subtitle != "" {
      spoken += " by \(subtitle)"
    }
    spoken += "."
    return spoken
  }
}

// MARK: - PlayPlayableContainableResultView

struct PlayPlayableContainableResultView: View {
  static let maxImageSize: CGFloat = 150
  var playableContainable: PlayableContainable

  func getImage() -> Image? {
    let account = playableContainable.account
    let theme = appDelegate.storage.settings.accounts.getSetting(account?.info).read.themePreference
    let artworkCollection = playableContainable.getArtworkCollection(theme: theme)
    if let singleImage = artworkCollection.singleImageEntity,
       playableContainable.containerIdentifier.type != .playlist {
      let uiImage = LibraryEntityImage.getImageToDisplayImmediately(
        libraryEntity: singleImage,
        themePreference: theme,
        artworkDisplayPreference: appDelegate.storage.settings.accounts.getSetting(account?.info)
          .read.artworkDisplayPreference,
        useCache: false
      )
      return Image(uiImage: uiImage)
    }
    return nil
  }

  func getAltImage() -> Image {
    playableContainable.containerIdentifier.type?.image.asImage ?? AmperfyImage.musicalNotes.asImage
  }

  var body: some View {
    VStack {
      if let img = getImage() {
        img
          .resizable()
          .scaledToFit()
          .frame(maxWidth: Self.maxImageSize, maxHeight: Self.maxImageSize)
          .clipShape(RoundedRectangle(cornerRadius: 10))
      } else {
        getAltImage()
          .font(intentResultViewHeaderImageFont)
          .foregroundStyle(
            appDelegate.storage.settings.accounts.activeSetting.read.themePreference
              .asSwiftUIColor
          )
      }
      Spacer()
      Text("\(playableContainable.spokenString)")
    }
    .padding()
  }
}

// MARK: - PlayIDIntent

struct PlayIDIntent: AppIntent, CustomIntentMigratedAppIntent, PredictableIntent {
  static let intentClassName = "PlayIDIntent"
  static let title: LocalizedStringResource = "Play ID"
  static let description =
    IntentDescription("Plays the library element with the given ID and player options.")

  @Parameter(title: "ID")
  var id: String

  @Parameter(
    title: "Account",
    description: "Account used to search for ID. If not provided the active account will be used."
  )
  var account: AccountAppEntity?

  @Parameter(title: "Library Element Type", default: .song)
  var libraryElementType: PlayableContainerTypeAppEnum

  @Parameter(title: "Shuffle", default: .off)
  var shuffleOption: ShuffleTypeAppEnum

  @Parameter(title: "Repeat", default: .off)
  var repeatOption: RepeatTypeAppEnum

  static var parameterSummary: some ParameterSummary {
    Summary("Play ID \(\.$id) of type \(\.$libraryElementType)") {
      \.$account
      \.$shuffleOption
      \.$repeatOption
    }
  }

  static var predictionConfiguration: some IntentPredictionConfiguration {
    IntentPrediction(parameters: (
      \.$id,
      \.$libraryElementType,
      \.$account,
      \.$shuffleOption,
      \.$repeatOption
    )) { id, libraryElementType, account, shuffleOption, repeatOption in
      DisplayRepresentation(
        title: "Play ID \(id) of type \(libraryElementType)",
        subtitle: ""
      )
    }
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
    guard let accountCoreData = appDelegate.intentManager.getAccount(fromIntent: account)
    else { throw AmperfyAppIntentError.accountNotValid }
    let isShuffle = shuffleOption == .on
    let repeatUser = RepeatMode.fromIntent(type: repeatOption)

    let playableContainer = appDelegate.intentManager.getPlayableContainer(
      account: accountCoreData,
      id: id,
      libraryElementType: libraryElementType
    )
    guard let playableContainer else { throw AmperfyAppIntentError.notFound }
    let _ = await appDelegate.intentManager.play(
      container: playableContainer,
      shuffleOption: isShuffle,
      repeatOption: repeatUser
    )
    return .result(
      dialog: IntentDialog(stringLiteral: playableContainer.spokenString),
      view:
      PlayPlayableContainableResultView(playableContainable: playableContainer)
    )
  }
}

extension IntentDialog {
  fileprivate static var idParameterPrompt: Self {
    "Which ID do you want to play?"
  }

  fileprivate static func libraryElementTypeParameterDisambiguationIntro(
    count: Int,
    libraryElementType: PlayableContainerTypeAppEnum
  )
    -> Self {
    "There are \(count) options matching ‘\(libraryElementType)’."
  }

  fileprivate static func libraryElementTypeParameterConfirmation(
    libraryElementType: PlayableContainerTypeAppEnum
  )
    -> Self {
    "Just to confirm, you wanted ‘\(libraryElementType)’?"
  }

  fileprivate static func shuffleOptionParameterDisambiguationIntro(
    count: Int,
    shuffleOption: ShuffleTypeAppEnum
  )
    -> Self {
    "There are \(count) options matching ‘\(shuffleOption)’."
  }

  fileprivate static func shuffleOptionParameterConfirmation(shuffleOption: ShuffleTypeAppEnum)
    -> Self {
    "Just to confirm, you wanted ‘\(shuffleOption)’?"
  }

  fileprivate static func repeatOptionParameterDisambiguationIntro(
    count: Int,
    repeatOption: RepeatTypeAppEnum
  )
    -> Self {
    "There are \(count) options matching ‘\(repeatOption)’."
  }

  fileprivate static func repeatOptionParameterConfirmation(repeatOption: RepeatTypeAppEnum)
    -> Self {
    "Just to confirm, you wanted ‘\(repeatOption)’?"
  }
}
