import XCTest
import Foundation
@testable import FluxCore

final class WheelWorkflowTests: XCTestCase {
    func testLegacyWidgetConfigurationAndDistinctDragKeys() throws {
        let original = FluxWidgetConfiguration()
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String:Any])
        old.removeValue(forKey:"dragActivation")
        let migrated = try JSONDecoder().decode(FluxWidgetConfiguration.self,from:JSONSerialization.data(withJSONObject:old)).validated()
        XCTAssertFalse(migrated.dragSettings.enabled)
        var settings = DragActivationSettings(); settings.enabled = true
        XCTAssertNoThrow(try settings.validated())
        settings.filesKey = settings.convertKey; XCTAssertThrowsError(try settings.validated())
    }
    func testDragGateRequiresButtonAndSingleModifierAndKeepsModesSeparate() {
        var settings = DragActivationSettings(); settings.enabled = true; var gate = DragActivationGate()
        XCTAssertNil(gate.update(settings:settings,keys:[.shift],dragging:false))
        XCTAssertEqual(gate.update(settings:settings,keys:[.shift],dragging:true),.convert)
        XCTAssertNil(gate.update(settings:settings,keys:[.shift],dragging:true))
        XCTAssertNil(gate.update(settings:settings,keys:[],dragging:true))
        XCTAssertEqual(gate.update(settings:settings,keys:[.command],dragging:true),.edit)
        XCTAssertNil(gate.update(settings:settings,keys:[.control,.shift],dragging:true))
        XCTAssertEqual(gate.update(settings:settings,keys:[.control],dragging:true),.files)
        settings.enabled = false; XCTAssertNil(gate.update(settings:settings,keys:[.shift],dragging:true))
    }
    func testCropSelectionClampsReversedDragAndRejectsEmptyOrOutside() throws {
        let selection = CropSelection(startX:1.5,startY:0.8,endX:0.25,endY:0.2)
        var options = ImageOptions(); try selection.apply(to:&options)
        XCTAssertEqual(options.cropX,0.25); XCTAssertEqual(options.cropY,0.2)
        XCTAssertEqual(options.cropWidth,0.75); XCTAssertEqual(options.cropHeight,0.6,accuracy:0.00001)
        XCTAssertThrowsError(try CropSelection(startX:0,startY:0,endX:0,endY:0).apply(to:&options))
        var invalid = selection; invalid.x = 0.9; XCTAssertThrowsError(try invalid.apply(to:&options))
    }
    func testMovePreflightPreservesCollisionsAndMovesUnicodeFile() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:root)}
        let destination = root.appendingPathComponent("destino")
        try FileManager.default.createDirectory(at:destination,withIntermediateDirectories:true)
        let input = root.appendingPathComponent("foto ñ $' espacio.txt"), target = destination.appendingPathComponent(input.lastPathComponent)
        try Data("original".utf8).write(to:input);try Data("existing".utf8).write(to:target)
        let engine = FileMoveEngine()
        do {_ = try await engine.plan([input],destination:destination);XCTFail("collision accepted")}catch{XCTAssertEqual(error as? EngineFailure,.collision)}
        XCTAssertEqual(try Data(contentsOf:input),Data("original".utf8));XCTAssertEqual(try Data(contentsOf:target),Data("existing".utf8))
        try FileManager.default.removeItem(at:target)
        let plan = try await engine.plan([input],destination:destination); try await engine.move(plan)
        XCTAssertFalse(FileManager.default.fileExists(atPath:input.path));XCTAssertEqual(try Data(contentsOf:target),Data("original".utf8))
    }
    func testMoveRollbackWhenDestinationAppearsAfterReview() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:root)}
        let destination = root.appendingPathComponent("target");try FileManager.default.createDirectory(at:destination,withIntermediateDirectories:true)
        let a = root.appendingPathComponent("a"), b = root.appendingPathComponent("b")
        try Data([1]).write(to:a);try Data([2]).write(to:b)
        let engine = FileMoveEngine(),plan = try await engine.plan([a,b],destination:destination)
        try Data([9]).write(to:destination.appendingPathComponent("b"))
        do {try await engine.move(plan);XCTFail("stale collision accepted")}catch{}
        XCTAssertEqual(try Data(contentsOf:a),Data([1]));XCTAssertEqual(try Data(contentsOf:b),Data([2]));XCTAssertEqual(try Data(contentsOf:destination.appendingPathComponent("b")),Data([9]))
        XCTAssertFalse(FileManager.default.fileExists(atPath:destination.appendingPathComponent("a").path))
    }
}

import PDFKit
extension WheelWorkflowTests {
    func testPDFVisualPlanDuplicateRotationAndOriginalIntegrity() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:root)}
        let source=root.appendingPathComponent("source.pdf");try DataEngine.textPDF("PAGE ORIGINAL",output:source)
        let original=try Data(contentsOf:source)
        var step=ToolStep(tool:.pdfExtract);step.pages="1,1";step.pageRotations=[0,90]
        let out=try await PDFEngine().execute(inputs:[source],step:step,staging:root)[0]
        let doc=try XCTUnwrap(PDFDocument(url:out));XCTAssertEqual(doc.pageCount,2)
        XCTAssertEqual(doc.page(at:0)?.rotation,0);XCTAssertEqual(doc.page(at:1)?.rotation,90)
        XCTAssertTrue(doc.string?.contains("PAGE ORIGINAL")==true);XCTAssertEqual(try Data(contentsOf:source),original)
        step.pageRotations=[45,0]
        do {_=try await PDFEngine().execute(inputs:[source],step:step,staging:root);XCTFail("Invalid page rotation accepted")}catch{XCTAssertEqual(error as? EngineFailure,.invalidOptions)}
    }
}

import AppKit
extension WheelWorkflowTests {
    func testVisualTopCropKeepsTopPixelsAndOriginal() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:root)}
        let rep=try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:8,pixelsHigh:8,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:32,bitsPerPixel:32))
        for y in 0..<8 {for x in 0..<8 {rep.setColor(NSColor(deviceRed:y<4 ? 1 : 0,green:0,blue:y<4 ? 0 : 1,alpha:1),atX:x,y:y)}}
        let source=root.appendingPathComponent("top bottom.png"),bytes=try XCTUnwrap(rep.representation(using:.png,properties:[:]))
        try bytes.write(to:source)
        let fixture=try XCTUnwrap(NSBitmapImageRep(data:bytes)), top=try XCTUnwrap(fixture.colorAt(x:2,y:2)?.usingColorSpace(NSColorSpace.deviceRGB))
        XCTAssertGreaterThan(top.redComponent,0.95);XCTAssertLessThan(top.blueComponent,0.05)
        var options=ImageOptions(format:.png,maxPixel:0);try CropSelection(startX:0,startY:0,endX:1,endY:0.5).apply(to:&options)
        let output=try await ImageEngine().convert(input:source,directory:root,options:options)
        let result=try XCTUnwrap(NSBitmapImageRep(data:Data(contentsOf:output)))
        XCTAssertEqual(result.pixelsWide,8);XCTAssertEqual(result.pixelsHigh,4)
        let color=try XCTUnwrap(result.colorAt(x:2,y:2)?.usingColorSpace(NSColorSpace.deviceRGB))
        XCTAssertGreaterThan(color.redComponent,0.95);XCTAssertLessThan(color.blueComponent,0.05)
        XCTAssertEqual(try Data(contentsOf:source),bytes)
    }
}
