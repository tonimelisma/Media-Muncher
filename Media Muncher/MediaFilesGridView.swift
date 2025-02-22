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
                let iconSize: CGFloat = columnWidth - 20
                let columns = Array(
                    repeating: GridItem(
                        .fixed(columnWidth), spacing: 10, alignment: .topLeading
                    ), count: columnsCount)

                LazyVGrid(columns: columns) {
                    ForEach(appState.files) {
                        file in
                        VStack {
                            // TODO function to provide correct image based on file type
                            // Image(systemName: "video.fill")
                            // Image(systemName: "speaker.3.fill")
                            // Image(systemName: "music.note")
                            // Image(systemName: "music.note.list")
                            Image(systemName: "photo.fill.on.rectangle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: iconSize, height: iconSize)
                            Text(file.sourceName)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding()
            }
            Spacer()
        }
    }
}
