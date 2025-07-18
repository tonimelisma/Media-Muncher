//
//  MediaFilesView.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/17/25.
//

import SwiftUI

struct MediaFilesGridView: View {
    @EnvironmentObject var appState: AppState
    @State private var columns: [GridItem] = []
    @State private var lastGeometryWidth: CGFloat = 0
    
    private func updateColumns(for width: CGFloat) {
        guard width != lastGeometryWidth else { return }
        lastGeometryWidth = width
        
        let columnWidth: CGFloat = 120
        let columnsCount = Int((width - 20)/(columnWidth + 10))
        columns = Array(repeating: GridItem(.fixed(columnWidth), spacing: 10, alignment: .topLeading), count: columnsCount)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: columns) {
                    ForEach(appState.files) { file in
                        MediaFileCellView(file: file)
                    }
                }
                .padding()
                .onAppear { updateColumns(for: geometry.size.width) }
                .onChange(of: geometry.size.width) { _, newWidth in updateColumns(for: newWidth) }
            }
            Spacer()
        }
    }
}
