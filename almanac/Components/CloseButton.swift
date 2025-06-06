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
                .font(.title2)
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
    }
}

#Preview {
    CloseButton {
        // Action
    }
}