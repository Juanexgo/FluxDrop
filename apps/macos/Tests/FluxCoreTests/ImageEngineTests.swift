import XCTest
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import FluxCore

final class ImageEngineTests: XCTestCase {
    func workspace() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("FluxDrop-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }; return url
    }
    func fixture(_ dir: URL, type: ImageFormat = .png, orientation: Int = 1) throws -> URL {
        let ctx = CGContext(data: nil, width: 80, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 0.3, blue: 0.1, alpha: 0.5)); ctx.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        let url = dir.appendingPathComponent("foto ñ con espacios." + type.fileExtension)
        let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, ctx.makeImage()!, [kCGImagePropertyOrientation: orientation,
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 20.0, kCGImagePropertyGPSLatitudeRef: "N"]] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest)); return url
    }
    func testEveryAvailableEncoderRoundTripAndOriginalPreserved() async throws {
        let dir = try workspace(); let input = try fixture(dir); let original = try Data(contentsOf: input)
        for format in ImageFormat.available {
            let output = try await ImageEngine().convert(input: input, directory: dir, options: .init(format: format, maxPixel: 32))
            let info = try ImageEngine.inspect(output)
            XCTAssertEqual(info.width, 32); XCTAssertEqual(info.height, 16); XCTAssertEqual(info.type, format.identifier)
            XCTAssertEqual(try Data(contentsOf: input), original)
            let source = CGImageSourceCreateWithURL(output as CFURL, nil)!
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)! as NSDictionary
            XCTAssertNil(props[kCGImagePropertyGPSDictionary])
        }
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: dir.path).contains { $0.hasPrefix(".fluxdrop-") })
    }
    func testCropRotateAndWatermarkOutputDimensions() async throws {
        let dir=try workspace(), input=try fixture(dir)
        var options=ImageOptions(format:.png,maxPixel:0)
        options.cropWidth=0.5; options.cropHeight=0.5; options.rotation=90
        options.flipHorizontal=true; options.watermark="Flux ñ"
        let result=try await ImageEngine().convert(input:input,directory:dir,options:options)
        let info=try ImageEngine.inspect(result)
        XCTAssertEqual(info.width,20); XCTAssertEqual(info.height,40)
        options.cropX=0.9
        do { _=try await ImageEngine().convert(input:input,directory:dir,options:options); XCTFail("Invalid crop accepted") } catch { XCTAssertEqual(error as? EngineFailure,.invalidOptions) }
    }
    func testCollisionDoesNotOverwrite() async throws {
        let dir = try workspace(); let input = try fixture(dir); let engine = ImageEngine()
        let first = try await engine.convert(input: input, directory: dir, options: .init(format: .png))
        let bytes = try Data(contentsOf: first)
        let second = try await engine.convert(input: input, directory: dir, options: .init(format: .png))
        XCTAssertNotEqual(first, second); XCTAssertEqual(try Data(contentsOf: first), bytes)
    }
    func testOrientationAndNoUpscaling() async throws {
        let dir = try workspace(); let input = try fixture(dir, type: .tiff, orientation: 6)
        let output = try await ImageEngine().convert(input: input, directory: dir, options: .init(format: .png, maxPixel: 2048))
        let info = try ImageEngine.inspect(output); XCTAssertEqual(info.width, 40); XCTAssertEqual(info.height, 80)
    }
    func testJPEGAlphaIsWhite() async throws {
        let dir = try workspace(); let input = try fixture(dir)
        let output = try await ImageEngine().convert(input: input, directory: dir, options: .init(format: .jpeg, maxPixel: 0, quality: 1))
        let image = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(output as CFURL, nil)!, 0, nil)!
        let ctx = CGContext(data: nil, width: 80, height: 40, bitsPerComponent: 8, bytesPerRow: 80 * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: 80, height: 40))
        let bytes = ctx.data!.assumingMemoryBound(to: UInt8.self); let offset = (20 * 80 + 70) * 4
        XCTAssertGreaterThan(bytes[offset], 245); XCTAssertGreaterThan(bytes[offset + 1], 245); XCTAssertGreaterThan(bytes[offset + 2], 245)
    }
    func testCorruptEmptyAndUnsupported() async throws {
        let dir = try workspace()
        for (name, content) in [("empty.png", Data()), ("fake.jpg", Data("hello".utf8))] {
            let input = dir.appendingPathComponent(name); try content.write(to: input)
            do { _ = try await ImageEngine().convert(input: input, directory: dir, options: .init()); XCTFail("Accepted corrupt file") }
            catch { XCTAssertEqual(error as? EngineFailure, .unreadable) }
        }
    }
    func testDetectionUsesContentNotExtension() throws {
        let dir = try workspace(); let input = try fixture(dir); let renamed = dir.appendingPathComponent("actually-image.txt")
        try FileManager.default.moveItem(at: input, to: renamed)
        XCTAssertEqual(try ImageEngine.inspect(renamed).type, UTType.png.identifier)
    }
    func testMultiplePagesRejected() throws {
        let dir = try workspace(); let input = try fixture(dir)
        let image = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(input as CFURL, nil)!, 0, nil)!
        let url = dir.appendingPathComponent("multi.tiff")
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.tiff.identifier as CFString, 2, nil)!
        CGImageDestinationAddImage(dest, image, nil); CGImageDestinationAddImage(dest, image, nil); XCTAssertTrue(CGImageDestinationFinalize(dest))
        XCTAssertThrowsError(try ImageEngine.inspect(url)) { XCTAssertEqual($0 as? EngineFailure, .multipleFrames) }
    }
    func testInvalidOptionsAndDestination() async throws {
        let dir = try workspace(); let input = try fixture(dir)
        do { _ = try await ImageEngine().convert(input: input, directory: dir, options: .init(maxPixel: -1)); XCTFail() }
        catch { XCTAssertEqual(error as? EngineFailure, .invalidOptions) }
        do { _ = try await ImageEngine().convert(input: input, directory: input, options: .init()); XCTFail() }
        catch { XCTAssertEqual(error as? EngineFailure, .destination) }
    }
    func testCancellationBeforeProcessing() async throws {
        let dir = try workspace(); let input = try fixture(dir)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await ImageEngine().convert(input: input, directory: dir, options: .init())
        }
        task.cancel()
        do { _ = try await task.value; XCTFail() } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path).count, 1)
    }
    @MainActor func testQueuePauseMixedBatchRetryAndRecovery() async throws {
        let dir = try workspace(); let input = try fixture(dir); let bad = dir.appendingPathComponent("missing.jpg")
        let journal = dir.appendingPathComponent("journal.json")
        let queue = JobQueue(journal: journal); queue.setPaused(true)
        queue.enqueue([input, bad], directory: dir, options: .init(format: .png))
        XCTAssertEqual(queue.jobs.map(\.state), [.pending, .pending])
        let recovered = JobQueue(journal: journal); XCTAssertEqual(recovered.jobs.map(\.state), [.interrupted, .interrupted])
        queue.setPaused(false)
        for _ in 0..<200 where queue.jobs.contains(where: { [.running, .pending].contains($0.state) }) { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(queue.jobs.map(\.state), [.succeeded, .failed])
        queue.setPaused(true); queue.retry(queue.jobs[1].id); XCTAssertEqual(queue.jobs.last?.state, .pending)
        queue.cancelAll(); XCTAssertEqual(queue.jobs.last?.state, .cancelled)
        queue.clearFinished(); XCTAssertTrue(queue.jobs.isEmpty)
    }
}
