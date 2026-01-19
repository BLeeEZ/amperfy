//
//  DiscordRichPresence.swift
//  AmperfyKit
//
//  Created by Aarav Chourishi on 2026-01-19.
//  Copyright (c) 2026 Aarav Chourishi. All rights reserved.
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
import os.log

// MARK: - DiscordRichPresenceActivity

/// Represents a Discord Rich Presence activity payload
/// Designed to match Spotify's Discord integration style - sleek, professional, and minimal
public struct DiscordRichPresenceActivity: Codable, Sendable {
  public var type: Int?  // 0 = Playing, 2 = Listening, 3 = Watching
  public var state: String?
  public var details: String?
  public var timestamps: Timestamps?
  public var assets: Assets?
  public var party: Party?
  public var buttons: [Button]?
  
  public struct Timestamps: Codable, Sendable {
    public var start: Int64?
    public var end: Int64?
    
    public init(start: Int64? = nil, end: Int64? = nil) {
      self.start = start
      self.end = end
    }
  }
  
  public struct Assets: Codable, Sendable {
    public var largeImage: String?
    public var largeText: String?
    public var smallImage: String?
    public var smallText: String?
    
    enum CodingKeys: String, CodingKey {
      case largeImage = "large_image"
      case largeText = "large_text"
      case smallImage = "small_image"
      case smallText = "small_text"
    }
    
    public init(
      largeImage: String? = nil,
      largeText: String? = nil,
      smallImage: String? = nil,
      smallText: String? = nil
    ) {
      self.largeImage = largeImage
      self.largeText = largeText
      self.smallImage = smallImage
      self.smallText = smallText
    }
  }
  
  public struct Party: Codable, Sendable {
    public var id: String?
    public var size: [Int]?
  }
  
  public struct Button: Codable, Sendable {
    public var label: String
    public var url: String
    
    public init(label: String, url: String) {
      self.label = label
      self.url = url
    }
  }
  
  public init(
    type: Int? = nil,
    state: String? = nil,
    details: String? = nil,
    timestamps: Timestamps? = nil,
    assets: Assets? = nil,
    party: Party? = nil,
    buttons: [Button]? = nil
  ) {
    self.type = type
    self.state = state
    self.details = details
    self.timestamps = timestamps
    self.assets = assets
    self.party = party
    self.buttons = buttons
  }
}

// MARK: - Discord IPC (macOS / Mac Catalyst only)

#if targetEnvironment(macCatalyst) || os(macOS)

import Darwin
import Foundation

/// Discord IPC Client for macOS / Mac Catalyst
/// Supports two modes:
/// 1. Direct socket connection (non-sandboxed)
/// 2. AppleScript bridge (sandboxed) - uses `do shell script` to run outside sandbox
private final class DiscordIPC: @unchecked Sendable {
  
  // Discord IPC opcodes
  private enum Opcode: UInt32 {
    case handshake = 0
    case frame = 1
    case close = 2
    case ping = 3
    case pong = 4
  }
  
  private var socketFD: Int32 = -1
  private let applicationId: String
  private var isConnected = false
  private let queue = DispatchQueue(label: "com.amperfy.discord.ipc", qos: .utility)
  
  init(applicationId: String) {
    self.applicationId = applicationId
  }
  
  deinit {
    disconnect()
  }
  
  /// Connect to Discord IPC
  func connect() -> Bool {
    guard !isConnected else { return true }
    
    // Discord IPC socket locations vary by system
    // On macOS, it's typically in the user's DARWIN_USER_TEMP_DIR
    // Sandboxed apps (like Mac Catalyst) have a different NSTemporaryDirectory,
    // so we need to find the real system temp directory
    
    var socketPaths: [String] = []
    
    // 1. Try to get the real system temp directory using confstr
    var size = confstr(_CS_DARWIN_USER_TEMP_DIR, nil, 0)
    if size > 0 {
      var buffer = [CChar](repeating: 0, count: size)
      confstr(_CS_DARWIN_USER_TEMP_DIR, &buffer, size)
      let systemTmpDir = String(cString: buffer)
      os_log(.debug, "Discord IPC: System temp dir from confstr: %{public}@", systemTmpDir)
      for i in 0..<10 {
        socketPaths.append("\(systemTmpDir)discord-ipc-\(i)")
      }
    }
    
    // 2. Try environment variable TMPDIR
    if let envTmpDir = ProcessInfo.processInfo.environment["TMPDIR"] {
      os_log(.debug, "Discord IPC: TMPDIR env: %{public}@", envTmpDir)
      for i in 0..<10 {
        let path = "\(envTmpDir)discord-ipc-\(i)"
        if !socketPaths.contains(path) {
          socketPaths.append(path)
        }
      }
    }
    
    // 3. Add NSTemporaryDirectory paths (for non-sandboxed apps)
    let appTmpDir = NSTemporaryDirectory()
    os_log(.debug, "Discord IPC: NSTemporaryDirectory: %{public}@", appTmpDir)
    for i in 0..<10 {
      let path = "\(appTmpDir)discord-ipc-\(i)"
      if !socketPaths.contains(path) {
        socketPaths.append(path)
      }
    }
    
    // 4. Try /tmp as fallback
    for i in 0..<10 {
      socketPaths.append("/tmp/discord-ipc-\(i)")
    }
    
    // 5. Search /var/folders for discord-ipc sockets
    let varFoldersBase = "/var/folders"
    let fileManager = FileManager.default
    
    // Check if we can even access /var/folders
    if fileManager.fileExists(atPath: varFoldersBase) {
      os_log(.debug, "Discord IPC: Can see /var/folders exists")
    } else {
      os_log(.debug, "Discord IPC: Cannot see /var/folders (sandbox?)")
    }
    
    if let topLevel = try? fileManager.contentsOfDirectory(atPath: varFoldersBase) {
      os_log(.debug, "Discord IPC: Found %d dirs in /var/folders", topLevel.count)
      for dir1 in topLevel {
        let level1 = "\(varFoldersBase)/\(dir1)"
        if let secondLevel = try? fileManager.contentsOfDirectory(atPath: level1) {
          for dir2 in secondLevel {
            let tempPath = "\(level1)/\(dir2)/T"
            for i in 0..<10 {
              let socketPath = "\(tempPath)/discord-ipc-\(i)"
              if fileManager.fileExists(atPath: socketPath) {
                os_log(.info, "Discord IPC: Found socket at %{public}@", socketPath)
                socketPaths.insert(socketPath, at: 0) // Prioritize found sockets
              }
            }
          }
        }
      }
    } else {
      os_log(.debug, "Discord IPC: Cannot list /var/folders contents (sandbox restriction)")
    }
    
    os_log(.debug, "Discord IPC: Trying %d socket paths", socketPaths.count)
    
    // Try all paths
    for path in socketPaths {
      if tryConnect(to: path) {
        return true
      }
    }
    
    os_log(.error, "Discord IPC: Could not find Discord socket. Is Discord running?")
    return false
  }
  
  private func tryConnect(to path: String) -> Bool {
    // Check if socket exists
    guard FileManager.default.fileExists(atPath: path) else {
      return false
    }
    
    // Create socket
    socketFD = socket(AF_UNIX, SOCK_STREAM, 0)
    guard socketFD >= 0 else {
      os_log(.error, "Discord IPC: Failed to create socket")
      return false
    }
    
    // Set SO_NOSIGPIPE to prevent SIGPIPE signal when Discord closes connection
    var noSigPipe: Int32 = 1
    setsockopt(socketFD, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
    
    // Connect to Unix socket
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    
    _ = withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
      path.withCString { cstr in
        strcpy(ptr, cstr)
      }
    }
    
    let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
    let result = withUnsafePointer(to: &addr) { ptr in
      ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
        Darwin.connect(socketFD, sockaddrPtr, addrLen)
      }
    }
    
    guard result == 0 else {
      close(socketFD)
      socketFD = -1
      return false
    }
    
    // Send handshake
    if sendHandshake() {
      isConnected = true
      os_log(.info, "Discord IPC: Connected via %{public}@", path)
      return true
    }
    
    close(socketFD)
    socketFD = -1
    return false
  }
  
  private func sendHandshake() -> Bool {
    let handshake: [String: Any] = [
      "v": 1,
      "client_id": applicationId
    ]
    
    guard let data = try? JSONSerialization.data(withJSONObject: handshake) else {
      return false
    }
    
    return send(opcode: .handshake, data: data) && receiveResponse()
  }
  
  private func send(opcode: Opcode, data: Data) -> Bool {
    guard socketFD >= 0 else { return false }
    
    // Discord IPC frame format:
    // [opcode: 4 bytes LE] [length: 4 bytes LE] [data: length bytes]
    var header = Data(count: 8)
    header.withUnsafeMutableBytes { ptr in
      ptr.storeBytes(of: opcode.rawValue.littleEndian, toByteOffset: 0, as: UInt32.self)
      ptr.storeBytes(of: UInt32(data.count).littleEndian, toByteOffset: 4, as: UInt32.self)
    }
    
    let packet = header + data
    
    // Use MSG_NOSIGNAL equivalent on macOS (SO_NOSIGPIPE) to prevent SIGPIPE crash
    // when Discord closes the connection
    let sent = packet.withUnsafeBytes { ptr in
      Darwin.send(socketFD, ptr.baseAddress, packet.count, 0)
    }
    
    if sent < 0 {
      let error = errno
      os_log(.debug, "Discord IPC: Send failed with errno %d", error)
      return false
    }
    
    return sent == packet.count
  }
  
  private func receiveResponse() -> Bool {
    guard socketFD >= 0 else { return false }
    
    var header = [UInt8](repeating: 0, count: 8)
    let headerRead = recv(socketFD, &header, 8, 0)
    
    guard headerRead == 8 else { return false }
    
    let length = Data(header[4..<8]).withUnsafeBytes { ptr in
      ptr.load(as: UInt32.self).littleEndian
    }
    
    guard length > 0 && length < 65536 else { return false }
    
    var body = [UInt8](repeating: 0, count: Int(length))
    let bodyRead = recv(socketFD, &body, Int(length), 0)
    
    return bodyRead == Int(length)
  }
  
  /// Set Rich Presence activity
  func setActivity(_ activity: DiscordRichPresenceActivity?) {
    queue.async { [self] in
      self.setActivitySync(activity)
    }
  }
  
  private func setActivitySync(_ activity: DiscordRichPresenceActivity?) {
    // Try direct socket connection first
    if !isConnected {
      if !connect() {
        // Direct connection failed, try AppleScript fallback (for sandboxed apps)
        os_log(.info, "Discord IPC: Direct connection failed, trying AppleScript fallback")
        if sendActivityViaAppleScript(activity) {
          os_log(.info, "Discord IPC: Activity sent via AppleScript")
        } else {
          os_log(.error, "Discord IPC: AppleScript fallback also failed")
        }
        return
      }
    }
    
    let args: [String: Any]
    if let activity = activity {
      var activityDict: [String: Any] = [:]
      
      // Activity type: 0 = Playing, 2 = Listening, 3 = Watching
      if let type = activity.type {
        activityDict["type"] = type
      }
      
      if let details = activity.details {
        activityDict["details"] = details
      }
      if let state = activity.state {
        activityDict["state"] = state
      }
      if let timestamps = activity.timestamps {
        var ts: [String: Any] = [:]
        if let start = timestamps.start { ts["start"] = start }
        if let end = timestamps.end { ts["end"] = end }
        if !ts.isEmpty { activityDict["timestamps"] = ts }
      }
      if let assets = activity.assets {
        var assetsDict: [String: Any] = [:]
        if let largeImage = assets.largeImage { assetsDict["large_image"] = largeImage }
        if let largeText = assets.largeText { assetsDict["large_text"] = largeText }
        if let smallImage = assets.smallImage { assetsDict["small_image"] = smallImage }
        if let smallText = assets.smallText { assetsDict["small_text"] = smallText }
        if !assetsDict.isEmpty { activityDict["assets"] = assetsDict }
      }
      
      args = [
        "pid": ProcessInfo.processInfo.processIdentifier,
        "activity": activityDict
      ]
    } else {
      args = [
        "pid": ProcessInfo.processInfo.processIdentifier
      ]
    }
    
    let payload: [String: Any] = [
      "cmd": "SET_ACTIVITY",
      "args": args,
      "nonce": UUID().uuidString
    ]
    
    guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
      return
    }
    
    if send(opcode: .frame, data: data) {
      _ = receiveResponse()
      if activity != nil {
        os_log(.debug, "Discord IPC: Activity updated")
      } else {
        os_log(.debug, "Discord IPC: Activity cleared")
      }
    } else {
      isConnected = false
      os_log(.error, "Discord IPC: Direct send failed, trying AppleScript fallback")
      // Try AppleScript as fallback
      if sendActivityViaAppleScript(activity) {
        os_log(.info, "Discord IPC: Activity sent via AppleScript fallback")
      }
    }
  }
  
  /// Disconnect from Discord IPC
  func disconnect() {
    guard socketFD >= 0 else { return }
    close(socketFD)
    socketFD = -1
    isConnected = false
    os_log(.info, "Discord IPC: Disconnected")
  }
  
  // MARK: - AppleScript Fallback (for sandboxed apps)
  
  /// Try to send activity via AppleScript (works in sandbox)
  /// This uses `do shell script` which runs outside the sandbox
  private func sendActivityViaAppleScript(_ activity: DiscordRichPresenceActivity?) -> Bool {
    // Build the JSON payload
    let args: [String: Any]
    if let activity = activity {
      var activityDict: [String: Any] = [:]
      
      if let type = activity.type {
        activityDict["type"] = type
      }
      if let details = activity.details {
        activityDict["details"] = details
      }
      if let state = activity.state {
        activityDict["state"] = state
      }
      if let timestamps = activity.timestamps {
        var ts: [String: Any] = [:]
        if let start = timestamps.start { ts["start"] = start }
        if let end = timestamps.end { ts["end"] = end }
        if !ts.isEmpty { activityDict["timestamps"] = ts }
      }
      if let assets = activity.assets {
        var assetsDict: [String: Any] = [:]
        if let largeImage = assets.largeImage { assetsDict["large_image"] = largeImage }
        if let largeText = assets.largeText { assetsDict["large_text"] = largeText }
        if let smallImage = assets.smallImage { assetsDict["small_image"] = smallImage }
        if let smallText = assets.smallText { assetsDict["small_text"] = smallText }
        if !assetsDict.isEmpty { activityDict["assets"] = assetsDict }
      }
      
      args = [
        "pid": ProcessInfo.processInfo.processIdentifier,
        "activity": activityDict
      ]
    } else {
      args = [
        "pid": ProcessInfo.processInfo.processIdentifier
      ]
    }
    
    let payload: [String: Any] = [
      "cmd": "SET_ACTIVITY",
      "args": args,
      "nonce": UUID().uuidString
    ]
    
    guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
          let jsonString = String(data: jsonData, encoding: .utf8) else {
      return false
    }
    
    // Escape the JSON for shell
    let escapedJson = jsonString.replacingOccurrences(of: "\\", with: "\\\\")
                                .replacingOccurrences(of: "\"", with: "\\\"")
                                .replacingOccurrences(of: "'", with: "'\\''")
    
    // Build the shell script that will connect to Discord IPC
    let shellScript = """
    #!/bin/bash
    TMPDIR_PATH=$(getconf DARWIN_USER_TEMP_DIR)
    SOCKET_PATH="${TMPDIR_PATH}discord-ipc-0"
    
    if [ ! -S "$SOCKET_PATH" ]; then
      exit 1
    fi
    
    # Application ID for handshake
    APP_ID="\(applicationId)"
    
    # Send handshake
    HANDSHAKE='{"v":1,"client_id":"'$APP_ID'"}'
    HANDSHAKE_LEN=${#HANDSHAKE}
    
    # Create the IPC frame (opcode 0 = handshake, then length, then data)
    # Using Python for binary data handling
    python3 -c "
    import socket
    import struct
    import json
    
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect('$SOCKET_PATH')
    
    # Handshake
    handshake = json.dumps({'v': 1, 'client_id': '$APP_ID'}).encode()
    sock.send(struct.pack('<II', 0, len(handshake)) + handshake)
    sock.recv(1024)
    
    # Activity
    activity = '\(escapedJson)'.encode()
    sock.send(struct.pack('<II', 1, len(activity)) + activity)
    sock.recv(1024)
    sock.close()
    " 2>/dev/null
    """
    
    // Execute via AppleScript's do shell script (runs outside sandbox)
    let appleScript = """
    do shell script "\(shellScript.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))"
    """
    
    var error: NSDictionary?
    if let script = NSAppleScript(source: appleScript) {
      script.executeAndReturnError(&error)
      if let error = error {
        os_log(.debug, "Discord AppleScript error: %{public}@", error.description)
        return false
      }
      return true
    }
    return false
  }
}

#endif

// MARK: - DiscordRichPresenceManager

/// Manages Discord Rich Presence integration for displaying currently playing tracks
/// macOS: Uses Discord IPC protocol via Unix domain sockets
/// iOS: Feature not available (Discord doesn't support iOS RPC)
@MainActor
public class DiscordRichPresenceManager {
  
  // MARK: - Properties
  
  /// Discord Application ID for Amperfy
  /// Register your own at https://discord.com/developers/applications
  /// Add assets named: "amperfy_logo", "playing", "paused" in Rich Presence > Art Assets
  private let applicationId = "1462842598036082720"
  
  private var isEnabled: Bool = false
  private var lastUpdateTime: Date = .distantPast
  private let minimumUpdateInterval: TimeInterval = 15.0
  
  private weak var musicPlayer: AudioPlayer?
  private weak var backendAudioPlayer: BackendAudioPlayer?
  private let storage: PersistentStorage
  
  #if targetEnvironment(macCatalyst) || os(macOS)
  private var discordIPC: DiscordIPC?
  #endif
  
  /// Current presence data for external access
  public private(set) var currentPresenceData: DiscordPresenceData?
  
  /// Whether Discord Rich Presence is available on this platform
  /// Only available on macOS when NOT sandboxed (direct distribution builds)
  public static var isAvailable: Bool {
    #if targetEnvironment(macCatalyst) || os(macOS)
    // Check if app is sandboxed
    let dominated = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    return !dominated
    #else
    return false
    #endif
  }
  
  // MARK: - Initialization
  
  init(
    musicPlayer: AudioPlayer,
    backendAudioPlayer: BackendAudioPlayer,
    storage: PersistentStorage
  ) {
    self.musicPlayer = musicPlayer
    self.backendAudioPlayer = backendAudioPlayer
    self.storage = storage
    
    #if targetEnvironment(macCatalyst) || os(macOS)
    discordIPC = DiscordIPC(applicationId: applicationId)
    #endif
  }
  
  // MARK: - Public Methods
  
  /// Enable or disable Discord Rich Presence
  public func setEnabled(_ enabled: Bool) {
    isEnabled = enabled
    
    #if targetEnvironment(macCatalyst) || os(macOS)
    if enabled {
      if musicPlayer?.currentlyPlaying != nil {
        updatePresence()
      }
    } else {
      clearPresence()
      discordIPC?.disconnect()
    }
    #endif
  }
  
  /// Force update presence (ignores rate limiting)
  public func forceUpdatePresence() {
    guard isEnabled else { return }
    lastUpdateTime = .distantPast
    updatePresence()
  }
  
  /// Update presence with current playback state
  public func updatePresence() {
    #if targetEnvironment(macCatalyst) || os(macOS)
    guard isEnabled else { return }
    
    // Rate limiting
    let now = Date()
    guard now.timeIntervalSince(lastUpdateTime) >= minimumUpdateInterval else { return }
    lastUpdateTime = now
    
    guard let player = musicPlayer,
          let backend = backendAudioPlayer,
          let playable = player.currentlyPlaying else {
      clearPresence()
      return
    }
    
    let activity = createActivity(for: playable, backend: backend)
    
    // Update presence data
    currentPresenceData = DiscordPresenceData(
      songTitle: playable.title,
      artistName: playable.creatorName,
      albumName: playable.asSong?.album?.name,
      albumArtworkURL: nil,
      isPlaying: backend.isPlaying,
      elapsedTime: backend.elapsedTime,
      duration: backend.duration
    )
    
    discordIPC?.setActivity(activity)
    
    NotificationCenter.default.post(
      name: .discordPresenceUpdated,
      object: self,
      userInfo: ["activity": activity]
    )
    #endif
  }
  
  /// Clear the current presence
  public func clearPresence() {
    currentPresenceData = nil
    
    #if targetEnvironment(macCatalyst) || os(macOS)
    discordIPC?.setActivity(nil)
    #endif
    
    NotificationCenter.default.post(
      name: .discordPresenceUpdated,
      object: self,
      userInfo: [:]
    )
  }
  
  // MARK: - Private Methods
  
  private func createActivity(
    for playable: AbstractPlayable,
    backend: BackendAudioPlayer
  ) -> DiscordRichPresenceActivity {
    let artistName = playable.creatorName
    let songTitle = playable.title
    let albumName = playable.asSong?.album?.name
    
    // Calculate timestamps for progress bar
    let elapsedTime = backend.elapsedTime
    let duration = backend.duration
    let startTimestamp = Int64(Date().timeIntervalSince1970 - elapsedTime)
    let endTimestamp = duration > 0 ? startTimestamp + Int64(duration) : nil
    
    // Build details - Song title only (first line)
    let details = String(songTitle.prefix(128))
    
    // Build state string - "by Artist" (second line)
    var stateString: String? = nil
    if !artistName.isEmpty {
      stateString = "by \(String(artistName.prefix(128)))"
    }
    
    // Create activity
    // Type 2 = Listening (shows music icon instead of game controller)
    var activity = DiscordRichPresenceActivity()
    activity.type = 2  // Listening
    activity.details = details
    activity.state = stateString
    
    // Timestamps for progress bar (only when playing)
    // This shows elapsed time and remaining time in Discord
    if backend.isPlaying && duration > 0 {
      activity.timestamps = DiscordRichPresenceActivity.Timestamps(
        start: startTimestamp,
        end: endTimestamp
      )
    }
    
    // Assets configuration:
    // - largeImage: Album art or app logo (upload to Discord Developer Portal as "album_art" or use "amperfy_logo")
    // - largeText: Album name (shown on hover)
    // - smallImage: Play/pause indicator
    // - smallText: Status text (shown on hover)
    //
    // To use album art, upload images to Discord Developer Portal → Rich Presence → Art Assets
    // Name them: "amperfy_logo", "playing", "paused"
    activity.assets = DiscordRichPresenceActivity.Assets(
      largeImage: "amperfy_logo",
      largeText: albumName ?? "Amperfy",
      smallImage: backend.isPlaying ? "playing" : "paused",
      smallText: backend.isPlaying ? "Playing" : "Paused"
    )
    
    return activity
  }
}

// MARK: - MusicPlayable

extension DiscordRichPresenceManager: MusicPlayable {
  
  public func didStartPlayingFromBeginning() {
    os_log(.info, "Discord: didStartPlayingFromBeginning called")
    // Force update on play start (ignore rate limit)
    lastUpdateTime = .distantPast
    updatePresence()
  }
  
  public func didStartPlaying() {
    os_log(.info, "Discord: didStartPlaying called")
    // Force update on play start (ignore rate limit)
    lastUpdateTime = .distantPast
    updatePresence()
  }
  
  public func didPause() {
    updatePresence()
  }
  
  public func didStopPlaying() {
    clearPresence()
  }
  
  public func didElapsedTimeChange() {
    // Don't update on every elapsed time change - too frequent
  }
  
  public func didPlaylistChange() {
    updatePresence()
  }
  
  public func didArtworkChange() {
    // Artwork changes don't affect Discord presence directly
  }
  
  public func didShuffleChange() {}
  
  public func didRepeatChange() {}
  
  public func didPlaybackRateChange() {}
}

// MARK: - Notification Extension

public extension Notification.Name {
  static let discordPresenceUpdated = Notification.Name("discordPresenceUpdated")
}

// MARK: - DiscordPresenceData

/// Public struct for accessing current Discord presence data
public struct DiscordPresenceData: Sendable {
  public let songTitle: String?
  public let artistName: String?
  public let albumName: String?
  public let albumArtworkURL: URL?
  public let isPlaying: Bool
  public let elapsedTime: TimeInterval
  public let duration: TimeInterval
  
  public init(
    songTitle: String?,
    artistName: String?,
    albumName: String?,
    albumArtworkURL: URL?,
    isPlaying: Bool,
    elapsedTime: TimeInterval,
    duration: TimeInterval
  ) {
    self.songTitle = songTitle
    self.artistName = artistName
    self.albumName = albumName
    self.albumArtworkURL = albumArtworkURL
    self.isPlaying = isPlaying
    self.elapsedTime = elapsedTime
    self.duration = duration
  }
  
  /// Formatted elapsed time (e.g., "2:34")
  public var formattedElapsedTime: String {
    formatTime(elapsedTime)
  }
  
  /// Formatted duration (e.g., "4:12")
  public var formattedDuration: String {
    formatTime(duration)
  }
  
  /// Progress as percentage (0.0 to 1.0)
  public var progress: Double {
    guard duration > 0 else { return 0 }
    return min(1.0, max(0.0, elapsedTime / duration))
  }
  
  /// Formatted progress string (e.g., "2:34 / 4:12")
  public var formattedProgress: String {
    "\(formattedElapsedTime) / \(formattedDuration)"
  }
  
  /// Display string for Discord status
  public var displayString: String {
    var result = songTitle ?? "Unknown"
    if let artist = artistName, !artist.isEmpty {
      result += " by \(artist)"
    }
    return result
  }
  
  private func formatTime(_ time: TimeInterval) -> String {
    let totalSeconds = Int(time)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60
    
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
      return String(format: "%d:%02d", minutes, seconds)
    }
  }
  
  /// Convert to dictionary for serialization
  public var asDictionary: [String: Any] {
    var dict: [String: Any] = [
      "isPlaying": isPlaying,
      "elapsedTime": elapsedTime,
      "duration": duration,
      "progress": progress,
      "formattedProgress": formattedProgress
    ]
    if let title = songTitle { dict["songTitle"] = title }
    if let artist = artistName { dict["artistName"] = artist }
    if let album = albumName { dict["albumName"] = album }
    if let artworkURL = albumArtworkURL { dict["albumArtworkURL"] = artworkURL.absoluteString }
    return dict
  }
}
