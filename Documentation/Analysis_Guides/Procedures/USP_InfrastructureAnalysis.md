# [monitor].[USP_InfrastructureAnalysis]

**Bereich:** Infrastruktur, Orchestrator<br>
**Zweck:** Orchestriert Agent, Resource Governor, HA, Backup, Log Shipping, Replikation und Data Capture.<br>
**Beobachtungsart:** nicht atomarer Mix aus Konfiguration, Runtime und Historie<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Infrastrukturmodule sollen als Triage in einem kontrollierten Lauf zusammengeführt werden?** Sie unterstützt die Entscheidung, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_InfrastructureAnalysis] @MitAgent=0, @MitAgentJobs=0, @MitResourceGovernor=1, @MitAvailabilityGroups=0, @MitBackupRecovery=0, @MitLogShipping=0, @MitReplication=0, @MitDataCapture=0, @MaxZeilen=50, @ResultSetArt='CONSOLE';
```

Aktivieren Sie Tiefenmodule nur bei konkreter Fragestellung.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter

| Parameter | Typ | Default | Eingabe und Wirkung |
|---|---|---|---|
| `@MitAgent` | `bit` | `1` | Schaltet monitor.USP_AgentStatus ein (1) oder aus (0). NULL wirkt wegen der IF-Prüfung wie aus. sonstige bit-konvertierbare Werte werden vor Eintritt von SQL Server zu bit konvertiert (ungleich 0 wird 1), Konvertierungsfehler treten davor auf. Bei Auslassung gilt 1. |
| `@MitAgentJobs` | `bit` | `1` | Schaltet monitor.USP_AgentJobs ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1. |
| `@MitResourceGovernor` | `bit` | `1` | Schaltet monitor.USP_ResourceGovernorAnalysis ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1. |
| `@MitAvailabilityGroups` | `bit` | `1` | Schaltet monitor.USP_AvailabilityGroups ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1. |
| `@MitBackupRecovery` | `bit` | `1` | Schaltet monitor.USP_BackupRecovery ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1. |
| `@MitLogShipping` | `bit` | `1` | Schaltet monitor.USP_LogShippingStatus ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1. |
| `@MitReplication` | `bit` | `1` | Schaltet monitor.USP_ReplicationStatus ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1. |
| `@MitDataCapture` | `bit` | `1` | Schaltet monitor.USP_DataCaptureStatus ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1. |
| `@MitReplicationDetails` | `bit` | `0` | Der Parameter nimmt 0, 1 oder NULL an; bei Auslassung gilt 0. 0 fordert nur sichtbare Replikationsrollen an. 1 fordert zusätzlich Publikations-, Subscription- und Fehlerdetails aus einer online sichtbaren lokalen Distribution-Datenbank an, einschließlich der letzten Agent-Historyzeile je Subscription. Der Child prüft den ENTERPRISE_TOPOLOGY_DEEP-Pfad mit Bestätigung, Gruppe und Berechtigung; die Bestätigung allein gibt den Pfad nicht frei. Eine fehlende online sichtbare Distribution-Datenbank ergibt Partialstatus oder, ohne Basiszeilen, UNAVAILABLE_FEATURE. NULL wird weitergereicht, aber nicht geprüft und fordert keine Details an. Der Parent reicht den Wert nur bei @MitReplication=1 als @MitDistributionDetails an USP_ReplicationStatus weiter; dieser Schalter aktiviert das Modul nicht. |
| `@MitBackupChain` | `bit` | `0` | Schaltet das optionale Child USP_BackupChainAnalysis ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 0. |
| `@MitAvailabilityDeep` | `bit` | `0` | Schaltet das optionale Child USP_AvailabilityDeepAnalysis ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 0. |
| `@MitAgentMonitoring` | `bit` | `0` | Schaltet das optionale Child USP_AgentMonitoringAnalysis ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 0. |
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Pipe-Liste exakter einteiliger SQL-Namen für BackupRecovery, DataCaptureStatus und BackupChainAnalysis. Eckige Klammern schützen enthaltene Pipe-Zeichen und ]] maskiert eine schließende Klammer. Die Empfänger behandeln NULL, Leertext und reine Leerzeichen als keine exakte Einschränkung. Ungültige Einträge werden abgelehnt. Der Parent lehnt jede Kombination aus nicht-NULL-Liste und nicht-NULL-Muster ab. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | Der Parent prüft den Wert nicht. SQL Server bindet ihn vor Prozedureintritt an `bit`: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung und Bindungsfehler treten vor dem Prozeduraufruf auf. Eine eigene Textnormalisierung oder Leertextauswahl erfolgt nicht. Bei Auslassung gilt 0. 0 schließt `master`, `tempdb`, `model` und `msdb` aus der Kandidatenauswahl aus. 1 lässt diese vier Datenbanken zu, sofern sie sichtbar, online und zugänglich sind und die übrigen Listen- oder Patternfilter erfüllen. Der Parent reicht den gebundenen Wert unverändert nur an BackupRecovery (`@MitBackupRecovery=1`), DataCaptureStatus (`@MitDataCapture=1`) und BackupChainAnalysis (`@MitBackupChain=1`) weiter. NULL wird dort erst bei erreichter Kandidatenvalidierung als `INVALID_PARAMETER` abgelehnt; vorherige Fehler können Vorrang haben, und der Parent garantiert keine einheitliche Statusweitergabe. Der Schalter gewährt keine zusätzlichen Datenbankrechte und aktiviert kein Kindmodul. DataCaptureStatus verarbeitet `tempdb` auch bei 1 nicht. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Alternatives Muster für die datenbankbezogenen Empfänger. Ohne Präfix oder mit LIKE: gilt SQL LIKE mit % und _. REGEX: berücksichtigt Groß- und Kleinschreibung, REGEXI: ignoriert sie. Regex benötigt SQL Server 2025 und Compatibility Level 170. NULL deaktiviert das Muster. Leere Muster sind ungültig. Nicht mit einer nicht-NULL-Liste kombinieren. |
| `@HighImpactConfirmed` | `bit` | `0` | Default 0; bei Auslassung gilt 0. SQL Server bindet den Wert vor Prozedureintritt an `bit`: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Eingabeformen unterliegen der SQL-Typkonvertierung, eine eigene Textnormalisierung oder Leertextauswahl erfolgt nicht, und Bindungsfehler treten vor dem Prozeduraufruf auf. Der Parent prüft oder normalisiert den Wert nicht und reicht ihn unverändert nur an BackupRecovery, DataCaptureStatus, BackupChainAnalysis und ReplicationStatus weiter, jeweils wenn deren eigener Schalter 1 ist. BackupRecovery und BackupChainAnalysis übergeben `@AnalysisClass=NULL`; 0 und 1 aktivieren dort keine Analyseklasse. DataCaptureStatus verwendet `HA_DR_CURRENT` ohne High-Impact-Bestätigungspflicht. Erreicht NULL bei diesen drei Children die Kandidatenprüfung, weist der gemeinsame Kandidatenhelfer den Wert als `INVALID_PARAMETER` ab, auch bei `@AnalysisClass=NULL`. Bei ReplicationStatus wird die Bestätigung nur geprüft, wenn `@MitReplicationDetails=1` ist und der Pfad erreicht wird: 0 ergibt `HIGH_IMPACT_CONFIRMATION_REQUIRED` vor der Gruppenprüfung, NULL ist ungültig, und 1 bestätigt nur die Anforderung. Die aktuelle Zugriffspolicy und erforderlichen SQL-Rechte gelten weiterhin. Bei deaktiviertem Detailpfad wird der Wert dort nicht geprüft. Vorherige Fehler können die Prüfungen verhindern. Ein Kindstatus ist keine garantierte Parent-Statusausgabe. Der Schalter erteilt keine Berechtigung und aktiviert kein Kindmodul. |
| `@MaxZeilen` | `int` | `2000` | Eine positive ganze Zahl begrenzt die Ergebnisse der jeweiligen Empfänger. NULL oder 0 bedeutet dort unbegrenzt. AgentStatus erhält den Parameter nicht. Negative Werte ergeben bereits im Parent INVALID_PARAMETER. Die Modulstatusliste wird nicht gekürzt. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | NULL wird zunächst zu leerem Text normalisiert. andernfalls werden äußere Leerzeichen getrimmt und der Vergleich erfolgt groß-/kleinschreibungsunabhängig. Zulässig sind RAW, CONSOLE, TABLE, NONE. RAW liefert Summary und Modultabelle mit technischen Spalten. CONSOLE lässt den internen Console-Adapter beschriftete Ergebnisse ausgeben. NONE unterdrückt fachliche Resultsets. TABLE exportiert ausschließlich moduleStatus in das Ziel aus @ResultTablesJson. Vor den Children werden TABLE und CONSOLE intern zu NONE normalisiert und dämpfen damit Childresultsets. Andere Werte ergeben INVALID_PARAMETER, außer der vorherige Hilfezweig kehrt zurück. Bei Auslassung gilt CONSOLE. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur bei @ResultSetArt=TABLE wird ein nichtleeres JSON-Objekt benötigt, mit genau dem case-sensitiven Schlüssel "moduleStatus" und Stringwert des Zielnamens, z.B. {"moduleStatus":"#InfraExample"}. Ziel muss eine bereits angelegte, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte sein. globale ##-, #Monitor*- oder überlange Ziele sind unzulässig. Der Helper validiert das einzelne Ziel und wirft bei Fehlern 51011 vor Hilfezweig/Childzugriff. Außerhalb TABLE werden NULL, leerer oder nur aus Leerzeichen bestehender Text ignoriert. nichtleere Werte lösen 51011 aus, ebenfalls vor Hilfe. Bei Auslassung gilt NULL. |
| `@JsonErzeugen` | `bit` | `0` | Bei 1 erzeugt der Parent @Json OUTPUT einschließlich meta, benannter Childfelder und warnings. deaktivierte/fehlende Childobjekte stehen als JSON null. Bei 0 oder NULL wird kein JSON erzeugt und @Json bleibt NULL. Child-JSON wird ebenfalls nur angefordert, wenn dieser Schalter 1 ist. SQL-Bitkonvertierung erfolgt vor Eintritt. bei Auslassung gilt 0. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Parameter: mit einer nvarchar(max)-Variablen als @Json=@Variable OUTPUT binden. Der Parent setzt ihn zu Beginn auf NULL und befüllt ihn nur bei @JsonErzeugen=1. Ohne OUTPUT-Bindung wird kein Wert in eine Aufrufervariable kopiert. |
| `@PrintMeldungen` | `bit` | `1` | Bei Auslassung gilt 1. SQL Server bindet den Wert vor Prozedureintritt an `bit`: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Eingabeformen unterliegen der SQL-Typkonvertierung, eine eigene Textnormalisierung oder Leertextauswahl erfolgt nicht, und Bindungsfehler treten vor dem Prozeduraufruf auf. Der Parent reicht den Wert unverändert an bis zu elf Children weiter, jeweils nur wenn deren eigener Schalter 1 ist, und leitet daraus keine eigene Meldung ab. Acht Children verwenden genau 1 als Freigabe optionaler Severity-10-RAISERROR-Meldungen: AgentStatus, AgentJobs, ResourceGovernorAnalysis, AvailabilityGroups, BackupRecovery, LogShippingStatus, ReplicationStatus und DataCaptureStatus. Meldungen erscheinen dort nur bei den jeweiligen Fehler-, Status- oder Hinweisbedingungen; auch bei 1 kann die Ausgabe leer bleiben. 0 und NULL unterdrücken diese optionalen Meldungen. BackupChainAnalysis, AvailabilityDeepAnalysis und AgentMonitoringAnalysis binden den Wert, lesen ihn aber nicht; 0, 1 und NULL ändern dort die Ausgabe nicht. Der Parameter unterdrückt keine beliebigen SQL-Fehler und ändert weder Modulstatus noch Aktivierung, Resultsets oder JSON. Die Hilfeausgabe wird separat durch `@Hilfe` gesteuert. |
| `@Hilfe` | `bit` | `0` | Bei 1 gibt die Procedure ihre knappe Hilfe mit PRINT aus und kehrt vor Childaufrufen zurück. NULL wirkt wie 0. SQL konvertiert vor Eintritt zu bit. TABLE-Zuordnung wird vorher geprüft. bei TABLE ist der Preflight somit auch im Hilfemodus aktiv, und ein nichtleeres ResultTablesJson außerhalb TABLE löst ebenfalls vorher Fehler 51011 aus. Ungültige normale Parameter werden nach diesem Hilfe-Rücksprung erst als INVALID_PARAMETER gemeldet. Bei Auslassung gilt 0. |

## Aufrufbeispiele

```sql
EXEC [monitor].[USP_InfrastructureAnalysis] @Hilfe=1;
```

```sql
EXEC [monitor].[USP_InfrastructureAnalysis] @MitAgent=0, @MitAgentJobs=0, @MitResourceGovernor=1, @MitAvailabilityGroups=0, @MitBackupRecovery=0, @MitLogShipping=0, @MitReplication=0, @MitDataCapture=0, @MaxZeilen=50, @ResultSetArt='RAW';
```

```sql
DECLARE @ResultJson nvarchar(max);
EXEC [monitor].[USP_InfrastructureAnalysis] @MitAgent=0, @MitAgentJobs=0, @MitResourceGovernor=1, @MitAvailabilityGroups=0, @MitBackupRecovery=0, @MitLogShipping=0, @MitReplication=0, @MitDataCapture=0, @MaxZeilen=50, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT;
SELECT @ResultJson AS [Json];
```

```sql
CREATE TABLE #InfrastructureAnalysis_HelpExample ([Seed] int NULL);
BEGIN TRY EXEC [monitor].[USP_InfrastructureAnalysis] @MitAgent=0, @MitAgentJobs=0, @MitResourceGovernor=1, @MitAvailabilityGroups=0, @MitBackupRecovery=0, @MitLogShipping=0, @MitReplication=0, @MitDataCapture=0, @MaxZeilen=50, @ResultSetArt='TABLE', @ResultTablesJson=N'{"moduleStatus":"#InfrastructureAnalysis_HelpExample"}';
SELECT * FROM #InfrastructureAnalysis_HelpExample;
DROP TABLE #InfrastructureAnalysis_HelpExample;
END TRY BEGIN CATCH DROP TABLE #InfrastructureAnalysis_HelpExample;
THROW;
END CATCH;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `moduleStatus`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

Die drei Textspalten des lokalen Modulstatus und seines TABLE-Exports
verwenden explizit `SQL_Latin1_General_CP1_CS_AS`. Deaktivierte Children
bleiben im JSON als NULL erhalten. Für die bisherigen Standardchildren
bedeutet `EXECUTED`, dass der Aufruf ohne äußeren Fehler beendet wurde;
der fachliche Status bleibt im Child-JSON zu prüfen. Ein Agent-Child mit
`UNAVAILABLE_FEATURE` ändert diese bestehende Ausführungssemantik nicht.
Die drei optionalen Vertiefungen übernehmen dagegen ihren fachlichen
Status in den Modulstatus. Einzelne Childzeitpunkte sind nicht atomar.

## Eine Zeile bedeutet

Die Granularität hängt vom Child ab: Dienst, Job, Pool, Replica, Datenbank, Backup, Log-Shipping-Paar, Replikationsobjekt oder Capturefeature.

## So lesen

Prüfen Sie zuerst den Childstatus. Unterscheiden Sie nicht verwendete Features von fehlenden Rechten und Fehlern.

## Warum kann das problematisch sein?

Ein leeres Child kann „Feature nicht eingesetzt“ oder „Quelle nicht lesbar“ bedeuten. Beide Aussagen sind fachlich verschieden.

## Wann ist es kein Problem?

Keine AG-Zeilen auf einer Standalone-Instanz sind erwartbar.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Backupchild partiell, AG-Child unavailable feature: Nur der Backupbereich benötigt Nacharbeit. Führen Sie Auffälliges Child gezielt erneut aus.

**Ähnlich aussehender Gegenfall:** Keine AG-Zeilen auf einer Standalone-Instanz sind erwartbar. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Ein leerer Historypfad kann Retention/Cleanup, deaktivierte Komponente oder falschen Scope bedeuten; er beweist keine erfolgreiche Ausführung.

Für `USP_InfrastructureAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Acht Children laufen: Agentstatus/-jobs, Resource Governor, Availability Groups, Backup/Recovery, Log Shipping, Replikation und Data Capture. Das ist eine breite Konfigurations-/Statusrunde, kein einzelner „kleiner“ Query. |
| Teuerster Pfad | Zusätzlich Distributiondetails, Backupketten, tiefe Availability-Evidenz und Agent Monitoring. Dieselben `msdb`-, HA- und Datenbankbereiche werden dabei teilweise in mehreren Children aus anderer Perspektive erneut gelesen. |
| Haupttreiber | Größe von `msdb`-Job-/Backup-/Restorehistorie, Zahl der Datenbanken und Captureobjekte, Replikations-/Distributionsmetadaten sowie AG-Replicas und -Datenbanken. Nicht aktivierte Technologien sind meist günstig, müssen aber zunächst erkannt werden. |
| Skalierung | Die Module laufen sequenziell ohne gemeinsamen Snapshot oder gemeinsamen Quellcache. Mehr aktivierte Children addieren ihre Kosten; ein breiter Datenbankscope wird von mehreren Children separat enumeriert. |
| Ressourcen | Vor allem `msdb`-I/O, Server-/HA-DMVs, Datenbankkataloge, CPU für Aggregation und JSON/Ergebnistransfer. Der Orchestrator enthält weder Sampling noch XEL-/Plan-XML-Parsing. |
| Begrenzungswirkung | `@MaxZeilen` wird je Child weitergereicht, aber nicht an `USP_AgentStatus`, dessen Quelle ohnehin konstant klein ist. Historien- und Statuschildren setzen Limits an unterschiedlichen Stellen; ein kleines Parentlimit verhindert deshalb nicht jede `msdb`-Aggregation oder Datenbankenumeration. |
| Locking und Nebenwirkungen | Read-only und sequenziell. Es werden weder Jobs gestartet noch Backup-, HA-, Replikations- oder Capturekonfigurationen geändert; Status kann sich zwischen den Childaufrufen ändern. `LOCK_TIMEOUT 0` am Parent ist keine globale Laufzeitgrenze für Children. |
| Schutzmechanismus | Die drei tieferen Zusatzmodule sind standardmäßig aus; Distributiondetails besitzen einen eigenen Schalter. `@HighImpactConfirmed` wird an BackupRecovery, DataCaptureStatus, BackupChainAnalysis und ReplicationStatus weitergereicht. Der geschützte Topologiepfad wird bei aktivierten Distributiondetails in Replication geprüft. Er ersetzt weder Datenbankscope noch Historienlimit. |
| Sicherer Einsatz | Eine Datenbank und kleines `@MaxZeilen` wählen, die vier Opt-ins aus lassen und nicht benötigte Standardchildren explizit deaktivieren. Modulstatus vor fachlichen Resultsets lesen. |
| Aussagegrenze | Ein leerer Child kann „Feature nicht genutzt“, „nicht lokal sichtbar“ oder „Berechtigung/Quelle fehlt“ bedeuten. Wegen getrennten Messzeitpunkten dürfen Job-, Backup- und HA-Zustände nicht als atomarer Infrastrukturzustand zusammeninterpretiert werden. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Infrastrukturmodule sollen als Triage in einem kontrollierten Lauf zusammengeführt werden?

### Technischer Hintergrund

Der Wrapper orchestriert Agent, Resource Governor, AG, Backup, Log Shipping, Replication und Capture. Nicht konfigurierte Features sollen als Status statt Fehler behandelt werden; Deep Children bleiben opt-in.

### Datenkette

Die Datenkette besteht aus frameworkinterner Orchestrierung; die Quellen liegen in den Childmodulen.

### Source Select

Kein einzelnes Grundselect wird verwendet. Die Procedure orchestriert Agent-, Resource-Governor-, Availability-, Backup-, Log-Shipping-, Replication- und Data-Capture-Module. Die direkten Beziehungen stehen auf den jeweiligen Child-Seiten.

**Wichtig für die Eigenlast:** Aktivieren Sie nur die für das Symptom benötigten Module. Reichen Sie Datenbank- und Zeitfilter an History-Childmodule weiter; ein finales Zeilenlimit spart deren `msdb`-, Distribution- oder HADR-Quellarbeit nicht.

### Zeit- und Scope-Modell

Die Auswertung kombiniert Snapshots und `msdb`-Historien nicht atomar.

### Bewertung und Gegenprobe

Vertiefen Sie Modulstatus zuerst, dann nur konfigurierte/auffällige Komponenten. Ein nicht vorhandenes Feature ist normal, sofern der Scope es nicht erwartet.

### Typische Fehlinterpretation

Leere Resultsets dürfen nicht quellenübergreifend als gesund zusammengefasst werden; jede Quelle besitzt eigene Retention und Berechtigung.

### Folgeanalyse

Führen Sie das betroffene Childmodul mit einem engen Scope aus.

## Primärquellen

- [SQL Server Agent](https://learn.microsoft.com/en-us/ssms/agent/sql-server-agent?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#12-monitorusp_infrastructureanalysis)
