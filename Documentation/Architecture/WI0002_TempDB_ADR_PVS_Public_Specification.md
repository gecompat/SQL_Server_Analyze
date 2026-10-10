# WI-0002: TempDB-ADR- und PVS-Diagnostik – öffentliche Spezifikation

**Status:** Implementiert; read-only Laufzeitnachweis auf SQL Server 2019, 2022 und 2025<br>
**Geltungsbereich:** Erweiterung von `[monitor].[USP_CurrentTempDB]` und dessen Current-State-Snapshotroute für SQL Server 2019 und neuer.

## Ziel und Abgrenzung

Der spätere Produkt-Slice ergänzt die bestehende TempDB-Session-, Datei- und Governance-Sicht um eine getrennte Momentaufnahme des traditionellen Version Store in `tempdb` und des ADR Persistent Version Store (PVS). Die Erweiterung beantwortet weder eine Ursachenfrage noch eine Cleanup- oder Kapazitätsprognose. Sie aktiviert oder konfiguriert ADR nicht, beendet keine Transaktion und persistiert keine Daten.

Sessionverbrauch, traditioneller Version Store und PVS besitzen verschiedene Granularitäten. Die Ausgabe darf ihre Werte deshalb nicht summieren, gegeneinander verrechnen oder einer Session zuschreiben.

## Öffentlicher Vertrag

Die vorhandenen öffentlichen Parameter und Resultsets bleiben unverändert. Der Produkt-Slice ergänzt genau ein benanntes Resultset `versionStore`. `TABLE` akzeptiert zusätzlich die Zuordnung `versionStore`; `RAW`, `CONSOLE` und JSON enthalten dieselbe fachliche Menge in ihrer jeweiligen bestehenden Ausgabedarstellung.

| Feld | Bedeutung |
|---|---|
| `DatabaseName` | Sichtbarer Datenbankname der Quelle; bei nicht auflösbarer ID `NULL`. |
| `TraditionalVersionStoreReservedPages` | Reservierte Seiten des traditionellen Version Store in `tempdb`. |
| `TraditionalVersionStoreReservedMb` | Aus den reservierten Seiten berechnete Größe in MiB. |
| `PersistentVersionStoreSizeKb` | Gemeldete Off-Row-PVS-Größe in KiB; In-Row-Versionen sind nicht enthalten. |
| `OnlineIndexVersionStoreSizeKb` | Gemeldete PVS-Größe für Online-Index-Rebuilds in KiB. |
| `PersistentVersionStoreFilegroupId` | Filegroup-ID des PVS, sofern die Quelle sie liefert. |
| `CollectionTimeUtc` | UTC-Zeitpunkt der lokalen Quellaufnahme. |
| `SourceStatus` | Status der jeweiligen Teilquelle, beispielsweise `AVAILABLE`, `UNAVAILABLE_VERSION`, `DENIED_PERMISSION` oder `ERROR_HANDLED`. |
| `ErrorNumber`, `ErrorMessage` | Technische Fehlerevidenz einer begrenzten Teilquelle; fachliche Nutzer- oder Nutzdaten werden nicht ausgegeben. |

Eine Zeile beschreibt eine Datenbankquelle, nicht eine Session, Datei oder Workload Group. Die resultierende Menge ist nicht durch `@MaxZeilen` begrenzt; das vorhandene Limit bleibt ausschließlich dem Sessionresultset vorbehalten.

## Quellen, Capability und Berechtigungen

Der traditionelle Version Store wird aus `sys.dm_tran_version_store_space_usage` erhoben. Der PVS wird aus `sys.dm_tran_persistent_version_store_stats` erhoben. Jede Quelle wird begrenzt und unabhängig gelesen; eine nicht verfügbare DMV, Spalte oder Berechtigung wird im eigenen Fehlerpfad als Teilquellenstatus ausgewiesen. Jede DMV wird höchstens einmal pro Procedure-Aufruf gelesen; die Namensauflösung verwendet keine dynamische Datenbankverbindung.

Für SQL Server 2022 und neuer erfordern die beiden Quellen mindestens `VIEW SERVER PERFORMANCE STATE`. Ältere unterstützte Versionen verwenden ausschließlich den dokumentierten Fallback für die jeweils verfügbare Quelle. Fehlende Rechte, nicht verfügbare Quellen oder nicht vorhandene optionale Spalten bleiben auf die betroffene Teilquelle begrenzt und unterdrücken weder Sessions noch Dateien oder `tempdbGovernance`.

## Parent- und Ausgabeparität

`USP_CurrentOverview` übernimmt die Version-Store-Menge aus dem gemeinsamen Current-State-Snapshot. Direkter und Parentpfad verwenden dieselben fachlichen Felder, Statuscodes und JSON-Schlüssel. Die optionale TempDB-Dateisicht bleibt davon unabhängig und wird weiterhin nach ihrem bestehenden Vertrag erhoben.

`moduleStatus` wird `AVAILABLE_LIMITED`, wenn mindestens eine Version-Store-Teilquelle begrenzt ist. Ein nicht verfügbarer PVS-Pfad darf nicht den traditionellen Version Store als nicht verfügbar darstellen und umgekehrt.

## Nachweisplan vor Implementierung

Die Implementierung benötigt einen SQL-Server-2025-Impact-Lauf nach der verbindlichen CI-Strategie. Zusätzlich sind nur bei einem konkreten Versionsrisiko gezielte 2019- oder 2022-Nachweise erforderlich. Der Vertrag umfasst mindestens verfügbare und leere Quellen, fehlende Berechtigung, fehlendes optionales Schema, Quellfehler, direkten und Parentpfad, RAW/CONSOLE/TABLE/JSON sowie die Erhaltung der bestehenden Session-, Datei- und Governance-Mengen.

Ein positiver PVS-Wert oder ein hoher traditioneller Version Store belegt weder eine Ursache noch eine erforderliche Betriebsmaßnahme. Eine Gegenprüfung benötigt den zugehörigen Transaktions-, ADR- oder Workloadkontext.

## Primärquellen

- [sys.dm_tran_version_store_space_usage](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-tran-version-store-space-usage-transact-sql?view=sql-server-ver17)
- [sys.dm_tran_persistent_version_store_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-tran-persistent-version-store-stats?view=sql-server-ver17)
- [Monitor and troubleshoot accelerated database recovery](https://learn.microsoft.com/en-us/sql/relational-databases/accelerated-database-recovery-troubleshoot?view=sql-server-ver17)
