import AVFoundation
import Observation
import SwiftUI

// MARK: - AudioAnalyzerProtocol

@MainActor
protocol AudioAnalyzerProtocol: AnyObject {
  func install(on audioNode: AVAudioNode)
  func playing(sampleRate: Float)
  func play()
  func stop()
}

// MARK: - AudioAnalyzer

@MainActor
public final class AudioAnalyzer: ObservableObject, AudioAnalyzerProtocol {
  @Published
  public var magnitudes: [Magnitude]
  @Published
  public var rms: Float = .zero

  private let fftSize: Int

  nonisolated(unsafe) private var _isActive = false
  private let _isActiveLock = NSLock()
  nonisolated public var isActive: Bool {
    get {
      _isActiveLock.withLock { _isActive }
    }
    set {
      _isActiveLock.withLock { _isActive = newValue }
    }
  }

  nonisolated(unsafe) private var _isPlaying = false
  private let _isPlayingLock = NSLock()
  nonisolated private var isPlaying: Bool {
    get {
      _isPlayingLock.withLock { _isPlaying }
    }
    set {
      _isPlayingLock.withLock { _isPlaying = newValue }
    }
  }

  nonisolated(unsafe) private var _sampleRate: Float = 0.0
  private let _sampleRateLock = NSLock()
  nonisolated private var sampleRate: Float {
    get {
      _sampleRateLock.withLock { _sampleRate }
    }
    set {
      _sampleRateLock.withLock { _sampleRate = newValue }
    }
  }

  nonisolated(unsafe) private var _fft: FFT
  private let _fftLock = NSLock()
  nonisolated private var fft: FFT {
    get {
      _fftLock.withLock { _fft }
    }
    set {
      _fftLock.withLock { _fft = newValue }
    }
  }

  public init(fftSize: Int = 256, windowType: WindowType = .hannWindow) {
    self.fftSize = fftSize
    self._fft = FFT(size: fftSize, windowType: windowType)
    self.magnitudes = .init(repeating: .zero, count: fftSize / 2)
  }

  public func install(on audioNode: AVAudioNode) {
    audioNode.installTap(
      onBus: .zero,
      bufferSize: AVAudioFrameCount(fftSize),
      format: nil,
      block: calculate
    )
  }

  public func playing(sampleRate: Float) {
    self.sampleRate = sampleRate
  }

  public func play() {
    isPlaying = true
  }

  public func stop() {
    isPlaying = false
    magnitudes = .init(repeating: .zero, count: fftSize / 2)
  }

  nonisolated func calculate(buffer: AVAudioPCMBuffer, audioTime: AVAudioTime) {
    if isActive, isPlaying, let data = buffer.floatChannelData {
      let magnitudesCalculated = fft.compute(sampleRate: sampleRate, audioData: data.pointee)
      let rmsCalculated = fft.rms(audioData: data.pointee)

      Task { @MainActor in
        self.magnitudes = magnitudesCalculated
        self.rms = rmsCalculated
      }
    }
  }
}
