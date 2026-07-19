# [monitor].[USP_EncryptionAnalysis]

**Bereich:** Versionsadaptive Spezialanalysen  
**Zweck:** Bewertet sichtbare TDE-, Schutzobjekt-, Backupverschlüsselungs-, Always-Encrypted- und Ledger-Metadaten ohne Schlüsselmaterial oder geschützte Inhalte.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_EncryptionAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurProblematisch = 1,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Datenbankzeile verbindet TDE-Zustand, sichtbaren Schutzobjekt-Lebenszyklus, den letzten sichtbaren Full-Backup-Verschlüsselungsstatus und ausschließlich aggregierte Featureanzahlen. Quellenstatus und Datenbankwarnungen sind eigene Zeilentypen.

## So lesen

Zuerst `StatusCode`, `IsPartial` und Quellenstatus prüfen. Danach `EncryptionStateDesc` und `EncryptionScanStateDesc` lesen. Zertifikatablauf und lokaler Exportzeitpunkt sind Betriebsindizien. `LatestFullBackupExplicitlyEncrypted` beschreibt nur explizite Backupverschlüsselung; TDE ist davon getrennt.

## Warum kann das problematisch sein?

Ein suspendierter oder abgebrochener TDE-Scan, ein nicht sichtbares Schutzobjekt oder fehlende erwartete Backupverschlüsselung kann einen laufenden Schutz- oder Wiederherstellungsprozess beeinträchtigen. Ohne externe Schlüsselkopie kann ein Restore trotz intakter Backupdatei unmöglich sein.

## Wann ist es kein Problem?

Eine unverschlüsselte Datenbank ist ohne entsprechende Schutzvorgabe kein Fehler. Ein leerer lokaler Zertifikat-Backupzeitpunkt beweist nicht, dass keine externe Kopie existiert. Ein Zertifikatablauf beendet bestehende TDE-Verschlüsselung nicht automatisch. Always-Encrypted- und Ledger-Anzahlen sind Inventarkontext, kein Health-Urteil.

## Datenschutz und Evidenzgrenze

Die Procedure liest keine Schlüsselpfade, Signaturen, verschlüsselten Werte, Backupmedien, Konten oder privaten Schlüssel und gibt keine Thumbprints aus. Ein erfolgreicher isolierter Restore mit autorisiertem Schlüsselmaterial bleibt externer Nachweis.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche TDE-/Verschlüsselungszustände und Key-/Certificate-Abhängigkeiten sind sichtbar, ohne Schlüsselmaterial offenzulegen?

### Technischer Hintergrund

TDE verschlüsselt Daten-/Logseiten at rest über Database Encryption Key, geschützt durch Server Certificate/Asymmetric Key in `master` oder EKM. `sys.dm_database_encryption_keys` zeigt State/Percent/Algorithm/Protector. Restore auf anderer Instanz benötigt passenden Protector/Private Key. Backups können zusätzlich separat verschlüsselt sein.

### Datenkette

`msdb.dbo.backupset`, `sys.column_encryption_keys`, `sys.column_master_keys`, `sys.columns`, `sys.databases`, `sys.tables`, `master.sys.certificates`, `sys.dm_database_encryption_keys`.

### Zeit- und Scope-Modell

Aktueller Encryption-/Keymetadatenzustand; Rotation/Scan kann Fortschrittszustände zeigen.

### Bewertung und Gegenprobe

Encryption State, Percent Complete, Algorithm/Key Length, Encryptor Type, Certificateablauf/-backupstatus, TempDB-/Systemkontext und Restoregovernance prüfen. Nur öffentliche Metadaten ausgeben, keine Thumbprints/Keybytes in Artefakten.

### Typische Fehlinterpretation

`ENCRYPTED` beweist nicht, dass Zertifikat/Private Key sicher gesichert und Restore getestet wurde. TDE schützt nicht vor berechtigten SQL-Abfragen oder Datenexfiltration im laufenden System.

### Folgeanalyse

Certificate-/Key-Backupinventar außerhalb Repository, echter Restoretest und Securitypolicy.

[Technische Detailbeschreibung](../09_Version_Adaptive.md)
