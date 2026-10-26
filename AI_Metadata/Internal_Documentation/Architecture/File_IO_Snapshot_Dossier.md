# Datei-I/O-Snapshots: Quellen, Identität und Vergleichsgrenzen

**Stand:** 26. Oktober 2026.
**Status:** Quell- und Identitätsvertrag mit implementiertem internem Target; die öffentliche native FILE_IO-Aufnahme bleibt offen.
**Artefakt-UID:** `urn:uuid:01a17554-a6d5-74c8-bf71-2eb993e63559`.
**Registrierung:** `DEFERRED`; keine finale lesbare Kennung vergeben.
**Zuordnung:** SC-023-EXPANSION, Rang 10 der
[Entwicklungsplanung](../Quality/Development_Waves_2026-10.md).

## Zweck und Abgrenzung

Nach dem öffentlichen Waitpfad soll das optionale Snapshotpaket gemessene
Datei-I/O-Rohwerte über getrennte lokale Aufrufe erhalten. Der Vergleich muss
beobachtete Identitätswechsel und fehlende Belege berücksichtigen.
Eine gleichbleibende beobachtete Identität beweist keine ununterbrochene
Zählerkontinuität. Numerische Differenzen bleiben deshalb ausdrücklich
unbewiesene Kandidaten.

Dieser Vorvertrag legt Quellenumfang, Identitätsbedingungen, Rohwerte und
fachliche Gegenfälle fest. Die öffentliche native Aufnahme und neue öffentliche Auswahlparameter bleiben
eine gesonderte Welle. Das interne Target implementiert den nachfolgenden Feldvertrag. Der [Feld- und Migrationsvertrag](File_IO_Snapshot_Field_Contract.md)
konkretisiert Source, Kontexte, Epochen und Versionsstufen und ist vor der Implementierung unabhängig geprüft.
Der [Snapshotvertrag](../../../Documentation/Architecture/Snapshot_Baseline_Package_Contract.md)
bleibt für den gelieferten Performance-Counter-/Waitstand und die interne Targetgrenze maßgeblich.

## Auswahl und native Aufnahme

Die Auswahl umfasst standardmäßig alle sichtbaren, zugänglichen
ONLINE-Benutzerdatenbanken. Exakte bracket-aware Pipe-Namen und ein getrenntes
Pattern schränken ausdrücklich ein; Systemdatenbanken bleiben opt-in.
Ein CURRENT-Default oder MaxDatenbanken wird nicht eingeführt. Die vorhandene
Kandidatenvorbereitung von `USP_CurrentIO` ist der Wiederverwendungspunkt.

Je Messzeitpunkt wird `sys.dm_io_virtual_file_stats(NULL,NULL)` genau einmal
ohne TOP oder Leselimit aufgenommen. Die Materialisierung wird mit der
ausgewählten Datenbankmenge verbunden; ein optionaler Payload enthält nur
deren Scope. `MaxRows` begrenzt erst die deterministisch ausgewählten
Dateientitäten für Targetwrites. Pending-I/O, physische Pfade und zusätzliche
Hostproben gehören nicht zu dieser Welle. Ein einzelner nativer Read beweist
keine atomare Sicht über alle DMV-Zeilen und Kataloge.

Vor und nach der Aufnahme werden Servername, nativer lokaler Engine-Start und
Startticks geprüft. Native UTC-Grenzen beschreiben das Messfenster; weder der
lokale Startwert noch `sample_ms` wird als UTC umetikettiert. Eine abweichende
Enginebindung verhindert Vergleichskandidaten. Der reguläre Aufruf führt
weder einen Reset noch eine zusätzliche Warte-/Samplingphase aus.

## Beobachtete Datenbank- und Dateiidentität

Die zugänglichen ausgewählten Datenbanken werden vor und nach dem nativen
Read in ihrem tatsächlich gebundenen Kontext geprüft. `sys.database_files`
liefert Dateimetadaten; die native I/O-Aufnahme liefert den Dateihandle.
Datenbank-ID, Name und `create_date` müssen weiterhin zum ausgewählten
Masterkatalogeintrag passen. Die Dateibindung umfasst Datei-ID, `file_guid`,
`create_lsn`, Typ und Handle. Der erste Umfang erfasst ROWS- und LOG-Dateien;
andere Typen oder nicht online befindliche Dateien erhalten einen expliziten
Ausschlussstatus.

Der logische Name dient der Lesbarkeit und ersetzt keine Identität. Fehlende
GUIDs, Generationswerte oder Handles sind keine Gleichheitsbelege. Auch ein
unveränderter Handle oder GUID beweist weder dauerhafte Objektidentität noch
einen ausgebliebenen Close-/Restore-/Resetvorgang. Die Bindung ist eine
beobachtete Vergleichsvoraussetzung innerhalb einer lokalen Instanz.

`sys.database_recovery_status` wird für diesen ersten Umfang nicht als
zusätzliche globale Identitätsquelle ausgewählt. Laut Primärquelle kann der
Katalogzugriff eine noch nicht geöffnete Datenbank starten. Eine spätere
Verwendung von Datenbank-GUID oder Recovery-Fork benötigt daher einen
ausdrücklich abgegrenzten und geprüften Zugriffspfad. Fehlende solche Werte
werden nicht aus Namen oder IDs erfunden.

## Rohwerte und Einheiten

Die folgenden gemessenen Werte bleiben je Datei getrennt. Es gibt keine
ungeprüfte Addition über Datenbanken, Dateien oder Einheiten.

| Native Quelle | Bedeutung und Behandlung |
|---|---|
| `num_of_reads` | Kumulative Anzahl ausgelöster Lese-I/O-Operationen. |
| `num_of_bytes_read` | Kumulative gelesene Bytes. |
| `io_stall_read_ms` | Kumulative lesebezogene Stallzeit in Millisekunden. |
| `num_of_writes` | Kumulative Anzahl ausgelöster Schreib-I/O-Operationen. |
| `num_of_bytes_written` | Kumulative geschriebene Bytes. |
| `io_stall_write_ms` | Kumulative schreibbezogene Stallzeit in Millisekunden. |
| `size_on_disk_bytes` | Aktuell beobachteter Gauge in Bytes; kein additiver Differenzkandidat. |
| `sample_ms` | Native Hostuptime-Beobachtung zur Einordnung; kein UTC-Zeitstempel. |

Die sechs kumulativen Größen können jeweils einen nichtnegativen
Differenzkandidaten erhalten. Raten, mittlere Latenzen, Engpassursachen,
Datenträgergesundheit und Queued-I/O-Auswertungen sind nicht Bestandteil
dieses ersten Umfangs. Fehlende Werte erzeugen keine Nullsamples.

## Vergleich, Epochen und Fehler

Verglichen wird ausschließlich mit dem unmittelbar vorhergehenden
finalisierten FILE_IO-Lauf, einschließlich eines fehlgeschlagenen Laufs.
Eine andere Auswahl oder eine dort fehlende Datei berechtigt nicht zum
Überspringen auf ältere Erfolge. Vollständige und gültige Kontext-/Rohdaten,
ein positives Zeitfenster, passende beobachtete Identität und nicht fallende
kumulative Werte sind notwendige Bedingungen für numerische Kandidaten.

Bei fehlender oder geänderter Identität, geändertem Handle, Quellenpartialität,
beschädigtem Kontext, fehlenden Rohwerten oder fallenden Countern werden
Zahlen unterdrückt und die konkrete Vergleichsgrenze erhalten. Unabhängig
verfügbare Rohwerte bleiben als Messung mit ihrer Identitätsgrenze erhalten.
Kandidaten tragen stets `MONOTONIC_CONTINUITY_UNPROVEN` und `IsPartial=1`;
ein erfolgreicher Datei-I/O-Capture bleibt deshalb `PARTIAL`.

Dateien können unterschiedliche Epochen besitzen. Ein einzelner
`CaptureRun.ResetEpochId` darf daraus keine gemeinsame Resetgeschichte
machen. Der genaue Vertrag muss Epochen an die jeweiligen Dateisamples und
ihren Kontext binden. Ein fataler nativer Quellfehler erzeugt einen ehrlichen
finalisierten Fehlerstatus ohne erfundene numerische Samples oder Epoche.
Fehler einzelner Datenbank-Metadatenquellen bleiben separat sichtbar.

Retention muss die letzte finalisierte FILE_IO-Laufzeile einschließlich
Fehlerstatus als Vergleichsgrenze erhalten. Ihre Kinder verfallen weiterhin
regulär. Ein erhaltener Run ohne erforderliche Kontext-/Rohdaten erlaubt
keinen numerischen Vergleich. Der bestehende Waitschutz bleibt erhalten.

## Genauer Feld- und Migrationsvertrag

Der [genaue Feldvertrag](File_IO_Snapshot_Field_Contract.md) führt die
Member-/Typentabellen und die bekannte Migration. Sein unabhängiger
Review ist abgeschlossen; der folgende Abschnitt erklärt deren fachlichen Zweck.

Der Feldvertrag konkretisiert die folgenden zusammenhängenden, unabhängig
geprüften Entscheidungen:

- Der transiente Sourcevertrag erhält exakte Member, JSON-Typen, Nullregeln,
  Mengenbindungen, UTC-/Native-Zeitformate und zulässige Quellenzustände.
- Getrennte globale und dateibezogene Kontexte müssen Auswahl, Capture,
  Scope, Epoche, Vorwert und tatsächlich gespeicherte Rohhashes binden.
  Ein globaler `nvarchar(4000)`-Wert kann keine unbeschränkte Dateiliste tragen.
- Metrikcodes, Einheiten, Werttypen, Qualitäts- und Vergleichscodes werden
  vollständig festgelegt. Sechs Rohcounter, ein Gauge und sechs Kandidaten
  sind der hier abgegrenzte fachliche Umfang; Kontext und Status sind eigene
  persistierte Informationen.
- Die alten `CollectorPolicy`- und `ScopeType`-CHECKs erlauben keinen
  FILE_IO-Collector beziehungsweise Dateiscope. Ihre bekannte Migration,
  Wiederholung, Seedkollisionen, unterbrochenen Stadien und letzte
  Abschlussmarkierung müssen vor DDL bestimmt sein.
- Neue Aufnahmeprüfungen müssen den gelieferten vollständigen Waitstand
  `1.2.1` weiterhin passend behandeln. Version, Schema und tatsächlicher
  Retentionsvertrag werden explizit zugeordnet; ein Marker allein genügt nicht.
- Die angehängten öffentlichen Auswahlparameter und der Collector-only-/
  gemeinsame Konfigurationsweg müssen bestehende positionale Aufrufe,
  den Performance-Counter-Default und die Waitverträge erhalten.

Der Quellstand implementiert das interne Target und die erforderliche
Waitkompatibilität. Nach deren regulärer Abnahme folgt die öffentliche native
Aufnahme als nächster getrennter Produktschritt. Der bestehende autonome
Benutzerauftrag bleibt die Arbeitsautorität.

## Abnahme und Betriebsgrenzen

Die native Abnahme benötigt eine unabhängige Vorher-/Nachher-Prüfung der
ausgewählten Dateimenge und Identitätsbelege gegen den gespeicherten Source.
Ein selbstkonsistenter SUT-Mengenzähler oder Payloadhash reicht nicht.
Volatile Counterwerte dürfen dabei nicht als gleichzeitig gelesen behauptet
werden. Ein tatsächliches TOP-/Filtergegenbeispiel muss erkannt werden.

Synthetische Gegenfälle umfassen wiederverwendete Datenbank-/Datei-IDs,
Restore, Dateigenerations- und Handlewechsel, fehlende GUIDs, gleiche oder
fallende Counter, nichtpositive Fenster, Auswahlwechsel, unmittelbar vorherige
Fehler, abgelaufene Kinder, manipulierte Rohwerte und ungültige Kontexte.
Quellrechte, einzelne Metadatenfehler und fataler Readfehler werden getrennt
geprüft. Budget, Enabled/Due vor Writes, derselbe Sessionlock, Callerzustände,
atomare Konfigurationsfehler und bestätigte Captures bei Ausgabefehlern gehören
zum späteren Produktvertrag.

Die Installer erteilen keine Rechte und erzeugen keine Datenbank oder Jobs.
Neue Entwicklungstests verwenden ausschließlich eigene gebundene Labobjekte;
die im SSIS-Chat erhaltene SSISDB bleibt außerhalb dieses Auftrags.
Dokumentation erhält statische Prüfungen ohne neue SQL-Instanz. Spätere
Installer-/Produktänderungen erhalten das vollständige SQL2025-Gate und nur
bei konkretem Versionsrisiko den betroffenen zusätzlichen nativen Scope gemäß
der [CI-Teststrategie](../../../Documentation/Quality/CI_Test_Strategy.md).

## Primärquellen

- [Datei-I/O-Statistik](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-io-virtual-file-stats-transact-sql?view=sql-server-ver17)
  beschreibt Rohfelder, Uptimebezug und native Berechtigungen.
- [Dateimetadaten](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-files-transact-sql?view=sql-server-ver17)
  beschreibt unter anderem Datei-GUID und mögliche NULL-Werte.
- [Recovery-Katalog](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-recovery-status-transact-sql?view=sql-server-ver17)
  beschreibt Sichtbarkeit, GUID-Grenzen und das mögliche Öffnen einer Datenbank.

Der [Snapshot-Ausbau](Snapshot_Expansion_Dossier.md) führt die bereits
integrierten Wellen und ihre historische Evidenz; der
[Betriebsleitfaden](../../../Documentation/Operations/Snapshot_Baseline_Operations.md)
erläutert ausschließlich den tatsächlich gelieferten Paketstand.

## Abnahme des Quell- und Identitätsvorvertrags

[PR #454](https://github.com/gecompat/SQL_Server_Analyze/pull/454) ist als
0237fddc integriert. Der unabhängige Review besitzt keine offenen P1/P2.
Alle vier Head-Prüfungen und die drei getrennten Main-Prüfungen für
Dokumentation 40245000001, Datenschutz 40244999998 und Commitnachricht
40245000048 bestehen. Die Regelkontextprüfung einschließlich 23 Selbsttests,
Dokumentationsstil, Roadmap-/Statuskonsistenz und die eindeutige UUIDv7
bestehen ebenfalls. Diese Dokumentationswelle startete keine SQL-Instanz
und behauptet keine FILE_IO-Laufzeitabnahme.
