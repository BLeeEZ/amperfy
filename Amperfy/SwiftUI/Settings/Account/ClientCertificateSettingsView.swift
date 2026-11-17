//
//  ClientCertificateSettingsView.swift
//  Amperfy
//
//  Created by Jerzy Królak on 08.05.26.
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
import UniformTypeIdentifiers

// MARK: - ClientCertificateSettingsView

struct ClientCertificateSettingsView: View {
  /// Keychain tag of the certificate to manage: the login tag or the tag of an account.
  let certTag: String

  var body: some View {
    SettingsList {
      ClientCertificateSections(certTag: certTag)
    }
    .navigationTitle("Client Certificate")
    .navigationBarTitleDisplayMode(.inline)
  }
}

// MARK: - ClientCertificateSections

/// The list sections to show, import, replace and remove a client certificate.
/// Shared by the account settings and the login options.
struct ClientCertificateSections: View {
  private let certTag: String

  @State
  private var certInfo: ClientCertificateInfo?
  @State
  private var isShowRemoveAlert = false
  @State
  private var importer = CertificateImporter()
  @State
  private var errorMessage: String?

  init(certTag: String) {
    self.certTag = certTag
    _certInfo = State(
      initialValue: ClientCertificateManager.shared.getCertificateInfo(tag: certTag)
    )
  }

  private func reload() {
    certInfo = ClientCertificateManager.shared.getCertificateInfo(tag: certTag)
  }

  private func importCertificate() {
    importer.importCertificate(tag: certTag) { error in
      errorMessage = error
      reload()
    }
  }

  private func removeCertificate() {
    try? ClientCertificateManager.shared.removeCertificate(tag: certTag)
    reload()
  }

  var body: some View {
    if let info = certInfo {
      SettingsSection(content: {
        SettingsRow(title: "Subject", orientation: .vertical) {
          SecondaryText(info.subjectName)
        }
        if let expiry = info.expirationDate {
          SettingsRow(title: "Expires") {
            Text(expiry, style: .date)
              .foregroundColor(info.isExpired ? .red : info.isExpiringSoon ? .orange : .secondary)
          }
        }
      }, header: "Installed Certificate")

      if info.isExpired {
        SettingsSection {
          Label(
            "This certificate has expired. Replace it to maintain server access.",
            systemImage: "exclamationmark.triangle.fill"
          )
          .foregroundColor(.red)
          .font(.footnote)
        }
      } else if info.isExpiringSoon, let days = info.daysUntilExpiry {
        SettingsSection {
          Label(
            "This certificate expires in \(days) day\(days == 1 ? "" : "s"). Consider replacing it soon.",
            systemImage: "exclamationmark.triangle"
          )
          .foregroundColor(.orange)
          .font(.footnote)
        }
      }

      SettingsSection {
        SettingsButtonRow(title: "Replace Certificate") {
          importCertificate()
        }
        SettingsButtonRow(title: "Remove Certificate", actionType: .destructive) {
          isShowRemoveAlert = true
        }
        .alert(isPresented: $isShowRemoveAlert) {
          Alert(
            title: Text("Remove Certificate"),
            message: Text(
              "This will remove the client certificate. You may not be able to connect to the server without it."
            ),
            primaryButton: .destructive(Text("Remove")) {
              removeCertificate()
            },
            secondaryButton: .cancel()
          )
        }
      }
    } else {
      SettingsSection(content: {
        SecondaryText("No client certificate configured.")
      }, header: "Client Certificate")

      SettingsSection {
        SettingsButtonRow(title: "Import Certificate") {
          importCertificate()
        }
      }
    }

    if let errorMessage {
      SettingsSection {
        Text(errorMessage)
          .foregroundColor(.red)
          .font(.footnote)
      }
    }
  }
}

// MARK: - CertificateImporter

/// The whole import flow: pick a certificate file, ask for its password in an alert (only if
/// the file has one) and store the certificate.
///
/// Presented with UIKit from the top-most view controller of the key window. SwiftUI presents
/// from the navigation stack's hosting controller, which UIKit reports as detached, and does
/// not reliably show a second presentation right after the file picker closes.
@MainActor
final class CertificateImporter: NSObject, UIDocumentPickerDelegate {
  private static let contentTypes = [
    UTType(filenameExtension: "p12"),
    UTType(filenameExtension: "pfx"),
  ].compactMap { $0 }

  private var tag = ""
  private var onFinished: ((_ error: String?) -> ())?
  private weak var presenter: UIViewController?

  /// `onFinished` gets `nil` once the certificate is stored, otherwise the error message.
  /// It is not called if the user cancels.
  func importCertificate(tag: String, onFinished: @escaping (_ error: String?) -> ()) {
    self.tag = tag
    self.onFinished = onFinished
    presenter = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow }
      .first { $0.isKeyWindow }?.rootViewController
    while let presented = presenter?.presentedViewController {
      presenter = presented
    }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: Self.contentTypes)
    picker.delegate = self
    present(picker)
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    // The picker can report the same pick twice (e.g. on a double tap), which would start two
    // imports and ask for the password twice.
    controller.delegate = nil
    guard let url = urls.first else { return }
    let isScoped = url.startAccessingSecurityScopedResource()
    defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
    do {
      // most certificate files have a password, but try without one first
      store(try Data(contentsOf: url), password: "", fileName: url.lastPathComponent)
    } catch {
      onFinished?(error.localizedDescription)
    }
  }

  private func store(_ data: Data, password: String, fileName: String) {
    do {
      try ClientCertificateManager.shared.storeCertificate(
        pkcs12: data, password: password, tag: tag
      )
      onFinished?(nil)
    } catch {
      if case ClientCertificateError.keychainError = error {
        onFinished?(error.localizedDescription)
      } else {
        // the file could not be opened with this password: ask (again)
        askPassword(
          for: data,
          fileName: fileName,
          message: password.isEmpty
            ? "Enter the password for \u{201C}\(fileName)\u{201D}."
            : error.localizedDescription
        )
      }
    }
  }

  private func askPassword(for data: Data, fileName: String, message: String) {
    let alert = UIAlertController(
      title: "Certificate Password",
      message: message,
      preferredStyle: .alert
    )
    alert.addTextField { textField in
      textField.placeholder = "Password"
      textField.isSecureTextEntry = true
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    let importAction = UIAlertAction(
      title: "Import",
      style: .default
    ) { [weak self, weak alert] _ in
      let password = alert?.textFields?.first?.text ?? ""
      self?.store(data, password: password, fileName: fileName)
    }
    alert.addAction(importAction)
    alert.preferredAction = importAction
    present(alert)
  }

  private func present(_ viewController: UIViewController) {
    guard let presenter else { return }
    if presenter.presentedViewController == nil {
      presenter.present(viewController, animated: true)
    } else {
      // the file picker or the previous alert is still closing
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(100))
        present(viewController)
      }
    }
  }
}
