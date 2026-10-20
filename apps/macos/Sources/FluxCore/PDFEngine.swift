import Foundation
import PDFKit
import AppKit
import Vision
import ImageIO
import UniformTypeIdentifiers

public actor PDFEngine {
    public init() {}
    public static func pageIndices(_ text: String, count: Int) throws -> [Int] {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return Array(0..<count) }
        var result: [Int] = []
        for token in text.split(separator: ",", omittingEmptySubsequences: false) {
            let parts = token.trimmingCharacters(in: .whitespaces).split(separator: "-", omittingEmptySubsequences: false)
            guard (1...2).contains(parts.count), let a = Int(parts[0]), a > 0, a <= count else { throw EngineFailure.invalidOptions }
            let b = parts.count == 2 ? Int(parts[1]) : a
            guard let b, b >= a, b <= count else { throw EngineFailure.invalidOptions }
            result += Array((a-1)...(b-1))
            guard result.count <= 10000 else { throw EngineFailure.tooLarge }
        }
        return result
    }
    private func document(_ url: URL, password: String?) throws -> PDFDocument {
        guard let doc = PDFDocument(url: url) else { throw EngineFailure.unreadable }
        if doc.isLocked { guard let password, doc.unlock(withPassword: password) else { throw EngineFailure.password } }
        guard doc.pageCount > 0, doc.pageCount <= 10000 else { throw EngineFailure.tooLarge }
        guard doc.allowsCopying else { throw EngineFailure.protectedDocument }
        return doc
    }
    private func render(_ page: PDFPage, dpi: Int) throws -> CGImage {
        guard (36...300).contains(dpi) else { throw EngineFailure.invalidOptions }
        let bounds = page.bounds(for: .mediaBox), scale = Double(dpi) / 72
        let width = Int(bounds.width * scale), height = Int(bounds.height * scale)
        guard width > 0, height > 0, width < 16000, height < 16000, Int64(width)*Int64(height) < 80_000_000 else { throw EngineFailure.tooLarge }
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw EngineFailure.encode }
        ctx.setFillColor(CGColor(gray: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.scaleBy(x: scale, y: scale); ctx.translateBy(x: -bounds.minX, y: -bounds.minY)
        page.draw(with: .mediaBox, to: ctx)
        guard let image = ctx.makeImage() else { throw EngineFailure.encode }; return image
    }
    public func execute(inputs: [URL], step: ToolStep, staging: URL, password: String? = nil,
                        progress: @Sendable (Double) async -> Void = { _ in }) async throws -> [URL] {
        guard !inputs.isEmpty else { throw EngineFailure.invalidOptions }
        if step.tool == .imagesPDF {
            let combined = PDFDocument()
            for (i, input) in inputs.enumerated() {
                try Task.checkCancellation(); _ = try ImageEngine.inspect(input)
                guard let image = NSImage(contentsOf: input), let page = PDFPage(image: image) else { throw EngineFailure.unreadable }
                combined.insert(page, at: combined.pageCount); await progress(Double(i+1)/Double(inputs.count))
            }
            return [try write(combined, to: staging.appendingPathComponent("images.pdf"))]
        }
        let result = PDFDocument(); var outputs: [URL] = []; var texts: [String] = []
        for (fileIndex, input) in inputs.enumerated() {
            let doc = try document(input, password: password)
            let indices = try Self.pageIndices(step.pages, count: doc.pageCount)
            for (index, pageIndex) in indices.enumerated() {
                try Task.checkCancellation()
                guard let original = doc.page(at: pageIndex), let page = original.copy() as? PDFPage else { throw EngineFailure.unreadable }
                let name = "\(fileIndex+1)-page-\(index+1)"
                switch step.tool {
                case .pdfText: texts.append(page.string ?? "")
                case .pdfOCR:
                    let image = try render(page, dpi: step.dpi)
                    let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate; request.usesLanguageCorrection = true
                    request.recognitionLanguages = ["en-US", "es-ES"]
                    try VNImageRequestHandler(cgImage: image).perform([request])
                    texts.append((request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n"))
                case .pdfImages:
                    let image = try render(page, dpi: step.dpi), target = staging.appendingPathComponent(name + ".png")
                    guard let dest = CGImageDestinationCreateWithURL(target as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw EngineFailure.encode }
                    CGImageDestinationAddImage(dest, image, nil); guard CGImageDestinationFinalize(dest), let src = CGImageSourceCreateWithURL(target as CFURL, nil), CGImageSourceCreateImageAtIndex(src, 0, nil) != nil else { throw EngineFailure.verify }
                    outputs.append(target)
                case .pdfSplit:
                    let single = PDFDocument(); single.insert(page, at: 0); outputs.append(try write(single, to: staging.appendingPathComponent(name + ".pdf")))
                case .pdfRotate:
                    guard step.rotation % 90 == 0 else { throw EngineFailure.invalidOptions }
                    page.rotation = (page.rotation + step.rotation) % 360; result.insert(page, at: result.pageCount)
                case .pdfCompress:
                    // Explicit lossy raster PDF; preserves page geometry, removes searchable text and vector detail.
                    let image = try render(page, dpi: step.dpi)
                    let data = NSMutableData()
                    guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { throw EngineFailure.encode }
                    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: step.image.quality] as CFDictionary)
                    guard CGImageDestinationFinalize(destination), let nsImage = NSImage(data: data as Data), let raster = PDFPage(image: nsImage) else { throw EngineFailure.encode }
                    raster.setBounds(page.bounds(for: .mediaBox), for: .mediaBox); result.insert(raster, at: result.pageCount)
                default: result.insert(page, at: result.pageCount)
                }
                await progress((Double(fileIndex) + Double(index+1)/Double(indices.count))/Double(inputs.count))
            }
        }
        if [.pdfText, .pdfOCR].contains(step.tool) {
            let url = staging.appendingPathComponent("text.txt"); try texts.joined(separator: "\n\n\u{000C}\n\n").write(to: url, atomically: true, encoding: .utf8)
            _ = try String(contentsOf: url, encoding: .utf8); return [url]
        }
        if !outputs.isEmpty { return outputs }
        return [try write(result, to: staging.appendingPathComponent("document.pdf"))]
    }
    private func write(_ document: PDFDocument, to url: URL) throws -> URL {
        try Task.checkCancellation()
        guard document.write(to: url), let check = PDFDocument(url: url), !check.isLocked, check.pageCount == document.pageCount,
              (0..<check.pageCount).allSatisfy({ check.page(at: $0) != nil }) else { throw EngineFailure.verify }
        return url
    }
}
