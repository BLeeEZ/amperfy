//
//  Created by Dimitrios Chatzieleftheriou on 03/11/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import AVFoundation

public enum AudioConverterError: CustomDebugStringConvertible, Sendable {
  case badPropertySizeError
  case formatNotSupported
  case inputSampleRateOutOfRange
  case invalidInputSize
  case invalidOutputSize
  case operationNotSupported
  case outputSampleRateOutOfRange
  case propertyNotSupported
  case requiresPacketDescriptionsError
  case unspecifiedError
  case cannotCreateConverter

  init(osstatus: OSStatus) {
    switch osstatus {
    case kAudioConverterErr_BadPropertySizeError:
      self = .badPropertySizeError
    case kAudioConverterErr_FormatNotSupported:
      self = .formatNotSupported
    case kAudioConverterErr_InputSampleRateOutOfRange:
      self = .inputSampleRateOutOfRange
    case kAudioConverterErr_InvalidInputSize:
      self = .invalidInputSize
    case kAudioConverterErr_InvalidOutputSize:
      self = .invalidOutputSize
    case kAudioConverterErr_OperationNotSupported:
      self = .operationNotSupported
    case kAudioConverterErr_OutputSampleRateOutOfRange:
      self = .outputSampleRateOutOfRange
    case kAudioConverterErr_PropertyNotSupported:
      self = .propertyNotSupported
    case kAudioConverterErr_RequiresPacketDescriptionsError:
      self = .requiresPacketDescriptionsError
    case kAudioConverterErr_UnspecifiedError:
      self = .unspecifiedError
    default:
      self = .unspecifiedError
    }
  }

  public var debugDescription: String {
    switch self {
    case .badPropertySizeError:
      return "Bad property size"
    case .formatNotSupported:
      return "Format not supported"
    case .inputSampleRateOutOfRange:
      return "Input sample rate is out of range"
    case .invalidInputSize:
      return "Invalid input size"
    case .invalidOutputSize:
      return "The byte size is not an integer multiple of the frame size."
    case .operationNotSupported:
      return "Operation not supported"
    case .outputSampleRateOutOfRange:
      return "Output sample rate out of range"
    case .propertyNotSupported:
      return "Property not supported"
    case .requiresPacketDescriptionsError:
      return "Required packet descriptions (error)"
    case .unspecifiedError:
      return "Unspecified error"
    case .cannotCreateConverter:
      return "Cannot create audio converter"
    }
  }
}
