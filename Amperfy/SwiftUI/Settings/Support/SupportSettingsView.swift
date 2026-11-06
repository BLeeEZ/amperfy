//
//  SupportSettingsView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 19.09.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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
import MessageUI
import SwiftUI

// MARK: - SupportSettingsView

struct SupportSettingsView: View {
  enum Destination: Hashable {
    case eventLog
  }

  let splitPercentage = 0.15

  @State
  var result: Result<MFMailComposeResult, Error>? = nil
  @State
  var isShowingMailView = false
  @State
  var isPreparingLogExport = false
  @State
  var logExportError: String? = nil

  var body: some View {
    ZStack {
      SettingsList {
        SettingsSection {
          SettingsButtonRow(
            title: "Report an issue on GitHub",
            splitPercentage: splitPercentage
          ) {
            if let url = URL(string: "https://github.com/BLeeEZ/amperfy/issues") {
              UIApplication.shared.open(url)
            }
          }
          SettingsButtonRow(
            title: "Send issue or feedback to developer",
            splitPercentage: splitPercentage
          ) {
            if MFMailComposeViewController.canSendMail() {
              isShowingMailView.toggle()
            } else {
              appDelegate.eventLogger.info(
                topic: "Email Info",
                statusCode: .emailError,
                message: "Email is not configured in settings app or Amperfy is not able to send an email.",
                displayPopup: true
              )
            }
          }
          Button(action: exportLog) {
            HStack {
              Text("Export log")
              Spacer()
              if isPreparingLogExport {
                ProgressView()
              }
            }
          }
          .disabled(isPreparingLogExport)
        }

        SettingsSection {
          NavigationLink(value: Destination.eventLog) {
            Text("Event Log")
          }
        }
      }
      .sheet(isPresented: $isShowingMailView) {
        MailView(
          result: $result,
          subject: "Amperfy support",
          messageBody: """
          \nPlease describe your issue.
          \nFeedback is always welcome too.
          \n
          \n
          --- Please don't remove the attachment ---
          """,
          recipients: ["amperfy@familie-zimba.de"],
          attachments: [MailAttachment(
            data: LogData.collectInformation(amperfyData: AmperKit.shared).asJSONData(),
            mimeType: "application/json",
            fileName: "AmperfyLog.json"
          )]
        )
      }
    }
    .navigationTitle("Support")
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(for: Destination.self) { destination in
      switch destination {
      case .eventLog: EventLogSettingsView()
      }
    }
    .onAppear {
      appDelegate.userStatistics.visited(.settingsSupport)
    }
    .alert(
      "Export log failed",
      isPresented: Binding(
        get: { logExportError != nil },
        set: { if !$0 { logExportError = nil } }
      ),
      presenting: logExportError
    ) { _ in
      Button("OK", role: .cancel) {}
    } message: { message in
      Text(message)
    }
  }

  /// Collects the log once, writes `AmperfyLog.json` and presents the share sheet.
  /// The row shows progress and ignores taps until the sheet is up or preparation failed.
  private func exportLog() {
    guard !isPreparingLogExport else { return }
    isPreparingLogExport = true
    Task { @MainActor in
      // Let the progress indicator render before the main-actor work starts.
      await Task.yield()
      do {
        guard let data = LogData.collectInformation(amperfyData: AmperKit.shared).asJSONData()
        else { throw CocoaError(.fileWriteUnknown) }
        let fileURL = try await Task.detached {
          try LogData.writeExportFile(data: data)
        }.value
        try presentShareSheet(fileURL: fileURL)
      } catch {
        isPreparingLogExport = false
        logExportError = error.localizedDescription
        appDelegate.eventLogger.error(
          topic: "Export log",
          statusCode: .internalError,
          message: "Export log failed: \(error.localizedDescription)",
          displayPopup: false
        )
      }
    }
  }

  private func presentShareSheet(fileURL: URL) throws {
    guard var presenter = AppDelegate.window?.rootViewController else {
      throw CocoaError(.featureUnsupported)
    }
    while let presented = presenter.presentedViewController, !presented.isBeingDismissed {
      presenter = presented
    }
    let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
    if let popover = activityVC.popoverPresentationController {
      popover.sourceView = presenter.view
      popover.sourceRect = CGRect(
        x: presenter.view.bounds.midX,
        y: presenter.view.bounds.midY,
        width: 0,
        height: 0
      )
      popover.permittedArrowDirections = []
    }
    activityVC.completionWithItemsHandler = { _, _, _, _ in
      try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }
    presenter.present(activityVC, animated: true) {
      isPreparingLogExport = false
    }
  }
}

// MARK: - SupportSettingsView_Previews

struct SupportSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SupportSettingsView()
  }
}
