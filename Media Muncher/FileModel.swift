//
//  FileModel.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/17/25.
//

struct File: Identifiable {
    var id: String {
        sourcePath
    }
    let sourcePath: String
    var destDirectory: String?
    var destFilename: String?
    var destPath: String? {
        guard let destDirectory = destDirectory, let destFilename = destFilename
        else {
            return nil
        }
        return destDirectory + "/" + destFilename
    }
}
