---
skill_format_version: "1.0.0"
name: "monitor.USP_InfrastructureAnalysis"
schema_name: "monitor"
object_name: "USP_InfrastructureAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Orchestriert die Phase-6-Module fehlertolerant."
source_path: "Code/07_Infrastructure/090_USP_InfrastructureAnalysis.sql"
---

# monitor.USP_InfrastructureAnalysis

## Zweck und Einsatz

Orchestriert die Phase-6-Module fehlertolerant.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_InfrastructureAnalysis] im vorgesehenen Datenbankkontext. Der Bericht ruft die gebundenen Infrastruktur-Teilanalysepfade auf; deren eigene `msdb`-/Serverquellen und Rechte können getrennt ausfallen. Ein Orchestratorstatus hebt Teilquellenfehler nicht auf.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @MitAgent | bit | nein | 1 |
| @MitAgentJobs | bit | nein | 1 |
| @MitResourceGovernor | bit | nein | 1 |
| @MitAvailabilityGroups | bit | nein | 1 |
| @MitBackupRecovery | bit | nein | 1 |
| @MitLogShipping | bit | nein | 1 |
| @MitReplication | bit | nein | 1 |
| @MitDataCapture | bit | nein | 1 |
| @MitReplicationDetails | bit | nein | 0 |
| @MitBackupChain | bit | nein | 0 |
| @MitAvailabilityDeep | bit | nein | 0 |
| @MitAgentMonitoring | bit | nein | 0 |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @MaxZeilen | int | nein | 2000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@MitAgent:** @MitAgent bit. Default ist 1. Schaltet monitor.USP_AgentStatus ein (1) oder aus (0). NULL wirkt wegen der IF-Prüfung wie aus. sonstige bit-konvertierbare Werte werden vor Eintritt von SQL Server zu bit konvertiert (ungleich 0 wird 1), Konvertierungsfehler treten davor auf. Bei Auslassung gilt 1.

**@MitAgentJobs:** @MitAgentJobs bit. Default ist 1. Schaltet monitor.USP_AgentJobs ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1.

**@MitResourceGovernor:** @MitResourceGovernor bit. Default ist 1. Schaltet monitor.USP_ResourceGovernorAnalysis ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1.

**@MitAvailabilityGroups:** @MitAvailabilityGroups bit. Default ist 1. Schaltet monitor.USP_AvailabilityGroups ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1.

**@MitBackupRecovery:** @MitBackupRecovery bit. Default ist 1. Schaltet monitor.USP_BackupRecovery ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1.

**@MitLogShipping:** @MitLogShipping bit. Default ist 1. Schaltet monitor.USP_LogShippingStatus ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1.

**@MitReplication:** @MitReplication bit. Default ist 1. Schaltet monitor.USP_ReplicationStatus ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1.

**@MitDataCapture:** @MitDataCapture bit. Default ist 1. Schaltet monitor.USP_DataCaptureStatus ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 1.

**@MitReplicationDetails:** @MitReplicationDetails bit. Default ist 0. Der bit-Parameter nimmt 0, 1 oder NULL an; bei Auslassung gilt 0. 0 fordert nur sichtbare Replikationsrollen an. 1 fordert zusätzlich Publikations-, Subscription- und Fehlerdetails aus einer online sichtbaren lokalen Distribution-Datenbank an, einschließlich der letzten Agent-Historyzeile je Subscription. Der Child prüft den ENTERPRISE_TOPOLOGY_DEEP-Pfad mit Bestätigung, Gruppe und Berechtigung; die Bestätigung allein gibt den Pfad nicht frei. Eine fehlende online sichtbare Distribution-Datenbank ergibt Partialstatus oder, ohne Basiszeilen, UNAVAILABLE_FEATURE. NULL wird weitergereicht, aber nicht geprüft und fordert keine Details an. Der Parent reicht den Wert nur bei @MitReplication=1 als @MitDistributionDetails an USP_ReplicationStatus weiter; dieser Schalter aktiviert das Modul nicht.

**@MitBackupChain:** @MitBackupChain bit. Default ist 0. Schaltet das optionale Child USP_BackupChainAnalysis ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 0.

**@MitAvailabilityDeep:** @MitAvailabilityDeep bit. Default ist 0. Schaltet das optionale Child USP_AvailabilityDeepAnalysis ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 0.

**@MitAgentMonitoring:** @MitAgentMonitoring bit. Default ist 0. Schaltet das optionale Child USP_AgentMonitoringAnalysis ein (1) oder aus (0). NULL wirkt wie aus. Bei Auslassung gilt 0.

**@DatabaseNames:** @DatabaseNames nvarchar(max). Default ist NULL. Pipe-Liste exakter einteiliger SQL-Namen für BackupRecovery, DataCaptureStatus und BackupChainAnalysis. Eckige Klammern schützen enthaltene Pipe-Zeichen und ]] maskiert eine schließende Klammer. Die Empfänger behandeln NULL, Leertext und reine Leerzeichen als keine exakte Einschränkung. Ungültige Einträge werden abgelehnt. Der Parent lehnt jede Kombination aus nicht-NULL-Liste und nicht-NULL-Muster ab.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit. Default ist 0. Der Parent prüft den Wert nicht. SQL Server bindet ihn vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung und Bindungsfehler treten vor dem Prozeduraufruf auf. Eine eigene Textnormalisierung oder Leertextauswahl erfolgt nicht. Bei Auslassung gilt 0. 0 schließt master, tempdb, model und msdb aus der Kandidatenauswahl aus. 1 lässt diese vier Datenbanken zu, sofern sie sichtbar, online und zugänglich sind und die übrigen Listen- oder Patternfilter erfüllen. Der Parent reicht den gebundenen Wert unverändert nur an BackupRecovery (@MitBackupRecovery=1), DataCaptureStatus (@MitDataCapture=1) und BackupChainAnalysis (@MitBackupChain=1) weiter. NULL wird dort erst bei erreichter Kandidatenvalidierung als INVALID_PARAMETER abgelehnt; vorherige Fehler können Vorrang haben, und der Parent garantiert keine einheitliche Statusweitergabe. Der Schalter gewährt keine zusätzlichen Datenbankrechte und aktiviert kein Kindmodul. DataCaptureStatus verarbeitet tempdb auch bei 1 nicht.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000). Default ist NULL; bei Auslassung gilt NULL und das Muster ist deaktiviert. Der Parser entfernt zuerst äußere U+0020-Leerzeichen. Er erkennt die Präfixe like:, regex: und regexi: ohne Beachtung der Groß- und Kleinschreibung; ohne bekanntes Präfix wird der gesamte Inhalt als LIKE-Muster verwendet, auch bei einem unbekannten Präfix. Nach Entfernen eines bekannten Präfixes wird nicht erneut getrimmt. NULL ergibt NONE. Leere Eingabe, nur U+0020-Leerzeichen und ein leerer Präfixrest ergeben intern EMPTY_PATTERN; bei erreichter Patternprüfung im Kindmodul wird INVALID_PARAMETER gemeldet. LIKE verwendet %, _ und [...] mit SQL_Latin1_General_CP1_CS_AS. REGEX verwendet Flag c und unterscheidet Groß- und Kleinschreibung; REGEXI verwendet Flag i und ignoriert sie. Die Präfixprüfung validiert keine Regexsyntax; Syntaxfehler entstehen erst, wenn REGEXP_LIKE tatsächlich ausgeführt wird. Regexausführung erfordert SQL Server 2025 und Compatibility Level mindestens 170 der Installationsdatenbank. Das Pattern ist keine Pipe-Liste. Im regulären Parentpfad ist jedes nicht-NULL @DatabaseNames zusammen mit einem nicht-NULL Pattern unzulässig, auch eine leere oder nur aus U+0020 bestehende Namensliste; der Hilfezweig kehrt vorher zurück. Sonst reicht der Parent das Pattern nur an aktive BackupRecovery, DataCaptureStatus und BackupChainAnalysis weiter. Der Kandidatenhelfer prüft das Pattern nur, wenn der tatsächliche Auswahl-/Parserpfad im Kindmodul erreicht wird.

**@HighImpactConfirmed:** @HighImpactConfirmed bit. Default ist 0; bei Auslassung gilt 0. SQL Server bindet den Wert vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Eingabeformen unterliegen der SQL-Typkonvertierung, eine eigene Textnormalisierung oder Leertextauswahl erfolgt nicht, und Bindungsfehler treten vor dem Prozeduraufruf auf. Der Parent prüft oder normalisiert den Wert nicht und reicht ihn unverändert nur an BackupRecovery, DataCaptureStatus, BackupChainAnalysis und ReplicationStatus weiter, jeweils wenn deren eigener Schalter 1 ist. BackupRecovery und BackupChainAnalysis übergeben @AnalysisClass=NULL; 0 und 1 aktivieren dort keine Analyseklasse. DataCaptureStatus verwendet HA_DR_CURRENT ohne High-Impact-Bestätigungspflicht. Erreicht NULL bei diesen drei Children die Kandidatenprüfung, weist der gemeinsame Kandidatenhelfer den Wert als INVALID_PARAMETER ab, auch bei @AnalysisClass=NULL. Bei ReplicationStatus wird die Bestätigung nur geprüft, wenn @MitReplicationDetails=1 ist und der Pfad erreicht wird: 0 ergibt HIGH_IMPACT_CONFIRMATION_REQUIRED vor der Gruppenprüfung, NULL ist ungültig, und 1 bestätigt nur die Anforderung. Die aktuelle Zugriffspolicy und erforderlichen SQL-Rechte gelten weiterhin. Bei deaktiviertem Detailpfad wird der Wert dort nicht geprüft. Vorherige Fehler können die Prüfungen verhindern. Ein Kindstatus ist keine garantierte Parent-Statusausgabe. Der Schalter erteilt keine Berechtigung und aktiviert kein Kindmodul.

**@MaxZeilen:** @MaxZeilen int. Default ist 2000. Eine positive ganze Zahl begrenzt die Ergebnisse der jeweiligen Empfänger. NULL oder 0 bedeutet dort unbegrenzt. AgentStatus erhält den Parameter nicht. Negative Werte ergeben bereits im Parent INVALID_PARAMETER. Die Modulstatusliste wird nicht gekürzt.

**@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. NULL wird zunächst zu leerem Text normalisiert. andernfalls werden äußere Leerzeichen getrimmt und der Vergleich erfolgt groß-/kleinschreibungsunabhängig. Zulässig sind RAW, CONSOLE, TABLE, NONE. RAW liefert Summary und Modultabelle mit technischen Spalten. CONSOLE lässt den internen Console-Adapter beschriftete Ergebnisse ausgeben. NONE unterdrückt fachliche Resultsets. TABLE exportiert ausschließlich moduleStatus in das Ziel aus @ResultTablesJson. Vor den Children werden TABLE und CONSOLE intern zu NONE normalisiert und dämpfen damit Childresultsets. Andere Werte ergeben INVALID_PARAMETER, außer der vorherige Hilfezweig kehrt zurück. Bei Auslassung gilt CONSOLE.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Nur bei @ResultSetArt=TABLE wird ein nichtleeres JSON-Objekt benötigt, mit genau dem case-sensitiven Schlüssel "moduleStatus" und Stringwert des Zielnamens, z.B. {"moduleStatus":"#InfraExample"}. Ziel muss eine bereits angelegte, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte sein. globale ##-, #Monitor*- oder überlange Ziele sind unzulässig. Der Helper validiert das einzelne Ziel und wirft bei Fehlern 51011 vor Hilfezweig/Childzugriff. Außerhalb TABLE werden NULL, leerer oder nur aus Leerzeichen bestehender Text ignoriert. nichtleere Werte lösen 51011 aus, ebenfalls vor Hilfe. Bei Auslassung gilt NULL.

**@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. Bei 1 erzeugt der Parent @Json OUTPUT einschließlich meta, benannter Childfelder und warnings. deaktivierte/fehlende Childobjekte stehen als JSON null. Bei 0 oder NULL wird kein JSON erzeugt und @Json bleibt NULL. Child-JSON wird ebenfalls nur angefordert, wenn dieser Schalter 1 ist. SQL-Bitkonvertierung erfolgt vor Eintritt. bei Auslassung gilt 0.

**@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. OUTPUT-Parameter: mit einer nvarchar(max)-Variablen als @Json=@Variable OUTPUT binden. Der Parent setzt ihn zu Beginn auf NULL und befüllt ihn nur bei @JsonErzeugen=1. Ohne OUTPUT-Bindung wird kein Wert in eine Aufrufervariable kopiert.

**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1; bei Auslassung gilt 1. SQL Server bindet den Parameter vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Eingabeformen unterliegen der SQL-Typkonvertierung, eine eigene Textnormalisierung oder Leertextauswahl erfolgt nicht, und Bindungsfehler treten vor dem Prozeduraufruf auf. Der Parent reicht den Wert unverändert an bis zu elf Children weiter, jeweils nur wenn deren eigener Schalter 1 ist, und leitet daraus keine eigene Meldung ab. Acht Children verwenden genau 1 als Freigabe optionaler Severity-10-RAISERROR-Meldungen: AgentStatus, AgentJobs, ResourceGovernorAnalysis, AvailabilityGroups, BackupRecovery, LogShippingStatus, ReplicationStatus und DataCaptureStatus. Meldungen erscheinen dort nur bei den jeweiligen Fehler-, Status- oder Hinweisbedingungen; auch bei 1 kann die Ausgabe leer bleiben. 0 und NULL unterdrücken diese optionalen Meldungen. BackupChainAnalysis, AvailabilityDeepAnalysis und AgentMonitoringAnalysis binden den Wert, lesen ihn aber nicht; 0, 1 und NULL ändern dort die Ausgabe nicht. Der Parameter unterdrückt keine beliebigen SQL-Fehler und ändert weder Modulstatus noch Aktivierung, Resultsets oder JSON. Die Hilfeausgabe wird separat durch @Hilfe gesteuert.

**@Hilfe:** @Hilfe bit. Default ist 0. Bei 1 gibt die Procedure ihre knappe Hilfe mit PRINT aus und kehrt vor Childaufrufen zurück. NULL wirkt wie 0. SQL konvertiert vor Eintritt zu bit. TABLE-Zuordnung wird vorher geprüft. bei TABLE ist der Preflight somit auch im Hilfemodus aktiv, und ein nichtleeres ResultTablesJson außerhalb TABLE löst ebenfalls vorher Fehler 51011 aus. Ungültige normale Parameter werden nach diesem Hilfe-Rücksprung erst als INVALID_PARAMETER gemeldet. Bei Auslassung gilt 0.

## Resultate und Ausgabe

Je aktiviertem Modul RAW oder CONSOLE sowie Modulstatus; NONE unterdrückt alle fachlichen Resultsets.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname NOT NULL , [StatusCode] varchar(40) NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_InfrastructureAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_InfrastructureAnalysis

Beispiel 1. EXEC [monitor].[USP_InfrastructureAnalysis] @Hilfe=1;

Beispiel 2. EXEC [monitor].[USP_InfrastructureAnalysis] @MitAgent=0, @MitAgentJobs=0, @MitResourceGovernor=1, @MitAvailabilityGroups=0, @MitBackupRecovery=0, @MitLogShipping=0, @MitReplication=0, @MitDataCapture=0, @MaxZeilen=50, @ResultSetArt='RAW';

Beispiel 3. DECLARE @ResultJson nvarchar(max); EXEC [monitor].[USP_InfrastructureAnalysis] @MitAgent=0, @MitAgentJobs=0, @MitResourceGovernor=1, @MitAvailabilityGroups=0, @MitBackupRecovery=0, @MitLogShipping=0, @MitReplication=0, @MitDataCapture=0, @MaxZeilen=50, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT; SELECT @ResultJson AS [Json];

Beispiel 4. CREATE TABLE #InfrastructureAnalysis_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_InfrastructureAnalysis] @MitAgent=0, @MitAgentJobs=0, @MitResourceGovernor=1, @MitAvailabilityGroups=0, @MitBackupRecovery=0, @MitLogShipping=0, @MitReplication=0, @MitDataCapture=0, @MaxZeilen=50, @ResultSetArt='TABLE', @ResultTablesJson=N'{"moduleStatus":"#InfrastructureAnalysis_HelpExample"}'; SELECT * FROM #InfrastructureAnalysis_HelpExample; DROP TABLE #InfrastructureAnalysis_HelpExample; END TRY BEGIN CATCH DROP TABLE #InfrastructureAnalysis_HelpExample; THROW; END CATCH;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_InfrastructureAnalysis
Version      : 2.1.0
Stand        : 2026-07-17
Typ          : Stored Procedure
Zweck        : Orchestriert die Phase-6-Module fehlertolerant.
SQL-Version  : SQL Server 2019 oder neuer.
Datenbankscope: @DatabaseNames ist eine bracket-aware Pipe-Liste; NULL bedeutet
               alle zulässigen Datenbanken. @DatabaseNamePattern ist alternativ.
Resultsets   : Je aktiviertem Modul RAW oder CONSOLE sowie Modulstatus;
               NONE unterdrückt alle fachlichen Resultsets.
JSON         : meta und benannte Modulobjekte agent, agentJobs,
               resourceGovernor, availabilityGroups, backupRecovery,
               logShipping, replication, dataCapture sowie warnings.
Berechtigung : Das Framework vergibt keine Rechte und ändert keine Konfiguration.
Änderungen   : 2.1.0 - Backupketten, tiefe AG- und Agent-Monitoring-Evidenz
                         als opt-in Teilmodule ergänzt.
               2.0.0 - @AlleDatenbanken entfernt; einheitlicher Datenbankscope,
                         Ausgabeadapter und JSON-Orchestrierung.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_InfrastructureAnalysis
Beispiel 1. EXEC [monitor].[USP_InfrastructureAnalysis] @Hilfe=1;
Beispiel 2. EXEC [monitor].[USP_InfrastructureAnalysis] @MitAgent=0, @MitAgentJobs=0, @MitResourceGovernor=1, @MitAvailabilityGroups=0, @MitBackupRecovery=0, @MitLogShipping=0, @MitReplication=0, @MitDataCapture=0, @MaxZeilen=50, @ResultSetArt='RAW';
Beispiel 3. DECLARE @ResultJson nvarchar(max); EXEC [monitor].[USP_InfrastructureAnalysis] @MitAgent=0, @MitAgentJobs=0, @MitResourceGovernor=1, @MitAvailabilityGroups=0, @MitBackupRecovery=0, @MitLogShipping=0, @MitReplication=0, @MitDataCapture=0, @MaxZeilen=50, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT; SELECT @ResultJson AS [Json];
Beispiel 4. CREATE TABLE #InfrastructureAnalysis_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_InfrastructureAnalysis] @MitAgent=0, @MitAgentJobs=0, @MitResourceGovernor=1, @MitAvailabilityGroups=0, @MitBackupRecovery=0, @MitLogShipping=0, @MitReplication=0, @MitDataCapture=0, @MaxZeilen=50, @ResultSetArt='TABLE', @ResultTablesJson=N'{"moduleStatus":"#InfrastructureAnalysis_HelpExample"}'; SELECT * FROM #InfrastructureAnalysis_HelpExample; DROP TABLE #InfrastructureAnalysis_HelpExample; END TRY BEGIN CATCH DROP TABLE #InfrastructureAnalysis_HelpExample; THROW; END CATCH;
```

