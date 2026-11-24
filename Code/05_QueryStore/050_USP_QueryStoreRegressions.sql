USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_QueryStoreRegressions
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Vergleicht zwei Query-Store-Zeitfenster über eine oder mehrere
               Quelldatenbanken. Lokales N+1 und globales Top-N vermeiden eine
               vollständige Materialisierung aller Query-Store-Zeilen.
Ausgabe      : RAW/CONSOLE/NONE; JSON mit meta, regressions und warnings.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.USP_QueryStoreRegressions 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.USP_QueryStoreRegressions"
-- schema_name: "monitor"
-- object_name: "USP_QueryStoreRegressions"
-- object_type: "PROCEDURE"
-- database_role: "framework"
-- is_internal: false
-- description: "Vergleicht zwei Query-Store-Zeitfenster über eine oder mehrere Quelldatenbanken."
-- source_path: "Code/05_QueryStore/050_USP_QueryStoreRegressions.sql"
-- ---
-- 
-- # monitor.USP_QueryStoreRegressions
-- 
-- ## Zweck und Einsatz
-- 
-- Vergleicht zwei Query-Store-Zeitfenster über eine oder mehrere Quelldatenbanken. Lokales N+1 und globales Top-N vermeiden eine vollständige Materialisierung aller Query-Store-Zeilen.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_QueryStoreRegressions]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `[monitor].[TVF_ParsePattern]`, `[monitor].[TVF_ParseSqlNameList]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `[monitor].[InternalCheckAnalysisPath]`, `[master].[sys].[databases]`, `[sys].[database_query_store_options]`, `[sys].[query_store_runtime_stats]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @QueryStoreDatabaseNames | nvarchar(max) | nein | NULL |
-- | @QueryStoreDatabaseNamePattern | nvarchar(4000) | nein | NULL |
-- | @HighImpactConfirmed | bit | nein | 0 |
-- | @ReferencedDatabaseNames | nvarchar(max) | nein | NULL |
-- | @ReferencedDatabaseNamePattern | nvarchar(4000) | nein | NULL |
-- | @QueryId | bigint | nein | NULL |
-- | @QueryHash | binary(8) | nein | NULL |
-- | @BaselineVonUtc | datetime2(7) | nein | NULL |
-- | @BaselineBisUtc | datetime2(7) | nein | NULL |
-- | @VergleichVonUtc | datetime2(7) | nein | NULL |
-- | @VergleichBisUtc | datetime2(7) | nein | NULL |
-- | @Metrik | varchar(32) | nein | 'DURATION_AVG' |
-- | @MinAusfuehrungenJeFenster | bigint | nein | 1 |
-- | @MinRegressionProzent | decimal(9,2) | nein | 20.0 |
-- | @AnalyseModus | varchar(16) | nein | 'TOP' |
-- | @MaxZeilen | int | nein | 100 |
-- | @MaxSqlTextZeichen | int | nein | 4000 |
-- | @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
-- | @ResultTablesJson | nvarchar(max) | nein | NULL |
-- | @JsonErzeugen | bit | nein | 0 |
-- | @Json | nvarchar(max) | nein | NULL OUTPUT |
-- | @PrintMeldungen | bit | nein | 1 |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@QueryStoreDatabaseNames:** @QueryStoreDatabaseNames nvarchar(max); Default: NULL. Ausgelassen/NULL, N'' oder nur äußere U+0020-Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger SQL-Datenbanknamen, zum Beispiel N'[ExampleDatabase]|[OtherDatabase]'; | trennt außerhalb von [...], ]] maskiert ]. Leere Elemente, ungültige Namen und Duplikate sind INVALID_PARAMETER. Eine effektive nichtleere Liste ist exklusiv mit dem nicht-NULL Quellpattern. Ohne Filter werden sichtbare geeignete Online-Benutzerdatenbanken gewählt; Systemdatenbanken bleiben ausgeschlossen.
-- 
-- **@QueryStoreDatabaseNamePattern:** @QueryStoreDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung entfernen. Ohne Präfix gilt LIKE; Rest wird nicht erneut getrimmt. Leer oder leer nach Präfix ist ungültig; exklusiv mit @QueryStoreDatabaseNames. REGEX/REGEXI laufen in der Installationsdatenbank und benötigen SQL Server 2025 plus CL170 dort; Syntax wird nicht vorab validiert.
-- 
-- **@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. ausgelassen/0 = nicht bestätigt. NULL ist im Datenbankhelfer INVALID_PARAMETER. 1 bestätigt nur ein aktiviertes Gruppengate: QUERY_STORE_CURRENT hat kein Gruppengate, QUERY_STORE_DEEP verwendet es. Die Bestätigung ändert keinen Scope und erteilt weder SQL-Berechtigung noch Gruppenmitgliedschaft. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.
-- 
-- **@ReferencedDatabaseNames:** @ReferencedDatabaseNames nvarchar(max); Default: NULL. ausgelassen/NULL kein Showplan-Referenzfilter. Sonst nichtleere bracket-aware Pipe-Liste einteiliger SQL-Namen; | trennt außerhalb von [...], ]] maskiert ]. Leerwert/Leerzeichen ungültig. Teil 1 muss nicht NULL, Teil 2 NULL und LEN(Teil 1) höchstens 128 sein. Punkte außerhalb eines einzelnen quotierten Namens sind auch bei ausgelassenen Qualifizierern ungültig. Gültige Namen werden mit expliziter Framework-Collation SQL_Latin1_General_CP1_CS_AS verglichen. Duplikate sind erlaubt; EXISTS vervielfacht keine Zeilen. Exklusiv mit @ReferencedDatabaseNamePattern; setzt QUERY_STORE_DEEP voraus.
-- 
-- **@ReferencedDatabaseNamePattern:** @ReferencedDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung. Ohne Präfix LIKE; Rest wird nicht erneut getrimmt; leer/leer nach Präfix ungültig. Exklusiv mit @ReferencedDatabaseNames; setzt QUERY_STORE_DEEP voraus. REGEX/REGEXI laufen je Quelldatenbank und benötigen SQL Server 2025 sowie CL170 dort; Syntax wird nicht vorab validiert.
-- 
-- **@QueryId:** @QueryId bigint; Default: NULL. Ausgelassen/NULL: kein Query-ID-Filter. Einen ganzzahligen bigint-Wert von -9223372036854775808 bis 9223372036854775807 übergeben; keine zusätzliche Positivitäts- oder Existenzprüfung. Exakter Vergleich je Quelle; Query-IDs sind quellenspezifisch.
-- 
-- **@QueryHash:** @QueryHash binary(8); Default: NULL. Ausgelassen/NULL: kein Hashfilter. Acht Byte als Binärwert übergeben, zum Beispiel 0x0123456789ABCDEF; exakter Vergleich ohne zusätzliche Werte- oder Existenzprüfung. SQL-Typkonvertierungen erfolgen vor dem Procedurekörper.
-- 
-- **@BaselineVonUtc:** @BaselineVonUtc datetime2(7); Default: NULL. Optionale UTC-Untergrenze des Baselinefensters. Jede gesetzte Grenze bleibt erhalten. Wenn NULL, wird eine Stunde vor @BaselineBisUtc berechnet; fehlt auch @BaselineBisUtc, ist dessen Default @VergleichVonUtc. Die Grenze muss vor @BaselineBisUtc liegen. Übergabe als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000; keine Zeitzonenumrechnung. Jede untere Grenze muss vor ihrer oberen liegen; BaselineBisUtc darf VergleichVonUtc nicht überschreiten. Vollständig überlappende Runtimeintervalle werden einbezogen, keine anteilige Kürzung. Jeder automatisch berechnete NULL-Beginn benötigt eine darstellbare Stunde vor seinem effektiven Ende. Wenn Vergleichsbeginn und beide Baselinegrenzen NULL bleiben, muss ein gesetztes Vergleichsende mindestens 0001-01-01T02:00:00.0000000 betragen. Frühere Werte können bei DATEADD vor der normalen Fachvalidierung ungefangen überlaufen; vollständig gesetzte gültige Fenster bleiben zulässig.
-- 
-- **@BaselineBisUtc:** @BaselineBisUtc datetime2(7); Default: NULL. Optionale UTC-Obergrenze des Baselinefensters. Wenn NULL, gilt @VergleichVonUtc. Die Grenze muss nach @BaselineVonUtc liegen und darf nicht nach @VergleichVonUtc liegen. Übergabe als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000; keine Zeitzonenumrechnung. Jede untere Grenze muss vor ihrer oberen liegen; BaselineBisUtc darf VergleichVonUtc nicht überschreiten. Vollständig überlappende Runtimeintervalle werden einbezogen, keine anteilige Kürzung. Jeder automatisch berechnete NULL-Beginn benötigt eine darstellbare Stunde vor seinem effektiven Ende. Wenn Vergleichsbeginn und beide Baselinegrenzen NULL bleiben, muss ein gesetztes Vergleichsende mindestens 0001-01-01T02:00:00.0000000 betragen. Frühere Werte können bei DATEADD vor der normalen Fachvalidierung ungefangen überlaufen; vollständig gesetzte gültige Fenster bleiben zulässig.
-- 
-- **@VergleichVonUtc:** @VergleichVonUtc datetime2(7); Default: NULL. Optionale UTC-Untergrenze des Vergleichsfensters. Wenn NULL, wird eine Stunde vor @VergleichBisUtc berechnet; wenn auch das Ende NULL ist, gilt zunächst jetzt in UTC. Die Grenze muss vor @VergleichBisUtc liegen. Baseline und Vergleich dürfen sich nicht überlappen. Übergabe als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000; keine Zeitzonenumrechnung. Jede untere Grenze muss vor ihrer oberen liegen; BaselineBisUtc darf VergleichVonUtc nicht überschreiten. Vollständig überlappende Runtimeintervalle werden einbezogen, keine anteilige Kürzung. Jeder automatisch berechnete NULL-Beginn benötigt eine darstellbare Stunde vor seinem effektiven Ende. Wenn Vergleichsbeginn und beide Baselinegrenzen NULL bleiben, muss ein gesetztes Vergleichsende mindestens 0001-01-01T02:00:00.0000000 betragen. Frühere Werte können bei DATEADD vor der normalen Fachvalidierung ungefangen überlaufen; vollständig gesetzte gültige Fenster bleiben zulässig.
-- 
-- **@VergleichBisUtc:** @VergleichBisUtc datetime2(7); Default: NULL. Optionale UTC-Obergrenze des Vergleichsfensters. Wenn NULL, gilt SYSUTCDATETIME() zum Aufruf. Jede gesetzte Grenze bleibt erhalten; aus den vier einzeln abgeleiteten Grenzen entsteht keine automatische Gleichlängenregel. Die Grenze muss nach @VergleichVonUtc liegen. Übergabe als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000; keine Zeitzonenumrechnung. Jede untere Grenze muss vor ihrer oberen liegen; BaselineBisUtc darf VergleichVonUtc nicht überschreiten. Vollständig überlappende Runtimeintervalle werden einbezogen, keine anteilige Kürzung. Jeder automatisch berechnete NULL-Beginn benötigt eine darstellbare Stunde vor seinem effektiven Ende. Wenn Vergleichsbeginn und beide Baselinegrenzen NULL bleiben, muss ein gesetztes Vergleichsende mindestens 0001-01-01T02:00:00.0000000 betragen. Frühere Werte können bei DATEADD vor der normalen Fachvalidierung ungefangen überlaufen; vollständig gesetzte gültige Fenster bleiben zulässig.
-- 
-- **@Metrik:** @Metrik varchar(32); Default: 'DURATION_AVG'. NULL wird wie DURATION_AVG behandelt; außen getrimmt und in Großbuchstaben normalisiert. Zulässige geschlossene Werte: DURATION_AVG = ausführungsgewichtete durchschnittliche Dauer in ms je Ausführung; CPU_AVG = gewichtete durchschnittliche CPU-Zeit in ms je Ausführung; READS_AVG = gewichtete durchschnittliche logische Reads je Ausführung; WRITES_AVG = gewichtete durchschnittliche logische Writes je Ausführung; EXECUTIONS = Ausführungszahl im Fenster. Für Dauer/CPU werden Quellwerte in Mikrosekunden durch 1000 in ms umgerechnet. Es werden nur Queries mit Werten in beiden Fenstern und einer berechneten Änderung mindestens @MinRegressionProzent ausgegeben. Prozent = 100 × (Vergleich − Baseline) / ABS(Baseline); bei Baseline 0 ist der Prozentwert NULL und erfüllt den Mindestfilter nicht. Der Schwellenwert wird mit dem vor der Ausgabe-Rundung berechneten Float-Prozentwert verglichen; Baselinewert 0 ergibt durch NULLIF NULL und wird durch das WHERE-Prädikat ausgeschlossen. Maßgeblich ist der bei SQL-Bindung auf die deklarierte Typbreite zugewiesene Wert; LTRIM/RTRIM entfernt äußere U+0020-Leerzeichen. Leer, nur U+0020 oder andere Werte sind im normalen Analysepfad ungültig.
-- 
-- **@MinAusfuehrungenJeFenster:** @MinAusfuehrungenJeFenster bigint; Default: 1. Mindestzahl der Ausführungen in jedem der beiden Fenster; Werte kleiner 1 sind ungültig. SQL-Prädikate filtern je Fenster vor dem Vergleich. NULL führt nicht pauschal zu INVALID_PARAMETER, erfüllt aber den Mindestvergleich nicht und ergibt damit keine Regressionstreffer. Als ganze Zahl von 1 bis 9223372036854775807 übergeben.
-- 
-- **@MinRegressionProzent:** @MinRegressionProzent decimal(9,2); Default: 20.0. Mindestwert für die prozentuale Änderung der ausgewählten Metrik, verglichen mit 100 × (Vergleich − Baseline) / ABS(Baseline). Negative Werte sind ungültig. NULL ist kein allgemeiner Parameterfehler, lässt das SQL-Schwellenprädikat aber UNKNOWN werden und liefert daher keine Regressionstreffer. Als dezimalen Zahlenwert von 0.00 bis 9999999.99 übergeben, zum Beispiel 20.00. Zuweisung an decimal(9,2) erfolgt vor der Prüfung und kann zusätzliche Nachkommastellen runden.
-- 
-- **@AnalyseModus:** @AnalyseModus varchar(16); Default: 'TOP'. NULL wird wie TOP behandelt; außen getrimmt und großgeschrieben. Geschlossene Optionen: TOP nutzt den rangbegrenzten lokalen Kandidatenpfad je Quelle; VOLL aktiviert den Deep-Check. Beide liefern weiterhin nur die nach Kriterien berechneten Regressionen. Maßgeblich ist der bei SQL-Bindung auf die deklarierte Typbreite zugewiesene Wert; LTRIM/RTRIM entfernt äußere U+0020-Leerzeichen. VOLL hebt das Zeilenlimit nicht auf. Leer, nur U+0020 oder andere Werte sind ungültig.
-- 
-- **@MaxZeilen:** @MaxZeilen int; Default: 100. Globale Ausgabegrenze nach lokaler N+1-Kandidatensammlung je Quelle, Textprojektion, Truncationwarnung und Mengen-/Statuszählung. Positiver Wert begrenzt die abschließende, global nach RegressionPercent DESC und AbsoluteChange DESC sortierte Exportmenge; Gleichstände bestimmen keine eindeutige Auswahl. NULL oder 0 bedeutet unbegrenzt. Negative Werte sind ungültig. Der lokale TOP ist bei positivem Wert höchstens @MaxZeilen+1 (bei int-Maximalwert ohne Addition); er begrenzt nicht pauschal alle gelesenen Query-Store-Runtimezeilen. @Limit > 1000 aktiviert QUERY_STORE_DEEP; bei NULL/0 ist das Limit maximal und Deep daher aktiv. Als ganze Zahl im SQL-int-Bereich bis 2147483647 übergeben.
-- 
-- **@MaxSqlTextZeichen:** @MaxSqlTextZeichen int; Default: 4000. Begrenzt die projizierte Länge von QuerySqlText in den lokal gesammelten Ergebnissen. NULL oder 0 bedeutet unbegrenzt; negative Werte sind ungültig. Projektion und Truncationmetadaten/-warnung werden vor der abschließenden globalen @MaxZeilen-Ausgabegrenze berechnet; die Begrenzung spart daher nicht die vorherige Quellaggregation. Die Unicode-Projektion zählt Zeichen mit SC-Collation und schneidet Surrogatpaare nicht auseinander. Als ganze Zahl im SQL-int-Bereich bis 2147483647 übergeben.
-- 
-- **@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Ausgelassen: CONSOLE. Nach U+0020-Trim/Großschreibung sind genau vier Werte erlaubt: RAW liefert drei Resultsets (Metadaten, regressions, Warnungen); CONSOLE liefert die fachliche Exportmenge mit Ergebnislabel oder bei Leere eine Hinweiszeile, ohne zusätzliche Metadaten-/Warnungsgrids; TABLE schreibt nur regressions ins geprüfte lokale Temp-Ziel; NONE unterdrückt normale Fachresultsets. JSON ist unabhängig. NULL, leer, nur Leerzeichen und andere Werte sind im normalen Analysepfad ungültig. Der TABLE-Preflight liegt vor Hilfe und Fachvalidierung. Der Eingabewert unterliegt der varchar(16)-Bindungsbreite.
-- 
-- **@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. außerhalb TABLE nur NULL, leer oder Leerzeichen zulässig; anderer nichtleerer Inhalt wirft 51011. Bei TABLE nichtleeres JSON-Objekt mit genau dem Schlüssel regressions und einem Ziel. Ziel: vorhandene, leere lokale #Temp-Tabelle (kein ##), maximal 116 Zeichen und genau eine beliebige Seed-Spalte; das volle Ergebnis-Schema muss nicht angelegt werden. Fehlendes/ungültiges Mapping/Ziel wird im frühen Preflight abgelehnt; leerer Wert ist in TABLE ungültig. Schlüssel binär exakt und ohne Duplikate; Ziele dürfen weder ## noch das reservierte #Monitor-Präfix verwenden. Ein Seed-Datensatz ist nicht zulässig; der Writer ersetzt die Seed-Struktur durch das Ergebnisschema.
-- 
-- **@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Steuert unabhängig von @ResultSetArt, ob JSON in @Json aufgebaut wird. SQL-bit-Konvertierung: numerische Eingaben ungleich 0 werden 1, 0 wird 0; NULL erzeugt kein JSON.
-- 
-- **@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Parameter. Zum Empfang nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Beim Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 gefüllt; bei Hilfe bleibt es NULL. Ausgelassen gilt der Vorgabewert, das Ergebnis ist dann nicht abrufbar. Leerwert als Eingabe wird nicht ausgewertet. Bei ungefangenem THROW besteht keine Zusage einer OUTPUT-Rückübertragung.
-- 
-- **@PrintMeldungen:** @PrintMeldungen bit; Default: 1. ausgelassen lässt Meldungen zu. 1 erlaubt Fehlerhinweise und die Truncationwarnung; 0 unterdrückt diese Meldungen. NULL unterdrückt die Truncationwarnung und erfüllt die direkte Fehlerausgabebedingung nicht. Status, Resultsets und Datenmenge bleiben davon unberührt. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.
-- 
-- **@Hilfe:** @Hilfe bit; Default: 0. ausgelassen/NULL führt normal aus. Nur 1 druckt die Hilfe und beendet vor normaler Parameter- und Datenvalidierung. Rohe SQL-Bindung und früher TABLE-Mapping-Preflight bleiben aktiv und können vorher scheitern; @Json wurde beim Eintritt geleert. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.
-- 
-- ## Resultate und Ausgabe
-- 
-- RAW/CONSOLE/NONE; JSON mit meta, regressions und warnings.
-- 
-- | Resultmenge | RAW | TABLE | Felder laut Inventar |
-- | --- | --- | --- | --- |
-- | regressions | 1 | 1 | [QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[QueryId] bigint,[QueryHash] binary(8),[ObjectId] bigint NULL,[ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[BaselineExecutions] bigint,[ComparisonExecutions] bigint,[BaselinePlanCount] bigint,[ComparisonPlanCount] bigint,[BaselineValue] decimal(38,3),[ComparisonValue] decimal(38,3),[AbsoluteChange] decimal(38,3),[RegressionPercent] decimal(38,3),[LastExecutionTimeUtc] datetimeoffset,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CapturedAtUtc] datetime2(3) NULL,[EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsAggregated] bit NULL,[QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NOT NULL DEFAULT(0),[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- ## Beispiel
-- 
-- ```sql
-- EXEC [monitor].[USP_QueryStoreRegressions] @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- monitor.USP_QueryStoreRegressions
-- 
-- monitor.USP_QueryStoreRegressions vergleicht aggregierte Query-Store-Werte aus zwei nicht überlappenden UTC-Zeitfenstern je ausgewählter Quelldatenbank. Die zugrunde liegenden Runtimeintervalle können beide Fenster überlappen und werden dann jeweils vollständig einbezogen, nicht anteilig zerlegt. Die Daten hängen von Query-Store-Capture und Retention ab; sie belegen weder eine Ursache noch allgemeine Performance.
-- 
-- Zeitfenster und Intervalle: Jede gesetzte Grenze bleibt erhalten. NULL-Ende des Vergleichs = jetzt UTC; NULL-Start = eine Stunde davor. NULL-Ende der Baseline = Vergleichsstart; NULL-Start der Baseline = eine Stunde davor. Diese Defaults werden einzeln berechnet und halten bei geänderten Grenzen keine gleiche Fensterlänge ein. Runtimeintervalle werden bei Überlappung vollständig einbezogen, nicht anteilig auf Fenstergrenzen zerlegt. Ausführungen und gewichtete Messwerte werden je Query/Fenster summiert; Plananzahl zählt unterschiedliche PlanIds.
-- 
-- Analysepfad: QUERY_STORE_CURRENT wird für die Datenbankauswahl geprüft. QUERY_STORE_DEEP wird zusätzlich aktiviert bei @AnalyseModus=VOLL, normalisiertem @MaxZeilen-Limit > 1000 (NULL/0 ist unbegrenzt und damit ebenfalls > 1000), DATEDIFF(HOUR,@BaselineVonUtc,@VergleichBisUtc)>24 (Stundengrenzen gemäß DATEDIFF) oder jedem gesetzten Referenzfilter. Die jeweilige Katalogklasse kann @HighImpactConfirmed=1 erfordern; Zugriffsrichtlinien können zusätzlich sperren.
-- 
-- Grenzen: Pro Datenbank werden lokal höchstens N+1 Kandidaten für das globale Limit gesammelt; damit sind nicht alle zuvor gelesenen Query-Store-Zeilen begrenzt. @MaxSqlTextZeichen wirkt nach Quellaggregation und Filterung auf die Textprojektion. Textprojektion, Truncationwarnungen sowie Anzahl/hasMoreRows werden vor dem abschließenden globalen Limit bestimmt. Die globale Sortierung ist RegressionPercent DESC, AbsoluteChange DESC; Gleichstände garantieren keine bestimmte Auswahl.
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.USP_QueryStoreRegressions
-- Version      : 2.0.0
-- Stand        : 2026-07-15
-- Zweck        : Vergleicht zwei Query-Store-Zeitfenster über eine oder mehrere
--                Quelldatenbanken. Lokales N+1 und globales Top-N vermeiden eine
--                vollständige Materialisierung aller Query-Store-Zeilen.
-- Ausgabe      : RAW/CONSOLE/NONE; JSON mit meta, regressions und warnings.
-- ```
-- 
-- ### Weitere bestehende Hilfehinweise
-- 
-- ```text
-- monitor.USP_QueryStoreRegressions
-- monitor.USP_QueryStoreRegressions vergleicht aggregierte Query-Store-Werte aus zwei nicht überlappenden UTC-Zeitfenstern je ausgewählter Quelldatenbank. Die zugrunde liegenden Runtimeintervalle können beide Fenster überlappen und werden dann jeweils vollständig einbezogen, nicht anteilig zerlegt. Die Daten hängen von Query-Store-Capture und Retention ab; sie belegen weder eine Ursache noch allgemeine Performance.
-- Zeitfenster und Intervalle: Jede gesetzte Grenze bleibt erhalten. NULL-Ende des Vergleichs = jetzt UTC; NULL-Start = eine Stunde davor. NULL-Ende der Baseline = Vergleichsstart; NULL-Start der Baseline = eine Stunde davor. Diese Defaults werden einzeln berechnet und halten bei geänderten Grenzen keine gleiche Fensterlänge ein. Runtimeintervalle werden bei Überlappung vollständig einbezogen, nicht anteilig auf Fenstergrenzen zerlegt. Ausführungen und gewichtete Messwerte werden je Query/Fenster summiert; Plananzahl zählt unterschiedliche PlanIds.
-- Analysepfad: QUERY_STORE_CURRENT wird für die Datenbankauswahl geprüft. QUERY_STORE_DEEP wird zusätzlich aktiviert bei @AnalyseModus=VOLL, normalisiertem @MaxZeilen-Limit > 1000 (NULL/0 ist unbegrenzt und damit ebenfalls > 1000), DATEDIFF(HOUR,@BaselineVonUtc,@VergleichBisUtc)>24 (Stundengrenzen gemäß DATEDIFF) oder jedem gesetzten Referenzfilter. Die jeweilige Katalogklasse kann @HighImpactConfirmed=1 erfordern; Zugriffsrichtlinien können zusätzlich sperren.
-- Grenzen: Pro Datenbank werden lokal höchstens N+1 Kandidaten für das globale Limit gesammelt; damit sind nicht alle zuvor gelesenen Query-Store-Zeilen begrenzt. @MaxSqlTextZeichen wirkt nach Quellaggregation und Filterung auf die Textprojektion. Textprojektion, Truncationwarnungen sowie Anzahl/hasMoreRows werden vor dem abschließenden globalen Limit bestimmt. Die globale Sortierung ist RegressionPercent DESC, AbsoluteChange DESC; Gleichstände garantieren keine bestimmte Auswahl.
-- Die beschriebenen fachlichen Validierungen gelten im normalen Analysepfad. @Hilfe=1 kehrt vorher zurück; SQL-Typbindung und frühe Mappingprüfungen bleiben aktiv. Ausgelassen gilt bei jedem Parameter der ausdrücklich angegebene Default.
-- DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreRegressions] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];
-- CREATE TABLE [#QueryStoreRegressions_HelpExample]([Seed] int NULL);
-- BEGIN TRY
--  EXEC [monitor].[USP_QueryStoreRegressions] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"regressions":"#QueryStoreRegressions_HelpExample"}';
--  SELECT * FROM [#QueryStoreRegressions_HelpExample];
--  DROP TABLE IF EXISTS [#QueryStoreRegressions_HelpExample];
-- END TRY
-- BEGIN CATCH
--  DROP TABLE IF EXISTS [#QueryStoreRegressions_HelpExample];
--  THROW;
-- END CATCH;
-- ```
-- 
-- USAGE_SKILL_END monitor.USP_QueryStoreRegressions
CREATE OR ALTER PROCEDURE [monitor].[USP_QueryStoreRegressions]
      @QueryStoreDatabaseNames          nvarchar(max)  = NULL
    , @QueryStoreDatabaseNamePattern    nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @ReferencedDatabaseNames          nvarchar(max)  = NULL
    , @ReferencedDatabaseNamePattern    nvarchar(4000) = NULL
    , @QueryId                          bigint         = NULL
    , @QueryHash                        binary(8)      = NULL
    , @BaselineVonUtc                   datetime2(7)   = NULL
    , @BaselineBisUtc                   datetime2(7)   = NULL
    , @VergleichVonUtc                  datetime2(7)   = NULL
    , @VergleichBisUtc                  datetime2(7)   = NULL
    , @Metrik                           varchar(32)    = 'DURATION_AVG'
    , @MinAusfuehrungenJeFenster        bigint         = 1
    , @MinRegressionProzent             decimal(9,2)   = 20.0
    , @AnalyseModus                     varchar(16)    = 'TOP'
    , @MaxZeilen                        int            = 100
    , @MaxSqlTextZeichen                int            = 4000
    , @ResultSetArt                     varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                     bit            = 0
    , @Json                             nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                   bit            = 1
    , @Hilfe                            bit            = 0
AS
BEGIN
 SET NOCOUNT ON;

    IF @Hilfe=1
 BEGIN
        SET @Json=NULL;
        PRINT N'monitor.USP_QueryStoreRegressions';
        PRINT N'monitor.USP_QueryStoreRegressions vergleicht aggregierte Query-Store-Werte aus zwei nicht überlappenden UTC-Zeitfenstern je ausgewählter Quelldatenbank. Die zugrunde liegenden Runtimeintervalle können beide Fenster überlappen und werden dann jeweils vollständig einbezogen, nicht anteilig zerlegt. Die Daten hängen von Query-Store-Capture und Retention ab; sie belegen weder eine Ursache noch allgemeine Performance.';
        PRINT N'Zeitfenster und Intervalle: Jede gesetzte Grenze bleibt erhalten. NULL-Ende des Vergleichs = jetzt UTC; NULL-Start = eine Stunde davor. NULL-Ende der Baseline = Vergleichsstart; NULL-Start der Baseline = eine Stunde davor. Diese Defaults werden einzeln berechnet und halten bei geänderten Grenzen keine gleiche Fensterlänge ein. Runtimeintervalle werden bei Überlappung vollständig einbezogen, nicht anteilig auf Fenstergrenzen zerlegt. Ausführungen und gewichtete Messwerte werden je Query/Fenster summiert; Plananzahl zählt unterschiedliche PlanIds.';
        PRINT N'Analysepfad: QUERY_STORE_CURRENT wird für die Datenbankauswahl geprüft. QUERY_STORE_DEEP wird zusätzlich aktiviert bei @AnalyseModus=VOLL, normalisiertem @MaxZeilen-Limit > 1000 (NULL/0 ist unbegrenzt und damit ebenfalls > 1000), DATEDIFF(HOUR,@BaselineVonUtc,@VergleichBisUtc)>24 (Stundengrenzen gemäß DATEDIFF) oder jedem gesetzten Referenzfilter. Die jeweilige Katalogklasse kann @HighImpactConfirmed=1 erfordern; Zugriffsrichtlinien können zusätzlich sperren.';
        PRINT N'Grenzen: Pro Datenbank werden lokal höchstens N+1 Kandidaten für das globale Limit gesammelt; damit sind nicht alle zuvor gelesenen Query-Store-Zeilen begrenzt. @MaxSqlTextZeichen wirkt nach Quellaggregation und Filterung auf die Textprojektion. Textprojektion, Truncationwarnungen sowie Anzahl/hasMoreRows werden vor dem abschließenden globalen Limit bestimmt. Die globale Sortierung ist RegressionPercent DESC, AbsoluteChange DESC; Gleichstände garantieren keine bestimmte Auswahl.';
        PRINT N'@Hilfe=1 druckt diese Hilfe und beendet die Auswertung. Die TABLE-Zuordnung wird vorher validiert; fehlerhafte Zuordnungen können auch den Hilfeaufruf abbrechen.';
        PRINT N'Die beschriebenen fachlichen Validierungen gelten im normalen Analysepfad. @Hilfe=1 kehrt vorher zurück; SQL-Typbindung und frühe Mappingprüfungen bleiben aktiv. Ausgelassen gilt bei jedem Parameter der ausdrücklich angegebene Default.';
        PRINT N'@QueryStoreDatabaseNames nvarchar(max); Default: NULL. Ausgelassen/NULL, N'''' oder nur äußere U+0020-Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger SQL-Datenbanknamen, zum Beispiel N''[ExampleDatabase]|[OtherDatabase]''; | trennt außerhalb von [...], ]] maskiert ]. Leere Elemente, ungültige Namen und Duplikate sind INVALID_PARAMETER. Eine effektive nichtleere Liste ist exklusiv mit dem nicht-NULL Quellpattern. Ohne Filter werden sichtbare geeignete Online-Benutzerdatenbanken gewählt; Systemdatenbanken bleiben ausgeschlossen.';
        PRINT N'@QueryStoreDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung entfernen. Ohne Präfix gilt LIKE; Rest wird nicht erneut getrimmt. Leer oder leer nach Präfix ist ungültig; exklusiv mit @QueryStoreDatabaseNames. REGEX/REGEXI laufen in der Installationsdatenbank und benötigen SQL Server 2025 plus CL170 dort; Syntax wird nicht vorab validiert.';
        PRINT N'@HighImpactConfirmed bit; Default: 0. ausgelassen/0 = nicht bestätigt. NULL ist im Datenbankhelfer INVALID_PARAMETER. 1 bestätigt nur ein aktiviertes Gruppengate: QUERY_STORE_CURRENT hat kein Gruppengate, QUERY_STORE_DEEP verwendet es. Die Bestätigung ändert keinen Scope und erteilt weder SQL-Berechtigung noch Gruppenmitgliedschaft. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.';
        PRINT N'@ReferencedDatabaseNames nvarchar(max); Default: NULL. ausgelassen/NULL kein Showplan-Referenzfilter. Sonst nichtleere bracket-aware Pipe-Liste einteiliger SQL-Namen; | trennt außerhalb von [...], ]] maskiert ]. Leerwert/Leerzeichen ungültig. Teil 1 muss nicht NULL, Teil 2 NULL und LEN(Teil 1) höchstens 128 sein. Punkte außerhalb eines einzelnen quotierten Namens sind auch bei ausgelassenen Qualifizierern ungültig. Gültige Namen werden mit expliziter Framework-Collation SQL_Latin1_General_CP1_CS_AS verglichen. Duplikate sind erlaubt; EXISTS vervielfacht keine Zeilen. Exklusiv mit @ReferencedDatabaseNamePattern; setzt QUERY_STORE_DEEP voraus.';
        PRINT N'@ReferencedDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung. Ohne Präfix LIKE; Rest wird nicht erneut getrimmt; leer/leer nach Präfix ungültig. Exklusiv mit @ReferencedDatabaseNames; setzt QUERY_STORE_DEEP voraus. REGEX/REGEXI laufen je Quelldatenbank und benötigen SQL Server 2025 sowie CL170 dort; Syntax wird nicht vorab validiert.';
        PRINT N'@QueryId bigint; Default: NULL. Ausgelassen/NULL: kein Query-ID-Filter. Einen ganzzahligen bigint-Wert von -9223372036854775808 bis 9223372036854775807 übergeben; keine zusätzliche Positivitäts- oder Existenzprüfung. Exakter Vergleich je Quelle; Query-IDs sind quellenspezifisch.';
        PRINT N'@QueryHash binary(8); Default: NULL. Ausgelassen/NULL: kein Hashfilter. Acht Byte als Binärwert übergeben, zum Beispiel 0x0123456789ABCDEF; exakter Vergleich ohne zusätzliche Werte- oder Existenzprüfung. SQL-Typkonvertierungen erfolgen vor dem Procedurekörper.';
        PRINT N'@BaselineVonUtc datetime2(7); Default: NULL. Optionale UTC-Untergrenze des Baselinefensters. Jede gesetzte Grenze bleibt erhalten. Wenn NULL, wird eine Stunde vor @BaselineBisUtc berechnet; fehlt auch @BaselineBisUtc, ist dessen Default @VergleichVonUtc. Die Grenze muss vor @BaselineBisUtc liegen. Übergabe als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000; keine Zeitzonenumrechnung. Jede untere Grenze muss vor ihrer oberen liegen; BaselineBisUtc darf VergleichVonUtc nicht überschreiten. Vollständig überlappende Runtimeintervalle werden einbezogen, keine anteilige Kürzung. Jeder automatisch berechnete NULL-Beginn benötigt eine darstellbare Stunde vor seinem effektiven Ende. Wenn Vergleichsbeginn und beide Baselinegrenzen NULL bleiben, muss ein gesetztes Vergleichsende mindestens 0001-01-01T02:00:00.0000000 betragen. Frühere Werte können bei DATEADD vor der normalen Fachvalidierung ungefangen überlaufen; vollständig gesetzte gültige Fenster bleiben zulässig.';
        PRINT N'@BaselineBisUtc datetime2(7); Default: NULL. Optionale UTC-Obergrenze des Baselinefensters. Wenn NULL, gilt @VergleichVonUtc. Die Grenze muss nach @BaselineVonUtc liegen und darf nicht nach @VergleichVonUtc liegen. Übergabe als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000; keine Zeitzonenumrechnung. Jede untere Grenze muss vor ihrer oberen liegen; BaselineBisUtc darf VergleichVonUtc nicht überschreiten. Vollständig überlappende Runtimeintervalle werden einbezogen, keine anteilige Kürzung. Jeder automatisch berechnete NULL-Beginn benötigt eine darstellbare Stunde vor seinem effektiven Ende. Wenn Vergleichsbeginn und beide Baselinegrenzen NULL bleiben, muss ein gesetztes Vergleichsende mindestens 0001-01-01T02:00:00.0000000 betragen. Frühere Werte können bei DATEADD vor der normalen Fachvalidierung ungefangen überlaufen; vollständig gesetzte gültige Fenster bleiben zulässig.';
        PRINT N'@VergleichVonUtc datetime2(7); Default: NULL. Optionale UTC-Untergrenze des Vergleichsfensters. Wenn NULL, wird eine Stunde vor @VergleichBisUtc berechnet; wenn auch das Ende NULL ist, gilt zunächst jetzt in UTC. Die Grenze muss vor @VergleichBisUtc liegen. Baseline und Vergleich dürfen sich nicht überlappen. Übergabe als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000; keine Zeitzonenumrechnung. Jede untere Grenze muss vor ihrer oberen liegen; BaselineBisUtc darf VergleichVonUtc nicht überschreiten. Vollständig überlappende Runtimeintervalle werden einbezogen, keine anteilige Kürzung. Jeder automatisch berechnete NULL-Beginn benötigt eine darstellbare Stunde vor seinem effektiven Ende. Wenn Vergleichsbeginn und beide Baselinegrenzen NULL bleiben, muss ein gesetztes Vergleichsende mindestens 0001-01-01T02:00:00.0000000 betragen. Frühere Werte können bei DATEADD vor der normalen Fachvalidierung ungefangen überlaufen; vollständig gesetzte gültige Fenster bleiben zulässig.';
        PRINT N'@VergleichBisUtc datetime2(7); Default: NULL. Optionale UTC-Obergrenze des Vergleichsfensters. Wenn NULL, gilt SYSUTCDATETIME() zum Aufruf. Jede gesetzte Grenze bleibt erhalten; aus den vier einzeln abgeleiteten Grenzen entsteht keine automatische Gleichlängenregel. Die Grenze muss nach @VergleichVonUtc liegen. Übergabe als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000; keine Zeitzonenumrechnung. Jede untere Grenze muss vor ihrer oberen liegen; BaselineBisUtc darf VergleichVonUtc nicht überschreiten. Vollständig überlappende Runtimeintervalle werden einbezogen, keine anteilige Kürzung. Jeder automatisch berechnete NULL-Beginn benötigt eine darstellbare Stunde vor seinem effektiven Ende. Wenn Vergleichsbeginn und beide Baselinegrenzen NULL bleiben, muss ein gesetztes Vergleichsende mindestens 0001-01-01T02:00:00.0000000 betragen. Frühere Werte können bei DATEADD vor der normalen Fachvalidierung ungefangen überlaufen; vollständig gesetzte gültige Fenster bleiben zulässig.';
        PRINT N'@Metrik varchar(32); Default: ''DURATION_AVG''. NULL wird wie DURATION_AVG behandelt; außen getrimmt und in Großbuchstaben normalisiert. Zulässige geschlossene Werte: DURATION_AVG = ausführungsgewichtete durchschnittliche Dauer in ms je Ausführung; CPU_AVG = gewichtete durchschnittliche CPU-Zeit in ms je Ausführung; READS_AVG = gewichtete durchschnittliche logische Reads je Ausführung; WRITES_AVG = gewichtete durchschnittliche logische Writes je Ausführung; EXECUTIONS = Ausführungszahl im Fenster. Für Dauer/CPU werden Quellwerte in Mikrosekunden durch 1000 in ms umgerechnet. Es werden nur Queries mit Werten in beiden Fenstern und einer berechneten Änderung mindestens @MinRegressionProzent ausgegeben. Prozent = 100 × (Vergleich − Baseline) / ABS(Baseline); bei Baseline 0 ist der Prozentwert NULL und erfüllt den Mindestfilter nicht. Der Schwellenwert wird mit dem vor der Ausgabe-Rundung berechneten Float-Prozentwert verglichen; Baselinewert 0 ergibt durch NULLIF NULL und wird durch das WHERE-Prädikat ausgeschlossen. Maßgeblich ist der bei SQL-Bindung auf die deklarierte Typbreite zugewiesene Wert; LTRIM/RTRIM entfernt äußere U+0020-Leerzeichen. Leer, nur U+0020 oder andere Werte sind im normalen Analysepfad ungültig.';
        PRINT N'@MinAusfuehrungenJeFenster bigint; Default: 1. Mindestzahl der Ausführungen in jedem der beiden Fenster; Werte kleiner 1 sind ungültig. SQL-Prädikate filtern je Fenster vor dem Vergleich. NULL führt nicht pauschal zu INVALID_PARAMETER, erfüllt aber den Mindestvergleich nicht und ergibt damit keine Regressionstreffer. Als ganze Zahl von 1 bis 9223372036854775807 übergeben.';
        PRINT N'@MinRegressionProzent decimal(9,2); Default: 20.0. Mindestwert für die prozentuale Änderung der ausgewählten Metrik, verglichen mit 100 × (Vergleich − Baseline) / ABS(Baseline). Negative Werte sind ungültig. NULL ist kein allgemeiner Parameterfehler, lässt das SQL-Schwellenprädikat aber UNKNOWN werden und liefert daher keine Regressionstreffer. Als dezimalen Zahlenwert von 0.00 bis 9999999.99 übergeben, zum Beispiel 20.00. Zuweisung an decimal(9,2) erfolgt vor der Prüfung und kann zusätzliche Nachkommastellen runden.';
        PRINT N'@AnalyseModus varchar(16); Default: ''TOP''. NULL wird wie TOP behandelt; außen getrimmt und großgeschrieben. Geschlossene Optionen: TOP nutzt den rangbegrenzten lokalen Kandidatenpfad je Quelle; VOLL aktiviert den Deep-Check. Beide liefern weiterhin nur die nach Kriterien berechneten Regressionen. Maßgeblich ist der bei SQL-Bindung auf die deklarierte Typbreite zugewiesene Wert; LTRIM/RTRIM entfernt äußere U+0020-Leerzeichen. VOLL hebt das Zeilenlimit nicht auf. Leer, nur U+0020 oder andere Werte sind ungültig.';
        PRINT N'@MaxZeilen int; Default: 100. Globale Ausgabegrenze nach lokaler N+1-Kandidatensammlung je Quelle, Textprojektion, Truncationwarnung und Mengen-/Statuszählung. Positiver Wert begrenzt die abschließende, global nach RegressionPercent DESC und AbsoluteChange DESC sortierte Exportmenge; Gleichstände bestimmen keine eindeutige Auswahl. NULL oder 0 bedeutet unbegrenzt. Negative Werte sind ungültig. Der lokale TOP ist bei positivem Wert höchstens @MaxZeilen+1 (bei int-Maximalwert ohne Addition); er begrenzt nicht pauschal alle gelesenen Query-Store-Runtimezeilen. @Limit > 1000 aktiviert QUERY_STORE_DEEP; bei NULL/0 ist das Limit maximal und Deep daher aktiv. Als ganze Zahl im SQL-int-Bereich bis 2147483647 übergeben.';
        PRINT N'@MaxSqlTextZeichen int; Default: 4000. Begrenzt die projizierte Länge von QuerySqlText in den lokal gesammelten Ergebnissen. NULL oder 0 bedeutet unbegrenzt; negative Werte sind ungültig. Projektion und Truncationmetadaten/-warnung werden vor der abschließenden globalen @MaxZeilen-Ausgabegrenze berechnet; die Begrenzung spart daher nicht die vorherige Quellaggregation. Die Unicode-Projektion zählt Zeichen mit SC-Collation und schneidet Surrogatpaare nicht auseinander. Als ganze Zahl im SQL-int-Bereich bis 2147483647 übergeben.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Ausgelassen: CONSOLE. Nach U+0020-Trim/Großschreibung sind genau vier Werte erlaubt: RAW liefert drei Resultsets (Metadaten, regressions, Warnungen); CONSOLE liefert die fachliche Exportmenge mit Ergebnislabel oder bei Leere eine Hinweiszeile, ohne zusätzliche Metadaten-/Warnungsgrids; TABLE schreibt nur regressions ins geprüfte lokale Temp-Ziel; NONE unterdrückt normale Fachresultsets. JSON ist unabhängig. NULL, leer, nur Leerzeichen und andere Werte sind im normalen Analysepfad ungültig. Der TABLE-Preflight liegt vor Hilfe und Fachvalidierung. Der Eingabewert unterliegt der varchar(16)-Bindungsbreite.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. außerhalb TABLE nur NULL, leer oder Leerzeichen zulässig; anderer nichtleerer Inhalt wirft 51011. Bei TABLE nichtleeres JSON-Objekt mit genau dem Schlüssel regressions und einem Ziel. Ziel: vorhandene, leere lokale #Temp-Tabelle (kein ##), maximal 116 Zeichen und genau eine beliebige Seed-Spalte; das volle Ergebnis-Schema muss nicht angelegt werden. Fehlendes/ungültiges Mapping/Ziel wird im frühen Preflight abgelehnt; leerer Wert ist in TABLE ungültig. Schlüssel binär exakt und ohne Duplikate; Ziele dürfen weder ## noch das reservierte #Monitor-Präfix verwenden. Ein Seed-Datensatz ist nicht zulässig; der Writer ersetzt die Seed-Struktur durch das Ergebnisschema.';
        PRINT N'@JsonErzeugen bit; Default: 0. Steuert unabhängig von @ResultSetArt, ob JSON in @Json aufgebaut wird. SQL-bit-Konvertierung: numerische Eingaben ungleich 0 werden 1, 0 wird 0; NULL erzeugt kein JSON.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Parameter. Zum Empfang nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Beim Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 gefüllt; bei Hilfe bleibt es NULL. Ausgelassen gilt der Vorgabewert, das Ergebnis ist dann nicht abrufbar. Leerwert als Eingabe wird nicht ausgewertet. Bei ungefangenem THROW besteht keine Zusage einer OUTPUT-Rückübertragung.';
        PRINT N'@PrintMeldungen bit; Default: 1. ausgelassen lässt Meldungen zu. 1 erlaubt Fehlerhinweise und die Truncationwarnung; 0 unterdrückt diese Meldungen. NULL unterdrückt die Truncationwarnung und erfüllt die direkte Fehlerausgabebedingung nicht. Status, Resultsets und Datenmenge bleiben davon unberührt. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.';
        PRINT N'@Hilfe bit; Default: 0. ausgelassen/NULL führt normal aus. Nur 1 druckt die Hilfe und beendet vor normaler Parameter- und Datenvalidierung. Rohe SQL-Bindung und früher TABLE-Mapping-Preflight bleiben aktiv und können vorher scheitern; @Json wurde beim Eintritt geleert. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.';
        PRINT N'EXEC [monitor].[USP_QueryStoreRegressions] @Hilfe=1;';
        PRINT N'EXEC [monitor].[USP_QueryStoreRegressions] @QueryStoreDatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''RAW'';';
        PRINT N'DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreRegressions] @QueryStoreDatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];';
        PRINT N'CREATE TABLE [#QueryStoreRegressions_HelpExample]([Seed] int NULL);
BEGIN TRY
 EXEC [monitor].[USP_QueryStoreRegressions] @QueryStoreDatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"regressions":"#QueryStoreRegressions_HelpExample"}'';
 SELECT * FROM [#QueryStoreRegressions_HelpExample];
 DROP TABLE IF EXISTS [#QueryStoreRegressions_HelpExample];
END TRY
BEGIN CATCH
 DROP TABLE IF EXISTS [#QueryStoreRegressions_HelpExample];
 THROW;
END CATCH;';
  -- USAGE_SKILL_HELP_BEGIN monitor.USP_QueryStoreRegressions
  SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'USP_QueryStoreRegressions') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.USP_QueryStoreRegressions"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "USP_QueryStoreRegressions"'
            + NCHAR(10)
            + N'object_type: "PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Vergleicht zwei Query-Store-Zeitfenster über eine oder mehrere Quelldatenbanken."'
            + NCHAR(10)
            + N'source_path: "Code/05_QueryStore/050_USP_QueryStoreRegressions.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.USP_QueryStoreRegressions'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Vergleicht zwei Query-Store-Zeitfenster über eine oder mehrere Quelldatenbanken. Lokales N+1 und globales Top-N vermeiden eine vollständige Materialisierung aller Query-Store-Zeilen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_QueryStoreRegressions]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `[monitor].[TVF_ParsePattern]`, `[monitor].[TVF_ParseSqlNameList]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `[monitor].[InternalCheckAnalysisPath]`, `[master].[sys].[databases]`, `[sys].[database_query_store_options]`, `[sys].[query_store_runtime_stats]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| @QueryStoreDatabaseNames | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @QueryStoreDatabaseNamePattern | nvarchar(4000) | nein | NULL |'
            + NCHAR(10)
            + N'| @HighImpactConfirmed | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @ReferencedDatabaseNames | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @ReferencedDatabaseNamePattern | nvarchar(4000) | nein | NULL |'
            + NCHAR(10)
            + N'| @QueryId | bigint | nein | NULL |'
            + NCHAR(10)
            + N'| @QueryHash | binary(8) | nein | NULL |'
            + NCHAR(10)
            + N'| @BaselineVonUtc | datetime2(7) | nein | NULL |'
            + NCHAR(10)
            + N'| @BaselineBisUtc | datetime2(7) | nein | NULL |'
            + NCHAR(10)
            + N'| @VergleichVonUtc | datetime2(7) | nein | NULL |'
            + NCHAR(10)
            + N'| @VergleichBisUtc | datetime2(7) | nein | NULL |'
            + NCHAR(10)
            + N'| @Metrik | varchar(32) | nein | ''DURATION_AVG'' |'
            + NCHAR(10)
            + N'| @MinAusfuehrungenJeFenster | bigint | nein | 1 |'
            + NCHAR(10)
            + N'| @MinRegressionProzent | decimal(9,2) | nein | 20.0 |'
            + NCHAR(10)
            + N'| @AnalyseModus | varchar(16) | nein | ''TOP'' |'
            + NCHAR(10)
            + N'| @MaxZeilen | int | nein | 100 |'
            + NCHAR(10)
            + N'| @MaxSqlTextZeichen | int | nein | 4000 |'
            + NCHAR(10)
            + N'| @ResultSetArt | varchar(16) | nein | ''CONSOLE'' |'
            + NCHAR(10)
            + N'| @ResultTablesJson | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @JsonErzeugen | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @Json | nvarchar(max) | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @PrintMeldungen | bit | nein | 1 |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@QueryStoreDatabaseNames:** @QueryStoreDatabaseNames nvarchar(max); Default: NULL. Ausgelassen/NULL, N'''' oder nur äußere U+0020-Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger SQL-Datenbanknamen, zum Beispiel N''[ExampleDatabase]|[OtherDatabase]''; | trennt außerhalb von [...], ]] maskiert ]. Leere Elemente, ungültige Namen und Duplikate sind INVALID_PARAMETER. Eine effektive nichtleere Liste ist exklusiv mit dem nicht-NULL Quellpattern. Ohne Filter werden sichtbare geeignete Online-Benutzerdatenbanken gewählt; Systemdatenbanken bleiben ausgeschlossen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@QueryStoreDatabaseNamePattern:** @QueryStoreDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung entfernen. Ohne Präfix gilt LIKE; Rest wird nicht erneut getrimmt. Leer oder leer nach Präfix ist ungültig; exklusiv mit @QueryStoreDatabaseNames. REGEX/REGEXI laufen in der Installationsdatenbank und benötigen SQL Server 2025 plus CL170 dort; Syntax wird nicht vorab validiert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. ausgelassen/0 = nicht bestätigt. NULL ist im Datenbankhelfer INVALID_PARAMETER. 1 bestätigt nur ein aktiviertes Gruppengate: QUERY_STORE_CURRENT hat kein Gruppengate, QUERY_STORE_DEEP verwendet es. Die Bestätigung ändert keinen Scope und erteilt weder SQL-Berechtigung noch Gruppenmitgliedschaft. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ReferencedDatabaseNames:** @ReferencedDatabaseNames nvarchar(max); Default: NULL. ausgelassen/NULL kein Showplan-Referenzfilter. Sonst nichtleere bracket-aware Pipe-Liste einteiliger SQL-Namen; | trennt außerhalb von [...], ]] maskiert ]. Leerwert/Leerzeichen ungültig. Teil 1 muss nicht NULL, Teil 2 NULL und LEN(Teil 1) höchstens 128 sein. Punkte außerhalb eines einzelnen quotierten Namens sind auch bei ausgelassenen Qualifizierern ungültig. Gültige Namen werden mit expliziter Framework-Collation SQL_Latin1_General_CP1_CS_AS verglichen. Duplikate sind erlaubt; EXISTS vervielfacht keine Zeilen. Exklusiv mit @ReferencedDatabaseNamePattern; setzt QUERY_STORE_DEEP voraus.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ReferencedDatabaseNamePattern:** @ReferencedDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung. Ohne Präfix LIKE; Rest wird nicht erneut getrimmt; leer/leer nach Präfix ungültig. Exklusiv mit @ReferencedDatabaseNames; setzt QUERY_STORE_DEEP voraus. REGEX/REGEXI laufen je Quelldatenbank und benötigen SQL Server 2025 sowie CL170 dort; Syntax wird nicht vorab validiert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@QueryId:** @QueryId bigint; Default: NULL. Ausgelassen/NULL: kein Query-ID-Filter. Einen ganzzahligen bigint-Wert von -9223372036854775808 bis 9223372036854775807 übergeben; keine zusätzliche Positivitäts- oder Existenzprüfung. Exakter Vergleich je Quelle; Query-IDs sind quellenspezifisch.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@QueryHash:** @QueryHash binary(8); Default: NULL. Ausgelassen/NULL: kein Hashfilter. Acht Byte als Binärwert übergeben, zum Beispiel 0x0123456789ABCDEF; exakter Vergleich ohne zusätzliche Werte- oder Existenzprüfung. SQL-Typkonvertierungen erfolgen vor dem Procedurekörper.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@BaselineVonUtc:** @BaselineVonUtc datetime2(7); Default: NULL. Optionale UTC-Untergrenze des Baselinefensters. Jede gesetzte Grenze bleibt erhalten. Wenn NULL, wird eine Stunde vor @BaselineBisUtc berechnet; fehlt auch @BaselineBisUtc, ist dessen Default @VergleichVonUtc. Die Grenze muss vor @BaselineBisUtc liegen. Übergabe als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000; keine Zeitzonenumrechnung. Jede untere Grenze muss vor ihrer oberen liegen; BaselineBisUtc darf VergleichVonUtc nicht überschreiten. Vollständig überlappende Runtimeintervalle werden einbezogen, keine anteilige Kürzung. Jeder automatisch berechnete NULL-Beginn benötigt eine darstellbare Stunde vor seinem effektiven Ende. Wenn Vergleichsbeginn und beide Baselinegrenzen NULL bleiben, muss ein gesetztes Vergleichsende mindestens 0001-01-01T02:00:00.0000000 betragen. Frühere Werte können bei DATEADD vor der normalen Fachvalidierung ungefangen überlaufen; vollständig gesetzte gültige '
            + N'Fenster bleiben zulässig.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@BaselineBisUtc:** @BaselineBisUtc datetime2(7); Default: NULL. Optionale UTC-Obergrenze des Baselinefensters. Wenn NULL, gilt @VergleichVonUtc. Die Grenze muss nach @BaselineVonUtc liegen und darf nicht nach @VergleichVonUtc liegen. Übergabe als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000; keine Zeitzonenumrechnung. Jede untere Grenze muss vor ihrer oberen liegen; BaselineBisUtc darf VergleichVonUtc nicht überschreiten. Vollständig überlappende Runtimeintervalle werden einbezogen, keine anteilige Kürzung. Jeder automatisch berechnete NULL-Beginn benötigt eine darstellbare Stunde vor seinem effektiven Ende. Wenn Vergleichsbeginn und beide Baselinegrenzen NULL bleiben, muss ein gesetztes Vergleichsende mindestens 0001-01-01T02:00:00.0000000 betragen. Frühere Werte können bei DATEADD vor der normalen Fachvalidierung ungefangen überlaufen; vollständig gesetzte gültige Fenster bleiben zulässig.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@VergleichVonUtc:** @VergleichVonUtc datetime2(7); Default: NULL. Optionale UTC-Untergrenze des Vergleichsfensters. Wenn NULL, wird eine Stunde vor @VergleichBisUtc berechnet; wenn auch das Ende NULL ist, gilt zunächst jetzt in UTC. Die Grenze muss vor @VergleichBisUtc liegen. Baseline und Vergleich dürfen sich nicht überlappen. Übergabe als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000; keine Zeitzonenumrechnung. Jede untere Grenze muss vor ihrer oberen liegen; BaselineBisUtc darf VergleichVonUtc nicht überschreiten. Vollständig überlappende Runtimeintervalle werden einbezogen, keine anteilige Kürzung. Jeder automatisch berechnete NULL-Beginn benötigt eine darstellbare Stunde vor seinem effektiven Ende. Wenn Vergleichsbeginn und beide Baselinegrenzen NULL bleiben, muss ein gesetztes Vergleichsende mindestens 0001-01-01T02:00:00.0000000 betragen. Frühere Werte können bei DATEADD vor der normalen Fachvalidierung ungefangen überlaufen; vollständig gese'
            + N'tzte gültige Fenster bleiben zulässig.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@VergleichBisUtc:** @VergleichBisUtc datetime2(7); Default: NULL. Optionale UTC-Obergrenze des Vergleichsfensters. Wenn NULL, gilt SYSUTCDATETIME() zum Aufruf. Jede gesetzte Grenze bleibt erhalten; aus den vier einzeln abgeleiteten Grenzen entsteht keine automatische Gleichlängenregel. Die Grenze muss nach @VergleichVonUtc liegen. Übergabe als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000; keine Zeitzonenumrechnung. Jede untere Grenze muss vor ihrer oberen liegen; BaselineBisUtc darf VergleichVonUtc nicht überschreiten. Vollständig überlappende Runtimeintervalle werden einbezogen, keine anteilige Kürzung. Jeder automatisch berechnete NULL-Beginn benötigt eine darstellbare Stunde vor seinem effektiven Ende. Wenn Vergleichsbeginn und beide Baselinegrenzen NULL bleiben, muss ein gesetztes Vergleichsende mindestens 0001-01-01T02:00:00.0000000 betragen. Frühere Werte können bei DATEADD vor der normalen Fachvalidierung ungefangen überlaufen; vollständig ge'
            + N'setzte gültige Fenster bleiben zulässig.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Metrik:** @Metrik varchar(32); Default: ''DURATION_AVG''. NULL wird wie DURATION_AVG behandelt; außen getrimmt und in Großbuchstaben normalisiert. Zulässige geschlossene Werte: DURATION_AVG = ausführungsgewichtete durchschnittliche Dauer in ms je Ausführung; CPU_AVG = gewichtete durchschnittliche CPU-Zeit in ms je Ausführung; READS_AVG = gewichtete durchschnittliche logische Reads je Ausführung; WRITES_AVG = gewichtete durchschnittliche logische Writes je Ausführung; EXECUTIONS = Ausführungszahl im Fenster. Für Dauer/CPU werden Quellwerte in Mikrosekunden durch 1000 in ms umgerechnet. Es werden nur Queries mit Werten in beiden Fenstern und einer berechneten Änderung mindestens @MinRegressionProzent ausgegeben. Prozent = 100 × (Vergleich − Baseline) / ABS(Baseline); bei Baseline 0 ist der Prozentwert NULL und erfüllt den Mindestfilter nicht. Der Schwellenwert wird mit dem vor der Ausgabe-Rundung berechneten Float-Prozentwert verglichen; Baselinewert 0 ergibt durch NULLIF NULL und wird '
            + N'durch das WHERE-Prädikat ausgeschlossen. Maßgeblich ist der bei SQL-Bindung auf die deklarierte Typbreite zugewiesene Wert; LTRIM/RTRIM entfernt äußere U+0020-Leerzeichen. Leer, nur U+0020 oder andere Werte sind im normalen Analysepfad ungültig.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MinAusfuehrungenJeFenster:** @MinAusfuehrungenJeFenster bigint; Default: 1. Mindestzahl der Ausführungen in jedem der beiden Fenster; Werte kleiner 1 sind ungültig. SQL-Prädikate filtern je Fenster vor dem Vergleich. NULL führt nicht pauschal zu INVALID_PARAMETER, erfüllt aber den Mindestvergleich nicht und ergibt damit keine Regressionstreffer. Als ganze Zahl von 1 bis 9223372036854775807 übergeben.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MinRegressionProzent:** @MinRegressionProzent decimal(9,2); Default: 20.0. Mindestwert für die prozentuale Änderung der ausgewählten Metrik, verglichen mit 100 × (Vergleich − Baseline) / ABS(Baseline). Negative Werte sind ungültig. NULL ist kein allgemeiner Parameterfehler, lässt das SQL-Schwellenprädikat aber UNKNOWN werden und liefert daher keine Regressionstreffer. Als dezimalen Zahlenwert von 0.00 bis 9999999.99 übergeben, zum Beispiel 20.00. Zuweisung an decimal(9,2) erfolgt vor der Prüfung und kann zusätzliche Nachkommastellen runden.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@AnalyseModus:** @AnalyseModus varchar(16); Default: ''TOP''. NULL wird wie TOP behandelt; außen getrimmt und großgeschrieben. Geschlossene Optionen: TOP nutzt den rangbegrenzten lokalen Kandidatenpfad je Quelle; VOLL aktiviert den Deep-Check. Beide liefern weiterhin nur die nach Kriterien berechneten Regressionen. Maßgeblich ist der bei SQL-Bindung auf die deklarierte Typbreite zugewiesene Wert; LTRIM/RTRIM entfernt äußere U+0020-Leerzeichen. VOLL hebt das Zeilenlimit nicht auf. Leer, nur U+0020 oder andere Werte sind ungültig.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxZeilen:** @MaxZeilen int; Default: 100. Globale Ausgabegrenze nach lokaler N+1-Kandidatensammlung je Quelle, Textprojektion, Truncationwarnung und Mengen-/Statuszählung. Positiver Wert begrenzt die abschließende, global nach RegressionPercent DESC und AbsoluteChange DESC sortierte Exportmenge; Gleichstände bestimmen keine eindeutige Auswahl. NULL oder 0 bedeutet unbegrenzt. Negative Werte sind ungültig. Der lokale TOP ist bei positivem Wert höchstens @MaxZeilen+1 (bei int-Maximalwert ohne Addition); er begrenzt nicht pauschal alle gelesenen Query-Store-Runtimezeilen. @Limit > 1000 aktiviert QUERY_STORE_DEEP; bei NULL/0 ist das Limit maximal und Deep daher aktiv. Als ganze Zahl im SQL-int-Bereich bis 2147483647 übergeben.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxSqlTextZeichen:** @MaxSqlTextZeichen int; Default: 4000. Begrenzt die projizierte Länge von QuerySqlText in den lokal gesammelten Ergebnissen. NULL oder 0 bedeutet unbegrenzt; negative Werte sind ungültig. Projektion und Truncationmetadaten/-warnung werden vor der abschließenden globalen @MaxZeilen-Ausgabegrenze berechnet; die Begrenzung spart daher nicht die vorherige Quellaggregation. Die Unicode-Projektion zählt Zeichen mit SC-Collation und schneidet Surrogatpaare nicht auseinander. Als ganze Zahl im SQL-int-Bereich bis 2147483647 übergeben.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultSetArt:** @ResultSetArt varchar(16); Default: ''CONSOLE''. Ausgelassen: CONSOLE. Nach U+0020-Trim/Großschreibung sind genau vier Werte erlaubt: RAW liefert drei Resultsets (Metadaten, regressions, Warnungen); CONSOLE liefert die fachliche Exportmenge mit Ergebnislabel oder bei Leere eine Hinweiszeile, ohne zusätzliche Metadaten-/Warnungsgrids; TABLE schreibt nur regressions ins geprüfte lokale Temp-Ziel; NONE unterdrückt normale Fachresultsets. JSON ist unabhängig. NULL, leer, nur Leerzeichen und andere Werte sind im normalen Analysepfad ungültig. Der TABLE-Preflight liegt vor Hilfe und Fachvalidierung. Der Eingabewert unterliegt der varchar(16)-Bindungsbreite.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. außerhalb TABLE nur NULL, leer oder Leerzeichen zulässig; anderer nichtleerer Inhalt wirft 51011. Bei TABLE nichtleeres JSON-Objekt mit genau dem Schlüssel regressions und einem Ziel. Ziel: vorhandene, leere lokale #Temp-Tabelle (kein ##), maximal 116 Zeichen und genau eine beliebige Seed-Spalte; das volle Ergebnis-Schema muss nicht angelegt werden. Fehlendes/ungültiges Mapping/Ziel wird im frühen Preflight abgelehnt; leerer Wert ist in TABLE ungültig. Schlüssel binär exakt und ohne Duplikate; Ziele dürfen weder ## noch das reservierte #Monitor-Präfix verwenden. Ein Seed-Datensatz ist nicht zulässig; der Writer ersetzt die Seed-Struktur durch das Ergebnisschema.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Steuert unabhängig von @ResultSetArt, ob JSON in @Json aufgebaut wird. SQL-bit-Konvertierung: numerische Eingaben ungleich 0 werden 1, 0 wird 0; NULL erzeugt kein JSON.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Parameter. Zum Empfang nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Beim Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 gefüllt; bei Hilfe bleibt es NULL. Ausgelassen gilt der Vorgabewert, das Ergebnis ist dann nicht abrufbar. Leerwert als Eingabe wird nicht ausgewertet. Bei ungefangenem THROW besteht keine Zusage einer OUTPUT-Rückübertragung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. ausgelassen lässt Meldungen zu. 1 erlaubt Fehlerhinweise und die Truncationwarnung; 0 unterdrückt diese Meldungen. NULL unterdrückt die Truncationwarnung und erfüllt die direkte Fehlerausgabebedingung nicht. Status, Resultsets und Datenmenge bleiben davon unberührt. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** @Hilfe bit; Default: 0. ausgelassen/NULL führt normal aus. Nur 1 druckt die Hilfe und beendet vor normaler Parameter- und Datenvalidierung. Rohe SQL-Bindung und früher TABLE-Mapping-Preflight bleiben aktiv und können vorher scheitern; @Json wurde beim Eintritt geleert. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'RAW/CONSOLE/NONE; JSON mit meta, regressions und warnings.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Resultmenge | RAW | TABLE | Felder laut Inventar |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| regressions | 1 | 1 | [QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[QueryId] bigint,[QueryHash] binary(8),[ObjectId] bigint NULL,[ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[BaselineExecutions] bigint,[ComparisonExecutions] bigint,[BaselinePlanCount] bigint,[ComparisonPlanCount] bigint,[BaselineValue] decimal(38,3),[ComparisonValue] decimal(38,3),[AbsoluteChange] decimal(38,3),[RegressionPercent] decimal(38,3),[LastExecutionTimeUtc] datetimeoffset,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CapturedAtUtc] datetime2(3) NULL,[EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsAggregated] bit NULL,[QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NOT NULL DEFAULT(0),[Evidence'
            + N'Limit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |'
            + NCHAR(10)
            + NCHAR(10)
            + N'Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[USP_QueryStoreRegressions] @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'monitor.USP_QueryStoreRegressions'
            + NCHAR(10)
            + NCHAR(10)
            + N'monitor.USP_QueryStoreRegressions vergleicht aggregierte Query-Store-Werte aus zwei nicht überlappenden UTC-Zeitfenstern je ausgewählter Quelldatenbank. Die zugrunde liegenden Runtimeintervalle können beide Fenster überlappen und werden dann jeweils vollständig einbezogen, nicht anteilig zerlegt. Die Daten hängen von Query-Store-Capture und Retention ab; sie belegen weder eine Ursache noch allgemeine Performance.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Zeitfenster und Intervalle: Jede gesetzte Grenze bleibt erhalten. NULL-Ende des Vergleichs = jetzt UTC; NULL-Start = eine Stunde davor. NULL-Ende der Baseline = Vergleichsstart; NULL-Start der Baseline = eine Stunde davor. Diese Defaults werden einzeln berechnet und halten bei geänderten Grenzen keine gleiche Fensterlänge ein. Runtimeintervalle werden bei Überlappung vollständig einbezogen, nicht anteilig auf Fenstergrenzen zerlegt. Ausführungen und gewichtete Messwerte werden je Query/Fenster summiert; Plananzahl zählt unterschiedliche PlanIds.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Analysepfad: QUERY_STORE_CURRENT wird für die Datenbankauswahl geprüft. QUERY_STORE_DEEP wird zusätzlich aktiviert bei @AnalyseModus=VOLL, normalisiertem @MaxZeilen-Limit > 1000 (NULL/0 ist unbegrenzt und damit ebenfalls > 1000), DATEDIFF(HOUR,@BaselineVonUtc,@VergleichBisUtc)>24 (Stundengrenzen gemäß DATEDIFF) oder jedem gesetzten Referenzfilter. Die jeweilige Katalogklasse kann @HighImpactConfirmed=1 erfordern; Zugriffsrichtlinien können zusätzlich sperren.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Grenzen: Pro Datenbank werden lokal höchstens N+1 Kandidaten für das globale Limit gesammelt; damit sind nicht alle zuvor gelesenen Query-Store-Zeilen begrenzt. @MaxSqlTextZeichen wirkt nach Quellaggregation und Filterung auf die Textprojektion. Textprojektion, Truncationwarnungen sowie Anzahl/hasMoreRows werden vor dem abschließenden globalen Limit bestimmt. Die globale Sortierung ist RegressionPercent DESC, AbsoluteChange DESC; Gleichstände garantieren keine bestimmte Auswahl.'
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Objekt       : monitor.USP_QueryStoreRegressions'
            + NCHAR(10)
            + N'Version      : 2.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-15'
            + NCHAR(10)
            + N'Zweck        : Vergleicht zwei Query-Store-Zeitfenster über eine oder mehrere'
            + NCHAR(10)
            + N'               Quelldatenbanken. Lokales N+1 und globales Top-N vermeiden eine'
            + NCHAR(10)
            + N'               vollständige Materialisierung aller Query-Store-Zeilen.'
            + NCHAR(10)
            + N'Ausgabe      : RAW/CONSOLE/NONE; JSON mit meta, regressions und warnings.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Weitere bestehende Hilfehinweise'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'monitor.USP_QueryStoreRegressions'
            + NCHAR(10)
            + N'monitor.USP_QueryStoreRegressions vergleicht aggregierte Query-Store-Werte aus zwei nicht überlappenden UTC-Zeitfenstern je ausgewählter Quelldatenbank. Die zugrunde liegenden Runtimeintervalle können beide Fenster überlappen und werden dann jeweils vollständig einbezogen, nicht anteilig zerlegt. Die Daten hängen von Query-Store-Capture und Retention ab; sie belegen weder eine Ursache noch allgemeine Performance.'
            + NCHAR(10)
            + N'Zeitfenster und Intervalle: Jede gesetzte Grenze bleibt erhalten. NULL-Ende des Vergleichs = jetzt UTC; NULL-Start = eine Stunde davor. NULL-Ende der Baseline = Vergleichsstart; NULL-Start der Baseline = eine Stunde davor. Diese Defaults werden einzeln berechnet und halten bei geänderten Grenzen keine gleiche Fensterlänge ein. Runtimeintervalle werden bei Überlappung vollständig einbezogen, nicht anteilig auf Fenstergrenzen zerlegt. Ausführungen und gewichtete Messwerte werden je Query/Fenster summiert; Plananzahl zählt unterschiedliche PlanIds.'
            + NCHAR(10)
            + N'Analysepfad: QUERY_STORE_CURRENT wird für die Datenbankauswahl geprüft. QUERY_STORE_DEEP wird zusätzlich aktiviert bei @AnalyseModus=VOLL, normalisiertem @MaxZeilen-Limit > 1000 (NULL/0 ist unbegrenzt und damit ebenfalls > 1000), DATEDIFF(HOUR,@BaselineVonUtc,@VergleichBisUtc)>24 (Stundengrenzen gemäß DATEDIFF) oder jedem gesetzten Referenzfilter. Die jeweilige Katalogklasse kann @HighImpactConfirmed=1 erfordern; Zugriffsrichtlinien können zusätzlich sperren.'
            + NCHAR(10)
            + N'Grenzen: Pro Datenbank werden lokal höchstens N+1 Kandidaten für das globale Limit gesammelt; damit sind nicht alle zuvor gelesenen Query-Store-Zeilen begrenzt. @MaxSqlTextZeichen wirkt nach Quellaggregation und Filterung auf die Textprojektion. Textprojektion, Truncationwarnungen sowie Anzahl/hasMoreRows werden vor dem abschließenden globalen Limit bestimmt. Die globale Sortierung ist RegressionPercent DESC, AbsoluteChange DESC; Gleichstände garantieren keine bestimmte Auswahl.'
            + NCHAR(10)
            + N'Die beschriebenen fachlichen Validierungen gelten im normalen Analysepfad. @Hilfe=1 kehrt vorher zurück; SQL-Typbindung und frühe Mappingprüfungen bleiben aktiv. Ausgelassen gilt bei jedem Parameter der ausdrücklich angegebene Default.'
            + NCHAR(10)
            + N'DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreRegressions] @QueryStoreDatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];'
            + NCHAR(10)
            + N'C'
            + N'REATE TABLE [#QueryStoreRegressions_HelpExample]([Seed] int NULL);'
            + NCHAR(10)
            + N'BEGIN TRY'
            + NCHAR(10)
            + N' EXEC [monitor].[USP_QueryStoreRegressions] @QueryStoreDatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"regressions":"#QueryStoreRegressions_HelpExample"}'';'
            + NCHAR(10)
            + N' SELECT * FROM [#QueryStoreRegressions_HelpExample];'
            + NCHAR(10)
            + N' DROP TABLE IF EXISTS [#QueryStoreRegressions_HelpExample];'
            + NCHAR(10)
            + N'END TRY'
            + NCHAR(10)
            + N'BEGIN CATCH'
            + NCHAR(10)
            + N' DROP TABLE IF EXISTS [#QueryStoreRegressions_HelpExample];'
            + NCHAR(10)
            + N' THROW;'
            + NCHAR(10)
            + N'END CATCH;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
  -- USAGE_SKILL_HELP_END monitor.USP_QueryStoreRegressions
        RETURN;
 END
SET @Json=NULL;SET @Metrik=UPPER(LTRIM(RTRIM(COALESCE(@Metrik,'DURATION_AVG'))));SET @AnalyseModus=UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus,'TOP'))));
 CREATE TABLE [#QueryStoreRegressions_Export]([QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[QueryId] bigint,[QueryHash] binary(8),[ObjectId] bigint NULL,[ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[BaselineExecutions] bigint,[ComparisonExecutions] bigint,[BaselinePlanCount] bigint,[ComparisonPlanCount] bigint,[BaselineValue] decimal(38,3),[ComparisonValue] decimal(38,3),[AbsoluteChange] decimal(38,3),[RegressionPercent] decimal(38,3),[LastExecutionTimeUtc] datetimeoffset,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CapturedAtUtc] datetime2(3) NULL,[EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsAggregated] bit NULL,[QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NOT NULL DEFAULT(0),[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
 DECLARE @Out varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),@Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) WHEN @MaxZeilen>0 THEN @MaxZeilen ELSE 0 END,@Local bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) WHEN @MaxZeilen<2147483647 THEN CONVERT(bigint,@MaxZeilen)+1 ELSE @MaxZeilen END;
    DECLARE @TableResultRequested bit = CASE WHEN @Out = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @Out = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'regressions',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @Out = 'NONE';
 ;
 IF @VergleichBisUtc IS NULL SET @VergleichBisUtc=SYSUTCDATETIME();IF @VergleichVonUtc IS NULL SET @VergleichVonUtc=DATEADD(HOUR,-1,@VergleichBisUtc);IF @BaselineBisUtc IS NULL SET @BaselineBisUtc=@VergleichVonUtc;IF @BaselineVonUtc IS NULL SET @BaselineVonUtc=DATEADD(HOUR,-1,@BaselineBisUtc);
 DECLARE @Now datetime2(3)=SYSUTCDATETIME(),@Status varchar(40)='AVAILABLE',@Partial bit=0,@Error nvarchar(2048)=NULL,@Cross bit=0,@Allowed bit=1,@Db sysname,@Compat tinyint,@Sql nvarchar(max),@Count bigint=0,@HasMore bit=0,@Msg nvarchar(2048),@MetricB nvarchar(240),@MetricC nvarchar(240),@RefMode varchar(8),@RefValue nvarchar(4000),@RefFlags varchar(8),@RefValid bit,@RefPredicate nvarchar(max)=N'';
 SELECT @RefMode=[PatternMode],@RefValue=[PatternValue],@RefFlags=[RegexFlags],@RefValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@ReferencedDatabaseNamePattern);
 SET @MetricB=CASE @Metrik WHEN 'DURATION_AVG' THEN N'[b].[duration_weighted]/NULLIF([b].[executions],0)/1000.0' WHEN 'CPU_AVG' THEN N'[b].[cpu_weighted]/NULLIF([b].[executions],0)/1000.0' WHEN 'READS_AVG' THEN N'[b].[reads_weighted]/NULLIF([b].[executions],0)' WHEN 'WRITES_AVG' THEN N'[b].[writes_weighted]/NULLIF([b].[executions],0)' WHEN 'EXECUTIONS' THEN N'CONVERT(float,[b].[executions])' END;
 SET @MetricC=CASE @Metrik WHEN 'DURATION_AVG' THEN N'[c].[duration_weighted]/NULLIF([c].[executions],0)/1000.0' WHEN 'CPU_AVG' THEN N'[c].[cpu_weighted]/NULLIF([c].[executions],0)/1000.0' WHEN 'READS_AVG' THEN N'[c].[reads_weighted]/NULLIF([c].[executions],0)' WHEN 'WRITES_AVG' THEN N'[c].[writes_weighted]/NULLIF([c].[executions],0)' WHEN 'EXECUTIONS' THEN N'CONVERT(float,[c].[executions])' END;
 CREATE TABLE [#QueryStoreRegressions_DatabaseCandidates]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsReadOnly] bit,[CompatibilityLevel] tinyint,[CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsSystemDatabase] bit,[RequestedOrdinal] int);
 CREATE TABLE [#QueryStoreRegressions_Result]([QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[QueryId] bigint,[QueryHash] binary(8),[ObjectId] bigint NULL,[ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[BaselineExecutions] bigint,[ComparisonExecutions] bigint,[BaselinePlanCount] bigint,[ComparisonPlanCount] bigint,[BaselineValue] decimal(38,3),[ComparisonValue] decimal(38,3),[AbsoluteChange] decimal(38,3),[RegressionPercent] decimal(38,3),[LastExecutionTimeUtc] datetimeoffset,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CapturedAtUtc] datetime2(3) NULL,[EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsAggregated] bit NULL,[QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NOT NULL DEFAULT(0),[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
 CREATE TABLE [#QueryStoreRegressions_Errors]([DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS);
 IF @MetricB IS NULL OR @AnalyseModus NOT IN('TOP','VOLL') OR @MaxZeilen<0 OR @MaxSqlTextZeichen < 0 OR @MinAusfuehrungenJeFenster<1 OR @MinRegressionProzent<0 OR @BaselineVonUtc>=@BaselineBisUtc OR @VergleichVonUtc>=@VergleichBisUtc OR @BaselineBisUtc>@VergleichVonUtc OR @Out NOT IN('RAW','CONSOLE','NONE') OR @RefValid=0 OR (@ReferencedDatabaseNames IS NOT NULL AND @ReferencedDatabaseNamePattern IS NOT NULL) OR (@ReferencedDatabaseNames IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@ReferencedDatabaseNames) WHERE [IsValid]=0)) BEGIN SET @Status='INVALID_PARAMETER';SET @Error=N'Ungültige Metrik, Grenze oder Zeitfenster.';END;
 IF @Status='AVAILABLE' EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@QueryStoreDatabaseNames,@SystemdatenbankenEinbeziehen=0,@DatabaseNamePattern=@QueryStoreDatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed,@AnalysisClass='QUERY_STORE_CURRENT',@StatusCode=@Status OUTPUT,@ErrorMessage=@Error OUTPUT,@CrossDatabaseRequested=@Cross OUTPUT,@CandidateTable=N'#QueryStoreRegressions_DatabaseCandidates';
 IF @Status='AVAILABLE' AND (@AnalyseModus='VOLL' OR @Limit>1000 OR DATEDIFF(HOUR,@BaselineVonUtc,@VergleichBisUtc)>24 OR @ReferencedDatabaseNames IS NOT NULL OR @ReferencedDatabaseNamePattern IS NOT NULL) EXEC [monitor].[InternalCheckAnalysisPath] @AnalysisClass='QUERY_STORE_DEEP',@HighImpactConfirmed=@HighImpactConfirmed,@StatusCode=@Status OUTPUT,@ErrorMessage=@Error OUTPUT;
 IF @ReferencedDatabaseNames IS NOT NULL SET @RefPredicate=N' AND EXISTS(SELECT 1 FROM (SELECT CONVERT(xml,[p].[query_plan]) [PlanXml]) [px] CROSS APPLY [px].[PlanXml].nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]'') [n]([x]) JOIN ' + QUOTENAME((SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID())) + N'.[monitor].[TVF_ParseSqlNameList](@ReferencedNames) [rf] ON [rf].[IsValid]=1 AND [rf].[NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS=PARSENAME([n].[x].value(''@Database'',''nvarchar(776)''),1) COLLATE SQL_Latin1_General_CP1_CS_AS)';
 ELSE IF @RefMode='LIKE' SET @RefPredicate=N' AND EXISTS(SELECT 1 FROM (SELECT CONVERT(xml,[p].[query_plan]) [PlanXml]) [px] CROSS APPLY [px].[PlanXml].nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]'') [n]([x]) WHERE PARSENAME([n].[x].value(''@Database'',''nvarchar(776)''),1) COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @RefValue COLLATE SQL_Latin1_General_CP1_CS_AS)';
 ELSE IF @RefMode IN('REGEX','REGEXI') SET @RefPredicate=N' AND EXISTS(SELECT 1 FROM (SELECT CONVERT(xml,[p].[query_plan]) [PlanXml]) [px] CROSS APPLY [px].[PlanXml].nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]'') [n]([x]) WHERE REGEXP_LIKE(PARSENAME([n].[x].value(''@Database'',''nvarchar(776)''),1),@RefValue,@RefFlags))';
 SET LOCK_TIMEOUT 0;
 IF @Status='AVAILABLE' BEGIN DECLARE [c] CURSOR LOCAL FAST_FORWARD FOR SELECT [DatabaseName],[CompatibilityLevel] FROM [#QueryStoreRegressions_DatabaseCandidates] ORDER BY COALESCE([RequestedOrdinal],[DatabaseId]),[DatabaseId];OPEN [c];FETCH NEXT FROM [c] INTO @Db,@Compat;WHILE @@FETCH_STATUS=0 BEGIN IF @RefMode IN('REGEX','REGEXI') AND (TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<17 OR @Compat<170) BEGIN INSERT [#QueryStoreRegressions_Errors] VALUES(@Db,'UNAVAILABLE_FEATURE',NULL,N'Regex benötigt SQL Server 2025 und Compatibility Level 170.');SET @Partial=1;END ELSE BEGIN TRY
 SET @Sql=N'USE '+QUOTENAME(@Db)+N';IF EXISTS(SELECT 1 FROM [sys].[database_query_store_options] WITH (NOLOCK) WHERE [actual_state] IN(1,2,4))
BEGIN
;WITH [R0] AS
(
 SELECT [q].[query_id],[q].[query_hash],[q].[object_id],[qt].[query_sql_text],[p].[plan_id],[i].[start_time],[i].[end_time],MAX([rs].[last_execution_time]) [last_execution_time],SUM([rs].[count_executions]) [executions],SUM(CONVERT(float,[rs].[avg_duration])*[rs].[count_executions]) [duration_weighted],SUM(CONVERT(float,[rs].[avg_cpu_time])*[rs].[count_executions]) [cpu_weighted],SUM(CONVERT(float,[rs].[avg_logical_io_reads])*[rs].[count_executions]) [reads_weighted],SUM(CONVERT(float,[rs].[avg_logical_io_writes])*[rs].[count_executions]) [writes_weighted]
 FROM [sys].[query_store_runtime_stats] [rs] WITH (NOLOCK) JOIN [sys].[query_store_runtime_stats_interval] [i] WITH (NOLOCK) ON [i].[runtime_stats_interval_id]=[rs].[runtime_stats_interval_id] JOIN [sys].[query_store_plan] [p] WITH (NOLOCK) ON [p].[plan_id]=[rs].[plan_id] JOIN [sys].[query_store_query] [q] WITH (NOLOCK) ON [q].[query_id]=[p].[query_id] JOIN [sys].[query_store_query_text] [qt] WITH (NOLOCK) ON [qt].[query_text_id]=[q].[query_text_id]
 WHERE (([i].[end_time]>@BFrom AND [i].[start_time]<@BTo) OR ([i].[end_time]>@CFrom AND [i].[start_time]<@CTo)) AND (@QueryId IS NULL OR [q].[query_id]=@QueryId) AND (@QueryHash IS NULL OR [q].[query_hash]=@QueryHash)'+@RefPredicate+N'
 GROUP BY [q].[query_id],[q].[query_hash],[q].[object_id],[qt].[query_sql_text],[p].[plan_id],[i].[start_time],[i].[end_time]
),[R] AS
(
 SELECT [query_id],[query_hash],[object_id],[query_sql_text],[plan_id],[last_execution_time],[executions],[duration_weighted],[cpu_weighted],[reads_weighted],[writes_weighted],''B'' [W] FROM [R0] WHERE [end_time]>@BFrom AND [start_time]<@BTo
 UNION ALL
 SELECT [query_id],[query_hash],[object_id],[query_sql_text],[plan_id],[last_execution_time],[executions],[duration_weighted],[cpu_weighted],[reads_weighted],[writes_weighted],''C'' [W] FROM [R0] WHERE [end_time]>@CFrom AND [start_time]<@CTo
),[A] AS
(
 SELECT [query_id],[query_hash],[object_id],[query_sql_text],[W],SUM([executions]) [executions],COUNT(DISTINCT [plan_id]) [plan_count],MAX([last_execution_time]) [last_execution_time],SUM([duration_weighted]) [duration_weighted],SUM([cpu_weighted]) [cpu_weighted],SUM([reads_weighted]) [reads_weighted],SUM([writes_weighted]) [writes_weighted] FROM [R] GROUP BY [query_id],[query_hash],[object_id],[query_sql_text],[W]
),[P] AS
(
 SELECT [b].[query_id],[b].[query_hash],[b].[object_id],[b].[query_sql_text],[b].[executions] [bexec],[c].[executions] [cexec],[b].[plan_count] [bplans],[c].[plan_count] [cplans],[c].[last_execution_time],CONVERT(float,'+@MetricB+N') [bvalue],CONVERT(float,'+@MetricC+N') [cvalue] FROM [A] [b] JOIN [A] [c] ON [c].[query_id]=[b].[query_id] AND [c].[W]=''C'' WHERE [b].[W]=''B'' AND [b].[executions]>=@MinExec AND [c].[executions]>=@MinExec
)
INSERT [#QueryStoreRegressions_Result]([QueryStoreDatabaseId],[QueryStoreDatabaseName],[QueryId],[QueryHash],[ObjectId],[ObjectName],[BaselineExecutions],[ComparisonExecutions],[BaselinePlanCount],[ComparisonPlanCount],[BaselineValue],[ComparisonValue],[AbsoluteChange],[RegressionPercent],[LastExecutionTimeUtc],[QuerySqlText]) SELECT TOP(@TopRows) DB_ID(),(SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID()),[P].[query_id],[P].[query_hash],[P].[object_id],CASE WHEN [P].[object_id]>0 THEN QUOTENAME([os].[name])+N''.''+QUOTENAME([oo].[name]) END,[P].[bexec],[P].[cexec],[P].[bplans],[P].[cplans],CONVERT(decimal(38,3),[P].[bvalue]),CONVERT(decimal(38,3),[P].[cvalue]),CONVERT(decimal(38,3),[P].[cvalue]-[P].[bvalue]),CONVERT(decimal(38,3),100.0*([P].[cvalue]-[P].[bvalue])/NULLIF(ABS([P].[bvalue]),0)),[P].[last_execution_time],[P].[query_sql_text] FROM [P] LEFT JOIN [sys].[objects] AS [oo] WITH (NOLOCK) ON [oo].[object_id]=[P].[object_id] LEFT JOIN [sys].[schemas] AS [os] WITH (NOLOCK) ON [os].[schema_id]=[oo].[schema_id] WHERE [P].[bvalue] IS NOT NULL AND [P].[cvalue] IS NOT NULL AND 100.0*([P].[cvalue]-[P].[bvalue])/NULLIF(ABS([P].[bvalue]),0)>=@MinPct ORDER BY 100.0*([P].[cvalue]-[P].[bvalue])/NULLIF(ABS([P].[bvalue]),0) DESC,[P].[cvalue]-[P].[bvalue] DESC;
END;';
 EXEC [sys].[sp_executesql] @Sql,N'@BFrom datetime2(7),@BTo datetime2(7),@CFrom datetime2(7),@CTo datetime2(7),@QueryId bigint,@QueryHash binary(8),@MinExec bigint,@MinPct decimal(9,2),@TopRows bigint,@TextChars int,@ReferencedNames nvarchar(max),@RefValue nvarchar(4000),@RefFlags varchar(8)',@BaselineVonUtc,@BaselineBisUtc,@VergleichVonUtc,@VergleichBisUtc,@QueryId,@QueryHash,@MinAusfuehrungenJeFenster,@MinRegressionProzent,@Local,@MaxSqlTextZeichen,@ReferencedDatabaseNames,@RefValue,@RefFlags;
 END TRY BEGIN CATCH INSERT [#QueryStoreRegressions_Errors] VALUES(@Db,CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,ERROR_NUMBER(),ERROR_MESSAGE());SET @Partial=1;IF @PrintMeldungen=1 BEGIN SET @Msg=FORMATMESSAGE(N'WARNUNG USP_QueryStoreRegressions [%s]: %s',@Db,ERROR_MESSAGE());RAISERROR(N'%s',10,1,@Msg) WITH NOWAIT;END;END CATCH;FETCH NEXT FROM [c] INTO @Db,@Compat;END;CLOSE [c];DEALLOCATE [c];END;
 UPDATE [#QueryStoreRegressions_Result]
 SET [SourceType]='QUERY_STORE',[SourceObject]=N'sys.query_store_runtime_stats|sys.query_store_plan|sys.query_store_query_text',
     [CapturedAtUtc]=@Now,[EvidenceScope]='DATABASE_QUERY_WINDOW_COMPARISON',[IsAggregated]=1,
     [EvidenceLimit]=N'Zwei Query-Store-Zeitfenster mit aggregierten Messwerten; keine Kausalitäts- oder aktuelle Einzelausführungsaussage.';
 DECLARE @TruncatedValueCount bigint=0,@LargestRequiredCharacters bigint=NULL;
  IF @MaxSqlTextZeichen IS NULL OR @MaxSqlTextZeichen>=0
  EXEC [monitor].[InternalProjectUnicodeTextColumn] @SourceTable=N'#QueryStoreRegressions_Result',@TextColumn=N'QuerySqlText',@CharactersColumn=N'QuerySqlTextCharacters',@BytesColumn=N'QuerySqlTextBytes',@IsTruncatedColumn=N'QuerySqlTextIsTruncated',@MaxCharacters=@MaxSqlTextZeichen,@TruncatedValueCount=@TruncatedValueCount OUTPUT,@LargestRequiredCharacters=@LargestRequiredCharacters OUTPUT;
 EXEC [monitor].[InternalEmitTruncationWarning] @TruncatedValueCount=@TruncatedValueCount,@ParameterName=N'@MaxSqlTextZeichen',@ParameterValue=@MaxSqlTextZeichen,@LargestRequiredCharacters=@LargestRequiredCharacters,@PrintMeldungen=@PrintMeldungen;
 SELECT @Count=COUNT_BIG(*) FROM [#QueryStoreRegressions_Result];SET @HasMore=CONVERT(bit,CASE WHEN @Limit<9223372036854775807 AND @Count>@Limit THEN 1 ELSE 0 END);IF @Partial=1 AND @Status='AVAILABLE' SET @Status='AVAILABLE_LIMITED';
  INSERT [#QueryStoreRegressions_Export] SELECT TOP(@Limit) * FROM [#QueryStoreRegressions_Result] ORDER BY [RegressionPercent] DESC,[AbsoluteChange] DESC;
  IF @Out<>'NONE' BEGIN SELECT N'USP_QueryStoreRegressions' [ModuleName],@Now [CollectionTimeUtc],@Status [StatusCode],@Partial [IsPartial],CASE WHEN @Count>@Limit THEN @Limit ELSE @Count END [ReturnedRowCount],@HasMore [HasMoreRows],@Metrik [Metric],@Error [ErrorMessage];IF @Out='RAW' SELECT * FROM [#QueryStoreRegressions_Export] ORDER BY [RegressionPercent] DESC,[AbsoluteChange] DESC;ELSE SELECT N'Query-Store Regression' [Ergebnis],[QueryStoreDatabaseName] [Query-Store-Datenbank],[QueryId] [Query],[ObjectName] [Objekt],CONCAT(CONVERT(varchar(30),[BaselineValue]),N' → ',CONVERT(varchar(30),[ComparisonValue])) [Vergleich],CONCAT(CONVERT(varchar(30),[RegressionPercent]),N' %') [Regression],[LastExecutionTimeUtc] [letzte Ausführung],[QueryStoreDatabaseName] [Quelle],[QuerySqlText] [SQL-Text] FROM [#QueryStoreRegressions_Export] ORDER BY [RegressionPercent] DESC,[AbsoluteChange] DESC;SELECT * FROM [#QueryStoreRegressions_Errors] ORDER BY [DatabaseName];END;
  IF @JsonErzeugen=1 BEGIN DECLARE @Meta nvarchar(max)=(SELECT N'QueryStoreRegressions' [resultName],1 [schemaVersion],@Now [generatedAtUtc],@Status [statusCode],@Metrik [metric],@MaxZeilen [requestedMaxRows],CASE WHEN @Count>@Limit THEN @Limit ELSE @Count END [returnedRows],@HasMore [hasMoreRows] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),@Data nvarchar(max)=(SELECT * FROM [#QueryStoreRegressions_Export] ORDER BY [RegressionPercent] DESC,[AbsoluteChange] DESC FOR JSON PATH,INCLUDE_NULL_VALUES),@Warnings nvarchar(max)=(SELECT * FROM [#QueryStoreRegressions_Errors] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"regressions":',COALESCE(@Data,N'[]'),N',"warnings":',COALESCE(@Warnings,N'[]'),N'}');END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#QueryStoreRegressions_Export'
            , @ResultLabel=N'QueryStoreRegressions'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#QueryStoreRegressions_Export'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
