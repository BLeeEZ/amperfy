//
//  EqualizerSettingsView.swift
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
import SwiftUI

// MARK: - EqualizerSettingsView

struct EqualizerSettingsView: View {
  @EnvironmentObject
  private var settings: Settings

  @StateObject
  private var viewModel = ParametricEQViewModel()

  @State
  private var selectedPresetId: UUID?
  @State
  private var isShowingNewPresetDialog = false
  @State
  private var newPresetName = ""
  @State
  private var isShowingDeleteAlert = false
  @State
  private var presetToDelete: ParametricEqualizerSetting?
  @State
  private var isShowingRenameDialog = false
  @State
  private var renameText = ""

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        // Enable/Disable Toggle
        enableSection

        if settings.isEqualizerEnabled {
          // Preset selector
          presetSection

          // Parametric EQ Editor
          if selectedPresetId != nil {
            editorSection
          }
        }
      }
      .padding()
    }
    .navigationTitle("Equalizer")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      loadActivePreset()
    }
    .alert("New Preset", isPresented: $isShowingNewPresetDialog) {
      TextField("Preset Name", text: $newPresetName)
      Button("Cancel", role: .cancel) {
        newPresetName = ""
      }
      Button("Create") {
        createNewPreset()
      }
    } message: {
      Text("Enter a name for the new equalizer preset")
    }
    .alert("Delete Preset", isPresented: $isShowingDeleteAlert) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        if let preset = presetToDelete {
          deletePreset(preset)
        }
      }
    } message: {
      Text("Are you sure you want to delete this preset?")
    }
    .alert("Rename Preset", isPresented: $isShowingRenameDialog) {
      TextField("Preset Name", text: $renameText)
      Button("Cancel", role: .cancel) {
        renameText = ""
      }
      Button("Rename") {
        renameCurrentPreset()
      }
    } message: {
      Text("Enter a new name for the preset")
    }
  }

  // MARK: - Enable Section

  private var enableSection: some View {
    SettingsSection(content: {
      SettingsCheckBoxRow(
        title: "Enable Equalizer",
        isOn: Binding(
          get: { settings.isEqualizerEnabled },
          set: { isEnabled in
            settings.isEqualizerEnabled = isEnabled
          }
        )
      )
    })
  }

  // MARK: - Preset Section

  private var presetSection: some View {
    SettingsSection(content: {
      // Active Preset Picker
      SettingsRow(title: "Active Preset") {
        Menu(settings.activeParametricEqualizerSetting.description) {
          Button(ParametricEqualizerSetting.off.description) {
            settings.activeParametricEqualizerSetting = .off
            selectedPresetId = nil
            viewModel.load(from: .off)
          }

          ForEach(settings.parametricEqualizerSettings, id: \.id) { preset in
            Button(preset.description) {
              settings.activeParametricEqualizerSetting = preset
              selectedPresetId = preset.id
              viewModel.load(from: preset)
            }
          }
        }
      }

      // Preset Management
      HStack {
        // Edit existing preset
        if !settings.parametricEqualizerSettings.isEmpty {
          Menu("Edit Preset") {
            ForEach(settings.parametricEqualizerSettings, id: \.id) { preset in
              Button(preset.name) {
                selectedPresetId = preset.id
                viewModel.load(from: preset)
              }
            }
          }
          .buttonStyle(.bordered)
        }

        Spacer()

        // New preset button
        Button {
          newPresetName = "New Preset"
          isShowingNewPresetDialog = true
        } label: {
          Label("New", systemImage: "plus")
        }
        .buttonStyle(.bordered)
      }
      .padding(.vertical, 4)
    }, header: "Presets")
  }

  // MARK: - Editor Section

  private var editorSection: some View {
    VStack(spacing: 16) {
      // Preset name and actions
      if let presetId = selectedPresetId,
         let preset = findPreset(id: presetId) {
        HStack {
          Text(preset.name)
            .font(.headline)

          Spacer()

          Menu {
            Button {
              renameText = preset.name
              isShowingRenameDialog = true
            } label: {
              Label("Rename", systemImage: "pencil")
            }

            Button {
              viewModel.createDefaultBands()
              saveCurrentPreset()
            } label: {
              Label("Reset to Default Bands", systemImage: "arrow.counterclockwise")
            }

            Divider()

            Button(role: .destructive) {
              presetToDelete = preset
              isShowingDeleteAlert = true
            } label: {
              Label("Delete Preset", systemImage: "trash")
            }
          } label: {
            Image(systemName: "ellipsis.circle")
          }
        }
        .padding(.horizontal)
      }

      // Parametric EQ View
      ParametricEQView(
        viewModel: viewModel,
        accentColor: Color(settings.themePreference.asColor),
        onSettingChanged: { _ in
          saveCurrentPreset()
        }
      )

      // Save indicator
      if selectedPresetId != nil {
        Text("Changes are saved automatically")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .padding(.vertical)
    .background(Color(.systemBackground))
    .cornerRadius(12)
  }

  // MARK: - Actions

  private func loadActivePreset() {
    let active = settings.activeParametricEqualizerSetting
    if active.id != ParametricEqualizerSetting.off.id {
      selectedPresetId = active.id
      viewModel.load(from: active)
    } else if let first = settings.parametricEqualizerSettings.first {
      // Load first preset for editing but don't activate
      selectedPresetId = first.id
      viewModel.load(from: first)
    }
  }

  private func createNewPreset() {
    var newPreset = ParametricEqualizerSetting(name: newPresetName)

    // Create default bands
    newPreset = ParametricEqualizerSetting(
      id: newPreset.id,
      name: newPresetName,
      bands: ParametricBand.defaultFrequencies.enumerated().map { index, freq in
        let filterType: ParametricBandFilterType
        if index == 0 {
          filterType = .lowShelf
        } else if index == ParametricBand.defaultFrequencies.count - 1 {
          filterType = .highShelf
        } else {
          filterType = .bell
        }
        return ParametricBand(frequency: freq, gain: 0, q: 1.0, filterType: filterType)
      },
      globalBypass: false
    )

    var presets = settings.parametricEqualizerSettings
    presets.append(newPreset)
    settings.parametricEqualizerSettings = presets

    // Activate and edit the new preset
    settings.activeParametricEqualizerSetting = newPreset
    selectedPresetId = newPreset.id
    viewModel.load(from: newPreset)

    newPresetName = ""
  }

  private func saveCurrentPreset() {
    guard let presetId = selectedPresetId else { return }

    let updatedSetting = viewModel.toSetting(withId: presetId)

    // Update in the presets list
    var presets = settings.parametricEqualizerSettings
    if let index = presets.firstIndex(where: { $0.id == presetId }) {
      presets[index] = updatedSetting
      settings.parametricEqualizerSettings = presets
    }

    // Update active preset if it's the one being edited
    if settings.activeParametricEqualizerSetting.id == presetId {
      settings.activeParametricEqualizerSetting = updatedSetting
    }
  }

  private func deletePreset(_ preset: ParametricEqualizerSetting) {
    var presets = settings.parametricEqualizerSettings
    presets.removeAll { $0.id == preset.id }
    settings.parametricEqualizerSettings = presets

    // Reset active if it was deleted
    if settings.activeParametricEqualizerSetting.id == preset.id {
      settings.activeParametricEqualizerSetting = .off
    }

    // Clear selection
    if selectedPresetId == preset.id {
      selectedPresetId = presets.first?.id
      if let first = presets.first {
        viewModel.load(from: first)
      }
    }

    presetToDelete = nil
  }

  private func renameCurrentPreset() {
    guard let presetId = selectedPresetId else { return }

    viewModel.name = renameText
    saveCurrentPreset()
    renameText = ""
  }

  private func findPreset(id: UUID) -> ParametricEqualizerSetting? {
    settings.parametricEqualizerSettings.first { $0.id == id }
  }
}

// MARK: - EqualizerSettingsView_Previews

struct EqualizerSettingsView_Previews: PreviewProvider {
  @State
  static var settings = Settings()

  static var previews: some View {
    EqualizerSettingsView().environmentObject(settings)
  }
}
