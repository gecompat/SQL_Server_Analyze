# [monitor].[USP_BackupRecovery]

**Bereich:** Infrastruktur<br>
**Zweck:** Bewertet Backupalter, Recovery Model, Logbackupbedarf, Kompressionsevidenz und Restorehistorie.<br>
**Beobachtungsart:** persistierte, retentionbegrenzte Historie<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Existieren im sichtbaren Fenster die erwarteten Full-, Differential- und Logbackups für das Recoverymodell?** Sie unterstützt die Entscheidung, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_BackupRecovery]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameterverträge

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | Default: `NULL` | NULL sowie nach Trim leere Eingaben wählen alle für den Aufrufer sichtbaren, online befindlichen und zugänglichen Datenbanken, standardmäßig ohne Systemdatenbanken. Andernfalls wird eine Pipe-Liste einteiliger SQL-Datenbanknamen verarbeitet; äußere Leerzeichen je Element werden entfernt. Bracket-quotierte Elemente erlauben ein wörtliches Pipe-Zeichen und maskieren eine schließende Klammer als `]]`. Jedes Element muss ein gültiger höchstens 128 Zeichen langer SQL-Name sein; leere, doppelte, fehlerhaft geklammerte, mehrteilige oder ungültige Namen führen zu `INVALID_PARAMETER`. Eine explizite Liste kann nicht zusammen mit einem Pattern verwendet werden. Die Auswahl wird nicht vorab begrenzt; Namen, die nicht im zugänglichen Kandidatenscope liegen, liefern keine Kandidaten. Gültige explizite Namen außerhalb des zugänglichen Kandidatenscopes erzeugen Warnzeilen mit DATABASE_UNAVAILABLE beziehungsweise SYSTEM_DATABASE_EXCLUDED und führen zu AVAILABLE_LIMITED mit IsPartial=1; sie werden nicht stillschweigend ignoriert. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@SystemdatenbankenEinbeziehen` | `bit` | Default: `0` | 0 schließt die vier Systemdatenbanken anhand ihrer database_id aus; 1 nimmt zugängliche, online befindliche Systemdatenbanken in denselben Kandidatenpfad auf. NULL ist ungültig und führt über die Kandidatenvalidierung zu `INVALID_PARAMETER`. Diese Procedure übergibt `@AnalysisClass = NULL`; deshalb aktiviert dieser Schalter kein High-Impact-Analyse-Gate. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | Default: `NULL` | NULL bedeutet kein Pattern; sonst werden äußere Leerzeichen entfernt und der Wert als Pattern ausgewertet. Zulässige Präfixe sind `LIKE:`, `REGEX:` und `REGEXI:` (Präfixerkennung ohne Beachtung der Groß-/Kleinschreibung); ohne Präfix gilt LIKE. `REGEX:` verlangt case-sensitive Regex, `REGEXI:` case-insensitive Regex; `LIKE:` entfernt nur das Präfix und verwendet SQL-LIKE-Musterzeichen. Der Inhalt nach dem Präfix darf nicht leer sein. Die maximale Eingabelänge beträgt 4000 UTF-16-Codeeinheiten. Ein Pattern ist mit einer exakten Namensliste unzulässig. Jedes nicht-NULL Pattern, das nach Trim beziehungsweise Präfixentfernung leer ist, sowie die Kombination mit einer exakten Liste setzen den Status `INVALID_PARAMETER`. Für `REGEX` und `REGEXI` benötigt die Installationsinstanz SQL Server 2025 und Compatibility Level 170; andernfalls meldet der Kandidatenhelfer `UNAVAILABLE_FEATURE`. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@HighImpactConfirmed` | `bit` | Default: `0` | 0 und 1 sind Bestätigungswerte, NULL ist ungültig und wird als `INVALID_PARAMETER` behandelt. Für diese Procedure bleibt die Bestätigung ohne Freischaltwirkung: Der Kandidatenhelfer wird mit `@AnalysisClass = NULL` aufgerufen, sodass kein Analysepfad geprüft oder aktiviert wird. Der Wert ist keine Genehmigung für Backup-, Restore- oder sonstige Änderungen. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@FullWarnHours` | `int` | Default: `48` | Zulässige nicht-NULL Werte sind ganze Zahlen von 1 bis 2147483647. Ganzzahlige Stundenschwelle für `FULL_TOO_OLD`; Werte kleiner als 1 sind ungültig. NULL passiert die `< 1`-Prüfung, lässt den Altersvergleich aber wegen SQL-NULL-Semantik nicht zutreffen und unterdrückt damit diese Schwellenklassifikation. Die Schwelle begrenzt keine gelesene msdb-Historie und ist kein RPO. Der Vergleich verwendet DATEDIFF(HOUR, ..., GETDATE()) > @FullWarnHours; DATEDIFF zählt Stundengrenzen. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@DiffWarnHours` | `int` | Default: `24` | Zulässige nicht-NULL Werte sind ganze Zahlen von 1 bis 2147483647. Ganzzahlige Stundenschwelle für den informativen Status `DIFF_OLD_INFORMATIONAL`; Werte kleiner als 1 sind ungültig. NULL passiert die `< 1`-Prüfung, lässt den Altersvergleich aber wegen SQL-NULL-Semantik nicht zutreffen. Die Schwelle begrenzt keine gelesene Historie und ist kein RPO. Der Vergleich verwendet DATEDIFF(HOUR, ..., GETDATE()) > @DiffWarnHours; DATEDIFF zählt Stundengrenzen. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@LogWarnMinutes` | `int` | Default: `30` | Zulässige nicht-NULL Werte sind ganze Zahlen von 1 bis 2147483647. Ganzzahlige Minutenschwelle für `LOG_TOO_OLD`; Werte kleiner als 1 sind ungültig. NULL passiert die `< 1`-Prüfung, lässt den Altersvergleich aber wegen SQL-NULL-Semantik nicht zutreffen. Der Vergleich verwendet `DATEDIFF(MINUTE, ..., GETDATE())`; die Schwelle begrenzt keine msdb-Historie und ist kein RPO. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MitRestoreHistory` | `bit` | Default: `1` | 0 lässt die Abfrage der msdb-Restorehistorie aus; 1 liest die Restorehistorie für ausgewählte Datenbanken. NULL verhält sich in `IF @MitRestoreHistory = 1` wie nicht aktiviert. Dieser Schalter betrifft nur Restoreausgabe und entfernt weder Backup- noch Freshnessauswertung. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MaxZeilen` | `int` | Default: `5000` | Eine positive Grenze ist eine ganze Zeilenzahl von 1 bis 2147483647. Negative Werte führen zu `INVALID_PARAMETER`; NULL oder 0 werden in eine unbegrenzte Obergrenze umgewandelt. Positive Werte begrenzen Freshness, Backup-, Kompressions-Backupset- und Restoreausgabe jeweils separat; die kleinen serverweiten Konfigurations- und Capability-Einträge bleiben sichtbar. Die Freshnessgrenze wird nach der Bewertung angewandt. Das Limit beschränkt nicht die zuvor geprüfte Backupsetmenge für Aggregation und Freshness und ist kein gemeinsames Gesamtlimit. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultSetArt` | `varchar(16)` | Default: `'CONSOLE'` | Nach `LTRIM`/`RTRIM` und Umwandlung in Großbuchstaben sind ausschließlich `CONSOLE`, `RAW`, `TABLE` und `NONE` zulässig; NULL und andere Texte führen zu `INVALID_PARAMETER`. `CONSOLE` liefert ausschließlich eine formatierte Freshnessausgabe ohne zusätzliches Modulstatus-Resultset; bei leerer Menge wird eine verständliche Hinweiszeile ausgegeben, `RAW` liefert die technischen Resultsets, `TABLE` schreibt ausschließlich die benannten lokalen Ziele, und `NONE` unterdrückt Resultsets. Für `CONSOLE` und `TABLE` wird der interne Resultsetpfad auf NONE gestellt, bevor die jeweilige Ausgabeadapterlogik läuft. Die Auswahl ist unabhängig von JSON-OUTPUT. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultTablesJson` | `nvarchar(max)` | Default: `NULL` | Nur bei `TABLE` darf dieser Wert nicht leer sein: Er muss ein JSON-Objekt mit Stringwerten für die case-sensitiven Schlüssel `freshness` und/oder `compression` enthalten; jeder Wert bezeichnet eine vorhandene lokale `#`-Temp-Tabelle. Ziele müssen leer sein und genau eine Seed-Spalte besitzen; doppelte/unbekannte Schlüssel, doppelte Ziele, globale oder reservierte `#Monitor`-Ziele, falsche Namen/Schemas oder ein ungültiges Mapping lösen den TABLE-Preflightfehler 51011 aus. Der Preflight prüft und verändert Ziele vorübergehend durch Hinzufügen und Entfernen einer Marker-Spalte. Bei allen anderen Ausgabearten ist NULL oder ein Leer-/Whitespacewert zulässig; ein nichtleeres Mapping löst 51011 aus. Das Mapping ändert keine fachlichen Backupdaten. Die Zielnamen dürfen höchstens 116 Zeichen lang sein. Zielnamen-Duplikate werden ohne Beachtung der Groß-/Kleinschreibung geprüft; Resultset-Schlüssel müssen dagegen exakt einschließlich Groß-/Kleinschreibung stimmen. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@JsonErzeugen` | `bit` | Default: `0` | 1 erzeugt das JSON-Dokument und weist es `@Json` zu; 0 oder NULL lässt es bei der anfänglichen Rücksetzung auf NULL. Das Root-Objekt enthält `meta` (u. a. resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, requestedMaxRows, errorNumber und errorMessage), `freshness`, `backups`, `compression`, `restores` und `warnings`. JSON-Erzeugung ist unabhängig von der gewählten Resultsetart. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Json` | `nvarchar(max) OUTPUT` | Default: `NULL` | OUTPUT-Empfangsparameter für das erzeugte JSON-Dokument. Die Procedure setzt ihn zu Beginn immer auf NULL; ein JSON-Text wird nur bei `@JsonErzeugen = 1` zugewiesen. Inhalt und Schlüssel stehen im Vertrag von `@JsonErzeugen`; bei HELP und bei deaktivierter JSON-Erzeugung bleibt der OUTPUT-Wert NULL. Binden Sie eine nvarchar(max)-Variable mit @Json=@Variable OUTPUT. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@PrintMeldungen` | `bit` | Default: `1` | 1 erlaubt die vorgesehenen Informations-/Warnmeldungen über `RAISERROR` mit Severity 10; 0 unterdrückt diese Meldungen. NULL wird durch die Prüfung `IF @PrintMeldungen = 1` ebenfalls nicht aktiviert. Der Schalter unterdrückt weder Resultsets noch JSON und ändert keinen Status. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Hilfe` | `bit` | Default: `0` | 1 gibt den Hilfetext mit `PRINT` aus und kehrt vor Kandidatensuche, Backup-/Restoreabfragen und Ausgabeverarbeitung zurück; 0 führt den normalen Ablauf aus. NULL wird nicht als aktiviert behandelt. Die TABLE-Zielvorprüfung liegt vor dieser Verzweigung: Bei `TABLE` kann deshalb bereits vorher Mapping validiert und eine Marker-Spalte temporär hinzugefügt/entfernt werden. HELP ist kein Backup-, Restore- oder Agent-Aufruf. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default. |

## Aufrufbeispiele zu den Parameterverträgen

Die Beispiele verwenden synthetische Namen. Die TABLE-Ziele dürfen vor dem Beispiel noch nicht existieren; sie werden leer mit einer Seed-Spalte angelegt und nach dem Aufruf oder einem Aufruffehler entfernt. Eine positive Zeilengrenze ist kein gemeinsames Gesamtlimit und begrenzt keinen vorherigen Historyscan.

```sql
EXEC [monitor].[USP_BackupRecovery] @Hilfe=1;

EXEC [monitor].[USP_BackupRecovery] @DatabaseNames=N'[ExampleDatabase]', @MitRestoreHistory=0, @MaxZeilen=100, @ResultSetArt='RAW';

DECLARE @BackupRecoveryJson nvarchar(max); EXEC [monitor].[USP_BackupRecovery] @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@BackupRecoveryJson OUTPUT; SELECT @BackupRecoveryJson AS [Json];

CREATE TABLE #BackupRecovery_Freshness_HelpExample ([Seed] int NULL); CREATE TABLE #BackupRecovery_Compression_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_BackupRecovery] @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"freshness":"#BackupRecovery_Freshness_HelpExample","compression":"#BackupRecovery_Compression_HelpExample"}'; SELECT * FROM #BackupRecovery_Freshness_HelpExample; SELECT * FROM #BackupRecovery_Compression_HelpExample; DROP TABLE #BackupRecovery_Compression_HelpExample; DROP TABLE #BackupRecovery_Freshness_HelpExample; END TRY BEGIN CATCH DROP TABLE #BackupRecovery_Compression_HelpExample; DROP TABLE #BackupRecovery_Freshness_HelpExample; THROW; END CATCH;

EXEC [monitor].[USP_BackupRecovery] @DatabaseNamePattern=N'like:ExampleDatabase%', @MaxZeilen=100, @ResultSetArt='RAW';

EXEC [monitor].[USP_BackupRecovery] @DatabaseNames=N'[ExampleDatabase]', @FullWarnHours=48, @DiffWarnHours=24, @LogWarnMinutes=30, @MitRestoreHistory=1, @MaxZeilen=100, @ResultSetArt='RAW';
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `freshness` und `compression`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Freshness-Triage; RAW, TABLE und JSON liefern die technische Kompressionsevidenz. Die `compression`-Menge trennt Serverkonfiguration, Versions-Capability und die sichtbare Algorithmusmetadaten je Backupset. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Eine Hauptzeile beschreibt den Backup-/Recoveryzustand einer Datenbank; Historienresultsets enthalten einzelne Backup- oder Restoreereignisse. Eine Kompressionszeile beschreibt entweder eine serverweite Konfiguration oder Capability oder ein sichtbares Backupset. Sie beweist weder einen Restore noch CPU- oder Durchsatzwirkung.

## So lesen

Berücksichtigen Sie Recovery Model, Alter von Full/Diff/Log, letzte erfolgreiche Sicherung, Copy-only und Restorehistorie gemeinsam. Prüfen Sie Kompressionskonfiguration, Capability und Historienalgorithmus getrennt: Die aktuelle Voreinstellung ist keine Aussage über ein bereits geschriebenes Backup und ein sichtbarer Algorithmus keine Empfehlung für dessen Einsatz.

## Warum kann das problematisch sein?

Alte oder fehlende Logbackups vergrößern möglichen Datenverlust und können bei FULL/BULK_LOGGED die Log-Wiederverwendung verhindern.

## Wann ist es kein Problem?

In SIMPLE Recovery sind Logbackups nicht vorgesehen. Eine fehlende Differential-Sicherung kann durch die Backupstrategie abgedeckt sein.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** FULL Recovery, letztes Logbackup vor sechs Stunden, RPO 30 Minuten: kritisch. SIMPLE plus kein Logbackup: erwartbar. Prüfen Sie Backupkette und echten Restore-Test.

**Ähnlich aussehender Gegenfall:** In SIMPLE Recovery sind Logbackups nicht vorgesehen. Eine fehlende Differential-Sicherung kann durch die Backupstrategie abgedeckt sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Ein leerer Historypfad kann Retention/Cleanup, deaktivierte Komponente oder falschen Scope bedeuten; er beweist keine erfolgreiche Ausführung.

Für `USP_BackupRecovery` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Eine `ExampleDatabase` mit Freshnessbewertung, bis zu 5000 Backup- und Kompressionsevidenzzeilen sowie optionaler Restorehistory. Die Warnschwellen sind Bewertungsgrenzen, kein History-Cutoff. |
| Teuerster Pfad | Alle sichtbaren Datenbanken, `@MaxZeilen = 0` und Restorehistory aktiv auf einer msdb mit sehr umfangreicher Backup-/Restorehistorie. |
| Haupttreiber | Zahl ausgewählter Datenbanken sowie Backupset-, Medien- und Restore-Historyzeilen im Lookback. Lange Aufbewahrung und häufige Logbackups vergrößern die msdb-Quellen deutlich stärker als die aktuelle Datenbankzahl allein. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_BackupRecovery ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU und I/O auf Katalogen beziehungsweise msdb-Historie; TempDB für Korrelation und Transfer bei langen Meldungen. |
| Begrenzungswirkung | Datenbankliste/-pattern begrenzen alle msdb-Joins. `@MitRestoreHistory = 0` lässt diesen Pfad aus. `@MaxZeilen` begrenzt Freshness, Backup-, Kompressionshistorien- und Restoreausgabe jeweils separat; die kleinen serverweiten Konfigurations- und Capabilityzeilen bleiben sichtbar. Die Freshnessaggregation über Backupset kann zuvor mehr Zeilen prüfen. Warnstunden/-minuten verändern nur Klassifikation. |
| Locking und Nebenwirkungen | Read-only; kurze Schema-Stability-Zugriffe auf msdb/Systemkataloge. Jobs, Backups oder Wartung laufen parallel weiter, daher ist das Ergebnis nicht atomar. |
| Schutzmechanismus | `@AnalysisClass = NULL`; `@HighImpactConfirmed` schaltet keinen Deep-Pfad frei. Die wirksamen Grenzen sind Datenbankscope, endliches Zeilenlimit und der Restorehistory-Schalter. |
| Sicherer Einsatz | Eine `ExampleDatabase`, endliches Limit und nur benötigte Restorehistory. Auf msdb mit langer Retention zunächst Freshness/Summary lesen, bevor Detailmengen erweitert werden. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „persistierte, retentionbegrenzte Historie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Existieren im sichtbaren Fenster die erwarteten Full-, Differential- und Logbackups für das Recoverymodell?

### Technischer Hintergrund

`msdb` speichert Backup Sets, Medien-/Dateiinformation, Type, LSNs, Start/Finish, Size/Compression/Checksum und Damageindikatoren. Recovery Model bestimmt, ob eine kontinuierliche Logkette erwartet wird.

### Datenkette

`sys.configurations`, `msdb.dbo.backupmediafamily`, `msdb.dbo.backupset`, `msdb.dbo.restorehistory`.

### Collation und Ausgabegrenzen

Die vier Textspalten des `freshness`-TABLE-Exports verwenden die Frameworkcollation
`SQL_Latin1_General_CP1_CS_AS`; eine abweichende Server- oder `tempdb`-Collation
bestimmt den Exportvertrag nicht. TABLE und JSON verwenden dieselbe
materialisierte Freshnessmenge. Ein positives `@MaxZeilen` begrenzt sie nach
vollständiger Bewertung: Datenbanken mit einem Status ungleich `OK` stehen vor
`OK`, danach folgt der Datenbankname. Backup- und Restorehistorie werden separat
nach ihren jüngsten Ereignissen begrenzt. Null und NULL sind unbegrenzt.
Das letzte normale Full und das letzte Copy-only Full bleiben getrennt.
`IsSnapshot` ist im vorhandenen Backupresultset NULL und kein gemessener Nullwert.

### Source Select

Backupsets werden über `media_set_id` mit den physischen Medien und optional über `backup_set_id` mit Restores verbunden:

```sql
SELECT
      [bs].[database_name]
    , [bs].[type]
    , [bs].[backup_finish_date]
    , [bmf].[physical_device_name]
    , [rh].[restore_date]
FROM [msdb].[dbo].[backupset] AS [bs] WITH (NOLOCK)
LEFT JOIN [msdb].[dbo].[backupmediafamily] AS [bmf] WITH (NOLOCK)
  ON [bmf].[media_set_id] = [bs].[media_set_id]
LEFT JOIN [msdb].[dbo].[restorehistory] AS [rh] WITH (NOLOCK)
  ON [rh].[backup_set_id] = [bs].[backup_set_id]
WHERE [bs].[database_name] = N'ExampleDatabase'
  AND [bs].[backup_finish_date] >= DATEADD(DAY, -30, GETDATE());
```

**Wichtig für die Eigenlast:** Der Zeitfilter des Gegenprüfungsbeispiels ist kein Parameter der Procedure. Die Procedure verarbeitet die vorhandene Historie der ausgewählten Datenbanken; Warnschwellen begrenzen diese Quellmenge nicht. Binden Sie Medien- und Restorezeilen in eigenen Gegenprüfungen nach dem gewählten Datenbank- und Zeitscope an; ein Backupset kann mehrere Media-Family-Zeilen besitzen.

### Zeit- und Scope-Modell

Die Auswertung berücksichtigt die Historie innerhalb der `msdb`-Retention; Datenträger und Dateien werden nicht geöffnet.

### Bewertung und Gegenprobe

Prüfen Sie die letzten Backupzeiten gegen RPO und Policy. Berücksichtigen Sie außerdem Recovery Model, CopyOnly, Checksum, Damage, Größe, Dauer und Logbackupkontinuität. SIMPLE benötigt keine Logbackups; FULL ohne regelmäßige Logbackups verhindert die Logtruncation.

### Typische Fehlinterpretation

Eine erfolgreiche Backup-Historyzeile beweist weder Dateiexistenz noch erfolgreichen Restore. `RESTORE VERIFYONLY` ist ebenfalls kein vollständiger Restoretest.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_BackupChainAnalysis`, Database Integrity und regelmäßiger echter Restoretest.

## Primärquellen

- [Backup und Restore](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/back-up-and-restore-of-sql-server-databases?view=sql-server-ver17)
- [Server configuration: backup compression algorithm](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/view-or-configure-the-backup-compression-algorithm-server-configuration-option?view=sql-server-ver17)
- [backupset (Transact-SQL)](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/backupset-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: SQL Server Backup – betriebliche Backup-Praxis](https://ola.hallengren.com/sql-server-backup.html)

[Technische Detailbeschreibung](../07_Infrastructure.md#5-monitorusp_backuprecovery)
