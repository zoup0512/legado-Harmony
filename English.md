# [English](English.md) [中文](README.md)

<div align="center">
<img width="125" height="125" src="svg/icon.svg" alt="legado"/>

Midu (based on Legado)

An open-source local ebook reader for HarmonyOS.
</div>

## Features

- Import multiple books through the system file picker or scan a directory selected by the user.
- Copy imported files into the application sandbox, detect duplicate content with SHA-256, and leave original files intact.
- Read local TXT and EPUB books using the system ReaderKit. The importer also recognizes MOBI, AZW and AZW3; actual readability depends on the system parser.
- List and grid bookshelves, groups, pinned books and batch management.
- Chapter navigation, reading position restoration, font size, colors, line spacing, page transitions and brightness settings.
- Themes and a privacy folder protected by a six-digit PIN, with optional fingerprint/face unlock. The privacy folder provides in-app hiding and access control, not file encryption.

## Local-only mode

The HarmonyOS application only reads local files. It does not provide built-in ebook sources, source imports, online book search, discovery, web scraping, RSS subscriptions, server bookshelves, WebDAV or a web source editor. It does not request Internet permission.

The update entry in About opens the system app store only when selected by the user; the application does not download books or scrape content.

### Import and read

1. Choose book import from the bookshelf menu.
2. Select files or a directory, review the candidates and start importing.
3. Open a book from the bookshelf, navigate chapters and adjust reader settings.

A successful import means that a file has been saved, not that every file can be parsed. If a book cannot be opened, check its integrity and the formats supported by the device's reader component.

### Existing data

- Upgrading does not clear the bookshelf or automatically delete old records and downloaded files.
- Previously downloaded server books can be read directly from local storage without checking for remote updates.
- Old records containing only remote addresses or metadata are not readable offline. Import a legitimate local file when prompted.
- Existing reading-position and settings storage remains compatible. Keep original files safe: clearing application data or uninstalling may remove sandbox copies and reading progress.

## Privacy folder

- Set and confirm a six-digit PIN on first use. Fingerprint or face enrollment is not required.
- The PIN is not stored in plaintext. Verification uses a random salt and PBKDF2-HMAC-SHA256. Five consecutive failures trigger a cooldown, increasing to at most 30 minutes. Waiting uses elapsed time since system startup, so changing the system date does not skip it. To preserve compatibility with existing credentials, a process restart conservatively restarts the full recorded cooldown tier; repeated status reads do not restart it.
- Change the PIN from the unlocked privacy folder. Optional biometric unlock is off by default and requires the current PIN and a successful system authentication before enabling.
- A forgotten PIN can only be reset with biometrics enabled beforehand. If unavailable, authentication cannot be bypassed; private books are not automatically deleted or made public. Keep the PIN safe.
- Existing private books without a PIN require the previous biometric authentication before setting one, preventing an unauthenticated visitor from taking over old data.
- Leaving the application locks access and hides private lists, details, chapters and book content. Private books are not written to public reading history; existing history is filtered against current private ownership.
- The application no longer actively restricts system screenshots or screen recording. Locking access and hiding private pages when leaving the application do not guarantee that recent-task snapshots are obscured.
- This is in-app access control, not file encryption or a replacement for the device lock screen and backups. It does not prevent authorized sandbox extraction tools or external cameras from obtaining content.

## Project scope

The HarmonyOS application consists of `entry`, `commons/colorLibrary` and `readerLibrary`. Local imports use `LocalBookImportService`; the current reader page uses the system ReaderKit.

`_ref/reader-dev` is a separate reference project and is not packaged in the HarmonyOS application. The local-only changes do not alter that backend or any deployed service.

### Local builds and signing

Build with DevEco Studio's bundled Node/Hvigor and the installed HarmonyOS SDK. Keep product, module and SDK selections consistent with the local project rather than renaming targets just to run tests.

Certificate paths, signing profiles, keys and passwords are machine-local configuration and must not be shared or committed. Configure signing locally in DevEco and exclude those differences before committing. Although `signing.properties` is ignored, this project does not currently load it as an override: creating the file alone has no effect. Preserve existing local signing edits; migration to a local override mechanism is a separate change.

### Development logs

- Production code uses a shared HiLog wrapper. Debug logging is disabled by default and enabled only by the application's generated `BuildProfile.DEBUG`; release builds emit no debug traces. Fixed events may be public, while necessary dynamic details use private arguments. Book content, complete business objects and preference values are not logged.

## Disclaimer

This application does not supply or distribute books. Import only files that are legally owned or authorized, and respect copyright and applicable laws.

## Contributors

[Contributors](https://github.com/mgz0227/legado-Harmony/graphs/contributors)
