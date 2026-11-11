//
//  ToastView.swift
//  Amperfy
//
//  Created by Chrizz Gelbach on 26.10.26.
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
import UIKit

// MARK: - ToastPlacement

/// Where a toast floats in window coordinates.
struct ToastPlacement {
  /// Horizontal center of the toast.
  let centerX: CGFloat
  /// The toast floats above this y coordinate.
  let bottomEdge: CGFloat
}

// MARK: - Toast

/// Shows one `ToastView` at a time above the bottom bar of a window.
@MainActor
enum Toast {
  private static let maxWidth: CGFloat = UIDevice.current.userInterfaceIdiom == .phone ? 260 : 360
  /// Distance between the toast and the edge it floats above.
  private static let bottomSpacing: CGFloat = 16

  /// Distance between the toast and the leading and trailing window edges.
  private static let sideSpacing: CGFloat = 16

  private static var host: UIHostingController<ToastView>?
  /// A toast whose window was closed before it finished does not count.
  static var isVisible: Bool { host?.view.window != nil }

  static func show(
    title: String,
    subtitle: String,
    style: LogEntryType,
    in window: UIWindow,
    placement: ToastPlacement,
    onTap: (() -> ())? = nil
  ) {
    guard !isVisible else { return }
    Self.host?.view.removeFromSuperview()
    let host = UIHostingController(rootView: ToastView(
      title: title,
      subtitle: subtitle,
      color: style.toastColor,
      onTap: onTap,
      onFinished: {}
    ))
    // only clear the toast that finished, not a newer one
    host.rootView.onFinished = { [weak host] in
      host?.view.removeFromSuperview()
      if Self.host === host { Self.host = nil }
    }
    Self.host = host
    host.view.backgroundColor = .clear
    host.sizingOptions = [.intrinsicContentSize]

    let view = host.view!
    view.translatesAutoresizingMaskIntoConstraints = false
    window.addSubview(view)
    let widthFill = view.widthAnchor.constraint(equalToConstant: maxWidth)
    widthFill.priority = .defaultHigh
    // centered on the mini player as long as it fits into the window
    let centered = view.centerXAnchor.constraint(
      equalTo: window.leftAnchor,
      constant: placement.centerX
    )
    centered.priority = .defaultHigh + 1
    NSLayoutConstraint.activate([
      centered,
      view.leftAnchor.constraint(greaterThanOrEqualTo: window.leftAnchor, constant: sideSpacing),
      view.rightAnchor.constraint(lessThanOrEqualTo: window.rightAnchor, constant: -sideSpacing),
      view.bottomAnchor.constraint(
        equalTo: window.topAnchor,
        constant: placement.bottomEdge - bottomSpacing
      ),
      view.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth),
      widthFill,
    ])
    // the toast is outside the focus order and gone after a few seconds: read it out
    UIAccessibility.post(notification: .announcement, argument: "\(title), \(subtitle)")
  }
}

// MARK: - ToastView

/// Compact glass capsule that builds out of a blur, disappears on its own the same way in reverse,
/// a little faster, and calls `onFinished` once it is gone.
struct ToastView: View {
  private static let height: CGFloat = 50
  private static let displayDuration: Duration = .seconds(5)
  private static let openAnimation: Animation = .spring(duration: 0.5, bounce: 0.2)
  private static let closeAnimation: Animation = .easeIn(duration: 0.30)

  let title: String
  let subtitle: String
  let color: Color
  let onTap: (() -> ())?
  var onFinished: () -> ()

  @State
  private var isShown = false
  @State
  private var isClosing = false
  @State
  private var isTapped = false

  var body: some View {
    ZStack {
      // keeps the size while the toast is not shown, so the host view does not jump
      text.hidden()
      if isShown {
        text
          .glassEffect(.regular.tint(color), in: .capsule)
          .glassEffectTransition(.materialize)
          .contentShape(.capsule)
          .onTapGesture(perform: handleTap)
          .accessibilityElement(children: .combine)
          .transition(.blurReplace)
      }
    }
    .onAppear {
      withAnimation(Self.openAnimation) { isShown = true }
    }
    .task {
      guard (try? await Task.sleep(for: Self.displayDuration)) != nil else { return }
      close()
    }
  }

  private var text: some View {
    VStack(spacing: 0) {
      Text(title)
        .font(.system(size: 13, weight: .medium))
        .lineLimit(1)
      // a longer subtitle wraps to a second line and the toast grows with it
      Text(subtitle)
        .font(.system(size: 12))
        .lineLimit(2)
    }
    .foregroundStyle(.white)
    .multilineTextAlignment(.center)
    .truncationMode(.tail)
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, minHeight: Self.height)
  }

  private func close() {
    guard !isClosing else { return }
    isClosing = true
    withAnimation(Self.closeAnimation) {
      isShown = false
    } completion: {
      onFinished()
    }
  }

  private func handleTap() {
    // runs even while the automatic close is already in progress
    guard !isTapped else { return }
    isTapped = true
    close()
    onTap?()
  }
}

extension LogEntryType {
  fileprivate var toastColor: Color {
    switch self {
    case .apiError, .error: return Color(uiColor: UIColor(named: "ToastError") ?? .systemRed)
    case .debug, .info: return Color(uiColor: UIColor(named: "ToastInfo") ?? .defaultBlue)
    }
  }
}
