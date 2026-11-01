USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ServiceBrokerAnalysis
Version      : 1.0.0
Stand        : 2026-07-18
Typ          : Stored Procedure
Zweck        : Die Procedure analysiert sichtbare Service-Broker-Konfiguration, Queue-
               Kapazität, interne Aktivierung, Transmission-Rückstand und
               aggregierte Conversation-Zustände.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.databases, sys.service_queues, sys.services,
               sys.dm_db_partition_stats, sys.dm_broker_queue_monitors,
               sys.dm_broker_activated_tasks, sys.transmission_queue und
               sys.conversation_endpoints.
Methodik     : Feature-Gate und jede abhängige Quelle werden datenbankweise
               best effort ausgewertet. Fehlende Rechte verwerfen andere
               zugängliche Evidenz nicht.
Grenzen      : Keine Queue-Nutzdaten, keine Nachrichtenkörper, kein RECEIVE,
               keine Queue-Änderung und kein END CONVERSATION. Deaktivierte
               Queues, alte Einträge und DMV-Zustände sind Prüfhinweise; sie
               beweisen weder eine Poison Message noch deren Ursache.
Kosten       : MEDIUM; Kataloge, aggregierte Broker-Laufzeitmetadaten und
               approximative Partitionsstatistik.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ServiceBrokerAnalysis]
      @DatabaseNames                    nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen     bit            = 0
    , @DatabaseNamePattern              nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @SchemaNames                      nvarchar(max)  = NULL
    , @SchemaNamePattern                nvarchar(4000) = NULL
    , @ObjectNames                      nvarchar(max)  = NULL
    , @ObjectNamePattern                nvarchar(4000) = NULL
    , @FullObjectNames                  nvarchar(max)  = NULL
    , @NurProblematisch                 bit            = 0
    , @TransmissionAgeWarnMinutes       bigint         = 60
    , @TransmissionRowsWarn             bigint         = 1000
    , @QueueRowsWarn                    bigint         = 10000
    , @ActivationSilenceWarnMinutes     bigint         = 60
    , @ConversationRowsWarn             bigint         = 100000
    , @MaxZeilen                        int            = 2000
    , @LockTimeoutMs                    int            = 0
    , @ResultSetArt                     varchar(16)     = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                     bit            = 0
    , @Json                             nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen                   bit            = 1
    , @Hilfe                            bit            = 0
    , @StatusCodeOut                    varchar(40)     = NULL OUTPUT
    , @IsPartialOut                     bit            = NULL OUTPUT
    , @ErrorNumberOut                   int            = NULL OUTPUT
    , @ErrorMessageOut                  nvarchar(2048)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json=NULL;

    DECLARE @Now datetime2(3)=SYSUTCDATETIME();
    DECLARE @Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'));
    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @OutputMode = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @OutputMode = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'findings',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @OutputMode = 'NONE';
    DECLARE @StatusCode varchar(40)='AVAILABLE';
    DECLARE @IsPartial bit=0;
    DECLARE @ErrorNumber int=NULL;
    DECLARE @ErrorMessage nvarchar(2048)=NULL;
    DECLARE @PrintMessage nvarchar(2048)=NULL;
    DECLARE @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0
                               THEN CONVERT(bigint,9223372036854775807)
                               ELSE CONVERT(bigint,@MaxZeilen) END;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_ServiceBrokerAnalysis';
        PRINT N'Die Procedure führt eine rein lesende Tiefenanalyse sichtbarer Service-Broker-Konfiguration und aggregierter Laufzeitmetadaten durch.';
        PRINT N'Queue-Schalter, approximative Queue-Zeilen, Aktivierungs-DMVs, Transmission-Gruppen und Conversation-Zustände werden aus sichtbaren Quellen als Momentaufnahme ausgewertet.';
        PRINT N'Die Datenbankauswahl begrenzt sämtliche ausgewählten Datenbankquellen; Schema- und Queuefilter greifen zusätzlich bei Queue-Auswertungen und bei über Service, Queue und Schema zugeordneten Transmission- und Conversation-Gruppen.';
        PRINT N'Bei gesetzten Queuefiltern können Einträge ohne passenden Service-, Queue- oder Schemascope wegen der LEFT-JOIN-Filterbedingungen entfallen; ohne solche Filter bleiben die Gruppen datenbankweit.';
        PRINT N'Grenzwerte, @NurProblematisch und @MaxZeilen steuern Prüfhinweise beziehungsweise die spätere Ausgabeauswahl; sie erzeugen kein automatisches Gesundheitsurteil.';
        PRINT N'CONSOLE, RAW, TABLE und NONE steuern die Resultsets; JSON wird unabhängig mit @JsonErzeugen angefordert.';
        PRINT N'Es werden keine Queue-Nutzdaten, Nachrichtenkörper oder Conversation-Handles gelesen; es erfolgen kein RECEIVE, keine DDL-Änderung und keine Conversation-Änderung.';
        PRINT N'@DatabaseNames nvarchar(max)=NULL; Default: NULL. Die effektive Datenbankauswahl: NULL, eine leere Zeichenfolge oder nur äußere Leerzeichen bedeuten keine explizite Namensliste; dann werden alle sichtbaren Online-Benutzerdatenbanken im zulässigen Scope berücksichtigt. Andernfalls ist eine Pipe-getrennte Liste einteiliger SQL-Datenbanknamen zulässig. Pipe trennt außerhalb von [Klammern]; ]] maskiert darin eine schließende Klammer, Segmentränder werden getrimmt. Leere Elemente, strukturell ungültige Klammerung, vom PARSENAME-basierten Prüfer abgewiesene mehrteilige Namen, Rohsegmente über 4000 UTF-16-Codeeinheiten sowie case-sensitive doppelte Namen sind ungültig. Die Namensprüfung ist keine vollständige SQL-Identifiergrammatik. Ein effektiver Listenwert ist mit @DatabaseNamePattern exklusiv; eine nur aus Leerzeichen bestehende Liste gilt als nicht angegeben. Datenbanknamen werden case-sensitive abgeglichen. Die Datenbankauswahl begrenzt sämtliche Datenbankquellen; optionale Schema- und Queuefilter beeinflussen zusätzlich queuebezogene Auswertungen sowie zugeordnete Transmission- und Conversation-Gruppen. Der einzelne Name ist auf höchstens 128 Zeichen begrenzt; dies gilt zusätzlich zur Rohsegmentgrenze von 4000 UTF-16-Codeeinheiten. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@SystemdatenbankenEinbeziehen bit=0; Default: 0. Steuert, ob die vier Systemdatenbanken master, tempdb, model und msdb in die Datenbankkandidaten einbezogen werden können. Nach SQL-Konvertierung in bit bedeutet 0 Ausschluss und jeder numerische Wert ungleich 0 den Wert 1; NULL ist im normalen Analysepfad ungültig; bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Eine ausdrücklich angeforderte, ausgeschlossene Systemdatenbank wird als nicht auswertbar ausgewiesen. Der Schalter setzt weder Datenbanksichtbarkeit noch Berechtigungen außer Kraft. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@DatabaseNamePattern nvarchar(4000)=NULL; Default: NULL. Optionales Pattern für die Datenbankauswahl; NULL bedeutet keine Pattern-Einschränkung, eine leere oder nur aus Leerzeichen bestehende Eingabe ist ungültig. Äußere Leerzeichen werden vor Präfixerkennung entfernt; like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt, sonst gilt LIKE. Der Rest nach dem Präfix wird nicht erneut getrimmt. LIKE wird case-sensitive ausgewertet; % steht für beliebig viele Zeichen, _ für ein Zeichen und [...] beziehungsweise [^...] für eine Zeichenklasse oder deren Negation. Es wird kein eigenes ESCAPE-Zeichen gesetzt. regex: verwendet Flag c, regexi: Flag i; die Parserprüfung validiert nicht die Regex-Syntax. Regex-Ausführung verlangt SQL Server 2025 oder neuer und Compatibility Level 170 der Installationsdatenbank. Ein effektiver @DatabaseNames-Listenwert ist mit dem Pattern exklusiv. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@HighImpactConfirmed bit=0; Default: 0. Bestätigt den High-Impact-Aufrufpfad. Nach SQL-Konvertierung in bit bedeutet 0 den Wert 0 und jeder numerische Wert ungleich 0 den Wert 1. NULL ist im normalen Analysepfad ein INVALID_PARAMETER des Vorbereitungspfads und wird nicht als 0 behandelt. Die Procedure prüft CATALOG_DEEP; der Klassenkatalog setzt dafür RequiresGroupGate=1. Bei 0 wird HIGH_IMPACT_CONFIRMATION_REQUIRED geliefert; bei 1 wird die aktuelle Zugriffspolicy geprüft und kann DENIED_GROUP ergeben. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Die Bestätigung selbst erteilt keine Freigabe und ersetzt weder Datenbanksichtbarkeit noch Quellenberechtigungen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@SchemaNames nvarchar(max)=NULL; Default: NULL. Optionale exakte Pipe-Liste einteiliger Schemanamen. NULL lässt Schemanamen ungefiltert; eine leere oder nur aus Leerzeichen bestehende Liste ist ungültig. Pipe trennt außerhalb bracket-quotierter Bereiche, ]] maskiert darin eine schließende Klammer, Segmentränder werden getrimmt. Der PARSENAME-basierte Prüfer kontrolliert die verwendeten Namensbestandteile, aber keine vollständige SQL-Identifiergrammatik; leere, abgewiesene mehrteilige, strukturell fehlerhafte, über 4000 UTF-16-Codeeinheiten lange und case-sensitive doppelte Elemente sind ungültig. Der Abgleich ist case-sensitive über SQL_Latin1_General_CP1_CS_AS. @SchemaNames ist mit @SchemaNamePattern exklusiv; @FullObjectNames ist mit @SchemaNames und @ObjectNames jeweils exklusiv. Die Filter begrenzen Queue-Katalog- und Queue-Kapazitätsauswertungen sowie über Service, Queue und Schema zugeordnete Transmission- und Conversation-Gruppen. Ohne gesetzte Queuefilter bleiben diese Gruppen datenbankweit; bei gesetzten Filtern können nicht zuordenbare LEFT-JOIN-Zeilen entfallen. Der einzelne Name ist auf höchstens 128 Zeichen begrenzt; dies gilt zusätzlich zur Rohsegmentgrenze von 4000 UTF-16-Codeeinheiten. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@SchemaNamePattern nvarchar(4000)=NULL; Default: NULL. Optionales Schema-Pattern; NULL bedeutet keine Pattern-Einschränkung, eine leere Eingabe oder ein leerer Inhalt nach Präfix ist ungültig. Äußere Leerzeichen werden vor Präfixerkennung entfernt; like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt, sonst gilt LIKE. Der Rest nach dem Präfix wird nicht erneut getrimmt. LIKE wird case-sensitive ausgewertet; % steht für beliebig viele Zeichen, _ für ein Zeichen und [...] beziehungsweise [^...] für eine Zeichenklasse oder deren Negation. Es wird kein eigenes ESCAPE-Zeichen gesetzt. regex: verwendet Flag c, regexi: Flag i; der Parser validiert weder Regex-Syntax noch Treffer. Regex-Ausführung verlangt SQL Server 2025 oder neuer und Compatibility Level 170 in jeder ausgewerteten Zieldatenbank. Mit @SchemaNames ist das Pattern exklusiv. Der Filter wirkt auf Queue-Bezüge und auf Transmission-/Conversation-Gruppen, die über Service, Queue und Schema zugeordnet werden; ohne Queuefilter bleiben diese Gruppen datenbankweit, während gesetzte Filter nicht zuordenbare LEFT-JOIN-Zeilen ausschließen können. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ObjectNames nvarchar(max)=NULL; Default: NULL. Optionale exakte Pipe-Liste einteiliger Queue-Namen. NULL lässt Queue-Namen ungefiltert; eine leere oder nur aus Leerzeichen bestehende Liste ist ungültig. Pipe trennt außerhalb bracket-quotierter Bereiche, ]] maskiert darin eine schließende Klammer, Segmentränder werden getrimmt. Der PARSENAME-basierte Prüfer kontrolliert die verwendeten Namensbestandteile, aber keine vollständige SQL-Identifiergrammatik; leere, abgewiesene mehrteilige, strukturell fehlerhafte, über 4000 UTF-16-Codeeinheiten lange und case-sensitive doppelte Elemente sind ungültig. Der Abgleich ist case-sensitive über SQL_Latin1_General_CP1_CS_AS. Mit @ObjectNamePattern und @FullObjectNames ist die Liste jeweils exklusiv. Die Filter begrenzen Queue-Auswertungen sowie über Service und Queue zugeordnete Transmission- und Conversation-Gruppen; ohne gesetzte Queuefilter bleiben diese Gruppen datenbankweit, während gesetzte Filter nicht zuordenbare LEFT-JOIN-Zeilen ausschließen können. Der einzelne Name ist auf höchstens 128 Zeichen begrenzt; dies gilt zusätzlich zur Rohsegmentgrenze von 4000 UTF-16-Codeeinheiten. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ObjectNamePattern nvarchar(4000)=NULL; Default: NULL. Optionales Pattern für Queue-Namen; NULL bedeutet keine Pattern-Einschränkung, eine leere Eingabe oder ein leerer Inhalt nach Präfix ist ungültig. Äußere Leerzeichen werden vor Präfixerkennung entfernt; like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt, sonst gilt LIKE. Der Rest nach dem Präfix wird nicht erneut getrimmt. LIKE wird case-sensitive ausgewertet; % steht für beliebig viele Zeichen, _ für ein Zeichen und [...] beziehungsweise [^...] für eine Zeichenklasse oder deren Negation. Es wird kein eigenes ESCAPE-Zeichen gesetzt. regex: verwendet Flag c, regexi: Flag i; der Parser validiert weder Regex-Syntax noch Treffer. Regex-Ausführung verlangt SQL Server 2025 oder neuer und Compatibility Level 170 in jeder ausgewerteten Zieldatenbank. Mit @ObjectNames ist das Pattern exklusiv. Der Filter wirkt auf Queue-bezogene Auswertungen sowie über Service und Queue zugeordnete Transmission- und Conversation-Gruppen; ohne Queuefilter bleiben diese Gruppen datenbankweit, gesetzte Filter können nicht zuordenbare LEFT-JOIN-Zeilen ausschließen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@FullObjectNames nvarchar(max)=NULL; Default: NULL. Optionale Pipe-Liste ein-, zwei- oder dreiteiliger Queue-Bezüge: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt. Vierteilige Linked-Server-Bezüge werden abgewiesen. NULL bedeutet kein Qualifikationsfilter; eine leere oder nur aus Leerzeichen bestehende Liste, leere Elemente, fehlerhafte Klammerung, Rohsegmente über 4000 UTF-16-Codeeinheiten sowie case-sensitive Duplikate sind ungültig. Pipe trennt außerhalb bracket-quotierter Teile, ]] maskiert darin eine schließende Klammer, Rand-Leerzeichen werden getrimmt. Die PARSENAME-basierte Prüfung untersucht die vorhandenen Bestandteile, ist aber keine vollständige SQL-Identifiergrammatik und löst keine Datenbanken, Schemas oder Objekte auf. Nicht angegebene Datenbank- oder Schemaanteile wirken als Wildcard; vorhandene Teile werden case-sensitive mit Datenbank, Schema und Queue abgeglichen. Mit @SchemaNames oder @ObjectNames ist die Liste exklusiv; Patternfilter bleiben kombinierbar. Die Filter wirken auch auf Transmission- und Conversation-Gruppen, soweit deren LEFT JOINs einen passenden Service-/Queue-/Schema-Bezug liefern; nicht zuordenbare Zeilen können bei gesetzten Filtern entfallen. Jeder vorhandene Objekt-, Schema- und Datenbankbestandteil ist einzeln auf höchstens 128 Zeichen begrenzt; die Rohsegmentgrenze von 4000 UTF-16-Codeeinheiten gilt zusätzlich. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@NurProblematisch bit=0; Default: 0. Nach Erzeugung der vollständigen Befunde beschränkt 0 die Ausgabe nicht; jeder numerische Wert ungleich 0 wird bei Bindung an bit zu 1 und aktiviert die Problemfilter, NULL ist ungültig. Bei 1 werden Findings auf Severity WARN, Queues auf AssessmentStatus REVIEW, Transmission-Gruppen auf vorhandenen TransmissionStatus oder ein Alter mindestens @TransmissionAgeWarnMinutes und Conversation-Gruppen auf StateCode ER, abgelaufene Lifetime oder EndpointCount mindestens @ConversationRowsWarn beschränkt. Der Conversation-Test verwendet den Code ER, nicht den Beschreibungstext ERROR. Die Queuefilter können zuvor auch die Transmission- und Conversation-Gruppen nach zugeordneten Queues einschränken. DatabaseStatus und SourceStatus werden von diesem Schalter nicht gefiltert. Die Auswahl ist kein umfassendes Gesundheitsurteil; insbesondere INFO-Findings werden bei 1 ausgelassen. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@TransmissionAgeWarnMinutes bigint=60; Default: 60. Nichtnegativer Grenzwert in Minuten für das Alter des ältesten Eintrags jeder gefilterten Transmission-Gruppe. NULL oder negativ ist ungültig. Das Alter wird als DATEDIFF_BIG(MINUTE, MIN(enqueue_time), SYSUTCDATETIME()) berechnet; es zählt Minutenintervallgrenzen bis zur jeweiligen Quellenaufnahme. Eine Gruppe erzeugt bei Alter >= Grenzwert ein WARN-Finding; bei 0 wird weiterhin Alter >= 0 geprüft. Gruppen mit negativem gemessenem Alter, etwa bei einem Zeitstempel in der Zukunft, erfüllen diese Bedingung nicht. Das Finding wird nur aus gruppierten Transmission-Einträgen erzeugt, und der Wert beweist allein keinen dauerhaften Übertragungsfehler, weil Zustellung und Retention Einträge sichtbar halten können. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@TransmissionRowsWarn bigint=1000; Default: 1000. Nichtnegativer Mindestwert für die Summe der MessageCount-Werte der nach Datenbank- und gegebenenfalls Queuefiltern verbleibenden Transmission-Gruppen je Datenbank. NULL oder negativ ist ungültig. Ab Summe >= Grenzwert wird ein WARN-Kontexthinweis erzeugt. Bei 0 wird der Hinweis für jede Datenbank mit mindestens einer verbleibenden Gruppe erzeugt; eine Datenbank ohne Gruppe erzeugt keinen Hinweis. Die Momentaufnahme belegt allein weder Fehler noch Rückstandsdauer. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@QueueRowsWarn bigint=10000; Default: 10000. Nichtnegativer Grenzwert für die approximative Zeilenzahl jeder sichtbaren und gefilterten Queue. NULL oder negativ ist ungültig. Bei QueueRowsApprox >= Grenzwert wird ein WARN-Kontexthinweis erzeugt; bei 0 gilt die Bedingung für jede Queue mit nicht-NULL Zählung. Der Wert stammt aus sys.dm_db_partition_stats und ist approximativ; er sagt allein nichts über Nachrichtenalter, Durchsatz, Priorität oder fachlich zulässigen Rückstand aus. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ActivationSilenceWarnMinutes bigint=60; Default: 60. Nichtnegativer Zeitgrenzwert in Minuten seit der letzten internen Aktivierung. NULL oder negativ ist ungültig. Ein WARN-Finding wird nur geprüft, wenn die Queue nichtleer ist, eine interne Aktivierungsprozedur eingetragen und aktiviert ist, kein aktivierter Task sichtbar ist, der Monitor nicht RECEIVES_OCCURRING meldet und die Quellen für Kapazität, Monitor und aktivierte Tasks sämtlich verfügbar sind. Bei NULL von LastActivatedTime gilt die Zeitbedingung als erfüllt; andernfalls wird DATEDIFF_BIG(MINUTE, LastActivatedTime, @Now) >= Grenzwert geprüft. Bei 0 wird weiterhin DATEDIFF_BIG(MINUTE, LastActivatedTime, @Now) >= 0 geprüft; ein zukünftiger nicht-NULL-Zeitstempel kann die Bedingung verfehlen. NULL von LastActivatedTime erfüllt die Zeitbedingung ausdrücklich. Die DMV-Werte sind Momentaufnahmen und belegen keine Ursache. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ConversationRowsWarn bigint=100000; Default: 100000. Nichtnegativer Mindestwert für die Summe der EndpointCount-Werte der nach Datenbank- und gegebenenfalls Queuefiltern verbleibenden Conversation-Zustandsgruppen je Datenbank. NULL oder negativ ist ungültig. Ab Summe >= Grenzwert wird ein WARN-Kontexthinweis erzeugt. Bei 0 wird der Hinweis für jede Datenbank mit mindestens einer verbleibenden Zustandsgruppe erzeugt; eine Datenbank ohne Gruppe erzeugt keinen Hinweis. Der Wert zählt die sichtbare Momentaufnahme aus sys.conversation_endpoints und beweist allein weder ein END CONVERSATION-Leck noch einen Fehler. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MaxZeilen int=2000; Default: 2000. Begrenzt jeweils die Findings-, Queue-, Transmission- und Conversation-Ausgabeliste; die vollständigen Quellenaggregate, Findings und Statuszähler werden vorher gebildet. NULL oder 0 bedeutet keine praktische Begrenzung; positive Werte sind die jeweilige Obergrenze und negative Werte sind ungültig. Die Begrenzung gilt je Liste und weder für DatabaseStatus/SourceStatus noch als gemeinsames Gesamtlimit. Findings werden mit WARN zuerst und danach nach FindingOrdinal sortiert; Queues mit REVIEW zuerst, danach absteigender approximativer Zeilenzahl sowie Datenbank, Schema und Queue; Transmission-Gruppen nach Alter und MessageCount absteigend, danach Datenbank; Conversation-Gruppen nach EndpointCount absteigend, danach Datenbank und StateCode. Die Sortierung bestimmt, welche Zeilen innerhalb des jeweiligen Limits ausgegeben werden; der Wert begrenzt nicht die zuvor gelesenen Quelldaten. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@LockTimeoutMs int=0; Default: 0. Lock-Wartezeit in Millisekunden für die dynamischen datenbankbezogenen Quellabfragen. Zulässig sind Werte von 0 bis 60000 einschließlich; NULL oder ein Wert außerhalb des Bereichs ist ungültig. 0 bedeutet NOWAIT für diese Quellabfragen. Der Wert wird in die einzelnen dynamischen Batches eingesetzt; die dort gesetzte Lock-Wartezeit wird bei Rückkehr aus dem Batch zurückgenommen. Er begrenzt weder die Gesamtlaufzeit noch die vorgelagerte lokale Temp-Tabellenanlage, für die die Helfer eigene Zeitfenster verwenden, und garantiert keine transaktionskonsistente Momentaufnahme. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultSetArt varchar(16)=''CONSOLE''; Default: ''CONSOLE''. Bestimmt die Ausgabeform; NULL, leer oder nur aus Leerzeichen bestehend ergibt nach Trim und Großschreibung einen ungültigen Wert. Zulässige Werte: CONSOLE erzeugt eine beschriftete Findings-Ansicht und bei leerer Findings-Quelle eine verständliche Leerzeile; RAW gibt genau sieben Resultsets in dieser Reihenfolge aus: Modul-/Statusübersicht, DatabaseStatus, SourceStatus, FindingsExport, Queue, TransmissionGroup und ConversationState; TABLE schreibt nur FindingsExport in das vorab geprüfte Ziel; NONE unterdrückt die normalen Resultsets. Weitere Werte ergeben INVALID_PARAMETER. Ein nichtleeres @ResultTablesJson ist nur mit TABLE zulässig; die Prüfung erfolgt vor @Hilfe. @JsonErzeugen steuert JSON unabhängig von der Resultsetart. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL; Default: NULL. Nur mit @ResultSetArt=TABLE ist ein nichtleerer JSON-Wert zulässig; außerhalb von TABLE löst jeder nach Trim nichtleere Inhalt Fehler 51011 aus. Beim TABLE-Preflight muss ein gültiges JSON-Objekt mit genau einem case-sensitiven Schlüssel findings und einem nichtleeren Zeichenfolgenwert für die Zieltemp-Tabelle vorliegen; zusätzliche Schlüssel, falsche Werttypen und ein abweichender Schlüssel werden abgewiesen. Das Ziel muss ein leeres lokales #Temp-Objekt mit Namen bis höchstens 116 Zeichen, einzelnem #-Präfix, ohne ## und ohne das case-insensitiv reservierte Präfix #Monitor sein. Als Seed genügt genau eine beliebige Spalte; ein fertiges Findings-Schema ist nicht erforderlich. Der Preflight prüft vor @Hilfe und kann 51011 werfen; der abschließende Writer ersetzt die Seedspalte anhand des Findings-Quellschemas und kann nach den OUTPUT-Zuweisungen mit Fehler 51010 werfen. Bei einem THROW ist keine Zustellung von OUTPUT-Werten zugesichert. Wiederholte findings-Schlüssel werden auch dann abgewiesen, wenn beide exakt findings lauten; nur ein einzelnes Vorkommen ist zulässig. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@JsonErzeugen bit=0; Default: 0. Steuert unabhängig von @ResultSetArt die Erzeugung des JSON-Dokuments in @Json. Nach SQL-Konvertierung in bit bedeutet 0 keine JSON-Erzeugung und jeder numerische Wert ungleich 0 die Erzeugung; NULL ist ungültig. Das JSON besteht aus dem Objekt meta und den Arrays databaseStatus, sourceStatus, findings, queues, transmissionGroups und conversationStates. Die vier Befund-/Fachdatenarrays findings, queues, transmissionGroups und conversationStates folgen @NurProblematisch und jeweils @MaxZeilen; die beiden Statusarrays sind von diesen Begrenzungen ausgenommen. ErrorNumber und ErrorMessage in meta werden unabhängig aggregiert und können aus unterschiedlichen Quellen stammen. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Json nvarchar(max)=NULL OUTPUT; Default: NULL. Ausgabeparameter für das JSON-Dokument. Für die Bindung wird eine Variable des Parametertyps verwendet und mit OUTPUT übergeben, zum Beispiel @Json = @JsonVariable OUTPUT. Der Wert wird zu Beginn auf NULL gesetzt; nur bei @JsonErzeugen ungleich 0 wird das meta-Objekt mit den sechs Arrays databaseStatus, sourceStatus, findings, queues, transmissionGroups und conversationStates zugewiesen. Ein früher @Hilfe-Rücksprung lässt @Json NULL. Bei einem späteren THROW ist keine Zustellung des OUTPUT-Werts zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@PrintMeldungen bit=1; Default: 1. Steuert die zusätzliche Meldung mit Severity 10 und NOWAIT bei einem globalen Status außerhalb AVAILABLE und NOT_APPLICABLE. Nach SQL-Konvertierung in bit bedeutet 0 keine Meldung und jeder numerische Wert ungleich 0 die Meldung; NULL ist ungültig. Der Text nennt Statuscode und Fehlertext oder verweist auf den strukturierten Quellenstatus. Die Einstellung verändert weder Status noch Resultsets und steuert nicht die einzelnen WARN-Findings. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Hilfe bit=0; Default: 0. Bei 1 werden die eingebauten Hilfezeilen ausgegeben und die Procedure kehrt vor Quellenanalyse und den vier diagnostischen OUTPUT-Zuweisungen zurück. Nach SQL-Konvertierung in bit führt 0 zum normalen Ausführungspfad; auch NULL wird nicht als ungültig behandelt und fällt in den normalen Pfad. Jeder numerische Wert ungleich 0 wird zu 1 und aktiviert die Hilfe. @Json wird vor dem Hilfezweig auf NULL gesetzt; die vier diagnostischen OUTPUT-Parameter bleiben bei diesem Rücksprung unverändert. Der TABLE-Preflight läuft vor dem Hilfezweig und kann daher auch bei einem Hilfeaufruf Fehler 51011 werfen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@StatusCodeOut varchar(40)=NULL OUTPUT; Default: NULL. OUTPUT-Bindung für den globalen Statuscode; eine Variable des Parametertyps wird mit @StatusCodeOut = @StatusVariable OUTPUT übergeben. Die tatsächlich erreichbaren Codes sind: AVAILABLE = Quellen vollständig ausgewertet, ohne WARN-Finding und mit sichtbarem Broker-Scope; INVALID_PARAMETER = ungültige oder widersprüchliche Eingabe; UNAVAILABLE_VERSION = Regex-Pattern bei SQL Server vor Version 2025; UNAVAILABLE_FEATURE = Datenbankregex wegen fehlender Compatibility Level 170 der Installationsdatenbank nicht verfügbar; HIGH_IMPACT_CONFIRMATION_REQUIRED = CATALOG_DEEP verlangt Gruppenbestätigung, aber @HighImpactConfirmed ist 0; DENIED_GROUP = Zugriffspolicy gibt den Analysepfad nicht frei; INTERNAL_ERROR = interner Kandidaten- oder Filtervorbereitungsfehler; TIMEOUT = Fehler 1222 im Namensfilter-Preflight; DENIED_PERMISSION = dort anhand 229, 262, 297, 300, 371 oder 916 klassifizierter Fehler; ERROR_HANDLED = sonstiger vom Namensfilter-Preflight behandelter Fehler; NOT_APPLICABLE = keine auswertbare Datenbank oder kein sichtbarer Broker-Scope; AVAILABLE_LIMITED = mindestens eine Datenbankquelle ist partiell; AVAILABLE_WITH_FINDING = Quellen vollständig und mindestens ein WARN-Finding vorhanden. Frühe Parameter-, Versions-, Feature-, Gate- und Helperfehler bleiben maßgeblich. Nach der Analyse gilt die Priorität AVAILABLE_LIMITED vor AVAILABLE_WITH_FINDING, vor NOT_APPLICABLE, vor AVAILABLE. TIMEOUT, DENIED_PERMISSION und ERROR_HANDLED aus dem Namensfilter-Preflight setzen @IsPartialOut auf 1, überspringen die spätere Datenbankanalyse und bleiben bis zu diesem OUTPUT-Wert und meta.statusCode erhalten. Dieselben Statusnamen können auch datenbank- oder quellenbezogen auftreten; diese Teilbefunde führen global zu AVAILABLE_LIMITED. NOT_APPLICABLE_VISIBLE_SCOPE ist ausschließlich datenbankbezogen. Beim @Hilfe-Rücksprung wird der Parameter nicht zugewiesen; bei einem THROW ist keine OUTPUT-Zustellung zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@IsPartialOut bit=NULL OUTPUT; Default: NULL. OUTPUT-Bindung für das globale Partial-Flag; eine Variable des Parametertyps wird mit @IsPartialOut = @PartialVariable OUTPUT übergeben. 1 wird bei ungültigen Parametern sowie frühen Versions-, Feature-, Gate- oder Helperabbrüchen gesetzt und kennzeichnet außerdem teilweise nicht verfügbare Quellen; AVAILABLE_LIMITED setzt es ebenfalls auf 1. Diese Zuweisungen gelten für den regulären Ausführungspfad nach dem TABLE-Preflight; ein früher THROW kann sie umgehen. 0 bedeutet nur, dass dieses Flag im Aufruf nicht auf 1 gesetzt wurde, nicht dass jede denkbare Quelle vollständig oder fachlich fehlerfrei ist. Bei @Hilfe erfolgt keine Zuweisung; bei einem THROW ist keine OUTPUT-Zustellung zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@ErrorNumberOut int=NULL OUTPUT; Default: NULL. OUTPUT-Bindung für die globale SQL-Fehlernummer; eine Variable des Parametertyps wird mit @ErrorNumberOut = @ErrorNumberVariable OUTPUT übergeben. Wenn mehrere Quellenfehler aggregiert werden, wird MIN(ErrorNumber) gewählt, unabhängig von MIN(ErrorMessage), sodass Nummer und Text nicht zwingend zusammengehören. NULL bedeutet, dass kein Fehlernummernwert gesetzt wurde. Bei @Hilfe erfolgt keine Zuweisung; bei einem THROW ist keine OUTPUT-Zustellung zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@ErrorMessageOut nvarchar(2048)=NULL OUTPUT; Default: NULL. OUTPUT-Bindung für den globalen Fehler- oder Statuskontext; eine Variable des Parametertyps wird mit @ErrorMessageOut = @ErrorMessageVariable OUTPUT übergeben. Wenn mehrere Quellenfehler aggregiert werden, wird MIN(ErrorMessage) gewählt, unabhängig von MIN(ErrorNumber), sodass Text und Nummer nicht zwingend zusammengehören. Der Wert ist kein vollständiger Fehlerbericht. Für datenbank- oder quellenbezogene Fehler stehen Einzelheiten in DatabaseStatus beziehungsweise SourceStatus. Frühe Fehler des Namensfilter-Preflights werden über den globalen Status und @ErrorMessageOut gemeldet und erzeugen nicht notwendigerweise Einträge in diesen Resultsets. Bei @Hilfe erfolgt keine Zuweisung; bei einem THROW ist keine OUTPUT-Zustellung zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'Beispiel 1: EXEC [monitor].[USP_ServiceBrokerAnalysis] @Hilfe=1;';
        PRINT N'Beispiel 2: EXEC [monitor].[USP_ServiceBrokerAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @HighImpactConfirmed=1, @FullObjectNames=N''[ExampleDatabase].[ExampleSchema].[ExampleQueue]'', @MaxZeilen=100, @ResultSetArt=''RAW'', @PrintMeldungen=0;';
        PRINT N'Beispiel 3: DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_ServiceBrokerAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @HighImpactConfirmed=1, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];';
        PRINT N'Beispiel 4: CREATE TABLE [#ServiceBrokerAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ServiceBrokerAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @HighImpactConfirmed=1, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"findings":"#ServiceBrokerAnalysis_HelpExample"}'', @PrintMeldungen=0; SELECT * FROM [#ServiceBrokerAnalysis_HelpExample]; DROP TABLE IF EXISTS [#ServiceBrokerAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#ServiceBrokerAnalysis_HelpExample]; THROW; END CATCH;';
        PRINT N'Beispiel 5: EXEC [monitor].[USP_ServiceBrokerAnalysis] @DatabaseNamePattern=N''like:ExampleDatabase%'', @SchemaNamePattern=N''like:Example%'', @HighImpactConfirmed=1, @MaxZeilen=100, @ResultSetArt=''RAW'', @PrintMeldungen=0;';
        RETURN;
    END;

    IF @SystemdatenbankenEinbeziehen IS NULL OR @NurProblematisch IS NULL
       OR @JsonErzeugen IS NULL OR @PrintMeldungen IS NULL
       OR @TransmissionAgeWarnMinutes IS NULL OR @TransmissionAgeWarnMinutes<0
       OR @TransmissionRowsWarn IS NULL OR @TransmissionRowsWarn<0
       OR @QueueRowsWarn IS NULL OR @QueueRowsWarn<0
       OR @ActivationSilenceWarnMinutes IS NULL OR @ActivationSilenceWarnMinutes<0
       OR @ConversationRowsWarn IS NULL OR @ConversationRowsWarn<0

       OR @MaxZeilen<0
       OR @LockTimeoutMs IS NULL OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
       OR @OutputMode NOT IN('CONSOLE','RAW','NONE')
    BEGIN
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,
               @ErrorMessage=N'Ungültiger Bit-, Grenzwert-, Mengen-, Lock-Timeout- oder Ausgabeparameter.';
    END;

    DECLARE @SchemaPatternMode varchar(8),@SchemaPatternValue nvarchar(4000),@SchemaRegexFlags varchar(8),@SchemaPatternValid bit;
    DECLARE @ObjectPatternMode varchar(8),@ObjectPatternValue nvarchar(4000),@ObjectRegexFlags varchar(8),@ObjectPatternValid bit;
    SELECT @SchemaPatternMode=[PatternMode],@SchemaPatternValue=[PatternValue],@SchemaRegexFlags=[RegexFlags],@SchemaPatternValid=[IsValid]
    FROM [monitor].[TVF_ParsePattern](@SchemaNamePattern);
    SELECT @ObjectPatternMode=[PatternMode],@ObjectPatternValue=[PatternValue],@ObjectRegexFlags=[RegexFlags],@ObjectPatternValid=[IsValid]
    FROM [monitor].[TVF_ParsePattern](@ObjectNamePattern);

    IF @StatusCode='AVAILABLE'
       AND (@SchemaPatternValid=0 OR @ObjectPatternValid=0
            OR (@SchemaNames IS NOT NULL AND @SchemaNamePattern IS NOT NULL)
            OR (@ObjectNames IS NOT NULL AND @ObjectNamePattern IS NOT NULL))
    BEGIN
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,
               @ErrorMessage=N'Pattern ungültig oder exakte Liste und Pattern derselben Eigenschaft gleichzeitig angegeben.';
    END;

    IF @StatusCode='AVAILABLE'
       AND (@SchemaPatternMode IN('REGEX','REGEXI') OR @ObjectPatternMode IN('REGEX','REGEXI'))
       AND COALESCE(@Major,0)<17
    BEGIN
        SELECT @StatusCode='UNAVAILABLE_VERSION',@IsPartial=1,
               @ErrorMessage=N'Regex-Pattern benötigen SQL Server 2025 oder neuer und Compatibility Level 170.';
    END;

    CREATE TABLE [#ServiceBrokerAnalysis_NameFilters]
    (
          [FilterType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ItemOrdinal] int NOT NULL
        , [NameValue] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#ServiceBrokerAnalysis_DatabaseCandidates]
    (
          [DatabaseId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsReadOnly] bit NULL
        , [CompatibilityLevel] tinyint NULL
        , [CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsSystemDatabase] bit NULL
        , [RequestedOrdinal] int NULL
    );
    CREATE TABLE [#ServiceBrokerAnalysis_DatabaseCandidateWarnings]
    (
          [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ServiceBrokerAnalysis_FeatureScope]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY
        , [IsBrokerEnabled] bit NOT NULL
        , [UserQueueCount] bigint NOT NULL
        , [UserServiceCount] bigint NOT NULL
    );
    CREATE TABLE [#ServiceBrokerAnalysis_DatabaseStatus]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [IsBrokerEnabled] bit NULL
        , [UserQueueCount] bigint NOT NULL
        , [UserServiceCount] bigint NOT NULL
        , [TransmissionMessageCount] bigint NOT NULL
        , [ConversationEndpointCount] bigint NOT NULL
        , [SourceFailureCount] int NOT NULL
        , [FindingCount] bigint NOT NULL
        , [RequiredPermission] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#ServiceBrokerAnalysis_SourceStatus]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SourceCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [RowCount] bigint NOT NULL
        , [RequiredPermission] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#ServiceBrokerAnalysis_Queue]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [QueueName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [QueueObjectId] int NOT NULL
        , [ServiceCount] int NOT NULL
        , [IsBrokerEnabled] bit NOT NULL
        , [IsActivationEnabled] bit NOT NULL
        , [IsReceiveEnabled] bit NOT NULL
        , [IsEnqueueEnabled] bit NOT NULL
        , [IsRetentionEnabled] bit NOT NULL
        , [IsPoisonMessageHandlingEnabled] bit NOT NULL
        , [MaxReaders] smallint NULL
        , [ActivationProcedure] nvarchar(776) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ExecuteAsPrincipalId] int NULL
        , [QueueRowsApprox] bigint NULL
        , [QueueReservedMb] decimal(19,2) NULL
        , [QueueUsedMb] decimal(19,2) NULL
        , [QueueMonitorState] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [LastEmptyRowsetTime] datetime NULL
        , [LastActivatedTime] datetime NULL
        , [TasksWaiting] int NULL
        , [ActivatedTaskCount] int NULL
        , [AssessmentStatus] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , PRIMARY KEY ([DatabaseName],[QueueObjectId])
    );
    CREATE TABLE [#ServiceBrokerAnalysis_TransmissionGroup]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FromServiceName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ToServiceName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ToBrokerInstance] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ServiceContractName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [MessageTypeName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [TransmissionStatus] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [MessageCount] bigint NOT NULL
        , [ConversationErrorMessageCount] bigint NOT NULL
        , [EndDialogMessageCount] bigint NOT NULL
        , [OldestEnqueueTimeUtc] datetime NULL
        , [NewestEnqueueTimeUtc] datetime NULL
        , [OldestAgeMinutes] bigint NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ServiceBrokerAnalysis_ConversationState]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StateCode] char(2) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StateDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsInitiator] bit NOT NULL
        , [IsSystem] bit NOT NULL
        , [EndpointCount] bigint NOT NULL
        , [ExpiredLifetimeCount] bigint NOT NULL
        , [EarliestLifetimeUtc] datetime NULL
        , [EarliestSecurityTimestampUtc] datetime NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ServiceBrokerAnalysis_Findings]
    (
          [FindingOrdinal] bigint IDENTITY(1,1) NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Confidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FindingCode] varchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [MetricName] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [MetricValue] decimal(38,4) NULL
        , [ThresholdValue] decimal(38,4) NULL
        , [Evidence] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RecommendedNextCheck] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ServiceBrokerAnalysis_FindingsExport]
    (
          [FindingOrdinal] bigint NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Confidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FindingCode] varchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [MetricName] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [MetricValue] decimal(38,4) NULL
        , [ThresholdValue] decimal(38,4) NULL
        , [Evidence] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RecommendedNextCheck] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    /* Eigene lokale Arbeitstabellen werden vor dem NOWAIT-Quellabschnitt angelegt. */
    SET LOCK_TIMEOUT 0;

    IF @StatusCode='AVAILABLE'
    BEGIN
        EXEC [monitor].[USP_PrepareNameFilters]
              @SchemaNames=@SchemaNames
            , @ObjectNames=@ObjectNames
            , @FullObjectNames=@FullObjectNames
            , @IndexNames=NULL
            , @StatisticsNames=NULL
            , @ColumnNames=NULL
            , @StatusCode=@StatusCode OUTPUT
            , @ErrorMessage=@ErrorMessage OUTPUT,@FilterTable=N'#ServiceBrokerAnalysis_NameFilters';
        IF @StatusCode<>'AVAILABLE' SET @IsPartial=1;
    END;

    DECLARE @CrossDatabaseRequested bit=0;
    IF @StatusCode='AVAILABLE'
    BEGIN
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
              @DatabaseNames=@DatabaseNames
            , @SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen
            , @DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed

            , @AnalysisClass='CATALOG_DEEP'
            , @StatusCode=@StatusCode OUTPUT
            , @ErrorMessage=@ErrorMessage OUTPUT
            , @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,@CandidateTable=N'#ServiceBrokerAnalysis_DatabaseCandidates',@WarningTable=N'#ServiceBrokerAnalysis_DatabaseCandidateWarnings';
        IF @StatusCode<>'AVAILABLE' SET @IsPartial=1;
    END;

    INSERT [#ServiceBrokerAnalysis_DatabaseStatus]
    ([DatabaseName],[StatusCode],[IsPartial],[IsBrokerEnabled],[UserQueueCount],[UserServiceCount],
     [TransmissionMessageCount],[ConversationEndpointCount],[SourceFailureCount],[FindingCount],[Detail])
    SELECT [DatabaseName],'PENDING',0,NULL,0,0,0,0,0,0,
           N'Feature-Gate und Service-Broker-Quellen werden datenbankweise best effort ausgewertet.'
    FROM [#ServiceBrokerAnalysis_DatabaseCandidates];

    INSERT [#ServiceBrokerAnalysis_DatabaseStatus]
    ([DatabaseName],[StatusCode],[IsPartial],[IsBrokerEnabled],[UserQueueCount],[UserServiceCount],
     [TransmissionMessageCount],[ConversationEndpointCount],[SourceFailureCount],[FindingCount],[ErrorMessage],[Detail])
    SELECT [RequestedName],[StatusCode],1,NULL,0,0,0,0,1,0,[ErrorMessage],N'Explizit angeforderte Datenbank nicht auswertbar.'
    FROM [#ServiceBrokerAnalysis_DatabaseCandidateWarnings];

    IF @StatusCode='AVAILABLE' AND NOT EXISTS(SELECT 1 FROM [#ServiceBrokerAnalysis_DatabaseCandidates])
    BEGIN
        SELECT @StatusCode='NOT_APPLICABLE',@ErrorMessage=N'Keine auswertbare Datenbank im gewählten Scope.';
    END;

    DECLARE @SchemaPredicate nvarchar(max)=
        N' AND (NOT EXISTS(SELECT 1 FROM [#ServiceBrokerAnalysis_NameFilters] WHERE [FilterType]=''SCHEMA'') OR EXISTS(SELECT 1 FROM [#ServiceBrokerAnalysis_NameFilters] [f] WHERE [f].[FilterType]=''SCHEMA'' AND [f].[NameValue]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    DECLARE @ObjectPredicate nvarchar(max)=
        N' AND (NOT EXISTS(SELECT 1 FROM [#ServiceBrokerAnalysis_NameFilters] WHERE [FilterType]=''OBJECT'') OR EXISTS(SELECT 1 FROM [#ServiceBrokerAnalysis_NameFilters] [f] WHERE [f].[FilterType]=''OBJECT'' AND [f].[NameValue]=[t].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    DECLARE @FullObjectPredicate nvarchar(max)=
        N' AND (NOT EXISTS(SELECT 1 FROM [#ServiceBrokerAnalysis_NameFilters] WHERE [FilterType]=''FULL_OBJECT'') OR EXISTS(SELECT 1 FROM [#ServiceBrokerAnalysis_NameFilters] [f] WHERE [f].[FilterType]=''FULL_OBJECT'' AND ([f].[DatabaseName] IS NULL OR [f].[DatabaseName]=@pDatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS) AND ([f].[SchemaName] IS NULL OR [f].[SchemaName]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS) AND [f].[ObjectName]=[t].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    IF @SchemaPatternMode='LIKE'
        SET @SchemaPredicate+=N' AND [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';
    IF @SchemaPatternMode IN('REGEX','REGEXI')
        SET @SchemaPredicate+=N' AND REGEXP_LIKE([s].[name],N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''','''+@SchemaRegexFlags+N''')';
    IF @ObjectPatternMode='LIKE'
        SET @ObjectPredicate+=N' AND [t].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@ObjectPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';
    IF @ObjectPatternMode IN('REGEX','REGEXI')
        SET @ObjectPredicate+=N' AND REGEXP_LIKE([t].[name],N'''+REPLACE(@ObjectPatternValue,N'''',N'''''')+N''','''+@ObjectRegexFlags+N''')';

    IF @StatusCode='AVAILABLE'
    BEGIN
        DECLARE @DbName sysname,@CompatibilityLevel int,@Sql nvarchar(max),@Rows bigint;
        DECLARE [DatabaseCursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [DatabaseName],[CompatibilityLevel]
            FROM [#ServiceBrokerAnalysis_DatabaseCandidates]
            ORDER BY COALESCE([RequestedOrdinal],[DatabaseId]),[DatabaseId];
        OPEN [DatabaseCursor];
        FETCH NEXT FROM [DatabaseCursor] INTO @DbName,@CompatibilityLevel;

        WHILE @@FETCH_STATUS=0
        BEGIN
            IF (@SchemaPatternMode IN('REGEX','REGEXI') OR @ObjectPatternMode IN('REGEX','REGEXI'))
               AND COALESCE(@CompatibilityLevel,0)<170
            BEGIN
                UPDATE [#ServiceBrokerAnalysis_DatabaseStatus]
                SET [StatusCode]='UNAVAILABLE_FEATURE',[IsPartial]=1,[SourceFailureCount]=1,
                    [ErrorMessage]=N'Regex-Pattern benötigen Compatibility Level 170.',
                    [Detail]=N'Für diese Datenbank wurde wegen inkompatiblem Patternvertrag keine Analyse ausgeführt.'
                WHERE [DatabaseName]=@DbName;
                INSERT [#ServiceBrokerAnalysis_SourceStatus]
                VALUES(@DbName,'FILTER_CONTRACT','UNAVAILABLE_FEATURE',1,0,NULL,NULL,
                       N'Regex-Pattern benötigen Compatibility Level 170.',N'Keine Quellenabfrage ausgeführt.');
                FETCH NEXT FROM [DatabaseCursor] INTO @DbName,@CompatibilityLevel;
                CONTINUE;
            END;

            BEGIN TRY
                SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(11),@LockTimeoutMs)+N'; USE '+QUOTENAME(@DbName)+N';
INSERT [#ServiceBrokerAnalysis_FeatureScope]([DatabaseName],[IsBrokerEnabled],[UserQueueCount],[UserServiceCount])
SELECT @pDatabaseName,CONVERT(bit,[d].[is_broker_enabled]),[q].[QueueCount],[svc].[ServiceCount]
FROM [sys].[databases] [d] WITH (NOLOCK)
CROSS APPLY
(
    SELECT COUNT_BIG(*) AS [QueueCount]
    FROM [sys].[service_queues] WITH (NOLOCK)
    WHERE [is_ms_shipped]=0
) [q]
CROSS APPLY
(
    SELECT COUNT_BIG(*) AS [ServiceCount]
    FROM [sys].[services] [x] WITH (NOLOCK)
    JOIN [sys].[service_queues] [sq] WITH (NOLOCK) ON [sq].[object_id]=[x].[service_queue_id]
    WHERE [sq].[is_ms_shipped]=0
) [svc]
WHERE [d].[database_id]=DB_ID();
SET @pRows=@@ROWCOUNT;';
                SET @Rows=0;
                EXEC [sys].[sp_executesql] @Sql,N'@pDatabaseName sysname,@pRows bigint OUTPUT',
                     @pDatabaseName=@DbName,@pRows=@Rows OUTPUT;
                INSERT [#ServiceBrokerAnalysis_SourceStatus]
                VALUES(@DbName,'BROKER_FEATURE_GATE','AVAILABLE',0,@Rows,
                       N'Katalogsicht auf sichtbare Datenbank- und Broker-Metadaten',NULL,NULL,
                       N'Prüft Datenbankschalter und sichtbare nicht ausgelieferte Queues/Services; Nullzählungen beweisen bei eingeschränkter Metadatensichtbarkeit keine Abwesenheit.');
                UPDATE [ds]
                SET [IsBrokerEnabled]=[fs].[IsBrokerEnabled],
                    [UserQueueCount]=[fs].[UserQueueCount],
                    [UserServiceCount]=[fs].[UserServiceCount]
                FROM [#ServiceBrokerAnalysis_DatabaseStatus] [ds]
                JOIN [#ServiceBrokerAnalysis_FeatureScope] [fs] ON [fs].[DatabaseName]=[ds].[DatabaseName]
                WHERE [ds].[DatabaseName]=@DbName;
            END TRY
            BEGIN CATCH
                INSERT [#ServiceBrokerAnalysis_SourceStatus]
                VALUES(@DbName,'BROKER_FEATURE_GATE','ERROR_HANDLED',1,0,
                       N'Katalogsicht auf sichtbare Datenbank- und Broker-Metadaten',ERROR_NUMBER(),ERROR_MESSAGE(),
                       N'Feature-Sichtbarkeit konnte nicht bestimmt werden.');
                UPDATE [#ServiceBrokerAnalysis_DatabaseStatus]
                SET [StatusCode]='ERROR_HANDLED',[IsPartial]=1,[SourceFailureCount]=[SourceFailureCount]+1,
                    [ErrorNumber]=ERROR_NUMBER(),[ErrorMessage]=ERROR_MESSAGE(),
                    [Detail]=N'Feature-Gate fehlgeschlagen; keine belastbare Anwendbarkeitsaussage.'
                WHERE [DatabaseName]=@DbName;
            END CATCH;

            IF NOT EXISTS(SELECT 1 FROM [#ServiceBrokerAnalysis_FeatureScope] WHERE [DatabaseName]=@DbName)
            BEGIN
                FETCH NEXT FROM [DatabaseCursor] INTO @DbName,@CompatibilityLevel;
                CONTINUE;
            END;

            IF EXISTS
            (
                SELECT 1 FROM [#ServiceBrokerAnalysis_FeatureScope]
                WHERE [DatabaseName]=@DbName AND [IsBrokerEnabled]=0
                  AND [UserQueueCount]=0 AND [UserServiceCount]=0
            )
            BEGIN
                UPDATE [#ServiceBrokerAnalysis_DatabaseStatus]
                SET [StatusCode]='NOT_APPLICABLE_VISIBLE_SCOPE',[IsPartial]=0,
                    [Detail]=N'Service Broker ist deaktiviert und im sichtbaren Katalogscope wurden keine benutzerdefinierten Queues oder Services erkannt; dies beweist bei eingeschränkter Metadatensichtbarkeit keine vollständige Abwesenheit.'
                WHERE [DatabaseName]=@DbName;
                INSERT [#ServiceBrokerAnalysis_SourceStatus]
                SELECT @DbName,[SourceCode],'NOT_APPLICABLE',0,0,[RequiredPermission],NULL,NULL,
                       N'Quelle wegen negativem sichtbaren Feature-Gate nicht aufgerufen.'
                FROM (VALUES
                      ('BROKER_QUEUE_CATALOG',N'Katalogsicht auf sichtbare Broker-Queues und Services'),
                      ('BROKER_QUEUE_CAPACITY',N'VIEW DATABASE STATE und VIEW DEFINITION; SQL Server 2022+: VIEW DATABASE PERFORMANCE STATE und VIEW SECURITY DEFINITION'),
                      ('BROKER_QUEUE_MONITOR',N'SQL Server 2019: VIEW SERVER STATE; SQL Server 2022+: VIEW SERVER PERFORMANCE STATE'),
                      ('BROKER_ACTIVATED_TASKS',N'SQL Server 2019: VIEW SERVER STATE; SQL Server 2022+: VIEW SERVER PERFORMANCE STATE'),
                      ('BROKER_TRANSMISSION',N'Katalogsicht auf sys.transmission_queue'),
                      ('BROKER_CONVERSATION',N'Katalogsicht auf sys.conversation_endpoints'))
                     [x]([SourceCode],[RequiredPermission]);
                FETCH NEXT FROM [DatabaseCursor] INTO @DbName,@CompatibilityLevel;
                CONTINUE;
            END;

            BEGIN TRY
                SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(11),@LockTimeoutMs)+N'; USE '+QUOTENAME(@DbName)+N';
INSERT [#ServiceBrokerAnalysis_Queue]
([DatabaseName],[SchemaName],[QueueName],[QueueObjectId],[ServiceCount],[IsBrokerEnabled],
 [IsActivationEnabled],[IsReceiveEnabled],[IsEnqueueEnabled],[IsRetentionEnabled],
 [IsPoisonMessageHandlingEnabled],[MaxReaders],[ActivationProcedure],[ExecuteAsPrincipalId],
 [AssessmentStatus],[EvidenceLimit])
SELECT @pDatabaseName,[s].[name],[t].[name],[t].[object_id],CONVERT(int,[svc].[ServiceCount]),
       CONVERT(bit,[d].[is_broker_enabled]),[t].[is_activation_enabled],[t].[is_receive_enabled],
       [t].[is_enqueue_enabled],[t].[is_retention_enabled],[t].[is_poison_message_handling_enabled],
       [t].[max_readers],[t].[activation_procedure],[t].[execute_as_principal_id],''AVAILABLE'',
       N''Queue-Kataloge und Aktivierungsmetadaten beweisen weder erfolgreiche Verarbeitung noch die Ursache eines deaktivierten Zustands.''
FROM [sys].[service_queues] [t] WITH (NOLOCK)
JOIN [sys].[schemas] [s] WITH (NOLOCK) ON [s].[schema_id]=[t].[schema_id]
OUTER APPLY
(
    SELECT COUNT_BIG(*) AS [ServiceCount]
    FROM [sys].[services] [x] WITH (NOLOCK)
    WHERE [x].[service_queue_id]=[t].[object_id]
) [svc]
CROSS APPLY
(
    SELECT [is_broker_enabled]
    FROM [sys].[databases] WITH (NOLOCK)
    WHERE [database_id]=DB_ID()
) [d]
WHERE [t].[is_ms_shipped]=0'+@SchemaPredicate+@ObjectPredicate+@FullObjectPredicate+N';
SET @pRows=@@ROWCOUNT;';
                SET @Rows=0;
                EXEC [sys].[sp_executesql] @Sql,N'@pDatabaseName sysname,@pRows bigint OUTPUT',
                     @pDatabaseName=@DbName,@pRows=@Rows OUTPUT;
                INSERT [#ServiceBrokerAnalysis_SourceStatus]
                VALUES(@DbName,'BROKER_QUEUE_CATALOG','AVAILABLE',0,@Rows,
                       N'Katalogsicht auf sichtbare Broker-Queues und Services',NULL,NULL,
                       N'Queue-Schalter, Aktivierungskonfiguration und Service-Zuordnungsanzahl; Nullzeilen können aus Filtern oder Metadatensichtbarkeit folgen.');
            END TRY
            BEGIN CATCH
                INSERT [#ServiceBrokerAnalysis_SourceStatus]
                VALUES(@DbName,'BROKER_QUEUE_CATALOG','ERROR_HANDLED',1,0,
                       N'Katalogsicht auf sichtbare Broker-Queues und Services',ERROR_NUMBER(),ERROR_MESSAGE(),
                       N'Queue-abhängige Kapazitäts- und Aktivierungsquellen werden ausgelassen; Transmission und Conversations bleiben unabhängig.');
            END CATCH;

            IF EXISTS
            (
                SELECT 1 FROM [#ServiceBrokerAnalysis_SourceStatus]
                WHERE [DatabaseName]=@DbName AND [SourceCode]='BROKER_QUEUE_CATALOG' AND [IsPartial]=1
            )
            BEGIN
                INSERT [#ServiceBrokerAnalysis_SourceStatus]
                VALUES
                (@DbName,'BROKER_QUEUE_CAPACITY','UNAVAILABLE_DEPENDENCY',1,0,
                 N'VIEW DATABASE STATE und VIEW DEFINITION; SQL Server 2022+: VIEW DATABASE PERFORMANCE STATE und VIEW SECURITY DEFINITION',
                 NULL,N'BROKER_QUEUE_CATALOG ist nicht verfügbar.',N'Keine Partitionsstatistik ohne belastbare Queue-Zuordnung.'),
                (@DbName,'BROKER_QUEUE_MONITOR','UNAVAILABLE_DEPENDENCY',1,0,
                 N'SQL Server 2019: VIEW SERVER STATE; SQL Server 2022+: VIEW SERVER PERFORMANCE STATE',
                 NULL,N'BROKER_QUEUE_CATALOG ist nicht verfügbar.',N'Keine Monitor-Zuordnung ohne belastbare Queue-Zuordnung.'),
                (@DbName,'BROKER_ACTIVATED_TASKS','UNAVAILABLE_DEPENDENCY',1,0,
                 N'SQL Server 2019: VIEW SERVER STATE; SQL Server 2022+: VIEW SERVER PERFORMANCE STATE',
                 NULL,N'BROKER_QUEUE_CATALOG ist nicht verfügbar.',N'Keine Task-Zuordnung ohne belastbare Queue-Zuordnung.');
            END
            ELSE
            BEGIN
                BEGIN TRY
                    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(11),@LockTimeoutMs)+N'; USE '+QUOTENAME(@DbName)+N';
UPDATE [q]
SET [QueueRowsApprox]=[p].[RowCountApprox],
    [QueueReservedMb]=[p].[ReservedMb],
    [QueueUsedMb]=[p].[UsedMb]
FROM [#ServiceBrokerAnalysis_Queue] [q]
OUTER APPLY
(
    SELECT SUM(CASE WHEN [index_id] IN(0,1) THEN CONVERT(bigint,[row_count]) END) AS [RowCountApprox],
           CONVERT(decimal(19,2),SUM(CONVERT(decimal(38,2),[reserved_page_count]))*8.0/1024.0) AS [ReservedMb],
           CONVERT(decimal(19,2),SUM(CONVERT(decimal(38,2),[used_page_count]))*8.0/1024.0) AS [UsedMb]
    FROM [sys].[dm_db_partition_stats] WITH (NOLOCK)
    WHERE [object_id]=[q].[QueueObjectId]
) [p]
WHERE [q].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=@pDatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS;
SET @pRows=@@ROWCOUNT;';
                    SET @Rows=0;
                    EXEC [sys].[sp_executesql] @Sql,N'@pDatabaseName sysname,@pRows bigint OUTPUT',
                         @pDatabaseName=@DbName,@pRows=@Rows OUTPUT;
                    INSERT [#ServiceBrokerAnalysis_SourceStatus]
                    VALUES(@DbName,'BROKER_QUEUE_CAPACITY','AVAILABLE',0,@Rows,
                           N'VIEW DATABASE STATE und VIEW DEFINITION; SQL Server 2022+: VIEW DATABASE PERFORMANCE STATE und VIEW SECURITY DEFINITION',NULL,NULL,
                           N'Approximative Queue-Zeilen und Seiten ohne Queue-Nutzdaten; row_count ist kein Durchsatz- oder Altersnachweis.');
                END TRY
                BEGIN CATCH
                    INSERT [#ServiceBrokerAnalysis_SourceStatus]
                    VALUES(@DbName,'BROKER_QUEUE_CAPACITY','ERROR_HANDLED',1,0,
                           N'VIEW DATABASE STATE und VIEW DEFINITION; SQL Server 2022+: VIEW DATABASE PERFORMANCE STATE und VIEW SECURITY DEFINITION',
                           ERROR_NUMBER(),ERROR_MESSAGE(),N'Queue-Katalog und andere Broker-Quellen bleiben verfügbar.');
                END CATCH;

                BEGIN TRY
                    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(11),@LockTimeoutMs)+N'; USE '+QUOTENAME(@DbName)+N';
UPDATE [q]
SET [QueueMonitorState]=[m].[MonitorState],
    [LastEmptyRowsetTime]=[m].[LastEmptyRowsetTime],
    [LastActivatedTime]=[m].[LastActivatedTime],
    [TasksWaiting]=[m].[TasksWaiting]
FROM [#ServiceBrokerAnalysis_Queue] [q]
OUTER APPLY
(
    SELECT MAX([state]) AS [MonitorState],MAX([last_empty_rowset_time]) AS [LastEmptyRowsetTime],
           MAX([last_activated_time]) AS [LastActivatedTime],MAX([tasks_waiting]) AS [TasksWaiting]
    FROM [sys].[dm_broker_queue_monitors] WITH (NOLOCK)
    WHERE [database_id]=DB_ID() AND [queue_id]=[q].[QueueObjectId]
) [m]
WHERE [q].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=@pDatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS;
SET @pRows=@@ROWCOUNT;';
                    SET @Rows=0;
                    EXEC [sys].[sp_executesql] @Sql,N'@pDatabaseName sysname,@pRows bigint OUTPUT',
                         @pDatabaseName=@DbName,@pRows=@Rows OUTPUT;
                    INSERT [#ServiceBrokerAnalysis_SourceStatus]
                    VALUES(@DbName,'BROKER_QUEUE_MONITOR','AVAILABLE',0,@Rows,
                           N'SQL Server 2019: VIEW SERVER STATE; SQL Server 2022+: VIEW SERVER PERFORMANCE STATE',NULL,NULL,
                           N'Monitorstatus und Zeitstempel sind Momentaufnahmen; wartende Tasks sind wartende Receiver und kein Backlogmaß.');
                END TRY
                BEGIN CATCH
                    INSERT [#ServiceBrokerAnalysis_SourceStatus]
                    VALUES(@DbName,'BROKER_QUEUE_MONITOR','ERROR_HANDLED',1,0,
                           N'SQL Server 2019: VIEW SERVER STATE; SQL Server 2022+: VIEW SERVER PERFORMANCE STATE',
                           ERROR_NUMBER(),ERROR_MESSAGE(),N'Queue-Katalog, Kapazität und andere Broker-Quellen bleiben verfügbar.');
                END CATCH;

                BEGIN TRY
                    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(11),@LockTimeoutMs)+N'; USE '+QUOTENAME(@DbName)+N';
UPDATE [q]
SET [ActivatedTaskCount]=[a].[ActivatedTaskCount]
FROM [#ServiceBrokerAnalysis_Queue] [q]
OUTER APPLY
(
    SELECT CONVERT(int,COUNT_BIG(*)) AS [ActivatedTaskCount]
    FROM [sys].[dm_broker_activated_tasks] WITH (NOLOCK)
    WHERE [database_id]=DB_ID() AND [queue_id]=[q].[QueueObjectId]
) [a]
WHERE [q].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=@pDatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS;
SET @pRows=@@ROWCOUNT;';
                    SET @Rows=0;
                    EXEC [sys].[sp_executesql] @Sql,N'@pDatabaseName sysname,@pRows bigint OUTPUT',
                         @pDatabaseName=@DbName,@pRows=@Rows OUTPUT;
                    INSERT [#ServiceBrokerAnalysis_SourceStatus]
                    VALUES(@DbName,'BROKER_ACTIVATED_TASKS','AVAILABLE',0,@Rows,
                           N'SQL Server 2019: VIEW SERVER STATE; SQL Server 2022+: VIEW SERVER PERFORMANCE STATE',NULL,NULL,
                           N'Zählt aktuell von Service Broker aktivierte Prozeduren pro Queue; externe oder manuelle Reader sind nicht vollständig abgebildet.');
                END TRY
                BEGIN CATCH
                    INSERT [#ServiceBrokerAnalysis_SourceStatus]
                    VALUES(@DbName,'BROKER_ACTIVATED_TASKS','ERROR_HANDLED',1,0,
                           N'SQL Server 2019: VIEW SERVER STATE; SQL Server 2022+: VIEW SERVER PERFORMANCE STATE',
                           ERROR_NUMBER(),ERROR_MESSAGE(),N'Queue-Katalog, Kapazität und andere Broker-Quellen bleiben verfügbar.');
                END CATCH;
            END;

            BEGIN TRY
                SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(11),@LockTimeoutMs)+N'; USE '+QUOTENAME(@DbName)+N';
INSERT [#ServiceBrokerAnalysis_TransmissionGroup]
([DatabaseName],[FromServiceName],[ToServiceName],[ToBrokerInstance],[ServiceContractName],
 [MessageTypeName],[TransmissionStatus],[MessageCount],[ConversationErrorMessageCount],
 [EndDialogMessageCount],[OldestEnqueueTimeUtc],[NewestEnqueueTimeUtc],[OldestAgeMinutes],[EvidenceLimit])
SELECT @pDatabaseName,[x].[from_service_name],[x].[to_service_name],[x].[to_broker_instance],
       [x].[service_contract_name],[x].[message_type_name],NULLIF([x].[transmission_status],N''''),
       COUNT_BIG(*),SUM(CONVERT(bigint,[x].[is_conversation_error])),
       SUM(CONVERT(bigint,[x].[is_end_of_dialog])),MIN([x].[enqueue_time]),MAX([x].[enqueue_time]),
       DATEDIFF_BIG(MINUTE,MIN([x].[enqueue_time]),SYSUTCDATETIME()),
       N''Transmission-Einträge können auch während normaler Zustellung oder Retention sichtbar sein; Alter und Status beweisen allein keinen dauerhaften Fehler.''
FROM [sys].[transmission_queue] [x] WITH (NOLOCK)
LEFT JOIN [sys].[services] [svc] WITH (NOLOCK) ON [svc].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[x].[from_service_name] COLLATE SQL_Latin1_General_CP1_CS_AS
LEFT JOIN [sys].[service_queues] [t] WITH (NOLOCK) ON [t].[object_id]=[svc].[service_queue_id]
LEFT JOIN [sys].[schemas] [s] WITH (NOLOCK) ON [s].[schema_id]=[t].[schema_id]
WHERE 1=1'+@SchemaPredicate+@ObjectPredicate+@FullObjectPredicate+N'
GROUP BY [x].[from_service_name],[x].[to_service_name],[x].[to_broker_instance],
         [x].[service_contract_name],[x].[message_type_name],NULLIF([x].[transmission_status],N'''');
SET @pRows=@@ROWCOUNT;';
                SET @Rows=0;
                EXEC [sys].[sp_executesql] @Sql,N'@pDatabaseName sysname,@pRows bigint OUTPUT',
                     @pDatabaseName=@DbName,@pRows=@Rows OUTPUT;
                INSERT [#ServiceBrokerAnalysis_SourceStatus]
                VALUES(@DbName,'BROKER_TRANSMISSION','AVAILABLE',0,@Rows,
                       N'Katalogsicht auf sys.transmission_queue',NULL,NULL,
                       N'Nur nicht-payloadhaltige Metadaten werden gruppiert; Nachrichtenkörper und Conversation-Handles werden nicht gelesen.');
            END TRY
            BEGIN CATCH
                INSERT [#ServiceBrokerAnalysis_SourceStatus]
                VALUES(@DbName,'BROKER_TRANSMISSION','ERROR_HANDLED',1,0,
                       N'Katalogsicht auf sys.transmission_queue',ERROR_NUMBER(),ERROR_MESSAGE(),
                       N'Queue- und Conversation-Evidenz bleiben verfügbar.');
            END CATCH;

            BEGIN TRY
                SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(11),@LockTimeoutMs)+N'; USE '+QUOTENAME(@DbName)+N';
INSERT [#ServiceBrokerAnalysis_ConversationState]
([DatabaseName],[StateCode],[StateDescription],[IsInitiator],[IsSystem],[EndpointCount],
 [ExpiredLifetimeCount],[EarliestLifetimeUtc],[EarliestSecurityTimestampUtc],[EvidenceLimit])
SELECT @pDatabaseName,[x].[state],[x].[state_desc],CONVERT(bit,[x].[is_initiator]),[x].[is_system],
       COUNT_BIG(*),SUM(CASE WHEN [x].[lifetime]<SYSUTCDATETIME() THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END),
       MIN([x].[lifetime]),MIN([x].[security_timestamp]),
       N''Aggregierte Endpoint-Zustände und Zeitstempel beweisen weder fachliche Vollständigkeit noch die Ursache verzögerter Conversation-Bereinigung.''
FROM [sys].[conversation_endpoints] [x] WITH (NOLOCK)
LEFT JOIN [sys].[services] [svc] WITH (NOLOCK) ON [svc].[service_id]=[x].[service_id]
LEFT JOIN [sys].[service_queues] [t] WITH (NOLOCK) ON [t].[object_id]=[svc].[service_queue_id]
LEFT JOIN [sys].[schemas] [s] WITH (NOLOCK) ON [s].[schema_id]=[t].[schema_id]
WHERE 1=1'+@SchemaPredicate+@ObjectPredicate+@FullObjectPredicate+N'
GROUP BY [x].[state],[x].[state_desc],[x].[is_initiator],[x].[is_system];
SET @pRows=@@ROWCOUNT;';
                SET @Rows=0;
                EXEC [sys].[sp_executesql] @Sql,N'@pDatabaseName sysname,@pRows bigint OUTPUT',
                     @pDatabaseName=@DbName,@pRows=@Rows OUTPUT;
                INSERT [#ServiceBrokerAnalysis_SourceStatus]
                VALUES(@DbName,'BROKER_CONVERSATION','AVAILABLE',0,@Rows,
                       N'Katalogsicht auf sys.conversation_endpoints',NULL,NULL,
                       N'Zustände werden ohne Handles, Gruppen-IDs, Schlüsselkennungen oder Nachrichteninhalt aggregiert.');
            END TRY
            BEGIN CATCH
                INSERT [#ServiceBrokerAnalysis_SourceStatus]
                VALUES(@DbName,'BROKER_CONVERSATION','ERROR_HANDLED',1,0,
                       N'Katalogsicht auf sys.conversation_endpoints',ERROR_NUMBER(),ERROR_MESSAGE(),
                       N'Queue- und Transmission-Evidenz bleiben verfügbar.');
            END CATCH;

            FETCH NEXT FROM [DatabaseCursor] INTO @DbName,@CompatibilityLevel;
        END;
        CLOSE [DatabaseCursor];
        DEALLOCATE [DatabaseCursor];
    END;

    UPDATE [ds]
    SET [TransmissionMessageCount]=COALESCE([tx].[MessageCount],0),
        [ConversationEndpointCount]=COALESCE([ce].[EndpointCount],0)
    FROM [#ServiceBrokerAnalysis_DatabaseStatus] [ds]
    OUTER APPLY
    (
        SELECT SUM([MessageCount]) AS [MessageCount]
        FROM [#ServiceBrokerAnalysis_TransmissionGroup] [x]
        WHERE [x].[DatabaseName]=[ds].[DatabaseName]
    ) [tx]
    OUTER APPLY
    (
        SELECT SUM([EndpointCount]) AS [EndpointCount]
        FROM [#ServiceBrokerAnalysis_ConversationState] [x]
        WHERE [x].[DatabaseName]=[ds].[DatabaseName]
    ) [ce];

    INSERT [#ServiceBrokerAnalysis_Findings]
    ([DatabaseName],[Severity],[Confidence],[FindingCode],[MetricName],[MetricValue],[ThresholdValue],
     [Evidence],[EvidenceLimit],[RecommendedNextCheck])
    SELECT [DatabaseName],'WARN','HIGH','BROKER_DISABLED_WITH_VISIBLE_OBJECTS','IS_BROKER_ENABLED',0,1,
           N'Service Broker ist für die Datenbank deaktiviert, obwohl sichtbare benutzerdefinierte Queues oder Services vorhanden sind.',
           N'Der Datenbankschalter und sichtbare Objekte beweisen nicht, ob die Deaktivierung geplant, temporär oder fehlerbedingt ist.',
           N'Betriebsabsicht, Restore-/Failover-Historie und abhängige Anwendungen prüfen; keine automatische Aktivierung ableiten.'
    FROM [#ServiceBrokerAnalysis_FeatureScope]
    WHERE [IsBrokerEnabled]=0 AND ([UserQueueCount]>0 OR [UserServiceCount]>0);

    INSERT [#ServiceBrokerAnalysis_Findings]
    ([DatabaseName],[SchemaName],[ObjectName],[Severity],[Confidence],[FindingCode],[MetricName],[MetricValue],[ThresholdValue],
     [Evidence],[EvidenceLimit],[RecommendedNextCheck])
    SELECT [DatabaseName],[SchemaName],[QueueName],'WARN','HIGH','QUEUE_RECEIVE_DISABLED','IS_RECEIVE_ENABLED',0,1,
           N'RECEIVE ist für die sichtbare Queue deaktiviert.',
           N'Der OFF-Zustand kann nach wiederholten Rollbacks durch Poison-Message-Erkennung oder manuell entstehen; ohne Ereignis- und Anwendungsevidenz ist die Ursache nicht bewiesen.',
           N'SQL-Fehlerlog, Broker:Queue Disabled beziehungsweise Extended Events, Anwendungstransaktionen und freigegebene Queue-Diagnose prüfen.'
    FROM [#ServiceBrokerAnalysis_Queue]
    WHERE [IsReceiveEnabled]=0;

    INSERT [#ServiceBrokerAnalysis_Findings]
    ([DatabaseName],[SchemaName],[ObjectName],[Severity],[Confidence],[FindingCode],[MetricName],[MetricValue],[ThresholdValue],
     [Evidence],[EvidenceLimit],[RecommendedNextCheck])
    SELECT [DatabaseName],[SchemaName],[QueueName],'WARN','HIGH','QUEUE_ENQUEUE_DISABLED','IS_ENQUEUE_ENABLED',0,1,
           N'Enqueue ist für die sichtbare Queue deaktiviert.',
           N'Der Katalogzustand zeigt keine Ursache und keine fachliche Betriebsabsicht.',
           N'Bereitstellungszustand, Betriebsabsicht und abhängige Sender prüfen; keine automatische Änderung ableiten.'
    FROM [#ServiceBrokerAnalysis_Queue]
    WHERE [IsEnqueueEnabled]=0;

    INSERT [#ServiceBrokerAnalysis_Findings]
    ([DatabaseName],[SchemaName],[ObjectName],[Severity],[Confidence],[FindingCode],[MetricName],[MetricValue],[ThresholdValue],
     [Evidence],[EvidenceLimit],[RecommendedNextCheck])
    SELECT [DatabaseName],[SchemaName],[QueueName],'WARN','HIGH','INTERNAL_ACTIVATION_DISABLED','IS_ACTIVATION_ENABLED',0,1,
           N'Eine interne Aktivierungsprozedur ist konfiguriert, die Aktivierung ist jedoch deaktiviert.',
           N'Externe oder geplante Reader können beabsichtigt sein; der Katalogzustand allein beweist keinen Verarbeitungsfehler.',
           N'Startstrategie, Deployment-Zustand und verantwortlichen Readerpfad prüfen.'
    FROM [#ServiceBrokerAnalysis_Queue]
    WHERE [ActivationProcedure] IS NOT NULL AND [IsActivationEnabled]=0;

    INSERT [#ServiceBrokerAnalysis_Findings]
    ([DatabaseName],[SchemaName],[ObjectName],[Severity],[Confidence],[FindingCode],[MetricName],[MetricValue],[ThresholdValue],
     [Evidence],[EvidenceLimit],[RecommendedNextCheck])
    SELECT [DatabaseName],[SchemaName],[QueueName],'WARN','MEDIUM','QUEUE_BACKLOG_CONTEXT','QUEUE_ROWS_APPROX',
           [QueueRowsApprox],@QueueRowsWarn,
           N'Die approximative Queue-Zeilenzahl überschreitet den konfigurierten Kontextgrenzwert.',
           N'row_count ist approximativ und enthält keine Aussage zu Nachrichtenalter, Durchsatz, Priorität oder fachlich zulässigem Rückstand.',
           N'Zeitreihe, Ankunfts-/Verarbeitungsrate, Conversation-Gruppen und Readerkapazität mit freigegebener Laufzeitevidenz korrelieren.'
    FROM [#ServiceBrokerAnalysis_Queue]
    WHERE [QueueRowsApprox]>=@QueueRowsWarn;

    INSERT [#ServiceBrokerAnalysis_Findings]
    ([DatabaseName],[SchemaName],[ObjectName],[Severity],[Confidence],[FindingCode],[MetricName],[MetricValue],[ThresholdValue],
     [Evidence],[EvidenceLimit],[RecommendedNextCheck])
    SELECT [DatabaseName],[SchemaName],[QueueName],'WARN','MEDIUM','INTERNAL_ACTIVATION_PROGRESS_REVIEW','MINUTES_SINCE_LAST_ACTIVATION',
           CASE WHEN [LastActivatedTime] IS NULL THEN NULL ELSE DATEDIFF_BIG(MINUTE,[LastActivatedTime],@Now) END,
           @ActivationSilenceWarnMinutes,
           N'Für eine nichtleere Queue mit aktivierter interner Prozedur ist aktuell kein aktivierter Task sichtbar und der Monitor meldet keine laufenden Receives.',
           N'DMV-Werte sind Momentaufnahmen; Conversation-Group-Locks, externe Reader, kurze Aktivierungen und fehlende DMV-Rechte können die Interpretation verändern.',
           N'Queue-Monitor, aktivierte Tasks, Fehlerlog und Ausführungskontext wiederholt messen; Prozedur nur kontrolliert und mit passendem EXECUTE-AS-Kontext testen.'
    FROM [#ServiceBrokerAnalysis_Queue]
    WHERE [QueueRowsApprox]>0
      AND [ActivationProcedure] IS NOT NULL
      AND [IsActivationEnabled]=1
      AND COALESCE([ActivatedTaskCount],0)=0
      AND COALESCE([QueueMonitorState],N'')<>N'RECEIVES_OCCURRING'
      AND ([LastActivatedTime] IS NULL OR DATEDIFF_BIG(MINUTE,[LastActivatedTime],@Now)>=@ActivationSilenceWarnMinutes)
      AND EXISTS
          (SELECT 1 FROM [#ServiceBrokerAnalysis_SourceStatus] [ss]
           WHERE [ss].[DatabaseName]=[#ServiceBrokerAnalysis_Queue].[DatabaseName]
             AND [ss].[SourceCode] IN('BROKER_QUEUE_CAPACITY','BROKER_QUEUE_MONITOR','BROKER_ACTIVATED_TASKS')
           GROUP BY [ss].[DatabaseName]
           HAVING SUM(CONVERT(int,[ss].[IsPartial]))=0 AND COUNT(*)=3);

    INSERT [#ServiceBrokerAnalysis_Findings]
    ([DatabaseName],[SchemaName],[ObjectName],[Severity],[Confidence],[FindingCode],[MetricName],[MetricValue],[ThresholdValue],
     [Evidence],[EvidenceLimit],[RecommendedNextCheck])
    SELECT [DatabaseName],[SchemaName],[QueueName],'INFO','MEDIUM','QUEUE_RETENTION_ENABLED_CONTEXT','IS_RETENTION_ENABLED',1,0,
           N'Die Queue behält Nachrichten bis zum Ende des Dialogs.',
           N'Retention kann sichtbare Zeilen trotz erfolgreicher Übertragung erhalten; dies ist Konfiguration und kein Fehler.',
           N'Bei Kapazitätsfragen Dialog-Lebenszyklus und erwartete Retention gemeinsam prüfen.'
    FROM [#ServiceBrokerAnalysis_Queue]
    WHERE [IsRetentionEnabled]=1;

    INSERT [#ServiceBrokerAnalysis_Findings]
    ([DatabaseName],[SchemaName],[ObjectName],[Severity],[Confidence],[FindingCode],[MetricName],[MetricValue],[ThresholdValue],
     [Evidence],[EvidenceLimit],[RecommendedNextCheck])
    SELECT [DatabaseName],[SchemaName],[QueueName],'INFO','MEDIUM','POISON_HANDLING_DISABLED_CONTEXT','IS_POISON_HANDLING_ENABLED',0,1,
           N'Die automatische Poison-Message-Behandlung ist für die Queue deaktiviert.',
           N'Dies kann eine bewusste Anwendungsstrategie sein und beweist keine vorhandene Poison Message.',
           N'Anwendungsseitige Fehler- und Wiederholungsstrategie gegen die Betriebsanforderungen prüfen.'
    FROM [#ServiceBrokerAnalysis_Queue]
    WHERE [IsPoisonMessageHandlingEnabled]=0;

    INSERT [#ServiceBrokerAnalysis_Findings]
    ([DatabaseName],[Severity],[Confidence],[FindingCode],[MetricName],[MetricValue],[ThresholdValue],
     [Evidence],[EvidenceLimit],[RecommendedNextCheck])
    SELECT [DatabaseName],'WARN','MEDIUM','TRANSMISSION_BACKLOG_CONTEXT','TRANSMISSION_MESSAGE_COUNT',
           SUM([MessageCount]),@TransmissionRowsWarn,
           N'Die aggregierte Transmission Queue überschreitet den konfigurierten Zeilengrenzwert.',
           N'Nicht alle Transmission-Einträge sind Fehler; Zustellung, Bestätigung und Retention können Einträge vorübergehend erhalten.',
           N'Statusgruppen, Alter, Routing, Endpunktverfügbarkeit und Zeitverlauf gemeinsam prüfen.'
    FROM [#ServiceBrokerAnalysis_TransmissionGroup]
    GROUP BY [DatabaseName]
    HAVING SUM([MessageCount])>=@TransmissionRowsWarn;

    INSERT [#ServiceBrokerAnalysis_Findings]
    ([DatabaseName],[Severity],[Confidence],[FindingCode],[MetricName],[MetricValue],[ThresholdValue],
     [Evidence],[EvidenceLimit],[RecommendedNextCheck])
    SELECT [DatabaseName],'WARN','HIGH','TRANSMISSION_STATUS_REPORTED','TRANSMISSION_MESSAGE_COUNT',
           [MessageCount],NULL,
           LEFT(CONCAT(N'Für eine Transmission-Gruppe ist ein Übertragungsstatus gemeldet: ',[TransmissionStatus]),1000),
           [EvidenceLimit],
           N'Routing, Broker-Endpunkt, Zertifikate, Zielverfügbarkeit und Fehlerlog anhand der Laufzeitumgebung prüfen.'
    FROM [#ServiceBrokerAnalysis_TransmissionGroup]
    WHERE [TransmissionStatus] IS NOT NULL;

    INSERT [#ServiceBrokerAnalysis_Findings]
    ([DatabaseName],[Severity],[Confidence],[FindingCode],[MetricName],[MetricValue],[ThresholdValue],
     [Evidence],[EvidenceLimit],[RecommendedNextCheck])
    SELECT [DatabaseName],'WARN','MEDIUM','AGED_TRANSMISSION_REVIEW','OLDEST_AGE_MINUTES',
           [OldestAgeMinutes],@TransmissionAgeWarnMinutes,
           N'Der älteste Eintrag einer Transmission-Gruppe überschreitet den konfigurierten Altersgrenzwert.',
           [EvidenceLimit],
           N'Wiederholte Messung, Status, Netzwerk-/Zielverfügbarkeit und beabsichtigte Retention korrelieren.'
    FROM [#ServiceBrokerAnalysis_TransmissionGroup]
    WHERE [OldestAgeMinutes]>=@TransmissionAgeWarnMinutes;

    INSERT [#ServiceBrokerAnalysis_Findings]
    ([DatabaseName],[Severity],[Confidence],[FindingCode],[MetricName],[MetricValue],[ThresholdValue],
     [Evidence],[EvidenceLimit],[RecommendedNextCheck])
    SELECT [DatabaseName],'WARN','HIGH','CONVERSATION_ERROR_STATE','ERROR_ENDPOINT_COUNT',
           SUM([EndpointCount]),0,
           N'Mindestens ein sichtbarer Conversation Endpoint befindet sich im Zustand ERROR.',
           N'Der Endpoint-Zustand enthält keine fachliche Ursache; die zugehörige Fehlermeldung kann bereits konsumiert worden sein.',
           N'Fehlerlog, Transmission-Status und Anwendungskorrelation prüfen, ohne Nachrichteninhalt zu persistieren.'
    FROM [#ServiceBrokerAnalysis_ConversationState]
    WHERE [StateCode]='ER'
    GROUP BY [DatabaseName];

    INSERT [#ServiceBrokerAnalysis_Findings]
    ([DatabaseName],[Severity],[Confidence],[FindingCode],[MetricName],[MetricValue],[ThresholdValue],
     [Evidence],[EvidenceLimit],[RecommendedNextCheck])
    SELECT [DatabaseName],'WARN','MEDIUM','CONVERSATION_ENDPOINT_GROWTH_CONTEXT','ENDPOINT_COUNT',
           SUM([EndpointCount]),@ConversationRowsWarn,
           N'Die sichtbare Zahl der Conversation Endpoints überschreitet den konfigurierten Kontextgrenzwert.',
           N'Die Anzahl allein beweist weder ein End-Dialog-Leck noch einen Fehler; langlebige aktive Dialoge können fachlich erforderlich sein.',
           N'Zustandsverteilung, Dialoglebenszyklus, Ankunftsrate und Verlauf getrennt untersuchen.'
    FROM [#ServiceBrokerAnalysis_ConversationState]
    GROUP BY [DatabaseName]
    HAVING SUM([EndpointCount])>=@ConversationRowsWarn;

    INSERT [#ServiceBrokerAnalysis_Findings]
    ([DatabaseName],[Severity],[Confidence],[FindingCode],[MetricName],[MetricValue],[ThresholdValue],
     [Evidence],[EvidenceLimit],[RecommendedNextCheck])
    SELECT [DatabaseName],'WARN','MEDIUM','EXPIRED_CONVERSATION_LIFETIME_REVIEW','EXPIRED_LIFETIME_COUNT',
           SUM([ExpiredLifetimeCount]),0,
           N'Sichtbare Conversation Endpoints besitzen eine abgelaufene Lifetime.',
           N'Lifetime und Zustandsaufnahme sind Momentaufnahmen; verzögerte Systemverarbeitung und normale Übergangszustände bleiben möglich.',
           N'Zustand, Zeitverlauf, Broker-Aktivität und Fehlerlog korrelieren; keine automatische Conversation-Bereinigung ausführen.'
    FROM [#ServiceBrokerAnalysis_ConversationState]
    WHERE [ExpiredLifetimeCount]>0
    GROUP BY [DatabaseName];

    INSERT [#ServiceBrokerAnalysis_Findings]
    ([DatabaseName],[Severity],[Confidence],[FindingCode],[MetricName],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
    SELECT [DatabaseName],'WARN','HIGH','SERVICE_BROKER_EVIDENCE_GAP',[SourceCode],
           COALESCE([ErrorMessage],N'Die angeforderte Quelle ist nicht verfügbar.'),
           [Detail],N'Berechtigung, Featureverfügbarkeit und Abhängigkeiten prüfen; andere Resultsets bleiben gültig.'
    FROM [#ServiceBrokerAnalysis_SourceStatus]
    WHERE [IsPartial]=1;

    UPDATE [q]
    SET [AssessmentStatus]=CASE WHEN EXISTS
        (SELECT 1 FROM [#ServiceBrokerAnalysis_Findings] [f]
         WHERE [f].[DatabaseName]=[q].[DatabaseName]
           AND [f].[SchemaName]=[q].[SchemaName]
           AND [f].[ObjectName]=[q].[QueueName]
           AND [f].[Severity]='WARN') THEN 'REVIEW' ELSE 'AVAILABLE' END
    FROM [#ServiceBrokerAnalysis_Queue] [q];

    UPDATE [ds]
    SET [SourceFailureCount]=[x].[FailureCount],
        [IsPartial]=CONVERT(bit,CASE WHEN [x].[FailureCount]>0 THEN 1 ELSE 0 END),
        [FindingCount]=[f].[FindingCount],
        [StatusCode]=CASE WHEN [ds].[StatusCode] IN('NOT_APPLICABLE_VISIBLE_SCOPE','UNAVAILABLE_FEATURE','ERROR_HANDLED') THEN [ds].[StatusCode]
                          WHEN [x].[FailureCount]>0 THEN 'AVAILABLE_LIMITED'
                          WHEN [f].[WarnCount]>0 THEN 'AVAILABLE_WITH_FINDING'
                          ELSE 'AVAILABLE' END,
        [Detail]=CASE WHEN [ds].[StatusCode]='PENDING' AND [x].[FailureCount]>0 THEN N'Mindestens eine isolierte Quelle fehlt; zugängliche Teilergebnisse bleiben erhalten.'
                      WHEN [ds].[StatusCode]='PENDING' AND [f].[WarnCount]>0 THEN N'Mindestens ein konfigurierter Prüfhinweis liegt vor; kein automatisches Gesundheitsurteil.'
                      WHEN [ds].[StatusCode]='PENDING' THEN N'Kein konfigurierter Warnindikator in der zugänglichen Momentaufnahme; dies beweist weder vollständige Zustellung noch fehlerfreie Verarbeitung.'
                      ELSE [ds].[Detail] END
    FROM [#ServiceBrokerAnalysis_DatabaseStatus] [ds]
    OUTER APPLY
    (
        SELECT COUNT_BIG(*) AS [FailureCount]
        FROM [#ServiceBrokerAnalysis_SourceStatus] [ss]
        WHERE [ss].[DatabaseName]=[ds].[DatabaseName] AND [ss].[IsPartial]=1
    ) [x]
    OUTER APPLY
    (
        SELECT COUNT_BIG(*) AS [FindingCount],
               COALESCE(SUM(CASE WHEN [ff].[Severity]='WARN' THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END),0) AS [WarnCount]
        FROM [#ServiceBrokerAnalysis_Findings] [ff]
        WHERE [ff].[DatabaseName]=[ds].[DatabaseName]
    ) [f]
    WHERE NOT EXISTS
    (
        SELECT 1 FROM [#ServiceBrokerAnalysis_DatabaseCandidateWarnings] [w]
        WHERE [w].[RequestedName]=[ds].[DatabaseName]
    );

    IF @StatusCode='AVAILABLE'
    BEGIN
        IF EXISTS(SELECT 1 FROM [#ServiceBrokerAnalysis_DatabaseStatus] WHERE [IsPartial]=1)
            SELECT @StatusCode='AVAILABLE_LIMITED',@IsPartial=1;
        ELSE IF EXISTS(SELECT 1 FROM [#ServiceBrokerAnalysis_Findings] WHERE [Severity]='WARN')
            SET @StatusCode='AVAILABLE_WITH_FINDING';
        ELSE IF NOT EXISTS
            (SELECT 1 FROM [#ServiceBrokerAnalysis_FeatureScope]
             WHERE [IsBrokerEnabled]=1 OR [UserQueueCount]>0 OR [UserServiceCount]>0)
            SET @StatusCode='NOT_APPLICABLE';
    END;

    SELECT @ErrorNumber=COALESCE(@ErrorNumber,MIN([ErrorNumber])),
           @ErrorMessage=COALESCE(@ErrorMessage,MIN([ErrorMessage]))
    FROM [#ServiceBrokerAnalysis_SourceStatus]
    WHERE [IsPartial]=1;

    /* Ausgabegrenzen werden nach der vollständigen Zählerbildung einmal angewandt. */
    INSERT [#ServiceBrokerAnalysis_FindingsExport]
    ([FindingOrdinal],[DatabaseName],[SchemaName],[ObjectName],[Severity],[Confidence],
     [FindingCode],[MetricName],[MetricValue],[ThresholdValue],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
    SELECT TOP(@Limit) [FindingOrdinal],[DatabaseName],[SchemaName],[ObjectName],[Severity],[Confidence],
           [FindingCode],[MetricName],[MetricValue],[ThresholdValue],[Evidence],[EvidenceLimit],[RecommendedNextCheck]
    FROM [#ServiceBrokerAnalysis_Findings]
    WHERE @NurProblematisch=0 OR [Severity]='WARN'
    ORDER BY CASE [Severity] WHEN 'WARN' THEN 1 ELSE 2 END,[FindingOrdinal];

    IF @JsonErzeugen=1
    BEGIN
        SELECT @Json=(
            SELECT
                JSON_QUERY((SELECT N'USP_ServiceBrokerAnalysis' AS [module],@Now AS [collectedAtUtc],@StatusCode AS [statusCode],@IsPartial AS [isPartial],@ErrorNumber AS [errorNumber],@ErrorMessage AS [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)) AS [meta],
                JSON_QUERY(COALESCE((SELECT * FROM [#ServiceBrokerAnalysis_DatabaseStatus] ORDER BY [DatabaseName] FOR JSON PATH),N'[]')) AS [databaseStatus],
                JSON_QUERY(COALESCE((SELECT * FROM [#ServiceBrokerAnalysis_SourceStatus] ORDER BY [DatabaseName],[SourceCode] FOR JSON PATH),N'[]')) AS [sourceStatus],
                JSON_QUERY(COALESCE((SELECT * FROM [#ServiceBrokerAnalysis_FindingsExport] ORDER BY CASE [Severity] WHEN 'WARN' THEN 1 ELSE 2 END,[FindingOrdinal] FOR JSON PATH),N'[]')) AS [findings],
                JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM [#ServiceBrokerAnalysis_Queue] WHERE @NurProblematisch=0 OR [AssessmentStatus]='REVIEW' ORDER BY CASE [AssessmentStatus] WHEN 'REVIEW' THEN 1 ELSE 2 END,[QueueRowsApprox] DESC,[DatabaseName],[SchemaName],[QueueName] FOR JSON PATH),N'[]')) AS [queues],
                JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM [#ServiceBrokerAnalysis_TransmissionGroup] WHERE @NurProblematisch=0 OR [TransmissionStatus] IS NOT NULL OR [OldestAgeMinutes]>=@TransmissionAgeWarnMinutes ORDER BY [OldestAgeMinutes] DESC,[MessageCount] DESC,[DatabaseName] FOR JSON PATH),N'[]')) AS [transmissionGroups],
                JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM [#ServiceBrokerAnalysis_ConversationState] WHERE @NurProblematisch=0 OR [StateCode]='ER' OR [ExpiredLifetimeCount]>0 OR [EndpointCount]>=@ConversationRowsWarn ORDER BY [EndpointCount] DESC,[DatabaseName],[StateCode] FOR JSON PATH),N'[]')) AS [conversationStates]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
    END;

    IF @OutputMode<>'NONE'
    BEGIN
        SELECT N'USP_ServiceBrokerAnalysis' AS [Module],@Now AS [CollectedAtUtc],@StatusCode AS [StatusCode],
               @IsPartial AS [IsPartial],@ErrorNumber AS [ErrorNumber],@ErrorMessage AS [ErrorMessage],
               N'Read-only Broker-Metadatenaufnahme; keine Queue-Nutzdaten, Nachrichtenkörper, RECEIVE-, DDL- oder Conversation-Änderung.' AS [Detail];
        SELECT * FROM [#ServiceBrokerAnalysis_DatabaseStatus] ORDER BY [DatabaseName];
        SELECT * FROM [#ServiceBrokerAnalysis_SourceStatus] ORDER BY [DatabaseName],[SourceCode];
        SELECT * FROM [#ServiceBrokerAnalysis_FindingsExport]
        ORDER BY CASE [Severity] WHEN 'WARN' THEN 1 ELSE 2 END,[FindingOrdinal];
        SELECT TOP(@Limit) * FROM [#ServiceBrokerAnalysis_Queue]
        WHERE @NurProblematisch=0 OR [AssessmentStatus]='REVIEW'
        ORDER BY CASE [AssessmentStatus] WHEN 'REVIEW' THEN 1 ELSE 2 END,
                 [QueueRowsApprox] DESC,[DatabaseName],[SchemaName],[QueueName];
        SELECT TOP(@Limit) * FROM [#ServiceBrokerAnalysis_TransmissionGroup]
        WHERE @NurProblematisch=0 OR [TransmissionStatus] IS NOT NULL OR [OldestAgeMinutes]>=@TransmissionAgeWarnMinutes
        ORDER BY [OldestAgeMinutes] DESC,[MessageCount] DESC,[DatabaseName];
        SELECT TOP(@Limit) * FROM [#ServiceBrokerAnalysis_ConversationState]
        WHERE @NurProblematisch=0 OR [StateCode]='ER' OR [ExpiredLifetimeCount]>0 OR [EndpointCount]>=@ConversationRowsWarn
        ORDER BY [EndpointCount] DESC,[DatabaseName],[StateCode];
    END;

    IF @PrintMeldungen=1 AND @StatusCode NOT IN('AVAILABLE','NOT_APPLICABLE')
    BEGIN
        SET @PrintMessage=LEFT(CONCAT(N'USP_ServiceBrokerAnalysis: ',@StatusCode,N'. ',COALESCE(@ErrorMessage,N'Siehe strukturierte Quellenstatus.')),2048);
        RAISERROR(N'%s',10,1,@PrintMessage) WITH NOWAIT;
    END;

    SELECT @StatusCodeOut=@StatusCode,@IsPartialOut=@IsPartial,
           @ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#ServiceBrokerAnalysis_FindingsExport'
            , @ResultLabel=N'ServiceBrokerAnalysis'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#ServiceBrokerAnalysis_FindingsExport'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
