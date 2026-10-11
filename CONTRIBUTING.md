# Contributing

CodeCatch is a macOS 15+ Swift package. Swift 6 and the Apple Command Line
Tools are sufficient; Xcode also works. Use the checked-in `Package.resolved`.

```sh
scripts/test.sh --force-resolved-versions
swift build -c release --scratch-path .build-release --force-resolved-versions
```

These commands need no mail accounts, Full Disk Access, Accessibility, signing
certificate or release secrets. Tests use synthetic messages, isolated settings,
in-memory vaults and private pasteboards. CI runs them on Apple silicon and Intel.
Do not use a personal inbox or vault as a test fixture.

## Layout

| Path | What it holds |
|---|---|
| `Sources/`, `Tests/` | The Swift package: the app, `CodeCatchCore` and the `codecatch` CLI, and their tests. See [ARCHITECTURE.md](ARCHITECTURE.md). |
| `Resources/` | `Info.plist` and the app icon, copied into the bundle by `scripts/install.sh` |
| `scripts/` | Build, release, test and site tooling |
| `site/` | The website, codecatch.app |
| `functions/` | Cloudflare Pages Functions for the site: download routing and install counts |

Swift package folders are capitalized as SwiftPM expects; `functions/` is the name Cloudflare
Pages looks for; everything else is lowercase.

Python scripts follow `ruff.toml`. Before committing a script change, run:

```sh
ruff check scripts && ruff format --check scripts
```

## Changes

Keep a change focused on a failure or a concrete simplification. For bugs, first
add a failing case to the closest existing test. Preserve behavioral assertions
when moving code. Tests around sensitive actions should exercise rejection,
cancellation and stale state, not just the successful path.

`Sources/CodeCatchCore` contains parsing and deterministic logic; macOS adapters
and UI live in `Sources/CodeCatch`. See [ARCHITECTURE.md](ARCHITECTURE.md) for the
privacy boundaries. New sources deliver `IncomingMessage` through the existing
ingestion path. Do not create another clipboard, storage or authentication path.
Add a line to `Tests/CodeCatchCoreTests/code-samples.txt` for every new code
format or false positive. `@Local` stands in for `@State`, whose macro plugin
only ships with Xcode.

Never commit inbox exports, real verification links, credentials, signing keys
or screenshots containing personal data. Use `example.com` or `.invalid` for
synthetic addresses. Report exposure bugs through [SECURITY.md](SECURITY.md).

Running the actual app is different from running tests: it can read the current
user's configured sources. Use a separate macOS account and synthetic messages
for permission, lock, sleep/wake and update checks.

## Debug tools

Debug builds have extra tools, such as `--probe` (prints the codes each mail
account would give, masked), `--snapshot <dir>` (renders the UI to PNGs) and
`--import-env`. The full list is in `Sources/CodeCatch/Debug/DebugCommand.swift`. Run them with
`scripts/debug.sh <flag>`; it signs the build like a release, so the Keychain
doesn't ask for your password after every rebuild. Release builds leave these
tools out.

Preview the site with `python3 -m http.server --directory site`.

The site is in English at the top and in other languages under `site/<lang>/`
(`de`, `ja`, `fr`, `it`, `es`, `pt`). Each page names its versions in `<link rel="alternate"
hreflang>` tags and in the footer's language links. `python3 scripts/check-site.py`
checks those, every link within the site and the sitemap; the deploy runs it too.
Changing an English page means changing its translations in the same commit.
To add a language, add its folder name to `LANGUAGES` in `scripts/check-site.py`
and `functions/_middleware.js`.

## Releasing

| Command | Result |
|---|---|
| `scripts/install.sh --build-only` | Tests, then builds a signed universal app in `.build-release/` |
| `scripts/install.sh --release` | Also makes `CodeCatch.dmg`, notarizes it, and writes `site/appcast.xml` |
| `scripts/install.sh --publish` | Also uploads the DMG as a GitHub release, then commits and pushes `site/appcast.xml` |

CI then deploys `site/` to Cloudflare Pages, and installed copies update
themselves from `https://codecatch.app/appcast.xml`.

Release builds remap source paths, strip object-file debug records, and scan the
app for embedded home directories before signing. Run the guard tests with
`python3 scripts/test-release-privacy.py`.

A release needs:

- a Developer ID certificate (`Developer ID Application` in the login keychain;
  set `CODECATCH_IDENTITY` to pick another)
- a `notarytool` Keychain profile named `codecatch` (or set `CODECATCH_NOTARY_PROFILE`)
- Sparkle's EdDSA key in the Keychain
- `uvx`, for `dmgbuild`
- `gh` and push access to `main`, with `main` checked out, pushed and clean

The build number is the commit count plus 100 (`CODECATCH_BUILD_NUMBER`
overrides it). Before a release, test the download on a fresh macOS account: on
Intel, on a Mac without Touch ID, and through Messages, mail and password unlock.
