//
//  CaptivePortalAuthenticator.swift
//  Amperfy
//
//  Created by Jerzy Królak on 07.05.26.
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
import UIKit
import WebKit

// MARK: - CaptivePortalAuthenticator

final class CaptivePortalAuthenticator: NSObject, CaptivePortalAuthHandler, @unchecked Sendable {
  @MainActor
  func performCaptivePortalAuth(serverURL: URL, clearSession: Bool) async throws {
    if clearSession {
      let dataStore = WKWebsiteDataStore.default()
      let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()
      let records = await dataStore.dataRecords(ofTypes: allTypes)
      await dataStore.removeData(ofTypes: allTypes, for: records)
    }

    try await showAlertAndAuthenticate(serverURL: serverURL)
  }

  @MainActor
  private func showAlertAndAuthenticate(serverURL: URL) async throws {
    guard let window = AppDelegate.mainSceneDelegate?.window,
          let rootVC = window.rootViewController
    else {
      throw CaptivePortalError.authenticationFailed
    }

    let topVC = Self.topViewController(from: rootVC)

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(), Error>) in
      let alert = UIAlertController(
        title: "Network Authentication Required",
        message:
        "Your server requires network authentication. You'll be redirected to log in.",
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
        self.presentWebView(serverURL: serverURL, from: topVC, continuation: continuation)
      })
      alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
        continuation.resume(throwing: CaptivePortalError.userCancelled)
      })
      topVC.present(alert, animated: true)
    }
  }

  @MainActor
  private func presentWebView(
    serverURL: URL,
    from presenter: UIViewController,
    continuation: CheckedContinuation<(), Error>
  ) {
    let webVC = CaptivePortalWebViewController(
      serverURL: serverURL,
      continuation: continuation
    )
    let navVC = UINavigationController(rootViewController: webVC)
    navVC.modalPresentationStyle = .fullScreen
    presenter.present(navVC, animated: true)
  }

  @MainActor
  private static func topViewController(from vc: UIViewController) -> UIViewController {
    if let presented = vc.presentedViewController {
      return topViewController(from: presented)
    }
    if let nav = vc as? UINavigationController, let visible = nav.visibleViewController {
      return topViewController(from: visible)
    }
    if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
      return topViewController(from: selected)
    }
    return vc
  }
}

// MARK: - CaptivePortalWebViewController

final class CaptivePortalWebViewController: UIViewController, WKNavigationDelegate,
  WKUIDelegate {
  private let serverURL: URL
  private let serverHost: String
  private var continuation: CheckedContinuation<(), Error>?
  private var webView: WKWebView!
  private var didComplete = false

  init(serverURL: URL, continuation: CheckedContinuation<(), Error>) {
    self.serverURL = serverURL
    self.serverHost = serverURL.host?.lowercased() ?? ""
    self.continuation = continuation
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Sign In"
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped)
    )

    let config = WKWebViewConfiguration()
    config.websiteDataStore = .default()
    webView = WKWebView(frame: view.bounds, configuration: config)
    webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    webView.navigationDelegate = self
    webView.uiDelegate = self
    view.addSubview(webView)

    webView.load(URLRequest(url: serverURL))
  }

  @objc
  private func cancelTapped() {
    finishWith(error: CaptivePortalError.userCancelled)
  }

  private func finishWith(error: Error?) {
    guard !didComplete else { return }
    didComplete = true
    dismiss(animated: true) {
      if let error {
        self.continuation?.resume(throwing: error)
        self.continuation = nil
      } else {
        self.copyCookiesToSharedStorage()
      }
    }
  }

  private func copyCookiesToSharedStorage() {
    webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
      for cookie in cookies {
        HTTPCookieStorage.shared.setCookie(cookie)
      }
      self.continuation?.resume()
      self.continuation = nil
    }
  }

  // MARK: - WKNavigationDelegate

  func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> ()
  ) {
    decisionHandler(.allow)
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    guard let currentHost = webView.url?.host?.lowercased() else { return }
    if currentHost == serverHost {
      finishWith(error: nil)
    }
  }

  func webView(
    _ webView: WKWebView,
    didFail navigation: WKNavigation!,
    withError error: Error
  ) {
    let nsError = error as NSError
    if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled { return }
    finishWith(error: CaptivePortalError.authenticationFailed)
  }

  func webView(
    _ webView: WKWebView,
    didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    let nsError = error as NSError
    if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled { return }
    finishWith(error: CaptivePortalError.authenticationFailed)
  }

  // MARK: - WKUIDelegate

  func webView(
    _ webView: WKWebView,
    createWebViewWith configuration: WKWebViewConfiguration,
    for navigationAction: WKNavigationAction,
    windowFeatures: WKWindowFeatures
  )
    -> WKWebView? {
    if navigationAction.targetFrame == nil || !navigationAction.targetFrame!.isMainFrame {
      webView.load(navigationAction.request)
    }
    return nil
  }

  func webView(
    _ webView: WKWebView,
    runJavaScriptAlertPanelWithMessage message: String,
    initiatedByFrame frame: WKFrameInfo,
    completionHandler: @escaping () -> ()
  ) {
    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
    present(alert, animated: true)
  }

  func webView(
    _ webView: WKWebView,
    runJavaScriptConfirmPanelWithMessage message: String,
    initiatedByFrame frame: WKFrameInfo,
    completionHandler: @escaping (Bool) -> ()
  ) {
    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
    alert
      .addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
    present(alert, animated: true)
  }
}
