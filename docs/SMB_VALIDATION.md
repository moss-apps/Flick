# SMB playback validation (issue #291)

## Scope

SMB playback caches the **original file**. There is no transcoding, resampling,
guest fallback, or change to signing/encryption policy. Test Connection now opens
the share and lists the configured root folder once; it does not guarantee read
permission for every file or successful decoding/output.

Library sync treats the configured root as mandatory but skips an unreadable or
vanished child directory (common on Windows shares: `System Volume
Information`, per-user folders, or a folder deleted mid-scan) instead of
aborting the whole sync. Directory identities are de-duplicated and recursion is
depth-capped so junction/DFS loops cannot run forever. Cover-art reads use the
pipelined reader, so images larger than the server's single-READ limit still
load.

Downloads use a same-directory hidden staging file, verify the server's byte
count, then close and atomically rename it. Dart also requires the completion
event and checks the published file length. Playback/prefetch for the same
server/file share one download. A resync invalidates cached bytes when the
listed file size changes, so a replaced file cannot keep playing from the old
cache. Older SMB cache entries are bypassed using a new SMB-only cache key,
without clearing app data or other protocols' cache entries. Normal
errors/cancellation clean up staging files; force-killing the process can leave
an unused hidden staging file, which is never considered playable. Progress
listeners are isolated from the transfer, so a failing UI callback cannot cancel
a download other callers are waiting on, and the shared-transfer entry is
released when the transfer finishes rather than when its first waiter leaves.

Listing-only songs can still show `00:00` before their first download. After a
successful download, metadata extraction asynchronously fills missing duration,
sample rate and bit depth when supported. Failure is nonfatal, and sync preserves
backfilled values and local edits for unchanged files. No eager library download
or database migration is needed.

## Automated checks

```sh
flutter analyze
flutter test test/services/smb_service_parse_test.dart test/services/smb_service_download_test.dart test/services/network_cache_service_test.dart test/services/remote_metadata_backfill_test.dart
cargo test --lib --manifest-path rust/Cargo.toml
flutter test
```

Tests cover interrupted/short downloads and retry, absent/invalid completion,
on-disk length validation, same-key concurrency with progress, original bytes,
legacy-cache bypass, LRU accounting, staging-file exclusion, URL encoding,
configured-root probing, safe diagnostics, metadata preservation, partial
directory walks, and progress-listener isolation.

## Real-device checklist (not replaced by unit tests)

Use the affected Galaxy A54/Android 16 if available, plus authenticated Windows
and Samba shares. Record Flick version, server OS/version and SMB version, without
posting addresses, share names or credentials.

1. Test `smb://server/share`, a nested folder and trailing slashes. Test spaces,
   Unicode and a literal percent sign (URL-encode it as `%25`). A host-only URL
   must request a share, not claim a successful connection. Credentials belong
   in their separate fields, never in the URL.
2. Confirm correct credentials work. Wrong credentials, denied shares, missing
   roots and denied file reads should fail at the corresponding stage. A readable
   root with a denied track can legitimately pass Test Connection. A denied
   child folder should be skipped during sync while sibling folders still
   import; a denied configured root must still fail the sync.
3. Play uncached FLAC/MP3 and a large hi-res/DSD original supported by the selected
   output. Compare the same file played locally in Flick. Confirm duration/format
   update after caching, and remain after library sync.
4. Interrupt Wi-Fi mid-download, restore it and retry **without clearing app
   data**. No partial file should play. Repeat with next-track prefetch running
   while manually selecting that track; both callers should use one transfer.
5. Upgrade from a build with a failed SMB transfer. The old cache file must not
   be reused. Check subsequent cache hits and cache-cap eviction.
6. Fail file decoding/output deliberately; the playback banner should distinguish
   this from an SMB download failure. Check repeated failures still show a banner.

## Privacy-safe reporting

New SMB diagnostic records contain only allowlisted stage/code, result, numeric
byte counts and elapsed milliseconds. Examples:

```text
SMB stage=root code=denied result=failed elapsed_ms=120
SMB stage=download result=ok received=123456 total=123456 elapsed_ms=500
```

Stages: `url`, `connect`, `share`, `root`, `read`, `download`, `cache`, `decode`.
Authentication/signing failures are codes on the operation that failed; `decode`
also covers selected-output startup failure after downloading.

Ask the reporter for only these new SMB records or the error banner's stage/code,
not an unreviewed full log. Existing logs elsewhere can contain track titles and
paths. Never request passwords, tokens, database dumps or packet captures.

Also ask whether blank credential fields were redacted or truly empty/guest;
request only the username **format** (plain, `DOMAIN\\user`, or `user@domain`),
not its value. In the edit screen a blank password retains the saved password.
Collect failing file type/approximate size and whether local Flick playback works.
Do not advise disabling SMB signing/encryption to make a test pass.
