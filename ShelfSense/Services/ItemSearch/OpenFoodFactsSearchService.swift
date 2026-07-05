//
//  OpenFoodFactsSearchService.swift
//  ShelfSense
//

import Foundation

enum OpenFoodFactsSearchService {
    private struct SearchResponse: Decodable {
        struct Product: Decodable {
            let product_name: String?
            let brands: String?
            let nutriscore_grade: String?
            let nutriscore_score: Int?
            let quantity: String?
            let image_url: String?
            let code: String?
        }

        let products: [Product]
    }

    static func search(query: String) async -> [ItemSearchOffer] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let fields = "product_name,brands,nutriscore_grade,nutriscore_score,quantity,image_url,code"
        guard let url = URL(string: "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(encoded)&json=true&page_size=12&fields=\(fields)") else { return [] }

        var request = URLRequest(url: url)
        request.setValue("StorePing/1.0 (iOS grocery search)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(SearchResponse.self, from: data) else { return [] }

        return decoded.products.compactMap { product in
            guard let name = product.product_name?.trimmingCharacters(in: .whitespacesAndNewlines),
                  name.count >= 3 else { return nil }

            let brand = product.brands?
                .components(separatedBy: ",")
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return ItemSearchOffer(
                id: "off-\(product.code ?? name)",
                productName: name,
                brand: brand,
                price: 0,
                originalPrice: nil,
                rating: nutriscoreRating(grade: product.nutriscore_grade, score: product.nutriscore_score),
                reviewCount: nil,
                storeName: "Open Food Facts",
                source: .openFoodFacts,
                distanceMeters: nil,
                productURL: product.code.flatMap { URL(string: "https://world.openfoodfacts.org/product/\($0)") },
                imageURL: product.image_url.flatMap(URL.init(string:)),
                notes: foodGradeLabel(grade: product.nutriscore_grade, quantity: product.quantity)
            )
        }
    }

    private static func nutriscoreRating(grade: String?, score: Int?) -> Double? {
        if let grade {
            switch grade.lowercased() {
            case "a": return 5
            case "b": return 4
            case "c": return 3
            case "d": return 2
            case "e": return 1
            default: break
            }
        }
        if let score {
            return max(1, min(5, 5 - Double(score) / 3.0))
        }
        return nil
    }

    private static func foodGradeLabel(grade: String?, quantity: String?) -> String? {
        var parts: [String] = []
        if let grade { parts.append("Nutri-Score \(grade.uppercased())") }
        if let quantity { parts.append(quantity) }
        return parts.isEmpty ? "Food product catalog" : parts.joined(separator: " · ")
    }
}
