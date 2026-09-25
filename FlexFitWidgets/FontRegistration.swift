import CoreText
import Foundation

/// Widgets run in their own process: register the bundled Plus Jakarta Sans files there too.
enum FontRegistration {
    static func register() {
        for name in ["Regular", "Medium", "SemiBold", "Bold", "ExtraBold"] {
            guard let url = Bundle.main.url(forResource: "PlusJakartaSans-\(name)", withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
