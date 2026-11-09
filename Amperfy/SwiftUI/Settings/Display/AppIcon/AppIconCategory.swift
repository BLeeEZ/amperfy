//
//  AppIconCategory.swift
//  Amperfy
//
//  Created by David Klopp on 09.11.26.
//  Copyright © 2026 Maximilian Bauer. All rights reserved.
//
import Foundation

enum AppIconCategory: String, CaseIterable, Identifiable {
  case amperfy
  case music
  case all

  var id: Self { self }

  var title: String {
    switch self {
    case .amperfy: "Amperfy"
    case .music: "Music"
    case .all: "All"
    }
  }
}
