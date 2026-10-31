# [monitor].[USP_ObjectAnalysis]

**Bereich:** Object und Index, Orchestrator<br>
**Zweck:** Orchestriert Inventar, Usage, Missing Indexes und optionale Tiefenmodule; das bestehende Inventar enthält capability-adaptive SQL-Server-2025-JSON-Indexmetadaten.<br>
**Beobachtungsart:** nicht atomarer Mix aus Katalog, kumulativen Zählern und optionalem physischem Scan<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche objektbezogenen Evidenzpfade sollen für einen Scope gemeinsam ausgeführt werden?** Sie unterstützt die Entscheidung, ob ein Struktur- oder Metadatensignal eine workloadbezogene Gegenprüfung rechtfertigt, nicht ob automatisch DDL ausgeführt werden soll.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen Geschäftsnutzen einer Strukturänderung, keine repräsentative Workload und keine automatische Aussage über den optimalen Index- oder Statistikzustand. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ObjectAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @FullObjectNames = N'[ExampleSchema].[ExampleTable]',
      @MitObjectInventory = 1,
      @MitIndexUsage = 0,
      @MitMissingIndexes = 0,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Der Aufruf aktiviert nur das Objektinventar; Usage und Missing Indexes werden ausdrücklich ausgeschaltet. Aktivieren Sie weitere Teilmodule einzeln, wenn deren zusätzliche Evidenz benötigt wird. Die Filter wählen unterschiedliche Quellen und Zeitbezüge; @MaxZeilen ist dabei je Child und kein Gesamtlimit.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Bracket-aware Pipe-Liste exakter einteiliger Datenbanknamen; &#124; trennt außerhalb von [...], ]] maskiert ], äußere U+0020-Elementleerzeichen werden getrimmt. Max. 128 Zeichen je Name und 4000 UTF-16-Codeeinheiten je Rohsegment; leere/ungültige Elemente und case-sensitive Duplikate sind ungültig. NULL oder leer/nur U+0020-Leerzeichen bedeutet keine exakte Auswahl. Nichtleere Liste ist mit nicht-NULL @DatabaseNamePattern exklusiv. An alle Children weitergereicht; begrenzt GEZIELT allein nicht auf ein Objekt. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | 0 schließt master, model, msdb und tempdb aus; 1 lässt sie zusätzlich zur Childauswahl zu. NULL wird von der Datenbankauswahl als INVALID_PARAMETER behandelt. Andere zu bit konvertierbare Zahlen werden beim Binden auf 0/1 abgebildet. An alle Children weitergereicht; Sichtbarkeit/Berechtigungen bleiben Voraussetzung. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Optionales Datenbanknamen-Pattern. NULL deaktiviert es; leer/nur U+0020-Leerzeichen und leeres Präfixergebnis sind ungültig. Äußere U+0020-Leerzeichen vor Präfixerkennung getrimmt, danach nicht erneut. Ohne Präfix oder like: SQL-LIKE mit %, _ und [...]; regex: Flag c, regexi: Flag i; Präfixerkennung case-insensitive. Mit nichtleerer @DatabaseNames-Liste exklusiv. Regex wird im Auswahlpfad geprüft und erfordert SQL Server 2025 plus Compatibility Level 170 im Installationsdatenbankkontext. An alle Children weitergegeben. |
| `@HighImpactConfirmed` | `bit` | `0` | 0 bestätigt keine Deep-Analyse; 1 erfüllt nur ein vom jeweils aktivierten Child verlangtes Bestätigungsflag und gewährt keine Berechtigung. NULL wird in der Datenbankauswahl als INVALID_PARAMETER behandelt; sonstige zu bit konvertierbare Werte bilden beim Binden 0/1. An alle Children weitergegeben; @Vollanalyse ersetzt kein Childgate. |
| `@SchemaNames` | `nvarchar(max)` | `NULL` | Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Bracket-aware Pipe-Liste exakter einteiliger Schemanamen, mit &#124; außerhalb von [...], ]] als Maskierung und an U+0020 getrimmten Elementen. Max. 128 Zeichen je Name/4000 UTF-16-Codeeinheiten je Rohsegment; leere/ungültige Namen und case-sensitive Duplikate ungültig. NULL bedeutet kein Filter; leerer Nicht-NULL-Wert ungültig. Exklusiv mit @SchemaNamePattern; bei nicht-NULL @FullObjectNames unzulässig. An objekteigene Children außer SchemaDesign weitergereicht; GEZIELT braucht einen passenden Objektfilter. |
| `@SchemaNamePattern` | `nvarchar(4000)` | `NULL` | Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Pattern für Schemanamen. NULL deaktiviert; leer/nur U+0020-Leerzeichen/leeres Präfix ungültig. Zuerst äußere U+0020-Leerzeichen trimmen, Präfix case-insensitive erkennen, nach Entfernen nicht erneut trimmen. Ohne Präfix/like: SQL-LIKE (%, _, [...]); regex: Flag c; regexi: Flag i. Regex läuft in Quelldatenbank und benötigt SQL Server 2025/Compatibility Level 170; für diesen Feldfilter keine separate Vorprüfung, Childfehler können je DB isoliert sein. Exklusiv mit nicht-NULL @SchemaNames. An objekteigene Children außer SchemaDesign weitergereicht. |
| `@ObjectNames` | `nvarchar(max)` | `NULL` | Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Bracket-aware Pipe-Liste exakter einteiliger Objektnamen. &#124; trennt außerhalb [...], ]] maskiert ], Elemente getrimmt; max. 128 Zeichen/Name und 4000 UTF-16-Codeeinheiten/Rohsegment. NULL = kein Filter; leer/ungültig oder case-sensitive Duplikate ungültig. Nicht mit @ObjectNamePattern oder nicht-NULL @FullObjectNames kombinieren. An objekteigene Children außer SchemaDesign weitergereicht. GEZIELT erfordert außerdem @SchemaNames oder @FullObjectNames. |
| `@ObjectNamePattern` | `nvarchar(4000)` | `NULL` | Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Pattern für Objektnamen; NULL deaktiviert, leer/nur U+0020-Leerzeichen/leeres Präfix ungültig. Äußere U+0020-Leerzeichen trimmen, Präfix case-insensitive erkennen, danach nicht erneut trimmen. Ohne Präfix/like: SQL-LIKE (%, _, [...]); regex: c; regexi: i. Regex benötigt SQL Server 2025/Compatibility Level 170 in Quelldatenbank; keine separate Vorprüfung für Feldfilter, mögliche Childfehler je DB. Exklusiv mit nicht-NULL @ObjectNames. An objekteigene Children außer SchemaDesign; ersetzt GEZIELT nicht dessen nötige Scopeform. |
| `@FullObjectNames` | `nvarchar(max)` | `NULL` | Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Bracket-aware Pipe-Liste von Objekt, Schema.Objekt oder Datenbank.Schema.Objekt; beim Datenbankteil ist Schema erforderlich, vier Teile unzulässig. &#124; trennt außerhalb [...], ]] maskiert ], Elemente getrimmt. NULL = kein Filter; leere Liste/Leerzeilenelement ungültig; max. 4000 UTF-16-Codeeinheiten/Rohsegment; Bestandteile werden per PARSENAME/sysname geprüft. Case-sensitive Duplikate ungültig. Bei nicht-NULL @SchemaNames oder @ObjectNames unzulässig (auch leer). An objekteigene Children außer SchemaDesign weitergereicht. |
| `@IndexNames` | `nvarchar(max)` | `NULL` | Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Bracket-aware Pipe-Liste exakter einteiliger Indexnamen; &#124; außerhalb [...], ]] maskiert ], Elemente getrimmt. NULL deaktiviert; leer/nur U+0020-Leerzeichen, ungültige/überlange Namen, Rohsegmente über 4000 UTF-16-Codeeinheiten und case-sensitive Duplikate ungültig. Nicht mit nicht-NULL @IndexNamePattern kombinieren. Nur an Operational Stats, Physical Stats und Vector Index Analysis weitergereicht. |
| `@IndexNamePattern` | `nvarchar(4000)` | `NULL` | Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Optionales Indexnamen-Pattern; NULL deaktiviert; leer/nur U+0020-Leerzeichen/leeres Präfix ungültig. Äußere U+0020-Leerzeichen trimmen, Präfix case-insensitive erkennen, danach nicht erneut trimmen. Ohne Präfix/like: SQL-LIKE (%, _, [...]); regex: c; regexi: i. Regex benötigt SQL Server 2025/Compatibility Level 170 in Quelldatenbank; keine separate Vorprüfung für Feldfilter. Exklusiv mit nicht-NULL @IndexNames. Nur Operational/Physical Stats erhalten es, nicht Vector Analysis. |
| `@StatisticsNames` | `nvarchar(max)` | `NULL` | Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Bracket-aware Pipe-Liste exakter einteiliger Statistiknamen; &#124; außerhalb [...], ]] maskiert ], Elemente getrimmt. NULL = kein Filter; leer/ungültig, Namen über sysname-Grenze, Rohsegmente über 4000 UTF-16-Codeeinheiten und case-sensitive Duplikate ungültig. Exklusiv mit nicht-NULL @StatisticsNamePattern. Nur Statistics und StatisticsDistributionAnalysis erhalten es. |
| `@StatisticsNamePattern` | `nvarchar(4000)` | `NULL` | Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Optionales Statistiknamen-Pattern; NULL deaktiviert; leer/nur U+0020-Leerzeichen/leeres Präfix ungültig. Äußere U+0020-Leerzeichen trimmen, Präfix case-insensitive erkennen, nach Entfernen nicht erneut trimmen. Ohne Präfix/like SQL-LIKE (%, _, [...]); regex c; regexi i. Regex benötigt SQL Server 2025/Compatibility Level 170 in Quelldatenbank; keine separate Feldvorprüfung. Exklusiv mit nicht-NULL @StatisticsNames. Nur Statistics und StatisticsDistributionAnalysis erhalten es. |
| `@Vollanalyse` | `bit` | `0` | 0 übergibt GEZIELT, 1 VOLL an Children mit Analysemodusparameter; NULL fällt durch CASE ELSE auf GEZIELT. Andere zu bit konvertierbare Zahlen werden auf 0/1 gebunden. Schaltet keine Children selbst ein: jedes läuft nur bei seinem @Mit*-Flag = 1. VOLL kann Childumfang/Analyseklasse ändern; Childgates und HighImpact-Bestätigung bleiben. Children ohne Analysemodusparameter erhalten keinen Moduswert. |
| `@MitObjectInventory` | `bit` | `1` | 0 oder NULL überspringt USP_ObjectInventory; 1 ruft es auf (sonstige zu bit konvertierbare Werte beim Binden 0/1). Übergibt Datenbank-, Schema-, Objekt-/FullObject-Filter, Modus, MaxZeilen, Lock und Ausgabe-/JSON-/Meldungsflags. JSON-/SQL-JSON-Pfadmetadaten gehören zum bestehenden Inventarcharakter. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet. |
| `@MitIndexUsage` | `bit` | `1` | 0 oder NULL überspringt USP_IndexUsage; 1 ruft es auf (Bit-Konvertierung wie SQL Server). Übergibt gemeinsame Datenbank-/Objektfilter, GEZIELT/VOLL, MaxZeilen, Lock und Ausgabeoptionen; Indexnamenfilter werden nicht übergeben. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet. |
| `@MitMissingIndexes` | `bit` | `1` | 0 oder NULL überspringt USP_MissingIndexes; 1 ruft es auf (Bit-Konvertierung wie SQL Server). Übergibt Datenbank-/Objektfilter, HighImpact-Bestätigung, MaxZeilen, Lock und Ausgabeoptionen; kein Analysemodus sowie keine Index-/Statistiknamenfilter. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet. |
| `@MitOperationalStats` | `bit` | `0` | 0 oder NULL überspringt USP_IndexOperationalStats; 1 ruft es auf. Übergibt gemeinsame Filter sowie @IndexNames/@IndexNamePattern, Analysemodus, MaxZeilen, Lock und Ausgabeoptionen. Childgate und Kosten bleiben separat. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet. |
| `@MitStatistics` | `bit` | `0` | 0 oder NULL überspringt USP_Statistics; 1 ruft es auf. Übergibt gemeinsame Filter sowie @StatisticsNames/@StatisticsNamePattern, Analysemodus, MaxZeilen, Lock und Ausgabeoptionen; Childgate bleibt separat. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet. |
| `@MitStatisticsDistribution` | `bit` | `0` | 0 oder NULL überspringt USP_StatisticsDistributionAnalysis; 1 ruft es auf. Übergibt gemeinsame Filter, Statistiknamenfilter, Analysemodus, MaxZeilen, Lock, Ausgabeoptionen und Status/Partialität/Fehlerdaten per OUTPUT. Childgate bleibt separat; der Schalter begrenzt keine Histogrammarbeit. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet. |
| `@MitPartitions` | `bit` | `0` | 0 oder NULL überspringt USP_Partitions; 1 ruft es auf. Übergibt gemeinsame Datenbank-/Objektfilter, Analysemodus, MaxZeilen, Lock und Ausgabeoptionen; keine Index-/Statistiknamenfilter. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet. |
| `@MitColumnstore` | `bit` | `0` | 0 oder NULL überspringt USP_Columnstore; 1 ruft es auf. Übergibt gemeinsame Datenbank-/Objektfilter, Analysemodus, MaxZeilen, Lock und Ausgabeoptionen; childinterne Tiefenschalter behalten ihre Childdefaults/Gates. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet. |
| `@MitPhysicalStats` | `bit` | `0` | 0 oder NULL überspringt USP_IndexPhysicalStats; 1 ruft es auf. Übergibt gemeinsame Filter, Indexnamenliste/-pattern, Analysemodus, MaxZeilen, Lock und Ausgabeoptionen. Scanmodus und Childgate bestimmt der Childvertrag, nicht dieser Wrapper. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet. |
| `@MitVectorIndexes` | `bit` | `0` | 0 oder NULL überspringt USP_VectorIndexAnalysis; 1 ruft es auf. Übergibt gemeinsame Datenbank-/Objektfilter, @IndexNames (kein Pattern), MaxZeilen, Lock, Ausgabeoptionen und Status/Partialität/Fehlerdaten per OUTPUT; kein Analysemodus. Child meldet Versionsverfügbarkeit explizit. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet. |
| `@MitSchemaDesign` | `bit` | `0` | 0 oder NULL überspringt USP_SchemaDesignAnalysis; 1 ruft es auf. Übergibt nur Datenbankauswahl, Systemdatenbankflag, DB-Pattern, HighImpact-Bestätigung, MaxZeilen, Ausgabeoptionen und Status/Partialität/Fehlerdaten per OUTPUT. Keine Schema-/Objekt-/Index-/Statistikfilter, kein Analysemodus/Lock; Objektfilter engen dieses Child nicht ein. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet. |
| `@MaxZeilen` | `int` | `2000` | Nichtnegative int-Eingabe von 0 bis 2147483647; negative Werte ergeben INVALID_PARAMETER. NULL besteht den Wrappertest @MaxZeilen &lt; 0 und wird weitergereicht; alle elf Empfänger behandeln 0 und NULL als unbegrenzt. Positive Werte gelten je Child/Quellabfrage, nicht als Gesamtlimit oder Grenze der Wrapper-/Modulstatuszeilen. ObjectInventory, IndexUsage (Rowstore/XTP getrennt), MissingIndexes, OperationalStats, PhysicalStats, Partitions und Statistics begrenzen Daten je Datenbank beziehungsweise Haupt-/Detailabfrage; Columnstore begrenzt je relevante Ergebnismenge und Datenbank. StatisticsDistribution begrenzt fertige Findings sowie Verteilungs-/Partitionsvariationszeilen, nicht Kandidaten oder Histogrammschritte. Vector begrenzt vectorIndexes, maintenance und findings jeweils separat nur in RAW/JSON; SchemaDesign begrenzt priorisierte Findings nur in RAW/JSON, nicht Warnungen. CONSOLE und TABLE übergeben den Children NONE und zeigen beziehungsweise schreiben ausschließlich Wrapper-Modulstatus; angefordertes Child-JSON bleibt nach den jeweiligen Grenzen begrenzt. Kein Limit garantiert begrenzte Quell-/DMF-Arbeit oder Gesamtdauer. |
| `@LockTimeoutMs` | `int` | `0` | Millisekunden, Wertebereich 0–60000 (0 fordert NOWAIT an); NULL besteht NOT BETWEEN durch Dreifachlogik und ist hier nicht als ungültig erkannt. Weitergabe an Children mit Lockparameter; SchemaDesign erhält keinen Lockwert. Wrapper setzt LOCK_TIMEOUT vor Childlauf und stellt zuvor gespeicherten Wert vor Ausgabe wieder her. Für NULL keinen bestimmten Timeout aus dem dynamischen NULL-Batch ableiten. Begrenzt Wartezeit, nicht CPU/I/O/Gesamtdauer. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Nach LTRIM/RTRIM von U+0020-Leerzeichen und UPPER gelten genau CONSOLE, RAW, TABLE oder NONE; NULL, leer und andere Texte sind INVALID_PARAMETER. CONSOLE gibt ausschließlich eine lesbare Modulstatusansicht aus, bei leerer Quelle eine Leerzeile; keine normalen Wrapperstatus-/Modulstatusresultsets, Children erhalten NONE. RAW gibt die RAW-Resultsets aktivierter Children und die beiden abschließenden Wrapperresultsets Status und Modulstatus aus; Childzahl und Struktur sind unterschiedlich. TABLE schreibt ausschließlich moduleStatus in das gemappte Ziel; Children erhalten NONE und es gibt keine normalen Resultsets. NONE unterdrückt Resultsets. JSON wird unabhängig per @JsonErzeugen gesteuert, Meldungen separat. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur TABLE: gültiges JSON-Objekt mit genau erlaubtem case-sensitive Schlüssel moduleStatus und Stringwert für vorhandene, leere lokale #Temp-Tabelle; keine ##Temp/#Monitor*-Ziele, max. 116 Zeichen, genau eine Seed-Spalte. Zielzuordnung wird vor Children und auch vor @Hilfe geprüft. Bei Nicht-TABLE löst ein nichtleerer, nicht nur aus Leerraum bestehender Wert THROW 51011 aus; NULL/leer/Leerraum zulässig. |
| `@JsonErzeugen` | `bit` | `0` | 0 oder NULL erzeugt weder Wrapper- noch Child-JSON. 1 fordert JSON aller aufgerufenen Children an und assembliert unabhängig von @ResultSetArt das Wrapperobjekt mit meta, moduleStatus und elf benannten Childfeldern; nicht erzeugte Childpayloads bleiben JSON null. @Hilfe=1 kehrt vor Childaufrufen und JSON-Assembly zurück, nachdem @Json auf NULL gesetzt und ggf. das TABLE-Mapping vorgeprüft wurde. Der gleiche Schalter wird unverändert weitergereicht; es gibt keinen getrennten Child-JSON-Schalter. Ohne JSON fehlt ObjectInventory, IndexUsage, MissingIndexes, OperationalStats, Statistics, Partitions, Columnstore und PhysicalStats die vom Wrapper gelesene JSON-Statusquelle: ihre Modulstatuswerte fallen auf EXECUTED zurück und belegen keinen bestimmten Childstatus. StatisticsDistribution, Vector und SchemaDesign liefern Status über OUTPUT. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden bit 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfang, etwa @Json=@Payload OUTPUT mit einer nvarchar(max)-Variablen. Der Eingabewert wird beim Eintritt auf NULL gesetzt. Im normalen Pfad mit @JsonErzeugen=1 enthält das Objekt meta, moduleStatus sowie objectInventory, indexUsage, missingIndexes, indexOperationalStats, statistics, statisticsDistribution, partitions, columnstore, indexPhysicalStats, vectorIndexAnalysis und schemaDesign. Nicht erzeugte Childpayloads sind JSON null. Andernfalls, auch bei früher Hilfe-Rückkehr, bleibt der Wert NULL. Ohne OUTPUT-Bindung wird kein Wert empfangen. Die Statusaussagegrenzen ohne Child-JSON stehen bei @JsonErzeugen. |
| `@PrintMeldungen` | `bit` | `1` | 0 oder NULL unterdrückt Wrapperwarnung; 1 sendet bei Status ungleich AVAILABLE eine Severity-10-RAISERROR-Meldung mit NOWAIT. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1. An Children weitergereicht; steuert weder Resultsets noch Childstatus. |
| `@Hilfe` | `bit` | `0` | 0 führt zu aktivierten Children; 1 gibt eingebaute PRINT-Zeilen aus und kehrt vor Childaufrufen, Datenbankauswahl und Facherhebung zurück. @Json ist davor bereits NULL. Bei TABLE läuft Mapping-Preflight davor und kann abbrechen. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1; NULL aktiviert den Hilfepfad nicht. |

### RAW

```sql
EXEC [monitor].[USP_ObjectAnalysis]
      @DatabaseNames = N'[ExampleDatabase]'
    , @FullObjectNames = N'[ExampleSchema].[ExampleTable]'
    , @MitObjectInventory = 1
    , @MitIndexUsage = 0
    , @MitMissingIndexes = 0
    , @ResultSetArt = 'RAW';
```

### JSON unabhängig von der Resultsetart

```sql
DECLARE @ObjectAnalysisJson nvarchar(max);
EXEC [monitor].[USP_ObjectAnalysis]
      @DatabaseNames = N'[ExampleDatabase]'
    , @FullObjectNames = N'[ExampleSchema].[ExampleTable]'
    , @MitObjectInventory = 1
    , @MitIndexUsage = 0
    , @MitMissingIndexes = 0
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @ObjectAnalysisJson OUTPUT;
SELECT @ObjectAnalysisJson AS [ObjectAnalysisJson];
```

### TABLE: nur Modulstatus in ein lokales Ziel schreiben

```sql
IF OBJECT_ID(N'tempdb..#ObjectAnalysis_HelpExample') IS NOT NULL
    DROP TABLE [#ObjectAnalysis_HelpExample];
CREATE TABLE [#ObjectAnalysis_HelpExample] ([Seed] bit NULL);
BEGIN TRY
    EXEC [monitor].[USP_ObjectAnalysis]
          @DatabaseNames = N'[ExampleDatabase]'
        , @FullObjectNames = N'[ExampleSchema].[ExampleTable]'
        , @MitObjectInventory = 1
        , @MitIndexUsage = 0
        , @MitMissingIndexes = 0
        , @ResultSetArt = 'TABLE'
        , @ResultTablesJson = N'{"moduleStatus":"#ObjectAnalysis_HelpExample"}';
END TRY
BEGIN CATCH
    IF OBJECT_ID(N'tempdb..#ObjectAnalysis_HelpExample') IS NOT NULL
        DROP TABLE [#ObjectAnalysis_HelpExample];
    THROW;
END CATCH;
SELECT * FROM [#ObjectAnalysis_HelpExample];
DROP TABLE [#ObjectAnalysis_HelpExample];
```

### Eingebaute Hilfe

```sql
EXEC [monitor].[USP_ObjectAnalysis] @Hilfe = 1;
```

## Resultsets und Leserichtung

TABLE schreibt ausschließlich das typisierte Wrapperresultset `moduleStatus` in das benannte lokale Ziel. CONSOLE gibt nur eine lesbare Modulstatusansicht aus; aktivierte Children erhalten dabei NONE. RAW gibt die RAW-Ausgaben der aktivierten Children und die beiden abschließenden Wrapperresultsets Status und Modulstatus aus. JSON wird im normalen Pfad unabhängig davon mit @JsonErzeugen erstellt; Hilfe kehrt davor zurück. Ohne Child-JSON fallen die Modulstatuswerte von ObjectInventory, IndexUsage, MissingIndexes, OperationalStats, Statistics, Partitions, Columnstore und PhysicalStats auf EXECUTED zurück. Diese Rückfallkennung belegt keinen bestimmten Childstatus; StatisticsDistribution, Vector und SchemaDesign liefern Status über OUTPUT. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Die Granularität hängt vom Child ab: Objekt/Index, Indexpartition, Statistik, Rowgroup, Partition oder Finding.

## So lesen

Prüfen Sie zuerst den Childstatus. Folgen Sie danach der Reihenfolge Inventar → Nutzung → konkrete Tiefenanalyse. Interpretieren Sie Befunde verschiedener Children gemeinsam, aber nicht als identische Zeilen.

## Warum kann das problematisch sein?

Ein Missing-Index-Vorschlag ohne Inventar kann Redundanz erzeugen; Fragmentierung ohne Page Count kann unnötige Wartung auslösen.

## Wann ist es kein Problem?

Nicht aktivierte Teilmodule werden nicht aufgerufen und erzeugen keine Modulstatuszeile. Das unterscheidet sie von aktivierten Children, deren Status etwa UNAVAILABLE_VERSION, NOT_APPLICABLE oder ERROR_HANDLED meldet. Bei acht Empfängern kann ein fachlicher Childstatus nur aus angefordertem JSON übernommen werden; ohne JSON meldet ihre Modulstatuszeile EXECUTED.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Inventar zeigt ähnlichen Index, Missing Index schlägt einen neuen vor, Usage zeigt geringe Nutzung: eher Konsolidierung prüfen als blind erstellen. Wiederholen Sie Relevantes Child mit engem Scope.

**Ähnlich aussehender Gegenfall:** Nicht aktivierte Teilmodule werden nicht aufgerufen und erzeugen keine Modulstatuszeile. Das unterscheidet sie von aktivierten Children, deren Status etwa UNAVAILABLE_VERSION, NOT_APPLICABLE oder ERROR_HANDLED meldet. Bei acht Empfängern kann ein fachlicher Childstatus nur aus angefordertem JSON übernommen werden; ohne JSON meldet ihre Modulstatuszeile EXECUTED. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Bei Katalogpfaden sind Featureabwesenheit, Filter, Offline-/Permission-Scope und tatsächlich fehlende Objekte getrennte Erklärungen.

Für `USP_ObjectAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | `GEZIELT` mit Objektinventar, Index Usage und Missing Indexes. Ohne Objektfilter kann auch dieser Default viele Datenbanken/Katalogobjekte berühren; „gezielt“ bezeichnet den Childmodus, nicht automatisch einen engen Eingabescope. |
| Teuerster Pfad | Eine Kombination aus VOLL-Modus und ausdrücklich aktivierten tiefen Children wie Statistikverteilung, Columnstore, Physical Stats und Vector Index Analysis kann Kataloge/DMVs wiederholt lesen, Histogramme zerlegen oder physische Scans ausführen. @Vollanalyse aktiviert die elf Children nicht selbst; @MaxZeilen ist keine Gesamtgrenze. |
| Haupttreiber | Zahl der ausgewählten Datenbanken, Objekte, Indizes, Statistiken und Partitionen; bei Physical Stats zusätzlich Seitenzahl/Scanmodus, bei Statistikverteilung Kandidatenzahl und bis zu 200 Histogrammschritte je Statistik. |
| Skalierung | Children laufen sequenziell und teilen keinen Katalogsnapshot. Dieselben Objekte werden für Inventar, Usage, Operational Stats, Statistics, Partitionen, Columnstore und Design jeweils neu aufgelöst; VOLL vergrößert Scope und Detailarbeit. |
| Ressourcen | Datenbankkatalog- und DMV-CPU, Metadaten-I/O, Arbeitsspeicher/TempDB für Gruppierung sowie optional physischer Indexscan und Histogrammabruf. Kein `msdb`, XEL- oder Samplingpfad. |
| Begrenzungswirkung | `@MaxZeilen` wird an jedes Child übergeben, ist aber kein Gesamtlimit. Je Child kann es früh Kandidaten, erst eine sortierte Ausgabe oder nur den Transfer begrenzen; besonders SchemaDesign scannt den Katalog vor dem Limit. `@LockTimeoutMs` begrenzt Wartezeit, nicht CPU, I/O oder Gesamtdauer. |
| Locking und Nebenwirkungen | Read-only, aber Katalog- und Physical-Stats-Zugriffe können mit DDL konkurrieren. Die Children laufen nicht atomar; Objekt- oder Indexdefinitionen können sich zwischen Resultsets ändern. Der angeforderte `LOCK_TIMEOUT` gilt für den Childlauf; anschließend wird der vorherige Sessionwert wiederhergestellt. |
| Schutzmechanismus | Jedes Child hat einen eigenen @Mit*-Schalter; aktivierte Children behalten ihre Analyseklassen und Gates. @HighImpactConfirmed wird weitergereicht, ist aber weder Berechtigung noch Mengenlimit. @MitSchemaDesign erhält keine Objektfilter, daher begrenzt ein FullObjectNames-Scope dieses Child nicht. |
| Sicherer Einsatz | Eine Datenbank und ein vollständiger Objektname; zunächst nur ein benötigtes Child aktivieren. @MaxZeilen begrenzt den Childauszug gemäß dessen Vertrag, nicht zwingend die geleistete Arbeit oder die Gesamtausgabe. Danach anhand des Childstatus weitere Pfade gezielt ergänzen. |
| Aussagegrenze | Die Resultsets kombinieren aktuelle Katalogstruktur, seit Restart kumulative DMVs und optionale physische Momentaufnahmen. Gemeinsame Namen bedeuten nicht gemeinsamen Messzeitpunkt; Limits können pro Child andere Objekte sichtbar machen. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche objektbezogenen Evidenzpfade sollen für einen Scope gemeinsam ausgeführt werden?

### Technischer Hintergrund

Der Orchestrator kombiniert Definition, Usage, Operations, Missing Indexes, Statistics, Partitions, Columnstore sowie optional Physical Stats und Vector-Index-Wartung. Jedes Child behält eigene Quelle, Kosten und Resetsemantik. SQL25-002 benötigt keinen neuen Schalter: Wenn `@MitObjectInventory = 1` und `@MitIndizes = 1` gelten, enthält der vorhandene Childvertrag die versions- und capability-adaptiven JSON-Index-/Pfadfelder.

### Datenkette

Die Datenkette besteht aus frameworkinterner Orchestrierung; die Quellen liegen in den aufgerufenen Childmodulen.

### Source Select

Kein einzelnes Grundselect wird verwendet. Die Procedure orchestriert je nach Schalter `USP_ObjectInventory`, `USP_IndexUsage`, `USP_MissingIndexes`, `USP_IndexOperationalStats`, `USP_Statistics`, `USP_StatisticsDistributionAnalysis`, `USP_Partitions`, `USP_Columnstore`, `USP_IndexPhysicalStats`, `USP_VectorIndexAnalysis` und `USP_SchemaDesignAnalysis`.

**Wichtig für die Eigenlast:** Reichen Sie Datenbank und vollständigen Objektnamen an alle Childmodule weiter und aktivieren Sie nur benötigte Tiefenpfade. Das abschließende Zeilenlimit ersetzt weder den DMF-Objektparameter noch den frühen Katalogscope.

### Zeit- und Scope-Modell

Die Auswertung kombiniert Metadaten, kumulative Zähler und aufrufbezogene physische Scans nicht atomar.

### Bewertung und Gegenprobe

Korrelieren Sie zuerst Childstatus und Kostenoptionen, danach Befunde nach Objekt/Index. Widersprüche sind möglich, etwa Missing-Index-Evidenz neben einem ähnlichen ungenutzten Index.

### Typische Fehlinterpretation

Die Zusammenfassung ist keine DDL-Liste. Ein Childfehler darf nicht als unauffälliges Objekt gelten.

### Folgeanalyse

Führen Sie je Befund das spezialisierte Child mit engem Scope erneut aus. `@MitVectorIndexes = 1` ruft das versionsadaptive Child auf; dessen Status wird in moduleStatus aufgenommen. Auf nicht unterstützten Versionen dokumentiert das Child die Verfügbarkeit, statt dass der Wrapper dies als erfolgreiche Analyse auslegt. JSON-Indexmetadaten werden dagegen über `USP_ObjectInventory` geroutet; Indexpräsenz und Pfadzahl sind keine automatische Health- oder DDL-Empfehlung.

## Primärquellen

- [SQL-Server-Katalogsichten](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/catalog-views-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../03_Object_Index.md#12-monitorusp_objectanalysis)

[SQL-Server-2025-JSON-Index-Vertrag](../../Architecture/SQL_Server_2025_JSON_Index_Inventory.md)
