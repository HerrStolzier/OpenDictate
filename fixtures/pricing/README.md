# Local cost estimates

`prices.json` is the common dated USD price table. Transcription values are
estimated USD per audio minute and must match the existing Swift table.
Translation values are USD per million input/output tokens. Prices can change;
update date/source and the Swift values together after checking official docs.
Unknown models or missing translation usage have unknown cost, never zero.
Custom servers count audio duration but have zero provider cost in this estimate.
Cached-token discounts, taxes, regional surcharges and actual invoices are not
represented. This is no account balance or provider billing statement.

`examples.json` supplies fixed windows and numeric examples for Rust and C#.
Windows are inclusive at the start and end at `now`; future entries are excluded.
Production windows use local calendar days (today and six preceding days) and
the local current month. Retention removes entries strictly older than 13
calendar months. Fixed window boundaries keep cross-language arithmetic tests
independent of the host time zone and current time.
