# Project file storage

`ProjectStorage` owns one project's working directory and asset store. Its root
stays fixed until the project closes, including after Save As, so outstanding
engine file paths remain valid. An unsaved or ZIP-imported project uses a
temporary root; explicit project roots are preserved on close.

## Files, scopes, and ownership

`ProjectAssetStore` registers immutable committed files. Writers obtain a private
pending file, finish and close their I/O, then commit it. Changing a file's
contents requires a new write. Categories distinguish required data from
regenerable caches.

Every client uses an `AssetScope`. Scopes own read grants, pending writes, and
retention claims; they do not know about processors, commands, or saved project
documents. A scope may forbid retaining cache files. Closing a scope rejects new
operations, waits for its store operations, releases its grants and claims, and
aborts unfinished writes. Clients must finish external file I/O before releasing
grants or closing the scope. Committed files are not deleted when claims end;
explicit deletion requires that no scope has a reader or retention claim.

`AssetRetention` groups independently disposable claims in a scope. Cloning a
handle creates fresh claims on the same files. Disposing one handle does not
invalidate another; closing their owning scope invalidates all of them.

`AssetScope.snapshot()` freezes that scope's reference-ID-to-path mapping and
acquires reads in a separate scope. It can be used for any scope and remains
valid after the source changes or closes. The caller closes the snapshot after
finishing file access. It contains no save or project policy.

## Project and engine clients

`ProjectStorage.projectFiles` is the scope whose claims describe the current
project document. New projects start with an empty scope. Loading explicitly
restores its mapping from `ProjectModel.fileRetentions` before starting the
engine. Opening the underlying store does not restore model state.

Commands and independent processor snapshot handles use generic retention
handles through `ProjectStorage.retainAssets`. These claims survive engine
restarts but are excluded from the current document's scope. Storage closure
invalidates these project-lifetime handles.

Each engine session owns a separate `AssetScope`. `FileStorageClient` remains an
asynchronous C++ client: IPC carries opaque tokens and file grants, and the Dart
request handler dispatches to the same scope API used by local callers. Ownership
is authoritative in Dart; it is not replicated into the engine. The engine scope
closes only after the engine has stopped accessing its files.

## Browser working storage

On web, a small Emscripten module hosts the working filesystem independently of
the audio engine. Dart's file adapter accesses this filesystem directly. Each
engine session mounts it through PROXYFS before starting C++, using the same
absolute paths as Dart. Project directories live under `/anthem/projects`;
ownership and retention remain in the existing Dart scopes.

Stopping an engine waits for its Emscripten runtime to exit before releasing the
engine's file scope. The working files, project references, and undo history
remain available to a replacement engine. Closing the project releases its
claims and removes its temporary working directory.

This backend uses MEMFS. Working files occupy memory and do not survive a page
reload. Downloading a project creates a ZIP containing its document and the
assets referenced by that document. Opening a ZIP extracts it into a fresh
temporary working directory and restores the document's file claims before
starting the engine. Closing the imported project removes that directory.

## Saving and exporting

`PreparedProjectSave` waits for pending commands, captures live processor state,
then captures the document JSON and a snapshot of `projectFiles`. It injects the
snapshot's reference manifest into that JSON without updating the live model's
load-time manifest. It also tracks subsequent model changes for dirty-state
handling. Directory and ZIP writers consume this prepared result; its owner
closes it on success or failure.

`SavedProjectFiles` is persistence bookkeeping using ordinary retention handles.
It protects assets used by documents sharing the working store's actual files.
Successful publication acquires the new claims before releasing that document's
previous claims. Failed saves leave the old claims intact.

Save As copies assets into an independent directory, and ZIP export embeds its
own copies. Those outputs require no additional claims on the source store.
Documents already sharing the source root remain protected until overwritten or
project closure. Project and snapshot formats, including persisted retention
IDs, are unchanged by this separation of responsibilities.

Native ZIP writers stream files to disk in an isolate. Browser downloads encode
the same layout into bytes using the captured document and asset reads. Both
import paths run one Dart extraction workflow that validates paths, checks file
lengths and CRCs, and removes temporary files on failure.

Native imports use the Dart ZIP decoder and file streams in an isolate. Browser
imports use a JavaScript worker with a pinned zip.js bundle, packaged as ordinary
Flutter assets under `lib/logic/project_file/web`. It supplies ZIP metadata to the Dart workflow
and decompresses each file when requested. Input range reads and output transfers
are limited to 64 KiB; each output chunk waits for a filesystem write before the
worker sends another. Browser imports stream entry contents into the UI-owned
filesystem instead of buffering the ZIP or a whole decompressed entry. Extracted
working files still occupy MEMFS. Legacy single-file projects can also be
migrated into temporary storage on either platform.

A successful browser download clears the dirty flag only if the project did
not change after save preparation. Exporting a copy leaves it unchanged.
