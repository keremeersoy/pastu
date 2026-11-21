# Security policy

Pastu is an early prototype and has had no release yet. It stores your clipboard history locally and
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
