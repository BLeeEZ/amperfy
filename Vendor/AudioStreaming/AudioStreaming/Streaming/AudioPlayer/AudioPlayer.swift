//
//  Created by Dimitrios Chatzieleftheriou on 01/06/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import AVFoundation
import CoreAudio
import OSLog

// MARK: - AudioPlayer

open class AudioPlayer {
  public weak var delegate: AudioPlayerDelegate?

  public var muted: Bool {
    get { playerContext.muted.value }
    set { playerContext.muted.write { $0 = newValue } }
  }

  /// The volume of the audio
  ///
  /// Defaults to 1.0. Valid ranges are 0.0 to 1.0
  /// The value is restricted from 0.0 to 1.0
  public var volume: Float {
    get { audioEngine.mainMixerNode.outputVolume }
    set { audioEngine.mainMixerNode.outputVolume = min(1.0, max(0.0, newValue)) }
  }

  /// The playback rate of the player.
  ///
  /// The default value is 1.0. Valid ranges are 1/32 to 32.0
  ///
  /// **NOTE:** Setting this to a value of more than `1.0` while playing a live broadcast stream would
  /// result in the audio being exhausted before it could fetch new data.
  public var rate: Float {
    get { rateNode.rate }
    set {
      rateNode.rate = newValue
      rateNode.bypass = (newValue == 1.0)
    }
  }

  /// The player's current state.
  public var state: AudioPlayerState {
    playerContext.state.value
  }

  /// Indicates the reason that the player stopped.
  public var stopReason: AudioPlayerStopReason {
    playerContext.stopReason.value
  }

  /// The duration of the audio, in seconds.
  ///
  /// **NOTE** In live audio playback this will be `0.0`
  ///
  /// - Returns: A `Double` value indicating the total duration.
  public var duration: Double {
    guard playerContext.internalState != .pendingNext else { return 0 }
    playerContext.entriesLock.lock()
    let playingEntry = playerContext.audioPlayingEntry
    playerContext.entriesLock.unlock()
    guard let entry = playingEntry else { return 0 }

    let entryDuration = entry.duration()
    let progress = progress
    if entryDuration < progress, entryDuration > 0 {
      return progress
    }
    return entryDuration
  }

  /// The progress of the audio playback, in seconds.
  public var progress: Double {
    guard playerContext.internalState != .pendingNext else { return 0 }
    playerContext.entriesLock.lock()
    let playingEntry = playerContext.audioPlayingEntry
    playerContext.entriesLock.unlock()
    guard let entry = playingEntry else { return 0 }
    entry.seekRequest.lock.lock()
    let seekRequested = entry.seekRequest.requested
    let seekTime = entry.seekRequest.time
    entry.seekRequest.lock.unlock()
    if seekRequested {
      return seekTime
    }
    return entry.progress
  }

  /// The number of audio frames that have been played
  public var framesPlayed: Int {
    guard playerContext.internalState != .pendingNext else { return 0 }
    playerContext.entriesLock.lock()
    let playingEntry = playerContext.audioPlayingEntry
    playerContext.entriesLock.unlock()
    guard let entry = playingEntry else { return 0 }
    return entry.framesPlayed
  }

  /// Indicates whether seeking is supported for the currently playing audio
  ///
  /// Returns `false` if:
  /// - The audio format doesn't support seeking (e.g., Ogg Vorbis streams)
  /// - The stream has no valid duration (e.g., live radio streams)
  ///
  /// Use this property to enable/disable seek controls in your UI
  public var isSeekable: Bool {
    guard playerContext.internalState != .pendingNext else { return true }

    playerContext.entriesLock.lock()
    let playingEntry = playerContext.audioPlayingEntry
    playerContext.entriesLock.unlock()
    guard let entry = playingEntry else { return true }

    // Check if format supports seeking (Ogg Vorbis doesn't)
    if entry.audioFileHint == kAudioFileOggType {
      return false
    }

    // Check if stream has a valid duration (live streams don't)
    let entryDuration = entry.duration()
    return entryDuration > 0
  }

  public private(set) var customAttachedNodes = [AVAudioNode]()

  /// The current configuration of the player.
  public let configuration: AudioPlayerConfiguration

  /// The loop mode for the audio player
  /// Defaults to `.off`.
  /// - Use `.single(times:)` to loop the current track
  /// - Use `.all(times:)` to loop the entire queue
  /// - Pass `nil` for times to loop infinitely, or a positive integer to loop that many times
  public var loopMode: AudioPlayerLoopMode = .off

  /// A Boolean value that indicates whether the audio engine is running.
  /// `true` if the engine is running, otherwise, `false`
  public var isEngineRunning: Bool { audioEngine.isRunning }

  /// The `AVAudioMixerNode` as created by the underlying audio engine
  public var mainMixerNode: AVAudioMixerNode {
    audioEngine.mainMixerNode
  }

  public var frameFiltering: FrameFiltering {
    frameFilterProcessor
  }

  /// An `AVAudioFormat` object for the canonical audio stream
  private let outputAudioFormat: AVAudioFormat = {
    let channelLayout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_MPEG_5_1_A)!
    return AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      // AirPods and the iPhone's output run at 48 kHz, so decoding to
      // 48 kHz resamples a track at most once (96 kHz halves exactly).
      sampleRate: 48000.0,
      interleaved: true,
      channelLayout: channelLayout
    )
  }()

  /// The last value passed to `AVAudioSession.setSupportsMultichannelContent`.
  private var declaredMultichannelContent: Bool?

  /// The format of the engine graph between the input and the output node.
  /// With `nil` the nodes take the device default (stereo), which would
  /// downmix multichannel tracks and lose the centre. Discrete channels pass
  /// through by index, also through `AVAudioUnitEQ`.
  private lazy var processingFormat = AVAudioFormat(
    standardFormatWithSampleRate: outputAudioFormat.sampleRate,
    channelLayout: AVAudioChannelLayout(
      layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | outputAudioFormat.channelCount
    )!
  )

  /// Keeps track of the player's state before being paused.
  private var stateBeforePaused: InternalState = .initial

  /// The underlying `AVAudioEngine` object
  private let audioEngine: AVAudioEngine
  /// An `AVAudioUnit` object that represents the audio player
  private(set) var player = AVAudioUnit()
  /// An `AVAudioUnitTimePitch` that controls the playback rate of the audio engine
  private let rateNode = AVAudioUnitTimePitch()

  /// An object representing the context of the audio render.
  /// Holds the audio buffer and in/out lists as required by the audio rendering
  private let rendererContext: AudioRendererContext
  /// An object representing the context of the player.
  /// Holds the player's state, current playing and reading entries.
  private let playerContext: AudioPlayerContext

  private let fileStreamProcessor: AudioFileStreamProcessor
  private let playerRenderProcessor: AudioPlayerRenderProcessor
  private let frameFilterProcessor: FrameFilterProcessor

  private let serializationQueue: DispatchQueue
  public let sourceQueue: DispatchQueue

  private let entryProvider: AudioEntryProviding

  var entriesQueue: PlayerQueueEntries

  /// Stores the original queue entries for loop all functionality
  private var originalQueueForLoop: [LoopEntryInfo] = []
  /// Tracks played entries for loop functionality
  private var playedEntries: [LoopEntryInfo] = []
  /// Tracks the current loop iteration (how many times we've looped so far)
  private var currentLoopIteration: Int = 0

  public init(configuration: AudioPlayerConfiguration = .default) {
    self.configuration = configuration.normalizeValues()
    let engine = AVAudioEngine()
    self.audioEngine = engine
    self.rendererContext = AudioRendererContext(
      configuration: configuration,
      outputAudioFormat: outputAudioFormat
    )
    self.playerContext = AudioPlayerContext()
    self.entriesQueue = PlayerQueueEntries()

    self.serializationQueue = DispatchQueue(label: "streaming.core.queue", qos: .userInitiated)
    self.sourceQueue = DispatchQueue(label: "source.queue", qos: .default)

    self.entryProvider = AudioEntryProvider(
      networkingClient: NetworkingClient(),
      underlyingQueue: sourceQueue,
      outputAudioFormat: outputAudioFormat
    )

    self.fileStreamProcessor = AudioFileStreamProcessor(
      playerContext: playerContext,
      rendererContext: rendererContext,
      outputAudioFormat: outputAudioFormat.basicStreamDescription
    )

    self.playerRenderProcessor = AudioPlayerRenderProcessor(
      playerContext: playerContext,
      rendererContext: rendererContext,
      outputAudioFormat: outputAudioFormat.basicStreamDescription
    )

    self.frameFilterProcessor = FrameFilterProcessor(
      mixerNodeProvider: {
        engine.mainMixerNode
      }
    )
    configPlayerContext()
    configPlayerNode()
    configureRateNode()
    setupEngine()
  }

  deinit {
    playerContext.audioPlayingEntry?.close()
    clearQueue()
    rendererContext.clean()
  }

  // MARK: Public

  /// Starts the audio playback for the given URL
  ///
  /// - parameter url: A `URL` specifying the audio context to be played
  public func play(url: URL) {
    play(url: url, headers: [:])
  }

  /// Starts the audio playback for the given URL
  ///
  /// - parameter url: A `URL` specifying the audio context to be played.
  /// - parameter headers: A `Dictionary` specifying any additional headers to be pass to the network request.
  public func play(url: URL, headers: [String: String]) {
    let audioEntry = entryProvider.provideAudioEntry(url: url, headers: headers)
    play(audioEntry: audioEntry)
  }

  /// Starts the audio playback for the given URL
  ///
  /// - parameter url: A `URL` specifying the audio context to be played.
  /// - parameter httpMethod: A `String` specifying the HTTP method to use (e.g. "GET", "POST").
  /// - parameter httpBody: A "Data" specifying the HTTP request body, if any.
  /// - parameter headers: A `Dictionary` specifying any additional headers to be pass to the network request.
  public func play(url: URL, httpMethod: String?, httpBody: Data?, headers: [String: String]) {
    let audioEntry = entryProvider.provideAudioEntry(
      url: url,
      httpMethod: httpMethod,
      httpBody: httpBody,
      headers: headers
    )
    play(audioEntry: audioEntry)
  }

  /// Starts the audio playback for the supplied stream
  ///
  /// - parameter source: A `CoreAudioStreamSource` that will providing streaming data
  /// - parameter entryId: A `String` that provides a unique id for this item
  /// - parameter format: An `AVAudioFormat` the format of this audio source
  public func play(source: CoreAudioStreamSource, entryId: String, format: AVAudioFormat) {
    let audioEntry = AudioEntry(
      source: source,
      entryId: AudioEntryId(id: entryId),
      outputAudioFormat: format
    )
    play(audioEntry: audioEntry)
  }

  private func play(audioEntry: AudioEntry) {
    audioEntry.delegate = self

    checkRenderWaitingAndNotifyIfNeeded()
    serializationQueue.sync {
      clearQueue()
      // Reset loop tracking when starting new playback
      playedEntries.removeAll()
      currentLoopIteration = 0
      entriesQueue.enqueue(item: audioEntry, type: .upcoming)
      playerContext.setInternalState(to: .pendingNext)
      do {
        try self.startEngineIfNeeded()
      } catch {
        self.raiseUnexpected(error: .audioSystemError(.engineFailure))
      }
    }

    sourceQueue.async { [weak self] in
      guard let self = self else { return }
      processSource()
    }
  }

  public func playNextInQueue() {
    checkRenderWaitingAndNotifyIfNeeded()
    serializationQueue.sync {
      if entriesQueue.count(for: .upcoming) > 0 {
        playerContext.setInternalState(to: .pendingNext)
      }
      do {
        try self.startEngineIfNeeded()
      } catch {
        self.raiseUnexpected(error: .audioSystemError(.engineFailure))
      }
    }

    sourceQueue.async { [weak self] in
      guard let self = self else { return }
      processSource()
    }
  }

  /// Queues the specified URL
  ///
  /// - Parameter url: A `URL` specifying the audio content to be played.
  public func queue(url: URL) {
    queue(url: url, headers: [:])
  }

  /// Queues the specified URLs
  ///
  /// - Parameter url: A `URL` specifying the audio content to be played.
  public func queue(urls: [URL]) {
    queue(urls: urls, headers: [:])
  }

  public func queue(url: URL, after afterUrl: URL) {
    queue(url: url, headers: [:], after: afterUrl)
  }

  /// Queues the specified audio stream
  ///
  /// - parameter source: A `CoreAudioStreamSource` that will providing streaming data
  /// - parameter entryId: A `String` that provides a unique id for this item
  /// - parameter format: An `AVAudioFormat` the format of this audio source
  public func queue(source: CoreAudioStreamSource, entryId: String, format: AVAudioFormat) {
    let audioEntry = AudioEntry(
      source: source,
      entryId: AudioEntryId(id: entryId),
      outputAudioFormat: format
    )
    queue(audioEntry: audioEntry)
  }

  public func removeFromQueue(url: URL) {
    serializationQueue.sync {
      if let item = entriesQueue.items(type: .upcoming)
        .first(where: { $0.id.id == url.absoluteString }) {
        entriesQueue.remove(item: item, type: .upcoming)

        if playerContext.audioPlayingEntry?.id.id == item.id.id {
          stop(clearQueue: false)
        }
      }
    }
    checkRenderWaitingAndNotifyIfNeeded()
    sourceQueue.async { [weak self] in
      self?.processSource()
    }
  }

  /// Queues the specified URL
  ///
  /// - Parameter url: A `URL` specifying the audio content to be played.
  /// - parameter headers: A `Dictionary` specifying any additional headers to be pass to the network request.
  public func queue(url: URL, headers: [String: String], after afterUrl: URL? = nil) {
    let audioEntry = entryProvider.provideAudioEntry(url: url, headers: headers)
    queue(audioEntry: audioEntry, after: afterUrl)
  }

  /// Queues the specified URLs
  ///
  /// - Parameter url: A array of `URL`s specifying the audio content to be played.
  /// - parameter headers: A `Dictionary` specifying any additional headers to be pass to the network request.
  public func queue(urls: [URL], headers: [String: String]) {
    serializationQueue.sync {
      for url in urls {
        let audioEntry = entryProvider.provideAudioEntry(url: url, headers: headers)
        audioEntry.delegate = self
        entriesQueue.enqueue(item: audioEntry, type: .upcoming)
      }
    }
    checkRenderWaitingAndNotifyIfNeeded()
    sourceQueue.async { [weak self] in
      self?.processSource()
    }
  }

  private func queue(audioEntry: AudioEntry, after afterUrl: URL? = nil) {
    serializationQueue.sync {
      audioEntry.delegate = self
      if let afterUrl = afterUrl {
        if let afterUrlEntry = entriesQueue.items(type: .upcoming)
          .first(where: { $0.id.id == afterUrl.absoluteString }) {
          entriesQueue.insert(item: audioEntry, type: .upcoming, after: afterUrlEntry)
        }
      } else {
        entriesQueue.enqueue(item: audioEntry, type: .upcoming)
      }
    }
    checkRenderWaitingAndNotifyIfNeeded()
    sourceQueue.async { [weak self] in
      self?.processSource()
    }
  }

  /// Stops the audio playback
  public func stop(clearQueue: Bool = true) {
    guard playerContext.internalState != .stopped else { return }

    serializationQueue.sync {
      stopEngine(reason: .userAction)
    }
    checkRenderWaitingAndNotifyIfNeeded()
    sourceQueue.async { [weak self] in
      guard let self = self else { return }
      playerContext.audioReadingEntry?.delegate = nil
      playerContext.audioReadingEntry?.close()
      if let playingEntry = playerContext.audioPlayingEntry {
        processFinishPlaying(entry: playingEntry, with: nil)
      }

      if clearQueue {
        self.clearQueue()
      }
      playerContext.entriesLock.lock()
      playerContext.audioReadingEntry = nil
      playerContext.audioPlayingEntry = nil
      playerContext.entriesLock.unlock()

      processSource()
    }
  }

  /// Pauses the audio playback
  public func pause() {
    if playerContext.internalState != .paused, playerContext.internalState.contains(.running) {
      stateBeforePaused = playerContext.internalState
      playerContext.setInternalState(to: .paused)
      serializationQueue.sync {
        pauseEngine()
      }
      playerContext.audioPlayingEntry?.suspend()
      sourceQueue.async { [weak self] in
        self?.processSource()
      }
    }
  }

  /// Resumes the audio playback, if previous paused
  public func resume() {
    guard playerContext.internalState == .paused else { return }
    playerContext.setInternalState(to: stateBeforePaused)
    serializationQueue.sync {
      do {
        try startEngine()
      } catch {
        Logger.debug(
          "resuming audio engine failed: \(error.localizedDescription)",
          category: .generic
        )
      }
      if let playingEntry = playerContext.audioReadingEntry {
        if playingEntry.seekRequest.requested {
          rendererContext.resetBuffers()
        }
        playingEntry.resume()
      }
      startPlayer(resetBuffers: false)
    }
  }

  /// Seeks the audio to the specified time.
  /// - Parameter time: A `Double` value specifying the time of the requested seek in seconds
  public func seek(to time: Double) {
    guard let playingEntry = playerContext.audioPlayingEntry else {
      return
    }
    playingEntry.seekRequest.lock.lock()
    let alreadyRequestedToSeek = playingEntry.seekRequest.requested
    playingEntry.seekRequest.requested = true
    playingEntry.seekRequest.time = time
    playingEntry.seekRequest.lock.unlock()

    if !alreadyRequestedToSeek {
      playingEntry.seekRequest.version.write { version in
        version += 1
      }
      playingEntry.suspend()
      checkRenderWaitingAndNotifyIfNeeded()
      sourceQueue.async { [weak self] in
        self?.processSource()
      }
    }
  }

  /// Attaches the given `AVAudioNode` to the engine
  /// - Note: The node will be added after the default rate node
  /// - Parameter node: An instance of `AVAudioNode`
  public func attach(node: AVAudioNode) {
    attach(nodes: [node])
  }

  /// Attaches the given `AVAudioNode`s to the engine
  /// - Note: The nodes will be added after the default rate node
  /// - Parameter node: An array of `AVAudioNode` instances
  public func attach(nodes: [AVAudioNode]) {
    for node in nodes {
      customAttachedNodes.append(node)
    }
    nodes.forEach(audioEngine.attach)

    reattachCustomNodes()
  }

  /// Detaches the given `AVAudioNode` from the engine
  /// - Parameter node: An instance of `AVAudioNode`
  public func detach(node: AVAudioNode) {
    guard customAttachedNodes.contains(node) else {
      return
    }
    customAttachedNodes.removeAll(where: { $0 == node })
    audioEngine.detach(node)
    reattachCustomNodes()
  }

  /// Detaches the given `AVAudioNode`s from the engine
  /// - Parameter node: An array of `AVAudioNode` instances
  public func detachCustomAttachedNodes() {
    for node in customAttachedNodes {
      audioEngine.detach(node)
    }
    attachAndConnectDefaultNodes()
  }

  // MARK: Private

  /// Setups the audio engine with manual rendering mode.
  private func setupEngine() {
    do {
      // audio engine must be stop before enabling manualRendering mode.
      audioEngine.stop()
      playerRenderProcessor.renderBlock = audioEngine.manualRenderingBlock

      try audioEngine.enableManualRenderingMode(
        .realtime,
        format: outputAudioFormat,
        maximumFrameCount: maxFramesPerSlice
      )

      let inputBlock = { [playerRenderProcessor] frameCount -> UnsafePointer<AudioBufferList>? in
        playerRenderProcessor.inRender(inNumberFrames: frameCount)
      }

      let success = audioEngine.inputNode.setManualRenderingInputPCMFormat(
        outputAudioFormat,
        inputBlock: inputBlock
      )
      guard success else {
        assertionFailure("failure setting manual rendering mode")
        return
      }
      attachAndConnectDefaultNodes()

      audioEngine.prepare()
      try audioEngine.start()
    } catch {
      Logger.error(
        "⚠️ error setting up audio engine: \(error.localizedDescription)",
        category: .generic
      )
    }
  }

  // Add this new method
  private func configureRateNode() {
    // Set overlap to a lower value for faster transitions (default is 8.0)
    rateNode.overlap = 4.0
    // Ensure pitch is not shifted
    rateNode.pitch = 0
    // Bypass by default since rate starts at 1.0
    rateNode.bypass = true
  }

  /// Creates and configures an `AVAudioUnit` with an output configuration
  /// and assigns it to the `player` variable.
  private func configPlayerNode() {
    AVAudioUnit.createAudioUnit(with: UnitDescriptions.output) { [weak self] result in
      guard let self = self else { return }
      switch result {
      case let .success(unit):
        player = unit
        playerRenderProcessor.attachCallback(on: unit, audioFormat: outputAudioFormat)
      case let .failure(error):
        assertionFailure("couldn't create player unit: \(error)")
        raiseUnexpected(error: .audioSystemError(.playerNotFound))
      }
    }
  }

  /// Attaches callbacks to the `playerContext` and `renderProcessor`.
  private func configPlayerContext() {
    playerContext.stateChanged = { [weak self] oldValue, newValue in
      guard let self = self else { return }
      asyncOnMain {
        self.delegate?.audioPlayerStateChanged(player: self, with: newValue, previous: oldValue)
      }
    }

    playerRenderProcessor.audioFinishedPlaying = { [weak self] entry in
      guard let self = self else { return }
      serializationQueue.sync {
        let nextEntry = self.entriesQueue.dequeue(type: .buffering)

        if nextEntry == nil {
          if let entry = entry {
            self.handleLoopingIfNeeded(for: entry)
          }
        } else {
          self.processFinishPlaying(entry: entry, with: nextEntry)
        }
      }
      sourceQueue.async {
        self.processSource()
      }
    }

    fileStreamProcessor.fileStreamCallback = { [weak self] effect in
      guard let self = self else { return }
      switch effect {
      case .processSource:
        sourceQueue.async {
          self.processSource()
        }
      case let .raiseError(error):
        raiseUnexpected(error: error)
      }
    }
  }

  /// Attaches and connect nodes to the `AudioEngine`.
  private func attachAndConnectDefaultNodes() {
    audioEngine.attach(rateNode)

    audioEngine.connect(audioEngine.inputNode, to: rateNode, format: processingFormat)
    audioEngine.connect(rateNode, to: audioEngine.mainMixerNode, format: processingFormat)
    audioEngine.connect(
      audioEngine.mainMixerNode,
      to: audioEngine.outputNode,
      format: processingFormat
    )
  }

  private func reattachCustomNodes() {
    audioEngine.disconnectNodeOutput(rateNode)
    customAttachedNodes.forEach { audioEngine.disconnectNodeOutput($0) }
    audioEngine.connect(audioEngine.inputNode, to: rateNode, format: processingFormat)

    if !customAttachedNodes.isEmpty {
      if let first = customAttachedNodes.first {
        audioEngine.connect(rateNode, to: first, format: processingFormat)
      }
      for index in 0 ..< customAttachedNodes.count - 1 {
        let current = customAttachedNodes[index]
        let next = customAttachedNodes[index + 1]
        let format = current.inputFormat(forBus: 0)
        audioEngine.connect(current, to: next, format: format)
      }
      if let last = customAttachedNodes.last {
        audioEngine.connect(last, to: audioEngine.mainMixerNode, format: processingFormat)
      }
    } else {
      audioEngine.connect(rateNode, to: audioEngine.mainMixerNode, format: processingFormat)
    }
  }

  /// Starts the engine, if not already running.
  ///
  /// - Throws: An `Error` when failed to start the engine.
  private func startEngineIfNeeded() throws {
    guard !isEngineRunning else {
      Logger.debug("engine already running 🛵", category: .generic)
      return
    }
    try startEngine()
  }

  /// Force starts the engine
  ///
  /// - Throws: An `Error` when failed to start the engine.
  private func startEngine() throws {
    try audioEngine.start()
    Logger.debug("engine started 🛵", category: .generic)
  }

  /// Pauses the audio engine and stops the player's hardware
  private func pauseEngine() {
    guard isEngineRunning else { return }
    audioEngine.reset()
    audioEngine.pause()
    player.auAudioUnit.stopHardware()
    Logger.debug("engine paused ⏸", category: .generic)
  }

  /// Stops the audio engine and the player's hardware
  ///
  /// - parameter reason: A value of `AudioPlayerStopReason` indicating the reason the engine stopped.
  private func stopEngine(reason: AudioPlayerStopReason) {
    audioEngine.stop()
    player.auAudioUnit.stopHardware()
    rendererContext.resetBuffers()
    playerContext.setInternalState(to: .stopped)
    playerContext.stopReason.write { $0 = reason }
    Logger.debug("engine stopped 🛑", category: .generic)
  }

  /// Makes the hardware receive stereo for stereo tracks and the canonical
  /// layout for multichannel tracks (see `HardwareOutput`). The output unit is
  /// stopped while its format changes, which costs a short gap only when the
  /// channel count changes between tracks.
  private func matchHardwareOutput(to entry: AudioEntry?) {
    dispatchPrecondition(condition: .onQueue(sourceQueue))
    guard let entry else { return }
    let sourceChannels = entry.lock.withLock { entry.audioStreamFormat.mChannelsPerFrame }
    // `AUAudioUnitBusArray` is not a Collection, so it has no `isEmpty`.
    // swiftformat:disable:next isEmpty
    let hasInputBus = player.auAudioUnit.inputBusses.count > 0
    guard let wanted = HardwareOutput.channelCount(
      forSourceChannels: sourceChannels,
      canonicalChannels: outputAudioFormat
        .channelCount
    ) else { return }
    declareMultichannelContent(wanted > 2)
    guard wanted != playerRenderProcessor.hardwareChannels, hasInputBus else { return }

    let unit = player.auAudioUnit
    let wasRunning = unit.isRunning
    let wasAllocated = unit.renderResourcesAllocated
    if wasRunning { unit.stopHardware() }
    if wasAllocated { unit.deallocateRenderResources() }
    do {
      let format = wanted == 2 ? HardwareOutput
        .stereoFormat(like: outputAudioFormat) : outputAudioFormat
      try unit.inputBusses[0].setFormat(format)
      playerRenderProcessor.hardwareChannels = wanted
      if wasAllocated { try unit.allocateRenderResources() }
      if wasRunning { try unit.startHardware() }
      Logger.debug("hardware output now \(wanted) channels", category: .generic)
    } catch {
      Logger.error(
        "Changing hardware output to %@ channels failed: %@",
        category: .audioRendering,
        args: String(wanted),
        error.localizedDescription
      )
    }
  }

  /// Tells iOS whether the app currently supplies multichannel content. Declared
  /// only while a multichannel track plays, so stereo tracks are treated as
  /// stereo, with the "Stereo as spatial audio" option, as in other music apps.
  private func declareMultichannelContent(_ supported: Bool) {
    #if os(iOS)
      guard declaredMultichannelContent != supported else { return }
      declaredMultichannelContent = supported
      do {
        try AVAudioSession.sharedInstance().setSupportsMultichannelContent(supported)
      } catch {
        Logger.error(
          "Declaring multichannel content failed: %@",
          category: .audioRendering,
          args: error.localizedDescription
        )
      }
    #endif
  }

  /// Starts the audio player, resetting the buffers if requested
  ///
  /// - parameter resetBuffers: A `Bool` value indicating if the buffers should be reset, prior starting the player.
  private func startPlayer(resetBuffers: Bool) {
    if resetBuffers {
      rendererContext.resetBuffers()
    }
    do {
      try startEngineIfNeeded()
      try player.auAudioUnit.allocateRenderResources()
      try player.auAudioUnit.startHardware()
    } catch {
      stopEngine(reason: .error)
      raiseUnexpected(error: .audioSystemError(.playerStartError))
    }
  }

  /// Processing the `playerContext` state to ensure correct behavior of playing/stop/seek
  private func processSource() {
    dispatchPrecondition(condition: .onQueue(sourceQueue))

    matchHardwareOutput(to: playerContext.entriesLock.withLock { playerContext.audioPlayingEntry })

    guard playerContext.internalState != .paused else { return }

    let snapshot = playerContext.entriesLock.withLock {
      (reading: playerContext.audioReadingEntry, playing: playerContext.audioPlayingEntry)
    }

    if playerContext.internalState == .pendingNext {
      let entry = entriesQueue.dequeue(type: .upcoming)
      playerContext.setInternalState(to: .waitingForData)
      setCurrentReading(entry: entry, startPlaying: true, shouldClearQueue: true)
      rendererContext.resetBuffers()
    } else if let playingEntry = snapshot.playing,
              playingEntry.seekRequest.requested,
              playingEntry != snapshot.reading {
      playingEntry.audioStreamState.processedDataFormat = false
      playingEntry.reset()
      if let readingEntry = snapshot.reading {
        readingEntry.delegate = nil
        readingEntry.close()
      }
      if configuration.flushQueueOnSeek {
        playerContext.setInternalState(to: .waitingForDataAfterSeek)
        setCurrentReading(entry: playingEntry, startPlaying: true, shouldClearQueue: true)
      } else {
        entriesQueue.requeueBufferingEntries { audioEntry in
          audioEntry.reset()
        }
        playerContext.setInternalState(to: .waitingForDataAfterSeek)
        setCurrentReading(entry: playingEntry, startPlaying: true, shouldClearQueue: false)
      }

    } else if snapshot.reading == nil {
      if entriesQueue.count(for: .upcoming) > 0 {
        let entry = entriesQueue.dequeue(type: .upcoming)
        let shouldStartPlaying = snapshot.playing == nil
        playerContext.setInternalState(to: .waitingForData)
        setCurrentReading(entry: entry, startPlaying: shouldStartPlaying, shouldClearQueue: false)
      } else if snapshot.playing == nil {
        if playerContext.internalState != .stopped {
          stopEngine(reason: .eof)
        }
      }
    }

    if let playingEntry = snapshot.playing,
       playingEntry.audioStreamState.processedDataFormat,
       playingEntry.calculatedBitrate() > 0.0 {
      let currSeekVersion = playingEntry.seekRequest.version.value
      playingEntry.seekRequest.lock.lock()
      let originalSeekToTimeRequested = playingEntry.seekRequest.requested
      playingEntry.seekRequest.lock.unlock()

      if originalSeekToTimeRequested, playerContext.audioReadingEntry === playingEntry {
        processSeekTime()

        let version = playingEntry.seekRequest.version.value
        if currSeekVersion == version {
          playingEntry.seekRequest.lock.lock()
          playingEntry.seekRequest.requested = false
          playingEntry.seekRequest.lock.unlock()
        }
      }
    }
  }

  private func processSeekTime() {
    assert(
      playerContext.audioReadingEntry === playerContext.audioPlayingEntry,
      "reading and playing entry must be the same"
    )
    fileStreamProcessor.processSeek()
  }

  private func setCurrentReading(entry: AudioEntry?, startPlaying: Bool, shouldClearQueue: Bool) {
    guard let entry = entry else { return }
    Logger.debug("Setting current reading entry to: \(entry.debugDescription)", category: .generic)
    if startPlaying {
      rendererContext.fillSilenceAudioBuffer()
    }

    fileStreamProcessor.closeFileStreamIfNeeded()

    if let readingEntry = playerContext.audioReadingEntry {
      readingEntry.delegate = nil
      readingEntry.close()
    }

    entry.delegate = self
    entry.seek(at: 0)
    playerContext.entriesLock.lock()
    playerContext.audioReadingEntry = entry
    playerContext.entriesLock.unlock()

    if startPlaying {
      if shouldClearQueue {
        clearQueue()
      }
      processFinishPlaying(entry: playerContext.audioPlayingEntry, with: entry)
      startPlayer(resetBuffers: true)
    } else {
      entriesQueue.enqueue(item: entry, type: .buffering)
    }
  }

  private func processFinishPlaying(entry: AudioEntry?, with nextEntry: AudioEntry?) {
    let playingEntry = playerContext.entriesLock.withLock { playerContext.audioPlayingEntry }
    guard entry == playingEntry else {
      return
    }

    let isPlayingSameItemProbablySeek = playerContext.audioPlayingEntry === nextEntry

    if let nextEntry = nextEntry {
      if !isPlayingSameItemProbablySeek {
        nextEntry.lock.withLock {
          nextEntry.seekTime = 0
        }
        nextEntry.seekRequest.lock.withLock {
          nextEntry.seekRequest.requested = false
        }
      }

      // Track entries as they transition (NOT for .all mode - handled separately to preserve order)
      if let entry = entry, !isPlayingSameItemProbablySeek, let url = URL(string: entry.id.id) {
        if case .all = loopMode {
          // Skip tracking for .all mode - it's handled in handleLoopingIfNeeded to preserve order
        } else {
          let alreadyTracked = playedEntries.contains(where: { $0.url == url })
          if !alreadyTracked {
            let entryInfo = LoopEntryInfo(url: url, headers: [:])
            playedEntries.append(entryInfo)
          }
        }
      }

      playerContext.entriesLock.lock()
      playerContext.audioPlayingEntry = nextEntry
      let playingQueueEntryId = playerContext.audioPlayingEntry?.id ?? AudioEntryId(id: "")
      playerContext.entriesLock.unlock()

      if let entry = entry, !isPlayingSameItemProbablySeek {
        let entryId = entry.id
        let progressInFrames = entry.progressInFrames()
        let progress = Double(progressInFrames) / outputAudioFormat.basicStreamDescription
          .mSampleRate
        let duration = entry.duration()
        asyncOnMain { [weak self] in
          guard let self else { return }
          delegate?.audioPlayerDidFinishPlaying(
            player: self,
            entryId: entryId,
            stopReason: stopReason,
            progress: progress,
            duration: duration
          )
        }
      }
      if !isPlayingSameItemProbablySeek {
        playerContext.setInternalState(to: .waitingForData)

        // For .all mode, track the STARTING entry to preserve queue order
        if case .all = loopMode, let url = URL(string: nextEntry.id.id) {
          let alreadyTracked = playedEntries.contains(where: { $0.url == url })
          if !alreadyTracked {
            let entryInfo = LoopEntryInfo(url: url, headers: [:])
            playedEntries.append(entryInfo)
          }
        }

        asyncOnMain { [weak self] in
          guard let self = self else { return }
          delegate?.audioPlayerDidStartPlaying(player: self, with: playingQueueEntryId)
        }
      }
    } else {
      // Track the LAST entry (NOT for .all mode - handled in handleLoopingIfNeeded to preserve order)
      if let entry = entry, !isPlayingSameItemProbablySeek, let url = URL(string: entry.id.id) {
        if case .all = loopMode {
          // Skip tracking for .all mode - it's handled in handleLoopingIfNeeded to preserve order
        } else {
          let alreadyTracked = playedEntries.contains(where: { $0.url == url })
          if !alreadyTracked {
            let entryInfo = LoopEntryInfo(url: url, headers: [:])
            playedEntries.append(entryInfo)
          }
        }
      }

      playerContext.entriesLock.lock()
      playerContext.audioPlayingEntry = nil
      playerContext.entriesLock.unlock()
      if let entry = entry, !isPlayingSameItemProbablySeek {
        let entryId = entry.id
        let progressInFrames = entry.progressInFrames()
        let progress = Double(progressInFrames) / outputAudioFormat.basicStreamDescription
          .mSampleRate
        let duration = entry.duration()

        sourceQueue.async { [weak self] in
          guard let self else { return }
          processSource()
          asyncOnMain {
            self.delegate?.audioPlayerDidFinishPlaying(
              player: self,
              entryId: entryId,
              stopReason: self.stopReason,
              progress: progress,
              duration: duration
            )
          }
        }
      }
    }
    sourceQueue.async { [weak self] in
      self?.processSource()
    }
    checkRenderWaitingAndNotifyIfNeeded()
  }

  /// Clears pending queues and informs the delegate
  private func clearQueue() {
    let pendingItems = entriesQueue.pendingEntriesId()
    entriesQueue.removeAll()
    playedEntries.removeAll()
    currentLoopIteration = 0
    if !pendingItems.isEmpty {
      asyncOnMain { [weak self] in
        guard let self = self else { return }
        delegate?.audioPlayerDidCancel(player: self, queuedItems: pendingItems)
      }
    }
  }

  /// Signals the packet process
  private func checkRenderWaitingAndNotifyIfNeeded() {
    if rendererContext.waiting.value {
      rendererContext.packetsSemaphore.signal()
    }
  }

  private func raiseUnexpected(error: AudioPlayerError) {
    playerContext.setInternalState(to: .error)
    asyncOnMain { [weak self] in
      guard let self = self else { return }
      delegate?.audioPlayerUnexpectedError(player: self, error: error)
    }
    Logger.error("Error: \(error.localizedDescription)", category: .generic)
  }

  /// Handles looping based on the current loop mode
  /// - Parameter entry: The audio entry that just finished playing
  private func handleLoopingIfNeeded(for entry: AudioEntry) {
    // For .all mode, track the last entry before checking if we should loop
    // This ensures the complete queue is captured for re-queueing
    if case .all = loopMode, let url = URL(string: entry.id.id) {
      let alreadyTracked = playedEntries.contains(where: { $0.url == url })
      if !alreadyTracked {
        let entryInfo = LoopEntryInfo(url: url, headers: [:])
        playedEntries.append(entryInfo)
      }
    }

    switch loopMode {
    case .off:
      processFinishPlaying(entry: entry, with: nil)

    case let .single(times):
      // Check if we've reached the loop count limit
      if let maxLoops = times, maxLoops > 0, currentLoopIteration >= maxLoops {
        processFinishPlaying(entry: entry, with: nil)
        return
      }

      guard let url = URL(string: entry.id.id) else {
        processFinishPlaying(entry: entry, with: nil)
        return
      }

      // Increment loop iteration
      currentLoopIteration += 1

      // Re-create the entry and enqueue for playback
      let newEntry = entryProvider.provideAudioEntry(url: url, headers: [:])
      newEntry.delegate = self
      entriesQueue.enqueue(item: newEntry, type: .upcoming)

    case let .all(times):
      // Check if we're at the end of all entries (nothing in queue)
      if entriesQueue.count(for: .upcoming) == 0, entriesQueue.count(for: .buffering) == 0 {
        // Check if we've reached the loop count limit
        if let maxLoops = times, maxLoops > 0, currentLoopIteration >= maxLoops {
          processFinishPlaying(entry: entry, with: nil)
          return
        }

        // Increment loop iteration
        currentLoopIteration += 1

        // Make a copy of playedEntries to re-queue
        let entriesToRequeue = playedEntries

        // Clear played entries BEFORE re-queueing to prevent duplicate tracking
        playedEntries.removeAll()

        // Re-create all played entries and enqueue as upcoming
        for entryInfo in entriesToRequeue {
          let newEntry = entryProvider.provideAudioEntry(
            url: entryInfo.url,
            headers: entryInfo.headers
          )
          newEntry.delegate = self
          entriesQueue.enqueue(item: newEntry, type: .upcoming)
        }
      }
    }
  }
}

// MARK: AudioStreamSourceDelegate

extension AudioPlayer: AudioStreamSourceDelegate {
  public func dataAvailable(source: CoreAudioStreamSource, data: Data) {
    guard let readingEntry = playerContext.audioReadingEntry, readingEntry.has(same: source) else {
      return
    }

    if !fileStreamProcessor.isFileStreamOpen {
      let openFileStreamStatus = fileStreamProcessor.openFileStream(with: source.audioFileHint)
      guard openFileStreamStatus == noErr else {
        let streamError = AudioFileStreamError(status: openFileStreamStatus)
        raiseUnexpected(error: .audioSystemError(.fileStreamError(streamError)))
        return
      }
    }

    if fileStreamProcessor.isFileStreamOpen {
      let streamBytesStatus = fileStreamProcessor.parseFileStreamBytes(data: data)
      guard streamBytesStatus == noErr else {
        if let playingEntry = playerContext.audioPlayingEntry, playingEntry.has(same: source) {
          let streamBytesError = AudioFileStreamError(status: streamBytesStatus)
          raiseUnexpected(error: .streamParseBytesFailure(streamBytesError))
        }
        return
      }

      if playerContext.audioReadingEntry == nil {
        source.close()
      }
    }
  }

  public func errorOccurred(source: CoreAudioStreamSource, error: Error) {
    guard let entry = playerContext.audioReadingEntry, entry.has(same: source) else { return }
    raiseUnexpected(error: .networkError(.failure(error)))
  }

  public func endOfFileOccurred(source: CoreAudioStreamSource) {
    let hasSameSource = playerContext.audioReadingEntry?.has(same: source) ?? false
    guard playerContext.audioReadingEntry == nil || hasSameSource else {
      source.delegate = nil
      source.close()
      return
    }
    let queuedItemId = playerContext.audioReadingEntry?.id
    asyncOnMain { [weak self] in
      guard let self = self else { return }
      guard let itemId = queuedItemId else { return }
      delegate?.audioPlayerDidFinishBuffering(player: self, with: itemId)
    }

    guard let readingEntry = playerContext.audioReadingEntry else {
      source.delegate = nil
      source.close()
      return
    }

    // Flush any remaining packets from AudioFileStream before marking EOF
    // This is critical for formats like FLAC that use sync words to determine packet boundaries.
    // Without this flush, the final partial packet will not be delivered.
    let flushStatus = fileStreamProcessor.flushRemainingPackets()
    if flushStatus != noErr {
      Logger.debug("Failed to flush remaining packets at EOF: \(flushStatus)", category: .generic)
    }

    readingEntry.lock.lock()
    readingEntry.framesState.lastFrameQueued = readingEntry.framesState.queued
    readingEntry.lock.unlock()

    readingEntry.delegate = nil
    readingEntry.close()

    playerContext.entriesLock.lock()
    playerContext.audioReadingEntry = nil
    playerContext.entriesLock.unlock()

    sourceQueue.async { [weak self] in
      guard let self = self else { return }
      processSource()
    }
  }

  public func metadataReceived(data: [String: String]) {
    asyncOnMain { [weak self] in
      guard let self = self else { return }
      delegate?.audioPlayerDidReadMetadata(player: self, metadata: data)
    }
  }
}
