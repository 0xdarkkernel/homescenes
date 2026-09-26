import AppKit
import Foundation
import VehlaDockWidgetSDK

@MainActor
final class HomeScenesModel: ObservableObject {
    @Published private(set) var library = HomeLibrary()
    @Published private(set) var ready = false
    @Published private(set) var scenes: [ShortcutEntry] = []
    @Published private(set) var accessories: [ShortcutEntry] = []
    @Published private(set) var folders: [String] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var runningID: String?
    @Published var error: String?
    @Published var notice: String?
    @Published var query = ""
    @Published var choosingFolder = false
    @Published var theme: VehlaDockWidgetTheme?

    private let client: any ShortcutClient
    private var store: HomeScenesStore?
    private var refreshTask: Task<Void, Never>?
    private var refreshGeneration = 0
    private var runTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var active = false

    init(client: any ShortcutClient = ProcessShortcutClient()) {
        self.client = client
    }

    var orderedScenes: [ShortcutEntry] {
        HomeSceneOrder.favoritesFirst(filtered(scenes), favoriteIDs: library.favoriteIDs)
    }

    var orderedAccessories: [ShortcutEntry] {
        HomeSceneOrder.favoritesFirst(filtered(accessories), favoriteIDs: [])
    }

    var showsAccessories: Bool {
        library.trimmedAccessoryFolder.caseInsensitiveCompare(library.trimmedSceneFolder) != .orderedSame
            && !orderedAccessories.isEmpty
    }

    var inlineScene: ShortcutEntry? {
        orderedScenes.first
    }

    var sceneCount: Int { scenes.count }

    func isFavorite(_ entry: ShortcutEntry) -> Bool {
        library.favoriteIDs.contains(entry.id)
    }

    func configure(_ context: VehlaDockWidgetContext) {
        theme = context.theme
        if store == nil {
            store = HomeScenesStore(directory: context.dataDirectory)
        }
        start()
    }

    func start() {
        active = true
        guard !ready else { return }
        refresh()
    }

    func stop() {
        active = false
        refreshTask?.cancel()
        runTask?.cancel()
        isRefreshing = false
        runningID = nil
    }

    func refresh() {
        guard active || store != nil else { return }
        refreshTask?.cancel()
        isRefreshing = true
        error = nil
        refreshGeneration += 1
        let generation = refreshGeneration
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await self.loadBoard(generation: generation)
        }
    }

    func selectFolder(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        library.sceneFolder = trimmed
        choosingFolder = false
        persist()
        refresh()
    }

    func toggleFavorite(_ entry: ShortcutEntry) {
        if let index = library.favoriteIDs.firstIndex(of: entry.id) {
            library.favoriteIDs.remove(at: index)
        } else {
            library.favoriteIDs.append(entry.id)
        }
        persist()
    }

    func run(_ entry: ShortcutEntry) {
        let catalog = scenes + accessories
        guard HomeSceneOrder.contains(entry, in: catalog) else {
            error = "That shortcut is no longer in the selected folder."
            return
        }
        guard runningID == nil else { return }
        runningID = entry.id
        error = nil
        runTask?.cancel()
        runTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.client.run(entry)
                guard !Task.isCancelled else { return }
                self.runningID = nil
                self.showNotice("Ran \(entry.name)")
            } catch is CancellationError {
                self.runningID = nil
            } catch let failure as ShortcutClientError {
                self.runningID = nil
                self.error = failure.userMessage
            } catch {
                self.runningID = nil
                self.error = error.localizedDescription
            }
        }
    }

    func openShortcuts() {
        NSWorkspaceBridge.openShortcuts()
    }

    private func filtered(_ entries: [ShortcutEntry]) -> [ShortcutEntry] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return entries }
        return entries.filter { $0.name.localizedStandardContains(needle) }
    }

    private func loadBoard(generation: Int) async {
        if !ready, let store, let loaded = try? await store.load() {
            library = loaded
        }
        do {
            let folderNames = try await client.folders()
            guard !Task.isCancelled, generation == refreshGeneration else { return }
            folders = folderNames
        } catch {
            guard !Task.isCancelled, generation == refreshGeneration else { return }
            folders = []
            if let failure = error as? ShortcutClientError, case .unavailable = failure {
                isRefreshing = false
                ready = true
                self.error = failure.userMessage
                return
            }
        }

        async let sceneResult = loadFolder(library.trimmedSceneFolder)
        let accessoryName = library.trimmedAccessoryFolder
        let accessoryResult: Result<[ShortcutEntry], Error>
        if accessoryName.caseInsensitiveCompare(library.trimmedSceneFolder) == .orderedSame {
            accessoryResult = .success([])
        } else {
            accessoryResult = await loadFolder(accessoryName)
        }
        let scenesLoaded = await sceneResult
        guard !Task.isCancelled, generation == refreshGeneration else { return }

        switch scenesLoaded {
        case .success(let entries):
            scenes = entries
            error = nil
        case .failure(let failure):
            scenes = []
            if let clientError = failure as? ShortcutClientError {
                if case .folderMissing = clientError {
                    error = nil
                } else {
                    error = clientError.userMessage
                }
            } else {
                error = failure.localizedDescription
            }
        }

        switch accessoryResult {
        case .success(let entries):
            accessories = entries
        case .failure:
            accessories = []
        }
        ready = true
        isRefreshing = false
    }

    private func loadFolder(_ name: String) async -> Result<[ShortcutEntry], Error> {
        do {
            return .success(try await client.shortcuts(in: name))
        } catch {
            return .failure(error)
        }
    }

    private func persist() {
        let snapshot = library
        guard let store else { return }
        Task {
            try? await store.save(snapshot)
        }
    }

    private func showNotice(_ text: String) {
        notice = text
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }
}

extension ShortcutClientError {
    var userMessage: String {
        switch self {
        case .emptyName:
            return "Choose a shortcut before running it."
        case .folderMissing:
            return "That Shortcuts folder could not be found."
        case .unavailable(let message), .failed(let message):
            return message
        }
    }
}

enum NSWorkspaceBridge {
    static func openShortcuts() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
    }
}
