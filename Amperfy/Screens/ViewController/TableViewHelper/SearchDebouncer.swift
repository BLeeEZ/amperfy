//
//  SearchDebouncer.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 23.02.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import UIKit

// MARK: - DebouncedSearchResultsUpdater

@MainActor
final class DebouncedSearchResultsUpdater: NSObject, UISearchResultsUpdating {
  weak var target: UISearchResultsUpdating?
  private let debouncer = SearchDebouncer()

  func updateSearchResults(for searchController: UISearchController) {
    let searchText = searchController.searchBar.text ?? ""
    if searchText.isEmpty {
      debouncer.runImmediately {
        target?.updateSearchResults(for: searchController)
      }
    } else {
      debouncer.schedule { [weak self] in
        self?.target?.updateSearchResults(for: searchController)
      }
    }
  }
}

// MARK: - SearchDebouncer

@MainActor
final class SearchDebouncer {
  private var pendingWorkItem: DispatchWorkItem?
  private let delay: TimeInterval

  init(delay: TimeInterval = 0.2) {
    self.delay = delay
  }

  func schedule(_ action: @escaping @MainActor () -> ()) {
    pendingWorkItem?.cancel()
    let workItem = DispatchWorkItem {
      MainActor.assumeIsolated { action() }
    }
    pendingWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
  }

  func runImmediately(_ action: @MainActor () -> ()) {
    cancel()
    action()
  }

  func cancel() {
    pendingWorkItem?.cancel()
    pendingWorkItem = nil
  }
}
