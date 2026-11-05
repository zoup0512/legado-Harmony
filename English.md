# [English](English.md) [中文](README.md)

<div align="center">
<img width="125" height="125" src="svg/icon.svg" alt="legado"/>

Legado

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
- The PIN is not stored in plaintext. Verification uses a random salt and PBKDF2-HMAC-SHA256. Five consecutive failures trigger a cooldown, which increases with further incorrect attempts.
- Change the PIN from the unlocked privacy folder. Optional biometric unlock is off by default and requires the current PIN and a successful system authentication before enabling.
- A forgotten PIN can only be reset with biometrics enabled beforehand. If unavailable, authentication cannot be bypassed; private books are not automatically deleted or made public. Keep the PIN safe.
- Existing private books without a PIN require the previous biometric authentication before setting one, preventing an unauthenticated visitor from taking over old data.
- Leaving the application locks access and hides private lists, details, chapters and book content. This is in-app access control, not file encryption or a replacement for the device lock screen and backups.

## Project scope

The HarmonyOS application consists of `entry`, `commons/colorLibrary` and `readerLibrary`. Local imports use `LocalBookImportService`; the current reader page uses the system ReaderKit.

`_ref/reader-dev` is a separate reference project and is not packaged in the HarmonyOS application. The local-only changes do not alter that backend or any deployed service.

## Disclaimer

This application does not supply or distribute books. Import only files that are legally owned or authorized, and respect copyright and applicable laws.

## Contributors

[Contributors](https://github.com/mgz0227/legado-Harmony/graphs/contributors)
