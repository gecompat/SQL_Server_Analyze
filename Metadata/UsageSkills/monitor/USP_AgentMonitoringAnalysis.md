---
skill_format_version: "1.0.0"
name: "monitor.USP_AgentMonitoringAnalysis"
schema_name: "monitor"
object_name: "USP_AgentMonitoringAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure prüft SQL-Agent-/Alert-/Operator-/Job- und Database-Mail-Evidenz."
source_path: "Code/07_Infrastructure/120_USP_AgentMonitoringAnalysis.sql"
---

# monitor.USP_AgentMonitoringAnalysis

## Zweck und Einsatz

Die Procedure prüft SQL-Agent-/Alert-/Operator-/Job- und Database-Mail-Evidenz.

## Voraussetzungen und Rechte

sys.dm_server_services, msdb.dbo.sysalerts, msdb.dbo.sysoperators, msdb.dbo.sysnotifications, msdb.dbo.sysjobs, msdb.dbo.sysjobschedules, msdb.dbo.sysschedules, msdb.dbo.sysjobhistory und msdb.dbo.sysmail_allitems.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @HistoryHours | int | nein | 24 |
| @MitJobStatus | bit | nein | 1 |
| @MitDatabaseMail | bit | nein | 1 |
| @MaxZeilen | int | nein | 1000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
| @IsPartialOut | bit | nein | NULL OUTPUT |
| @ErrorNumberOut | int | nein | NULL OUTPUT |
| @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |

**@HistoryHours:** @HistoryHours int=24; Default: 24. Ganze Stundenzahl für das lokale Historienfenster der Alertaktivität und Database-Mail-Zeilen; erlaubt sind 1 bis 8760. Nach dem Hilfezweig wird der Cutoff mit DATEADD(HOUR, -@HistoryHours, GETDATE()) vor der Bereichsprüfung berechnet. NULL sowie Werte außerhalb des erlaubten Bereichs setzen INVALID_PARAMETER und IsPartial=1 und überspringen die Fachquellen, sofern die Cutoff-Berechnung erfolgreich war. Extreme int-Werte können vorher ungefangen an Negation oder datetime-Überlauf scheitern; dabei werden die Status-/Fehler-OUTPUTs nicht zugewiesen. Jobhistory wird ohne Zeitfilter nach dem letzten Gesamtoutcome durchsucht; der Cutoff klassifiziert nur diesen letzten Lauf. Übergeben Sie eine ganze Zahl oder eine int-Variable. Andere Literalformen durchlaufen zunächst die SQL-Typkonvertierung; eine leere Zeichenfolge ist kein eigener Leerwert des Prozedurcodes. Bei ausgelassenem Argument gilt der angegebene Default.

**@MitJobStatus:** @MitJobStatus bit=1; Default: 1. Steuert, ob Jobzustand, letzter Gesamtoutcome und Schedule-Zahlen aus msdb erhoben werden. Genau 1 aktiviert den Pfad. 0 und NULL lassen ihn aus; andere ursprüngliche Werte werden bereits beim Binden an bit durch SQL Server konvertiert oder abgewiesen. Der Jobpfad liest die vollständige sichtbare Gesamtzeilen-History ohne @HistoryHours-Filter und klassifiziert danach den letzten Outcome relativ zum Cutoff. Er führt keine Jobs aus oder ändert deren Zustand. Bei ausgelassenem Argument gilt der angegebene Default.

**@MitDatabaseMail:** @MitDatabaseMail bit=1; Default: 1. Steuert die Aggregation der Database-Mail-Zeilen aus msdb innerhalb des mit @HistoryHours gebildeten Cutoffs. Genau 1 aktiviert den Pfad; 0 und NULL lassen ihn aus. Andere Eingaben durchlaufen vor Prozedurbeginn die SQL-Konvertierung zu bit oder schlagen bei der Bindung fehl. Der Pfad liest nur Status, Anzahl und älteste/neuste Anforderungszeit; Adressen, Empfänger, Betreff und Nachrichtentext werden nicht ausgewertet. Ein Lesefehler setzt Partialstatus. Bei ausgelassenem Argument gilt der angegebene Default.

**@MaxZeilen:** @MaxZeilen int=1000; Default: 1000. Begrenzt die ausgegebenen Findings und Jobzeilen. NULL oder 0 bedeutet unbegrenzt; positive ganze Werte von 1 bis 2147483647 sind die Zeilenobergrenze; negative Werte setzen INVALID_PARAMETER und IsPartial=1 und überspringen die Quellen. Findings werden vor einer positiven Begrenzung nach HIGH, MEDIUM, INFO, Kategorie und Scope-Name gereiht; Jobs werden nach Jobname gereiht. Das Limit reduziert keine vorherige Katalog- oder Historyaggregation. Services und Mailstatus werden nicht mit dieser Zeilengrenze gekürzt. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultSetArt:** @ResultSetArt varchar(16)='CONSOLE'; Default: 'CONSOLE'. Nach Entfernen äußerer Leerzeichen und Umwandlung in Großbuchstaben sind ausschließlich RAW, CONSOLE, NONE und TABLE erlaubt. NULL wird wie leer behandelt und ist ungültig. RAW liefert fünf Resultsets: Modulstatus, Services, begrenzte Findings, begrenzte Jobs und Mailaggregation. CONSOLE liefert genau eine Findingsausgabe mit verständlicher Hinweiszeile bei leerer Menge; es gibt dabei keine zusätzlichen Service- oder Modulstatus-Resultsets. NONE unterdrückt fachliche Resultsets. TABLE schreibt ausschließlich findings in das vorgeprüfte Ziel. JSON über @JsonErzeugen und die Status-/Fehler-OUTPUTs sind davon unabhängig. Ungültige Werte führen nach dem Hilfezweig zu INVALID_PARAMETER mit IsPartial=1. Eingaben werden zunächst an varchar(16) gebunden. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. Enthält ausschließlich für TABLE die JSON-Zuordnung des einen exportierbaren Resultsets findings, in der Form {"findings":"#ExampleTarget"}: genau dieser case-sensitive Schlüssel mit dem lokalen Zielnamen als JSON-Stringwert, keine weiteren Eigenschaften. Der Zielname darf höchstens 116 Zeichen lang sein. Das Ziel muss eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte sein; globale ##Temp-Tabellen, permanente Tabellen, das reservierte Präfix #Monitor, unbekannte oder doppelte Namen/Ziele, nichtstringige Werte, leere Ziele und zusätzliche Schlüssel sind unzulässig. Das JSON muss ein Objekt sein; NULL, leer oder nur Leerzeichen ist kein gültiges TABLE-Mapping. Außerhalb TABLE sind NULL/leer/Leerzeichen zulässig; jeder nichtleere Wert löst Fehler 51011 aus. TABLE-Mapping und Ziel werden vor der Hilfeausgabe vorgeprüft, sodass ein ungültiges Mapping auch mit @Hilfe=1 fehlschlägt. Der Helper erwartet OPENJSON-kompatibles JSON und installiertes Framework. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. Aktiviert die zusätzliche JSON-Erzeugung nur bei exakt 1; 0 und NULL überspringen sie. SQL Server bindet Eingaben zuerst an bit und konvertiert oder verwirft abweichende Formen. Bei Aktivierung enthält @Json das Objekt meta sowie die vier Arrays services, findings, jobs und mailStatus. Die Arrays verwenden INCLUDE_NULL_VALUES; meta wird ohne INCLUDE_NULL_VALUES serialisiert, sodass NULL-Eigenschaften dort entfallen. meta enthält UTC-Erstellungszeit, Status, Partialflag und @HistoryHours. Findings und Jobs folgen @MaxZeilen; Services und Mailstatus bleiben vollständige getrennte Arrays. Die Ausgabe enthält keine Mailadressen, Empfänger, Betreffzeilen, Jobbefehle oder Meldungstexte. @Json wird am Prozedureintritt auf NULL gesetzt und bleibt bei deaktiviertem Schalter oder vorzeitigem Hilfe-RETURN NULL. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. Empfängt bei @JsonErzeugen=1 das erzeugte JSON nvarchar(max) mit meta-, services-, findings-, jobs- und mailStatus-Elementen. Der Wert wird zu Beginn immer auf NULL gesetzt und nur nach abgeschlossener Erhebung bei aktiviertem JSON-Schalter befüllt; bei Hilfe-RETURN und Fehlern vor der Erzeugung bleibt er NULL. NULL-Werte werden in den Kontextarrays erhalten. Findings und Jobs verwenden die Begrenzung aus @MaxZeilen. Status-/Fehler-OUTPUTs werden bei Hilfe-RETURN nicht aktualisiert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@PrintMeldungen:** @PrintMeldungen bit=1; Default: 1. Wird in der Implementierung nicht gelesen und steuert daher weder PRINT-Ausgaben noch Resultsets. Die fest codierten PRINT-Zeilen der Hilfeausgabe erscheinen bei @Hilfe=1 unabhängig von diesem Schalter. NULL sowie 0 oder 1 ändern das Verhalten nicht; eine Bit-Konvertierung oder ein Konvertierungsfehler geschieht vor dem Prozedurcode. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit=0; Default: 0. Bei exakt 1 gibt die Procedure ihre Hilfe mit PRINT aus und kehrt vor der Analyse mit RETURN zurück. 0 und NULL führen in den normalen Ablauf; abweichende Formen werden beim Binden an bit konvertiert oder abgewiesen. @Json wird zuvor auf NULL gesetzt. Die Status-, Partial- und Fehler-OUTPUTs werden im Hilfezweig nicht belegt und behalten ihre Eingangs-/Bindungswerte. Die Ausgabeoptionen werden vor diesem Zweig geprüft: ein ungültiger Nicht-TABLE-Wert von @ResultTablesJson oder ein fehlerhafter TABLE-Preflight kann daher trotz Hilfe einen Fehler auslösen. Bei ausgelassenem Argument gilt der angegebene Default.

**@StatusCodeOut:** @StatusCodeOut varchar(40)=NULL OUTPUT; Default: NULL. Empfängt genau einen der vier Modulstatuswerte: INVALID_PARAMETER bei einem nach erfolgreicher Cutoff-Berechnung erkannten ungültigen Historien-, Zeilen- oder Ausgabewert; AVAILABLE_LIMITED bei mindestens einem abgefangenen Quellenfehler; AVAILABLE_WITH_FINDING bei mindestens einem HIGH-/MEDIUM-Finding oder einem nicht laufenden sichtbaren Agentdienst ohne Quellenfehler; AVAILABLE sonst, auch bei ausschließlich INFO-Findings. Der Status wird vor der Ausgabegrenze auf der vollständigen Erhebung bestimmt. Binden Sie eine varchar(40)-Variable mit OUTPUT. Bei @Hilfe=1 sowie bei einem Fehler des frühen TABLE-Preflights oder der Cutoff-Berechnung bleibt die Eingangs-/Bindungsvariable unverändert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@IsPartialOut:** @IsPartialOut bit=NULL OUTPUT; Default: NULL. Empfängt das Partialflag: 0 bei vollständiger Erhebung, 1 bei ungültigem Historien-/Zeilen-/Ausgabewert oder einem abgefangenen Fehler eines Quellenpfads. Ein ausgelassener optionaler Job- oder Mailpfad allein setzt das Flag nicht. Bei @Hilfe=1 sowie bei Fehlern im frühen Ausgabepreflight wird der Wert vor Abbruch/RETURN nicht beschrieben. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@ErrorNumberOut:** @ErrorNumberOut int=NULL OUTPUT; Default: NULL. Empfängt die erste abgefangene SQL-Quellenfehlernummer oder NULL, wenn kein Quellenfehler erfasst wurde. Ein ungültiger Analyseparameter setzt keinen Fehlernummernwert. Bei @Hilfe=1 und bei einem Fehler des frühen Output-Mappings erfolgt keine Zuweisung. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048)=NULL OUTPUT; Default: NULL. Empfängt NULL ohne abgefangenen Quellenfehler oder den ersten abgefangenen SQL-Fehler mit einem quellenspezifischen Präfix in nvarchar(2048). Bei ungültigen Analyseparametern steht hier eine generische Parameterfehlermeldung; spätere Quellenfehler überschreiben die erste gespeicherte Fehlermeldung nicht. Die Texte können SQL-Fehlerdetails enthalten, umfassen aber keine gelesenen Mail- oder Jobnachrichten. Bei Hilfe-RETURN und frühem Mappingfehler erfolgt keine Zuweisung. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| findings | 1 | 1 | [Category] varchar(40) NOT NULL , [FindingCode] varchar(100) NOT NULL , [Severity] varchar(16) NOT NULL , [ScopeType] nvarchar(40) NOT NULL , [ScopeName] nvarchar(256) NULL , [MetricValue] bigint NULL , [Evidence] nvarchar(1000) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_AgentMonitoringAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Fehlende Standardalarme sind ein Prüfauftrag; externe Monitoringwege können die Alarmierung anderweitig abdecken.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_AgentMonitoringAnalysis
Version      : 1.1.0
Stand        : 2026-07-18
Zweck        : Die Procedure prüft SQL-Agent-/Alert-/Operator-/Job- und Database-Mail-Evidenz.
Datenquellen : sys.dm_server_services, msdb.dbo.sysalerts,
               msdb.dbo.sysoperators, msdb.dbo.sysnotifications,
               msdb.dbo.sysjobs, msdb.dbo.sysjobschedules,
               msdb.dbo.sysschedules, msdb.dbo.sysjobhistory und
               msdb.dbo.sysmail_allitems.
Methodik     : Alert-Routing, Jobzustand und aggregierter Mailstatus werden über
               dieselben reinen Interpretationsfunktionen klassifiziert, die
               der deterministische Laufzeitvertrag verwendet.
Datenschutz  : Liest keine Mailadressen, Empfänger, Betreffzeilen,
               Jobschrittbefehle oder Fehlermeldungstexte.
Grenzen      : Fehlende Standardalarme sind ein Prüfauftrag; externe
               Monitoringwege können die Alarmierung anderweitig abdecken.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_AgentMonitoringAnalysis
Die Procedure erstellt einen lesenden Snapshot des SQL-Agent-Dienstes, der erforderlichen Alertabdeckung, des Alert-Routings, der Operatoren, des letzten sichtbaren Gesamtoutcomes je Job und optional aggregierter Database-Mail-Status. Sie liest keine Mailadressen, Empfänger, Betreffzeilen, Jobschrittbefehle oder Meldungstexte und führt keine Agent- oder Mailaktion aus.
Voraussetzung sind die Procedure und ihre Interpretations- und TABLE-Helper im Schema monitor sowie ausreichende Lesesicht auf sys.dm_server_services und die verwendeten msdb-Kataloge. Fehlende Sichtbarkeit wird soweit abgefangen als AVAILABLE_LIMITED mit erster Fehlernummer und Fehlermeldung ausgewiesen. Für die TABLE-Ausgabe muss zusätzlich ein gültiges lokales Ziel vorhanden sein.
Alertaktivität und Mailzeilen verwenden einen lokalen Cutoff; der Jobpfad liest dagegen den letzten sichtbaren Gesamtoutcome ohne Zeitfilter. Die Erhebung ist kein atomarer Snapshot und belegt weder erfolgreiche Zustellung noch eine vollständige Jobausführungsreihe oder externe Alarmierung.
Beispiel 1: EXEC [monitor].[USP_AgentMonitoringAnalysis] @Hilfe=1;
Beispiel 2: EXEC [monitor].[USP_AgentMonitoringAnalysis] @HistoryHours=24, @MaxZeilen=100, @ResultSetArt='RAW';
Beispiel 3: DECLARE @AgentMonitoringJson nvarchar(max), @AgentMonitoringStatus varchar(40), @AgentMonitoringPartial bit, @AgentMonitoringError int, @AgentMonitoringMessage nvarchar(2048); EXEC [monitor].[USP_AgentMonitoringAnalysis] @HistoryHours=24, @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@AgentMonitoringJson OUTPUT, @StatusCodeOut=@AgentMonitoringStatus OUTPUT, @IsPartialOut=@AgentMonitoringPartial OUTPUT, @ErrorNumberOut=@AgentMonitoringError OUTPUT, @ErrorMessageOut=@AgentMonitoringMessage OUTPUT; SELECT @AgentMonitoringStatus AS [StatusCode], @AgentMonitoringPartial AS [IsPartial], @AgentMonitoringError AS [ErrorNumber], @AgentMonitoringMessage AS [ErrorMessage], @AgentMonitoringJson AS [Json];
Beispiel 4: CREATE TABLE #AgentMonitoring_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AgentMonitoringAnalysis] @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#AgentMonitoring_HelpExample"}'; SELECT * FROM #AgentMonitoring_HelpExample; DROP TABLE #AgentMonitoring_HelpExample; END TRY BEGIN CATCH DROP TABLE #AgentMonitoring_HelpExample; THROW; END CATCH;
Beispiel 5: EXEC [monitor].[USP_AgentMonitoringAnalysis] @HistoryHours=24, @MitJobStatus=0, @MitDatabaseMail=0, @MaxZeilen=100, @ResultSetArt='RAW';
```

