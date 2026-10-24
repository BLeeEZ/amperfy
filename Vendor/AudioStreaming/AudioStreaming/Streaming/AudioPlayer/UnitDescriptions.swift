//
//  Created by Dimitrios Chatzieleftheriou on 10/06/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import AVFoundation

enum UnitDescriptions {
  static let output: AudioComponentDescription = {
    var desc = AudioComponentDescription()
    desc.componentType = kAudioUnitType_Output
    #if os(iOS) || os(tvOS)
      desc.componentSubType = kAudioUnitSubType_RemoteIO
    #else
      desc.componentSubType = kAudioUnitSubType_DefaultOutput
    #endif
    desc.componentManufacturer = kAudioUnitManufacturer_Apple
    desc.componentFlags = 0
    desc.componentFlagsMask = 0
    return desc
  }()
}
