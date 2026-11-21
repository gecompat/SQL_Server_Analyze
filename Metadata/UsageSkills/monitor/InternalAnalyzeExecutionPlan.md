---
skill_format_version: "1.0.0"
name: "monitor.InternalAnalyzeExecutionPlan"
schema_name: "monitor"
object_name: "InternalAnalyzeExecutionPlan"
object_type: "INTERNAL_PROCEDURE"
database_role: "framework"
is_internal: true
description: "Die Procedure zerlegt genau ein vom Aufrufer geliefertes Showplan-XML mit unterstützten StmtSimple-Elementen in die vorbereiteten lokalen #ExecutionPlanAnalysis_*-Tabellen."
source_path: "Code/04_PlanCache/051_InternalAnalyzeExecutionPlan.sql"
---

# monitor.InternalAnalyzeExecutionPlan

## Zweck und Einsatz

Die Procedure zerlegt genau ein vom Aufrufer geliefertes Showplan-XML mit unterstützten StmtSimple-Elementen in die vorbereiteten lokalen #ExecutionPlanAnalysis_*-Tabellen.

## Voraussetzungen und Rechte

Der Aufrufer stellt 19 lokale Ergebnistabellen mit dem vereinbarten Schema bereit. 19 SELECT TOP (0)-Probes erzeugen 19 leere Resultsets und testen den Tabellenzugriff, nicht die vollständige Schemakompatibilität. Die Procedure führt keine Plananweisung aus und beschafft oder löst keine Planquelle über einen Katalog auf. Spätere Fehler nehmen bereits geschriebene Teilergebnisse nicht atomar zurück.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @AnalysisObjectId | int | ja | kein Default |
| @PlanXml | xml | ja | kein Default |
| @PlanSource | varchar(24) | ja | kein Default |
| @RuntimeCounterScope | varchar(32) | ja | kein Default |
| @WorkloadProfile | varchar(32) | nein | 'BALANCED' |
| @MinSeverity | varchar(16) | nein | 'INFO' |
| @EvidenceJson | nvarchar(max) | nein | NULL |
| @MitThreadRuntime | bit | nein | 0 |
| @EvidenzDatenschutzModus | varchar(24) | nein | 'DERIVED_ONLY' |
| @IdentifierDatenschutzModus | varchar(16) | nein | 'RAW' |
| @SourceObservedAtUtc | datetime2(3) | nein | NULL |
| @ParameterEvidenceSessionId | smallint | nein | NULL |
| @ParameterEvidenceRequestId | int | nein | NULL |
| @PlanHandle | varbinary(64) | nein | NULL |
| @QueryStoreDatabaseName | sysname | nein | NULL |
| @QueryStorePlanId | bigint | nein | NULL |
| @StatusCodeOut | varchar(40) OUTPUT | nein | NULL |
| @IsPartialOut | bit OUTPUT | nein | NULL |
| @ErrorNumberOut | int OUTPUT | nein | NULL |
| @ErrorMessageOut | nvarchar(2048) OUTPUT | nein | NULL |
| @Hilfe | bit | nein | 0 |

**@AnalysisObjectId:** - @AnalysisObjectId int, Eingabe, erforderlich, kein Default: positive Kennung für Ergebniszeilen. NULL, '' (als int gebunden: 0) und jeder Wert < 1 ergeben INVALID_PARAMETER. Zulässig sind 1 bis 2147483647.

**@PlanXml:** - @PlanXml xml, Eingabe, erforderlich, kein Default: Showplan-XML. NULL ergibt INVALID_PARAMETER. '' wird als leeres XML gebunden und enthält kein StmtSimple; das ergibt UNAVAILABLE_OBJECT und Partialität. Die Suche verwendet local-name(.) für StmtSimple und validiert kein bestimmtes Root-Element oder Namespace.

**@PlanSource:** - @PlanSource varchar(24), Eingabe, erforderlich, kein Default: Codes IMPORTED (importiertes XML), COMPILE (Kompilierungsplan), LAST_ACTUAL (letzter Actual Plan), CURRENT_ACTUAL (aktueller Actual Plan), QUERY_STORE (Query-Store-Plan). '' und NULL sind ungültig und ergeben INVALID_PARAMETER. Keine Normalisierung. Der Wert klassifiziert die Quelle und beschafft keinen Plan.

**@RuntimeCounterScope:** - @RuntimeCounterScope varchar(32), Eingabe, erforderlich, kein Default: Codes NONE (keine Runtimecounter beansprucht), LAST_COMPLETED_EXECUTION (letzte abgeschlossene Ausführung), CURRENT_PARTIAL_EXECUTION (aktuelle möglicherweise unvollständige Ausführung), IMPORTED_ACTUAL (importiertes Actual-Plan-XML), QUERY_STORE_AGGREGATE (aggregierte Query-Store-Zuordnung), UNKNOWN (Scope unbekannt). '' und NULL sind ungültig und ergeben INVALID_PARAMETER. Keine Normalisierung. Klassifiziert die gelieferten Daten, beschafft oder verifiziert aber keine Runtimecounter.

**@WorkloadProfile:** - @WorkloadProfile varchar(32), Eingabe, Default 'BALANCED': offene, tabellengesteuerte Allowlist monitor.PlanAnalysisProfile. NULL wird BALANCED; Rand-Leerraum wird entfernt und Großschreibung hergestellt. Unbekannte, deaktivierte und leere Werte fallen auf BALANCED zurück. Seedprofile: LATENCY_SENSITIVE gewichtet interaktive/ häufige Zugriffe je Ausführung und Wiederholungsrate stärker; BALANCED ist neutral für gemischte Workloads ohne belastbare Zuordnung; THROUGHPUT gewichtet absolute CPU-, I/O-, TempDB- und Datenmengen stärker; MAINTENANCE behandelt große Scans und Sorts bei Wartung/Strukturänderungen als möglicherweise erwartet; UNKNOWN bleibt konservativ und weist geringe Zuordnungssicherheit aus. Weitere aktive Codes sind möglich.

**@MinSeverity:** - @MinSeverity varchar(16), Eingabe, Default 'INFO': INFO (informativ), LOW (niedrig), MEDIUM (mittel), HIGH (hoch), CRITICAL (kritisch/höchste Stufe). NULL wird INFO; Rand-Leerraum wird entfernt und Großschreibung hergestellt. '' und andere Werte sind ungültig. Filtert Findings und PlanWarnings unterhalb der Schwelle; NO_EXPLICIT_WARNING bleibt zunächst ausgenommen. Ein Hinweis kann melden, dass keine Warnung die Schwelle erreicht. Keine Aussage über Planoptimalität oder fehlende Quelle.

**@EvidenceJson:** - @EvidenceJson nvarchar(max), Eingabe, Default NULL: optionale externe STATISTICS IO/TIME-Evidenz. NULL lässt die Evidenz aus. '' ist ungültige JSON-Syntax und setzt Partialität mit Capability EXECUTION_EVIDENCE_JSON/INVALID_JSON. Syntaktisch gültiges JSON wird nicht schemaweit validiert; lax OPENJSON-Pfade mit fehlenden oder falsch geformten Werten können leere/unerkannte Teilergebnisse liefern. Zusätzliche Felder werden ignoriert; Pfadnamen sind case-sensitive. Ungültige Typkonvertierungen können ERROR_HANDLED auslösen. Negative Dezimalwerte werden nicht gefiltert; confidence, timeCategory und parseStatus haben keine geprüfte Werteliste. Pfade und Typen: $.capture.sameExecutionConfidence (Text, Fallback UNCONFIRMED); $.statisticsIo[*].statementOrdinal int, objectDisplayName nvarchar(512), logicalReads/physicalReads/readAheadReads/scanCount decimal(38,4), parseStatus varchar(40); $.statisticsTime[*].statementOrdinal int, timeCategory varchar(24), cpuMs/elapsedMs decimal(38,4), parseStatus varchar(40). Nicht-NULL IO-Werte werden als pages-Metriken, Zeitwerte als ms ausgegeben. Confidence belegt keine gleiche Ausführung. Synthetisches Beispiel: {"capture":{"sameExecutionConfidence":"UNCONFIRMED"},"statisticsIo":[{"statementOrdinal":1,"objectDisplayName":"[dbo].[Sample]","logicalReads":12,"physicalReads":0,"readAheadReads":0,"scanCount":1,"parseStatus":"PARSED"}],"statisticsTime":[{"statementOrdinal":1,"timeCategory":"SQL","cpuMs":2.5,"elapsedMs":3,"parseStatus":"PARSED"}]}

**@MitThreadRuntime:** - @MitThreadRuntime bit, Eingabe, Default 0: 0 löscht die Threadzeilen nach ihrer Materialisierung und der Ableitung aggregierter Runtimewerte; 1 behält sie. NULL ergibt INVALID_PARAMETER. Numerische Werte ungleich 0 werden bei Bindung zu 1; '' kann zu 0 konvertieren.

**@EvidenzDatenschutzModus:** - @EvidenzDatenschutzModus varchar(24), Eingabe, Default 'DERIVED_ONLY': geschlossene Codes DERIVED_ONLY (Werte weglassen, abgeleitete Evidenz führen), TOKENIZED (Werte weglassen, vorhandene Werte mit frischem lokalem Zufallssalt tokenisieren), RAW (Werte im Klartext) und STRUCTURE_ONLY (Werte weglassen, Strukturstatus setzen). NULL wird DERIVED_ONLY; äußere U+0020-Leerzeichen entfernen und Großschreibung. '' ist ungültig. DERIVED_ONLY und STRUCTURE_ONLY lassen dieselben Wertespalten leer, unterscheiden sich aber im ValueHandlingStatus. SQL-NULL-Werte werden markiert und nicht tokenisiert. Keine globale Redaktion anderer Planwerte oder Namen.

**@IdentifierDatenschutzModus:** - @IdentifierDatenschutzModus varchar(16), Eingabe, Default 'RAW': RAW (Objektanzeige übernehmen), TOKENIZED (mit frischem lokalem Zufallssalt tokenisieren), OMIT (weglassen). NULL wird RAW; äußere U+0020-Leerzeichen entfernen und Großschreibung. '' ist ungültig. Wirkt nur auf statisticsIo.objectDisplayName als Scope-Bezeichnung, nicht global.

**@SourceObservedAtUtc:** - @SourceObservedAtUtc datetime2(3), Eingabe, Default NULL: Zeitpunkt nach UTC-Konvention. Auslassen/NULL setzt SYSUTCDATETIME(). Ein expliziter Wert wird als UTC-Konvention übernommen, aber nicht umgerechnet oder als tatsächliche Quellzeit verifiziert. '' wird nach SQL-Typbindungsregeln behandelt; die Procedure prüft den resultierenden Wert nicht auf Herkunft oder UTC-Abweichung. Eingabe als datetime2-Variable oder ISO-Text, etwa 2000-01-01T00:00:00.000.

**@ParameterEvidenceSessionId:** - @ParameterEvidenceSessionId smallint, Eingabe, Default NULL: Session-Skalar im ParameterEvidence-Kontext. Signed smallint-Bereich -32768 bis 32767, einschließlich negativer und null Werte; keine Positivitätsprüfung. NULL bleibt NULL; '' als smallint gebunden wird 0. Keine DMV-Abfrage oder Sessionauflösung.

**@ParameterEvidenceRequestId:** - @ParameterEvidenceRequestId int, Eingabe, Default NULL: Request-Skalar im ParameterEvidence-Kontext. Signed int-Bereich -2147483648 bis 2147483647; keine Positivitätsprüfung. NULL bleibt NULL; '' als int gebunden wird 0. Keine Requestauflösung.

**@PlanHandle:** - @PlanHandle varbinary(64), Eingabe, Default NULL: Binärwert, als varbinary-Variable oder SQL-0x-Hexwert zu binden; 0x bezeichnet einen leeren Handle. Der Typ begrenzt den gebundenen Wert auf 64 Bytes; die Procedure führt keine eigene Längenprüfung aus. NULL bleibt NULL. Kein Textpfad, keine Suche oder Auflösung über den Handle.

**@QueryStoreDatabaseName:** - @QueryStoreDatabaseName sysname, Eingabe, Default NULL: einzelner unquotierter Unicode-Datenbankname im sysname-Typ (nvarchar(128)); keine Liste oder Identifier-Syntax. '' wird unverändert akzeptiert; NULL bleibt NULL. Keine Auflösung und keine Query-Store-Abfrage.

**@QueryStorePlanId:** - @QueryStorePlanId bigint, Eingabe, Default NULL: Plan-ID als Kontextskalar. Signed bigint-Bereich -9223372036854775808 bis 9223372036854775807; keine Positivitätsprüfung. NULL bleibt NULL; '' als bigint gebunden wird 0. Keine Query-Store-Abfrage oder Planbeschaffung.

**@StatusCodeOut:** - @StatusCodeOut varchar(40), OUTPUT, Signatur-Default NULL: Eingabewert (auch NULL oder '') wird ignoriert; ausgelassen ist der Default NULL. Ohne OUTPUT wird die Ausgabe verworfen; zum Empfang varchar(40)-Variable mit OUTPUT binden. Initialwert AVAILABLE. Endwerte: AVAILABLE (ohne Partialitätskennzeichen beendet), PARTIAL (Hauptanalyse abgeschlossen und Partialitätsflag gesetzt), INVALID_PARAMETER (validierter Eingabefehler), UNAVAILABLE_OBJECT (kein unterstütztes StmtSimple), INTERNAL_ERROR (lokale Ergebnistabelle fehlt oder ist nicht zugreifbar), ERROR_HANDLED (abgefangener späterer Fehler). Profilabfrage und eigene Temp-Anlage können außerhalb dieses Statuspfads fehlschlagen. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@IsPartialOut:** - @IsPartialOut bit, OUTPUT, Signatur-Default NULL: Eingabewert (auch NULL oder '', sofern als bit gebunden) wird ignoriert; ausgelassen ist der Default NULL. Ohne OUTPUT wird die Ausgabe verworfen; zum Empfang bit-Variable mit OUTPUT binden. Initialwert 0. 1 kennzeichnet unter anderem ungültige Eingabe, fehlende Statements, ungültiges JSON oder abgefangene Fehler; bei regulärem Abschluss wird AVAILABLE zu PARTIAL. NULL ist kein regulärer Ausgangswert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorNumberOut:** - @ErrorNumberOut int, OUTPUT, Signatur-Default NULL: Eingabewert (auch NULL oder '', sofern als int gebunden) wird ignoriert; ausgelassen ist der Default NULL. Ohne OUTPUT wird die Ausgabe verworfen; zum Empfang int-Variable mit OUTPUT binden. Initialwert NULL; nur Fehlerpfade mit erfasster SQL-Fehlernummer setzen einen Wert. Bei PARTIAL ohne abgefangenen SQL-Fehler kann die Ausgabe NULL bleiben. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorMessageOut:** - @ErrorMessageOut nvarchar(2048), OUTPUT, Signatur-Default NULL: Eingabewert (auch NULL oder '') wird ignoriert; ausgelassen ist der Default NULL. Ohne OUTPUT wird die Ausgabe verworfen; zum Empfang nvarchar(2048)-Variable mit OUTPUT binden. Initialwert NULL; nur belegte Meldungspfade setzen Text. Bei PARTIAL ohne expliziten Meldungspfad kann die Ausgabe NULL bleiben. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Die 19 TOP (0)-Probes der vom Aufrufer bereitgestellten #ExecutionPlanAnalysis_*-Tabellen erzeugen 19 leere Schema-Resultsets. Die Analyse schreibt normalisierte Plan-, Warnungs- und Evidenzzeilen in diese lokalen Tabellen; sie beschafft und führt keinen Plan aus. `@StatusCodeOut` (varchar(40) OUTPUT) beginnt AVAILABLE und kann AVAILABLE, PARTIAL, INVALID_PARAMETER, UNAVAILABLE_OBJECT, INTERNAL_ERROR oder ERROR_HANDLED liefern. `@IsPartialOut` (bit OUTPUT) kennzeichnet Teilbefunde, `@ErrorNumberOut` (int OUTPUT) und `@ErrorMessageOut` (nvarchar(2048) OUTPUT) beschreiben behandelte Fehler und können bei PARTIAL ohne solchen Fehler NULL bleiben. Die TOP (0)-Probes beweisen Tabellenauflösung, nicht volle Schemakompatibilität; spätere Fehler rollen bereits geschriebene lokale Zeilen nicht atomar zurück.

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.


## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalAnalyzeExecutionPlan';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [monitor].[InternalAnalyzeExecutionPlan] @AnalysisObjectId=NULL, @PlanXml=NULL, @PlanSource=NULL, @RuntimeCounterScope=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Objekt       : monitor.InternalAnalyzeExecutionPlan
Version      : 1.2.1
Stand        : 2026-10-14
Typ          : Interne Stored Procedure
Zweck        : Die Procedure zerlegt genau ein vom Aufrufer geliefertes Showplan-XML
               mit unterstützten StmtSimple-Elementen in die vorbereiteten
               lokalen #ExecutionPlanAnalysis_*-Tabellen.
Voraussetzung: Der Aufrufer stellt 19 lokale Ergebnistabellen mit dem vereinbarten
               Schema bereit. 19 SELECT TOP (0)-Probes erzeugen 19 leere
               Resultsets und testen den Tabellenzugriff, nicht die vollständige
               Schemakompatibilität. Die Procedure führt keine Plananweisung aus und
               beschafft oder löst keine Planquelle über einen Katalog auf.
               Spätere Fehler nehmen bereits geschriebene Teilergebnisse nicht
               atomar zurück.

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.InternalAnalyzeExecutionPlan
Version      : 1.2.1
Stand        : 2026-10-14
Typ          : Interne Stored Procedure
Zweck        : Die Procedure zerlegt genau ein vom Aufrufer geliefertes Showplan-XML
               mit unterstützten StmtSimple-Elementen in die vorbereiteten
               lokalen #ExecutionPlanAnalysis_*-Tabellen.
Voraussetzung: Der Aufrufer stellt 19 lokale Ergebnistabellen mit dem vereinbarten
               Schema bereit. 19 SELECT TOP (0)-Probes erzeugen 19 leere
               Resultsets und testen den Tabellenzugriff, nicht die vollständige
               Schemakompatibilität. Die Procedure führt keine Plananweisung aus und
               beschafft oder löst keine Planquelle über einen Katalog auf.
               Spätere Fehler nehmen bereits geschriebene Teilergebnisse nicht
               atomar zurück.

Parametervertrag
Die vier ersten Parameter sind erforderlich. Alle folgenden Parameter haben den in der
Signatur angegebenen Default; sie können ausgelassen werden. Ein OUTPUT-Parameter
kann auch als typisierter Skalar oder NULL ohne OUTPUT übergeben werden; der
Eingabewert wird ignoriert und die Ausgabe verworfen. Zum Empfang ist eine Variable
des angegebenen Typs mit OUTPUT zu binden. Typkonvertierung erfolgt vor dem
Prozedureintritt; Konvertierungsfehler sind nicht allgemein durch den Prozedur-CATCH
abgedeckt.

- @AnalysisObjectId int, Eingabe, erforderlich, kein Default: positive Kennung für
  Ergebniszeilen. NULL, '' (als int gebunden: 0) und jeder Wert < 1 ergeben
  INVALID_PARAMETER. Zulässig sind 1 bis 2147483647.
- @PlanXml xml, Eingabe, erforderlich, kein Default: Showplan-XML. NULL ergibt
  INVALID_PARAMETER. '' wird als leeres XML gebunden und enthält kein StmtSimple;
  das ergibt UNAVAILABLE_OBJECT und Partialität. Die Suche verwendet local-name(.)
  für StmtSimple und validiert kein bestimmtes Root-Element oder Namespace.
- @PlanSource varchar(24), Eingabe, erforderlich, kein Default: Codes IMPORTED
  (importiertes XML), COMPILE (Kompilierungsplan), LAST_ACTUAL (letzter Actual Plan),
  CURRENT_ACTUAL (aktueller Actual Plan), QUERY_STORE (Query-Store-Plan). '' und NULL
  sind ungültig und ergeben INVALID_PARAMETER. Keine Normalisierung. Der Wert
  klassifiziert die Quelle und beschafft keinen Plan.
- @RuntimeCounterScope varchar(32), Eingabe, erforderlich, kein Default: Codes NONE
  (keine Runtimecounter beansprucht), LAST_COMPLETED_EXECUTION (letzte abgeschlossene
  Ausführung), CURRENT_PARTIAL_EXECUTION (aktuelle möglicherweise unvollständige
  Ausführung), IMPORTED_ACTUAL (importiertes Actual-Plan-XML), QUERY_STORE_AGGREGATE
  (aggregierte Query-Store-Zuordnung), UNKNOWN (Scope unbekannt). '' und NULL sind
  ungültig und ergeben INVALID_PARAMETER. Keine Normalisierung. Klassifiziert die
  gelieferten Daten, beschafft oder verifiziert aber keine Runtimecounter.
- @WorkloadProfile varchar(32), Eingabe, Default 'BALANCED': offene, tabellengesteuerte
  Allowlist monitor.PlanAnalysisProfile. NULL wird BALANCED; Rand-Leerraum wird
  entfernt und Großschreibung hergestellt. Unbekannte, deaktivierte und leere Werte
  fallen auf BALANCED zurück. Seedprofile: LATENCY_SENSITIVE gewichtet interaktive/
  häufige Zugriffe je Ausführung und Wiederholungsrate stärker; BALANCED ist neutral
  für gemischte Workloads ohne belastbare Zuordnung; THROUGHPUT gewichtet absolute
  CPU-, I/O-, TempDB- und Datenmengen stärker; MAINTENANCE behandelt große Scans und
  Sorts bei Wartung/Strukturänderungen als möglicherweise erwartet; UNKNOWN bleibt
  konservativ und weist geringe Zuordnungssicherheit aus. Weitere aktive Codes sind
  möglich.
- @MinSeverity varchar(16), Eingabe, Default 'INFO': INFO (informativ), LOW (niedrig),
  MEDIUM (mittel), HIGH (hoch), CRITICAL (kritisch/höchste Stufe). NULL wird INFO;
  Rand-Leerraum wird entfernt und Großschreibung hergestellt. '' und andere Werte
  sind ungültig. Filtert Findings und PlanWarnings unterhalb der Schwelle;
  NO_EXPLICIT_WARNING bleibt zunächst ausgenommen. Ein Hinweis kann melden, dass
  keine Warnung die Schwelle erreicht. Keine Aussage über Planoptimalität oder
  fehlende Quelle.
- @EvidenceJson nvarchar(max), Eingabe, Default NULL: optionale externe STATISTICS
  IO/TIME-Evidenz. NULL lässt die Evidenz aus. '' ist ungültige JSON-Syntax und setzt
  Partialität mit Capability EXECUTION_EVIDENCE_JSON/INVALID_JSON. Syntaktisch
  gültiges JSON wird nicht schemaweit validiert; lax OPENJSON-Pfade mit fehlenden oder
  falsch geformten Werten können leere/unerkannte Teilergebnisse liefern. Zusätzliche
  Felder werden ignoriert; Pfadnamen sind case-sensitive. Ungültige Typkonvertierungen
  können ERROR_HANDLED auslösen. Negative Dezimalwerte werden nicht gefiltert;
  confidence, timeCategory und parseStatus haben keine geprüfte Werteliste.
  Pfade und Typen: $.capture.sameExecutionConfidence (Text, Fallback UNCONFIRMED);
  $.statisticsIo[*].statementOrdinal int, objectDisplayName nvarchar(512),
  logicalReads/physicalReads/readAheadReads/scanCount decimal(38,4), parseStatus
  varchar(40); $.statisticsTime[*].statementOrdinal int, timeCategory varchar(24),
  cpuMs/elapsedMs decimal(38,4), parseStatus varchar(40). Nicht-NULL IO-Werte werden
  als pages-Metriken, Zeitwerte als ms ausgegeben. Confidence belegt keine gleiche
  Ausführung. Synthetisches Beispiel:
  {"capture":{"sameExecutionConfidence":"UNCONFIRMED"},"statisticsIo":[{"statementOrdinal":1,"objectDisplayName":"[dbo].[Sample]","logicalReads":12,"physicalReads":0,"readAheadReads":0,"scanCount":1,"parseStatus":"PARSED"}],"statisticsTime":[{"statementOrdinal":1,"timeCategory":"SQL","cpuMs":2.5,"elapsedMs":3,"parseStatus":"PARSED"}]}
- @MitThreadRuntime bit, Eingabe, Default 0: 0 löscht die Threadzeilen nach ihrer
  Materialisierung und der Ableitung aggregierter Runtimewerte; 1 behält sie.
  NULL ergibt INVALID_PARAMETER. Numerische Werte ungleich 0 werden bei Bindung
  zu 1; '' kann zu 0 konvertieren.
- @EvidenzDatenschutzModus varchar(24), Eingabe, Default 'DERIVED_ONLY': geschlossene
  Codes DERIVED_ONLY (Werte weglassen, abgeleitete Evidenz führen), TOKENIZED (Werte
  weglassen, vorhandene Werte mit frischem lokalem Zufallssalt tokenisieren), RAW
  (Werte im Klartext) und STRUCTURE_ONLY (Werte weglassen, Strukturstatus setzen).
  NULL wird DERIVED_ONLY; äußere U+0020-Leerzeichen entfernen und Großschreibung. '' ist ungültig.
  DERIVED_ONLY und STRUCTURE_ONLY lassen dieselben Wertespalten leer, unterscheiden
  sich aber im ValueHandlingStatus. SQL-NULL-Werte werden markiert und nicht
  tokenisiert. Keine globale Redaktion anderer Planwerte oder Namen.
- @IdentifierDatenschutzModus varchar(16), Eingabe, Default 'RAW': RAW (Objektanzeige
  übernehmen), TOKENIZED (mit frischem lokalem Zufallssalt tokenisieren), OMIT
  (weglassen). NULL wird RAW; äußere U+0020-Leerzeichen entfernen und Großschreibung. '' ist ungültig. Wirkt nur
  auf statisticsIo.objectDisplayName als Scope-Bezeichnung, nicht global.
- @SourceObservedAtUtc datetime2(3), Eingabe, Default NULL: Zeitpunkt nach
  UTC-Konvention. Auslassen/NULL setzt SYSUTCDATETIME(). Ein expliziter Wert wird als
  UTC-Konvention übernommen, aber nicht umgerechnet oder als tatsächliche Quellzeit
  verifiziert. '' wird nach SQL-Typbindungsregeln behandelt; die Procedure prüft den
  resultierenden Wert nicht auf Herkunft oder UTC-Abweichung.
  Eingabe als datetime2-Variable oder ISO-Text, etwa 2000-01-01T00:00:00.000.
- @ParameterEvidenceSessionId smallint, Eingabe, Default NULL: Session-Skalar im
  ParameterEvidence-Kontext. Signed smallint-Bereich -32768 bis 32767, einschließlich
  negativer und null Werte; keine Positivitätsprüfung. NULL bleibt NULL; '' als
  smallint gebunden wird 0. Keine DMV-Abfrage oder Sessionauflösung.
- @ParameterEvidenceRequestId int, Eingabe, Default NULL: Request-Skalar im
  ParameterEvidence-Kontext. Signed int-Bereich -2147483648 bis 2147483647;
  keine Positivitätsprüfung. NULL bleibt NULL; '' als int gebunden wird 0. Keine
  Requestauflösung.
- @PlanHandle varbinary(64), Eingabe, Default NULL: Binärwert, als varbinary-Variable
  oder SQL-0x-Hexwert zu binden; 0x bezeichnet einen leeren Handle. Der Typ begrenzt
  den gebundenen Wert auf 64 Bytes; die Procedure führt keine eigene Längenprüfung aus.
  NULL bleibt NULL. Kein Textpfad, keine Suche oder Auflösung über den Handle.
- @QueryStoreDatabaseName sysname, Eingabe, Default NULL: einzelner unquotierter
  Unicode-Datenbankname im sysname-Typ (nvarchar(128)); keine Liste oder
  Identifier-Syntax. '' wird unverändert akzeptiert; NULL bleibt NULL. Keine
  Auflösung und keine Query-Store-Abfrage.
- @QueryStorePlanId bigint, Eingabe, Default NULL: Plan-ID als Kontextskalar. Signed
  bigint-Bereich -9223372036854775808 bis 9223372036854775807; keine
  Positivitätsprüfung. NULL bleibt NULL; '' als bigint gebunden wird 0. Keine
  Query-Store-Abfrage oder Planbeschaffung.
- @StatusCodeOut varchar(40), OUTPUT, Signatur-Default NULL: Eingabewert (auch NULL
  oder '') wird ignoriert; ausgelassen ist der Default NULL. Ohne OUTPUT wird die
  Ausgabe verworfen; zum Empfang varchar(40)-Variable mit OUTPUT binden. Initialwert
  AVAILABLE. Endwerte: AVAILABLE (ohne Partialitätskennzeichen beendet), PARTIAL
  (Hauptanalyse abgeschlossen und Partialitätsflag gesetzt), INVALID_PARAMETER
  (validierter Eingabefehler), UNAVAILABLE_OBJECT (kein unterstütztes StmtSimple),
  INTERNAL_ERROR (lokale Ergebnistabelle fehlt oder ist nicht zugreifbar),
  ERROR_HANDLED (abgefangener späterer Fehler). Profilabfrage und eigene Temp-Anlage
  können außerhalb dieses Statuspfads fehlschlagen.
- @IsPartialOut bit, OUTPUT, Signatur-Default NULL: Eingabewert (auch NULL oder '',
  sofern als bit gebunden) wird ignoriert; ausgelassen ist der Default NULL. Ohne
  OUTPUT wird die Ausgabe verworfen; zum Empfang bit-Variable mit OUTPUT binden.
  Initialwert 0. 1 kennzeichnet unter anderem ungültige Eingabe, fehlende Statements,
  ungültiges JSON oder abgefangene Fehler; bei regulärem Abschluss wird AVAILABLE zu
  PARTIAL. NULL ist kein regulärer Ausgangswert.
- @ErrorNumberOut int, OUTPUT, Signatur-Default NULL: Eingabewert (auch NULL oder '',
  sofern als int gebunden) wird ignoriert; ausgelassen ist der Default NULL. Ohne
  OUTPUT wird die Ausgabe verworfen; zum Empfang int-Variable mit OUTPUT binden.
  Initialwert NULL; nur Fehlerpfade mit erfasster SQL-Fehlernummer setzen einen Wert.
  Bei PARTIAL ohne abgefangenen SQL-Fehler kann die Ausgabe NULL bleiben.
- @ErrorMessageOut nvarchar(2048), OUTPUT, Signatur-Default NULL: Eingabewert (auch
  NULL oder '') wird ignoriert; ausgelassen ist der Default NULL. Ohne OUTPUT wird
  die Ausgabe verworfen; zum Empfang nvarchar(2048)-Variable mit OUTPUT binden.
  Initialwert NULL; nur belegte Meldungspfade setzen Text.
  Bei PARTIAL ohne expliziten Meldungspfad kann die Ausgabe NULL bleiben.

Kontext- und Fehlergrenzen
Die sechs optionalen Kontextwerte SourceObservedAtUtc, ParameterEvidenceSessionId,
ParameterEvidenceRequestId, PlanHandle, QueryStoreDatabaseName und QueryStorePlanId
sind typisierte Skalare. Sie beweisen weder Planherkunft noch Ausführungsgleichheit.
Lokale T-SQL-Variablenwerte werden nicht aus DMV-Kontext ergänzt. PlanHandle bleibt
binär. Tokenisierung verwendet einen pro Aufruf frischen lokalen Zufallssalt und
liefert keinen stabilen aufrufübergreifenden Schlüssel. Die Profilabfrage gegen
monitor.PlanAnalysisProfile liegt vor dem Haupt-TRY; ein Fehler dort kann nach außen
gelangen. Fehler der eigenen Temp-Tabellenanlage werden nach Wiederherstellung von
LOCK_TIMEOUT 0 erneut ausgelöst. Der spätere Haupt-CATCH meldet ERROR_HANDLED mit
Fehlernummer und -text; frühere Einfügungen werden nicht atomar zurückgenommen.
```

