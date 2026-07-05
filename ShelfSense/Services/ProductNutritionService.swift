//
//  ProductNutritionService.swift
//  ShelfSense
//

import Foundation

struct ProductBrandOption: Identifiable, Sendable {
    let id: String
    let productName: String
    let brand: String?
    let barcode: String?
    let estimatedPrice: Double?
    let calories: Double?
    let carbs: Double?
    let protein: Double?
    let fat: Double?
    let fiber: Double?
    let sodium: Double?
    let servingSize: String?
    let imageURL: URL?
    let sourceLabel: String
    let nutriScore: String?
    let allergens: [String]
}

enum ProductNutritionService {
    private struct SearchResponse: Decodable {
        struct Product: Decodable {
            let product_name: String?
            let brands: String?
            let code: String?
            let quantity: String?
            let serving_size: String?
            let image_url: String?
            let nutriscore_grade: String?
            let allergens_tags: [String]?
            let nutriments: Nutriments?
        }

        let products: [Product]
    }

    private struct Nutriments: Decodable {
        let energyKcal: Double?
        let carbohydrates: Double?
        let proteins: Double?
        let fat: Double?
        let fiber: Double?
        let sodium: Double?

        enum CodingKeys: String, CodingKey {
            case energyKcal = "energy-kcal_100g"
            case carbohydrates = "carbohydrates_100g"
            case proteins = "proteins_100g"
            case fat = "fat_100g"
            case fiber = "fiber_100g"
            case sodium = "sodium_100g"
        }
    }

    static func brandOptions(for query: String) async -> [ProductBrandOption] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        async let catalog = fetchOpenFoodFacts(query: trimmed)
        async let priced = fetchPricedOptions(query: trimmed)

        let combined = await catalog + priced
        return Array(dedupe(combined).prefix(12))
    }

    static func lookupBarcode(_ barcode: String) async -> ProductBrandOption? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("StorePing/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else { return nil }

        struct ProductResponse: Decodable {
            struct Product: Decodable {
                let product_name: String?
                let brands: String?
                let code: String?
                let quantity: String?
                let serving_size: String?
                let image_url: String?
                let nutriscore_grade: String?
                let allergens_tags: [String]?
                let nutriments: Nutriments?
            }
            let product: Product?
        }

        guard let decoded = try? JSONDecoder().decode(ProductResponse.self, from: data),
              let product = decoded.product,
              let name = product.product_name?.trimmingCharacters(in: .whitespacesAndNewlines),
              name.count >= 2 else { return nil }

        let brand = product.brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let allergens = (product.allergens_tags ?? []).map { $0.replacingOccurrences(of: "en:", with: "").replacingOccurrences(of: "-", with: " ") }

        return ProductBrandOption(
            id: "off-\(product.code ?? barcode)",
            productName: name,
            brand: brand,
            barcode: product.code ?? barcode,
            estimatedPrice: nil,
            calories: product.nutriments?.energyKcal,
            carbs: product.nutriments?.carbohydrates,
            protein: product.nutriments?.proteins,
            fat: product.nutriments?.fat,
            fiber: product.nutriments?.fiber,
            sodium: product.nutriments?.sodium,
            servingSize: product.serving_size ?? product.quantity,
            imageURL: product.image_url.flatMap(URL.init(string:)),
            sourceLabel: "Barcode lookup · Open Food Facts",
            nutriScore: product.nutriscore_grade?.uppercased(),
            allergens: allergens
        )
    }

    private static func fetchOpenFoodFacts(query: String) async -> [ProductBrandOption] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let fields = "product_name,brands,code,quantity,serving_size,image_url,nutriments"
        guard let url = URL(string: "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(encoded)&json=true&page_size=10&fields=\(fields)") else { return [] }

        var request = URLRequest(url: url)
        request.setValue("StorePing/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(SearchResponse.self, from: data) else { return [] }

        return decoded.products.compactMap { product in
            guard let name = product.product_name?.trimmingCharacters(in: .whitespacesAndNewlines),
                  name.count >= 2 else { return nil }

            let brand = product.brands?
                .components(separatedBy: ",")
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return ProductBrandOption(
                id: "off-\(product.code ?? name)",
                productName: name,
                brand: brand,
                barcode: product.code,
                estimatedPrice: nil,
                calories: product.nutriments?.energyKcal,
                carbs: product.nutriments?.carbohydrates,
                protein: product.nutriments?.proteins,
                fat: product.nutriments?.fat,
                fiber: product.nutriments?.fiber,
                sodium: product.nutriments?.sodium,
                servingSize: product.serving_size ?? product.quantity,
                imageURL: product.image_url.flatMap(URL.init(string:)),
                sourceLabel: "Nutrition per 100g · Open Food Facts",
                nutriScore: product.nutriscore_grade?.uppercased(),
                allergens: (product.allergens_tags ?? []).map { $0.replacingOccurrences(of: "en:", with: "").replacingOccurrences(of: "-", with: " ") }
            )
        }
    }

    private static func fetchPricedOptions(query: String) async -> [ProductBrandOption] {
        let walmart = await WalmartProductSearchService.search(query: query)
        return walmart.prefix(6).map { offer in
            ProductBrandOption(
                id: offer.id,
                productName: offer.productName,
                brand: offer.brand,
                barcode: nil,
                estimatedPrice: offer.hasPrice ? offer.price : nil,
                calories: nil,
                carbs: nil,
                protein: nil,
                fat: nil,
                fiber: nil,
                sodium: nil,
                servingSize: nil,
                imageURL: offer.imageURL,
                sourceLabel: "Walmart online price",
                nutriScore: nil,
                allergens: []
            )
        }
    }

    private static func dedupe(_ options: [ProductBrandOption]) -> [ProductBrandOption] {
        var seen = Set<String>()
        return options.filter { option in
            let key = "\(option.brand ?? "")-\(option.productName)".lowercased()
            return seen.insert(key).inserted
        }
    }
}
