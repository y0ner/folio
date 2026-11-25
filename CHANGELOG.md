# Changelog

All notable changes to **Folio** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-11-24

### Added

- **Home & file organization**: recent documents grouped by Today / This week / Older, accent- and case-insensitive search, and filter chips by document type (PDF, Word, Excel, PowerPoint).
- **Android file intake & defaults**: open documents via system file picker, Android `"Open with"` / `"Share"` intents, and configure Folio as the default viewer per document type under **Settings → Open documents**.
- **Native PDF viewer** (`pdfrx` / PDFium): pinch and double-tap zoom, text selection, internal links, password-protected PDF support, and in-PDF search with match highlighting and counter.
- **Word viewer** (`docx-preview` 0.4.1): faithful page rendering for `.docx`, `.docm`, and `.dotx` with bundled metric-compatible fonts (Carlito, Caladea, Liberation Sans/Serif).
- **Excel & CSV viewer** (SheetJS CE 0.20.3): support for `.xlsx`, `.xlsm`, `.xls`, and `.csv` with sticky headers, merged cells, sheet tabs, and smooth virtualized scrolling for sheets up to 20,000 rows parsed in a Web Worker.
- **PowerPoint viewer** (`pptx-preview` 1.0.7): full-width slide list with progressive loading for `.pptx`, `.ppsx`, and `.pptm`.
- **Viewer ergonomics & file actions**: immersive mode (single tap toggles bars), floating page indicator, Go to Page dialog, file info sheet with real path and copy-path action, **Save a copy…**, and document sharing.
- **Design & offline privacy**: "ink and paper" Material 3 theme with light, dark, and system modes, bundled Inter font and Lucide icons, 100% offline execution with external URL blocking, and bundled third-party licenses (`THIRD_PARTY_NOTICES.md`).

### Fixed

- Word bullets drawn with Symbol/Wingdings private-use glyphs now render as real bullets (•, ▪, ✓…) instead of empty boxes.
- Word, Excel and PowerPoint no longer hang on "Opening document…" in release builds (missing `INTERNET` permission required by Android WebView).

### Project

- Website: https://folio-visor.vercel.app (source in `website/`).

[1.0.0]: https://github.com/y0ner/folio/releases/tag/v1.0.0
