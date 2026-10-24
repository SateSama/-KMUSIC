import SwiftUI
import UIKit

/// Gothic Crimson palette, shared with the desktop KMUSIC theme.
extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    static let kBackground = Color(hex: 0x0A0507)
    static let kSurface = Color(hex: 0x1A0B0E)
    static let kSurfaceHigh = Color(hex: 0x2A1216)
    static let kText = Color(hex: 0xE8DCDC)
    static let kMuted = Color(hex: 0xA08487)
    static let kPrimary = Color(hex: 0xC8182A)
    static let kPrimaryBright = Color(hex: 0xE02033)
}

enum Appearance {
    static func configure() {
        let background = UIColor(red: 0.039, green: 0.020, blue: 0.027, alpha: 1)
        let text = UIColor(red: 0.91, green: 0.86, blue: 0.86, alpha: 1)

        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = background
        navigation.titleTextAttributes = [.foregroundColor: text]
        navigation.largeTitleTextAttributes = [.foregroundColor: text]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation

        let tabs = UITabBarAppearance()
        tabs.configureWithOpaqueBackground()
        tabs.backgroundColor = UIColor(red: 0.024, green: 0.012, blue: 0.016, alpha: 1)
        UITabBar.appearance().standardAppearance = tabs
        UITabBar.appearance().scrollEdgeAppearance = tabs
    }
}

/// Square cover image with a dark placeholder.
struct CoverView: View {
    let url: URL?

    var body: some View {
        Color.kSurface
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(systemName: "music.note")
                    .font(.largeTitle)
                    .foregroundColor(Color.kMuted)
            }
            .overlay {
                if let url {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Color.clear
                        }
                    }
                }
            }
            .clipped()
    }
}

func clock(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds)
    return String(format: "%d:%02d", total / 60, total % 60)
}
