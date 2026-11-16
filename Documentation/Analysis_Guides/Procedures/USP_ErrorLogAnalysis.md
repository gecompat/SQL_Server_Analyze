# [monitor].[USP_ErrorLogAnalysis]

**Bereich:** Infrastructure<br>
**Zweck:** Verdichtet begrenzte SQL-Server- und optional SQL-Agent-Errorlogtreffer zu Kategorien.<br>
**Beobachtungsart:** serverlokaler, rotationsabhängiger Ereignissnapshot<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet: **Welche kuratierten Engine-, I/O-, Backup-, Wachstums-, Anmelde- oder Betriebsereignisse sind im gewählten Errorlog- und Zeitbereich sichtbar?** Sie ist eine Triagehilfe für einen konkreten Störungszeitraum, kein allgemeiner Logexport. Der Standard liest nur Archiv `0`, verwendet einen 24-Stunden-Zeitraum in der vom Errorlog gelieferten Serverlokalzeit und gibt ausschließlich Kategorien, Häufigkeiten und Zeitgrenzen aus. Meldungstext, ProcessInfo, SQL-Agent-Log und ältere Archive sind opt-in.

Eine Kategorie ist eine Such- und Klassifikationsspur. Sie beweist weder Ursache noch Betroffenheit. Ein `IO_ERROR` muss beispielsweise mit Datei-I/O, Windows-/Linux- und Storage-Evidenz korreliert werden. Ein Backup-Treffer ersetzt keine Prüfung der Backupkette oder einen Test-Restore. `sourceStatus` zeigt je Produkt, Archiv und Suchregel, ob die Quelle verfügbar, begrenzt oder verweigert war.

## Nicht beantwortete Fragen

Die Procedure liest keine Betriebssystem- oder Storage-Logs, keinen SQL-Text, keine Jobschritte und keine vollständige Ereignishistorie. Rotation kann ältere Ereignisse entfernen; ein nicht gelesener Archivbereich bleibt unbekannt. `sp_readerrorlog` besitzt keinen dokumentierten Zeitparameter. Der Keywordfilter wirkt in der Systemprocedure, die Zeitgrenze erst auf dem zurückgegebenen Trefferset. Ein kleines `@MaxQuellzeilen` begrenzt daher Speicher und weitere Verarbeitung, garantiert aber keine proportionale Quell-I/O-Reduktion.

Eine leere Summary bedeutet nur: Im sichtbaren Produkt-, Archiv-, Keyword- und Zeit-Scope entstand kein Treffer. Sie ist kein Nachweis, dass ein Ereignis nie auftrat. Lokalisierte oder anders formulierte Meldungen können einen kuratierten englischen Filter nicht treffen. Ein benutzerdefinierter Suchtext erweitert die Standardregeln nicht, sondern ersetzt sie für den Aufruf.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ErrorLogAnalysis]
      @MaxArchivNummer = 0,
      @MeldungstextEinbeziehen = 0,
      @MaxQuellzeilen = 10000,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Für einen synthetischen Filter kann beispielsweise `@Suchtext1 = N'ExampleWave2NoMatch'` verwendet werden. Erst wenn die Kategorie und der Zeitraum relevant sind, sollte Meldungstext mit einer kleinen Grenze opt-in gelesen werden. Der Aufruf wechselt oder löscht kein Log.

## Parameter

| Parameter | Typ | Default | Eingabe und Wirkung |
|---|---|---|---|
| `@AgentEinbeziehen` | `bit` | `0` | 0 liest nur SQL-Server-Logs. 1 nimmt zusätzlich Agent-Logs auf. NULL/andere Bitwerte ungültig. |
| `@MaxArchivNummer` | `tinyint` | `0` | Höchste Archivnummer. 0 nur aktuelles Log, n liest Archive 0..n für gewählte Produkte. 0..20 inkl.. NULL oder >20 ungültig. Keine Rotation. |
| `@SeitServerlokalzeit` | `datetime2(3)` | `NULL` | Untergrenze für LogDate in Serverlokalzeit. NULL berechnet 24 Stunden vor serverlokaler SYSDATETIME beim Prozedurstart. Der Grenzwert wird nach Keywordfilter angewandt, sp_readerrorlog wird dadurch zeitlich nicht eingeengt. Fester Zeitpunkt empfohlen für reproduzierbare Läufe. kein UTC-Offset wird angenommen. |
| `@Suchtext1` | `nvarchar(4000)` | `NULL` | NULL zusammen mit Suchtext2=NULL aktiviert kuratierte Suchregeln. Ein nichtleerer Suchtext ersetzt diese Regeln durch den dokumentierten Keywordfilter. Leertext und reine Leerzeichen sind ungültig. Suchtext2 darf nur zusammen mit Suchtext1 gesetzt sein. |
| `@Suchtext2` | `nvarchar(4000)` | `NULL` | Optionaler zweiter Keywordfilter zusammen mit Suchtext1. NULL deaktiviert ihn. Ohne ersten Suchtext oder bei leerer beziehungsweise nur aus Leerzeichen bestehender Eingabe ist der Aufruf ungültig. |
| `@MeldungstextEinbeziehen` | `bit` | `0` | 0 lässt Details/Volltext aus. 1 aktiviert Detailausgabe mit ProcessInfo und projiziertem Meldungstext (Datenschutz-Opt-in). NULL ungültig. Ausgabe bleibt durch MaxZeilen und MaxMeldungszeichen begrenzbar. |
| `@MaxMeldungszeichen` | `int` | `4000` | Maximale Zeichen pro projiziertem Meldungstext. 4000 default, 0 explizit unbegrenzt. nichtnegativ. Kürzung erzeugt genau eine Warning. NULL/negativ ungültig. |
| `@MaxQuellzeilen` | `int` | `10000` | Eine positive ganze Zahl begrenzt die materialisierten Quelltreffer. NULL oder 0 hebt die Grenze auf. Negative Werte sind ungültig. Keywordfilter wirken beim Loglesen, die Zeitprüfung anschließend. |
| `@MaxZeilen` | `int` | `1000` | Detailausgabe Top-N nach Sortierung. 1000 default, 0 oder NULL unbegrenzt, positiv begrenzt, negativ ungültig. Begrenzt keine Summary, Quellenstatus, Zähler oder Warnungen. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | CONSOLE zeigt die Zusammenfassung. RAW liefert alle fachlichen Mengen mit Status und Warnungen. TABLE schreibt benannte Ergebnismengen. NONE unterdrückt die Resultsets. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. NULL, Leertext und andere Werte sind ungültig. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Bei TABLE ist ein gültiges nichtleeres JSON-Objekt erforderlich. Wählen Sie eine Teilmenge der exakten Schlüssel moduleStatus, summary, details, sourceStatus und warnings. Jeder Wert benennt eine andere vorhandene leere lokale #Temp-Tabelle mit einer Seed-Spalte. Globale Tabellen und #Monitor-Präfixe sind ausgeschlossen. Außerhalb von TABLE sind nur NULL, Leertext und reine Leerzeichen zulässig. |
| `@JsonErzeugen` | `bit` | `0` | 1 erzeugt JSON, 0 aus. NULL ungültig. JSON enthält Metadaten, Summary und je nach Opt-in Details. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Outputparameter, wird zu Beginn NULL gesetzt. bei JsonErzeugen=1 befüllt. Eingabe ignoriert. Für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden. |
| `@PrintMeldungen` | `bit` | `1` | Steuert PRINT-Meldungen. 1 an, 0 aus, NULL ungültig. Verändert nicht das Resultset. |
| `@Hilfe` | `bit` | `0` | 1 zeigt die Hilfe vor dem Logzugriff und der Parameterprüfung. 0 und NULL führen die Analyse aus. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Outputstatus des Laufs, z.B. AVAILABLE/AVAILABLE_LIMITED/DENIED_PERMISSION. Eingabe ignoriert. Für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Outputbit, kennzeichnet unvollständige Quellen/Evidenz. Eingabe ignoriert. Für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Outputfehlernummer oder NULL, wenn keiner erfasst. Eingabe ignoriert. Für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Outputfehlertext oder NULL, wenn keiner erfasst. Eingabe ignoriert. Für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden. |

## Aufrufbeispiele

```sql
EXEC [monitor].[USP_ErrorLogAnalysis] @Hilfe=1;
```

```sql
DECLARE @Since datetime2(3)='2026-01-01T00:00:00';
EXEC [monitor].[USP_ErrorLogAnalysis] @SeitServerlokalzeit=@Since, @Suchtext1=N'ExampleNoMatch', @MaxQuellzeilen=100, @MaxZeilen=25, @ResultSetArt='RAW';
```

```sql
DECLARE @Since datetime2(3)='2026-01-01T00:00:00';
DECLARE @ResultJson nvarchar(max);
EXEC [monitor].[USP_ErrorLogAnalysis] @SeitServerlokalzeit=@Since, @Suchtext1=N'ExampleNoMatch', @MaxQuellzeilen=100, @MaxZeilen=25, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT;
SELECT @ResultJson AS [Json];
```

```sql
CREATE TABLE #ErrorLogAnalysis_HelpExample ([Seed] int NULL);
DECLARE @Since datetime2(3)='2026-01-01T00:00:00';
BEGIN TRY EXEC [monitor].[USP_ErrorLogAnalysis] @SeitServerlokalzeit=@Since, @Suchtext1=N'ExampleNoMatch', @MaxQuellzeilen=100, @MaxZeilen=25, @ResultSetArt='TABLE', @ResultTablesJson=N'{"moduleStatus":"#ErrorLogAnalysis_HelpExample"}';
SELECT * FROM #ErrorLogAnalysis_HelpExample;
DROP TABLE #ErrorLogAnalysis_HelpExample;
END TRY BEGIN CATCH DROP TABLE #ErrorLogAnalysis_HelpExample;
THROW;
END CATCH;
```

## Resultsets und Leserichtung

Der typisierte Vertrag registriert `moduleStatus`, `summary`, `details`, `sourceStatus` und `warnings`. Lesen Sie zuerst `moduleStatus` und `sourceStatus`: `HasMoreSourceRows`, `AVAILABLE_LIMITED`, verweigerte Archive und die Serverlokalzeit bestimmen die Aussagegrenze. Werten Sie danach `summary` nach Produkt und Kategorie aus. `details` bleibt im Standard leer und enthält nur bei einem ausdrücklichen Opt-in den Unicode-sicher projizierten Meldungstext. `warnings` fasst Quelllücken und das globale Quelllimit zusammen.

Alle 37 lokalen Textspalten verwenden die Frameworkcollation
`SQL_Latin1_General_CP1_CS_AS`; 35 davon wurden zusätzlich annotiert.
Die fünf TABLE-Exporte enthalten zusammen 22 Textspalten. Ein Export
übernimmt damit keine abweichende `tempdb`-Collation.

`@MaxZeilen` begrenzt ausschließlich die materialisierten Details nach
derselben Sortierung in RAW, TABLE und JSON. Summary, Quellenstatus,
Quellzähler und Warnungen bleiben von diesem Detailausgabelimit ungekürzt.
Auch die Meldungskürzungswarnung bezieht sich weiterhin auf die vollständige
Detailmenge vor der Zeilenauswahl. CONSOLE zeigt ausschließlich die Summary.

## Eine Zeile bedeutet

In `summary` bedeutet eine Zeile eine Kombination aus Produkt (`SQL_SERVER` oder `SQL_AGENT`) und Kategorie im gewählten Scope. `EventCount` ist die Anzahl deduplizierter Treffer, nicht die Zahl unterschiedlicher Ursachen. In `details` ist eine Zeile ein einzelner sichtbarer Logeintrag. In `sourceStatus` ist eine Zeile ein konkreter Leseversuch für Produkt, Archiv und Suchregel.

## So lesen

Prüfen Sie zuerst die Zeitsemantik und Archivgrenze. Unterscheiden Sie danach vollständige und partielle Quellen. Berücksichtigen Sie anschließend `EventCount` sowie den ersten und letzten Zeitpunkt gemeinsam. Ein wiederkehrendes Ereignis nahe dem Störungsfenster ist aussagekräftiger als ein alter Einzelwert, bleibt jedoch eine Korrelation. Bei Details zeigen `MessageCharacters`, `MessageBytes` und `MessageIsTruncated`, ob der Text vollständig sichtbar ist. Mehrere Regeln können denselben Eintrag treffen; die Procedure dedupliziert nach Produkt, Archiv, Zeit, ProcessInfo und Text-Hash.

## Warum kann das problematisch sein?

Errorlogs enthalten Hinweise auf schwere I/O-Fehler, Dumps, lange I/O-Vorgänge, fehlgeschlagene Backups, Login-Probleme und andere Betriebsstörungen. Wiederholte Treffer können einen Incident zeitlich eingrenzen. Gleichzeitig können groß gewordene Archive und breite Textfilter teuer sein. Unbegrenzte Archive, leere Suchtexte oder standardmäßig ausgegebener Volltext würden sowohl Eigenlast als auch Datenexposition erhöhen; diese Pfade sind deshalb begrenzt oder opt-in.

## Wann ist es kein Problem?

Ein Treffer kann zu geplanter Wartung, einem bekannten Test oder einem bereits behobenen Ereignis gehören. Eine Cache-Flush- oder Autogrowth-Meldung ist ohne Häufigkeit, Größenordnung und Workloadwirkung keine Fehlkonfiguration. Ein Loginfehler kann absichtlich durch einen kontrollierten Test entstanden sein. Bewertung benötigt Betriebsfenster, Wiederholung und eine unabhängige Quelle.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Mehrere `IO_ERROR`-Treffer im engen Incidentfenster, gleichzeitig wiederholt Pending I/O auf derselben `ExampleDatabase`-Datei und passende OS-Ereignisse. Das ist eine belastbare Spur für eine Storage-Vertiefung, noch keine automatische Hardwarediagnose.

**Gegenbeispiel:** Ein einzelner alter Backupfehler in Archiv 4 bei anschließend grüner Backupkette und erfolgreichem Restoretest rechtfertigt keine aktuelle Störungsaussage.

**Nicht entscheidbar:** `NOT_EXECUTED_ROW_LIMIT` oder fehlende Rechte bei einzelnen Archiven verhindern eine Entwarnung. Begrenzen Sie den Scope stärker oder prüfen Sie die Quelle mit autorisierten Rechten erneut.

## Leere oder partielle Ausgabe

`AVAILABLE` plus leere Summary bedeutet keinen Treffer im vollständig gelesenen Scope. `AVAILABLE_LIMITED` bedeutet, dass mindestens eine Regel, ein Archiv oder das Quelllimit die Evidenz einschränkt. `DENIED_PERMISSION` ist keine Nullmessung. `HasMoreDetailRows` betrifft das sichtbare Detail-Top-N; `HasMoreSourceRows` ist die stärkere Grenze, weil bereits die materialisierte Quellmenge unvollständig ist.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Aktuelles SQL-Server-Log, kuratierte Keywordfilter, 24 Stunden serverlokal, kein Volltext. |
| Teuerster Pfad | Viele Archive, Agent, benutzerdefinierter breiter Filter, unbegrenzte Quelle und Meldungstext. |
| Haupttreiber | Archivgröße, Trefferbreite, Anzahl Regeln und Archive. |
| Skalierung | Leseversuche wachsen mit Regeln × Produkte × Archive; Deduplizierung wächst mit akzeptierten Treffern. |
| Ressourcen | Systemprocedure, TempDB-Materialisierung, Hashing und optionale Textprojektion. |
| Begrenzungswirkung | Keywordfilter wirkt in `sp_readerrorlog`; Zeit und `@MaxQuellzeilen` wirken anschließend. |
| Locking und Nebenwirkungen | Read-only, `LOCK_TIMEOUT 0`, kein Logwechsel und keine Persistenz. |
| Schutzmechanismus | Archivmaximum 20, Quelllimit 10000, Agent und Meldungstext standardmäßig aus. |
| Sicherer Einsatz | Archiv 0, enger Zeitraum, Summary zuerst, Details nur gezielt. |
| Aussagegrenze | Rotation, Sprache, Rechte und Filter verhindern eine vollständige historische Negativaussage. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche hochsignaligen Errorlogkategorien sind im abgegrenzten Betriebsfenster sichtbar?

### Technischer Hintergrund

Die dokumentierten vier Parameter von `sp_readerrorlog` adressieren Archiv, Produkt und zwei Suchtexte. Deshalb entsteht der Zeitvertrag aus serverseitigem Keywordfilter und nachgelagertem Vergleich von `LogDate`. Die reine Funktion `TVF_ClassifyErrorLogEvent` macht die Klassifikation mit synthetischen Texten testbar, ohne einen echten Logeintrag zu erzeugen.

### Datenkette

`master.sys.sp_readerrorlog`, `monitor.TVF_ClassifyErrorLogEvent`, `monitor.TVF_ProjectUnicodeText`.

### Source Select

Kein direktes `SELECT`: SQL Server stellt das Error Log über die System-Procedure bereit. Der reduzierte Quellaufruf zeigt die wichtigen serverseitigen Einschränkungen:

```sql
EXEC [master].[sys].[sp_readerrorlog]
      @p1 = 0,
      @p2 = 1,
      @p3 = N'Error',
      @p4 = NULL;
```

**Wichtig für die Eigenlast:** Archivnummer, Produkt und Suchbegriffe werden an `sp_readerrorlog` übergeben. Die Serverlokalzeitgrenze wirkt erst auf die zurückgegebenen Treffer. Eine spätere Textklassifikation oder `@MaxZeilen`-Begrenzung spart keinen bereits erfolgten Logdateizugriff.

### Zeit- und Scope-Modell

`LogDate` wird als `SERVER_LOCAL_TIME_FROM_ERRORLOG` erhalten. UTC-Umrechnung wird ohne sichere Offsetevidenz nicht erfunden. Archive, Produkt, Suchregeln, Zeit und Quelllimit bilden gemeinsam den Scope.

### Bewertung und Gegenprobe

Bewerten Sie zuerst Kategorie, Wiederholung und zeitliche Nähe. Prüfen Sie danach eine passende Fachquelle wie Current I/O, Backupkette, Agentstatus oder OS-Telemetrie.

### Typische Fehlinterpretation

Ein Keywordtreffer ist keine bestätigte Ursache; kein Treffer ist ohne vollständigen Scope keine Entwarnung.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_CurrentIO`, `USP_BackupChainAnalysis`, `USP_AgentMonitoringAnalysis` sowie autorisierte OS-/Storage-Telemetrie.

## Primärquellen

- [sp_readerrorlog](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-readerrorlog-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#14-monitorusp_errorloganalysis)
