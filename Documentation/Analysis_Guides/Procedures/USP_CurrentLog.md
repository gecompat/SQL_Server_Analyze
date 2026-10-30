# [monitor].[USP_CurrentLog]

**Bereich:** Current State<br>
**Zweck:** Zeigt Logauslastung, Wiederverwendungswartegrund, VLF- und optional PVS-Kontext.<br>
**Beobachtungsart:** Snapshot + Katalog + kumulative Teilwerte<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die vollständige Hilfe (@Hilfe = 1) beschreibt alle 14 Parameter mit Typ, Default und tatsächlicher Wirkung und druckt getrennte, kopierbare CONSOLE-, TABLE- und JSON-Beispiele samt Scope-, Berechtigungs-, Status- und Partialitätsgrenzen aus.

### Einzelne Parameterverträge

| Parameter | Vollständiger Vertrag |
|---|---|
| `@DatabaseNames` | @DatabaseNames nvarchar(max), Default=NULL; bracket-aware Pipe-Liste exakter Datenbanknamen, z. B. N'[DbA]&#124;[DbB]'; case-sensitive Vergleich, keine Duplikate. Ausgelassen/NULL/leer/nur Leerzeichen bedeutet keine Einschränkung innerhalb sichtbarer, zugreifbarer ONLINE Datenbanken; nicht verfügbare explizite Namen erzeugen Auswahlwarning. Exklusiv mit @DatabaseNamePattern. Das Zeichen `\|` trennt nur außerhalb von `[...]`; in `[...]` bleibt `\|` im Namen, und `]]` maskiert ein inneres `]`. |
| `@SystemdatenbankenEinbeziehen` | @SystemdatenbankenEinbeziehen bit, Default=0; Schalter 0 schließt master, tempdb, model, msdb aus; 1 erlaubt sie. Ausgelassen ergibt 0; NULL wird als INVALID_PARAMETER abgewiesen. Numerische Eingaben werden vor Procedure-Eintritt nach bit konvertiert; ungleich 0 wird 1. |
| `@DatabaseNamePattern` | @DatabaseNamePattern nvarchar(4000), Default=NULL; einzelnes nichtleeres Pattern, exklusiv mit exakter Liste. Kein Präfix oder like: = case-sensitive SQL-LIKE (%, _, []); regex: = case-sensitive Regex; regexi: = case-insensitive Regex. Präfix case-insensitive erkannt, äußere Leerzeichen entfernt; Inhalt unverändert. Ausgelassen/NULL deaktiviert; leer/Whitespace/Präfix ohne Muster ungültig. Regex benötigt SQL Server 2025 und Installationsdatenbank-Compatibility-Level 170. |
| `@HighImpactConfirmed` | @HighImpactConfirmed bit, Default=0; 0/ausgelassen bestätigt nicht, numerischer Wert ungleich 0 wird vor Eintritt zu 1. NULL führt bei Pfadprüfung zu INVALID_PARAMETER. Bestätigt angeforderten High-Impact-Pfad, erteilt aber keine Gruppenfreigabe: Auswahl prüft STANDARD_CURRENT; bei @MitVlfInformationen=1 zusätzlich LOG_VLF_DEEP; nur aktivierte, gruppengated Klassen verlangen beides. |
| `@MinUsedPercent` | @MinUsedPercent decimal(5,2), Default=NULL Prozent; Wertebereich 0.00..100.00. NULL/ausgelassen deaktiviert Filter; Wert filtert nach Erfassung darunterliegende UsedLogPercent-Zeilen. Bei aktivem Filter gilt NULL UsedLogPercent als -1 und wird auch bei Schwelle 0 entfernt; NULL heißt unbekannt, nicht 0. |
| `@MitVlfInformationen` | @MitVlfInformationen bit, Default=0; 1 fragt nach LOG_VLF_DEEP je Datenbank COUNT_BIG(*) aus dm_db_log_info ab und ergänzt TotalVlfCount nur, wenn dm_db_log_stats keinen Gesamtwert lieferte; 0 überspringt (VlfStatus SKIPPED). Ausgelassen ergibt 0; NULL deaktiviert Abfrage und ergibt SKIPPED. Nichtnull/numerische Konvertierung: jeder Wert ungleich 0 wird 1. |
| `@MitPersistentVersionStore` | @MitPersistentVersionStore bit, Default=0; 1 liest/aggregiert PVS-KB aus sys.dm_tran_persistent_version_store_stats für ausgewählte Datenbanken mit ADR; bei deaktiviertem ADR NOT_APPLICABLE. 0 überspringt (SKIPPED). Ausgelassen ergibt 0; NULL lässt PvsStatus PENDING und fragt nicht ab; numerischer Wert ungleich 0 wird vor Eintritt zu 1. |
| `@MaxZeilen` | @MaxZeilen int, Default=1000 Zeilen; ganze Zahl 0..2147483647. NULL oder 0 unbegrenzt; negativ INVALID_PARAMETER. Positiv begrenzt nach Sammlung/Prozentfilter sortiert auf UsedLogPercent DESC, DatabaseName, ohne Erfassungsarbeit einzuschränken. RAW und JSON sortieren; TABLE/CONSOLE haben keine Ordnungszusage. |
| `@ResultSetArt` | @ResultSetArt varchar(16), Default='CONSOLE'; nach Trim/UPPER taxativ RAW (Status, Logs, Teilquellenfehler), CONSOLE (Status, Logzeilen, Warnings), TABLE (logs-Temp-Export), NONE (keine fachlichen Resultsets). Ausgelassen ergibt CONSOLE; NULL/leer normalisiert zu '' und ist ungültig. Andere Werte INVALID_PARAMETER. |
| `@ResultTablesJson` | @ResultTablesJson nvarchar(max), Default=NULL; nur TABLE: JSON-Objekt mit exakt einem erlaubten Key logs (Logzeilen je Datenbank) und einem JSON-String als Zielname einer vorhandenen lokalen #Temp-Tabelle. Ziel muss leer und mit genau einer Seed-Spalte vorbereitet sein; Vorbereitung/Validierung erfolgt vor semantischer Parameterprüfung, ungültige Zuordnung wirft 51011. Andere Modi verlangen NULL/leer, sonst 51011. Ausgelassen/NULL oder leer ist nur außerhalb TABLE zulässig; TABLE benötigt die nichtleere Zuordnung mit Key logs. |
| `@JsonErzeugen` | @JsonErzeugen bit, Default=0; 1 erzeugt JSON-Envelope meta, logs, databaseStatus, warnings, unabhängig vom Resultsetmodus; 0 deaktiviert. Ausgelassen ergibt 0; NULL erzeugt keines. Jeder numerische Nichtnullwert ungleich 0 konvertiert zu 1. |
| `@Json` | @Json nvarchar(max) OUTPUT, Default=NULL; optionale Empfangsvariable nvarchar(max), beim EXEC mit OUTPUT binden. Beim Eintritt NULL, bei @JsonErzeugen=1 mit Envelope befüllt; ohne Erzeugung bleibt NULL. Auslassen, wenn nicht empfangen. |
| `@PrintMeldungen` | @PrintMeldungen bit, Default=1; 1 sendet bei Endstatus ungleich AVAILABLE Severity-10-Warnung mit NOWAIT; 0 unterdrückt Meldung. Ausgelassen ergibt 1; NULL unterdrückt Meldung. Ändert Resultsets/JSON nicht; numerischer Wert ungleich 0 wird zu 1. |
| `@Hilfe` | @Hilfe bit, Default=0; 1 gibt PRINT-Hilfe aus und kehrt vor fachlicher Verarbeitung zurück; 0/NULL führt normalen Pfad aus. Ausgelassen ergibt 0. Vor Eintritt konvertiert SQL Server numerische Werte ungleich 0 zu 1. |

Die Procedure beantwortet die Betriebsfrage: **Wie voll ist das Transaktionslog, warum kann es nicht wiederverwendet werden und welches Risiko entsteht?** Sie unterstützt die Entscheidung, ob das aktuelle Symptom im Erfassungsmoment sichtbar ist und welcher engere Live-, Verlaufs- oder Planpfad als Nächstes sinnvoll ist.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine lückenlose Historie und allein aus einem Snapshot weder Dauerhäufigkeit noch Root Cause oder zukünftige Entwicklung. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentLog]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Resultsets und Leserichtung

TABLE schreibt ausschließlich `logs` mit 19 Feldern, acht Frameworktextcollations und sechs NOT-NULL-Feldern ohne Identity. Die aktive CONSOLE zeigt dieselbe Menge mit einer zusätzlichen Beschriftung; bei leerer Menge liefert sie eine dreispaltige Hinweiszeile. RAW liefert Modulstatus, Logs und Teilquellenfehler. JSON ergänzt `meta`, `logs`, `databaseStatus` und `warnings`; `databaseStatus` enthält ausschließlich Teilquellenfehler, keine eigene Erfolgszeile für jede Datenbank. Status, Scope und Warnings sind vor der Bewertung der Fachwerte zu prüfen.

## Eine Zeile bedeutet

Eine `logs`-Zeile beschreibt eine ausgewählte Datenbank. VLF-Anzahlen und optionaler PVS-Kontext sind zusammengefasste Felder dieser Zeile; einzelne Logdateien, VLFs oder Version-Store-Zeilen werden nicht ausgegeben.

## So lesen

Berücksichtigen Sie Used Percent, absolute Loggröße, `log_reuse_wait_desc`, Growth, VLF und offene Transaktionen gemeinsam.

## Warum kann das problematisch sein?

Hohe Nutzung ist besonders kritisch, wenn Wiederverwendung durch eine alte Transaktion, fehlende Logbackups oder HA-/Replikations-Lag blockiert wird. Reines Vergrößern behebt die Ursache nicht.

## Wann ist es kein Problem?

Hohe Nutzung während eines geplanten Batches kann akzeptabel sein, wenn Kapazität, Backupfolge und anschließende Wiederverwendung gesichert sind.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 95 % genutzt plus `ACTIVE_TRANSACTION` plus zwei Stunden alte Transaktion: Primärursache ist die offene Transaktion. Prüfen Sie `USP_CurrentTransactions`, Backupstatus und Kapazität.

**Ähnlich aussehender Gegenfall:** Hohe Nutzung während eines geplanten Batches kann akzeptabel sein, wenn Kapazität, Backupfolge und anschließende Wiederverwendung gesichert sind. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Bei Live-DMVs kann der Zustand bereits beendet sein, bevor die Quelle gelesen wird. Eine leere Menge ist deshalb höchstens 'jetzt nicht sichtbar', nicht 'trat nicht auf'.

Für `USP_CurrentLog` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

**Quellcode-Hinweis zur Eigenlast:** Der Standardpfad besitzt eine moderate Eigenlast; die automatische Datenbankauswahl besitzt keine Vorabbegrenzung.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Alle gewählten Datenbanken mit Logspace, Reuse-Metadaten und Logstatistik einschließlich aktiver und gesamter VLF-Anzahl. Ohne Einschränkung sind alle sichtbaren, zugreifbaren und online befindlichen Benutzerdatenbanken ausgewählt. |
| Teuerster Pfad | Cross-Database-VOLL-Lauf mit VLF- und PVS-Vertiefung über große beziehungsweise VLF-reiche Logs. |
| Haupttreiber | Zahl gewählter Datenbanken und – bei aktiviertem Detail – ihrer VLF-Zeilen aus `dm_db_log_info`; Log-Space-/Log-Stats-Summary ist je Datenbank klein. PVS-Kontext fügt Metadaten hinzu, liest aber keine Version-Store-Zeilen. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_CurrentLog ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | Katalog-/DMV-CPU und bei VLF-/PVS-Vertiefung zusätzliche datenbankweise Arbeit, TempDB und Ergebnistransfer. |
| Begrenzungswirkung | Datenbankfilter begrenzen den Quellzugriff. Das gemeinsame Zeilenlimit folgt auf vollständige Datenbankarbeit, Prozentfilter, Zähler und Statusbewertung; es reduziert diese frühere Arbeit nicht. `NULL` oder `0` bedeutet unbegrenzt, ein negatives Limit `INVALID_PARAMETER`. Alle vier Ausgabeformen verwenden die danach begrenzte Logmenge. |
| Locking und Nebenwirkungen | Read-only, aber dynamische datenbankweise Katalogzugriffe können kurz mit DDL/Statuswechseln kollidieren. Der Zustand kann sich schon während des Laufs ändern. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `LOG_VLF_DEEP`, `STANDARD_CURRENT`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Zuerst eine ExampleDb ohne VLF-/PVS-Details; LOG_VLF_DEEP nur gezielt und in ruhigerem Betriebsfenster freigeben. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot + Katalog + kumulative Teilwerte“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie voll ist das Transaktionslog, warum kann es nicht wiederverwendet werden und welches Risiko entsteht?

### Technischer Hintergrund

Das Log ist eine sequenzielle Recoverystruktur aus VLFs. Log Records müssen für Commit gehärtet und für Recovery/Backup/HADR/Replication je nach Konfiguration erhalten werden. Space-Usage, Filemetadaten, VLF-Kontext und `log_reuse_wait_desc` erklären verschiedene Ebenen.

### Datenkette

`master.sys.databases`, `sys.dm_db_log_info`, `sys.dm_db_log_space_usage`, `sys.dm_db_log_stats`, `sys.dm_tran_persistent_version_store_stats`, `sys.sp_executesql`.

### Source Select

Die Datenbankidentität, das Recovery Model, der Reuse-Wait und der ADR-Schalter stammen aus `master.sys.databases`. Pro ausgewählter Datenbank werden Logspace und Logstatistik getrennt gelesen:

```sql
SELECT [total_log_size_in_bytes], [used_log_space_in_bytes],
       [used_log_space_in_percent], [log_space_in_bytes_since_last_backup]
FROM [sys].[dm_db_log_space_usage] WITH (NOLOCK);

SELECT [active_vlf_count], [total_vlf_count], [log_truncation_holdup_reason],
       [log_backup_time], [log_recovery_size_mb]
FROM [sys].[dm_db_log_stats](DB_ID());
```

Bytewerte werden durch 1.048.576 geteilt und auf `decimal(19,2)` projiziert. `UsedLogPercent` übernimmt den nativen Prozentwert als `decimal(19,4)`; er wird nicht aus gerundeten MB berechnet. Der VLF-Opt-in zählt `dm_db_log_info` und ergänzt die Gesamtanzahl nur bei fehlendem Logstatistikwert. PVS wird optional datenbankweise aus KB aggregiert; bei deaktiviertem ADR lautet sein Teilstatus `NOT_APPLICABLE`.

**Wichtig für die Eigenlast:** Zuerst die Datenbankkandidaten einschränken. `sys.dm_db_log_info` liefert eine Zeile je VLF und ist der wesentliche Vertiefungstreiber; VLF-Details nicht breit über alle Datenbanken lesen.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Space- und Reusezustand. Einzelne Werte sind kumulativ; Belegung und Reuse-Wait können sich während der getrennten Quellenabfragen ändern. `LogBackupTime` übernimmt den nativen `datetime`-Wert ohne zusätzliche UTC-Konvertierung. Eine atomare Momentaufnahme aller Datenbankwerte entsteht nicht.

Ohne Datenbankeinschränkung bedeuten `NULL`, `N''` und Leerzeichen alle zulässigen Benutzerdatenbanken; Systemdatenbanken benötigen Opt-in. Exakte bracket-aware Pipe-Liste und Pattern sind exklusiv, doppelte exakte Namen ungültig. Der tatsächlich aktivierte Standardpfad ist `STANDARD_CURRENT`; VLF-Details prüfen zusätzlich `LOG_VLF_DEEP` und dessen Bestätigung/Freigabe.

Die Auswahl nach einem positiven Mengenlimit erfolgt nach `UsedLogPercent DESC, DatabaseName`. RAW und JSON sortieren diese Menge ausdrücklich; TABLE und die aktive CONSOLE besitzen keinen eigenen Zeilenordnungsvertrag. Kandidaten, Fehler, Auswahlwarnings und Detailbewertung bleiben vollständig. Standardmäßig sind VLF- und PVS-Optionen deaktiviert. Der unveränderte NULL-VLF-Schalter liefert `SKIPPED`; ein NULL-PVS-Schalter lässt `PENDING` und einen NULL-MB-Wert bestehen, ohne die PVS-Abfrage auszuführen.

### Bewertung und Gegenprobe

Berücksichtigen Sie Used Percent, absolute freie MB, Wachstumsoption, Volumeplatz und Reuse-Wait gemeinsam. `ACTIVE_TRANSACTION`, `LOG_BACKUP`, `AVAILABILITY_REPLICA` oder `REPLICATION` führen zu unterschiedlichen Maßnahmen.

### Typische Fehlinterpretation

Logvergrößerung beseitigt die Reuse-Ursache nicht. Shrink ist keine dauerhafte Lösung und kann VLF-/Autogrowthprobleme verschärfen.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_CurrentTransactions`, Backup-/AG-/Replicationmodule, `USP_CurrentIO` für Logfilelatenz.

## Primärquellen

- [sys.dm_db_log_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-log-stats-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../02_Current_State.md#9-monitorusp_currentlog)
