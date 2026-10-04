# Local agent reference library

These are reference material, not instructions to install another desktop or
copy its implementation into Titan. Keep Titan's existing shell, command
interfaces, branding and user layers. Consult [Omarchy coverage](omarchy.md)
before implementing a feature again.

## Omarchy

- Public source: https://github.com/omacom/omarchy
- Local reference checkout:
  [~/.cache/titan/references/omarchy](/home/shade/.cache/titan/references/omarchy).
  This shallow clone is outside Titan's Git tree and survives `/tmp` cleanup.
- Reviewed revision: `5c4da021469517449770579793b37ce26d0a0d48`, cloned
  2026-10-04. Use `git -C ~/.cache/titan/references/omarchy rev-parse HEAD`
  before using it; upstream changes do not change the recorded coverage.
- Start with its [manual](/home/shade/.cache/titan/references/omarchy/manual/01-welcome-to-omarchy.md),
  then inspect the relevant `bin/`, `config/`, `default/`, `install/` and
  `shell/` source. Its current shell differs from the older Titan shortcut
  reference at `a85e29abb556816f4644cf975e98da694b486aa8`.
- Titan's local `.webfetch/index.md` also links a saved GitHub landing page;
  the clone is the source reference for behavior. Neither archive nor clone
  is packaged or committed into Titan.

## Quickshell

- User-supplied archive:
  [~/.webfetch/quickshell/index.md](/home/shade/.webfetch/quickshell/index.md).
- [Catalog](/home/shade/.webfetch/quickshell/catalog.md),
  [coverage](/home/shade/.webfetch/quickshell/coverage.md),
  [broken links](/home/shade/.webfetch/quickshell/broken-links.md) and
  [external references](/home/shade/.webfetch/quickshell/external-references.md).
- Coverage reports 790 successfully captured pages across versions 0.1.0,
  0.2.0, 0.2.1, 0.3.0 and 0.3.1, plus 124 broken linked URLs. Images and
  external Qt documentation are linked, not archived. These are the archive's
  reported checks, not a new review of every page by this agent.
- **Use v0.3.1 for the installed Quickshell 0.3.1.** Search the index for the
  exact type and version, then open its linked `content.md`. Pages retain
  source URLs and code blocks. Consult the failure list if a link is missing;
  don't silently substitute an older API.
- Canonical reference: https://quickshell.org/docs/v0.3.1/types/

These absolute paths belong to the owner's development machine. On another
machine, clone Omarchy into an external reference directory and obtain the
versioned public Quickshell docs. Never hard-code reference paths into shipped
runtime code. Keep source/version evidence in research and verification notes.
