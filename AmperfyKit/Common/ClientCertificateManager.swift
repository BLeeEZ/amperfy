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
  case certificateExpired

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
    case .certificateExpired:
      return "The certificate has expired."
    }
  }
}

// MARK: - ClientCertificateInfo

public struct ClientCertificateInfo: Sendable {
  public let subjectName: String
  public let issuerName: String
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

public final class ClientCertificateManager: Sendable {
  public static let shared = ClientCertificateManager()
  public static let loginTag = "amperfy.mtls.login"

  public static func accountTag(for accountIdent: String) -> String {
    "amperfy.mtls.\(accountIdent)"
  }

  private init() {}

  public func importPKCS12(data: Data, password: String) throws -> (
    identity: SecIdentity, info: ClientCertificateInfo
  ) {
    let options: [String: Any] = [kSecImportExportPassphrase as String: password]
    var rawItems: CFArray?
    let status = SecPKCS12Import(data as CFData, options as CFDictionary, &rawItems)

    guard status == errSecSuccess else {
      if status == errSecAuthFailed || status == errSecDecode {
        throw ClientCertificateError.incorrectPassword
      }
      throw ClientCertificateError.invalidPKCS12Data
    }

    guard let items = rawItems as? [[String: Any]],
          let firstItem = items.first,
          let identityRef = firstItem[kSecImportItemIdentity as String]
    else {
      throw ClientCertificateError.noIdentityFound
    }
    // swiftlint:disable:next force_cast
    let identity = identityRef as! SecIdentity

    let info = try extractCertificateInfo(from: identity)
    return (identity, info)
  }

  public func storeIdentity(_ identity: SecIdentity, tag: String) throws {
    try removeIdentityIfExists(tag: tag)

    let addQuery: [String: Any] = [
      kSecClass as String: kSecClassIdentity,
      kSecValueRef as String: identity,
      kSecAttrLabel as String: tag,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
    ]

    let status = SecItemAdd(addQuery as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw ClientCertificateError.keychainError(status: status)
    }
  }

  public func getIdentity(tag: String) -> SecIdentity? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassIdentity,
      kSecAttrLabel as String: tag,
      kSecReturnRef as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess else { return nil }
    return (result as! SecIdentity)
  }

  public func getCredential(tag: String) -> URLCredential? {
    guard let identity = getIdentity(tag: tag) else { return nil }
    return URLCredential(
      identity: identity,
      certificates: nil,
      persistence: .forSession
    )
  }

  public func removeIdentity(tag: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassIdentity,
      kSecAttrLabel as String: tag,
    ]

    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw ClientCertificateError.keychainError(status: status)
    }
  }

  public func hasIdentity(tag: String) -> Bool {
    getIdentity(tag: tag) != nil
  }

  public func getCertificateInfo(tag: String) -> ClientCertificateInfo? {
    guard let identity = getIdentity(tag: tag) else { return nil }
    return try? extractCertificateInfo(from: identity)
  }

  public func migrateIdentity(from sourceTag: String, to destinationTag: String) throws {
    guard let identity = getIdentity(tag: sourceTag) else { return }
    try storeIdentity(identity, tag: destinationTag)
    try removeIdentity(tag: sourceTag)
  }

  // MARK: - Private

  private func removeIdentityIfExists(tag: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassIdentity,
      kSecAttrLabel as String: tag,
    ]
    let status = SecItemDelete(query as CFDictionary)
    if status != errSecSuccess, status != errSecItemNotFound {
      throw ClientCertificateError.keychainError(status: status)
    }
  }

  private func extractCertificateInfo(from identity: SecIdentity) throws -> ClientCertificateInfo {
    var certificate: SecCertificate?
    let status = SecIdentityCopyCertificate(identity, &certificate)
    guard status == errSecSuccess, let cert = certificate else {
      throw ClientCertificateError.noIdentityFound
    }

    let subjectName = SecCertificateCopySubjectSummary(cert) as String? ?? "Unknown"
    let derData = SecCertificateCopyData(cert) as Data
    let expirationDate = Self.parseExpirationDate(from: derData)

    return ClientCertificateInfo(
      subjectName: subjectName,
      issuerName: "Unknown",
      expirationDate: expirationDate
    )
  }

  /// Parses the notAfter date from DER-encoded X.509 certificate data.
  /// X.509 structure: SEQUENCE { tbsCertificate SEQUENCE { version, serial, sigAlgo, issuer, validity SEQUENCE { notBefore, notAfter }, ... } }
  private static func parseExpirationDate(from derData: Data) -> Date? {
    var offset = 0
    let bytes = [UInt8](derData)

    func readTag() -> UInt8? {
      guard offset < bytes.count else { return nil }
      let tag = bytes[offset]
      offset += 1
      return tag
    }

    func readLength() -> Int? {
      guard offset < bytes.count else { return nil }
      let first = bytes[offset]
      offset += 1
      if first < 0x80 {
        return Int(first)
      }
      let numBytes = Int(first & 0x7F)
      guard offset + numBytes <= bytes.count else { return nil }
      var length = 0
      for _ in 0 ..< numBytes {
        length = (length << 8) | Int(bytes[offset])
        offset += 1
      }
      return length
    }

    func skipElement() -> Bool {
      guard readTag() != nil, let len = readLength() else { return false }
      offset += len
      return offset <= bytes.count
    }

    func enterSequence() -> Bool {
      guard let tag = readTag(), (tag & 0x30) == 0x30 else { return false }
      return readLength() != nil
    }

    func parseTime() -> Date? {
      guard let tag = readTag(), let len = readLength() else { return nil }
      guard offset + len <= bytes.count else { return nil }
      let timeBytes = Array(bytes[offset ..< (offset + len)])
      offset += len
      guard let timeString = String(bytes: timeBytes, encoding: .ascii) else { return nil }

      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone(identifier: "UTC")

      if tag == 0x17 { // UTCTime
        formatter.dateFormat = "yyMMddHHmmss'Z'"
      } else if tag == 0x18 { // GeneralizedTime
        formatter.dateFormat = "yyyyMMddHHmmss'Z'"
      } else {
        return nil
      }
      return formatter.date(from: timeString)
    }

    // Certificate SEQUENCE
    guard enterSequence() else { return nil }
    // tbsCertificate SEQUENCE
    guard enterSequence() else { return nil }

    // version [0] EXPLICIT (optional)
    if offset < bytes.count, bytes[offset] == 0xA0 {
      guard skipElement() else { return nil }
    }
    // serialNumber
    guard skipElement() else { return nil }
    // signature algorithm
    guard skipElement() else { return nil }
    // issuer
    guard skipElement() else { return nil }
    // validity SEQUENCE
    guard enterSequence() else { return nil }
    // notBefore
    _ = parseTime()
    // notAfter
    return parseTime()
  }
}
