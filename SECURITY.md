# Security policy

Pastu is an early prototype (v0.1 prereleases only). It stores your clipboard history locally and
makes no network calls, so the most relevant problems are about local data exposure
(for example: sensitive copies that get stored although they should not, wrong file permissions,
or a way for another process to read or change the history).

## Reporting a vulnerability

Please do **not** open a public issue for a security problem.

Report it privately with GitHub's **"Report a vulnerability"** button on the repository's Security tab
(private vulnerability reporting). If that button is not available, contact the maintainer through the contact
details on their GitHub profile and do not post the details publicly.

Please include the macOS version, the Pastu version or commit, and steps to reproduce.
You can expect an answer within about a week. This is a hobby-scale open source project, so there is no
bug bounty and no guaranteed fix time, but reports are taken seriously.

## Scope and known limitations

- The history database is **not encrypted**. It is protected by file permissions only (`0700` folder,
  `0600` files). This is documented in the README and is not a vulnerability by itself.
- Copies that apps do not mark as concealed or transient cannot be told apart from normal text.
- Pictures (for example screenshots) are stored unencrypted as PNG, like text, and can contain sensitive content.
- The source app of a clip (used by the ignored-apps list) is a best guess: the frontmost app when the copy was
  noticed. A very fast app switch can attribute a copy to the wrong app.
- Release builds are signed ad hoc, not notarized. Only download Pastu from this repository's Releases page
  and check the published SHA-256 checksum.

## Supported versions

Only the latest release (and `main`) receives fixes.
