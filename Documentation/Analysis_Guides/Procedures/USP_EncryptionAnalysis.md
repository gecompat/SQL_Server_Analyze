# [monitor].[USP_EncryptionAnalysis]

**Bereich:** Versionsadaptive Spezialanalysen<br>
**Zweck:** Bewertet sichtbare TDE-, Schutzobjekt-, Backupverschlüsselungs-, Always-Encrypted- und Ledger-Metadaten ohne Schlüsselmaterial oder geschützte Inhalte.<br>
**Beobachtungsart:** Snapshot + retentionbegrenzte Metadatenhistorie<br>
**Kostenklasse:** MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche TDE-/Verschlüsselungszustände und Key-/Certificate-Abhängigkeiten sind sichtbar, ohne Schlüsselmaterial offenzulegen?** Sie unterstützt die Entscheidung, ob das Spezialfeature vorhanden und in einem auffälligen Zustand ist und welches featureeigene Diagnoseverfahren als Nächstes gebraucht wird.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Korrektheit der Featurekonfiguration, keine geschützten Inhalte und keine End-to-End-Funktionsprüfung außerhalb sichtbarer Metadaten. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_EncryptionAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurProblematisch = 1,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

### Individuelle Parameterverträge

Die folgenden Einträge erklären jeden Parameter mit Datentyp, Eingabeform und ausdrücklich bezeichnetem Default. OUTPUT-Werte werden nur mit einer passenden, mit OUTPUT gebundenen Variable empfangen.

| Parameter und Typ | Default | Eingabeform, Wirkung und Grenzen |
|---|---|---|
| `@DatabaseNames nvarchar(max)` | `NULL` | NULL, Leerstring oder ausschließlich äußere U+0020-Leerzeichen bedeuten keine exakte Einschränkung. Sonst eine bracket-aware Pipe-Liste: \| trennt außerhalb von [...], ]] maskiert innen eine schließende Klammer; äußere U+0020-Leerzeichen je Element werden entfernt. Jedes rohe Segment darf höchstens 4000 UTF-16-Codeeinheiten umfassen. TVF_ParseSqlNameList prüft PARSENAME-Teil 1 auf einen nicht-NULL Namen, Teil 2 auf NULL und LEN(Teil 1) auf höchstens 128; Teile 3 und 4 werden nicht gesondert geprüft. Dies ist keine vollständige SQL-Bezeichnergrammatik, Existenz- oder Berechtigungsprüfung. Leere/fehlerhaft geklammerte Elemente, Parserablehnung und case-sensitive doppelte gültige Namen ergeben INVALID_PARAMETER. Eine wirksame Liste und jeder nicht-NULL @DatabaseNamePattern-Wert sind zusammen ungültig. Nur sichtbare, ONLINE befindliche, zugreifbare Datenbanken ohne Snapshotmarkierung werden Kandidaten; Systemdatenbanken bleiben ohne Opt-in ausgeschlossen. Nicht verfügbare explizit angeforderte Namen können Auswahlwarnungen liefern. |
| `@SystemdatenbankenEinbeziehen bit` | `0` | 0 schließt master, tempdb, model, msdb aus; 1 lässt sie zu und beeinflusst SYSTEM_DATABASE_EXCLUDED-Warnings. Numerisch 0→0, jeder konvertierbare numerische Wert ungleich 0→1; NULL ergibt beim Candidate-Helper INVALID_PARAMETER; ausgelassen = 0. |
| `@DatabaseNamePattern nvarchar(4000)` | `NULL` | NULL/ausgelassen deaktiviert Pattern. Sonst äußere U+0020-Leerzeichen werden getrimmt; LIKE mit %, _, [...] oder Präfix like:, regex:, regexi: (Präfix case-insensitive). Nach Präfix kein erneutes Trim; leer/Präfix ohne Inhalt ungültig. LIKE verwendet SQL_Latin1_General_CP1_CS_AS; regex: Flag c, regexi: Flag i. Regex benötigt SQL Server 2025 und Compatibility Level >=170 der Installationsdatenbank, sonst UNAVAILABLE_FEATURE; Syntax wird nicht vorgeprüft. Mit wirksamer Namensliste ist jeder nicht-NULL Patternwert unzulässig; Filter nach Kandidatenermittlung. |
| `@HighImpactConfirmed bit` | `0` | 0 keine Bestätigung; 1 bestätigt nur ein tatsächlich angefordertes Klassen-Gruppengate. Numerisch 0→0, jeder Wert ungleich 0→1; NULL ergibt beim Helper INVALID_PARAMETER, ausgelassen = 0. Hier wird @AnalysisClass=NULL übergeben, daher kein Gate und kein teurerer Pfad. |
| `@NurProblematisch bit` | `0` | 0 exportiert INFO/MEDIUM/HIGH; 1 nur MEDIUM/HIGH. Filter nach Befundbildung und unabhängig von Status, Quellenstatus und Warnings. Numerisch 0→0, jeder numerische Wert ungleich 0→1; NULL ist nicht validiert und SQL-Filter lässt dann nur MEDIUM/HIGH durch. Ausgelassen = 0. |
| `@TdeTransitionWarnMinutes int` | `60` | Minuten, gültig 1–525600; Zustände 2,4,5,6 werden TDE_TRANSITION_LONG_RUNNING, wenn Scanänderung älter als UTC-Zeit minus Fenster ist. NULL wird nicht abgefangen und unterdrückt den Befund über NULL-Vergleich. Ausgelassen = 60. |
| `@CertificateExpiryWarnDays int` | `90` | Tage, gültig 1–36500; Ablauf vor GETDATE()+Fenster ergibt TDE_CERTIFICATE_EXPIRY_WINDOW. NULL wird nicht abgefangen und unterdrückt den Befund über NULL-Vergleich. Ausgelassen = 90. |
| `@ExpliziteBackupverschluesselungErwartet bit` | `0` | 0 keine Erwartungswarnung; 1 MEDIUM, wenn kein jüngstes nicht-copy-only Full-Backup im Lookback sichtbar ist oder key_algorithm NULL ist. Getrennt von TDE. Numerisch 0→0/jeder numerische Wert ungleich 0→1; NULL unterdrückt mangels Validierung den Vergleich. Ausgelassen = 0. |
| `@BackupLookbackDays int` | `35` | Tage vor GETDATE(), gültig 1–3650. Nur backupset type D, is_copy_only=0 und finish_date im Fenster; jüngstes je Datenbank. NULL ergibt NULL-Datumsgrenze/keinen Treffer ohne Parameterfehler. Ausgelassen = 35. |
| `@MaxZeilen int` | `1000` | NULL oder 0 unbegrenzt; positive int-Zahl ist Maximalzeilen nach Severity HIGH, MEDIUM, INFO und DatabaseId; negativ INVALID_PARAMETER und leere Exportmenge. Limit nach Analyse und Filter, nicht für Status/Sources/Warnings. Ausgelassen = 1000. |
| `@LockTimeoutMs int` | `0` | Nichtnegative ganze Zahl in Millisekunden von 0 bis 2147483647; 0 verlangt im jeweiligen datenbanklokalen Aggregatbatch sofortige Rückgabe bei einer Sperre. Negativ ist INVALID_PARAMETER. Der Wert ist kein Gesamtzeitbudget und wird nur in diese dynamischen Aggregatbatches eingefügt; übrige direkte Quellen verwenden LOCK_TIMEOUT 0. SET-Werte im dynamischen Batch enden mit dessen Rückkehr. NULL wird nicht abgefangen und macht den verketteten Batchtext @Sql zu NULL. Daraus wird hier kein garantierter SQL-Fehler und kein bestimmter Laufzeiteffekt behauptet; die Procedure definiert für NULL keinen regulären Timeoutwert. |
| `@ResultSetArt varchar(16)` | `'CONSOLE'` | Normalisiert mit UPPER/TRIM/COALESCE; gültig RAW, CONSOLE, TABLE, NONE. RAW vier technische Resultsets; CONSOLE ein beschriftetes Ergebnis über InternalEmitConsoleResult aus der Exportmenge; TABLE schreibt einzig databases; NONE keine Hauptsets. JSON separat über @JsonErzeugen. NULL/leer→INVALID_PARAMETER; äußere Leerzeichen und Case normalisiert. TABLE/CONSOLE intern auf NONE umgeschaltet. |
| `@ResultTablesJson nvarchar(max)` | `NULL` | Nur bei TABLE zulässig; sonst nichtleerer Wert THROW 51011. Helper preflight verlangt Mapping für exakt ein benanntes Ergebnis databases, mindestens ein Paar, string key/value, passende exakte/case-sensitive Schlüssel, keine doppelten Schlüssel oder case-insensitive doppelten Ziele/Extra-Schlüssel; Quelle muss vorhandene leere lokale #Temp-Tabelle sein, kein ##/#Monitor, Länge <=116. NULL/leerer Text scheitert am TABLE-Preflight. Vor Analyse geprüft; späterer Writer prüft Zielspalten per Namen und kann Teilwrites hinterlassen. Preflight/Writer THROW bei ThrowOnError=1. |
| `@JsonErzeugen bit` | `0` | 0 lässt @Json NULL; 1 erzeugt JSON mit meta, databases, sources, warnings; Datenarrays INCLUDE_NULL_VALUES. Numerisch 0→0/jeder numerische Wert ungleich 0→1; NULL wird nicht validiert und überspringt IF. Ausgelassen = 0; unabhängig von ResultSetArt. |
| `@Json nvarchar(max) OUTPUT` | `NULL` | OUTPUT nvarchar(max); sofort beim Eintritt NULL, auch bei Hilfe. Bei @JsonErzeugen=1 empfängt gebundene nvarchar(max)-Variable JSON mit resultName/schemaVersion/Zeit/Status/Partial/Version, databases, sources, warnings; sonst NULL. Mit passender Variable OUTPUT binden, sonst wird Wert nicht empfangen. Hilfe lässt NULL. |
| `@PrintMeldungen bit` | `1` | Signatur bietet bit 0/1 (numerisch 0→0, jeder numerische Wert ungleich 0→1), NULL unvalidiert, ausgelassen = 1. Parameter wird im Body nicht gelesen und hat keine Wirkung; Hilfe wird separat von @Hilfe gesteuert. |
| `@Hilfe bit` | `0` | 0 Analyse; 1 druckt die Hilfetexte und RETURN vor Tabellen, Validierung, Kandidatensuche und Diagnose-OUTPUT-Zuweisungen; @Json wurde davor NULL. Numerisch 0→0/jeder numerische Wert ungleich 0→1; NULL unvalidiert und normaler Pfad. Ausgelassen = 0. |
| `@StatusCodeOut varchar(40) OUTPUT` | `NULL` | Optionale OUTPUT-Bindung an eine varchar(40)-Variable. Alle erreichbaren Statuswerte: AVAILABLE bedeutet Abschluss ohne gesetzte Partialität und ohne HIGH-/MEDIUM-Befund; AVAILABLE_WITH_FINDING bedeutet mindestens einen HIGH-/MEDIUM-Befund bei sonst verfügbarem Ergebnis; AVAILABLE_LIMITED bedeutet partielle Quellenaufnahme oder Auswahlwarnungen; INVALID_PARAMETER bedeutet lokale oder delegierte ungültige Eingaben; INTERNAL_ERROR bedeutet, dass der Auswahlhelfer seine erwartete Kandidatentabelle nicht verwenden kann; UNAVAILABLE_FEATURE bedeutet einen mangels SQL Server 2025/Compatibility Level 170 nicht ausführbaren Regexfilter. Lokale/delegierte Eingabefehler verhindern den regulären Analysepfad. Bei erfolgreicher Vorbereitung gehen Quellenpartialität und anschließend Auswahlwarnungen einem Findingstatus vor. Weil @AnalysisClass=NULL übergeben wird, gibt es hier keine Analyseklassen-Gruppen- oder High-Impact-Freigabe. Hilfe lässt den Eingangswert dieses OUTPUTs unverändert. Reguläre Statusausgabe bestätigt keine Wiederherstellbarkeit. |
| `@IsPartialOut bit OUTPUT` | `NULL` | OUTPUT bit; mit passender OUTPUT-Variable binden. 1 bei partieller Quelle, Auswahlwarning oder Status außerhalb AVAILABLE/AVAILABLE_WITH_FINDING; sonst 0. Hilfe lässt unverändert. |
| `@ErrorNumberOut int OUTPUT` | `NULL` | Optionale OUTPUT-Bindung an eine int-Variable. Empfängt die letzte in den äußeren Quellen- oder Aggregations-CATCH-Blöcken gespeicherte native SQL-Fehlernummer; spätere solche Zuweisungen überschreiben frühere. Ohne diese Zuweisungen bleibt der reguläre Wert NULL. Lokale Parameterfehler setzen keine Nummer. Der datenbanklokale Aggregat-CATCH setzt nur Partialität und eine Auswahlwarnung, ohne diesen Diagnose-OUTPUT zu füllen. Geworfene TABLE-Vorprüfungs-/Writerfehler umgehen die normale abschließende OUTPUT-Zuweisung; Hilfe lässt den Eingangswert unverändert. |
| `@ErrorMessageOut nvarchar(2048) OUTPUT` | `NULL` | Optionale OUTPUT-Bindung an eine nvarchar(2048)-Variable. Empfängt die zuletzt in den äußeren Quellen-/Aggregations-CATCH-Blöcken gespeicherte native Fehlermeldung oder den Vorbereitungs-/Validierungstext. Lokale INVALID_PARAMETER-Prüfung setzt eine generische Nachricht, ohne Fehlernummer. Spätere tatsächliche Meldungszuweisungen überschreiben frühere. Der datenbanklokale Aggregat-CATCH setzt nur Partialität und Auswahlwarnung, ohne diesen Diagnose-OUTPUT zu füllen. Ohne gespeicherte Meldung wird regulär NULL ausgegeben. Geworfene TABLE-Vorprüfungs-/Writerfehler umgehen die normale abschließende OUTPUT-Zuweisung; Hilfe lässt den Eingangswert unverändert. |

### Kopierbare Aufrufbeispiele

Die getrennten Aufrufe zeigen RAW, JSON mit den tatsächlich vorhandenen Diagnose-OUTPUTs und RETURN, einen TABLE-Teilexport und die Hilfe. Das TABLE-Ziel wird mit einer Seed-Spalte angelegt und in beiden Abschlusswegen entfernt.

```sql
EXEC [monitor].[USP_EncryptionAnalysis] @MaxZeilen=200, @ResultSetArt='RAW', @PrintMeldungen=0;
```

```sql
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_EncryptionAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];
```

```sql
CREATE TABLE [#EncryptionAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_EncryptionAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=N'{"databases":"#EncryptionAnalysis_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#EncryptionAnalysis_HelpExample]; DROP TABLE IF EXISTS [#EncryptionAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#EncryptionAnalysis_HelpExample]; THROW; END CATCH;
```

```sql
EXEC [monitor].[USP_EncryptionAnalysis] @Hilfe=1;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `databases`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

RAW, CONSOLE, TABLE und JSON verwenden innerhalb eines Aufrufs dieselbe Exportmenge mit 26 Feldern. `@NurProblematisch = 1` wählt Priorität HIGH oder MEDIUM; `@MaxZeilen` begrenzt danach nach Priorität und `DatabaseId`. NULL und 0 bedeuten unbegrenzt; negative Werte werden als `INVALID_PARAMETER` mit leerer Exportmenge zurückgegeben. Die elf Textfelder verwenden explizit `SQL_Latin1_General_CP1_CS_AS`. Quellenstatus und Auswahlwarnings bleiben unabhängig vom fachlichen Ausgabefilter und Limit erhalten.

## Eine Zeile bedeutet

Eine Datenbankzeile verbindet TDE-Zustand, sichtbaren Schutzobjekt-Lebenszyklus, den letzten sichtbaren Full-Backup-Verschlüsselungsstatus und ausschließlich aggregierte Featureanzahlen. Quellenstatus und Datenbankwarnungen sind eigene Zeilentypen.

## So lesen

Prüfen Sie zuerst `StatusCode`, `IsPartial` und Quellenstatus. Berücksichtigen Sie danach `EncryptionStateDesc` und `EncryptionScanStateDesc`. Zertifikatablauf und lokaler Exportzeitpunkt sind Betriebsindizien. `LatestFullBackupExplicitlyEncrypted` beschreibt nur explizite Backupverschlüsselung; TDE ist davon getrennt.

Der Zertifikatpfad berücksichtigt `CERTIFICATE` und `CERTIFICATE_OAEP_256`. SQL Server 2025 verwendet den OAEP-Typ bei Compatibility Level 170; der gemessene `EncryptorType` bleibt im Export unverändert. Beide Typen binden sichtbare Zertifikate in `master` und verwenden dieselben Regeln für fehlende Schutzobjekte, das konfigurierte Ablaufwarnfenster und fehlende lokale Exportzeitpunkte.

## Warum kann das problematisch sein?

Ein suspendierter oder abgebrochener TDE-Scan, ein nicht sichtbares Schutzobjekt oder fehlende erwartete Backupverschlüsselung kann einen laufenden Schutz- oder Wiederherstellungsprozess beeinträchtigen. Ohne externe Schlüsselkopie kann ein Restore trotz intakter Backupdatei unmöglich sein.

## Wann ist es kein Problem?

Eine unverschlüsselte Datenbank ist ohne entsprechende Schutzvorgabe kein Fehler. Ein leerer lokaler Zertifikat-Backupzeitpunkt beweist nicht, dass keine externe Kopie existiert. Ein Zertifikatablauf beendet bestehende TDE-Verschlüsselung nicht automatisch. Always-Encrypted- und Ledger-Anzahlen sind Inventarkontext, kein Health-Urteil.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Ein suspendierter oder abgebrochener TDE-Scan, ein nicht sichtbares Schutzobjekt oder fehlende erwartete Backupverschlüsselung kann einen laufenden Schutz- oder Wiederherstellungsprozess beeinträchtigen. Ohne externe Schlüsselkopie kann ein Restore trotz intakter Backupdatei unmöglich sein.

**Ähnlich aussehender Gegenfall:** Eine unverschlüsselte Datenbank ist ohne entsprechende Schutzvorgabe kein Fehler. Ein leerer lokaler Zertifikat-Backupzeitpunkt beweist nicht, dass keine externe Kopie existiert. Ein Zertifikatablauf beendet bestehende TDE-Verschlüsselung nicht automatisch. Always-Encrypted- und Ledger-Anzahlen sind Inventarkontext, kein Health-Urteil. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Nicht installiert, nicht aktiviert, in der gewählten Datenbank nicht verwendet und nicht abfragbar sind vier verschiedene Zustände.

Für `USP_EncryptionAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

Ein Auswahlwarning führt bei sonst auswertbarem Aufruf zu `AVAILABLE_LIMITED` und `IsPartial = 1`; eine erfolgreiche Teilquelle behält ihren eigenen Status. Modulstatus und Partialität werden vor dem Ausgabefilter und Limit bestimmt. Eine leere Problemscope-Ausgabe entfernt deshalb weder den Auswahlwarning noch die Aussagegrenze des Moduls.

## Eigenlast und Grenzen

Die Procedure liest keine Schlüsselpfade, Signaturen, verschlüsselten Werte, Backupmedien, Konten oder privaten Schlüssel und gibt keine Thumbprints aus. Ein erfolgreicher isolierter Restore mit autorisiertem Schlüsselmaterial bleibt externer Nachweis.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM |
| Standardpfad | Eine `ExampleDatabase`, Problemscope, 35 Tage Backup-Lookback und endliches Limit. Gelesen werden TDE-/Zertifikat-, Always-Encrypted-, Ledger- und aggregierte Backupmetadaten, niemals Schlüsselmaterial. |
| Teuerster Pfad | Alle sichtbaren Datenbanken, sehr großer Backup-Lookback und unbegrenzte Ausgabe auf einer Instanz mit umfangreicher `msdb.dbo.backupset`-Historie sowie vielen sichtbaren Schutzobjekten. Ein separater Deep-Modus existiert nicht. |
| Haupttreiber | Zahl gewählter Datenbanken, TDE-/Zertifikat-/Schlüsselmetadaten, Always-Encrypted- und Ledgerobjekte sowie verschlüsselte Backupsets im Lookback. Schlüsselmaterial und geschützte Nutzdaten werden nicht gelesen. |
| Skalierung | Datenbankpfad wächst mit Schutzobjekten/verschlüsselten Spalten; der Backupbeleg wächst mit Datenbankanzahl, Lookback und msdb-Retention. Ergebnisaggregation und Sortierung folgen der vollständig materialisierten Metadatenmenge. |
| Ressourcen | CPU und Katalog-/msdb-I/O, insbesondere `sys.dm_database_encryption_keys`, Zertifikats-/Schlüsselkataloge und `msdb.dbo.backupset`; kleine temporäre Ergebnistabellen. |
| Begrenzungswirkung | Datenbankscope und `@BackupLookbackDays` begrenzen relevante Quellarbeit. `@NurProblematisch` und `@MaxZeilen` wirken erst auf die erzeugte Auswertung und reduzieren vor allem Rückgabe/JSON. |
| Locking und Nebenwirkungen | Rein lesend; keine Schlüssel-, Zertifikat- oder Konfigurationsänderung und kein Zugriff auf Backupmedien. Katalog und msdb werden nacheinander gelesen, weshalb ein parallel laufendes Backup oder eine Schlüsselrotation einen Mischstand erzeugen kann. |
| Schutzmechanismus | Der Kandidatenpfad verwendet `@AnalysisClass = NULL`; `@HighImpactConfirmed` schaltet hier keinen teureren Pfad frei. Schutz bieten Einzeldatenbank-Scope, Lookback und `@LockTimeoutMs`. |
| Sicherer Einsatz | Eine `ExampleDatabase`, begrenzter Backup-Lookback und Problemscope; Zertifikat-/Restoreaussagen immer gegen autorisierten externen Export- beziehungsweise Test-Restore-Nachweis prüfen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot + retentionbegrenzte Metadatenhistorie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche TDE-/Verschlüsselungszustände und Key-/Certificate-Abhängigkeiten sind sichtbar, ohne Schlüsselmaterial offenzulegen?

### Technischer Hintergrund

TDE verschlüsselt Daten-/Logseiten at rest über Database Encryption Key, geschützt durch Server Certificate/Asymmetric Key in `master` oder EKM. `sys.dm_database_encryption_keys` zeigt State/Percent/Algorithm/Protector. Restore auf anderer Instanz benötigt passenden Protector/Private Key. Backups können zusätzlich separat verschlüsselt sein.

### Datenkette

`msdb.dbo.backupset`, `sys.column_encryption_keys`, `sys.column_master_keys`, `sys.columns`, `sys.databases`, `sys.tables`, `master.sys.certificates`, `sys.dm_database_encryption_keys`.

### Source Select

Der TDE-Kern verbindet den Datenbankkatalog mit dem Encryption-Key-Laufzeitzustand:

```sql
SELECT
      [d].[name] AS [DatabaseName]
    , [dek].[encryption_state]
    , [dek].[percent_complete]
    , [dek].[encryptor_type]
FROM [sys].[databases] AS [d] WITH (NOLOCK)
LEFT JOIN [sys].[dm_database_encryption_keys] AS [dek] WITH (NOLOCK)
  ON [dek].[database_id] = [d].[database_id]
WHERE [d].[name] = N'ExampleDatabase';
```

**Wichtig für die Eigenlast:** Setzen Sie Datenbankfilter vor Zertifikats-, Backup- und Always-Encrypted-Katalogpfaden. Die Procedure gibt keine Schlüsselmaterialien aus; Zertifikats- und Backupprüfung sind getrennte Metadatenzweige.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Encryption-/Keymetadatenzustand; Rotation/Scan kann Fortschrittszustände zeigen.

### Bewertung und Gegenprobe

Prüfen Sie Encryption State, Percent Complete, Algorithm und Key Length, Encryptor Type, Zertifikatsablauf und Backupstatus, TempDB- und Systemkontext sowie Restoregovernance. Geben Sie ausschließlich öffentliche Metadaten aus und übernehmen Sie keine Thumbprints oder Keybytes in Artefakte.

### Typische Fehlinterpretation

`ENCRYPTED` beweist nicht, dass Zertifikat/Private Key sicher gesichert und Restore getestet wurde. TDE schützt nicht vor berechtigten SQL-Abfragen oder Datenexfiltration im laufenden System.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Certificate-/Key-Backupinventar in einem geschützten Zielsystem, echter Restoretest und Securitypolicy.

## Primärquellen

- [Transparent Data Encryption](https://learn.microsoft.com/en-us/sql/relational-databases/security/encryption/transparent-data-encryption?view=sql-server-ver17)
- [Compatibility Level 160 und 170: OAEP-Zertifikattyp](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-compatibility-level?view=sql-server-ver17#differences-between-compatibility-level-160-and-level-170)

[Technische Detailbeschreibung](../09_Version_Adaptive.md)
