import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let dir=URL(fileURLWithPath:CommandLine.arguments.count>1 ? CommandLine.arguments[1] : "fixtures",isDirectory:true)
try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
let context=CGContext(data:nil,width:640,height:360,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
context.setFillColor(CGColor(red:0.98,green:0.3,blue:0.15,alpha:0.8));context.fill(CGRect(x:0,y:0,width:420,height:360))
let file=dir.appendingPathComponent("coral ñ.png")
let destination=CGImageDestinationCreateWithURL(file as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(destination,context.makeImage()!,nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write PNG fixture") }
try Data("invalid image".utf8).write(to:dir.appendingPathComponent("corrupt.jpg"))
try Data().write(to:dir.appendingPathComponent("empty.png"))
