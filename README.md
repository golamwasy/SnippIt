# SnippIt

A native Mac scratchpad with folders, plain-text notes, search, and a line-numbered editor.

Open `SnippIt.xcodeproj` in Xcode and run the SnippIt scheme. Requires macOS 15.2 or later.

## Storage

Notes and folders are stored on this Mac using SwiftData. Each edit is committed immediately.
Closing the window, quitting the app, and restarting the Mac preserve your notes and the
last selected note. There is no account, server, Docker container, or internet dependency.
SnippIt opens directly into your local library.
Typing updates only the edited note in the database.

The database is `SnippIt/Library.store` inside the app's Application Support directory.
For a sandboxed build this is normally
`~/Library/Containers/com.golamwasy.SnippIt/Data/Library/Application Support/SnippIt/Library.store`.

If saving fails, the app keeps your latest text in memory and shows an error with a retry
button. Quitting with unsaved changes asks whether to keep the app open.
An unreadable library produces an error rather than being replaced with an empty one.

Notes from the former remote service are not present in the local database.

## Shortcuts

- **⌘N**: new note in the selected folder (or the first folder).
- **⇧⌘N**: new folder.
- **⌘F**: find and replace in the editor.
- **⌘S**: retry/confirm saving; normal edits already save automatically.
- **⌘Z / ⇧⌘Z**: undo / redo in the editor.
- **⌘+ / ⌘− / ⌘0**: increase, decrease, or reset text size.

New notes take their title from the first nonempty line. Click the title above the editor
or use Rename to give a note a fixed name. Existing note titles are preserved.

Right-click a note to rename it, move it to another folder, or move it to Recently Deleted.
Use the trash button at the bottom of the sidebar to restore notes and folders.
Items remain there until you explicitly delete them permanently, which asks for confirmation.
Restoring a folder does not restore notes that were individually deleted before the folder.

The View menu controls text size and line numbers. These preferences persist across launches.
Search in the sidebar matches note names, folder names, and note contents.
The gutter numbers logical lines; wrapped continuations keep the same line number.

## Verification

```sh
xcodebuild -project SnippIt.xcodeproj -scheme SnippIt \
  -destination 'platform=macOS' test
```

The persistence tests use separate on-disk databases, including save-failure recovery,
upgrading the original local schema, moving notes, and restoring deleted content.
UI tests use isolated libraries and preferences, verify note titles and trash recovery,
and check text after terminating and relaunching the app.

The icon source and generation prompt are in [Design/Icon.md](Design/Icon.md).
