import SwiftUI
import AppKit

/// System surfaces follow macOS appearance and accessibility settings.
/// Bamboo green is reserved for actions and small accents, never window fills.
enum FitPalette {
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let card = Color(nsColor: .controlBackgroundColor)
    static let border = Color(nsColor: .separatorColor)
    static let accent = Color("AccentColor")
}
