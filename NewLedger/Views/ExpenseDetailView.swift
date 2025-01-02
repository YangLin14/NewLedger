import SwiftUI
import VisionKit
import Vision

struct ExpenseDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: ExpenseStore
    let expense: Expense
    @State private var showingEditSheet = false
    @State private var imageData: Data?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Receipt Image Section
                if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                }
                
                // Expense Details
                VStack(spacing: 16) {
                    HStack {
                        Text(expense.category.emoji)
                            .font(.system(size: 40))
                        
                        VStack(alignment: .leading) {
                            Text(expense.name)
                                .font(.title2)
                                .bold()
                            Text(expense.category.name)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Amount")
                            Spacer()
                            Text(expense.amount.formatted(.currency(code: store.profile.currency.rawValue)))
                                .bold()
                        }
                        
                        HStack {
                            Text("Date")
                            Spacer()
                            Text(expense.date.formatted(date: .long, time: .shortened))
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                }
                .padding()
            }
        }
        .navigationTitle("Expense Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddExpenseView(expense: expense, isEditing: true)
        }
        .onAppear {
            // Load receipt image if available
            if let imageData = store.getReceiptImage(for: expense.id) {
                self.imageData = imageData
            }
        }
    }
}

struct ReceiptScannerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var name: String
    @Binding var amount: Double
    @Binding var date: Date
    @Binding var receiptImage: UIImage?
    
    @StateObject private var scannerViewModel = ScannerViewModel()
    @State private var showingScanner = false
    
    var body: some View {
        VStack {
            if let image = receiptImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
            }
            
            Button {
                showingScanner = true
            } label: {
                Label("Scan Receipt", systemImage: "doc.text.viewfinder")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
        .sheet(isPresented: $showingScanner) {
            DocumentScanner { result in
                switch result {
                case .success(let scan):
                    let scannedImage = scan.imageOfPage(at: 0)  // Get first page
                    receiptImage = scannedImage
                    scannerViewModel.processReceipt(scannedImage)
                case .failure(let error):
                    print("Scanning failed: \(error.localizedDescription)")
                }
            }
        }
        .onChange(of: scannerViewModel.extractedMerchantName) { _, newValue in
            if let merchantName = newValue {
                name = merchantName
            }
        }
        .onChange(of: scannerViewModel.extractedAmount) { _, newValue in
            if let totalAmount = newValue {
                amount = totalAmount
            }
        }
        .onChange(of: scannerViewModel.extractedDate) { _, newValue in
            if let receiptDate = newValue {
                date = receiptDate
            }
        }
    }
}

@MainActor
class ScannerViewModel: ObservableObject {
    @Published var extractedMerchantName: String?
    @Published var extractedAmount: Double?
    @Published var extractedDate: Date?
    
    func processReceipt(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            let text = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            // Process the extracted text to find relevant information
            self?.extractInformation(from: text)
        }
        
        try? requestHandler.perform([request])
    }
    
    private func extractInformation(from text: String) {
        let lines = text.components(separatedBy: .newlines)
        
        // Extract merchant name (first non-empty line)
        extractedMerchantName = lines.first { !$0.isEmpty }
        
        // Extract total amount
        if let totalLine = lines.first(where: { $0.lowercased().contains("total") }) {
            let numbers = totalLine.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .joined()
            if let total = Double(numbers) {
                extractedAmount = total / 100 // Convert cents to dollars
            }
        }
        
        // Extract date (simplified - enhance based on your needs)
        if let dateLine = lines.first(where: { $0.contains("/") }) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yyyy"
            if let date = formatter.date(from: dateLine) {
                extractedDate = date
            }
        }
    }
}

struct DocumentScanner: UIViewControllerRepresentable {
    let completion: (Result<VNDocumentCameraScan, Error>) -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completion: (Result<VNDocumentCameraScan, Error>) -> Void
        
        init(completion: @escaping (Result<VNDocumentCameraScan, Error>) -> Void) {
            self.completion = completion
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            completion(.success(scan))
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            completion(.failure(error))
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
    }
}
