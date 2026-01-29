//
//  ParametricEQViewModel.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 19.07.25.
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
import Combine
import SwiftUI

// MARK: - ParametricEQViewModel

@MainActor
final class ParametricEQViewModel: ObservableObject {
  // MARK: - Published State

  @Published
  var bands: [ParametricBand] = []
  @Published
  var selectedBandId: UUID?
  @Published
  var globalBypass: Bool = false
  @Published
  var name: String = ""

  // A-B Comparison State
  @Published
  var isABCompareActive: Bool = false
  @Published
  private(set) var currentABState: ABState = .a

  // MARK: - Private State

  private var undoStack: [EQSnapshot] = []
  private var redoStack: [EQSnapshot] = []
  private let maxUndoLevels = 50

  private var stateA: EQSnapshot?
  private var stateB: EQSnapshot?

  /// Tracks whether a drag operation is in progress (to avoid saving undo state on every frame)
  private var isDragging: Bool = false

  // MARK: - Types

  enum ABState {
    case a, b
  }

  struct EQSnapshot: Equatable {
    let bands: [ParametricBand]
    let globalBypass: Bool
  }

  // MARK: - Computed Properties

  var selectedBand: ParametricBand? {
    guard let id = selectedBandId else { return nil }
    return bands.first { $0.id == id }
  }

  var canUndo: Bool { !undoStack.isEmpty }
  var canRedo: Bool { !redoStack.isEmpty }
  var canAddBand: Bool { bands.count < ParametricEqualizerSetting.maxBands }

  var currentSnapshot: EQSnapshot {
    EQSnapshot(bands: bands, globalBypass: globalBypass)
  }

  // MARK: - Initialization

  func load(from setting: ParametricEqualizerSetting) {
    bands = setting.bands
    globalBypass = setting.globalBypass
    name = setting.name
    selectedBandId = bands.first?.id

    // Clear history when loading new preset
    undoStack.removeAll()
    redoStack.removeAll()
    isABCompareActive = false
    stateA = nil
    stateB = nil
  }

  func toSetting(withId id: UUID = UUID()) -> ParametricEqualizerSetting {
    ParametricEqualizerSetting(
      id: id,
      name: name,
      bands: bands,
      globalBypass: globalBypass
    )
  }

  // MARK: - Band Management

  func addBand() {
    guard canAddBand else { return }
    saveUndoState()

    // Find a frequency that's not too close to existing bands
    let existingFreqs = Set(bands.map { Int($0.frequency) })
    let defaultFreqs = ParametricBand.defaultFrequencies
    var newFreq: Float = 1000

    for freq in defaultFreqs where !existingFreqs.contains(Int(freq)) {
      newFreq = freq
      break
    }

    let newBand = ParametricBand(
      frequency: newFreq,
      gain: 0,
      q: 1.0,
      filterType: .bell,
      bypass: false
    )
    bands.append(newBand)
    selectedBandId = newBand.id
  }

  func removeBand(id: UUID) {
    guard let index = bands.firstIndex(where: { $0.id == id }) else { return }
    saveUndoState()

    bands.remove(at: index)

    // Select adjacent band or nil
    if selectedBandId == id {
      if !bands.isEmpty {
        let newIndex = min(index, bands.count - 1)
        selectedBandId = bands[newIndex].id
      } else {
        selectedBandId = nil
      }
    }
  }

  func updateBand(
    id: UUID,
    frequency: Float? = nil,
    gain: Float? = nil,
    q: Float? = nil,
    filterType: ParametricBandFilterType? = nil,
    bypass: Bool? = nil
  ) {
    guard let index = bands.firstIndex(where: { $0.id == id }) else { return }
    // Only save undo state if not in a drag operation (drag saves state at start)
    if !isDragging {
      saveUndoState()
    }

    var band = bands[index]
    if let f = frequency { band.frequency = f.clamped(to: ParametricBand.frequencyRange) }
    if let g = gain { band.gain = g.clamped(to: ParametricBand.gainRange) }
    if let qVal = q { band.q = qVal.clamped(to: ParametricBand.qRange) }
    if let ft = filterType { band.filterType = ft }
    if let b = bypass { band.bypass = b }

    bands[index] = band
  }

  func setGlobalBypass(_ bypass: Bool) {
    saveUndoState()
    globalBypass = bypass
  }

  func selectBand(id: UUID?) {
    selectedBandId = id
  }

  // MARK: - Drag State Management

  /// Call at the start of a drag operation to save undo state once
  func beginDrag() {
    guard !isDragging else { return }
    isDragging = true
    saveUndoState()
  }

  /// Call at the end of a drag operation
  func endDrag() {
    isDragging = false
  }

  // MARK: - Undo/Redo

  private func saveUndoState() {
    let snapshot = currentSnapshot

    // Don't save if nothing changed
    if undoStack.last == snapshot { return }

    undoStack.append(snapshot)
    if undoStack.count > maxUndoLevels {
      undoStack.removeFirst()
    }
    redoStack.removeAll()
  }

  func undo() {
    guard let previousState = undoStack.popLast() else { return }
    redoStack.append(currentSnapshot)
    applySnapshot(previousState)
  }

  func redo() {
    guard let nextState = redoStack.popLast() else { return }
    undoStack.append(currentSnapshot)
    applySnapshot(nextState)
  }

  private func applySnapshot(_ snapshot: EQSnapshot) {
    bands = snapshot.bands
    globalBypass = snapshot.globalBypass

    // Maintain selection if possible
    if let selectedId = selectedBandId,
       !bands.contains(where: { $0.id == selectedId }) {
      selectedBandId = bands.first?.id
    }
  }

  // MARK: - A-B Comparison

  func startABCompare() {
    stateA = currentSnapshot
    stateB = currentSnapshot
    currentABState = .a
    isABCompareActive = true
  }

  func toggleAB() {
    guard isABCompareActive else { return }

    // Save current state to the active slot
    switch currentABState {
    case .a:
      stateA = currentSnapshot
      currentABState = .b
      if let stateB { applySnapshot(stateB) }
    case .b:
      stateB = currentSnapshot
      currentABState = .a
      if let stateA { applySnapshot(stateA) }
    }
  }

  func endABCompare(keepCurrent: Bool) {
    if keepCurrent {
      // Keep whatever is currently displayed
    } else {
      // Revert to state A
      if let stateA { applySnapshot(stateA) }
    }

    isABCompareActive = false
    stateA = nil
    stateB = nil
    currentABState = .a
  }

  // MARK: - Presets

  func createDefaultBands() {
    saveUndoState()

    bands = ParametricBand.defaultFrequencies.enumerated().map { index, freq in
      let filterType: ParametricBandFilterType
      if index == 0 {
        filterType = .lowShelf
      } else if index == ParametricBand.defaultFrequencies.count - 1 {
        filterType = .highShelf
      } else {
        filterType = .bell
      }

      return ParametricBand(
        frequency: freq,
        gain: 0,
        q: 1.0,
        filterType: filterType,
        bypass: false
      )
    }

    selectedBandId = bands.first?.id
  }

  func resetAllBands() {
    saveUndoState()
    for i in bands.indices {
      bands[i].gain = 0
      bands[i].bypass = false
    }
    globalBypass = false
  }
}
