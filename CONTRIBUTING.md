# Contributing to Disk Clean AI

Thanks for helping! Bug reports, fixes, new cleanup finders, themes, translations of the
website copy and documentation are all welcome. By taking part you agree to follow the
[code of conduct](CODE_OF_CONDUCT.md).

## Before you start

- **Bugs**: search [existing issues](https://github.com/postmcp/diskcleanai/issues) first, then
  open one with the bug template. Include your macOS version and the app version (Disk Clean AI → About).
- **Features**: open an issue to discuss the idea before writing a large change, so nobody's
  time is wasted on something that doesn't fit.
- **Security problems**: never in a public issue, see [SECURITY.md](SECURITY.md).

## Repository layout

| Folder | What it is |
| --- | --- |
| `macApp/` | The SwiftUI app. Architecture notes are in [`macApp/README.md`](macApp/README.md) |
| `landing/` | The Next.js website at diskcleanai.com. See [`landing/README.md`](landing/README.md) |
| `UPDATING.md` | How maintainers build, notarize and publish a release |

## Working on the app

Requirements: macOS 14 or later and Xcode 16 or later. No Apple Developer account is needed: the
project signs ad-hoc, so it builds and runs from a fresh clone.

```bash
git clone https://github.com/postmcp/diskcleanai.git
cd diskcleanai/macApp
open DiskCleanAI.xcodeproj            # run the DiskCleanAI scheme
xcodebuild -project DiskCleanAI.xcodeproj -scheme DiskCleanAI test   # unit tests (Swift Testing)
```

- Grant the Debug build **Full Disk Access** (System Settings → Privacy & Security) to scan everything.
- The AI Advisor needs your own [OpenRouter](https://openrouter.ai) key; everything else works without one.
- Xcode builds share the bundle id `ai.diskclean.app` with the release app. Quit the installed copy
  while you debug.
- The project uses file-system-synchronised groups: a new `.swift` file in a folder is part of the
  target automatically, with no project-file edits needed.

### Ground rules for app changes

1. **Nothing is deleted outright.** Every removal goes through `TrashService` into the Trash, after
   the user approves it in Review & Clean, and the batch can be undone. Keep it that way.
2. **Respect `SafetyPolicy`.** New finders must build `CleanupItem`s (which assess safety
   themselves) and must never bypass the protected list. If you change the policy, add tests.
3. **Privacy.** File contents never leave the Mac. Anything new sent to the AI model must be
   metadata, visible under "Show what was sent", and documented in `macApp/README.md` and the
   website's privacy page.
4. **Match the surrounding code**: SwiftUI + Observation, the `Theme` environment for colours,
   the shared components in `Views/Components`. No third-party dependencies without discussion.
5. **Add or update tests** in `DiskCleanAITests` for logic changes (parsers, policies, layout maths).

## Working on the website

```bash
cd landing
npm install
npm run dev      # http://localhost:3000
npm run lint
npm run build    # also type-checks
```

Blog posts live in `landing/content/blog/` with their metadata in `landing/lib/blog.ts`.

## Pull requests

- Branch from `main` and keep each pull request to one topic.
- Describe what changed and why, and add screenshots or a short recording for UI changes.
- Make sure `xcodebuild … test` (app) and `npm run lint && npm run build` (website) pass. CI runs
  both on every pull request.
- Write commit messages in the imperative ("Fix duplicate grouping for hard links").
- By submitting a pull request you agree that your contribution is licensed under the
  [MIT license](LICENSE).

Releases are cut by maintainers; see [UPDATING.md](UPDATING.md).
