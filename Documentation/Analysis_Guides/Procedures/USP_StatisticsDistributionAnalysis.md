# [monitor].[USP_StatisticsDistributionAnalysis]

**Bereich:** Object und Index<br>
**Zweck:** Analysiert ausgewählte Histogramme auf Skew, dominante Schritte, Tail und Partitionsabweichungen.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Datenverteilung bildet das Histogramm ab, und wo können Skew, dominante Werte oder grobe Rangeannahmen Schätzungen erschweren?** Sie unterstützt die Entscheidung, ob ein Struktur- oder Metadatensignal eine workloadbezogene Gegenprüfung rechtfertigt, nicht ob automatisch DDL ausgeführt werden soll.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen Geschäftsnutzen einer Strukturänderung, keine repräsentative Workload und keine automatische Aussage über den optimalen Index- oder Statistikzustand. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_StatisticsDistributionAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @FullObjectNames = N'[ExampleSchema].[ExampleObject]',
      @AnalyseModus = 'GEZIELT',
      @MaxVerteilungsStatistiken = 10,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Beide Modi prüfen die Analyseklasse `CATALOG_DEEP`; eine erforderliche Gruppenfreigabe und die Bestätigung werden unabhängig vom Modus geprüft. `GEZIELT` verlangt einen Objekt-, Schema- oder Statistikfilter. Die Bestätigung ersetzt weder diesen Scope noch die Kandidatengrenze.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Ein einzelner Datenbankname oder eine bracket-aware Pipe-Liste einteiliger SQL-Namen. NULL oder eine nach äußerem Trimmen leere Eingabe bedeutet keine explizite Auswahl; der Kandidatenhelfer wählt alle zulässigen sichtbaren Online-Benutzerdatenbanken, soweit kein Pattern einschränkt. Pipe trennt nur außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt. Leere Elemente, ungültige SQL-Namen, case-sensitive Duplikate und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Eine nichtleere Liste ist mit einem nicht-NULL-Datenbankpattern exklusiv. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | Bit-Schalter: 0 schließt master, model, msdb und tempdb aus; 1 erlaubt deren Aufnahme, soweit sichtbar und online. NULL ist im Datenbankkandidatenhelfer ungültig. Beim Binden zu bit konvertierbare numerische Nichtnullwerte werden zu 0 oder 1 konvertiert. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Datenbanknamen-Pattern. NULL deaktiviert es; leer oder nach Präfixentfernung leer ist ungültig. Äußere Leerzeichen werden getrimmt; die Präfixe like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt, ohne Präfix gilt LIKE; danach wird nicht erneut getrimmt. LIKE verwendet %, _ und [...] mit case-sensitiver Framework-Collation. regex: verwendet Flag c, regexi: Flag i. Für Datenbanknamen prüft der Kandidatenhelfer Regex-Unterstützung im Installationsdatenbankkontext; erforderlich sind SQL Server 2025 und Compatibility Level 170. Nicht mit einer nichtleeren @DatabaseNames-Liste kombinieren. |
| `@HighImpactConfirmed` | `bit` | `0` | SQL-bit-Bestätigung mit 0 oder 1; 0 bleibt 0, von 0 verschiedene konvertierbare Zahlenwerte werden 1. In beiden Modi wird nach der eigenen Validierung CATALOG_DEEP geprüft: 0 führt im erreichbaren Gate zu HIGH_IMPACT_CONFIRMATION_REQUIRED, NULL zu INVALID_PARAMETER, 1 erfüllt die Bestätigung. Danach wird die aktuelle Gruppen-/Tokenberechtigung getrennt geprüft; 1 verleiht weder Rolle noch SQL-Rechte, ohne Freigabe folgt DENIED_GROUP. Bei erfolgreichem Gate wird derselbe Wert an USP_Statistics weitergereicht. |
| `@SchemaNames` | `nvarchar(max)` | `NULL` | Exakte einteilige Schemanamen als bracket-aware Pipe-Liste. NULL bedeutet kein exakter Filter; eine leere oder nur aus Leerzeichen bestehende Nicht-NULL-Liste ist ungültig. Pipe trennt außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt, als einteilige SQL-Namen mit höchstens 128 Zeichen validiert und case-sensitive verglichen. Doppelte Werte derselben Namensart und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Nicht mit @SchemaNamePattern kombinieren; bei nicht-NULL @FullObjectNames ist diese Kombination ebenfalls ungültig. |
| `@SchemaNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Pattern für Schemanamen. NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere Leerzeichen werden vor der Erkennung eines Präfixes like:, regex: oder regexi: entfernt; danach bleibt das Pattern unverändert. Ohne Präfix und mit like: gilt case-sensitives SQL-LIKE mit %, _ und [...]; regex: nutzt Flag c, regexi: Flag i. Feldregex wird inline in der jeweiligen Quelldatenbank ausgeführt; dafür gibt es keine eigene Versionsvorprüfung, sodass fehlende Unterstützung als datenbankweise isolierter Fehler auftreten kann. Nicht mit nicht-NULL @SchemaNames kombinieren. |
| `@ObjectNames` | `nvarchar(max)` | `NULL` | Exakte einteilige Objektnamen als bracket-aware Pipe-Liste. NULL bedeutet kein exakter Filter; eine leere Nicht-NULL-Liste ist ungültig. Pipe trennt außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt, mit höchstens 128 Zeichen geprüft und case-sensitive verglichen. Doppelte Objektnamen und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Nicht mit @ObjectNamePattern kombinieren; bei nicht-NULL @FullObjectNames ist diese Kombination ebenfalls ungültig. |
| `@ObjectNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Objektnamen-Pattern. NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere Leerzeichen werden vor dem Erkennen von like:, regex: oder regexi: entfernt; danach wird nicht erneut getrimmt. Ohne Präfix/like: gilt case-sensitives LIKE mit %, _ und [...]; regex: nutzt Flag c, regexi: Flag i. Feldregex läuft inline je Quelldatenbank ohne eigene Versionsvorprüfung; fehlende Unterstützung kann als isolierter Datenbankfehler erscheinen. Nicht mit nicht-NULL @ObjectNames kombinieren. |
| `@FullObjectNames` | `nvarchar(max)` | `NULL` | Bracket-aware Pipe-Liste vollständiger Objektbezüge mit 1 bis 3 Teilen: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt. Bei einem Datenbankteil ist das Schema erforderlich; vierteilige Linked-Server-Bezüge sind unzulässig. Pipe trennt außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt und nach PARSENAME/sysname-Grenzen geprüft. NULL bedeutet kein Filter; ein leerer nvarchar-String ist EMPTY_LIST, Leerzeichen ergibt ein ungültiges Element. Bestandteile werden case-sensitive verglichen; nicht angegebene Datenbank-/Schemanamen bleiben offen. Duplikate und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Nicht mit nicht-NULL @SchemaNames oder @ObjectNames kombinieren. |
| `@StatisticsNames` | `nvarchar(max)` | `NULL` | Exakte einteilige Statistiknamen als bracket-aware Pipe-Liste. NULL bedeutet kein exakter Filter; eine leere Nicht-NULL-Liste ist ungültig. Pipe trennt außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt, als einteilige SQL-Namen bis 128 Zeichen validiert und case-sensitive verglichen. Duplikate sowie Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Nicht mit nicht-NULL @StatisticsNamePattern kombinieren. |
| `@StatisticsNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Statistiknamen-Pattern. NULL deaktiviert den Filter; leere Eingabe oder leeres Präfix ist ungültig. Äußere Leerzeichen werden vor Erkennung von like:, regex: oder regexi: getrimmt; der Rest wird nicht erneut getrimmt. Ohne Präfix/like: gilt case-sensitives LIKE mit %, _ und [...]; regex: nutzt Flag c, regexi: Flag i. Regex wird im jeweiligen Quelldatenbankbatch ausgewertet und hat keine separate Versionsvorprüfung; Fehler können pro Datenbank isoliert werden. Nicht mit nicht-NULL @StatisticsNames kombinieren. Ein Statistikpattern allein erfüllt den GEZIELT-Filter von USP_Statistics nicht; ein zusätzlicher Schema-/Objektfilter ist erforderlich. Das gilt auch beim weitergereichten Aufruf aus der Verteilungsanalyse. |
| `@AnalyseModus` | `varchar(16)` | `'GEZIELT'` | Text wird getrimmt und ohne Beachtung der Großschreibung normalisiert. Zulässig sind ausschließlich GEZIELT und VOLL; NULL wird als GEZIELT behandelt. Bei USP_Statistics verlangt GEZIELT mindestens eine exakte Schema-/Objekt-/Statistikliste, @FullObjectNames oder ein Schema-/Objektpattern; nur eine Datenbank genügt nicht. VOLL prüft CATALOG_DEEP. Die Verteilungsanalyse prüft CATALOG_DEEP unabhängig vom Modus; GEZIELT verlangt dort einen Objekt-, Schema- oder Statistikfilter. Ein gültiger Scope bleibt erforderlich. |
| `@MaxVerteilungsStatistiken` | `int` | `50` | Anzahl der vor dem Histogrammzugriff ausgewählten Statistiken je Datenbank; zulässig sind ganze Zahlen von 1 bis 250 einschließlich. NULL und Werte außerhalb des Bereichs sind ungültig. Die Auswahlgrenze begrenzt Kandidaten vor dem Histogrammzugriff; die interne Vorpoolgröße beträgt höchstens 1000 (vierfach, maximal). Sie ist kein globales Datenbanklimit. |
| `@MinVerteilungsZeilen` | `bigint` | `1000` | Nichtnegative Kontext-/Findingschwelle von 0 bis 9223372036854775807 Zeilen; NULL oder negative Werte sind INVALID_PARAMETER. Dominanz-, Skew- und Tail-Findings verwenden HistogramEstimatedRows, der Änderungshinweis verwendet Rows bei vorhandenem Histogramm und der Partitionsvergleich TotalRows. Ein kleiner Histogrammkontext wird als SMALL_HISTOGRAM_CONTEXT gekennzeichnet. Histogrammabruf und Distribution-Zeilen werden nicht unterdrückt; fehlende Histogrammsichtbarkeit bleibt eine unabhängige Meldung. Die Schwelle begrenzt weder Kandidaten noch Histogrammsteps. |
| `@SkewWarnFaktor` | `decimal(19,4)` | `10` | decimal(19,4)-Mindestfaktor; bei der Parameterbindung wird auf vier Nachkommastellen konvertiert. für Skew- und Tail-Hinweise, zulässig von 1 bis 100000 einschließlich. NULL oder Werte außerhalb des Bereichs sind ungültig. Er wird mit EqualRowsSkewRatio, AverageRangeRowsSkewRatio und TailVsAverageStepRatio verglichen; höhere Schwellen erzeugen weniger entsprechende Findings. |
| `@DominanterSchrittWarnPercent` | `decimal(9,4)` | `50` | decimal(9,4)-Grenzwert; bei der Parameterbindung wird auf vier Nachkommastellen konvertiert. für den Anteil des dominanten Histogrammschritts, 0 bis 100 einschließlich. NULL oder Werte außerhalb dieses Bereichs sind ungültig. Er steuert den Hinweis auf einen dominanten Schritt, sofern die Mindestzeilenzahl erfüllt ist. |
| `@ModificationWarnPercent` | `decimal(9,4)` | `20` | decimal(9,4)-Grenzwert; bei der Parameterbindung wird auf vier Nachkommastellen konvertiert. für ModificationPercent, 0 bis 100 einschließlich. NULL oder Werte außerhalb dieses Bereichs sind ungültig. Der Hinweis wird nur bei Histogrammsteps &gt; 0 und Rows mindestens @MinVerteilungsZeilen erzeugt; er belegt keine Wertverteilung außerhalb des Histogramms. |
| `@PartitionSpreadWarnPercent` | `decimal(9,4)` | `20` | decimal(9,4)-Grenzwert; bei der Parameterbindung wird auf vier Nachkommastellen konvertiert. für die Streuung der Änderungsanteile inkrementeller Statistikpartitionen, 0 bis 100 einschließlich. NULL oder Werte außerhalb dieses Bereichs sind ungültig. Ein Finding entsteht, wenn TotalRows mindestens @MinVerteilungsZeilen und ModificationSpreadPercentPoints mindestens diesen Wert erreicht. |
| `@MaxZeilen` | `int` | `1000` | Nichtnegative int-Obergrenze von 0 bis 2147483647 für fertige Findings sowie Distribution- und PartitionVariation-Zeilen in RAW/JSON/CONSOLE. NULL oder 0 bedeutet unbegrenzt; negative Werte sind ungültig. Findings werden nach Severity (HIGH, MEDIUM, LOW, danach weitere) und FindingOrdinal ausgewählt. Datenbankstatus und vollständige Zähler bleiben unbegrenzt; die Grenze beschränkt keine Kandidaten oder Histogrammsteps. |
| `@LockTimeoutMs` | `int` | `0` | Ganzzahlige Metadatenlock-Wartezeit in Millisekunden von 0 bis 60000 einschließlich; 0 wartet nicht. Werte außerhalb des Bereichs sind ungültig. Der Wert wird an USP_Statistics für deren dynamische Datenbankbatches weitergereicht. Die Verteilungsprocedure setzt ihr eigenes LOCK_TIMEOUT im Prozedurscope auf 0; SET-Werte aus Procedure-/dynamischem Batchscope werden bei Rückkehr zurückgenommen. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Wird getrimmt und ohne Beachtung der Großschreibung normalisiert. Zulässig sind CONSOLE, RAW, TABLE und NONE. RAW gibt Meta-/Datenbankstatus, Verteilung, Partitionsvariation und Findings aus; CONSOLE liefert beschriftete Fassungen; TABLE schreibt ausschließlich findings nach Preflight in das typisierte lokale Ziel; NONE unterdrückt Resultsets. NULL/leer ist ungültig. Nichtleeres @ResultTablesJson ist nur mit TABLE erlaubt. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | JSON-Zielzuordnung für TABLE. Bei TABLE muss die Zuordnung findings auf eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte abbilden; Preflightfehler treten vor der Analyse als Fehler auf. Bei anderen Ausgabearten ist nur NULL/leer zulässig. Das TABLE-Ergebnis enthält die begrenzte Findingsmenge. |
| `@JsonErzeugen` | `bit` | `0` | Bit-Schalter: 0 lässt @Json nach anfänglicher NULL-Zuweisung NULL; 1 erzeugt JSON mit meta, databaseStatus, distribution, partitionVariation und findings. NULL wird nicht als ungültig abgefangen und aktiviert die IF-Bedingung nicht. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Parameter vom Typ nvarchar(max); optional an eine nvarchar(max)-OUTPUT-Variable zu binden. Wird beim Eintritt auf NULL gesetzt. Bei @JsonErzeugen=1 erhält er das JSON-Objekt mit meta, databaseStatus, distribution, partitionVariation und findings; andernfalls bleibt er NULL. Meta enthält resultName, schemaVersion=1, generatedAtUtc, statusCode, isPartial, maxStatisticsPerDatabase, minimumDistributionRows, distributionCount und findingCount. |
| `@PrintMeldungen` | `bit` | `1` | Bit-Schalter für Warnmeldungen mit Severity 10 und NOWAIT. 1 gibt die Meldung aus, wenn Status nicht AVAILABLE, AVAILABLE_WITH_FINDING oder NOT_APPLICABLE ist; 0 unterdrückt sie. NULL aktiviert die IF-Bedingung nicht. Resultsets, JSON und OUTPUT-Status bleiben davon getrennt. |
| `@Hilfe` | `bit` | `0` | Bit-Schalter; 1 druckt die eingebaute PRINT-Hilfe und kehrt vor Validierung und Analyse zurück, 0 führt den Ablauf aus. NULL wird nicht als Hilfe behandelt. Die TABLE-Zuordnungsprüfung findet vor dem Hilfezweig statt; @ResultTablesJson darf daher auch bei Hilfe nicht als nichtleere Angabe mit einer anderen Ausgabeart kombiniert werden. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | OUTPUT-Status varchar(40), optional an eine varchar(40)-OUTPUT-Variable zu binden. Erhält am Ende den Modulstatus, z. B. AVAILABLE, AVAILABLE_WITH_FINDING, NOT_APPLICABLE, INVALID_PARAMETER, HIGH_IMPACT_CONFIRMATION_REQUIRED, DENIED_GROUP, UNAVAILABLE_FEATURE, AVAILABLE_LIMITED, PARTIAL, SKIPPED, TIMEOUT, DENIED_PERMISSION, ERROR_HANDLED oder einen weitergereichten Kandidaten-/Datenbankstatus. Die Zuweisung erfolgt nach der Analyse; ein früher Hilfe-RETURN überspringt sie. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optionaler bit-OUTPUT-Empfänger; zum Empfang eine Variable mit OUTPUT binden. Am Ende wird das interne Partial-Flag übergeben: es übernimmt den Quellenstatus von USP_Statistics und wird bei den behandelten Fehler-/Verfügbarkeitspfaden gesetzt. Das Kappen durch @MaxVerteilungsStatistiken oder @MaxZeilen setzt das Flag für sich nicht; 0 ist deshalb kein Nachweis einer ungekürzten Kandidaten- oder Ergebnismenge. Hilfe kehrt vor der Zuweisung zurück und lässt den übergebenen Variablenwert unverändert. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | OUTPUT-Fehlernummer int, optional an int-OUTPUT-Variable zu binden. Erhält die im Modulstatus gespeicherte SQL-Fehlernummer oder NULL, wenn kein Fehlercode gesetzt wurde. Die Zuweisung erfolgt am Ende nach der Analyse; bei Hilfe-RETURN wird sie nicht ausgeführt. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | OUTPUT-Fehlertext nvarchar(2048), optional an eine nvarchar(2048)-OUTPUT-Variable zu binden. Erhält die Statusfehlermeldung oder NULL, wenn keine gesetzt ist. Die Zuweisung erfolgt am Ende nach der Analyse; bei Hilfe-RETURN wird sie nicht ausgeführt. |

Alle Example*-Werte sind synthetisch. RAW erhält den Quellenstatus. TABLE-Ziele werden vor TRY neu angelegt und auf beiden Ausgängen entfernt.

```sql
EXEC [monitor].[USP_StatisticsDistributionAnalysis] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @HighImpactConfirmed=1, @MaxVerteilungsStatistiken=10, @MaxZeilen=100, @ResultSetArt='RAW';

DECLARE @ExampleJson nvarchar(max), @ExampleStatus varchar(40), @ExamplePartial bit, @ExampleError int, @ExampleMessage nvarchar(2048);
EXEC [monitor].[USP_StatisticsDistributionAnalysis] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @HighImpactConfirmed=1, @MaxVerteilungsStatistiken=10, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT, @StatusCodeOut=@ExampleStatus OUTPUT, @IsPartialOut=@ExamplePartial OUTPUT, @ErrorNumberOut=@ExampleError OUTPUT, @ErrorMessageOut=@ExampleMessage OUTPUT;
SELECT @ExampleJson AS [ExampleJson], @ExampleStatus AS [StatusCode], @ExamplePartial AS [IsPartial], @ExampleError AS [ErrorNumber], @ExampleMessage AS [ErrorMessage];

CREATE TABLE [#ExampleFindings]([Seed] int NULL);
BEGIN TRY
    EXEC [monitor].[USP_StatisticsDistributionAnalysis] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @HighImpactConfirmed=1, @MaxVerteilungsStatistiken=10, @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#ExampleFindings"}';
END TRY
BEGIN CATCH
    DROP TABLE [#ExampleFindings];
    THROW;
END CATCH;
DROP TABLE [#ExampleFindings];

EXEC [monitor].[USP_StatisticsDistributionAnalysis] @Hilfe=1;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `findings`. TABLE und CONSOLE verwenden dieselbe begrenzte Findingsmenge wie RAW und JSON. RAW und JSON enthalten zusätzlich Modul- und Datenbankstatus sowie Histogramm- und Partitionskennzahlen; JSON besitzt kein separates Warnings-Array. Status und Scope sind vor der Bewertung der Findings zu lesen. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

Die gemeinsame Exportquelle enthält keine Identity-Spalte. `FindingOrdinal` übernimmt die ursprünglichen Werte aus der vollständigen Findingsammlung. RAW und positive CONSOLE melden für dieses Feld deshalb nativ `IsIdentity=False`; TABLE war bereits ohne Identity. Die übrigen Feldmetadaten und SchemaVersion 1 bleiben erhalten.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Statistik, eine Verteilungszusammenfassung, eine Partitionsvariation oder ein normalisiertes Finding.

## So lesen

Berücksichtigen Sie zuerst Sample und Modification, danach Dominant Step, Skew, Tail und Partitionsspread. Bewerten Sie Findings erst mit der zugrunde liegenden Verteilung.

## Warum kann das problematisch sein?

Starke Spitzen oder neue Tailwerte können dazu führen, dass ein Plan für häufige Parameter bei seltenen Parametern ungeeignet ist – oder umgekehrt.

## Wann ist es kein Problem?

Skew kann die reale Datenverteilung korrekt beschreiben und bei geeigneten Plänen völlig unkritisch sein.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Ein Wert umfasst 70 % der Zeilen. Problematisch wird das erst, wenn seltene und häufige Parameter denselben Plan verwenden und stark unterschiedliche Zeilenmengen erzeugen. Vergleichen Sie Query Store und Showplan.

**Ähnlich aussehender Gegenfall:** Skew kann die reale Datenverteilung korrekt beschreiben und bei geeigneten Plänen völlig unkritisch sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Bei Katalogpfaden sind Featureabwesenheit, Filter, Offline-/Permission-Scope und tatsächlich fehlende Objekte getrennte Erklärungen.

Für `USP_StatisticsDistributionAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | HIGH_OPT_IN |
| Standardpfad | Eine Datenbank, ein Objekt und höchstens zehn ausgewählte Statistiken; pro Kandidat wird das vorhandene Histogramm numerisch zusammengefasst. |
| Teuerster Pfad | Viele ausgewählte Statistiken/Partitionen; pro Histogramm können bis zu 200 Steps gelesen, aggregiert und bewertet werden. |
| Haupttreiber | Zahl gewählter Datenbanken/Objekte, ausgewählter Statistiken und Partitionen. Für jede Kandidatenstatistik werden die vorhandenen Histogramm-Steps – höchstens 200 je Histogramm – gelesen und numerisch verdichtet. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_StatisticsDistributionAnalysis ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU und Statistik-/Histogramm-Metadaten-I/O sowie Arbeitsspeicher für höchstens 200 Steps je ausgewähltem Histogramm; keine Segment-, Dictionary-, Benutzerdaten- oder XML-Ausgabe. |
| Begrenzungswirkung | Objekt-/Statistikfilter und `@MaxVerteilungsStatistiken` begrenzen Kandidaten vor dem Histogrammzugriff. `@MaxZeilen` begrenzt die fertigen Findings sowie Histogramm- und Partitionszeilen in RAW, CONSOLE und JSON; TABLE enthält nur Findings. NULL und 0 bedeuten unbegrenzt. Datenbankstatus und vollständige Zähler bleiben davon unabhängig; Histogrammschritte werden nicht begrenzt. NULL und 0 sind unbegrenzt. Datenbankstatus, vollständige Zähler und Modulstatus bleiben vom Ausgabelimit unabhängig; Histogrammschritte werden dadurch nicht begrenzt. |
| Locking und Nebenwirkungen | Read-only mit Katalog-/Strukturzugriffen; parallele DDL-, Load- oder Wartungsaktivität kann kurz kollidieren und inkonsistente Momentbilder erzeugen. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `CATALOG_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine ExampleDb, ein ExampleObject und wenige Statistiken; erst danach weitere Histogramme oder Partitionen aufnehmen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Katalogsnapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Datenverteilung bildet das Histogramm ab, und wo können Skew, dominante Werte oder grobe Rangeannahmen Schätzungen erschweren?

### Technischer Hintergrund

Histogrammsteps speichern `RANGE_HI_KEY`, `EQ_ROWS`, `RANGE_ROWS`, `DISTINCT_RANGE_ROWS` und `AVG_RANGE_ROWS`. Gleichheitsprädikate auf Stepgrenzen und Werte innerhalb einer Range werden unterschiedlich geschätzt. Skew- und Konzentrationskennzahlen des Frameworks sind abgeleitete Prüfwerte.

### Datenkette

`sys.columns`, `sys.databases`, `sys.dm_db_stats_histogram`, `sys.sp_executesql`, `sys.stats_columns`, `sys.types`.

### Source Select

Nach der vorgelagerten Zielauflösung zeigt der direkte Histogrammpfad die führende Statistikspalte und ihre Verteilung:

```sql
SELECT
      [sc].[stats_column_id]
    , [c].[name] AS [LeadingColumnName]
    , [ty].[name] AS [LeadingTypeName]
    , [h].[step_number]
    , [h].[range_high_key]
    , [h].[range_rows]
    , [h].[equal_rows]
    , [h].[distinct_range_rows]
FROM [sys].[stats_columns] AS [sc] WITH (NOLOCK)
JOIN [sys].[columns] AS [c] WITH (NOLOCK)
  ON [c].[object_id] = [sc].[object_id]
 AND [c].[column_id] = [sc].[column_id]
JOIN [sys].[types] AS [ty] WITH (NOLOCK)
  ON [ty].[user_type_id] = [c].[user_type_id]
CROSS APPLY [sys].[dm_db_stats_histogram]
            (@ObjectId, @StatisticsId) AS [h]
WHERE [sc].[object_id] = @ObjectId
  AND [sc].[stats_id] = @StatisticsId
  AND [sc].[stats_column_id] = 1;
```

**Wichtig für die Eigenlast:** `@ObjectId` und `@StatisticsId` stammen aus der zuvor eng begrenzten Kandidatenmenge von `USP_Statistics`. Das Histogramm nie für eine unbeabsichtigt breite Statistikmenge öffnen; konkrete Grenzwerte können fachliche Schlüssel enthalten und bleiben im Default abgeleitet beziehungsweise anonymisiert.

### Zeit- und Scope-Modell

Die Auswertung beschreibt das aktuelle Histogramm der letzten Statistikaktualisierung. Es enthält maximal 200 Steps und basiert gegebenenfalls auf einem Sample statt auf einem Vollscan.

### Bewertung und Gegenprobe

Verbinden Sie dominante EQ-Werte, große Ranges, eine geringe Distinctanzahl, die Samplequote, den Modification Counter und konkrete Parameterwerte. Die Verteilung ist besonders bei Parameter Sensitivity und stark unterschiedlichen Selectivities relevant.

### Typische Fehlinterpretation

Ein Skew-Score ist kein Produktfehler und kein universeller Threshold. Gute Pläne können trotz Skew entstehen; schlechte Schätzungen können ohne sichtbaren starken Skew vorkommen.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Showplan, Query Store PlanChanges/Regressions, gezieltes Statistikupdate nur nach Test.

## Primärquellen

- [sys.dm_db_stats_histogram](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-stats-histogram-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: Index and Statistics Maintenance – betriebliche Wartungsperspektive](https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html)

[Technische Detailbeschreibung](../03_Object_Index.md#6-monitorusp_statisticsdistributionanalysis)
