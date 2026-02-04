//
//  SwiftUIView.swift
//
//
//  Created by Urvi Koladiya on 2025-04-14.
//

import SwiftUI

// Use custom dark background (90% black) instead of pure black
let BgColor: Color = Color(UIColor { traitCollection in
  if traitCollection.userInterfaceStyle == .dark {
    return UIColor(white: 0.1, alpha: 1.0)
  } else {
    return UIColor.systemBackground
  }
})
