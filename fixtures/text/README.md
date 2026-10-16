# Shared transcript sanitization cases

`sanitize.json` is read by the Rust policy tests, Windows `TextFixtureChecks`
and Swift `TranscriptTextTests`. Each case contains a stable `name`, `input`,
`expected` sanitized text and `multiline` for the sanitized result. Inputs use
JSON Unicode escapes. The file covers controls, bidirectional marks, line
endings, Unicode separators, whitespace and preserved Unicode text.

Line and paragraph separators become LF on every platform, as required by
`PRIVACY.md`. Rust and C# previously kept U+2028/U+2029, missing the console
multiline guard. This is a correction to that documented safety contract.
Zero-width joiners/non-joiners, zero-width space and BOM are preserved; these
are not control characters and joiners are needed for compound emoji.
There are no platform-specific exceptions in the current cases.
