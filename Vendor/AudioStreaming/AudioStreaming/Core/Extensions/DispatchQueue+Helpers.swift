//
//  Created by Dimitrios Chatzieleftheriou on 10/06/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import Foundation

/// Helper method to dispatch the given block asynchronously on the MainQueue
func asyncOnMain(_ block: @escaping () -> ()) {
  DispatchQueue.main.async(execute: block)
}

/// Helper method to dispatch the given block asynchronously on the MainQueue, after a given time interval
/// - note: This account for `.now()` plus the passed deadline
func asyncOnMain(deadline: DispatchTimeInterval, block: @escaping () -> ()) {
  DispatchQueue.main.asyncAfter(deadline: .now() + deadline, execute: block)
}
