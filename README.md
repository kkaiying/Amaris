# Amaris

A macOS reading tracker with desktop widgets. It shows a calendar with the cover of whatever I was reading on each day, and rotates through my favourite quotes from books. Named after Amaris from *Alchemised*, my favourite read of 2026.

I built it because I track every book on Goodreads but wanted something more personal and visual on my desktop. Goodreads shows lists and numbers. I wanted to *see* my year of reading.

## What it does

**App**
- **Library:** every book I've read, am reading, or didn't finish (DNF), grouped by year, with covers, ratings (including quarter stars), and editable start and finish dates.
- **Reading calendar:** a full-year view in which each day shows the cover of the book I was reading, from its start date to its finish date. If two books overlap, both covers appear.
- **Quotes:** a library of favourite quotes. I paste several at once and they're split automatically. I can favourite, edit, merge (for a quote that got split in two) and delete them.
- **Goodreads sync:** I keep using Goodreads as normal. Amaris syncs every hour and when the Mac wakes, and starts, finishes or DNFs books to match.
- **Runs in the background:** it opens at login with no window and lives in the menu bar, so syncing continues without the app being open.

**Desktop widgets** (WidgetKit)
- **Reading Calendar** (large): this month, with a cover on every reading day.
- **Quote** (medium): a saved quote that changes every hour, with a *next* button that works directly on the widget. It can show all quotes or favourites only, with optional faint fan art behind it.
- **Reading Now** (small): the current book and how many days I've been reading it.
- **Year** (small): books finished this year.

Each widget can use either of two visual themes I designed:
- **Once Upon a Broken Heart:** pink and whimsical, with washi tape on tilted covers, a gingham header and hand-drawn doodles.
- **Alchemy:** near-black with gold linework, transmutation-circle details, serif type and Roman numerals.

## Technical overview

- **Language and frameworks:** Swift, SwiftUI, SwiftData, WidgetKit, App Intents, AppKit and ServiceManagement. About 5,000 lines of Swift.
- **Architecture:** a macOS app plus a widget extension. They share a SwiftData database and a cover-image cache through an **App Group container**. Code used by both (models, calendar logic, theming, widget data) lives in a shared module. Widgets can't make network requests while drawing, so the app downloads and resizes covers ahead of time and the widgets read them from disk.
- **Data model:** `Book`, `Reading` (one reading session: start and finish dates, outcome, and flags marking whether the dates were estimated or edited by hand), and `Quote`. It is designed to be compatible with iCloud sync for a future iPhone version.
- **Tests:** 41 unit tests using Swift Testing. They cover parsing, the backfill rules, sync behaviour, calendar maths, quote rotation and regressions for bugs I found.

## Interesting problems

**Goodreads has no public API.** Goodreads closed it in 2020, so I combined three unofficial sources:
- the **CSV export** for my reading history (finish dates, ratings, reviews),
- a **saved HTML shelf page**, which I parse for real start dates (the export doesn't include them),
- the public **RSS feeds**, for ongoing sync and for cover images that match the edition I own.

**Rebuilding missing history.** For books with no recorded start date, I estimate one: the start is the previous book's finish date, capped at 30 days. Each estimate is flagged, and a later real date (from the HTML import or from editing in the app) always replaces it.

**Getting quotes from reviews.** My reviews start with favourite quotes in italics. A parser pulls them out of Goodreads' HTML, which uses inconsistent tag nesting, `<br/>` separators and HTML entities. That produced 32 quotes to start the library.

**Sync that never undoes my own edits.** Hourly syncing could easily overwrite changes made in the app. I prevent that in two ways:
- Any date I edit by hand is flagged and never touched again.
- A book's status only changes when it **moves to a different Goodreads shelf**, so marking a book DNF in the app isn't reverted an hour later.

**Feeds that lag behind.** The per-shelf RSS feeds turned out to lag behind Goodreads by hours, so finishing a book didn't show up. The all-books feed is up to date, so sync now reads that and works out each book's shelf itself.

**Covers.** Covers come from Goodreads first, with **Open Library** as a fallback and a manual override (drag and drop or a file picker). Images are resized to keep the widgets light. One bug made every book look like it had no cover: the code checked a percent-encoded file path (`Group%20Containers`), so the two cover sources kept overwriting each other. I fixed it and added a regression test.

**Dates and time zones.** Goodreads stores the "date read" as midnight UTC, which can shift to the previous day in local time. I convert it to a calendar day so a book finished on the 3rd stays on the 3rd.

**Widget design and engineering:**
- The two themes are built from a shared theme layer: palettes, bundled open-licence fonts, and decorative shapes drawn in SwiftUI.
- Quote rotation uses a seeded shuffle, so it's stable across widget reloads and the *next* button advances it.
- Timelines are scheduled to refresh at midnight (calendar) or hourly (quotes).

## Status and next steps

I use it daily on my own Mac. Ideas for later:
- an iPhone version with iCloud sync,
- a digital bookshelf with spines generated from cover colours and page counts,
- daily reading progress from the Kindle app's local data.

`SPEC.md` is the original planning document, written before the build.
