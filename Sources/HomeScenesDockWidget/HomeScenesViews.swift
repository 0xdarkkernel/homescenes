import AppKit
import SwiftUI
import VehlaDockWidgetSDK

extension HomeScenesModel {
    var primaryColor: Color { Color(nsColor: theme?.primaryTextColor ?? .labelColor) }
    var secondaryColor: Color { Color(nsColor: theme?.secondaryTextColor ?? .secondaryLabelColor) }
    var accentColor: Color { .white }
}

private struct HomeActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.black.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Color.white.opacity(configuration.isPressed ? 0.7 : 0.95),
                in: RoundedRectangle(cornerRadius: 8)
            )
    }
}

struct HomeScenesRootView: View {
    let surface: VehlaDockWidgetSurface
    @ObservedObject var model: HomeScenesModel

    var body: some View {
        Group {
            switch surface {
            case .compact:
                CompactHomeView(model: model)
            case .inline:
                InlineHomeView(model: model)
            case .popup:
                HomeScenesPopup(model: model)
            @unknown default:
                EmptyView()
            }
        }
    }
}

private struct CompactHomeView: View {
    @ObservedObject var model: HomeScenesModel

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "house.fill")
                .font(.system(size: 20, weight: .semibold))
            Text(model.sceneCount == 0 ? "Home" : "\(model.sceneCount) scenes")
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(Color(nsColor: model.theme?.tileTextColor ?? .labelColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(model.sceneCount == 0 ? "Home" : "\(model.sceneCount) home scenes")
    }
}

private struct InlineHomeView: View {
    @ObservedObject var model: HomeScenesModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "house.fill")
            VStack(alignment: .leading, spacing: 1) {
                Text(model.inlineScene?.name ?? "Home scenes")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Text(model.sceneCount == 0 ? "Add a Shortcuts folder" : "\(model.sceneCount) scenes")
                    .font(.system(size: 9))
                    .opacity(0.7)
            }
            Spacer(minLength: 0)
            if let scene = model.inlineScene {
                Button {
                    model.run(scene)
                } label: {
                    if model.runningID == scene.id {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "play.fill")
                    }
                }
                .buttonStyle(.plain)
                .help("Run \(scene.name)")
                .disabled(model.runningID != nil && model.runningID != scene.id)
            }
        }
        .padding(10)
        .foregroundStyle(Color(nsColor: model.theme?.tileTextColor ?? .labelColor))
    }
}

private struct HomeScenesPopup: View {
    @ObservedObject var model: HomeScenesModel

    var body: some View {
        VStack(spacing: 0) {
            if model.choosingFolder {
                FolderPicker(model: model)
            } else if model.ready && model.scenes.isEmpty && !model.isRefreshing {
                SetupView(model: model)
            } else {
                SceneList(model: model)
            }
            if let error = model.error {
                HStack {
                    Text(error).font(.caption).lineLimit(3)
                    Spacer()
                    Button("Dismiss") { model.error = nil }
                        .buttonStyle(.plain)
                }
                .padding(12)
            }
            if let notice = model.notice {
                HStack {
                    Text(notice).font(.caption).lineLimit(2)
                    Spacer()
                    Button { model.notice = nil } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss message")
                }
                .padding(10)
                .background(model.primaryColor.opacity(0.08))
            }
        }
        .background(Color.clear)
        .foregroundStyle(model.primaryColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .tint(.white)
        .preferredColorScheme(model.theme?.isDark == true ? .dark : .light)
    }
}

private struct SceneList: View {
    @ObservedObject var model: HomeScenesModel

    var body: some View {
        VStack(spacing: 0) {
            header
            search
            Divider()
            if !model.ready || (model.isRefreshing && model.scenes.isEmpty) {
                ProgressView("Loading scenes…")
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.orderedScenes.isEmpty && model.orderedAccessories.isEmpty {
                ContentUnavailableView(
                    "No matching shortcuts",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different name or folder.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if !model.orderedScenes.isEmpty {
                            sectionTitle("Scenes", count: model.orderedScenes.count)
                            ForEach(model.orderedScenes) { entry in
                                SceneRow(model: model, entry: entry, kind: .scene)
                            }
                        }
                        if model.showsAccessories {
                            sectionTitle("Accessories", count: model.orderedAccessories.count)
                                .padding(.top, 8)
                            ForEach(model.orderedAccessories) { entry in
                                SceneRow(model: model, entry: entry, kind: .accessory)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            Divider()
            footer
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Home").font(.system(size: 20, weight: .semibold))
                Text("Scenes from Shortcuts")
                    .font(.caption)
                    .foregroundStyle(model.secondaryColor)
            }
            Spacer()
            Button {
                model.refresh()
            } label: {
                if model.isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(HomeActionStyle())
            .disabled(model.isRefreshing)
            .keyboardShortcut("r", modifiers: .command)
        }
        .padding(16)
    }

    private var search: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(model.secondaryColor)
            TextField("Search scenes", text: $model.query)
                .textFieldStyle(.plain)
            if !model.query.isEmpty {
                Button { model.query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(10)
        .background(model.primaryColor.opacity(0.08), in: Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var footer: some View {
        HStack {
            Button {
                model.choosingFolder = true
            } label: {
                Label(model.library.trimmedSceneFolder, systemImage: "folder")
            }
            .buttonStyle(.plain)
            .foregroundStyle(model.secondaryColor)
            Spacer()
            Text("\(model.sceneCount) scenes")
                .font(.caption)
                .foregroundStyle(model.secondaryColor)
        }
        .padding(14)
    }

    private func sectionTitle(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(model.secondaryColor)
            Spacer()
        }
    }
}

private struct SceneRow: View {
    @ObservedObject var model: HomeScenesModel
    let entry: ShortcutEntry
    let kind: HomeSceneKind

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: HomeSceneSymbol.systemImage(for: entry.name, kind: kind))
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            Text(entry.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(model.primaryColor)
                .lineLimit(1)
            Spacer(minLength: 8)
            if kind == .scene {
                Button {
                    model.toggleFavorite(entry)
                } label: {
                    Image(systemName: model.isFavorite(entry) ? "star.fill" : "star")
                        .foregroundStyle(model.isFavorite(entry) ? model.accentColor : model.secondaryColor)
                }
                .buttonStyle(.plain)
                .help(model.isFavorite(entry) ? "Remove favorite" : "Favorite")
            }
            Button {
                model.run(entry)
            } label: {
                if model.runningID == entry.id {
                    ProgressView().controlSize(.small).frame(width: 36)
                } else {
                    Text("Run")
                }
            }
            .buttonStyle(HomeActionStyle())
            .disabled(model.runningID != nil)
        }
        .padding(.vertical, 4)
    }
}

private struct SetupView: View {
    @ObservedObject var model: HomeScenesModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Home").font(.system(size: 20, weight: .semibold))
                    Text("Scenes from Shortcuts")
                        .font(.caption)
                        .foregroundStyle(model.secondaryColor)
                }
                Spacer()
            }
            Text("Create a shortcut that runs a Home scene, then put it in a Shortcuts folder named \(model.library.trimmedSceneFolder). Optional light and switch shortcuts go in \(model.library.trimmedAccessoryFolder).")
                .font(.callout)
                .foregroundStyle(model.secondaryColor)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button { model.openShortcuts() } label: {
                    Label("Open Shortcuts", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(HomeActionStyle())
                Button { model.choosingFolder = true } label: {
                    Label("Choose Folder", systemImage: "folder")
                }
                .buttonStyle(.plain)
                Spacer()
                Button { model.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct FolderPicker: View {
    @ObservedObject var model: HomeScenesModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Scene folder")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button("Done") { model.choosingFolder = false }
                    .buttonStyle(HomeActionStyle())
            }
            Text("Shortcuts in this folder appear as scenes. Accessories stay in \(model.library.trimmedAccessoryFolder).")
                .font(.caption)
                .foregroundStyle(model.secondaryColor)
            if model.folders.isEmpty {
                Text("No Shortcuts folders yet. Create one named Home, then refresh.")
                    .font(.callout)
                    .foregroundStyle(model.secondaryColor)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(model.folders, id: \.self) { folder in
                            Button {
                                model.selectFolder(folder)
                            } label: {
                                HStack {
                                    Text(folder)
                                        .font(.system(size: 13, weight: .medium))
                                    Spacer()
                                    if folder == model.library.trimmedSceneFolder {
                                        Image(systemName: "checkmark")
                                    }
                                }
                                .foregroundStyle(
                                    folder == model.library.trimmedSceneFolder
                                        ? Color.black.opacity(0.85)
                                        : Color.white.opacity(0.85)
                                )
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    folder == model.library.trimmedSceneFolder
                                        ? Color.white.opacity(0.95)
                                        : Color.white.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
