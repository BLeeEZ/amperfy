//
//  AdaptiveSheet.swift
//  Amperfy
//
//  Created by David Klopp on 26.08.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import Foundation
import SwiftUI

// A sheet that respects the size of its content on macOS.
// Note 1: Do not use this in combination with `presentationMode` or other fancy stuff. It won't work.
// Note 2: Explicitly pass in required environment variables, such as `settings` if needed.
class FormSheetWrapper<Content: View>: UIViewController, UIPopoverPresentationControllerDelegate {

    var content: () -> Content
    var onDismiss: (() -> Void)?

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
        self.hostVC = vc
        self.present(vc, animated: true, completion: nil)
    }

    func hide() {
        guard let vc = self.hostVC, !vc.isBeingDismissed else { return }
        self.dismiss(animated: true, completion: nil)
        self.hostVC = nil
    }

    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        self.hostVC = nil
        self.onDismiss?()
    }
}

struct FormSheet<Content: View> : UIViewControllerRepresentable {

    @Binding var show: Bool

    let content: () -> Content

    func makeUIViewController(context: UIViewControllerRepresentableContext<FormSheet<Content>>) -> FormSheetWrapper<Content> {

        let vc = FormSheetWrapper(content: content)
        vc.onDismiss = { self.show = false }
        return vc
    }

    func updateUIViewController(_ uiViewController: FormSheetWrapper<Content>,
                                context: UIViewControllerRepresentableContext<FormSheet<Content>>) {
        if self.show {
            uiViewController.show()
        } else {
            uiViewController.hide()
        }
    }
}

extension View {
    public func formSheet<Content: View>(isPresented: Binding<Bool>,
                                          @ViewBuilder content: @escaping () -> Content) -> some View {
        self.background(FormSheet(show: isPresented, content: content))
    }
}
