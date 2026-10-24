//
//  Created by Dimitrios Chatzieleftheriou on 25/10/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import Foundation

final class ProcessedPacketsState {
  var bufferSize: UInt32 = 0
  var count: UInt32 = 0
  var sizeTotal: UInt32 = 0

  var isEmpty: Bool {
    count == 0
  }
}
