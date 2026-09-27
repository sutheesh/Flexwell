import SwiftUI
import WebKit

/// Privacy Policy, Terms and open-source acknowledgements, shown in-app (never handed off to Safari mid-purchase).
enum LegalPage: String, Identifiable {
    case privacy, terms, acknowledgements
    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: "Privacy Policy"
        case .terms: "Terms of Use"
        case .acknowledgements: "Acknowledgements"
        }
    }

    var url: URL? {
        switch self {
        // TODO(launch): host FlexFit's own privacy policy and put its URL here. This placeholder is not live.
        case .privacy: URL(string: "https://ilabbs.com/flexfit/privacy")!
        // Apple's standard EULA until FlexFit has its own terms.
        case .terms: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
        case .acknowledgements: nil
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
            Group {
                if let url = page.url {
                    WebContent(url: url).ignoresSafeArea(edges: .bottom)
                } else {
                    ScrollView {
                        Text(Acknowledgements.text)
                            .textStyle(.caption)
                            .foregroundStyle(Palette.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Space.lg)
                    }
                    .pageBackground()
                }
            }
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

/// Licences for the open-source code FlexFit ships.
enum Acknowledgements {
    static let text = """
    Exercise data by RepDB (repdb.co). Exercise illustrations in Gym come from the RepDB free-tier dataset, used under the RepDB Free Tier License: in-app use with attribution.

    MuscleMap (github.com/melihcolpan/MuscleMap), used for the body diagrams in Gym.

    MIT License

    Copyright (c) 2026 Melih Colpan

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    """
}
