---
skill_format_version: "1.0.0"
name: "monitor.USP_CurrentWaits"
schema_name: "monitor"
object_name: "USP_CurrentWaits"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liefert aktuelle Waiting Tasks sowie kumulativen oder gesampelten instanzweiten Wait-Kontext mit Listen- und Patternfiltern."
source_path: "Code/02_CurrentState/040_USP_CurrentWaits.sql"
---

# monitor.USP_CurrentWaits

## Zweck und Einsatz

Liefert aktuelle Waiting Tasks sowie kumulativen oder gesampelten instanzweiten Wait-Kontext mit Listen- und Patternfiltern.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_CurrentWaits]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `sys.dm_os_waiting_tasks`, `sys.dm_os_wait_stats`, `[monitor].[TVF_ParsePattern]`, `[monitor].[TVF_ParseBigintList]`, `[monitor].[TVF_ParseStringList]`, `[master].[sys].[databases]`, `[sys].[sp_executesql]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SessionIds | nvarchar(max) | nein | NULL |
| @MinWaitMs | bigint | nein | 0 |
| @WaitTypes | nvarchar(max) | nein | NULL |
| @WaitTypePattern | nvarchar(4000) | nein | NULL |
| @WaitGroups | nvarchar(max) | nein | NULL |
| @WaitGroupPattern | nvarchar(4000) | nein | NULL |
| @SystemSessionsEinbeziehen | bit | nein | 0 |
| @ToolHintergrundabfragenEinbeziehen | bit | nein | 0 |
| @MitSqlText | bit | nein | 1 |
| @MaxSqlTextZeichen | int | nein | 2000 |
| @SampleSeconds | tinyint | nein | 0 |
| @UnkritischeWaitsEinbeziehen | bit | nein | 0 |
| @TopWaitPercentage | decimal(5,2) | nein | 95.00 |
| @MaxZeilen | int | nein | 1000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @ParentCurrentStateSnapshotId | uniqueidentifier | nein | NULL |

**@SessionIds:** @SessionIds: nvarchar(max); Default=NULL. Ausgelassen entspricht NULL und deaktiviert den Filter. TVF_ParseBigintList ersetzt jedes Komma und Semikolon durch Pipe (auch innerhalb von Klammern), danach trennt | außerhalb von [...]; ]] maskiert dort ]. Äußere Segmentleerzeichen werden getrimmt, Klammern werden für Zahlen nicht entquotet. Leere Liste/Elemente, fehlerhafte Klammern, Rohsegmente über 4000 UTF-16-Codeeinheiten, nicht bigint-konvertierbare Werte sowie IDs außerhalb 1..32767 ergeben INVALID_PARAMETER; Duplikate werden gruppiert. IDs beschränken nur Tasks; NULL lässt alle sichtbaren Session-IDs passieren.

**@MinWaitMs:** @MinWaitMs: bigint; Default=0 ms. Ausgelassen nutzt 0. Ganze Zahlen ab 0 sind zulässig; negativ ist INVALID_PARAMETER. Wird die numerische Steuerprüfung beim Status AVAILABLE erreicht, ist NULL ungültig und führt vor der fachlichen Quellaufnahme zu INVALID_PARAMETER bei unverändertem IsPartial=0; frühere Statuswerte wie UNAVAILABLE_FEATURE bleiben vorrangig. Die Eingabe wird vor Prozedureintritt als SQL-bigint gebunden; Textwerte durchlaufen die SQL-Typkonvertierung, Leertext hat keinen eigenen Sonderdefault. Begrenzt die Mindestdauer aktueller Waiting Tasks, nicht Instanz-Wait-Stats.

**@WaitTypes:** @WaitTypes: nvarchar(max); Default=NULL. Ausgelassen/NULL deaktiviert die exakte WaitType-Auswahl. Sonst bracket-aware Pipe-Liste nach TVF_ParseStringList: Pipe trennt außerhalb [...], innerhalb ist es Inhalt, ]] maskiert ]; getrimmte Einträge werden bei bracket-quotierten Einträgen entklammert/entmaskiert. Leere Liste/Elemente, ungültige Klammern, Rohsegment über 4000 UTF-16-Codeeinheiten oder Wertlänge über 120 ergeben INVALID_PARAMETER. Gültige Duplikate werden gruppiert. Vergleich ist exakt und case-sensitive unter SQL_Latin1_General_CP1_CS_AS; Typen müssen nicht im Katalog stehen. Exklusiv mit @WaitTypePattern, sobald beide nicht NULL sind. Filtert Task- und Instanzmengen.

**@WaitTypePattern:** @WaitTypePattern: nvarchar(4000); Default=NULL. Ausgelassen/NULL deaktiviert das Pattern. TVF_ParsePattern trimmt äußere Eingabezeichen, erkennt case-insensitiv regexi:, regex: und like:, entfernt genau das Präfix ohne erneutes Trimmen des Rests; ohne Präfix gilt LIKE. LIKE ist case-sensitive SQL-LIKE mit %, _ und []-Klassen; like: wählt denselben Modus. regex: ist case-sensitive (Flag c), regexi: case-insensitive (Flag i). Leere Eingabe oder leerer Präfixrest ist INVALID_PARAMETER; Leerzeichen nach Präfix bleiben Musterinhalt. Exklusiv mit @WaitTypes. Regex erfordert SQL Server 2025/Majorversion 17 und Compatibility Level >=170 der aktuellen Datenbank, sonst UNAVAILABLE_FEATURE. Wird spät auf Task-/Instanzkandidaten angewandt; Regex hebt das frühe Taskkandidatenlimit auf und normalisiert den Instanz-Prozentnenner danach nicht neu.

**@WaitGroups:** @WaitGroups: nvarchar(max); Default=NULL. Ausgelassen/NULL deaktiviert die exakte WaitGroup-Auswahl. Sonst gilt die bracket-aware Pipe-Liste von TVF_ParseStringList: | trennt außerhalb von [...], innerhalb ist es Literalinhalt und ]] maskiert eine schließende Klammer; äußere Leerzeichen der Segmente werden getrimmt. Bei bracket-quotierten Elementen werden die äußeren Klammern entfernt und ]] zu ] entmaskiert. Leere Gesamtliste, leere Elemente, fehlerhafte Klammern, Rohsegmente über 4000 UTF-16-Codeeinheiten und nach Entquotung leere Werte sind ungültig; Wertlänge über 64 ergibt INVALID_PARAMETER. Gültige Duplikate werden gruppiert. Beliebige syntaktisch gültige Namen sind als Filterwert zulässig; Treffer entstehen nur bei exakter case-sensitiver Übereinstimmung mit einer WaitGroup, die TVF_WaitTypeInfo für die jeweilige Waittypzeile liefert. Ein endlicher erlaubter Namenskatalog ist nicht im Parameterparser festgelegt. Exklusiv mit @WaitGroupPattern, wenn beide nicht NULL sind. Begrenzt Tasks und Instanz-Waits.

**@WaitGroupPattern:** @WaitGroupPattern: nvarchar(4000); Default=NULL. Ausgelassen/NULL deaktiviert. Präfix-, Trim-, LIKE-/Regex-, Leerwert- und Regexvoraussetzungen entsprechen @WaitTypePattern; LIKE und Regex vergleichen case-sensitive/case-insensitive gemäß Modus mit der Katalog-WaitGroup. Exklusiv mit @WaitGroups. Regex wird spät angewandt, hebt das frühe Tasklimit auf und entfernt Instanzzeilen nach der Prozentberechnung, ohne den Nenner neu zu normalisieren.

**@SystemSessionsEinbeziehen:** @SystemSessionsEinbeziehen: bit; Default=0. Ausgelassen ergibt 0. 0 schließt Tasks von System-Sessions aus (is_user_process=0); 1 bezieht sie ein. NULL ist nicht als ungültig validiert und wird wie nicht gleich 1 behandelt: User-Sessions passieren, System-Sessions nicht. Numerische Eingaben werden vor Procedure-Eintritt zu bit konvertiert (0→0, Nichtnull→1). Nur Taskpfad.

**@ToolHintergrundabfragenEinbeziehen:** @ToolHintergrundabfragenEinbeziehen: bit; Default=0. Ausgelassen ergibt 0. 0 blendet als Tool-Hintergrundabfrage erkannte Tasks aus; 1 bezieht sie mit Klassifikationsfeldern ein. NULL und jeder nach Konvertierung nicht als 0/1 zulässige Wert führen zu INVALID_PARAMETER. Numerische Eingaben konvertieren vor Eintritt zu bit (0→0, Nichtnull→1). Filter betrifft Tasks, nicht Instanz-Wait-Stats; Erkennung beruht auf dem Toolklassifikationshelper und ist keine Sicherheitsgrenze.

**@MitSqlText:** @MitSqlText: bit; Default=1. Ausgelassen ergibt 1. 1 versucht den aktuellen Statementtext für Taskzeilen aus dem jeweiligen Requestkontext zu ergänzen; 0 unterdrückt Textzugriff/-projektion. NULL ist nicht eigens ungültig und folgt den IF/CASE-Gleich-1-Pfaden, damit wird Text nicht ergänzt. Numerische Werte werden vor Eintritt zu bit konvertiert. Bei Parent-Snapshot wird vorhandener gemeinsamer Text nur bei Aktivierung konsumiert; die Taskquellen können unabhängig vom Filter bereits materialisiert sein.

**@MaxSqlTextZeichen:** @MaxSqlTextZeichen: int; Default=2000 Zeichen. Ausgelassen nutzt 2000. Nichtnegative Ganzzahl zulässig; negativ ist INVALID_PARAMETER. NULL und 0 heben die durch diesen Grenzwert bewirkte Zeichenbegrenzung auf. Positive Werte begrenzen/kürzen CurrentStatement nach dieser Zahl und können Trunkierungswarnungen erzeugen. Steuert Textbreite, nicht Kandidatenzahl.

**@SampleSeconds:** @SampleSeconds: tinyint; Default=0 Sekunden. Ausgelassen ergibt 0; zulässiger Bereich 0..60, Werte über 60 ergeben INVALID_PARAMETER (tinyint-Konvertierung erfolgt vor Eintritt). 0 liefert kumulative sys.dm_os_wait_stats; 1..60 liest Wait-Stats vor und nach WAITFOR DELAY der entsprechenden Sekundenzahl und bildet daraus das Delta; aktuelle Tasks werden zuvor einmal als Snapshot erfasst und nicht erneut gesampelt. Wird die numerische Steuerprüfung beim Status AVAILABLE erreicht, ist NULL ungültig und führt vor der fachlichen Quellaufnahme zu INVALID_PARAMETER bei unverändertem IsPartial=0; frühere Statuswerte wie UNAVAILABLE_FEATURE bleiben vorrangig. Die Eingabe wird vor Prozedureintritt als SQL-tinyint gebunden; Textwerte durchlaufen die SQL-Typkonvertierung, Leertext hat keinen eigenen Sonderdefault. Bei ParentCurrentStateSnapshotId werden Tasks/Sessions/Requests/Text aus dem Elternsnapshot bezogen, Wait-Stats-Sampling bleibt ein eigener Messpunkt.

**@UnkritischeWaitsEinbeziehen:** @UnkritischeWaitsEinbeziehen: bit; Default=0. Ausgelassen ergibt 0. 0 schließt Instanz-Waitzeilen aus, deren Katalogfeld IsGenerallyBenign=1 ist; 1 lässt sie in die Instanzstatistik ein. Das ist keine globale Aussage, dass ein Wait bei konkreter Workloadauswirkung unkritisch wäre. NULL wird nicht abgelehnt und der Vergleich =1 ist nicht TRUE, daher werden nur Katalogzeilen mit IsGenerallyBenign=0 aufgenommen; NULL-Katalogklassifikation passiert ebenfalls nicht. Numerische Eingaben werden vor Eintritt zu bit konvertiert. Taskfilter werden davon nicht verändert.

**@TopWaitPercentage:** @TopWaitPercentage: decimal(5,2); Default=95.00 Prozent. Ausgelassen nutzt 95.00. Zulässig ist >0 und <=100; 0, negative oder >100 ergeben INVALID_PARAMETER. Wird die numerische Steuerprüfung beim Status AVAILABLE erreicht, ist NULL ungültig und führt vor der fachlichen Quellaufnahme zu INVALID_PARAMETER bei unverändertem IsPartial=0; frühere Statuswerte wie UNAVAILABLE_FEATURE bleiben vorrangig. Die Eingabe wird vor Prozedureintritt als SQL-decimal(5,2) gebunden; Textwerte durchlaufen die SQL-Typkonvertierung, Leertext hat keinen eigenen Sonderdefault. Die Prozentwerte und ihr Nenner entstehen nach Benign-, exakten Listen- und LIKE-Filtern. Danach entfernt Regex weitere Zeilen ohne Neuberechnung dieser Prozentwerte; erst anschließend folgen Kumulierung und der Cutoff CumulativePercentage - WaitPercentage >= Wert.

**@MaxZeilen:** @MaxZeilen: int; Default=1000 Zeilen je Fachmenge. Ausgelassen nutzt 1000; negativ ist INVALID_PARAMETER; NULL oder 0 bedeutet unbegrenzt. Positiver Wert begrenzt Tasks und Instanz-Waits jeweils separat nach ihrer Auswahlordnung. Beim einfachen Taskpfad werden höchstens N+1 Kandidaten gelesen, um Abschneidung zu erkennen; bei N=int-Max wird Kandidatengrenze als bigint N+1 berechnet und ist daher 2147483648, kein int-Überlauf. Regex oder unbegrenzte Ausgabe hebt dieses frühe Kandidatenlimit auf; spätere Zeilenbegrenzung bleibt. Instanzwerte werden vollständig aggregiert und danach begrenzt.

**@ResultSetArt:** @ResultSetArt: varchar(16); Default='CONSOLE'. Ausgelassen nutzt CONSOLE. Nach LTRIM/RTRIM und UPPER sind genau RAW (Status, Task-/Instanzdaten, Warnings), CONSOLE (Taskgrid mit Beschriftung; bei leerer Menge Hinweiszeile), TABLE (Export nur currentTasks in geprüftes Ziel) und NONE (keine fachlichen Resultsets) zulässig; sonst INVALID_PARAMETER. NULL wird zu leerem Text normalisiert und ist ungültig. Werte sind case-insensitive. Nichtleeres @ResultTablesJson außerhalb TABLE wirft im normalen Pfad 51011; Hilfe kehrt vorher zurück.

**@ResultTablesJson:** @ResultTablesJson: nvarchar(max); Default=NULL. Bei @ResultSetArt=TABLE erforderlich: gültiges, nichtleeres JSON-Objekt mit exakt case-sensitivem Schlüssel currentTasks und einem nichtleeren JSON-String als Wert. Der String benennt exakt (ohne Trim-Normalisierung) eine vorhandene lokale #Temp-Tabelle; LTRIM/RTRIM mit SQL-Standard-Leerzeichen U+0020 prüft nur, ob der Zielname leer ist. Zulässig sind Namen mit führendem #, nicht ##, höchstens 116 Zeichen gemäß SQL-LEN-Prüfung und nicht mit #Monitor beginnend (Präfixprüfung case-insensitiv); Ziel muss leer sein und genau eine Seed-Spalte beliebigen Typs haben. Unbekannter/duplizierter Schlüssel oder Ziel, falscher JSON-Werttyp, ungültige JSON-Form, fehlendes oder unzulässiges Ziel sowie befülltes oder abweichend spaltiges Ziel werfen beim Preflight 51011. Außerhalb TABLE müssen NULL, leer oder nach LTRIM/RTRIM nur gewöhnliche U+0020-Leerzeichen stehen; eine danach nichtleere Map wirft im normalen Pfad 51011; Hilfe kehrt vorher zurück.

**@JsonErzeugen:** @JsonErzeugen: bit; Default=0. Ausgelassen ergibt 0. 0 deaktiviert JSON; 1 erzeugt unabhängig von ResultSetArt ein JSON-Objekt mit meta, currentTasks, instanceWaits und warnings. NULL wird nicht eigens abgelehnt und der IF-Gleich-1-Zweig wird nicht ausgeführt, sodass kein JSON erzeugt wird. Numerische Eingaben werden vor Eintritt zu bit konvertiert (0→0, Nichtnull→1).

**@Json:** @Json: nvarchar(max) OUTPUT; Default=NULL. Zum Empfang muss eine nvarchar(max)-Variable gebunden und im EXEC mit OUTPUT markiert werden. Procedure setzt den Parameter beim Eintritt auf NULL; mit @JsonErzeugen=1 enthält er das Envelope, sonst bleibt er NULL. Ohne Bindung kann der Wert nicht empfangen werden.

**@PrintMeldungen:** @PrintMeldungen: bit; Default=1. Ausgelassen ergibt 1. 1 erlaubt optionale Zusatz-/Warnmeldungen, 0 unterdrückt sie; Ergebnissets und JSON bleiben davon unabhängig. NULL wird nicht validiert und die Gleich-1-Ausgabezweige bleiben aus. Numerische Werte werden vor Eintritt zu bit konvertiert (0→0, Nichtnull→1).

**@Hilfe:** @Hilfe: bit; Default=0. Ausgelassen ergibt 0. Genau 1 druckt Hilfe und beendet vor fachlicher Analyse; 0 führt regulär aus. NULL wird nicht als Hilfe erkannt und ist nicht ungültig; numerische Werte werden vor Eintritt zu bit konvertiert. Vor diesem Zweig gilt: Im normalen Pfad wirft eine bei nicht-TABLE unzulässige nichtleere @ResultTablesJson-Map 51011; bei TABLE kann der Einzelziel-Preflight ebenfalls 51011 werfen. @Hilfe=1 kehrt vor beiden Prüfungen zurück.

**@ParentCurrentStateSnapshotId:** @ParentCurrentStateSnapshotId: uniqueidentifier; Default=NULL. Ausgelassen/NULL erzeugt eine eigene Snapshot-ID und liest Quellen selbst. Ein GUID bindet Tasks, Sessions, Requests und gegebenenfalls SQL-Text an die gleichnamige, im aufrufenden Sessionkontext vorhandene Parent-Snapshot-ID mit OwnerSessionId=@@SPID und ContractVersion=2; fehlender/fremder/unpassender Kontext führt zu behandelten Fehler-/Partialstatus. Instanzweite Wait-Stats werden weiterhin separat kumulativ oder im Sample gelesen. Ungültig formatierte Eingaben scheitern bereits bei SQL-Konvertierung zu uniqueidentifier.

## Resultate und Ausgabe

RAW, CONSOLE, NONE und optionales JSON mit currentTasks, instanceWaits und warnings.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| currentTasks | 1 | 1 | [SessionId] smallint NULL,[ExecContextId] int NULL,[WaitDurationMs] bigint NULL,[WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[BlockingSessionId] smallint NULL,[ResourceDescription] nvarchar(3072) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SessionStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[RequestStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[LoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[HostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsToolBackgroundQuery] bit NOT NULL,[ToolBackgroundRuleCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ToolBackgroundCategory] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ToolBackgroundDetection] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ToolBackgroundConfidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[DatabaseId] smallint NULL,[Command] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CurrentStatementCharacters] bigint NULL,[CurrentStatementBytes] bigint NULL,[CurrentStatementIsTruncated] bit NOT NULL DEFAULT(0),[CurrentStatement] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WaitGroup] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WaitSeverity] tinyint NULL,[IsGenerallyBenign] bit NULL,[WaitMeaning] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WaitTypicalOccurrence] nvarchar(1200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[HighWaitImpact] nvarchar(1200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[RecommendedChecks] nvarchar(1500) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WaitHelpUrl] nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[DescriptionSource] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[DescriptionQuality] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CatalogMatchType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_CurrentWaits] @ResultSetArt='CONSOLE';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_CurrentWaits; Snapshotdiagnostik, keine Historie.

Daten: sys.dm_os_waiting_tasks plus sys.dm_os_wait_stats kumulativ oder gesampelt.

Berechtigung: VIEW SERVER STATE bis 2019, VIEW SERVER PERFORMANCE STATE ab 2022.

Regex benötigt SQL Server 2025 und Compatibility Level 170.

RAW/JSON enthalten Status und Warnungen; ungültige Kombinationen ergeben INVALID_PARAMETER, Regex ohne Voraussetzung UNAVAILABLE_FEATURE. JSON enthält meta, currentTasks, instanceWaits und warnings. TABLE-Preflight läuft nur im normalen Pfad nach dem Hilfezweig und kann bei ungültigem Mapping werfen.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_CurrentWaits
Version      : 4.0.0
Stand        : 2026-07-23
Zweck        : Liefert aktuelle Waiting Tasks sowie kumulativen oder
               gesampelten instanzweiten Wait-Kontext mit Listen- und
               Patternfiltern.
Ausgabe      : RAW, CONSOLE, NONE und optionales JSON mit currentTasks,
               instanceWaits und warnings.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_CurrentWaits; Snapshotdiagnostik, keine Historie.
Daten: sys.dm_os_waiting_tasks plus sys.dm_os_wait_stats kumulativ oder gesampelt.
Berechtigung: VIEW SERVER STATE bis 2019, VIEW SERVER PERFORMANCE STATE ab 2022.
Regex benötigt SQL Server 2025 und Compatibility Level 170.
RAW/JSON enthalten Status und Warnungen; ungültige Kombinationen ergeben INVALID_PARAMETER, Regex ohne Voraussetzung UNAVAILABLE_FEATURE. JSON enthält meta, currentTasks, instanceWaits und warnings. TABLE-Preflight läuft nur im normalen Pfad nach dem Hilfezweig und kann bei ungültigem Mapping werfen.
CONSOLE:
TABLE-Mapping separat deklarieren; lokale Ziele müssen leere Einspalten-#Temp-Tabellen sein:
DECLARE @Tables nvarchar(max);
CREATE TABLE #CurrentWaits_HelpExample (Seed int NULL);
DROP TABLE #CurrentWaits_HelpExample;
JSON:
DECLARE @Json nvarchar(max);
```

