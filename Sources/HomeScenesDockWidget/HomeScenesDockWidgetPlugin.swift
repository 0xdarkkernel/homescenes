import AppKit
import SwiftUI
import VehlaDockWidgetSDK

@objc(HomeScenesDockWidgetPlugin)
public final class HomeScenesDockWidgetPlugin: NSObject, VehlaDockWidgetPlugin {
    public let apiVersion = VehlaDockWidgetAPIVersion
    public let widgets = [
        VehlaDockWidgetDescriptor(
            id: "home-scenes",
            title: "Home",
            subtitle: "Scenes and accessory shortcuts",
            systemImage: "house.fill",
            preferredPopupWidth: 560,
            preferredPopupHeight: 700,
            supportedSurfaces: [.compact, .inline, .popup]
        ),
    ]

    @MainActor private let model = HomeScenesModel()

    @MainActor
    public func makeViewController(
        widgetID: String,
        surface: VehlaDockWidgetSurface,
        context: VehlaDockWidgetContext
    ) throws -> NSViewController {
        guard widgetID == "home-scenes" else { throw CocoaError(.fileNoSuchFile) }
        model.configure(context)
        return NSHostingController(rootView: HomeScenesRootView(surface: surface, model: model))
    }

    @MainActor
    public func widget(
        _ widgetID: String,
        didEnter phase: VehlaDockWidgetVisibilityPhase
    ) {
        phase == .hidden ? model.stop() : model.start()
    }

    @MainActor
    public func widget(
        _ widgetID: String,
        themeDidChange theme: VehlaDockWidgetTheme
    ) {
        model.theme = theme
    }

    @MainActor
    public func widgetWillClose(_ widgetID: String) {
        model.stop()
    }
}
