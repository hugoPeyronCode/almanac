//
//  CloseButton.swift
//  almanac
//
//  Reusable close button component for fullscreen views
//

import SwiftUI

struct CloseButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "xmark")
        .foregroundStyle(Color.primary)
        .font(.subheadline)
    }
  }
}

#Preview {
  CloseButton {
  }
}
