import SwiftUI

/// The same cheerful palette used by the website, with readable night variants.
enum FitPalette {
    static let canvas = Color("FitCanvas")
    static let card = Color("FitCard")
    static let sidebar = Color("FitSidebar")
    static let border = Color("FitBorder")
    static let mintWash = Color("FitMintWash")
    static let peachWash = Color("FitPeachWash")
    static let skyWash = Color("FitSkyWash")
    static let lilacWash = Color("FitLilacWash")
    static let roseWash = Color("FitRoseWash")
    static let purple = Color("FitPurple")
    static let teal = Color("FitTeal")
    static let sky = Color("FitSky")
    static let peach = Color("FitPeach")
    static let pink = Color("FitPink")
    static let gold = Color("FitGold")
}

extension StorageCategory {
    var wash: Color {
        switch self {
        case .installations, .components, .archives: FitPalette.lilacWash
        case .builds, .simulators: FitPalette.skyWash
        case .caches, .previews: FitPalette.mintWash
        case .packages, .logs: FitPalette.peachWash
        case .deviceSupport, .other: FitPalette.roseWash
        }
    }
}
