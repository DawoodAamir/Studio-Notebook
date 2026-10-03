import Foundation

public struct PageRecord: Codable, Sendable, Identifiable {
  public var id: UUID
  public var title: String
  public var notes: String
  public var transcript: String
  public var markup: Data
  public init(id: UUID, title: String, notes: String, transcript: String, markup: Data) {
    self.id = id
    self.title = title
    self.notes = notes
    self.transcript = transcript
    self.markup = markup
  }
}
public struct NotebookRecord: Codable, Sendable {
  public var version = 1
  public var pages: [PageRecord]
  public init(pages: [PageRecord]) { self.pages = pages }
  public static func decode(_ data: Data) throws -> Self {
    guard data.count <= 40_000_000 else { throw NotebookError.invalid }
    let result = try JSONDecoder().decode(Self.self, from: data)
    guard result.version == 1, !result.pages.isEmpty, result.pages.count <= 100,
      Set(result.pages.map(\.id)).count == result.pages.count,
      result.pages.allSatisfy({
        $0.markup.count <= 25_000_000 && $0.title.count <= 200 && $0.notes.count <= 10000
          && $0.transcript.count <= 20000
      })
    else { throw NotebookError.invalid }
    return result
  }
  public func encode() throws -> Data {
    let data = try JSONEncoder().encode(self)
    _ = try Self.decode(data)
    return data
  }
}
public enum NotebookError: LocalizedError, Sendable {
  case invalid
  public var errorDescription: String? {
    "This notebook is invalid or exceeds the 100-page, 40 MB document limit. Its original file has not been replaced."
  }
}
