import SwiftUI
import PhotosUI
import AVFoundation
import FlexFitEngine

/// "Food Scanner" (reference design): camera with corner brackets, four modes, shutter.
/// Always dark (it's a camera), so fixed tokens throughout.
struct FoodScannerView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case food = "Scan Food", barcode = "Barcode", label = "Food Label", library = "Library"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .food: "fork.knife"
            case .barcode: "barcode.viewfinder"
            case .label: "doc.text.viewfinder"
            case .library: "photo.on.rectangle"
            }
        }
        var hint: String {
            switch self {
            case .food: "Fit your plate inside the frame and tap the shutter."
            case .barcode: "Point at the barcode. It reads on its own."
            case .label: "Fill the frame with the nutrition panel and tap the shutter."
            case .library: "Pick a photo of what you ate."
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var camera = CameraController()
    @State private var cameraReady = false
    @State private var mode: Mode = .food
    @State private var working = false
    @State private var message: String?
    @State private var pickerItem: PhotosPickerItem?
    @State private var result: ScanResult?

    var body: some View {
        ZStack {
            Palette.navy.ignoresSafeArea()
            if cameraReady {
                CameraPreview(session: camera.session).ignoresSafeArea()
            } else {
                VStack(spacing: Space.sm) {
                    Image(systemName: "camera").font(TextStyle.display.font).foregroundStyle(Palette.onPanelMuted)
                    Text(CameraController.isAvailable ? "Allow camera access in Profile to scan." : "No camera here. Use Library or enter it by hand.")
                        .textStyle(.body).foregroundStyle(Palette.onPanelMuted).multilineTextAlignment(.center)
                }
                .padding(Space.xl)
            }
            LinearGradient(colors: [Palette.navy.opacity(0.35), .clear, Palette.navy.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                Spacer()
                ScanFrame().frame(width: Size.flower * 0.9, height: Size.flower)
                Text(message ?? mode.hint)
                    .textStyle(.caption)
                    .foregroundStyle(Palette.onPanel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.xl)
                    .padding(.top, Space.md)
                Spacer()
                modes
                bottomBar
            }
            .readableColumn()

            if working {
                Palette.navy.opacity(0.5).ignoresSafeArea()
                ProgressView().tint(Palette.onPanel).controlSize(.large)
            }
        }
        .task {
            cameraReady = await camera.start()
            camera.onBarcode = { code in Task { @MainActor in await lookup(code) } }
        }
        .onDisappear { camera.stop() }
        .onChange(of: mode) { _, new in
            message = nil
            camera.barcodeEnabled = new == .barcode
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await fromLibrary(item) }
        }
        .fullScreenCover(item: $result) { r in
            FoodDetailsView(result: r) { dismiss() }
        }
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            circleButton("arrow.left", label: "Back") { dismiss() }
            Spacer()
            Text("Food Scanner").textStyle(.headline).foregroundStyle(Palette.onPanel)
            Spacer()
            circleButton("xmark", label: "Close") { dismiss() }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.sm)
    }

    private var modes: some View {
        HStack(spacing: Space.xs) {
            ForEach(Mode.allCases) { m in
                let selected = m == mode
                Group {
                    if m == .library {
                        PhotosPicker(selection: $pickerItem, matching: .images) { ModeTile(mode: m, selected: selected) }
                            .simultaneousGesture(TapGesture().onEnded { mode = .library })
                    } else {
                        Button { mode = m } label: { ModeTile(mode: m, selected: selected) }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.lg)
    }

    private var bottomBar: some View {
        HStack {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: "photo")
                    .font(TextStyle.headline.font)
                    .foregroundStyle(Palette.onPanel)
                    .frame(width: Size.detailButton, height: Size.detailButton)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Choose a photo")
            Spacer()
            Button(action: shutter) {
                ZStack {
                    Circle().strokeBorder(Palette.white, lineWidth: 4)
                    Circle().fill(Palette.white).padding(Space.sm)
                    Image(systemName: mode == .label ? "doc.text.viewfinder" : "viewfinder")
                        .font(TextStyle.title2.font)
                        .foregroundStyle(Palette.navy)
                }
                .frame(width: Size.detailButton * 1.5, height: Size.detailButton * 1.5)
            }
            .buttonStyle(PressableStyle())
            .disabled(!cameraReady || mode == .barcode || mode == .library)
            .opacity(cameraReady && (mode == .food || mode == .label) ? 1 : 0.5)
            .accessibilityLabel(mode == .label ? "Read label" : "Scan food")
            Spacer()
            circleButton("arrow.triangle.2.circlepath", label: "Flip camera", filled: true) { camera.flip() }
                .disabled(!cameraReady)
        }
        .padding(.horizontal, Space.xl)
        .padding(.bottom, Space.lg)
        .overlay(alignment: .top) {
            Button { result = ScanResult(facts: nil, candidates: [], photo: nil, source: "manual") } label: {
                Text("Enter manually").textStyle(.micro).foregroundStyle(Palette.onPanelMuted)
            }
            .offset(y: -Space.lg)
        }
    }

    private func circleButton(_ icon: String, label: String, filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(TextStyle.rowTitle.font)
                .foregroundStyle(filled ? Palette.onPanel : Palette.navy)
                .frame(width: Size.detailButton, height: Size.detailButton)
                .background(filled ? Palette.navy : Palette.white, in: Circle())
                .overlay(Circle().strokeBorder(filled ? Palette.onPanelOutline : .clear))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Actions

    private func shutter() {
        Task {
            working = true
            defer { working = false }
            guard let photo = await camera.capturePhoto() else { message = "Couldn't take the photo. Try again."; return }
            if mode == .label { await fromLabel(photo) } else { await fromPhoto(photo, source: "scan") }
        }
    }

    private func fromPhoto(_ photo: UIImage, source: String) async {
        let candidates = await FoodVision.classify(photo)
        if candidates.isEmpty {
            message = "Couldn't recognise that. Pick a name on the next screen."
        }
        result = ScanResult(facts: candidates.first, candidates: candidates, photo: photo, source: source)
    }

    private func fromLabel(_ photo: UIImage) async {
        let lines = await FoodVision.readText(photo)
        guard let parsed = NutritionLabelParser.parse(lines) else {
            message = "Couldn't read the label. Get closer, keep it flat, and try again."
            return
        }
        let facts = FoodFacts(name: "", category: "Packaged", kcalPer100g: parsed.kcal, proteinPer100g: parsed.proteinG,
                              carbsPer100g: parsed.carbsG, fatPer100g: parsed.fatG,
                              defaultGrams: Int(parsed.servingGrams ?? 100))
        result = ScanResult(facts: facts, candidates: [], photo: photo, source: "label")
    }

    private func fromLibrary(_ item: PhotosPickerItem) async {
        working = true
        defer { working = false; pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
            message = "Couldn't open that photo."
            return
        }
        await fromPhoto(image, source: "library")
    }

    @MainActor
    private func lookup(_ code: String) async {
        guard mode == .barcode, !working, result == nil else { return }
        working = true
        camera.barcodeEnabled = false
        defer { working = false }
        do {
            let facts = try await OpenFoodFacts.lookup(barcode: code)
            result = ScanResult(facts: facts, candidates: [], photo: nil, source: "barcode")
        } catch OpenFoodFacts.LookupError.network {
            message = "No connection. Barcode lookups need the internet; try Food Label instead."
            camera.barcodeEnabled = true
        } catch {
            message = "Product \(code) isn't in the database. Try Food Label."
            camera.barcodeEnabled = true
        }
    }
}

private struct ModeTile: View {
    let mode: FoodScannerView.Mode
    let selected: Bool

    var body: some View {
        VStack(spacing: Space.xs) {
            Image(systemName: mode.icon).font(TextStyle.headline.font)
            Text(mode.rawValue).textStyle(.micro).lineLimit(1).minimumScaleFactor(0.8)
        }
        .foregroundStyle(selected ? Palette.navy : Palette.onPanel)
        .frame(maxWidth: .infinity, minHeight: Size.ingredientTile)
        .background {
            RoundedRectangle(cornerRadius: Radius.tile - 4)
                .fill(selected ? AnyShapeStyle(Palette.white) : AnyShapeStyle(.ultraThinMaterial))
        }
        .overlay(RoundedRectangle(cornerRadius: Radius.tile - 4).strokeBorder(Palette.onPanelOutline))
    }
}

/// What a scan produced, handed to Food Details.
struct ScanResult: Identifiable {
    let id = UUID()
    var facts: FoodFacts?
    var candidates: [FoodFacts]
    var photo: UIImage?
    var source: String
}

/// The white corner brackets around the scan area.
private struct ScanFrame: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, l = min(w, h) * 0.22, r = Radius.sheet
            Path { p in
                for (x, y, dx, dy) in [(0.0, 0.0, 1.0, 1.0), (w, 0, -1, 1), (0, h, 1, -1), (w, h, -1, -1)] {
                    p.move(to: CGPoint(x: x, y: y + dy * l))
                    p.addLine(to: CGPoint(x: x, y: y + dy * r))
                    p.addQuadCurve(to: CGPoint(x: x + dx * r, y: y), control: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x + dx * l, y: y))
                }
            }
            .stroke(Palette.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}

/// AVCaptureSession preview layer.
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
