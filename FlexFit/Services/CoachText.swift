import Foundation
import FlexFitEngine
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Friendly copy for today's session (PRD: Apple Foundation Models "for plan text and variety",
/// structured output only; devices without Apple Intelligence get the same logic with template copy).
/// The model only phrases facts the engine already decided — it never changes numbers or safety.
enum CoachText {
    struct SessionFacts: Hashable {
        let name: String
        let focus: String
        let minutes: Int
        let exercises: Int
        let rpeCap: Int
        let variant: SessionVariant
        let travel: Bool
        let tone: CoachTone
    }

    static func template(_ f: SessionFacts) -> String {
        let base: String = switch f.variant {
        case .full: "\(f.focus), \(f.minutes) minutes, \(f.exercises) exercises. Stop each set about 2 reps shy of failure (RPE \(f.rpeCap))."
        case .trimmed: "Short version today: \(f.minutes) minutes, top lifts only. It still counts."
        case .minimum: "Minimum day: \(f.minutes) easy minutes of mobility and one lift. The streak holds."
        }
        let travel = f.travel ? " Travel kit only." : ""
        return switch f.tone {
        case .direct: base + travel
        case .warm: "\(f.name), " + base.prefix(1).lowercased() + base.dropFirst() + travel + " You've got this."
        case .hard: base + travel + " No skipping."
        }
    }

    static var isModelAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    /// On-device text when available, otherwise the template. Never throws; never blocks the UI.
    static func sessionIntro(_ f: SessionFacts) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), SystemLanguageModel.default.availability == .available {
            if let text = try? await generate(f), isAcceptable(text, facts: f) { return text }
        }
        #endif
        return template(f)
    }

    /// Guardrail on generated text: short, and it must not invent numbers the engine didn't give.
    static func isAcceptable(_ text: String, facts f: SessionFacts) -> Bool {
        guard !text.isEmpty, text.count <= 220 else { return false }
        let allowed: Set<String> = ["\(f.minutes)", "\(f.exercises)", "\(f.rpeCap)", "2"]
        let numbers = text.split(whereSeparator: { !$0.isNumber }).map(String.init)
        return numbers.allSatisfy(allowed.contains)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    @Generable
    struct Intro {
        @Guide(description: "One or two short sentences introducing today's workout. No medical advice.")
        var text: String
    }

    @available(iOS 26.0, *)
    private static func generate(_ f: SessionFacts) async throws -> String {
        let tone = switch f.tone {
        case .direct: "short, factual, no fluff"
        case .warm: "encouraging but honest"
        case .hard: "firm, holds them to it"
        }
        let session = LanguageModelSession(instructions: """
            You write one or two short sentences introducing a strength session in a fitness app. \
            Tone: \(tone). Use only the facts given; do not add numbers, exercises, diet or medical advice.
            """)
        let facts = """
            Name: \(f.name). Session: \(f.focus). Minutes: \(f.minutes). Exercises: \(f.exercises). \
            Effort cap: RPE \(f.rpeCap). Version: \(f.variant.rawValue). Travel mode: \(f.travel ? "yes" : "no").
            """
        let response = try await session.respond(to: facts, generating: Intro.self)
        return response.content.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    #endif
}
