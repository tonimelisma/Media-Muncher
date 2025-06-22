//
//  AppError.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/22/25.
//

import Foundation

enum AppError: Error, Identifiable, LocalizedError {
    var id: String { localizedDescription }
    
    case scanFailed(reason: String)
    case destinationNotSet
    case importFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .scanFailed(let reason):
            return "Scan failed: \(reason)"
        case .destinationNotSet:
            return "Please select a destination folder in Settings before importing."
        case .importFailed(let reason):
            return "Import failed: \(reason)"
        }
    }
} 