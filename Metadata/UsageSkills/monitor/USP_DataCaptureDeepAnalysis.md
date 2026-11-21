---
skill_format_version: "1.0.0"
name: "monitor.USP_DataCaptureDeepAnalysis"
schema_name: "monitor"
object_name: "USP_DataCaptureDeepAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure vertieft Change Tracking, Change Data Capture und lokal erreichbare Replikationsmetadaten mit isolierten Quellen."
source_path: "Code/09_VersionAdaptive/070_USP_DataCaptureDeepAnalysis.sql"
---

# monitor.USP_DataCaptureDeepAnalysis

## Zweck und Einsatz

Die Procedure vertieft Change Tracking, Change Data Capture und lokal erreichbare Replikationsmetadaten mit isolierten Quellen.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

sys.change_tracking_databases, sys.change_tracking_tables, cdc.change_tables, sys.dm_cdc_log_scan_sessions, sys.dm_cdc_errors, msdb.dbo.cdc_jobs sowie lokale MSdistribution_*, MSlogreader_*, MSmerge_* und MSrepl_errors.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @SchemaNames | nvarchar(max) | nein | NULL |
| @SchemaNamePattern | nvarchar(4000) | nein | NULL |
| @ObjectNames | nvarchar(max) | nein | NULL |
| @ObjectNamePattern | nvarchar(4000) | nein | NULL |
| @FullObjectNames | nvarchar(max) | nein | NULL |
| @NurProblematisch | bit | nein | 0 |
| @ChangeTrackingClientVersion | bigint | nein | NULL |
| @CdcLatencyWarnSeconds | bigint | nein | 300 |
| @CdcCleanupGraceMinutes | bigint | nein | 60 |
| @ErrorLookbackHours | int | nein | 24 |
| @ReplicationLatencyWarnSeconds | bigint | nein | 300 |
| @ReplicationPendingCommandWarn | bigint | nein | 10000 |
| @ReplicationAgentStaleWarnMinutes | bigint | nein | 15 |
| @MaxZeilen | int | nein | 2000 |
| @LockTimeoutMs | int | nein | 0 |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max)=NULL; Default: NULL. Wählt eine oder mehrere Datenbanken als exakte, pipe-getrennte SQL-Namensliste. NULL oder nur Leerraum bedeutet keine explizite Liste; Leerraum allein wird daher wie NULL behandelt. Eine nichtleere Liste ist mit @DatabaseNamePattern exklusiv, darf jeden Datenbanknamen nur einmal case-sensitiv enthalten und muss vollständig gültig sein. Pro Element gilt höchstens 4000 Zeichen im Rohtext und höchstens 128 Zeichen für den Namen; einteilige Namen können geklammert werden, ein äußeres Paar eckiger Klammern wird durch PARSENAME ausgewertet. Ein senkrechter Strich innerhalb eines geklammerten Namens ist möglich; schließende Klammern werden als ]] maskiert. Vierteilige oder mehrteilige Datenbanknamen sind nicht zulässig. Ungültige oder doppelte Einträge liefern INVALID_PARAMETER. Bei ausgelassenem Argument gilt der angegebene Default.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit=0; Default: 0. Steuert, ob master, tempdb, model und msdb in den Datenbankkandidaten enthalten sein dürfen. Ein numerisch gebundener Wert 0 wird zu 0 und schließt sie aus; ein numerisch von 0 verschiedener Wert wird zu 1 und schließt sie ein. Bei 0 erzeugt der Helper für ausdrücklich angeforderte ausgeschlossene Systemdatenbanken eine Auswahlwarnung. NULL ist im Aufrufer ungültig und ergibt INVALID_PARAMETER. Bei ausgelassenem Argument gilt der angegebene Default.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000)=NULL; Default: NULL. Filtert die Datenbankkandidaten mit einem Pattern; NULL bedeutet kein Pattern. Ein explizites Präfix LIKE: verwendet SQL-LIKE-Syntax, REGEX: regulären Ausdruck mit case-sensitiver Auswertung und REGEXI: regulären Ausdruck mit case-insensitiver Auswertung; Präfixe werden ohne Beachtung ihrer Groß-/Kleinschreibung erkannt. Ohne Präfix wird der Text als LIKE-Pattern behandelt. Der Wert nach einem Präfix darf nicht leer sein. Das Pattern ist mit @DatabaseNames exklusiv. REGEX/REGEXI benötigen SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank; sonst meldet der Helper UNAVAILABLE_FEATURE. Bei ausgelassenem Argument gilt der angegebene Default.

**@HighImpactConfirmed:** @HighImpactConfirmed bit=0; Default: 0. Bestätigt für die gewählte Analyseklasse den erforderlichen High-Impact-Aufrufpfad. Ein numerisch gebundener Wert 0 wird zu 0 und gibt keine Bestätigung; ein numerisch von 0 verschiedener Wert wird zu 1 und bestätigt den Pfad. NULL ist ungültig. Die Bestätigung ersetzt weder die Zielauswahl noch eine Berechtigung und erklärt keine Analyse unabhängig von der Zugriffspolitik für freigegeben. Bei ausgelassenem Argument gilt der angegebene Default.

**@SchemaNames:** @SchemaNames nvarchar(max)=NULL; Default: NULL. Beschränkt CT- und CDC-Quelltabellen auf die angegebene pipe-getrennte, case-sensitive Liste einteiliger Schemanamen; NULL bedeutet kein exakter Schemascope. Nur Leerraum ist ein nichtleeres, ungültiges Element. Namenselemente dürfen höchstens 4000 Zeichen im Rohtext und der SQL-Name höchstens 128 Zeichen umfassen. Pipe trennt Elemente, außer innerhalb eines geklammerten Namens; ]] maskiert darin eine schließende Klammer. Doppelte Werte werden case-sensitiv erkannt und abgewiesen. Mit @SchemaNamePattern ist die Liste exklusiv. Sie filtert weder das Feature-Gate noch Replikationsrollen oder -agenten. Bei ausgelassenem Argument gilt der angegebene Default.

**@SchemaNamePattern:** @SchemaNamePattern nvarchar(4000)=NULL; Default: NULL. Beschränkt CT- und CDC-Quelltabellen nach Schema auf ein Pattern; NULL bedeutet kein Pattern. LIKE:, REGEX: und REGEXI: haben dieselbe Syntax wie @DatabaseNamePattern. Präfixerkennung ist case-insensitiv; ohne Präfix gilt LIKE-Syntax. Ein Präfix ohne nachfolgenden Inhalt ist ungültig. Für Schema-/Objektregex setzt eine SQL-Server-Version unter 17 global UNAVAILABLE_VERSION. Compatibility-Level unter 170 in einer ausgewählten Zieldatenbank setzt deren DatabaseStatus auf UNAVAILABLE_FEATURE und markiert sie partiell; die globale Aggregation wird dadurch AVAILABLE_LIMITED. Diese Ziel-DB-Anforderung ist von der Installationsdatenbankanforderung des @DatabaseNamePattern getrennt. Das Pattern ist mit @SchemaNames exklusiv und wirkt nicht auf Feature-Gate oder Replikationsobjekte. Bei ausgelassenem Argument gilt der angegebene Default.

**@ObjectNames:** @ObjectNames nvarchar(max)=NULL; Default: NULL. Beschränkt CT- und CDC-Quelltabellen auf die angegebene pipe-getrennte, case-sensitive Liste einteiliger Objektnamen; NULL bedeutet kein exakter Objektscope. Nur Leerraum ist ungültig. Rohes Element maximal 4000 Zeichen, SQL-Name maximal 128 Zeichen; Klammerquotierung erlaubt ein Pipe-Zeichen im Namen und ]] maskiert eine schließende Klammer. PARSENAME muss genau einen Namensbestandteil ergeben; schemaqualifizierte Namen sind hier unzulässig. Case-sensitive Duplikate werden abgewiesen. Mit @ObjectNamePattern ist die Liste exklusiv. Der Filter schränkt weder das Feature-Gate noch Replikationsmetadaten ein. Bei ausgelassenem Argument gilt der angegebene Default.

**@ObjectNamePattern:** @ObjectNamePattern nvarchar(4000)=NULL; Default: NULL. Beschränkt CT- und CDC-Quelltabellen nach Objektname anhand eines Patterns; NULL bedeutet kein Pattern. LIKE:, REGEX: und REGEXI: haben dieselbe Syntax wie @DatabaseNamePattern. Präfixerkennung ist case-insensitiv; ungekennzeichnete Texte nutzen LIKE. Ein leeres Pattern nach dem Präfix ist ungültig. Für Schema-/Objektregex setzt eine SQL-Server-Version unter 17 global UNAVAILABLE_VERSION. Compatibility-Level unter 170 in einer ausgewählten Zieldatenbank setzt deren DatabaseStatus auf UNAVAILABLE_FEATURE und markiert sie partiell; die globale Aggregation wird dadurch AVAILABLE_LIMITED. Diese Ziel-DB-Anforderung ist von der Installationsdatenbankanforderung des @DatabaseNamePattern getrennt. Mit @ObjectNames ist das Pattern exklusiv. Es filtert weder Feature-Gate noch Replikationsmetadaten. Bei ausgelassenem Argument gilt der angegebene Default.

**@FullObjectNames:** @FullObjectNames nvarchar(max)=NULL; Default: NULL. Beschränkt CT- und CDC-Quelltabellen anhand vollständiger ein-, zwei- oder dreiteiliger Objektbezüge database.schema.object, schema.object oder object; NULL bedeutet kein solcher Filter. Eine übergebene leere oder nur aus Leerraum bestehende Liste ist ungültig und ergibt INVALID_PARAMETER. Dreiteilige Bezüge müssen das Schema enthalten; vierteilige Linked-Server-Namen sind unzulässig. Je Namensbestandteil höchstens 128 Zeichen, rohes Listenelement höchstens 4000 Zeichen. Die Pipe-Liste behandelt geklammerte Namen und ]] wie die anderen Namenslisten; case-sensitive Duplikate sind ungültig. Diese Liste ist laut Helper ausschließlich und darf nicht zusammen mit @SchemaNames oder @ObjectNames angegeben werden. Sie kann mit Schema- oder Objektpattern kombiniert werden; die jeweilige Patternbedingung wird zusätzlich angewandt. Filterwirkung nur auf CT-/CDC-Tabellen, nicht auf Feature-Gate oder Replikation. Bei ausgelassenem Argument gilt der angegebene Default.

**@NurProblematisch:** @NurProblematisch bit=0; Default: 0. Steuert Findings, Change-Tracking-Tabellen, CDC-Capture-Instanzen und Replikationsagenten: 0 lässt diese Kategorien ungefiltert; ein numerisch von 0 verschiedener Wert wird zu 1 und behält bei Findings nur Severity=WARN sowie bei CT-/CDC-/Agentzeilen nur AssessmentStatus=REVIEW. Der Schalter filtert CDC-Scan-Sitzungen, CDC-Fehlergruppen, CDC-Jobs, Replikationsfehlergruppen und DatabaseStatus-/SourceStatus-Statusresultsets nicht. Davon unabhängig begrenzt @MaxZeilen die vier genannten CDC-/Replikationsfachresultsets per TOP; DatabaseStatus und SourceStatus bleiben unbegrenzt. NULL ist ungültig. Bei ausgelassenem Argument gilt der angegebene Default.

**@ChangeTrackingClientVersion:** @ChangeTrackingClientVersion bigint=NULL; Default: NULL. Gibt einen echten, zuletzt erfolgreich bestätigten Consumer-Wasserstand an, der für alle ausgewerteten Change-Tracking-Tabellen der einzigen ausgewählten Datenbank gilt. NULL bedeutet: keinen Consumervergleich durchführen und keinen Synchronisationsverlust behaupten. Der zulässige Zahlenbereich ist 0 bis 9223372036854775807; negative Werte sind ungültig. 0 ist ein expliziter Wasserstand und wird mit dem tabellenspezifischen MinValidVersion-Wert und dem datenbankweiten CurrentVersion-Wert verglichen; ein höherer Stand als CurrentVersion wird als inkonsistent bewertet. Ein Stand unter einer Tabelle-MinValidVersion kann für diesen Consumer und diese Tabelle eine vollständige inkrementelle Enumeration unmöglich machen. Mehrere Datenbanken oder unterschiedliche Consumer-Wasserstände lassen sich mit diesem einen Parameter nicht ausdrücken; bei mehr als einer ausgewählten Datenbank wird INVALID_PARAMETER gesetzt. Bei ausgelassenem Argument gilt der angegebene Default.

**@CdcLatencyWarnSeconds:** @CdcLatencyWarnSeconds bigint=300; Default: 300. Schwelle in Sekunden für die aggregierte CDC-Scan-Latenz. Zulässig sind 0 bis 315360000 einschließlich; NULL oder außerhalb des Bereichs ist INVALID_PARAMETER. 0 aktiviert den Vergleich ab Latenz 0; bei einer verfügbaren Session-0-Zeile mit SQL-NULL-Latenz greift der Vergleich nicht. Wird die Schwelle erreicht, ergibt ein CDC-Capture-Job mit IsContinuous=1 oder NULL den Finding-Status WARN und Confidence MEDIUM; bei IsContinuous=0 entsteht INFO mit Confidence LOW als Kontext für zeitgesteuertes Capture. Die DMV ist eine Momentaufnahme und kein lückenloser Verlauf. Bei ausgelassenem Argument gilt der angegebene Default.

**@CdcCleanupGraceMinutes:** @CdcCleanupGraceMinutes bigint=60; Default: 60. Zusätzliche Toleranz in Minuten auf die konfigurierte CDC-Cleanup-Retention, nicht Ersatz der Retention. Zulässig sind 0 bis 52560000 einschließlich; NULL oder außerhalb ungültig. 0 addiert keine Toleranz; positive Werte erlauben genau diesen Zusatz. Die Heuristik vergleicht Alter des ältesten verfügbaren CDC-LSN gegen Retention plus Toleranz und behauptet allein keinen Verlust. Ein WARN erfordert eine bekannte CleanupRetentionMinutes und OldestAvailableAgeMinutes strikt größer als CleanupRetentionMinutes plus Toleranz; Gleichheit genügt nicht. Bei ausgelassenem Argument gilt der angegebene Default.

**@ErrorLookbackHours:** @ErrorLookbackHours int=24; Default: 24. Zeitfenster in Stunden für CDC-Fehler aus sys.dm_cdc_errors und Replikationsfehler aus MSrepl_errors relativ zur Erfassungszeit @Now=SYSUTCDATETIME(). Zulässig sind 0 bis 876000 einschließlich; NULL oder außerhalb ungültig. 0 setzt die untere Zeitgrenze auf @Now; positive Werte verschieben sie um die angegebene Stundenzahl zurück. Beide Prädikate enthalten nur die Untergrenze und keine obere Zeitgrenze, daher können zukünftige Quellzeitstempel enthalten sein. Der Parameter wird nicht auf Distribution-Agenthistorie angewandt; deren Alter und Rückstand werden separat beurteilt. Bei ausgelassenem Argument gilt der angegebene Default.

**@ReplicationLatencyWarnSeconds:** @ReplicationLatencyWarnSeconds bigint=300; Default: 300. Warnschwelle für aus lokaler Distribution-Agenthistorie abgeleitete Delivery-Latenz in Sekunden. Zulässig sind 0 bis 315360000 einschließlich; NULL oder außerhalb ungültig. 0 vergleicht ab 0, positive Werte mit >= Schwelle. Nur lokal aggregierte Agenthistorie wird verwendet; Remote-Distributor-/Subscriber-Zustand wird nicht daraus abgeleitet. Bei ausgelassenem Argument gilt der angegebene Default.

**@ReplicationPendingCommandWarn:** @ReplicationPendingCommandWarn bigint=10000; Default: 10000. Warnschwelle für PendingCommandCount eines lokal sichtbaren Distribution-Agents. Zulässig sind 0 bis 9223372036854775807; NULL und negative Werte sind ungültig. Die Finding-Bedingung gilt ausschließlich für AgentType=DISTRIBUTION und PendingCommandCount >= Schwelle. Bei 0 erfüllt jeder nicht-NULL-Wert ab 0 die Schwelle; ein SQL-NULL-Zähler erfüllt den Vergleich nicht. Keine Remote-Distribution oder Subscriber-Daten werden abgefragt. Bei ausgelassenem Argument gilt der angegebene Default.

**@ReplicationAgentStaleWarnMinutes:** @ReplicationAgentStaleWarnMinutes bigint=15; Default: 15. Schwelle in Minuten für LastHistoryAgeMinutes lokaler Distribution-Agents. Zulässig sind 0 bis 52560000 einschließlich; NULL oder außerhalb ungültig. Ein Finding erfordert zugleich AgentType=DISTRIBUTION, LastHistoryAgeMinutes >= Schwelle und COALESCE(PendingCommandCount,0)>0. Bei 0 gilt die Altersbedingung für nichtnegative Alterswerte; ein zukünftiger History-Zeitstempel kann negatives Alter ergeben und die Bedingung verfehlen. NULL im Alterswert erfüllt den Vergleich nicht. Bei ausgelassenem Argument gilt der angegebene Default.

**@MaxZeilen:** @MaxZeilen int=2000; Default: 2000. Begrenzt die Findings-Auswahl und die fachlichen Datenresultsets je Ausgabe. NULL und 0 bedeuten unbegrenzt; positive Werte sind die jeweilige TOP-Grenze; negative Werte sind ungültig. Findings werden nach dem Problemscope zuerst nach WARN-Priorität und dann FindingOrdinal ausgewählt und sortiert. Statuskopf, DatabaseStatus und SourceStatus bleiben in RAW und JSON unbegrenzt; fachliche Datenresultsets unterliegen TOP(@Limit) und ihren ausgewiesenen Sortierungen. Das Limit wird nach Quellenlesen und Aggregation angewandt und begrenzt diese Arbeit nicht. Der positive int-Bereich reicht von 1 bis 2147483647. Bei ausgelassenem Argument gilt der angegebene Default.

**@LockTimeoutMs:** @LockTimeoutMs int=0; Default: 0. Setzt das Lock-Timeout in Millisekunden für dynamische Datenbank- und lokale Distributionsabfragen. Zulässig sind 0 bis 60000 einschließlich; NULL oder außerhalb ungültig. 0 bedeutet NOWAIT, positive Werte warten höchstens die angegebene Zeit auf Sperren; bei Timeout kann die betroffene Teilquelle als Fehler erfasst und die Gesamtausgabe partiell werden. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultSetArt:** @ResultSetArt varchar(16)='CONSOLE'; Default: 'CONSOLE'. Wählt die Ausgabeart nach Trim und Umwandlung in Großbuchstaben: CONSOLE rendert Findings in einer Console-Zeile je Finding bzw. eine verständliche Leerzeile; RAW gibt in fester Reihenfolge den Statuskopf, DatabaseStatus, SourceStatus, Findings, ChangeTrackingTable, CdcCaptureInstance, CdcScanSession, CdcErrorGroup, CdcJob, ReplicationAgent und ReplicationErrorGroup aus; TABLE schreibt ausschließlich das einzelne Resultset findings in ein Ziel aus @ResultTablesJson; NONE unterdrückt Resultsetausgabe. NULL und leere Zeichenfolge normalisieren auf einen ungültigen Wert; nur CONSOLE, RAW, TABLE und NONE sind zulässig. @ResultTablesJson ist ausschließlich mit TABLE erlaubt. JSON-Erzeugung über @JsonErzeugen/@Json ist davon unabhängig. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. Enthält für TABLE ausschließlich ein JSON-Objekt mit dem Schlüssel findings und einem JSON-Stringwert als lokalem Zieltabellennamen. Leeres oder fehlendes Mapping, zusätzliche Schlüssel, nichtstringige Werte, unbekannte Resultsetnamen, case-sensitiv doppelte Resultsetnamen und case-insensitiv doppelte Ziele sind ungültig. Der einzige erlaubte Seed ist eine leere lokale #Temp-Tabelle mit genau einer beliebigen Seed-Spalte. Zielnamen höchstens 116 Zeichen, beginnend mit #, ohne ## und ohne case-insensitives Präfix #Monitor. Preflight prüft Ziel und Seed vor HELP; ungültige Zuordnung wirft 51011. Der Writer überträgt nach der regulären OUTPUT-Zuweisung und wirft bei Fehlern 51010. TABLE-Zeilen werden nicht per OUTPUT-Parameter zurückgegeben. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. Steuert zusätzliche JSON-Erzeugung. Ein numerisch gebundener Wert 0 wird zu 0 und unterlässt das Befüllen von @Json; ein numerisch von 0 verschiedener Wert wird zu 1 und erzeugt ein JSON-Objekt. NULL ist ungültig. JSON enthält meta als eingebettetes JSON-Objekt mit module, collectedAtUtc, statusCode, isPartial, errorNumber und errorMessage sowie benannte Arrays databaseStatus, sourceStatus, findings, changeTrackingTables, cdcCaptureInstances, cdcScanSessions, cdcErrors, cdcJobs, replicationAgents und replicationErrors; leere Arrays bleiben []. Die jeweilige Sortierung und @NurProblematisch-/@MaxZeilen-Wirkung folgt den einzelnen SELECTs. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. OUTPUT-Parameter für das von @JsonErzeugen angeforderte JSON-Dokument; im Aufruf ist eine nvarchar(max)-Variable mit OUTPUT zu binden. Zu Beginn wird der Parameter auf NULL gesetzt; wenn JSON-Erzeugung aktiv ist, enthält er das JSON-Objekt samt meta und Ergebnisarrays. Bei deaktivierter Erzeugung und beim Help-Return bleibt er NULL. Er ist kein Rückgabekanal für TABLE-Zeilen; bei einem späteren THROW ist keine OUTPUT-Zustellung zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@PrintMeldungen:** @PrintMeldungen bit=1; Default: 1. Steuert ergänzende Severity-10-Statusmeldung bei einem Status außerhalb AVAILABLE und NOT_APPLICABLE. Ein numerisch gebundener Wert 0 wird zu 0 und unterdrückt die Meldung; ein numerisch von 0 verschiedener Wert wird zu 1 und gibt sie mit RAISERROR(...,10,1) WITH NOWAIT aus. NULL ist ungültig. Die strukturierte Ausgabe und OUTPUT-Statuswerte werden davon nicht unterdrückt. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit=0; Default: 0. Fordert die eingebaute PRINT-Hilfe mit Zweck, sämtlichen Parameterverträgen und Beispielaufrufen an. Nach numerischer Konvertierung nach bit führt 0 die Analyse aus; ein Wert ungleich 0 wird zu 1 und löst den Help-Return aus. NULL löst ihn nicht aus und wird nicht in der allgemeinen NULL-Prüfung erfasst. Vor dem Hilfezweig wird die TABLE-Zuordnung geprüft und @Json auf NULL gesetzt. Bei der frühen Rückkehr werden die vier Diagnose-OUTPUT-Parameter nicht neu zugewiesen. Bei ausgelassenem Argument gilt der angegebene Default.

**@StatusCodeOut:** @StatusCodeOut varchar(40)=NULL OUTPUT; Default: NULL. OUTPUT liefert den globalen Statuscode in eine Aufrufer-Variable vom Typ varchar(40), die mit OUTPUT gebunden wird; bei einem späteren THROW ist keine OUTPUT-Zustellung zugesichert. Die 13 global erreichbaren Codes sind: AVAILABLE (alle ausgewerteten Datenbank- und Quellenpfade ohne Partialität; kein WARN-Finding), AVAILABLE_LIMITED (mindestens eine Datenbank oder Teilquelle ist eingeschränkt; Ergebnis ist partiell), AVAILABLE_WITH_FINDING (mindestens ein WARN-Finding bei sonst vollständiger Evidenz), NOT_APPLICABLE (kein auswertbarer Datenbankscope oder keine anwendbare Analyse), INVALID_PARAMETER (ungültige Parameter, Kombination oder CT-Wasserstand für mehr als eine ausgewählte Datenbank), UNAVAILABLE_VERSION (Schema-/Objektregex wurde auf SQL Server vor Version 17 angefordert), UNAVAILABLE_FEATURE (globaler Rückgabecode des Datenbankkandidaten-Helpers, wenn DatabaseNamePattern mit Regex auf Engine vor Version 17 oder Installationsdatenbank-Compatibility-Level unter 170 nicht verfügbar ist), ERROR_HANDLED (direkt propagierter Fehlerstatus des Namensfilter-Helpers 084 nach einem sonstigen behandelten Fehler), TIMEOUT (direkt propagierter Sperrtimeoutstatus des Namensfilter-Helpers 084), DENIED_PERMISSION (direkt propagierter Berechtigungsstatus des Namensfilter-Helpers 084), INTERNAL_ERROR (interner Fehlerstatus eines aufgerufenen Vorbereitungshelpers), HIGH_IMPACT_CONFIRMATION_REQUIRED (die Analyseklassenrichtlinie verlangt eine High-Impact-Bestätigung, die fehlt) und DENIED_GROUP (die Zugriffspolitik verweigert die Gruppe für die Analyseklasse). Schema-/Objektregex auf einer ausgewählten Zieldatenbank mit Compatibility-Level unter 170 setzt deren DatabaseStatus auf UNAVAILABLE_FEATURE und macht sie partiell; global wird dieser Ziel-Datenbankfall als AVAILABLE_LIMITED aggregiert. Andere Datenbank- und Quellenfehler werden in DatabaseStatus/SourceStatus und Partialität abgebildet, nicht als die drei direkt propagierten 084-Codes. Die reguläre OUTPUT-Zuweisung erfolgt vor CONSOLE-/TABLE-Finalisierung; beim Help-Return wird der Parameter nicht neu zugewiesen. Bei einem späteren THROW ist keine Zustellung zugesichert. Frühe Parameter-, Gate- und Helfercodes bleiben maßgeblich. Solange der Status AVAILABLE ist, haben partielle Ergebnisse Vorrang vor WARN-Findings, danach folgt ein fehlender anwendbarer Scope, sonst AVAILABLE. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@IsPartialOut:** @IsPartialOut bit=NULL OUTPUT; Default: NULL. OUTPUT-Bit, das anzeigt, ob mindestens eine Teilquelle oder Datenbank fehlt/eingeschränkt ist; im Aufruf ist eine bit-Variable mit OUTPUT zu binden. 0 bedeutet, dass der globale Lauf keine Partialität markiert hat; 1 bedeutet unvollständige Evidenz, auch wenn andere Resultsets nutzbare Daten enthalten. Regulär folgt der Wert dem globalen Status und wird vor CONSOLE-/TABLE-Finalisierung zugewiesen. Beim Help-Return wird er nicht neu zugewiesen; bei späterem THROW ist keine OUTPUT-Zustellung zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@ErrorNumberOut:** @ErrorNumberOut int=NULL OUTPUT; Default: NULL. OUTPUT für die unabhängige SQL-Fehlernummer; im Aufruf ist eine int-Variable mit OUTPUT zu binden. NULL bedeutet, dass der globale Analysepfad keine solche Fehlernummer gesetzt hat. Der Wert ist von @StatusCodeOut unabhängig: ein Status kann eine Quellenlücke kennzeichnen, während die Nummer NULL bleibt. Regulär vor CONSOLE-/TABLE-Finalisierung zugewiesen; beim Help-Return nicht neu zugewiesen, und bei späterem THROW ist keine OUTPUT-Zustellung zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048)=NULL OUTPUT; Default: NULL. OUTPUT für den unabhängig vom Statuscode gehaltenen Fehler-/Hinweistext; im Aufruf ist eine nvarchar(2048)-Variable mit OUTPUT zu binden. NULL bedeutet, dass kein globaler Fehlertext gesetzt ist. Der Code initialisiert die Meldung auf NULL und setzt sie für ungültige Parameter/Scope oder bestimmte Quellenfehler; Code und Text sind getrennte Felder. Regulär vor CONSOLE-/TABLE-Finalisierung zugewiesen; beim Help-Return nicht neu zugewiesen, und bei späterem THROW ist keine OUTPUT-Zustellung zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| findings | 1 | 1 | [FindingOrdinal] bigint IDENTITY(1,1) NOT NULL , [DatabaseName] sysname NULL , [SchemaName] sysname NULL , [ObjectName] sysname NULL , [Severity] varchar(16) NOT NULL , [Confidence] varchar(16) NOT NULL , [FindingCode] varchar(120) NOT NULL , [MetricName] varchar(80) NOT NULL , [MetricValue] decimal(38,4) NULL , [ThresholdValue] decimal(38,4) NULL , [Evidence] nvarchar(1000) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL , [RecommendedNextCheck] nvarchar(1000) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_DataCaptureDeepAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Keine Nutzdaten, Change-Table-Zeilen, Replikationsbefehle, Anmeldeinformationen, Agent-Commands oder DDL. Eine entfernte oder unzugaengliche Distribution wird als Evidenzluecke und niemals als gesunder Zustand ausgegeben.

MEDIUM; Kataloge, kleine CDC-DMVs, Jobhistorie und aggregierte lokale Distributionsmetadaten.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_DataCaptureDeepAnalysis
Version      : 1.0.0
Stand        : 2026-07-18
Typ          : Stored Procedure
Zweck        : Die Procedure vertieft Change Tracking, Change Data Capture und lokal
               erreichbare Replikationsmetadaten mit isolierten Quellen.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.change_tracking_databases, sys.change_tracking_tables,
               cdc.change_tables, sys.dm_cdc_log_scan_sessions,
               sys.dm_cdc_errors, msdb.dbo.cdc_jobs sowie lokale
               MSdistribution_*, MSlogreader_*, MSmerge_* und MSrepl_errors.
Methodik     : Feature-Gate und Quellen werden best effort ausgewertet.
               Grenzwerte sind konfigurierbare Pruefheuristiken. Ein sicherer
               Change-Tracking-Synchronisationsverlust wird nur gegen eine
               explizit gelieferte Client-Version bewertet.
Grenzen      : Keine Nutzdaten, Change-Table-Zeilen, Replikationsbefehle,
               Anmeldeinformationen, Agent-Commands oder DDL. Eine entfernte
               oder unzugaengliche Distribution wird als Evidenzluecke und
               niemals als gesunder Zustand ausgegeben.
Kosten       : MEDIUM; Kataloge, kleine CDC-DMVs, Jobhistorie und aggregierte
               lokale Distributionsmetadaten.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_DataCaptureDeepAnalysis
Die Procedure führt eine rein lesende Tiefenanalyse von Change Tracking, CDC und lokal erreichbarer Replikation durch.
Die Analyse bleibt best effort, die Teilquellen werden nicht atomar gelesen und alle Findings sind auf den ausgewählten und sichtbaren Scope begrenzt. Ein CT-Verlusturteil setzt den echten zuletzt bestätigten Consumer-Wasserstand für genau eine ausgewählte Datenbank voraus; CDC- und Replikationsschwellen sind Priorisierungsheuristiken. Die Procedure liest keine Nutzdaten, Change-Tabellenzeilen, Replikationsbefehle, Zugangsdaten oder Agent-Commands und ändert keine Konfiguration.
Beispiel 1: EXEC [monitor].[USP_DataCaptureDeepAnalysis] @Hilfe=1;
Beispiel 2: EXEC [monitor].[USP_DataCaptureDeepAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @FullObjectNames=N'[ExampleDatabase].[ExampleSchema].[ExampleTable]', @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
Beispiel 3: DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_DataCaptureDeepAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];
Beispiel 4: CREATE TABLE [#DataCaptureDeepAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_DataCaptureDeepAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#DataCaptureDeepAnalysis_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#DataCaptureDeepAnalysis_HelpExample]; DROP TABLE IF EXISTS [#DataCaptureDeepAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#DataCaptureDeepAnalysis_HelpExample]; THROW; END CATCH;
Beispiel 5: EXEC [monitor].[USP_DataCaptureDeepAnalysis] @DatabaseNamePattern=N'like:ExampleDatabase%', @SchemaNamePattern=N'like:Example%', @HighImpactConfirmed=1, @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
Beispiel 6: EXEC [monitor].[USP_DataCaptureDeepAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @ChangeTrackingClientVersion=100, @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
```

