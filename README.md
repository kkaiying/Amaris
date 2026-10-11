# Amaris

Amaris is a macOS reading tracker built around desktop widgets. It keeps a record of every book read, shows a calendar in which each day carries the cover of the book being read at the time, and rotates through a personal collection of favourite quotes. The app takes its name from Amaris, a character in *Alchemised*.

The project began as a personal tool. Goodreads works well for logging books but presents reading history as lists and numbers. Amaris uses the same data to give a more visual picture of a year of reading, placed where it is seen every day: on the desktop.

## Features

### The app

The **Library** lists every book that has been read, is in progress, or was not finished (DNF), grouped by year. Each book has its cover, a rating that supports quarter stars, and start and finish dates that can be edited.

The **Calendar** shows a full year. A book's cover fills every day from its start date to its finish date, or up to today if it is still being read. When two books overlap, both covers appear on the shared days. A book can be put on hold, and the days it spends on hold are left empty.

The **Quotes** section holds saved passages from books. Several quotes can be pasted at once and are separated automatically at blank lines. Quotes can be marked as favourites, edited, merged (for a passage that was split by mistake) or deleted.

Amaris stays in step with **Goodreads** without any extra effort. Books continue to be logged on Goodreads as usual, and Amaris syncs every hour and whenever the Mac wakes, starting, finishing or marking books as DNF to match. Goodreads has no paused status, so a book added to a custom `on-hold` shelf is treated as on hold. The app opens at login without a window and runs from the menu bar, so syncing continues while it is out of the way.

### The widgets

Four desktop widgets are available:

| Widget | Size | Shows |
| --- | --- | --- |
| Reading Calendar | Large | The current month, with a cover on each reading day |
| Quote | Medium | A saved quote that changes every hour, with a button for the next one |
| Reading Now | Small | The book currently being read and how many days it has been in progress |
| Year | Small | The number of books finished this year |

The quote widget can show all quotes or favourites only, and can display a faint background image chosen in the app's settings.

Each widget can be set to one of the two visual themes designed so far. **Once Upon a Broken Heart** is pink and playful, with washi tape on tilted covers, a gingham header and small hand-drawn details. **Alchemy** is dark, with gold linework, alchemical circle motifs, serif lettering and Roman numerals.

## Technical overview

Amaris is written in Swift (about 5,000 lines) using SwiftUI, SwiftData, WidgetKit and App Intents, with AppKit and ServiceManagement for the menu bar and login behaviour. Testing uses Swift Testing.

The project has two parts: the macOS app and a widget extension. Both read the same SwiftData database and cover-image cache, which live in a shared App Group container. Code needed by both, such as the data models, calendar logic, theming and widget data, sits in a shared folder that is compiled into each target. Widgets cannot make network requests while they are drawn, so the app downloads and resizes covers in advance and the widgets read them from disk.

The data model has three types. A `Book` holds the details of a title, a `Reading` records a single attempt at it (start and finish dates, whether it was finished or abandoned, and whether the dates were estimated or edited by hand), and a `Quote` belongs to a book. The model is kept compatible with iCloud sync, which would allow an iPhone version later.

There are 46 unit tests covering parsing, history reconstruction, sync behaviour, calendar calculations, quote rotation, and regressions for bugs found during development.

## Design notes

### Working without a Goodreads API

Goodreads closed its public API in 2020, so Amaris draws on three other sources. The CSV export supplies past reading history, including finish dates, ratings and reviews. A saved copy of the Goodreads shelf page supplies the real start dates, which the export leaves out. Finally, the public RSS feeds are used for ongoing sync and for cover images that match the edition on the shelf.

In practice, the feeds for individual shelves lagged behind Goodreads by several hours, so a book that had just been finished did not appear. The feed covering all shelves is current, so Amaris reads that one and works out each book's shelf itself.

### Reconstructing reading history

Older books often have a finish date but no start date. For these, the start is estimated as the finish date of the previous book, limited to 30 days before the book's own finish. Every estimate is flagged, and a real date always replaces it, whether it comes from the shelf-page import or from an edit in the app.

### Extracting quotes from reviews

Reviews on this account begin with favourite quotes in italics. A parser extracts them from the review HTML, handling inconsistent tag nesting, line-break separators and HTML entities. This provided the first 32 quotes in the library.

### Keeping manual edits safe during sync

Hourly sync could easily overwrite changes made in the app. Two rules prevent this. Any date edited by hand is flagged and never changed by sync again. A book's status changes only when it moves to a different Goodreads shelf, so marking a book as DNF in the app is not reversed by the next sync. The on-hold shelf follows the same rule: a book is paused or resumed only when it is added to or removed from that shelf.

### Covers

Covers come from Goodreads first, then from Open Library as a fallback, and can be replaced by hand by dragging in an image. Images are resized so the widgets stay light. During development, a percent-encoded file path (`Group%20Containers`) made every cover appear missing, so the two sources kept replacing each other's images. The fix is covered by a regression test.

### Dates and time zones

Goodreads stores the date a book was read as midnight UTC, which can fall on the previous day in local time. Amaris converts it to a plain calendar date, so a book finished on the 3rd always appears on the 3rd.

### Widgets

Both themes are built from a shared theme layer of colour palettes, bundled open-licence fonts, and decorative shapes drawn in SwiftUI. Quotes rotate in a shuffled but fixed order, so the sequence stays the same across widget reloads, and the next-quote button moves it forward. The calendar refreshes at midnight and the quote widget every hour.

## Status

Amaris is in daily use on macOS. Planned additions include an iPhone version with iCloud sync, a digital bookshelf with spines generated from cover colours and page counts, and daily reading progress taken from the Kindle app.

`SPEC.md` contains the original design specification.
