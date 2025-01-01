import Foundation

struct Expense: Identifiable, Codable {
    var id = UUID()
    var name: String
    var amount: Double
    var date: Date
    var category: Category
}
