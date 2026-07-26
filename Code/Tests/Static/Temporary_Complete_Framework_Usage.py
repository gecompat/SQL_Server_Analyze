#!/usr/bin/env python3
"""Apply the bounded FRAMEWORK-USAGE-001 integration patch."""

from __future__ import annotations

import csv
import io
from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def write(path: str, content: str) -> None:
    Path(path).write_text(content, encoding="utf-8", newline="\n")


def replace_once(path: str, old: str, new: str) -> None:
    text = read(path)
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"Anchor not found: {path}")
    write(path, text.replace(old, new, 1))


procedure_path = "Code/09_VersionAdaptive/500_USP_FrameworkUsageFromQueryStore.sql"
replace_once(
    procedure_path,
    "       OR @LockTimeoutMs NOT BETWEEN 0 AND 60000\n",
    "       OR @LockTimeoutMs IS NULL OR @LockTimeoutMs NOT BETWEEN 0 AND 60000\n",
)

test_path = "Code/Tests/QueryStore/120_Framework_Usage_Runtime_Contract.sql"
replace_once(
    test_path,
    "    SELECT COUNT_BIG(*) AS [SyntheticObjectCount]\n    FROM [sys].[objects] WITH (NOLOCK);",
    "    DECLARE @SyntheticObjectCount bigint;\n    SELECT @SyntheticObjectCount=COUNT_BIG(*)\n    FROM [sys].[objects] WITH (NOLOCK);",
)
replace_once(
    test_path,
    "    SET LOCK_TIMEOUT @OriginalLockTimeout;\n    RAISERROR",
    "    DECLARE @SuccessRestoreSql nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';\n    EXEC [sys].[sp_executesql] @SuccessRestoreSql;\n    RAISERROR",
)

object_inventory_path = "Metadata/Inventory/ObjectInventory.csv"
rows = list(csv.reader(io.StringIO(read(object_inventory_path))))
new_object = [
    "PROCEDURE",
    "USP_FrameworkUsageFromQueryStore",
    "Code/09_VersionAdaptive/500_USP_FrameworkUsageFromQueryStore.sql",
]
rows = [row for row in rows if len(row) < 2 or row[1] != new_object[1]]
rows.append(new_object)
out = io.StringIO(newline="")
csv.writer(out, lineterminator="\n").writerows(rows)
write(object_inventory_path, out.getvalue())

resultsets_path = "Metadata/Inventory/ResultSets.csv"
rows = list(csv.reader(io.StringIO(read(resultsets_path))))
rows = [row for row in rows if not row or row[0] != "USP_FrameworkUsageFromQueryStore"]
rows.extend(
    [
        [
            "USP_FrameworkUsageFromQueryStore",
            "moduleStatus",
            "0",
            "1",
            "1",
            "#FrameworkUsage_ModuleStatus",
            "1",
            "[ModuleName] sysname NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) NOT NULL , [IsPartial] bit NOT NULL , [QueryStoreActualStateDesc] nvarchar(60) NULL , [QueryStoreReadonlyReason] bigint NULL , [RequestedWindowDays] int NULL , [MinimumExecutions] bigint NOT NULL , [ReturnedRowCount] bigint NOT NULL , [HasMoreRows] bit NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) NULL",
            "",
        ],
        [
            "USP_FrameworkUsageFromQueryStore",
            "usage",
            "1",
            "1",
            "1",
            "#FrameworkUsage_Usage",
            "1",
            "[ProcedureName] sysname NOT NULL , [ExecutionCount] bigint NOT NULL , [LastExecutionTime] datetimeoffset(7) NULL , [AvgDurationMs] decimal(19,3) NULL , [AvgCpuMs] decimal(19,3) NULL , [AvgLogicalReads] decimal(19,2) NULL , [AvgMemoryGrantKB] decimal(19,2) NULL , [PlanCount] bigint NOT NULL , [QueryCount] bigint NOT NULL , [FirstSeen] datetimeoffset(7) NULL , [LastSeen] datetimeoffset(7) NULL",
            "Keine sichtbare Framework-Nutzung im gewählten Query-Store-Scope",
        ],
        [
            "USP_FrameworkUsageFromQueryStore",
            "sourceStatus",
            "0",
            "1",
            "1",
            "#FrameworkUsage_SourceStatus",
            "1",
            "[SourceOrdinal] int NOT NULL , [SourceName] sysname NOT NULL , [SourceObject] nvarchar(256) NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) NOT NULL , [IsPartial] bit NOT NULL , [ReturnedRowCount] bigint NOT NULL , [RequiredPermission] nvarchar(256) NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) NULL , [EvidenceLimit] nvarchar(1000) NOT NULL",
            "",
        ],
        [
            "USP_FrameworkUsageFromQueryStore",
            "warnings",
            "0",
            "1",
            "1",
            "#FrameworkUsage_Warnings",
            "1",
            "[WarningOrdinal] int NOT NULL , [SourceName] sysname NOT NULL , [StatusCode] varchar(40) NOT NULL , [ErrorNumber] int NULL , [Message] nvarchar(2048) NOT NULL",
            "",
        ],
    ]
)
out = io.StringIO(newline="")
csv.writer(out, lineterminator="\n").writerows(rows)
write(resultsets_path, out.getvalue())

release_gate_path = "Code/Tests/Run_Release_Gate.sql"
replace_once(
    release_gate_path,
    "Suiten 120, 121, 122, 123, 190, 191, 196, 198 und 199 sind\n",
    "Suiten 120, 121, 122, 123, QueryStore/120, 190, 191, 196, 198 und 199 sind\n",
)
replace_once(
    release_gate_path,
    ":r QueryStore/110_Test_und_Abnahme_Phase4.sql\n",
    ":r QueryStore/110_Test_und_Abnahme_Phase4.sql\n:r QueryStore/120_Framework_Usage_Runtime_Contract.sql\n",
)

query_store_smoke = "Code/Tests/QueryStore/110_Test_und_Abnahme_Phase4.sql"
replace_once(
    query_store_smoke,
    "EXEC [monitor].[USP_QueryStoreAnalysis] @Hilfe=1;\n",
    "EXEC [monitor].[USP_QueryStoreAnalysis] @Hilfe=1;\nEXEC [monitor].[USP_FrameworkUsageFromQueryStore] @Hilfe=1;\n",
)

guide_path = "Documentation/Analysis_Guides/Procedures/USP_FrameworkUsageFromQueryStore.md"
guide = """# [monitor].[USP_FrameworkUsageFromQueryStore]

**Bereich:** Versionsadaptive Spezialanalysen  
**Zweck:** Aggregiert die sichtbare Nutzung installierter `monitor`-Procedures aus dem Query Store der Frameworkdatenbank.  
**Beobachtungsart:** begrenzter Query-Store-Katalogsnapshot  
**Kostenklasse:** LOW_TO_MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Frage: **Welche Framework-Procedures wurden im sichtbaren Query-Store-Zeitraum ausgeführt, wie häufig und mit welcher aggregierten Last?**

Sie eignet sich für Nutzungsinventur, Schulungs- und Dokumentationspriorisierung sowie eine erste Eigenlastprüfung des Frameworks. Sie erzeugt keine eigene Historie und ändert keine Query-Store-Einstellung.

## Voraussetzungen

- SQL Server 2019 oder neuer.
- Query Store ist in der Frameworkdatenbank lesbar aktiv.
- Der Aufrufer besitzt ausreichende Metadatensichtbarkeit für die Query-Store-Systemviews.
- Retention, Capture Mode, Cleanup und Flushzeitpunkt bestimmen, welche Ausführungen sichtbar sind.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_FrameworkUsageFromQueryStore];
```

Der Standardaufruf liefert höchstens 100 Procedures mit mindestens einer sichtbaren Ausführung.

## Parameter

| Parameter | Typ | Default | Bedeutung |
|---|---|---|---|
| `@MaxZeilen` | int | 100 | Positive Werte begrenzen. `NULL` oder `0` bedeutet unbegrenzt. Negativ ist ungültig. |
| `@MinAusfuehrungen` | bigint | 1 | Mindestanzahl sichtbarer Ausführungen je Procedure. Muss mindestens 1 sein. |
| `@ZeitraumTage` | int | NULL | `NULL` oder `0` verwendet den gesamten sichtbaren Query-Store-Zeitraum. |
| `@LockTimeoutMs` | int | 0 | Lokaler Lock-Timeout für die Katalogzugriffe; 0 bis 60000. Der ursprüngliche Wert wird wiederhergestellt. |
| `@ResultSetArt` | varchar(16) | CONSOLE | `CONSOLE`, `RAW`, `TABLE` oder `NONE`. |
| `@ResultTablesJson` | nvarchar(max) | NULL | Benannte TABLE-Ziele: `moduleStatus`, `usage`, `sourceStatus`, `warnings`. |
| `@JsonErzeugen` | bit | 0 | Erzeugt bei 1 das versionierte JSON-Dokument. |
| `@Json` | nvarchar(max) OUTPUT | NULL | JSON-Ausgabe mit `meta`, `usage`, `sourceStatus` und `warnings`. |
| `@PrintMeldungen` | bit | 1 | Gibt kontrollierte Statusmeldungen mit Severity 10 aus. |
| `@Hilfe` | bit | 0 | Gibt die Hilfe aus und beendet den fachlichen Pfad. |
| `@StatusCodeOut` | varchar(40) OUTPUT | NULL | Gesamtstatus. |
| `@IsPartialOut` | bit OUTPUT | NULL | Kennzeichnet unvollständige Fehler- oder Berechtigungspfade. |
| `@ErrorNumberOut` | int OUTPUT | NULL | Kontrolliert abgefangene Fehlernummer. |
| `@ErrorMessageOut` | nvarchar(2048) OUTPUT | NULL | Kontrolliert abgefangene Fehlermeldung. |

## Resultsets

### `moduleStatus`

Enthält Erfassungszeit, Query-Store-Zustand, Zeitraum, Mindestanzahl, Zeilenanzahl, `HasMoreRows` sowie den Gesamtstatus.

### `usage`

| Spalte | Bedeutung |
|---|---|
| `ProcedureName` | Sichtbare Procedure im Schema `monitor`. |
| `ExecutionCount` | Summe der Query-Store-Ausführungsanzahlen aller erfassten Statements der Procedure. |
| `LastExecutionTime` | Letzter sichtbarer Ausführungszeitpunkt. |
| `AvgDurationMs` | Nach `count_executions` gewichtete durchschnittliche Dauer in Millisekunden. |
| `AvgCpuMs` | Nach `count_executions` gewichtete durchschnittliche CPU-Zeit in Millisekunden. |
| `AvgLogicalReads` | Gewichtete durchschnittliche logische Reads. |
| `AvgMemoryGrantKB` | Gewichteter durchschnittlicher maximal verwendeter Query-Speicher in KB. |
| `PlanCount` | Anzahl unterschiedlicher sichtbarer Query-Store-Pläne. |
| `QueryCount` | Anzahl unterschiedlicher sichtbarer Query-Store-Queries. |
| `FirstSeen` / `LastSeen` | Sichtbare zeitliche Evidenzgrenze. |

### `sourceStatus`

Trennt die Zustandsprüfung des Query Store von der eigentlichen Laufzeitaggregation. Ein fehlgeschlagener Quellenpfad wird nicht als leere Nutzung ausgegeben.

### `warnings`

Enthält kontrollierte Berechtigungs-, Feature- und Lesefehler. Freie Query-Texte und Benutzeridentitäten werden nicht gelesen.

## Leserichtung

1. Zuerst `moduleStatus.StatusCode` und `QueryStoreActualStateDesc` prüfen.
2. `HasMoreRows=1` bedeutet ausschließlich, dass `@MaxZeilen` die Projektion begrenzt hat.
3. `ExecutionCount` ist eine Statement-Aggregation je Procedure und keine Anzahl äußerer `EXEC`-Aufrufe.
4. Dauer, CPU, Reads und Speicher sind gewichtete Query-Store-Intervallaggregate und keine einzelnen Laufzeitmessungen.
5. Mehrere Pläne sind ein Prüfhinweis, aber kein automatischer Nachweis für Parameter-Sensitivität oder Regression.

## Aussagegrenzen und Fehlinterpretationen

- Eine fehlende Procedure beweist nicht, dass sie nie ausgeführt wurde. Capture Mode, Retention, Cleanup, Query-Store-Reset und Metadatensichtbarkeit können Evidenz entfernen oder verhindern.
- Query Store liefert keine Benutzerattribution und keinen verlässlichen Erfolgs- oder Fehlerstatus des äußeren Procedure-Aufrufs.
- Hohe Nutzung oder hohe Durchschnittswerte sind keine automatische Fehlerklassifikation.
- `READ_ONLY` kann weiterhin lesbare Historie liefern; es sagt nichts über die Vollständigkeit zukünftiger Erfassung aus.
- Die Procedure führt kein Flush, Cleanup, `ALTER DATABASE` oder sonstige Schreiboperation aus.

## Beispielaufrufe

```sql
EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
      @ZeitraumTage=30
    , @MaxZeilen=10;

EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
      @MaxZeilen=0
    , @ResultSetArt='RAW';

DECLARE @UsageJson nvarchar(max);
EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
      @ZeitraumTage=7
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@UsageJson OUTPUT;
SELECT @UsageJson;

CREATE TABLE #ModuleStatus([Seed] bit NULL);
CREATE TABLE #Usage([Seed] bit NULL);
CREATE TABLE #SourceStatus([Seed] bit NULL);
CREATE TABLE #Warnings([Seed] bit NULL);

EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
      @ResultSetArt='TABLE'
    , @ResultTablesJson=N'{
        "moduleStatus":"#ModuleStatus",
        "usage":"#Usage",
        "sourceStatus":"#SourceStatus",
        "warnings":"#Warnings"
      }';
```

## Nächste Gegenprüfungen

- `USP_QueryStoreStatus` für Zustand, Größe, Retention und Capture Mode.
- `USP_QueryStoreAnalysis` für detaillierte Query-Store-Evidenz.
- `USP_ServerVersionInformation` für Versions- und Buildkontext.
- `USP_CheckFrameworkCapabilities` für Berechtigungs- und Capability-Grenzen.

## Weiterführend

- [Query Store](../05_Query_Store.md)
- [Scope und Grenzen](../../Reference/Scope_and_Limitations.md)
- [TABLE-Ausgabevertrag](../../Architecture/Database_Console_Table_Contract.md)
"""
write(guide_path, guide)

procedure_reference_path = "Documentation/Reference/Procedure_Reference.md"
procedure_reference = read(procedure_reference_path)
marker = "## `[monitor].[USP_FrameworkUsageFromQueryStore]`"
section = """

## `[monitor].[USP_FrameworkUsageFromQueryStore]`

Quelle: `Code/09_VersionAdaptive/500_USP_FrameworkUsageFromQueryStore.sql`

```sql
@MaxZeilen          int            = 100
    , @MinAusfuehrungen   bigint         = 1
    , @ZeitraumTage       int            = NULL
    , @LockTimeoutMs      int            = 0
    , @ResultSetArt       varchar(16)    = 'CONSOLE'
    , @ResultTablesJson   nvarchar(max)  = NULL
    , @JsonErzeugen       bit            = 0
    , @Json               nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen     bit            = 1
    , @Hilfe              bit            = 0
    , @StatusCodeOut      varchar(40)    = NULL OUTPUT
    , @IsPartialOut       bit            = NULL OUTPUT
    , @ErrorNumberOut     int            = NULL OUTPUT
    , @ErrorMessageOut    nvarchar(2048) = NULL OUTPUT
```
"""
if marker not in procedure_reference:
    write(procedure_reference_path, procedure_reference.rstrip() + section + "\n")

maturity_path = "Metadata/Inventory/Module_Maturity.csv"
rows = list(csv.reader(io.StringIO(read(maturity_path))))
for row in rows:
    if row and row[0] == "Framework Usage":
        row[:] = [
            "Framework Usage",
            "USP_FrameworkUsageFromQueryStore",
            "COMPLETE",
            "YES",
            "YES",
            "YES",
            "",
            "FULL",
            "FRAMEWORK-USAGE-001 mit Hilfe RAW CONSOLE TABLE NONE JSON und Query-Store-Laufzeitvertrag",
        ]
out = io.StringIO(newline="")
csv.writer(out, lineterminator="\n").writerows(rows)
write(maturity_path, out.getvalue())

status_path = "Metadata/Quality/Implementation_Status.csv"
rows = list(csv.reader(io.StringIO(read(status_path))))
for row in rows:
    if row and row[0] == "FRAMEWORK-USAGE-001":
        row[:] = [
            "FRAMEWORK-USAGE-001",
            "IMPLEMENTED_ACTIONS_GATE",
            "Canonical object and result-set inventories @Hilfe weighted Query Store aggregation CONSOLE RAW TABLE NONE JSON source status warnings lock-timeout restoration and three-version runtime contract",
            "",
            "Documentation/Analysis_Guides/Procedures/USP_FrameworkUsageFromQueryStore.md",
        ]
out = io.StringIO(newline="")
csv.writer(out, lineterminator="\n").writerows(rows)
write(status_path, out.getvalue())

next_steps_path = "AI_Metadata/Internal_Documentation/Quality/Next_Steps.md"
next_steps = read(next_steps_path)
old_section = """## 3. Unmittelbar offene Konsistenz- und Produktaufgabe

### FRAMEWORK-USAGE-001 – Frameworknutzung aus Query Store

`monitor.USP_FrameworkUsageFromQueryStore` ist als SQL-Datei vorhanden, wird vom Gesamtinstaller referenziert und besitzt eine ausführliche Procedure-Seite. Der aktuelle Stand ist dennoch nur eine partielle Produktfunktion:

- das Objekt fehlt im kanonischen Objektinventar;
- `@Hilfe` fehlt;
- der dokumentierte JSON-Ausgabepfad wird nicht erzeugt;
- TABLE- und NONE-Verträge sind nicht frameworkkonform abgeschlossen;
- ein benanntes Resultsetinventar und eine Drei-Versionen-Laufzeitmatrix fehlen.

Diese Lücke ist vor einer neuen funktionalen Erweiterung zu schließen, weil bereits ein öffentlich sichtbares und installierbares Objekt betroffen ist.
"""
new_section = """## 3. Abgeschlossene Konsistenz- und Produktwelle

### FRAMEWORK-USAGE-001 – Frameworknutzung aus Query Store

`monitor.USP_FrameworkUsageFromQueryStore` besitzt nun den vollständigen öffentlichen Frameworkvertrag: kanonisches Objekt- und Resultsetinventar, `@Hilfe`, gewichtete Query-Store-Aggregation, sichtbare Quellenlage, CONSOLE, RAW, TABLE, NONE, JSON, Status-OUTPUT-Parameter und Wiederherstellung von `LOCK_TIMEOUT`. Der Begleitvertrag `Code/Tests/QueryStore/120_Framework_Usage_Runtime_Contract.sql` prüft den Vertrag auf SQL Server 2019, 2022 und 2025.
"""
if old_section in next_steps:
    next_steps = next_steps.replace(old_section, new_section, 1)
next_steps = next_steps.replace(
    "1. `FRAMEWORK-USAGE-001` frameworkkonform abschließen.\n2. `SQL25-005` implementieren und dreiversionig testen.\n3. RUNTIME-001-, Windows- und weitere Feature-Evidenz nachziehen.\n4. `OPS-005`, `OPS-006` und `OPS-008` umsetzen.\n5. SSIS-001 Phase 0 abschließen.\n6. `COLL-001` als eigene Querschnittswelle planen und umsetzen.\n7. P3-Erweiterungen nur nach den jeweils erforderlichen externen Entscheidungen ausführen.",
    "1. `SQL25-005` implementieren und dreiversionig testen.\n2. RUNTIME-001-, Windows- und weitere Feature-Evidenz nachziehen.\n3. `OPS-005`, `OPS-006` und `OPS-008` umsetzen.\n4. SSIS-001 Phase 0 abschließen.\n5. `COLL-001` als eigene Querschnittswelle planen und umsetzen.\n6. P3-Erweiterungen nur nach den jeweils erforderlichen externen Entscheidungen ausführen.",
    1,
)
write(next_steps_path, next_steps)
