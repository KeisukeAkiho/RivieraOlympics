import PDFKit
import SwiftUI

struct OfficialPDFPage: View {
    private var pdfURL: URL? {
        Bundle.main.url(forResource: "RivieraOlympicsRules", withExtension: "pdf")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "doc.fill")
                    .foregroundStyle(RivieraTheme.fairway)
                VStack(alignment: .leading, spacing: 2) {
                    Text("公式PDF（原文）")
                        .font(.headline)
                    Text("リビエラ会オリンピックルール 2025.8.26")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemBackground))

            Divider()

            if let pdfURL {
                PDFKitView(url: pdfURL)
            } else {
                ContentUnavailableView(
                    "PDFが見つかりません",
                    systemImage: "doc.questionmark",
                    description: Text("アプリを再インストールしてください。")
                )
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(url: url)
        view.backgroundColor = .systemGroupedBackground
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}
