import Observation
import PaperKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
  static let studioNotebook = UTType(
    exportedAs: "com.dd.studionotebook.document", conformingTo: .data)
}
struct NotebookPage: Identifiable, Sendable, Equatable {
  var id = UUID()
  var title = "Untitled page"
  var notes = ""
  var transcript = ""
  var markup = PaperMarkup(bounds: CGRect(x: 0, y: 0, width: 900, height: 1200))
}
@MainActor @Observable final class NotebookDocument: Document {
  var pages = [NotebookPage()]
  let configuration: URLDocumentConfiguration
  init(configuration: URLDocumentConfiguration) { self.configuration = configuration }
  func replacePages(_ next: [NotebookPage], undoManager: UndoManager, action: String) {
    guard next != pages else { return }
    let previous = pages
    pages = next
    undoManager.registerUndo(withTarget: self) { document in
      MainActor.assumeIsolated {
        document.replacePages(previous, undoManager: undoManager, action: action)
      }
    }
    undoManager.setActionName(action)
  }
  nonisolated static var readableContentTypes: [UTType] { [.studioNotebook] }
  nonisolated func reader(configuration: sending ReadConfiguration)
    -> sending FileWrapperDocumentReader<NotebookRecord>
  {
    FileWrapperDocumentReader(configuration) { wrapper in
      guard let data = wrapper.regularFileContents else { throw NotebookError.invalid }
      return try NotebookRecord.decode(data)
    }
  }
  nonisolated func writer(configuration: sending WriteConfiguration)
    -> sending FileWrapperDocumentWriter<NotebookRecord>
  {
    FileWrapperDocumentWriter(configuration) { record, _ in
      FileWrapper(regularFileWithContents: try record.encode())
    }
  }
  func apply(snapshot: sending NotebookRecord, previous: sending NotebookRecord?) async throws {
    let decoded = try snapshot.pages.map { record in
      var page = NotebookPage()
      page.id = record.id
      page.title = record.title
      page.notes = record.notes
      page.transcript = record.transcript
      page.markup = try PaperMarkup(dataRepresentation: record.markup)
      return page
    }
    pages = decoded
  }
  func snapshot(contentType: UTType) async throws -> sending NotebookRecord {
    // Capture values before suspension so an autosave represents one coherent revision.
    let captured = pages
    var records: [PageRecord] = []
    for page in captured {
      records.append(
        PageRecord(
          id: page.id, title: page.title, notes: page.notes, transcript: page.transcript,
          markup: try await page.markup.dataRepresentation()))
    }
    return NotebookRecord(pages: records)
  }
}
@main struct NotebookApp: App {
  init() {
    try? FileManager.default.createDirectory(
      at: URL.documentsDirectory, withIntermediateDirectories: true)
  }
  var body: some Scene {
    DocumentGroup { document in
      NotebookView(document: document)
    } makeDocument: { configuration, _ in
      NotebookDocument(configuration: configuration)
    }
  }
}
