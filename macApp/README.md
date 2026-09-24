# Disk Clean AI — macOS app

Native SwiftUI storage analyser for macOS 14+. Free and open source under the MIT license. Scans a volume or folder on the Mac, draws an interactive sunburst of what is using space, finds large files, byte-identical duplicates, near-identical photos, unused apps with their leftovers and stale downloads, and (optionally) asks a model on OpenRouter — with the user's own key — what is safe to remove. Nothing is deleted without approval; approved items go to the Trash and the batch can be undone.

## Build

Open `DiskCleanAI.xcodeproj` in Xcode 16 or later and run the `DiskCleanAI` scheme, or from the terminal:

```bash
xcodebuild -project DiskCleanAI.xcodeproj -scheme DiskCleanAI -configuration Debug build
```

Run the unit tests with:

```bash
xcodebuild -project DiskCleanAI.xcodeproj -scheme DiskCleanAI test
```

The project is signed to run locally (ad-hoc), so no Apple Developer account is needed to build or test it. Set your team in Signing & Capabilities before distributing. See [`../CONTRIBUTING.md`](../CONTRIBUTING.md) for the contribution guidelines.

Updates come from the GitHub releases of `postmcp/diskcleanai` (`AppConfig.githubRepo`). To test the updater against another repository, run `defaults write ai.diskclean.app updates.repo owner/name`.

## Layout

```
DiskCleanAI/
  App/        entry point, menu commands, AppState (single source of truth), preference keys
  Theme/      Theme model, ten built-in themes, ThemeManager, button/card styles
  Models/     FileNode tree, categories, scan snapshot, cleanup queue items, AI suggestions
  Services/   DiskScanner, DuplicateFinder, SimilarPhotoFinder, AppInventory, TrashService,
              KeychainStore, OpenRouterClient, AIAdvisor, SafetyPolicy, formatters, UpdateChecker, AppConfig
  Views/      one folder per screen plus shared components; Views/Explore holds the nine patterns;
              Views/Updates holds the update sheet and Settings → Updates
  Resources/  asset catalog (app icon, mascot)
DiskCleanAITests/   Swift Testing suites for classification, tree maths, sunburst layout,
                    safety policy, perceptual hashing, AI response parsing
```

The project uses Xcode's file-system-synchronised groups, so adding a file to a folder adds it to the target.

## Explore patterns

The Explore screen draws the same scan in nine interchangeable patterns, switched from the bar above the chart:

| Pattern | What it shows |
| --- | --- |
| Folders | Grid of folder cards sized by bytes, with item counts and category dots |
| Sunburst | Rings radiating from the focused folder; the depth slider sets ring count |
| Treemap | Squarified rectangles, one level nested inside each folder |
| Bubbles | Circle packing, one bubble per folder with children packed inside |
| Mind Map | Radial tree from the focused folder, branch thickness by size |
| Icicle | Horizontal partition layers from the root down |
| Top Sizes | Ranked bars: in this folder, biggest files anywhere, biggest folders anywhere, or a sidebar quick win |
| Age Map | Age buckets, a bytes-by-modified-month heat grid, and big untouched files |
| List | Outline table with sizes, share, item counts and dates |

Graphical patterns can be coloured **by type** (dominant file category), **by folder** (one hue per top-level child) or **by age** (last modified). Single-click selects an item for the inspector; double-click drills in; the breadcrumb, the centre of the sunburst, or ⌘↑ go back up. The inspector shows size on disk, logical size, compression savings, file and folder counts, share of parent, dates, the largest items inside, and Reveal / Quick Look / Focus / Copy Path / Add to Cleanup.

The sidebar has six destinations — Explore, Find (Large Files · Duplicates · Downloads · Similar Photos as tabs), Apps, AI Advisor, Review & Clean, System Tools — plus a collapsible **Quick wins** list (Downloads, caches and logs, iOS simulators, large media, node_modules, build artefacts, DerivedData, Trash). Clicking a quick win opens it in Explore's Top Sizes pattern with a one-click "stage for cleanup" button.

## Themes

Ocean (default), Match System, Daylight, Midnight, Graphite, Nord, Solar, Dusk, Forest and Sakura. Pick one from **View → Theme**, the palette button in the toolbar, or **Settings → Appearance**. A theme is a `Theme` value (ground, surface, card, line, ink, body, muted, brand, eight chart colours, semantic colours) read from the SwiftUI environment; add another by appending to `Theme.all` and `ThemeID`.

## Window

The app runs as a standard resizable window. The green traffic-light button zooms to fill the screen rather than entering macOS full screen, so close, minimise and zoom are always visible. To allow full screen again, drop `.fullScreenNone` from `WindowConfigurator` in `App/DiskCleanAIApp.swift`.

## Updates

* `UpdateChecker` reads GitHub's `releases/latest` for `postmcp/diskcleanai` once a day (toggle in **Settings → Updates**). If the tag (`v1.2.0`) is newer than `MARKETING_VERSION` it downloads the release's `DiskCleanAI.zip`, verifies it against the sha256 GitHub publishes for the asset, confirms the bundle id and version, swaps the running bundle and relaunches. If the app is somewhere it cannot write it reveals the download in Finder instead. Drafts and pre-releases are never offered.
* Raise `MARKETING_VERSION` for every release and tag it `v<version>` — the updater compares the tag with that, numerically. `scripts/build-release.sh` archives, signs, notarizes and zips a release and prints the `gh release create` command; the end-to-end process is in [`../UPDATING.md`](../UPDATING.md).
* Builds from the paid era (before the app went open source) left a license key, trial and license tokens and a device id in the Keychain; `KeychainStore.removeLegacyLicensing()` deletes them on launch.

## Privacy and safety

* Scans, duplicates, photo comparison and the app inventory run entirely on the Mac.
* The AI Advisor sends paths, names, sizes, kinds and dates for the items shown on its screen — never file contents. "Show what was sent" reveals the exact payload.
* The OpenRouter key is stored in the macOS Keychain.
* The only other request is the daily update check to GitHub's public releases API. Disk Clean AI has no server of its own: no accounts, no device id, no telemetry.
* `SafetyPolicy` marks system paths, app-bundle internals, keychains, SSH/GPG keys, Mail, Messages and Photos as protected; they cannot be queued. `~/Library/Preferences` and `~/Library/Cookies` themselves are protected, but an app's own plist or cookie file inside them can be removed with the app. Library paths are flagged for a second look.
* Removals use `FileManager.trashItem`; the last batch can be restored from the Clean menu or the toast.
* Full Disk Access is optional but recommended; the app detects it and links to System Settings.

## Menu bar and System Tools

The app also lives in the macOS menu bar (Settings → General → Menu bar turns it off, or shows free space next to the icon). The popover and the **System Tools** screen (⌘T) share one `SystemMonitor`, which samples only while one of them is open:

- **Listening ports** from `lsof`: process, PID, protocol and whether it is bound to localhost or all interfaces. Kill a row, or type a port and press Kill Port: SIGTERM first, SIGKILL if it is still alive after 1.5 s. Right-click for graceful quit, force kill, kill as administrator (macOS password prompt), open in browser or copy the URL / PID. Without root, `lsof` only sees the current user's processes.
- **Disk, memory, CPU, swap and local IP** at a glance, plus the heaviest processes by memory or CPU with Quit / Force Quit.
- **Quick fixes**: keep awake (display and system), flush DNS and free inactive memory (both ask for an admin password), restart Finder or the Dock, show or hide dotfiles in Finder, clear the clipboard, sleep the display, open Activity Monitor, copy the local IP.
