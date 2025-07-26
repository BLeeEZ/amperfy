public struct Magnitude: Sendable, CustomStringConvertible {
  public var hertz: Float
  public var value: Float

  public var description: String {
    String(format: "%0.2f Hz: magnitude = %f", hertz, value)
  }

  public static let zero = Magnitude(hertz: 0, value: 0)
}
