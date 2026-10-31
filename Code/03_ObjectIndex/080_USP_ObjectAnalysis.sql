USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ObjectAnalysis
Version      : 2.4.0
Stand        : 2026-07-23
Typ          : Stored Procedure
Zweck        : Orchestriert die Objekt-, Index-, Statistik-, Partition-,
               Columnstore-, Vector-Index- und Physical-Stats-Analysen mit
               einem einheitlichen Listen-, Pattern- und Ausgabevertrag.
               Das ObjectInventory ergänzt capability-adaptiv sichtbare
               SQL-Server-2025-JSON-Indizes und deren SQL/JSON-Pfade.
SQL-Version  : SQL Server 2019 oder neuer.
Parameter    : Filter, elf unabhängige @Mit*-Schalter, @Vollanalyse,
               @MaxZeilen, @LockTimeoutMs, Ausgabe-/JSON-Optionen und @Hilfe.
Semantik     : Exakte Listen sind bracket-aware Pipe-Listen; Pattern sind
               einzelne LIKE-/Regex-Ausdrücke. Exaktliste und Pattern derselben
               Eigenschaft schließen einander aus; @FullObjectNames ist zu
               separaten Schema-/Objektlisten exklusiv.
Ausgabe      : RAW liefert Wrapperstatus, Modulstatus und Child-RAW-Ausgaben;
               CONSOLE liefert ausschließlich eine lesbare Modulstatusansicht; TABLE schreibt nur moduleStatus; NONE
               unterdrückt Resultsets. @JsonErzeugen erstellt im normalen Pfad unabhängig davon
               meta, moduleStatus und benannte Child-Envelopes in @Json.
               Ohne Child-JSON fallen acht Modulstatuswerte auf EXECUTED zurück;
               diese Kennung belegt keinen bestimmten fachlichen Childstatus.
Locking      : Der Wrapper setzt den angeforderten LOCK_TIMEOUT vor dem
               Childlauf und stellt den zuvor gespeicherten Wert vor der eigenen
               Ausgabe wieder her. @MitSchemaDesign erhält keinen Lockwert.
Änderungen   : 2.4.0 - SQL25-002-JSON-Indexmetadaten über das bestehende
                         ObjectInventory in den Orchestratorvertrag aufgenommen.
               2.3.0 - SQL-Server-2025-Vector-Index-Laufzeitanalyse als
                          capability-adaptives opt-in Teilmodul integriert.
               2.2.0 - Begrenzte Statistikverteilungsanalyse als opt-in
                         Teilmodul integriert.
               2.1.0 - Schema-/Designkorrektheit als opt-in Teilmodul.
               2.0.0 - Mehrfachfilter, getrennte Pattern, Cross-Database-Scope,
                         RAW/CONSOLE/NONE und JSON-Orchestrierung.
               1.3.0 - Vorheriger Stand.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ObjectAnalysis]
      @DatabaseNames                    nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen     bit            = 0
    , @DatabaseNamePattern              nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @SchemaNames                      nvarchar(max)  = NULL
    , @SchemaNamePattern                nvarchar(4000) = NULL
    , @ObjectNames                      nvarchar(max)  = NULL
    , @ObjectNamePattern                nvarchar(4000) = NULL
    , @FullObjectNames                  nvarchar(max)  = NULL
    , @IndexNames                       nvarchar(max)  = NULL
    , @IndexNamePattern                 nvarchar(4000) = NULL
    , @StatisticsNames                  nvarchar(max)  = NULL
    , @StatisticsNamePattern            nvarchar(4000) = NULL
    , @Vollanalyse                      bit            = 0
    , @MitObjectInventory               bit            = 1
    , @MitIndexUsage                    bit            = 1
    , @MitMissingIndexes                bit            = 1
    , @MitOperationalStats              bit            = 0
    , @MitStatistics                    bit            = 0
    , @MitStatisticsDistribution        bit            = 0
    , @MitPartitions                    bit            = 0
    , @MitColumnstore                   bit            = 0
    , @MitPhysicalStats                 bit            = 0
    , @MitVectorIndexes                 bit            = 0
    , @MitSchemaDesign                  bit            = 0
    , @MaxZeilen                        int            = 2000
    , @LockTimeoutMs                    int            = 0
    , @ResultSetArt                     varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                     bit            = 0
    , @Json                             nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                   bit            = 1
    , @Hilfe                            bit            = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json = NULL;
    DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT;
    DECLARE @LockTimeoutSql nvarchar(64);

    DECLARE @ResultSetArtNormalisiert varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'moduleStatus',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @AnalyseModus varchar(16) = CASE WHEN @Vollanalyse = 1 THEN 'VOLL' ELSE 'GEZIELT' END;
    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @MonitorPrintMessage nvarchar(2048);

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_ObjectAnalysis';
        PRINT N'monitor.USP_ObjectAnalysis orchestriert bis zu elf Objekt- und Index-Teilmodule; jedes wird nur über seinen eigenen @Mit*-Schalter aktiviert.';
        PRINT N'Listenfilter verwenden bracket-aware Pipe-Listen, Patternfilter eigene LIKE- oder Regex-Ausdrücke; @FullObjectNames ist zu separaten Schema-/Objektlisten exklusiv.';
        PRINT N'@Vollanalyse wählt den an passende Children übergebenen Modus VOLL, aktiviert aber keine zusätzlichen Children und hebt keine Child-Gates auf.';
        PRINT N'@MaxZeilen wird je aktiviertem Child weitergereicht und ist keine Gesamtgrenze. @HighImpactConfirmed bestätigt nur ein erforderliches Child-Gate.';
        PRINT N'@ResultSetArt steuert Wrapper- und Childresultsets; @JsonErzeugen steuert zusätzlich das benannte Wrapper-JSON. TABLE ordnet ausschließlich moduleStatus zu.';
        PRINT N'Ohne JSON können die Modulstatuswerte von acht Children nur EXECUTED lauten; diese Rückfallkennung ist keine Bestätigung ihres fachlichen Status. StatisticsDistribution, Vector und SchemaDesign liefern Status gesondert über OUTPUT.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Bracket-aware Pipe-Liste exakter einteiliger Datenbanknamen; | trennt außerhalb von [...], ]] maskiert ], äußere U+0020-Elementleerzeichen werden getrimmt. Max. 128 Zeichen je Name und 4000 UTF-16-Codeeinheiten je Rohsegment; leere/ungültige Elemente und case-sensitive Duplikate sind ungültig. NULL oder leer/nur U+0020-Leerzeichen bedeutet keine exakte Auswahl. Nichtleere Liste ist mit nicht-NULL @DatabaseNamePattern exklusiv. An alle Children weitergereicht; begrenzt GEZIELT allein nicht auf ein Objekt.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. 0 schließt master, model, msdb und tempdb aus; 1 lässt sie zusätzlich zur Childauswahl zu. NULL wird von der Datenbankauswahl als INVALID_PARAMETER behandelt. Andere zu bit konvertierbare Zahlen werden beim Binden auf 0/1 abgebildet. An alle Children weitergereicht; Sichtbarkeit/Berechtigungen bleiben Voraussetzung.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Optionales Datenbanknamen-Pattern. NULL deaktiviert es; leer/nur U+0020-Leerzeichen und leeres Präfixergebnis sind ungültig. Äußere U+0020-Leerzeichen vor Präfixerkennung getrimmt, danach nicht erneut. Ohne Präfix oder like: SQL-LIKE mit %, _ und [...]; regex: Flag c, regexi: Flag i; Präfixerkennung case-insensitive. Mit nichtleerer @DatabaseNames-Liste exklusiv. Regex wird im Auswahlpfad geprüft und erfordert SQL Server 2025 plus Compatibility Level 170 im Installationsdatenbankkontext. An alle Children weitergegeben.';
        PRINT N'@HighImpactConfirmed bit; Default: 0. 0 bestätigt keine Deep-Analyse; 1 erfüllt nur ein vom jeweils aktivierten Child verlangtes Bestätigungsflag und gewährt keine Berechtigung. NULL wird in der Datenbankauswahl als INVALID_PARAMETER behandelt; sonstige zu bit konvertierbare Werte bilden beim Binden 0/1. An alle Children weitergegeben; @Vollanalyse ersetzt kein Childgate.';
        PRINT N'@SchemaNames nvarchar(max); Default: NULL. Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Bracket-aware Pipe-Liste exakter einteiliger Schemanamen, mit | außerhalb von [...], ]] als Maskierung und an U+0020 getrimmten Elementen. Max. 128 Zeichen je Name/4000 UTF-16-Codeeinheiten je Rohsegment; leere/ungültige Namen und case-sensitive Duplikate ungültig. NULL bedeutet kein Filter; leerer Nicht-NULL-Wert ungültig. Exklusiv mit @SchemaNamePattern; bei nicht-NULL @FullObjectNames unzulässig. An objekteigene Children außer SchemaDesign weitergereicht; GEZIELT braucht einen passenden Objektfilter.';
        PRINT N'@SchemaNamePattern nvarchar(4000); Default: NULL. Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Pattern für Schemanamen. NULL deaktiviert; leer/nur U+0020-Leerzeichen/leeres Präfix ungültig. Zuerst äußere U+0020-Leerzeichen trimmen, Präfix case-insensitive erkennen, nach Entfernen nicht erneut trimmen. Ohne Präfix/like: SQL-LIKE (%, _, [...]); regex: Flag c; regexi: Flag i. Regex läuft in Quelldatenbank und benötigt SQL Server 2025/Compatibility Level 170; für diesen Feldfilter keine separate Vorprüfung, Childfehler können je DB isoliert sein. Exklusiv mit nicht-NULL @SchemaNames. An objekteigene Children außer SchemaDesign weitergereicht.';
        PRINT N'@ObjectNames nvarchar(max); Default: NULL. Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Bracket-aware Pipe-Liste exakter einteiliger Objektnamen. | trennt außerhalb [...], ]] maskiert ], Elemente getrimmt; max. 128 Zeichen/Name und 4000 UTF-16-Codeeinheiten/Rohsegment. NULL = kein Filter; leer/ungültig oder case-sensitive Duplikate ungültig. Nicht mit @ObjectNamePattern oder nicht-NULL @FullObjectNames kombinieren. An objekteigene Children außer SchemaDesign weitergereicht. GEZIELT erfordert außerdem @SchemaNames oder @FullObjectNames.';
        PRINT N'@ObjectNamePattern nvarchar(4000); Default: NULL. Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Pattern für Objektnamen; NULL deaktiviert, leer/nur U+0020-Leerzeichen/leeres Präfix ungültig. Äußere U+0020-Leerzeichen trimmen, Präfix case-insensitive erkennen, danach nicht erneut trimmen. Ohne Präfix/like: SQL-LIKE (%, _, [...]); regex: c; regexi: i. Regex benötigt SQL Server 2025/Compatibility Level 170 in Quelldatenbank; keine separate Vorprüfung für Feldfilter, mögliche Childfehler je DB. Exklusiv mit nicht-NULL @ObjectNames. An objekteigene Children außer SchemaDesign; ersetzt GEZIELT nicht dessen nötige Scopeform.';
        PRINT N'@FullObjectNames nvarchar(max); Default: NULL. Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Bracket-aware Pipe-Liste von Objekt, Schema.Objekt oder Datenbank.Schema.Objekt; beim Datenbankteil ist Schema erforderlich, vier Teile unzulässig. | trennt außerhalb [...], ]] maskiert ], Elemente getrimmt. NULL = kein Filter; leere Liste/Leerzeilenelement ungültig; max. 4000 UTF-16-Codeeinheiten/Rohsegment; Bestandteile werden per PARSENAME/sysname geprüft. Case-sensitive Duplikate ungültig. Bei nicht-NULL @SchemaNames oder @ObjectNames unzulässig (auch leer). An objekteigene Children außer SchemaDesign weitergereicht.';
        PRINT N'@IndexNames nvarchar(max); Default: NULL. Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Bracket-aware Pipe-Liste exakter einteiliger Indexnamen; | außerhalb [...], ]] maskiert ], Elemente getrimmt. NULL deaktiviert; leer/nur U+0020-Leerzeichen, ungültige/überlange Namen, Rohsegmente über 4000 UTF-16-Codeeinheiten und case-sensitive Duplikate ungültig. Nicht mit nicht-NULL @IndexNamePattern kombinieren. Nur an Operational Stats, Physical Stats und Vector Index Analysis weitergereicht.';
        PRINT N'@IndexNamePattern nvarchar(4000); Default: NULL. Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Optionales Indexnamen-Pattern; NULL deaktiviert; leer/nur U+0020-Leerzeichen/leeres Präfix ungültig. Äußere U+0020-Leerzeichen trimmen, Präfix case-insensitive erkennen, danach nicht erneut trimmen. Ohne Präfix/like: SQL-LIKE (%, _, [...]); regex: c; regexi: i. Regex benötigt SQL Server 2025/Compatibility Level 170 in Quelldatenbank; keine separate Vorprüfung für Feldfilter. Exklusiv mit nicht-NULL @IndexNames. Nur Operational/Physical Stats erhalten es, nicht Vector Analysis.';
        PRINT N'@StatisticsNames nvarchar(max); Default: NULL. Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Bracket-aware Pipe-Liste exakter einteiliger Statistiknamen; | außerhalb [...], ]] maskiert ], Elemente getrimmt. NULL = kein Filter; leer/ungültig, Namen über sysname-Grenze, Rohsegmente über 4000 UTF-16-Codeeinheiten und case-sensitive Duplikate ungültig. Exklusiv mit nicht-NULL @StatisticsNamePattern. Nur Statistics und StatisticsDistributionAnalysis erhalten es.';
        PRINT N'@StatisticsNamePattern nvarchar(4000); Default: NULL. Die Namens-/Patterngrammatik prüft erst ein aktivierter Empfänger; ohne betreffenden Empfänger bleibt sie ungeprüft. Die eigenen Kombinationstests des Wrappers gelten unabhängig davon. Optionales Statistiknamen-Pattern; NULL deaktiviert; leer/nur U+0020-Leerzeichen/leeres Präfix ungültig. Äußere U+0020-Leerzeichen trimmen, Präfix case-insensitive erkennen, nach Entfernen nicht erneut trimmen. Ohne Präfix/like SQL-LIKE (%, _, [...]); regex c; regexi i. Regex benötigt SQL Server 2025/Compatibility Level 170 in Quelldatenbank; keine separate Feldvorprüfung. Exklusiv mit nicht-NULL @StatisticsNames. Nur Statistics und StatisticsDistributionAnalysis erhalten es.';
        PRINT N'@Vollanalyse bit; Default: 0. 0 übergibt GEZIELT, 1 VOLL an Children mit Analysemodusparameter; NULL fällt durch CASE ELSE auf GEZIELT. Andere zu bit konvertierbare Zahlen werden auf 0/1 gebunden. Schaltet keine Children selbst ein: jedes läuft nur bei seinem @Mit*-Flag = 1. VOLL kann Childumfang/Analyseklasse ändern; Childgates und HighImpact-Bestätigung bleiben. Children ohne Analysemodusparameter erhalten keinen Moduswert.';
        PRINT N'@MitObjectInventory bit; Default: 1. 0 oder NULL überspringt USP_ObjectInventory; 1 ruft es auf (sonstige zu bit konvertierbare Werte beim Binden 0/1). Übergibt Datenbank-, Schema-, Objekt-/FullObject-Filter, Modus, MaxZeilen, Lock und Ausgabe-/JSON-/Meldungsflags. JSON-/SQL-JSON-Pfadmetadaten gehören zum bestehenden Inventarcharakter. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet.';
        PRINT N'@MitIndexUsage bit; Default: 1. 0 oder NULL überspringt USP_IndexUsage; 1 ruft es auf (Bit-Konvertierung wie SQL Server). Übergibt gemeinsame Datenbank-/Objektfilter, GEZIELT/VOLL, MaxZeilen, Lock und Ausgabeoptionen; Indexnamenfilter werden nicht übergeben. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet.';
        PRINT N'@MitMissingIndexes bit; Default: 1. 0 oder NULL überspringt USP_MissingIndexes; 1 ruft es auf (Bit-Konvertierung wie SQL Server). Übergibt Datenbank-/Objektfilter, HighImpact-Bestätigung, MaxZeilen, Lock und Ausgabeoptionen; kein Analysemodus sowie keine Index-/Statistiknamenfilter. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet.';
        PRINT N'@MitOperationalStats bit; Default: 0. 0 oder NULL überspringt USP_IndexOperationalStats; 1 ruft es auf. Übergibt gemeinsame Filter sowie @IndexNames/@IndexNamePattern, Analysemodus, MaxZeilen, Lock und Ausgabeoptionen. Childgate und Kosten bleiben separat. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet.';
        PRINT N'@MitStatistics bit; Default: 0. 0 oder NULL überspringt USP_Statistics; 1 ruft es auf. Übergibt gemeinsame Filter sowie @StatisticsNames/@StatisticsNamePattern, Analysemodus, MaxZeilen, Lock und Ausgabeoptionen; Childgate bleibt separat. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet.';
        PRINT N'@MitStatisticsDistribution bit; Default: 0. 0 oder NULL überspringt USP_StatisticsDistributionAnalysis; 1 ruft es auf. Übergibt gemeinsame Filter, Statistiknamenfilter, Analysemodus, MaxZeilen, Lock, Ausgabeoptionen und Status/Partialität/Fehlerdaten per OUTPUT. Childgate bleibt separat; der Schalter begrenzt keine Histogrammarbeit. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet.';
        PRINT N'@MitPartitions bit; Default: 0. 0 oder NULL überspringt USP_Partitions; 1 ruft es auf. Übergibt gemeinsame Datenbank-/Objektfilter, Analysemodus, MaxZeilen, Lock und Ausgabeoptionen; keine Index-/Statistiknamenfilter. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet.';
        PRINT N'@MitColumnstore bit; Default: 0. 0 oder NULL überspringt USP_Columnstore; 1 ruft es auf. Übergibt gemeinsame Datenbank-/Objektfilter, Analysemodus, MaxZeilen, Lock und Ausgabeoptionen; childinterne Tiefenschalter behalten ihre Childdefaults/Gates. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet.';
        PRINT N'@MitPhysicalStats bit; Default: 0. 0 oder NULL überspringt USP_IndexPhysicalStats; 1 ruft es auf. Übergibt gemeinsame Filter, Indexnamenliste/-pattern, Analysemodus, MaxZeilen, Lock und Ausgabeoptionen. Scanmodus und Childgate bestimmt der Childvertrag, nicht dieser Wrapper. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet.';
        PRINT N'@MitVectorIndexes bit; Default: 0. 0 oder NULL überspringt USP_VectorIndexAnalysis; 1 ruft es auf. Übergibt gemeinsame Datenbank-/Objektfilter, @IndexNames (kein Pattern), MaxZeilen, Lock, Ausgabeoptionen und Status/Partialität/Fehlerdaten per OUTPUT; kein Analysemodus. Child meldet Versionsverfügbarkeit explizit. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet.';
        PRINT N'@MitSchemaDesign bit; Default: 0. 0 oder NULL überspringt USP_SchemaDesignAnalysis; 1 ruft es auf. Übergibt nur Datenbankauswahl, Systemdatenbankflag, DB-Pattern, HighImpact-Bestätigung, MaxZeilen, Ausgabeoptionen und Status/Partialität/Fehlerdaten per OUTPUT. Keine Schema-/Objekt-/Index-/Statistikfilter, kein Analysemodus/Lock; Objektfilter engen dieses Child nicht ein. NULL entspricht 0; andere zu bit konvertierbare gebundene Zahlenwerte werden auf 0 oder 1 abgebildet.';
        PRINT N'@MaxZeilen int; Default: 2000. Nichtnegative int-Eingabe von 0 bis 2147483647; negative Werte ergeben INVALID_PARAMETER. NULL besteht den Wrappertest @MaxZeilen < 0 und wird weitergereicht; alle elf Empfänger behandeln 0 und NULL als unbegrenzt. Positive Werte gelten je Child/Quellabfrage, nicht als Gesamtlimit oder Grenze der Wrapper-/Modulstatuszeilen. ObjectInventory, IndexUsage (Rowstore/XTP getrennt), MissingIndexes, OperationalStats, PhysicalStats, Partitions und Statistics begrenzen Daten je Datenbank beziehungsweise Haupt-/Detailabfrage; Columnstore begrenzt je relevante Ergebnismenge und Datenbank. StatisticsDistribution begrenzt fertige Findings sowie Verteilungs-/Partitionsvariationszeilen, nicht Kandidaten oder Histogrammschritte. Vector begrenzt vectorIndexes, maintenance und findings jeweils separat nur in RAW/JSON; SchemaDesign begrenzt priorisierte Findings nur in RAW/JSON, nicht Warnungen. CONSOLE und TABLE übergeben den Children NONE und zeigen beziehungsweise schreiben ausschließlich Wrapper-Modulstatus; angefordertes Child-JSON bleibt nach den jeweiligen Grenzen begrenzt. Kein Limit garantiert begrenzte Quell-/DMF-Arbeit oder Gesamtdauer.';
        PRINT N'@LockTimeoutMs int; Default: 0. Millisekunden, Wertebereich 0–60000 (0 fordert NOWAIT an); NULL besteht NOT BETWEEN durch Dreifachlogik und ist hier nicht als ungültig erkannt. Weitergabe an Children mit Lockparameter; SchemaDesign erhält keinen Lockwert. Wrapper setzt LOCK_TIMEOUT vor Childlauf und stellt zuvor gespeicherten Wert vor Ausgabe wieder her. Für NULL keinen bestimmten Timeout aus dem dynamischen NULL-Batch ableiten. Begrenzt Wartezeit, nicht CPU/I/O/Gesamtdauer.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Nach LTRIM/RTRIM von U+0020-Leerzeichen und UPPER gelten genau CONSOLE, RAW, TABLE oder NONE; NULL, leer und andere Texte sind INVALID_PARAMETER. CONSOLE gibt ausschließlich eine lesbare Modulstatusansicht aus, bei leerer Quelle eine Leerzeile; keine normalen Wrapperstatus-/Modulstatusresultsets, Children erhalten NONE. RAW gibt die RAW-Resultsets aktivierter Children und die beiden abschließenden Wrapperresultsets Status und Modulstatus aus; Childzahl und Struktur sind unterschiedlich. TABLE schreibt ausschließlich moduleStatus in das gemappte Ziel; Children erhalten NONE und es gibt keine normalen Resultsets. NONE unterdrückt Resultsets. JSON wird unabhängig per @JsonErzeugen gesteuert, Meldungen separat.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur TABLE: gültiges JSON-Objekt mit genau erlaubtem case-sensitive Schlüssel moduleStatus und Stringwert für vorhandene, leere lokale #Temp-Tabelle; keine ##Temp/#Monitor*-Ziele, max. 116 Zeichen, genau eine Seed-Spalte. Zielzuordnung wird vor Children und auch vor @Hilfe geprüft. Bei Nicht-TABLE löst ein nichtleerer, nicht nur aus Leerraum bestehender Wert THROW 51011 aus; NULL/leer/Leerraum zulässig.';
        PRINT N'@JsonErzeugen bit; Default: 0. 0 oder NULL erzeugt weder Wrapper- noch Child-JSON. 1 fordert JSON aller aufgerufenen Children an und assembliert unabhängig von @ResultSetArt das Wrapperobjekt mit meta, moduleStatus und elf benannten Childfeldern; nicht erzeugte Childpayloads bleiben JSON null. @Hilfe=1 kehrt vor Childaufrufen und JSON-Assembly zurück, nachdem @Json auf NULL gesetzt und ggf. das TABLE-Mapping vorgeprüft wurde. Der gleiche Schalter wird unverändert weitergereicht; es gibt keinen getrennten Child-JSON-Schalter. Ohne JSON fehlt ObjectInventory, IndexUsage, MissingIndexes, OperationalStats, Statistics, Partitions, Columnstore und PhysicalStats die vom Wrapper gelesene JSON-Statusquelle: ihre Modulstatuswerte fallen auf EXECUTED zurück und belegen keinen bestimmten Childstatus. StatisticsDistribution, Vector und SchemaDesign liefern Status über OUTPUT. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden bit 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfang, etwa @Json=@Payload OUTPUT mit einer nvarchar(max)-Variablen. Der Eingabewert wird beim Eintritt auf NULL gesetzt. Im normalen Pfad mit @JsonErzeugen=1 enthält das Objekt meta, moduleStatus sowie objectInventory, indexUsage, missingIndexes, indexOperationalStats, statistics, statisticsDistribution, partitions, columnstore, indexPhysicalStats, vectorIndexAnalysis und schemaDesign. Nicht erzeugte Childpayloads sind JSON null. Andernfalls, auch bei früher Hilfe-Rückkehr, bleibt der Wert NULL. Ohne OUTPUT-Bindung wird kein Wert empfangen. Die Statusaussagegrenzen ohne Child-JSON stehen bei @JsonErzeugen.';
        PRINT N'@PrintMeldungen bit; Default: 1. 0 oder NULL unterdrückt Wrapperwarnung; 1 sendet bei Status ungleich AVAILABLE eine Severity-10-RAISERROR-Meldung mit NOWAIT. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1. An Children weitergereicht; steuert weder Resultsets noch Childstatus.';
        PRINT N'@Hilfe bit; Default: 0. 0 führt zu aktivierten Children; 1 gibt eingebaute PRINT-Zeilen aus und kehrt vor Childaufrufen, Datenbankauswahl und Facherhebung zurück. @Json ist davor bereits NULL. Bei TABLE läuft Mapping-Preflight davor und kann abbrechen. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1; NULL aktiviert den Hilfepfad nicht.';
        PRINT N'EXEC [monitor].[USP_ObjectAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @FullObjectNames=N''[ExampleSchema].[ExampleTable]'', @MitObjectInventory=1, @MitIndexUsage=0, @MitMissingIndexes=0, @ResultSetArt=''RAW'';';
        PRINT N'DECLARE @ObjectAnalysisJson nvarchar(max); EXEC [monitor].[USP_ObjectAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @FullObjectNames=N''[ExampleSchema].[ExampleTable]'', @MitObjectInventory=1, @MitIndexUsage=0, @MitMissingIndexes=0, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@ObjectAnalysisJson OUTPUT; SELECT @ObjectAnalysisJson AS [ObjectAnalysisJson];';
        PRINT N'EXEC [monitor].[USP_ObjectAnalysis] @Hilfe=1;';









        RETURN;
    END;

    CREATE TABLE [#ObjectAnalysis_ModuleStatus]
    (
          [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    IF @MaxZeilen < 0 OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
       OR @ResultSetArtNormalisiert NOT IN ('RAW','CONSOLE','NONE')
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Ungültige Mengen-, Lock-Timeout- oder Ausgabeparameter.';
    END;

    IF @StatusCode = 'AVAILABLE'
       AND @FullObjectNames IS NOT NULL
       AND (@SchemaNames IS NOT NULL OR @ObjectNames IS NOT NULL OR @SchemaNamePattern IS NOT NULL OR @ObjectNamePattern IS NOT NULL)
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'@FullObjectNames ist zu separaten Schema-/Objektfiltern gegenseitig exklusiv.';
    END;

    IF @StatusCode='AVAILABLE'
    BEGIN
        SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N';';
        EXEC [sys].[sp_executesql] @LockTimeoutSql;
    END;

    IF @StatusCode = 'AVAILABLE'
       AND ((@SchemaNames IS NOT NULL AND @SchemaNamePattern IS NOT NULL)
         OR (@ObjectNames IS NOT NULL AND @ObjectNamePattern IS NOT NULL)
         OR (@IndexNames IS NOT NULL AND @IndexNamePattern IS NOT NULL)
         OR (@StatisticsNames IS NOT NULL AND @StatisticsNamePattern IS NOT NULL))
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Exakte Liste und Pattern derselben Eigenschaft sind gegenseitig exklusiv.';
    END;

    DECLARE @JsonObjectInventory nvarchar(max) = NULL;
    DECLARE @JsonIndexUsage nvarchar(max) = NULL;
    DECLARE @JsonMissingIndexes nvarchar(max) = NULL;
    DECLARE @JsonOperationalStats nvarchar(max) = NULL;
    DECLARE @JsonStatistics nvarchar(max) = NULL;
    DECLARE @JsonStatisticsDistribution nvarchar(max) = NULL;
    DECLARE @JsonPartitions nvarchar(max) = NULL;
    DECLARE @JsonColumnstore nvarchar(max) = NULL;
    DECLARE @JsonPhysicalStats nvarchar(max) = NULL;
    DECLARE @JsonVectorIndexes nvarchar(max) = NULL;
    DECLARE @JsonSchemaDesign nvarchar(max) = NULL;
    DECLARE @StatisticsDistributionStatus varchar(40) = NULL;
    DECLARE @StatisticsDistributionPartial bit = NULL;
    DECLARE @StatisticsDistributionErrorNumber int = NULL;
    DECLARE @StatisticsDistributionErrorMessage nvarchar(2048) = NULL;
    DECLARE @VectorIndexStatus varchar(40) = NULL;
    DECLARE @VectorIndexPartial bit = NULL;
    DECLARE @VectorIndexErrorNumber int = NULL;
    DECLARE @VectorIndexErrorMessage nvarchar(2048) = NULL;
    DECLARE @SchemaDesignStatus varchar(40) = NULL;
    DECLARE @SchemaDesignPartial bit = NULL;
    DECLARE @SchemaDesignErrorNumber int = NULL;
    DECLARE @SchemaDesignErrorMessage nvarchar(2048) = NULL;

    IF @StatusCode = 'AVAILABLE' AND @MitObjectInventory = 1
    BEGIN TRY
        EXEC [monitor].[USP_ObjectInventory]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
            , @SchemaNames=@SchemaNames,@SchemaNamePattern=@SchemaNamePattern,@ObjectNames=@ObjectNames,@ObjectNamePattern=@ObjectNamePattern,@FullObjectNames=@FullObjectNames
            , @AnalyseModus=@AnalyseModus,@MaxZeilen=@MaxZeilen,@LockTimeoutMs=@LockTimeoutMs
            , @ResultSetArt=@ResultSetArtNormalisiert,@JsonErzeugen=@JsonErzeugen,@Json=@JsonObjectInventory OUTPUT,@PrintMeldungen=@PrintMeldungen;
        INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_ObjectInventory',COALESCE(JSON_VALUE(@JsonObjectInventory,'$.meta.statusCode'),'EXECUTED'),NULL,NULL);
    END TRY BEGIN CATCH INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_ObjectInventory','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE()); SET @IsPartial=1; END CATCH;

    IF @StatusCode = 'AVAILABLE' AND @MitIndexUsage = 1
    BEGIN TRY
        EXEC [monitor].[USP_IndexUsage]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
            , @SchemaNames=@SchemaNames,@SchemaNamePattern=@SchemaNamePattern,@ObjectNames=@ObjectNames,@ObjectNamePattern=@ObjectNamePattern,@FullObjectNames=@FullObjectNames
            , @AnalyseModus=@AnalyseModus,@MaxZeilen=@MaxZeilen,@LockTimeoutMs=@LockTimeoutMs
            , @ResultSetArt=@ResultSetArtNormalisiert,@JsonErzeugen=@JsonErzeugen,@Json=@JsonIndexUsage OUTPUT,@PrintMeldungen=@PrintMeldungen;
        INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_IndexUsage',COALESCE(JSON_VALUE(@JsonIndexUsage,'$.meta.statusCode'),'EXECUTED'),NULL,NULL);
    END TRY BEGIN CATCH INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_IndexUsage','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE()); SET @IsPartial=1; END CATCH;

    IF @StatusCode = 'AVAILABLE' AND @MitMissingIndexes = 1
    BEGIN TRY
        EXEC [monitor].[USP_MissingIndexes]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
            , @SchemaNames=@SchemaNames,@SchemaNamePattern=@SchemaNamePattern,@ObjectNames=@ObjectNames,@ObjectNamePattern=@ObjectNamePattern,@FullObjectNames=@FullObjectNames
            ,@MaxZeilen=@MaxZeilen,@LockTimeoutMs=@LockTimeoutMs
            , @ResultSetArt=@ResultSetArtNormalisiert,@JsonErzeugen=@JsonErzeugen,@Json=@JsonMissingIndexes OUTPUT,@PrintMeldungen=@PrintMeldungen;
        INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_MissingIndexes',COALESCE(JSON_VALUE(@JsonMissingIndexes,'$.meta.statusCode'),'EXECUTED'),NULL,NULL);
    END TRY BEGIN CATCH INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_MissingIndexes','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE()); SET @IsPartial=1; END CATCH;

    IF @StatusCode = 'AVAILABLE' AND @MitOperationalStats = 1
    BEGIN TRY
        EXEC [monitor].[USP_IndexOperationalStats]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
            , @SchemaNames=@SchemaNames,@SchemaNamePattern=@SchemaNamePattern,@ObjectNames=@ObjectNames,@ObjectNamePattern=@ObjectNamePattern,@FullObjectNames=@FullObjectNames
            , @IndexNames=@IndexNames,@IndexNamePattern=@IndexNamePattern,@AnalyseModus=@AnalyseModus
            ,@MaxZeilen=@MaxZeilen,@LockTimeoutMs=@LockTimeoutMs
            , @ResultSetArt=@ResultSetArtNormalisiert,@JsonErzeugen=@JsonErzeugen,@Json=@JsonOperationalStats OUTPUT,@PrintMeldungen=@PrintMeldungen;
        INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_IndexOperationalStats',COALESCE(JSON_VALUE(@JsonOperationalStats,'$.meta.statusCode'),'EXECUTED'),NULL,NULL);
    END TRY BEGIN CATCH INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_IndexOperationalStats','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE()); SET @IsPartial=1; END CATCH;

    IF @StatusCode = 'AVAILABLE' AND @MitStatistics = 1
    BEGIN TRY
        EXEC [monitor].[USP_Statistics]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
            , @SchemaNames=@SchemaNames,@SchemaNamePattern=@SchemaNamePattern,@ObjectNames=@ObjectNames,@ObjectNamePattern=@ObjectNamePattern,@FullObjectNames=@FullObjectNames
            , @StatisticsNames=@StatisticsNames,@StatisticsNamePattern=@StatisticsNamePattern,@AnalyseModus=@AnalyseModus
            ,@MaxZeilen=@MaxZeilen,@LockTimeoutMs=@LockTimeoutMs
            , @ResultSetArt=@ResultSetArtNormalisiert,@JsonErzeugen=@JsonErzeugen,@Json=@JsonStatistics OUTPUT,@PrintMeldungen=@PrintMeldungen;
        INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_Statistics',COALESCE(JSON_VALUE(@JsonStatistics,'$.meta.statusCode'),'EXECUTED'),NULL,NULL);
    END TRY BEGIN CATCH INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_Statistics','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE()); SET @IsPartial=1; END CATCH;

    IF @StatusCode = 'AVAILABLE' AND @MitStatisticsDistribution = 1
    BEGIN TRY
        EXEC [monitor].[USP_StatisticsDistributionAnalysis]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
            , @SchemaNames=@SchemaNames,@SchemaNamePattern=@SchemaNamePattern,@ObjectNames=@ObjectNames,@ObjectNamePattern=@ObjectNamePattern,@FullObjectNames=@FullObjectNames
            , @StatisticsNames=@StatisticsNames,@StatisticsNamePattern=@StatisticsNamePattern,@AnalyseModus=@AnalyseModus
            ,@MaxZeilen=@MaxZeilen,@LockTimeoutMs=@LockTimeoutMs
            , @ResultSetArt=@ResultSetArtNormalisiert,@JsonErzeugen=@JsonErzeugen,@Json=@JsonStatisticsDistribution OUTPUT,@PrintMeldungen=@PrintMeldungen
            , @StatusCodeOut=@StatisticsDistributionStatus OUTPUT,@IsPartialOut=@StatisticsDistributionPartial OUTPUT
            , @ErrorNumberOut=@StatisticsDistributionErrorNumber OUTPUT,@ErrorMessageOut=@StatisticsDistributionErrorMessage OUTPUT;
        INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_StatisticsDistributionAnalysis',COALESCE(@StatisticsDistributionStatus,'ERROR_HANDLED'),@StatisticsDistributionErrorNumber,@StatisticsDistributionErrorMessage);
    END TRY BEGIN CATCH INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_StatisticsDistributionAnalysis','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE()); SET @IsPartial=1; END CATCH;

    IF @StatusCode = 'AVAILABLE' AND @MitPartitions = 1
    BEGIN TRY
        EXEC [monitor].[USP_Partitions]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
            , @SchemaNames=@SchemaNames,@SchemaNamePattern=@SchemaNamePattern,@ObjectNames=@ObjectNames,@ObjectNamePattern=@ObjectNamePattern,@FullObjectNames=@FullObjectNames
            , @AnalyseModus=@AnalyseModus,@MaxZeilen=@MaxZeilen,@LockTimeoutMs=@LockTimeoutMs
            , @ResultSetArt=@ResultSetArtNormalisiert,@JsonErzeugen=@JsonErzeugen,@Json=@JsonPartitions OUTPUT,@PrintMeldungen=@PrintMeldungen;
        INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_Partitions',COALESCE(JSON_VALUE(@JsonPartitions,'$.meta.statusCode'),'EXECUTED'),NULL,NULL);
    END TRY BEGIN CATCH INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_Partitions','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE()); SET @IsPartial=1; END CATCH;

    IF @StatusCode = 'AVAILABLE' AND @MitColumnstore = 1
    BEGIN TRY
        EXEC [monitor].[USP_Columnstore]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
            , @SchemaNames=@SchemaNames,@SchemaNamePattern=@SchemaNamePattern,@ObjectNames=@ObjectNames,@ObjectNamePattern=@ObjectNamePattern,@FullObjectNames=@FullObjectNames
            , @AnalyseModus=@AnalyseModus,@MaxZeilen=@MaxZeilen,@LockTimeoutMs=@LockTimeoutMs
            , @ResultSetArt=@ResultSetArtNormalisiert,@JsonErzeugen=@JsonErzeugen,@Json=@JsonColumnstore OUTPUT,@PrintMeldungen=@PrintMeldungen;
        INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_Columnstore',COALESCE(JSON_VALUE(@JsonColumnstore,'$.meta.statusCode'),'EXECUTED'),NULL,NULL);
    END TRY BEGIN CATCH INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_Columnstore','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE()); SET @IsPartial=1; END CATCH;

    IF @StatusCode = 'AVAILABLE' AND @MitPhysicalStats = 1
    BEGIN TRY
        EXEC [monitor].[USP_IndexPhysicalStats]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
            , @SchemaNames=@SchemaNames,@SchemaNamePattern=@SchemaNamePattern,@ObjectNames=@ObjectNames,@ObjectNamePattern=@ObjectNamePattern,@FullObjectNames=@FullObjectNames
            , @IndexNames=@IndexNames,@IndexNamePattern=@IndexNamePattern,@AnalyseModus=@AnalyseModus
            ,@MaxZeilen=@MaxZeilen,@LockTimeoutMs=@LockTimeoutMs
            , @ResultSetArt=@ResultSetArtNormalisiert,@JsonErzeugen=@JsonErzeugen,@Json=@JsonPhysicalStats OUTPUT,@PrintMeldungen=@PrintMeldungen;
        INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_IndexPhysicalStats',COALESCE(JSON_VALUE(@JsonPhysicalStats,'$.meta.statusCode'),'EXECUTED'),NULL,NULL);
    END TRY BEGIN CATCH INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_IndexPhysicalStats','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE()); SET @IsPartial=1; END CATCH;

    IF @StatusCode = 'AVAILABLE' AND @MitVectorIndexes = 1
    BEGIN TRY
        EXEC [monitor].[USP_VectorIndexAnalysis]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
            , @SchemaNames=@SchemaNames,@SchemaNamePattern=@SchemaNamePattern,@ObjectNames=@ObjectNames,@ObjectNamePattern=@ObjectNamePattern,@FullObjectNames=@FullObjectNames
            , @IndexNames=@IndexNames,@IndexNamePattern=@IndexNamePattern,@MaxZeilen=@MaxZeilen,@LockTimeoutMs=@LockTimeoutMs
            , @ResultSetArt=@ResultSetArtNormalisiert,@JsonErzeugen=@JsonErzeugen,@Json=@JsonVectorIndexes OUTPUT,@PrintMeldungen=@PrintMeldungen
            , @StatusCodeOut=@VectorIndexStatus OUTPUT,@IsPartialOut=@VectorIndexPartial OUTPUT
            , @ErrorNumberOut=@VectorIndexErrorNumber OUTPUT,@ErrorMessageOut=@VectorIndexErrorMessage OUTPUT;
        INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_VectorIndexAnalysis',COALESCE(@VectorIndexStatus,'ERROR_HANDLED'),@VectorIndexErrorNumber,@VectorIndexErrorMessage);
    END TRY BEGIN CATCH INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_VectorIndexAnalysis','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE()); SET @IsPartial=1; END CATCH;

    IF @StatusCode = 'AVAILABLE' AND @MitSchemaDesign = 1
    BEGIN TRY
        EXEC [monitor].[USP_SchemaDesignAnalysis]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
            ,@MaxZeilen=@MaxZeilen
            , @ResultSetArt=@ResultSetArtNormalisiert,@JsonErzeugen=@JsonErzeugen,@Json=@JsonSchemaDesign OUTPUT,@PrintMeldungen=@PrintMeldungen
            , @StatusCodeOut=@SchemaDesignStatus OUTPUT,@IsPartialOut=@SchemaDesignPartial OUTPUT
            , @ErrorNumberOut=@SchemaDesignErrorNumber OUTPUT,@ErrorMessageOut=@SchemaDesignErrorMessage OUTPUT;
        INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_SchemaDesignAnalysis',COALESCE(@SchemaDesignStatus,'ERROR_HANDLED'),@SchemaDesignErrorNumber,@SchemaDesignErrorMessage);
    END TRY BEGIN CATCH INSERT [#ObjectAnalysis_ModuleStatus] VALUES(N'USP_SchemaDesignAnalysis','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE()); SET @IsPartial=1; END CATCH;

    IF EXISTS(SELECT 1 FROM [#ObjectAnalysis_ModuleStatus]
              WHERE [StatusCode] NOT IN ('EXECUTED','AVAILABLE','AVAILABLE_WITH_FINDING','NOT_APPLICABLE','UNAVAILABLE_VERSION','UNAVAILABLE_FEATURE','NOT_ENABLED'))
    BEGIN
        SET @StatusCode = 'PARTIAL_RESULT';
        SET @IsPartial = 1;
    END
    ELSE IF EXISTS(SELECT 1 FROM [#ObjectAnalysis_ModuleStatus] WHERE [StatusCode] = 'AVAILABLE_WITH_FINDING')
        SET @StatusCode = 'AVAILABLE_WITH_FINDING';

    IF @StatusCode <> 'AVAILABLE' AND @PrintMeldungen = 1
    BEGIN
        SET @MonitorPrintMessage = FORMATMESSAGE(N'WARNUNG USP_ObjectAnalysis %s: %s',@StatusCode,COALESCE(@ErrorMessage,N'Mindestens ein Teilmodul lieferte kein vollständiges Ergebnis.'));
        RAISERROR(N'%s',10,1,@MonitorPrintMessage) WITH NOWAIT;
    END;

    SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @LockTimeoutSql;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @JsonMeta nvarchar(max)=(SELECT N'ObjectAnalysis' [resultName],1 [schemaVersion],@CollectionTimeUtc [generatedAtUtc],@StatusCode [statusCode],@IsPartial [isPartial],@ErrorMessage [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @JsonModuleStatus nvarchar(max)=(SELECT * FROM [#ObjectAnalysis_ModuleStatus] ORDER BY [ModuleName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT
        (
              N'{"meta":',COALESCE(@JsonMeta,N'{}')
            ,N',"moduleStatus":',COALESCE(@JsonModuleStatus,N'[]')
            ,N',"objectInventory":',COALESCE(@JsonObjectInventory,N'null')
            ,N',"indexUsage":',COALESCE(@JsonIndexUsage,N'null')
            ,N',"missingIndexes":',COALESCE(@JsonMissingIndexes,N'null')
            ,N',"indexOperationalStats":',COALESCE(@JsonOperationalStats,N'null')
            ,N',"statistics":',COALESCE(@JsonStatistics,N'null')
            ,N',"statisticsDistribution":',COALESCE(@JsonStatisticsDistribution,N'null')
            ,N',"partitions":',COALESCE(@JsonPartitions,N'null')
            ,N',"columnstore":',COALESCE(@JsonColumnstore,N'null')
            ,N',"indexPhysicalStats":',COALESCE(@JsonPhysicalStats,N'null')
            ,N',"vectorIndexAnalysis":',COALESCE(@JsonVectorIndexes,N'null')
            ,N',"schemaDesign":',COALESCE(@JsonSchemaDesign,N'null')
            ,N'}'
        );
    END;

    IF @ResultSetArtNormalisiert <> 'NONE'
    BEGIN
        IF @ResultSetArtNormalisiert = 'RAW'
            SELECT @CollectionTimeUtc [CollectionTimeUtc],N'monitor.USP_ObjectAnalysis' [ModuleName],@StatusCode [StatusCode],@IsPartial [IsPartial],@ErrorMessage [ErrorMessage];
        ELSE
            SELECT N'Objekt-/Indexanalyse' [Ergebnis],@CollectionTimeUtc [Stand_UTC],@StatusCode [Status],@IsPartial [Teilergebnis],@ErrorMessage [Hinweis];

        IF @ResultSetArtNormalisiert = 'RAW'
            SELECT * FROM [#ObjectAnalysis_ModuleStatus] ORDER BY [ModuleName];
        ELSE
            SELECT N'Teilmodulstatus' [Ergebnis],[ModuleName] [Modul],[StatusCode] [Status],[ErrorNumber] [Fehlernummer],[ErrorMessage] [Fehlermeldung] FROM [#ObjectAnalysis_ModuleStatus] ORDER BY [ModuleName];
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#ObjectAnalysis_ModuleStatus'
            , @ResultLabel=N'ObjectAnalysis'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#ObjectAnalysis_ModuleStatus'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
