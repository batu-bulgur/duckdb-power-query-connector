# Personal fork releases

Versions use [Semantic Versioning](https://semver.org/). Fork tags are namespaced
as `fork-vMAJOR.MINOR.PATCH`, independently of MotherDuck's upstream `v*` tags.
The connector metadata and VERSION file contain the same numeric version.

| Version | Changes and validated folding scope |
| --- | --- |
| [0.5.0](docs/release-notes/0.5.0.md) | Eight GUI date targets with kind/precision/offset preservation and M/SQL/ODBC regressions |
| [0.4.0](docs/release-notes/0.4.0.md) | First 14 scalar/index targets: UTF-16 text, rounding/equality, normal error transport, ordered SQL index plans, M inventory and exhaustive parallel regression verification; SDK/culture/host limits remain explicit |
| [0.3.0](docs/release-notes/0.3.0.md) | Initial fork release: pagination, text/Unicode fixes, native EndsWith, sample standard deviation, headless correctness/SQL/row guards and automated versioned releases |

See [versioning policy](docs/versioning.md). The downloadable artifact, exact
validated commit and checksums are on the personal fork's
[Releases page](https://github.com/batu-bulgur/duckdb-power-query-connector/releases).
