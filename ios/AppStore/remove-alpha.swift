// Rewrites PNGs in place without a transparency (alpha) channel, at the same pixel size.
// App Store Connect refuses screenshots that have one, and simulator screenshots can.
//
//   swift remove-alpha.swift one.png two.png …
//
// macOS only (CoreGraphics). CI runs it on the App Store screenshots; see .github/workflows/ios.yml.
import CoreGraphics
import Foundation
import ImageIO

var failed = false
for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let source = CGImageSourceCreateWithURL(url, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { print("remove-alpha: can't read \(path)"); failed = true; continue }
    // Anything see-through lands on white, though a screenshot shouldn't have any.
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    guard let flat = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil)
    else { print("remove-alpha: can't rewrite \(path)"); failed = true; continue }
    CGImageDestinationAddImage(destination, flat, nil)
    if !CGImageDestinationFinalize(destination) { print("remove-alpha: can't write \(path)"); failed = true }
}
exit(failed ? 1 : 0)
