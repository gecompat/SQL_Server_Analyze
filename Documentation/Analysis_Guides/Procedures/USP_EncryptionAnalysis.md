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

[Technische Detailbeschreibung](../09_Version_Adaptive.md)
