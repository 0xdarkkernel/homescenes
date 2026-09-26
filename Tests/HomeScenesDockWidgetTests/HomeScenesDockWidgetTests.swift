import Foundation
import Testing
@testable import HomeScenesDockWidget

@Test func parserReadsParenthesizedAndTrailingIdentifiers() {
    let output = """
    Good Night (AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE)
    Movie Night (Director's cut) (BBBBBBBB-BBBB-CCCC-DDDD-EEEEEEEEEEEE)
    Morning\tCCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC
    Just a name

    Good Night (AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE)
    """
    let entries = ShortcutListParser.entries(from: output)
    #expect(entries.map(\.name) == [
        "Good Night",
        "Movie Night (Director's cut)",
        "Morning",
        "Just a name",
    ])
    #expect(entries[0].identifier == "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
    #expect(entries[2].identifier == "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")
    #expect(entries[3].identifier == "")
    #expect(entries[3].id == "Just a name")
    #expect(entries[0].runToken == "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
}

@Test func folderParserDropsBlanksAndDuplicates() {
    #expect(ShortcutListParser.folders(from: "Home\n\nAccessories\nHome\n") == ["Home", "Accessories"])
}

@Test func favoritesSortAheadOfAlphabeticalScenes() {
    let entries = [
        ShortcutEntry(name: "Zebra", identifier: "z"),
        ShortcutEntry(name: "Alpha", identifier: "a"),
        ShortcutEntry(name: "Morning", identifier: "m"),
    ]
    let ordered = HomeSceneOrder.favoritesFirst(entries, favoriteIDs: ["m"])
    #expect(ordered.map(\.name) == ["Morning", "Alpha", "Zebra"])
}

@Test func runCommandsUseTheIdentifierAndRejectAForeignEntry() {
    let scene = ShortcutEntry(name: "Good Night", identifier: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
    #expect(ShortcutCommands.run(scene) == ["run", scene.identifier])
    #expect(ShortcutCommands.list(folder: "Home") == ["list", "--folder-name", "Home", "--show-identifiers"])
    let other = ShortcutEntry(name: "Good Night", identifier: "other")
    #expect(!HomeSceneOrder.contains(other, in: [scene]))
    #expect(HomeSceneOrder.contains(scene, in: [scene]))
}

@Test func symbolsFollowSceneAndAccessoryNames() {
    #expect(HomeSceneSymbol.systemImage(for: "Good Night", kind: .scene) == "moon.stars.fill")
    #expect(HomeSceneSymbol.systemImage(for: "Movie Time", kind: .scene) == "film.fill")
    #expect(HomeSceneSymbol.systemImage(for: "Kitchen Lights", kind: .accessory) == "lightbulb.fill")
    #expect(HomeSceneSymbol.systemImage(for: "Front Lock", kind: .accessory) == "lock.fill")
}

@Test func failureTextRecognizesMissingFoldersAndTheShortcutsHelper() {
    #expect(ShortcutFailureText.isFolderMissing("The folder “Home” could not be found."))
    #expect(!ShortcutFailureText.isFolderMissing("Couldn’t communicate with a helper application."))
    #expect(ShortcutFailureText.isHelperUnavailable("Couldn’t communicate with a helper application."))
}

@Test func libraryRoundTripKeepsFavoritesAndFolderNames() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = HomeScenesStore(directory: directory)
    var library = HomeLibrary()
    library.sceneFolder = "Downstairs"
    library.favoriteIDs = ["scene-1"]
    try await store.save(library)
    let loaded = try await store.load()
    #expect(loaded == library)
}
