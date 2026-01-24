//
//  AutoEQSearchView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 24.01.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
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

// MARK: - AutoEQSearchView

struct AutoEQSearchView: View {
  @ObservedObject var service: AutoEQService
  let onPresetSelected: (AutoEQPresetData) -> Void
  
  @Environment(\.dismiss) private var dismiss
  
  @State private var searchText = ""
  @State private var isLoadingPreset = false
  @State private var loadingHeadphone: AutoEQHeadphone?
  @State private var errorMessage: String?
  @State private var showError = false
  
  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Search bar
        HStack {
          Image(systemName: "magnifyingglass")
            .foregroundColor(.secondary)
          TextField("Search headphones...", text: $searchText)
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .onChange(of: searchText) { newValue in
              Task {
                await service.search(query: newValue)
              }
            }
          if !searchText.isEmpty {
            Button {
              searchText = ""
              Task {
                await service.search(query: "")
              }
            } label: {
              Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
            }
          }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
        
        // Results or loading state
        if service.isLoading {
          Spacer()
          ProgressView("Loading headphone database...")
          Spacer()
        } else if let error = service.error {
          Spacer()
          VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
              .font(.largeTitle)
              .foregroundColor(.orange)
            Text("Failed to load headphones")
              .font(.headline)
            Text(error.localizedDescription)
              .font(.caption)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
            Button("Retry") {
              Task {
                await service.loadIndex()
              }
            }
            .buttonStyle(.borderedProminent)
          }
          .padding()
          Spacer()
        } else if searchText.isEmpty {
          // Show instructions
          VStack(spacing: 16) {
            Spacer()
            Image(systemName: "headphones")
              .font(.system(size: 60))
              .foregroundColor(.secondary)
            Text("Search for your headphones")
              .font(.headline)
            Text("AutoEQ provides scientifically measured EQ corrections for 3000+ headphones to match the Harman target curve.")
              .font(.caption)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal)
            Link(destination: URL(string: "https://github.com/jaakkopasanen/AutoEq")!) {
              HStack {
                Image(systemName: "link")
                Text("Learn more about AutoEQ")
              }
              .font(.caption)
            }
            Spacer()
          }
          .padding()
        } else if service.searchResults.isEmpty {
          Spacer()
          VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
              .font(.largeTitle)
              .foregroundColor(.secondary)
            Text("No headphones found")
              .font(.headline)
            Text("Try a different search term")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          Spacer()
        } else {
          // Search results list
          List {
            ForEach(groupedResults.keys.sorted(), id: \.self) { category in
              Section(header: Text(category)) {
                ForEach(groupedResults[category] ?? []) { headphone in
                  HeadphoneRow(
                    headphone: headphone,
                    isLoading: loadingHeadphone?.id == headphone.id,
                    onSelect: {
                      selectHeadphone(headphone)
                    }
                  )
                }
              }
            }
          }
          .listStyle(.insetGrouped)
        }
      }
      .navigationTitle("AutoEQ")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
      }
      .alert("Error", isPresented: $showError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(errorMessage ?? "An unknown error occurred")
      }
      .task {
        // Load index when view appears
        if service.headphones.isEmpty {
          await service.loadIndex()
        }
      }
    }
  }
  
  // Group results by category for display
  private var groupedResults: [String: [AutoEQHeadphone]] {
    Dictionary(grouping: service.searchResults) { $0.category.displayName }
  }
  
  private func selectHeadphone(_ headphone: AutoEQHeadphone) {
    loadingHeadphone = headphone
    
    Task {
      do {
        let preset = try await service.fetchPreset(for: headphone)
        await MainActor.run {
          loadingHeadphone = nil
          onPresetSelected(preset)
        }
      } catch {
        await MainActor.run {
          loadingHeadphone = nil
          errorMessage = error.localizedDescription
          showError = true
        }
      }
    }
  }
}

// MARK: - HeadphoneRow

private struct HeadphoneRow: View {
  let headphone: AutoEQHeadphone
  let isLoading: Bool
  let onSelect: () -> Void
  
  var body: some View {
    Button(action: onSelect) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(headphone.name)
            .font(.body)
            .foregroundColor(.primary)
          Text("Source: \(headphone.source)")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        Spacer()
        if isLoading {
          ProgressView()
        } else {
          Image(systemName: "chevron.right")
            .foregroundColor(.secondary)
            .font(.caption)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(isLoading)
  }
}

// MARK: - Preview

struct AutoEQSearchView_Previews: PreviewProvider {
  static var previews: some View {
    AutoEQSearchView(
      service: AutoEQService(),
      onPresetSelected: { _ in }
    )
  }
}
