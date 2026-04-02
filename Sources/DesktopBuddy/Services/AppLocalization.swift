import Foundation

public enum AppLanguage: String, Sendable {
    case chinese
    case english

    public static var current: AppLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? Locale.current.identifier.lowercased()
        return preferred.hasPrefix("zh") ? .chinese : .english
    }

    public var isChinese: Bool {
        self == .chinese
    }
}

public enum L10n {
    public static var currentLanguage: AppLanguage {
        AppLanguage.current
    }

    public static func text(_ chinese: String, _ english: String) -> String {
        currentLanguage.isChinese ? chinese : english
    }

    public static func format(_ chinese: String, _ english: String, _ arguments: CVarArg...) -> String {
        let template = text(chinese, english)
        return String(format: template, locale: Locale.current, arguments: arguments)
    }
}
