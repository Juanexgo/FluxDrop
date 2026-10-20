import Foundation
import Yams
import CoreText
import CoreGraphics
import PDFKit

public actor DataEngine {
    public init() {}
    static func read(_ url: URL, encoding: String) throws -> String {
        guard (try url.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? Int.max <= 16_000_000 else { throw EngineFailure.tooLarge }
        let enc: String.Encoding = encoding == "utf16" ? .utf16 : encoding == "latin1" ? .isoLatin1 : .utf8
        guard let text = String(data: try Data(contentsOf: url), encoding: enc) else { throw EngineFailure.unreadable }; return text
    }
    public static func parseCSV(_ text: String, delimiter: Character) throws -> [[String]] {
        guard delimiter != "\"", delimiter != "\n", delimiter != "\r" else { throw EngineFailure.invalidOptions }
        let text = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        var rows: [[String]] = [], row: [String] = [], field = "", quoted = false, afterQuote = false
        let chars = Array(text); var i = 0
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" { if i+1 < chars.count && chars[i+1] == "\"" { field.append("\""); i += 1 } else { quoted = false; afterQuote = true } }
                else { field.append(c) }
            } else if c == delimiter { row.append(field); field = ""; afterQuote = false }
            else if c == "\n" || c == "\r" || c == "\r\n" {
                row.append(field); rows.append(row); row = []; field = ""; afterQuote = false
                if c == "\r", i+1 < chars.count, chars[i+1] == "\n" { i += 1 }
            } else if c == "\"" && field.isEmpty && !afterQuote { quoted = true }
            else { guard !afterQuote, c != "\"" else { throw EngineFailure.dataLoss }; field.append(c) }
            guard rows.count <= 100000, field.utf8.count <= 1_000_000 else { throw EngineFailure.tooLarge }
            i += 1
        }
        guard !quoted else { throw EngineFailure.dataLoss }
        if !row.isEmpty || !field.isEmpty || afterQuote { row.append(field); rows.append(row) }
        guard let width = rows.first?.count, width > 0, rows.allSatisfy({ $0.count == width }) else { throw EngineFailure.dataLoss }
        return rows
    }
    static func csv(_ rows: [[String]], delimiter: Character) -> String {
        rows.map { row in row.map { value in
            value.contains(delimiter) || value.contains("\"") || value.contains("\n") || value.contains("\r")
            ? "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : value
        }.joined(separator: String(delimiter)) }.joined(separator: "\r\n") + "\r\n"
    }
    static func jsonNode(_ node: Node, depth: Int = 0) throws -> Any {
        guard depth < 64, node.anchor == nil else { throw EngineFailure.dataLoss }
        switch node {
        case .alias: throw EngineFailure.dataLoss
        case .sequence(let sequence): return try sequence.map { try jsonNode($0, depth: depth+1) }
        case .mapping(let mapping):
            var result: [String: Any] = [:]
            for (key, value) in mapping {
                guard key.tag.description == "tag:yaml.org,2002:str", let string = key.string, result[string] == nil else { throw EngineFailure.dataLoss }
                result[string] = try jsonNode(value, depth: depth+1)
            }
            return result
        case .scalar:
            switch node.tag.description {
            case "tag:yaml.org,2002:str": return node.string ?? ""
            case "tag:yaml.org,2002:null": return NSNull()
            case "tag:yaml.org,2002:bool": guard let value = node.bool else { throw EngineFailure.dataLoss }; return value
            case "tag:yaml.org,2002:int": guard let value = node.int else { throw EngineFailure.dataLoss }; return value
            case "tag:yaml.org,2002:float": guard let value = node.float, value.isFinite else { throw EngineFailure.dataLoss }; return value
            default: throw EngineFailure.dataLoss
            }
        }
    }
    static func yamlValue(_ text: String) throws -> Any {
        // Node anchors are weak references; keep their owning parser alive through validation.
        let parser = try Yams.Parser(yaml: text)
        guard let node = try parser.singleRoot() else { throw EngineFailure.dataLoss }
        return try withExtendedLifetime(parser) { try jsonNode(node) }
    }
    static func json(_ text: String) throws -> Any {
        let parsed = try JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])
        _ = try yamlValue(text) // reject duplicate keys and values beyond the supported numeric range
        return parsed
    }
    static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
    /// Deliberately documented Markdown subset: headings, unordered lists, fenced code, paragraphs. HTML is escaped.
    public static func markdownHTML(_ text: String) -> String {
        var body = "", code = false, list = false
        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix("```") { if list { body += "</ul>"; list = false }; body += code ? "</code></pre>" : "<pre><code>"; code.toggle(); continue }
            if code { body += escape(line) + "\n"; continue }
            if line.hasPrefix("- ") || line.hasPrefix("* ") { if !list { body += "<ul>"; list = true }; body += "<li>" + escape(String(line.dropFirst(2))) + "</li>"; continue }
            if list { body += "</ul>"; list = false }
            let hashes = line.prefix { $0 == "#" }.count
            if (1...6).contains(hashes), line.dropFirst(hashes).hasPrefix(" ") { body += "<h\(hashes)>" + escape(String(line.dropFirst(hashes+1))) + "</h\(hashes)>" }
            else if !line.isEmpty { body += "<p>" + escape(line) + "</p>" }
        }
        if code { body += "</code></pre>" }; if list { body += "</ul>" }
        return "<!doctype html><html lang=\"en\"><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width\"><title>Document</title><style>body{font:18px system-ui;max-width:70ch;margin:3rem auto;padding:1rem;line-height:1.6}pre{white-space:pre-wrap;background:#eee;padding:1rem}</style><body>" + body + "</body></html>"
    }
    public func execute(inputs: [URL], step: ToolStep, staging: URL) throws -> [URL] {
        var outputs: [URL] = []
        guard step.delimiter.count == 1 else { throw EngineFailure.invalidOptions }
        for (i, input) in inputs.enumerated() {
            try Task.checkCancellation(); let text = try Self.read(input, encoding: step.encoding)
            var result = "", ext = "json"
            switch step.tool {
            case .jsonPretty, .jsonMinify:
                let value = try Self.json(text)
                result = String(decoding: try JSONSerialization.data(withJSONObject: value, options: step.tool == .jsonPretty ? [.prettyPrinted, .sortedKeys, .fragmentsAllowed] : [.sortedKeys, .fragmentsAllowed]), as: UTF8.self)
            case .jsonYAML: result = try Yams.dump(object: Self.json(text)); ext = "yaml"
            case .yamlJSON:
                result = String(decoding: try JSONSerialization.data(withJSONObject: Self.yamlValue(text), options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]), as: UTF8.self)
            case .csvJSON:
                let rows = try Self.parseCSV(text, delimiter: step.delimiter.first!)
                let value: Any
                if step.headers {
                    let header = rows[0]; guard Set(header).count == header.count, !header.contains("") else { throw EngineFailure.dataLoss }
                    value = rows.dropFirst().map { Dictionary(uniqueKeysWithValues: zip(header, $0)) }
                } else { value = rows }
                result = String(decoding: try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self)
            case .jsonCSV:
                let object = try Self.json(text); var rows: [[String]]
                if step.headers {
                    guard let records = object as? [[String: String]], let first = records.first else { throw EngineFailure.dataLoss }
                    let keys = first.keys.sorted(); guard records.allSatisfy({ Set($0.keys) == Set(keys) }) else { throw EngineFailure.dataLoss }
                    rows = [keys] + records.map { record in keys.map { record[$0]! } }
                } else { guard let arrays = object as? [[String]], let first = arrays.first, arrays.allSatisfy({ $0.count == first.count }) else { throw EngineFailure.dataLoss }; rows = arrays }
                result = Self.csv(rows, delimiter: step.delimiter.first!); ext = "csv"
            case .csvTSV: result = Self.csv(try Self.parseCSV(text, delimiter: step.delimiter.first!), delimiter: "\t"); ext = "tsv"
            case .tsvCSV: result = Self.csv(try Self.parseCSV(text, delimiter: "\t"), delimiter: step.delimiter.first!); ext = "csv"
            case .markdownHTML: result = Self.markdownHTML(text); ext = "html"
            case .markdownPDF:
                let output = staging.appendingPathComponent("\(i+1)-document.pdf")
                try Self.textPDF(text, output: output); outputs.append(output); continue
            default: throw EngineFailure.unsupported
            }
            let output = staging.appendingPathComponent("\(i+1)-data." + ext)
            try result.write(to: output, atomically: true, encoding: .utf8)
            let check = try String(contentsOf: output, encoding: .utf8)
            guard check == result else { throw EngineFailure.verify }
            if ext == "json" { _ = try Self.json(check) }
            outputs.append(output)
        }
        return outputs
    }
    static func textPDF(_ text: String, output: URL) throws {
        let attributed = try AttributedString(markdown: text, options: .init(interpretedSyntax: .full))
        let native = NSMutableAttributedString(attributedString: NSAttributedString(attributed))
        native.addAttribute(NSAttributedString.Key(kCTFontAttributeName as String), value: CTFontCreateWithName("Helvetica" as CFString, 12, nil), range: NSRange(location: 0, length: native.length))
        let setter = CTFramesetterCreateWithAttributedString(native)
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let context = CGContext(output as CFURL, mediaBox: &box, nil) else { throw EngineFailure.encode }
        var offset = 0, pages = 0
        repeat {
            try Task.checkCancellation(); context.beginPDFPage(nil)
            let path = CGPath(rect: box.insetBy(dx: 45, dy: 45), transform: nil)
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: offset, length: 0), path, nil)
            CTFrameDraw(frame, context); let visible = CTFrameGetVisibleStringRange(frame)
            context.endPDFPage(); pages += 1
            if native.length > 0 && visible.length == 0 { throw EngineFailure.encode }
            offset += visible.length
            guard pages <= 10000 else { throw EngineFailure.tooLarge }
        } while offset < native.length
        context.closePDF()
        guard PDFDocument(url: output)?.pageCount == pages else { throw EngineFailure.verify }
    }
}
