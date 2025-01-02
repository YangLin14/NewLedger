import SwiftUI
import VisionKit
import Vision

struct ExpenseDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: ExpenseStore
    let expense: Expense
    @State private var showingEditSheet = false
    @State private var imageData: Data?
    @State private var isZoomViewPresented = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
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
                
                Spacer(minLength: 15)
                
                // Receipt Image Section
                if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 700)
                        .cornerRadius(12)
                        .padding()
                        .onTapGesture {
                            isZoomViewPresented = true
                        }
                }
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
        .sheet(isPresented: $isZoomViewPresented) {
            if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                ZoomableImageView(image: uiImage)
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

struct ZoomableImageView: View {
    let image: UIImage
    
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = max(1.0, lastScale * value) // Ensure scale does not go below 1.0
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        let newOffset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                        
                                        // Constrain dragging to screen bounds
                                        let halfWidth = (geometry.size.width * scale) / 2
                                        let halfHeight = (geometry.size.height * scale) / 2
                                        
                                        let maxX = max(halfWidth - geometry.size.width / 2, 0)
                                        let maxY = max(halfHeight - geometry.size.height / 2, 0)
                                        
                                        offset = CGSize(
                                            width: min(max(newOffset.width, -maxX), maxX),
                                            height: min(max(newOffset.height, -maxY), maxY)
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )
                        .onTapGesture {
                            dismiss() // Dismiss on tap
                        }
                    Spacer()
                }
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
                print("Updated amount: \(amount)")
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
        // print("Scanned text: \(lines)")

        // Extract store name and address
        if let addressIndex = lines.firstIndex(where: { $0.contains(",") && $0.range(of: "\\d{5}", options: .regularExpression) != nil }) {
            // Use the line above the address as the store name, if it exists
            if addressIndex > 0 {
                extractedMerchantName = lines[addressIndex - 2].trimmingCharacters(in: .whitespacesAndNewlines)
                print("Extracted store name: \(extractedMerchantName ?? "None")")
            }
        }

        // Extract the largest amount after the "$" symbol
        var largestAmount: Double = 0.0
        for line in lines {
            if line.contains("$") {
                let regex = try? NSRegularExpression(pattern: "\\$(\\d+(\\.\\d{1,2})?)")
                let matches = regex?.matches(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)) ?? []

                for match in matches {
                    if let matchRange = Range(match.range(at: 1), in: line) {
                        let numberString = String(line[matchRange])

                        if let amount = Double(numberString) {
                            largestAmount = max(largestAmount, amount)
                        }
                    }
                }
            }
        }
        if largestAmount > 0.0 {
            extractedAmount = largestAmount
            print("Extracted largest amount: \(largestAmount)")
        }

        // Extract the receipt date
        let dateFormats = ["MM/dd/yyyy", "MM-dd-yyyy", "yyyy-MM-dd", "MM/dd/yy", "MMMM d, yyyy"]
        let regex = try? NSRegularExpression(pattern: "\\b\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}\\b|\\b[A-Za-z]+\\s\\d{1,2},\\s\\d{4}\\b")

        for line in lines {
            if let match = regex?.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)) {
                if let matchRange = Range(match.range, in: line) {
                    var detectedDateString = String(line[matchRange])

                    // Normalize 2-digit year formats to 4-digit year (e.g., 12/17/24 -> 12/17/2024)
                    if detectedDateString.range(of: "\\d{1,2}/\\d{1,2}/\\d{2}", options: .regularExpression) != nil {
                        let components = detectedDateString.split(separator: "/")
                        if components.count == 3, let year = Int(components[2]), year < 100 {
                            detectedDateString = "\(components[0])/\(components[1])/20\(components[2])"
                        }
                    }

                    for dateFormat in dateFormats {
                        let formatter = DateFormatter()
                        formatter.dateFormat = dateFormat
                        if let detectedDate = formatter.date(from: detectedDateString) {
                            extractedDate = detectedDate
                            print("Extracted date: \(detectedDate)")
                            break
                        }
                    }
                }
            }
            if extractedDate != nil { break }
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
