# [monitor].[USP_IndexUsage]

**Bereich:** Object und Index<br>
**Zweck:** Zeigt kumulative Read-/Write-Nutzung klassischer und optional In-Memory-Indizes.<br>
**Beobachtungsart:** kumulativ seit Struktur-/Instanzreset<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche sichtbaren Reads und Writes wurden einem Index seit dem DMV-Reset zugerechnet?** Sie unterstützt die Entscheidung, ob ein Struktur- oder Metadatensignal eine workloadbezogene Gegenprüfung rechtfertigt, nicht ob automatisch DDL ausgeführt werden soll.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen Geschäftsnutzen einer Strukturänderung, keine repräsentative Workload und keine automatische Aussage über den optimalen Index- oder Statistikzustand. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_IndexUsage]
      @DatabaseNames = N'[ExampleDatabase]',
      @SchemaNames = N'dbo',
      @ObjectNames = N'ExampleTable',
      @ResultSetArt = 'RAW';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Ein einzelner Datenbankname oder bracket-aware Pipe-Liste einteiliger SQL-Namen. NULL oder nach Trim leere Eingabe bedeutet keine explizite Auswahl und lässt die Datenbankauswahl alle zulässigen sichtbaren Online-Datenbanken bestimmen. Nichtleere Liste: äußere Elementleerzeichen werden getrimmt, [] quotiert Namen und ]] maskiert ]; Pipe trennt außerhalb von Klammern. Leere Elemente, ungültige SQL-Namen und case-sensitive Duplikate führen zu INVALID_PARAMETER. Eine nichtleere Liste ist mit @DatabaseNamePattern gegenseitig exklusiv; NULL/Leerraum plus Pattern ist möglich. Eine Datenbankliste allein erfüllt den GEZIELT-Objektfilter nicht. Die Namensprüfung verlangt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und LEN von Teil 1 höchstens 128; Teile 3 und 4 werden nicht gesondert geprüft. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | bit-Schalter: 0 schließt master, model, msdb und tempdb aus; 1 erlaubt ihre Aufnahme, soweit sichtbar und online. SQL Server konvertiert beim Binden von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines bit-Parameters zu 1. NULL wird vom Datenbankauswahlhelfer als INVALID_PARAMETER abgewiesen. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Pattern für Datenbanknamen nach TVF_ParsePattern: äußere Leerzeichen trimmen; Präfixe like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt; ohne Präfix gilt LIKE. Der verbleibende Inhalt wird nicht erneut getrimmt; NULL bedeutet kein Pattern, leerer Wert oder leeres Präfix ist ungültig. Datenbankname-Pattern ist mit nichtleerer @DatabaseNames-Liste exklusiv. LIKE-Wildcards gelten im Datenbankkandidatenpfad. regex: setzt Flag c, regexi: Flag i; Regex-Verfügbarkeit wird am Installationsdatenbank-Kontext geprüft und erfordert SQL Server 2025 sowie Compatibility Level 170. LIKE nutzt %, _ und Zeichenklassen [...] unter expliziter case-sensitiver Framework-Collation. Ein Übergabebeispiel ist N'like:App%'; nach Präfixentfernung wird nicht erneut getrimmt. |
| `@HighImpactConfirmed` | `bit` | `0` | bit-Bestätigung für den VOLL-Pfad CATALOG_DEEP, der erst nach OBJECT_ANALYSIS_CURRENT aktiviert wird: 0 bestätigt den Deep-Pfad nicht; 1 erfüllt die Bestätigungsanforderung, erteilt selbst aber keine Berechtigung. SQL Server konvertiert gebundene von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines bit-Parameters zu 1. NULL wird vom Datenbankauswahlhelfer als INVALID_PARAMETER abgewiesen. GEZIELT nutzt OBJECT_ANALYSIS_CURRENT und verlangt diese Bestätigung nicht. |
| `@SchemaNames` | `nvarchar(max)` | `NULL` | Exakte einteilige Schemanamen als bracket-aware Pipe-Liste. NULL bedeutet kein Filter; eine leere oder nur aus Leerzeichen bestehende Liste ist kein NULL und wird als ungültige Namensliste abgewiesen. Pipe trennt außerhalb von [...]; ]] maskiert eine Klammer. Namen werden getrimmt, als einteilige SQL-Namen mit höchstens 128 Zeichen geprüft und case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Doppelte Werte derselben Namensart sind ungültig. Nicht gemeinsam mit @SchemaNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig. |
| `@SchemaNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Schemanamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @SchemaNames kombinieren. Übergabe zum Beispiel N'like:App%'. |
| `@ObjectNames` | `nvarchar(max)` | `NULL` | Exakte einteilige Objektnamen als bracket-aware Pipe-Liste; NULL bedeutet kein Filter, eine leere Liste ist ungültig. Pipe trennt außerhalb geklammerter Namen; ]] maskiert ]. Elemente werden getrimmt und als einteilige SQL-Namen mit höchstens 128 Zeichen validiert, case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Duplikate derselben Namensart sind ungültig. Nicht gemeinsam mit @ObjectNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig. Für GEZIELT genügt eine nichtleere exakte Namensliste als Objektfilter; zusätzliche Schemafilter können den Scope weiter einschränken. |
| `@ObjectNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Objektnamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @ObjectNames kombinieren. Übergabe zum Beispiel N'like:App%'. |
| `@FullObjectNames` | `nvarchar(max)` | `NULL` | Bracket-aware Pipe-Liste vollständiger Objektbezüge mit 1 bis 3 Teilen: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt; bei Datenbankteil ist das Schema erforderlich, vier Teile sind unzulässig. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Namensbestandteile werden nach PARSENAME und sysname-Länge geprüft. Pipe trennt nur außerhalb von [...]; ]] maskiert ]. NULL bedeutet kein Filter; N'' ist EMPTY_LIST, Leerzeichen erzeugt ein ungültiges Element. Bestandteile werden case-sensitive verglichen; nicht angegebene Datenbank-/Schemaanteile bleiben im Prädikat offen. Doppelte vollständige Bezüge sind ungültig. Der Helper weist @FullObjectNames zusammen mit @SchemaNames oder @ObjectNames ab, sobald die betreffenden Eingaben nicht NULL sind; auch leere Nicht-NULL-Listen sind also eine Kombination. Dient als zulässiger Objektfilter für GEZIELT. |
| `@AnalyseModus` | `varchar(16)` | `'GEZIELT'` | Nach LTRIM/RTRIM und Großschreibung sind nur GEZIELT und VOLL gültig; NULL wird wie GEZIELT normalisiert. GEZIELT verlangt eine exakte Namenliste, FullObjectNames oder mindestens ein Schema-/Objekt-Pattern; nur DatabaseNames genügt nicht. VOLL erweitert auf die breite Indexkataloganalyse und aktiviert CATALOG_DEEP. Dieser Pfad benötigt die Freigabe für CATALOG_DEEP sowie @HighImpactConfirmed=1; GEZIELT verlangt keine High-Impact-Bestätigung. Leer oder nur Leerzeichen sowie andere Werte sind INVALID_PARAMETER. |
| `@NurUngenutzt` | `bit` | `0` | bit-Filter auf beide Resultsets: 0 lässt Rowstore- und XTP-Zeilen unabhängig von Nutzung zu; 1 lässt Rowstore-Indizes ohne User-Seeks, Scans und Lookups seit sichtbarem Reset zu und XTP-Indizes mit ScansStarted=0. SQL Server konvertiert gebundene von 0 verschiedene, zu bit konvertierbare Zahlenwerte des bit-Parameters zu 1. Bei NULL macht die jeweilige Gleich-Null-ODER-Ungenutzt-Bedingung reguläre genutzte Zeilen nicht wahr; nur Zeilen, deren Ungenutzt-Prüfung wahr ist, können passieren. |
| `@MinUserUpdates` | `bigint` | `0` | Nichtnegative bigint-Mindestzahl kumulativer User-Update-Operationen im klassischen Rowstore-Resultset; zulässiger Bereich 0 bis 9223372036854775807, Default 0 schränkt nicht ein. Negative Werte führen bei fachlicher Validierung zu INVALID_PARAMETER. NULL besteht den Kleiner-Null-Prüftest in SQL-Dreifachlogik, macht danach aber COALESCE(user_updates,0) &gt;= @MinUserUpdates UNKNOWN und lässt dadurch keine Rowstore-Zeile passieren. Für XTP wird dieser Filter nicht angewandt. |
| `@PrimaryUndUniqueEinbeziehen` | `bit` | `1` | bit-Schalter für Primary-Key- und Unique-Constraint-Indizes in Rowstore und XTP: 0 schließt diese beiden Schutzarten aus; 1 lässt sie zu. Bei NULL lautet die Filterbedingung @P=1 OR (is_primary_key=0 AND is_unique_constraint=0): normale Indizes können passieren, PK-/Unique-Constraint-Indizes nicht. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte des bit-Parameters werden beim Binden zu 1 konvertiert. |
| `@MitMemoryOptimized` | `bit` | `1` | bit-Schalter für die separate XTP-Abfrage: 0 überspringt sie; 1 versucht sys.dm_db_xtp_index_stats und befüllt bei Erfolg den XTP-Datenbestand; das vierte RAW-Resultset und der JSON-Schlüssel memoryOptimizedIndexes existieren auch bei übersprungenem Zweig mit leerer Datenmenge. SQL Server konvertiert gebundene von 0 verschiedene, zu bit konvertierbare Zahlenwerte des bit-Parameters zu 1. NULL erfüllt IF @MitMemoryOptimized=1 nicht und überspringt den Zweig. Der klassische Rowstore-Zweig bleibt separat. |
| `@MaxZeilen` | `int` | `5000` | Nichtnegative int-TOP-Grenze, Bereich 0 bis 2147483647, Default 5000; 0 oder NULL wird intern zu der bigint-Grenze 9223372036854775807 umgerechnet. Negative Werte führen zu INVALID_PARAMETER. Die Grenze gilt je Datenbank und getrennt für die Rowstore- und XTP-Quellabfragen. Rowstore-TOP sortiert vorab nach UserUpdates absteigend, dann RowCount absteigend; XTP-TOP nach ScansStarted absteigend, dann RowsTouched absteigend. Keine globale Zeilenobergrenze; die Endausgabe hat eigene Sortierung und Katalog-/DMV-Vorarbeit ist nicht dadurch begrenzt. |
| `@LockTimeoutMs` | `int` | `0` | int in Millisekunden; gültiger nicht-NULL-Wertebereich 0 bis 60000, 0 setzt vor den fachlichen Zugriffen NOWAIT. Der Bereichstest @LockTimeoutMs NOT BETWEEN 0 AND 60000 wertet NULL als UNKNOWN; zusammen mit nichtnegativem MaxZeilen wird NULL dadurch nicht als INVALID_PARAMETER erkannt. Anschließend wird der Wert mit N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(11), @LockTimeoutMs) + ... in dynamisches SQL konkateniniert. Bei NULL wird der zusammengebaute SQL-Text NULL; der Quellcode setzt darin keinen konkreten Wert. Vor der Datenbankschleife setzt die Procedure ausdrücklich LOCK_TIMEOUT 0. Der NULL-Batch setzt keine andere konkrete Wartezeit; die zuvor gesetzte NOWAIT-Einstellung bleibt für diesen Ausführungspfad maßgeblich. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | varchar(16), nach LTRIM/RTRIM und UPPER genau CONSOLE, RAW, TABLE oder NONE. NULL und leer werden als leerer String normalisiert und als INVALID_PARAMETER validiert, nicht als NONE behandelt. CONSOLE gibt nur das menschenlesbare Rowstore-Fachresultset als Resultset aus; RAW gibt Modulstatus, Datenbankstatus, Rowstore und stets als viertes Resultset den XTP-Datensatz, bei übersprungenem XTP-Zweig leer als Resultsets aus; TABLE schreibt das Rowstore-Fachresultset ins Ziel; NONE unterdrückt normale Resultsets. JSON entsteht unabhängig über @JsonErzeugen. Statuswarnungen können bei @PrintMeldungen=1 zusätzlich als Meldung ausgegeben werden. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur für TABLE wird ein JSON-Objekt mit exakt einem erlaubten, case-sensitive Resultnamen und Stringziel erwartet: rowstoreIndexes als Schlüssel. Ziel ist eine vorhandene, leere lokale #Temp-Tabelle, kein ##Temp oder #Monitor*-Name, mit genau einer Seed-Spalte; Zielzuordnungen sind eindeutig. NULL/leer bei TABLE scheitert am Preflight. Bei jeder nicht-TABLE-Ausgabe löst ein nichtleerer, nicht aus Leerzeichen bestehender Wert THROW 51011 aus; NULL, leerer oder nur aus Leerzeichen bestehender Wert ist zulässig. Der Zielname darf höchstens 116 Zeichen haben; Beispiel: N'{"rowstoreIndexes":"#IndexHelpTarget"}'. |
| `@JsonErzeugen` | `bit` | `0` | bit-Schalter: 0 erzeugt kein JSON; 1 erstellt JSON unabhängig von @ResultSetArt. Das JSON-Objekt enthält die Schlüssel meta, rowstoreIndexes, memoryOptimizedIndexes und databaseStatus. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines gebundenen bit-Parameters werden zu 1 konvertiert; NULL aktiviert die IF-Bedingung nicht und erzeugt kein JSON. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | nvarchar(max)-OUTPUT-Parameter; zum Empfangen des JSON eine nvarchar(max)-Variable mit OUTPUT binden; der Parameter darf ausgelassen werden, dann gilt der deklarierte Default NULL. Die Procedure setzt den Wert beim Eintritt auf NULL; wenn @JsonErzeugen=1, wird das JSON-Dokument mit meta, rowstoreIndexes, memoryOptimizedIndexes und databaseStatus zurückgegeben, andernfalls bleibt der Output NULL; der frühe @Hilfe-Zweig gibt ebenfalls kein JSON zurück. |
| `@PrintMeldungen` | `bit` | `1` | bit-Schalter: 0 unterdrückt strukturierte Warnmeldungen; 1 sendet bei Status ungleich AVAILABLE eine RAISERROR-Meldung mit Severity 10 und NOWAIT. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert. NULL erfüllt IF @PrintMeldungen=1 nicht und unterdrückt die Meldung. |
| `@Hilfe` | `bit` | `0` | bit-Schalter: 0 führt nach Auswahl-/Filtervorbereitung die Fachanalyse aus; 1 gibt die eingebauten PRINT-Zeilen aus und kehrt vor der fachlichen DMV-/Katalogerhebung zurück. Namefilter- und Datenbankkandidatenauswahl sowie Gate-Prüfungen liegen davor; TABLE führt außerdem das Mapping-Preflight vorher aus. Die Vorbereitung wird durch den Hilfezweig nicht unterlassen. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert; NULL erfüllt den Hilfezweig nicht. |

```sql
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_IndexUsage] @DatabaseNames=N'[ExampleDatabase]', @SchemaNames=N'dbo', @ObjectNames=N'ExampleTable', @ResultSetArt='RAW', @JsonErzeugen=1, @Json=@Json OUTPUT;
SELECT @Json;
CREATE TABLE #IndexUsageTarget([Seed] int NULL);
BEGIN TRY
    EXEC [monitor].[USP_IndexUsage] @DatabaseNames=N'[ExampleDatabase]', @SchemaNames=N'dbo', @ObjectNames=N'ExampleTable', @ResultSetArt='TABLE', @ResultTablesJson=N'{"rowstoreIndexes":"#IndexUsageTarget"}';
END TRY
BEGIN CATCH
    DROP TABLE #IndexUsageTarget;
    THROW;
END CATCH;
DROP TABLE #IndexUsageTarget;
EXEC [monitor].[USP_IndexUsage] @Hilfe=1;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `rowstoreIndexes`. RAW liefert zuerst Modul- und Datenbankstatus, danach die Fachresultsets. CONSOLE gibt nur das menschenlesbare Fachresultset aus; TABLE schreibt das registrierte Fachresultset ins Ziel. JSON enthält seine Metadaten, die Fachdaten und den Datenbankstatus. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einem Index im sichtbaren DMV-Scope; XTP-Indizes erscheinen in einem separaten Resultset mit eigener Zählersemantik.

## So lesen

Berücksichtigen Sie Resetzeit, Reads, Updates, letzte Nutzung und Schutzmerkmale wie PK, Unique oder Constraint gemeinsam.

## Warum kann das problematisch sein?

Viele Updates ohne Reads bedeuten mögliche Schreib-, Log-, Lock- und Speicherlast ohne sichtbaren Lesebedarf.

## Wann ist es kein Problem?

Kurzes Beobachtungsfenster, saisonale Reports oder Constraintfunktionen machen `0 Reads` unzureichend für eine Löschungsentscheidung.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 0 Reads, 8 Mio. Updates, 180 Tage Beobachtung: starker Reviewkandidat. 0 Reads, 40 Updates, zwei Stunden seit Restart: praktisch keine belastbare Aussage.

**Bisher dokumentierter Folgeschritt:** Prüfen Sie Query Store, Abhängigkeiten, Constraints und `USP_IndexOperationalStats`. Löschen Sie niemals allein aus dieser DMV einen Index.

**Ähnlich aussehender Gegenfall:** Kurzes Beobachtungsfenster, saisonale Reports oder Constraintfunktionen machen `0 Reads` unzureichend für eine Löschungsentscheidung. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Bei Katalogpfaden sind Featureabwesenheit, Filter, Offline-/Permission-Scope und tatsächlich fehlende Objekte getrennte Erklärungen.

Für `USP_IndexUsage` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

**Quellcode-Hinweis zur Eigenlast:** Die DMV- und Katalogabfrage besitzt eine moderate Eigenlast; Physical-Stats-Scans werden nicht ausgeführt.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Eine explizit benannte `ExampleDatabase` und ein Objekt im Modus `GEZIELT`; klassische und optional In-Memory-Indexzähler werden korreliert. |
| Teuerster Pfad | Cross-Database-`VOLL`, unbegrenzte Ausgabe, Memory-Optimized-Pfad und alle sichtbaren Indizes auf einer indexreichen Instanz. Es werden weiterhin keine Physical Stats gelesen. |
| Haupttreiber | Zahl gewählter Datenbanken/Objekte und ihrer klassischen Indizes sowie optional XTP-Indizes. Katalog-/Usage-Stats-Korrelation erfolgt je Datenbank; ein späteres Rankinglimit spart diese Vorarbeit nicht vollständig. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_IndexUsage ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU, Katalogseiten und TempDB für Joins/Aggregation; bei breitem Cross-Database-Scope zusätzlicher Compile- und Ergebnistransferaufwand. |
| Begrenzungswirkung | Datenbank-/Objektfilter begrenzen die Quellarbeit. TOP oder MaxZeilen werden häufig nach Katalogjoins und Aggregation angewandt und sind dann nur Ausgabelimits. |
| Locking und Nebenwirkungen | Read-only; Katalogabfragen nehmen üblicherweise kurze Schema-Stability-Zugriffe und können mit gleichzeitigem DDL oder Datenbankstatuswechseln konkurrieren. |
| Schutzmechanismus | Der gezielte `OBJECT_ANALYSIS_CURRENT`-Pfad braucht keine High-Impact-Bestätigung. `VOLL` prüft zusätzlich `CATALOG_DEEP` und erfordert `@HighImpactConfirmed = 1`. |
| Sicherer Einsatz | Mit einer ExampleDb und einem ExampleObject starten; erst nach Größenprüfung auf mehrere Datenbanken oder VOLL erweitern. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „kumulativ seit Struktur-/Instanzreset“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche sichtbaren Reads und Writes wurden einem Index seit dem DMV-Reset zugerechnet?

### Technischer Hintergrund

`sys.dm_db_index_usage_stats` zählt user/system seeks, scans, lookups und updates sowie letzte Zeitpunkte. Ein einzelnes DML-Statement kann mehrere Indexupdates verursachen. Der Zähler erfasst nicht jede semantische Abhängigkeit, etwa Constraintwirkung oder seltene saisonale Reports.

### Datenkette

`sys.dm_db_index_usage_stats`, `sys.dm_db_xtp_index_stats`, `sys.dm_os_sys_info`, `sys.hash_indexes`, `sys.indexes`, `sys.objects`, `sys.partitions`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`.

### Source Select

Die kumulative Nutzungs-DMV wird über Datenbank-, Objekt- und Index-ID mit dem Katalog verbunden:

```sql
SELECT
      [s].[name] AS [SchemaName]
    , [o].[name] AS [ObjectName]
    , [i].[name] AS [IndexName]
    , [us].[user_seeks]
    , [us].[user_scans]
    , [us].[user_lookups]
    , [us].[user_updates]
FROM [sys].[indexes] AS [i] WITH (NOLOCK)
JOIN [sys].[objects] AS [o] WITH (NOLOCK)
  ON [o].[object_id] = [i].[object_id]
JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
  ON [s].[schema_id] = [o].[schema_id]
LEFT JOIN [sys].[dm_db_index_usage_stats] AS [us] WITH (NOLOCK)
  ON [us].[database_id] = DB_ID()
 AND [us].[object_id] = [i].[object_id]
 AND [us].[index_id] = [i].[index_id]
WHERE [s].[name] = N'ExampleSchema'
  AND [o].[name] = N'ExampleObject';
```

**Wichtig für die Eigenlast:** Datenbank und Objekt im Katalogpfad früh eingrenzen. XTP-Indexstatistiken sind ein separater optionaler Zweig; fehlende DMV-Zeilen bedeuten nicht automatisch ungenutzte Indizes.

### Zeit- und Scope-Modell

Die Zähler sind innerhalb des jeweiligen Engine-, Datenbank- oder DMV-Lebenszyklus kumulativ. Neustart, Detach und Attach, Offline und Online sowie andere Ereignisse können den Beobachtungszeitraum verkürzen.

### Bewertung und Gegenprobe

Berücksichtigen Sie Reads, Updates, letzte Nutzung, Uptime oder Resetzeit, Indexgröße und Schutzstatus gemeinsam. Viele Updates ohne Reads über ein ausreichend langes, repräsentatives Fenster kennzeichnen einen Reviewkandidaten, aber keinen Dropbefehl.

### Typische Fehlinterpretation

`0 Reads` bedeutet nur keine in dieser DMV sichtbare Nutzung im Fenster. Prüfen Sie Planforcing, Query Store, Wartung, FK/Unique/PK und Monats-/Jahresworkloads gegen.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_IndexOperationalStats`, Query Store, Dependency-/Constraintreview.

## Primärquellen

- [sys.dm_db_index_usage_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-index-usage-stats-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: Index and Statistics Maintenance – betriebliche Wartungsperspektive](https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html)

[Technische Detailbeschreibung](../03_Object_Index.md#2-monitorusp_indexusage)
