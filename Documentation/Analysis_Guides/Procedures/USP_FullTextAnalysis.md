# [monitor].[USP_FullTextAnalysis]

**Bereich:** Versionsadaptive Spezialanalysen<br>
**Zweck:** Bewertet sichtbare Full-Text-Kataloge, -Indizes und aggregierte Laufzeitmetadaten ohne indizierte Inhalte, Suchbegriffe, Crawl-Logs, Pfade oder Zustandsänderung.<br>
**Beobachtungsart:** Runtime- und Katalogsnapshot<br>
**Kostenklasse:** MEDIUM_HIGH_OPT_IN (statische Navigator-Einstufung; der SQL-Header klassifiziert Kataloge und aggregierte Full-Text-Laufzeitmetadaten separat als MEDIUM).

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche sichtbaren Full-Text-Kataloge und -Indizes sowie aktuellen aggregierten Populationen, Batches, Fragmente und serverweiten Laufzeitkapazitäten liegen im gewählten Scope vor?** Sie liefert einen nicht atomaren Metadaten-Snapshot und konfigurationsabhängige Prüfhinweise. Das serverweite Feature-Gate, der sichtbare Objektbestand und die Abfragbarkeit einzelner Quellen sind unterschiedliche Evidenzzustände.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Korrektheit der Featurekonfiguration, keine geschützten Inhalte und keine End-to-End-Funktionsprüfung außerhalb sichtbarer Metadaten. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_FullTextAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurProblematisch = 1,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Der Full-Text-Katalogpfad wird als `CATALOG_DEEP` an die Analysis Policy übergeben. Wenn diese Policy ein Gruppengate verlangt, ist `@HighImpactConfirmed = 1` erforderlich; der Schalter erweitert den Scope nicht und erlaubt keinen Zugriff auf indizierte Inhalte. Datenbankfilter wählen den Datenbankscope; Schema-, Objekt- und qualifizierte Namensfilter beschränken Tabellen darin. Das Full-Text-Feature-Gate bezieht sich auf Serverproperty; Memory Pools und FDHosts werden serverweit gelesen.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameterverträge

Jeder Eintrag erklärt den tatsächlichen Parametervertrag einschließlich NULL-Verhalten und der erlaubten Werte.

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | Default: `NULL` | Wählt Datenbanken aus einer pipe-getrennten Liste exakter Namen aus. Elemente werden außen getrimmt; eckige Klammern können Sonderzeichen und ein schließendes ] als ]] maskieren. Jedes rohe Listensegment darf höchstens 4000 UTF-16-Codeeinheiten und jeder Name höchstens 128 Zeichen haben. NULL oder eine nur aus Leerzeichen bestehende Gesamteingabe wird zu keiner expliziten Liste normalisiert; leere Listenelemente sind ungültig. Eine nichtleere wirksame Liste ist mit @DatabaseNamePattern gegenseitig ausgeschlossen und führt zusammen zu INVALID_PARAMETER. Systemdatenbanken bleiben ausgeschlossen, sofern @SystemdatenbankenEinbeziehen nicht 1 ist. Der Abgleich und die Duplikatprüfung sind case-sensitive. Der einteilige Namensprüfer verlangt einen nicht-NULL-Teil 1 und einen NULL-Teil 2; Teile 3 und 4 werden nicht gesondert geprüft. Dies ist keine vollständige SQL-Namensgrammatik oder Existenz-/Rechteprüfung. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@SystemdatenbankenEinbeziehen` | `bit` | Default: `0` | 0 schließt Systemdatenbanken aus; 1 lässt sie im sonst gewählten Datenbankscope zu. NULL ist ungültig. SQL Server bindet den Wert zuerst als bit; die Validierung sieht den konvertierten 0/1-Wert oder NULL, nicht den ursprünglichen Ausdruck. Der Schalter erweitert nicht eigenständig die Datenbankliste und ersetzt weder Filter noch das CATALOG_DEEP-Policygate. Bei numerischer SQL-Konvertierung nach bit wird 0 zu 0 und jeder Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | Default: `NULL` | Wählt Datenbanknamen über kein Präfix oder like: für SQL-LIKE, regex: für Regex mit Flag c (case-sensitive) oder regexi: für Regex mit Flag i (case-insensitive). Präfixe werden ohne Beachtung ihrer Groß-/Kleinschreibung erkannt; der Patternrest wird nicht erneut getrimmt. LIKE vergleicht case-sensitive, verwendet % für beliebig viele Zeichen, _ für genau ein Zeichen und [...] beziehungsweise [^...] für Zeichenklassen beziehungsweise deren Negation und bietet keinen eigenen ESCAPE-Parameter. NULL bedeutet kein Pattern; leerer oder nur aus Leerzeichen bestehender Inhalt ist ungültig. Maximal 4000 Zeichen. Ein wirksamer @DatabaseNames-Listenfilter ist gegenseitig ausgeschlossen. Datenbank-Regex verlangt SQL Server 2025 oder neuer und Compatibility Level 170 der Installationsdatenbank; andernfalls lautet der globale Status UNAVAILABLE_FEATURE. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@HighImpactConfirmed` | `bit` | Default: `0` | Bestätigt das vom Analysis-Policy-Pfad CATALOG_DEEP verlangte Gruppengate. 0 verweigert den Pfad, wenn die Policy die Bestätigung erfordert; 1 bestätigt ihn. NULL ist ungültig. SQL Server bindet den Wert zuerst als bit; die Validierung sieht den konvertierten 0/1-Wert oder NULL, nicht den ursprünglichen Ausdruck. Die Bestätigung erweitert keinen Scope und erlaubt keinen Zugriff auf indizierte Inhalte. Bei numerischer SQL-Konvertierung nach bit wird 0 zu 0 und jeder Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@SchemaNames` | `nvarchar(max)` | Default: `NULL` | Wählt Tabellenschemas über eine Pipe-Liste exakter einteiliger Namen. NULL bedeutet kein Schema-Listenfilter. Pipe trennt nur außerhalb eckiger Klammern; ]] maskiert darin eine schließende Klammer. Äußere Elementleerzeichen werden entfernt. Ein Rohsegment umfasst höchstens 4000 UTF-16-Codeeinheiten, ein geparster Name höchstens 128 Zeichen. Der PARSENAME-basierte Prüfer verlangt Teil 1 und keinen Teil 2; Teile 3 und 4 werden nicht separat geprüft. Dies ist keine vollständige SQL-Namensgrammatik und keine Prüfung von Existenz oder Rechten. Leere Elemente, eine leere oder nur aus Leerzeichen bestehende Gesamtliste, fehlerhafte Klammerung und case-sensitive Duplikate sind ungültig. @SchemaNames ist mit @SchemaNamePattern sowie @FullObjectNames jeweils exklusiv. Eine Schema- und eine Objektliste können zusammen Tabellen einschränken. Der Abgleich verwendet SQL_Latin1_General_CP1_CS_AS und ist case-sensitive; serverweite Memory Pools und FDHosts werden damit nicht eingegrenzt. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@SchemaNamePattern` | `nvarchar(4000)` | Default: `NULL` | Wählt Tabellenschemas über kein Präfix oder like: für SQL-LIKE, regex: für Regex mit Flag c (case-sensitive) oder regexi: für Regex mit Flag i (case-insensitive). Präfixe werden ohne Beachtung ihrer Groß-/Kleinschreibung erkannt; der Patternrest wird nicht erneut getrimmt. LIKE vergleicht case-sensitive, verwendet % für beliebig viele Zeichen, _ für genau ein Zeichen und [...] beziehungsweise [^...] für Zeichenklassen beziehungsweise deren Negation und bietet keinen eigenen ESCAPE-Parameter. NULL bedeutet kein Pattern; leerer oder nur aus Leerzeichen bestehender Inhalt ist ungültig. Maximal 4000 Zeichen. Mit @SchemaNames ungültig. Schema-/Objekt-Regex auf SQL Server unter 2025 ergibt UNAVAILABLE_VERSION; bei Compatibility Level unter 170 in einer Zieldatenbank wird diese DB-Quelle partiell, wodurch global AVAILABLE_LIMITED entstehen kann. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ObjectNames` | `nvarchar(max)` | Default: `NULL` | Wählt Tabellennamen über eine Pipe-Liste exakter einteiliger Namen. NULL bedeutet kein Objekt-Listenfilter. Pipe trennt nur außerhalb eckiger Klammern; ]] maskiert darin eine schließende Klammer. Äußere Elementleerzeichen werden entfernt. Ein Rohsegment umfasst höchstens 4000 UTF-16-Codeeinheiten, ein geparster Name höchstens 128 Zeichen. Der PARSENAME-basierte Prüfer verlangt Teil 1 und keinen Teil 2; Teile 3 und 4 werden nicht separat geprüft. Dies ist keine vollständige SQL-Namensgrammatik und keine Prüfung von Existenz oder Rechten. Leere Elemente, eine leere oder nur aus Leerzeichen bestehende Gesamtliste, fehlerhafte Klammerung und case-sensitive Duplikate sind ungültig. @ObjectNames ist mit @ObjectNamePattern sowie @FullObjectNames jeweils exklusiv. Eine Objekt- und eine Schemaliste können zusammen Tabellen einschränken. Der Abgleich verwendet SQL_Latin1_General_CP1_CS_AS und ist case-sensitive; serverweite Memory Pools und FDHosts werden damit nicht eingegrenzt. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ObjectNamePattern` | `nvarchar(4000)` | Default: `NULL` | Wählt Tabellennamen über kein Präfix oder like: für SQL-LIKE, regex: für Regex mit Flag c (case-sensitive) oder regexi: für Regex mit Flag i (case-insensitive). Präfixe werden ohne Beachtung ihrer Groß-/Kleinschreibung erkannt; der Patternrest wird nicht erneut getrimmt. LIKE vergleicht case-sensitive, verwendet % für beliebig viele Zeichen, _ für genau ein Zeichen und [...] beziehungsweise [^...] für Zeichenklassen beziehungsweise deren Negation und bietet keinen eigenen ESCAPE-Parameter. NULL bedeutet kein Pattern; leerer oder nur aus Leerzeichen bestehender Inhalt ist ungültig. Maximal 4000 Zeichen. Mit @ObjectNames ungültig. Schema-/Objekt-Regex auf SQL Server unter 2025 ergibt UNAVAILABLE_VERSION; bei Compatibility Level unter 170 in einer Zieldatenbank wird diese DB-Quelle partiell, wodurch global AVAILABLE_LIMITED entstehen kann. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@FullObjectNames` | `nvarchar(max)` | Default: `NULL` | Wählt Tabellen über eine Pipe-Liste der Formen Objekt, Schema.Objekt oder Datenbank.Schema.Objekt. Bei drei Teilen ist ein Schema erforderlich; vierteilige Linked-Server-Bezüge sind unzulässig. NULL bedeutet kein Filter; eine leere oder nur aus Leerzeichen bestehende Liste sowie leere Elemente sind ungültig. Pipe trennt außerhalb von [...]; ]] maskiert darin eine schließende Klammer, äußere Elementleerzeichen werden entfernt. Rohsegmente sind auf 4000 UTF-16-Codeeinheiten und jeder vorhandene Namensbestandteil auf 128 Zeichen begrenzt. PARSENAME prüft die Komponenten, aber keine vollständige SQL-Grammatik, Katalogexistenz oder Rechte. Fehlerhafte Klammerung und case-sensitive Duplikate sind ungültig. @FullObjectNames ist mit @SchemaNames und @ObjectNames jeweils exklusiv; Patternfilter bleiben kombinierbar. Fehlende Datenbank-/Schemaanteile wirken im Abgleich als Wildcard; angegebene Teile werden case-sensitive abgeglichen. Serverweite Memory Pools und FDHosts werden damit nicht eingegrenzt. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@NurProblematisch` | `bit` | Default: `0` | 0 lässt alle Zeilen der Detailarrays zu; 1 beschränkt Findings auf Severity WARN und Katalog-/Indexzeilen auf AssessmentStatus REVIEW. Bei populations gilt AgeMinutes >= @PopulationAgeWarnMinutes oder Status = 11; bei outstandingBatches gilt BatchErrorCode ungleich 0 oder IsRetryBatch = 1 oder FailedDocumentCount >= @FailedDocumentWarn; bei semanticPopulations gilt AgeMinutes >= @PopulationAgeWarnMinutes. Memory Pools und FDHosts haben kein @NurProblematisch-Prädikat. NULL ist ungültig; SQL Server bindet den Eingang vorab als bit, sodass die Validierung nur den konvertierten Wert sieht. Quellen werden vorher gelesen und aggregiert; der Schalter begrenzt keine Quellarbeit oder Zähler. Bei numerischer SQL-Konvertierung nach bit wird 0 zu 0 und jeder Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@PopulationAgeWarnMinutes` | `bigint` | Default: `60` | Numerischer Minutenwert für die Schwelle des Alters aktuell sichtbarer normaler und semantischer Populationen. Erreicht AgeMinutes den Wert, entsteht ein WARN. Der gebundene bigint-Wert muss zwischen 0 und 9223372036854775807 liegen; NULL und negative Werte sind ungültig. 0 vergleicht jedes nichtnegative Alter. DATEDIFF_BIG berechnet Minuten bis zur UTC-Aufnahme; ein Zukunftszeitstempel kann negatives Alter ergeben. Die DMVs zeigen laufende Vorgänge, keine Historie. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@QueryableFragmentWarn` | `bigint` | Default: `30` | Numerischer Zählwert für die Mindestzahl querybarer Fragmente je Index, ab der WARN entsteht. Es zählen Fragmente mit Status 4 oder 6; die Anzahl muss zusätzlich positiv sein. Der gebundene bigint-Wert muss zwischen 0 und 9223372036854775807 liegen; NULL und negative Werte sind ungültig. 0 weist jeden Index mit mindestens einem solchen Fragment aus. Es gibt keinen universellen Microsoft-Grenzwert und die Procedure reorganisiert nicht. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@OutstandingBatchWarn` | `bigint` | Default: `100` | Numerischer Zählwert für aktuell ausstehende Batches je Tabelle; eine positive Batchsumme ab Schwelle erzeugt WARN. Der gebundene bigint-Wert muss zwischen 0 und 9223372036854775807 liegen; NULL und negative Werte sind ungültig. 0 weist jede Tabelle mit mindestens einem offenen Batch aus. Die Momentaufnahme beweist keine Blockierung und ändert keine Population. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@FailedDocumentWarn` | `bigint` | Default: `1` | Numerischer Zählwert für aktuell gemeldete Dokumentfehler je Tabelle; positive aggregierte Fehler ab Schwelle erzeugen WARN. Der gebundene bigint-Wert muss zwischen 0 und 9223372036854775807 liegen; NULL und negative Werte sind ungültig. 0 weist Tabellen nur dann aus, wenn die Fehlerzahl positiv ist. Gelesen werden aggregierte Zahlen, keine Dokumentinhalte oder Schlüsselwerte. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@CatalogSizeWarnMb` | `decimal(19,2)` | Default: `10240` | Numerischer Größenwert in MB für querybare Fragmente; eine positive aggregierte logische Kataloggröße ab Schwelle erzeugt INFO. Der gebundene decimal(19,2)-Wert liegt zwischen 0.00 und 99999999999999999.99; NULL und negative Werte sind ungültig. SQL Server bindet zuerst auf zwei Nachkommastellen, sodass überzählige Dezimalstellen vor der Prüfung gerundet werden; Werte außerhalb des Typbereichs können bei dieser Typkonvertierung überlaufen. Die Kennzahl ist weder gesamte Speicherbelegung noch Gesundheitsurteil. Bei 0 entsteht der INFO-Hinweis für jede positive aggregierte Kataloggröße; eine Größe von 0 erfüllt die zusätzliche Positivbedingung nicht. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MaxZeilen` | `int` | Default: `2000` | Begrenzt Detailarrays und Fachdaten-Resultsets, nicht meta, databaseStatus, sourceStatus oder zuvor gelesene/gezählte Quellzeilen. Positive Werte setzen die Obergrenze; Findings werden nach WARN vor INFO und dann FindingOrdinal ausgewählt. NULL oder 0 bedeutet unbegrenzt, negative Werte sind INVALID_PARAMETER; positive Werte liegen im int-Bereich bis 2147483647. Bei @NurProblematisch wird zuerst nach der jeweiligen Problemregel gefiltert. Zähler bleiben vor der Ausgabegrenze berechnet. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@LockTimeoutMs` | `int` | Default: `0` | Numerischer Millisekundenwert für Lock-Timeouts dynamischer fachlicher Leseabfragen je Datenbank. Zulässig sind gebundene int-Werte von 0 bis 60000 einschließlich; NULL und Werte außerhalb dieses Bereichs sind ungültig. 0 bedeutet sofortiger Lock-Timeout. Lokale Temp-DDL und Quellzugriffe haben ihre eigene Lockingbehandlung; der Wert ändert keine Daten. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultSetArt` | `varchar(16)` | Default: `'CONSOLE'` | Wählt nach Trim und Großschreibung genau CONSOLE, RAW, TABLE oder NONE; NULL/Leerstring wird ungültig. CONSOLE liefert eine beschriftete Findingsansicht samt Leerzeile; RAW liefert in dieser Reihenfolge elf Resultsets: Header, DatabaseStatus, SourceStatus, FindingsExport, Catalog, FullTextIndex, Population, BatchGroup, SemanticPopulation, MemoryPool und FdHost. TABLE schreibt nur findings; NONE unterdrückt Resultsets. @ResultTablesJson ist ausschließlich mit TABLE zulässig. TABLE-Preflight läuft vor HELP und wirft bei ungültiger Zielzuordnung 51011; ein späterer Writerfehler kann 51010 nach OUTPUT-Zuweisung auslösen. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultTablesJson` | `nvarchar(max)` | Default: `NULL` | Enthält im TABLE-Modus ein nichtleeres gültiges JSON-Objekt mit genau der erlaubten Zuordnung findings zu einer lokalen Ziel-Temp-Tabelle. Der Resultsetname findings muss exakt dem erlaubten Namen entsprechen; doppelte JSON-Keys werden binär geprüft, doppelte Ziele case-insensitive. Das Ziel muss mit # beginnen, darf nicht ## sein, höchstens 116 Zeichen lang sein und keinen case-insensitive Präfix #Monitor haben. Die Tabelle muss vorab leer sein und genau eine Seed-Spalte besitzen. Ungültige Schlüssel, Ziele oder Seed-Struktur werfen beim TABLE-Preflight Fehler 51011 vor HELP; ein nichtleerer Wert außerhalb TABLE wirft ebenfalls 51011 vor HELP. NULL/leer außerhalb TABLE ist zulässig. Späterer Schreibfehler kann 51010 nach Zuweisung der Diagnose-OUTPUT-Werte auslösen. Der Zielwert muss eine nichtleere JSON-Zeichenfolge sein; Zahlen, NULL, Arrays oder Objekte als Zielwerte sind ungültig. NULL, leere Zeichenfolge und nur Leerzeichen sind mit TABLE ungültig. Der Writer ersetzt die Seedspalte durch das Findings-Quellschema. Bei einem THROW ist die Zustellung der OUTPUT-Werte nicht zugesichert. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@JsonErzeugen` | `bit` | Default: `0` | 0 lässt @Json NULL; 1 erzeugt dort das JSON-Dokument. NULL ist ungültig. SQL Server bindet den Wert zuerst als bit; die Validierung sieht den konvertierten 0/1-Wert oder NULL, nicht den ursprünglichen Ausdruck. Das Dokument enthält meta, databaseStatus, sourceStatus, findings, catalogs, fullTextIndexes, populations, outstandingBatches, semanticPopulations, memoryPools und fdHosts. Die Findingsauswahl ist dieselbe wie für andere Ausgabearten; Detailarrays werden je @MaxZeilen begrenzt. Bei numerischer SQL-Konvertierung nach bit wird 0 zu 0 und jeder Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Json` | `nvarchar(max) OUTPUT` | Default: `NULL` | OUTPUT nvarchar(max)-Parameter; an eine nvarchar(max)-Variable mit OUTPUT binden. Die Procedure setzt ihn zu Beginn auf NULL und erzeugt bei @JsonErzeugen=1 ein äußeres JSON-Objekt mit meta als Objekt sowie den zehn Arrays databaseStatus, sourceStatus, findings, catalogs, fullTextIndexes, populations, outstandingBatches, semanticPopulations, memoryPools und fdHosts. meta enthält Modul, Aufnahmezeit, globalen Status, Partialität sowie Fehlernummer und -text. @MaxZeilen begrenzt Detailarrays, nicht meta oder die Statusarrays databaseStatus/sourceStatus; @NurProblematisch verwendet je Array die dokumentierten Detailprädikate. HELP kehrt vor JSON-Erzeugung zurück. Bei einem THROW ist die Zustellung des OUTPUT-Werts nicht zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@PrintMeldungen` | `bit` | Default: `1` | 0 unterdrückt, 1 erlaubt die zusätzliche Severity-10-Meldung mit NOWAIT bei globalen Statuscodes außer AVAILABLE und NOT_APPLICABLE. NULL ist ungültig. SQL Server bindet den Wert zuerst als bit; die Validierung sieht den konvertierten 0/1-Wert oder NULL, nicht den ursprünglichen Ausdruck. Die Meldung ersetzt weder Resultsets noch OUTPUT-Diagnosewerte; bei HELP wird sie nicht erreicht. Bei numerischer SQL-Konvertierung nach bit wird 0 zu 0 und jeder Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Hilfe` | `bit` | Default: `0` | 0 setzt die Analyse fort; 1 druckt Hilfe und kehrt ohne Analyse zurück. NULL wird durch den IF-Test wie 0 behandelt. Vor der Verzweigung erfolgen TABLE-Preflight und Prüfung eines nichtleeren unzulässigen @ResultTablesJson; die vier Diagnose-OUTPUT-Werte werden durch den frühen Rücksprung nicht zugewiesen. @Json wurde zu Beginn auf NULL gesetzt. Bei numerischer SQL-Konvertierung nach bit wird 0 zu 0 und jeder Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | Default: `NULL` | OUTPUT varchar(40), mit varchar(40)-Variable und OUTPUT binden. Regulärer Abschluss übernimmt den globalen Status. Alle 13 erreichbaren Codes haben eigene Bedeutung: AVAILABLE = vollständige zugängliche Aufnahme ohne WARN; AVAILABLE_LIMITED = mindestens eine Quellen-/Datenbankauswertung fehlt oder ist partiell; AVAILABLE_WITH_FINDING = mindestens ein WARN ohne Partialität; NOT_APPLICABLE = keine auswertbare Datenbank oder kein sichtbarer Katalog und Index; INVALID_PARAMETER = ungültige Parameter, Filterkombination oder Analyseklasse; UNAVAILABLE_FEATURE = Datenbank-Regex-Gate nicht erfüllt, weil SQL Server vor 2025 liegt oder die Installationsdatenbank unter Compatibility Level 170 steht; UNAVAILABLE_VERSION = Schema-/Objekt-Regex auf SQL Server vor 2025; HIGH_IMPACT_CONFIRMATION_REQUIRED = aktivierter CATALOG_DEEP-Pfad verlangt Bestätigung und @HighImpactConfirmed ist 0; DENIED_GROUP = Analysis Policy gibt den Pfad nicht frei; INTERNAL_ERROR = Kandidaten-Temp-Tabelle hat nicht das erwartete Schema; TIMEOUT = Name-Filter-Helfer fängt SQL-Fehler 1222; DENIED_PERMISSION = dieser Helfer fängt 229, 262, 297, 300, 371 oder 916; ERROR_HANDLED = sonstiger dort gefangener Name-Filterfehler. Die Name-Filtercodes TIMEOUT, DENIED_PERMISSION und ERROR_HANDLED werden nach dem Helper nur von IsPartial begleitet und nicht überschrieben; die OUTPUT-Zuweisung übernimmt den Code. Fehler-/Helperstatus bleiben erhalten, weil Kandidaten- und Finalaggregation nur bei Status AVAILABLE laufen. Bei Status AVAILABLE hat anschließend Partialität Vorrang vor WARN-Findings, danach folgt NOT_APPLICABLE bei fehlendem sichtbarem Katalog/Index, sonst AVAILABLE. TABLE-Preflight läuft vor HELP; HELP lässt den gebundenen Wert unverändert. Bei einem THROW ist die Zustellung des OUTPUT-Werts nicht zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@IsPartialOut` | `bit OUTPUT` | Default: `NULL` | OUTPUT bit für die globale Partial-/Fehlermarkierung, mit bit-Variable und OUTPUT binden. 0 bedeutet, dass kein früher Fehler und keine fehlende ausgewertete Quelle markiert wurde; 1 kann sowohl bei einer unvollständigen Analyse als auch bei ungültigen Eingaben, Regexversions- oder Auswahl-/Policyfehlern auftreten, auch wenn noch keine verwertbaren Ergebnisse vorliegen. Ein WARN-Finding allein setzt den Wert nicht. HELP lässt die OUTPUT-Variable unverändert. Bei einem THROW ist die Zustellung des OUTPUT-Werts nicht zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@ErrorNumberOut` | `int OUTPUT` | Default: `NULL` | OUTPUT int; mit int-Variable und OUTPUT binden. Regulärer Abschluss bevorzugt eine bereits gesetzte Nummer, sonst MIN(ErrorNumber) über partielle SourceStatus-Zeilen; NULL bedeutet keine verfügbare Nummer. Nummer und Text werden unabhängig aggregiert und können aus verschiedenen Quellen stammen. HELP lässt den gebundenen Wert unverändert. Bei einem THROW ist die Zustellung des OUTPUT-Werts nicht zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | Default: `NULL` | OUTPUT nvarchar(2048); mit Variable dieses Typs und OUTPUT binden. Regulärer Abschluss bevorzugt einen bereits gesetzten Text, sonst MIN(ErrorMessage) über partielle SourceStatus-Zeilen; NULL bedeutet kein verfügbarer Text. Text und Fehlernummer werden unabhängig aggregiert. HELP lässt den gebundenen Wert unverändert. Bei einem THROW ist die Zustellung des OUTPUT-Werts nicht zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |

## Aufrufbeispiele zu den Parameterverträgen

Die Beispiele verwenden synthetische Namen, die durch einen ausdrücklich freigegebenen Scope ersetzt werden müssen. Die Analyseaufrufe bestätigen CATALOG_DEEP ausdrücklich; Gruppenfreigabe, Full-Text-Verfügbarkeit und Quellenberechtigungen werden weiterhin geprüft. Das TABLE-Beispiel erstellt ein leeres Ziel mit einer Seedspalte und entfernt es auch im Fehlerfall.

```sql
EXEC [monitor].[USP_FullTextAnalysis] @Hilfe=1;

EXEC [monitor].[USP_FullTextAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @FullObjectNames=N'[ExampleDatabase].[ExampleSchema].[ExampleTable]', @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;

DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_FullTextAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];

CREATE TABLE [#FullTextAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_FullTextAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#FullTextAnalysis_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#FullTextAnalysis_HelpExample]; DROP TABLE IF EXISTS [#FullTextAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#FullTextAnalysis_HelpExample]; THROW; END CATCH;

EXEC [monitor].[USP_FullTextAnalysis] @DatabaseNamePattern=N'like:ExampleDatabase%', @SchemaNamePattern=N'like:Example%', @HighImpactConfirmed=1, @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `findings`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

RAW, CONSOLE, TABLE und das JSON-Array `findings` verwenden dieselbe materialisierte Findings-Auswahl. `@NurProblematisch = 1` beschränkt diese Auswahl auf `Severity = WARN`; ein positives `@MaxZeilen` begrenzt sie nach Warnpriorität und `FindingOrdinal`. `NULL` und `0` liefern die Auswahl ohne Zeilenlimit. Negative Werte führen zu `INVALID_PARAMETER`. Der TABLE-Export behält seine 13 Felder; seine zehn Textspalten verwenden explizit `SQL_Latin1_General_CP1_CS_AS`.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem Datenbankstatus, isolierten Quellenstatus, Finding, Katalog, Full-Text-Index, einer aktuell laufenden Population, einer aggregierten Batchgruppe, einer semantischen Population, einem Speicherpool oder einer FDHost-Typgruppe.

## So lesen

Prüfen Sie zuerst `StatusCode`, `IsPartial` und `SourceStatus`. Berücksichtigen Sie danach Index-/Schlüsselindexschalter, Crawl-Kontext, aktuelle Populationen und Batches gemeinsam. Fragmentanzahl und logische Größe sind Heuristik- beziehungsweise Kapazitätskontext; Memory Pools und FDHosts sind serverweit und keiner einzelnen Datenbank exklusiv zurechenbar.

## Warum kann das problematisch sein?

Deaktivierte Indizes, abgebrochene Populationen, Batchfehler oder fehlgeschlagene Dokumente können Suchaktualität und Auffindbarkeit begrenzen. Viele querybare Fragmente können die Abfrageleistung verschlechtern. Ein langer Lauf oder eine große Batchzahl beweist jedoch keinen Stillstand.

## Wann ist es kein Problem?

`MANUAL` oder `OFF` beim Change Tracking kann bewusst gewählt sein. Ein initialer Full Crawl kann durch `NO POPULATION` absichtlich ausstehen. Population-, Batch- und FDHost-DMVs sind Momentaufnahmen; Status 7 kann während eines automatischen Merge auftreten. Es existiert kein universeller Fragment- oder Laufzeitgrenzwert.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Eine Population über dem Altersgrenzwert mit weiter steigendem Fortschritt ist eher ein Kapazitäts- als ein Stillstandsfall. Korrelieren Sie erst bei wiederholt fehlendem Fortschritt zusätzlich Batches, I/O, Log und geschützte Full-Text- und Crawl-Logs in der Laufzeitumgebung. Speichern und übermitteln Sie reale Logdaten oder interne Strukturen nur kontrolliert.

**Ähnlich aussehender Gegenfall:** `MANUAL` oder `OFF` beim Change Tracking kann bewusst gewählt sein. Ein initialer Full Crawl kann durch `NO POPULATION` absichtlich ausstehen. Population-, Batch- und FDHost-DMVs sind Momentaufnahmen; Status 7 kann während eines automatischen Merge auftreten. Es existiert kein universeller Fragment- oder Laufzeitgrenzwert. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Nicht installiert, nicht aktiviert, in der gewählten Datenbank nicht verwendet und nicht abfragbar sind vier verschiedene Zustände.

Für `USP_FullTextAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

Eine leere Population-DMV ist weder Abschlussnachweis noch Historie. Fehlende DMV-Rechte lassen zugängliche Katalog- und Fragmentevidenz gültig; die Procedure kennzeichnet die Lücke über `IsPartial` und `SourceStatus`. `NOT_APPLICABLE_VISIBLE_SCOPE` beweist bei eingeschränkter Metadatensichtbarkeit keine vollständige Abwesenheit.

`DatabaseStatus.FindingCount` und die Quellenzähler werden vor der Findings-Auswahl berechnet und bleiben bei Ausgabegrenzen erhalten. Warnings für ausdrücklich angeforderte, nicht auswertbare Datenbanken behalten ihren Status und ihre Partialität bei der späteren Statusaggregation. Ein solcher Auswahlwarning macht auch einen ansonsten leeren Feature-Scope partiell.

## Eigenlast und Grenzen

Der SQL-Header klassifiziert die Abfrage sichtbarer Kataloge, Fragmente und aggregierter Full-Text-DMVs als MEDIUM. Die statische Navigator-Einstufung bleibt MEDIUM_HIGH_OPT_IN; die Kennzeichnungen stammen aus unterschiedlichen Vertragsstellen. Es werden keine Tabellenzeilen, Keywords, Stopwords, Parser-Eingaben, Schlüsselwerte, Crawl-Logs oder Pfade gelesen und kein ALTER FULLTEXT ausgeführt.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM_HIGH_OPT_IN |
| Standardpfad | Eine `ExampleDatabase`, Problemscope und endliches Limit; Kataloge, Indizes und aktuelle aggregierte Full-Text-Runtimequellen werden einmal gelesen. |
| Teuerster Pfad | Alle sichtbaren Datenbanken ohne Objektfilter und unbegrenzte Ausgabe bei vielen Katalogen, Indizes, Fragmenten, Populationen, Outstanding Batches und semantischen Populationen. |
| Haupttreiber | Zahl gewählter Datenbanken, Full-Text-Kataloge/-Indizes und aktueller Population-, FDHost- und Memory-Pool-Zeilen. Indizierte Dokumente, Suchbegriffe und Crawl-Logs liegen außerhalb des Pfads und skalieren die Abfrage nicht direkt. |
| Skalierung | Quellarbeit wächst mit Full-Text-Objekten, Fragmenten und aktuellen Population-/Batchzeilen. Serverweite Memory-Pool-/FDHost-Quellen bleiben meist klein; Ausgabe und Sortierung wachsen mit allen materialisierten Detailtabellen. |
| Ressourcen | CPU, Katalog-/Full-Text-DMV-I/O, dynamisches SQL je Datenbank und TempDB/Arbeitsspeicher für isolierte Detailtabellen und Findings. Keine indizierten Inhalte oder Crawl-Logs. |
| Begrenzungswirkung | Datenbankfilter begrenzen den Quellenscope; Objektfilter beschränken Indexzuordnung und davon abhängige DMV-Arbeit. Kataloge werden im sichtbaren Datenbankscope gelesen. `@NurProblematisch` und `@MaxZeilen` begrenzen die Ausgabe nach dem Lesen und Aggregieren der Quellen; Findings werden dafür einmal gemeinsam materialisiert. |
| Locking und Nebenwirkungen | Read-only ohne `ALTER FULLTEXT`; Kataloge und flüchtige Runtime-DMVs werden nicht atomar gelesen. Eine laufende Population kann ihren Status zwischen Teilquellen ändern. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `CATALOG_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine bekannte `ExampleDatabase`, Problemscope und möglichst Objektfilter. Erst Quellenstatus, dann Katalog/Index, Populationen und Batches lesen; serverweite Kapazität zuletzt korrelieren. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Runtime- und Katalogsnapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

Der Laufzeitvertrag `Code/Tests/Common/158_FullTextAnalysis_Collation_Runtime_Contract.sql` verwendet eine eigene leere Quelldatenbank mit abweichender Collation und prüft Exporttextcollation, negative Feature-Gates, Auswahlwarnings sowie gültige und ungültige Parameter. Framework- und Source-Compatibility-Level werden getrennt bestätigt. Ohne positive Full-Text-Objekte belegt dieser Vertrag keine nichtleeren Findingsfilter oder Limits und keine gegateten Full-Text-DMV-Pfade.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie sind Full-Text Catalogs/Indexes konfiguriert, und laufen Population/Change Tracking ohne sichtbare Fehler oder Rückstand?

### Technischer Hintergrund

Full-Text Engine tokenisiert sprachabhängig, speichert invertierte Indizes in Catalogs und aktualisiert sie über Full/Incremental/Auto Population. Stoplists, Search Properties und Change Tracking beeinflussen Inhalt. Population DMVs zeigen aktive Crawls/Phasen.

### Datenkette

`sys.dm_fts_fdhosts`, `sys.dm_fts_index_population`, `sys.dm_fts_memory_pools`, `sys.dm_fts_outstanding_batches`, `sys.dm_fts_semantic_similarity_population`, `sys.fulltext_catalogs`, `sys.fulltext_index_columns`, `sys.fulltext_index_fragments`, `sys.fulltext_indexes`, `sys.indexes`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`.

### Source Select

Der Katalogkern verbindet Full-Text-Index, Basistabelle, Schema, Katalog und Key-Index:

```sql
SELECT
      [s].[name] AS [SchemaName]
    , [t].[name] AS [TableName]
    , [fc].[name] AS [FullTextCatalogName]
    , [i].[name] AS [KeyIndexName]
    , [fi].[change_tracking_state_desc]
FROM [sys].[fulltext_indexes] AS [fi] WITH (NOLOCK)
JOIN [sys].[tables] AS [t] WITH (NOLOCK)
  ON [t].[object_id] = [fi].[object_id]
JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
  ON [s].[schema_id] = [t].[schema_id]
LEFT JOIN [sys].[fulltext_catalogs] AS [fc] WITH (NOLOCK)
  ON [fc].[fulltext_catalog_id] = [fi].[fulltext_catalog_id]
LEFT JOIN [sys].[indexes] AS [i] WITH (NOLOCK)
  ON [i].[object_id] = [fi].[object_id]
 AND [i].[index_id] = [fi].[unique_index_id]
WHERE [s].[name] = N'ExampleSchema'
  AND [t].[name] = N'ExampleObject';
```

**Wichtig für die Eigenlast:** Setzen Sie Objektfilter vor Fragment- und Population-DMVs. Berücksichtigen Sie `sys.fulltext_index_fragments` und Outstanding-/Population-Details erst für verbleibende Full-Text-Indizes.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Metadaten- und Populationzustand sowie die begrenzte Crawl- und Errorhistorie.

### Bewertung und Gegenprobe

Korrelieren Sie Catalog/Index, Change Tracking State, Population Type/Status, Start/End, Items processed/failed, Fragmentcount, Language/Stoplist und Base-Table-Änderung. Querybedarf bestimmt Dringlichkeit.

### Typische Fehlinterpretation

`IDLE` kann erfolgreich fertig oder nie gestartet bedeuten. Ein vorhandener Full-Text-Index garantiert keine aktuelle Vollständigkeit oder semantisch passende Wordbreaker.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Full-Text Crawl Logs/Errorlog, Job/Populationstart und konkrete CONTAINS-Query.

## Primärquellen

- [Full-Text Search](https://learn.microsoft.com/en-us/sql/relational-databases/search/full-text-search?view=sql-server-ver17)

[Technische Detailbeschreibung](../09_Version_Adaptive.md#6-monitorusp_fulltextanalysis)
