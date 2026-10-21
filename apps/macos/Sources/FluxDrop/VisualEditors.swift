import AppKit
import SwiftUI
import ImageIO
import PDFKit
import AVKit
import AVFoundation
import FluxCore

@MainActor final class EditorController {
    enum Kind { case image, pdf, media, compress, folders }
    static let shared = EditorController()
    private var window: NSWindow?
    func show(_ kind: Kind, files: [URL]) {
        guard !files.isEmpty else { return }
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 820,height: 640), styleMask: [.titled,.closable,.miniaturizable,.resizable], backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false; w.center(); window = w
        }
        guard let window else { return }; window.title = tr("studio.title")
        switch kind {
        case .image: window.contentView = NSHostingView(rootView: ImageStudio(files: files))
        case .pdf: window.contentView = NSHostingView(rootView: PDFStudio(files: files))
        case .media: window.contentView = NSHostingView(rootView: MediaStudio(files: files))
        case .compress: window.contentView = NSHostingView(rootView: CompressionStudio(files: files))
        case .folders: AppModel.shared.files = files; window.contentView = NSHostingView(rootView: FoldersView(model:.shared))
        }
        PanelController.shared.hide(); NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil)
    }
}
/// ImageIO downsamples an oriented preview. Originals are never loaded in full into the view.
private actor StudioPreviewLoader {
    func load(_ url: URL) throws -> Data {
        _ = try ImageEngine.inspect(url)
        guard let source = CGImageSourceCreateWithURL(url as CFURL,nil), let image = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:1200] as CFDictionary) else { throw EngineFailure.unreadable }
        let data = NSMutableData()
        guard let out = CGImageDestinationCreateWithData(data,"public.png" as CFString,1,nil) else { throw EngineFailure.encode }
        CGImageDestinationAddImage(out,image,nil); guard CGImageDestinationFinalize(out) else { throw EngineFailure.encode }; return data as Data
    }
}
struct ImageStudio: View {
    let files: [URL]
    @State private var selected: URL?
    @State private var preview: NSImage?
    @State private var options = ImageOptions(maxPixel: 0)
    @State private var crop = CropSelection(startX: 0,startY: 0,endX: 1,endY: 1)
    @State private var dragStart: CGPoint?
    @State private var message: String?
    private let loader = StudioPreviewLoader()
    private var input: URL? { selected ?? files.first }
    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                Text(tr("studio.image")).font(.title2.bold())
                Text(tr("studio.oneFile")).font(.caption).foregroundStyle(.secondary)
                Picker(tr("files"), selection: Binding(get: { input },set: { selected = $0 })) { ForEach(files,id: \.self) { Text($0.lastPathComponent).tag(Optional($0)) } }
                if let preview {
                    GeometryReader { geometry in
                        let size = fitted(preview.size,in: geometry.size)
                        ZStack(alignment: .topLeading) {
                            Image(nsImage: preview).resizable().interpolation(.high).frame(width: size.width,height: size.height)
                            Rectangle().fill(.black.opacity(0.18))
                            Rectangle().stroke(.white,lineWidth: 2).background(.white.opacity(0.07))
                                .frame(width: size.width*crop.width,height: size.height*crop.height)
                                .offset(x: size.width*crop.x,y: size.height*crop.y)
                        }.frame(width: size.width,height: size.height).clipped().contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 1).onChanged { value in
                            if dragStart == nil { dragStart = value.startLocation }
                            let start = dragStart ?? value.startLocation
                            crop = CropSelection(startX: start.x/size.width,startY: start.y/size.height,endX: value.location.x/size.width,endY: value.location.y/size.height)
                        }.onEnded { _ in dragStart = nil })
                        .accessibilityLabel(tr("studio.cropCanvas"))
                    }.frame(minHeight: 260)
                } else { ProgressView().frame(maxWidth: .infinity,minHeight: 260) }
                Text(tr("studio.cropHint")).font(.caption)
                HStack { cropField("X", $crop.x); cropField("Y", $crop.y); cropField(tr("crop.width"), $crop.width); cropField(tr("crop.height"), $crop.height) }
                Button(tr("studio.resetCrop")) { crop = CropSelection(startX: 0,startY: 0,endX: 1,endY: 1) }
                if let message { Text(message).foregroundStyle(.red) }
            }.padding(20).frame(minWidth: 400)
            ScrollView { VStack(alignment: .leading,spacing: 12) {
                ImageEditOptions(options: $options, showCropFields: false)
                Text(tr("studio.transformNote")).font(.caption).foregroundStyle(.secondary)
                Button(tr("destination.choose")) { AppModel.shared.chooseDestination() }
                Text(AppModel.shared.directory.path).font(.caption).textSelection(.enabled)
                Button(tr("studio.exportCopy")) { export() }.buttonStyle(.borderedProminent).disabled(preview == nil)
            }.padding(20) }.frame(minWidth: 280,maxWidth: 340)
        }.task(id: input) { await load() }
    }
    private func fitted(_ image: CGSize,in bounds: CGSize) -> CGSize {
        let scale = min(bounds.width/max(image.width,1),bounds.height/max(image.height,1)); return CGSize(width: image.width*scale,height: image.height*scale)
    }
    private func cropField(_ title: String,_ value: Binding<Double>) -> some View {
        VStack(alignment: .leading) { Text(title).font(.caption); TextField(title,value: value,format: .number.precision(.fractionLength(0...3))).accessibilityLabel(title).frame(minWidth: 60) }
    }
    private func load() async {
        preview = nil; message = nil
        guard let input else { return }
        do { let data = try await loader.load(input); try Task.checkCancellation(); preview = NSImage(data:data); crop = CropSelection(startX:0,startY:0,endX:1,endY:1) }
        catch is CancellationError {} catch { message = tr("error." + ((error as? EngineFailure)?.rawValue ?? "unreadable")) }
    }
    private func export() {
        guard let input else { return }
        do {
            var settings = options; try crop.apply(to: &settings)
            guard crop.x >= 0, crop.y >= 0, crop.x+crop.width <= 1.000001, crop.y+crop.height <= 1.000001 else { throw EngineFailure.invalidOptions }
            var step = ToolStep(tool:.image); step.image = settings
            AppModel.shared.queue.enqueue([input],directory:AppModel.shared.directory,recipe:Recipe(name:tr("studio.image"),steps:[step]))
            message = tr("studio.queued")
        } catch { message = tr("error.invalidOptions") }
    }
}
struct PDFPageCard: Identifiable {
    let id = UUID()
    let original: Int
    let image: NSImage
    var rotation = 0
}
struct PDFStudio: View {
    let files: [URL]
    @State private var selected: URL?
    @State private var pages: [PDFPageCard] = []
    @State private var password = ""
    @State private var message: String?
    private var input: URL? { selected ?? files.first }
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            Text(tr("studio.pdf")).font(.title.bold())
            Text(tr("studio.oneFile")).font(.caption)
            Picker(tr("files"),selection: Binding(get:{input},set:{selected=$0;load()})) { ForEach(files,id:\.self) { Text($0.lastPathComponent).tag(Optional($0)) } }
            HStack { SecureField(tr("pdf.password"),text:$password); Button(tr("studio.loadPages")) { load() } }
            Text(tr("studio.pdfLimit")).font(.caption).foregroundStyle(.secondary)
            ScrollView { LazyVGrid(columns:[GridItem(.adaptive(minimum:145))],spacing:16) {
                ForEach(pages) { page in
                    VStack {
                        Image(nsImage:page.image).resizable().scaledToFit().frame(height:150).rotationEffect(.degrees(Double(page.rotation)))
                        Text("\(page.original+1)").font(.caption)
                        HStack {
                            Button { move(page,-1) } label: { Image(systemName:"arrow.left") }.accessibilityLabel(tr("move.up"))
                            Button { move(page,1) } label: { Image(systemName:"arrow.right") }.accessibilityLabel(tr("move.down"))
                            Button { pages.append(PDFPageCard(original:page.original,image:page.image,rotation:page.rotation)) } label: { Image(systemName:"plus.square.on.square") }.accessibilityLabel(tr("studio.duplicatePage"))
                            Button { if let i = pages.firstIndex(where: { $0.id == page.id }) { pages[i].rotation = (pages[i].rotation+90)%360 } } label: { Image(systemName:"rotate.right") }.accessibilityLabel(tr("rotation"))
                            Button { pages.removeAll { $0.id == page.id } } label: { Image(systemName:"xmark") }.accessibilityLabel(tr("remove"))
                        }.buttonStyle(.borderless)
                    }.padding(10).background(.quaternary,in:RoundedRectangle(cornerRadius:10))
                }
            } }
            HStack {
                Button(tr("destination.choose")) { AppModel.shared.chooseDestination() }
                Button(tr("studio.exportCopy")) { export() }.buttonStyle(.borderedProminent).disabled(pages.isEmpty)
            }
            if let message { Text(message).font(.caption) }
        }.padding(24).onAppear { load() }
    }
    private func move(_ page: PDFPageCard,_ delta:Int) { guard let i=pages.firstIndex(where:{$0.id==page.id}),pages.indices.contains(i+delta) else{return};pages.swapAt(i,i+delta) }
    private func load() {
        pages=[];message=nil
        guard let input,let doc=PDFDocument(url:input) else{message=tr("error.unreadable");return}
        if doc.isLocked && !doc.unlock(withPassword:password) {message=tr("error.password");return}
        guard doc.allowsCopying,doc.pageCount>0,doc.pageCount<=150 else{message=tr("studio.pdfLimit");return}
        pages=(0..<doc.pageCount).compactMap { index in doc.page(at:index).map { PDFPageCard(original:index,image:$0.thumbnail(of:CGSize(width:160,height:180),for:.mediaBox)) } }
    }
    private func export() {
        guard let input,!pages.isEmpty else{return};var step=ToolStep(tool:.pdfExtract);step.pages=pages.map{String($0.original+1)}.joined(separator:",");step.pageRotations=pages.map(\.rotation)
        AppModel.shared.queue.enqueue([input],directory:AppModel.shared.directory,recipe:Recipe(name:tr("studio.pdf"),steps:[step]),password:password)
        password="";message=tr("studio.queued")
    }
}
struct MediaStudio: View {
    let files: [URL]
    @State private var step=ToolStep(tool:.videoMP4)
    @State private var selected: URL?
    @State private var player: AVPlayer?
    @State private var length = 0.0
    @State private var notice: String?
    private var input: URL? { selected ?? files.first }
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            Text(tr("studio.media")).font(.title.bold())
            Text(tr("studio.mediaNote")).font(.caption)
            Text(tr("studio.oneFile")).font(.caption)
            Picker(tr("files"),selection: Binding(get:{input},set:{selected=$0})) { ForEach(files,id:\.self) { Text($0.lastPathComponent).tag(Optional($0)) } }
            if let player { VideoPlayer(player:player).frame(minHeight:180,maxHeight:220) }
            if length > 0 {
                HStack { Text(tr("media.start")); Slider(value:$step.start,in:0...length).onChange(of:step.start) { player?.seek(to:CMTime(seconds:step.start,preferredTimescale:600)); if step.start+step.duration>length {step.duration=max(0,length-step.start)} } }
                HStack { Text(tr("media.duration")); Slider(value:$step.duration,in:0...max(0.001,length-step.start)) }
            }
            if let notice {Text(notice).font(.caption).foregroundStyle(.secondary); if let input {Button(tr("preview")) {PreviewController.shared.show(input)}}}
            Picker(tr("operation"),selection:$step.tool) { ForEach([ToolID.videoMP4,.videoMOV,.videoGIF,.audioM4A,.audioWAV,.audioFLAC],id:\.self) { Text(tr("tool."+$0.rawValue)).tag($0) } }
            StepOptions(step:$step)
            Button(tr("destination.choose")) { AppModel.shared.chooseDestination() }
            Button(tr("studio.exportCopy")) { if let input { AppModel.shared.queue.enqueue([input],directory:AppModel.shared.directory,recipe:Recipe(name:tr("studio.media"),steps:[step])) } }.buttonStyle(.borderedProminent)
            QueueView(queue:AppModel.shared.queue)
        }.padding(24).task(id:input) { await load() }.onDisappear {player?.pause()}
    }
    private func load() async {
        player?.pause();player=nil;length=0;notice=nil
        guard let input else{return}
        do {
            let asset=AVURLAsset(url:input), time=try await asset.load(.duration)
            try Task.checkCancellation(); let seconds=CMTimeGetSeconds(time)
            guard seconds.isFinite,seconds>0 else{throw EngineFailure.unreadable}
            length=seconds;step.start=0;step.duration=seconds
            step.tool=["mp3","m4a","wav","flac","aiff","aac","ogg","opus"].contains(input.pathExtension.lowercased()) ? .audioM4A : .videoMP4
            player=AVPlayer(playerItem:AVPlayerItem(asset:asset))
        }catch is CancellationError {}catch { notice=tr("studio.previewUnavailable") }
    }
}
struct CompressionStudio: View {
    let files:[URL]
    @State private var quality=0.75
    @State private var maxPixel=2048
    @State private var targetMB=10.0
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            Text(tr("studio.compress")).font(.title.bold());Text(tr("studio.compressNote")).font(.caption)
            Slider(value:$quality,in:0.2...1).accessibilityLabel(tr("quality"))
            Text(quality,format:.percent.precision(.fractionLength(0)))
            Picker(tr("resize.zero"),selection:$maxPixel) { ForEach([0,1024,2048,4096],id:\.self) { Text($0==0 ? tr("size.original") : "\($0) px").tag($0) } }
            TextField(tr("media.target"),value:$targetMB,format:.number)
            Button(tr("destination.choose")) { AppModel.shared.chooseDestination() }
            Button(tr("studio.exportCopy")) { run() }.buttonStyle(.borderedProminent)
            QueueView(queue:AppModel.shared.queue)
        }.padding(24)
    }
    private func run() {
        for file in files {
            let ext=file.pathExtension.lowercased();var step:ToolStep
            if ext=="pdf" {step=ToolStep(tool:.pdfCompress);step.image.quality=quality}
            else if ["jpg","jpeg","png","heic","tif","tiff","bmp","webp"].contains(ext) {step=ToolStep(tool:.image);step.image=ImageOptions(format:.jpeg,maxPixel:maxPixel,quality:quality)}
            else if ["mp3","m4a","wav","flac","aiff","aac","ogg","opus"].contains(ext) {step=ToolStep(tool:.audioM4A)}
            else {step=ToolStep(tool:.videoMP4);step.targetMB=targetMB}
            AppModel.shared.queue.enqueue([file],directory:AppModel.shared.directory,recipe:Recipe(name:tr("studio.compress"),steps:[step]))
        }
    }
}

struct VisualStudioLauncher: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            Text(tr("studio.title")).font(.largeTitle.bold())
            SelectionView(model:model)
            HStack {
                Button(tr("studio.image")) { EditorController.shared.show(.image,files:model.files) }
                Button(tr("studio.pdf")) { EditorController.shared.show(.pdf,files:model.files) }
                Button(tr("studio.media")) { EditorController.shared.show(.media,files:model.files) }
                Button(tr("studio.compress")) { EditorController.shared.show(.compress,files:model.files) }
            }.disabled(model.files.isEmpty)
            Text(tr("studio.launchNote")).foregroundStyle(.secondary)
            QueueView(queue:model.queue)
        }.padding(24)
    }
}
