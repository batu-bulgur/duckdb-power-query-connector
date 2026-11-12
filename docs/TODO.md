# Development backlog

## Actionable errors and user guidance

- [ ] **2026-11-12 — User request; future development.** This entry records the requirement only. Do not implement it as part of this backlog update.

Power Query users should understand why an operation failed and how to proceed. Unexpected folding behavior must not disappear behind a generic error or an unexplained change of execution path.

Future scope:

- Distinguish native M function/argument/value errors, DuckDB SQL binding and evaluation errors, ODBC/transport errors, connector translation defects and known support limits.
- Preserve original M `Reason`, `Message`, `Detail`, error codes and other available fields. Add useful context to DuckDB/ODBC failures without losing their original cause or presenting them as native M errors.
- Identify the M step/function and relevant argument or data condition when known. State uncertainty explicitly instead of presenting a suspected cause as verified.
- Provide an actionable remedy or next step: correct the argument/type, rewrite the query, use a supported mapping or evaluate locally from an appropriate step.
- Distinguish general function support from an unsupported invocation. If suggesting local M evaluation, provide a concrete example and explain its folding/transfer impact. Recommend it only when result equivalence is preserved.
- Report unexpected translator defects distinctly from ordinary support limits. Make retries/fallback diagnosable and never count incorrect results as success.
- Consider safe diagnostic correlation identifiers. Keep tokens, connection secrets, personal data and raw customer records out of messages/logs; do not automatically display complete SQL.

Acceptance: synthetic tests must cover each error class and proposed recovery path. Check original error preservation, correct source classification, actionable explanation and fallback result equivalence separately. Verify the user-visible Power Query message in the host; SDK tests alone do not establish host behavior.
