# Connector development

Primary upstream: `motherduckdb/duckdb-power-query-connector`. Keep its ODBC
connector, public function signature, resources, and `DuckDB.proj` compatible.
The local `origin` is the personal fork; `upstream` is MotherDuck. Do not push
without an explicit request.

Use 64-bit PowerShell 7.2 or newer on Windows:

```powershell
./tools/dev.ps1 bootstrap
./tools/dev.ps1 doctor
./tools/dev.ps1 build
./tools/dev.ps1 test
./tools/dev.ps1 test-folding
./tools/dev.ps1 verify
```

- Read `docs/development.md` and `docs/upstream-review.md` before changing folding.
- Reproduce failures with the actual SDK and ODBC driver before changing capabilities.
- Keep fixes narrow and add correct-result, SQL, and ODBC-row regression assertions.
  PQTest exit code zero alone is not success. Never regenerate baselines in test runs.
- For text folding changes, read `docs/text-folding.md`. Preserve the additive
  VARCHAR/NVARCHAR conversion and the negative EndsWith escape regression until
  actual driver folding is demonstrated. Driver source/build work is a separate scope.
- Use only synthetic fixtures. Never use MAW or production data in automated tests.
- Put downloads, substituted queries, fixture databases, credentials, logs, and
  ad-hoc research under `/.agent/`. Never stage that directory or `/outputs/`.
  `bin/AnyCPU/Debug/DuckDB.mez` is the intentional, ignored build output.
- Preserve the upstream MSBuild build. The headless SDK build must package the
  exact same allowlisted resources from `DuckDB.proj` and load with `PQTest info`.
- Do not modify installed ODBC drivers, DSNs, system locale, security policies,
  user Excel/Power BI sessions, or custom-connector trust settings as a test shortcut.
- Keep SDK-only compatibility adjustments in `tools/Initialize-Sdk.ps1`, never
  in connector runtime code. Keep environment-specific experiments separate.
- ADBC remains a research track (`docs/experiments/adbc.md`); no migration without
  measured folding, correctness, performance, and maintainability evidence.
- Host integration is a final, separate check. SDK success does not prove Excel
  custom-connector support or Power BI Desktop GUI integration.
