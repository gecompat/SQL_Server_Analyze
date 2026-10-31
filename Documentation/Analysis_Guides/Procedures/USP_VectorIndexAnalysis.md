# [monitor].[USP_VectorIndexAnalysis]

`USP_VectorIndexAnalysis` inventarisiert sichtbare Vector-Indizes auf SQL Server
2025 und korreliert sie mit dem aktuellen Zustand ihrer
Hintergrundwartung. Auf SQL Server 2019 und 2022 bleibt dieselbe Procedure
installierbar und liefert `UNAVAILABLE_VERSION`, ohne die neueren Systemobjekte
zu referenzieren.

**Bereich:** SQL Server 2025 und Objekt-/Indexanalyse
**Zweck:** Trennt Vector-Index-Katalog, aktuelle Hintergrundwartung, Quellenstatus und begrenzte Reviewhinweise.
**Beobachtungsart:** versionsadaptiver Katalog- und Runtime-Snapshot
**Kostenklasse:** LOW bis MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure wird eingesetzt, wenn sichtbare Vector-Indizes und ihre aktuelle Wartungsevidenz für eine ausdrücklich ausgewählte Datenbank oder ein Objekt inventarisiert werden sollen. Sie eignet sich nach der leichten Featureinventur und vor einer workloadbezogenen Recall- oder Performanceprüfung.

## Nicht beantwortete Fragen

Die Procedure misst keinen Recall, keine Suchqualität und keinen geschäftlichen Nutzen. Sie liest weder Vektorinhalte noch interne Buildparameter. Ein aktueller Wartungsstatus erklärt keine historische Entwicklung. Auch ein Preview-Featurestatus auf Product Major Version 17 garantiert nicht, dass alle Systemobjekte im konkreten Build vorhanden oder aktiviert sind.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Optionaler einteiliger Datenbankname oder bracket-aware Pipe-Liste; &#124; trennt außerhalb von [...], ]] maskiert ]; Elemente außen getrimmt und case-sensitive. NULL, N'' oder nur Leerzeichen bedeutet keine exakte Auswahl und prüft alle zulässigen sichtbaren ONLINE-Benutzerdatenbanken. Nichtleere Liste ist mit nicht-NULL @DatabaseNamePattern exklusiv. Leere/ungültige Elemente, Duplikate, ungültiger PARSENAME-Name oder Rohsegment über 4000 UTF-16-Codeeinheiten sind INVALID_PARAMETER; LEN höchstens 128. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | 0 (Default) schließt master, model, msdb und tempdb aus; 1 lässt sie in die Auswahl zu. NULL INVALID_PARAMETER. Beim Binden an bit werden konvertierbare numerische Werte ungleich 0 auf 1 abgebildet. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Datenbankpattern; NULL kein Filter, leer/Whitespace oder Präfix ohne Inhalt ungültig. Außen trimmen; like:, regex:, regexi: ohne Beachtung der Großschreibung; Rest nicht erneut trimmen; ohne Präfix LIKE. LIKE nutzt %, _ und [...] case-sensitiv. regex: Flag c, regexi: Flag i; Syntax wird nicht vorgeprüft. Dieser Datenbankpatternpfad prüft Regex-Verfügbarkeit im Installationsdatenbankkontext (SQL Server 2025, Compatibility Level 170), sonst UNAVAILABLE_FEATURE. Nicht mit wirksamer nichtleerer Datenbankliste kombinieren. |
| `@HighImpactConfirmed` | `bit` | `0` | 0 (Default) bestätigt kein High-Impact-Gate; 1 bestätigt die Anforderung eines tatsächlich aktivierten Analysepfads. NULL INVALID_PARAMETER. Dieses Modul übergibt OBJECT_ANALYSIS_CURRENT an den Kandidatenhelfer. Bestätigung ersetzt weder Aktivierung/Freigabe noch die Prüfung, ob die Klasse ein Gruppengate verlangt. Bit-Bindung bildet konvertierbare numerische Nichtnullwerte auf 1 ab. |
| `@SchemaNames` | `nvarchar(max)` | `NULL` | Optionale exakte einteilige Schemanamen als bracket-aware Pipe-Liste; &#124; trennt außerhalb von [...], ]] maskiert ]; außen getrimmt und case-sensitive. NULL kein Filter; nicht-NULL leer/Whitespace, leere/ungültige Elemente, Duplikate, ungültiger PARSENAME-Name oder Rohsegment über 4000 UTF-16-Codeeinheiten ungültig. Teil 1 muss vorhanden, Teil 2 NULL und LEN höchstens 128 sein. Nicht mit nicht-NULL @SchemaNamePattern oder @FullObjectNames kombinieren. |
| `@SchemaNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Schema-Pattern; NULL deaktiviert, leer/Whitespace oder leeres Präfix ungültig. Außen trimmen; Präfixe like:, regex:, regexi: ohne Beachtung der Großschreibung; Rest nicht erneut trimmen; ohne Präfix LIKE. LIKE-Wildcards %, _ und [...] case-sensitiv; regex: c, regexi: i. Regex läuft in der jeweiligen Zieldatenbank ohne separate Versions-/Kompatibilitätsvorprüfung; fehlende Funktion kann als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit nicht-NULL @SchemaNames kombinieren. |
| `@ObjectNames` | `nvarchar(max)` | `NULL` | Optionale exakte einteilige Objektnamen als bracket-aware Pipe-Liste; &#124; trennt außerhalb von [...], ]] maskiert ]; außen getrimmt, case-sensitive. NULL kein Filter; nicht-NULL leere Liste, leere/ungültige Elemente, Duplikate, PARSENAME-Fehler oder Rohsegment über 4000 UTF-16-Codeeinheiten ungültig; LEN höchstens 128. Nicht mit nicht-NULL @ObjectNamePattern oder @FullObjectNames kombinieren. |
| `@ObjectNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Objektpattern; NULL deaktiviert, leer/Whitespace oder Präfix ohne Inhalt ungültig. Außen trimmen; Präfixe like:, regex:, regexi: case-insensitiv erkannt; Rest nicht erneut trimmen; ohne Präfix LIKE. LIKE-Wildcards %, _ und [...] case-sensitiv; regex: c, regexi: i. Feldregex läuft in Zieldatenbank ohne eigene Versions-/Kompatibilitätsvorprüfung und kann je Datenbank als ERROR_HANDLED isoliert werden. Nicht mit nicht-NULL @ObjectNames kombinieren. |
| `@FullObjectNames` | `nvarchar(max)` | `NULL` | Optionale bracket-aware Pipe-Liste vollständiger Objektbezüge mit 1 bis 3 Teilen: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt. &#124; trennt außerhalb von [...], ]] maskiert ]; geparst mit PARSENAME, case-sensitive, Rohsegment bis 4000 UTF-16-Codeeinheiten und Bestandteile sysname-limitiert. Datenbankteil braucht Schema; vier Teile unzulässig. NULL kein Filter; nicht-NULL leere Liste ungültig. Nicht angegebene Datenbank-/Schemaanteile bleiben offen. Mit nicht-NULL @SchemaNames oder @ObjectNames exklusiv. |
| `@IndexNames` | `nvarchar(max)` | `NULL` | Optionale exakte einteilige Indexnamen als bracket-aware Pipe-Liste; &#124; trennt außerhalb von [...], ]] maskiert ]; außen getrimmt und case-sensitive. NULL kein Filter; nicht-NULL leer/Whitespace, ungültige/leere Elemente, Duplikate oder ungültiger PARSENAME-/sysname-Wert INVALID_PARAMETER. Rohsegmente bis 4000 UTF-16-Codeeinheiten. Mit nicht-NULL @IndexNamePattern exklusiv. |
| `@IndexNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Indexpattern; NULL kein Filter, leer/Whitespace oder Präfix ohne Inhalt ungültig. Außen trimmen; like:, regex:, regexi: ohne Beachtung der Großschreibung; Rest danach nicht erneut trimmen; ohne Präfix LIKE. LIKE-Wildcards %, _ und [...] case-sensitiv; regex: c, regexi: i. Regex wird in Zieldatenbank ohne separate Versions-/Kompatibilitätsvorprüfung ausgeführt und kann datenbankweise isoliert fehlschlagen. Nicht mit nicht-NULL @IndexNames kombinieren. |
| `@StalenessReviewPercent` | `decimal(5,2)` | `15.00` | Optionaler Reviewgrenzwert in Prozent, 0 bis 100 einschließlich; NULL deaktiviert nur das VECTOR_STALENESS_REVIEW-Finding. Default 15.00: Finding bei verfügbarer ungefährer Staleness &gt;= Grenzwert. Kein universeller Fehler-/Rebuildgrenzwert. |
| `@MaxZeilen` | `int` | `2000` | Nichtnegative int-Grenze; 0 oder NULL bedeutet unbegrenzt, negative Werte führen zu INVALID_PARAMETER. Nur in RAW und JSON begrenzt ein positiver Wert vectorIndexes, maintenance und findings jeweils separat; hasMore meldet weitere Zeilen. CONSOLE zeigt alle Findings, TABLE schreibt die vollständigen gemappten Quellen. Status-, Quellenstatus- und Warnmengen bleiben ungekürzt; Ermittlung und Korrelation werden dadurch nicht global begrenzt. |
| `@LockTimeoutMs` | `int` | `0` | Lockwartezeit in Millisekunden von 0 bis 60000 einschließlich; 0 bedeutet NOWAIT, außerhalb INVALID_PARAMETER. Im Analysepfad wird der Wert dynamisch gesetzt; vor der Ausgabe wird aus dem zuvor gespeicherten @@LOCK_TIMEOUT ein separater Wiederherstellungsbatch gebildet. NULL wird von der Bereichsprüfung nicht als ungültig erkannt; die spätere dynamische SET-LOCK_TIMEOUT-Textbildung wird durch den NULL-Wert NULL. Ein konkreter Ausführungsstatus dieses NULL-Batches wird hier nicht zugesichert. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Nach TRIM/UPPER genau CONSOLE, RAW, TABLE oder NONE; NULL/leer wird ungültig. CONSOLE zeigt eine menschenlesbare Findings-Ansicht. RAW liefert sechs getrennte Mengen: moduleStatus, vectorIndexes, maintenance, findings, sourceStatus, warnings. TABLE schreibt gemappte Namen; NONE unterdrückt reguläre Resultsets. JSON-OUTPUT unabhängig über @JsonErzeugen. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur für TABLE ein JSON-Objekt Resultsetname→vorhandene lokale #Temp-Tabelle. TABLE erfordert gültiges nichtleeres Objekt mit ausschließlich moduleStatus, vectorIndexes, maintenance, findings, sourceStatus oder warnings. Ziele eindeutig, lokal, leer und mit genau einer Seed-Spalte; der Helper prüft und wirft bei Fehler. Außerhalb TABLE führt nichtleerer Inhalt zu INVALID_PARAMETER; NULL/leer dort zulässig. |
| `@JsonErzeugen` | `bit` | `0` | 0 unterdrückt JSON-Erzeugung; 1 befüllt @Json mit Schema 1 und Schlüsseln meta, vectorIndexes, maintenance, findings, sourceStatus, warnings. NULL ist INVALID_PARAMETER. JSON-Facharrays folgen der jeweiligen @MaxZeilen-Grenze; hasMore… zeigt weitere Zeilen an. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Optionaler nvarchar(max)-OUTPUT-Empfänger, zu Beginn auf NULL gesetzt; mit @JsonErzeugen=1 enthält er das JSON-Dokument. Zum Empfang Variable des passenden Typs mit OUTPUT binden; ohne OUTPUT kommt Zuweisung nicht beim Aufrufer an. Hilfe kehrt nach dem NULL-Set zurück. |
| `@PrintMeldungen` | `bit` | `1` | 0 unterdrückt Severity-10-Statusmeldung; 1 (Default) sendet sie bei Abschluss außer bei AVAILABLE, AVAILABLE_WITH_FINDING und NOT_APPLICABLE. NULL INVALID_PARAMETER. Meldung ergänzt Status-/Warnings-Ausgaben. |
| `@Hilfe` | `bit` | `0` | 1 druckt fünf Hilfezeilen und kehrt sofort vor Filter-, Ausgabe-, Datenbank- und Engineprüfungen sowie vor OUTPUT-Statuszuweisungen zurück. @Json ist zuvor bereits NULL. 0 normaler Ablauf; NULL wird nicht als 1 behandelt. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger varchar(40); erhält am regulären Ablaufende den finalen Modulstatus. Mit passender varchar(40)-Aufrufervariable samt OUTPUT binden; ohne OUTPUT erreicht die Zuweisung den Aufrufer nicht. Default NULL; bei frühem @Hilfe-Return unverändert. AVAILABLE bedeutet verfügbare Erhebung ohne Finding/Partialität; AVAILABLE_WITH_FINDING kennzeichnet mindestens ein WARN-Finding; AVAILABLE_LIMITED bedeutet partielle Erhebung; NOT_APPLICABLE: keine sichtbaren Vector-Indizes; UNAVAILABLE_VERSION: Product Major Version fehlt oder kleiner 17; UNAVAILABLE_FEATURE: keine verfügbare Vector-Quelle. Bei fehlendem erfolgreichem Katalogstatus kann zusätzlich der erste Katalogquellenstatus wie DENIED_PERMISSION, TIMEOUT, ERROR_HANDLED oder UNAVAILABLE_SOURCE_SCHEMA ausgegeben werden; ungültige Eingabe ergibt INVALID_PARAMETER. Quellenstatus bleibt separat in sourceStatus. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger bit; erhält am regulären Ablaufende den Partialitätsindikator. 1 kennzeichnet unvollständige/abgewiesene Erhebung; 0 eine nicht als partiell markierte Erhebung. Mit bit-Variable samt OUTPUT binden; ohne OUTPUT keine Rückgabe. Default NULL und bei frühem Hilfe-Return unverändert. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger int; erhält am normalen Ablaufende die gesetzte Fehlernummer oder NULL, wenn keine Fehlernummer für den Modulstatus gewählt wurde. Eine int-Variable mit OUTPUT bindet den Rückgabewert; ohne OUTPUT keine Rückgabe. Default NULL und bei Hilfe unverändert. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger nvarchar(2048); erhält am normalen Ablaufende die gewählte Fehler-/Warnmeldung oder NULL. Bei fehlendem expliziten Fehlertext wird die erste Warnmeldung gewählt. Eine nvarchar(2048)-Variable mit OUTPUT bindet den Rückgabewert; ohne OUTPUT keine Rückgabe. Default NULL und bei Hilfe unverändert. |

~~~sql
EXEC [monitor].[USP_VectorIndexAnalysis]
      @DatabaseNames=N'[ExampleDatabase]'
    , @FullObjectNames=N'[ExampleSchema].[ExampleTable]'
    , @ResultSetArt='RAW';
~~~

~~~sql
DECLARE @VectorIndexAnalysis_JsonExample nvarchar(max);
DECLARE @VectorIndexAnalysis_StatusExample varchar(40);
DECLARE @VectorIndexAnalysis_PartialExample bit;
DECLARE @VectorIndexAnalysis_ErrorNumberExample int;
DECLARE @VectorIndexAnalysis_ErrorMessageExample nvarchar(2048);
EXEC [monitor].[USP_VectorIndexAnalysis]
      @DatabaseNames=N'[ExampleDatabase]'
    , @JsonErzeugen=1
    , @Json=@VectorIndexAnalysis_JsonExample OUTPUT
    , @StatusCodeOut=@VectorIndexAnalysis_StatusExample OUTPUT
    , @IsPartialOut=@VectorIndexAnalysis_PartialExample OUTPUT
    , @ErrorNumberOut=@VectorIndexAnalysis_ErrorNumberExample OUTPUT
    , @ErrorMessageOut=@VectorIndexAnalysis_ErrorMessageExample OUTPUT;
SELECT @VectorIndexAnalysis_StatusExample AS [StatusCode], @VectorIndexAnalysis_JsonExample AS [JsonDocument];
~~~

~~~sql
CREATE TABLE #VectorIndexAnalysis_ModuleExample ([Seed] bit NULL);
BEGIN TRY
    EXEC [monitor].[USP_VectorIndexAnalysis]
          @DatabaseNames=N'[ExampleDatabase]'
        , @ResultSetArt='TABLE'
        , @ResultTablesJson=N'{"moduleStatus":"#VectorIndexAnalysis_ModuleExample"}';
END TRY
BEGIN CATCH
    DROP TABLE #VectorIndexAnalysis_ModuleExample;
    THROW;
END CATCH;
DROP TABLE #VectorIndexAnalysis_ModuleExample;
~~~

~~~sql
EXEC [monitor].[USP_VectorIndexAnalysis] @Hilfe=1;
~~~

## Resultsets und Leserichtung

RAW, TABLE und JSON trennen `moduleStatus`, `sourceStatus`, `vectorIndexes`, `maintenance` und `findings`; CONSOLE priorisiert die fachlichen Reviewhinweise. Lesen Sie Version und Quelle vor Katalog- oder Runtimewerten. TABLE verwendet nur die im Resultsetinventar benannten Ziele und erhält dieselben nativen Spaltentypen.

## Eine Zeile bedeutet

Eine Zeile in `vectorIndexes` beschreibt genau einen für den aktuellen
Sicherheitskontext sichtbaren Vector-Index. Eine Zeile in `maintenance`
beschreibt die Korrelation desselben Index mit der aktuellen Runtime-DMV.
`findings` enthält nur einen begrenzten Reviewhinweis; es ist weder eine
Wartungsanweisung noch ein historischer Trend.

## So lesen

1. Zuerst `moduleStatus` auf Version, Partialität und `hasMore…` prüfen.
2. Danach in `sourceStatus` Katalog- und Runtimequelle getrennt lesen.
3. `vectorIndexes` für Typ, Distanzmetrik und Disabled-Status verwenden.
4. `maintenance` nur als Momentaufnahme interpretieren.
5. `findings` stets zusammen mit `EvidenceLimit` und
   `RecommendedNextCheck` lesen.

`AVAILABLE_EMPTY`, `NOT_ENABLED`, `UNAVAILABLE_VERSION`,
`UNAVAILABLE_FEATURE`, `DENIED_PERMISSION` und `NOT_RETURNED` sind
unterschiedliche Zustände. Ein leeres fachliches Array ersetzt diese
Unterscheidung nicht.

Der approximative Vector-Index-Pfad ist in SQL Server 2025 ein Previewfeature.
Auch bei Product Major Version 17 können `UNAVAILABLE_FEATURE` oder
`NOT_ENABLED` deshalb korrekt sein, wenn `PREVIEW_FEATURES` nicht aktiviert ist
oder der konkrete Build die beiden Systemobjekte nicht bereitstellt.

## Beispiele und Gegenbeispiele

Ein passender Example-Fall verwendet eine synthetische Tabelle mit einem kontrollierten Vector-Index auf SQL Server 2025 und prüft getrennt Katalog- und DMV-Status. Ein Gegenbeispiel ist die automatische Rebuild-Empfehlung aus einer einzelnen Stalenessmessung. Ebenso darf `UNAVAILABLE_VERSION` auf SQL Server 2022 nicht als Installationsfehler interpretiert werden.

## Leere oder partielle Ausgabe

`AVAILABLE_EMPTY` bedeutet, dass im sichtbaren Scope kein Vector-Index gefunden wurde. `NOT_ENABLED` und `UNAVAILABLE_FEATURE` trennen Konfiguration und Capability. Ein verweigerter Runtimezugriff darf sichtbare Katalogzeilen nicht entfernen; stattdessen bleibt die Runtimequelle partiell und der Katalogbestand erhalten.

## Eigenlast und Grenzen

| Dimension | Einordnung |
|---|---|
| Kostenklasse | `LOW` bis `MEDIUM` |
| Standardpfad | Capabilityprüfung und gefiltertes Kataloginventar |
| Teuerster Pfad | Katalog plus Runtime-DMV für viele sichtbare Indizes |
| Haupttreiber | Datenbank-, Objekt- und Indexanzahl |
| Skalierung | Sequenziell je ausgewählter Datenbank |
| Ressourcen | Katalog- und DMV-I/O sowie lokale Korrelation |
| Begrenzungswirkung | Datenbank-/Objektfilter schränken den Scope ein. Ein positives `@MaxZeilen` begrenzt vectorIndexes, maintenance und findings jeweils separat nur in RAW und JSON; CONSOLE und TABLE erhalten die vollständigen jeweiligen Quellen. Status-, Quellenstatus- und Warnmengen bleiben ungekürzt. |
| Locking und Nebenwirkungen | Read-only; kein Build, Rebuild oder DDL |
| Schutzmechanismus | Versions-, Objekt- und Spaltenprobes vor dynamischen Zugriffen |
| Sicherer Einsatz | Kleine explizite Datenbank- und Objektmenge |
| Aussagegrenze | Wartungssnapshot ist keine Suchqualitätsbewertung |

## Warum kann das problematisch sein?

Ein fehlgeschlagener Hintergrundtask kann dazu führen, dass Änderungen nicht
planmäßig in die Indexstruktur eingearbeitet werden. Anhaltend hohe ungefähre
Staleness kann zusammen mit hoher DML-Rate, schlechterem Recall oder
Performanceänderungen auf einen Wartungsrückstand hindeuten. Ein deaktivierter
Index kann außerdem erklären, warum eine erwartete approximative Suche nicht
verwendet wird.

## Wann ist es kein Problem?

Erhöhte Staleness während eines Batchloads kann vorübergehend normal sein.
Ein einzelner letzter Taskfehler kann durch einen späteren erfolgreichen Lauf
überholt sein. Eine fehlende DMV-Zeile beweist weder einen defekten Index noch
fehlende Katalogdefinition. Die Procedure empfiehlt deshalb keinen
automatischen Rebuild.

## Sicherer Einstieg

Das Beispiel verwendet ausschließlich synthetische Bezeichner:

```sql
DECLARE @Json nvarchar(max);

EXEC [monitor].[USP_VectorIndexAnalysis]
      @DatabaseNames = N'[ExampleDatabase]'
    , @FullObjectNames = N'[ExampleSchema].[ExampleTable]'
    , @StalenessReviewPercent = 15
    , @MaxZeilen = 100
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT;

SELECT @Json AS [VectorIndexAnalysisJson];
```

Für einen breiten Cross-Database-Aufruf sollte der Datenbankscope explizit
angegeben werden. `@MaxZeilen = 0` bedeutet unbegrenzt und ist für einen
Ersteinstieg nicht empfohlen.

## Technische Vertiefung

### Leitfrage

Welche Vector-Indizes sind im gewählten Scope sichtbar, welche aktuelle
Wartungsevidenz liefert SQL Server dazu, und welche Quelle ist vollständig
verfügbar?

### Technischer Hintergrund

Die Katalogsicht erbt die öffentlichen Indexspalten aus `sys.indexes` und
ergänzt Vector-Indextyp sowie Distanzmetrik. Die Runtime-DMV liefert
ungefähre Staleness, Key-Space-Nutzung und den letzten Hintergrundtask. Die
Procedure liest ausdrücklich keine internen `build_parameters`.

### Datenkette

Produktversion und Systemobjektschema werden zuerst geprüft. Danach wird
`sys.vector_indexes` einmal je Zieldatenbank in eine lokale Evidenztabelle
materialisiert. `sys.dm_db_vector_indexes` wird ebenfalls einmal gelesen und
lokal über `DatabaseId`, `ObjectId` und `IndexId` korreliert. Sämtliche
Ausgabearten projizieren dieselben lokalen Tabellen.

### Source Select

Das folgende verkürzte Grundmuster zeigt die fachliche Korrelation:

```sql
SELECT
      [v].[object_id]
    , [v].[index_id]
    , [v].[vector_index_type]
    , [v].[distance_metric]
    , [d].[approximate_staleness_percent]
    , [d].[last_background_task_succeeded]
FROM [sys].[vector_indexes] AS [v]
LEFT JOIN [sys].[dm_db_vector_indexes] AS [d]
  ON [d].[object_id]=[v].[object_id]
 AND [d].[index_id]=[v].[index_id];
```

**Wichtig für die Eigenlast:** Die Frameworkprocedure liest die beiden Quellen
nicht mit diesem kombinierten Beispiel mehrfach, sondern materialisiert jede
Quelle höchstens einmal pro Datenbank und Aufruf. Katalogfilter und
`@MaxZeilen` begrenzen Scope beziehungsweise Ausgabe.

### Zeit- und Scope-Modell

`CapturedAtUtc` ist der aufrufweite Erfassungszeitpunkt. Katalog und DMV werden
nicht in einer transaktionalen Momentaufnahme gelesen. Die Runtimewerte sind
aktuell und flüchtig; die Procedure persistiert keinen Verlauf.

### Bewertung und Gegenprobe

Staleness sollte über mehrere Zeitpunkte mit DML-Rate, Taskstatus sowie
messbarem Recall und Suchlaufzeit korreliert werden. Objektgröße und allgemeiner
Indexbestand lassen sich anschließend über `USP_ObjectAnalysis` gegenprüfen.

### Typische Fehlinterpretation

`VECTOR_STALENESS_REVIEW` bedeutet nicht „Index rebuilden“. Der
Standardgrenzwert von 15 Prozent ist ein konfigurierbarer Reviewauslöser, kein
universeller Qualitätsgrenzwert.

### Folgeanalyse

`USP_ObjectAnalysis` ergänzt Objekt- und Indexkontext. Der
`USP_SpecialFeatureInventory`-Pfad eignet sich davor als leichte Inventur
nativer Vector-Spalten.

## Primärquellen

- [sys.vector_indexes](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-vector-indexes-transact-sql?view=sql-server-ver17)
- [sys.dm_db_vector_indexes](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-vector-indexes-transact-sql?view=sql-server-ver17)
- [CREATE VECTOR INDEX und SQL-Server-2025-Previewvoraussetzung](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-vector-index-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../../Architecture/SQL_Server_2025_Vector_Index_Analysis.md)  
[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)
