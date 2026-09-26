import Foundation

actor HomeScenesStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL) {
        fileURL = directory.appendingPathComponent("library.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() throws -> HomeLibrary {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return HomeLibrary() }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(HomeLibrary.self, from: data)
    }

    func save(_ library: HomeLibrary) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(library)
        let temporary = directory.appendingPathComponent("library.json.tmp")
        try data.write(to: temporary, options: .atomic)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporary)
        } else {
            try FileManager.default.moveItem(at: temporary, to: fileURL)
        }
    }
}
