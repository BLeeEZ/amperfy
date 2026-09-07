//
//  CacheLocationSettingsView.swift
//  Amperfy
//
//  Copyright (c) 2026 Amperfy contributors. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

#if targetEnvironment(macCatalyst)
  import AmperfyKit
  import SwiftUI
  import UIKit
  import UniformTypeIdentifiers

  enum CacheLocationAccessibility {
    static let preLoginEntry = "amperfy.login.cache-location"
    static let sheet = "amperfy.cache-location.sheet"
    static let chooseFolder = "amperfy.cache-location.choose-folder"
    static let pendingSelection = "amperfy.cache-location.pending-selection"
    static let confirmSelection = "amperfy.cache-location.confirm-selection"
    static let status = "amperfy.cache-location.status"
    static let close = "amperfy.cache-location.close"
    static let picker = "amperfy.cache-location.folder-picker"
  }

  // MARK: - CacheFolderPicker

  /// UIKit is the only v1 folder-picker implementation. An AppKit bridge is intentionally absent.
  struct CacheFolderPicker: UIViewControllerRepresentable {
    let didSelect: (URL) -> ()
    let didCancel: () -> ()

    func makeCoordinator() -> Coordinator {
      Coordinator(didSelect: didSelect, didCancel: didCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
      let picker = UIDocumentPickerViewController(
        forOpeningContentTypes: [.folder],
        asCopy: false
      )
      picker.allowsMultipleSelection = false
      picker.delegate = context.coordinator
      picker.view.accessibilityIdentifier = CacheLocationAccessibility.picker
      picker.view.accessibilityLabel = "Choose a folder for downloaded files"
      return picker
    }

    func updateUIViewController(
      _ uiViewController: UIDocumentPickerViewController,
      context: Context
    ) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
      private let didSelect: (URL) -> ()
      private let didCancel: () -> ()

      init(didSelect: @escaping (URL) -> (), didCancel: @escaping () -> ()) {
        self.didSelect = didSelect
        self.didCancel = didCancel
      }

      func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
      ) {
        guard let url = urls.first else { return didCancel() }
        didSelect(url)
      }

      func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        didCancel()
      }
    }
  }

  // MARK: - CacheLocationSettingsView

  struct CacheLocationSettingsView: View {
    var onWorkingChanged: (Bool) -> () = { _ in }
    @State
    private var prepared: PreparedExternalCacheSelection?
    @State
    private var choosingFolder = false
    @State
    private var reconnecting = false
    @State
    private var confirmingMove = false
    @State
    private var bytesToMove: Int64 = 0
    @State
    private var isWorking = false
    @State
    private var moveTask: Task<(), Never>?
    @State
    private var progress = CacheMoveProgress(message: "")
    @State
    private var errorMessage: String?
    @State
    private var location = "On This Mac"
    @State
    private var locationPath = ""
    @State
    private var availableSpace = ""
    @State
    private var usedSpace = ""
    @State
    private var isExternal = false
    @State
    private var isAvailable = false
    @State
    private var unfinishedMove = false
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
      SettingsList {
        SettingsSection(
          content: {
            SettingsRow(title: "Location") { SecondaryText(location) }
              .accessibilityIdentifier(CacheLocationAccessibility.status)
            if !locationPath.isEmpty {
              SettingsRow(title: "Folder") { SecondaryText(locationPath) }
            }
            SettingsRow(title: "Status") {
              SecondaryText(
                isWorking ? "Moving files" :
                  (isAvailable ? "Available" : "Drive unavailable")
              )
            }
            if isAvailable {
              SettingsRow(title: "Downloaded Audio") { SecondaryText(usedSpace) }
              SettingsRow(title: "Available Space") { SecondaryText(availableSpace) }
            }
          },
          footer: "Songs, podcasts, artwork, and lyrics use this location for all accounts. Your account settings and library database stay on this Mac."
        )

        if isWorking {
          SettingsSection {
            Text(progress.message)
            if progress.totalBytes > 0 {
              ProgressView(
                value: Double(progress.completedBytes),
                total: Double(progress.totalBytes)
              )
              SecondaryText(
                "\(progress.completedBytes.asByteString) of \(progress.totalBytes.asByteString)"
              )
            } else {
              ProgressView()
            }
            Button("Cancel Move", role: .cancel) { moveTask?.cancel() }
              .disabled(
                progress.message == "Switching cache location…" || progress
                  .message == "Removing the previous copy…"
              )
          }
        } else if unfinishedMove {
          SettingsSection(
            content: {
              Button("Finish Previous Move") { finishPreviousMove() }
            },
            footer: "A previous move was interrupted. Reconnect both drives to finish cleanup. The location shown above remains active."
          )
        } else if isAvailable {
          SettingsSection {
            Button("Change…") {
              reconnecting = false
              choosingFolder = true
            }
            .accessibilityIdentifier(CacheLocationAccessibility.chooseFolder)
            if isExternal {
              Button("Use Built-in Storage…") {
                prepared?.cancel()
                prepared = nil
                Task {
                  do {
                    bytesToMove = try await Task
                      .detached { try CacheRootRuntime.shared.cacheInventorySize() }.value
                    confirmingMove = true
                  } catch { errorMessage = cacheErrorMessage(error) }
                }
              }
            }
          }
        } else {
          SettingsSection(
            content: {
              Button("Retry") {
                Task {
                  await Task.detached { CacheRootRuntime.shared.refreshAvailability() }.value
                  await refresh()
                }
              }
              Button("Locate Cache Folder…") {
                reconnecting = true
                choosingFolder = true
              }
            },
            footer: "Reconnect the drive to use downloaded music, or select the folder you originally chose. You can continue browsing and stream music in online mode. Downloads will wait; they will not use built-in storage instead."
          )
        }
      }
      .navigationTitle("Cache Location")
      .navigationBarTitleDisplayMode(.inline)
      .accessibilityIdentifier(CacheLocationAccessibility.sheet)
      .interactiveDismissDisabled(isWorking)
      .navigationBarBackButtonHidden(isWorking)
      .onChange(of: isWorking) { _, working in onWorkingChanged(working) }
      .task { await refresh() }
      .onReceive(timer) { _ in Task { await refresh() } }
      .sheet(isPresented: $choosingFolder) {
        CacheFolderPicker(didSelect: { url in
          choosingFolder = false
          Task {
            do {
              if reconnecting {
                try await Task.detached {
                  try CacheRootRuntime.shared.reselectConfiguredExternal(selectedParentURL: url)
                }.value
                await refresh()
              } else {
                let selection = try await Task.detached {
                  try CacheRootRuntime.shared.prepareExternal(selectedParentURL: url)
                }.value
                prepared?.cancel()
                prepared = selection
                bytesToMove = try await Task
                  .detached { try CacheRootRuntime.shared.cacheInventorySize() }.value
                try CacheCapacityPolicy().validate(
                  available: selection.availableCapacity,
                  inventoryBytes: bytesToMove
                )
                confirmingMove = true
              }
            } catch { errorMessage = cacheErrorMessage(error) }
          }
        }, didCancel: { choosingFolder = false })
      }
      .alert("Move Downloaded Files?", isPresented: $confirmingMove) {
        Button("Cancel", role: .cancel) { prepared?.cancel(); prepared = nil }
        Button("Move") { startMove() }
          .accessibilityIdentifier(CacheLocationAccessibility.confirmSelection)
      } message: {
        Text(
          "Move \(bytesToMove.asByteString) of downloaded files for all accounts to \(prepared?.parentURL.lastPathComponent ?? "built-in storage")? Playback and downloads pause during the move. Amperfy verifies the new copy before removing the old one."
        )
      }
      .alert("Cache Location", isPresented: Binding(
        get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
      )) {
        Button("OK", role: .cancel) { errorMessage = nil }
      } message: { Text(errorMessage ?? "") }
    }

    private func refresh() async {
      let runtime = CacheRootRuntime.shared
      let preference = try? runtime.configuredPreference()
      isExternal = preference?.mode == .external
      isAvailable = runtime.isCacheAvailable
      location = isExternal ? (preference?.displayName ?? "External Drive") : "On This Mac"
      if case let .ready(_, root) = runtime.state { locationPath = root.path }
      else { locationPath = "" }
      unfinishedMove = runtime.hasUnfinishedMove
      usedSpace = runtime.fileManager.completePlayableCacheSize.asByteString
      let capacity = await Task.detached { try? runtime.availableCapacity() }.value
      availableSpace = capacity?.asByteString ?? "Unavailable"
    }

    private func startMove() {
      let selection = prepared
      prepared = nil
      isWorking = true
      progress = CacheMoveProgress(message: "Preparing to move…")
      moveTask = Task {
        if AmperKit.shared.settings.accounts.active != nil { AmperKit.shared.player.pause() }
        await AmperKit.shared.pauseDownloadsForCacheMove()
        let worker = Task.detached {
          try CacheRootRuntime.shared.relocateCache(to: selection, progress: { update in
            Task { @MainActor in progress = update }
          }, checkCancellation: { try Task.checkCancellation() })
        }
        do {
          try await withTaskCancellationHandler(
            operation: { try await worker.value },
            onCancel: { worker.cancel() }
          )
        } catch is CancellationError {
          errorMessage = "The move was canceled. Your previous cache location remains active."
        } catch { errorMessage = cacheErrorMessage(error) }
        await AmperKit.shared.resumeDownloadsAfterCacheMove()
        isWorking = false
        moveTask = nil
        await refresh()
      }
    }

    private func finishPreviousMove() {
      isWorking = true
      progress = CacheMoveProgress(message: "Finishing the previous move…")
      Task {
        do { try await Task.detached { try CacheRootRuntime.shared.finishInterruptedMove() }.value }
        catch { errorMessage = cacheErrorMessage(error) }
        isWorking = false
        await refresh()
      }
    }

    private func cacheErrorMessage(_ error: Error) -> String {
      switch error {
      case let CacheRootError.insufficientCapacity(required, available):
        return "This location needs \(required.asByteString) free, including working space. It has \(available.asByteString) available. Choose a drive with more space."
      case CacheRootError.markerMismatch:
        return "This folder does not contain the expected cache, or already contains another cache. Select the original cache folder to reconnect, or an empty folder for a new location."
      case CacheRootError.invalidPreparedSelection:
        return "Choose a different folder outside the current cache."
      case CacheRootError.migrationRequired:
        return "The destination already contains downloaded files. Choose an empty folder."
      default:
        return "Amperfy could not finish this operation. Check that the drive is connected and the folder is writable, then retry. The active location is shown in settings."
      }
    }
  }

  // MARK: - CacheLocationSheet

  struct CacheLocationSheet: View {
    @Environment(\.dismiss)
    private var dismiss
    @State
    private var isWorking = false

    var body: some View {
      NavigationStack {
        CacheLocationSettingsView(onWorkingChanged: { isWorking = $0 })
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button("Done") { dismiss() }
                .disabled(isWorking)
                .accessibilityIdentifier(CacheLocationAccessibility.close)
                .accessibilityLabel("Close Cache Location")
            }
          }
      }
      .accessibilityIdentifier(CacheLocationAccessibility.sheet)
    }
  }

#endif
