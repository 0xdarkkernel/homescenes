import Foundation

enum ShortcutClientError: Error, Equatable {
    case emptyName
    case folderMissing
    case unavailable(String)
    case failed(String)
}

protocol ShortcutClient: Sendable {
    func folders() async throws -> [String]
    func shortcuts(in folder: String) async throws -> [ShortcutEntry]
    func run(_ entry: ShortcutEntry) async throws
}

struct ProcessShortcutClient: ShortcutClient {
    var executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
    var timeout: Duration = .seconds(30)

    func folders() async throws -> [String] {
        let output = try await execute(ShortcutCommands.listFolders(), folder: nil)
        return ShortcutListParser.folders(from: output)
    }

    func shortcuts(in folder: String) async throws -> [ShortcutEntry] {
        let output = try await execute(ShortcutCommands.list(folder: folder), folder: folder)
        return ShortcutListParser.entries(from: output)
    }

    func run(_ entry: ShortcutEntry) async throws {
        let token = entry.runToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !token.contains(where: \.isNewline) else {
            throw ShortcutClientError.emptyName
        }
        _ = try await execute(ShortcutCommands.run(entry), folder: nil)
    }

    private func execute(_ arguments: [String], folder: String?) async throws -> String {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()

        let timeoutTask = Task {
            try? await Task.sleep(for: timeout)
            if process.isRunning { process.terminate() }
        }
        defer { timeoutTask.cancel() }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { process in
                    let output = String(
                        data: stdout.fileHandleForReading.readDataToEndOfFile(),
                        encoding: .utf8
                    ) ?? ""
                    let errorText = String(
                        data: stderr.fileHandleForReading.readDataToEndOfFile(),
                        encoding: .utf8
                    ) ?? ""
                    if process.terminationStatus == 0 {
                        continuation.resume(returning: output)
                        return
                    }
                    continuation.resume(throwing: Self.classify(errorText, folder: folder))
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }

    static func classify(_ message: String, folder: String?) -> ShortcutClientError {
        if ShortcutFailureText.isHelperUnavailable(message) {
            return .unavailable("Shortcuts is unavailable. Open Shortcuts, then try again.")
        }
        if folder != nil, ShortcutFailureText.isFolderMissing(message) {
            return .folderMissing
        }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .failed("Shortcuts could not complete that action.")
        }
        return .failed(trimmed)
    }
}
