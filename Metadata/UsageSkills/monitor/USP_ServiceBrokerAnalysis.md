---
skill_format_version: "1.0.0"
name: "monitor.USP_ServiceBrokerAnalysis"
schema_name: "monitor"
object_name: "USP_ServiceBrokerAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure analysiert sichtbare Service-Broker-Konfiguration, Queue- Kapazität, interne Aktivierung, Transmission-Rückstand und aggregierte Conversation-Zustände."
source_path: "Code/09_VersionAdaptive/050_USP_ServiceBrokerAnalysis.sql"
---

# monitor.USP_ServiceBrokerAnalysis

## Zweck und Einsatz

Die Procedure analysiert sichtbare Service-Broker-Konfiguration, Queue- Kapazität, interne Aktivierung, Transmission-Rückstand und aggregierte Conversation-Zustände.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

sys.databases, sys.service_queues, sys.services, sys.dm_db_partition_stats, sys.dm_broker_queue_monitors, sys.dm_broker_activated_tasks, sys.transmission_queue und sys.conversation_endpoints.

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
| @TransmissionAgeWarnMinutes | bigint | nein | 60 |
| @TransmissionRowsWarn | bigint | nein | 1000 |
| @QueueRowsWarn | bigint | nein | 10000 |
| @ActivationSilenceWarnMinutes | bigint | nein | 60 |
| @ConversationRowsWarn | bigint | nein | 100000 |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max)=NULL; Default: NULL. Die effektive Datenbankauswahl: NULL, eine leere Zeichenfolge oder nur äußere Leerzeichen bedeuten keine explizite Namensliste; dann werden alle sichtbaren Online-Benutzerdatenbanken im zulässigen Scope berücksichtigt. Andernfalls ist eine Pipe-getrennte Liste einteiliger SQL-Datenbanknamen zulässig. Pipe trennt außerhalb von [Klammern]; ]] maskiert darin eine schließende Klammer, Segmentränder werden getrimmt. Leere Elemente, strukturell ungültige Klammerung, vom PARSENAME-basierten Prüfer abgewiesene mehrteilige Namen, Rohsegmente über 4000 UTF-16-Codeeinheiten sowie case-sensitive doppelte Namen sind ungültig. Die Namensprüfung ist keine vollständige SQL-Identifiergrammatik. Ein effektiver Listenwert ist mit @DatabaseNamePattern exklusiv; eine nur aus Leerzeichen bestehende Liste gilt als nicht angegeben. Datenbanknamen werden case-sensitive abgeglichen. Die Datenbankauswahl begrenzt sämtliche Datenbankquellen; optionale Schema- und Queuefilter beeinflussen zusätzlich queuebezogene Auswertungen sowie zugeordnete Transmission- und Conversation-Gruppen. Der einzelne Name ist auf höchstens 128 Zeichen begrenzt; dies gilt zusätzlich zur Rohsegmentgrenze von 4000 UTF-16-Codeeinheiten. Bei ausgelassenem Argument gilt der angegebene Default.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit=0; Default: 0. Steuert, ob die vier Systemdatenbanken master, tempdb, model und msdb in die Datenbankkandidaten einbezogen werden können. Nach SQL-Konvertierung in bit bedeutet 0 Ausschluss und jeder numerische Wert ungleich 0 den Wert 1; NULL ist im normalen Analysepfad ungültig; bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Eine ausdrücklich angeforderte, ausgeschlossene Systemdatenbank wird als nicht auswertbar ausgewiesen. Der Schalter setzt weder Datenbanksichtbarkeit noch Berechtigungen außer Kraft. Bei ausgelassenem Argument gilt der angegebene Default.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000)=NULL; Default: NULL. Optionales Pattern für die Datenbankauswahl; NULL bedeutet keine Pattern-Einschränkung, eine leere oder nur aus Leerzeichen bestehende Eingabe ist ungültig. Äußere Leerzeichen werden vor Präfixerkennung entfernt; like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt, sonst gilt LIKE. Der Rest nach dem Präfix wird nicht erneut getrimmt. LIKE wird case-sensitive ausgewertet; % steht für beliebig viele Zeichen, _ für ein Zeichen und [...] beziehungsweise [^...] für eine Zeichenklasse oder deren Negation. Es wird kein eigenes ESCAPE-Zeichen gesetzt. regex: verwendet Flag c, regexi: Flag i; die Parserprüfung validiert nicht die Regex-Syntax. Regex-Ausführung verlangt SQL Server 2025 oder neuer und Compatibility Level 170 der Installationsdatenbank. Ein effektiver @DatabaseNames-Listenwert ist mit dem Pattern exklusiv. Bei ausgelassenem Argument gilt der angegebene Default.

**@HighImpactConfirmed:** @HighImpactConfirmed bit=0; Default: 0. Bestätigt den High-Impact-Aufrufpfad. Nach SQL-Konvertierung in bit bedeutet 0 den Wert 0 und jeder numerische Wert ungleich 0 den Wert 1. NULL ist im normalen Analysepfad ein INVALID_PARAMETER des Vorbereitungspfads und wird nicht als 0 behandelt. Die Procedure prüft CATALOG_DEEP; der Klassenkatalog setzt dafür RequiresGroupGate=1. Bei 0 wird HIGH_IMPACT_CONFIRMATION_REQUIRED geliefert; bei 1 wird die aktuelle Zugriffspolicy geprüft und kann DENIED_GROUP ergeben. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Die Bestätigung selbst erteilt keine Freigabe und ersetzt weder Datenbanksichtbarkeit noch Quellenberechtigungen. Bei ausgelassenem Argument gilt der angegebene Default.

**@SchemaNames:** @SchemaNames nvarchar(max)=NULL; Default: NULL. Optionale exakte Pipe-Liste einteiliger Schemanamen. NULL lässt Schemanamen ungefiltert; eine leere oder nur aus Leerzeichen bestehende Liste ist ungültig. Pipe trennt außerhalb bracket-quotierter Bereiche, ]] maskiert darin eine schließende Klammer, Segmentränder werden getrimmt. Der PARSENAME-basierte Prüfer kontrolliert die verwendeten Namensbestandteile, aber keine vollständige SQL-Identifiergrammatik; leere, abgewiesene mehrteilige, strukturell fehlerhafte, über 4000 UTF-16-Codeeinheiten lange und case-sensitive doppelte Elemente sind ungültig. Der Abgleich ist case-sensitive über SQL_Latin1_General_CP1_CS_AS. @SchemaNames ist mit @SchemaNamePattern exklusiv; @FullObjectNames ist mit @SchemaNames und @ObjectNames jeweils exklusiv. Die Filter begrenzen Queue-Katalog- und Queue-Kapazitätsauswertungen sowie über Service, Queue und Schema zugeordnete Transmission- und Conversation-Gruppen. Ohne gesetzte Queuefilter bleiben diese Gruppen datenbankweit; bei gesetzten Filtern können nicht zuordenbare LEFT-JOIN-Zeilen entfallen. Der einzelne Name ist auf höchstens 128 Zeichen begrenzt; dies gilt zusätzlich zur Rohsegmentgrenze von 4000 UTF-16-Codeeinheiten. Bei ausgelassenem Argument gilt der angegebene Default.

**@SchemaNamePattern:** @SchemaNamePattern nvarchar(4000)=NULL; Default: NULL. Optionales Schema-Pattern; NULL bedeutet keine Pattern-Einschränkung, eine leere Eingabe oder ein leerer Inhalt nach Präfix ist ungültig. Äußere Leerzeichen werden vor Präfixerkennung entfernt; like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt, sonst gilt LIKE. Der Rest nach dem Präfix wird nicht erneut getrimmt. LIKE wird case-sensitive ausgewertet; % steht für beliebig viele Zeichen, _ für ein Zeichen und [...] beziehungsweise [^...] für eine Zeichenklasse oder deren Negation. Es wird kein eigenes ESCAPE-Zeichen gesetzt. regex: verwendet Flag c, regexi: Flag i; der Parser validiert weder Regex-Syntax noch Treffer. Regex-Ausführung verlangt SQL Server 2025 oder neuer und Compatibility Level 170 in jeder ausgewerteten Zieldatenbank. Mit @SchemaNames ist das Pattern exklusiv. Der Filter wirkt auf Queue-Bezüge und auf Transmission-/Conversation-Gruppen, die über Service, Queue und Schema zugeordnet werden; ohne Queuefilter bleiben diese Gruppen datenbankweit, während gesetzte Filter nicht zuordenbare LEFT-JOIN-Zeilen ausschließen können. Bei ausgelassenem Argument gilt der angegebene Default.

**@ObjectNames:** @ObjectNames nvarchar(max)=NULL; Default: NULL. Optionale exakte Pipe-Liste einteiliger Queue-Namen. NULL lässt Queue-Namen ungefiltert; eine leere oder nur aus Leerzeichen bestehende Liste ist ungültig. Pipe trennt außerhalb bracket-quotierter Bereiche, ]] maskiert darin eine schließende Klammer, Segmentränder werden getrimmt. Der PARSENAME-basierte Prüfer kontrolliert die verwendeten Namensbestandteile, aber keine vollständige SQL-Identifiergrammatik; leere, abgewiesene mehrteilige, strukturell fehlerhafte, über 4000 UTF-16-Codeeinheiten lange und case-sensitive doppelte Elemente sind ungültig. Der Abgleich ist case-sensitive über SQL_Latin1_General_CP1_CS_AS. Mit @ObjectNamePattern und @FullObjectNames ist die Liste jeweils exklusiv. Die Filter begrenzen Queue-Auswertungen sowie über Service und Queue zugeordnete Transmission- und Conversation-Gruppen; ohne gesetzte Queuefilter bleiben diese Gruppen datenbankweit, während gesetzte Filter nicht zuordenbare LEFT-JOIN-Zeilen ausschließen können. Der einzelne Name ist auf höchstens 128 Zeichen begrenzt; dies gilt zusätzlich zur Rohsegmentgrenze von 4000 UTF-16-Codeeinheiten. Bei ausgelassenem Argument gilt der angegebene Default.

**@ObjectNamePattern:** @ObjectNamePattern nvarchar(4000)=NULL; Default: NULL. Optionales Pattern für Queue-Namen; NULL bedeutet keine Pattern-Einschränkung, eine leere Eingabe oder ein leerer Inhalt nach Präfix ist ungültig. Äußere Leerzeichen werden vor Präfixerkennung entfernt; like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt, sonst gilt LIKE. Der Rest nach dem Präfix wird nicht erneut getrimmt. LIKE wird case-sensitive ausgewertet; % steht für beliebig viele Zeichen, _ für ein Zeichen und [...] beziehungsweise [^...] für eine Zeichenklasse oder deren Negation. Es wird kein eigenes ESCAPE-Zeichen gesetzt. regex: verwendet Flag c, regexi: Flag i; der Parser validiert weder Regex-Syntax noch Treffer. Regex-Ausführung verlangt SQL Server 2025 oder neuer und Compatibility Level 170 in jeder ausgewerteten Zieldatenbank. Mit @ObjectNames ist das Pattern exklusiv. Der Filter wirkt auf Queue-bezogene Auswertungen sowie über Service und Queue zugeordnete Transmission- und Conversation-Gruppen; ohne Queuefilter bleiben diese Gruppen datenbankweit, gesetzte Filter können nicht zuordenbare LEFT-JOIN-Zeilen ausschließen. Bei ausgelassenem Argument gilt der angegebene Default.

**@FullObjectNames:** @FullObjectNames nvarchar(max)=NULL; Default: NULL. Optionale Pipe-Liste ein-, zwei- oder dreiteiliger Queue-Bezüge: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt. Vierteilige Linked-Server-Bezüge werden abgewiesen. NULL bedeutet kein Qualifikationsfilter; eine leere oder nur aus Leerzeichen bestehende Liste, leere Elemente, fehlerhafte Klammerung, Rohsegmente über 4000 UTF-16-Codeeinheiten sowie case-sensitive Duplikate sind ungültig. Pipe trennt außerhalb bracket-quotierter Teile, ]] maskiert darin eine schließende Klammer, Rand-Leerzeichen werden getrimmt. Die PARSENAME-basierte Prüfung untersucht die vorhandenen Bestandteile, ist aber keine vollständige SQL-Identifiergrammatik und löst keine Datenbanken, Schemas oder Objekte auf. Nicht angegebene Datenbank- oder Schemaanteile wirken als Wildcard; vorhandene Teile werden case-sensitive mit Datenbank, Schema und Queue abgeglichen. Mit @SchemaNames oder @ObjectNames ist die Liste exklusiv; Patternfilter bleiben kombinierbar. Die Filter wirken auch auf Transmission- und Conversation-Gruppen, soweit deren LEFT JOINs einen passenden Service-/Queue-/Schema-Bezug liefern; nicht zuordenbare Zeilen können bei gesetzten Filtern entfallen. Jeder vorhandene Objekt-, Schema- und Datenbankbestandteil ist einzeln auf höchstens 128 Zeichen begrenzt; die Rohsegmentgrenze von 4000 UTF-16-Codeeinheiten gilt zusätzlich. Bei ausgelassenem Argument gilt der angegebene Default.

**@NurProblematisch:** @NurProblematisch bit=0; Default: 0. Nach Erzeugung der vollständigen Befunde beschränkt 0 die Ausgabe nicht; jeder numerische Wert ungleich 0 wird bei Bindung an bit zu 1 und aktiviert die Problemfilter, NULL ist ungültig. Bei 1 werden Findings auf Severity WARN, Queues auf AssessmentStatus REVIEW, Transmission-Gruppen auf vorhandenen TransmissionStatus oder ein Alter mindestens @TransmissionAgeWarnMinutes und Conversation-Gruppen auf StateCode ER, abgelaufene Lifetime oder EndpointCount mindestens @ConversationRowsWarn beschränkt. Der Conversation-Test verwendet den Code ER, nicht den Beschreibungstext ERROR. Die Queuefilter können zuvor auch die Transmission- und Conversation-Gruppen nach zugeordneten Queues einschränken. DatabaseStatus und SourceStatus werden von diesem Schalter nicht gefiltert. Die Auswahl ist kein umfassendes Gesundheitsurteil; insbesondere INFO-Findings werden bei 1 ausgelassen. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.

**@TransmissionAgeWarnMinutes:** @TransmissionAgeWarnMinutes bigint=60; Default: 60. Nichtnegativer Grenzwert in Minuten für das Alter des ältesten Eintrags jeder gefilterten Transmission-Gruppe. NULL oder negativ ist ungültig. Das Alter wird als DATEDIFF_BIG(MINUTE, MIN(enqueue_time), SYSUTCDATETIME()) berechnet; es zählt Minutenintervallgrenzen bis zur jeweiligen Quellenaufnahme. Eine Gruppe erzeugt bei Alter >= Grenzwert ein WARN-Finding; bei 0 wird weiterhin Alter >= 0 geprüft. Gruppen mit negativem gemessenem Alter, etwa bei einem Zeitstempel in der Zukunft, erfüllen diese Bedingung nicht. Das Finding wird nur aus gruppierten Transmission-Einträgen erzeugt, und der Wert beweist allein keinen dauerhaften Übertragungsfehler, weil Zustellung und Retention Einträge sichtbar halten können. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.

**@TransmissionRowsWarn:** @TransmissionRowsWarn bigint=1000; Default: 1000. Nichtnegativer Mindestwert für die Summe der MessageCount-Werte der nach Datenbank- und gegebenenfalls Queuefiltern verbleibenden Transmission-Gruppen je Datenbank. NULL oder negativ ist ungültig. Ab Summe >= Grenzwert wird ein WARN-Kontexthinweis erzeugt. Bei 0 wird der Hinweis für jede Datenbank mit mindestens einer verbleibenden Gruppe erzeugt; eine Datenbank ohne Gruppe erzeugt keinen Hinweis. Die Momentaufnahme belegt allein weder Fehler noch Rückstandsdauer. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.

**@QueueRowsWarn:** @QueueRowsWarn bigint=10000; Default: 10000. Nichtnegativer Grenzwert für die approximative Zeilenzahl jeder sichtbaren und gefilterten Queue. NULL oder negativ ist ungültig. Bei QueueRowsApprox >= Grenzwert wird ein WARN-Kontexthinweis erzeugt; bei 0 gilt die Bedingung für jede Queue mit nicht-NULL Zählung. Der Wert stammt aus sys.dm_db_partition_stats und ist approximativ; er sagt allein nichts über Nachrichtenalter, Durchsatz, Priorität oder fachlich zulässigen Rückstand aus. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.

**@ActivationSilenceWarnMinutes:** @ActivationSilenceWarnMinutes bigint=60; Default: 60. Nichtnegativer Zeitgrenzwert in Minuten seit der letzten internen Aktivierung. NULL oder negativ ist ungültig. Ein WARN-Finding wird nur geprüft, wenn die Queue nichtleer ist, eine interne Aktivierungsprozedur eingetragen und aktiviert ist, kein aktivierter Task sichtbar ist, der Monitor nicht RECEIVES_OCCURRING meldet und die Quellen für Kapazität, Monitor und aktivierte Tasks sämtlich verfügbar sind. Bei NULL von LastActivatedTime gilt die Zeitbedingung als erfüllt; andernfalls wird DATEDIFF_BIG(MINUTE, LastActivatedTime, @Now) >= Grenzwert geprüft. Bei 0 wird weiterhin DATEDIFF_BIG(MINUTE, LastActivatedTime, @Now) >= 0 geprüft; ein zukünftiger nicht-NULL-Zeitstempel kann die Bedingung verfehlen. NULL von LastActivatedTime erfüllt die Zeitbedingung ausdrücklich. Die DMV-Werte sind Momentaufnahmen und belegen keine Ursache. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.

**@ConversationRowsWarn:** @ConversationRowsWarn bigint=100000; Default: 100000. Nichtnegativer Mindestwert für die Summe der EndpointCount-Werte der nach Datenbank- und gegebenenfalls Queuefiltern verbleibenden Conversation-Zustandsgruppen je Datenbank. NULL oder negativ ist ungültig. Ab Summe >= Grenzwert wird ein WARN-Kontexthinweis erzeugt. Bei 0 wird der Hinweis für jede Datenbank mit mindestens einer verbleibenden Zustandsgruppe erzeugt; eine Datenbank ohne Gruppe erzeugt keinen Hinweis. Der Wert zählt die sichtbare Momentaufnahme aus sys.conversation_endpoints und beweist allein weder ein END CONVERSATION-Leck noch einen Fehler. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.

**@MaxZeilen:** @MaxZeilen int=2000; Default: 2000. Begrenzt jeweils die Findings-, Queue-, Transmission- und Conversation-Ausgabeliste; die vollständigen Quellenaggregate, Findings und Statuszähler werden vorher gebildet. NULL oder 0 bedeutet keine praktische Begrenzung; positive Werte sind die jeweilige Obergrenze und negative Werte sind ungültig. Die Begrenzung gilt je Liste und weder für DatabaseStatus/SourceStatus noch als gemeinsames Gesamtlimit. Findings werden mit WARN zuerst und danach nach FindingOrdinal sortiert; Queues mit REVIEW zuerst, danach absteigender approximativer Zeilenzahl sowie Datenbank, Schema und Queue; Transmission-Gruppen nach Alter und MessageCount absteigend, danach Datenbank; Conversation-Gruppen nach EndpointCount absteigend, danach Datenbank und StateCode. Die Sortierung bestimmt, welche Zeilen innerhalb des jeweiligen Limits ausgegeben werden; der Wert begrenzt nicht die zuvor gelesenen Quelldaten. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.

**@LockTimeoutMs:** @LockTimeoutMs int=0; Default: 0. Lock-Wartezeit in Millisekunden für die dynamischen datenbankbezogenen Quellabfragen. Zulässig sind Werte von 0 bis 60000 einschließlich; NULL oder ein Wert außerhalb des Bereichs ist ungültig. 0 bedeutet NOWAIT für diese Quellabfragen. Der Wert wird in die einzelnen dynamischen Batches eingesetzt; die dort gesetzte Lock-Wartezeit wird bei Rückkehr aus dem Batch zurückgenommen. Er begrenzt weder die Gesamtlaufzeit noch die vorgelagerte lokale Temp-Tabellenanlage, für die die Helfer eigene Zeitfenster verwenden, und garantiert keine transaktionskonsistente Momentaufnahme. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultSetArt:** @ResultSetArt varchar(16)='CONSOLE'; Default: 'CONSOLE'. Bestimmt die Ausgabeform; NULL, leer oder nur aus Leerzeichen bestehend ergibt nach Trim und Großschreibung einen ungültigen Wert. Zulässige Werte: CONSOLE erzeugt eine beschriftete Findings-Ansicht und bei leerer Findings-Quelle eine verständliche Leerzeile; RAW gibt genau sieben Resultsets in dieser Reihenfolge aus: Modul-/Statusübersicht, DatabaseStatus, SourceStatus, FindingsExport, Queue, TransmissionGroup und ConversationState; TABLE schreibt nur FindingsExport in das vorab geprüfte Ziel; NONE unterdrückt die normalen Resultsets. Weitere Werte ergeben INVALID_PARAMETER. Ein nichtleeres @ResultTablesJson ist nur mit TABLE zulässig; die Prüfung erfolgt vor @Hilfe. @JsonErzeugen steuert JSON unabhängig von der Resultsetart. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. Nur mit @ResultSetArt=TABLE ist ein nichtleerer JSON-Wert zulässig; außerhalb von TABLE löst jeder nach Trim nichtleere Inhalt Fehler 51011 aus. Beim TABLE-Preflight muss ein gültiges JSON-Objekt mit genau einem case-sensitiven Schlüssel findings und einem nichtleeren Zeichenfolgenwert für die Zieltemp-Tabelle vorliegen; zusätzliche Schlüssel, falsche Werttypen und ein abweichender Schlüssel werden abgewiesen. Das Ziel muss ein leeres lokales #Temp-Objekt mit Namen bis höchstens 116 Zeichen, einzelnem #-Präfix, ohne ## und ohne das case-insensitiv reservierte Präfix #Monitor sein. Als Seed genügt genau eine beliebige Spalte; ein fertiges Findings-Schema ist nicht erforderlich. Der Preflight prüft vor @Hilfe und kann 51011 werfen; der abschließende Writer ersetzt die Seedspalte anhand des Findings-Quellschemas und kann nach den OUTPUT-Zuweisungen mit Fehler 51010 werfen. Bei einem THROW ist keine Zustellung von OUTPUT-Werten zugesichert. Wiederholte findings-Schlüssel werden auch dann abgewiesen, wenn beide exakt findings lauten; nur ein einzelnes Vorkommen ist zulässig. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. Steuert unabhängig von @ResultSetArt die Erzeugung des JSON-Dokuments in @Json. Nach SQL-Konvertierung in bit bedeutet 0 keine JSON-Erzeugung und jeder numerische Wert ungleich 0 die Erzeugung; NULL ist ungültig. Das JSON besteht aus dem Objekt meta und den Arrays databaseStatus, sourceStatus, findings, queues, transmissionGroups und conversationStates. Die vier Befund-/Fachdatenarrays findings, queues, transmissionGroups und conversationStates folgen @NurProblematisch und jeweils @MaxZeilen; die beiden Statusarrays sind von diesen Begrenzungen ausgenommen. ErrorNumber und ErrorMessage in meta werden unabhängig aggregiert und können aus unterschiedlichen Quellen stammen. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. Ausgabeparameter für das JSON-Dokument. Für die Bindung wird eine Variable des Parametertyps verwendet und mit OUTPUT übergeben, zum Beispiel @Json = @JsonVariable OUTPUT. Der Wert wird zu Beginn auf NULL gesetzt; nur bei @JsonErzeugen ungleich 0 wird das meta-Objekt mit den sechs Arrays databaseStatus, sourceStatus, findings, queues, transmissionGroups und conversationStates zugewiesen. Ein früher @Hilfe-Rücksprung lässt @Json NULL. Bei einem späteren THROW ist keine Zustellung des OUTPUT-Werts zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@PrintMeldungen:** @PrintMeldungen bit=1; Default: 1. Steuert die zusätzliche Meldung mit Severity 10 und NOWAIT bei einem globalen Status außerhalb AVAILABLE und NOT_APPLICABLE. Nach SQL-Konvertierung in bit bedeutet 0 keine Meldung und jeder numerische Wert ungleich 0 die Meldung; NULL ist ungültig. Der Text nennt Statuscode und Fehlertext oder verweist auf den strukturierten Quellenstatus. Die Einstellung verändert weder Status noch Resultsets und steuert nicht die einzelnen WARN-Findings. Bei @Hilfe=1 wird die normale Eingabevalidierung übersprungen. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit=0; Default: 0. Bei 1 werden die eingebauten Hilfezeilen ausgegeben und die Procedure kehrt vor Quellenanalyse und den vier diagnostischen OUTPUT-Zuweisungen zurück. Nach SQL-Konvertierung in bit führt 0 zum normalen Ausführungspfad; auch NULL wird nicht als ungültig behandelt und fällt in den normalen Pfad. Jeder numerische Wert ungleich 0 wird zu 1 und aktiviert die Hilfe. @Json wird vor dem Hilfezweig auf NULL gesetzt; die vier diagnostischen OUTPUT-Parameter bleiben bei diesem Rücksprung unverändert. Der TABLE-Preflight läuft vor dem Hilfezweig und kann daher auch bei einem Hilfeaufruf Fehler 51011 werfen. Bei ausgelassenem Argument gilt der angegebene Default.

**@StatusCodeOut:** @StatusCodeOut varchar(40)=NULL OUTPUT; Default: NULL. OUTPUT-Bindung für den globalen Statuscode; eine Variable des Parametertyps wird mit @StatusCodeOut = @StatusVariable OUTPUT übergeben. Die tatsächlich erreichbaren Codes sind: AVAILABLE = Quellen vollständig ausgewertet, ohne WARN-Finding und mit sichtbarem Broker-Scope; INVALID_PARAMETER = ungültige oder widersprüchliche Eingabe; UNAVAILABLE_VERSION = Regex-Pattern bei SQL Server vor Version 2025; UNAVAILABLE_FEATURE = Datenbankregex wegen fehlender Compatibility Level 170 der Installationsdatenbank nicht verfügbar; HIGH_IMPACT_CONFIRMATION_REQUIRED = CATALOG_DEEP verlangt Gruppenbestätigung, aber @HighImpactConfirmed ist 0; DENIED_GROUP = Zugriffspolicy gibt den Analysepfad nicht frei; INTERNAL_ERROR = interner Kandidaten- oder Filtervorbereitungsfehler; TIMEOUT = Fehler 1222 im Namensfilter-Preflight; DENIED_PERMISSION = dort anhand 229, 262, 297, 300, 371 oder 916 klassifizierter Fehler; ERROR_HANDLED = sonstiger vom Namensfilter-Preflight behandelter Fehler; NOT_APPLICABLE = keine auswertbare Datenbank oder kein sichtbarer Broker-Scope; AVAILABLE_LIMITED = mindestens eine Datenbankquelle ist partiell; AVAILABLE_WITH_FINDING = Quellen vollständig und mindestens ein WARN-Finding vorhanden. Frühe Parameter-, Versions-, Feature-, Gate- und Helperfehler bleiben maßgeblich. Nach der Analyse gilt die Priorität AVAILABLE_LIMITED vor AVAILABLE_WITH_FINDING, vor NOT_APPLICABLE, vor AVAILABLE. TIMEOUT, DENIED_PERMISSION und ERROR_HANDLED aus dem Namensfilter-Preflight setzen @IsPartialOut auf 1, überspringen die spätere Datenbankanalyse und bleiben bis zu diesem OUTPUT-Wert und meta.statusCode erhalten. Dieselben Statusnamen können auch datenbank- oder quellenbezogen auftreten; diese Teilbefunde führen global zu AVAILABLE_LIMITED. NOT_APPLICABLE_VISIBLE_SCOPE ist ausschließlich datenbankbezogen. Beim @Hilfe-Rücksprung wird der Parameter nicht zugewiesen; bei einem THROW ist keine OUTPUT-Zustellung zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@IsPartialOut:** @IsPartialOut bit=NULL OUTPUT; Default: NULL. OUTPUT-Bindung für das globale Partial-Flag; eine Variable des Parametertyps wird mit @IsPartialOut = @PartialVariable OUTPUT übergeben. 1 wird bei ungültigen Parametern sowie frühen Versions-, Feature-, Gate- oder Helperabbrüchen gesetzt und kennzeichnet außerdem teilweise nicht verfügbare Quellen; AVAILABLE_LIMITED setzt es ebenfalls auf 1. Diese Zuweisungen gelten für den regulären Ausführungspfad nach dem TABLE-Preflight; ein früher THROW kann sie umgehen. 0 bedeutet nur, dass dieses Flag im Aufruf nicht auf 1 gesetzt wurde, nicht dass jede denkbare Quelle vollständig oder fachlich fehlerfrei ist. Bei @Hilfe erfolgt keine Zuweisung; bei einem THROW ist keine OUTPUT-Zustellung zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@ErrorNumberOut:** @ErrorNumberOut int=NULL OUTPUT; Default: NULL. OUTPUT-Bindung für die globale SQL-Fehlernummer; eine Variable des Parametertyps wird mit @ErrorNumberOut = @ErrorNumberVariable OUTPUT übergeben. Wenn mehrere Quellenfehler aggregiert werden, wird MIN(ErrorNumber) gewählt, unabhängig von MIN(ErrorMessage), sodass Nummer und Text nicht zwingend zusammengehören. NULL bedeutet, dass kein Fehlernummernwert gesetzt wurde. Bei @Hilfe erfolgt keine Zuweisung; bei einem THROW ist keine OUTPUT-Zustellung zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048)=NULL OUTPUT; Default: NULL. OUTPUT-Bindung für den globalen Fehler- oder Statuskontext; eine Variable des Parametertyps wird mit @ErrorMessageOut = @ErrorMessageVariable OUTPUT übergeben. Wenn mehrere Quellenfehler aggregiert werden, wird MIN(ErrorMessage) gewählt, unabhängig von MIN(ErrorNumber), sodass Text und Nummer nicht zwingend zusammengehören. Der Wert ist kein vollständiger Fehlerbericht. Für datenbank- oder quellenbezogene Fehler stehen Einzelheiten in DatabaseStatus beziehungsweise SourceStatus. Frühe Fehler des Namensfilter-Preflights werden über den globalen Status und @ErrorMessageOut gemeldet und erzeugen nicht notwendigerweise Einträge in diesen Resultsets. Bei @Hilfe erfolgt keine Zuweisung; bei einem THROW ist keine OUTPUT-Zustellung zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| findings | 1 | 1 | [FindingOrdinal] bigint IDENTITY(1,1) NOT NULL , [DatabaseName] sysname NULL , [SchemaName] sysname NULL , [ObjectName] sysname NULL , [Severity] varchar(16) NOT NULL , [Confidence] varchar(16) NOT NULL , [FindingCode] varchar(120) NOT NULL , [MetricName] varchar(80) NOT NULL , [MetricValue] decimal(38,4) NULL , [ThresholdValue] decimal(38,4) NULL , [Evidence] nvarchar(1000) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL , [RecommendedNextCheck] nvarchar(1000) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_ServiceBrokerAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Keine Queue-Nutzdaten, keine Nachrichtenkörper, kein RECEIVE, keine Queue-Änderung und kein END CONVERSATION. Deaktivierte Queues, alte Einträge und DMV-Zustände sind Prüfhinweise; sie beweisen weder eine Poison Message noch deren Ursache.

MEDIUM; Kataloge, aggregierte Broker-Laufzeitmetadaten und approximative Partitionsstatistik.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
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
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_ServiceBrokerAnalysis
Die Procedure führt eine rein lesende Tiefenanalyse sichtbarer Service-Broker-Konfiguration und aggregierter Laufzeitmetadaten durch.
Queue-Schalter, approximative Queue-Zeilen, Aktivierungs-DMVs, Transmission-Gruppen und Conversation-Zustände werden aus sichtbaren Quellen als Momentaufnahme ausgewertet.
Die Datenbankauswahl begrenzt sämtliche ausgewählten Datenbankquellen; Schema- und Queuefilter greifen zusätzlich bei Queue-Auswertungen und bei über Service, Queue und Schema zugeordneten Transmission- und Conversation-Gruppen.
Bei gesetzten Queuefiltern können Einträge ohne passenden Service-, Queue- oder Schemascope wegen der LEFT-JOIN-Filterbedingungen entfallen; ohne solche Filter bleiben die Gruppen datenbankweit.
Grenzwerte, @NurProblematisch und @MaxZeilen steuern Prüfhinweise beziehungsweise die spätere Ausgabeauswahl; sie erzeugen kein automatisches Gesundheitsurteil.
CONSOLE, RAW, TABLE und NONE steuern die Resultsets; JSON wird unabhängig mit @JsonErzeugen angefordert.
Es werden keine Queue-Nutzdaten, Nachrichtenkörper oder Conversation-Handles gelesen; es erfolgen kein RECEIVE, keine DDL-Änderung und keine Conversation-Änderung.
Beispiel 1: EXEC [monitor].[USP_ServiceBrokerAnalysis] @Hilfe=1;
Beispiel 2: EXEC [monitor].[USP_ServiceBrokerAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @FullObjectNames=N'[ExampleDatabase].[ExampleSchema].[ExampleQueue]', @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
Beispiel 3: DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_ServiceBrokerAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];
Beispiel 4: CREATE TABLE [#ServiceBrokerAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ServiceBrokerAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#ServiceBrokerAnalysis_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#ServiceBrokerAnalysis_HelpExample]; DROP TABLE IF EXISTS [#ServiceBrokerAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#ServiceBrokerAnalysis_HelpExample]; THROW; END CATCH;
Beispiel 5: EXEC [monitor].[USP_ServiceBrokerAnalysis] @DatabaseNamePattern=N'like:ExampleDatabase%', @SchemaNamePattern=N'like:Example%', @HighImpactConfirmed=1, @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
```

