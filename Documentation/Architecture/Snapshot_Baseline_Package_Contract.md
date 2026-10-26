# Optionales Snapshot-/Baseline-Paket – Architekturvertrag

**Produktstatus des ausgelieferten Performance-Counter-Slice:** `IMPLEMENTED_ACTIONS_GATE`  
**Waitausbau und weitere Collector, Rollups, Scheduler-/Exportpakete:** `PARTIAL_PRODUCT_FUNCTION`; der Waitpfad ist implementiert, weitere Ausbaupakete bleiben offen.

## Zweck und Abgrenzung

Der Frameworkkern ist zustandslos. Das optionale Snapshot-/Baseline-Paket ergänzt eine ausdrücklich installierte lokale Persistenz für begrenzte Zeitreihen und technische Modulstatus. Es wird nicht durch `Install_All.sql` installiert und richtet keinen Scheduler ein.

Pro SQL-Server-Instanz wird eine eigene Snapshotdatenbank empfohlen. Die Frameworkdatenbank hält nur die Zielbindung; Evidenz wird in der separat installierten Zieldatenbank gespeichert.

## Öffentliche Procedures

| Procedure | Aufgabe |
|---|---|
| `[monitor].[USP_ConfigureSnapshotTarget]` | bindet Ziel, Collector-, Retention-, Budget- und Payloadpolicy |
| `[monitor].[USP_RunSnapshotCollectionCycle]` | führt genau einen begrenzten Collection Cycle aus |
| `[monitor].[USP_PurgeSnapshotData]` | entfernt abgelaufene Daten child-first in begrenzten Batches |

Alle drei Procedures stehen im vollständigen Analysis Catalog mit `PackageCode = SNAPSHOT_OPTIONAL`. `IsInstalled` zeigt, ob sie lokal vorhanden sind.

## Installation

Zwei gleichwertige Installationswege stehen zur Verfügung:

- SQLCMD: die beiden kanonischen `Install_SnapshotBaseline_*.sql`-Masterinstaller
  aus einer vollständigen Repositorykopie ausführen;
- Standalone: `Code/Install/Build-SnapshotBaselineInstallers.ps1` ausführen und
  danach die beiden eingebetteten Artefakte unter `Code/Install/generated/`
  ohne SQLCMD-Modus verwenden.

In beiden Fällen bleibt die Reihenfolge verbindlich:

1. separate Snapshotdatenbank anlegen;
2. Target-Installer in der ausdrücklich ausgewählten Snapshotdatenbank ausführen;
3. Framework-Installer nach Anpassung von `[DeineDatenbank]` in der Frameworkdatenbank ausführen;
4. Ziel und Policies mit `USP_ConfigureSnapshotTarget` setzen;
5. einen kontrollierten manuellen Collection Cycle prüfen;
6. erst danach einen externen Scheduler konfigurieren.

Das Paket erstellt keine Datenbank, Benutzer, Login, Berechtigung oder Scheduleraufgabe.

Der aktuelle Quellstand installiert Target-PackageVersion 1.3.1 mit
SchemaVersion 3. Die öffentliche Collectorwahl umfasst Performance Counter,
Waits und ausdrücklich gewählte Datei-I/O-Aufnahmen. Das Datei-I/O-Backend
enthält 16 Metrikdefinitionen und eine zunächst deaktivierte FILE_IO-Policy.
Die öffentliche native Quelle verlangt Targetpatch 1.3.1 und Retentionsvertrag 3. Der [interne Datei-I/O-Vertrag](#internes-datei-io-target) beschreibt
Source-, Kontext-, Epochen- und Mengenbindung.

Der Purge erhält die größte finalisierte WAIT_STATS-ID und die größte
FILE_IO-ID einschließlich offener und fehlerhafter Läufe als Vergleichsgrenze;
ihre Kinder dürfen regulär ablaufen. Performance Counter behalten ihren bisherigen Löschpfad.
Bekannte Targets 1.0.0 / Schema 1 und 1.1.0, 1.1.1, 1.2.0, 1.2.1 / Schema 2
werden unter Erhaltung ihrer Daten, Identitäten und Policies auf Schema 3
migriert. 1.2.2 / Schema 3 ist ausschließlich das bekannte unvollständige
Installationsstadium. Das vollständige Target 1.3.0 / Schema 3 wird als
bekannter Patchstand unter Datenerhaltung auf 1.3.1 aktualisiert. Unbekannte Versionen, gemischte Domänen, zusätzliche
CHECKs, veränderte Tabellenfacetten und deaktivierte oder nicht vertrauenswürdige
Constraints werden vor Produktänderungen abgelehnt. Ein abweichender Stand
muss vor erneutem Installieren fachlich geklärt werden; der Installer repariert
keine unbekannten Nutzeränderungen.

Die Targetinstallation benötigt CONTROL DATABASE und VIEW ANY DEFINITION
für die native Struktur- und Triggerprüfung. Diese Installationsrechte sind
von den späteren Collector-Leserechten getrennt. Der direkte SQLCMD-Weg
bindet Strukturprüfung und Migration an dieselbe Transaktion. Die native
Katalogvorprüfung begrenzt jede Sperrwartezeit auf 10000 ms; die anschließende
eigene DDL verwendet LOCK_TIMEOUT 0. Der erzeugte Target-Standaloneinstaller führt alle
Batches in einer gemeinsamen Transaktion mit Abbruch beim ersten Fehler aus.
Er benötigt TRANCOUNT=0 und IMPLICIT_TRANSACTIONS OFF. Das kombinierte
Deployment behält seine eigene gesamte Transaktion und strikte Nachprüfung.
Eine Wiederholung darf LastInstallerRunUtc aktualisieren, überschreibt aber
keine vorhandenen Policies oder Samples.

Der lokale Neubau des Snapshot-Standaloneinstallers benötigt neben PowerShell
Python 3.11 oder neuer. PythonExecutable wählt den Interpreter ausdrücklich.
Die vorbereiteten SQL-Artefakte benötigen zur Ausführung keinen Interpreter.
Bereits veröffentlichte ZIP-Dateien bleiben unverändert; ihre enthaltene
Paketversion wird durch diesen Quellstand nicht nachträglich geändert.


## Zielbindung

`monitor.SnapshotTargetConfiguration` enthält die aktive Datenbankbindung und typisierte Steuerwerte. Das Ziel muss lokal erreichbar, als Snapshotpaket erkennbar und versionskompatibel sein.

Eine Zielkonfiguration umfasst mindestens:

- Zieldatenbank und Aktivstatus;
- Collectoraktivierung und Intervall;
- Rohdaten-, Payload- und Rollupretention;
- Softbudget und Budgetreaktion;
- Purgeintervall und Batchgröße;
- Payloadfreigabe;
- Schedulerherkunft.

Unbekannte Zielobjekte oder inkompatible Paketversionen führen zu einem kontrollierten Status. Es wird keine fremde Tabelle als Snapshotziel verwendet.

## Zielschema

| Tabelle | Granularität und Rolle |
|---|---|
| `[snapshot].[PackageVersion]` | installierte Paket- und Schemaversion |
| `[snapshot].[RetentionPolicy]` | typisierte Retention je Datenklasse |
| `[snapshot].[CollectorPolicy]` | Aktivierung, Intervall, Limits und Payloadmodus je Collector |
| `[snapshot].[CaptureRun]` | ein Collection Cycle mit Zeit-, Reset- und Gesamtstatus |
| `[snapshot].[ModuleStatus]` | Status, Partialität und Evidenzgrenze je Laufmodul |
| `[snapshot].[Scope]` | technische Scopeidentität und Parentbezug |
| `[snapshot].[MetricDefinition]` | versionierter Metrikcode, Typ, Einheit und Bedeutung |
| `[snapshot].[MetricSample]` | genau ein typisierter Wert je Lauf, Scope und Metrik |
| `[snapshot].[PayloadSnapshot]` | optionaler komprimierter, hashgebundener Rohpayload |
| `[snapshot].[PurgeRun]` | technische Summen eines Retentionlaufs |

Die vollständigen Spalten und Stabilitätsgrenzen stehen in der [Objektreferenz](../Reference/Object_Reference.md).

## Collection-Vertrag

Pro Instanz darf höchstens ein Collection Cycle gleichzeitig laufen. Eine benannte Anwendungssperre wird ohne Wartezeit angefordert; Parallelaufrufe werden kontrolliert übersprungen.

Ein Lauf:

1. prüft Zielbindung, Paketversion und Policy;
2. prüft Fälligkeit oder ausdrückliches `RunEvenIfNotDue`;
3. legt `CaptureRun` mit Scheduler-, UTC- und Resetkontext an;
4. ruft nur aktivierte Collectorpfade auf;
5. schreibt Modulstatus auch bei partieller oder nicht verfügbarer Quelle;
6. schreibt nur typisierte, definierte Metriken;
7. schreibt Payload nur bei expliziter Aktivierung;
8. finalisiert Laufstatus und Summen.

Der Defaultcollector erfasst begrenzte Performance-Counter-Evidenz; der ausdrücklich gewählte Waitcollector liest den gesamten Cache und begrenzt erst die Schreibauswahl. Weitere Frameworkmodule werden durch die Paketinstallation nicht automatisch persistiert.

## Zeit- und Resetmodell

Jeder Lauf verwendet UTC-Zeitgrenzen. Performance Counter behalten ihren bestehenden Engine-Start-/Epochenvertrag. Waits speichern den nativen lokalen Startwert und Startticks getrennt vom UTC-Messfenster; ihr `SqlServerStartTimeUtc` bleibt NULL. Gleicher Enginekontext beweist keinen ausgebliebenen Waitreset.

Metriken tragen ihren Werttyp und ihre Einheit in `MetricDefinition`. `MetricSample` speichert numerische, ganzzahlige oder textuelle Werte in getrennten Spalten. Ein partieller Read erzeugt keinen erfundenen Nullwert.

Ein Baselinevergleich ist nur zulässig, wenn Metrikcode, Vertragsversion, Scope, Einheit, Resetepoche und Qualitätsstatus kompatibel sind.

## Payloadvertrag

`PayloadEnabled = 0` ist der sichere Ausgangspunkt. Bei Aktivierung kann der vollständige versionierte JSON-Vertrag eines unterstützten Collectors komprimiert gespeichert werden.

Payloads besitzen:

- Capture- und Modulbezug;
- Format- und Vertragsversion;
- Kompressionstyp;
- Hash über den gespeicherten Inhalt;
- ursprüngliche Zeichenzahl;
- eigene Retention.

Ein Payload ist keine anonymisierte Darstellung. Seine Speicherung benötigt einen ausdrücklichen Datenschutz-, Berechtigungs-, Backup- und Löschvertrag.

## Retention

Retention ist je Datenklasse typisiert. `USP_PurgeSnapshotData` löscht nur Daten, deren Ablaufgrenze erreicht ist, und verarbeitet Abhängigkeiten child-first:

1. Payloads und Metriksamples;
2. Modulstatus;
3. Capture Runs;
4. nicht mehr referenzierte Scopes;
5. technische Purgesumme.

Batch- und Laufgrenzen verhindern einen unbeschränkten Einzeldelete. `@Force` hebt ausschließlich die Fälligkeitsprüfung nach dokumentiertem Vertrag auf; es erweitert nicht Ziel oder Datenklassen.

## Budgetmodell

`SoftBudgetMB` ist eine Betriebsgrenze, keine harte Dateigrößenbeschränkung. Die konfigurierte `BudgetAction` bestimmt die Reaktion, beispielsweise zuerst abgelaufene Daten zu purgen und weitere Collection zu stoppen, wenn das Budget weiterhin überschritten ist.

Ein Softbudget kann kurzfristig überschritten werden. Dateigröße, tatsächlich belegter Speicher, Logwachstum und freier Volumespeicher bleiben getrennte Betriebsmetriken.

## Fehler- und Partialitätsmodell

- Eine nicht lesbare Collectorquelle markiert das Modul partiell oder nicht verfügbar.
- Ein Modulfehler darf bereits erfolgreiche Module nicht als vollständig darstellen.
- Ein nicht fälliger Lauf ist kontrolliert übersprungen, nicht fehlgeschlagen.
- Ein Parallelaufruf ist kontrolliert übersprungen.
- Ein Ziel- oder Schemavertragsfehler verhindert fachliche Writes.
- Ein Purgefehler behält Summen und Fehlergrenze des bereits verarbeiteten Umfangs.

## Locking und Transaktionen

Die Zieldatenbank enthält echte persistente Writes. Collection verwendet kurze, begrenzte Inserts; Purge begrenzte child-first Deletes. Fremdschlüssel und Indizes können Zeilen- und Schlüsselsperren erzeugen. Die Betriebsdatenbank sollte für den Paketvertrag passend dimensioniert, gesichert und überwacht werden.

Lange Transaktionen über Quelllesung und gesamten Collection Cycle werden vermieden. Modulstatus bewahrt Teilfortschritt und Aussagegrenze.

## Datenschutz und Sicherheit

Die Snapshotdatenbank kann reale Laufzeitwerte, Namen, technische Identitäten und bei freigegebenem Payload vollständige JSON-Evidenz enthalten. Das Framework erweitert den Quellsicherheitskontext nicht und sammelt keine Kennwörter oder Schlüsselmaterialien.

Erforderlich sind:

- minimal berechtigter Collector;
- getrennte Rechte auf Framework- und Snapshotdatenbank;
- definierte Retention und Löschung;
- passende Backup- und Verschlüsselungsvorgaben;
- keine Payloadaktivierung ohne fachlichen Bedarf;
- kontrollierte Exporte und Weiterverarbeitung.

Siehe [Datenschutz und Laufzeitausgaben](Runtime_Data_Privacy.md).

## Nichtziele

- kein zentraler Fleet- oder Cloudservice;
- kein automatischer Scheduler;
- keine automatische Anonymisierung;
- keine persistente Vollkopie aller Frameworkresultsets;
- keine autonome Schwellwertaktion oder Konfigurationsänderung;
- kein Ersatz für Query Store, Extended Events oder reguläre Monitoringplattformen.

## Weiterführende Dokumentation

- [Betriebsleitfaden](../Operations/Snapshot_Baseline_Operations.md)
- [Installation](../Reference/Installation.md)
- [Procedure-Seite `USP_ConfigureSnapshotTarget`](../Analysis_Guides/Procedures/USP_ConfigureSnapshotTarget.md)
- [Procedure-Seite `USP_RunSnapshotCollectionCycle`](../Analysis_Guides/Procedures/USP_RunSnapshotCollectionCycle.md)
- [Procedure-Seite `USP_PurgeSnapshotData`](../Analysis_Guides/Procedures/USP_PurgeSnapshotData.md)


## Erhaltung der letzten Wait-Vergleichsgrenze

Die CaptureRun-Zeile mit der größten finalisierten WAIT_STATS-CaptureRunId
bleibt beim Purge erhalten, auch wenn sie einen Fehler meldet oder ihre Kinder
fehlen. Erst eine neuere tatsächlich finalisierte Wait-Aufnahme gibt die alte
Grenzzeile zur regulären Retention frei. Ein unfinalisierter Wait-Lauf oder
ein neuerer Performance-Counter-Lauf gibt sie nicht frei. Die Ausnahme hält
höchstens eine zusätzliche finalisierte Zeile; Performance-Counter-Läufe
behalten ihren bisherigen Löschpfad.

MetricSamples, Payloads, Modulstatus und nicht mehr referenzierte Scopes
laufen weiterhin nach ihrer normalen Retention ab. Ein erhaltener Run ohne
notwendige Rohdaten erlaubt keinen numerischen Vergleich. Der Waitcollector berücksichtigt fehlende Kinder und die unmittelbar vorherige Fehlergrenze ausdrücklich.


## Targetabschluss und öffentliche Wait-Aktivierung

Die erste Targetquelle 030 prüft Kontext, bekannte Struktur und beide
Collector-Seedverträge vor Produktänderungen. Sie markiert anschließend
Schema 3 als vorläufigen Stand 1.2.2. Quelle 075 prüft und ergänzt den
Waitteil; erst die letzte Quelle 078 prüft alle sieben Targethelper mit
ihren typisierten Parametern, die kompatiblen Seeds und den tatsächlich
schreibfreien Retentionsvertrag 3 und markiert 1.3.1. Ein unterbrochener
SQLCMD-Lauf ist kein fertiger Collectorstand. Standalone- und Gesamtinstaller
behalten ihre gesamte Transaktion und strikte Nachprüfung.

Die read-only Metrikkollisionsprüfung stammt aus der kanonischen letzten
Targetquelle und wird in den geprüften 030-Preflight übernommen. Ein fremdes
Objekt auf dem neuen Helpernamen in einem älteren Paket wird vor Änderungen
abgewiesen; ein exakt erkanntes eigenes Zwischenstadium bleibt wiederholbar.
Vorhandene passende Metrikdefinitionen, Beschreibungen und eigene Policywerte
werden erhalten. Eine fehlende WAIT_STATS-Policy wird mit IsEnabled=0 und
PayloadEnabled=0 angelegt; ein vorhandener passender eigener Zustand wird
nicht blind überschrieben.

Der interne Abschlusshelper verlangt den Source-v1- und Kontext-v1-Vertrag,
die passende tatsächliche Zielidentität und einen unbeschriebenen eigenen
laufenden Wait-Run. Er speichert keine garantierten resetfreien Deltas,
Raten oder Mittelwerte. Seine drei möglichen Differenzkandidaten sind immer
MONOTONIC_CONTINUITY_UNPROVEN mit IsPartial=1. Fehlende, partielle oder
widersprüchliche Basisdaten unterdrücken Zahlen und erhalten einen Status.
Die vier Rohwerte sind davon getrennt gemessene kumulative Werte; die maximale
Waitzeit ist ein High-Water-Wert und besitzt keinen additiven Kandidaten.
Die öffentliche Aktivierung erfolgt ausdrücklich über `@CollectorCode='WAIT_STATS'`
an Konfiguration und Collection. Der Defaultpfad bleibt Performance Counter.
Zwei interne Frameworkhelper prüfen die tatsächliche Zielidentität und führen
Enabled-/Due-Prüfung, Purge, Vorbereitung, vollständigen Nativecache-Read,
Waitabschluss und Ausgabe unter demselben Sessionlock zusammen. Signaturen,
neun Metrikdefinitionen und Retentionsvertrag müssen tatsächlich passen;
ein Versionsmarker allein genügt nicht. Die installierte Paketnamespace ist
vertrauenswürdig; dies ist kein Integritätsnachweis gegen administrative
Änderungen an Verfahren mit unveränderter Signatur.

Neue Konfigurationsoptionen verlangen einen Caller ohne eigene oder implizite
Transaktion. Mit `@UpdateSharedPolicy=1` besitzt der öffentliche Konfigurationspfad
die gesamte Transaktion über beide Datenbanken; das interne Target nimmt nur
mit ausdrücklichem Join teil. Mit `0` bleiben Frameworkzeile und gemeinsame
Werte einschließlich eigener Retentionszuordnung erhalten.

Bekannte Targets `1.2.0` werden mit ihren tatsächlich alten Helpern geprüft.
Auch der Abbruch nach dem erneuten 030-Stadium `1.2.2` vor Umschreiben des
Waithelpers ist wiederaufnehmbar, wenn dessen gespeicherter Code exakt dem
veröffentlichten eigenen Stand entspricht. Fremde Definitionen werden nicht
allgemein als eigener Zwischenstand anerkannt.

Das aktualisierte Framework unterstützt für Waits vollständige Targets
1.2.1 / Schema 2 mit Retentionsvertrag 1 und 1.3.0 / Schema 3 mit
Retentionsvertrag 2 sowie 1.3.1 / Schema 3 mit Retentionsvertrag 3. Beim getrennten Rollout wird zuerst das Framework
aktualisiert. Das alte Framework kennt den neuen Targetmarker nicht;
die umgekehrte Reihenfolge ist deshalb nicht als unterbrechungsfrei qualifiziert.

## Internes Datei-I/O-Target

InternalCompleteFileIOCycle nimmt einen geschlossenen Source-v1-Rahmen mit
meta, databases, files und issues entgegen. Die bereitgestellten Werte werden
vor der Speicherung auf Member, Typ, Nullregeln, native Wertebereiche,
Zeitfenster sowie Framework- und Auswahlbindung geprüft. Der Helper führt
keinen nativen VFS-Read aus. Er verlangt einen unbeschriebenen eigenen
Lauf mit CollectorCode=FILE_IO und Status RUNNING im vollständigen Target 1.3.1 / Schema 3 und besitzt
seine eigene Transaktion; Caller- und implizite Transaktionen sind unzulässig.

Jede ausgewählte geeignete Datei erhält sechs kumulative Rohcounter, den
Gauge für SizeOnDiskBytes, einen Vergleichsstatus und einen Dateikontext. Nur bei
gültiger unmittelbarer Vorwertbasis entstehen sechs nichtnegative
MONOTONIC_CONTINUITY_UNPROVEN-Kandidaten. Zusätzlich wird ein globaler
Aufnahmekontext geschrieben. Für N geschriebene und C vergleichbare Dateien
gilt MetricSampleCount = 9*N + 6*C + 1. Ein gültiger leerer Capture besitzt
nur den globalen Kontext; ein fataler Sourcefehler besitzt keine Metrics.

Dateiepochen binden Rohwerte, Status, Dateikontext und Kandidaten. Der globale
Kontext erhält eine eigene technische ContextEpochId je Capture;
CaptureRun.ResetEpochId und SqlServerStartTimeUtc bleiben NULL. Die bestehende
NOT-NULL-Bedingung von MetricSample.ResetEpochId bleibt erhalten.
Kanonische UTF-16LE-Hashes binden tatsächliche Scopeidentitäten, sieben
gespeicherte Rohzeilen und Dateikontexte. Der unmittelbar vorherige
FILE_IO-Lauf einschließlich offener und fehlerhafter Läufe ist die Vergleichsgrenze.
Fehlende, partielle, widersprüchliche oder abgelaufene Belege erlauben keine
Zahlen. Gleiche Beobachtungen beweisen keine ausbleibenden Resets;
Kandidaten und erfolgreiche Gesamtaufnahmen bleiben partiell.

Quellfehler verschwinden auch bei PayloadEnabled=0 nicht. Jeder gültige Issue
besitzt eine unveränderte Zeile mit Fehler und Evidenz und einen an deren tatsächliche
ModuleStatusId gebundenen Entitätskontext. Hinzu kommt eine Summaryzeile;
bei J Issues entstehen 1+2*J Module. Ein ungültiger Sourcevertrag finalisiert
einen kontrollierten SOURCE_CONTRACT-Fehler ohne numerische Samples.
Wiederholte SourceNames erhalten ab dem zweiten gleichnamigen Issue den Suffix
#<Originalordinal>. Der erste Kontext am nullbasierten Ordinal 0 heißt
FileIOSourceIssueContext; weitere heißen FileIOSourceIssueContext#<Ordinal>.
Die erste Sourcezeile bleibt unverändert benannt. Der ursprüngliche SourceName,
Status, Fehlertext und Evidenz bleiben vollständig erhalten; die tatsächliche
ModuleStatusId bindet den zugehörigen Kontext. Diese Ableitung erhält den
bestehenden UNIQUE-Vertrag für CaptureRunId/ModuleName ohne Schemaänderung.

## Öffentliche Datei-I/O-Aufnahme

Konfiguration und Collection wählen FILE_IO ausdrücklich mit @CollectorCode.
Das vollständige Target 1.3.1 / Schema 3 und der tatsächlich schreibfreie
Retentionsvertrag 3 sind erforderlich. Die FILE_IO-Policy bleibt nach der
Installation deaktiviert. Die drei angehängten Collectionparameter entsprechen
CurrentIO: @DatabaseNames als bracketfähige Pipe-Liste, @SystemdatenbankenEinbeziehen
mit Default 0 und @DatabaseNamePattern mit Default NULL. Wirksame neue Filter
an einem anderen Collector werden mit 51011 abgewiesen.

Der Frameworkcollector liest sys.dm_io_virtual_file_stats(NULL,NULL) genau
einmal vollständig in einen lokalen Cache. Erst danach werden die tatsächlich
ausgewählten Datenbanken zugeordnet. Vorher-/Nachher-Engine- und Katalogreads
binden die beobachteten Dateien; physische Dateipfade werden dafür nicht gelesen.
MaxRows begrenzt ausschließlich die sortierten geeigneten Targetwrites.
Metadatenlücken bleiben Issues, fehlende Werte werden keine Nullsamples.
Die Quelle garantiert keine atomare Dateiidentität oder Resetkontinuität.

Ein erfolgreicher nativer Read bleibt SUCCEEDED mit seiner beobachteten Menge,
auch wenn anschließend eine Engine- oder Zeitbindung scheitert. Der fatale
Frame enthält dann keine Dateiwerte und erzeugt keine Metrics. Ein nicht
begonnener Read hat bei nichtleerer Auswahl eine unbekannte Menge; die
bekannte leere Auswahl besitzt NOT_STARTED und die Menge 0.

Liegt die tatsächliche Abschlusszeit vor dem gespeicherten Runstart, bleiben
EndedAtUtc und die numerische Aufnahme unbestätigt. OUTPUT liefert
FINALIZATION_UNCONFIRMED mit der tatsächlichen Capture-ID. Ein gesonderter
Fehlerwrite erhält validierte Source-Issues, eine getrennte technische Diagnose
und FileIOFinalizationBoundary. Run- und Fehler-OUTPUT behalten bei erfolgreichem
Fehlerwrite die originale Sourcefehlerprojektion. Scheitert auch dieser Write,
liefern sie die tatsächlich abgefangene sekundäre Fehlernummer und Meldung.
Scheitert zusätzlich das Readback, bleibt die Runprojektion leer; lokal erhaltene
Quelldiagnosen tragen ModuleStatusId=NULL und behaupten keine Persistenz.

Die größte vorhergehende FILE_IO-ID ist auch mit EndedAtUtc=NULL die unmittelbare
Vergleichsgrenze. PREVIOUS_CAPTURE_UNCONFIRMED verhindert Kandidaten und den
Rückgriff auf ältere erfolgreiche Belege. Retentionsvertrag 3 erhält die größte
FILE_IO-ID unabhängig von Abschluss, Status und Kindern. Erst eine höhere
FILE_IO-ID gibt sie zur gewöhnlichen ablaufbezogenen Löschung frei. Die
Waitretention erhält weiterhin den größten finalisierten Waitlauf.

CONSOLE, RAW, TABLE, NONE und optionaler JSON-OUTPUT verwenden die bestehenden
run-/modules-Verträge. Der Default bleibt PERFORMANCE_COUNTERS. Die
[Betriebsanleitung](../Operations/Snapshot_Baseline_Operations.md) beschreibt
Aktivierung, Rechte und den ersten begrenzten Aufruf.
