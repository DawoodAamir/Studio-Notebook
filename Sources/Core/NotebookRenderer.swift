import Foundation
import ImageIO
import PaperKit

public enum NotebookRenderer {
  @concurrent public static func image(_ url: URL) async throws -> CGImage {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 20_000_000 else {
      throw NotebookError.invalid
    }
    try Task.checkCancellation()
    let data = try Data(contentsOf: url)
    guard data.count <= 20_000_000, let source = CGImageSourceCreateWithData(data as CFData, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
      let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
      width.doubleValue > 0, height.doubleValue > 0,
      width.doubleValue * height.doubleValue <= 50_000_000,
      let image = CGImageSourceCreateThumbnailAtIndex(
        source, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceThumbnailMaxPixelSize: 2200,
          kCGImageSourceCreateThumbnailWithTransform: true,
        ] as CFDictionary)
    else { throw NotebookError.invalid }
    return image
  }
  @concurrent public static func pdf(_ pages: [PaperMarkup]) async throws -> Data {
    let data = NSMutableData()
    guard let consumer = CGDataConsumer(data: data),
      let context = CGContext(consumer: consumer, mediaBox: nil, nil)
    else { throw NotebookError.invalid }
    for page in pages {
      try Task.checkCancellation()
      var bounds = CGRect(x: 0, y: 0, width: 600, height: 800)
      context.beginPDFPage(
        [kCGPDFContextMediaBox: NSData(bytes: &bounds, length: MemoryLayout<CGRect>.size)]
          as CFDictionary)
      await page.draw(in: context, frame: bounds)
      context.endPDFPage()
    }
    context.closePDF()
    return data as Data
  }
}
