//
//  MediaFilesView.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/17/25.
//

import SwiftUI

struct MediaFilesGridView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                let columnWidth: CGFloat = 120
                let columnsCount = Int(
                    (geometry.size.width - 20)/(columnWidth + 10))
                let columns = Array(
                    repeating: GridItem(
                        .fixed(columnWidth), spacing: 10, alignment: .topLeading
                    ), count: columnsCount)

                LazyVGrid(columns: columns) {
                    ForEach(appState.files) { file in
                        MediaFileCellView(file: file)
                    }
                }
                .padding()
            }
            Spacer()
        }
    }
}
