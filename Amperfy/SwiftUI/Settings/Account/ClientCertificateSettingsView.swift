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
  @EnvironmentObject
  var settings: Settings

  @State
  private var certInfo: ClientCertificateInfo?
  @State
  private var isShowRemoveAlert = false
  @State
  private var isShowFilePicker = false
  @State
  private var isShowPasswordPrompt = false
  @State
  private var selectedFileData: Data?
  @State
  private var errorMessage: String?

  private var certTag: String {
    guard let accountInfo = settings.activeAccountInfo else {
      return ClientCertificateManager.loginTag
    }
    return ClientCertificateManager.accountTag(for: accountInfo.ident)
  }

  private func reload() {
    certInfo = ClientCertificateManager.shared.getCertificateInfo(tag: certTag)
  }

  private func removeCertificate() {
    try? ClientCertificateManager.shared.removeIdentity(tag: certTag)
    reload()
  }

  var body: some View {
    SettingsList {
      if let info = certInfo {
        SettingsSection(content: {
          SettingsRow(title: "Subject", orientation: .vertical) {
            SecondaryText(info.subjectName)
          }
          SettingsRow(title: "Issuer", orientation: .vertical) {
            SecondaryText(info.issuerName)
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
            isShowFilePicker = true
          }
          SettingsButtonRow(title: "Remove Certificate", actionType: .destructive) {
            isShowRemoveAlert = true
          }
        }
      } else {
        SettingsSection(content: {
          SecondaryText("No client certificate configured.")
        }, header: "Client Certificate")

        SettingsSection {
          SettingsButtonRow(title: "Import Certificate") {
            isShowFilePicker = true
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
    .navigationTitle("Client Certificate")
    .navigationBarTitleDisplayMode(.inline)
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
    .sheet(isPresented: $isShowFilePicker) {
      CertificateDocumentPicker(fileData: $selectedFileData)
    }
    .sheet(isPresented: $isShowPasswordPrompt) {
      CertificatePasswordPrompt(
        fileData: selectedFileData ?? Data(),
        certTag: certTag,
        onComplete: { success, error in
          isShowPasswordPrompt = false
          if success {
            errorMessage = nil
            reload()
          } else {
            errorMessage = error
          }
        }
      )
    }
    .onChange(of: selectedFileData) { _, newValue in
      if newValue != nil {
        isShowPasswordPrompt = true
      }
    }
    .onAppear { reload() }
  }
}

// MARK: - CertificateDocumentPicker

struct CertificateDocumentPicker: UIViewControllerRepresentable {
  @Binding
  var fileData: Data?
  @Environment(\.dismiss)
  var dismiss

  func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
    let types: [UTType] = [
      UTType(filenameExtension: "p12")!,
      UTType(filenameExtension: "pfx")!,
    ]
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
    picker.allowsMultipleSelection = false
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(
    _ uiViewController: UIDocumentPickerViewController,
    context: Context
  ) {}

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  class Coordinator: NSObject, UIDocumentPickerDelegate {
    let parent: CertificateDocumentPicker

    init(_ parent: CertificateDocumentPicker) {
      self.parent = parent
    }

    func documentPicker(
      _ controller: UIDocumentPickerViewController,
      didPickDocumentsAt urls: [URL]
    ) {
      guard let url = urls.first else { return }
      guard url.startAccessingSecurityScopedResource() else { return }
      defer { url.stopAccessingSecurityScopedResource() }
      parent.fileData = try? Data(contentsOf: url)
      parent.dismiss()
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
      parent.dismiss()
    }
  }
}

// MARK: - CertificatePasswordPrompt

struct CertificatePasswordPrompt: View {
  let fileData: Data
  let certTag: String
  let onComplete: (Bool, String?) -> ()

  @State
  private var password = ""
  @State
  private var isImporting = false
  @State
  private var errorText: String?

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Certificate Password")) {
          SecureField("Password", text: $password)
        }

        if let errorText {
          Section {
            Text(errorText)
              .foregroundColor(.red)
              .font(.footnote)
          }
        }

        Section {
          Button("Import") {
            importCertificate()
          }
          .disabled(isImporting)
        }
      }
      .navigationTitle("Import Certificate")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            onComplete(false, nil)
          }
        }
      }
    }
  }

  private func importCertificate() {
    isImporting = true
    do {
      let (identity, _) = try ClientCertificateManager.shared.importPKCS12(
        data: fileData, password: password
      )
      try ClientCertificateManager.shared.storeIdentity(identity, tag: certTag)
      onComplete(true, nil)
    } catch {
      errorText = error.localizedDescription
      isImporting = false
    }
  }
}
