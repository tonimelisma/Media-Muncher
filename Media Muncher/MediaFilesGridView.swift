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
                let columnsCount = Int(geometry.size.width / (columnWidth + 10))
                let iconSize: CGFloat = columnWidth - 20
                let columns = Array(
                    repeating: GridItem(
                        .fixed(columnWidth), spacing: 10, alignment: .topLeading
                    ), count: columnsCount)

                LazyVGrid(columns: columns) {
                    ForEach(appState.files) {
                        file in
                        VStack {
                            // Image(systemName: "folder.fill")
                            // Image(systemName: "video.fill")
                            // Image(systemName: "speaker.3.fill")
                            // Image(systemName: "music.note")
                            // Image(systemName: "music.note.list")
                            Image(
                                systemName: "photo.fill.on.rectangle.fill"
                            )
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: iconSize, height: iconSize)
                            Text(file.sourcePath)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .frame(
                    width: CGFloat(columnsCount) * (columnWidth + 10),
                    alignment: .leading)
                .padding()
                Spacer()
            }
        }
    }
}
