import Foundation

/// Defines all available audio visualizer types
public enum VisualizerType: String, CaseIterable, Codable, Sendable {
  /// Oscilloscope-style smooth waveform visualization
  case waveform
  /// Classic equalizer-style animated frequency bars
  case spectrumBars
  /// Circular/radial visualization with rotating elements
  case radial
  /// Procedural generative art with particle effects
  case generativeArt
  /// Legacy ring visualizer (frequency bars in circular arrangement)
  case ring

  public var displayName: String {
    switch self {
    case .waveform:
      return "Waveform"
    case .spectrumBars:
      return "Spectrum Bars"
    case .radial:
      return "Radial"
    case .generativeArt:
      return "Generative Art"
    case .ring:
      return "Ring"
    }
  }

  public var iconName: String {
    switch self {
    case .waveform:
      return "waveform.path"
    case .spectrumBars:
      return "chart.bar.fill"
    case .radial:
      return "circle.hexagongrid.fill"
    case .generativeArt:
      return "sparkles"
    case .ring:
      return "circle.dashed"
    }
  }

  public static var defaultValue: VisualizerType {
    .radial
  }
}
