import AppKit
import CoreImage

enum IconStyle {
    case solid           // Just the icon as silhouette
    case stacked         // Two copies offset
    case stackedFading   // Three copies with fading opacity
    case cascade         // Small/medium/large
    case dual            // Two side by side
}

struct IconGenerator {

    static func generateMenuBarIcon(style: IconStyle) -> NSImage {
        guard let claudeIcon = loadClaudeIcon() else {
            // Fallback to star
            return NSImage(systemSymbolName: "star.fill", accessibilityDescription: "StarCmd")!
        }

        let size = NSSize(width: 38, height: 24)

        let result: NSImage
        switch style {
        case .solid:
            result = createSolidIcon(from: claudeIcon, size: size)
        case .stacked:
            result = createStackedIcon(from: claudeIcon, size: size)
        case .stackedFading:
            result = createStackedFadingIcon(from: claudeIcon, size: size)
        case .cascade:
            result = createCascadeIcon(from: claudeIcon, size: size)
        case .dual:
            result = createDualIcon(from: claudeIcon, size: size)
        }

        result.isTemplate = true
        return result
    }

    private static func loadClaudeIcon() -> NSImage? {
        // Use Claude's actual tray icon template (the logo without background)
        let trayIconPath = "/Applications/Claude.app/Contents/Resources/TrayIconTemplate@2x.png"
        if let image = NSImage(contentsOfFile: trayIconPath) {
            return image
        }
        // Fallback to app icon (will be square)
        let claudePath = "/Applications/Claude.app"
        if FileManager.default.fileExists(atPath: claudePath) {
            return NSWorkspace.shared.icon(forFile: claudePath)
        }
        return nil
    }

    // MARK: - Style: Solid (single icon)

    private static func createSolidIcon(from source: NSImage, size: NSSize) -> NSImage {
        let result = NSImage(size: size)
        let iconSize: CGFloat = 20

        result.lockFocus()
        let x = (size.width - iconSize) / 2
        let y = (size.height - iconSize) / 2
        source.draw(in: NSRect(x: x, y: y, width: iconSize, height: iconSize))
        result.unlockFocus()

        return result
    }

    // MARK: - Style: Stacked (2 copies offset diagonally)

    private static func createStackedIcon(from source: NSImage, size: NSSize) -> NSImage {
        let result = NSImage(size: size)
        let iconSize: CGFloat = 20

        result.lockFocus()

        // Back copy (top-left, slightly faded)
        source.draw(in: NSRect(x: 0, y: size.height - iconSize + 2, width: iconSize, height: iconSize),
                   from: .zero,
                   operation: .sourceOver,
                   fraction: 0.4)

        // Front copy (bottom-right, solid)
        source.draw(in: NSRect(x: size.width - iconSize, y: -2, width: iconSize, height: iconSize))

        result.unlockFocus()
        return result
    }

    // MARK: - Style: Stacked with Fading Opacity (3 copies)

    private static func createStackedFadingIcon(from source: NSImage, size: NSSize) -> NSImage {
        let result = NSImage(size: size)
        let iconSize: CGFloat = 16

        result.lockFocus()

        // Back copy (faint)
        source.draw(in: NSRect(x: 0, y: size.height - iconSize + 2, width: iconSize, height: iconSize),
                   from: .zero,
                   operation: .sourceOver,
                   fraction: 0.2)

        // Middle copy
        source.draw(in: NSRect(x: 6, y: 1, width: iconSize, height: iconSize),
                   from: .zero,
                   operation: .sourceOver,
                   fraction: 0.5)

        // Front copy (solid)
        source.draw(in: NSRect(x: 12, y: -2, width: iconSize + 2, height: iconSize + 2),
                   from: .zero,
                   operation: .sourceOver,
                   fraction: 1.0)

        result.unlockFocus()
        return result
    }

    // MARK: - Style: Size Cascade (small to large)

    private static func createCascadeIcon(from source: NSImage, size: NSSize) -> NSImage {
        let result = NSImage(size: size)

        result.lockFocus()

        // Small (back)
        source.draw(in: NSRect(x: 0, y: size.height - 12, width: 12, height: 12),
                   from: .zero,
                   operation: .sourceOver,
                   fraction: 0.3)

        // Medium
        source.draw(in: NSRect(x: 6, y: 2, width: 16, height: 16),
                   from: .zero,
                   operation: .sourceOver,
                   fraction: 0.6)

        // Large (front)
        source.draw(in: NSRect(x: 12, y: -2, width: 20, height: 20),
                   from: .zero,
                   operation: .sourceOver,
                   fraction: 1.0)

        result.unlockFocus()
        return result
    }

    // MARK: - Style: Dual (two side by side)

    private static func createDualIcon(from source: NSImage, size: NSSize) -> NSImage {
        let result = NSImage(size: size)
        let iconSize: CGFloat = 22

        result.lockFocus()

        // Left icon (full opacity)
        source.draw(in: NSRect(x: 0, y: (size.height - iconSize) / 2, width: iconSize, height: iconSize))

        // Right icon (full opacity, slightly overlapping)
        source.draw(in: NSRect(x: 14, y: (size.height - iconSize) / 2, width: iconSize, height: iconSize))

        result.unlockFocus()
        return result
    }
}
