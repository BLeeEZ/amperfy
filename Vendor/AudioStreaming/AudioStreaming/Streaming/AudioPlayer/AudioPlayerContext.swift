//
//  Created by Dimitrios Chatzieleftheriou on 16/06/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import Foundation

final class AudioPlayerContext {
  var stopReason: Atomic<AudioPlayerStopReason>

  var state: Atomic<AudioPlayerState>
  var stateChanged: ((_ oldState: AudioPlayerState, _ newState: AudioPlayerState) -> ())?

  var muted: Atomic<Bool>

  var internalState: AudioPlayer.InternalState {
    playerInternalState.value
  }

  let entriesLock: UnfairLock
  var audioReadingEntry: AudioEntry?
  var audioPlayingEntry: AudioEntry?

  /// This is the player's internal state to use
  /// - NOTE: Do not use directly instead use the `internalState` to set and get the property
  /// or the `setInternalState(to:when:)`method
  private var playerInternalState = Atomic<AudioPlayer.InternalState>(.initial)

  init() {
    self.stopReason = Atomic<AudioPlayerStopReason>(.none)
    self.state = Atomic<AudioPlayerState>(.ready)
    self.muted = Atomic<Bool>(false)
    self.entriesLock = UnfairLock()
  }

  /// Sets the internal state if given the `inState` will be evaluated before assignment occurs.
  /// This also convenvienlty sets the `stopReason` as well
  /// - parameter state: The new `PlayerInternalState`
  /// - parameter inState: If the `inState` expression is not nil, the internalState will be set if the evaluated expression is `true`
  /// - NOTE: This sets the underlying `__playerInternalState` variable
  func setInternalState(
    to state: AudioPlayer.InternalState,
    when inState: ((AudioPlayer.InternalState) -> Bool)? = nil
  ) {
    let newValues = playerStateAndStopReason(for: state)
    if let stopReason = newValues.stopReason {
      self.stopReason.write { $0 = stopReason }
    }
    guard state != internalState else { return }
    if let inState = inState, !inState(internalState) {
      return
    }
    playerInternalState.write { $0 = state }
    let previousPlayerState = self.state.value
    if newValues.state != previousPlayerState {
      self.state.write { $0 = newValues.state }
      stateChanged?(previousPlayerState, newValues.state)
    }
  }
}
