# Verification

October 3, 2026. Code revision `86fc1e1` passed [GitHub Actions run 37116032934](https://github.com/DawoodAamir/Studio-Notebook/actions/runs/37116032934).

## Automated checks

- Three core tests passed in Debug and Release: portable page round-trip, invalid/versioned/duplicate document rejection, and real PaperMarkup content plus two-page PDF round-trip.
- The sandboxed Mac Release app and unsigned iPad device Release app built with Swift 6 complete concurrency.
- The native iPad simulator workflow created a notebook, edited its page details, inserted a rectangle, and opened the PDF export save interface. This workflow checks the export interface; it does not save and reopen an iPad file.
- The iPad capture in this folder comes from that passing workflow, with the inspector and keyboard dismissed.

## Native Mac review

The Release app was built locally with ad-hoc signing and tested using an original review notebook. No personal signing team or documents were used.

- Opened the notebook, inspected its title, notes and PaperKit content, and resized the window from a compact layout to a large workspace. The page remained centered and fit the available canvas.
- Inserted an ellipse, used Undo and Redo, then restored the original content with Undo. The canvas remained responsive.
- Exported an editable `.studionotebook` copy through the system save interface and reopened that exact file through File > Open. Its title, notes and canvas content were preserved.
- Saved a PDF through the system save interface. CoreGraphics read the resulting document as one valid 600 × 800 point page; the automated round-trip test separately checks two-page export.
- Inspected the Mac workspace capture in this folder after reopening the exported copy.

## Remaining device checks

Physical Apple Pencil drawing, handwriting recognition across languages, tool picker interactions on a physical iPad, VoiceOver, large text, iCloud/provider conflicts, and crash recovery require further device review. Saving and reopening an exported file was verified on Mac, not on a physical iPad.

The app uses explicit per-document exports. Finder/USB sharing of its entire Documents folder is not enabled.
