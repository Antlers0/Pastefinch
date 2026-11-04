import AppKit
import Foundation
import SwiftUI

struct ParsedColor: Hashable {
    let color: NSColor
    let hex: String
    let rgbLabel: String

    var swiftUIColor: Color { Color(nsColor: color) }
}

enum ColorParser {
    static func parse(_ raw: String) -> ParsedColor? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 64 else { return nil }

        if let hex = parseHex(text) { return hex }
        if let rgb = parseRGB(text) { return rgb }
        return nil
    }

    private static func make(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1) -> ParsedColor {
        let color = NSColor(srgbRed: r, green: g, blue: b, alpha: a)
        let ri = Int((r * 255).rounded())
        let gi = Int((g * 255).rounded())
        let bi = Int((b * 255).rounded())
        let ai = Int((a * 255).rounded())
        let hex: String
        if ai >= 255 {
            hex = String(format: "#%02X%02X%02X", ri, gi, bi)
        } else {
            hex = String(format: "#%02X%02X%02X%02X", ri, gi, bi, ai)
        }
        let rgbLabel: String
        if a >= 0.999 {
            rgbLabel = "rgb(\(ri), \(gi), \(bi))"
        } else {
            let aText = String(format: "%.2f", Double(a))
            rgbLabel = "rgba(\(ri), \(gi), \(bi), \(aText))"
        }
        return ParsedColor(color: color, hex: hex, rgbLabel: rgbLabel)
    }

    private static func parseHex(_ text: String) -> ParsedColor? {
        var s = text
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.allSatisfy(\.isHexDigit) else { return nil }

        func nibble(_ c: Character) -> CGFloat? {
            guard let v = Int(String(c), radix: 16) else { return nil }
            return CGFloat(v) / 15
        }
        func byte(_ pair: Substring) -> CGFloat? {
            guard let v = Int(pair, radix: 16) else { return nil }
            return CGFloat(v) / 255
        }

        switch s.count {
        case 3:
            let chars = Array(s)
            guard let r = nibble(chars[0]), let g = nibble(chars[1]), let b = nibble(chars[2]) else { return nil }
            return make(r: r, g: g, b: b)
        case 4:
            let chars = Array(s)
            guard let r = nibble(chars[0]), let g = nibble(chars[1]),
                  let b = nibble(chars[2]), let a = nibble(chars[3]) else { return nil }
            return make(r: r, g: g, b: b, a: a)
        case 6:
            let idx = s.index(s.startIndex, offsetBy: 2)
            let idx2 = s.index(idx, offsetBy: 2)
            guard let r = byte(s[..<idx]),
                  let g = byte(s[idx..<idx2]),
                  let b = byte(s[idx2...]) else { return nil }
            return make(r: r, g: g, b: b)
        case 8:
            let i1 = s.index(s.startIndex, offsetBy: 2)
            let i2 = s.index(i1, offsetBy: 2)
            let i3 = s.index(i2, offsetBy: 2)
            guard let r = byte(s[..<i1]),
                  let g = byte(s[i1..<i2]),
                  let b = byte(s[i2..<i3]),
                  let a = byte(s[i3...]) else { return nil }
            return make(r: r, g: g, b: b, a: a)
        default:
            return nil
        }
    }

    private static func parseRGB(_ text: String) -> ParsedColor? {
        let lower = text.lowercased()
        let pattern = #"^rgba?\(\s*([0-9]{1,3})\s*,\s*([0-9]{1,3})\s*,\s*([0-9]{1,3})(?:\s*,\s*([0-9]*\.?[0-9]+))?\s*\)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) else {
            return nil
        }

        func intGroup(_ idx: Int) -> Int? {
            guard let range = Range(match.range(at: idx), in: lower) else { return nil }
            return Int(lower[range])
        }
        func floatGroup(_ idx: Int) -> CGFloat? {
            guard match.range(at: idx).location != NSNotFound,
                  let range = Range(match.range(at: idx), in: lower),
                  let v = Double(lower[range]) else { return nil }
            return CGFloat(v)
        }

        guard let r = intGroup(1), let g = intGroup(2), let b = intGroup(3),
              (0...255).contains(r), (0...255).contains(g), (0...255).contains(b) else {
            return nil
        }
        let a = floatGroup(4) ?? 1
        guard a >= 0, a <= 1 else { return nil }
        return make(r: CGFloat(r) / 255, g: CGFloat(g) / 255, b: CGFloat(b) / 255, a: a)
    }
}
