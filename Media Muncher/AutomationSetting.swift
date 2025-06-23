import Foundation

public enum AutomationSetting: String, Codable, CaseIterable, Identifiable {
    case ask
    case autoImport
    case ignore
    
    public var id: Self { self }
    
    var localizedDescription: String {
        switch self {
        case .ask:
            return "Ask What to Do"
        case .autoImport:
            return "Automatically Import"
        case .ignore:
            return "Ignore"
        }
    }
} 