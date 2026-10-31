# [monitor].[USP_Statistics]

**Bereich:** Object und Index<br>
**Zweck:** Inventarisiert Statistikdefinition, Materialisierung, Sample, Änderungen, inkrementelle Details und auf SQL Server 2025 die Herkunft persistierter Statistiken auf lesbaren Replikaten.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Wie aktuell und repräsentativ sind die Statistiken, die der Cardinality Estimator für Schätzungen verwendet, und aus welcher Replikatrolle stammt ihr aktuell gespeicherter Stand?** Sie unterstützt die Entscheidung, ob ein Struktur- oder Metadatensignal eine workloadbezogene Gegenprüfung rechtfertigt, nicht ob automatisch DDL ausgeführt werden soll.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen Geschäftsnutzen einer Strukturänderung, keine repräsentative Workload und keine automatische Aussage über den optimalen Index- oder Statistikzustand. Die Replikatherkunft ist insbesondere kein Verwendungsnachweis für einen Queryplan und nicht mit der aktuellen Datenbankrolle gleichzusetzen. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_Statistics]
      @DatabaseNames = N'[ExampleDatabase]',
      @FullObjectNames = N'[ExampleSchema].[ExampleTable]',
      @MitIncrementellenDetails = 0,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

`GEZIELT` verlangt mindestens eine exakte Schema-, Objekt- oder Statistikliste, einen vollständigen Objektbezug oder ein Schema-/Objektpattern; eine Datenbankauswahl allein genügt nicht. `VOLL` prüft `CATALOG_DEEP`. Inkrementelle Details werden nach der Hauptsicht für bereits materialisierte inkrementelle Statistiken gelesen und prüfen ebenfalls `CATALOG_DEEP`.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Ein einzelner Datenbankname oder eine bracket-aware Pipe-Liste einteiliger SQL-Namen. NULL oder eine nach äußerem Trimmen leere Eingabe bedeutet keine explizite Auswahl; der Kandidatenhelfer wählt alle zulässigen sichtbaren Online-Benutzerdatenbanken, soweit kein Pattern einschränkt. Pipe trennt nur außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt. Leere Elemente, ungültige SQL-Namen, case-sensitive Duplikate und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Eine nichtleere Liste ist mit einem nicht-NULL-Datenbankpattern exklusiv. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | Bit-Schalter: 0 schließt master, model, msdb und tempdb aus; 1 erlaubt deren Aufnahme, soweit sichtbar und online. NULL ist im Datenbankkandidatenhelfer ungültig. Beim Binden zu bit konvertierbare numerische Nichtnullwerte werden zu 0 oder 1 konvertiert. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Datenbanknamen-Pattern. NULL deaktiviert es; leer oder nach Präfixentfernung leer ist ungültig. Äußere Leerzeichen werden getrimmt; die Präfixe like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt, ohne Präfix gilt LIKE; danach wird nicht erneut getrimmt. LIKE verwendet %, _ und [...] mit case-sensitiver Framework-Collation. regex: verwendet Flag c, regexi: Flag i. Für Datenbanknamen prüft der Kandidatenhelfer Regex-Unterstützung im Installationsdatenbankkontext; erforderlich sind SQL Server 2025 und Compatibility Level 170. Nicht mit einer nichtleeren @DatabaseNames-Liste kombinieren. |
| `@HighImpactConfirmed` | `bit` | `0` | SQL-bit-Bestätigung mit 0 oder 1; 0 bleibt 0, von 0 verschiedene zu bit konvertierbare Zahlenwerte werden 1. STATISTICS_TARGETED verlangt kein Gruppengate. VOLL oder @MitIncrementellenDetails=1 aktiviert zusätzlich CATALOG_DEEP und verlangt ausdrücklich 1; 0 bestätigt diesen Pfad nicht. NULL ist im normalen Datenbankauswahl-/Deep-Prüfpfad INVALID_PARAMETER. Bestätigung wird vor der Gruppen-/Tokenberechtigung geprüft: 1 verleiht keine Rolle und keine SQL-Rechte; ohne Berechtigung folgt DENIED_GROUP. |
| `@SchemaNames` | `nvarchar(max)` | `NULL` | Exakte einteilige Schemanamen als bracket-aware Pipe-Liste. NULL bedeutet kein exakter Filter; eine leere oder nur aus Leerzeichen bestehende Nicht-NULL-Liste ist ungültig. Pipe trennt außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt, als einteilige SQL-Namen mit höchstens 128 Zeichen validiert und case-sensitive verglichen. Doppelte Werte derselben Namensart und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Nicht mit @SchemaNamePattern kombinieren; bei nicht-NULL @FullObjectNames ist diese Kombination ebenfalls ungültig. |
| `@SchemaNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Pattern für Schemanamen. NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere Leerzeichen werden vor der Erkennung eines Präfixes like:, regex: oder regexi: entfernt; danach bleibt das Pattern unverändert. Ohne Präfix und mit like: gilt case-sensitives SQL-LIKE mit %, _ und [...]; regex: nutzt Flag c, regexi: Flag i. Feldregex wird inline in der jeweiligen Quelldatenbank ausgeführt; dafür gibt es keine eigene Versionsvorprüfung, sodass fehlende Unterstützung als datenbankweise isolierter Fehler auftreten kann. Nicht mit nicht-NULL @SchemaNames kombinieren. |
| `@ObjectNames` | `nvarchar(max)` | `NULL` | Exakte einteilige Objektnamen als bracket-aware Pipe-Liste. NULL bedeutet kein exakter Filter; eine leere Nicht-NULL-Liste ist ungültig. Pipe trennt außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt, mit höchstens 128 Zeichen geprüft und case-sensitive verglichen. Doppelte Objektnamen und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Nicht mit @ObjectNamePattern kombinieren; bei nicht-NULL @FullObjectNames ist diese Kombination ebenfalls ungültig. |
| `@ObjectNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Objektnamen-Pattern. NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere Leerzeichen werden vor dem Erkennen von like:, regex: oder regexi: entfernt; danach wird nicht erneut getrimmt. Ohne Präfix/like: gilt case-sensitives LIKE mit %, _ und [...]; regex: nutzt Flag c, regexi: Flag i. Feldregex läuft inline je Quelldatenbank ohne eigene Versionsvorprüfung; fehlende Unterstützung kann als isolierter Datenbankfehler erscheinen. Nicht mit nicht-NULL @ObjectNames kombinieren. |
| `@FullObjectNames` | `nvarchar(max)` | `NULL` | Bracket-aware Pipe-Liste vollständiger Objektbezüge mit 1 bis 3 Teilen: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt. Bei einem Datenbankteil ist das Schema erforderlich; vierteilige Linked-Server-Bezüge sind unzulässig. Pipe trennt außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt und nach PARSENAME/sysname-Grenzen geprüft. NULL bedeutet kein Filter; ein leerer nvarchar-String ist EMPTY_LIST, Leerzeichen ergibt ein ungültiges Element. Bestandteile werden case-sensitive verglichen; nicht angegebene Datenbank-/Schemanamen bleiben offen. Duplikate und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Nicht mit nicht-NULL @SchemaNames oder @ObjectNames kombinieren. |
| `@StatisticsNames` | `nvarchar(max)` | `NULL` | Exakte einteilige Statistiknamen als bracket-aware Pipe-Liste. NULL bedeutet kein exakter Filter; eine leere Nicht-NULL-Liste ist ungültig. Pipe trennt außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt, als einteilige SQL-Namen bis 128 Zeichen validiert und case-sensitive verglichen. Duplikate sowie Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Nicht mit nicht-NULL @StatisticsNamePattern kombinieren. |
| `@StatisticsNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Statistiknamen-Pattern. NULL deaktiviert den Filter; leere Eingabe oder leeres Präfix ist ungültig. Äußere Leerzeichen werden vor Erkennung von like:, regex: oder regexi: getrimmt; der Rest wird nicht erneut getrimmt. Ohne Präfix/like: gilt case-sensitives LIKE mit %, _ und [...]; regex: nutzt Flag c, regexi: Flag i. Regex wird im jeweiligen Quelldatenbankbatch ausgewertet und hat keine separate Versionsvorprüfung; Fehler können pro Datenbank isoliert werden. Nicht mit nicht-NULL @StatisticsNames kombinieren. Ein Statistikpattern allein erfüllt den GEZIELT-Filter von USP_Statistics nicht; ein zusätzlicher Schema-/Objektfilter ist erforderlich. Das gilt auch beim weitergereichten Aufruf aus der Verteilungsanalyse. |
| `@AnalyseModus` | `varchar(16)` | `'GEZIELT'` | Text wird getrimmt und ohne Beachtung der Großschreibung normalisiert. Zulässig sind ausschließlich GEZIELT und VOLL; NULL wird als GEZIELT behandelt. Bei USP_Statistics verlangt GEZIELT mindestens eine exakte Schema-/Objekt-/Statistikliste, @FullObjectNames oder ein Schema-/Objektpattern; nur eine Datenbank genügt nicht. VOLL prüft CATALOG_DEEP. Die Verteilungsanalyse prüft CATALOG_DEEP unabhängig vom Modus; GEZIELT verlangt dort einen Objekt-, Schema- oder Statistikfilter. Ein gültiger Scope bleibt erforderlich. |
| `@MinModificationPercent` | `decimal(9,2)` | `0` | Mindestanteil geänderter Zeilen relativ zur Statistikzeilenzahl, decimal(9,2)-Wert von 0 bis 100 einschließlich; bei der Parameterbindung wird auf zwei Nachkommastellen konvertiert. Werte außerhalb dieses Bereichs werden als INVALID_PARAMETER abgewiesen; NULL ist nicht ausdrücklich abgewiesen und führt wegen des SQL-NULL-Vergleichs nicht zu dieser Bereichsverletzung. 0 lässt alle passenden Statistiken zu; höhere Werte filtern nach ModificationPercent. Bei Nullbasis wird der Anteil zu NULL und der Filterausdruck fällt aus der Auswahl. |
| `@MinAlterTage` | `int` | `0` | Nichtnegative ganze Zahl von 0 bis 2147483647. 0 deaktiviert den Altersfilter; positive Werte vergleichen DATEDIFF(DAY,last_updated,SYSDATETIME()) mit dieser Untergrenze. Gezählt werden überschrittene Kalendertagsgrenzen gemäß der Serveruhr, nicht volle 24-Stunden-Perioden. Negative Werte sind INVALID_PARAMETER. NULL passiert den negativen Wertecheck als UNKNOWN; dann erfüllen nur Zeilen mit last_updated IS NULL den gesonderten Alterszweig. Solche NULL-Zeitpunkte passieren auch bei positiver Grenze, ohne dadurch ein gemessenes Alter zu belegen. |
| `@MitIncrementellenDetails` | `bit` | `0` | Bit-Schalter: 0 lässt das zusätzliche Partitionsresultset und JSON-Array aus; 1 liest nach der Hauptabfrage inkrementelle Details nur für bereits materialisierte Ergebnisstatistiken mit IsIncremental=1. Aktivierung prüft CATALOG_DEEP und braucht gegebenenfalls die Gruppenfreigabe. NULL löst diese Zusatzabfrage nicht aus. Die Obergrenze gilt je Datenbank und Detailquery; fehlgeschlagene Detailquellen werden datenbankweise als Teilfehler markiert, während Basisstatistiken erhalten bleiben. |
| `@MaxZeilen` | `int` | `10000` | Nichtnegative int-Obergrenze von 0 bis 2147483647. NULL oder 0 wird intern als unbegrenzt behandelt; negative Werte sind ungültig. Die TOP-Grenze gilt je Datenbank und je Haupt- beziehungsweise Detailabfrage, nicht global. Ergebnisse werden vor TOP nach ModificationPercent absteigend priorisiert; bei mehreren Datenbanken kann die Gesamtzahl die angegebene Zahl überschreiten. |
| `@LockTimeoutMs` | `int` | `0` | Ganzzahlige Wartezeit für Metadatenlocks in Millisekunden, zulässig von 0 bis 60000 einschließlich. 0 wartet nicht; Werte außerhalb des Bereichs sind ungültig. Der Wert wird nur in isolierten dynamischen Datenbankbatches gesetzt. SET-Werte des Prozedur- oder dynamischen Batchscopes werden bei Rückkehr zurückgenommen; der eigenständige SET-Batch belegt keine weiterreichende Sessionwirkung. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Wird außen getrimmt und ohne Beachtung der Großschreibung normalisiert. Zulässig sind CONSOLE, RAW, TABLE und NONE. CONSOLE liefert beschriftete Status- und Fachresultsets; RAW liefert dieselben Statusbereiche mit technischen Fachdaten; TABLE schreibt das typisierte Resultset statistics nach erfolgreichem Vorab-Preflight; NONE unterdrückt Resultsets. NULL/leer wird ungültig. @ResultTablesJson darf nur bei TABLE nichtleer sein. Die Konsolenausgabe erzeugt bei leerer Fachquelle eine verständliche Leerzeile. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | JSON-Konfiguration der lokalen TABLE-Zieltabelle; nur bei @ResultSetArt=TABLE darf der bereinigte Inhalt nichtleer sein. Für TABLE ist die Konfiguration erforderlich und muss den zulässigen Resultnamen statistics auf eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte abbilden. NULL/leer bei TABLE führt zum Preflightfehler; ungültige Ziele werfen einen Fehler vor der fachlichen Analyse. Bei anderen Ausgabearten ist ein nichtleerer Wert ein Fehler. |
| `@JsonErzeugen` | `bit` | `0` | Bit-Schalter: 0 erzeugt kein JSON und lässt @Json nach seiner anfänglichen NULL-Zuweisung NULL; 1 erzeugt das JSON mit meta, statistics, incrementalStatistics und databaseStatus. NULL ist nicht als ungültig abgefangen und aktiviert die IF-Bedingung nicht. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Parameter vom Typ nvarchar(max). Optional mit einer nvarchar(max)-OUTPUT-Variablen zu binden; eine fehlende Bindung verhindert den Prozeduraufruf nicht. Wird bei Eintritt auf NULL gesetzt. Bei @JsonErzeugen=1 erhält er das JSON-Objekt mit den Schlüsseln meta, statistics, incrementalStatistics und databaseStatus; sonst bleibt er NULL. Meta enthält resultName, schemaVersion=2, generatedAtUtc, statusCode, isPartial und rowCount. |
| `@PrintMeldungen` | `bit` | `1` | Bit-Schalter für eine zusätzliche Warnmeldung via RAISERROR mit Severity 10 und NOWAIT. 1 gibt sie bei Status ungleich AVAILABLE aus; 0 unterdrückt diese Meldung. NULL aktiviert die IF-Bedingung nicht. Der Schalter ändert Status, Resultsets und JSON nicht. |
| `@Hilfe` | `bit` | `0` | SQL-bit-Schalter: 1 druckt die PRINT-Hilfe und kehrt vor den eigentlichen Statistikabfragen und der Ergebniskonstruktion zurück; 0 führt den normalen Ablauf fort. Von 0 verschiedene zu bit konvertierbare Zahlenwerte werden 1, NULL aktiviert Hilfe nicht. Patternparsing, Namensfilter, Datenbankkandidaten und ein bedingt aktiviertes Deep-Gate laufen bereits davor. Auch TABLE-Preflight und die Abweisung einer nichtleeren TABLE-Zuordnung bei anderer Ausgabeart erfolgen vor Hilfe; Hilfe ist daher kein voraussetzungsloser Filter-/Berechtigungs-Bypass. |

Alle Example*-Werte sind synthetisch. RAW erhält den Quellenstatus. TABLE-Ziele werden vor TRY neu angelegt und auf beiden Ausgängen entfernt.

```sql
EXEC [monitor].[USP_Statistics] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @MaxZeilen=100, @ResultSetArt='RAW';

DECLARE @ExampleJson nvarchar(max);
EXEC [monitor].[USP_Statistics] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT;
SELECT @ExampleJson AS [ExampleJson];

CREATE TABLE [#ExampleStatistics]([Seed] int NULL);
BEGIN TRY
    EXEC [monitor].[USP_Statistics] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"statistics":"#ExampleStatistics"}';
END TRY
BEGIN CATCH
    DROP TABLE [#ExampleStatistics];
    THROW;
END CATCH;
DROP TABLE [#ExampleStatistics];

EXEC [monitor].[USP_Statistics] @Hilfe=1;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `statistics` in Schema-Version 2. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

Die SQL-Server-2025-Erweiterung ergänzt sieben Spalten:

| Feld | Leserichtung |
|---|---|
| `IsTemporary` | Temporäre Statistik gemäß `sys.stats.is_temporary` |
| `CurrentReplicaRole` | Aktuelle Datenbankrolle: `HADR_DISABLED`, `PRIMARY`, `SECONDARY` oder `NOT_IN_AG_OR_UNKNOWN` |
| `CurrentReplicaRoleStatus` | Verfügbarkeit der separaten Rollenprüfung |
| `ReplicaRoleId`, `ReplicaRoleDesc` | Herkunft beziehungsweise letzte Aktualisierungsrolle der Statistik |
| `ReplicaName` | Ursprungsreplikat; bei Primary-Herkunft regulär `NULL` |
| `ReplicaMetadataStatus` | Verfügbarkeit und Konsistenz der Herkunftsevidenz |

## Eine Zeile bedeutet

Im Hauptresultset beschreibt eine Zeile eine Statistik. Inkrementelle Details besitzen eine zusätzliche Partitionsgranularität.

## So lesen

Berücksichtigen Sie Rows, Rows Sampled, Modification Counter, führende Spalte, Filter und letzten Updatezeitpunkt gemeinsam. Lesen Sie `CurrentReplicaRole` und `ReplicaRole*` getrennt: Das erste Feld beschreibt den Erfassungsort, die anderen Felder den gespeicherten Statistikursprung.

## Warum kann das problematisch sein?

Unpassendes Sample oder relevante Datenänderungen können Kardinalitätsschätzungen und dadurch Joinart, Grant und Zugriffspfad verschlechtern.

## Wann ist es kein Problem?

Eine alte Statistik kann korrekt bleiben, wenn sich relevante Daten kaum ändern. Niedriger Sample-Prozentsatz kann bei sehr großen Tabellen ausreichend sein.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Zehn Jahre alt plus Modification Counter 0 ist nicht automatisch schlecht. Eine gestern aktualisierte Statistik kann einen neu entstandenen Tail dennoch schlecht abbilden. Prüfen Sie Histogramm und betroffene Pläne.

**Ähnlich aussehender Gegenfall:** Eine alte Statistik kann korrekt bleiben, wenn sich relevante Daten kaum ändern. Niedriger Sample-Prozentsatz kann bei sehr großen Tabellen ausreichend sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Bei Katalogpfaden sind Featureabwesenheit, Filter, Offline-/Permission-Scope und tatsächlich fehlende Objekte getrennte Erklärungen.

Für `USP_Statistics` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. Für `ReplicaName` ist `NULL` bei Primary-Herkunft ausdrücklich regulär. `ReplicaMetadataStatus=NOT_RECORDED` bedeutet, dass keine Herkunft aufgezeichnet ist; `PARTIAL_METADATA` markiert inkonsistente oder unvollständige Herkunftsfelder. Auf SQL Server 2019/2022 bleiben die typisierten Felder erhalten und melden `UNAVAILABLE_VERSION`. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

**Quellcode-Hinweis zur Eigenlast:** Eine gezielte Abfrage besitzt eine moderate Eigenlast; VOLL und inkrementelle Details sind durch `CATALOG_DEEP` beziehungsweise den Cross-Database-Pfad geschützt und begrenzt.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | `GEZIELT` erfordert Schema-/Objektfilter, liest Definition/Spalten und `sys.dm_db_stats_properties` für passende Statistiken; inkrementelle Partitionsdetails sind aus. Auf SQL Server 2025 wird das Herkunftsschema einmal capability-geprüft. |
| Teuerster Pfad | `VOLL` und `@MitIncrementellenDetails = 1` über alle sichtbaren Datenbanken, ohne Schwellen und mit `@MaxZeilen = 0`: jede Statistik plus jede inkrementelle Partition wird materialisiert. |
| Haupttreiber | Zahl passender Statistiken und Statistikspalten; für inkrementelle Statistiken zusätzlich Partitionen. Tabellenzeilenzahl wirkt nur auf zurückgegebene Properties, nicht als gescannte Nutzdatenmenge. |
| Skalierung | Pro Kandidatendatenbank wird dynamisches Katalog-SQL kompiliert. `sys.stats` wird je Aufruf und Datenbank höchstens einmal gelesen; inkrementelle Details verwenden die bereits materialisierten Statistik-IDs. Cross-Database-Kosten addieren sich pro Datenbank. |
| Ressourcen | Katalogseiten, `dm_db_stats_properties`/`dm_db_incremental_stats_properties`, auf SQL Server 2025 eine kleine Spalten-Capability-Prüfung und bei aktiviertem HADR höchstens ein Aufruf von `sys.fn_hadr_is_primary_replica`; dazu CPU für Filter/Joins und TempDB/Transfer. Histogramme selbst werden hier nicht gelesen. |
| Begrenzungswirkung | Objekt-/Statistikfilter und Modification-/Altersschwellen reduzieren fachliche Zeilen. `@MaxZeilen` ist TOP je Datenbank und je Haupt-/Detailquery, kein globales Parentlimit; Gesamtzeilen können bei mehreren Datenbanken darüber liegen. |
| Locking und Nebenwirkungen | Read-only; Katalogabfragen nehmen üblicherweise kurze Schema-Stability-Zugriffe und können mit gleichzeitigem DDL oder Datenbankstatuswechseln konkurrieren. `@LockTimeoutMs` gilt nur in isolierten dynamischen Datenbankbatches; der äußere `LOCK_TIMEOUT` bleibt unverändert. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `CATALOG_DEEP`, `STATISTICS_TARGETED`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine `ExampleDatabase`, ein `ExampleSchema.ExampleTable`, 100 Zeilen und keine inkrementellen Details. Danach eine konkrete Statistik oder Partition vertiefen. |
| Aussagegrenze | Properties sind Metadaten zum letzten Update, nicht Histogrammqualität oder aktuelle Kardinalitätsgenauigkeit. Replikatherkunft belegt weder Statistiknutzung noch aktuelle Datenbankrolle. Modification Counter und Alter müssen mit Zeilenzahl, Filterstatistik, Partition und Planverhalten interpretiert werden. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie aktuell und repräsentativ sind die Statistiken, die der Cardinality Estimator für Schätzungen verwendet?

### Technischer Hintergrund

Statistiken enthalten Header, Dichteinformationen und ein Histogramm für die führende Statistikspalte mit maximal 200 Steps. Auto-/User-Created, Filter, Persisted Sample und `dm_db_stats_properties` liefern Aktualisierungs-, Row-, Sample- und Modification-Kontext. SQL Server 2025 kann auf einer lesbaren Secondary erzeugte Statistiken auf dem Primary persistieren und kennzeichnet deren Herkunft in `sys.stats`. Ein späteres Update auf dem Primary überträgt diese Herkunft; temporäre und permanente Fassungen können bis Recompilation oder Neustart nebeneinander bestehen.

### Datenkette

`sys.all_columns`, `sys.all_views`, `sys.columns`, `sys.dm_db_incremental_stats_properties`, `sys.dm_db_stats_properties`, `sys.fn_hadr_is_primary_replica`, `sys.indexes`, `sys.objects`, `sys.schemas`, `sys.sp_executesql`, `sys.stats`, `sys.stats_columns`, `sys.tables`.

### Source Select

Zielstatistiken werden zuerst im Katalog bestimmt und erst dann an `dm_db_stats_properties` übergeben:

```sql
WITH [TargetStatistics] AS
(
    SELECT
          [st].[object_id]
        , [st].[stats_id]
        , [st].[name] AS [StatisticsName]
        , [s].[name] AS [SchemaName]
        , [o].[name] AS [ObjectName]
    FROM [sys].[stats] AS [st] WITH (NOLOCK)
    JOIN [sys].[objects] AS [o] WITH (NOLOCK)
      ON [o].[object_id] = [st].[object_id]
    JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id] = [o].[schema_id]
    WHERE [s].[name] = N'ExampleSchema'
      AND [o].[name] = N'ExampleObject'
)
SELECT
      [t].[SchemaName]
    , [t].[ObjectName]
    , [t].[StatisticsName]
    , [p].[last_updated]
    , [p].[rows]
    , [p].[rows_sampled]
    , [p].[modification_counter]
FROM [TargetStatistics] AS [t]
OUTER APPLY [sys].[dm_db_stats_properties]
            ([t].[object_id], [t].[stats_id]) AS [p];
```

**Wichtig für die Eigenlast:** Objekt und Statistik vor den DMFs bestimmen. Inkrementelle Partitionsdetails nur für bereits materialisierte inkrementelle Statistiken lesen; `@MaxZeilen` nach der DMF spart deren Aufrufe nicht. Die SQL-Server-2025-Spalten werden erst nach Versions- und Capabilityprüfung in Dynamic SQL referenziert.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuell gespeicherten Statistikstand seit dem letzten Update. Der Modification Counter beschreibt Änderungen seitdem, aber nicht deren genaue Verteilungswirkung. `CurrentReplicaRole` ist ein Snapshot zum Erfassungszeitpunkt; die Herkunftsfelder sind der aktuell gespeicherte Katalogstand und keine unveränderliche Entstehungshistorie.

### Bewertung und Gegenprobe

Berücksichtigen Sie Rows, Rows Sampled, Samplingrate, Last Updated, Modifications, führende Spalte, Filter und betroffene Queryprädikate gemeinsam. Eine alte unveränderte Statistik kann korrekt sein; eine junge stark gesampelte Statistik bei Skew kann problematisch sein. Bei Secondary-Herkunft prüfen Sie die aktuelle Rolle separat und verwenden Query-/Plannachweise, bevor Sie einen Nutzen oder ein Problem unterstellen.

### Typische Fehlinterpretation

Alter oder Modification Counter allein beweist keinen Schätzfehler. Auto-Update-Schwellen und asynchrones Update sind kontextabhängig. `ReplicaRoleId=2` beweist weder, dass die aktuelle Verbindung auf einer Secondary läuft, noch dass eine konkrete Query diese Statistik verwendet. `ReplicaName=NULL` ist bei Primary-Herkunft kein Fehler.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_StatisticsDistributionAnalysis`, Showplan Estimated/Actual Rows und Query Store Regression.

## Primärquellen

- [sys.dm_db_stats_properties](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-stats-properties-transact-sql?view=sql-server-ver17)
- [sys.stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-stats-transact-sql?view=sql-server-ver17)
- [Persisted Statistics for Readable Secondary Replicas](https://learn.microsoft.com/en-us/sql/relational-databases/performance/persisted-stats-secondary-replicas?view=sql-server-ver17)
- [sys.fn_hadr_is_primary_replica](https://learn.microsoft.com/en-us/sql/relational-databases/system-functions/sys-fn-hadr-is-primary-replica-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: Index and Statistics Maintenance – betriebliche Wartungsperspektive](https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html)

[Technische Detailbeschreibung](../03_Object_Index.md#5-monitorusp_statistics)
