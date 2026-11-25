> **AI agents:** follow every rule and architectural constraint in [`AGENTS.md`](AGENTS.md) before making changes.

# Contributing to Folio

Thank you for your interest in contributing to **Folio**, an offline, read-only document viewer for Android.

## Reporting bugs

When opening a GitHub issue, please include:

1. **Steps to reproduce** the issue clearly.
2. **Document format and extension** (e.g., `.pdf`, `.docx`, `.xlsx`, `.pptx`) and approximate file size if relevant.
3. **Android version** and device architecture (`arm64-v8a`, etc.).
4. **Expected vs. actual behavior**, including any error message shown by Folio.

## Proposing changes (Pull Requests)

1. **Fork and branch from `dev`**:
   - Create your feature or fix branch from `dev` (do not target `main`, which only receives verified release merges).
   - Keep each pull request focused on a single task or fix.
2. **Respect core scope**:
   - **Read-only**: Folio only displays documents; do not add editing features.
   - **100% offline**: never add network requests, telemetry, remote CDNs, or new dependencies requiring internet access at runtime.
   - **No new Android permissions** unless strictly necessary and discussed beforehand.
3. **Design & code conventions**:
   - Follow the design system in [`docs/diseno.md`](docs/diseno.md): use `context.folio.*`, `DocKind.color/tint`, or `ColorScheme` for colors; `FolioTokens` for spacing/radii; `Theme.of(context).textTheme` for typography; and `lucide_icons_flutter` (`LucideIcons.*`) for icons.
   - Write comments, user-facing strings, and commit messages in **Spanish**, matching the rest of the codebase.
   - Add unit tests in `test/` (mirroring `lib/`) for new logic and widget tests for significant UI components.
4. **Verify before opening a PR**:
   ```bash
   ./run.sh analyze
   ./run.sh test
   ```
5. **Open a Pull Request against `dev`** describing what changed and how it was tested.
