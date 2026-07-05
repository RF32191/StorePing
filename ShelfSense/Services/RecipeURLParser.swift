//
//  RecipeURLParser.swift
//  ShelfSense
//

import Foundation

enum RecipeURLParser {
    static func parseIngredients(from urlString: String) async -> [String] {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme, scheme.hasPrefix("http") else {
            return fallbackFromText(trimmed)
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return [] }
            return extractIngredients(from: html)
        } catch {
            return fallbackFromText(trimmed)
        }
    }

    private static func extractIngredients(from html: String) -> [String] {
        var items: [String] = []

        let patterns = [
            #"itemprop=\"recipeIngredient\"[^>]*>([^<]+)"#,
            #"\"recipeIngredient\"\s*:\s*\"([^\"]+)\""#,
            #"<li class=\"[^\"]*ingredient[^\"]*\"[^>]*>([^<]+)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            regex.enumerateMatches(in: html, range: range) { match, _, _ in
                guard let match, match.numberOfRanges > 1,
                      let capture = Range(match.range(at: 1), in: html) else { return }
                let text = String(html[capture])
                    .replacingOccurrences(of: "&nbsp;", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if text.count > 2, text.count < 80 { items.append(cleanIngredient(text)) }
            }
        }

        return Array(Set(items)).prefix(20).map { $0 }
    }

    private static func fallbackFromText(_ text: String) -> [String] {
        text
            .split(separator: ",")
            .map { cleanIngredient(String($0)) }
            .filter { $0.count > 2 }
    }

    private static func cleanIngredient(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "^[\\d/\\.\\s]+", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
