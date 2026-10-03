# Verification

October 3, 2026. Verification in progress.

- Three core tests pass locally: portable page round-trip, invalid/versioned/duplicate document rejection, and real PaperMarkup content plus two-page PDF round-trip.
- Native iPad Debug simulator builds pass with complete Swift 6 concurrency. Earlier Mac and iPad builds verified the document APIs and canvas bridges.
- Create/edit autosave produced a valid local notebook during development. Hosted Release builds and native creation/edit/export UI verification are pending.

Physical checks remain necessary for Apple Pencil drawing, handwriting recognition in different languages, tool picker behavior, VoiceOver, large text, iCloud/provider conflicts, reopening an exported notebook, and crash recovery. No Finder/USB Documents-folder sharing is enabled.
