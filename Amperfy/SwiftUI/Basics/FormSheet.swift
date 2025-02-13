//
//  FormSheet.swift
//  Amperfy
//
//  Created by David Klopp on 26.08.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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

import Foundation
import SwiftUI

// MARK: - FormSheetWrapper

// A sheet that respects the size of its content on macOS.
// Note 1: Do not use this in combination with `presentationMode` or other fancy stuff. It won't work.
// Note 2: Explicitly pass in required environment variables, such as `settings` if needed.
class FormSheetWrapper<Content: View>: UIViewController, UIPopoverPresentationControllerDelegate {
  var content: () -> Content
  var onDismiss: (() -> ())?

  private var hostVC: UIHostingController<Content>?

  required init?(coder: NSCoder) { fatalError("") }

  init(content: @escaping () -> Content) {
    self.content = content
    super.init(nibName: nil, bundle: nil)
  }

  func show() {
    guard hostVC == nil else { return }
    let vc = UIHostingController(rootView: content())

    vc.view.sizeToFit()
    vc.view.backgroundColor = .clear
    vc.preferredContentSize = vc.view.frame.size
    vc.modalPresentationStyle = .formSheet
    vc.presentationController?.delegate = self
    hostVC = vc
    present(vc, animated: true, completion: nil)
  }

  func hide() {
    guard let vc = hostVC, !vc.isBeingDismissed else { return }
    dismiss(animated: true, completion: nil)
    hostVC = nil
  }

  func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
    hostVC = nil
    onDismiss?()
  }
}

// MARK: - FormSheet

struct FormSheet<Content: View>: UIViewControllerRepresentable {
  @Binding
  var show: Bool

  let content: () -> Content

  func makeUIViewController(context: UIViewControllerRepresentableContext<FormSheet<Content>>)
    -> FormSheetWrapper<Content> {
    let vc = FormSheetWrapper(content: content)
    vc.onDismiss = { show = false }
    return vc
  }

  func updateUIViewController(
    _ uiViewController: FormSheetWrapper<Content>,
    context: UIViewControllerRepresentableContext<FormSheet<Content>>
  ) {
    if show {
      uiViewController.show()
    } else {
      uiViewController.hide()
    }
  }
}

extension View {
  public func formSheet<Content: View>(
    isPresented: Binding<Bool>,
    @ViewBuilder content: @escaping () -> Content
  )
    -> some View {
    background(FormSheet(show: isPresented, content: content))
  }
}
