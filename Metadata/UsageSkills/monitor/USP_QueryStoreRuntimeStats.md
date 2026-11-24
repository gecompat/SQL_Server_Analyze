---
skill_format_version: "1.0.0"
name: "monitor.USP_QueryStoreRuntimeStats"
schema_name: "monitor"
object_name: "USP_QueryStoreRuntimeStats"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liefert Query-Store-Runtime-Statistiken aus einer oder mehreren Query-Store-Quelldatenbanken mit exaktem globalem Top-N."
source_path: "Code/05_QueryStore/020_USP_QueryStoreRuntimeStats.sql"
---

# monitor.USP_QueryStoreRuntimeStats

## Zweck und Einsatz

Liefert Query-Store-Runtime-Statistiken aus einer oder mehreren Query-Store-Quelldatenbanken mit exaktem globalem Top-N.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_QueryStoreRuntimeStats] im vorgesehenen Datenbankkontext. Die Procedure liest Query-Store-Optionen, Runtime-Statistiken und Intervalle pro zugänglicher ausgewählter Datenbank. Query Store kann deaktiviert oder für den Caller nicht lesbar sein.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @QueryStoreDatabaseNames | nvarchar(max) | nein | NULL |
| @QueryStoreDatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @ReferencedDatabaseNames | nvarchar(max) | nein | NULL |
| @ReferencedDatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @QueryId | bigint | nein | NULL |
| @QueryHash | binary(8) | nein | NULL |
| @TextPattern | nvarchar(4000) | nein | NULL |
| @VonUtc | datetime2(7) | nein | NULL |
| @BisUtc | datetime2(7) | nein | NULL |
| @Sortierung | varchar(32) | nein | 'CPU_TOTAL' |
| @AnalyseModus | varchar(16) | nein | 'TOP' |
| @MaxZeilen | int | nein | 100 |
| @MitPlanXml | bit | nein | 0 |
| @MaxSqlTextZeichen | int | nein | 4000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@QueryStoreDatabaseNames:** @QueryStoreDatabaseNames nvarchar(max); Default: NULL. Im normalen Analysepfad: Gibt exakte Query-Store-Quelldatenbanken als bracket-aware Pipe-Liste an; jedes Element ist ein einteiliger SQL-Name. Pipe trennt außerhalb von [...], ]] maskiert dort eine schließende Klammer, Rand-Leerzeichen je Element werden entfernt. Ausgelassen oder NULL sowie N'' oder nur äußere Leerzeichen: keine Namenseinschränkung, also alle sichtbaren geeigneten Online-Benutzerdatenbanken. Nichtleere Liste: ungültige Elemente und doppelte gültige Namen ergeben INVALID_PARAMETER; Liste und @QueryStoreDatabaseNamePattern dürfen nicht gleichzeitig aktiv sein. Dies filtert Quell-Datenbanken, nicht Showplan-Referenzen. Ausgelassen gilt der deklarierte Default NULL. Die tatsächliche Namensprüfung verlangt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und höchstens 128 Zeichen für Teil 1. Punkte außerhalb eines einzelnen quotierten Namens sind auch bei ausgelassenen Qualifizierern ungültig. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig.

**@QueryStoreDatabaseNamePattern:** @QueryStoreDatabaseNamePattern nvarchar(4000); Default: NULL. Im normalen Analysepfad: Alternativer Patternfilter für Query-Store-Quelldatenbanken. NULL: kein Pattern. Äußere Leerzeichen werden getrimmt; optionale Präfixe LIKE/Regex werden ohne Beachtung der Großschreibung erkannt, der Patternwert danach nicht erneut getrimmt. Unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE; regex: case-sensitive (Flag c); regexi: case-insensitive (Flag i). Leer/U+0020-Leerzeichen und leeres Präfixergebnis sind ungültig. Nicht-NULL Pattern und wirksame exakte Quellliste schließen einander aus. Regex erfordert SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank; der Auswahlhelfer führt den Regexfilter dort auf Kandidatennamen aus. Dies ist nicht die spätere Regexprüfung je Query-Store-Quelldatenbank. Filtert keine Showplan-Referenzen. Ausgelassen gilt der deklarierte Default NULL. LIKE verwendet %, _ und Zeichenklassen [...]. Präfix- und Eingabeformat sind Textwerte, zum Beispiel N'like:App%'; nach Präfixentfernung bleiben Inhalt und Groß-/Kleinschreibung erhalten.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. Im normalen Auswahlpfad: Bestätigt einen tatsächlich aktivierten High-Impact-Pfad mit 1. NULL ist INVALID_PARAMETER durch 083, unabhängig davon, ob die Analyseklasse ein Gruppengate verlangt; 0 lässt Bestätigung aus. QUERY_STORE_CURRENT verlangt derzeit kein Gruppengate; QUERY_STORE_DEEP hat RequiresGroupGate=1. Bestätigung aktiviert Deep nicht und gewährt keine Gruppen- oder SQL-Berechtigung; Freigabe und Rechte werden getrennt geprüft. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.

**@ReferencedDatabaseNames:** @ReferencedDatabaseNames nvarchar(max); Default: NULL. Im normalen Analysepfad: Filtert Querys anhand einteiliger Namen in gespeicherten Showplans, nicht die Quell-Datenbanken. NULL/ausgelassen: kein Referenzfilter. Nicht-NULL muss eine gültige bracket-aware Pipe-Liste sein; N''/nur Leerzeichen und ungültige Parserwerte sind INVALID_PARAMETER. Gültige Duplikate sind zulässig; EXISTS vervielfacht Treffer nicht. Exakte Liste und @ReferencedDatabaseNamePattern dürfen nicht gleichzeitig non-NULL sein. Jedes gesetzte Referenzlistenfilter ist Deep und erfordert gespeicherte Showplan-XML. Ausgelassen gilt der deklarierte Default NULL. Die tatsächliche Namensprüfung verlangt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und höchstens 128 Zeichen für Teil 1. Punkte außerhalb eines einzelnen quotierten Namens sind auch bei ausgelassenen Qualifizierern ungültig. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig.

**@ReferencedDatabaseNamePattern:** @ReferencedDatabaseNamePattern nvarchar(4000); Default: NULL. Im normalen Analysepfad: Filtert nach in gespeicherten Showplans referenzierten Datenbanknamen; keine Quell-DB-Auswahl. NULL: kein Pattern. Unpräfigiert oder like: case-sensitive LIKE; regex: case-sensitive mit Flag c; regexi: case-insensitive mit Flag i. Äußere Leerzeichen werden vor Präfixerkennung getrimmt, danach der Inhalt nicht erneut. Leer/U+0020-Leerzeichen oder leeres Präfixergebnis ungültig. Jeder gesetzte Referenzpatternwert ist exklusiv zu @ReferencedDatabaseNames und löst Deep aus. Regex benötigt SQL Server 2025 und Compatibility Level 170 je Quelldatenbank. Ausgelassen gilt der deklarierte Default NULL. LIKE verwendet %, _ und Zeichenklassen [...]. Präfix- und Eingabeformat sind Textwerte, zum Beispiel N'like:App%'; nach Präfixentfernung bleiben Inhalt und Groß-/Kleinschreibung erhalten.

**@QueryId:** @QueryId bigint; Default: NULL. Filtert auf die exakte QueryId in jeder gewählten Query-Store-Quelldatenbank. NULL/ausgelassen: kein QueryId-Filter. Jeder signed-bigint-Wert ist zulässig; keine zusätzliche Positivitätsprüfung. Wirkung bleibt auf Quellen, Zeitfenster und übrige Filter beschränkt.

**@QueryHash:** @QueryHash binary(8); Default: NULL. Filtert exakt auf den 8-Byte-QueryHash. NULL/ausgelassen: kein Hashfilter. Der Wert muss zu binary(8) konvertierbar sein; Hexwerte als 0x plus 16 Hexziffern angeben. Hash ersetzt nicht die Identität aus Quelldatenbank und QueryId.

**@TextPattern:** @TextPattern nvarchar(4000); Default: NULL. Im normalen Analysepfad: Filtert den gespeicherten SQL-Text. NULL/ausgelassen: kein Filter. Unpräfigiert oder like: SQL-LIKE unter expliziter case-sensitive Framework-Collation; regex: case-sensitive Regex (Flag c); regexi: case-insensitive Regex (Flag i). Präfixerkennung case-insensitive; äußere Leerzeichen werden zuerst getrimmt, nach Präfixentfernung der Wert nicht erneut. Leerer/U+0020-Leerzeichen Wert oder leeres Präfixergebnis ungültig. Regex benötigt SQL Server 2025 und Compatibility Level 170 in jeder Quelldatenbank und aktiviert Deep; unpassende Quelle wird als unavailable/partial gemeldet. Ausgelassen gilt der deklarierte Default NULL. LIKE verwendet %, _ und Zeichenklassen [...]. Präfix- und Eingabeformat sind Textwerte, zum Beispiel N'like:App%'; nach Präfixentfernung bleiben Inhalt und Groß-/Kleinschreibung erhalten.

**@VonUtc:** @VonUtc datetime2(7); Default: NULL. Im normalen Analysepfad: UTC-Untergrenze; caller liefert UTC, datetime2 hat keinen Offset und es erfolgt keine Zeitzonenkonvertierung. NULL wird nach Auflösung von @BisUtc auf BisUtc minus eine Stunde gesetzt. Erforderlich ist VonUtc < BisUtc; Gleichheit oder größer ist ungültig. Intervalle werden bei end_time > VonUtc und start_time < BisUtc vollständig berücksichtigt, ohne anteilige Kürzung; gemeldete Execution-Zeiten können außerhalb des Fensters liegen. Ausgelassen gilt der deklarierte Default NULL. Übergabeform zum Beispiel '2026-01-01T12:00:00.0000000' als UTC-datetime2(7); kein Offset wird umgerechnet. Ist @VonUtc NULL, muss das effektive Ende mindestens 0001-01-01T01:00:00.0000000 betragen, damit DATEADD eine Stunde abziehen kann. Frühere Endwerte können vor der normalen Fachvalidierung ungefangen überlaufen. Vollständig gesetzte gültige Grenzen bleiben zulässig.

**@BisUtc:** @BisUtc datetime2(7); Default: NULL. UTC-Obergrenze; caller liefert UTC ohne Offsetkonvertierung. NULL/ausgelassen wird zu SYSUTCDATETIME() aufgelöst; zugleich NULLes @VonUtc ergibt eine Stunde Fenster. Muss größer als @VonUtc sein. Mit end_time > VonUtc und start_time < BisUtc schneiden Intervalle das Fenster; sie werden vollständig und nicht anteilig einbezogen. Ausgelassen gilt der deklarierte Default NULL. Übergabeform zum Beispiel '2026-01-01T12:00:00.0000000' als UTC-datetime2(7); kein Offset wird umgerechnet. Ist @VonUtc NULL, muss das effektive Ende mindestens 0001-01-01T01:00:00.0000000 betragen, damit DATEADD eine Stunde abziehen kann. Frühere Endwerte können vor der normalen Fachvalidierung ungefangen überlaufen. Vollständig gesetzte gültige Grenzen bleiben zulässig.

**@Sortierung:** @Sortierung varchar(32); Default: 'CPU_TOTAL'. Im normalen Analysepfad: Werte werden getrimmt und großgeschrieben; NULL/ausgelassen wird CPU_TOTAL, leer oder unbekannt ist ungültig. Geschlossene Wertemenge mit tatsächlichem Rank-Ausdruck, jeweils DESC: CPU_TOTAL=TotalCpuMs (gesamte CPU ms); DURATION_TOTAL=TotalDurationMs (Gesamtdauer ms); READS_TOTAL=TotalLogicalReads (aggregierte logische Lesezugriffe); WRITES_TOTAL=TotalLogicalWrites (aggregierte logische Schreibzugriffe); EXECUTIONS=ExecutionCount (Ausführungsanzahl); MEMORY_MAX=MaxMemoryGrantKb (größter beobachteter Query-Speicherwert in KB); TEMPDB_TOTAL=TotalTempdbKb (aggregierte TempDB-Menge in KB); LOG_BYTES_TOTAL=TotalLogBytes (aggregierte Logbytes); LAST_EXECUTION=LastExecutionTimeUtc (letzte Ausführung). Im globalen Ranking folgen letzter Ausführungszeitpunkt DESC, Query-Store-Datenbankname, QueryId und PlanId; lokal wird nach Rang und gegebenenfalls letztem Ausführungszeitpunkt geordnet. Bestimmt den globalen Ausschnitt; RAW und JSON ordnen ausdrücklich. Für TABLE und die aktive CONSOLE besteht keine zusätzliche physische Reihenfolgegarantie. Ausgelassen gilt der deklarierte Default 'CPU_TOTAL'. Maßgeblich ist der bereits an varchar(32) zugewiesene Wert; eine längere Textangabe kann davor auf die Typbreite gekürzt werden. LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen.

**@AnalyseModus:** @AnalyseModus varchar(16); Default: 'TOP'. Im normalen Analysepfad: Werte werden getrimmt und großgeschrieben; NULL/ausgelassen wird TOP. Geschlossene Menge: TOP ist der Standard-Rankingpfad und fordert allein keinen Deep-Pfad an; VOLL aktiviert QUERY_STORE_DEEP und dessen High-Impact-/Zugriffsgate, hebt aber nicht das Zeilenlimit auf. Leer/unbekannt ist ungültig. Unabhängige Deep-Auslöser: MitPlanXml=1, effektives MaxZeilen >1000, DATEDIFF(HOUR,VonUtc,BisUtc)>24, nicht-NULL Referenznamen/-pattern oder Querytext-REGEX/REGEXI. Ausgelassen gilt der deklarierte Default 'TOP'. Maßgeblich ist der bereits an varchar(16) zugewiesene Wert; eine längere Textangabe kann davor auf die Typbreite gekürzt werden. LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen.

**@MaxZeilen:** @MaxZeilen int; Default: 100. Im normalen Analysepfad: Globales Ergebnislimit nach lokalem Ranking. Ausgelassen: 100; NULL/0 unbegrenzt; positiver int 1 bis 2147483647 begrenzt; negative Werte INVALID_PARAMETER. Je Quelle werden höchstens N+1 lokale Kandidaten gelesen, außer int-Maximum verwendet N; NULL/0 nutzt unbegrenzte lokale Kandidaten. Nach Quellenaggregation/-sortierung folgen Textprojektion, Plan-XML-Parsing, Warnungen und Zähler für alle Kandidaten vor dem globalen TOP. Effektives Limit >1000 sowie unbegrenzt (NULL/0) aktivieren Deep. ResultLimited/hasMoreRows zeigt global abgeschnittene Treffer an.

**@MitPlanXml:** @MitPlanXml bit; Default: 0. Nur genau 1 aktiviert Planausgabe und XML-Parsen gespeicherter Plantexte für ausgewählte Kandidaten und löst Deep aus. 0 unterdrückt Planausgabe und XML-Parsen, QueryPlan bleibt NULL und QueryPlanStatus wird NOT_REQUESTED. NULL aktiviert weder Planausgabe/XML-Parsen noch Deep, erhält aber durch den Status-CASE PENDING statt NOT_REQUESTED. Nur bei 1 werden Plantexte tatsächlich geparst; XML-Inhalt kann AVAILABLE/XML_EMPTY/SOURCE_NULL oder Fehlerstatus liefern. Erhöht Quell- und Parseaufwand. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. Der Quell-CTE referenziert und gruppiert den gespeicherten Plantexteintrag unabhängig vom Schalter; 0 oder NULL garantiert deshalb keine Vermeidung nativer Plantexte-Zugriffe.

**@MaxSqlTextZeichen:** @MaxSqlTextZeichen int; Default: 4000. Im normalen Analysepfad: Maximale exportierte SQL-Textlänge je Treffer. Default 4000; NULL/0: vollständig; positiv: Grenze in Unicode-Zeichen unter SC-Collation, Surrogatpaar zählt als ein Zeichen und wird nicht geteilt; Graphemcluster werden nicht gezählt. Negativ ist INVALID_PARAMETER. QuerySqlTextCharacters/QuerySqlTextBytes bleiben verfügbar und QuerySqlTextIsTruncated kennzeichnet Kürzung. Eine zusammengefasste Warnung wird bei Kürzung nur mit @PrintMeldungen=1 ausgegeben. Die Grenze projiziert nach Materialisierung des Quelltexts. Ausgelassen gilt der deklarierte Default 4000.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Im normalen Analysepfad: Werte werden getrimmt und großgeschrieben, daher case-insensitiv. Geschlossene Menge: CONSOLE formatiert nur die fachliche Exportmenge oder bei Leere einen Hinweis; RAW liefert drei technische Resultsets (Metadaten, runtimeStats, Warnungen); TABLE schreibt nur runtimeStats ins benannte Ziel und unterdrückt Grids; NONE unterdrückt Resultsetgrids. JSON über @JsonErzeugen/@Json ist unabhängig davon. Nur TABLE erlaubt nichtleeres @ResultTablesJson. TABLE verlangt eine gültige Zuordnung und bestehende leere lokale #Temp-Zieltabelle mit genau einer beliebigen Seed-Spalte; Helper-Preflight erfolgt vor fachlichem Zugriff. NULL wird zu leer und ist wie leer/unbekannt ungültig. Ausgelassen gilt der deklarierte Default 'CONSOLE'. Maßgeblich ist der bereits an varchar(16) zugewiesene Wert; eine längere Textangabe kann davor auf die Typbreite gekürzt werden. LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. JSON-Zuordnung für das einzelne TABLE-Resultset runtimeStats. Bei TABLE ist ein gültiges nichtleeres JSON-Objekt erforderlich; NULL/ausgelassen, leer/U+0020-Leerzeichen oder ungültiges JSON schlägt den Preflight fehl. Das Objekt muss genau den Schlüssel runtimeStats auf ein vorhandenes, eindeutiges lokales #Temp-Ziel abbilden; unbekannte/doppelte Namen oder Ziele sind ungültig. Ziel muss bereits existieren und leer sein, mit genau einer beliebigen Seed-Spalte; es braucht nicht die volle RuntimeStats-Zielstruktur. Preflight vor fachlichen Datenquellen. Nichtleeres Mapping ausschließlich mit TABLE; für andere ResultSetArt wird es vor dem fachlichen Zugriff abgewiesen. Ausgelassen gilt der deklarierte Default NULL. Schlüssel werden binär einschließlich Groß-/Kleinschreibung verglichen; doppelte Schlüssel sind ungültig. Zielnamen sind Strings mit LEN höchstens 116, beginnen mit #, aber nicht ## oder case-insensitiv #Monitor; doppelte Ziele werden case-insensitiv abgewiesen. Die einzelne Seed-Spalte hat einen beliebigen Namen und Typ; eine Seed-Zeile ist nicht zulässig. Sowohl diese TABLE-Vorprüfung als auch die Ablehnung eines nichtleeren Mappings außerhalb TABLE liegen nur im normalen Pfad nach dem Hilfezweig.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Nur genau 1 baut @Json als Objekt mit meta, runtimeStats und warnings. 0 oder NULL erzeugt kein JSON; der Parameter ist nicht abhängig von @ResultSetArt, daher auch mit NONE möglich. Die JSON-Daten reflektieren die gemeinsame Exportmenge, Sortierung und globale Begrenzung. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optionale OUTPUT-Bindung zum Empfang des JSON. Beim Procedure-Eintritt wird der Ausgabewert immer auf NULL zurückgesetzt; ohne callerseitige OUTPUT-Bindung gibt es keinen empfangenen Wert. Nur mit @JsonErzeugen=1 wird das meta/runtimeStats/warnings-Objekt zugewiesen; ansonsten bleibt NULL. Im EXEC-Aufruf muss auch die empfangende Variable mit OUTPUT gebunden werden. Ausgelassen gilt der deklarierte Default NULL. Der Eingabewert dient nicht als Steuerwert; bei Hilfe bleibt der intern zurückgesetzte Wert NULL. Bei vorzeitigem THROW ist kein übernommener OUTPUT zugesichert.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Steuert Severity-10-Meldungen, nicht Warning-Datensätze oder JSON. Default/1: erlaubte Quellenfehler und Truncationwarnung werden als Meldungen ausgegeben. 0/NULL: Meldungen unterdrückt; Fehler-/Warning-Daten in RAW und JSON warnings bleiben erhalten; die aktive CONSOLE hat kein separates Warnungsresultset. Nur genau 1 aktiviert die Meldungsausgabe. Ausgelassen gilt der deklarierte Default 1. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.

**@Hilfe:** @Hilfe bit; Default: 0. Genau 1 druckt integrierte Parameterhilfe via PRINT und kehrt unmittelbar zurück, vor Zeitauflösung, Datenbankkandidaten, fachlichen Quellen und Ausgabe. Default/0 führt Analyse aus; NULL löst den Hilfezweig nicht aus. Hilfe erzeugt keine fachlichen Resultsets. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. Die nichtleere Mappingzuordnung außerhalb TABLE wird ebenso wie der TABLE-Zielpreflight erst im normalen Pfad geprüft; ein Mappingfehler kann den normalen Aufruf verhindern. Die normale Validierung von Ausgabemodus, Sortierung, Analysemodus, Namen, Pattern, Zeitfenster, Zeilen-/Textgrenzen und Analysefreigaben entfällt im Hilfezweig; die Mappingprüfungen werden im Hilfezweig übersprungen.

## Resultate und Ausgabe

RAW, CONSOLE, TABLE oder NONE; optionales JSON mit meta, runtimeStats und warnings.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| runtimeStats | 1 | 1 | [QueryStoreDatabaseId] int NULL, [QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [QueryId] bigint NOT NULL, [PlanId] bigint NOT NULL, [QueryHash] binary(8) NULL, [QueryPlanHash] binary(8) NULL, [ObjectId] bigint NULL, [ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ExecutionTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [FirstExecutionTimeUtc] datetimeoffset NULL, [LastExecutionTimeUtc] datetimeoffset NULL, [ExecutionCount] bigint NULL, [TotalDurationMs] decimal(38,3) NULL, [AverageDurationMs] decimal(38,3) NULL, [TotalCpuMs] decimal(38,3) NULL, [AverageCpuMs] decimal(38,3) NULL, [TotalLogicalReads] decimal(38,3) NULL, [AverageLogicalReads] decimal(38,3) NULL, [TotalLogicalWrites] decimal(38,3) NULL, [AverageLogicalWrites] decimal(38,3) NULL, [TotalPhysicalReads] decimal(38,3) NULL, [TotalMemoryGrantKb] decimal(38,3) NULL, [MaxMemoryGrantKb] decimal(38,3) NULL, [TotalRowCount] decimal(38,3) NULL, [TotalLogBytes] decimal(38,3) NULL, [TotalTempdbKb] decimal(38,3) NULL, [SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [CapturedAtUtc] datetime2(3) NULL, [EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [QuerySqlTextCharacters] bigint NULL, [QuerySqlTextBytes] bigint NULL, [QuerySqlTextIsTruncated] bit NULL, [QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [QueryPlanStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [QueryPlanCharacters] bigint NULL, [QueryPlanBytes] bigint NULL, [QueryPlan] xml NULL, [QueryPlanTextFallback] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_QueryStoreRuntimeStats] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_QueryStoreRuntimeStats

Aggregiert persistierte Query-Store-Runtime- und Ressourcenwerte je Query, Plan und Ausführungstyp über Runtime-Intervalle.

Hilfe kehrt vor den ResultTablesJson-Prüfungen und der normalen Analyseparameter-Validierung zurück. Ungültige fachliche Filter, Ausgabewerte und Mappings werden im Hilfezweig nicht geprüft.

DECLARE @Json nvarchar(max); EXEC [monitor].[USP_QueryStoreRuntimeStats] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];

CREATE TABLE [#QueryStoreRuntimeStats_HelpExample] ([seed] int NULL); EXEC [monitor].[USP_QueryStoreRuntimeStats] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"runtimeStats":"#QueryStoreRuntimeStats_HelpExample"}'; SELECT * FROM [#QueryStoreRuntimeStats_HelpExample]; DROP TABLE [#QueryStoreRuntimeStats_HelpExample];


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_QueryStoreRuntimeStats
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Liefert Query-Store-Runtime-Statistiken aus einer oder mehreren
               Query-Store-Quelldatenbanken mit exaktem globalem Top-N.
SQL-Version  : SQL Server 2019 oder neuer.
Quelldatenbanken: @QueryStoreDatabaseNames bracket-aware Pipe-Liste;
               NULL/N'' = alle zulässigen Datenbanken.
Referenzfilter: @ReferencedDatabaseNames beziehungsweise
               @ReferencedDatabaseNamePattern filtern auf Datenbanken, die in
               gespeicherten Showplans referenziert werden.
Pattern      : LIKE (Default/like:), regex:, regexi:. Regex benötigt SQL Server
               2025 und Compatibility Level 170 der jeweils ausgewerteten DB.
Top-N        : Je Quelldatenbank werden höchstens N+1 lokale Kandidaten gelesen;
               anschließend wird daraus das exakte globale Top N gebildet.
Ausgabe      : RAW, CONSOLE, TABLE oder NONE; optionales JSON mit meta, runtimeStats
               und warnings.
Änderungen   : 2.0.0 - Quell-/Referenzdatenbanken getrennt, @AlleDatenbanken
                         entfernt, globale Top-N-Logik, Pattern und JSON.
               1.0.0 - Erstfassung Phase 4.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_QueryStoreRuntimeStats
Aggregiert persistierte Query-Store-Runtime- und Ressourcenwerte je Query, Plan und Ausführungstyp über Runtime-Intervalle.
Hilfe kehrt vor den ResultTablesJson-Prüfungen und der normalen Analyseparameter-Validierung zurück. Ungültige fachliche Filter, Ausgabewerte und Mappings werden im Hilfezweig nicht geprüft.
DECLARE @Json nvarchar(max); EXEC [monitor].[USP_QueryStoreRuntimeStats] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
CREATE TABLE [#QueryStoreRuntimeStats_HelpExample] ([seed] int NULL); EXEC [monitor].[USP_QueryStoreRuntimeStats] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"runtimeStats":"#QueryStoreRuntimeStats_HelpExample"}'; SELECT * FROM [#QueryStoreRuntimeStats_HelpExample]; DROP TABLE [#QueryStoreRuntimeStats_HelpExample];
```

