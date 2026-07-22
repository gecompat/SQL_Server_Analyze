# [monitor].[USP_EncryptionAnalysis]

**Bereich:** Versionsadaptive Spezialanalysen<br>
**Zweck:** Bewertet sichtbare TDE-, Schutzobjekt-, Backupverschlüsselungs-, Always-Encrypted- und Ledger-Metadaten ohne Schlüsselmaterial oder geschützte Inhalte.<br>
**Beobachtungsart:** Snapshot + retentionbegrenzte Metadatenhistorie<br>
**Kostenklasse:** MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche TDE-/Verschlüsselungszustände und Key-/Certificate-Abhängigkeiten sind sichtbar, ohne Schlüsselmaterial offenzulegen?** Der dokumentierte Zweck ist: Bewertet sichtbare TDE-, Schutzobjekt-, Backupverschlüsselungs-, Always-Encrypted- und Ledger-Metadaten ohne Schlüsselmaterial oder geschützte Inhalte. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob das Spezialfeature vorhanden und in einem auffälligen Zustand ist und welches featureeigene Diagnoseverfahren als Nächstes gebraucht wird. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Korrektheit der Featurekonfiguration, keine geschützten Inhalte und keine End-to-End-Funktionsprüfung außerhalb sichtbarer Metadaten. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Encryption-/Keymetadatenzustand; Rotation/Scan kann Fortschrittszustände zeigen. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_EncryptionAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurProblematisch = 1,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `databases` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Datenbankzeile verbindet TDE-Zustand, sichtbaren Schutzobjekt-Lebenszyklus, den letzten sichtbaren Full-Backup-Verschlüsselungsstatus und ausschließlich aggregierte Featureanzahlen. Quellenstatus und Datenbankwarnungen sind eigene Zeilentypen.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Zuerst `StatusCode`, `IsPartial` und Quellenstatus prüfen. Danach `EncryptionStateDesc` und `EncryptionScanStateDesc` lesen. Zertifikatablauf und lokaler Exportzeitpunkt sind Betriebsindizien. `LatestFullBackupExplicitlyEncrypted` beschreibt nur explizite Backupverschlüsselung; TDE ist davon getrennt.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Ein suspendierter oder abgebrochener TDE-Scan, ein nicht sichtbares Schutzobjekt oder fehlende erwartete Backupverschlüsselung kann einen laufenden Schutz- oder Wiederherstellungsprozess beeinträchtigen. Ohne externe Schlüsselkopie kann ein Restore trotz intakter Backupdatei unmöglich sein.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Eine unverschlüsselte Datenbank ist ohne entsprechende Schutzvorgabe kein Fehler. Ein leerer lokaler Zertifikat-Backupzeitpunkt beweist nicht, dass keine externe Kopie existiert. Ein Zertifikatablauf beendet bestehende TDE-Verschlüsselung nicht automatisch. Always-Encrypted- und Ledger-Anzahlen sind Inventarkontext, kein Health-Urteil.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Ein suspendierter oder abgebrochener TDE-Scan, ein nicht sichtbares Schutzobjekt oder fehlende erwartete Backupverschlüsselung kann einen laufenden Schutz- oder Wiederherstellungsprozess beeinträchtigen. Ohne externe Schlüsselkopie kann ein Restore trotz intakter Backupdatei unmöglich sein.

**Ähnlich aussehender Gegenfall:** Eine unverschlüsselte Datenbank ist ohne entsprechende Schutzvorgabe kein Fehler. Ein leerer lokaler Zertifikat-Backupzeitpunkt beweist nicht, dass keine externe Kopie existiert. Ein Zertifikatablauf beendet bestehende TDE-Verschlüsselung nicht automatisch. Always-Encrypted- und Ledger-Anzahlen sind Inventarkontext, kein Health-Urteil. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Nicht installiert, nicht aktiviert, in der gewählten Datenbank nicht verwendet und nicht abfragbar sind vier verschiedene Zustände.

Für `USP_EncryptionAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Die Procedure liest keine Schlüsselpfade, Signaturen, verschlüsselten Werte, Backupmedien, Konten oder privaten Schlüssel und gibt keine Thumbprints aus. Ein erfolgreicher isolierter Restore mit autorisiertem Schlüsselmaterial bleibt externer Nachweis.

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

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
    , [dek].[encryptor_thumbprint]
FROM [sys].[databases] AS [d] WITH (NOLOCK)
LEFT JOIN [sys].[dm_database_encryption_keys] AS [dek] WITH (NOLOCK)
  ON [dek].[database_id] = [d].[database_id]
WHERE [d].[name] = N'ExampleDatabase';
```

**Wichtig für die Eigenlast:** Datenbankfilter vor Zertifikats-, Backup- und Always-Encrypted-Katalogpfaden setzen. Die Procedure gibt keine Schlüsselmaterialien aus; Zertifikats- und Backupprüfung sind getrennte Metadatenzweige.

### Zeit- und Scope-Modell

Aktueller Encryption-/Keymetadatenzustand; Rotation/Scan kann Fortschrittszustände zeigen.

### Bewertung und Gegenprobe

Encryption State, Percent Complete, Algorithm/Key Length, Encryptor Type, Certificateablauf/-backupstatus, TempDB-/Systemkontext und Restoregovernance prüfen. Nur öffentliche Metadaten ausgeben, keine Thumbprints/Keybytes in Artefakten.

### Typische Fehlinterpretation

`ENCRYPTED` beweist nicht, dass Zertifikat/Private Key sicher gesichert und Restore getestet wurde. TDE schützt nicht vor berechtigten SQL-Abfragen oder Datenexfiltration im laufenden System.

### Folgeanalyse

Certificate-/Key-Backupinventar in einem geschützten Zielsystem, echter Restoretest und Securitypolicy.

## Primärquellen

- [Transparent Data Encryption](https://learn.microsoft.com/en-us/sql/relational-databases/security/encryption/transparent-data-encryption?view=sql-server-ver17)

[Technische Detailbeschreibung](../09_Version_Adaptive.md)
