//
//  MailView.swift
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

import MessageUI
import SwiftUI
import UIKit

// MARK: - MailAttachment

struct MailAttachment {
  var data: Data?
  var mimeType: String
  var fileName: String
}

// MARK: - MailView

struct MailView: UIViewControllerRepresentable {
  @Environment(\.presentationMode)
  var presentation
  @Binding
  var result: Result<MFMailComposeResult, Error>?
  var subject: String
  var messageBody: String
  var recipients: [String]
  var attachments: [MailAttachment]

  class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
    @Binding
    var presentation: PresentationMode
    @Binding
    var result: Result<MFMailComposeResult, Error>?

    init(
      presentation: Binding<PresentationMode>,
      result: Binding<Result<MFMailComposeResult, Error>?>
    ) {
      _presentation = presentation
      _result = result
    }

    func mailComposeController(
      _ controller: MFMailComposeViewController,
      didFinishWith result: MFMailComposeResult,
      error: Error?
    ) {
      defer {
        $presentation.wrappedValue.dismiss()
      }
      guard error == nil else {
        self.result = .failure(error!)
        return
      }
      self.result = .success(result)
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(
      presentation: presentation,
      result: $result
    )
  }

  func makeUIViewController(context: UIViewControllerRepresentableContext<MailView>)
    -> MFMailComposeViewController {
    let vc = MFMailComposeViewController()
    vc.setSubject(subject)
    vc.setMessageBody(messageBody, isHTML: false)
    vc.setToRecipients(recipients)
    for attachment in attachments {
      if let data = attachment.data {
        vc.addAttachmentData(data, mimeType: attachment.mimeType, fileName: attachment.fileName)
      }
    }
    vc.mailComposeDelegate = context.coordinator
    return vc
  }

  func updateUIViewController(
    _ uiViewController: MFMailComposeViewController,
    context: UIViewControllerRepresentableContext<MailView>
  ) {}
}

// MARK: - MailView_Previews

struct MailView_Previews: PreviewProvider {
  @State
  static var result: Result<MFMailComposeResult, Error>? = nil

  static var previews: some View {
    MailView(
      result: $result,
      subject: "",
      messageBody: "",
      recipients: [],
      attachments: []
    )
  }
}
