import Foundation

struct Expense: Identifiable, Codable {
    var id = UUID()
    var name: String
    var amount: Double
    var date: Date
    var category: Category
}

extension Expense {
    var receiptImageURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("receipts")
            .appendingPathComponent("\(id.uuidString).jpg")
    }
}
