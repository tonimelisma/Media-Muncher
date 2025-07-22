//
//  MediaFilesView.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/17/25.
//

import SwiftUI

struct MediaFilesGridView: View {
    @EnvironmentObject var fileStore: FileStore
    @State private var columns: [GridItem] = []
    @State private var lastGeometryWidth: CGFloat = 0
    
    private func updateColumns(for width: CGFloat) {
        guard width != lastGeometryWidth else { return }
        lastGeometryWidth = width
        
        let columnsCount = Constants.gridColumnsCount(for: width)
        columns = Array(repeating: GridItem(.fixed(Constants.gridColumnWidth), spacing: Constants.gridColumnSpacing, alignment: .topLeading), count: columnsCount)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: columns) {
                    ForEach(fileStore.files) { file in
                        MediaFileCellView(file: file)
                    }
                }
                .padding()
                .onAppear { updateColumns(for: geometry.size.width) }
                .onChange(of: geometry.size.width) { _, newWidth in updateColumns(for: newWidth) }
            }
        }
    }
}
