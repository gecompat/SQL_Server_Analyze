# [monitor].[USP_CurrentWaits]

**Bereich:** Current State<br>
**Zweck:** Zeigt aktuelle oder kurz gesampelte Waits und ordnet sie Waitgruppen zu.<br>
**Beobachtungsart:** Snapshot + kumulativ + optionale Stichprobe<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Auf welche Ressourcen oder Ereignisse warten Tasks aktuell, und welche Waits dominierten Instanz oder Sample?** Sie unterstützt die Entscheidung, ob das aktuelle Symptom im Erfassungsmoment sichtbar ist und welcher engere Live-, Verlaufs- oder Planpfad als Nächstes sinnvoll ist.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine lückenlose Historie und allein aus einem Snapshot weder Dauerhäufigkeit noch Root Cause oder zukünftige Entwicklung. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

Die vollständige Parameterhilfe zu Quellen, Ausgaben und Grenzen erscheint mit `EXEC [monitor].[USP_CurrentWaits] @Hilfe = 1`.

```sql
EXEC [monitor].[USP_CurrentWaits]
      @SampleSeconds = 5,
      @MitSqlText = 0,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Das Sample betrifft die instanzweiten Wait-Statistiken; aktuelle wartende Tasks
werden einmalig als Snapshot gelesen. SQL-Text anschließend nur für konkrete
Sessions zuschalten.

Erkannte Tool-Hintergrundtasks sind im Default ausgeblendet und werden mit
`@ToolHintergrundabfragenEinbeziehen = 1` samt Klassifikation sichtbar. Der
Schalter betrifft nur aktuelle Tasks; instanzweite Wait-Stats lassen sich nicht
nach Client aufteilen.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parametervertrag

Die folgenden Verträge beschreiben jeden Parameter einzeln. Vor der Hilfe werden nichtleere Zuordnungen außerhalb von TABLE und bei TABLE das Zielmapping geprüft. Ungültige Zuordnungen können deshalb auch bei `@Hilfe = 1` den Fehler 51011 auslösen.

| Parameter | Typ, Default, Eingabeform und Wirkung |
|---|---|
| `@SessionIds` | nvarchar(max); Default=NULL. Ausgelassen entspricht NULL und deaktiviert den Filter. TVF_ParseBigintList ersetzt jedes Komma und Semikolon durch Pipe (auch innerhalb von Klammern), danach trennt &#124; außerhalb von [...]; ]] maskiert dort ]. Äußere Segmentleerzeichen werden getrimmt, Klammern werden für Zahlen nicht entquotet. Leere Liste/Elemente, fehlerhafte Klammern, Rohsegmente über 4000 UTF-16-Codeeinheiten, nicht bigint-konvertierbare Werte sowie IDs außerhalb 1..32767 ergeben INVALID_PARAMETER; Duplikate werden gruppiert. IDs beschränken nur Tasks; NULL lässt alle sichtbaren Session-IDs passieren. |
| `@MinWaitMs` | bigint; Default=0 ms. Ausgelassen nutzt 0. Ganze Zahlen ab 0 sind zulässig; negativ ist INVALID_PARAMETER. NULL wird nicht eigens abgelehnt, aber der Taskvergleich WaitDurationMs &gt;= NULL ist nicht TRUE und lässt keine Taskzeile passieren. Begrenzt die Mindestdauer aktueller Waiting Tasks, nicht Instanz-Wait-Stats. |
| `@WaitTypes` | nvarchar(max); Default=NULL. Ausgelassen/NULL deaktiviert die exakte WaitType-Auswahl. Sonst bracket-aware Pipe-Liste nach TVF_ParseStringList: Pipe trennt außerhalb [...], innerhalb ist es Inhalt, ]] maskiert ]; getrimmte Einträge werden bei bracket-quotierten Einträgen entklammert/entmaskiert. Leere Liste/Elemente, ungültige Klammern, Rohsegment über 4000 UTF-16-Codeeinheiten oder Wertlänge über 120 ergeben INVALID_PARAMETER. Gültige Duplikate werden gruppiert. Vergleich ist exakt und case-sensitive unter SQL_Latin1_General_CP1_CS_AS; Typen müssen nicht im Katalog stehen. Exklusiv mit @WaitTypePattern, sobald beide nicht NULL sind. Filtert Task- und Instanzmengen. |
| `@WaitTypePattern` | nvarchar(4000); Default=NULL. Ausgelassen/NULL deaktiviert das Pattern. TVF_ParsePattern trimmt äußere Eingabezeichen, erkennt case-insensitiv regexi:, regex: und like:, entfernt genau das Präfix ohne erneutes Trimmen des Rests; ohne Präfix gilt LIKE. LIKE ist case-sensitive SQL-LIKE mit %, _ und []-Klassen; like: wählt denselben Modus. regex: ist case-sensitive (Flag c), regexi: case-insensitive (Flag i). Leere Eingabe oder leerer Präfixrest ist INVALID_PARAMETER; Leerzeichen nach Präfix bleiben Musterinhalt. Exklusiv mit @WaitTypes. Regex erfordert SQL Server 2025/Majorversion 17 und Compatibility Level &gt;=170 der aktuellen Datenbank, sonst UNAVAILABLE_FEATURE. Wird spät auf Task-/Instanzkandidaten angewandt; Regex hebt das frühe Taskkandidatenlimit auf und normalisiert den Instanz-Prozentnenner danach nicht neu. |
| `@WaitGroups` | nvarchar(max); Default=NULL. Ausgelassen/NULL deaktiviert die exakte WaitGroup-Auswahl. Sonst gilt die bracket-aware Pipe-Liste von TVF_ParseStringList: &#124; trennt außerhalb von [...], innerhalb ist es Literalinhalt und ]] maskiert eine schließende Klammer; äußere Leerzeichen der Segmente werden getrimmt. Bei bracket-quotierten Elementen werden die äußeren Klammern entfernt und ]] zu ] entmaskiert. Leere Gesamtliste, leere Elemente, fehlerhafte Klammern, Rohsegmente über 4000 UTF-16-Codeeinheiten und nach Entquotung leere Werte sind ungültig; Wertlänge über 64 ergibt INVALID_PARAMETER. Gültige Duplikate werden gruppiert. Beliebige syntaktisch gültige Namen sind als Filterwert zulässig; Treffer entstehen nur bei exakter case-sensitiver Übereinstimmung mit einer WaitGroup, die TVF_WaitTypeInfo für die jeweilige Waittypzeile liefert. Ein endlicher erlaubter Namenskatalog ist nicht im Parameterparser festgelegt. Exklusiv mit @WaitGroupPattern, wenn beide nicht NULL sind. Begrenzt Tasks und Instanz-Waits. |
| `@WaitGroupPattern` | nvarchar(4000); Default=NULL. Ausgelassen/NULL deaktiviert. Präfix-, Trim-, LIKE-/Regex-, Leerwert- und Regexvoraussetzungen entsprechen @WaitTypePattern; LIKE und Regex vergleichen case-sensitive/case-insensitive gemäß Modus mit der Katalog-WaitGroup. Exklusiv mit @WaitGroups. Regex wird spät angewandt, hebt das frühe Tasklimit auf und entfernt Instanzzeilen nach der Prozentberechnung, ohne den Nenner neu zu normalisieren. |
| `@SystemSessionsEinbeziehen` | bit; Default=0. Ausgelassen ergibt 0. 0 schließt Tasks von System-Sessions aus (is_user_process=0); 1 bezieht sie ein. NULL ist nicht als ungültig validiert und wird wie nicht gleich 1 behandelt: User-Sessions passieren, System-Sessions nicht. Numerische Eingaben werden vor Procedure-Eintritt zu bit konvertiert (0→0, Nichtnull→1). Nur Taskpfad. |
| `@ToolHintergrundabfragenEinbeziehen` | bit; Default=0. Ausgelassen ergibt 0. 0 blendet als Tool-Hintergrundabfrage erkannte Tasks aus; 1 bezieht sie mit Klassifikationsfeldern ein. NULL und jeder nach Konvertierung nicht als 0/1 zulässige Wert führen zu INVALID_PARAMETER. Numerische Eingaben konvertieren vor Eintritt zu bit (0→0, Nichtnull→1). Filter betrifft Tasks, nicht Instanz-Wait-Stats; Erkennung beruht auf dem Toolklassifikationshelper und ist keine Sicherheitsgrenze. |
| `@MitSqlText` | bit; Default=1. Ausgelassen ergibt 1. 1 versucht den aktuellen Statementtext für Taskzeilen aus dem jeweiligen Requestkontext zu ergänzen; 0 unterdrückt Textzugriff/-projektion. NULL ist nicht eigens ungültig und folgt den IF/CASE-Gleich-1-Pfaden, damit wird Text nicht ergänzt. Numerische Werte werden vor Eintritt zu bit konvertiert. Bei Parent-Snapshot wird vorhandener gemeinsamer Text nur bei Aktivierung konsumiert; die Taskquellen können unabhängig vom Filter bereits materialisiert sein. |
| `@MaxSqlTextZeichen` | int; Default=2000 Zeichen. Ausgelassen nutzt 2000. Nichtnegative Ganzzahl zulässig; negativ ist INVALID_PARAMETER. NULL und 0 heben die durch diesen Grenzwert bewirkte Zeichenbegrenzung auf. Positive Werte begrenzen/kürzen CurrentStatement nach dieser Zahl und können Trunkierungswarnungen erzeugen. Steuert Textbreite, nicht Kandidatenzahl. |
| `@SampleSeconds` | tinyint; Default=0 Sekunden. Ausgelassen ergibt 0; zulässiger Bereich 0..60, Werte über 60 ergeben INVALID_PARAMETER (tinyint-Konvertierung erfolgt vor Eintritt). 0 liefert kumulative sys.dm_os_wait_stats; 1..60 liest Wait-Stats vor und nach WAITFOR DELAY der entsprechenden Sekundenzahl und bildet daraus das Delta; aktuelle Tasks werden zuvor einmal als Snapshot erfasst und nicht erneut gesampelt. NULL besteht die Vergleichsvalidierung, wird als Nicht-0 in den Delta-Zweig geleitet und erzeugt bei DATEADD/WAITFOR-Konvertierung einen behandelten Samplingfehler/partielle Delta-Sicht. Bei ParentCurrentStateSnapshotId werden Tasks/Sessions/Requests/Text aus dem Elternsnapshot bezogen, Wait-Stats-Sampling bleibt ein eigener Messpunkt. |
| `@UnkritischeWaitsEinbeziehen` | bit; Default=0. Ausgelassen ergibt 0. 0 schließt Instanz-Waitzeilen aus, deren Katalogfeld IsGenerallyBenign=1 ist; 1 lässt sie in die Instanzstatistik ein. Das ist keine globale Aussage, dass ein Wait bei konkreter Workloadauswirkung unkritisch wäre. NULL wird nicht abgelehnt und der Vergleich =1 ist nicht TRUE, daher werden nur Katalogzeilen mit IsGenerallyBenign=0 aufgenommen; NULL-Katalogklassifikation passiert ebenfalls nicht. Numerische Eingaben werden vor Eintritt zu bit konvertiert. Taskfilter werden davon nicht verändert. |
| `@TopWaitPercentage` | decimal(5,2); Default=95.00 Prozent. Ausgelassen nutzt 95.00. Zulässig ist &gt;0 und &lt;=100; 0, negative oder &gt;100 ergeben INVALID_PARAMETER. NULL wird nicht eigens abgelehnt; Validierungsvergleiche sind UNKNOWN und der spätere Cutoffvergleich entfernt keine Zeilen. Die Prozentwerte und ihr Nenner entstehen nach Benign-, exakten Listen- und LIKE-Filtern. Danach entfernt Regex weitere Zeilen ohne Neuberechnung dieser Prozentwerte; erst anschließend folgen Kumulierung und der Cutoff CumulativePercentage - WaitPercentage &gt;= Wert. |
| `@MaxZeilen` | int; Default=1000 Zeilen je Fachmenge. Ausgelassen nutzt 1000; negativ ist INVALID_PARAMETER; NULL oder 0 bedeutet unbegrenzt. Positiver Wert begrenzt Tasks und Instanz-Waits jeweils separat nach ihrer Auswahlordnung. Beim einfachen Taskpfad werden höchstens N+1 Kandidaten gelesen, um Abschneidung zu erkennen; bei N=int-Max wird Kandidatengrenze als bigint N+1 berechnet und ist daher 2147483648, kein int-Überlauf. Regex oder unbegrenzte Ausgabe hebt dieses frühe Kandidatenlimit auf; spätere Zeilenbegrenzung bleibt. Instanzwerte werden vollständig aggregiert und danach begrenzt. |
| `@ResultSetArt` | varchar(16); Default='CONSOLE'. Ausgelassen nutzt CONSOLE. Nach LTRIM/RTRIM und UPPER sind genau RAW (Status, Task-/Instanzdaten, Warnings), CONSOLE (Taskgrid mit Beschriftung; bei leerer Menge Hinweiszeile), TABLE (Export nur currentTasks in geprüftes Ziel) und NONE (keine fachlichen Resultsets) zulässig; sonst INVALID_PARAMETER. NULL wird zu leerem Text normalisiert und ist ungültig. Werte sind case-insensitive. Nichtleeres @ResultTablesJson außerhalb TABLE wirft vor Hilfe 51011. |
| `@ResultTablesJson` | nvarchar(max); Default=NULL. Bei @ResultSetArt=TABLE erforderlich: gültiges, nichtleeres JSON-Objekt mit exakt case-sensitivem Schlüssel currentTasks und einem nichtleeren JSON-String als Wert. Der String benennt exakt (ohne Trim-Normalisierung) eine vorhandene lokale #Temp-Tabelle; LTRIM/RTRIM mit SQL-Standard-Leerzeichen U+0020 prüft nur, ob der Zielname leer ist. Zulässig sind Namen mit führendem #, nicht ##, höchstens 116 Zeichen gemäß SQL-LEN-Prüfung und nicht mit #Monitor beginnend (Präfixprüfung case-insensitiv); Ziel muss leer sein und genau eine Seed-Spalte beliebigen Typs haben. Unbekannter/duplizierter Schlüssel oder Ziel, falscher JSON-Werttyp, ungültige JSON-Form, fehlendes oder unzulässiges Ziel sowie befülltes oder abweichend spaltiges Ziel werfen beim Preflight 51011. Außerhalb TABLE müssen NULL, leer oder nach LTRIM/RTRIM nur gewöhnliche U+0020-Leerzeichen stehen; eine danach nichtleere Map wirft vor Hilfe 51011. |
| `@JsonErzeugen` | bit; Default=0. Ausgelassen ergibt 0. 0 deaktiviert JSON; 1 erzeugt unabhängig von ResultSetArt ein JSON-Objekt mit meta, currentTasks, instanceWaits und warnings. NULL wird nicht eigens abgelehnt und der IF-Gleich-1-Zweig wird nicht ausgeführt, sodass kein JSON erzeugt wird. Numerische Eingaben werden vor Eintritt zu bit konvertiert (0→0, Nichtnull→1). |
| `@Json` | nvarchar(max) OUTPUT; Default=NULL. Zum Empfang muss eine nvarchar(max)-Variable gebunden und im EXEC mit OUTPUT markiert werden. Procedure setzt den Parameter beim Eintritt auf NULL; mit @JsonErzeugen=1 enthält er das Envelope, sonst bleibt er NULL. Ohne Bindung kann der Wert nicht empfangen werden. |
| `@PrintMeldungen` | bit; Default=1. Ausgelassen ergibt 1. 1 erlaubt optionale Zusatz-/Warnmeldungen, 0 unterdrückt sie; Ergebnissets und JSON bleiben davon unabhängig. NULL wird nicht validiert und die Gleich-1-Ausgabezweige bleiben aus. Numerische Werte werden vor Eintritt zu bit konvertiert (0→0, Nichtnull→1). |
| `@Hilfe` | bit; Default=0. Ausgelassen ergibt 0. Genau 1 druckt Hilfe und beendet vor fachlicher Analyse; 0 führt regulär aus. NULL wird nicht als Hilfe erkannt und ist nicht ungültig; numerische Werte werden vor Eintritt zu bit konvertiert. Vor diesem Zweig gilt: Bei nicht-TABLE ist eine nach LTRIM/RTRIM (gewöhnliche U+0020-Leerzeichen) nichtleere @ResultTablesJson-Map unzulässig und wirft 51011; bei TABLE läuft der Einzelziel-Preflight und kann ebenfalls 51011 werfen. Daher kann eine unzulässige Map auch mit Hilfe den Aufruf abbrechen. |
| `@ParentCurrentStateSnapshotId` | uniqueidentifier; Default=NULL. Ausgelassen/NULL erzeugt eine eigene Snapshot-ID und liest Quellen selbst. Ein GUID bindet Tasks, Sessions, Requests und gegebenenfalls SQL-Text an die gleichnamige, im aufrufenden Sessionkontext vorhandene Parent-Snapshot-ID mit OwnerSessionId=@@SPID und ContractVersion=2; fehlender/fremder/unpassender Kontext führt zu behandelten Fehler-/Partialstatus. Instanzweite Wait-Stats werden weiterhin separat kumulativ oder im Sample gelesen. Ungültig formatierte Eingaben scheitern bereits bei SQL-Konvertierung zu uniqueidentifier. |

## Resultsets und Leserichtung

TABLE schreibt die 33 Felder von `currentTasks`; CONSOLE zeigt dieselbe Taskmenge mit einer zusätzlichen Beschriftung oder bei leerer Menge eine Hinweiszeile. Status, instanzweite Waits und Warnings stehen in RAW beziehungsweise JSON. Diese Evidenz ist vor der Taskausgabe zu prüfen. Die 23 Instanzfelder haben eine andere Zeilengranularität und dürfen nicht mit Taskwerten summiert werden. Alle 22 Task- und elf Instanztextfelder verwenden die Framework-Collation. NULL oder 0 als `@MaxZeilen` bedeutet unbegrenzt; eine positive Grenze kürzt beide Fachmengen vor den Verbrauchern. Die Zeilenzähler beschreiben die ausgegebenen Mengen.

Im Overview konsumiert der aktuelle Taskpfad Waiting Tasks, Sessions, Requests
und deduplizierten SQL-Text aus derselben Snapshot-ID. Die instanzweiten
Wait-Stats und ein optionales Delta-Sample bleiben eigene Messpunkte. Ein
Standalone-Aufruf verwendet ausschließlich frische Quellen.

## Eine Zeile bedeutet

Eine Taskzeile beschreibt eine sichtbare wartende Task mit Session- und Requestkontext. Mehrere Tasks einer Session sind möglich. Eine Instanzzeile beschreibt einen Waittyp im kumulativen Scope oder im Sampledelta.

## So lesen

Berücksichtigen Sie Waittyp und Waitgruppe mit Dauer, Anzahl, Session, Request und Samplemodus. Priorisieren Sie Gesamtzeit und Wiederholung vor Einzelspitzen. Verwenden Sie für die vertiefte Einordnung `TVF_WaitTypeInfo` und für die aussagebezogenen Belege `TVF_WaitTypeSources`.

## Warum kann das problematisch sein?

Ein dominanter Wait zeigt, wo Zeit verloren geht. Relevant wird er durch hohe Gesamtdauer, Wiederholung und konkrete Workloadauswirkung.

## Wann ist es kein Problem?

Viele Waits sind normale Hintergrund- oder Koordinationszustände. Parallelitätswaits allein beweisen keine falsche MAXDOP-Konfiguration.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Ein einzelner `PAGEIOLATCH_SH` über 20 ms beweist kein Storageproblem. Viele solche Waits plus hohe Datei-Latenz und langsame Requests bilden dagegen eine belastbare I/O-Spur. Verwenden Sie danach `USP_CurrentIO`.

**Ähnlich aussehender Gegenfall:** Viele Waits sind normale Hintergrund- oder Koordinationszustände. Parallelitätswaits allein beweisen keine falsche MAXDOP-Konfiguration. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Bei Live-DMVs kann der Zustand bereits beendet sein, bevor die Quelle gelesen wird. Eine leere Menge ist deshalb höchstens 'jetzt nicht sichtbar', nicht 'trat nicht auf'.

Für `USP_CurrentWaits` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Default `@SampleSeconds = 0`: ein Snapshot aktueller wartender Tasks plus kumulative `sys.dm_os_wait_stats` seit SQL-Server-Start. SQL-Text ist standardmäßig an. |
| Teuerster Pfad | 60-Sekunden-Delta, SQL-Text ohne Zeichenlimit, Regexfilter und `@MaxZeilen = 0`. Regex wird spät angewandt und hebt das frühe Kandidatenlimit für Tasks auf; mehrere parallele Sampler belegen mehrere Sessions. |
| Haupttreiber | Zahl aktuell wartender Tasks/Requests und SQL-Textbreite; die instanzweite Waittypmenge ist vergleichsweise klein. Für ein Delta wird `sys.dm_os_wait_stats` zweimal gelesen, aktuelle Tasks aber nur einmal. |
| Skalierung | Taskarbeit wächst mit aktiven Waitern und optionalem Textzugriff. Instanzwaits werden nach Waittyp aggregiert und prozentual eingeordnet; Sampledauer erhöht vor allem Verbindungszeit, nicht die Zeilenzahl. |
| Ressourcen | Joins auf `sys.dm_os_waiting_tasks`, Requests/Sessions und optional `sys.dm_exec_sql_text`; ein oder zwei Wait-Stats-Snapshots, Temp-Tabellen und bei Sampling WAITFOR. |
| Begrenzungswirkung | Für Tasks gilt bei einfachen Filtern ein N+1-Kandidatenlimit; Regex oder unbegrenzte Ausgabe materialisiert alle sichtbaren Kandidaten und löscht erst danach. Instanzwaits werden vollständig aggregiert und erst anschließend auf `@MaxZeilen` gekürzt. Das Limit verkürzt das WAITFOR nicht. |
| Locking und Nebenwirkungen | Read-only. WAITFOR hält nur die aufrufende Verbindung; die Procedure hält keine Nutzdatenlocks über das Intervall. Ein Engine-Restart zwischen Wait-Stats-Snapshots verwirft das Delta. |
| Schutzmechanismus | Kein High-Impact-Gate. `@SampleSeconds` ist auf 60 begrenzt; Session-/Waitfilter, `@MaxZeilen`, `@MaxSqlTextZeichen` und `@MitSqlText = 0` begrenzen Kandidaten beziehungsweise Breite. Regex hebt das frühe Tasklimit auf, und kein Parameter vermeidet den vollständigen Instanz-Wait-Stats-Snapshot. |
| Sicherer Einsatz | Fünf Sekunden, SQL-Text aus, `@MaxZeilen = 100` und bei Bedarf exakte Session-/Waitfilter. Text erst für einen identifizierten Request nachfordern. |
| Aussagegrenze | Aktuelle Tasks und Instanzdelta haben unterschiedliche Zeitmodelle und dürfen nicht zeilengleich korreliert werden. Kumulative Waits sind keine aktuelle Last; ein kurzes Delta kann seltene Ereignisse verpassen. Top-N und späte Regexfilter können relevante Waittypen oder Sessions ausblenden. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Auf welche Ressourcen oder Ereignisse warten Tasks aktuell, und welche Waits dominierten Instanz oder Sample?

### Technischer Hintergrund

Die Procedure kombiniert aktuelle Waiting Tasks mit instanzweiten abgeschlossenen Waits und optionalem Delta. Ressource, Signalzeit, Taskparallelität und Wait Group gehören zum technischen Modell.

### Datenkette

`master.sys.databases`, `sys.dm_exec_requests`, `sys.dm_exec_sessions`, `sys.dm_exec_sql_text`, `sys.dm_os_sys_info`, `sys.dm_os_wait_stats`, `sys.dm_os_waiting_tasks`, `sys.sp_executesql`.

### Source Select

Der Livepfad verbindet wartende Tasks mit Session und aktuellem Request:

```sql
SELECT
      [wt].[session_id]
    , [wt].[exec_context_id]
    , [wt].[wait_type]
    , [wt].[wait_duration_ms]
    , [wt].[blocking_session_id]
    , [r].[database_id]
    , [s].[status] AS [SessionStatus]
FROM [sys].[dm_os_waiting_tasks] AS [wt] WITH (NOLOCK)
LEFT JOIN [sys].[dm_exec_requests] AS [r] WITH (NOLOCK)
  ON [r].[session_id] = [wt].[session_id]
LEFT JOIN [sys].[dm_exec_sessions] AS [s] WITH (NOLOCK)
  ON [s].[session_id] = [wt].[session_id]
WHERE [wt].[wait_duration_ms] >= @MinWaitMs;
```

**Wichtig für die Eigenlast:** Die Procedure materialisiert die Quell-Sessions, Requests und Waiting Tasks sowie bei `@MitSqlText = 1` deduplizierten SQL-Text vor der fachlichen Taskauswahl. Ein Sessionfilter vermeidet diesen Quellzugriff nicht. Die anschließende Unicodeprojektion betrifft die bereits begrenzte Taskmenge. Weitere Join-, Filter-, Sortier- und Statementextraktionsarbeit ist damit nicht physisch auf das Ausgabelimit begrenzt. Der Delta-Pfad liest `sys.dm_os_wait_stats` zweimal; `@SampleSeconds` verursacht Wartezeit, aber keine Nutzdatenlocks.

### Zeit- und Scope-Modell

Die Auswertung kombiniert einen Tasksnapshot mit kumulativem Kontext oder einem gültigen Sampledelta. Aktuelle Tasks werden vor der optionalen Samplingpause erfasst.

### Bewertung und Gegenprobe

Berücksichtigen Sie Waittyp, Dauer, Anzahl, Resource- und Signalanteil, Workloadwirkung und eine zweite Evidenzquelle gemeinsam.

### Typische Fehlinterpretation

Ein Wait ist keine Root Cause und ein hoher kumulativer Wert kein aktuelles Problem.

### Folgeanalyse

Verwenden Sie die kanonischen [Wait-Details](../02_Current_State.md#4-monitorusp_currentwaits), den [Betriebsvertrag des Wait-Katalogs](../../Operations/Wait_Type_Catalog.md) und das [Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md). Verfolgen Sie danach abhängig von der Wait Group Blocking, I/O, Grants, CPU oder HADR weiter.

## Primärquellen

- [sys.dm_os_wait_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-wait-stats-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQLskills Wait Types Library – vertiefende Einordnung einzelner Waittypen](https://www.sqlskills.com/help/waits/)
- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../02_Current_State.md#4-monitorusp_currentwaits)
