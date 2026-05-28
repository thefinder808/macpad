import SwiftUI
import AppKit
import Combine

enum ThemeOption: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
}

final class ThemeManager: ObservableObject {
    private static let key = "macpad.theme"

    @Published var selectedOption: ThemeOption {
        didSet {
            UserDefaults.standard.set(selectedOption.rawValue, forKey: Self.key)
            resolveCurrent()
        }
    }
    @Published private(set) var current: any AppTheme = Win11LightTheme()

    private var systemAppearanceObserver: NSObjectProtocol?

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.key),
           let opt = ThemeOption(rawValue: raw) {
            self.selectedOption = opt
        } else {
            self.selectedOption = .system
        }
        resolveCurrent()

        // Re-resolve when system appearance flips so .system tracks it.
        systemAppearanceObserver = DistributedNotificationCenter.default.addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resolveCurrent()
        }
    }

    deinit {
        if let observer = systemAppearanceObserver {
            DistributedNotificationCenter.default.removeObserver(observer)
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch selectedOption {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    private func resolveCurrent() {
        switch selectedOption {
        case .light:
            current = Win11LightTheme()
        case .dark:
            current = Win11DarkTheme()
        case .system:
            current = systemIsDark() ? Win11DarkTheme() : Win11LightTheme()
        }
    }

    private func systemIsDark() -> Bool {
        let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
        return style?.lowercased().contains("dark") ?? false
    }
}
