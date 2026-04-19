/*
 * Copyright 2026 rootfont
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import CoreText

/// Main font manager for RootFont application
public class FontManager {
    
    private var fontCache: [String: CTFont] = [:]
    
    /// Singleton instance
    public static let shared = FontManager()
    
    private init() {}
    
    /// Load all available fonts on the system
    /// - Returns: Array of font family names
    public func loadAllFontFamilies() -> [String] {
        guard let familyNames = CTFontManagerCopyAvailableFontFamilyNames() as? [String] else {
            return []
        }
        return familyNames.sorted()
    }
    
    /// Get font names for a specific family
    /// - Parameter familyName: Font family name
    /// - Returns: Array of font names in the family
    public func fontNames(for familyName: String) -> [String] {
        guard let fontNames = CTFontManagerCopyAvailableFontURLs() as? [URL] else {
            return []
        }
        
        return fontNames
            .filter { $0.lastPathComponent.contains(familyName) }
            .map { $0.deletingPathExtension().lastPathComponent }
    }
    
    /// Preview text with specified font
    /// - Parameters:
    ///   - text: Text to preview
    ///   - fontName: Name of the font
    ///   - size: Font size
    /// - Returns: NSAttributedString with the font applied
    public func previewText(_ text: String, withFont fontName: String, size: CGFloat = 24) -> NSAttributedString {
        let font = CTFontCreateWithName(fontName as CFString, size, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.textColor
        ]
        
        return NSAttributedString(string: text, attributes: attributes)
    }
    
    /// Check if font is installed
    /// - Parameter fontName: Name of the font to check
    /// - Returns: Boolean indicating if font is installed
    public func isFontInstalled(_ fontName: String) -> Bool {
        let font = CTFontCreateWithName(fontName as CFString, 12, nil)
        let installedFontName = CTFontCopyPostScriptName(font) as String
        return installedFontName == fontName
    }
}