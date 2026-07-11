# Email templates

Standalone, hand-sent HTML emails — **not** wired to ActionMailer. Author an
announcement, then send it from your mail client on your own schedule. Styled to
match the game: dark-green card, chartreuse/gold accents, hex-spectrum divider,
gold uppercase labels from the in-game scoring row.

## `announcement.html`

A reusable announcement layout. The committed sample content dogfoods the
timed-games launch — replace it per send.

**To reuse:** edit only the regions marked `<!-- EDIT: ... -->`:
- preheader (inbox preview line)
- headline + dek
- body copy
- the three labelled "what's new" items
- the CTA `href` (two places: the `<!--[if mso]>` VML button and the normal `<a>`)

**Sending from Thunderbird:** compose a new message in HTML mode, then
**Insert → HTML…**, paste this whole file, and Insert (don't paste into the
visual body — that escapes the tags). Put every recipient in **BCC** so players
don't see each other's addresses. The footer's Unsubscribe is a `mailto:` that
drafts you an opt-out email to action by hand (there's no managed opt-out list
for hand-sent mail).

## Notes

- Email-safe by construction: table layout, inline styles, Outlook VML button,
  web-safe font stack (inboxes can't load Atkinson Hyperlegible, so it degrades
  to Segoe/Arial — the identity rides on color + layout).
- Deliberately single-theme (the KBC dark-green world); an email renders as one
  fixed design in every inbox.
- Preview it in a browser, or send yourself a test before a broadcast.
