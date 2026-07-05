//
//  RecipeCatalog.swift
//  ShelfSense
//

import Foundation

struct RecipeIngredient: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let quantity: String
    let unit: String
}

struct Recipe: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let prepMinutes: Int
    let servings: Int
    let ingredients: [RecipeIngredient]
    let steps: [String]
    let tags: [String]
    let caloriesPerServing: Int?
    let carbsPerServing: Double?
    let proteinPerServing: Double?
    let isFastFood: Bool
    let fastFoodChain: String?

    static var all: [Recipe] { recipes + fastFoodItems }

    static func find(byName name: String) -> Recipe? {
        all.first { $0.name.lowercased() == name.lowercased() }
    }

    static func find(byID id: String) -> Recipe? {
        all.first { $0.id == id }
    }

    static func pantryMatches(inventoryNames: [String]) -> [Recipe] {
        let pantry = Set(inventoryNames.map { $0.lowercased() })
        return recipes.filter { recipe in
            let needed = recipe.ingredients.map { $0.name.lowercased() }
            let matched = needed.filter { ing in pantry.contains { $0.contains(ing) || ing.contains($0) } }
            return Double(matched.count) / Double(max(needed.count, 1)) >= 0.5
        }
    }

    private static let recipes: [Recipe] = [
        Recipe(id: "stir-fry", name: "Chicken stir-fry", category: "Quick", prepMinutes: 25, servings: 4,
               ingredients: [
                   RecipeIngredient(name: "chicken breast", quantity: "1", unit: "lb"),
                   RecipeIngredient(name: "soy sauce", quantity: "3", unit: "tbsp"),
                   RecipeIngredient(name: "vegetables", quantity: "2", unit: "cups"),
                   RecipeIngredient(name: "rice", quantity: "2", unit: "cups")
               ],
               steps: ["Cut chicken into strips.", "Stir-fry chicken until golden.", "Add vegetables and sauce.", "Serve over rice."],
               tags: ["meat", "quick"], caloriesPerServing: 420, carbsPerServing: 45, proteinPerServing: 32, isFastFood: false, fastFoodChain: nil),
        Recipe(id: "pasta-primavera", name: "Pasta primavera", category: "Vegetarian", prepMinutes: 30, servings: 4,
               ingredients: [
                   RecipeIngredient(name: "pasta", quantity: "12", unit: "oz"),
                   RecipeIngredient(name: "zucchini", quantity: "1", unit: "medium"),
                   RecipeIngredient(name: "bell pepper", quantity: "1", unit: "medium"),
                   RecipeIngredient(name: "olive oil", quantity: "2", unit: "tbsp")
               ],
               steps: ["Boil pasta.", "Sauté vegetables in olive oil.", "Toss pasta with vegetables.", "Season and serve."],
               tags: ["vegetarian"], caloriesPerServing: 380, carbsPerServing: 58, proteinPerServing: 12, isFastFood: false, fastFoodChain: nil),
        Recipe(id: "tacos", name: "Tacos", category: "Mexican", prepMinutes: 20, servings: 4,
               ingredients: [
                   RecipeIngredient(name: "ground beef", quantity: "1", unit: "lb"),
                   RecipeIngredient(name: "tortillas", quantity: "8", unit: "count"),
                   RecipeIngredient(name: "lettuce", quantity: "2", unit: "cups"),
                   RecipeIngredient(name: "cheese", quantity: "1", unit: "cup")
               ],
               steps: ["Brown beef with seasoning.", "Warm tortillas.", "Assemble with toppings."],
               tags: ["meat", "quick"], caloriesPerServing: 450, carbsPerServing: 35, proteinPerServing: 28, isFastFood: false, fastFoodChain: nil),
        Recipe(id: "salmon-bowls", name: "Salmon bowls", category: "Healthy", prepMinutes: 35, servings: 2,
               ingredients: [
                   RecipeIngredient(name: "salmon", quantity: "2", unit: "fillets"),
                   RecipeIngredient(name: "rice", quantity: "1", unit: "cup"),
                   RecipeIngredient(name: "avocado", quantity: "1", unit: "medium"),
                   RecipeIngredient(name: "cucumber", quantity: "1", unit: "medium")
               ],
               steps: ["Cook rice.", "Pan-sear salmon.", "Slice avocado and cucumber.", "Build bowls."],
               tags: ["fish", "healthy"], caloriesPerServing: 520, carbsPerServing: 42, proteinPerServing: 35, isFastFood: false, fastFoodChain: nil),
        Recipe(id: "veggie-curry", name: "Veggie curry", category: "Vegetarian", prepMinutes: 40, servings: 4,
               ingredients: [
                   RecipeIngredient(name: "coconut milk", quantity: "1", unit: "can"),
                   RecipeIngredient(name: "curry paste", quantity: "3", unit: "tbsp"),
                   RecipeIngredient(name: "potato", quantity: "2", unit: "medium"),
                   RecipeIngredient(name: "spinach", quantity: "2", unit: "cups")
               ],
               steps: ["Simmer potatoes in curry sauce.", "Add spinach at the end.", "Serve with rice."],
               tags: ["vegetarian", "vegan"], caloriesPerServing: 340, carbsPerServing: 48, proteinPerServing: 8, isFastFood: false, fastFoodChain: nil),
        Recipe(id: "sheet-pan-fajitas", name: "Sheet-pan fajitas", category: "Mexican", prepMinutes: 30, servings: 4,
               ingredients: [
                   RecipeIngredient(name: "chicken breast", quantity: "1.5", unit: "lb"),
                   RecipeIngredient(name: "bell pepper", quantity: "2", unit: "medium"),
                   RecipeIngredient(name: "onion", quantity: "1", unit: "large"),
                   RecipeIngredient(name: "tortillas", quantity: "8", unit: "count")
               ],
               steps: ["Slice chicken and vegetables.", "Roast on sheet pan at 425°F.", "Serve in warm tortillas."],
               tags: ["meat"], caloriesPerServing: 410, carbsPerServing: 38, proteinPerServing: 30, isFastFood: false, fastFoodChain: nil),
        Recipe(id: "greek-wraps", name: "Greek salad wraps", category: "Mediterranean", prepMinutes: 15, servings: 2,
               ingredients: [
                   RecipeIngredient(name: "pita", quantity: "2", unit: "count"),
                   RecipeIngredient(name: "feta", quantity: "4", unit: "oz"),
                   RecipeIngredient(name: "cucumber", quantity: "1", unit: "medium"),
                   RecipeIngredient(name: "tomato", quantity: "2", unit: "medium")
               ],
               steps: ["Chop vegetables.", "Crumble feta.", "Fill pitas with salad."],
               tags: ["vegetarian"], caloriesPerServing: 320, carbsPerServing: 28, proteinPerServing: 14, isFastFood: false, fastFoodChain: nil),
        Recipe(id: "tomato-soup", name: "Tomato soup + grilled cheese", category: "Comfort", prepMinutes: 25, servings: 4,
               ingredients: [
                   RecipeIngredient(name: "tomatoes", quantity: "28", unit: "oz can"),
                   RecipeIngredient(name: "bread", quantity: "8", unit: "slices"),
                   RecipeIngredient(name: "cheese", quantity: "8", unit: "slices"),
                   RecipeIngredient(name: "butter", quantity: "4", unit: "tbsp")
               ],
               steps: ["Simmer tomato soup.", "Butter bread and add cheese.", "Grill sandwiches.", "Serve together."],
               tags: ["vegetarian"], caloriesPerServing: 480, carbsPerServing: 52, proteinPerServing: 18, isFastFood: false, fastFoodChain: nil),
        Recipe(id: "burrito-bowls", name: "Burrito bowls", category: "Mexican", prepMinutes: 30, servings: 4,
               ingredients: [
                   RecipeIngredient(name: "rice", quantity: "2", unit: "cups"),
                   RecipeIngredient(name: "black beans", quantity: "1", unit: "can"),
                   RecipeIngredient(name: "corn", quantity: "1", unit: "cup"),
                   RecipeIngredient(name: "salsa", quantity: "1", unit: "cup")
               ],
               steps: ["Cook rice.", "Warm beans and corn.", "Layer bowls with toppings."],
               tags: ["vegetarian", "vegan"], caloriesPerServing: 390, carbsPerServing: 62, proteinPerServing: 14, isFastFood: false, fastFoodChain: nil),
        Recipe(id: "shrimp-fried-rice", name: "Shrimp fried rice", category: "Asian", prepMinutes: 20, servings: 4,
               ingredients: [
                   RecipeIngredient(name: "shrimp", quantity: "1", unit: "lb"),
                   RecipeIngredient(name: "rice", quantity: "3", unit: "cups"),
                   RecipeIngredient(name: "eggs", quantity: "2", unit: "count"),
                   RecipeIngredient(name: "soy sauce", quantity: "2", unit: "tbsp")
               ],
               steps: ["Scramble eggs.", "Cook shrimp.", "Fry rice with soy sauce.", "Combine and serve."],
               tags: ["fish"], caloriesPerServing: 440, carbsPerServing: 50, proteinPerServing: 26, isFastFood: false, fastFoodChain: nil),
        Recipe(id: "caprese-panini", name: "Caprese panini", category: "Italian", prepMinutes: 15, servings: 2,
               ingredients: [
                   RecipeIngredient(name: "bread", quantity: "4", unit: "slices"),
                   RecipeIngredient(name: "mozzarella", quantity: "8", unit: "oz"),
                   RecipeIngredient(name: "tomato", quantity: "2", unit: "medium"),
                   RecipeIngredient(name: "basil", quantity: "1/4", unit: "cup")
               ],
               steps: ["Layer mozzarella, tomato, basil.", "Grill in panini press.", "Serve hot."],
               tags: ["vegetarian"], caloriesPerServing: 380, carbsPerServing: 36, proteinPerServing: 20, isFastFood: false, fastFoodChain: nil),
        Recipe(id: "chili", name: "Chili", category: "Comfort", prepMinutes: 45, servings: 6,
               ingredients: [
                   RecipeIngredient(name: "ground beef", quantity: "1.5", unit: "lb"),
                   RecipeIngredient(name: "kidney beans", quantity: "2", unit: "cans"),
                   RecipeIngredient(name: "tomatoes", quantity: "28", unit: "oz can"),
                   RecipeIngredient(name: "onion", quantity: "1", unit: "large")
               ],
               steps: ["Brown beef with onion.", "Add beans and tomatoes.", "Simmer 30 minutes."],
               tags: ["meat"], caloriesPerServing: 420, carbsPerServing: 38, proteinPerServing: 32, isFastFood: false, fastFoodChain: nil)
    ]

    private static let fastFoodItems: [Recipe] = [
        "Chipotle", "In-N-Out", "Panera", "Subway", "Taco Bell",
        "McDonald's", "Wendy's", "Shake Shack", "Panda Express", "Five Guys",
        "Chick-fil-A", "Starbucks"
    ].map { chain in
        Recipe(
            id: "ff-\(chain.lowercased().replacingOccurrences(of: " ", with: "-"))",
            name: chain,
            category: "Fast Food",
            prepMinutes: 0,
            servings: 1,
            ingredients: [],
            steps: ["Head to \(chain) and enjoy! Check deals tab for any current promotions."],
            tags: ["fast-food"],
            caloriesPerServing: nil,
            carbsPerServing: nil,
            proteinPerServing: nil,
            isFastFood: true,
            fastFoodChain: chain
        )
    }
}
