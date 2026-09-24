# Security policy

Disk Clean AI moves files to the Trash, can quit processes, and runs a few maintenance
commands with administrator rights when you ask it to, so we take security reports seriously.

## Reporting a vulnerability

Please **do not open a public issue** for a security problem. Instead, either:

- use GitHub's private reporting: **[Report a vulnerability](https://github.com/postmcp/diskcleanai/security/advisories/new)**, or
- email **hello@diskcleanai.com** with "Security" in the subject.

Include the version (Disk Clean AI → About), your macOS version, and steps to reproduce. We aim
to reply within 3 working days and to ship a fix in a new release as soon as it is verified.
We are happy to credit you in the release notes.

## Supported versions

Only the [latest release](https://github.com/postmcp/diskcleanai/releases/latest) receives fixes.
The app updates itself from GitHub releases, so staying current is one click.

## What is in scope

- Anything that could delete, move or expose user data without the user's approval
  (for example a way around `SafetyPolicy` or the Review & Clean step).
- The self-updater (`UpdateChecker`): installing something other than a genuine release.
- Leaking the OpenRouter API key or sending file contents off the Mac.
- The website at diskcleanai.com.
