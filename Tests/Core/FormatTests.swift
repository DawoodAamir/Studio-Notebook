import CoreGraphics
import Foundation
import PaperKit
import Testing

@testable import NotebookCore

@Test func portablePagesRoundTrip() throws {
  let pages = [
    PageRecord(
      id: UUID(), title: "Design review", notes: "Confirm proportions", transcript: "Review",
      markup: Data([1, 2, 3]))
  ]
  let decoded = try NotebookRecord.decode(NotebookRecord(pages: pages).encode())
  #expect(decoded.pages[0].id == pages[0].id)
  #expect(decoded.pages[0].markup == pages[0].markup)
  #expect(decoded.pages[0].notes == pages[0].notes)
}
@Test func invalidDocumentsAreRejected() throws {
  #expect(throws: NotebookError.self) { try NotebookRecord(pages: []).encode() }
  let page = PageRecord(id: UUID(), title: "Page", notes: "", transcript: "", markup: Data())
  #expect(throws: NotebookError.self) { try NotebookRecord(pages: [page, page]).encode() }
  var future = NotebookRecord(pages: [page])
  future.version = 99
  #expect(throws: NotebookError.self) { try future.encode() }
}

@Test func realMarkupRoundTripAndPDF() async throws {
  var markup = PaperMarkup(bounds: CGRect(x: 0, y: 0, width: 900, height: 1200))
  markup.insertNewTextbox(
    attributedText: AttributedString("Review the prototype"),
    frame: CGRect(x: 50, y: 70, width: 300, height: 80))
  markup.insertNewShape(
    configuration: ShapeConfiguration(type: .ellipse),
    frame: CGRect(x: 90, y: 240, width: 200, height: 150))
  let data = try await markup.dataRepresentation()
  let restored = try PaperMarkup(dataRepresentation: data)
  #expect(restored.subelements.count == 2)
  #expect(await restored.indexableContent?.contains("Review the prototype") == true)
  let pdf = try await NotebookRenderer.pdf([restored, restored])
  let provider = try #require(CGDataProvider(data: pdf as CFData))
  let document = try #require(CGPDFDocument(provider))
  #expect(document.numberOfPages == 2)
}
