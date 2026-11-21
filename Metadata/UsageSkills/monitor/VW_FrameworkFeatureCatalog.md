---
skill_format_version: "1.0.0"
name: "monitor.VW_FrameworkFeatureCatalog"
schema_name: "monitor"
object_name: "VW_FrameworkFeatureCatalog"
object_type: "VIEW"
database_role: "framework"
is_internal: false
description: "Stellt einen deklarativen Katalog der Feature-Metadaten, Berechtigungshinweise und statischen Probe- und Enablement-Vorlagen bereit."
source_path: "Code/01_Common/060_VW_FrameworkFeatureCatalog.sql"
---

# monitor.VW_FrameworkFeatureCatalog

## Zweck und Einsatz

Stellt einen deklarativen Katalog der Feature-Metadaten, Berechtigungshinweise und statischen Probe- und Enablement-Vorlagen bereit. Die View führt diese Vorlagen nicht aus und prüft weder Berechtigungen noch Featurezustände.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[VW_FrameworkFeatureCatalog]. Die View stellt fest definierte Frameworkdaten bereit und liest keine DMVs, fremden Kataloge oder Anwendungsdaten; aus einer Katalogzeile folgt keine Berechtigung auf andere Objekte.

## Parameter und Eingabe

Keine Aufrufparameter.

## Resultate und Ausgabe

22 Spalten: 16 Katalogfelder sowie sechs abgeleitete Berechtigungsausgaben; die Reihenfolge entspricht dem SELECT.


## Beispiel

```sql
SELECT TOP (10) * FROM [monitor].[VW_FrameworkFeatureCatalog];
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Ein SELECT wertet die in der View-Definition benannten konstanten oder gelesenen Quellen aus und persistiert keine Daten. Ein CREATE OR ALTER VIEW ändert nur die View-Definition.

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.VW_FrameworkFeatureCatalog
Version      : 1.7.0
Stand        : 2026-07-14
Typ          : View
Zweck        : Stellt einen deklarativen Katalog der Feature-Metadaten,
               Berechtigungshinweise und statischen Probe- und
               Enablement-Vorlagen bereit. Die View führt diese Vorlagen
               nicht aus und prüft weder Berechtigungen noch Featurezustände.
Parameter    : Keine.
Resultset    : 22 Spalten: 16 Katalogfelder sowie sechs abgeleitete
               Berechtigungsausgaben; die Reihenfolge entspricht dem SELECT.

Katalogfelder (Werte und Bedeutung):
- FeatureOrdinal (smallint) ist ein Hinweis für die Anzeige; er garantiert
  keine intrinsische Sortierung. FeatureCode (varchar(64)) ist der Code,
  FeatureName (nvarchar(200)) die lesbare Bezeichnung.
- ScopeType (varchar(16)) bezeichnet SERVER oder DATABASE. AnalysisClass
  (varchar(64)) gruppiert Features; AnalysisLevel (varchar(16)) und
  IsResourceIntensive (bit) sind deklarierte Hinweise, keine Laufzeitmessung.
- MinimumMajorVersion (tinyint) nennt die deklarierte Mindestversion.
  Sie qualifiziert weder die tatsächliche Engineversion noch Verfügbarkeit,
  Zustand oder Berechtigung des Features.
- PermissionScopeBeforeSql2022 und PermissionScopeFromSql2022
  (varchar(16)) nennen den deklarierten Scope der jeweiligen
  Berechtigungshinweise. PermissionBeforeSql2022 und PermissionFromSql2022
  (nvarchar(128)) bewahren deren Anzeigetext. Beide Varianten werden stets
  ausgegeben; die View wählt nicht anhand der Laufzeitversion aus.
- ExpectedWithoutPermission (varchar(32)) enthält die Literaloptionen
  ERROR, LIMITED und ERROR_OR_LIMITED. Sie beschreiben die deklarierte
  Erwartung ohne Berechtigung, nicht ein von der View festgestelltes Ergebnis.
- ProbeSqlTemplate und EnablementSqlTemplate (nvarchar(2000)) sind statische
  Textvorlagen. Ein Datenbankmarker in einer Vorlage ist gespeicherter Text;
  seine Ersetzung oder Ausführung ist keine Funktion dieser View.
  EnablementSqlTemplate kann NULL sein; NULL bedeutet hier keine angegebene
  Vorlage und keinen nachgewiesenen Fehler.
- Description (nvarchar(1000)) enthält die deklarierte Featurebeschreibung.

Abgeleitete Berechtigungsausgaben:
- PermissionCheckTypeBeforeSql2022 und PermissionCheckTypeFromSql2022
  (varchar(24)) enthalten HAS_PERMS_BY_NAME, wenn der jeweilige Hinweis exakt
  einem dieser sieben Namen entspricht: VIEW SERVER STATE,
  VIEW SERVER PERFORMANCE STATE, VIEW DATABASE STATE,
  VIEW DATABASE PERFORMANCE STATE, VIEW ANY DEFINITION,
  VIEW ANY DATABASE oder VIEW DEFINITION. Sonst lautet der Wert PROBE_ONLY.
- PermissionNameBeforeSql2022 und PermissionNameFromSql2022 (sysname) geben
  bei einem dieser Namen den Namen aus, andernfalls NULL. Die zugehörigen
  PermissionDisplayTextBeforeSql2022 und PermissionDisplayTextFromSql2022
  bewahren den jeweiligen ursprünglichen Anzeigetext unverändert.

Die Kennzeichnung HAS_PERMS_BY_NAME ist eine Klassifikation des Textwerts;
die View ruft HAS_PERMS_BY_NAME nicht auf. PROBE_ONLY kennzeichnet ebenfalls
nur die Klassifikation und führt keine Probe aus. Die Katalogwerte belegen
weder vorhandene Berechtigungen noch Vollständigkeit oder einen Zustand.
Insbesondere ist aus einem Probe-Template keine günstige oder folgenlose
Ausführung abzuleiten.

Aufruf       : SELECT [FeatureOrdinal], [FeatureCode], [FeatureName],
                      [ScopeType], [AnalysisClass], [AnalysisLevel],
                      [IsResourceIntensive], [MinimumMajorVersion],
                      [PermissionScopeBeforeSql2022],
                      [PermissionScopeFromSql2022],
                      [PermissionBeforeSql2022], [PermissionFromSql2022],
                      [PermissionCheckTypeBeforeSql2022],
                      [PermissionNameBeforeSql2022],
                      [PermissionDisplayTextBeforeSql2022],
                      [PermissionCheckTypeFromSql2022],
                      [PermissionNameFromSql2022],
                      [PermissionDisplayTextFromSql2022],
                      [ExpectedWithoutPermission], [ProbeSqlTemplate],
                      [EnablementSqlTemplate], [Description]
               FROM [monitor].[VW_FrameworkFeatureCatalog] WITH (NOLOCK)
               ORDER BY [FeatureOrdinal];
Berechtigung : SELECT auf der View. Die genannten Berechtigungen sind Hinweise;
               die View führt keine Berechtigungsprüfung, Probe, Vorlage oder
               Enablement-SQL aus und führt niemals GRANT, DENY oder REVOKE aus.
Eigenlast    : Die View liest deklarative Werte und enthält keine Abfrage von
               Metadaten- oder Systemkatalogen. Zur Eigenlast einer späteren
               Ausführung ausgegebener Probe-Texte trifft sie keine Aussage.
Änderungen   : 1.7.0 - Maschinenlesbare PermissionCheckType-/PermissionName-Spalten ergänzt; freie Hinweistexte werden nur noch per Probe geprüft.
               1.6.0 - Phase-6-Quellen für Agent, Resource Governor, HA/DR, Backup, Replication, CDC und Change Tracking ergänzt.
               1.5.0 - Extended-Events-Katalog, Targetruntime, Filezugriff, Deadlocks und Blocked-Process-Reports differenziert.
               1.4.0 - Query-Store-Status, Runtime, Waits, Pläne, Forced Plans und SQL-2022-Hints getrennt katalogisiert.
               1.3.0 - Plan-Cache-, Planattribut-, Showplan-, Last-Actual- und Live-Plan-Capabilities präzisiert.
               1.2.0 - Index Operational Stats und In-Memory-OLTP-Indexnutzung ergänzt.
               1.1.0 - Phase-2-Objekt-, Statistik-, Partitions- und Columnstore-Quellen ergänzt.
               1.0.0 - Erstfassung Phase 1A.
```

