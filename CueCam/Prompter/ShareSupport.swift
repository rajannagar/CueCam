import SwiftUI
import UIKit

/// SwiftUI wrapper around the system share sheet (AirDrop, Messages, TikTok,
/// Instagram, Save to Files, etc.).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

/// Renders a script to a clean, paginated PDF in the temporary directory.
enum ScriptPDF {
    static func make(from script: Script) -> URL? {
        let title = script.title.isEmpty ? "Script" : script.title
        let html = """
        <html><head><meta name="viewport" content="width=device-width"><style>
        body { font: -apple-system; margin: 0; color: #111; }
        h1 { font-size: 26px; margin: 0 0 16px 0; }
        pre { font-family: -apple-system, Helvetica, sans-serif; font-size: 15px;
              line-height: 1.5; white-space: pre-wrap; word-wrap: break-word; }
        </style></head><body>
        <h1>\(escape(title))</h1>
        <pre>\(escape(script.body))</pre>
        </body></html>
        """

        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

        let page = CGRect(x: 0, y: 0, width: 612, height: 792)            // US Letter
        let printable = page.insetBy(dx: 48, dy: 56)
        renderer.setValue(NSValue(cgRect: page), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printable), forKey: "printableRect")

        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, page, nil)
        let pages = max(renderer.numberOfPages, 1)
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: pages))
        for i in 0..<pages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()

        let safeName = title.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).pdf")
        do { try data.write(to: url); return url } catch { return nil }
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
