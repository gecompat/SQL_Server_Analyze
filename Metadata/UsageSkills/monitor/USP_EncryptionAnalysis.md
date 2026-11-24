---
skill_format_version: "1.0.0"
name: "monitor.USP_EncryptionAnalysis"
schema_name: "monitor"
object_name: "USP_EncryptionAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure bewertet den sichtbaren Lebenszyklus von TDE, Schutzertifikaten, expliziter Backupverschluesselung, Always Encrypted und Ledger."
source_path: "Code/09_VersionAdaptive/080_USP_EncryptionAnalysis.sql"
---

# monitor.USP_EncryptionAnalysis

## Zweck und Einsatz

Die Procedure bewertet den sichtbaren Lebenszyklus von TDE, Schutzertifikaten, expliziter Backupverschluesselung, Always Encrypted und Ledger.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_EncryptionAnalysis]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `[sys].[databases]`, `[sys].[dm_database_encryption_keys]`, `[master].[sys].[certificates]`, `sys.dm_database_encryption_keys`, `master.sys.certificates`, `[msdb].[dbo].[backupset]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @NurProblematisch | bit | nein | 0 |
| @TdeTransitionWarnMinutes | int | nein | 60 |
| @CertificateExpiryWarnDays | int | nein | 90 |
| @ExpliziteBackupverschluesselungErwartet | bit | nein | 0 |
| @BackupLookbackDays | int | nein | 35 |
| @MaxZeilen | int | nein | 1000 |
| @LockTimeoutMs | int | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
| @IsPartialOut | bit | nein | NULL OUTPUT |
| @ErrorNumberOut | int | nein | NULL OUTPUT |
| @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. NULL, Leerstring oder ausschließlich äußere U+0020-Leerzeichen bedeuten keine exakte Einschränkung. Sonst eine bracket-aware Pipe-Liste: | trennt außerhalb von [...], ]] maskiert innen eine schließende Klammer; äußere U+0020-Leerzeichen je Element werden entfernt. Jedes rohe Segment darf höchstens 4000 UTF-16-Codeeinheiten umfassen. TVF_ParseSqlNameList prüft PARSENAME-Teil 1 auf einen nicht-NULL Namen, Teil 2 auf NULL und LEN(Teil 1) auf höchstens 128. Punkte außerhalb eines einzelnen quotierten Namens sind auch bei ausgelassenen Qualifizierern ungültig. Dies ist keine vollständige SQL-Bezeichnergrammatik, Existenz- oder Berechtigungsprüfung. Leere/fehlerhaft geklammerte Elemente, Parserablehnung und case-sensitive doppelte gültige Namen ergeben INVALID_PARAMETER. Eine wirksame Liste und jeder nicht-NULL @DatabaseNamePattern-Wert sind zusammen ungültig. Nur sichtbare, ONLINE befindliche, zugreifbare Datenbanken ohne Snapshotmarkierung werden Kandidaten; Systemdatenbanken bleiben ohne Opt-in ausgeschlossen. Nicht verfügbare explizit angeforderte Namen können Auswahlwarnungen liefern. Bei ausgelassenem Argument gilt der angegebene Default.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. 0 schließt master, tempdb, model, msdb aus; 1 lässt sie zu und beeinflusst SYSTEM_DATABASE_EXCLUDED-Warnings. Numerisch 0→0, jeder konvertierbare numerische Wert ungleich 0→1; NULL ergibt beim Candidate-Helper INVALID_PARAMETER; ausgelassen = 0. Bei ausgelassenem Argument gilt der angegebene Default.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. NULL/ausgelassen deaktiviert Pattern. Sonst äußere U+0020-Leerzeichen werden getrimmt; LIKE mit %, _, [...] oder Präfix like:, regex:, regexi: (Präfix case-insensitive). Nach Präfix kein erneutes Trim; leer/Präfix ohne Inhalt ungültig. LIKE verwendet SQL_Latin1_General_CP1_CS_AS; regex: Flag c, regexi: Flag i. Regex benötigt SQL Server 2025 und Compatibility Level >=170 der Installationsdatenbank, sonst UNAVAILABLE_FEATURE; Syntax wird nicht vorgeprüft. Mit wirksamer Namensliste ist jeder nicht-NULL Patternwert unzulässig; Filter nach Kandidatenermittlung. Bei ausgelassenem Argument gilt der angegebene Default.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. 0 keine Bestätigung; 1 bestätigt nur ein tatsächlich angefordertes Klassen-Gruppengate. Numerisch 0→0, jeder Wert ungleich 0→1; NULL ergibt beim Helper INVALID_PARAMETER, ausgelassen = 0. Hier wird @AnalysisClass=NULL übergeben, daher kein Gate und kein teurerer Pfad. Bei ausgelassenem Argument gilt der angegebene Default.

**@NurProblematisch:** @NurProblematisch bit; Default: 0. 0 exportiert INFO/MEDIUM/HIGH; 1 nur MEDIUM/HIGH. Filter nach Befundbildung und unabhängig von Status, Quellenstatus und Warnings. Numerisch 0→0, jeder numerische Wert ungleich 0→1; NULL ist nicht validiert und SQL-Filter lässt dann nur MEDIUM/HIGH durch. Ausgelassen = 0. Bei ausgelassenem Argument gilt der angegebene Default.

**@TdeTransitionWarnMinutes:** @TdeTransitionWarnMinutes int; Default: 60. Minuten, gültig 1–525600; Zustände 2,4,5,6 werden TDE_TRANSITION_LONG_RUNNING, wenn Scanänderung älter als UTC-Zeit minus Fenster ist. NULL ergibt INVALID_PARAMETER und eine leere Exportmenge. Die Bindung erfolgt als SQL-int; Leertext hat keinen Sonderdefault und unterliegt vor der Procedure der SQL-Konvertierung, danach gilt der Bereich. Ausgelassen = 60. Bei ausgelassenem Argument gilt der angegebene Default.

**@CertificateExpiryWarnDays:** @CertificateExpiryWarnDays int; Default: 90. Tage, gültig 1–36500; Ablauf vor GETDATE()+Fenster ergibt TDE_CERTIFICATE_EXPIRY_WINDOW. NULL ergibt INVALID_PARAMETER und eine leere Exportmenge. Die Bindung erfolgt als SQL-int; Leertext hat keinen Sonderdefault und unterliegt vor der Procedure der SQL-Konvertierung, danach gilt der Bereich. Ausgelassen = 90. Bei ausgelassenem Argument gilt der angegebene Default.

**@ExpliziteBackupverschluesselungErwartet:** @ExpliziteBackupverschluesselungErwartet bit; Default: 0. 0 keine Erwartungswarnung; 1 MEDIUM, wenn kein jüngstes nicht-copy-only Full-Backup im Lookback sichtbar ist oder key_algorithm NULL ist. Getrennt von TDE. Numerisch 0→0/jeder numerische Wert ungleich 0→1; NULL unterdrückt mangels Validierung den Vergleich. Ausgelassen = 0. Bei ausgelassenem Argument gilt der angegebene Default.

**@BackupLookbackDays:** @BackupLookbackDays int; Default: 35. Tage vor GETDATE(), gültig 1–3650. Nur backupset type D, is_copy_only=0 und finish_date im Fenster; jüngstes je Datenbank. NULL ergibt INVALID_PARAMETER und eine leere Exportmenge. Die Bindung erfolgt als SQL-int; Leertext hat keinen Sonderdefault und unterliegt vor der Procedure der SQL-Konvertierung, danach gilt der Bereich. Ausgelassen = 35. Bei ausgelassenem Argument gilt der angegebene Default.

**@MaxZeilen:** @MaxZeilen int; Default: 1000. NULL oder 0 unbegrenzt; positive int-Zahl ist Maximalzeilen nach Severity HIGH, MEDIUM, INFO und DatabaseId; negativ INVALID_PARAMETER und leere Exportmenge. Limit nach Analyse und Filter, nicht für Status/Sources/Warnings. Ausgelassen = 1000. Bei ausgelassenem Argument gilt der angegebene Default.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Nichtnegative ganze Zahl in Millisekunden von 0 bis 2147483647; 0 verlangt im jeweiligen datenbanklokalen Aggregatbatch sofortige Rückgabe bei einer Sperre. Negativ ist INVALID_PARAMETER. Der Wert ist kein Gesamtzeitbudget und wird nur in diese dynamischen Aggregatbatches eingefügt; übrige direkte Quellen verwenden LOCK_TIMEOUT 0. SET-Werte im dynamischen Batch enden mit dessen Rückkehr. NULL ergibt INVALID_PARAMETER und eine leere Exportmenge; für NULL wird kein dynamischer Aggregatbatch erzeugt. Die Bindung erfolgt als SQL-int; Leertext hat keinen Sonderdefault und unterliegt vor der Procedure der SQL-Konvertierung, danach gilt der Bereich. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Normalisiert mit UPPER/TRIM/COALESCE; gültig RAW, CONSOLE, TABLE, NONE. RAW vier technische Resultsets; CONSOLE ein beschriftetes Ergebnis über InternalEmitConsoleResult aus der Exportmenge; TABLE schreibt einzig databases; NONE keine Hauptsets. JSON separat über @JsonErzeugen. NULL/leer→INVALID_PARAMETER; äußere Leerzeichen und Case normalisiert. TABLE/CONSOLE intern auf NONE umgeschaltet. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur bei TABLE zulässig; sonst nichtleerer Wert THROW 51011. Helper preflight verlangt Mapping für exakt ein benanntes Ergebnis databases, mindestens ein Paar, string key/value, passende exakte/case-sensitive Schlüssel, keine doppelten Schlüssel oder case-insensitive doppelten Ziele/Extra-Schlüssel; Quelle muss vorhandene leere lokale #Temp-Tabelle sein, kein ##/#Monitor, Länge <=116. NULL/leerer Text scheitert am TABLE-Preflight. Vor Analyse geprüft; späterer Writer prüft Zielspalten per Namen und kann Teilwrites hinterlassen. Preflight/Writer THROW bei ThrowOnError=1. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 0 lässt @Json NULL; 1 erzeugt JSON mit meta, databases, sources, warnings; Datenarrays INCLUDE_NULL_VALUES. Numerisch 0→0/jeder numerische Wert ungleich 0→1; NULL wird nicht validiert und überspringt IF. Ausgelassen = 0; unabhängig von ResultSetArt. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT nvarchar(max); sofort beim Eintritt NULL, auch bei Hilfe. Bei @JsonErzeugen=1 empfängt gebundene nvarchar(max)-Variable JSON mit resultName/schemaVersion/Zeit/Status/Partial/Version, databases, sources, warnings; sonst NULL. Mit passender Variable OUTPUT binden, sonst wird Wert nicht empfangen. Hilfe lässt NULL. Bei ausgelassenem Argument gilt der angegebene Default.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Signatur bietet bit 0/1 (numerisch 0→0, jeder numerische Wert ungleich 0→1), NULL unvalidiert, ausgelassen = 1. Parameter wird im Body nicht gelesen und hat keine Wirkung; Hilfe wird separat von @Hilfe gesteuert. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit; Default: 0. 0 Analyse; 1 druckt die Hilfetexte und RETURN vor Tabellen, Validierung, Kandidatensuche und Diagnose-OUTPUT-Zuweisungen; @Json wurde davor NULL. Numerisch 0→0/jeder numerische Wert ungleich 0→1; NULL unvalidiert und normaler Pfad. Ausgelassen = 0. Bei ausgelassenem Argument gilt der angegebene Default.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionale OUTPUT-Bindung an eine varchar(40)-Variable. Alle erreichbaren Statuswerte: AVAILABLE bedeutet Abschluss ohne gesetzte Partialität und ohne HIGH-/MEDIUM-Befund; AVAILABLE_WITH_FINDING bedeutet mindestens einen HIGH-/MEDIUM-Befund bei sonst verfügbarem Ergebnis; AVAILABLE_LIMITED bedeutet partielle Quellenaufnahme oder Auswahlwarnungen; INVALID_PARAMETER bedeutet lokale oder delegierte ungültige Eingaben; INTERNAL_ERROR bedeutet, dass der Auswahlhelfer seine erwartete Kandidatentabelle nicht verwenden kann; UNAVAILABLE_FEATURE bedeutet einen mangels SQL Server 2025/Compatibility Level 170 nicht ausführbaren Regexfilter. Lokale/delegierte Eingabefehler verhindern den regulären Analysepfad. Bei erfolgreicher Vorbereitung gehen Quellenpartialität und anschließend Auswahlwarnungen einem Findingstatus vor. Weil @AnalysisClass=NULL übergeben wird, gibt es hier keine Analyseklassen-Gruppen- oder High-Impact-Freigabe. Hilfe lässt den Eingangswert dieses OUTPUTs unverändert. Reguläre Statusausgabe bestätigt keine Wiederherstellbarkeit. Bei ausgelassenem Argument gilt der angegebene Default.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. OUTPUT bit; mit passender OUTPUT-Variable binden. 1 bei partieller Quelle, Auswahlwarning oder Status außerhalb AVAILABLE/AVAILABLE_WITH_FINDING; sonst 0. Hilfe lässt unverändert. Bei ausgelassenem Argument gilt der angegebene Default.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Optionale OUTPUT-Bindung an eine int-Variable. Empfängt die letzte in den äußeren Quellen- oder Aggregations-CATCH-Blöcken gespeicherte native SQL-Fehlernummer; spätere solche Zuweisungen überschreiben frühere. Ohne diese Zuweisungen bleibt der reguläre Wert NULL. Lokale Parameterfehler setzen keine Nummer. Der datenbanklokale Aggregat-CATCH setzt nur Partialität und eine Auswahlwarnung, ohne diesen Diagnose-OUTPUT zu füllen. Geworfene TABLE-Vorprüfungs-/Writerfehler umgehen die normale abschließende OUTPUT-Zuweisung; Hilfe lässt den Eingangswert unverändert. Bei ausgelassenem Argument gilt der angegebene Default.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionale OUTPUT-Bindung an eine nvarchar(2048)-Variable. Empfängt die zuletzt in den äußeren Quellen-/Aggregations-CATCH-Blöcken gespeicherte native Fehlermeldung oder den Vorbereitungs-/Validierungstext. Lokale INVALID_PARAMETER-Prüfung setzt eine generische Nachricht, ohne Fehlernummer. Spätere tatsächliche Meldungszuweisungen überschreiben frühere. Der datenbanklokale Aggregat-CATCH setzt nur Partialität und Auswahlwarnung, ohne diesen Diagnose-OUTPUT zu füllen. Ohne gespeicherte Meldung wird regulär NULL ausgegeben. Geworfene TABLE-Vorprüfungs-/Writerfehler umgehen die normale abschließende OUTPUT-Zuweisung; Hilfe lässt den Eingangswert unverändert. Bei ausgelassenem Argument gilt der angegebene Default.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| databases | 1 | 1 | [DatabaseId] int NOT NULL PRIMARY KEY , [DatabaseName] sysname NOT NULL , [IsEncrypted] bit NULL , [EncryptionState] int NULL , [EncryptionStateDesc] nvarchar(60) NULL , [PercentComplete] real NULL , [EncryptionScanState] int NULL , [EncryptionScanStateDesc] nvarchar(60) NULL , [EncryptionScanModifyDate] datetime NULL , [KeyAlgorithm] nvarchar(32) NULL , [KeyLength] int NULL , [EncryptorType] nvarchar(32) NULL , [ProtectorName] sysname NULL , [ProtectorExpiryDate] datetime NULL , [ProtectorPrivateKeyLastBackupDate] datetime NULL , [LatestFullBackupFinishDate] datetime NULL , [LatestFullBackupExplicitlyEncrypted] bit NULL , [LatestFullBackupAlgorithm] nvarchar(32) NULL , [LatestFullBackupEncryptorType] nvarchar(32) NULL , [ColumnMasterKeyCount] bigint NULL , [ColumnEncryptionKeyCount] bigint NULL , [EncryptedColumnCount] bigint NULL , [LedgerTableCount] bigint NULL , [FindingCode] varchar(100) NULL , [FindingSeverity] varchar(16) NULL , [EvidenceLimit] nvarchar(1000) NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_EncryptionAnalysis] @MaxZeilen=200, @ResultSetArt='RAW', @PrintMeldungen=0;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Metadaten und lokale Zertifikat-Backuphistorie beweisen weder den Besitz externer Schluesselkopien noch die Wiederherstellbarkeit.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_EncryptionAnalysis
Version      : 1.0.1
Stand        : 2026-10-09
Zweck        : Die Procedure bewertet den sichtbaren Lebenszyklus von TDE, Schutzertifikaten,
               expliziter Backupverschluesselung, Always Encrypted und Ledger.
Methodik     : Read-only Metadatenanalyse mit je Quelle isolierter Fehlergrenze.
Datenschutz  : Liest keine Schluesselpfade, Thumbprints, verschluesselten Werte,
               Backupmedien, SQL-Texte, Konten oder privaten Schluessel.
Grenzen      : Metadaten und lokale Zertifikat-Backuphistorie beweisen weder den
               Besitz externer Schluesselkopien noch die Wiederherstellbarkeit.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_EncryptionAnalysis
Bewertet sichtbare TDE- und Schutzobjektzustände, explizite Verschlüsselung des letzten Full-Backups sowie aggregierte Always Encrypted- und Ledger-Metadaten je ausgewählter Datenbank.
Liest keine Schlüsselpfade, Thumbprints, verschlüsselten Werte, Backupmedien, Konten, SQL-Texte oder privaten Schlüssel. Fehlende lokale Zertifikat-Backuphistorie beweist keinen fehlenden externen Export; Metadaten beweisen weder Besitz externer Schlüsselkopien noch Wiederherstellbarkeit.
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_EncryptionAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];
CREATE TABLE [#EncryptionAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_EncryptionAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=N'{"databases":"#EncryptionAnalysis_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#EncryptionAnalysis_HelpExample]; DROP TABLE IF EXISTS [#EncryptionAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#EncryptionAnalysis_HelpExample]; THROW; END CATCH;
```

