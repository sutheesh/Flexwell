import SwiftUI
import MuscleMap
import FlexFitEngine

/// An anatomical front or back body (MuscleMap's male model, MIT licence) with our muscle groups lit:
/// primary in copper, secondary in sand, everything else a quiet slate on navy.
struct BodyFigure: View {
    enum Side: String { case front, back }

    let side: Side
    var primary: Set<MuscleGroup> = []
    var secondary: Set<MuscleGroup> = []
    /// Muscle outlines on/off (off for small thumbnails).
    var outlined = true
    /// Tapping a muscle on the figure (body map only).
    var onTap: ((MuscleGroup) -> Void)?

    /// The model's view box is 727 × 1280.
    static let aspect: CGFloat = 727.0 / 1280.0

    var body: some View {
        // The 3D render when it's bundled; the vector model otherwise (and for taps).
        if onTap == nil, MuscleHeatmap.isAvailable {
            MuscleHeatmap(side: side, primary: primary, secondary: secondary)
        } else {
            vectorFigure
        }
    }

    private var vectorFigure: some View {
        // The model's feet are toeless wedges; hide them and draw feet with toes in the same plate style.
        var view = BodyView(gender: .male, side: side == .front ? .front : .back, style: style)
            .highlight(.feet, color: .clear)
            // Ankles belong to the feet in the model, so they'd vanish with them; keep them in body colour.
            .highlight(.ankles, color: Palette.onPanel.opacity(0.2))
        for group in secondary {
            view = view.highlight(group.mapMuscles, color: Palette.sand)
        }
        for group in primary {
            view = view.highlight(group.mapMuscles, color: Palette.copper)
        }
        if primary.contains(.hips) || secondary.contains(.hips) {
            view = view.showSubGroups()
        }
        if let onTap {
            view = view.onMuscleSelected { muscle, _ in
                if let group = MuscleGroup(mapMuscle: muscle) { onTap(group) }
            }
        }
        return view
            .overlay {
                FeetShape(side: side)
                    .fill(Palette.onPanel.opacity(0.2))
                    .overlay { FeetShape(side: side).stroke(outlined ? Palette.navy.opacity(0.7) : .clear, lineWidth: 0.6) }
                    .allowsHitTesting(false)
            }
            .aspectRatio(Self.aspect, contentMode: .fit)
            // The model catches taps even without a handler; let cards and links underneath get them.
            .allowsHitTesting(onTap != nil)
            .accessibilityHidden(onTap == nil)
    }

    private var style: BodyViewStyle {
        BodyViewStyle(
            defaultFillColor: Palette.onPanel.opacity(0.2),
            strokeColor: outlined ? Palette.navy.opacity(0.7) : .clear,
            strokeWidth: outlined ? 0.6 : 0,
            selectionColor: Palette.copper,
            selectionStrokeColor: Palette.copper,
            selectionStrokeWidth: 0,
            headColor: Palette.onPanel.opacity(0.2),
            hairColor: Palette.onPanel.opacity(0.08)
        )
    }
}

/// RepDB's 3D body render with our muscle groups tinted on it: primary in copper, secondary in sand.
/// Each group is a grayscale cut of the render's own shading (`Heatmap/<side>_<group>`), so the tint keeps
/// the muscle's 3D shape.
struct MuscleHeatmap: View {
    let side: BodyFigure.Side
    var primary: Set<MuscleGroup> = []
    var secondary: Set<MuscleGroup> = []

    var body: some View {
        if let base = Self.image("\(side.rawValue)_base") {
            Image(uiImage: base)
                .resizable()
                .overlay {
                    ForEach(layers(secondary.subtracting(primary)), id: \.self) { layer($0, Palette.sand) }
                    ForEach(layers(primary), id: \.self) { layer($0, Palette.copper) }
                }
                .aspectRatio(base.size, contentMode: .fit)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func layers(_ groups: Set<MuscleGroup>) -> [UIImage] {
        groups.sorted { $0.rawValue < $1.rawValue }.compactMap { Self.image("\(side.rawValue)_\($0.rawValue)") }
    }

    private func layer(_ image: UIImage, _ tint: Color) -> some View {
        Image(uiImage: image).resizable().colorMultiply(tint)
    }

    /// Whether the renders are bundled.
    static var isAvailable: Bool { image("front_base") != nil && image("back_base") != nil }

    private static var cache: [String: UIImage?] = [:]
    private static func image(_ name: String) -> UIImage? {
        if let hit = cache[name] { return hit }
        let image = UIImage(named: "Heatmap/\(name)")
        cache[name] = image
        return image
    }
}

/// Feet with toes, drawn in the model's own coordinates (its 727 × 1280 view box) so they sit exactly under
/// its ankles: the top of the foot and five toes from the front, the heel and the edge of the sole from behind.
/// Each part is a separate plate, like the model's muscles. The right foot mirrors the left.
struct FeetShape: Shape {
    let side: BodyFigure.Side

    private typealias Curve = (to: CGPoint, c1: CGPoint, c2: CGPoint)
    private struct Plate { let start: CGPoint; let curves: [Curve] }

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
    private static func plate(_ start: CGPoint, _ c: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)]) -> Plate {
        Plate(start: start, curves: c.map { (to: p($0.4, $0.5), c1: p($0.0, $0.1), c2: p($0.2, $0.3)) })
    }
    /// A toe: an ellipse as four cubic curves.
    private static func toe(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Plate {
        let k: CGFloat = 0.5523
        return plate(p(cx - rx, cy), [
            (cx - rx, cy - ry * k, cx - rx * k, cy - ry, cx, cy - ry),
            (cx + rx * k, cy - ry, cx + rx, cy - ry * k, cx + rx, cy),
            (cx + rx, cy + ry * k, cx + rx * k, cy + ry, cx, cy + ry),
            (cx - rx * k, cy + ry, cx - rx, cy + ry * k, cx - rx, cy),
        ])
    }

    /// Left foot, front view (box x 0–727, y 95–1375).
    private static let front: [Plate] = [
        plate(p(275, 1286), [(287, 1292, 300, 1292, 308, 1284), (313, 1296, 315, 1308, 314, 1317),
                             (306, 1320, 296, 1321, 286, 1321), (274, 1321, 262, 1319, 254, 1314),
                             (260, 1303, 268, 1294, 275, 1286)]),
        toe(304.5, 1330, 8.5, 11.5), toe(292, 1331.5, 6, 9.5), toe(281.5, 1331, 5.5, 9),
        toe(271.5, 1328.5, 5, 8), toe(262.5, 1324, 4.3, 6.8),
    ]

    /// Left heel, back view (box x 718–1445, y 95–1375).
    private static let back: [Plate] = [
        plate(p(994, 1314), [(1002, 1310, 1014, 1310, 1021, 1314), (1024, 1326, 1023, 1337, 1015, 1343),
                             (1008, 1347, 1000, 1346, 995, 1342), (990, 1334, 990, 1324, 994, 1314)]),
        plate(p(992, 1336), [(984, 1338, 976, 1341, 977, 1344), (985, 1346, 993, 1345, 997, 1344),
                             (995, 1340, 994, 1338, 992, 1336)]),
    ]

    func path(in rect: CGRect) -> Path {
        let originX: CGFloat = side == .front ? 0 : 718
        let sx = rect.width / 727, sy = rect.height / 1280
        // The model is symmetric about x ≈ 365.35 of its box.
        func map(_ pt: CGPoint, mirrored: Bool) -> CGPoint {
            let x = pt.x - originX
            return CGPoint(x: rect.minX + (mirrored ? 730.7 - x : x) * sx, y: rect.minY + (pt.y - 95) * sy)
        }
        var path = Path()
        for mirrored in [false, true] {
            for plate in side == .front ? Self.front : Self.back {
                path.move(to: map(plate.start, mirrored: mirrored))
                for c in plate.curves {
                    path.addCurve(to: map(c.to, mirrored: mirrored),
                                  control1: map(c.c1, mirrored: mirrored), control2: map(c.c2, mirrored: mirrored))
                }
                path.closeSubpath()
            }
        }
        return path
    }
}

extension MuscleGroup {
    /// The MuscleMap regions that draw this group.
    var mapMuscles: [MuscleMap.Muscle] {
        switch self {
        case .shoulders: [.deltoids]
        case .chest: [.chest]
        case .biceps: [.biceps]
        case .triceps: [.triceps]
        case .forearms: [.forearm]
        case .abs: [.abs]
        case .obliques: [.obliques]
        case .traps: [.trapezius]
        case .back: [.upperBack]
        case .lowerBack: [.lowerBack]
        case .glutes: [.gluteal]
        case .hamstrings: [.hamstring]
        case .quads: [.quadriceps]
        case .adductors: [.adductors]
        case .calves: [.calves, .tibialis]
        case .hips: [.hipFlexors]
        case .cardio: []
        }
    }

    init?(mapMuscle: MuscleMap.Muscle) {
        let m = mapMuscle.parentGroup ?? mapMuscle
        if mapMuscle == .adductors { self = .adductors; return }
        if mapMuscle == .hipFlexors { self = .hips; return }
        guard let group = MuscleGroup.allCases.first(where: { $0.mapMuscles.contains(m) }) else { return nil }
        self = group
    }
}

/// Where each group's dot sits on the body-map photo and the row its label takes, as fractions of the photo
/// (x of its width, y of its height), placed by eye on `BodyMapFront` / `BodyMapBack` (784 × 1376).
/// Label rows are spaced apart; the leader line bends from the label to the dot.
enum BodyGeometry {
    struct Anchor {
        let group: MuscleGroup
        let point: CGPoint
        let labelY: CGFloat
        let leftLabel: Bool
    }

    static func anchors(_ side: BodyFigure.Side) -> [Anchor] {
        func a(_ g: MuscleGroup, _ x: CGFloat, _ y: CGFloat, label: CGFloat, left: Bool) -> Anchor {
            Anchor(group: g, point: CGPoint(x: x, y: y), labelY: label, leftLabel: left)
        }
        switch side {
        case .front:
            return [
                a(.shoulders, 0.319, 0.247, label: 0.19, left: true), a(.chest, 0.420, 0.290, label: 0.27, left: true),
                a(.obliques, 0.389, 0.378, label: 0.35, left: true), a(.forearms, 0.268, 0.443, label: 0.43, left: true),
                a(.hips, 0.400, 0.465, label: 0.51, left: true), a(.quads, 0.389, 0.567, label: 0.59, left: true),
                a(.cardio, 0.640, 0.070, label: 0.04, left: false), a(.traps, 0.590, 0.205, label: 0.12, left: false),
                a(.biceps, 0.695, 0.320, label: 0.26, left: false), a(.abs, 0.523, 0.349, label: 0.345, left: false),
                a(.adductors, 0.548, 0.618, label: 0.60, left: false), a(.calves, 0.600, 0.780, label: 0.76, left: false),
            ]
        case .back:
            return [
                a(.traps, 0.470, 0.215, label: 0.16, left: true), a(.shoulders, 0.335, 0.235, label: 0.235, left: true),
                a(.triceps, 0.280, 0.305, label: 0.31, left: true), a(.lowerBack, 0.470, 0.400, label: 0.39, left: true),
                a(.glutes, 0.420, 0.494, label: 0.48, left: true), a(.back, 0.631, 0.320, label: 0.30, left: false),
                a(.forearms, 0.733, 0.443, label: 0.42, left: false), a(.hamstrings, 0.585, 0.610, label: 0.60, left: false),
                a(.calves, 0.600, 0.790, label: 0.76, left: false),
            ]
        }
    }
}

/// The body-map photo (front or back), cut out onto transparency so the navy page shows through.
struct BodyPhoto: View {
    let side: BodyFigure.Side
    /// The photos are 784 × 1376.
    static let aspect: CGFloat = 784.0 / 1376.0

    var body: some View {
        Image(side == .front ? "BodyMapFront" : "BodyMapBack")
            .resizable()
            .aspectRatio(Self.aspect, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

extension MuscleGroup {
    var title: String {
        switch self {
        case .shoulders: "Shoulders"
        case .chest: "Chest"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .forearms: "Forearms"
        case .abs: "Abs"
        case .obliques: "Obliques"
        case .traps: "Traps"
        case .back: "Back"
        case .lowerBack: "Lower back"
        case .glutes: "Glutes"
        case .hamstrings: "Hamstrings"
        case .quads: "Quads"
        case .adductors: "Adductors"
        case .calves: "Calves"
        case .hips: "Hips"
        case .cardio: "Cardio"
        }
    }

    /// Which side of the figure shows this group best.
    var side: BodyFigure.Side {
        switch self {
        case .triceps, .back, .lowerBack, .glutes, .hamstrings: .back
        default: .front
        }
    }
}

extension Exercise {
    var primaryGroups: Set<MuscleGroup> { Set(primaryMuscles.map(MuscleGroup.group(of:))) }
    var secondaryGroups: Set<MuscleGroup> { Set(secondaryMuscles.map(MuscleGroup.group(of:))).subtracting(primaryGroups) }

    /// The side that shows most of what this exercise works.
    var bestSide: BodyFigure.Side {
        let back = primaryGroups.filter { $0.side == .back }.count
        return back > primaryGroups.count - back ? .back : .front
    }
}

#Preview {
    HStack {
        BodyFigure(side: .front, primary: [.quads], secondary: [.glutes, .adductors])
        BodyFigure(side: .back, primary: [.back], secondary: [.biceps, .shoulders])
        MuscleHeatmap(side: .front, primary: [.chest], secondary: [.abs, .biceps])
        MuscleHeatmap(side: .back, primary: [.back], secondary: [.traps])
    }
    .padding()
    .background(Palette.navy)
}
