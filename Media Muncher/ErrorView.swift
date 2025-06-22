//
//  ErrorView.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/21/25.
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
        }
    }
}
