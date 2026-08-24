import Foundation
import DefaultAppsCore
import UniformTypeIdentifiers

/// UI strings use English literals as keys; per-language `.lproj` files
/// translate them. Missing key → English fallback.
func t(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

func tKey(_ raw: String) -> String {
    Bundle.module.localizedString(forKey: raw, value: raw, table: nil)
}

func familySymbol(_ name: String) -> String {
    switch name {
    case "plain text": "doc.text"
    case "code": "curlybraces"
    case "web": "globe"
    case "images": "photo"
    case "audio": "waveform"
    case "video": "film"
    case "archives": "archivebox"
    case "documents": "doc.richtext"
    case "url schemes": "link"
    default: "folder"
    }
}

func typeDescription(for target: QueryTarget) -> String? {
    switch target {
    case .fileExtension(let ext):
        return UTType(filenameExtension: ext)?.localizedDescription
    case .contentType(let uti):
        return UTType(uti)?.localizedDescription
    case .scheme(let scheme):
        let known: [String: String] = [
            "http": t("Web"), "https": t("Web"), "mailto": t("Email"),
            "ftp": t("File transfer"), "ssh": t("Remote shell"),
            "tel": t("Phone calls"), "webcal": t("Calendar subscriptions"),
        ]
        return known[scheme]
    }
}
