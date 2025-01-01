import Foundation

struct Category: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var emoji: String
    
    static let defaultCategories = [
        Category(name: "Food", emoji: "🍔"),
        Category(name: "Transport", emoji: "🚗"),
        Category(name: "Shopping", emoji: "🛍"),
        Category(name: "Entertainment", emoji: "🎮"),
        Category(name: "Bills", emoji: "📱"),
        Category(name: "Others", emoji: "📦")
    ]
}
