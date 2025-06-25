//
//  MediaFilesView.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/17/25.
//

import SwiftUI

struct MediaFilesGridView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingErrorAlertFor: File?

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
                        VStack {
                            ZStack {
                                if let thumbnail = file.thumbnail {
                                    thumbnail
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 100, height: 100)
                                } else {
                                    Image(systemName: file.mediaType.sfSymbolName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 50, height: 50)
                                        .padding(.vertical, 25)
                                }
                                
                                if file.status == .pre_existing || file.status == .imported {
                                    Color.black.opacity(0.4)
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.white)
                                        .font(.largeTitle)
                                }
                                
                                if file.status == .duplicate_in_source {
                                    Color.black.opacity(0.4)
                                    Image(systemName: "doc.on.doc.fill")
                                        .foregroundColor(.white)
                                        .font(.largeTitle)
                                }
                                
                                if file.status == .copying || file.status == .verifying {
                                    Color.black.opacity(0.4)
                                    ProgressView()
                                        .controlSize(.large)
                                        .tint(.white)
                                }
                                
                                if file.status == .failed {
                                    Color.black.opacity(0.4)
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.largeTitle)
                                        .onTapGesture {
                                            self.showingErrorAlertFor = file
                                        }
                                }
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text(file.sourceName)
                                .lineLimit(1)
                                .font(.caption)
                                .frame(width: 100)
                        }
                    }
                }
                .padding()
            }
            Spacer()
        }
        .alert(item: $showingErrorAlertFor) { file in
            Alert(
                title: Text("Import Failed"),
                message: Text(file.importError ?? "An unknown error occurred."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
