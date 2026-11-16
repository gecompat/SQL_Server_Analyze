# [monitor].[USP_BackupChainAnalysis]

**Bereich:** Infrastruktur<br>
**Zweck:** Prüft Full-/Diff-/Log-Beziehungen, LSN-Folgen und optionale Restoreevidenz.<br>
**Beobachtungsart:** persistierte, retentionbegrenzte Historie<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Ist aus sichtbaren Backupsets eine technisch konsistente Restorekette mit passender Full-/Diff-/Log-LSN-Folge rekonstruierbar?** Sie unterstützt die Entscheidung, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_BackupChainAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @HistoryDays = 35,
      @MitRestoreEvidence = 1,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameterverträge

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | Default: `NULL` | Die optionale Liste ist eine durch Pipezeichen getrennte Folge einteiliger SQL-Namen. Der Parser behandelt \| innerhalb von [...] als Namenstext, ]] als maskierte schließende Klammer und entfernt äußere Leerzeichen jedes Elements. Rohsegmente über 4000 UTF-16-Codeeinheiten und Namen über 128 Zeichen sind ungültig; mehrteilige SQL-Namen, ungültige Klammern, leere Elemente und nach SQL_Latin1_General_CP1_CS_AS doppelte Namen führen ebenfalls zu INVALID_PARAMETER. NULL, eine leere Zeichenfolge und ein nur aus Leerzeichen bestehender Wert werden vor dem Listenparser wie keine Liste behandelt und wählen alle für den Aufrufer sichtbaren, online befindlichen und zugänglichen Datenbanken; Systemdatenbanken bleiben ohne Opt-in ausgeschlossen. Nicht verfügbare explizite Namen erzeugen DATABASE_UNAVAILABLE, ohne Opt-in ausgeschlossene Systemnamen SYSTEM_DATABASE_EXCLUDED in der Warning-Tabelle; wenn solche Warnungen vorliegen, wird der Status AVAILABLE_LIMITED. Die Liste ist mit einem nicht-NULL Pattern unvereinbar. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@SystemdatenbankenEinbeziehen` | `bit` | Default: `0` | Der Parameter wird als SQL-bit gebunden; numerische Null wird 0, jeder numerische Nichtnullwert wird 1, NULL bleibt NULL. Nach der Bindung sind nur 0 und 1 gültig: NULL führt beim Kandidatenhelfer zu INVALID_PARAMETER. 0 lässt Systemdatenbanken aus, 1 schließt sie in die Kandidatenauswahl ein. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | Default: `NULL` | Das Eingabefeld ist nvarchar(4000) und nimmt höchstens 4000 UTF-16-Codeeinheiten an. NULL bedeutet Modus NONE; eine leere oder nur aus Leerzeichen bestehende Eingabe ist ungültig, und ein Inhalt, der nach einem Präfix leer bleibt, ebenfalls. Der Parser trimmt äußere Leerzeichen, erkennt LIKE:, REGEX: und REGEXI: ohne Beachtung der Großschreibung und entfernt danach das Präfix; der verbleibende Inhalt wird nicht erneut getrimmt. Ohne Präfix gilt LIKE. LIKE wertet das Pattern mit SQL_Latin1_General_CP1_CS_AS case-sensitiv aus; exakte Datenbanknamen werden ebenfalls mit dieser Collation verglichen; REGEX nutzt Flag c und REGEXI Flag i. REGEX und REGEXI benötigen SQL Server 2025 sowie Compatibility Level 170 der Installationsdatenbank. Ein nicht-NULL Pattern kann nicht zusammen mit einer wirksamen exakten Datenbankliste verwendet werden. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@HighImpactConfirmed` | `bit` | Default: `0` | Der Parameter wird als SQL-bit gebunden: numerische Null wird 0, jeder numerische Nichtnullwert wird 1, NULL bleibt NULL. NULL ist beim Kandidatenhelfer ungültig. Der Aufrufer übergibt @AnalysisClass ausdrücklich als NULL; dadurch wird kein Analyseklassen- oder High-Impact-Gate ausgelöst. Eine gebundene 1 erteilt keine zusätzliche Berechtigung. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@HistoryDays` | `int` | Default: `35` | Zulässige nicht-NULL Werte sind ganze Zahlen von 1 bis 3650 Tagen. Die Backuphistorie wird mit dem Grenzwert DATEADD(DAY, -@HistoryDays, GETDATE()) auf backup_finish_date gefiltert; GETDATE verwendet die lokale Serverzeit. Die Prüfung auf Werte < 1 oder > 3650 steht vor der Backupabfrage, aber nach TABLE-Preflight und Hilfezweig. NULL besteht diese IF-Prüfung wegen SQL-UNKNOWN und ergibt keinen gültigen Cutoff; dann gelangen die normalen Backupsets nicht durch den Zeitvergleich, während der jüngste nicht-copy-only Full je Kandidat per separater OR-Bedingung unabhängig vom Fenster einbezogen wird. Ein zu kurzes Fenster kann weitere benötigte Full-/Diff-/Logevidenz ausschließen. Das Zeitfenster begrenzt Backupsets; die optionale Restorehistory-Abfrage wird nicht durch @HistoryDays begrenzt. msdb-Historie kann bereinigt oder unvollständig sein; ein scheinbares Gap kann deshalb auch aus nicht sichtbarer Historie resultieren. Sichtbare Metadatenkonsistenz beweist weder vorhandene/lesbare Medien noch eine erfolgreiche Wiederherstellung. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MitRestoreEvidence` | `bit` | Default: `1` | Der SQL-bit-Parameter ist standardmäßig 1; nach Bindung aktiviert nur 1 die zusätzliche Auswertung von msdb.dbo.restorehistory und die Bewertung fehlender Restoreevidenz. Gebundene 0 und NULL deaktivieren beides; NULL wird nicht als ungültiger Parameter geprüft. Die Restorehistory-Abfrage ist für ausgewählte Datenbanken nicht nach @HistoryDays zeitlich eingeschränkt. Ein msdb-Restoreeintrag ist kein Nachweis eines erfolgreichen Test-Restores. Die Abfrage gruppiert nach destination_database_name und nimmt MAX(restore_date); sie belegt deshalb nur den letzten lokalen msdb-Eintrag für das Ziel, keine Zuordnung zu einem konkreten Backupset, Medienverfügbarkeit, Entschlüsselbarkeit oder erfolgreiche Wiederherstellung. SQL Server bindet das Argument vor Eintritt an bit: 0 ergibt 0, ein konvertierbarer numerischer Nichtnullwert ergibt 1, NULL bleibt NULL; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MaxZeilen` | `int` | Default: `1000` | Der int-Parameter akzeptiert 0 bis 2147483647; negative Werte sind ungültig. NULL und 0 werden vor der Ausgabe in das unbegrenzte bigint-Limit 9223372036854775807 überführt. Ein positives Limit entfernt nach vollständigem msdb-Scan und Kettenaggregation zusätzliche Summaryzeilen nach DatabaseId sowie Backupzeilen nach Abschlusszeit und Backupset-ID absteigend. Das Limit kürzt weder den Scan noch die vollständig berechneten Summaryzähler oder die Warning-Tabelle und setzt kein Truncation- oder Partial-Flag. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultSetArt` | `varchar(16)` | Default: `'CONSOLE'` | Nach COALESCE mit leerem Text, Trimmen und Großschreibung sind RAW, CONSOLE, TABLE und NONE zulässig. CONSOLE und TABLE werden für die Modusprüfung zunächst auf NONE normalisiert, danach aber über getrennte Adapter ausgeführt. RAW liefert vier Resultsets: Status-/Kontextzeile, Summary, Backups und Warnings. CONSOLE liefert nur Summary über InternalEmitConsoleResult; eine leere Summary ergibt dort eine erklärende Zeile, ohne separaten Status- oder Warning-Datensatz. TABLE schreibt nur das Resultset summary in die benannte lokale Zieltabelle und wirft bei einem Schreibfehler. NONE erzeugt keine fachlichen Resultsets. NULL, leer und andere Werte sind ungültig. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultTablesJson` | `nvarchar(max)` | Default: `NULL` | Ein nichtleerer Wert ist ausschließlich bei @ResultSetArt=TABLE zulässig; andernfalls wirft der Code vor Hilfe Fehler 51011. TABLE erwartet vor Hilfe ein gültiges JSON-Objekt mit genau dem case-sensitiven Schlüssel summary und einem JSON-String als Zieltabellennamen. Zulässig ist nur eine vorhandene lokale #Temp-Tabelle, nicht ##, nicht #Monitor*, mit höchstens 116 Zeichen. Das Ziel muss leer sein und genau eine Dummy-Seed-Spalte besitzen; der Schreibhelfer passt eine leere Zieltabelle an die native Struktur von summary an. Bei TABLE fehlt die Zuordnung, ist das JSON ungültig oder ist das Ziel nicht verfügbar, nicht leer oder anders strukturiert, schlägt der Preflight fehl. Bei Nicht-TABLE-Modi sind NULL, leerer oder nur aus Leerzeichen bestehender Wert zulässig. Resultset-Schlüssel und JSON-Stringwerte dürfen nicht doppelt vorkommen; zusätzliche Schlüssel, globale ##-Ziele und reservierte #Monitor-Präfixe sind unzulässig. Der Preflight prüft das Ziel unter anderem durch temporäres Hinzufügen und Entfernen einer Marker-Spalte. Ein ungültiges Mapping kann vor Hilfe Fehler 51011 auslösen; der spätere TABLE-Writer kann nach der Status-OUTPUT-Zuweisung Fehler 51010 werfen. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@JsonErzeugen` | `bit` | Default: `0` | Der SQL-bit-Parameter wird vor der Ausführung konvertiert; nur der gebundene Wert 1 erzeugt JSON, während 0 und NULL überspringen. Das Dokument hat ein meta-Objekt und die Arrays summary, backups und warnings. summary und backups spiegeln das nach @MaxZeilen begrenzte Material; warnings bleiben ungekürzt. meta enthält resultName, schemaVersion, generatedAtUtc, statusCode, isPartial und historyDays und lässt NULL-Eigenschaften weg. Die drei Arrays verwenden INCLUDE_NULL_VALUES; Fehlernummer und Fehlermeldung werden separat über die Fehler-OUTPUTs beziehungsweise RAW bereitgestellt. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Json` | `nvarchar(max) OUTPUT` | Default: `NULL` | nvarchar(max) OUTPUT wird beim Eintritt auf NULL gesetzt. Nur wenn @JsonErzeugen=1 und der Hilfezweig nicht vorher zurückkehrt, wird ein JSON-Dokument mit meta-Objekt sowie summary-, backups- und warnings-Arrays zugewiesen. Bei fehlender JSON-Anforderung bleibt der OUTPUT-Wert NULL. Binden Sie eine Variable des deklarierten Typs mit @Json=@Variable OUTPUT. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@PrintMeldungen` | `bit` | Default: `1` | Der SQL-bit-Parameter wird in der Procedure weder gelesen noch zur Ausgabe verwendet. Die Signatur setzt ihn auf 1; auch ein gebundenes NULL oder 0 ändert den Ausgabepfad nicht. SQL Server bindet das Argument vor Eintritt an bit: 0 ergibt 0, ein konvertierbarer numerischer Nichtnullwert ergibt 1, NULL bleibt NULL; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Hilfe` | `bit` | Default: `0` | Nur der gebundene bit-Wert 1 gibt die Hilfe mit PRINT aus und kehrt zurück. Numerische Nichtnullwerte werden vor Eintritt zu bit 1 konvertiert; 0 aktiviert die Hilfe nicht. NULL bleibt NULL und aktiviert IF @Hilfe=1 ebenfalls nicht. Modusnormalisierung sowie TABLE-/ResultTablesJson-Vorprüfung liegen vor diesem Rücksprung. Der TABLE-Preflight kann die lokale Zieltabelle bereits durch temporäres Hinzufügen und Entfernen einer Marker-Spalte prüfen. Die Status-, Partial- und Fehler-OUTPUTs bleiben im Hilfezweig auf ihren Eingangs-/Bindungswerten; @Json wurde zuvor bereits auf NULL gesetzt. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | Default: `NULL` | Empfängt am gemeinsamen Zuweisungspunkt vor JSON und Resultsets genau einen dieser acht Statuswerte: AVAILABLE, wenn ohne Kandidatenwarnungen kein abweichender Summarybefund vorliegt; CHAIN_METADATA_CONSISTENT und TEMPDB_NOT_APPLICABLE sind damit vereinbar. INVALID_PARAMETER bezeichnet eine ungültige Modus-, Historien-, Zeilen- oder Kandidatenauswahl. INTERNAL_ERROR bezeichnet einen Fehler bei der defensiven Kandidatentabellenprobe, ohne die Ursache ausschließlich auf ein falsches Schema festzulegen. UNAVAILABLE_FEATURE bezeichnet einen nicht unterstützten Regex-Engine-/Compatibility-Pfad. AVAILABLE_LIMITED hat bei vorhandenen Kandidatenwarnungen Vorrang. AVAILABLE_WITH_FINDING bezeichnet ohne Kandidatenwarnungen mindestens einen Summarycode außerhalb von CHAIN_METADATA_CONSISTENT und TEMPDB_NOT_APPLICABLE. DENIED_PERMISSION ist die Codeklassifikation des Analyse-CATCH für Fehler 229, 371 oder 916, keine unabhängige Ursachendiagnose. ERROR_HANDLED bezeichnet andere im Analyse-CATCH erfasste SQL-Fehler. @AnalysisClass=NULL überspringt die Analyseklassengates. Bei Hilfe oder frühem Preflight-THROW bleibt der gebundene Eingangswert unverändert. Vom TABLE-Writer behandelte Schreibfehler können nach der OUTPUT-Zuweisung Fehler 51010 auslösen und ändern den bereits zugewiesenen Status nicht. Binden Sie eine Variable des deklarierten Typs mit @StatusCodeOut=@Variable OUTPUT. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@IsPartialOut` | `bit OUTPUT` | Default: `NULL` | bit OUTPUT wird im regulären Ablauf gemeinsam mit Status vor JSON und Resultsets zugewiesen; in HELP und bei einem früheren Preflight-THROW bleibt der gebundene OUTPUT-Eingangswert bestehen. Der interne Analyseflag wird mit 0 initialisiert; der Signatur-Default des OUTPUT-Arguments ist NULL. Die Hauptparameterprüfung für @HistoryDays, @MaxZeilen und @ResultSetArt setzt bei Fehlern 1; Kandidatenwarnungen und behandelte Analysefehler setzen ebenfalls 1. Ein Fehlerstatus des Kandidatenhelfers (INVALID_PARAMETER, UNAVAILABLE_FEATURE oder INTERNAL_ERROR) kann dagegen mit Partial=0 ankommen. Ein positives @MaxZeilen-Limit oder Ausgabeabschneiden setzt es nicht auf 1. Binden Sie eine Variable des deklarierten Typs mit @IsPartialOut=@Variable OUTPUT. SQL Server bindet das Argument vor Eintritt an bit: 0 ergibt 0, ein konvertierbarer numerischer Nichtnullwert ergibt 1, NULL bleibt NULL; Bindungsfehler treten vor dem Prozedurcode auf. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@ErrorNumberOut` | `int OUTPUT` | Default: `NULL` | int OUTPUT wird am gemeinsamen regulären Zuweisungspunkt befüllt; in HELP und bei einem früheren Preflight-THROW bleibt der gebundene OUTPUT-Eingangswert bestehen. Der Analyse-CATCH setzt ihn auf die abgefangene SQL-Fehlernummer; ohne solchen CATCH bleibt er NULL. Binden Sie eine Variable des deklarierten Typs mit @ErrorNumberOut=@Variable OUTPUT. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | Default: `NULL` | nvarchar(2048) OUTPUT wird am gemeinsamen regulären Zuweisungspunkt befüllt; in HELP und bei einem früheren Preflight-THROW bleibt der gebundene OUTPUT-Eingangswert bestehen. Er enthält eine Validierungs-, Kandidaten- oder Analysefehlermeldung und bleibt bei erfolgreicher Auswertung NULL. Binden Sie eine Variable des deklarierten Typs mit @ErrorMessageOut=@Variable OUTPUT. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |

## Aufrufbeispiele zu den Parameterverträgen

Die Beispiele verwenden synthetische Namen. Das TABLE-Ziel darf vor dem Beispiel noch nicht existieren; es wird leer mit einer Seed-Spalte angelegt und nach dem Aufruf oder einem Aufruffehler entfernt. Eine positive Ausgabegrenze ersetzt keinen Filter auf vorherige msdb-Zugriffe.

```sql
EXEC [monitor].[USP_BackupChainAnalysis] @Hilfe=1;

EXEC [monitor].[USP_BackupChainAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HistoryDays=35, @MitRestoreEvidence=0, @MaxZeilen=100, @ResultSetArt='RAW';

DECLARE @BackupChainJson nvarchar(max), @BackupChainStatus varchar(40), @BackupChainPartial bit, @BackupChainError int, @BackupChainMessage nvarchar(2048); EXEC [monitor].[USP_BackupChainAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HistoryDays=35, @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@BackupChainJson OUTPUT, @StatusCodeOut=@BackupChainStatus OUTPUT, @IsPartialOut=@BackupChainPartial OUTPUT, @ErrorNumberOut=@BackupChainError OUTPUT, @ErrorMessageOut=@BackupChainMessage OUTPUT; SELECT @BackupChainStatus AS [StatusCode], @BackupChainPartial AS [IsPartial], @BackupChainError AS [ErrorNumber], @BackupChainMessage AS [ErrorMessage], @BackupChainJson AS [Json];

CREATE TABLE #BackupChainAnalysis_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_BackupChainAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HistoryDays=35, @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"summary":"#BackupChainAnalysis_HelpExample"}'; SELECT * FROM #BackupChainAnalysis_HelpExample; DROP TABLE #BackupChainAnalysis_HelpExample; END TRY BEGIN CATCH DROP TABLE #BackupChainAnalysis_HelpExample; THROW; END CATCH;

EXEC [monitor].[USP_BackupChainAnalysis] @DatabaseNamePattern=N'like:ExampleDatabase%', @HistoryDays=35, @MaxZeilen=100, @ResultSetArt='RAW';

EXEC [monitor].[USP_BackupChainAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HistoryDays=7, @MitRestoreEvidence=1, @MaxZeilen=100, @ResultSetArt='RAW';
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `summary`. RAW liefert zuerst eine Status- und Kontextzeile und danach Summary, Backups und Warnings. JSON enthält ein Metaobjekt sowie die Arrays summary, backups und warnings. CONSOLE liefert ausschließlich Summary über den Console-Adapter; bei leerer Summary erscheint eine erklärende Zeile, aber kein separater Status-, Scope- oder Warning-Datensatz. TABLE schreibt ausschließlich summary in das validierte lokale Ziel. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

Die 16 lokalen Textspalten verwenden explizit die Frameworkcollation
`SQL_Latin1_General_CP1_CS_AS`; dies gilt auch für die fünf Textspalten des
Summary-TABLE-Exports. Eine abweichende Server- oder `tempdb`-Collation
ändert dessen Textvertrag nicht.

`@MaxZeilen` wird nach vollständiger Kettenberechnung und Statusermittlung
auf die gemeinsame Summary- und Backupauswahl angewendet. TABLE, RAW und
JSON verwenden denselben Summaryausschnitt nach `DatabaseId`; die
Backupausgabe wird nach Abschlusszeit und Backupsetkennung absteigend
begrenzt. Warnungen bleiben ungekürzt. Die Begrenzung reduziert weder den
vorherigen msdb-Zugriff noch die vollständigen Summaryzähler.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile ein Backup, eine Kettenbeziehung, ein LSN-Segment, Restoreevidenz oder ein Finding.

## So lesen

Berücksichtigen Sie Full-Basis, Differential Base, Log-LSN-Folge und Gaps in zeitlicher Reihenfolge.

## Warum kann das problematisch sein?

Eine unterbrochene LSN-Kette kann Point-in-Time-Restore verhindern. Vorhandene Dateien garantieren keine wiederherstellbare Folge.

## Wann ist es kein Problem?

Copy-only Full verändert die Differential Base nicht und darf nicht als Kettenbruch bewertet werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Full und viele Logbackups vorhanden, aber ein LSN-Segment fehlt: Restore bis zum Ende nicht möglich. Testen Sie Medien und echten Restore.

**Ähnlich aussehender Gegenfall:** Copy-only Full verändert die Differential Base nicht und darf nicht als Kettenbruch bewertet werden. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Ein leerer Historypfad kann Retention/Cleanup, deaktivierte Komponente oder falschen Scope bedeuten; er beweist keine erfolgreiche Ausführung.

Das Partialflag ist kein eigenständiger Vollständigkeitsnachweis. Die Hauptparameterprüfung, Kandidatenwarnungen und behandelte Analysefehler setzen `IsPartial=1`; Fehlerstatus des Kandidatenhelfers können dagegen mit `IsPartial=0` zurückkehren. Status, Fehlerangaben und Kandidatenwarnungen sind deshalb gemeinsam zu lesen. Positive Ausgabegrenzen können Summary- und Backupzeilen ausblenden, setzen aber weder Partial- noch Kürzungsflag; die Summaryzähler werden vorher auf der vollständigen Erhebung berechnet.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Eine `ExampleDatabase`, 35 Tage Backuphistorie, Restoreevidenz aktiv und endliches Limit; der letzte nicht-copy-only Full vor dem Fenster wird als Kettenanker zusätzlich gelesen. |
| Teuerster Pfad | Alle sichtbaren Datenbanken, `@HistoryDays = 3650`, Restoreevidenz und unbegrenzte Ausgabe auf einer msdb mit sehr langer Backup-/Restore-Retention. |
| Haupttreiber | Zahl ausgewählter Datenbanken sowie Full-/Diff-/Log-Backupsets im Lookback. Die optionale Restorehistory-Auswertung ist auf die ausgewählten Datenbanken begrenzt, enthält aber kein zusätzliches @HistoryDays-Zeitprädikat. Häufige Logbackups vergrößern LSN-Sortierung und Kettenkorrelation besonders stark. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_BackupChainAnalysis ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU und I/O auf Katalogen beziehungsweise msdb-Historie; TempDB für Korrelation und Transfer bei langen Meldungen. |
| Begrenzungswirkung | Datenbankscope und `@HistoryDays` begrenzen Backupquellen, wobei der letzte Full vor dem Fenster bewusst zusätzlich gesucht wird. `@MitRestoreEvidence = 0` lässt Restorehistory aus. `@MaxZeilen` wirkt erst je fertigem Summary-/Backupresultset. |
| Locking und Nebenwirkungen | Read-only; kurze Schema-Stability-Zugriffe auf msdb/Systemkataloge. Jobs, Backups oder Wartung laufen parallel weiter, daher ist das Ergebnis nicht atomar. |
| Schutzmechanismus | Der Datenbankkandidatenpfad verwendet `@AnalysisClass = NULL`; `@HighImpactConfirmed` aktiviert hier keinen Deep-Pfad. Schutz bieten explizite Datenbank, Historyfenster und optional ausgelassene Restoreevidenz. |
| Sicherer Einsatz | Eine `ExampleDatabase`, 35 Tage und endliches Limit; Restoreevidenz nur auslassen, wenn die Entscheidung sie nachweislich nicht benötigt. Lange Retentionen datenbankweise prüfen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „persistierte, retentionbegrenzte Historie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Ist aus sichtbaren Backupsets eine technisch konsistente Restorekette mit passender Full-/Diff-/Log-LSN-Folge rekonstruierbar?

### Technischer Hintergrund

Fullbackups definieren Database Backup LSN/Checkpoint; Differentials basieren auf Differential Base; Logbackups decken First/Last LSN und Recovery Forks ab. CopyOnly beeinflusst Differential Base beziehungsweise Logkette unterschiedlich. Restorefolge muss LSN- und Forkkonsistenz wahren.

### Datenkette

`msdb.dbo.backupset`, `msdb.dbo.restorehistory`.

### Source Select

Die Kette beginnt bei `backupset`. Die folgende Abfrage ist ein illustrativer quellenübergreifender Überblick nach Datenbank und bildet die Restoreevidenz-Abfrage der Procedure nicht ab. Die Procedure berechnet den letzten lokalen Restorezeitpunkt getrennt als MAX(restore_date) je ausgewähltem destination_database_name ohne @HistoryDays-Zeitprädikat. Das belegt weder die Wiederherstellung eines bestimmten Backupsets noch einen erfolgreichen Test-Restore.

```sql
SELECT
      [bs].[database_name]
    , [bs].[backup_set_id]
    , [bs].[type]
    , [bs].[backup_start_date]
    , [bs].[backup_finish_date]
    , [rh].[restore_date]
FROM [msdb].[dbo].[backupset] AS [bs] WITH (NOLOCK)
LEFT JOIN [msdb].[dbo].[restorehistory] AS [rh] WITH (NOLOCK)
  ON [rh].[destination_database_name] COLLATE SQL_Latin1_General_CP1_CS_AS
   = [bs].[database_name] COLLATE SQL_Latin1_General_CP1_CS_AS
WHERE [bs].[database_name] = N'ExampleDatabase'
  AND [bs].[backup_finish_date] >= DATEADD(DAY, -30, GETDATE());
```

**Wichtig für die Eigenlast:** Datenbank und Zeitfenster gehören in die erste `backupset`-Abfrage. Ohne diese Einschränkungen wachsen Sortierung und Kettenbildung mit der gesamten `msdb`-Historie.

### Zeit- und Scope-Modell

Die Auswertung verwendet `msdb`-Metadaten aus dem gewählten Fenster; ein zu kurzes Fenster kann die notwendige Basis ausblenden.

### Bewertung und Gegenprobe

Prüfen Sie Recovery Fork, Full-Basis, Differential Base, Log First und Last LSN, Gap- und Overlapindikatoren, CopyOnly und Backupzeiten. Bewerten Sie die Kette für den gewünschten Restorezeitpunkt.

### Typische Fehlinterpretation

Metadatenkonsistenz beweist nicht, dass Medien vorhanden, unbeschädigt, entschlüsselbar oder zugreifbar sind. Ein vermeintliches Gap kann durch außerhalb des Fensters liegende Sets entstehen.

### Folgeanalyse

Führen Sie für die weitere Analyse einen echten Restoretest durch und verwenden Sie `USP_BackupRecovery` sowie die Encryption- und Certificate-Governance.

## Primärquellen

- [Backup history and header information](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/backup-history-and-header-information-sql-server?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: SQL Server Backup – betriebliche Backup-Praxis](https://ola.hallengren.com/sql-server-backup.html)

[Technische Detailbeschreibung](../07_Infrastructure.md#9-monitorusp_backupchainanalysis)
