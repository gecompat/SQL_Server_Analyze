---
skill_format_version: "1.0.0"
name: "monitor.USP_FullTextAnalysis"
schema_name: "monitor"
object_name: "USP_FullTextAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure analysiert sichtbare Full-Text-Kataloge und -Indizes sowie aktuelle Populationen, ausstehende Batches, Fragmente, semantische Populationen und serverweite Laufzeitkapazitaet."
source_path: "Code/09_VersionAdaptive/060_USP_FullTextAnalysis.sql"
---

# monitor.USP_FullTextAnalysis

## Zweck und Einsatz

Die Procedure analysiert sichtbare Full-Text-Kataloge und -Indizes sowie aktuelle Populationen, ausstehende Batches, Fragmente, semantische Populationen und serverweite Laufzeitkapazitaet.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

SERVERPROPERTY, sys.fulltext_catalogs, sys.fulltext_indexes, sys.fulltext_index_columns, sys.fulltext_index_fragments, sys.indexes, sys.dm_fts_index_population, sys.dm_fts_outstanding_batches, sys.dm_fts_semantic_similarity_population, sys.dm_fts_memory_pools und sys.dm_fts_fdhosts.

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
| @PopulationAgeWarnMinutes | bigint | nein | 60 |
| @QueryableFragmentWarn | bigint | nein | 30 |
| @OutstandingBatchWarn | bigint | nein | 100 |
| @FailedDocumentWarn | bigint | nein | 1 |
| @CatalogSizeWarnMb | decimal(19,2) | nein | 10240 |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max)=NULL; Default: NULL. Wählt Datenbanken aus einer pipe-getrennten Liste exakter Namen aus. Elemente werden außen getrimmt; eckige Klammern können Sonderzeichen und ein schließendes ] als ]] maskieren. Jedes rohe Listensegment darf höchstens 4000 UTF-16-Codeeinheiten und jeder Name höchstens 128 Zeichen haben. NULL oder eine nur aus Leerzeichen bestehende Gesamteingabe wird zu keiner expliziten Liste normalisiert; leere Listenelemente sind ungültig. Eine nichtleere wirksame Liste ist mit @DatabaseNamePattern gegenseitig ausgeschlossen und führt zusammen zu INVALID_PARAMETER. Systemdatenbanken bleiben ausgeschlossen, sofern @SystemdatenbankenEinbeziehen nicht 1 ist. Der Abgleich und die Duplikatprüfung sind case-sensitive. Der einteilige Namensprüfer verlangt einen nicht-NULL-Teil 1 und einen NULL-Teil 2; Teile 3 und 4 werden nicht gesondert geprüft. Dies ist keine vollständige SQL-Namensgrammatik oder Existenz-/Rechteprüfung. Bei ausgelassenem Argument gilt der angegebene Default.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit=0; Default: 0. 0 schließt Systemdatenbanken aus; 1 lässt sie im sonst gewählten Datenbankscope zu. NULL ist ungültig. SQL Server bindet den Wert zuerst als bit; die Validierung sieht den konvertierten 0/1-Wert oder NULL, nicht den ursprünglichen Ausdruck. Der Schalter erweitert nicht eigenständig die Datenbankliste und ersetzt weder Filter noch das CATALOG_DEEP-Policygate. Bei numerischer SQL-Konvertierung nach bit wird 0 zu 0 und jeder Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000)=NULL; Default: NULL. Wählt Datenbanknamen über kein Präfix oder like: für SQL-LIKE, regex: für Regex mit Flag c (case-sensitive) oder regexi: für Regex mit Flag i (case-insensitive). Präfixe werden ohne Beachtung ihrer Groß-/Kleinschreibung erkannt; der Patternrest wird nicht erneut getrimmt. LIKE vergleicht case-sensitive, verwendet % für beliebig viele Zeichen, _ für genau ein Zeichen und [...] beziehungsweise [^...] für Zeichenklassen beziehungsweise deren Negation und bietet keinen eigenen ESCAPE-Parameter. NULL bedeutet kein Pattern; leerer oder nur aus Leerzeichen bestehender Inhalt ist ungültig. Maximal 4000 Zeichen. Ein wirksamer @DatabaseNames-Listenfilter ist gegenseitig ausgeschlossen. Datenbank-Regex verlangt SQL Server 2025 oder neuer und Compatibility Level 170 der Installationsdatenbank; andernfalls lautet der globale Status UNAVAILABLE_FEATURE. Bei ausgelassenem Argument gilt der angegebene Default.

**@HighImpactConfirmed:** @HighImpactConfirmed bit=0; Default: 0. Bestätigt das vom Analysis-Policy-Pfad CATALOG_DEEP verlangte Gruppengate. 0 verweigert den Pfad, wenn die Policy die Bestätigung erfordert; 1 bestätigt ihn. NULL ist ungültig. SQL Server bindet den Wert zuerst als bit; die Validierung sieht den konvertierten 0/1-Wert oder NULL, nicht den ursprünglichen Ausdruck. Die Bestätigung erweitert keinen Scope und erlaubt keinen Zugriff auf indizierte Inhalte. Bei numerischer SQL-Konvertierung nach bit wird 0 zu 0 und jeder Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default.

**@SchemaNames:** @SchemaNames nvarchar(max)=NULL; Default: NULL. Wählt Tabellenschemas über eine Pipe-Liste exakter einteiliger Namen. NULL bedeutet kein Schema-Listenfilter. Pipe trennt nur außerhalb eckiger Klammern; ]] maskiert darin eine schließende Klammer. Äußere Elementleerzeichen werden entfernt. Ein Rohsegment umfasst höchstens 4000 UTF-16-Codeeinheiten, ein geparster Name höchstens 128 Zeichen. Der PARSENAME-basierte Prüfer verlangt Teil 1 und keinen Teil 2; Teile 3 und 4 werden nicht separat geprüft. Dies ist keine vollständige SQL-Namensgrammatik und keine Prüfung von Existenz oder Rechten. Leere Elemente, eine leere oder nur aus Leerzeichen bestehende Gesamtliste, fehlerhafte Klammerung und case-sensitive Duplikate sind ungültig. @SchemaNames ist mit @SchemaNamePattern sowie @FullObjectNames jeweils exklusiv. Eine Schema- und eine Objektliste können zusammen Tabellen einschränken. Der Abgleich verwendet SQL_Latin1_General_CP1_CS_AS und ist case-sensitive; serverweite Memory Pools und FDHosts werden damit nicht eingegrenzt. Bei ausgelassenem Argument gilt der angegebene Default.

**@SchemaNamePattern:** @SchemaNamePattern nvarchar(4000)=NULL; Default: NULL. Wählt Tabellenschemas über kein Präfix oder like: für SQL-LIKE, regex: für Regex mit Flag c (case-sensitive) oder regexi: für Regex mit Flag i (case-insensitive). Präfixe werden ohne Beachtung ihrer Groß-/Kleinschreibung erkannt; der Patternrest wird nicht erneut getrimmt. LIKE vergleicht case-sensitive, verwendet % für beliebig viele Zeichen, _ für genau ein Zeichen und [...] beziehungsweise [^...] für Zeichenklassen beziehungsweise deren Negation und bietet keinen eigenen ESCAPE-Parameter. NULL bedeutet kein Pattern; leerer oder nur aus Leerzeichen bestehender Inhalt ist ungültig. Maximal 4000 Zeichen. Mit @SchemaNames ungültig. Schema-/Objekt-Regex auf SQL Server unter 2025 ergibt UNAVAILABLE_VERSION; bei Compatibility Level unter 170 in einer Zieldatenbank wird diese DB-Quelle partiell, wodurch global AVAILABLE_LIMITED entstehen kann. Bei ausgelassenem Argument gilt der angegebene Default.

**@ObjectNames:** @ObjectNames nvarchar(max)=NULL; Default: NULL. Wählt Tabellennamen über eine Pipe-Liste exakter einteiliger Namen. NULL bedeutet kein Objekt-Listenfilter. Pipe trennt nur außerhalb eckiger Klammern; ]] maskiert darin eine schließende Klammer. Äußere Elementleerzeichen werden entfernt. Ein Rohsegment umfasst höchstens 4000 UTF-16-Codeeinheiten, ein geparster Name höchstens 128 Zeichen. Der PARSENAME-basierte Prüfer verlangt Teil 1 und keinen Teil 2; Teile 3 und 4 werden nicht separat geprüft. Dies ist keine vollständige SQL-Namensgrammatik und keine Prüfung von Existenz oder Rechten. Leere Elemente, eine leere oder nur aus Leerzeichen bestehende Gesamtliste, fehlerhafte Klammerung und case-sensitive Duplikate sind ungültig. @ObjectNames ist mit @ObjectNamePattern sowie @FullObjectNames jeweils exklusiv. Eine Objekt- und eine Schemaliste können zusammen Tabellen einschränken. Der Abgleich verwendet SQL_Latin1_General_CP1_CS_AS und ist case-sensitive; serverweite Memory Pools und FDHosts werden damit nicht eingegrenzt. Bei ausgelassenem Argument gilt der angegebene Default.

**@ObjectNamePattern:** @ObjectNamePattern nvarchar(4000)=NULL; Default: NULL. Wählt Tabellennamen über kein Präfix oder like: für SQL-LIKE, regex: für Regex mit Flag c (case-sensitive) oder regexi: für Regex mit Flag i (case-insensitive). Präfixe werden ohne Beachtung ihrer Groß-/Kleinschreibung erkannt; der Patternrest wird nicht erneut getrimmt. LIKE vergleicht case-sensitive, verwendet % für beliebig viele Zeichen, _ für genau ein Zeichen und [...] beziehungsweise [^...] für Zeichenklassen beziehungsweise deren Negation und bietet keinen eigenen ESCAPE-Parameter. NULL bedeutet kein Pattern; leerer oder nur aus Leerzeichen bestehender Inhalt ist ungültig. Maximal 4000 Zeichen. Mit @ObjectNames ungültig. Schema-/Objekt-Regex auf SQL Server unter 2025 ergibt UNAVAILABLE_VERSION; bei Compatibility Level unter 170 in einer Zieldatenbank wird diese DB-Quelle partiell, wodurch global AVAILABLE_LIMITED entstehen kann. Bei ausgelassenem Argument gilt der angegebene Default.

**@FullObjectNames:** @FullObjectNames nvarchar(max)=NULL; Default: NULL. Wählt Tabellen über eine Pipe-Liste der Formen Objekt, Schema.Objekt oder Datenbank.Schema.Objekt. Bei drei Teilen ist ein Schema erforderlich; vierteilige Linked-Server-Bezüge sind unzulässig. NULL bedeutet kein Filter; eine leere oder nur aus Leerzeichen bestehende Liste sowie leere Elemente sind ungültig. Pipe trennt außerhalb von [...]; ]] maskiert darin eine schließende Klammer, äußere Elementleerzeichen werden entfernt. Rohsegmente sind auf 4000 UTF-16-Codeeinheiten und jeder vorhandene Namensbestandteil auf 128 Zeichen begrenzt. PARSENAME prüft die Komponenten, aber keine vollständige SQL-Grammatik, Katalogexistenz oder Rechte. Fehlerhafte Klammerung und case-sensitive Duplikate sind ungültig. @FullObjectNames ist mit @SchemaNames und @ObjectNames jeweils exklusiv; Patternfilter bleiben kombinierbar. Fehlende Datenbank-/Schemaanteile wirken im Abgleich als Wildcard; angegebene Teile werden case-sensitive abgeglichen. Serverweite Memory Pools und FDHosts werden damit nicht eingegrenzt. Bei ausgelassenem Argument gilt der angegebene Default.

**@NurProblematisch:** @NurProblematisch bit=0; Default: 0. 0 lässt alle Zeilen der Detailarrays zu; 1 beschränkt Findings auf Severity WARN und Katalog-/Indexzeilen auf AssessmentStatus REVIEW. Bei populations gilt AgeMinutes >= @PopulationAgeWarnMinutes oder Status = 11; bei outstandingBatches gilt BatchErrorCode ungleich 0 oder IsRetryBatch = 1 oder FailedDocumentCount >= @FailedDocumentWarn; bei semanticPopulations gilt AgeMinutes >= @PopulationAgeWarnMinutes. Memory Pools und FDHosts haben kein @NurProblematisch-Prädikat. NULL ist ungültig; SQL Server bindet den Eingang vorab als bit, sodass die Validierung nur den konvertierten Wert sieht. Quellen werden vorher gelesen und aggregiert; der Schalter begrenzt keine Quellarbeit oder Zähler. Bei numerischer SQL-Konvertierung nach bit wird 0 zu 0 und jeder Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default.

**@PopulationAgeWarnMinutes:** @PopulationAgeWarnMinutes bigint=60; Default: 60. Numerischer Minutenwert für die Schwelle des Alters aktuell sichtbarer normaler und semantischer Populationen. Erreicht AgeMinutes den Wert, entsteht ein WARN. Der gebundene bigint-Wert muss zwischen 0 und 9223372036854775807 liegen; NULL und negative Werte sind ungültig. 0 vergleicht jedes nichtnegative Alter. DATEDIFF_BIG berechnet Minuten bis zur UTC-Aufnahme; ein Zukunftszeitstempel kann negatives Alter ergeben. Die DMVs zeigen laufende Vorgänge, keine Historie. Bei ausgelassenem Argument gilt der angegebene Default.

**@QueryableFragmentWarn:** @QueryableFragmentWarn bigint=30; Default: 30. Numerischer Zählwert für die Mindestzahl querybarer Fragmente je Index, ab der WARN entsteht. Es zählen Fragmente mit Status 4 oder 6; die Anzahl muss zusätzlich positiv sein. Der gebundene bigint-Wert muss zwischen 0 und 9223372036854775807 liegen; NULL und negative Werte sind ungültig. 0 weist jeden Index mit mindestens einem solchen Fragment aus. Es gibt keinen universellen Microsoft-Grenzwert und die Procedure reorganisiert nicht. Bei ausgelassenem Argument gilt der angegebene Default.

**@OutstandingBatchWarn:** @OutstandingBatchWarn bigint=100; Default: 100. Numerischer Zählwert für aktuell ausstehende Batches je Tabelle; eine positive Batchsumme ab Schwelle erzeugt WARN. Der gebundene bigint-Wert muss zwischen 0 und 9223372036854775807 liegen; NULL und negative Werte sind ungültig. 0 weist jede Tabelle mit mindestens einem offenen Batch aus. Die Momentaufnahme beweist keine Blockierung und ändert keine Population. Bei ausgelassenem Argument gilt der angegebene Default.

**@FailedDocumentWarn:** @FailedDocumentWarn bigint=1; Default: 1. Numerischer Zählwert für aktuell gemeldete Dokumentfehler je Tabelle; positive aggregierte Fehler ab Schwelle erzeugen WARN. Der gebundene bigint-Wert muss zwischen 0 und 9223372036854775807 liegen; NULL und negative Werte sind ungültig. 0 weist Tabellen nur dann aus, wenn die Fehlerzahl positiv ist. Gelesen werden aggregierte Zahlen, keine Dokumentinhalte oder Schlüsselwerte. Bei ausgelassenem Argument gilt der angegebene Default.

**@CatalogSizeWarnMb:** @CatalogSizeWarnMb decimal(19,2)=10240; Default: 10240. Numerischer Größenwert in MB für querybare Fragmente; eine positive aggregierte logische Kataloggröße ab Schwelle erzeugt INFO. Der gebundene decimal(19,2)-Wert liegt zwischen 0.00 und 99999999999999999.99; NULL und negative Werte sind ungültig. SQL Server bindet zuerst auf zwei Nachkommastellen, sodass überzählige Dezimalstellen vor der Prüfung gerundet werden; Werte außerhalb des Typbereichs können bei dieser Typkonvertierung überlaufen. Die Kennzahl ist weder gesamte Speicherbelegung noch Gesundheitsurteil. Bei 0 entsteht der INFO-Hinweis für jede positive aggregierte Kataloggröße; eine Größe von 0 erfüllt die zusätzliche Positivbedingung nicht. Bei ausgelassenem Argument gilt der angegebene Default.

**@MaxZeilen:** @MaxZeilen int=2000; Default: 2000. Begrenzt Detailarrays und Fachdaten-Resultsets, nicht meta, databaseStatus, sourceStatus oder zuvor gelesene/gezählte Quellzeilen. Positive Werte setzen die Obergrenze; Findings werden nach WARN vor INFO und dann FindingOrdinal ausgewählt. NULL oder 0 bedeutet unbegrenzt, negative Werte sind INVALID_PARAMETER; positive Werte liegen im int-Bereich bis 2147483647. Bei @NurProblematisch wird zuerst nach der jeweiligen Problemregel gefiltert. Zähler bleiben vor der Ausgabegrenze berechnet. Bei ausgelassenem Argument gilt der angegebene Default.

**@LockTimeoutMs:** @LockTimeoutMs int=0; Default: 0. Numerischer Millisekundenwert für Lock-Timeouts dynamischer fachlicher Leseabfragen je Datenbank. Zulässig sind gebundene int-Werte von 0 bis 60000 einschließlich; NULL und Werte außerhalb dieses Bereichs sind ungültig. 0 bedeutet sofortiger Lock-Timeout. Lokale Temp-DDL und Quellzugriffe haben ihre eigene Lockingbehandlung; der Wert ändert keine Daten. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultSetArt:** @ResultSetArt varchar(16)='CONSOLE'; Default: 'CONSOLE'. Wählt nach Trim und Großschreibung genau CONSOLE, RAW, TABLE oder NONE; NULL/Leerstring wird ungültig. CONSOLE liefert eine beschriftete Findingsansicht samt Leerzeile; RAW liefert in dieser Reihenfolge elf Resultsets: Header, DatabaseStatus, SourceStatus, FindingsExport, Catalog, FullTextIndex, Population, BatchGroup, SemanticPopulation, MemoryPool und FdHost. TABLE schreibt nur findings; NONE unterdrückt Resultsets. @ResultTablesJson ist ausschließlich mit TABLE zulässig. TABLE-Preflight läuft vor HELP und wirft bei ungültiger Zielzuordnung 51011; ein späterer Writerfehler kann 51010 nach OUTPUT-Zuweisung auslösen. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. Enthält im TABLE-Modus ein nichtleeres gültiges JSON-Objekt mit genau der erlaubten Zuordnung findings zu einer lokalen Ziel-Temp-Tabelle. Der Resultsetname findings muss exakt dem erlaubten Namen entsprechen; doppelte JSON-Keys werden binär geprüft, doppelte Ziele case-insensitive. Das Ziel muss mit # beginnen, darf nicht ## sein, höchstens 116 Zeichen lang sein und keinen case-insensitive Präfix #Monitor haben. Die Tabelle muss vorab leer sein und genau eine Seed-Spalte besitzen. Ungültige Schlüssel, Ziele oder Seed-Struktur werfen beim TABLE-Preflight Fehler 51011 vor HELP; ein nichtleerer Wert außerhalb TABLE wirft ebenfalls 51011 vor HELP. NULL/leer außerhalb TABLE ist zulässig. Späterer Schreibfehler kann 51010 nach Zuweisung der Diagnose-OUTPUT-Werte auslösen. Der Zielwert muss eine nichtleere JSON-Zeichenfolge sein; Zahlen, NULL, Arrays oder Objekte als Zielwerte sind ungültig. NULL, leere Zeichenfolge und nur Leerzeichen sind mit TABLE ungültig. Der Writer ersetzt die Seedspalte durch das Findings-Quellschema. Bei einem THROW ist die Zustellung der OUTPUT-Werte nicht zugesichert. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. 0 lässt @Json NULL; 1 erzeugt dort das JSON-Dokument. NULL ist ungültig. SQL Server bindet den Wert zuerst als bit; die Validierung sieht den konvertierten 0/1-Wert oder NULL, nicht den ursprünglichen Ausdruck. Das Dokument enthält meta, databaseStatus, sourceStatus, findings, catalogs, fullTextIndexes, populations, outstandingBatches, semanticPopulations, memoryPools und fdHosts. Die Findingsauswahl ist dieselbe wie für andere Ausgabearten; Detailarrays werden je @MaxZeilen begrenzt. Bei numerischer SQL-Konvertierung nach bit wird 0 zu 0 und jeder Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. OUTPUT nvarchar(max)-Parameter; an eine nvarchar(max)-Variable mit OUTPUT binden. Die Procedure setzt ihn zu Beginn auf NULL und erzeugt bei @JsonErzeugen=1 ein äußeres JSON-Objekt mit meta als Objekt sowie den zehn Arrays databaseStatus, sourceStatus, findings, catalogs, fullTextIndexes, populations, outstandingBatches, semanticPopulations, memoryPools und fdHosts. meta enthält Modul, Aufnahmezeit, globalen Status, Partialität sowie Fehlernummer und -text. @MaxZeilen begrenzt Detailarrays, nicht meta oder die Statusarrays databaseStatus/sourceStatus; @NurProblematisch verwendet je Array die dokumentierten Detailprädikate. HELP kehrt vor JSON-Erzeugung zurück. Bei einem THROW ist die Zustellung des OUTPUT-Werts nicht zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@PrintMeldungen:** @PrintMeldungen bit=1; Default: 1. 0 unterdrückt, 1 erlaubt die zusätzliche Severity-10-Meldung mit NOWAIT bei globalen Statuscodes außer AVAILABLE und NOT_APPLICABLE. NULL ist ungültig. SQL Server bindet den Wert zuerst als bit; die Validierung sieht den konvertierten 0/1-Wert oder NULL, nicht den ursprünglichen Ausdruck. Die Meldung ersetzt weder Resultsets noch OUTPUT-Diagnosewerte; bei HELP wird sie nicht erreicht. Bei numerischer SQL-Konvertierung nach bit wird 0 zu 0 und jeder Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit=0; Default: 0. 0 setzt die Analyse fort; 1 druckt Hilfe und kehrt ohne Analyse zurück. NULL wird durch den IF-Test wie 0 behandelt. Vor der Verzweigung erfolgen TABLE-Preflight und Prüfung eines nichtleeren unzulässigen @ResultTablesJson; die vier Diagnose-OUTPUT-Werte werden durch den frühen Rücksprung nicht zugewiesen. @Json wurde zu Beginn auf NULL gesetzt. Bei numerischer SQL-Konvertierung nach bit wird 0 zu 0 und jeder Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default.

**@StatusCodeOut:** @StatusCodeOut varchar(40)=NULL OUTPUT; Default: NULL. OUTPUT varchar(40), mit varchar(40)-Variable und OUTPUT binden. Regulärer Abschluss übernimmt den globalen Status. Alle 13 erreichbaren Codes haben eigene Bedeutung: AVAILABLE = vollständige zugängliche Aufnahme ohne WARN; AVAILABLE_LIMITED = mindestens eine Quellen-/Datenbankauswertung fehlt oder ist partiell; AVAILABLE_WITH_FINDING = mindestens ein WARN ohne Partialität; NOT_APPLICABLE = keine auswertbare Datenbank oder kein sichtbarer Katalog und Index; INVALID_PARAMETER = ungültige Parameter, Filterkombination oder Analyseklasse; UNAVAILABLE_FEATURE = Datenbank-Regex-Gate nicht erfüllt, weil SQL Server vor 2025 liegt oder die Installationsdatenbank unter Compatibility Level 170 steht; UNAVAILABLE_VERSION = Schema-/Objekt-Regex auf SQL Server vor 2025; HIGH_IMPACT_CONFIRMATION_REQUIRED = aktivierter CATALOG_DEEP-Pfad verlangt Bestätigung und @HighImpactConfirmed ist 0; DENIED_GROUP = Analysis Policy gibt den Pfad nicht frei; INTERNAL_ERROR = Kandidaten-Temp-Tabelle hat nicht das erwartete Schema; TIMEOUT = Name-Filter-Helfer fängt SQL-Fehler 1222; DENIED_PERMISSION = dieser Helfer fängt 229, 262, 297, 300, 371 oder 916; ERROR_HANDLED = sonstiger dort gefangener Name-Filterfehler. Die Name-Filtercodes TIMEOUT, DENIED_PERMISSION und ERROR_HANDLED werden nach dem Helper nur von IsPartial begleitet und nicht überschrieben; die OUTPUT-Zuweisung übernimmt den Code. Fehler-/Helperstatus bleiben erhalten, weil Kandidaten- und Finalaggregation nur bei Status AVAILABLE laufen. Bei Status AVAILABLE hat anschließend Partialität Vorrang vor WARN-Findings, danach folgt NOT_APPLICABLE bei fehlendem sichtbarem Katalog/Index, sonst AVAILABLE. TABLE-Preflight läuft vor HELP; HELP lässt den gebundenen Wert unverändert. Bei einem THROW ist die Zustellung des OUTPUT-Werts nicht zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@IsPartialOut:** @IsPartialOut bit=NULL OUTPUT; Default: NULL. OUTPUT bit für die globale Partial-/Fehlermarkierung, mit bit-Variable und OUTPUT binden. 0 bedeutet, dass kein früher Fehler und keine fehlende ausgewertete Quelle markiert wurde; 1 kann sowohl bei einer unvollständigen Analyse als auch bei ungültigen Eingaben, Regexversions- oder Auswahl-/Policyfehlern auftreten, auch wenn noch keine verwertbaren Ergebnisse vorliegen. Ein WARN-Finding allein setzt den Wert nicht. HELP lässt die OUTPUT-Variable unverändert. Bei einem THROW ist die Zustellung des OUTPUT-Werts nicht zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@ErrorNumberOut:** @ErrorNumberOut int=NULL OUTPUT; Default: NULL. OUTPUT int; mit int-Variable und OUTPUT binden. Regulärer Abschluss bevorzugt eine bereits gesetzte Nummer, sonst MIN(ErrorNumber) über partielle SourceStatus-Zeilen; NULL bedeutet keine verfügbare Nummer. Nummer und Text werden unabhängig aggregiert und können aus verschiedenen Quellen stammen. HELP lässt den gebundenen Wert unverändert. Bei einem THROW ist die Zustellung des OUTPUT-Werts nicht zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048)=NULL OUTPUT; Default: NULL. OUTPUT nvarchar(2048); mit Variable dieses Typs und OUTPUT binden. Regulärer Abschluss bevorzugt einen bereits gesetzten Text, sonst MIN(ErrorMessage) über partielle SourceStatus-Zeilen; NULL bedeutet kein verfügbarer Text. Text und Fehlernummer werden unabhängig aggregiert. HELP lässt den gebundenen Wert unverändert. Bei einem THROW ist die Zustellung des OUTPUT-Werts nicht zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| findings | 1 | 1 | [FindingOrdinal] bigint IDENTITY(1,1) NOT NULL , [DatabaseName] sysname NULL , [SchemaName] sysname NULL , [ObjectName] sysname NULL , [Severity] varchar(16) NOT NULL , [Confidence] varchar(16) NOT NULL , [FindingCode] varchar(120) NOT NULL , [MetricName] varchar(80) NOT NULL , [MetricValue] decimal(38,4) NULL , [ThresholdValue] decimal(38,4) NULL , [Evidence] nvarchar(1000) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL , [RecommendedNextCheck] nvarchar(1000) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_FullTextAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Keine Tabelleninhalte, Suchbegriffe, Schluesselwerte, Stopwords, Parser-Eingaben, Crawl-Logs, Dateipfade oder DDL. Eine fehlende aktive Population beweist weder Abschluss noch Stillstand; MANUAL/OFF ist zulaessige Konfiguration.

MEDIUM; Kataloge und aggregierte Full-Text-Laufzeitmetadaten.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_FullTextAnalysis
Version      : 1.0.0
Stand        : 2026-07-18
Typ          : Stored Procedure
Zweck        : Die Procedure analysiert sichtbare Full-Text-Kataloge und -Indizes sowie
               aktuelle Populationen, ausstehende Batches, Fragmente,
               semantische Populationen und serverweite Laufzeitkapazitaet.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : SERVERPROPERTY, sys.fulltext_catalogs, sys.fulltext_indexes,
               sys.fulltext_index_columns, sys.fulltext_index_fragments,
               sys.indexes, sys.dm_fts_index_population,
               sys.dm_fts_outstanding_batches,
               sys.dm_fts_semantic_similarity_population,
               sys.dm_fts_memory_pools und sys.dm_fts_fdhosts.
Methodik     : Feature-Gate und jede abhaengige Quelle werden best effort
               ausgewertet. Eine DMV-Momentaufnahme ist keine Historie;
               Grenzwerte erzeugen Pruefhinweise, keine Betriebsentscheidung.
Grenzen      : Keine Tabelleninhalte, Suchbegriffe, Schluesselwerte,
               Stopwords, Parser-Eingaben, Crawl-Logs, Dateipfade oder DDL.
               Eine fehlende aktive Population beweist weder Abschluss noch
               Stillstand; MANUAL/OFF ist zulaessige Konfiguration.
Kosten       : MEDIUM; Kataloge und aggregierte Full-Text-Laufzeitmetadaten.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_FullTextAnalysis
Die Procedure liest sichtbare Full-Text-Kataloge, Full-Text-Indizes und aktuelle aggregierte Population-, Batch-, Fragment- und Serverkapazitätsmetadaten als nicht atomare Momentaufnahme.
Pipe-getrennte exakte Datenbank-, Schema-, Objekt- und qualifizierte Namenslisten verwenden je Namenskomponente höchstens 128 Zeichen und je rohem Listensegment höchstens 4000 Zeichen; Datenbankfilter und Tabellenfilter wirken in ihren jeweiligen Scopes.
Pattern erlauben LIKE ohne Präfix oder mit like:, regex: und regexi:; LIKE ist case-sensitive, Regexflags sind c und i. Regexkompatibilität wird für Datenbank- und Tabellenpattern in unterschiedlichen Datenbankkontexten geprüft.
Die fünf Schwellenwerte erzeugen Populationsalter-, Fragment-, Batch- und Dokumentfehler-WARNs sowie einen Kataloggrößen-INFO-Hinweis; sie sind keine universellen Gesundheitsgrenzen.
Die globale Statusauswahl erfolgt nur solange der aktuelle Code AVAILABLE ist; frühere Fehler-, Policy- und Filtercodes bleiben daher erhalten und können auch ohne Datenresultate ausgegeben werden.
RAW liefert elf Resultsets in fester Reihenfolge; JSON besteht aus einem meta-Objekt und zehn Ergebnisarrays. TABLE-Zielpreflight läuft vor HELP und die Diagnose-OUTPUT-Zuweisung vor dem späteren Tabellen-Writer.
Es werden weder indizierte Tabelleninhalte noch Suchbegriffe, Schlüsselwerte oder Crawl-Logs gelesen; die Procedure ändert keine Daten.
Beispiel 1: EXEC [monitor].[USP_FullTextAnalysis] @Hilfe=1;
Beispiel 2: EXEC [monitor].[USP_FullTextAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @FullObjectNames=N'[ExampleDatabase].[ExampleSchema].[ExampleTable]', @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
Beispiel 3: DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_FullTextAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];
Beispiel 4: CREATE TABLE [#FullTextAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_FullTextAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#FullTextAnalysis_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#FullTextAnalysis_HelpExample]; DROP TABLE IF EXISTS [#FullTextAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#FullTextAnalysis_HelpExample]; THROW; END CATCH;
Beispiel 5: EXEC [monitor].[USP_FullTextAnalysis] @DatabaseNamePattern=N'like:ExampleDatabase%', @SchemaNamePattern=N'like:Example%', @HighImpactConfirmed=1, @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
```

