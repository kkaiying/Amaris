# Amaris: Design Specification

This document describes the requirements, data sources and data model behind Amaris, a macOS reading tracker with desktop widgets. It was written before development began and has since been updated to match the built app. For an overview of the finished project, see `README.md`.

## 1. Goals

Amaris records when each book was started and finished, shows that history visually, and keeps a library of favourite quotes. Goodreads stays the place where books are logged, and Amaris follows it automatically.

| # | Feature | Priority | Where it appears | Status |
| --- | --- | --- | --- | --- |
| 1 | Reading calendar: a book cover on every day the book was being read | High | App and calendar widget | Built |
| 2 | Start and finish tracking, including marking a book as DNF | High | App; drives the calendar | Built |
| 3 | Quote rotation, with a quick way to add quotes | High | App and quote widget | Built |
| 4 | Daily reading progress | Low | App only | Not started |

### 1.1 Reading calendar

A book's cover appears on every day from its start date to its finish date, inclusive. A book started on the 1st and finished on the 5th therefore appears on the 1st through the 5th. A book still being read fills every day from its start up to today. When two books are read at the same time, both covers are shown on the overlapping days. A book marked as DNF fills the days from its start to the day it was abandoned.

The app shows a full year. The calendar widget shows the current month.

### 1.2 Start and finish tracking

Going forward, start and finish dates come from Goodreads, which is updated whenever a book is started or finished. Books can also be marked as DNF in the app, and the Goodreads `did-not-finish` shelf is imported. Past books are reconstructed from the Goodreads CSV export (Section 3). Re-reads are rare. The data model allows them, but they are not a focus.

### 1.3 Quote rotation

The quote widget shows one quote at a time, with the book's title, author and cover, and changes on a schedule (hourly). A button on the widget moves to the next quote, and the widget can be set to show favourites only.

Adding quotes needs to be quick. The user picks a book (defaulting to the current or most recently finished one) and pastes one or more quotes, separated by blank lines, matching the format already used in Goodreads reviews. Quotes can be edited, deleted or merged afterwards. A merge joins a passage that was split in two by mistake.

Typically about five quotes are kept per book, but only one to three make it into the Goodreads review, so the app stores all of them. Kindle highlights are deliberately not imported in bulk, because many of them are reference notes rather than favourite passages.

### 1.4 Reading progress (deferred)

Progress per day or session would be useful but is not shown on any widget. The only possible source is the local data of the Kindle app for Mac (Section 2.3), which has not been verified, so this feature is deferred.

## 2. Data sources

| Source | Provides | How it is used |
| --- | --- | --- |
| Goodreads CSV export | Title, author, rating, page count, date read, shelf and review for past books | Imported once (can be re-run safely) |
| Goodreads shelf page, saved as HTML | Real start dates for past books | Imported once (can be re-run safely) |
| Goodreads RSS feed (`/review/list_rss/<user-id>?shelf=#ALL#`) | Current shelf, date added, date read and cover image for every book | Read at launch, hourly and on wake |
| Manual entry in the app | Quotes, DNF, corrections to any date, cover overrides | As needed |
| Kindle app for Mac (local database) | Reading position and highlights | Not used; considered for feature 4 |

The RSS feeds require a public Goodreads profile and public shelves.

### 2.1 Goodreads RSS feed

On the currently-reading shelf, `user_date_added` is the date the book was shelved there, which is used as the start date. For read books, `user_read_at` is the finish date, stored as midnight UTC. `book_large_image_url` carries a size suffix such as `._SY475_`, and removing it gives the original image.

Ratings in the feed are rounded to whole stars. They are only used to fill in a missing rating and never overwrite a more precise one entered in the app.

The feeds for individual shelves were found to lag behind Goodreads by several hours. The combined `#ALL#` feed is current, so sync uses it. In that feed, `user_shelves` names the currently-reading, did-not-finish and to-read shelves (alongside any custom shelves) but is left blank for read books. Any book that is not on one of those three shelves is therefore treated as read.

### 2.2 Goodreads CSV export

Quotes appear at the start of a review, wrapped in `<i>…</i>` or `<i><b>…</b></i>`, with the closing tags in either order. Goodreads converts line breaks to `<br/>`, so separate quotes are divided by `<br/><br/>`, and some reviews contain several separate italic blocks. Quotation marks are inconsistent (curly, straight or absent), and the text is kept as written. Reviews without quotes contain no italics.

One limitation remains: a single quote that spans two paragraphs is imported as two quotes. The merge action in the app fixes this.

The export does not include start dates, which is why the saved shelf page is also imported.

### 2.3 Kindle app for Mac (not used)

The Kindle app stores its data under `~/Library/Containers/com.amazon.Lassen/Data/Library/`:

- `Protected/BookData.sqlite`: the library, with current and maximum reading positions (enough to work out percentage progress) and the last access time.
- `Application Support/Whispersync/WSyncDefault.sqlite`: a read or unread state per book, without a timestamp.
- `AnnotationStorage`: highlights and last-page-read entries.

None of these store a history of reading sessions, only the current state, so a history would have to be built by checking repeatedly and recording changes. It is also unclear whether a position reached on a Kindle device reaches the Mac app without opening the book there. The format is undocumented and may change. For these reasons the Kindle data is not used.

## 3. Reconstructing past reading history

1. Only the `read`, `currently-reading` and `did-not-finish` shelves are imported.
2. Read books without a date read are skipped. Older reads without dates are not needed for the calendar.
3. Books are ordered by date read, not by their order in the CSV (which follows the date added).
4. The estimated start date is the finish date of the previous book, limited to 30 days before the book's own finish date. Books finished on the same day share the same estimated start.
5. A book currently being read takes its start date from the Goodreads feed.
6. DNF books have no dates in the export, so they appear in the library but not on the calendar until dates are added.
7. Quotes are extracted from reviews of dated books.
8. Every estimated date is flagged as an estimate. A real start date from the saved shelf page, or an edit in the app, replaces it. Re-running the CSV import never overwrites a date that is no longer an estimate.

## 4. Data model

The data model uses SwiftData and is stored in an App Group container shared by the app and the widget extension. It is kept compatible with iCloud sync: there are no unique constraints, and every property has a default value or is optional.

| Model | Fields | Notes |
| --- | --- | --- |
| `Book` | Goodreads ID, Kindle book ID, ISBN-13, title, author, page count, rating (supports quarter stars), cover file name, cover source, status (`reading`, `read`, `dnf`), last known Goodreads shelf | One per book |
| `Reading` | Book, start date, finish date (empty while reading), outcome (`read` or `dnf`), start-is-estimated flag, dates-edited-by-hand flag, source (`goodreadsCSV`, `goodreadsRSS`, `manual`) | Drives the calendar. A book can have several (re-reads) |
| `Quote` | Book, text, favourite flag, source, created date, last shown date | |

Deleting a book also deletes its readings and quotes.

**Calendar query:** for each day, every reading whose start date falls on or before that day, and whose finish date (or today, if unfinished) falls on or after it.

### 4.1 Sync rules

Feed items are matched to books by Goodreads ID. Sync follows two rules so that it never undoes changes made in the app:

- A reading whose dates were edited by hand is never changed by sync.
- A book's status changes, and a reading is started or ended, only when the book moves to a different Goodreads shelf than the one last seen. Marking a book as DNF in the app is therefore not reversed by the next sync.

## 5. Covers

Front covers are chosen in this order:

1. The Goodreads feed cover, which matches the edition on the shelf.
2. Open Library, searched by ISBN and then by title and author. This can return translated editions, so it is only a fallback.
3. A cover chosen by hand in the app, which sync never replaces.

Covers are downloaded once, resized to 900 pixels, and stored in the shared container, because widgets cannot fetch images while they are drawn.

Spines for the planned digital bookshelf would have to be generated, since no service provides spine images. The planned approach is to take colours from the cover, set the width from the page count, and set the title and author vertically.

## 6. Architecture

- **App:** Swift and SwiftUI on macOS. Library, quotes, calendar and settings views. Opens at login without a window and runs from the menu bar.
- **Widgets:** WidgetKit widgets for the calendar (large), quotes (medium), the current book (small) and the year's total (small). Each widget can be set to one of two themes, and the next-quote button uses App Intents.
- **Sync:** at launch, hourly, and when the Mac wakes. The widgets are refreshed after every saved change.
- **Shared code:** models, storage, calendar logic, theming and widget data are compiled into both the app and the widget extension.

## 7. Build order

1. Data model in the shared App Group container. (Done)
2. Goodreads CSV import, quote extraction and covers. (Done)
3. App: library, quotes and full-year calendar. (Done)
4. Goodreads RSS sync. (Done)
5. Widgets: calendar, quote, current book and year, in two themes. (Done)
6. Background running: login item and menu bar. (Done)
7. Later: digital bookshelf, iPhone version with iCloud sync, and daily progress.

## 8. Local data files

The `data/` folder holds personal Goodreads data and is excluded from version control.

- `goodreads_export_raw.csv`: an unmodified copy of the Goodreads export.
- `goodreads_clean.csv`: the export reduced to the columns in use, with ISBN-13 cleaned and to-read books removed.
- `quotes_seed.json`: quotes extracted from reviews.
- `goodreads_shelf.html`: the saved shelf page used for start dates.
- `backups/`: copies of the database taken before major changes.
