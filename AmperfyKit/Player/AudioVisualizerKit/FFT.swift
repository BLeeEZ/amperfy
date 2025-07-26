import Accelerate

// MARK: - FFTProtocol

protocol FFTProtocol: AnyObject {
  init(size: Int, windowType: WindowType)
  func compute(sampleRate: Float, audioData: UnsafePointer<Float>) -> [Magnitude]
  func rms(audioData: UnsafePointer<Float>) -> Float
}

// MARK: - FFT

public final class FFT: FFTProtocol {
  private let windowType: WindowType
  private let fftFullSize: vDSP_Length
  private let fftHalfSize: vDSP_Length
  private let mLog2N: vDSP_Length
  private var fftSetup: FFTSetup?

  public init(size: Int, windowType: WindowType) {
    self.windowType = windowType
    self.fftFullSize = vDSP_Length(size)
    self.fftHalfSize = vDSP_Length(size / 2)
    self.mLog2N = vDSP_Length(log2(Double(size)).rounded() + 1.0)
    self.fftSetup = vDSP_create_fftsetup(mLog2N, FFTRadix(kFFTRadix2))
  }

  deinit {
    vDSP_destroy_fftsetup(fftSetup)
  }

  public func compute(sampleRate: Float, audioData: UnsafePointer<Float>) -> [Magnitude] {
    guard let fftSetup else {
      return .init(repeating: .zero, count: Int(fftHalfSize))
    }
    // Applies the window function.
    let windowData = UnsafeMutablePointer<Float>.allocate(capacity: Int(fftFullSize))
    defer {
      windowData.deallocate()
    }
    // Creates the window data.
    switch windowType {
    case .hannWindow:
      vDSP_hann_window(windowData, fftFullSize, 0)
    case .hammingWindow:
      vDSP_hamm_window(windowData, fftFullSize, 0)
    case .blackmanWindow:
      vDSP_blkman_window(windowData, fftFullSize, 0)
    }
    // Computes the element-wise product of two vectors
    vDSP_vmul(audioData, 1, windowData, 1, windowData, 1, fftFullSize)

    // Creates a vector with all elements zero.
    let zeroData = UnsafeMutablePointer<Float>.allocate(capacity: Int(fftFullSize))
    defer {
      zeroData.deallocate()
    }
    vDSP_vclr(zeroData, 1, fftFullSize)

    // Puts signal data into real part of complex vector.
    var dspSplitComplex = DSPSplitComplex(
      realp: windowData,
      imagp: zeroData
    )

    // Performs Fast Fourier Transform (FFT).
    vDSP_fft_zrip(fftSetup, &dspSplitComplex, 1, mLog2N, FFTDirection(FFT_FORWARD))

    // Calculates the element-wise division of a vector and a scalar value.
    // Divides the FFT result by the number of elements.
    var fftNormFactor = Float(fftFullSize)
    vDSP_vsdiv(dspSplitComplex.realp, 1, &fftNormFactor, dspSplitComplex.realp, 1, fftHalfSize)
    vDSP_vsdiv(dspSplitComplex.imagp, 1, &fftNormFactor, dspSplitComplex.imagp, 1, fftHalfSize)

    // Computes the element-wise absolute value of a complex vector.
    // sqrt(real * real + imag * imag)
    var magnitudeData = [Float](repeating: .zero, count: Int(fftHalfSize))
    vDSP_zvabs(&dspSplitComplex, 1, &magnitudeData, 1, fftHalfSize)

    // Multiplies by 2 to get the correct amplitude.
    var fftFactor = Float(2)
    vDSP_vsmul(magnitudeData, 1, &fftFactor, &magnitudeData, 1, fftHalfSize)

    // Create an array of frequencies
    var hertsData: [Float] = vDSP.ramp(withInitialValue: 1, increment: 1, count: Int(fftHalfSize))
    var hertsFactor = sampleRate / Float(fftFullSize)
    vDSP_vsmul(hertsData, 1, &hertsFactor, &hertsData, 1, fftHalfSize)

    return zip(hertsData, magnitudeData).map { Magnitude(hertz: $0, value: $1) }
  }

  public func rms(audioData: UnsafePointer<Float>) -> Float {
    var value: Float = 0
    vDSP_measqv(audioData, 1, &value, vDSP_Length(fftFullSize))
    return sqrtf(value)
  }
}
