//
//  Created by Dimitrios Chatzieleftheriou on 20/03/2024.
//  Copyright © 2020 Decimal. All rights reserved.
//

import Foundation
import OSLog

// MARK: - MP4Atom

struct MP4Atom: Equatable, CustomDebugStringConvertible {
  let type: Int
  let size: Int
  let offset: Int
  var data: Data?

  var isFreeSpaceAtom: Bool {
    type == Atoms.free || type == Atoms.skip || type == Atoms.wide
  }

  var debugDescription: String {
    "[Atom][size: \(size))][type: \(Atoms.integerToFourCC(type) ?? "")][offset: \(offset)]"
  }
}

// MARK: - Mp4OptimizeInfo

struct Mp4OptimizeInfo: Equatable {
  let moovOffset: Int
  let moovSize: Int
}

// MARK: - Atoms

/// These are some atoms, helpful for audio mp4
enum Atoms {
  static var ftyp: Int { fourCcToInt("ftyp") }
  static var moov: Int { fourCcToInt("moov") }
  static var mdat: Int { fourCcToInt("mdat") }
  static var free: Int { fourCcToInt("free") }
  static var skip: Int { fourCcToInt("skip") }
  static var wide: Int { fourCcToInt("wide") }

  static var cmov: Int { fourCcToInt("cmov") }
  static var stco: Int { fourCcToInt("stco") }
  static var co64: Int { fourCcToInt("co64") }

  static var atomPreampleSize: Int = 8

  static func fourCcToInt(_ fourCc: String) -> Int {
    let data = fourCc.data(using: .ascii)!
    return Int(bigEndian: Int(data: data))
  }

  static func integerToFourCC(_ value: Int) -> String? {
    guard value >= 0, value <= 0xFFFF_FFFF else {
      return nil // Integer value out of range
    }

    var bytes: [UInt8] = []
    bytes.append(UInt8((value >> 24) & 0xFF))
    bytes.append(UInt8((value >> 16) & 0xFF))
    bytes.append(UInt8((value >> 8) & 0xFF))
    bytes.append(UInt8(value & 0xFF))

    let data = Data(bytes)
    return String(data: data, encoding: .ascii)
  }
}

// MARK: - Mp4RestructureError

enum Mp4RestructureError: Error {
  case unableToRestructureData
  case missingMoovData
  case invalidMoovAtom
  case invalidAtomSize
  case invalidAtomType
  case invalidOffset
  case missingMdatAtom
  case missingMoovAtom
  case compressedAtomNotSupported
  case nonOptimizedMp4AndServerCannotSeek
  case networkError(Error)
}

// MARK: - OptimizeCheckResult

enum OptimizeCheckResult: Equatable {
  case optimized
  case needsRestructure(moovOffset: Int)
  case undetermined
}

// MARK: - Mp4Restructure

final class Mp4Restructure {
  private var atomOffset: Int = 0
  private var atoms: [MP4Atom] = []
  private var ftyp: MP4Atom?
  private var foundMoov = false
  private var foundMdat = false

  private(set) var dataOptimized: Bool = false

  private var moovAtomSize: Int = 0

  func clear() {
    atomOffset = 0
    atoms = []
    ftyp = nil
    foundMdat = false
    foundMoov = false
  }

  /// Adjust the seekOffset of subtracting the moovAtomSize
  /// - Parameter offset: A byte offset
  /// - Returns: An adjusted byte offset
  func seekAdjusted(offset: Int) -> Int {
    offset - moovAtomSize
  }

  func restructureMoov(data: Data) throws -> (initialData: Data, mdatOffset: Int) {
    let (atomData, moovSize) = try doRestructureMoov(data: data)
    moovAtomSize = moovSize
    guard let mdatIndex = atoms.firstIndex(where: { $0.type == Atoms.mdat }) else {
      throw Mp4RestructureError.missingMdatAtom
    }
    let mdatAtom = atoms[mdatIndex]
    let atoms = Array(atoms[..<mdatIndex])
    let dataOfAtomsBefore = atoms.filter { $0.data != nil }.compactMap(\.data)
    let accumulatedInitialData = dataOfAtomsBefore.reduce(into: Data()) { partialResult, data in
      partialResult.append(data)
    }
    let initialData = accumulatedInitialData + atomData
    let mdatOffset: Int
    if let ftyp = ftyp {
      mdatOffset = ftyp.offset + ftyp.size
    } else {
      let freeSpaceAtoms = atoms.filter(\.isFreeSpaceAtom)
      let freeSpaceSize = freeSpaceAtoms.reduce(into: 0) { partialResult, atom in
        partialResult += atom.size
      }
      mdatOffset = mdatAtom.offset - freeSpaceSize
    }
    dataOptimized = true
    return (initialData, mdatOffset)
  }

  /// Incrementally checks if the MP4 is optimized. Returns tri-state result.
  func checkIsOptimized(data: Data) throws -> OptimizeCheckResult {
    while atomOffset + 8 <= data.count {
      var atomSize: Int = try Int(getInteger(data: data, offset: atomOffset) as UInt32)
      let atomType: Int = try Int(getInteger(data: data, offset: atomOffset + 4) as UInt32)
      var headerSize = 8

      // Handle extended size (64-bit)
      if atomSize == 1 {
        if atomOffset + 16 > data.count {
          // Mark presence from header only to allow early decisions
          switch atomType {
          case Atoms.ftyp:
            if ftyp == nil {
              ftyp = MP4Atom(type: atomType, size: Int.max, offset: atomOffset, data: nil)
            }
          case Atoms.mdat:
            foundMdat = true
          case Atoms.moov:
            foundMoov = true
          default:
            break
          }
          if ftyp != nil, foundMoov, !foundMdat {
            Logger.debug("🕵️ detected an optimized mp4", category: .generic)
            return .optimized
          }
          // For non-optimized case we need a reliable moov offset; wait for more data
          break
        }
        let ext: UInt64 = try getInteger(data: data, offset: atomOffset + 8)
        atomSize = Int(ext)
        headerSize = 16
      } else if atomSize == 0 {
        // Size extends to EOF; still record what we saw and decide if possible
        switch atomType {
        case Atoms.ftyp:
          if ftyp == nil {
            // We only have header; store minimal info
            let start = atomOffset
            let end = min(data.count, atomOffset + headerSize)
            let ftypData = data[start ..< end]
            let ftyp = MP4Atom(type: atomType, size: 0, offset: atomOffset, data: ftypData)
            self.ftyp = ftyp
          }
        case Atoms.mdat:
          foundMdat = true
        case Atoms.moov:
          foundMoov = true
        default:
          break
        }
        if ftyp != nil, foundMoov, !foundMdat {
          Logger.debug("🕵️ detected an optimized mp4", category: .generic)
          return .optimized
        }
        // Otherwise we can't reliably compute moov offset yet
        break
      }

      // Bounds and sanity checks
      if atomSize < headerSize {
        break
      }
      if atomOffset + atomSize > data.count {
        // We have the header but not the full atom yet. Record presence for decision.
        switch atomType {
        case Atoms.ftyp:
          if ftyp == nil {
            ftyp = MP4Atom(type: atomType, size: atomSize, offset: atomOffset, data: nil)
          }
        case Atoms.moov:
          foundMoov = true
        case Atoms.mdat:
          foundMdat = true
        default:
          break
        }

        if ftyp != nil {
          if foundMoov, !foundMdat {
            Logger.debug(
              "🕵️ detected an optimized mp4 (header-only observation)",
              category: .generic
            )
            return .optimized
          }
        }
        break
      }

      switch atomType {
      case Atoms.ftyp:
        let start = atomOffset
        let end = atomOffset + atomSize
        let ftypData = data[start ..< end]
        let ftyp = MP4Atom(type: atomType, size: atomSize, offset: atomOffset, data: ftypData)
        self.ftyp = ftyp
        atoms.append(ftyp)
      case Atoms.mdat:
        let mdat = MP4Atom(type: atomType, size: atomSize, offset: atomOffset)
        atoms.append(mdat)
        foundMdat = true
      case Atoms.moov:
        let moov = MP4Atom(type: atomType, size: atomSize, offset: atomOffset)
        atoms.append(moov)
        foundMoov = true
      default:
        let atom = MP4Atom(type: atomType, size: atomSize, offset: atomOffset)
        atoms.append(atom)
      }

      if ftyp != nil {
        if foundMoov, !foundMdat {
          Logger.debug("🕵️ detected an optimized mp4", category: .generic)
          return .optimized
        } else if !foundMoov, foundMdat {
          Logger.debug("🕵️ detected a non-optimized mp4", category: .generic)
          let possibleMoovOffset = atomOffset + atomSize
          return .needsRestructure(moovOffset: possibleMoovOffset)
        }
      }

      atomOffset += atomSize
    }
    return .undetermined
  }

  /// logic taken from qt-faststart.c over at ffmpeg
  /// https://github.com/FFmpeg/FFmpeg/blob/b47b2c5b912558b639c8542993e1256f9c69e675/tools/qt-faststart.c
  private func doRestructureMoov(data: Data) throws -> (Data, Int) {
    var moovAtomSize = 0
    var moovAtomType = 0
    var originalData = ByteBuffer(data: data)
    var offset = 0
    // do search for moov within the new data
    while offset < originalData.length {
      moovAtomSize = Int(try originalData.getInteger() as UInt32)
      moovAtomType = Int(try originalData.getInteger() as UInt32)

      if moovAtomType == Atoms.moov {
        break
      }
      offset += moovAtomSize
    }

    // error if we couldn't find an moov type
    guard moovAtomType == Atoms.moov else {
      throw Mp4RestructureError.missingMoovAtom
    }

    originalData.offset = offset
    var moovAtom = ByteBuffer(size: moovAtomSize)
    let slicedData: Data = try originalData.readBytes(moovAtom.length)
    moovAtom.writeBytes(slicedData)
    moovAtom.rewind()

    if try Int(moovAtom.getInteger(12) as UInt32) == Atoms.cmov {
      Logger.debug("Compressed moov atom not supported", category: .generic)
      throw Mp4RestructureError.compressedAtomNotSupported
    }

    var atomType: Int
    var atomSize: Int

    // crawl through the atom and restructure offsets
    while moovAtom.bytesAvailable >= 8 {
      let atomHead = moovAtom.offset
      atomType = try Int(moovAtom.getInteger(atomHead + 4) as UInt32)

      if !(atomType == Atoms.stco || atomType == Atoms.co64) {
        moovAtom.offset += 1
        continue
      }

      atomSize = try Int(moovAtom.getInteger(atomHead) as UInt32)
      if atomSize > moovAtom.bytesAvailable {
        Logger.debug("aborting due to a bad size on an atom", category: .generic)
        throw Mp4RestructureError.unableToRestructureData
      }
      // we need to skip the offset by `12` which come from the bytes of [size/4][type/4][version/1][flags/3]
      // more info https://developer.apple.com/documentation/quicktime-file-format/chunk_offset_atom
      moovAtom.offset = atomHead + 12
      if moovAtom.bytesAvailable < 4 {
        Logger.debug("aborting due to a malformed atom", category: .generic)
        throw Mp4RestructureError.unableToRestructureData
      }

      // the next integer determines the `Number of entries`
      // https://developer.apple.com/documentation/quicktime-file-format/chunk_offset_atom/number_of_entries
      let numberOfOffsetEntries = try Int(moovAtom.getInteger() as UInt32)
      // Adjust by moov size
      let adjustDelta = moovAtomSize
      if atomType == Atoms.stco {
        Logger.debug("🏗️ patching stco atom...", category: .generic)
        if moovAtom.bytesAvailable < numberOfOffsetEntries * 4 {
          Logger.debug("aborting due to bad atom..", category: .generic)
          throw Mp4RestructureError.unableToRestructureData
        }

        for _ in 0 ..< numberOfOffsetEntries {
          let currentOffset = try Int(moovAtom.getInteger(moovAtom.offset) as UInt32)
          // adjust the offset by adding the size of moov atom
          let adjustOffset = currentOffset + adjustDelta

          if currentOffset < 0, adjustOffset >= 0 {
            throw Mp4RestructureError.unableToRestructureData
          }
          moovAtom.put(UInt32(adjustOffset).bigEndian)
        }
      } else if atomType == Atoms.co64 {
        Logger.debug("🏗️ patching co64 atom...", category: .generic)
        if moovAtom.bytesAvailable < numberOfOffsetEntries * 8 {
          Logger.debug("aborting due to bad atom..", category: .generic)
          throw Mp4RestructureError.unableToRestructureData
        }
        for _ in 0 ..< numberOfOffsetEntries {
          let currentOffset: Int = try moovAtom.getInteger(moovAtom.offset)
          // adjust the offset by adding the size of moov atom (write as big-endian 64-bit)
          moovAtom.put(UInt64(currentOffset + adjustDelta).bigEndian)
        }
      }
    }
    return (moovAtom.storage, moovAtomSize)
  }

  func getInteger<T: FixedWidthInteger>(data: Data, offset: Int) throws -> T {
    let sizeOfInteger = MemoryLayout<T>.size
    guard offset >= 0, offset + sizeOfInteger <= data.count else {
      throw ByteBuffer.Error.eof
    }
    let end = offset + sizeOfInteger
    return T(data: data[offset ..< end]).bigEndian
  }
}
