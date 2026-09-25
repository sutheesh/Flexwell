import SwiftUI
import WebKit

/// Privacy Policy and Terms, shown in-app (never handed off to Safari mid-purchase).
enum LegalPage: String, Identifiable {
    case privacy, terms
    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: "Privacy Policy"
        case .terms: "Terms of Use"
        }
    }

    var url: URL {
        switch self {
        // TODO(launch): host FlexFit's own privacy policy and put its URL here. This placeholder is not live.
        case .privacy: URL(string: "https://ilabbs.com/flexfit/privacy")!
        // Apple's standard EULA until FlexFit has its own terms.
        case .terms: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
        }
    }
}

extension View {
    /// Presented from a background so it composes with whatever sheet is already showing this view.
    func legalPage(_ page: Binding<LegalPage?>) -> some View {
        background { Color.clear.sheet(item: page) { LegalWebView(page: $0) } }
    }
}

private struct LegalWebView: View {
    let page: LegalPage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WebContent(url: page.url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(page.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct WebContent: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url == nil { webView.load(URLRequest(url: url)) }
    }
}
