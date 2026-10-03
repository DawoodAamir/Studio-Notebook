import PaperKit
import PencilKit
import SwiftUI
import UniformTypeIdentifiers

struct NotebookView: View {
  @Bindable var document: NotebookDocument
  @Environment(\.undoManager) private var undoManager
  @State private var selection: UUID?
  @State private var search = ""
  @State private var inspector = false
  @State private var importing = false
  @State private var deleting = false
  @State private var recognizing = false
  @State private var error: String?
  @State private var export: NotebookExport?
  @State private var exportType = UTType.pdf
  @State private var exportTask: Task<Void, Never>?
  @State private var importTask: Task<Void, Never>?
  @State private var recognitionGeneration = UUID()
  @State private var exporting = false
  @State private var recognizer = PKStrokeRecognizer()
  @State private var recognitionTask: Task<Void, Never>?
  private var index: Int? { document.pages.firstIndex { $0.id == selection } }
  var body: some View {
    NavigationSplitView {
      List(selection: $selection) {
        ForEach(
          document.pages.filter {
            search.isEmpty
              || ($0.title + $0.notes + $0.transcript).localizedCaseInsensitiveContains(search)
          }
        ) { page in
          NavigationLink(value: page.id) {
            VStack(alignment: .leading, spacing: 4) {
              Text(page.title)
              if !page.notes.isEmpty {
                Text(page.notes).lineLimit(1).font(.caption).foregroundStyle(.secondary)
              }
            }
          }
        }
      }.navigationTitle("Pages").searchable(text: $search, prompt: "Titles, notes, recognised ink")
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        .toolbar {
          Button("Add page", systemImage: "plus") {
            let page = NotebookPage()
            edit("Add page") { $0.append(page) }
            selection = page.id
          }.disabled(document.pages.count >= 100)
        }
    } detail: {
      if let index {
        PaperCanvas(markup: markupBinding(for: document.pages[index].id))
          .id(document.pages[index].id)
          .navigationTitle(document.pages[index].title)
          .toolbar {
            Menu("Insert", systemImage: "plus.square") {
              Button("Text box") { insertText(index) }
              Button("Rectangle") { insertShape(index, .roundedRectangle) }
              Button("Ellipse") { insertShape(index, .ellipse) }
              Button("Image") { importing = true }
            }
            Button("Page details", systemImage: "sidebar.right") { inspector.toggle() }
            Menu("Page actions", systemImage: "ellipsis.circle") {
              Button("Duplicate page") {
                var page = document.pages[index]
                page.id = UUID()
                page.title += " copy"
                edit("Duplicate page") { $0.append(page) }
                selection = page.id
              }.disabled(document.pages.count >= 100)
              Button("Export notebook PDF") { startExport(as: .pdf) }
              Button("Export notebook copy") { startExport(as: .studioNotebook) }
              Button("Delete page", role: .destructive) { deleting = true }.disabled(
                document.pages.count == 1)
            }
          }
          .inspector(isPresented: $inspector) {
            details(index).inspectorColumnWidth(min: 240, ideal: 300, max: 400)
          }
      } else {
        ContentUnavailableView(
          "Choose a page", systemImage: "book.closed",
          description: Text("Your drawings, images, and notes stay in this notebook document."))
      }
    }
    .task { if selection == nil { selection = document.pages.first?.id } }
    .onDisappear {
      recognitionGeneration = UUID()
      recognitionTask?.cancel()
      importTask?.cancel()
      exportTask?.cancel()
    }
    .fileImporter(isPresented: $importing, allowedContentTypes: [.image]) { result in
      importTask?.cancel()
      importTask = Task {
        do { try await importImage(result.get()) } catch is CancellationError {} catch {
          if !Task.isCancelled { self.error = error.localizedDescription }
        }
      }
    }
    .fileExporter(
      isPresented: $exporting, document: export, contentType: exportType,
      defaultFilename: "Notebook"
    ) { result in if case .failure(let error) = result { self.error = error.localizedDescription } }
    .confirmationDialog("Delete this page?", isPresented: $deleting) {
      Button("Delete page", role: .destructive) {
        if let index {
          edit("Delete page") { $0.remove(at: index) }
          selection = document.pages.first?.id
        }
      }
    } message: {
      Text("Use Undo to restore the deleted page.")
    }
    .alert(
      "Couldn't finish",
      isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    ) {
      Button("OK") { error = nil }
    } message: {
      Text(error ?? "")
    }
  }
  private func details(_ index: Int) -> some View {
    Form {
      TextField(
        "Page title",
        text: textBinding(
          for: document.pages[index].id, key: \.title, limit: 200, action: "Rename page")
      ).accessibilityIdentifier(
        "page-title")
      TextField(
        "Notes",
        text: textBinding(
          for: document.pages[index].id, key: \.notes, limit: 10000, action: "Edit notes"),
        axis: .vertical
      ).lineLimit(4...12)
      Section("Handwriting") {
        Button("Recognise ink", systemImage: "text.viewfinder") {
          recognitionTask?.cancel()
          let generation = UUID()
          recognitionGeneration = generation
          recognitionTask = Task { await recognize(generation: generation) }
        }
        .disabled(recognizing)
        if recognizing { ProgressView() }
        Text(
          document.pages[index].transcript.isEmpty
            ? "Recognition runs locally. Handwriting and language affect accuracy; review the result."
            : document.pages[index].transcript
        ).textSelection(.enabled)
      }
      Text(
        "Search uses titles, notes, and the last recognition result. Re-run recognition after changing ink."
      ).font(.caption).foregroundStyle(.secondary)
    }.formStyle(.grouped)
  }
  private func insertText(_ index: Int) {
    edit("Insert text") { pages in
      pages[index].markup.insertNewTextbox(
        attributedText: AttributedString("Your note"),
        frame: CGRect(x: 120, y: 180, width: 400, height: 100))
    }
  }
  private func insertShape(_ index: Int, _ shape: ShapeConfiguration.Shape) {
    edit("Insert shape") { pages in
      pages[index].markup.insertNewShape(
        configuration: ShapeConfiguration(
          type: shape, fillColor: CGColor(srgbRed: 0.86, green: 0.9, blue: 0.96, alpha: 1),
          strokeColor: CGColor(gray: 0.3, alpha: 1), lineWidth: 2),
        frame: CGRect(x: 160, y: 340, width: 300, height: 180))
    }
  }
  private func recognize(generation: UUID) async {
    guard let index else { return }
    recognizing = true
    defer { if recognitionGeneration == generation { recognizing = false } }
    let page = document.pages[index]
    let drawing = PKDrawing(strokes: page.markup.subelements.strokes)
    await recognizer.updateDrawing(drawing)
    let text = await recognizer.recognizedText() ?? ""
    guard !Task.isCancelled, recognitionGeneration == generation,
      let current = document.pages.firstIndex(where: { $0.id == page.id }),
      document.pages[current].markup == page.markup
    else { return }
    edit("Recognise handwriting") { $0[current].transcript = String(text.prefix(20000)) }
  }
  private func importImage(_ url: URL) async throws {
    guard let index else { return }
    let pageID = document.pages[index].id
    let image = try await NotebookRenderer.image(url)
    try Task.checkCancellation()
    guard let current = document.pages.firstIndex(where: { $0.id == pageID }) else { return }
    let ratio = CGFloat(image.height) / CGFloat(image.width)
    edit("Insert image") { pages in
      pages[current].markup.insertNewImage(
        image, frame: CGRect(x: 150, y: 250, width: 500, height: min(800, 500 * ratio)))
    }
  }
  private func edit(_ action: String, _ change: (inout [NotebookPage]) -> Void) {
    guard let undoManager else {
      error = "The document's editing session isn't ready. Reopen the notebook."
      return
    }
    var next = document.pages
    change(&next)
    document.replacePages(next, undoManager: undoManager, action: action)
  }
  private func markupBinding(for id: UUID) -> Binding<PaperMarkup> {
    Binding(
      get: {
        document.pages.first(where: { $0.id == id })?.markup
          ?? PaperMarkup(bounds: CGRect(x: 0, y: 0, width: 900, height: 1200))
      },
      set: { value in
        edit("Edit canvas") { pages in
          if let i = pages.firstIndex(where: { $0.id == id }) { pages[i].markup = value }
        }
      })
  }
  private func textBinding(
    for id: UUID, key: WritableKeyPath<NotebookPage, String>, limit: Int, action: String
  ) -> Binding<String> {
    Binding(
      get: { document.pages.first(where: { $0.id == id })?[keyPath: key] ?? "" },
      set: { value in
        edit(action) { pages in
          if let i = pages.firstIndex(where: { $0.id == id }) {
            pages[i][keyPath: key] = String(value.prefix(limit))
          }
        }
      })
  }
  private func startExport(as type: UTType) {
    exportTask?.cancel()
    exportTask = Task {
      do {
        let data: Data
        if type == .pdf {
          data = try await NotebookRenderer.pdf(document.pages.map(\.markup))
        } else {
          data = try await document.snapshot(contentType: .studioNotebook).encode()
        }
        try Task.checkCancellation()
        export = NotebookExport(data: data)
        exportType = type
        exporting = true
      } catch is CancellationError {} catch {
        if !Task.isCancelled { self.error = error.localizedDescription }
      }
    }
  }
}
struct NotebookExport: FileDocument {
  static var readableContentTypes: [UTType] { [.pdf, .studioNotebook] }
  var data: Data
  init(data: Data) { self.data = data }
  init(configuration: ReadConfiguration) throws {
    guard let contents = configuration.file.regularFileContents else { throw NotebookError.invalid }
    data = contents
  }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}
