import Foundation

enum HomeSceneKind: String, Sendable {
    case scene
    case accessory
}

struct ShortcutEntry: Hashable, Codable, Sendable, Identifiable {
    var name: String
    var identifier: String

    var id: String { identifier.isEmpty ? name : identifier }

    var runToken: String { identifier.isEmpty ? name : identifier }
}

struct HomeLibrary: Codable, Equatable, Sendable {
    var version: Int = 1
    var sceneFolder: String = "Home"
    var accessoryFolder: String = "Accessories"
    var favoriteIDs: [String] = []

    var trimmedSceneFolder: String {
        let trimmed = sceneFolder.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Home" : trimmed
    }

    var trimmedAccessoryFolder: String {
        let trimmed = accessoryFolder.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Accessories" : trimmed
    }
}

enum ShortcutCommands {
    static func listFolders() -> [String] { ["list", "--folders"] }

    static func list(folder: String) -> [String] {
        ["list", "--folder-name", folder, "--show-identifiers"]
    }

    static func run(_ entry: ShortcutEntry) -> [String] {
        ["run", entry.runToken]
    }
}

enum ShortcutListParser {
    private static let uuid =
        #"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"#

    static func entries(from output: String) -> [ShortcutEntry] {
        var seen = Set<String>()
        return output.split(whereSeparator: \.isNewline).compactMap { line in
            let entry = entry(from: String(line))
            guard let entry, seen.insert(entry.id).inserted else { return nil }
            return entry
        }
    }

    static func folders(from output: String) -> [String] {
        var seen = Set<String>()
        return output.split(whereSeparator: \.isNewline).compactMap { line in
            let name = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seen.insert(name).inserted else { return nil }
            return name
        }
    }

    static func entry(from line: String) -> ShortcutEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let pattern = #"^(.*?)(?:\s+\((\#(uuid))\)|\s+(\#(uuid)))$"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: trimmed,
                range: NSRange(trimmed.startIndex..., in: trimmed)
              ),
              let nameRange = Range(match.range(at: 1), in: trimmed)
        else {
            return ShortcutEntry(name: trimmed, identifier: "")
        }
        let name = String(trimmed[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return ShortcutEntry(name: trimmed, identifier: "") }
        let identifier = identifier(in: trimmed, match: match, group: 2)
            ?? identifier(in: trimmed, match: match, group: 3)
            ?? ""
        return ShortcutEntry(name: name, identifier: identifier)
    }

    private static func identifier(in text: String, match: NSTextCheckingResult, group: Int) -> String? {
        let range = match.range(at: group)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }
}

enum HomeSceneSymbol {
    static func systemImage(for name: String, kind: HomeSceneKind) -> String {
        let lowered = name.lowercased()
        if kind == .accessory {
            if lowered.contains("lock") { return "lock.fill" }
            if lowered.contains("fan") { return "fan.fill" }
            if lowered.contains("switch") { return "switch.2" }
            if lowered.contains("outlet") || lowered.contains("plug") { return "powerplug.fill" }
            if lowered.contains("blind") || lowered.contains("shade") { return "blinds.horizontal.closed" }
            if lowered.contains("thermo") || lowered.contains("heat") || lowered.contains("cool") {
                return "thermometer.medium"
            }
            return "lightbulb.fill"
        }
        if lowered.contains("night") || lowered.contains("sleep") || lowered.contains("bed") {
            return "moon.stars.fill"
        }
        if lowered.contains("morning") || lowered.contains("wake") || lowered.contains("sunrise") {
            return "sunrise.fill"
        }
        if lowered.contains("movie") || lowered.contains("cinema") || lowered.contains("tv") {
            return "film.fill"
        }
        if lowered.contains("away") || lowered.contains("leave") || lowered.contains("goodbye") {
            return "figure.walk.departure"
        }
        if lowered.contains("arrive") || lowered == "home" || lowered.contains("i'm home") || lowered.contains("im home") {
            return "house.fill"
        }
        if lowered.contains("dinner") || lowered.contains("eat") { return "fork.knife" }
        if lowered.contains("party") || lowered.contains("guest") { return "party.popper.fill" }
        if lowered.contains("work") || lowered.contains("focus") { return "briefcase.fill" }
        if lowered.contains("read") { return "book.fill" }
        if lowered.contains("music") { return "music.note" }
        return "sparkles"
    }
}

enum HomeSceneOrder {
    static func favoritesFirst(
        _ entries: [ShortcutEntry],
        favoriteIDs: [String]
    ) -> [ShortcutEntry] {
        let favorite = Set(favoriteIDs)
        return entries.sorted { lhs, rhs in
            let leftFavorite = favorite.contains(lhs.id)
            let rightFavorite = favorite.contains(rhs.id)
            if leftFavorite != rightFavorite { return leftFavorite }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    static func contains(_ entry: ShortcutEntry, in entries: [ShortcutEntry]) -> Bool {
        entries.contains { $0.id == entry.id && $0.runToken == entry.runToken }
    }
}

enum ShortcutFailureText {
    static func isFolderMissing(_ message: String) -> Bool {
        let lowered = message.lowercased()
        return lowered.contains("folder")
            && (lowered.contains("not found")
                || lowered.contains("not be found")
                || lowered.contains("couldn't find")
                || lowered.contains("could not find")
                || lowered.contains("no folder"))
    }

    static func isHelperUnavailable(_ message: String) -> Bool {
        message.lowercased().contains("helper application")
    }
}
