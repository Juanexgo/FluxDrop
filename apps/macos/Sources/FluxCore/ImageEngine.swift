import Foundation
import ImageIO
import CoreGraphics
import CoreText
import UniformTypeIdentifiers

public enum ImageFormat: String, Codable, CaseIterable, Sendable {
    case jpeg, png, tiff, heic
    public var identifier: String {
        switch self { case .jpeg: UTType.jpeg.identifier; case .png: UTType.png.identifier
        case .tiff: UTType.tiff.identifier; case .heic: UTType.heic.identifier }
    }
    public var fileExtension: String { self == .jpeg ? "jpg" : rawValue }
    public static var available: [Self] {
        let types = CGImageDestinationCopyTypeIdentifiers() as! [String]
        return allCases.filter { types.contains($0.identifier) }
    }
}

public struct ImageOptions: Codable, Equatable, Sendable {
    public var format: ImageFormat
    /// Zero preserves dimensions. Never upscales.
    public var maxPixel: Int
    public var quality: Double
    public var rotation: Int = 0
    public var flipHorizontal = false
    public var flipVertical = false
    public var cropX = 0.0
    public var cropY = 0.0
    public var cropWidth = 1.0
    public var cropHeight = 1.0
    public var stripMetadata = true
    public var watermark = ""
    public var watermarkImage: URL?
    enum CodingKeys: String, CodingKey { case format, maxPixel, quality, rotation, flipHorizontal, flipVertical, cropX, cropY, cropWidth, cropHeight, stripMetadata, watermark, watermarkImage }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decode(ImageFormat.self, forKey: .format); maxPixel = try c.decode(Int.self, forKey: .maxPixel); quality = try c.decode(Double.self, forKey: .quality)
        rotation = try c.decodeIfPresent(Int.self, forKey: .rotation) ?? 0
        flipHorizontal = try c.decodeIfPresent(Bool.self, forKey: .flipHorizontal) ?? false
        flipVertical = try c.decodeIfPresent(Bool.self, forKey: .flipVertical) ?? false
        cropX = try c.decodeIfPresent(Double.self, forKey: .cropX) ?? 0; cropY = try c.decodeIfPresent(Double.self, forKey: .cropY) ?? 0
        cropWidth = try c.decodeIfPresent(Double.self, forKey: .cropWidth) ?? 1; cropHeight = try c.decodeIfPresent(Double.self, forKey: .cropHeight) ?? 1
        stripMetadata = try c.decodeIfPresent(Bool.self, forKey: .stripMetadata) ?? true
        watermark = try c.decodeIfPresent(String.self, forKey: .watermark) ?? ""; watermarkImage = try c.decodeIfPresent(URL.self, forKey: .watermarkImage)
    }
    public init(format: ImageFormat = .jpeg, maxPixel: Int = 2048, quality: Double = 0.85) {
        self.format = format; self.maxPixel = maxPixel; self.quality = quality
    }
}

public enum EngineFailure: String, Error, Codable, Sendable {
    case collision, partialRename, hdr, password, protectedDocument, process, unavailableEngine, unsafeArchive, dataLoss, unreadable, unsupported, multipleFrames, invalidOptions, tooLarge, destination, noSpace, encode, verify, interrupted, unknown
}

public struct ImageInfo: Sendable {
    public let type: String
    public let width: Int
    public let height: Int
}

/// Runs on a dedicated actor, never on the UI executor. One job at a time limits peak memory.
public actor ImageEngine {
    public init() {}
    public static func inspect(_ url: URL) throws -> ImageInfo {
        guard url.isFileURL, let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source) as String? else { throw EngineFailure.unreadable }
        guard ImageFormat.allCases.map(\.identifier).contains(type) else { throw EngineFailure.unsupported }
        guard CGImageSourceGetCount(source) == 1 else { throw EngineFailure.multipleFrames }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int, w > 0, h > 0 else { throw EngineFailure.unreadable }
        guard w <= 32768, h <= 32768, Int64(w) * Int64(h) <= 100_000_000 else { throw EngineFailure.tooLarge }
        return ImageInfo(type: type, width: w, height: h)
    }

    public func convert(input: URL, directory: URL, options: ImageOptions) throws -> URL {
        try Task.checkCancellation()
        guard (0...16384).contains(options.maxPixel), options.quality.isFinite,
              (0...1).contains(options.quality), ImageFormat.available.contains(options.format) else { throw EngineFailure.invalidOptions }
        let info = try Self.inspect(input)
        var isDir: ObjCBool = false
        let fm = FileManager.default
        guard directory.isFileURL, fm.fileExists(atPath: directory.path, isDirectory: &isDir), isDir.boolValue,
              fm.isWritableFile(atPath: directory.path) else { throw EngineFailure.destination }
        let edge = options.maxPixel == 0 ? max(info.width, info.height) : min(options.maxPixel, max(info.width, info.height))
        let required = Int64(edge) * Int64(edge) * 8 + 16_777_216
        let space = try directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let free = space.volumeAvailableCapacityForImportantUsage, free < required { throw EngineFailure.noSpace }
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
              var image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: edge,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw EngineFailure.unreadable }
        try Task.checkCancellation()
        image = try Self.transform(image, options: options)
        // JPEG has no alpha. Flatten explicitly onto white in sRGB; never silently use black.
        if options.format == .jpeg {
            guard let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            else { throw EngineFailure.encode }
            ctx.setFillColor(CGColor(gray: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            guard let flat = ctx.makeImage() else { throw EngineFailure.encode }; image = flat
        }
        // Private staging directory on the destination volume; only this job's temporary is removed.
        let staging = directory.appendingPathComponent(".fluxdrop-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? fm.removeItem(at: staging) }
        let temp = staging.appendingPathComponent("output." + options.format.fileExtension)
        guard let dest = CGImageDestinationCreateWithURL(temp as CFURL, options.format.identifier as CFString, 1, nil) else { throw EngineFailure.encode }
        // Fresh raster export: EXIF/IPTC/GPS are deliberately not copied; color comes from the CGImage.
        var properties: [CFString: Any] = options.stripMetadata ? [:] : (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:])
        properties[kCGImagePropertyOrientation] = 1
        properties[kCGImagePropertyPixelWidth] = image.width; properties[kCGImagePropertyPixelHeight] = image.height
        // Avoid stale EXIF dimensions/orientation when retaining other metadata.
        if var exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            exif[kCGImagePropertyExifPixelXDimension] = image.width; exif[kCGImagePropertyExifPixelYDimension] = image.height
            properties[kCGImagePropertyExifDictionary] = exif
        }
        if var tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] { tiff[kCGImagePropertyTIFFOrientation] = 1; properties[kCGImagePropertyTIFFDictionary] = tiff }
        properties[kCGImageDestinationLossyCompressionQuality] = options.quality
        CGImageDestinationAddImage(dest, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw EngineFailure.encode }
        try Task.checkCancellation()
        guard let check = CGImageSourceCreateWithURL(temp as CFURL, nil),
              CGImageSourceGetType(check) as String? == options.format.identifier,
              let decoded = CGImageSourceCreateImageAtIndex(check, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
              decoded.width == image.width, decoded.height == image.height else { throw EngineFailure.verify }
        try Task.checkCancellation()
        let stem = String(input.deletingPathExtension().lastPathComponent.prefix(120)) + "-fluxdrop"
        // link(2) atomically creates a name without replacing a pre-existing file, including symlinks.
        for index in 0..<10000 {
            let suffix = index == 0 ? "" : "-\(index)"
            let output = directory.appendingPathComponent(stem + suffix + "." + options.format.fileExtension)
            if link(temp.path, output.path) == 0 { return output }
            if errno != EEXIST { throw EngineFailure.destination }
        }
        throw EngineFailure.destination
    }
    static func transform(_ source: CGImage, options: ImageOptions) throws -> CGImage {
        let values = [options.cropX, options.cropY, options.cropWidth, options.cropHeight]
        guard values.allSatisfy({ $0.isFinite && (0...1).contains($0) }), options.cropWidth > 0, options.cropHeight > 0,
              options.cropX + options.cropWidth <= 1.000001, options.cropY + options.cropHeight <= 1.000001,
              [0, 90, 180, 270].contains(options.rotation), options.watermark.count <= 200 else { throw EngineFailure.invalidOptions }
        let rect = CGRect(x: options.cropX * Double(source.width), y: options.cropY * Double(source.height),
                          width: options.cropWidth * Double(source.width), height: options.cropHeight * Double(source.height)).integral
        guard let cropped = source.cropping(to: rect) else { throw EngineFailure.invalidOptions }
        let swap = options.rotation == 90 || options.rotation == 270
        let w = swap ? cropped.height : cropped.width, h = swap ? cropped.width : cropped.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: cropped.colorSpace?.model == .rgb ? cropped.colorSpace! : CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw EngineFailure.encode }
        ctx.saveGState(); ctx.translateBy(x: Double(w)/2, y: Double(h)/2)
        ctx.scaleBy(x: options.flipHorizontal ? -1 : 1, y: options.flipVertical ? -1 : 1)
        ctx.rotate(by: -Double(options.rotation) * .pi / 180)
        let drawWidth = CGFloat(cropped.width), drawHeight = CGFloat(cropped.height)
        let drawRect = CGRect(x: -drawWidth / 2, y: -drawHeight / 2, width: drawWidth, height: drawHeight)
        ctx.draw(cropped, in: drawRect); ctx.restoreGState()
        if !options.watermark.isEmpty {
            let fontSize = max(10, Double(w)/35)
            let attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, fontSize, nil), NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 0.9)]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: options.watermark, attributes: attributes))
            ctx.setFillColor(CGColor(gray: 0, alpha: 0.5)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: Int(fontSize * 2)))
            ctx.textPosition = CGPoint(x: fontSize/2, y: fontSize/2); CTLineDraw(line, ctx)
        }
        if let url = options.watermarkImage {
            _ = try inspect(url)
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil), let mark = CGImageSourceCreateThumbnailAtIndex(src, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: max(1, w/4)] as CFDictionary) else { throw EngineFailure.unreadable }
            ctx.setAlpha(0.7); ctx.draw(mark, in: CGRect(x: max(0,w-mark.width-12), y: 12, width: mark.width, height: mark.height))
        }
        guard let result = ctx.makeImage() else { throw EngineFailure.encode }; return result
    }
    public func icons(input: URL, directory: URL) throws -> URL {
        let info = try Self.inspect(input)
        guard info.width == info.height, info.width >= 1024 else { throw EngineFailure.invalidOptions }
        let folder = directory.appendingPathComponent("AppIcon.iconset", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        for size in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let output = try convert(input: input, directory: folder, options: .init(format: .png, maxPixel: size*scale))
                let name = "icon_\(size)x\(size)" + (scale == 2 ? "@2x" : "") + ".png"
                try FileManager.default.moveItem(at: output, to: folder.appendingPathComponent(name))
            }
        }
        return folder
    }

}
