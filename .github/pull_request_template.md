## What and why

<!-- What does this change, and what problem does it solve? Link the issue: "Fixes #123". -->

## How it was tested

<!-- Steps you took, and screenshots or a recording for UI changes. -->

## Checklist

- [ ] `xcodebuild -project macApp/DiskCleanAI.xcodeproj -scheme DiskCleanAI test` passes (app changes)
- [ ] `npm run lint && npm run build` in `landing/` passes (website changes)
- [ ] Removals still go through `TrashService` and `SafetyPolicy`
- [ ] No file contents or new personal data leave the Mac, or the privacy docs are updated
