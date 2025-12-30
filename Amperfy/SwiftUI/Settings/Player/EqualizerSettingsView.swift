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
import os
import SwiftUI

// MARK: - EqualizerSettingsView

struct EqualizerSettingsView: View {
  @EnvironmentObject
  private var settings: Settings

  @State
  private var eqSettingToEdit: EqualizerSetting?
  @State
  private var eqSettingNameSaved: String = ""
  @State
  private var eqSettingName: String = ""
  @State
  var eqSettingGains: [CGFloat] = EqualizerSetting.legacyFrequencies.map { _ in 0.0 }
  @State
  var sliderLabel: [String] = EqualizerSetting.legacyFrequencies.map {
    if $0 < 1000 {
      return "\(Int($0))"
    } else {
      return "\(Int($0 / 1000))k"
    }
  }

  @State
  private var complexity: EqualizerComplexity = .advanced

  @State
  private var isShowDeleteAlert = false

  @State
  private var searchText: String = ""
  @State
  private var searchResults: [AutoEqHeadphone] = []
  @State
  private var isSearching: Bool = false
  @State
  private var isShowAutoEqSearch: Bool = false
  @State
  private var isShowClearAllAlert: Bool = false
  @State
  private var isAutoPreampEnabled: Bool = true
  @State
  private var isShowRenameAlert: Bool = false
  @State
  private var newPresetName: String = ""
  @State
  private var isShowTextEditSheet: Bool = false
  @State
  private var textEditContent: String = ""

  var body: some View {
    ZStack {
      SettingsList {
        SettingsSection {
          SettingsCheckBoxRow(
            title: "Enable Equalizer",
            isOn: $settings.isEqualizerEnabled
          )
          .padding(.vertical, 4)

          Divider()

          HStack {
            Text("Complexity:")
              .font(.headline)
            Picker("Complexity", selection: $complexity) {
              ForEach(EqualizerComplexity.allCases, id: \.self) { level in
                Text(level.rawValue.capitalized).tag(level)
              }
            }
            .pickerStyle(.segmented)
          }
          .padding(.vertical, 8)

          HStack(spacing: 8) {
            Button {
              if let eq = eqSettingToEdit {
                textEditContent = eq.parametricFormat
                isShowTextEditSheet = true
              }
            } label: {
              Image(systemName: "pencil")
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)

            Button {
              resetEqualizer()
            } label: {
              Image(systemName: "arrow.counterclockwise")
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)

            Button {
              deleteCurrentEqualizer()
            } label: {
              Image(systemName: "trash")
                .foregroundColor(.red)
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            
            // Preset Selector (was AutoEQ search)
            Menu {
              Button("Create new Equalizer") {
                createNewEqualizer()
              }
              if eqSettingToEdit != nil {
                Button("Rename current EQ") {
                  newPresetName = eqSettingToEdit?.name ?? ""
                  isShowRenameAlert = true
                }
              }
              Divider()
              Section("Custom Presets") {
                ForEach(settings.equalizerSettings, id: \.self) { eq in
                  Button(eq.name) {
                    loadEqualizer(eq)
                  }
                }
              }
              Section("Standard Presets") {
                ForEach(EqualizerSetting.basicPresets, id: \.self) { eq in
                  Button(eq.name) {
                    var newEq = eq
                    newEq.name = "\(eq.name) (Custom)"
                    loadEqualizer(newEq)
                    saveEqualizer()
                  }
                }
              }
              Divider()
              Button("Clear all custom EQs", role: .destructive) {
                isShowClearAllAlert = true
              }
            } label: {
              HStack {
                Text(eqSettingToEdit?.name ?? "Off")
                  .font(.system(size: 14))
                  .foregroundColor(.primary)
                  .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                  .foregroundColor(.secondary)
                  .font(.system(size: 12))
              }
              .padding(.horizontal, 10)
              .frame(height: 32)
              .frame(maxWidth: .infinity)
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Button {
              createNewEqualizer()
            } label: {
              Image(systemName: "plus")
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)

            Button {
              isShowAutoEqSearch = true
            } label: {
              Image(systemName: "headphones")
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
          }

          if let currentEq = eqSettingToEdit {
            VStack(spacing: 16) {
              HStack {
                Text("Preamp:")
                  .font(.system(size: 14, weight: .medium))
                  .frame(width: 70, alignment: .leading)
                
                Slider(value: Binding(
                  get: { CGFloat(currentEq.preamp) },
                  set: { val in
                    var eq = currentEq
                    eq.preamp = Float(val)
                    eqSettingToEdit = eq
                    isAutoPreampEnabled = false // Manual adjust disables auto
                    saveEqualizer()
                  }
                ), in: -12...12)
                
                Text(String(format: "%.1fdB", currentEq.preamp))
                  .font(.system(size: 14, design: .monospaced))
                  .frame(width: 60, alignment: .trailing)
                
                Toggle("Auto", isOn: $isAutoPreampEnabled)
                  .labelsHidden()
                  .controlSize(.small)
                  .onChange(of: isAutoPreampEnabled) { enabled in
                    if enabled { applyAutoPreamp() }
                  }
                Text("Auto")
                  .font(.system(size: 12))
              }
              .padding(.top, 8)

              EqualizerView(
                sliderLabels: Binding(get: { displayedLabels }, set: { _ in }),
                sliderValues: Binding(
                  get: { displayedGains },
                  set: { updateGains(with: $0) }
                ),
                sliderTintColor: Color(settings.themePreference.asColor),
                gradientColors: [Color(settings.themePreference.asColor), .clear]
              )
            }
          }
        }
      }
    }
    .navigationTitle("Equalizer")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      if eqSettingToEdit == nil {
        loadEqualizer(settings.activeEqualizerSetting)
      }
    }
    .alert("Clear All EQs", isPresented: $isShowClearAllAlert) {
      Button("Cancel", role: .cancel) {}
      Button("Clear All", role: .destructive) {
        clearAllCustomEqualizers()
      }
    } message: {
      Text("This will remove all custom and AutoEQ presets. Only the 'Off' preset will remain.")
    }
    .alert("Rename Equalizer", isPresented: $isShowRenameAlert) {
      TextField("Preset Name", text: $newPresetName)
      Button("Cancel", role: .cancel) {}
      Button("Rename") {
        renameCurrentEqualizer()
      }
    } message: {
      Text("Enter a new name for this equalizer preset.")
    }
    .sheet(isPresented: $isShowAutoEqSearch) {
      AutoEqSearchView(
        isSearching: $isSearching,
        searchText: $searchText,
        searchResults: $searchResults,
        onSelect: { headphone in
          applyAutoEq(headphone)
          isShowAutoEqSearch = false
        },
        onSearch: performSearch
      )
    }
    .sheet(isPresented: $isShowTextEditSheet) {
      NavigationView {
        VStack(spacing: 0) {
          TextEditor(text: $textEditContent)
            .font(.system(.body, design: .monospaced))
            .padding()
          
          Text("Standard Parametric EQ format (Preamp + Filters)")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.bottom, 8)
        }
        .navigationTitle("Edit as Text")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") { isShowTextEditSheet = false }
          }
          ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") {
              if let updatedEq = EqualizerSetting.parseParametric(text: textEditContent, name: eqSettingToEdit?.name ?? "Imported EQ") {
                if var currentEq = eqSettingToEdit {
                  currentEq.bands = updatedEq.bands
                  currentEq.preamp = updatedEq.preamp
                  eqSettingToEdit = currentEq
                  saveEqualizer()
                  loadEqualizer(currentEq) // Refresh UI state
                }
              }
              isShowTextEditSheet = false
            }
            .fontWeight(.bold)
          }
        }
      }
    }
  }

  private var displayedLabels: [String] {
    switch complexity {
    case .basic:
      return ["64", "250", "1k", "4k", "16k"]
    case .advanced:
      return ["32", "64", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    }
  }

  private var displayedGains: [CGFloat] {
    guard let eq = eqSettingToEdit else { return [] }
    switch complexity {
    case .basic:
      let indices = [1, 3, 5, 7, 9] // 64, 250, 1k, 4k, 16k
      return indices.map { i in
        if i < eq.bands.count { 
          let g = CGFloat(eq.bands[i].gain)
          return g.isNaN ? 0 : g
        }
        return 0.0
      }
    case .advanced:
      return eq.legacyGains.map { 
        let g = CGFloat($0)
        return g.isNaN ? 0 : g
      }
    }
  }

  private func updateGains(with newGains: [CGFloat]) {
    guard var eq = eqSettingToEdit else { return }
    let safeGains = newGains.map { $0.isNaN ? 0 : $0 }
    
    switch complexity {
    case .basic:
      let indices = [1, 3, 5, 7, 9]
      for (idx, newGain) in zip(indices, safeGains) {
        if idx < eq.bands.count {
          eq.bands[idx].gain = Float(newGain)
        }
      }
    case .advanced:
      eq.legacyGains = safeGains.map { Float($0) }
    }
    
    eqSettingToEdit = eq
    saveEqualizer()
    if isAutoPreampEnabled {
      applyAutoPreamp()
    }
  }

  private func resetEqualizer() {
    guard var eq = eqSettingToEdit else { return }
    eq.bands = eq.bands.map {
      var band = $0
      band.gain = 0
      return band
    }
    eq.preamp = 0
    eqSettingToEdit = eq
    saveEqualizer()
    if isAutoPreampEnabled {
      applyAutoPreamp()
    }
  }

  private func saveEqualizer() {
    guard let eqToEdit = eqSettingToEdit else { return }
    var curEqSetting = settings.equalizerSettings
    
    // Match by name or ID to prevent duplicates
    if let index = curEqSetting.firstIndex(where: { $0.id == eqToEdit.id || $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == eqToEdit.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }) {
      curEqSetting[index] = eqToEdit
      settings.equalizerSettings = curEqSetting
      if settings.activeEqualizerSetting.id == eqToEdit.id || settings.activeEqualizerSetting.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == eqToEdit.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        settings.activeEqualizerSetting = eqToEdit
      }
    } else {
      curEqSetting.append(eqToEdit)
      settings.equalizerSettings = curEqSetting
    }
  }

  private func createNewEqualizer() {
    let newEQ = EqualizerSetting(name: "New Equalizer", bands: EqualizerSetting.legacyFrequencies.map { EqualizerBand(frequency: $0) })
    var curEqSetting = settings.equalizerSettings
    curEqSetting.append(newEQ)
    settings.equalizerSettings = curEqSetting
    loadEqualizer(newEQ)
  }

  private func loadEqualizer(_ eq: EqualizerSetting) {
    eqSettingToEdit = eq
    eqSettingName = eq.name
    eqSettingNameSaved = eq.name
    eqSettingGains = eq.legacyGains.compactMap { CGFloat($0) }
    
    // Also update the globally active setting so the player receives it
    settings.activeEqualizerSetting = eq
  }

  private func performSearch() {
    guard !searchText.isEmpty else { return }
    isSearching = true
    Task {
      do {
        let all = try await AutoEqService.shared.fetchHeadphoneIndex()
        let filtered = all.filter { $0.name.lowercased().contains(searchText.lowercased()) }.prefix(10).map { $0 }
        await MainActor.run {
          searchResults = filtered
          isSearching = false
        }
      } catch {
        os_log(.error, "AutoEQ Search failed: %s", error.localizedDescription)
        await MainActor.run { isSearching = false }
      }
    }
  }

  private func applyAutoEq(_ headphone: AutoEqHeadphone) {
    Task { @MainActor in
      do {
        var preset = try await AutoEqService.shared.fetchPreset(for: headphone)
        let timestamp = Int(Date().timeIntervalSince1970) % 1000
        preset.name = "\(headphone.name) (\(timestamp))"
        
        var curSettings = settings.equalizerSettings
        curSettings.append(preset)
        settings.equalizerSettings = curSettings
        
        loadEqualizer(preset)
        settings.activeEqualizerSetting = preset
        settings.isEqualizerEnabled = true
        
        searchText = ""
        searchResults = []
      } catch {
        os_log(.error, "Failed to apply AutoEQ preset: %s", error.localizedDescription)
      }
    }
  }

  private func applyAutoPreamp() {
    guard var eq = eqSettingToEdit else { return }
    let maxGain = eq.bands.filter { !$0.bypass }.map { $0.gain }.max() ?? 0
    let requiredPreamp = -max(0, maxGain)
    eq.preamp = requiredPreamp
    eqSettingToEdit = eq
    saveEqualizer()
  }

  private func deleteCurrentEqualizer() {
    guard let eqToDelete = eqSettingToEdit else { return }
    var curEqSettings = settings.equalizerSettings
    if eqToDelete.name == "Off" { return }

    if let index = curEqSettings.firstIndex(where: { $0.id == eqToDelete.id || $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == eqToDelete.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }) {
      curEqSettings.remove(at: index)
      settings.equalizerSettings = curEqSettings

      if let next = settings.equalizerSettings.first {
        loadEqualizer(next)
      } else {
        loadEqualizer(EqualizerSetting.off)
      }
    }
  }

  private func clearAllCustomEqualizers() {
    settings.equalizerSettings = [EqualizerSetting.off]
    settings.activeEqualizerSetting = EqualizerSetting.off
    loadEqualizer(EqualizerSetting.off)
  }

  private func renameCurrentEqualizer() {
    guard var eq = eqSettingToEdit, !newPresetName.isEmpty else { return }
    let oldId = eq.id
    eq.name = newPresetName
    eqSettingToEdit = eq
    
    // Update in settings list
    var curSettings = settings.equalizerSettings
    if let index = curSettings.firstIndex(where: { $0.id == oldId }) {
      curSettings[index] = eq
      settings.equalizerSettings = curSettings
    }
    
    // Update active setting if matches
    if settings.activeEqualizerSetting.id == oldId {
      settings.activeEqualizerSetting = eq
    }
    
    saveEqualizer()
  }
}

// MARK: - AutoEqSearchView

struct AutoEqSearchView: View {
  @Environment(\.dismiss) var dismiss
  @Binding var isSearching: Bool
  @Binding var searchText: String
  @Binding var searchResults: [AutoEqHeadphone]
  var onSelect: (AutoEqHeadphone) -> Void
  var onSearch: () -> Void

  var body: some View {
    NavigationView {
      VStack {
        TextField("Search Headphones (e.g. Sony, Sennheiser)", text: $searchText)
          .textFieldStyle(.roundedBorder)
          .padding()
          .onChange(of: searchText) { newValue in
            if newValue.count >= 2 {
              onSearch()
            }
          }
        
        if isSearching {
          ProgressView("Searching...")
            .padding()
        }
        
        List(searchResults, id: \.self) { headphone in
          Button {
            onSelect(headphone)
          } label: {
            VStack(alignment: .leading) {
              Text(headphone.name)
                .font(.headline)
              if let author = headphone.author {
                Text("by \(author)")
                  .font(.subheadline)
                  .foregroundColor(.secondary)
              }
            }
          }
        }
      }
      .navigationTitle("AutoEQ Search")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }
}

enum EqualizerComplexity: String, CaseIterable {
  case basic, advanced
}

// MARK: - EqualizerSettingsView_Previews

struct EqualizerSettingsView_Previews: PreviewProvider {
  @State
  static var settings = Settings()

  static var previews: some View {
    EqualizerSettingsView().environmentObject(settings)
  }
}
