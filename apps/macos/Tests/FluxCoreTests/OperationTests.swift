import XCTest
import Foundation
import PDFKit
import ImageIO
@testable import FluxCore

final class OperationTests: XCTestCase {
    func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("FluxDrop-operation-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:url,withIntermediateDirectories:true)
        addTeardownBlock { try? FileManager.default.removeItem(at:url) }; return url
    }
    func text(_ text: String, _ directory: URL, name: String) throws -> URL { let url=directory.appendingPathComponent(name); try text.write(to:url,atomically:true,encoding:.utf8); return url }
    func testCSVQuotedNewlinesAndLossRejection() throws {
        let rows=try DataEngine.parseCSV("name,note\r\nAna,\"line 1\nline 2, \"\"yes\"\"\"\r\n",delimiter:",")
        XCTAssertEqual(rows,[["name","note"],["Ana","line 1\nline 2, \"yes\""]])
        XCTAssertThrowsError(try DataEngine.parseCSV("a,b\n1,2,3",delimiter:","))
        XCTAssertThrowsError(try DataEngine.parseCSV("a\n\"unterminated",delimiter:","))
        XCTAssertThrowsError(try DataEngine.json("{\"x\":1,\"x\":2}"))
    }
    func testDataRoundTrips() async throws {
        let dir=try folder(), engine=DataEngine()
        let input=try text("[{\"name\":\"Ana\",\"note\":\"ñ, hello\"}]",dir,name:"data.json")
        let yaml=try await engine.execute(inputs:[input],step:.init(tool:.jsonYAML),staging:dir)[0]
        let json=try await engine.execute(inputs:[yaml],step:.init(tool:.yamlJSON),staging:dir)[0]
        let result=try JSONSerialization.jsonObject(with:Data(contentsOf:json)) as! [[String:String]]
        XCTAssertEqual(result.first?["note"],"ñ, hello")
        let csv=try await engine.execute(inputs:[input],step:.init(tool:.jsonCSV),staging:dir)[0]
        let back=try await engine.execute(inputs:[csv],step:.init(tool:.csvJSON),staging:dir)[0]
        XCTAssertEqual(try JSONSerialization.jsonObject(with:Data(contentsOf:back)) as? [[String:String]],result)
        let html=DataEngine.markdownHTML("# Title\n<script>alert(1)</script>\n- One")
        XCTAssertTrue(html.contains("<h1>Title</h1>")); XCTAssertFalse(html.contains("<script>"))
    }
    func testYAMLRejectsUnsupportedTypesAndAliases() async throws {
        let dir=try folder()
        for contents in ["a: &x [1, 2]\nb: *x", "a: 2025-01-01", "a: .nan", "a: 1\na: 2", "? [a, b]\n: value"] {
            let input=try text(contents,dir,name:"input.yaml")
            do { _=try await DataEngine().execute(inputs:[input],step:.init(tool:.yamlJSON),staging:dir); XCTFail("Accepted lossy YAML: \(contents)") } catch {}
        }
    }
    func testPDFPagesTextRasterAndOCR() async throws {
        let dir=try folder(); let first=dir.appendingPathComponent("first.pdf")
        try DataEngine.textPDF("FLUXDROP LOCAL TEST",output:first)
        XCTAssertTrue(PDFDocument(url:first)?.string?.contains("FLUXDROP") == true)
        let engine=PDFEngine()
        let merged=try await engine.execute(inputs:[first,first],step:.init(tool:.pdfMerge),staging:dir)[0]
        XCTAssertEqual(PDFDocument(url:merged)?.pageCount,2)
        var extract=ToolStep(tool:.pdfExtract); extract.pages="2,1"
        let target=try folder(); let reordered=try await engine.execute(inputs:[merged],step:extract,staging:target)[0]
        XCTAssertEqual(PDFDocument(url:reordered)?.pageCount,2)
        let pages=try await engine.execute(inputs:[merged],step:.init(tool:.pdfSplit),staging:dir)
        XCTAssertEqual(pages.count,2); XCTAssertTrue(pages.allSatisfy { PDFDocument(url:$0)?.pageCount == 1 })
        let images=try await engine.execute(inputs:[first],step:.init(tool:.pdfImages),staging:dir)
        XCTAssertEqual(try ImageEngine.inspect(images[0]).width,1190)
        let ocr=try await engine.execute(inputs:[first],step:.init(tool:.pdfOCR),staging:dir)[0]
        XCTAssertTrue(try String(contentsOf:ocr,encoding:.utf8).uppercased().contains("FLUXDROP"))
        XCTAssertEqual(try PDFEngine.pageIndices("3,1-2",count:3),[2,0,1])
        XCTAssertThrowsError(try PDFEngine.pageIndices("0,4",count:3))
        let compressed=try await engine.execute(inputs:[first],step:.init(tool:.pdfCompress),staging:target)[0]
        XCTAssertEqual(PDFDocument(url:compressed)?.pageCount,1)
    }
    func testArchivesRoundTripAndPaths() async throws {
        let dir=try folder(); let input=try text("fixture ñ",dir,name:"hello ñ.txt"); let engine=ArchiveEngine()
        for (create,extract) in [(ToolID.zipCreate,ToolID.zipExtract),(.tarCreate,.tarExtract),(.gzipCreate,.gzipExtract)] {
            let staging=try folder(); let archive=try await engine.execute(inputs:[input],step:.init(tool:create),staging:staging)[0]
            let dest=try folder(); let extracted=try await engine.execute(inputs:[archive],step:.init(tool:extract),staging:dest)[0]
            let file=extracted.appendingPathComponent(create == .gzipCreate ? "decompressed" : input.lastPathComponent)
            XCTAssertEqual(try Data(contentsOf:file),try Data(contentsOf:input))
        }
        for path in ["../escape","/etc/passwd","a/../../b","a\\..\\b","a/./b","C:foo"] { XCTAssertThrowsError(try ArchiveEngine.safeComponents(path)) }
        let link=dir.appendingPathComponent("link"); try FileManager.default.createSymbolicLink(at:link,withDestinationURL:input)
        do { _=try await engine.execute(inputs:[link],step:.init(tool:.zipCreate),staging:try folder()); XCTFail() } catch { XCTAssertEqual(error as? EngineFailure,.unsafeArchive) }
    }
    func testRecipeCompositionAndAtomicMultiOutput() async throws {
        let dir=try folder(); let input=try text("{\"a\":1}",dir,name:"input.json")
        let recipe=Recipe(name:"JSON YAML JSON",steps:[.init(tool:.jsonYAML),.init(tool:.yamlJSON)])
        let outputs=try await WorkflowEngine(tools:dir).run(inputs:[input],recipe:recipe,directory:dir)
        XCTAssertEqual(try JSONSerialization.jsonObject(with:Data(contentsOf:outputs[0])) as? [String:Int],["a":1])
        XCTAssertThrowsError(try Recipe(name:"bad",steps:[.init(tool:.jsonYAML),.init(tool:.pdfText)]).validate())
        var wrong=recipe; wrong.version=9; XCTAssertThrowsError(try wrong.validate())
        XCTAssertEqual(try String(contentsOf:input,encoding:.utf8),"{\"a\":1}")
    }
    func testRenameCollisionDuplicatesAndWatchQuietPeriod() async throws {
        let dir=try folder(), engine=FolderEngine(); let first=try text("same",dir,name:"one.txt"), second=try text("same",dir,name:"two.txt")
        let groups=try await engine.duplicates([first,second]); XCTAssertEqual(groups.count,1)
        var options=RenameOptions(); options.prefix="new-"
        let plan=try await engine.plan([first,second],options:options); XCTAssertEqual(plan.count,2)
        try await engine.rename(plan); XCTAssertFalse(FileManager.default.fileExists(atPath:first.path))
        XCTAssertEqual(try String(contentsOf:plan[0].destination,encoding:.utf8),"same")
        let source=try folder(), dest=try folder(); _=try text("{}",source,name:"input.json")
        var rule=try WatchRule(source:source,destination:dest,recipe:Recipe(name:"pretty",steps:[.init(tool:.jsonPretty)]))
        let scanner=WatchScanner(); let now=Date()
        let initial=try await scanner.scan(rule,now:now); XCTAssertTrue(initial.ready.isEmpty)
        let ready=try await scanner.scan(rule,now:now.addingTimeInterval(11)); XCTAssertEqual(ready.ready.count,1)
        rule.processed=ready.fingerprints; let again=try await scanner.scan(rule,now:now.addingTimeInterval(20)); XCTAssertTrue(again.ready.isEmpty)
        XCTAssertThrowsError(try WatchRule(source:source,destination:source,recipe:rule.recipe))
    }
    func testExternalProcessCancellation() async throws {
        guard let path=ProcessInfo.processInfo.environment["FLUXDROP_TEST_TOOLS"] else { throw XCTSkip("Embedded engine unavailable") }
        let dir=try folder(), runner=ProcessRunner()
        let task=Task { try await runner.run(executable:URL(fileURLWithPath:path).appendingPathComponent("ffmpeg"),arguments:["-v","error","-re","-f","lavfi","-i","sine=frequency=440","-t","30","-f","null","-"],directory:dir) }
        try await Task.sleep(for:.milliseconds(300)); task.cancel()
        do { _=try await task.value; XCTFail("Cancellation ignored") } catch is CancellationError {} catch { XCTFail("Unexpected cancellation error: \(error)") }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath:dir.path).isEmpty)
    }
    func testRenameRecipeAndAtomicFailure() async throws {
        let dir=try folder(), input=try text("{\"a\":1}",dir,name:"source ñ.json")
        var rename=ToolStep(tool:.renameCopy); rename.renamePrefix="ready-"
        let recipe=Recipe(name:"Pretty rename",steps:[.init(tool:.jsonPretty),rename])
        let engine=WorkflowEngine(tools:dir)
        let output=try await engine.run(inputs:[input],recipe:recipe,directory:dir)[0]
        XCTAssertTrue(output.lastPathComponent.hasPrefix("ready-"))
        XCTAssertEqual(try JSONSerialization.jsonObject(with:Data(contentsOf:output)) as? [String:Int],["a":1])
        let bad=try text("broken",dir,name:"bad.json"), before=Set(try FileManager.default.contentsOfDirectory(atPath:dir.path))
        do { _=try await engine.run(inputs:[input,bad],recipe:recipe,directory:dir); XCTFail("Accepted corrupt input") } catch {}
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath:dir.path)),before)
        XCTAssertEqual(try String(contentsOf:input,encoding:.utf8),"{\"a\":1}")
    }
    func testMediaEmbeddedEngine() async throws {
        guard let path=ProcessInfo.processInfo.environment["FLUXDROP_TEST_TOOLS"] else { throw XCTSkip("Set FLUXDROP_TEST_TOOLS to the built embedded engine directory") }
        let dir=try folder(), tools=URL(fileURLWithPath:path), input=dir.appendingPathComponent("clip ñ.mp4")
        let runner=ProcessRunner()
        _=try await runner.run(executable:tools.appendingPathComponent("ffmpeg"),arguments:["-v","error","-f","lavfi","-i","testsrc=size=160x90:rate=10","-f","lavfi","-i","sine=frequency=440:sample_rate=48000","-t","1","-c:v","mpeg4","-pix_fmt","yuv420p","-c:a","aac",input.path],directory:dir)
        let engine=MediaEngine(tools:tools)
        for tool in [ToolID.mediaInspect,.videoMP4,.videoMOV,.videoGIF,.audioM4A,.audioWAV,.audioFLAC] {
            let stage=try folder(); var step=ToolStep(tool:tool); step.width=80; step.start=0.1; step.duration=0.5
            let result=try await engine.execute(inputs:[input],step:step,staging:stage)
            XCTAssertFalse(result.isEmpty)
            if tool != .mediaInspect { let data=try await engine.inspect(result[0],staging:stage); let json=try JSONSerialization.jsonObject(with:data) as! [String:Any]; let streams=json["streams"] as! [[String:Any]]; XCTAssertFalse(streams.isEmpty)
                let seconds=Double((json["format"] as! [String:Any])["duration"] as? String ?? "0") ?? 0
                XCTAssertGreaterThan(seconds,0.3); XCTAssertLessThan(seconds,0.8)
                if [.videoMP4,.videoMOV,.videoGIF].contains(tool) { XCTAssertEqual(streams.first { $0["codec_type"] as? String == "video" }?["width"] as? Int,80) } }
        }
        let joined=try await engine.execute(inputs:[input,input],step:.init(tool:.audioJoin),staging:try folder())
        XCTAssertTrue(FileManager.default.fileExists(atPath:joined[0].path))
    }
}
