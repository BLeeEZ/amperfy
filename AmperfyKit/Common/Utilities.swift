//
//  Utilities.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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

import CoreData
import Foundation
import os.log
import UIKit

public typealias VoidFunctionCallback = () -> ()

// MARK: - CustomEquatable

public protocol CustomEquatable {
  func isEqualTo(_ other: CustomEquatable) -> Bool
}

extension CustomEquatable where Self: Equatable {
  public func isEqualTo(_ other: CustomEquatable) -> Bool {
    if let other = other as? Self { return self == other }
    return false
  }
}

// MARK: - Atomic

@propertyWrapper
public final class Atomic<Value>: Sendable {
  nonisolated(unsafe) private var value: Value
  private let lock = NSLock()

  public var wrappedValue: Value {
    get { lock.withLock { value } }
    set { lock.withLock { value = newValue } }
  }

  public init(wrappedValue value: Value) {
    self.value = value
  }
}

extension Bool {
  public mutating func toggle() {
    self = !self
  }

  public static func random(probabilityForTrueInPercent probability: Float) -> Bool {
    Float.random(in: 0 ..< 100) <= probability
  }
}

extension Int16 {
  public static func isValid(value: Int) -> Bool {
    !((value < Int16.min) || (value > Int16.max))
  }
}

extension Int32 {
  public static func isValid(value: Int) -> Bool {
    !((value < Int32.min) || (value > Int32.max))
  }
}

extension Int64 {
  public var asByteString: String {
    ByteCountFormatter.string(
      fromByteCount: self,
      countStyle: ByteCountFormatter.CountStyle.decimal
    )
  }
}

extension Int {
  public mutating func setOtherRandomValue(in targetRange: ClosedRange<Int>) {
    var newValue = 0
    repeat {
      newValue = Int.random(in: targetRange)
    } while newValue == self
    self = newValue
  }

  public func roundDownToFractionOf(_ value: Int) -> Int {
    (self / value) * value
  }

  public var asColonDurationString: String {
    var hourString = ""
    let hours = self / (60 * 60)
    if hours > 0 {
      hourString += "\(hours):"
    }
    let minutes = (self - (hours * 60 * 60)) / 60
    let seconds = self - ((hours * 60 * 60) + (minutes * 60))
    if hourString.isEmpty {
      return String(format: "%01d", minutes) + ":" + String(format: "%02d", seconds)
    } else {
      return hourString + String(format: "%02d", minutes) + ":" + String(format: "%02d", seconds)
    }
  }

  public var asDurationShortString: String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute]
    formatter.unitsStyle = .abbreviated
    return formatter.string(from: TimeInterval(self))!
  }

  public var asDurationString: String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = .abbreviated
    return formatter.string(from: TimeInterval(self))!
  }

  public var asMinuteString: String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.minute]
    formatter.unitsStyle = .short
    return formatter.string(from: TimeInterval(self))!
  }

  public var asDayString: String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.day]
    formatter.unitsStyle = .short
    return formatter.string(from: TimeInterval(self))!
  }
}

extension String {
  public func isFoundBy(searchText: String) -> Bool {
    lowercased().contains(searchText.lowercased())
  }

  public func isContainedIn(_ container: [String]) -> Bool {
    container.contains(self)
  }

  public var asIso8601Date: Date? {
    let dateFormatter = ISO8601DateFormatter()
    return dateFormatter.date(from: self)
  }

  public var asByteCount: Int? {
    guard !isEmpty else { return nil }
    if hasSuffix(" GB") {
      let stringSize = self[..<index(endIndex, offsetBy: -3)]
      guard let stringFloat = Float(stringSize) else { return nil }
      return Int(stringFloat * 1000 * 1000 * 1000)
    } else if hasSuffix(" MB") {
      let stringSize = self[..<index(endIndex, offsetBy: -3)]
      guard let stringFloat = Float(stringSize) else { return nil }
      return Int(stringFloat * 1000 * 1000)
    } else if hasSuffix(" KB") {
      let stringSize = self[..<index(endIndex, offsetBy: -3)]
      guard let stringFloat = Float(stringSize) else { return nil }
      return Int(stringFloat * 1000)
    } else if hasSuffix(" B") {
      let stringSize = self[..<index(endIndex, offsetBy: -2)]
      guard let stringFloat = Float(stringSize) else { return nil }
      return Int(stringFloat)
    } else {
      return nil
    }
  }

  public var asDurationInSeconds: Int? {
    let components = split { $0 == ":" }.compactMap { Int($0) }
    guard components.count == 3 else { return nil }
    return (components[0] * 60 * 24) + (components[1] * 60) + components[2]
  }

  public static var defaultSectionInital: String.Element {
    "?"
  }

  public var sectionInitial: String {
    guard !isEmpty else { return "?" }
    let initial = String(
      prefix(1).folding(options: .diacriticInsensitive, locale: nil)
        .uppercased()
    )
    if let _ = initial.rangeOfCharacter(from: CharacterSet.decimalDigits) {
      return "#"
    } else if let _ = initial
      .rangeOfCharacter(from: CharacterSet(charactersIn: String.uppercaseAsciiLetters)) {
      return initial
    } else if let _ = initial
      .rangeOfCharacter(from: CharacterSet.letters) { // japanese / chinese letters
      return "&"
    } else {
      return "?"
    }
  }

  public static var uppercaseAsciiLetters: String {
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  }

  public static func generateRandomString(ofLength length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0 ..< length).map { _ in letters.randomElement()! })
  }

  public func deletingPrefix(_ prefix: String) -> String {
    guard hasPrefix(prefix) else { return self }
    return String(dropFirst(prefix.count))
  }

  private var html2AttributedString: NSAttributedString? {
    Data(utf8).html2AttributedString
  }

  public var html2String: String {
    html2AttributedString?.string.html2AttributedString?.string ?? ""
  }
}

extension Dictionary where Value: Equatable {
  public func findKey(forValue val: Value) -> Key? {
    first(where: { $1 == val })?.key
  }
}

extension Array {
  public func object(at: Int) -> Element? {
    at < count ? self[at] : nil
  }

  public func chunked(intoSubarrayCount chunkCount: Int) -> [[Element]] {
    let chuckSize = Int(ceil(Float(count) / Float(chunkCount)))
    return chunked(intoSubarraySize: chuckSize)
  }

  public func chunked(intoSubarraySize size: Int) -> [[Element]] {
    guard count > 0 else { return [[Element]]() }
    return stride(from: 0, to: count, by: size).map {
      Array(self[$0 ..< Swift.min($0 + size, count)])
    }
  }

  /// Picks `n` random elements (partial Fisher-Yates shuffle approach)
  public subscript(randomPick pickCount: Int) -> [Element] {
    var copy = self
    let n = Swift.min(pickCount, count)
    for i in stride(from: count - 1, to: count - n - 1, by: -1) {
      copy.swapAt(i, Int(arc4random_uniform(UInt32(i + 1))))
    }
    return Array(copy.suffix(n))
  }

  public func prefix(upToAsArray: Int) -> [Element] {
    Array(prefix(upToAsArray))
  }
}

extension UIColor {
  public convenience init(hue: CGFloat, saturation: CGFloat, lightness: CGFloat, alpha: CGFloat) {
    precondition(
      0 ... 1 ~= hue &&
        0 ... 1 ~= saturation &&
        0 ... 1 ~= lightness &&
        0 ... 1 ~= alpha,
      "input range is out of range 0...1"
    )

    // from HSL TO HSB
    var newSaturation: CGFloat = 0.0
    let brightness = lightness + saturation * min(lightness, 1 - lightness)
    if brightness == 0 {
      newSaturation = 0.0
    } else {
      newSaturation = 2 * (1 - lightness / brightness)
    }
    self.init(hue: hue, saturation: newSaturation, brightness: brightness, alpha: alpha)
  }

  public func getHue(
    _ hue: UnsafeMutablePointer<CGFloat>?,
    saturation targetSaturation: UnsafeMutablePointer<CGFloat>?,
    lightness targetLightness: UnsafeMutablePointer<CGFloat>?,
    alpha targetAlpha: UnsafeMutablePointer<CGFloat>?
  )
    -> Bool {
    var saturation, brightness, alpha: CGFloat
    (saturation, brightness, alpha) = (0.0, 0.0, 0.0)
    getHue(hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
    // from HSB TO HSL
    var newSaturation: CGFloat = 0.0
    let lightness = brightness * (1 - saturation / 2)
    if lightness == 0 || lightness == 1 {
      newSaturation = 0.0
    } else {
      newSaturation = (brightness - lightness) / min(lightness, 1 - lightness)
    }

    targetSaturation?.pointee = newSaturation
    targetLightness?.pointee = lightness
    targetAlpha?.pointee = alpha
    return true
  }

  public func getWithLightness(of: CGFloat) -> UIColor {
    precondition(0 ... 1 ~= of, "input range is out of range 0...1")
    var hue, saturation, lightness, alpha: CGFloat
    (hue, saturation, lightness, alpha) = (0.0, 0.0, 0.0, 0.0)
    _ = getHue(&hue, saturation: &saturation, lightness: &lightness, alpha: &alpha)
    return UIColor(hue: hue, saturation: saturation, lightness: of, alpha: alpha)
  }

  // 007AFF
  // r:0 g:122 b:255
  public static var defaultBlue: UIColor {
    UIColor(displayP3Red: 0 / 255, green: 122 / 255, blue: 1.0, alpha: 1.0)
  }

  public static var gold: UIColor {
    UIColor(displayP3Red: 241 / 255, green: 194 / 255, blue: 66 / 255, alpha: 1.0)
  }

  public static var labelColor: UIColor {
    if #available(iOS 13.0, *) {
      return UIColor.label
    } else {
      return UIColor.black
    }
  }

  public static var redHeart: UIColor {
    .red.withAlphaComponent(0.8)
  }

  public static var fillColor: UIColor {
    if #available(iOS 13.0, *) {
      return UIColor.systemFill
    } else {
      return UIColor(displayP3Red: 217 / 255, green: 214 / 255, blue: 209 / 255, alpha: 1.0)
    }
  }

  public static var secondaryLabelColor: UIColor {
    if #available(iOS 13.0, *) {
      return UIColor.secondaryLabel
    } else {
      return UIColor.systemGray
    }
  }

  public static var backgroundColor: UIColor {
    if #available(iOS 13.0, *) {
      return UIColor.systemBackground
    } else {
      return UIColor.white
    }
  }
}

extension UIActivityIndicatorView {
  public static var defaultStyle: Style {
    if #available(iOS 13.0, *) {
      return .medium
    } else {
      return .gray
    }
  }
}

extension NSObject {
  public class var typeName: String {
    String(describing: self)
  }
}

extension NSData {
  public var sizeInByte: Int64 {
    Int64(length)
  }
}

extension Data {
  public static func fetch(fromUrlString urlString: String) -> Data? {
    var data: Data?
    guard let url = URL(string: urlString) else {
      return nil
    }
    do {
      let dataFromURL = try Data(contentsOf: url)
      data = dataFromURL
    } catch {}
    return data
  }

  public var sizeInByte: Int64 {
    Int64(count)
  }

  public func createLocalUrl(fileName: String? = nil) -> URL {
    let tempDirectoryURL = NSURL.fileURL(withPath: NSTemporaryDirectory(), isDirectory: true)
    let url = tempDirectoryURL.appendingPathComponent(fileName ?? UUID().uuidString)
    try! write(to: url, options: Data.WritingOptions.atomic)
    return url
  }

  public var html2AttributedString: NSAttributedString? {
    try? NSAttributedString(
      data: self,
      options: [
        .documentType: NSAttributedString.DocumentType.html,
        .characterEncoding: String.Encoding.utf8.rawValue,
      ],
      documentAttributes: nil
    )
  }

  public var html2String: String { html2AttributedString?.string.html2String ?? "" }
}

extension Date {
  public var asIso8601String: String {
    let dateFormatter = ISO8601DateFormatter()
    return dateFormatter.string(from: self)
  }

  public var asShortDayMonthString: String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "d. MMMM"
    dateFormatter.timeZone = NSTimeZone(name: "UTC")! as TimeZone
    return dateFormatter.string(from: self)
  }

  public var asShortHrMinString: String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .none
    dateFormatter.timeStyle = .short
    return dateFormatter.string(from: self)
  }
}

extension URLComponents {
  public mutating func addQueryItem(name: String, value: Int) {
    addQueryItem(name: name, value: String(value))
  }

  public mutating func addQueryItem(name: String, value: String) {
    let queryItem = URLQueryItem(name: name, value: value)
    var queryItems = queryItems ?? [URLQueryItem]()
    queryItems.append(queryItem)
    self.queryItems = queryItems
  }
}

extension Array {
  public func element(at index: Int) -> Element? {
    index < count ? self[index] : nil
  }
}

extension Array where Element: Equatable {
  public func allIndices(of element: Element) -> [Int] {
    enumerated().filter {
      $0.element == element
    }.map {
      $0.offset
    }
  }
}

extension Array where Element == String {
  public func sortAlphabeticallyAscending() -> [String] {
    sorted { $0.localizedStandardCompare($1) == ComparisonResult.orderedAscending }
  }

  public func sortAlphabeticallyDescending() -> [String] {
    sorted { $0.localizedStandardCompare($1) == ComparisonResult.orderedDescending }
  }
}

extension UIView {
  public func setGradientBackground(colorTop: UIColor, colorBottom: UIColor) {
    let gradientLayer = CAGradientLayer()
    gradientLayer.colors = [colorBottom.cgColor, colorTop.cgColor]
    gradientLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
    gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
    gradientLayer.locations = [0, 1]
    gradientLayer.frame = bounds
    layer.insertSublayer(gradientLayer, at: 0)
  }

  public var screenshot: UIImage? {
    UIGraphicsBeginImageContextWithOptions(layer.frame.size, false, 0)
    defer {
      UIGraphicsEndImageContext()
    }
    guard let context = UIGraphicsGetCurrentContext() else { return nil }
    layer.render(in: context)
    return UIGraphicsGetImageFromCurrentImageContext()
  }
}

extension UIAlertAction {
  public convenience init(
    title: String?,
    image: UIImage,
    style: Style,
    handler: ((UIAlertAction) -> ())? = nil
  ) {
    self.init(title: title, style: style, handler: handler)
    self.image = image
  }

  public var image: UIImage {
    get { value(forKey: "image") as? UIImage ?? UIImage() }
    set(image) { setValue(image, forKey: "image") }
  }
}

extension UIImage {
  public func averageColor() -> UIColor {
    var bitmap = [UInt8](repeating: 0, count: 4)

    let context = CIContext(options: nil)
    let cgImg = context.createCGImage(
      CoreImage.CIImage(cgImage: cgImage!),
      from: CoreImage.CIImage(cgImage: cgImage!).extent
    )

    let inputImage = CIImage(cgImage: cgImg!)
    let extent = inputImage.extent
    let inputExtent = CIVector(
      x: extent.origin.x,
      y: extent.origin.y,
      z: extent.size.width,
      w: extent.size.height
    )
    let filter = CIFilter(
      name: "CIAreaAverage",
      parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: inputExtent]
    )!
    let outputImage = filter.outputImage!
    let outputExtent = outputImage.extent
    assert(outputExtent.size.width == 1 && outputExtent.size.height == 1)

    // Render to bitmap.
    context.render(
      outputImage,
      toBitmap: &bitmap,
      rowBytes: 4,
      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
      format: CIFormat.RGBA8,
      colorSpace: CGColorSpaceCreateDeviceRGB()
    )

    // Compute result.
    let result = UIColor(
      red: CGFloat(bitmap[0]) / 255.0,
      green: CGFloat(bitmap[1]) / 255.0,
      blue: CGFloat(bitmap[2]) / 255.0,
      alpha: CGFloat(bitmap[3]) / 255.0
    )
    return result
  }

  public func invertedImage() -> UIImage {
    guard let cgImage = cgImage else { return UIImage() }
    let ciImage = CoreImage.CIImage(cgImage: cgImage)
    guard let filter = CIFilter(name: "CIColorInvert") else { return UIImage() }
    filter.setDefaults()
    filter.setValue(ciImage, forKey: kCIInputImageKey)
    let context = CIContext(options: nil)
    guard let outputImage = filter.outputImage else { return UIImage() }
    guard let outputImageCopy = context.createCGImage(outputImage, from: outputImage.extent)
    else { return UIImage() }
    return UIImage(cgImage: outputImageCopy, scale: scale, orientation: .up)
  }
}

extension UIDevice {
  public var totalDiskCapacityInByte: Int64? {
    let fileURL = URL(fileURLWithPath: "/")
    guard let values = try? fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey]),
          let capacity = values.volumeTotalCapacity else { return nil }
    return Int64(capacity)
  }

  public var availableDiskCapacityInByte: Int64? {
    let fileURL = URL(fileURLWithPath: "/")
    guard let values = try? fileURL.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
          let capacity = values.volumeAvailableCapacity else { return nil }
    return Int64(capacity)
  }
}
