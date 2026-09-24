# Updating Disk Clean AI — release & update guide

How a new version gets from your Mac to every user. There is no update server: the
app reads the newest release on GitHub (`postmcp/diskcleanai`) and installs its zip.

## 1. How updates flow

```
 You                                   GitHub (postmcp/diskcleanai)            User's Mac
 ──────────────────────────────────    ──────────────────────────────────────  ─────────────────────────────────
 bump version + build number
 scripts/build-release.sh               release v1.2.0                          app checks once a day
   (archive, sign, notarize, zip) ───▶    └ DiskCleanAI.zip        ───────────▶ GET api.github.com/repos/postmcp/
 gh release create v1.2.0 …               (GitHub computes its sha256)              diskcleanai/releases/latest
                                                                                tag v1.2.0 > running 1.1.0 → offer it
                                                                                downloads zip → verifies sha256
                                                                                unpacks → checks bundle id + version
                                                                                swaps the app → relaunches
```

| What | Where it lives | Who reads it |
| --- | --- | --- |
| **The app (zip)** | An asset named `DiskCleanAI.zip` on a GitHub release of `postmcp/diskcleanai` | The in-app updater, and the website's Download button, which downloads it directly from `github.com/postmcp/diskcleanai/releases/latest/download/DiskCleanAI.zip` |
| **"Is there an update?"** | GitHub's `releases/latest` API — the newest published release that is not a draft or pre-release | The app |

The app decides "is there an update?" by comparing the **release tag** (`v1.2.0`) with its own
**`MARKETING_VERSION`** (`CFBundleShortVersionString`), numerically: `1.10.0` beats `1.9.3`.
The repository must be **public** — assets on a private repo need a login and the updater cannot fetch them.

## 2. One-time setup

1. **Apple Developer Program** membership — done. Team **Shiva Kumar**, Team ID **`4P833G76XL`**.
2. **Developer ID Application certificate** — created 11 Sep 2026 (G2 sub-CA, expires 12 Sep 2031) and
   installed in the login keychain of the maintainer's release Mac. Check with `security find-identity -v -p codesigning`.
   **Back it up**: Keychain Access → My Certificates → right-click *Developer ID Application: Shiva Kumar*
   → Export → `.p12` with a password, stored somewhere safe. Apple cannot re-issue the private key; a new
   Mac or CI machine needs this file.
3. **Notarization credentials** (an app-specific password from appleid.apple.com → Sign-In and Security):
   ```bash
   xcrun notarytool store-credentials diskcleanai --apple-id <your Apple ID email> --team-id 4P833G76XL
   ```
4. **GitHub CLI** logged in with push access to `postmcp/diskcleanai`: `brew install gh && gh auth login`.

## 3. Shipping a new version (every time)

```bash
# 0. make sure you are on a clean, tested tree
cd macApp && xcodebuild -project DiskCleanAI.xcodeproj -scheme DiskCleanAI test
```

**a) Bump the version.** In Xcode select the project → target *DiskCleanAI* → General:

| Field | Xcode name | Rule |
| --- | --- | --- |
| `MARKETING_VERSION` | Version | Semver, e.g. `1.2.0`. **Must be higher than the last release and match the tag** — this is what the updater compares |
| `CURRENT_PROJECT_VERSION` | Build | Integer, +1 every release (macOS and notarization expect it to grow) |

Or from the terminal (edits both Debug and Release):
```bash
sed -i '' -e 's/MARKETING_VERSION = .*;/MARKETING_VERSION = 1.2.0;/' \
          -e 's/CURRENT_PROJECT_VERSION = .*;/CURRENT_PROJECT_VERSION = 3;/' DiskCleanAI.xcodeproj/project.pbxproj
```

**b) Write release notes** in a `notes.md`. They become the GitHub release body and are shown in
the app's update sheet (bold, italics, links and code render; line breaks are kept). Two to six
bullet points is the sweet spot.

**c) Build, sign, notarize, zip:**
```bash
./scripts/build-release.sh          # TEAM_ID defaults to 4P833G76XL, NOTARY_PROFILE to diskcleanai
```
Produces `build/DiskCleanAI.zip`, prints its version, sha256 and size, and prints the exact
`gh release create` command for the next step. Notarization takes a few minutes; the script
waits and staples the ticket.

> Signing with the Developer ID identity was verified directly with `codesign` on 11 Sep 2026. The
> `xcodebuild archive` / `-exportArchive` flow in the script has not been run end to end yet; if the
> first run complains about provisioning, `-allowProvisioningUpdates` usually resolves it, otherwise
> sign in to the Apple ID in Xcode → Settings → Accounts once.

**d) Publish the GitHub release:**
```bash
gh release create v1.2.0 build/DiskCleanAI.zip --repo postmcp/diskcleanai \
  --title "Disk Clean AI 1.2.0" --notes-file notes.md
```
The tag must be `v` + `MARKETING_VERSION`. Attach exactly one zip and keep it named
**`DiskCleanAI.zip`**: the website's Download button is a permanent link to
`releases/latest/download/DiskCleanAI.zip`, which GitHub serves from whichever release is latest.
The version lives in the tag, not the file name. (A `.dmg` alongside it is fine; the updater ignores it.)
The moment this returns, the website's Download button points at 1.2.0 and every running copy
offers it within 24 hours.

**e) Verify:**
```bash
gh release view --repo postmcp/diskcleanai                         # the new release is "Latest"
curl -s https://api.github.com/repos/postmcp/diskcleanai/releases/latest \
  | grep -E '"tag_name"|"browser_download_url"|"digest"'            # tag, zip URL, sha256:…
curl -sIL -o /dev/null -w '%{http_code}\n' https://github.com/postmcp/diskcleanai/releases/latest/download/DiskCleanAI.zip   # 200
```
Then, on a Mac still running the old version: **Disk Clean AI → Check for Updates…** → Download & Install.

### Release checklist

- [ ] Tests pass
- [ ] `MARKETING_VERSION` raised, `CURRENT_PROJECT_VERSION` incremented
- [ ] `notes.md` written
- [ ] `build-release.sh` finished with "Notarizing… Accepted" and a stapled app
- [ ] `gh release create v<version>` with `DiskCleanAI.zip` attached, not marked pre-release
- [ ] The website's Download link returns 200
- [ ] `releases/latest` API shows the new tag
- [ ] Old version updated itself successfully on one machine

## 4. What the app does with a release

Code: [`macApp/DiskCleanAI/Services/UpdateChecker.swift`](macApp/DiskCleanAI/Services/UpdateChecker.swift).

- **When it checks**: on launch if the last check was more than 24 h ago and *Settings → Updates →
  "Check for updates automatically"* is on; any time from **Disk Clean AI → Check for Updates…**,
  Settings → Updates, or Settings → About.
- **What it sends**: one unauthenticated `GET https://api.github.com/repos/postmcp/diskcleanai/releases/latest`
  with a `DiskCleanAI/1.1.0 (2) macOS` user agent. No device id, nothing else. GitHub allows 60
  unauthenticated API requests per hour per IP; a daily check never comes close, and if it is ever
  hit the app says so and tries again later.
- **Which release**: GitHub's "latest" — the newest published release that is not a draft or
  pre-release. Tags that are not a version number (e.g. `nightly`) are ignored. The first zip whose
  name starts with `DiskCleanAI` is used (otherwise the first zip). A release with no zip still shows
  up, with an **Open Release Page** button instead of Download & Install.
- **Skip This Version** remembers the version (`updates.skippedVersion`) and stays quiet until a
  newer one appears. A manual check ignores the skip.
- **Download & Install**: downloads to `~/Library/Caches/ai.diskclean.app/updates/`, verifies the
  sha256 GitHub publishes for the asset (`digest`; a mismatch aborts and deletes the file), unpacks with
  `ditto`, confirms the bundle id is `ai.diskclean.app`, that its `CFBundleShortVersionString` matches
  the tag and that this Mac meets its `LSMinimumSystemVersion`, moves the running app aside, moves the
  new one into place, deletes the old copy and relaunches via `open -n`.
- **Where the app must live**: anywhere the user can write — `/Applications` for a normal drag-install
  works. If the folder is read-only, or the app is running from Xcode's DerivedData, it *does not*
  swap; it reveals the downloaded app in Finder with a message so the user can drag it in.

## 5. Pre-releases, drafts and rollback

- **Draft**: `gh release create … --draft` — invisible to the app and the website until you publish
  it (`gh release edit v1.2.0 --draft=false`).
- **Beta**: `gh release create … --prerelease` — GitHub's `latest` skips pre-releases, so the app
  never offers it. Testers download it from the releases page.
- **Test the updater before launch**: point one Mac at a test repository with
  `defaults write ai.diskclean.app updates.repo yourname/diskcleanai-test`, publish releases there,
  and `defaults delete ai.diskclean.app updates.repo` when done.
- **Pull a bad release**: mark it pre-release (`gh release edit v1.2.0 --prerelease`) or delete it
  (`gh release delete v1.2.0 --repo postmcp/diskcleanai`). "Latest" falls back to the previous release,
  so Macs that have not installed it stop seeing it. Macs that already installed it **do not downgrade**
  — the app only ever moves forward — so fix the bug and ship 1.2.1.
- **Replace a zip under the same tag**: avoid it; users mid-download would get a checksum mismatch.
  Ship a new version instead.

## 6. Updating the website

`landing/` is a static Next.js site. Deploy on Vercel/Netlify with
`NEXT_PUBLIC_SITE_URL=https://diskcleanai.com`. The Download button links to
`github.com/postmcp/diskcleanai/releases/latest/download/DiskCleanAI.zip`, so a site deploy never
needs to know the current version: publish the GitHub release and the button downloads it.

## 7. Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| App says "You're up to date" but you just published | Its `MARKETING_VERSION` ≥ the tag, or the release is a draft/pre-release. Check `curl …/releases/latest`. Or the user clicked *Skip This Version* — a manual check ignores skips. |
| "You're up to date" before the first launch release | `releases/latest` returns 404 while the repo has no published release; the app treats that as up to date. |
| "GitHub is limiting update checks from this network" | 60 requests/hour per IP exhausted (shared office NAT, lots of manual checks). Wait an hour. |
| "The download was corrupted (checksum mismatch)" | The asset changed during the download, or the network mangled it. Try again; don't replace assets on a published release. |
| "The downloaded app is version X, but the release is tagged vY" | You zipped a different build than the tag says. Rebuild, or fix the tag. |
| Update sheet shows **Open Release Page** instead of Download & Install | No `.zip` asset on the release. Upload one: `gh release upload v1.2.0 build/DiskCleanAI.zip`. |
| "Disk Clean AI could not replace itself here…" and Finder opens | App folder is not writable or the app runs from DerivedData. Drag the revealed app to /Applications. |
| Gatekeeper "cannot be opened" after update | Build was not notarized/stapled (`SKIP_NOTARIZE`). Rebuild with notarization. |
| Old app stays open after "Installed. Relaunching…" | Should not happen (there is an `exit(0)` fallback). If it does, quit it; the new copy is already in place. |
| Testing locally | Use a test repo (see §5), build with a lower `MARKETING_VERSION` than its latest tag, and reset the daily timer with `defaults delete ai.diskclean.app updates.lastCheck`. |
| Two copies react to `diskcleanai://` links | An Xcode/DerivedData build shares the bundle id. Quit it. |

## 8. Quick reference

| Thing | Value |
| --- | --- |
| Bundle id | `ai.diskclean.app` |
| Release repo | `postmcp/diskcleanai` (`AppConfig.githubRepo`) |
| Feed the app reads | `https://api.github.com/repos/postmcp/diskcleanai/releases/latest` |
| Point a Mac at another repo | `defaults write ai.diskclean.app updates.repo owner/name` / `defaults delete …` |
| Reset the daily check | `defaults delete ai.diskclean.app updates.lastCheck` |
| Forget a skipped version | `defaults delete ai.diskclean.app updates.skippedVersion` |
| Update cache | `~/Library/Caches/ai.diskclean.app/updates/` |
| Build & notarize | `cd macApp && ./scripts/build-release.sh` |
| Publish | `gh release create v<version> build/DiskCleanAI.zip --repo postmcp/diskcleanai --notes-file notes.md` |
| Website download link | `https://github.com/postmcp/diskcleanai/releases/latest/download/DiskCleanAI.zip` (404 until the first release) |
| Pull a release | `gh release edit v<version> --prerelease` or `gh release delete v<version>` |
| Team ID / identity | `4P833G76XL` · `Developer ID Application: Shiva Kumar (4P833G76XL)` |
| Forks | Set `TEAM_ID` to your own team and publish to your own repo with `REPO=owner/name`; point `AppConfig.githubRepo` at it too |
