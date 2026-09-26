import AVFoundation
import UIKit
import Vision
import FlexFitEngine

// MARK: - On-device recognition

/// All recognition runs on the phone (PRD privacy promise). Only a barcode number is ever sent out.
enum FoodVision {
    /// Food candidates for a photo, via Vision's built-in image classifier.
    static func classify(_ image: UIImage) async -> [FoodFacts] {
        guard let cg = image.cgImage else { return [] }
        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, _ in
                let labels = (request.results as? [VNClassificationObservation] ?? [])
                    .filter { $0.confidence > 0.05 }
                    .map { (label: $0.identifier, confidence: Double($0.confidence)) }
                continuation.resume(returning: FoodRecognizer.candidates(for: labels, limit: 4))
            }
            do {
                try VNImageRequestHandler(cgImage: cg, orientation: image.cgOrientation).perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    /// Text lines from a photographed nutrition label.
    static func readText(_ image: UIImage) async -> [String] {
        guard let cg = image.cgImage else { return [] }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            do {
                try VNImageRequestHandler(cgImage: cg, orientation: image.cgOrientation).perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
}

extension UIImage {
    var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }

    /// A small JPEG for the food log (kept light for iCloud sync).
    func logThumbnail() -> Data? {
        let side: CGFloat = 480
        let scale = min(1, side / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: target)) }.jpegData(compressionQuality: 0.7)
    }
}

// MARK: - Barcode lookup

/// Open Food Facts: a free, public product database. Only the barcode number is sent.
enum OpenFoodFacts {
    struct Response: Decodable {
        struct Product: Decodable {
            let product_name: String?
            let categories: String?
            let serving_quantity: Double?
            let nutriments: [String: NumberOrString]?
        }
        let status: Int?
        let product: Product?
    }

    /// Nutriment values arrive as numbers or numeric strings.
    struct NumberOrString: Decodable {
        let value: Double?
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let d = try? c.decode(Double.self) { value = d }
            else if let s = try? c.decode(String.self) { value = Double(s) }
            else { value = nil }
        }
    }

    enum LookupError: Error { case notFound, network }

    static func lookup(barcode: String) async throws -> FoodFacts {
        let fields = "product_name,categories,serving_quantity,nutriments"
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=\(fields)") else {
            throw LookupError.notFound
        }
        var request = URLRequest(url: url)
        request.setValue("FlexFit iOS - food logging", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { throw LookupError.network }
        guard let r = try? JSONDecoder().decode(Response.self, from: data), r.status == 1, let p = r.product,
              let n = p.nutriments, let kcal = n["energy-kcal_100g"]?.value else { throw LookupError.notFound }
        let category = p.categories?.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? "Packaged"
        return FoodFacts(name: p.product_name?.isEmpty == false ? p.product_name! : "Barcode \(barcode)",
                         category: category,
                         kcalPer100g: kcal,
                         proteinPer100g: n["proteins_100g"]?.value ?? 0,
                         carbsPer100g: n["carbohydrates_100g"]?.value ?? 0,
                         fatPer100g: n["fat_100g"]?.value ?? 0,
                         defaultGrams: Int(p.serving_quantity ?? 100))
    }
}

// MARK: - Camera

/// Live camera for the scanner: preview, still photos, and barcode detection.
final class CameraController: NSObject, @unchecked Sendable, AVCapturePhotoCaptureDelegate, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let queue = DispatchQueue(label: "flexfit.camera")
    private var position: AVCaptureDevice.Position = .back
    private var photoContinuation: CheckedContinuation<UIImage?, Never>?

    /// Called on the main queue with each barcode read while barcode mode is on.
    var onBarcode: ((String) -> Void)?
    var barcodeEnabled = false {
        didSet { queue.async { self.metadataOutput.metadataObjectTypes = self.barcodeEnabled ? Self.barcodeTypes.filter(self.metadataOutput.availableMetadataObjectTypes.contains) : [] } }
    }

    static let barcodeTypes: [AVMetadataObject.ObjectType] = [.ean13, .ean8, .upce, .code128]

    static var isAvailable: Bool { AVCaptureDevice.default(for: .video) != nil }

    func start() async -> Bool {
        guard await AVCaptureDevice.requestAccess(for: .video) else { return false }
        return await withCheckedContinuation { continuation in
            queue.async {
                self.configure()
                if !self.session.isRunning { self.session.startRunning() }
                continuation.resume(returning: self.session.isRunning)
            }
        }
    }

    func stop() { queue.async { self.session.stopRunning() } }

    func flip() {
        queue.async {
            self.position = self.position == .back ? .front : .back
            self.session.beginConfiguration()
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.addInput()
            self.session.commitConfiguration()
        }
    }

    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            queue.async {
                guard self.session.isRunning else { continuation.resume(returning: nil); return }
                self.photoContinuation = continuation
                self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            }
        }
    }

    private func configure() {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        addInput()
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        }
        session.commitConfiguration()
    }

    private func addInput() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return }
        session.addInput(input)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        photoContinuation?.resume(returning: image)
        photoContinuation = nil
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard barcodeEnabled, let code = (objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        onBarcode?(code)
    }
}
