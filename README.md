# Home Scenes

Run Home scenes from the Dock. Compact shows the scene count, inline runs the favorite scene, and the popup lists every shortcut in the folder you choose.

Vehla does not include Apple's HomeKit entitlement, so this widget cannot read the Home app directly. Shortcuts already can. A shortcut that uses **Control Home** is the scene button.

## Setup

1. In Shortcuts, create a shortcut that runs a Home scene.
2. Put those shortcuts in a folder named **Home**.
3. Optional: put light, switch, and lock shortcuts in a folder named **Accessories**.
4. Install this package, then enable **Home** under Settings → Dock Widgets.

The popup can point the scene list at a different Shortcuts folder. Favorites stay on this Mac in the extension's private storage. Accessory shortcuts are listed separately and are not mixed into favorites.

## Build and install

Requires macOS 14+, Apple silicon, and Swift 6.

```sh
swift test --package-path extensions/home-scenes-dock-widget
zsh extensions/home-scenes-dock-widget/build.sh
swift run --package-path sdk/swift vehla-swift validate \
  extensions/home-scenes-dock-widget/dist/HomeScenes
```

In Vehla, choose **Settings → Store → Install Local Package** and select `dist/HomeScenes`.

The popup uses the host palette for text, a clear background, and the same white controls as Research. Compact and inline text follow the Dock tile color.

## Signing

Release archives are signed with the existing `release-2026-09` publisher key in the login keychain (`com.0xdarkkernel.vehla.publisher`). The script reads that key only to sign, and it will not create a replacement key.

```sh
swift extensions/home-scenes-dock-widget/scripts/sign-release.swift \
  packages/home-scenes-dock-widget-1.0.0.zip \
  extensions/home-scenes-dock-widget/releases/home-scenes-dock-widget-1.0.0.signature.json
```
