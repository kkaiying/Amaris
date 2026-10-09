# Amaris — Spec

A macOS reading tracker app + desktop widgets for tracking what I read and keeping a library of my favourite quotes. Named after Amaris from *Alchemised*.

_Last updated: 2026-10-09_

---

## Features

| # | Feature | Priority | On a widget? |
|---|---|---|---|
| 1 | **Reading calendar**: a book cover on every day I was reading that book | High |  Calendar widget |
| 2 | **Reading progress**: how much I read per day / session | Low | App only (later) |
| 3 | **Quote rotation**: favourite quotes cycle on a widget, plus an easy upload screen | High | Quote widget |
| 4 | **Start / finish tracking**: when I started and finished each book, plus a DNF button | High | Feeds the calendar |

### 1. Reading calendar
- A book's cover appears on **every day from its start date to its finish date (inclusive)**.
  - Example: started on the 1st, finished on the 5th → cover on the 1st, 2nd, 3rd, 4th and 5th.
- A book I'm **currently reading** fills from its start date **through today**.
- If I'm reading **two books at once**, **show both** covers on the overlapping days.
- **DNF books** fill from their start date to the day I marked them DNF.
- One month per view.

### 2. Reading progress (low priority, not built yet)
- Nice-to-have data: progress per day or session. Not shown on any widget.
- Only possible source: the Mac Kindle app's local data (see *Data sources*). Unverified, so it comes later.

### 3. Quote rotation
- The widget shows one quote at a time (text, book title, author) and rotates on a schedule (e.g. hourly).
- A **"next quote" button** on the widget (interactive widgets, macOS 14+).
- **Favourite** flag: the widget can cycle all quotes or only favourites.
- **Upload screen**, which needs to be quick:
  - Pick the book (defaults to the most recently finished or current book).
  - Paste one or **several quotes at once**. A blank line separates quotes (same convention as my reviews).
  - Save. Edit, delete and merge (for a quote that got split in two) are available afterwards.
- I usually pull ~5 quotes per book but only 1–3 make it into my Goodreads review, so **the app stores all of them**.
- **Not** importing all Kindle highlights: many of mine are for lore and aren't favourites.

### 4. Start / finish tracking
- **Going forward:** start and finish dates come from **Goodreads**, which I update every time I start or finish a book.
- **DNF:** a DNF button in the app. Goodreads' `did-not-finish` shelf is also imported.
- **Past books:** rebuilt from the Goodreads CSV export (see *Backfill*).
- Re-reads are unlikely. The database allows them but they aren't a focus.

---

## Data sources

| Source | Gives us | How | Status |
|---|---|---|---|
| **Goodreads CSV export** | Past books: title, author, rating, pages, date read, shelf, review (→ quotes) | One-time import | Done (`data/`) |
| **Goodreads shelf RSS** (`/review/list_rss/<user-id>?shelf=…`) | Finished books + date read, rating, review, **cover image** | Poll ~hourly | Verify with my user ID |
| **Goodreads updates RSS** (`/user/updates_rss/<user-id>`) | "Started reading X" events + timestamps → **start dates** | Poll ~hourly | ⏳ Verify that "started reading" events appear |
| **Manual entry (app)** | Quotes, DNF, corrections to any date | Upload screen / buttons | To build |
| **Mac Kindle app (local DB)** | Progress position, "read" state, highlights | Read-only access to its SQLite files | Optional, only for feature 2 |

The Goodreads RSS feeds only work if my **profile and shelves are public**.

### Goodreads export: what I found
- Quotes are at the **start** of a review, wrapped in `<i>…</i>` or `<i><b>…</b></i>`. The closing-tag order varies (`</b></i>` or `</i></b>`).
- Goodreads converts line breaks to `<br/>`, so several quotes are separated by `<br/><br/>`.
- Some reviews have **several separate `<i>` blocks**, one quote each.
- Quotation marks are inconsistent (curly “ ”, straight " or none). Text is kept as written.
- Reviews without quotes have no italics at all. I checked: none contain quotes in any other format.
- **Known limitation:** a single quote spanning two paragraphs gets split into two quotes. Fix with "merge" in the app.

### Mac Kindle app: what I found (for later)
Data lives in `~/Library/Containers/com.amazon.Lassen/Data/Library/`. **Read-only, and always on a copy.**
- `Protected/BookData.sqlite` → `ZBOOK`: library (144 books), `ZRAWCURRENTPOSITION` / `ZRAWMAXPOSITION` (→ % progress), last access time.
- `Application Support/Whispersync/WSyncDefault.sqlite` → `BookReadStates`: `READ` / `UNREAD` per book. `origin: MANUAL` = my "have read" click. **No timestamp.**
- `AnnotationStorage` → `ZANNOTATION`: 1,412 highlights, plus `lpr` (last page read) entries.
- **No reading history or sessions** are stored, only the current state. History would have to be built by polling and diffing.
- **Open question:** does a position from my Kindle reach the Mac app without opening the book on the Mac? The first test (Project Hail Mary, 2026-10-09) showed no change. Not yet confirmed either way.
- Undocumented, and Amazon may change it. macOS may ask for permission or Full Disk Access.

---

## Backfill rules (past books from the CSV)

1. Import only shelves **`read`**, **`currently-reading`** and **`did-not-finish`**. `to-read` is already removed.
2. **Skip `read` books with no "Date Read"** (131 old reads, not needed). That leaves **71 dated books** (Dec 2023 – Oct 2026).
3. Sort by **Date Read**, not by CSV order (the CSV is ordered by date added).
4. **Estimated start date** = the finish date of the previous book in that order, **capped at 30 days before its own finish date**.
   - Several books finished on the same day → each gets the same previous finish as its start.
5. **Currently reading** (*The Invisible Life of Addie LaRue*): start = the last finished book's date (same 30-day cap), or the real date from the Goodreads updates feed if it's available.
6. **DNF books** (10) have no dates in the export → library only, not on the calendar.
7. Quotes: 32 quotes from 23 books, all from dated books → `data/quotes_seed.json`.
8. Every estimated date can be **edited in the app**.

---

## Database

| Table | Columns | Notes |
|---|---|---|
| **books** | `id`, `goodreads_id`, `kindle_book_id` (nullable), `isbn13`, `title`, `author`, `cover_url` / `cover_path`, `page_count`, `rating` (decimal: Goodreads allows quarter stars, e.g. 3.25, 3.5, 3.75; 0 = unrated), `status` (`reading` / `read` / `dnf`), `spine_color` _(later)_ | One row per book |
| **reads** | `id`, `book_id`, `started_at`, `finished_at` (null while reading), `ended_reason` (`finished` / `dnf`), `start_is_estimated`, `source` (`goodreads_csv` / `goodreads_rss` / `manual`) | **Drives the calendar.** Several per book allowed (re-reads) |
| **quotes** | `id`, `book_id`, `text`, `source` (`goodreads` / `manual`), `is_favourite`, `created_at`, `last_shown_at` | `last_shown_at` keeps rotation fair |
| **progress_log** _(later)_ | `book_id`, `observed_at`, `position`, `max_position` | Feature 2 only. Append-only, rows written on change |

**Calendar query:** for each day of the month, return every `read` where `started_at ≤ day ≤ (finished_at ?? today)`.

**Dedup on sync:** match Goodreads RSS items to `books` by `goodreads_id`. Never overwrite a date I've edited manually.

---

## Covers & spines
- **Front covers**, by priority: Open Library Covers API by ISBN13 (71 of 82 books have one) → Goodreads RSS cover URL → Kindle app cover cache (`Library/Caches/covers`, `HighResCovers`; ~40 books, 953×1440) → manual override in the app.
- Covers are **downloaded once and stored locally** in the shared container. Widgets can't fetch images while rendering.
- **Spines** (for the future digital bookshelf): no API provides spine images, so they're **generated**. Colour = the cover's dominant colours, width ∝ page count, vertical title/author text. Optional manual spine photo per book.

## Build order
1. Database (SwiftData models in the shared App Group container)
2. Import: Goodreads CSV + quotes seed + covers
3. App: library (edit dates, DNF), quotes (browse, favourite, upload), **full-year calendar**
4. Goodreads RSS sync
5. Widgets: current-month calendar, quote (with cover), currently reading
6. Extras: digital bookshelf, daily progress from Kindle

## Tech stack (planned)
- **Swift + SwiftUI** macOS app (it hosts the widgets).
- **WidgetKit** widgets: calendar (large) and quote (small/medium). Interactive buttons via App Intents (macOS 14+).
- **SwiftData or SQLite** for storage, in an **App Group** container so the app and widgets share it.
- **Background sync:** poll the Goodreads RSS feeds every ~hour while the app runs, then refresh the widgets.
- **Covers:** Goodreads RSS cover URLs, with Open Library as a fallback, cached locally.

---

## Open items
- [ ] Send Goodreads profile link → verify both RSS feeds (fields, cover sizes, "started reading" events, review text).
- [ ] Confirm the Goodreads profile/shelves are public.
- [ ] If the updates feed lacks start events: fall back to a "Start reading" button, or to the date a book appears on `currently-reading` in the shelf feed.
- [ ] (Later, feature 2) Re-run the Kindle sync test.
- [ ] Decide widget sizes and the calendar look, e.g. how two covers share one day.

## Files
- `data/goodreads_export_raw.csv`: untouched copy of the Goodreads export (2026-10-04)
- `data/goodreads_clean.csv`: kept columns only (+ ISBN13 for cover lookups, `="…"` wrapper stripped), `to-read` removed (213 rows)
- `data/quotes_seed.json`: 32 extracted quotes
