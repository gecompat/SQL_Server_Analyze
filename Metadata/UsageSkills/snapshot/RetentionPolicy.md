---
skill_format_version: "1.0.0"
name: "snapshot.RetentionPolicy"
schema_name: "snapshot"
object_name: "RetentionPolicy"
object_type: "TABLE"
database_role: "snapshot_target"
is_internal: false
description: "Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank."
source_path: "Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql"
---

# snapshot.RetentionPolicy

## Zweck und Einsatz

Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank. Das Schema speichert Erfassungsläufe, Status, Scopes, typisierte Messwerte und optionale Nutzdaten. Es startet weder Sammler noch Zeitpläne oder Retention-Purges.

## Voraussetzungen und Rechte

Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das Ziel und verwendet ausschließlich den geprüften Verbindungskontext.

CONTROL DATABASE und VIEW ANY DEFINITION sind für die native Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.

Lesender Einsatz erfordert SELECT auf [snapshot].[RetentionPolicy]; Installation und Aktualisierung benötigen die im Quellskript gezeigten DDL- und DML-Rechte.

## Parameter und Eingabe

Keine Aufrufparameter.

## Resultate und Ausgabe

Tabellenspalten und Constraints aus der eigenen CREATE-TABLE-Definition:

```sql
(
          [RetentionPolicyCode] varchar(64) NOT NULL
        , [RawRetentionDays] smallint NOT NULL
        , [PayloadRetentionDays] smallint NOT NULL
        , [RollupRetentionDays] smallint NOT NULL
        , [SoftBudgetMB] bigint NOT NULL
        , [PurgeIntervalMinutes] int NOT NULL
        , [PurgeBatchRows] int NOT NULL
        , [BudgetAction] varchar(40) NOT NULL
        , [IsFrameworkDefault] bit NOT NULL
              CONSTRAINT [DF_snapshot_RetentionPolicy_IsFrameworkDefault]
              DEFAULT (0)
        , [SeedVersion] int NOT NULL
        , [LastUpdatedUtc] datetime2(3) NOT NULL
              CONSTRAINT [DF_snapshot_RetentionPolicy_LastUpdatedUtc]
              DEFAULT (SYSUTCDATETIME())
        , CONSTRAINT [PK_snapshot_RetentionPolicy]
              PRIMARY KEY CLUSTERED ([RetentionPolicyCode])
        , CONSTRAINT [CK_snapshot_RetentionPolicy_RawRetentionDays]
              CHECK ([RawRetentionDays] BETWEEN 1 AND 36500)
        , CONSTRAINT [CK_snapshot_RetentionPolicy_PayloadRetentionDays]
              CHECK ([PayloadRetentionDays] BETWEEN 1 AND 36500)
        , CONSTRAINT [CK_snapshot_RetentionPolicy_RollupRetentionDays]
              CHECK ([RollupRetentionDays] BETWEEN 1 AND 36500)
        , CONSTRAINT [CK_snapshot_RetentionPolicy_SoftBudgetMB]
              CHECK ([SoftBudgetMB] > 0)
        , CONSTRAINT [CK_snapshot_RetentionPolicy_PurgeIntervalMinutes]
              CHECK ([PurgeIntervalMinutes] BETWEEN 1 AND 10080)
        , CONSTRAINT [CK_snapshot_RetentionPolicy_PurgeBatchRows]
              CHECK ([PurgeBatchRows] BETWEEN 1 AND 100000)
        , CONSTRAINT [CK_snapshot_RetentionPolicy_BudgetAction]
              CHECK ([BudgetAction] = 'PURGE_EXPIRED_THEN_STOP')
        , CONSTRAINT [CK_snapshot_RetentionPolicy_SeedVersion]
              CHECK ([SeedVersion] > 0)
    )
```


## Beispiel

```sql
SELECT TOP (10) * FROM [snapshot].[RetentionPolicy];
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Das zugehörige Installationsskript enthält CREATE TABLE, INSERT, UPDATE, DELETE; ein lesendes SELECT führt diese Installationsschritte nicht aus. Constraints und NULL-Grenzen stehen in der Tabellendefinition.

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Datei        : 030_Snapshot_Target_Schema.sql
Version      : 1.2.2
Stand        : 2026-10-26
Zweck        : Erstellt und aktualisiert das versionierte Basisschema des
               optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell
               verbundenen Datenbank. Das Schema speichert Erfassungsläufe,
               Status, Scopes, typisierte Messwerte und optionale Nutzdaten.
               Es startet weder Sammler noch Zeitpläne oder Retention-Purges.

Tabellen     : PackageVersion kennzeichnet Paket- und Schemafassung sowie
               Erstinstallation und letzten Installationslauf. RetentionPolicy
               hält Aufbewahrungsfristen für Rohwerte, Nutzdaten und Rollups,
               Speicherbudget, Purge-Takt, Batchgröße und Budgetaktion.
               CollectorPolicy beschreibt Aktivierung, Intervall, Zeilenlimit,
               Nutzdatenerfassung und zugeordnete RetentionPolicy.
               CaptureRun protokolliert Sammler, Schedulerart, Start und Ende,
               Quelldatenbankname, SQL-Server-Startzeit, Reset-Epoche,
               Vertragsfassung, Status, Partialität, Fehler und Zeilenzähler.
               ModuleStatus hält je Lauf und Modul Zeitpunkt, Status, Partial-
               und Fehlerangaben sowie Evidenzgrenzen.
               Scope ordnet Messungen über Scope-Typ, optionalen Eltern-Scope,
               32-Byte-Schlüsselhash und JSON-Identität einem Erfassungsbereich
               zu. MetricDefinition beschreibt Metrikcode, Werttyp, Einheit,
               Vertragsfassung, Text, Framework-Default und Seedfassung.
               MetricSample verbindet Lauf, Scope und Metrik mit Messzeit,
               Reset-Epoche, genau einem typisierten Wert, Qualitätscode und
               Partialitätskennzeichen. PayloadSnapshot speichert optionale,
               Modulnutzdaten mit Format, Vertragsfassung, Hash
               und unkomprimierter Zeichenanzahl. PurgeRun protokolliert
               Aufräumlauf, Status, Batches, gelöschte Zeilen, Budgetmessung
               und Fehler.

Beziehungen  : Fremdschlüssel verbinden CollectorPolicy mit RetentionPolicy,
               CaptureRun mit CollectorPolicy, ModuleStatus und PayloadSnapshot
               mit CaptureRun sowie MetricSample mit CaptureRun, Scope und
               MetricDefinition. Scope kann auf einen Eltern-Scope verweisen.
               Primär- und eindeutige Schlüssel verhindern doppelte
               Policycodes, Modulstatus je Lauf/Modul sowie Messwerte je
               Lauf/Scope/Metrik. Ein gefilterter eindeutiger Index lässt
               höchstens eine RetentionPolicy als Framework-Default zu;
               Zeit- und Zuordnungsindizes unterstützen die im Schema
               vorgesehenen Lauf-, Messwert-, Nutzdaten- und Purgeabfragen.
               Die DDL definiert keine kaskadierenden Fremdschlüssel.

Werte        : UTC-Zeitfelder geben den jeweiligen Erfassungs-, Lauf- oder
               Änderungszeitpunkt an. NULL ist bei Endzeiten, optionalen
               Start-/Resetinformationen, Fehlerfeldern und alternativen
               Messwertspalten zulässig, soweit die DDL dies festlegt.
               NumericValue, BigintValue und StringValue sind Alternativen:
               MetricSample verlangt genau einen nicht-NULL-Wert. ValueType
               und Unit in MetricDefinition beschreiben dessen Interpretation;
               der Vertrag garantiert keine Umrechnung. ResetEpochId grenzt
               Zählerstände über eine Reset-Epoche ab. QualityCode, StatusCode
               und IsPartial erhalten Qualitäts-, Ablauf- und
               Vollständigkeitsangaben. ScopeIdentityJson muss JSON sein;
               ScopeKeyHash ist genau 32 Byte lang. PayloadHash ist ebenfalls
               32 Byte lang; PayloadFormat und CompressionType sind auf die
               im Schema genannten Werte beschränkt.

Migration    : Die native Vorprüfung akzeptiert nur erkannte Schemaformen.
               Für erkannte Legacy- und Schema-2-Stände erweitert sie die
               CollectorCode- und ScopeType-Prüfwerte um FILE_IO
               beziehungsweise FILE_IO_FILE. Unbekannte oder abweichende
               Strukturen werden nicht beliebig repariert oder überschrieben.
               Paketversion 1.2.2 / Schema 3 kennzeichnet Installationsmetadaten,
               nicht die Laufzeitqualifikation oder Freigabe des Pakets.

Seeds        : Neue DEFAULT-Retention-, PERFORMANCE_COUNTERS-Policy- und
               Performance-Counter-Metrikzeilen werden nur eingefügt, wenn
               ihr jeweiliger Schlüssel fehlt. Vorhandene solche Zeilen bleiben
               erhalten. PackageVersion wird für SC-023 angelegt oder auf
               Paketversion 1.2.2 und Schema 3 gesetzt; InstalledAtUtc bleibt
               bei einem vorhandenen Datensatz unverändert, während
               LastInstallerRunUtc aktualisiert wird.

Voraussetzung: Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare
               Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das
               Ziel und verwendet ausschließlich den geprüften Verbindungskontext.
Datenschutz  : Die Tabellen dürfen im autorisierten Betrieb vollständige reale
               Laufzeitevidenz einschließlich optionaler Payloads speichern.
               Dieses Installationsskript enthält nur generische Seeds und
               keine Laufzeitwerte oder Datenbanknamen.
Transaktion  : Implizite Transaktionen müssen ausgeschaltet sein. Das Skript
               verwendet bei Bedarf eine eigene Transaktion, andernfalls einen
               Savepoint. Im Fehlerfall wird die eigene Transaktion bei
               XACT_STATE() ungleich 0 zurückgerollt; im Aufruferkontext nur
               bei XACT_STATE() = 1 bis zum Savepoint. Bei XACT_STATE() = -1
               kann dieser Savepoint-Rollback nicht erfolgen; ein allgemeiner
               Rollback der Aufrufertransaktion wird nicht zugesichert.
               Die gesetzten SET-Optionen gelten für die verbundene Sitzung;
               das Skript stellt deren vorherige Werte nicht wieder her.
Locking      : Die privilegierte native Strukturvorprüfung verwendet
               LOCK_TIMEOUT 10000 und hält geprüfte Tabellen bis zum
               Transaktionsende. Die anschließende eigene DDL verwendet
               LOCK_TIMEOUT 0 und wartet nicht auf fremde Sch-M-Sperren.
Rechte       : CONTROL DATABASE und VIEW ANY DEFINITION sind für die native
               Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.
```

