---
skill_format_version: "1.0.0"
name: "monitor.USP_QueryStoreRegressions"
schema_name: "monitor"
object_name: "USP_QueryStoreRegressions"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Vergleicht zwei Query-Store-Zeitfenster über eine oder mehrere Quelldatenbanken."
source_path: "Code/05_QueryStore/050_USP_QueryStoreRegressions.sql"
---

# monitor.USP_QueryStoreRegressions

## Zweck und Einsatz

Vergleicht zwei Query-Store-Zeitfenster über eine oder mehrere Quelldatenbanken. Lokales N+1 und globales Top-N vermeiden eine vollständige Materialisierung aller Query-Store-Zeilen.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_QueryStoreRegressions]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `[monitor].[TVF_ParsePattern]`, `[monitor].[TVF_ParseSqlNameList]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `[monitor].[InternalCheckAnalysisPath]`, `[master].[sys].[databases]`, `[sys].[database_query_store_options]`, `[sys].[query_store_runtime_stats]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

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
| @BaselineVonUtc | datetime2(7) | nein | NULL |
| @BaselineBisUtc | datetime2(7) | nein | NULL |
| @VergleichVonUtc | datetime2(7) | nein | NULL |
| @VergleichBisUtc | datetime2(7) | nein | NULL |
| @Metrik | varchar(32) | nein | 'DURATION_AVG' |
| @MinAusfuehrungenJeFenster | bigint | nein | 1 |
| @MinRegressionProzent | decimal(9,2) | nein | 20.0 |
| @AnalyseModus | varchar(16) | nein | 'TOP' |
| @MaxZeilen | int | nein | 100 |
| @MaxSqlTextZeichen | int | nein | 4000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@QueryStoreDatabaseNames:** @QueryStoreDatabaseNames nvarchar(max); Default: NULL. Ausgelassen/NULL, N'' oder nur äußere U+0020-Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger SQL-Datenbanknamen, zum Beispiel N'[ExampleDatabase]|[OtherDatabase]'; | trennt außerhalb von [...], ]] maskiert ]. Leere Elemente, ungültige Namen und Duplikate sind INVALID_PARAMETER. Eine effektive nichtleere Liste ist exklusiv mit dem nicht-NULL Quellpattern. Ohne Filter werden sichtbare geeignete Online-Benutzerdatenbanken gewählt; Systemdatenbanken bleiben ausgeschlossen.

**@QueryStoreDatabaseNamePattern:** @QueryStoreDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung entfernen. Ohne Präfix gilt LIKE; Rest wird nicht erneut getrimmt. Leer oder leer nach Präfix ist ungültig; exklusiv mit @QueryStoreDatabaseNames. REGEX/REGEXI laufen in der Installationsdatenbank und benötigen SQL Server 2025 plus CL170 dort; Syntax wird nicht vorab validiert.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. ausgelassen/0 = nicht bestätigt. NULL ist im Datenbankhelfer INVALID_PARAMETER. 1 bestätigt nur ein aktiviertes Gruppengate: QUERY_STORE_CURRENT hat kein Gruppengate, QUERY_STORE_DEEP verwendet es. Die Bestätigung ändert keinen Scope und erteilt weder SQL-Berechtigung noch Gruppenmitgliedschaft. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.

**@ReferencedDatabaseNames:** @ReferencedDatabaseNames nvarchar(max); Default: NULL. ausgelassen/NULL kein Showplan-Referenzfilter. Sonst nichtleere bracket-aware Pipe-Liste einteiliger SQL-Namen; | trennt außerhalb von [...], ]] maskiert ]. Leerwert/Leerzeichen ungültig. Teil 1 muss nicht NULL, Teil 2 NULL und LEN(Teil 1) höchstens 128 sein. Punkte außerhalb eines einzelnen quotierten Namens sind auch bei ausgelassenen Qualifizierern ungültig. Gültige Namen werden mit expliziter Framework-Collation SQL_Latin1_General_CP1_CS_AS verglichen. Duplikate sind erlaubt; EXISTS vervielfacht keine Zeilen. Exklusiv mit @ReferencedDatabaseNamePattern; setzt QUERY_STORE_DEEP voraus.

**@ReferencedDatabaseNamePattern:** @ReferencedDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung. Ohne Präfix LIKE; Rest wird nicht erneut getrimmt; leer/leer nach Präfix ungültig. Exklusiv mit @ReferencedDatabaseNames; setzt QUERY_STORE_DEEP voraus. REGEX/REGEXI laufen je Quelldatenbank und benötigen SQL Server 2025 sowie CL170 dort; Syntax wird nicht vorab validiert.

**@QueryId:** @QueryId bigint; Default: NULL. Ausgelassen/NULL: kein Query-ID-Filter. Einen ganzzahligen bigint-Wert von -9223372036854775808 bis 9223372036854775807 übergeben; keine zusätzliche Positivitäts- oder Existenzprüfung. Exakter Vergleich je Quelle; Query-IDs sind quellenspezifisch.

**@QueryHash:** @QueryHash binary(8); Default: NULL. Ausgelassen/NULL: kein Hashfilter. Acht Byte als Binärwert übergeben, zum Beispiel 0x0123456789ABCDEF; exakter Vergleich ohne zusätzliche Werte- oder Existenzprüfung. SQL-Typkonvertierungen erfolgen vor dem Procedurekörper.

**@BaselineVonUtc:** @BaselineVonUtc datetime2(7); Default: NULL. Optionale UTC-Untergrenze des Baselinefensters. Jede gesetzte Grenze bleibt erhalten. Wenn NULL, wird eine Stunde vor @BaselineBisUtc berechnet; fehlt auch @BaselineBisUtc, ist dessen Default @VergleichVonUtc. Die Grenze muss vor @BaselineBisUtc liegen. Übergabe als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000; keine Zeitzonenumrechnung. Jede untere Grenze muss vor ihrer oberen liegen; BaselineBisUtc darf VergleichVonUtc nicht überschreiten. Vollständig überlappende Runtimeintervalle werden einbezogen, keine anteilige Kürzung. Jeder automatisch berechnete NULL-Beginn benötigt eine darstellbare Stunde vor seinem effektiven Ende. Wenn Vergleichsbeginn und beide Baselinegrenzen NULL bleiben, muss ein gesetztes Vergleichsende mindestens 0001-01-01T02:00:00.0000000 betragen. Frühere Werte können bei DATEADD vor der normalen Fachvalidierung ungefangen überlaufen; vollständig gesetzte gültige Fenster bleiben zulässig.

**@BaselineBisUtc:** @BaselineBisUtc datetime2(7); Default: NULL. Optionale UTC-Obergrenze des Baselinefensters. Wenn NULL, gilt @VergleichVonUtc. Die Grenze muss nach @BaselineVonUtc liegen und darf nicht nach @VergleichVonUtc liegen. Übergabe als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000; keine Zeitzonenumrechnung. Jede untere Grenze muss vor ihrer oberen liegen; BaselineBisUtc darf VergleichVonUtc nicht überschreiten. Vollständig überlappende Runtimeintervalle werden einbezogen, keine anteilige Kürzung. Jeder automatisch berechnete NULL-Beginn benötigt eine darstellbare Stunde vor seinem effektiven Ende. Wenn Vergleichsbeginn und beide Baselinegrenzen NULL bleiben, muss ein gesetztes Vergleichsende mindestens 0001-01-01T02:00:00.0000000 betragen. Frühere Werte können bei DATEADD vor der normalen Fachvalidierung ungefangen überlaufen; vollständig gesetzte gültige Fenster bleiben zulässig.

**@VergleichVonUtc:** @VergleichVonUtc datetime2(7); Default: NULL. Optionale UTC-Untergrenze des Vergleichsfensters. Wenn NULL, wird eine Stunde vor @VergleichBisUtc berechnet; wenn auch das Ende NULL ist, gilt zunächst jetzt in UTC. Die Grenze muss vor @VergleichBisUtc liegen. Baseline und Vergleich dürfen sich nicht überlappen. Übergabe als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000; keine Zeitzonenumrechnung. Jede untere Grenze muss vor ihrer oberen liegen; BaselineBisUtc darf VergleichVonUtc nicht überschreiten. Vollständig überlappende Runtimeintervalle werden einbezogen, keine anteilige Kürzung. Jeder automatisch berechnete NULL-Beginn benötigt eine darstellbare Stunde vor seinem effektiven Ende. Wenn Vergleichsbeginn und beide Baselinegrenzen NULL bleiben, muss ein gesetztes Vergleichsende mindestens 0001-01-01T02:00:00.0000000 betragen. Frühere Werte können bei DATEADD vor der normalen Fachvalidierung ungefangen überlaufen; vollständig gesetzte gültige Fenster bleiben zulässig.

**@VergleichBisUtc:** @VergleichBisUtc datetime2(7); Default: NULL. Optionale UTC-Obergrenze des Vergleichsfensters. Wenn NULL, gilt SYSUTCDATETIME() zum Aufruf. Jede gesetzte Grenze bleibt erhalten; aus den vier einzeln abgeleiteten Grenzen entsteht keine automatische Gleichlängenregel. Die Grenze muss nach @VergleichVonUtc liegen. Übergabe als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000; keine Zeitzonenumrechnung. Jede untere Grenze muss vor ihrer oberen liegen; BaselineBisUtc darf VergleichVonUtc nicht überschreiten. Vollständig überlappende Runtimeintervalle werden einbezogen, keine anteilige Kürzung. Jeder automatisch berechnete NULL-Beginn benötigt eine darstellbare Stunde vor seinem effektiven Ende. Wenn Vergleichsbeginn und beide Baselinegrenzen NULL bleiben, muss ein gesetztes Vergleichsende mindestens 0001-01-01T02:00:00.0000000 betragen. Frühere Werte können bei DATEADD vor der normalen Fachvalidierung ungefangen überlaufen; vollständig gesetzte gültige Fenster bleiben zulässig.

**@Metrik:** @Metrik varchar(32); Default: 'DURATION_AVG'. NULL wird wie DURATION_AVG behandelt; außen getrimmt und in Großbuchstaben normalisiert. Zulässige geschlossene Werte: DURATION_AVG = ausführungsgewichtete durchschnittliche Dauer in ms je Ausführung; CPU_AVG = gewichtete durchschnittliche CPU-Zeit in ms je Ausführung; READS_AVG = gewichtete durchschnittliche logische Reads je Ausführung; WRITES_AVG = gewichtete durchschnittliche logische Writes je Ausführung; EXECUTIONS = Ausführungszahl im Fenster. Für Dauer/CPU werden Quellwerte in Mikrosekunden durch 1000 in ms umgerechnet. Es werden nur Queries mit Werten in beiden Fenstern und einer berechneten Änderung mindestens @MinRegressionProzent ausgegeben. Prozent = 100 × (Vergleich − Baseline) / ABS(Baseline); bei Baseline 0 ist der Prozentwert NULL und erfüllt den Mindestfilter nicht. Der Schwellenwert wird mit dem vor der Ausgabe-Rundung berechneten Float-Prozentwert verglichen; Baselinewert 0 ergibt durch NULLIF NULL und wird durch das WHERE-Prädikat ausgeschlossen. Maßgeblich ist der bei SQL-Bindung auf die deklarierte Typbreite zugewiesene Wert; LTRIM/RTRIM entfernt äußere U+0020-Leerzeichen. Leer, nur U+0020 oder andere Werte sind im normalen Analysepfad ungültig.

**@MinAusfuehrungenJeFenster:** @MinAusfuehrungenJeFenster bigint; Default: 1. Mindestzahl der Ausführungen in jedem der beiden Fenster; Werte kleiner 1 sind ungültig. SQL-Prädikate filtern je Fenster vor dem Vergleich. NULL führt nicht pauschal zu INVALID_PARAMETER, erfüllt aber den Mindestvergleich nicht und ergibt damit keine Regressionstreffer. Als ganze Zahl von 1 bis 9223372036854775807 übergeben.

**@MinRegressionProzent:** @MinRegressionProzent decimal(9,2); Default: 20.0. Mindestwert für die prozentuale Änderung der ausgewählten Metrik, verglichen mit 100 × (Vergleich − Baseline) / ABS(Baseline). Negative Werte sind ungültig. NULL ist kein allgemeiner Parameterfehler, lässt das SQL-Schwellenprädikat aber UNKNOWN werden und liefert daher keine Regressionstreffer. Als dezimalen Zahlenwert von 0.00 bis 9999999.99 übergeben, zum Beispiel 20.00. Zuweisung an decimal(9,2) erfolgt vor der Prüfung und kann zusätzliche Nachkommastellen runden.

**@AnalyseModus:** @AnalyseModus varchar(16); Default: 'TOP'. NULL wird wie TOP behandelt; außen getrimmt und großgeschrieben. Geschlossene Optionen: TOP nutzt den rangbegrenzten lokalen Kandidatenpfad je Quelle; VOLL aktiviert den Deep-Check. Beide liefern weiterhin nur die nach Kriterien berechneten Regressionen. Maßgeblich ist der bei SQL-Bindung auf die deklarierte Typbreite zugewiesene Wert; LTRIM/RTRIM entfernt äußere U+0020-Leerzeichen. VOLL hebt das Zeilenlimit nicht auf. Leer, nur U+0020 oder andere Werte sind ungültig.

**@MaxZeilen:** @MaxZeilen int; Default: 100. Globale Ausgabegrenze nach lokaler N+1-Kandidatensammlung je Quelle, Textprojektion, Truncationwarnung und Mengen-/Statuszählung. Positiver Wert begrenzt die abschließende, global nach RegressionPercent DESC und AbsoluteChange DESC sortierte Exportmenge; Gleichstände bestimmen keine eindeutige Auswahl. NULL oder 0 bedeutet unbegrenzt. Negative Werte sind ungültig. Der lokale TOP ist bei positivem Wert höchstens @MaxZeilen+1 (bei int-Maximalwert ohne Addition); er begrenzt nicht pauschal alle gelesenen Query-Store-Runtimezeilen. @Limit > 1000 aktiviert QUERY_STORE_DEEP; bei NULL/0 ist das Limit maximal und Deep daher aktiv. Als ganze Zahl im SQL-int-Bereich bis 2147483647 übergeben.

**@MaxSqlTextZeichen:** @MaxSqlTextZeichen int; Default: 4000. Begrenzt die projizierte Länge von QuerySqlText in den lokal gesammelten Ergebnissen. NULL oder 0 bedeutet unbegrenzt; negative Werte sind ungültig. Projektion und Truncationmetadaten/-warnung werden vor der abschließenden globalen @MaxZeilen-Ausgabegrenze berechnet; die Begrenzung spart daher nicht die vorherige Quellaggregation. Die Unicode-Projektion zählt Zeichen mit SC-Collation und schneidet Surrogatpaare nicht auseinander. Als ganze Zahl im SQL-int-Bereich bis 2147483647 übergeben.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Ausgelassen: CONSOLE. Nach U+0020-Trim/Großschreibung sind genau vier Werte erlaubt: RAW liefert drei Resultsets (Metadaten, regressions, Warnungen); CONSOLE liefert die fachliche Exportmenge mit Ergebnislabel oder bei Leere eine Hinweiszeile, ohne zusätzliche Metadaten-/Warnungsgrids; TABLE schreibt nur regressions ins geprüfte lokale Temp-Ziel; NONE unterdrückt normale Fachresultsets. JSON ist unabhängig. NULL, leer, nur Leerzeichen und andere Werte sind im normalen Analysepfad ungültig. Der TABLE-Preflight liegt vor Hilfe und Fachvalidierung. Der Eingabewert unterliegt der varchar(16)-Bindungsbreite.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. außerhalb TABLE nur NULL, leer oder Leerzeichen zulässig; anderer nichtleerer Inhalt wirft 51011. Bei TABLE nichtleeres JSON-Objekt mit genau dem Schlüssel regressions und einem Ziel. Ziel: vorhandene, leere lokale #Temp-Tabelle (kein ##), maximal 116 Zeichen und genau eine beliebige Seed-Spalte; das volle Ergebnis-Schema muss nicht angelegt werden. Fehlendes/ungültiges Mapping/Ziel wird im frühen Preflight abgelehnt; leerer Wert ist in TABLE ungültig. Schlüssel binär exakt und ohne Duplikate; Ziele dürfen weder ## noch das reservierte #Monitor-Präfix verwenden. Ein Seed-Datensatz ist nicht zulässig; der Writer ersetzt die Seed-Struktur durch das Ergebnisschema.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Steuert unabhängig von @ResultSetArt, ob JSON in @Json aufgebaut wird. SQL-bit-Konvertierung: numerische Eingaben ungleich 0 werden 1, 0 wird 0; NULL erzeugt kein JSON.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Parameter. Zum Empfang nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Beim Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 gefüllt; bei Hilfe bleibt es NULL. Ausgelassen gilt der Vorgabewert, das Ergebnis ist dann nicht abrufbar. Leerwert als Eingabe wird nicht ausgewertet. Bei ungefangenem THROW besteht keine Zusage einer OUTPUT-Rückübertragung.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. ausgelassen lässt Meldungen zu. 1 erlaubt Fehlerhinweise und die Truncationwarnung; 0 unterdrückt diese Meldungen. NULL unterdrückt die Truncationwarnung und erfüllt die direkte Fehlerausgabebedingung nicht. Status, Resultsets und Datenmenge bleiben davon unberührt. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.

**@Hilfe:** @Hilfe bit; Default: 0. ausgelassen/NULL führt normal aus. Nur 1 druckt die Hilfe und beendet vor normaler Parameter- und Datenvalidierung. Rohe SQL-Bindung und früher TABLE-Mapping-Preflight bleiben aktiv und können vorher scheitern; @Json wurde beim Eintritt geleert. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.

## Resultate und Ausgabe

RAW/CONSOLE/NONE; JSON mit meta, regressions und warnings.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| regressions | 1 | 1 | [QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[QueryId] bigint,[QueryHash] binary(8),[ObjectId] bigint NULL,[ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[BaselineExecutions] bigint,[ComparisonExecutions] bigint,[BaselinePlanCount] bigint,[ComparisonPlanCount] bigint,[BaselineValue] decimal(38,3),[ComparisonValue] decimal(38,3),[AbsoluteChange] decimal(38,3),[RegressionPercent] decimal(38,3),[LastExecutionTimeUtc] datetimeoffset,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CapturedAtUtc] datetime2(3) NULL,[EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsAggregated] bit NULL,[QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NOT NULL DEFAULT(0),[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_QueryStoreRegressions] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_QueryStoreRegressions

monitor.USP_QueryStoreRegressions vergleicht aggregierte Query-Store-Werte aus zwei nicht überlappenden UTC-Zeitfenstern je ausgewählter Quelldatenbank. Die zugrunde liegenden Runtimeintervalle können beide Fenster überlappen und werden dann jeweils vollständig einbezogen, nicht anteilig zerlegt. Die Daten hängen von Query-Store-Capture und Retention ab; sie belegen weder eine Ursache noch allgemeine Performance.

Zeitfenster und Intervalle: Jede gesetzte Grenze bleibt erhalten. NULL-Ende des Vergleichs = jetzt UTC; NULL-Start = eine Stunde davor. NULL-Ende der Baseline = Vergleichsstart; NULL-Start der Baseline = eine Stunde davor. Diese Defaults werden einzeln berechnet und halten bei geänderten Grenzen keine gleiche Fensterlänge ein. Runtimeintervalle werden bei Überlappung vollständig einbezogen, nicht anteilig auf Fenstergrenzen zerlegt. Ausführungen und gewichtete Messwerte werden je Query/Fenster summiert; Plananzahl zählt unterschiedliche PlanIds.

Analysepfad: QUERY_STORE_CURRENT wird für die Datenbankauswahl geprüft. QUERY_STORE_DEEP wird zusätzlich aktiviert bei @AnalyseModus=VOLL, normalisiertem @MaxZeilen-Limit > 1000 (NULL/0 ist unbegrenzt und damit ebenfalls > 1000), DATEDIFF(HOUR,@BaselineVonUtc,@VergleichBisUtc)>24 (Stundengrenzen gemäß DATEDIFF) oder jedem gesetzten Referenzfilter. Die jeweilige Katalogklasse kann @HighImpactConfirmed=1 erfordern; Zugriffsrichtlinien können zusätzlich sperren.

Grenzen: Pro Datenbank werden lokal höchstens N+1 Kandidaten für das globale Limit gesammelt; damit sind nicht alle zuvor gelesenen Query-Store-Zeilen begrenzt. @MaxSqlTextZeichen wirkt nach Quellaggregation und Filterung auf die Textprojektion. Textprojektion, Truncationwarnungen sowie Anzahl/hasMoreRows werden vor dem abschließenden globalen Limit bestimmt. Die globale Sortierung ist RegressionPercent DESC, AbsoluteChange DESC; Gleichstände garantieren keine bestimmte Auswahl.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_QueryStoreRegressions
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Vergleicht zwei Query-Store-Zeitfenster über eine oder mehrere
               Quelldatenbanken. Lokales N+1 und globales Top-N vermeiden eine
               vollständige Materialisierung aller Query-Store-Zeilen.
Ausgabe      : RAW/CONSOLE/NONE; JSON mit meta, regressions und warnings.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_QueryStoreRegressions
monitor.USP_QueryStoreRegressions vergleicht aggregierte Query-Store-Werte aus zwei nicht überlappenden UTC-Zeitfenstern je ausgewählter Quelldatenbank. Die zugrunde liegenden Runtimeintervalle können beide Fenster überlappen und werden dann jeweils vollständig einbezogen, nicht anteilig zerlegt. Die Daten hängen von Query-Store-Capture und Retention ab; sie belegen weder eine Ursache noch allgemeine Performance.
Zeitfenster und Intervalle: Jede gesetzte Grenze bleibt erhalten. NULL-Ende des Vergleichs = jetzt UTC; NULL-Start = eine Stunde davor. NULL-Ende der Baseline = Vergleichsstart; NULL-Start der Baseline = eine Stunde davor. Diese Defaults werden einzeln berechnet und halten bei geänderten Grenzen keine gleiche Fensterlänge ein. Runtimeintervalle werden bei Überlappung vollständig einbezogen, nicht anteilig auf Fenstergrenzen zerlegt. Ausführungen und gewichtete Messwerte werden je Query/Fenster summiert; Plananzahl zählt unterschiedliche PlanIds.
Analysepfad: QUERY_STORE_CURRENT wird für die Datenbankauswahl geprüft. QUERY_STORE_DEEP wird zusätzlich aktiviert bei @AnalyseModus=VOLL, normalisiertem @MaxZeilen-Limit > 1000 (NULL/0 ist unbegrenzt und damit ebenfalls > 1000), DATEDIFF(HOUR,@BaselineVonUtc,@VergleichBisUtc)>24 (Stundengrenzen gemäß DATEDIFF) oder jedem gesetzten Referenzfilter. Die jeweilige Katalogklasse kann @HighImpactConfirmed=1 erfordern; Zugriffsrichtlinien können zusätzlich sperren.
Grenzen: Pro Datenbank werden lokal höchstens N+1 Kandidaten für das globale Limit gesammelt; damit sind nicht alle zuvor gelesenen Query-Store-Zeilen begrenzt. @MaxSqlTextZeichen wirkt nach Quellaggregation und Filterung auf die Textprojektion. Textprojektion, Truncationwarnungen sowie Anzahl/hasMoreRows werden vor dem abschließenden globalen Limit bestimmt. Die globale Sortierung ist RegressionPercent DESC, AbsoluteChange DESC; Gleichstände garantieren keine bestimmte Auswahl.
Die beschriebenen fachlichen Validierungen gelten im normalen Analysepfad. @Hilfe=1 kehrt vorher zurück; SQL-Typbindung und frühe Mappingprüfungen bleiben aktiv. Ausgelassen gilt bei jedem Parameter der ausdrücklich angegebene Default.
DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreRegressions] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];
CREATE TABLE [#QueryStoreRegressions_HelpExample]([Seed] int NULL);
BEGIN TRY
 EXEC [monitor].[USP_QueryStoreRegressions] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"regressions":"#QueryStoreRegressions_HelpExample"}';
 SELECT * FROM [#QueryStoreRegressions_HelpExample];
 DROP TABLE IF EXISTS [#QueryStoreRegressions_HelpExample];
END TRY
BEGIN CATCH
 DROP TABLE IF EXISTS [#QueryStoreRegressions_HelpExample];
 THROW;
END CATCH;
```

