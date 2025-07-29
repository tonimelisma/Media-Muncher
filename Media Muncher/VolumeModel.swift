//
//  VolumeModel.swift
//  Media Muncher
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

struct Volume: Identifiable, Equatable {
    // Computed property to conform to the Identifiable protocol
    var id: String {
        devicePath
    }
    let name: String
    let devicePath: String
    let volumeUUID: String

    static func == (lhs: Volume, rhs: Volume) -> Bool {
        return lhs.volumeUUID == rhs.volumeUUID
    }
}
