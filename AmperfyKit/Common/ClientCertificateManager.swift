//
//  ClientCertificateManager.swift
//  AmperfyKit
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

import Foundation
import Security

// MARK: - ClientCertificateError

public enum ClientCertificateError: LocalizedError, Equatable {
  case invalidPKCS12Data
  case incorrectPassword
  case keychainError(status: OSStatus)
  case noIdentityFound

  public var errorDescription: String? {
    switch self {
    case .invalidPKCS12Data:
      return "The certificate file is invalid or corrupted."
    case .incorrectPassword:
      return "Incorrect certificate password."
    case let .keychainError(status):
      return "Keychain error: \(status)"
    case .noIdentityFound:
      return "No identity found in the certificate file."
    }
  }
}

// MARK: - ClientCertificateInfo

public struct ClientCertificateInfo: Sendable {
  public let subjectName: String
  public let expirationDate: Date?

  public var isExpired: Bool {
    guard let expirationDate else { return false }
    return expirationDate < Date()
  }

  public var isExpiringSoon: Bool {
    guard let expirationDate else { return false }
    let thirtyDays = TimeInterval(30 * 24 * 60 * 60)
    return !isExpired && expirationDate.timeIntervalSinceNow < thirtyDays
  }

  public var daysUntilExpiry: Int? {
    guard let expirationDate else { return nil }
    return Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day
  }
}

// MARK: - ClientCertificateManager

/// Keeps one client certificate per tag. The PKCS#12 file and its password are stored as a
/// generic keychain item: unlike a keychain identity, the same certificate can then be stored
/// under several tags (accounts) and moved between them.
public final class ClientCertificateManager: @unchecked Sendable {
  public static let shared = ClientCertificateManager()
  public static let loginTag = "amperfy.mtls.login"

  public static func accountTag(for accountIdent: String) -> String {
    "amperfy.mtls.\(accountIdent)"
  }

  private struct StoredCertificate: Codable {
    let pkcs12: Data
    let password: String
  }

  private init() {}

  private let lock = NSLock()
  /// Identities already loaded from the keychain (`nil` value: tag has no certificate), so that
  /// requests do not query the keychain every time.
  private var identities = [String: SecIdentity?]()
  private var _activeStreamingCertificateAccountIdent: String?

  /// Account ident of the currently streaming account, if any.
  /// Set on the main actor before playback starts and read from the streaming library's
  /// background URLSession delegate queue, so access is lock-protected.
  public var activeStreamingCertificateAccountIdent: String? {
    get { lock.withLock { _activeStreamingCertificateAccountIdent } }
    set { lock.withLock { _activeStreamingCertificateAccountIdent = newValue } }
  }

  /// The `URLCredential` to present for the currently streaming account, or `nil` if no account is
  /// set (e.g. radio). Safe to call from any thread.
  public func activeStreamingCredential() -> URLCredential? {
    guard let ident = activeStreamingCertificateAccountIdent else { return nil }
    return credential(accountIdent: ident)
  }

  /// Validates the PKCS#12 file and stores it under the tag, replacing an existing certificate.
  public func storeCertificate(pkcs12: Data, password: String, tag: String) throws {
    let identity = try Self.importIdentity(pkcs12: pkcs12, password: password)
    let stored = StoredCertificate(pkcs12: pkcs12, password: password)
    try write(JSONEncoder().encode(stored), tag: tag)
    lock.withLock { identities[tag] = identity }
  }

  private func identity(tag: String) -> SecIdentity? {
    lock.withLock { () -> SecIdentity? in
      if let cached = identities[tag] { return cached }
      let loaded = read(tag: tag)
        .flatMap { try? JSONDecoder().decode(StoredCertificate.self, from: $0) }
        .flatMap { try? Self.importIdentity(pkcs12: $0.pkcs12, password: $0.password) }
      identities.updateValue(loaded, forKey: tag)
      return loaded
    }
  }

  /// The client-certificate credential to present for the given account. Without an account
  /// (during login) the login-time certificate is used; an existing account never falls back to it.
  /// Shared by every per-request mTLS path: API requests, downloads, and streaming.
  public func credential(accountIdent: String?) -> URLCredential? {
    identity(tag: accountIdent.map { Self.accountTag(for: $0) } ?? Self.loginTag)
      .map { URLCredential(identity: $0, certificates: nil, persistence: .forSession) }
  }

  public func removeCertificate(tag: String) throws {
    let status = SecItemDelete(query(tag: tag) as CFDictionary)
    lock.withLock { _ = identities.removeValue(forKey: tag) }
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw ClientCertificateError.keychainError(status: status)
    }
  }

  public func hasCertificate(tag: String) -> Bool {
    identity(tag: tag) != nil
  }

  public func getCertificateInfo(tag: String) -> ClientCertificateInfo? {
    var certificate: SecCertificate?
    guard let identity = identity(tag: tag),
          SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess,
          let cert = certificate
    else { return nil }
    return ClientCertificateInfo(
      subjectName: SecCertificateCopySubjectSummary(cert) as String? ?? "Unknown",
      expirationDate: SecCertificateCopyNotValidAfterDate(cert) as Date?
    )
  }

  /// Moves the certificate to another tag, e.g. from the login tag to the account after login.
  public func moveCertificate(from sourceTag: String, to destinationTag: String) throws {
    guard let data = read(tag: sourceTag) else { return }
    try write(data, tag: destinationTag)
    try removeCertificate(tag: sourceTag)
  }

  // MARK: - Private

  private func query(tag: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "amperfy.mtls",
      kSecAttrAccount as String: tag,
    ]
  }

  private func read(tag: String) -> Data? {
    var item = query(tag: tag)
    item[kSecReturnData as String] = true
    item[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    guard SecItemCopyMatching(item as CFDictionary, &result) == errSecSuccess else { return nil }
    return result as? Data
  }

  private func write(_ data: Data, tag: String) throws {
    try removeCertificate(tag: tag)
    var item = query(tag: tag)
    item[kSecValueData as String] = data
    item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    let status = SecItemAdd(item as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw ClientCertificateError.keychainError(status: status)
    }
  }

  private static func importIdentity(pkcs12: Data, password: String) throws -> SecIdentity {
    // Memory only: on the Mac the identity would otherwise also be added to the keychain, and
    // importing the same file again would fail as a duplicate.
    let options: [String: Any] = [
      kSecImportExportPassphrase as String: password,
      kSecImportToMemoryOnly as String: true,
    ]
    var rawItems: CFArray?
    let status = SecPKCS12Import(pkcs12 as CFData, options as CFDictionary, &rawItems)

    guard status == errSecSuccess else {
      throw status == errSecAuthFailed
        ? ClientCertificateError.incorrectPassword
        : ClientCertificateError.invalidPKCS12Data
    }

    guard let items = rawItems as? [[String: Any]],
          let identityRef = items.first?[kSecImportItemIdentity as String]
    else {
      throw ClientCertificateError.noIdentityFound
    }
    // swiftlint:disable:next force_cast
    return identityRef as! SecIdentity
  }
}

// MARK: - ClientCertificateURLSessionDelegate

/// Presents the client certificate when the server asks for one. Everything else, including the
/// validation of the server certificate, is left to the system.
final class ClientCertificateURLSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
  private let credential: URLCredential

  init(credential: URLCredential) {
    self.credential = credential
    super.init()
  }

  func urlSession(
    _ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> ()
  ) {
    if challenge.protectionSpace
      .authenticationMethod == NSURLAuthenticationMethodClientCertificate {
      completionHandler(.useCredential, credential)
    } else {
      completionHandler(.performDefaultHandling, nil)
    }
  }
}
