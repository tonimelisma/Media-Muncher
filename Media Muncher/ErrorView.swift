//
//  ErrorView.swift
//  Media Muncher
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI

struct ErrorView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if let error = appState.error {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .accessibilityIdentifier("errorBanner")
        }
    }
}

#if DEBUG
#Preview("No Error") {
    ErrorView()
        .environmentObject(PreviewHelpers.appState())
}
#endif
