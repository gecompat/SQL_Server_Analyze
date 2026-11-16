# [monitor].[USP_AgentMonitoringAnalysis]

**Bereich:** Infrastruktur<br>
**Zweck:** Verknüpft Jobprobleme mit Alerts, Operatoren und Database Mail.<br>
**Beobachtungsart:** Konfigurationssnapshot + retentionbegrenzte Historie<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Jobs, Alerts und Benachrichtigungsketten gefährden geplante Betriebsabläufe?** Sie unterstützt die Entscheidung, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_AgentMonitoringAnalysis]
      @HistoryHours = 24,
      @MitJobStatus = 1,
      @MitDatabaseMail = 1,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameterverträge

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@HistoryHours` | `int` | Default: `24` | Ganze Stundenzahl für das lokale Historienfenster der Alertaktivität und Database-Mail-Zeilen; erlaubt sind 1 bis 8760. Nach dem Hilfezweig wird der Cutoff mit DATEADD(HOUR, -@HistoryHours, GETDATE()) vor der Bereichsprüfung berechnet. NULL sowie Werte außerhalb des erlaubten Bereichs setzen INVALID_PARAMETER und IsPartial=1 und überspringen die Fachquellen, sofern die Cutoff-Berechnung erfolgreich war. Extreme int-Werte können vorher ungefangen an Negation oder datetime-Überlauf scheitern; dabei werden die Status-/Fehler-OUTPUTs nicht zugewiesen. Jobhistory wird ohne Zeitfilter nach dem letzten Gesamtoutcome durchsucht; der Cutoff klassifiziert nur diesen letzten Lauf. Übergeben Sie eine ganze Zahl oder eine int-Variable. Andere Literalformen durchlaufen zunächst die SQL-Typkonvertierung; eine leere Zeichenfolge ist kein eigener Leerwert des Prozedurcodes. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MitJobStatus` | `bit` | Default: `1` | Steuert, ob Jobzustand, letzter Gesamtoutcome und Schedule-Zahlen aus msdb erhoben werden. Genau 1 aktiviert den Pfad. 0 und NULL lassen ihn aus; andere ursprüngliche Werte werden bereits beim Binden an bit durch SQL Server konvertiert oder abgewiesen. Der Jobpfad liest die vollständige sichtbare Gesamtzeilen-History ohne @HistoryHours-Filter und klassifiziert danach den letzten Outcome relativ zum Cutoff. Er führt keine Jobs aus oder ändert deren Zustand. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MitDatabaseMail` | `bit` | Default: `1` | Steuert die Aggregation der Database-Mail-Zeilen aus msdb innerhalb des mit @HistoryHours gebildeten Cutoffs. Genau 1 aktiviert den Pfad; 0 und NULL lassen ihn aus. Andere Eingaben durchlaufen vor Prozedurbeginn die SQL-Konvertierung zu bit oder schlagen bei der Bindung fehl. Der Pfad liest nur Status, Anzahl und älteste/neuste Anforderungszeit; Adressen, Empfänger, Betreff und Nachrichtentext werden nicht ausgewertet. Ein Lesefehler setzt Partialstatus. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MaxZeilen` | `int` | Default: `1000` | Begrenzt die ausgegebenen Findings und Jobzeilen. NULL oder 0 bedeutet unbegrenzt; positive ganze Werte von 1 bis 2147483647 sind die Zeilenobergrenze; negative Werte setzen INVALID_PARAMETER und IsPartial=1 und überspringen die Quellen. Findings werden vor einer positiven Begrenzung nach HIGH, MEDIUM, INFO, Kategorie und Scope-Name gereiht; Jobs werden nach Jobname gereiht. Das Limit reduziert keine vorherige Katalog- oder Historyaggregation. Services und Mailstatus werden nicht mit dieser Zeilengrenze gekürzt. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultSetArt` | `varchar(16)` | Default: `'CONSOLE'` | Nach Entfernen äußerer Leerzeichen und Umwandlung in Großbuchstaben sind ausschließlich RAW, CONSOLE, NONE und TABLE erlaubt. NULL wird wie leer behandelt und ist ungültig. RAW liefert fünf Resultsets: Modulstatus, Services, begrenzte Findings, begrenzte Jobs und Mailaggregation. CONSOLE liefert genau eine Findingsausgabe mit verständlicher Hinweiszeile bei leerer Menge; es gibt dabei keine zusätzlichen Service- oder Modulstatus-Resultsets. NONE unterdrückt fachliche Resultsets. TABLE schreibt ausschließlich findings in das vorgeprüfte Ziel. JSON über @JsonErzeugen und die Status-/Fehler-OUTPUTs sind davon unabhängig. Ungültige Werte führen nach dem Hilfezweig zu INVALID_PARAMETER mit IsPartial=1. Eingaben werden zunächst an varchar(16) gebunden. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultTablesJson` | `nvarchar(max)` | Default: `NULL` | Enthält ausschließlich für TABLE die JSON-Zuordnung des einen exportierbaren Resultsets findings, in der Form {"findings":"#ExampleTarget"}: genau dieser case-sensitive Schlüssel mit dem lokalen Zielnamen als JSON-Stringwert, keine weiteren Eigenschaften. Der Zielname darf höchstens 116 Zeichen lang sein. Das Ziel muss eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte sein; globale ##Temp-Tabellen, permanente Tabellen, das reservierte Präfix #Monitor, unbekannte oder doppelte Namen/Ziele, nichtstringige Werte, leere Ziele und zusätzliche Schlüssel sind unzulässig. Das JSON muss ein Objekt sein; NULL, leer oder nur Leerzeichen ist kein gültiges TABLE-Mapping. Außerhalb TABLE sind NULL/leer/Leerzeichen zulässig; jeder nichtleere Wert löst Fehler 51011 aus. TABLE-Mapping und Ziel werden vor der Hilfeausgabe vorgeprüft, sodass ein ungültiges Mapping auch mit @Hilfe=1 fehlschlägt. Der Helper erwartet OPENJSON-kompatibles JSON und installiertes Framework. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@JsonErzeugen` | `bit` | Default: `0` | Aktiviert die zusätzliche JSON-Erzeugung nur bei exakt 1; 0 und NULL überspringen sie. SQL Server bindet Eingaben zuerst an bit und konvertiert oder verwirft abweichende Formen. Bei Aktivierung enthält @Json das Objekt meta sowie die vier Arrays services, findings, jobs und mailStatus. Die Arrays verwenden INCLUDE_NULL_VALUES; meta wird ohne INCLUDE_NULL_VALUES serialisiert, sodass NULL-Eigenschaften dort entfallen. meta enthält UTC-Erstellungszeit, Status, Partialflag und @HistoryHours. Findings und Jobs folgen @MaxZeilen; Services und Mailstatus bleiben vollständige getrennte Arrays. Die Ausgabe enthält keine Mailadressen, Empfänger, Betreffzeilen, Jobbefehle oder Meldungstexte. @Json wird am Prozedureintritt auf NULL gesetzt und bleibt bei deaktiviertem Schalter oder vorzeitigem Hilfe-RETURN NULL. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Json` | `nvarchar(max) OUTPUT` | Default: `NULL` | Empfängt bei @JsonErzeugen=1 das erzeugte JSON nvarchar(max) mit meta-, services-, findings-, jobs- und mailStatus-Elementen. Der Wert wird zu Beginn immer auf NULL gesetzt und nur nach abgeschlossener Erhebung bei aktiviertem JSON-Schalter befüllt; bei Hilfe-RETURN und Fehlern vor der Erzeugung bleibt er NULL. NULL-Werte werden in den Kontextarrays erhalten. Findings und Jobs verwenden die Begrenzung aus @MaxZeilen. Status-/Fehler-OUTPUTs werden bei Hilfe-RETURN nicht aktualisiert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@PrintMeldungen` | `bit` | Default: `1` | Wird in der Implementierung nicht gelesen und steuert daher weder PRINT-Ausgaben noch Resultsets. Die fest codierten PRINT-Zeilen der Hilfeausgabe erscheinen bei @Hilfe=1 unabhängig von diesem Schalter. NULL sowie 0 oder 1 ändern das Verhalten nicht; eine Bit-Konvertierung oder ein Konvertierungsfehler geschieht vor dem Prozedurcode. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Hilfe` | `bit` | Default: `0` | Bei exakt 1 gibt die Procedure ihre Hilfe mit PRINT aus und kehrt vor der Analyse mit RETURN zurück. 0 und NULL führen in den normalen Ablauf; abweichende Formen werden beim Binden an bit konvertiert oder abgewiesen. @Json wird zuvor auf NULL gesetzt. Die Status-, Partial- und Fehler-OUTPUTs werden im Hilfezweig nicht belegt und behalten ihre Eingangs-/Bindungswerte. Die Ausgabeoptionen werden vor diesem Zweig geprüft: ein ungültiger Nicht-TABLE-Wert von @ResultTablesJson oder ein fehlerhafter TABLE-Preflight kann daher trotz Hilfe einen Fehler auslösen. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | Default: `NULL` | Empfängt genau einen der vier Modulstatuswerte: INVALID_PARAMETER bei einem nach erfolgreicher Cutoff-Berechnung erkannten ungültigen Historien-, Zeilen- oder Ausgabewert; AVAILABLE_LIMITED bei mindestens einem abgefangenen Quellenfehler; AVAILABLE_WITH_FINDING bei mindestens einem HIGH-/MEDIUM-Finding oder einem nicht laufenden sichtbaren Agentdienst ohne Quellenfehler; AVAILABLE sonst, auch bei ausschließlich INFO-Findings. Der Status wird vor der Ausgabegrenze auf der vollständigen Erhebung bestimmt. Binden Sie eine varchar(40)-Variable mit OUTPUT. Bei @Hilfe=1 sowie bei einem Fehler des frühen TABLE-Preflights oder der Cutoff-Berechnung bleibt die Eingangs-/Bindungsvariable unverändert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@IsPartialOut` | `bit OUTPUT` | Default: `NULL` | Empfängt das Partialflag: 0 bei vollständiger Erhebung, 1 bei ungültigem Historien-/Zeilen-/Ausgabewert oder einem abgefangenen Fehler eines Quellenpfads. Ein ausgelassener optionaler Job- oder Mailpfad allein setzt das Flag nicht. Bei @Hilfe=1 sowie bei Fehlern im frühen Ausgabepreflight wird der Wert vor Abbruch/RETURN nicht beschrieben. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@ErrorNumberOut` | `int OUTPUT` | Default: `NULL` | Empfängt die erste abgefangene SQL-Quellenfehlernummer oder NULL, wenn kein Quellenfehler erfasst wurde. Ein ungültiger Analyseparameter setzt keinen Fehlernummernwert. Bei @Hilfe=1 und bei einem Fehler des frühen Output-Mappings erfolgt keine Zuweisung. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | Default: `NULL` | Empfängt NULL ohne abgefangenen Quellenfehler oder den ersten abgefangenen SQL-Fehler mit einem quellenspezifischen Präfix in nvarchar(2048). Bei ungültigen Analyseparametern steht hier eine generische Parameterfehlermeldung; spätere Quellenfehler überschreiben die erste gespeicherte Fehlermeldung nicht. Die Texte können SQL-Fehlerdetails enthalten, umfassen aber keine gelesenen Mail- oder Jobnachrichten. Bei Hilfe-RETURN und frühem Mappingfehler erfolgt keine Zuweisung. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |

## Aufrufbeispiele zu den Parameterverträgen

Die Beispiele verwenden synthetische Namen. Eine positive Zeilengrenze begrenzt die Ausgabe und ersetzt keinen Filter auf vorherige Katalog- oder Historyzugriffe. Das TABLE-Beispiel benötigt eine neue, leere lokale Tabelle und entfernt sie auch bei einem Fehler.

```sql
EXEC [monitor].[USP_AgentMonitoringAnalysis] @Hilfe=1;

EXEC [monitor].[USP_AgentMonitoringAnalysis] @HistoryHours=24, @MaxZeilen=100, @ResultSetArt='RAW';

DECLARE @AgentMonitoringJson nvarchar(max), @AgentMonitoringStatus varchar(40), @AgentMonitoringPartial bit, @AgentMonitoringError int, @AgentMonitoringMessage nvarchar(2048); EXEC [monitor].[USP_AgentMonitoringAnalysis] @HistoryHours=24, @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@AgentMonitoringJson OUTPUT, @StatusCodeOut=@AgentMonitoringStatus OUTPUT, @IsPartialOut=@AgentMonitoringPartial OUTPUT, @ErrorNumberOut=@AgentMonitoringError OUTPUT, @ErrorMessageOut=@AgentMonitoringMessage OUTPUT; SELECT @AgentMonitoringStatus AS [StatusCode], @AgentMonitoringPartial AS [IsPartial], @AgentMonitoringError AS [ErrorNumber], @AgentMonitoringMessage AS [ErrorMessage], @AgentMonitoringJson AS [Json];

CREATE TABLE #AgentMonitoring_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AgentMonitoringAnalysis] @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#AgentMonitoring_HelpExample"}'; SELECT * FROM #AgentMonitoring_HelpExample; DROP TABLE #AgentMonitoring_HelpExample; END TRY BEGIN CATCH DROP TABLE #AgentMonitoring_HelpExample; THROW; END CATCH;

EXEC [monitor].[USP_AgentMonitoringAnalysis] @HistoryHours=24, @MitJobStatus=0, @MitDatabaseMail=0, @MaxZeilen=100, @ResultSetArt='RAW';
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `findings`. RAW liefert fünf Resultsets mit Modulstatus, Services, Findings, Jobs und Mailaggregation. CONSOLE liefert ausschließlich die Findingsausgabe; bei leerem Findingsbestand enthält sie eine Hinweiszeile. JSON wird separat über `@Json` ausgegeben. Partialität und Fehlerdetails stehen in den Status-/Fehlerausgaben; eine separate Warningsammlung gibt es nicht. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem Jobproblem, Alert, Operator, Mailstatus oder normalisierten Finding.

## So lesen

Prüfen Sie Jobfehler, Alertkonfiguration, Operatorerreichbarkeit und Mailpfad getrennt und verbinden Sie die Ergebnisse anschließend.

## Warum kann das problematisch sein?

Ein Fehler kann unbemerkt bleiben, wenn Alert, Operator oder Mailpfad fehlt.

## Wann ist es kein Problem?

Database Mail ist nicht zwingend, wenn ein dokumentierter alternativer Alarmweg existiert.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Kritischer Job schlägt wiederholt fehl, aber kein aktiver Operator ist erreichbar: höheres Betriebsrisiko als der Jobfehler allein. Prüfen Sie Jobdetails und Monitoringprozess.

**Ähnlich aussehender Gegenfall:** Database Mail ist nicht zwingend, wenn ein dokumentierter alternativer Alarmweg existiert. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Ein leerer Historypfad kann Retention/Cleanup, deaktivierte Komponente oder falschen Scope bedeuten; er beweist keine erfolgreiche Ausführung.

Bei `USP_AgentMonitoringAnalysis` kennzeichnet `IsPartial=1` einen ungültigen Analyseparameter oder einen abgefangenen Quellenfehler. Der Status unterscheidet diese Fälle durch `INVALID_PARAMETER` beziehungsweise `AVAILABLE_LIMITED`. Ein positives Limit kann Findings- oder Jobzeilen ausblenden; der Modulstatus wird vor der Ausgabegrenze bestimmt. NULL-Felder können unbekannte, nicht anwendbare oder nicht auflösbare Werte darstellen. Status und Fehlerangaben sind deshalb zusammen mit den Fachergebnissen zu lesen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Aktueller Service-/Alert-/Operator-/Schedulezustand, der letzte Job-Outcome und 24 Stunden Alertaktivität beziehungsweise aggregierter Database-Mail-Status. |
| Teuerster Pfad | `@HistoryHours = 8760`, beide optionalen Pfade aktiv und unbegrenzte Ausgabe auf einer msdb mit umfangreicher Job- und Mailhistorie. Einen Datenbank- oder Jobfilter besitzt die Procedure nicht. |
| Haupttreiber | Zahl der Jobs, Alerts, Operatoren und Schedules, die gesamte sichtbare Job-Outcome-Historie sowie Database-Mail-Zeilen innerhalb `@HistoryHours`. Das spätere Findingslimit verkleinert diese vorgelagerte msdb-Aggregation nicht. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_AgentMonitoringAnalysis ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU und I/O auf Katalogen beziehungsweise msdb-Historie; TempDB für Korrelation und Transfer bei langen Meldungen. |
| Begrenzungswirkung | `@HistoryHours` begrenzt Alertaktivität und Mailzeilen zeitlich; Jobhistory wird für den letzten Outcome ohne Zeitfilter gelesen und danach zeitlich klassifiziert. `@MitJobStatus`/`@MitDatabaseMail` können ganze Pfade auslassen. `@MaxZeilen` wirkt erst auf fertige Findings/Jobs und begrenzt die vorherige Konfigurations- und Historyaggregation nicht. |
| Locking und Nebenwirkungen | Read-only; kurze Schema-Stability-Zugriffe auf msdb/Systemkataloge. Jobs, Backups oder Wartung laufen parallel weiter, daher ist das Ergebnis nicht atomar. |
| Schutzmechanismus | Kein High-Impact-Gate. `@HistoryHours` ist auf höchstens 8760 begrenzt; `@MitJobStatus` und `@MitDatabaseMail` lassen die beiden variablen Historypfade vollständig aus. `@MaxZeilen` schützt dagegen nur die fertige Ausgabe, nicht die vorherige Aggregation. |
| Sicherer Einsatz | Mit 24 Stunden und nur dem aktuell benötigten optionalen Pfad beginnen. Da kein Jobfilter existiert, lange Lookbacks auf großen msdb-Beständen außerhalb der Lastspitze ausführen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Konfigurationssnapshot + retentionbegrenzte Historie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Jobs, Alerts und Benachrichtigungsketten gefährden geplante Betriebsabläufe?

### Technischer Hintergrund

Die Procedure verbindet Job-/Step-/Schedule-/Historyanalyse mit Alerts, Operators und Database Mail-/Notificationkontext. Laufzeitanomalien benötigen historische Vergleichswerte; Notifications benötigen korrekt verknüpfte Operator-/Mailkonfiguration.

### Datenkette

`msdb.dbo.agent_datetime`, `msdb.dbo.sysalerts`, `msdb.dbo.sysjobhistory`, `msdb.dbo.sysjobs`, `msdb.dbo.sysjobschedules`, `msdb.dbo.sysmail_allitems`, `msdb.dbo.sysnotifications`, `msdb.dbo.sysoperators`, `msdb.dbo.sysschedules`, `sys.dm_server_services`.

### Collation und Ausgabegrenzen

Die sieben Textspalten des `findings`-TABLE-Exports verwenden die
Frameworkcollation `SQL_Latin1_General_CP1_CS_AS`. RAW, CONSOLE, TABLE und
JSON verwenden dieselbe begrenzte Findingsmenge. Ein positives `@MaxZeilen`
begrenzt diese Menge nach dem bestehenden Rang HIGH, MEDIUM und anschließend
INFO, danach nach Kategorie und Scope-Name. Job-JSON besitzt eine eigene
Namensgrenze. Null und NULL sind unbegrenzt. Der Modulstatus wird vor der
Ausgabegrenze auf der vollständigen Erhebung bestimmt; eine ausgeblendete
Befundzeile ändert den Status nicht. Service- und Mailstatus bleiben getrennte
Kontextarrays.

### Source Select

Die Procedure besitzt mehrere fachlich getrennte Quellen. Der folgende Kernpfad zeigt die Beziehung für Alert-Routing; Jobzustand und Database Mail werden in separaten Zweigen gelesen:

```sql
SELECT
      [a].[id] AS [AlertId]
    , [a].[name] AS [AlertName]
    , [n].[notification_method]
    , [o].[name] AS [OperatorName]
FROM [msdb].[dbo].[sysalerts] AS [a] WITH (NOLOCK)
LEFT JOIN [msdb].[dbo].[sysnotifications] AS [n] WITH (NOLOCK)
  ON [n].[alert_id] = [a].[id]
LEFT JOIN [msdb].[dbo].[sysoperators] AS [o] WITH (NOLOCK)
  ON [o].[id] = [n].[operator_id]
WHERE [a].[enabled] = 1;
```

**Wichtig für die Eigenlast:** Die Procedure besitzt keine Alert- oder Jobfilter. Der Jobpfad liest die gesamte sichtbare Outcome-Historie für den letzten Lauf je Job; `@HistoryHours` steuert dessen zeitliche Klassifikation. Der Mailpfad liest dagegen nur Zeilen innerhalb dieses Zeitfensters. Die beiden Opt-in-Schalter können die jeweiligen Pfade auslassen; das Findingslimit verkleinert diese vorgelagerten Zugriffe nicht.

### Zeit- und Scope-Modell

Die Auswertung kombiniert aktuelle Konfiguration mit dem letzten sichtbaren Job-Outcome sowie zeitlich begrenzter Alertaktivität und Mailhistorie. Fehlende Jobhistory bleibt NULL; die Procedure liefert keine vollständige Ausführungsreihe und keine Laufzeitbaseline.

Der letzte Job-Outcome wird nach `instance_id` aus Gesamtzeilen mit positivem
`run_date` gewählt. `LatestRunDateTime` interpretiert Datum und Uhrzeit als
lokalen Startzeitpunkt. `LatestRunDuration` erhält den Integerrohwert aus
`run_duration`; das Feld enthält keine umgerechneten Sekunden. Die
Schaltag-/Dauergegenprobe auf SQL Server 2025 prüft diese bestehenden NONE-/JSON-
Felder getrennt von der Sekundenumrechnung in `USP_AgentJobs`.

Die getrennte SQL-2025-Kalendergegenprobe bestätigt bei Joboutcomes
20230229 und 20240230 den Status `AVAILABLE_LIMITED`, `isPartial=true`,
den direkt gemessenen nativen Fehler 242 und ein leeres Jobarray.
Dieselben ungültigen Werte in Stepoutcomes beeinträchtigen den gültigen
Jobgesamtoutcome in dieser Probe nicht: Monitoring meldet
`AVAILABLE_WITH_FINDING` ohne Partial- oder Fehlerstatus und erhält den
lokalen Jobstart samt Rohdauer. Die Probe verwendet NONE/JSON mit
Jobstatus an, Database Mail aus und `XACT_ABORT OFF`.

Eine weitere getrennte SQL-2025-Gegenprobe bestätigt diese Modul- und
Jobarrayzustände für 236060 und 240000 bei gültigem Datum 20240229,
jeweils als Job- oder Stepoutcome. Vier direkte Orakel messen Fehler 242.
236060 verändert Minuten und Sekunden gemeinsam. Weitere Uhrzeitwerte,
isolierte Minuten-/Sekundengrenzen und XACT_ABORT ON bleiben ungeprüft.

Eine getrennte tatsächliche SQL-2025-Ausführung eines eigenen lokalen
TSQL-Steps mit einem konfigurierten Retry und Intervall 0 bestätigt den
abschließenden Joberfolg nach kontrolliertem Erstfehler und Steperfolg.
Nach Deaktivierung des eigenen Jobs liefert NONE/JSON bei Jobstatus an und
Database Mail aus genau diesen letzten Gesamtoutcome mit Runstatus 1 und
JOB_STATE_INFORMATIONAL/INFO. Der Modulstatus ist AVAILABLE_WITH_FINDING
ohne Partial und ohne Fehlernummer/-meldung. Diese Probe bestätigt keine
laufende Retryphase, Retryerschöpfung oder allgemeine Retryzählung.

Eine spätere getrennte SQL-2025/Docker-Gegenprobe hält den eigenen Job
nach ausgeschöpftem Retry aktiviert. Der TSQL-Step scheitert in beiden
Versuchen bei einem konfigurierten Retry und Intervall 0. NONE/JSON mit
Jobstatus an und Mail aus liefert den letzten fehlgeschlagenen Gesamtoutcome
mit LatestRunStatus 0 und LATEST_JOB_RUN_FAILED_IN_WINDOW/HIGH. Der
Modulstatus bleibt AVAILABLE_WITH_FINDING ohne Partial und ohne Fehlerstatus.
Der native Jobfehler ist ein fachlicher Befund und kein Consumerfehler.
Positive Intervalle, Parallelität und andere Engines sind damit nicht geprüft.

Eine getrennte tatsächliche SQL-2025/Docker-Probe prüft drei erfolgreiche
Läufe eines eigenen aktivierten Jobs unter automatischer Vierzeilen-Retention
pro Job. Die Historycounts sind zwei, vier und vier; das erste native
Zeilenpaar verschwindet, während sämtliche Werte des zweiten erhalten bleiben.
NONE/JSON liefert in jeder Phase LatestRunStatus 1 und den Befund
ENABLED_JOB_WITHOUT_SCHEDULE/INFO. AVAILABLE_WITH_FINDING ohne Partial oder
Consumerfehler beschreibt den fehlenden Schedule dieses aktivierten Jobs.
Die Probe belegt weder globale Grenzüberschreitung noch Altersretention.

Eine getrennte tatsächliche SQL-2025/Docker-Probe prüft eine globale
Agent-Historiengrenze von sechs Zeilen bei einer Vierzeilen-Grenze pro Job.
Vier erfolgreiche Läufe zweier eigener aktivierter Jobs mit je einem TSQL-Step in der
Reihenfolge A, B, A, B hinterlassen zwei, vier, sechs und sechs Zeilen.
Das erste A-Paar verschwindet; vollständige Werte der beiden jüngeren
Paare bleiben erhalten. NONE/JSON liefert für jeden vorhandenen Job
LatestRunStatus 1 und ENABLED_JOB_WITHOUT_SCHEDULE/INFO ohne Partial oder
Consumerfehler. Andere Limits, Altersretention und Parallelität bleiben offen.

Eine getrennte tatsächliche SQL-2025/Docker-Probe bestätigt den Erfolg
eines eigenen TSQL-Steps nach einem Retry mit positivem Intervall von
einer Minute. Drei native Zeilen zeigen Retry, Steperfolg und Joberfolg.
Der noch nicht abgeschlossene Job wird nach vorhandener Retryzeile in
mindestens 50 durch Einsekunden-Waits getrennten Pollzyklen beobachtet.
Nach Abschluss und eigener Deaktivierung liefert NONE/JSON den erfolgreichen
Jobgesamtoutcome mit JOB_STATE_INFORMATIONAL/INFO bei AVAILABLE_WITH_FINDING
ohne Partial oder Consumerfehler. Während des laufenden Jobs werden keine
Consumer aufgerufen; andere Intervalle und positive Retryerschöpfung bleiben offen.

Eine getrennte tatsächliche SQL-2025/Docker-Probe bestätigt den
fehlgeschlagenen Jobgesamtoutcome nach Retryerschöpfung bei Intervall
einer Minute. Beide Versuche des eigenen TSQL-Steps scheitern kontrolliert.
Mindestens 50 durch Einsekunden-Waits getrennte Pollzyklen erfassen den
noch nicht abgeschlossenen Job nach vorhandener Retryzeile. Nach gebundenem
Abschluss meldet NONE/JSON für den weiterhin aktivierten Job
LATEST_JOB_RUN_FAILED_IN_WINDOW/HIGH bei AVAILABLE_WITH_FINDING ohne
Partial oder Consumerfehler. Consumer während des laufenden Jobs,
weitere Intervalle und Parallelität bleiben ungeprüft.

Eine spätere getrennte SQL-2025-Kalenderprobe mit XACT_ABORT ON und
jeweils frischer committable Callertransaktion erfasst eine Fehlergrenze.
Bei 20230229 und 20240230 als Joboutcome entkommt Fehler 3930 aus
AgentMonitoring; öffentliche Statusoutputs und JSON fehlen. XACT_STATE ist
danach -1. Dieselben ungültigen Stepdaten ergeben AVAILABLE_WITH_FINDING
ohne Partial oder Fehler, ein Jobarray mit einer Zeile und XACT_STATE 1.
Die sechs Quellen und Calleroptionen bleiben in allen vier Fällen erhalten;
der private Beobachter rollt jede eigene Transaktion zurück. Eine erfolgreiche
Fehlerisolation der ungültigen Joboutcomes bei ON ist damit nicht belegt.
Die Korrektur begrenzt XACT_ABORT OFF auf die Jobcollection und stellt
die ursprüngliche Einstellung vor weiteren Collections und der Ausgabe
wieder her. Eine nachfolgende SQL-2025-Gegenprobe mit denselben vier
Kalenderfällen besteht bei ON und OFF. Ungültige Joboutcomes liefern nun
AVAILABLE_LIMITED/Partial mit Fehler 242, nicht leerem ErrorMessage und
gültigem JSON; das Jobarray bleibt leer. Ungültige Stepfälle erhalten
AVAILABLE_WITH_FINDING ohne Partial oder Fehler und eine Jobzeile. Alle
eigenen Callertransaktionen bleiben schreibfähig mit XACT_STATE 1. Sechs
Quellen, TX1 und Locktimeout 31 bleiben erhalten. Der Nachweis gilt für
NONE/JSON auf SQL Server 2025; andere Collectionfehler und ungültige
Kalenderfälle im TABLE-Export bleiben ungeprüft. Eine bereits
uncommittable Callertransaktion wird nicht repariert.

Eine nachfolgende getrennte SQL-2025-Gegenprobe prüft 236060 und
240000 bei gültigem Datum 20240229 jeweils als Job- und Stepoutcome.
Bei XACT_ABORT ON und OFF bleibt die eigene frische Callertransaktion
nach jedem NONE-/JSON-Aufruf schreibfähig. Ein ungültiger Joboutcome
liefert AVAILABLE_LIMITED/Partial mit Fehler 242, nicht leerer Fehlermeldung,
gültigem JSON und leerem Jobarray. Ein ungültiger Stepoutcome erhält
AVAILABLE_WITH_FINDING ohne Partial oder Fehler und eine gültige Jobzeile.
Sechs vollständige Quellen, TX1 und Locktimeout 31 bleiben erhalten.
236060 kombiniert ungültige Minuten und Sekunden; isolierte Teilfeldgrenzen,
andere Uhrzeiten und fehlerhafte Kalenderwerte in TABLE/RAW/CONSOLE
bleiben ungeprüft.

Eine getrennte native SQL-2025-Probe führt einen eigenen TSQL-Job mit
einem Step und drei Sekunden WAITFOR ohne Retry aus. Nach Abschluss
wird der Job deaktiviert. Monitoring liefert AVAILABLE_WITH_FINDING
ohne Partial oder Fehler mit einer erfolgreichen Jobzeile und
JOB_STATE_INFORMATIONAL/INFO. LatestRunDuration entspricht den nativ
gespeicherten 4 Sekunden; LatestRunDateTime entspricht der unabhängig
aus run_date und run_time gebildeten Jobstartzeit. Der NONE-/JSON-Aufruf
erhält sechs vollständige Quellen und ON/31/TX1. Diese kurze positive
Probe belegt keine Minuten-/Stundenübergänge, lange Ausführungen oder
Durationparität anderer Ausgabearten.

Eine weitere getrennte SQL-2025-Probe isoliert ungültige Minuten und
Sekunden: 6000 entspricht 00:60:00, 60 entspricht 00:00:60. Bei gültigem
Datum 20240229 werden beide Werte als Job- und Stepoutcome geprüft.
Je zwölf NONE-/JSON-Aufrufe bei ON und OFF bleiben schreibfähig.
Beim Jobfehler liefert Monitoring AVAILABLE_LIMITED/Partial/242 mit
nicht leerer Message, gültigem JSON und leerem Jobarray. Beim Stepfehler
erhält es AVAILABLE_WITH_FINDING ohne Partial oder Fehler und eine gültige
Jobzeile. Sechs vollständige Quellen, TX1 und Locktimeout 31 bleiben
erhalten. Andere Werte und ungültige Kalenderfälle in TABLE/RAW/CONSOLE
bleiben ungeprüft.

Eine weitere native SQL-2025-Probe führt einen eigenen TSQL-Job mit
einem Step und 63 Sekunden WAITFOR ohne Retry aus. Nach abgeschlossenem
Joberfolg wird der Job deaktiviert. Monitoring liefert AVAILABLE_WITH_FINDING
ohne Partial oder Fehler mit einer erfolgreichen Jobzeile und
JOB_STATE_INFORMATIONAL/INFO. LatestRunDuration erhält den nativen
HHmmss-Jobrohwert 103; das Feld liefert keine Sekundenumrechnung.
AgentJobs bestätigt getrennt 63 Sekunden aus demselben nativen Wert.
LatestRunDateTime entspricht der unabhängig aus run_date und run_time
gebildeten Jobstartzeit. Der NONE-/JSON-Aufruf erhält sechs vollständige
Quellen und ON/31/TX1. Diese einzelne tatsächliche Probe belegt die
Minutenkomponente eins; Stundenwerte, weitere Dauergrenzen und andere
Ausgabearten bleiben offen.

Eine getrennte native SQL-2025-Probe injiziert acht gültige Dauergrenzen
in die History eines eigenen deaktivierten Jobs mit einem definierten Step.
LatestRunDuration erhält die nativen HHmmss-Rohwerte 59, 100, 159, 200,
5959, 10000, 235959 und 240000. 240000 bezeichnet hier eine Dauer von
24 Stunden; im getrennten Feld run_time ist derselbe Integerwert eine
ungültige Uhrzeit. Monitoring liefert jeweils AVAILABLE_WITH_FINDING
ohne Partial oder Fehler mit JOB_STATE_INFORMATIONAL/INFO und dem
festen Startwert 2024-02-29T01:02:03. 32 Consumeraufrufe und acht eigene
Rollbacks erhalten sechs vollständige Quellen und den Callerzustand.
Der Job wird nicht ausgeführt. Tatsächliche Stundenläufe, fehlerhafte
Dauerformate und andere Ausgabearten bleiben ungeprüft.

Eine getrennte native SQL-2025-Probe charakterisiert drei injizierte
nicht kanonische positive Dauercodierungen. LatestRunDuration erhält
die unveränderten run_duration-Jobrohwerte 60, 6000 und 236060. Monitoring
liefert jeweils AVAILABLE_WITH_FINDING ohne Partial oder Fehler mit
JOB_STATE_INFORMATIONAL/INFO und dem festen Startwert 2024-02-29T01:02:03.
Zwölf Consumeraufrufe und drei eigene Rollbacks erhalten sechs vollständige
Quellen und den Callerzustand. Der Job wird nicht ausgeführt. Diese Probe
belegt weder Formatvalidierung noch Normalisierung, tatsächliche
Ausführungsdauer oder allgemeine semantische Zulässigkeit. Die früheren
Fehler-242-Uhrzeitproben betreffen das getrennte Feld run_time.

Eine getrennte native SQL-2025-Probe charakterisiert die selektive
Historybereinigung eines eigenen deaktivierten Jobs bei erhaltenem zweitem
Job. Vier frisch aufgebaute unabhängige Phasen liefern Gesamtcounts
8, 6, 4 und 2 sowie Zieljobcounts 6, 4, 2 und 0. Monitoring behält beide
Jobs mit JOB_STATE_INFORMATIONAL/INFO und AVAILABLE_WITH_FINDING ohne
Partial oder Fehler. Nach dem NULL-Datumspurge für den Zieljob sind nur
dessen LatestRunStatus, LatestRunDateTime und LatestRunDuration NULL;
die Historywerte des zweiten Jobs bleiben erhalten. 16 NONE-/JSON-Aufrufe
und vier eigene Rollbacks erhalten Quellen und Callerzustand. Die History
ist injiziert; tatsächliche Jobausführung, automatische Altersretention
und allgemeine Purgegarantien werden nicht belegt.

### Bewertung und Gegenprobe

Korrelieren Sie Fehlerhäufigkeit, letzten und aktuellen Lauf, typische Dauer, Schedule Miss, Retry, Alertbedingungen, Operatorzeiten und Mailstatus. Priorisieren Sie kritische Jobs nach ihrer Funktion.

### Typische Fehlinterpretation

Keine Mail bedeutet nicht kein Fehler und ein erfolgreicher Mailtest nicht funktionierende Jobnotification. P95-/Baselinewerte sind bei wenigen Läufen schwach.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Agent Jobs, Jobstepoutput, Database Mail Logs und Current State.

## Primärquellen

- [SQL Server Agent](https://learn.microsoft.com/en-us/ssms/agent/sql-server-agent?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#11-monitorusp_agentmonitoringanalysis)
