//
//  Created by Dimitrios Chatzieleftheriou on 24/10/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import Foundation

final class EntryFramesState {
  var queued: Int = 0
  var played: Int = 0
  var lastFrameQueued: Int = -1
}
