# Shortcut-backed file storage


## Activity

Make DataRunner and Print 2 Mail file I/O work with either ordinary local
directories or directories represented by Windows `.lnk` files that point to
SMB shares.

The immediate example is:

```text
P2M_SHIPPING_STATION=/mnt/o/Outputs/DataRunner/00_ShippingStation.lnk
```

The P2M “Move to Shipping Station” action must copy and remove files through
SMB when this configuration points to a shortcut.

## Agreed decisions

- Use a shared abstraction for DataRunner and Print 2 Mail.
- Any configured directory location may be local or a Windows shortcut.
- Shortcut targets always represent folders, not individual files.
- Use the `smb_shortcut` gem; extending it is acceptable.
- Add SMB configuration variables to `.env`; credentials will be supplied
  separately.
- Create file stores lazily. Startup validation must not require an active SMB
  connection or make application boot fail because a share is temporarily
  unavailable.
- Expand startup diagnostics beyond the current local directory/file checks.

## Proposed architecture

```text
configured location
        |
        v
FileStore.for(location)
        |
        +-- LocalFileStore  -> Pathname / FileUtils
        |
        +-- SmbFileStore    -> WindowsShortcut / SmbShare
```

Callers should use file-store operations instead of assuming that every
location is a `Pathname`. The initial useful operations are:

- `directory?`
- `readable?`
- `list`
- `exist?(name)`
- `copy(source, name)`
- `remove(name)`

The SMB implementation must preserve the folder portion of the shortcut's
UNC target. `SmbShare` currently accepts a host and share and operates with
remote filenames, so the target's relative folder may require an addition to
the gem or a small adapter.

## Startup validation

For each configured directory location:

1. Confirm the value is present.
2. For a normal path, check that it is a readable directory.
3. For a `.lnk`, check that the shortcut file exists.
4. Parse the shortcut with `SmbShortcut::WindowsShortcut`.
5. Confirm that it resolves to a folder-style SMB target.
6. Confirm that SMB credentials are configured.
7. Report configuration, parsing, tooling, and credential errors separately.

SMB connectivity should be checked only when appropriate for diagnostics; the
file store itself must connect lazily during the requested operation. Startup
messages must never expose passwords.

## TODO

- [x] Inspect the `~/gitea/smb_shortcut` source repository.
- [x] Put the shared abstraction in Paperboy and extend `smb_shortcut` with
      the SMB-specific operations it needs.
- [x] Add a remote-folder accessor to `WindowsShortcut`.
- [x] Define the initial local and SMB file-store interfaces.
- [x] Add lazy SMB client construction and credential handling.
- [x] Identify the P2M configured directories and convert their stores and
      services to use the abstraction.
- [ ] Convert remaining DataRunner path consumers and generated DSL locations
      as needed.
- [ ] Convert DataRunner path consumers and generated DSL locations as needed.
- [x] Update the shipping-station copy and remove operations.
- [x] Update P2M staging and printer queue copy/remove operations to use the
      initial file-store interface.
- [ ] Update batch shipping-station operations.
- [x] Convert P2M Data Reset to recursively list and clear local or SMB stores.
- [x] Convert P2M destroy archive writes and cleanup operations to file stores.
- [x] Expand `StartupConfiguration` to validate local paths and shortcuts.
- [x] Add initial unit tests for local stores and remote-folder paths.
- [x] Add structured SMB directory entries and remote downloads.
- [x] Convert P2M production-file listing and preview to the file store.
- [x] Preserve remote directory-entry timestamps for production-file sorting.
- [ ] Add tests proving P2M never treats a `.lnk` file as a local directory.
- [x] Add the agreed SMB variables to the environment documentation/template.
- [ ] Run RuboCop, Brakeman, bundle-audit, and the test suite.

## Open questions

- Which exact environment variables should support shortcut-backed folders?
- Should a configured shortcut be required to have a `.lnk` extension, or
  should shortcut detection inspect the file contents as well?
- Should a remote existing file with the same name be considered success, or
  should the implementation compare remote metadata/content where possible?
- What is the desired user-facing distinction between an unavailable share,
  invalid credentials, and an existing conflicting file?

## Resume prompt

```text
Resume the shortcut-backed file storage activity documented in
docs/FILE_STORE_SHORTCUTS.md. Inspect the available smb_shortcut codebase,
then implement the shared lazy local/SMB file-store abstraction for DataRunner
and Print 2 Mail. Support configured directory locations that are either local
directories or Windows .lnk files pointing to SMB folders. Expand startup
diagnostics, update P2M shipping-station copy/remove behavior, add tests, and
run the project quality checks. Do not add real credentials to the repository.
```
