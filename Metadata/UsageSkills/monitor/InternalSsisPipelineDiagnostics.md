---
skill_format_version: "1.0.0"
name: "monitor.InternalSsisPipelineDiagnostics"
schema_name: "monitor"
object_name: "InternalSsisPipelineDiagnostics"
object_type: "INTERNAL_PROCEDURE"
database_role: "framework"
is_internal: true
description: "Die Procedure bildet aus bereits vom Scopeconsumer gebundenen Phasen- und Transferbelegen partielle Kennzahlen und versionierte Hinweise für den jeweiligen beobachteten Pipelineinstanzscope."
source_path: "Code/10_SSIS/037_InternalSsisPipelineDiagnostics.sql"
---

# monitor.InternalSsisPipelineDiagnostics

## Zweck und Einsatz

Die Procedure bildet aus bereits vom Scopeconsumer gebundenen Phasen- und Transferbelegen partielle Kennzahlen und versionierte Hinweise für den jeweiligen beobachteten Pipelineinstanzscope. Phasengruppen verwenden die gemessenen Intervalle; Transfergruppen verwenden gemeldete Zeilenzahlen und eine Portrolle aus dem gelieferten Toolbelt-Modell. Überlappende Intervalle sind weder CPU-Zeit noch kritischer Pfad oder Paketlaufzeit. Die Procedure lädt keine Paketdateien und führt keine erneute Modell- oder Lineageanalyse aus.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalSsisPipelineDiagnostics]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `sys.sp_executesql`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @Models | nvarchar(max) | ja | kein Default |
| @Bound | bit | ja | kein Default |
| @Deadline | datetime2(3) | ja | kein Default |
| @Limit | int | ja | kein Default |
| @PipelinePhaseThresholdMs | bigint | nein | NULL |
| @Hilfe | bit | nein | 0 |

**@Models:** @Models: nvarchar(max); Default: keiner, Pflichtargument. Erwartet wird das Unicode-JSON-Dokument des bereits geprüften Paketsatzes. Der Helper liest je Paket model.nodes mit id, kind und attributes.portRole für Knoten des Typs PORT sowie model.edges mit id, kind und fromId für Kanten des Typs PIPELINE_PATH. Er ordnet dadurch die Quellportrolle einer bereits korrelierten Modellkante zu. Die Portrollen kommen aus dem Toolbelt-Modell und bilden hier keine geschlossene Eingabewerteliste; ERROR und NO_MATCH lösen jeweils einen Hinweis aus, während fehlende Rollen als UNKNOWN und andere Rollen unverändert in der Zusammenfassung erscheinen. Die öffentliche Procedure prüft Paketmodell und Transportgrenzen einschließlich Dokumentgröße, JSON-Tiefe und doppelter Schlüssel; dies sind keine unabhängigen Vertrauensprüfungen dieser internen Procedure. Auslassen scheitert an der Pflichtsignatur. Bei NULL liefern die JSON-OPENJSON-Joins keine Modellkanten und Ports, während eine Zusammenfassung aus bereits zugeordneten Phasenbelegen weiterhin entstehen kann. Leertext oder ungültiges JSON kann im TRY als Diagnoseeingabefehler erfasst werden.

**@Bound:** @Bound: bit; Default: keiner, Pflichtargument. Skalarer interner Übergabeflag aus der lokalen Bindungsprüfung des Scopeconsumers. Diagnoseanalyse beginnt nur bei @Bound=1 und ohne PIPELINE_BINDING_UNPROVEN in der bereits vorhandenen Pipeline-Coverage. Bei 0 oder NULL wird die Analyse übersprungen; die Procedure schreibt dennoch Diagnose-Coverage aus den vorhandenen Coverage- und Belegtabellen und kann einen Coveragehinweis erzeugen. Der Flag allein ist kein Beleg und die Procedure prüft weder Handover noch Capturebindung. Auslassen scheitert an der Pflichtsignatur. Die vollständige bit-Wertemenge ist 0 (nicht gebunden) und 1 (vom Aufrufer als gebunden markiert). SQL Server konvertiert numerische Werte ungleich 0 zu 1 und leeren Text zu 0 vor dem Procedure-Eintritt.

**@Deadline:** @Deadline: datetime2(3); Default: keiner, Pflichtargument. Enthält dieselbe absolute UTC-Deadline, die der Scopeconsumer an die Korrelation übergeben hat. Die Procedure prüft sie vor und nach wesentlichen Diagnosephasen; ein erkanntes Überschreiten wird als DIAGNOSTIC_TIME_LIMIT in Diagnose-Coverage dargestellt. NULL unterdrückt die Vergleiche wegen SQL-NULL-Semantik und wird hier nicht als ungültiger Wert abgefangen. Auslassen scheitert an der Pflichtsignatur. Als datetime2(3)-Variable oder konvertierbaren ISO-Zeitpunkt übergeben, beispielsweise 2026-11-06T13:00:00.000; der Wert selbst trägt keine Zeitzone und muss UTC repräsentieren. Leerer Text kann zum Zeitpunkt 1900-01-01 konvertiert werden und ist dann abgelaufen; nicht konvertierbarer Text scheitert vor dem Eintritt.

**@Limit:** @Limit: int; Default: keiner, Pflichtargument. Enthält das vom Scopeconsumer abgeleitete Zeilenlimit. Der Helper kürzt keine Ergebnis- oder Diagnosezeilen; er setzt OutputTruncated in Diagnose-Coverage, wenn die Anzahl der Phasen-Zusammenfassungen, Transfer-Zusammenfassungen, Hinweise oder Coveragezeilen das Limit überschreitet. Die eigentliche Ausgabe kürzt der Scopeconsumer. Der Helper validiert den Wert nicht: Bei NULL ergibt der Vergleich keinen Treffer und das Flag wird wegen dieses Vergleichs nicht gesetzt; 0 oder negative Werte können bei vorhandenen Zeilen das Flag setzen. Negative Werte sind bei Umgehung der öffentlichen Guard-Prüfung kein gültiger Aufrufvertrag. Auslassen scheitert an der Pflichtsignatur. Als skalaren ganzzahligen int-Wert von -2147483648 bis 2147483647 übergeben; der Scopeconsumer liefert ein positives wirksames Limit. Leerer Text kann vor dem Eintritt nach 0 konvertiert werden.

**@PipelinePhaseThresholdMs:** @PipelinePhaseThresholdMs: bigint; Default: NULL. Skalarer Millisekunden-Grenzwert für den Hinweis SSIS_PIPELINE_PHASE_THRESHOLD_EXCEEDED. NULL deaktiviert diesen Hinweis; ein nicht-NULL-Wert erzeugt ihn, wenn das längste bekannte einzelne Phasenintervall einer Komponentengruppe strikt größer ist als der Grenzwert. Gleichheit genügt nicht. Die interne Procedure selbst akzeptiert auch negative Werte, wenn der öffentliche Scopeconsumer umgangen wird; dann können bekannte nichtnegative Intervalle den Grenzwert überschreiten. Die öffentliche Procedure verwirft negative Werte und gesetzte Werte ohne Diagnoseopt-in. Auslassen verwendet NULL. Leerer Text wird bei erfolgreicher SQL-Typkonvertierung zu bigint regelmäßig als 0 übergeben und aktiviert dann den Vergleich; nicht konvertierbarer Text scheitert bereits bei der Parameterbindung. Der SQL-Typ erlaubt ganze Werte von -9223372036854775808 bis 9223372036854775807; der öffentliche Vertrag beschränkt gesetzte Werte auf den nichtnegativen Bereich.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Kein direktes Resultset und keine OUTPUT-Parameter. Der Helper schreibt die vorgegebenen lokalen Ziele für Phasen- und Transferzusammenfassungen, Findings und DiagnosticCoverage. `OutputTruncated` ist ein Statushinweis beim Überschreiten von `@Limit`; der Helper kappt selbst keine Ergebniszeilen. Die öffentliche SSIS-Procedure wählt und exportiert die fertigen Gruppen.

## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalSsisPipelineDiagnostics';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [monitor].[InternalSsisPipelineDiagnostics] @Models=NULL, @Bound=NULL, @Deadline=NULL, @Limit=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Während der Diagnoseanalyse erfasste Fehler werden durch Löschen der Phasen-Zusammenfassungen, Transfer-Zusammenfassungen und bis dahin erzeugten Hinweise zurückgenommen. Fehlernummer 57920 wird als DIAGNOSTIC_TIME_LIMIT mit gleicher Fehlernummer abgebildet; sonstige abgefangene Fehler erhalten DIAGNOSTIC_INPUT_REJECTED mit ihrer ursprünglichen Fehlernummer. Diagnose-Coverage wird danach aus den Pipeline-Coveragewerten geschrieben und erhält bei Fehlern den jeweiligen Diagnose-Reason-Code. Nach dem CATCH liegen Coverage-Schreiben, Erzeugung des Hinweises SSIS_PIPELINE_DIAGNOSTIC_EVIDENCE_LIMITED, OutputTruncated-Aktualisierung und Wiederherstellung des vorherigen LOCK_TIMEOUT außerhalb der Abfangstrecke und können selbst fehlschlagen. Daher besteht keine universelle Fehler- oder Wiederherstellungszusage und keine atomare Gesamttransaktion.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt: [monitor].[InternalSsisPipelineDiagnostics].
Typ: Interne Stored Procedure.
Zweck: Die Procedure bildet aus bereits vom Scopeconsumer gebundenen Phasen- und Transferbelegen partielle Kennzahlen und versionierte Hinweise für den jeweiligen beobachteten Pipelineinstanzscope. Phasengruppen verwenden die gemessenen Intervalle; Transfergruppen verwenden gemeldete Zeilenzahlen und eine Portrolle aus dem gelieferten Toolbelt-Modell. Überlappende Intervalle sind weder CPU-Zeit noch kritischer Pfad oder Paketlaufzeit. Die Procedure lädt keine Paketdateien und führt keine erneute Modell- oder Lineageanalyse aus.

Parameter:
@Models: nvarchar(max); Default: keiner, Pflichtargument. Erwartet wird das Unicode-JSON-Dokument des bereits geprüften Paketsatzes. Der Helper liest je Paket model.nodes mit id, kind und attributes.portRole für Knoten des Typs PORT sowie model.edges mit id, kind und fromId für Kanten des Typs PIPELINE_PATH. Er ordnet dadurch die Quellportrolle einer bereits korrelierten Modellkante zu. Die Portrollen kommen aus dem Toolbelt-Modell und bilden hier keine geschlossene Eingabewerteliste; ERROR und NO_MATCH lösen jeweils einen Hinweis aus, während fehlende Rollen als UNKNOWN und andere Rollen unverändert in der Zusammenfassung erscheinen. Die öffentliche Procedure prüft Paketmodell und Transportgrenzen einschließlich Dokumentgröße, JSON-Tiefe und doppelter Schlüssel; dies sind keine unabhängigen Vertrauensprüfungen dieser internen Procedure. Auslassen scheitert an der Pflichtsignatur. Bei NULL liefern die JSON-OPENJSON-Joins keine Modellkanten und Ports, während eine Zusammenfassung aus bereits zugeordneten Phasenbelegen weiterhin entstehen kann. Leertext oder ungültiges JSON kann im TRY als Diagnoseeingabefehler erfasst werden.

@Bound: bit; Default: keiner, Pflichtargument. Skalarer interner Übergabeflag aus der lokalen Bindungsprüfung des Scopeconsumers. Diagnoseanalyse beginnt nur bei @Bound=1 und ohne PIPELINE_BINDING_UNPROVEN in der bereits vorhandenen Pipeline-Coverage. Bei 0 oder NULL wird die Analyse übersprungen; die Procedure schreibt dennoch Diagnose-Coverage aus den vorhandenen Coverage- und Belegtabellen und kann einen Coveragehinweis erzeugen. Der Flag allein ist kein Beleg und die Procedure prüft weder Handover noch Capturebindung. Auslassen scheitert an der Pflichtsignatur. Die vollständige bit-Wertemenge ist 0 (nicht gebunden) und 1 (vom Aufrufer als gebunden markiert). SQL Server konvertiert numerische Werte ungleich 0 zu 1 und leeren Text zu 0 vor dem Procedure-Eintritt.

@Deadline: datetime2(3); Default: keiner, Pflichtargument. Enthält dieselbe absolute UTC-Deadline, die der Scopeconsumer an die Korrelation übergeben hat. Die Procedure prüft sie vor und nach wesentlichen Diagnosephasen; ein erkanntes Überschreiten wird als DIAGNOSTIC_TIME_LIMIT in Diagnose-Coverage dargestellt. NULL unterdrückt die Vergleiche wegen SQL-NULL-Semantik und wird hier nicht als ungültiger Wert abgefangen. Auslassen scheitert an der Pflichtsignatur. Als datetime2(3)-Variable oder konvertierbaren ISO-Zeitpunkt übergeben, beispielsweise 2026-11-06T13:00:00.000; der Wert selbst trägt keine Zeitzone und muss UTC repräsentieren. Leerer Text kann zum Zeitpunkt 1900-01-01 konvertiert werden und ist dann abgelaufen; nicht konvertierbarer Text scheitert vor dem Eintritt.

@Limit: int; Default: keiner, Pflichtargument. Enthält das vom Scopeconsumer abgeleitete Zeilenlimit. Der Helper kürzt keine Ergebnis- oder Diagnosezeilen; er setzt OutputTruncated in Diagnose-Coverage, wenn die Anzahl der Phasen-Zusammenfassungen, Transfer-Zusammenfassungen, Hinweise oder Coveragezeilen das Limit überschreitet. Die eigentliche Ausgabe kürzt der Scopeconsumer. Der Helper validiert den Wert nicht: Bei NULL ergibt der Vergleich keinen Treffer und das Flag wird wegen dieses Vergleichs nicht gesetzt; 0 oder negative Werte können bei vorhandenen Zeilen das Flag setzen. Negative Werte sind bei Umgehung der öffentlichen Guard-Prüfung kein gültiger Aufrufvertrag. Auslassen scheitert an der Pflichtsignatur. Als skalaren ganzzahligen int-Wert von -2147483648 bis 2147483647 übergeben; der Scopeconsumer liefert ein positives wirksames Limit. Leerer Text kann vor dem Eintritt nach 0 konvertiert werden.

@PipelinePhaseThresholdMs: bigint; Default: NULL. Skalarer Millisekunden-Grenzwert für den Hinweis SSIS_PIPELINE_PHASE_THRESHOLD_EXCEEDED. NULL deaktiviert diesen Hinweis; ein nicht-NULL-Wert erzeugt ihn, wenn das längste bekannte einzelne Phasenintervall einer Komponentengruppe strikt größer ist als der Grenzwert. Gleichheit genügt nicht. Die interne Procedure selbst akzeptiert auch negative Werte, wenn der öffentliche Scopeconsumer umgangen wird; dann können bekannte nichtnegative Intervalle den Grenzwert überschreiten. Die öffentliche Procedure verwirft negative Werte und gesetzte Werte ohne Diagnoseopt-in. Auslassen verwendet NULL. Leerer Text wird bei erfolgreicher SQL-Typkonvertierung zu bigint regelmäßig als 0 übergeben und aktiviert dann den Vergleich; nicht konvertierbarer Text scheitert bereits bei der Parameterbindung. Der SQL-Typ erlaubt ganze Werte von -9223372036854775808 bis 9223372036854775807; der öffentliche Vertrag beschränkt gesetzte Werte auf den nichtnegativen Bereich.

Ergebnis- und Temp-Vertrag: Die Procedure erzeugt kein Resultset und hat keine OUTPUT-Parameter. Sie liest die vom Scopeconsumer bereitgestellten Temp-Tabellen #InternalSsisExecutionScopes_PipelineCoverage, #InternalSsisExecutionScopes_ComponentPhases, #InternalSsisExecutionScopes_PathTransfers, #InternalSsisExecutionScopes_Packages und #InternalSsisExecutionScopes_Binding und schreibt in #InternalSsisExecutionScopes_PhaseSummary, #InternalSsisExecutionScopes_TransferSummary, #InternalSsisExecutionScopes_PipelineFindings und #InternalSsisExecutionScopes_DiagnosticCoverage. Die Gruppen componentPhaseSummary enthalten je Pipelineinstanz, Komponente und Phasenname ObservedIntervalCount, ValidIntervalCount, UnknownIntervalCount, ObservedIntervalSumMs, LongestIntervalMs, SpanMs, FirstStartTime, LastEndTime, OverlapObserved, RankWithinFlowPhase, EvidencePhaseStatsId und IsPartial. Summen und Rangfolge berücksichtigen gültige zugeordnete Beobachtungen; SpanMs reicht vom frühesten bekannten Start bis zum spätesten bekannten Ende und kann Überlappungen enthalten. pathTransferSummary enthält je Pipelineinstanz und Kante PortRole, ObservedTransferCount, KnownRowCount, UnknownRowCount, ObservedRowsSent, FirstCreatedTime, LastCreatedTime, FirstDataStatsId, PositiveDataStatsId und IsPartial. pipelineFindings enthält RuleId, RuleVersion, Severity, EvidenceLevel, Paket-/Aufruf-/Flow-/Knoten-/Kantenbezug, SourceName, SourceId, ObservedValue, ThresholdMs, PackageSha256, SourceBindingSha256 und IsPartial. pipelineDiagnosticCoverage enthält SourceName, StatusCode, SourceErrorNumber, ObservedRowCount, MappedRowCount, UnassignedRowCount, SummaryRowCount, UnknownValueCount, UnknownRoleCount, LoggingLevel, IsPartial, OutputTruncated und ReasonCode. Die fünf möglichen RuleId-Werte lauten SSIS_PIPELINE_ERROR_OUTPUT_OBSERVED für positive beobachtete Zeilen auf einer ERROR-Ausgabe, SSIS_PIPELINE_NO_MATCH_OBSERVED für positive beobachtete Zeilen auf einer NO_MATCH-Ausgabe, SSIS_PIPELINE_ZERO_OBSERVED_TRANSFER für einen Transfer mit vollständig bekannten Zeilenwerten und Summe null, SSIS_PIPELINE_PHASE_THRESHOLD_EXCEEDED für ein bekanntes einzelnes Phasenintervall oberhalb des gesetzten Grenzwerts sowie SSIS_PIPELINE_DIAGNOSTIC_EVIDENCE_LIMITED für Diagnosequellen mit eingeschränkter Abdeckung oder unbekannten Werten beziehungsweise Rollen. Hinweise tragen Version 1.0.0 und Severity INFO. Fehlerhinweise sind Evidenzhinweise und keine Aussagen über Ursache oder Auswirkung außerhalb der beobachteten Daten. Der Aufrufer kürzt alle Ergebnisgruppen später und kennzeichnet tatsächliche Ausgabekürzung.

Fehlergrenzen: Während der Diagnoseanalyse erfasste Fehler werden durch Löschen der Phasen-Zusammenfassungen, Transfer-Zusammenfassungen und bis dahin erzeugten Hinweise zurückgenommen. Fehlernummer 57920 wird als DIAGNOSTIC_TIME_LIMIT mit gleicher Fehlernummer abgebildet; sonstige abgefangene Fehler erhalten DIAGNOSTIC_INPUT_REJECTED mit ihrer ursprünglichen Fehlernummer. Diagnose-Coverage wird danach aus den Pipeline-Coveragewerten geschrieben und erhält bei Fehlern den jeweiligen Diagnose-Reason-Code. Nach dem CATCH liegen Coverage-Schreiben, Erzeugung des Hinweises SSIS_PIPELINE_DIAGNOSTIC_EVIDENCE_LIMITED, OutputTruncated-Aktualisierung und Wiederherstellung des vorherigen LOCK_TIMEOUT außerhalb der Abfangstrecke und können selbst fehlschlagen. Daher besteht keine universelle Fehler- oder Wiederherstellungszusage und keine atomare Gesamttransaktion.
```

