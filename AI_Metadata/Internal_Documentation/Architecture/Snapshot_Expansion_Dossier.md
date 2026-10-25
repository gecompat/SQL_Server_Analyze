# Ausbau der lokalen Snapshot- und Baseline-Erfassung

**Stand:** 25. Oktober 2026.
**Status:** Konzept-, Schema-2-Vertrags- und Produktreview bestanden; lokale Schema-2-Abnahme liegt vor. Head-CI, native Paketabnahme und PR-Integration bleiben offen. Die Collectorqualifikation ist nicht Teil dieser Migration.
**Artefakt-UID:** `urn:uuid:01a17312-4ac5-78b9-b77d-536e996e2817`.
**Registrierung:** `DEFERRED`; keine neue finale lesbare Kennung vergeben.
**Bestehende Zuordnung:** SC-023-EXPANSION, Rang 10 der
[Entwicklungswellen](../Quality/Development_Waves_2026-10.md).

## Ausgangslage und nächster Nutzen

Das [optionale Snapshotpaket](../../../Documentation/Architecture/Snapshot_Baseline_Package_Contract.md)
persistiert derzeit ausschließlich Performance-Counter-Evidenz. Configure,
Collection Cycle, Retention, Budgetreaktion, Scopeidentitäten, typisierte
Metriken und Modulstatus sind vorhanden. Wait-/Datei-I/O-Zeitreihen sind
keine bereits ausgelieferte Funktion dieses Pakets.

Die erste Ausbauwelle soll instanzweite Wait-Counter über getrennte lokale
Collection Cycles vergleichen können. Danach folgt Datei-I/O mit eigener
Datenbank-/Dateiidentität. Kapazität, Ressourcendruck, Rollups, Scheduler und
Exporte sind nachfolgende getrennte Schritte. Der Frameworkkern bleibt
zustandslos; neue persistente Daten liegen ausschließlich im ausdrücklich
installierten eigenen Snapshotziel.

Die separate SSIS-Arbeit umfasst aktuell Datenflusskorrelation. Diese Welle
übernimmt weder deren Parser-/Lineagearbeit noch deren erhaltene SSISDB.
Der nächste unabhängige Gesamtauftrag kann Rang 10 bearbeiten, während die
SSIS-Zuständigkeit und ein freier Vergleichsscope weiter abgeglichen werden.
Die gelieferten Sicherheitsbausteine und der erste Endpoint-Slice werden
dabei nicht erneut implementiert.

## Quellen und vorhandene Wiederverwendung

Die nativen Grundquellen sind sys.dm_os_wait_stats und
sys.dm_io_virtual_file_stats. sys.dm_os_sys_info liefert den Engine-Startkontext;
Datenbank- und Dateikataloge liefern getrennte Identitätsbelege. SQL2019
benötigt für die beiden Counterquellen VIEW SERVER STATE, SQL2022+ VIEW SERVER
PERFORMANCE STATE. Sichtbarkeit, Identitätsquellen und Zielschreibrechte
bleiben getrennte Quellen-/Berechtigungsgrenzen.

CurrentWaits besitzt bereits kumulative Instanzwerte und ein begrenztes
lokales Sampling. Seine aktive Tasksicht, SQLtexte, Filter, Benign-Auswahl
und Top-Prozentdarstellung sind jedoch kein vollständiger Persistenzvertrag.
CurrentIO besitzt bereits Datenbankauswahl, native Datei-Caches und lokale
Delta-/Pending-Diagnostik. Die Erweiterung prüft deren wiederverwendbare
Quellen- und Identitätslogik, übernimmt aber keine gefilterte oder gekappte
Darstellung als vollständigen Basiswert. Eine zusätzliche öffentliche
Liveanalyse wird durch diesen Scope nicht begründet.

Die bestehenden Snapshothelper sind derzeit fest an PERFORMANCE_COUNTERS
gebunden. Vor einer Implementierung werden Prepare, Complete, Finalize,
Policy, Installer, Versionsprüfung und Purge gemeinsam angepasst. Ein
zusätzlicher Seed allein aktiviert keinen nutzbaren Collector.

## Reset- und Zeitgrenzen

Microsoft dokumentiert Wait-Counter kumulativ seit Engine-Start oder letztem
Reset. DBCC SQLPERF kann sie ohne Engine-Neustart zurücksetzen. Gleicher
sqlserver_start_time-Wert und monotone Counterschnappschüsse beweisen daher
keine lückenlose Kontinuität: Ein unbeobachteter Reset kann vor der zweiten
Aufnahme durch erneute Zunahme verdeckt werden.

Der Vertrag muss diese Beobachtungsgrenze erhalten. Rohwerte, beobachtete
Differenz und nachgewiesene Kontinuität sind getrennte Aussagen. Ein
monotoner Differenzkandidat darf nur mit ausdrücklich sichtbarer unbewiesener
Resetkontinuität ausgegeben werden; er erhält keinen vorbehaltlosen VALID-
oder Gesundheitsstatus. Reset-sicher bedeutet hier, dass erkannte oder
unbekannte Grenzen nicht als nachgewiesene durchgehende Messung ausgegeben
werden. Die zusätzliche externe Resetkontinuität wird nicht erfunden.

Ein erkannter Neustart, Counterrückgang, fehlender notwendiger Vorwert,
Quellenfehler, Teilaufnahme, Ausgabelimit oder inkompatibler Vertrag verhindert
einen als vergleichbar ausgewiesenen Wert. Eine erkannte globale
Wait-Counterrücksetzung betrifft den gesamten Wait-Aufnahmebereich, nicht
nur den zufällig rückläufigen Waittyp. Fehlende Werte werden nicht als Null
ersetzt. Eine dokumentierte Nullunterdrückung benötigt einen eigenen
Vollständigkeitsbeleg; der erste Slice darf stattdessen FIRST_OBSERVATION
mit unbekannter Differenz liefern.

waiting_tasks_count zählt begonnene Waits, während die DMV abgeschlossene
Waitzeit beschreibt. Wartezeiten über Threads können sich überlappen;
eine Summe ist keine vergangene Wandzeit. max_wait_time_ms ist ein Maximum
und keine additive kumulative Metrik. Eine Differenz von Maxima oder eine
unbelegte durchschnittliche Dauer eines identischen Ereignissatzes wird
nicht als neue Metrik eingeführt.

UTC-Grenzen bezeichnen tatsächliche Aufnahmezeitpunkte. Der native
sqlserver_start_time-Kontext wird als native Engineidentität behandelt und
nicht ohne Zeitzonenbeleg in einen UTC-Zeitpunkt umbenannt. Der vorhandene
Performance-Counter-Adapter schreibt diesen nativen JSON-Kontext derzeit
in SqlServerStartTimeUtc; der neue Collector darf diese Benennung nicht
ungeprüft als UTC-Nachweis übernehmen. Eine nötige kompatible Korrektur wird
vor dem Produktvertrag samt Migration und bestehendem Consumerumfang
festgelegt. Fehlender Startkontext darf keine gemeinsame geratene Epoche
erzeugen.

## Vorgeschlagene erste vertikale Lieferung

Der erste Produktschritt erweitert bestehende Konfigurations- und
Collection-Einstiege um einen ausdrücklich gewählten WAIT_STATS-Collector.
Der bisherige PERFORMANCE_COUNTERS-Pfad bleibt der Default. Pro Aufruf wird
genau ein ausgewählter Collector mit einem CaptureRun verarbeitet; der
skalare CaptureRunIdOut erhält dadurch keine mehrdeutige Bedeutung.
Die genaue additive Parametrierung und Paketversion werden vor dem Code
im typisierten Vorvertrag unabhängig geprüft.

Waittypen bilden lokale technische Scopes. Rohwerte werden als BIGINT mit
festen Metrikcodes, Einheiten, ContractVersion, ResetEpochId und QualityCode
persistiert. SQLtexte, Session-/Clientidentitäten und Nutzdaten gehören nicht
zum neuen Collector. Die Aufnahme liest die native Quelle vor jeder fachlichen
Kappung. MaxRows und Softbudget begrenzen echte Zielwrites; eine dadurch
partielle Aufnahme begründet keinen vollständigen Vergleich. Nur neu
aktivierte eigene Policies starten den neuen Pfad. Payload bleibt standardmäßig
aus und ein vorhandenes Target erhält keine implizite neue Sammlung.

Die Ableitung benötigt zwei vollständig gebundene erfolgreiche Aufnahmen.
Vorherige Werte werden nach Collector, Scope, Metrik, Einheit, Vertrag und
Epoche ausgewählt; parallele oder ältere ungeeignete Läufe werden nicht
still als Vorwert gewählt. Ein UTC-Intervall muss positiv und eindeutig sein.
Die erste Lieferung spezifiziert ausdrücklich, wo nur ein monotoner
Differenzkandidat mit unbekannter Resetkontinuität vorliegt und wo Werte
unterdrückt werden. Ein erfolgreich gespeicherter Rohwert ist kein Beweis
eines qualifizierten Deltas.

## Getrennte Datei-I/O-Fortsetzung

Datei-I/O folgt nach dem Wait-Slice mit dem festen Datenbankauswahlvertrag:
alle sichtbaren zugänglichen ONLINE-Benutzerdatenbanken, optionale
bracket-aware Pipe-Namen und getrenntes Pattern, Systemdatenbanken opt-in;
kein CURRENT-Default oder MaxDatenbanken. Eine native Aufnahme erfolgt
höchstens einmal pro Messzeitpunkt; Pending-I/O, physische Pfade und
zusätzliche Hostproben bleiben außerhalb dieser Persistenzwelle.

Datenbank-ID und Datei-ID allein sind keine dauerhafte Objektidentität.
Neuanlage, Wiederverwendung, Restore, Dateiwechsel, fehlende GUIDs und
geänderte Handles müssen vor Implementierung als eigene Abnahmefälle
festgelegt werden. sample_ms beschreibt Hostuptime und ist kein UTC-
Zeitstempel. size_on_disk_bytes ist ein Gauge; Read-/Write-/Byte-/Stallcounter
besitzen andere Einheiten und dürfen nicht als gleichartige Werte aggregiert
werden. Dateiname oder Laufwerksbuchstabe beweisen keine stabile Identität.

## Migration, Betrieb und Grenzen

Die Erweiterung bleibt optional, lokal und schedulerneutral. Sie erzeugt
keine Datenbank, fremden Benutzer, Rechte oder Agentjobs. Entwicklungstests
installieren und verändern ausschließlich gebundene eigene Labziele.
Versionierte Tabellen, Constraints, Seeds, Properties, Target-/Framework-
Installer und der Gesamtdeploymentweg müssen denselben Stand erkennen.
Unbekannte oder inkompatible Ziele werden vor Fachwrites abgelehnt.

Eine erforderliche Migration bewahrt vorhandene Counterdaten, eigene
Policies und Fremdobjekte. Wiederholung muss idempotent sein; eine fehlende
Spalte oder ein fehlender neuer Helper darf keine halbe Aktivierung erlauben.
Retention bleibt child-first und begrenzt; neue Metriken, Scopes und optionale
Payloads erhalten denselben Lösch- und Budgetpfad. Ein aktiver Run, ein
Purgefehler oder ein fehlgeschlagener Collector darf einen älteren Erfolg
nicht zu einer scheinbar vollständigen neuen Messung machen.

Die Snapshotdatenbank speichert echte Laufzeitwerte innerhalb ihres bestehenden
Datenschutz-, Zugriffs-, Backup- und Löschvertrags. Repositoryartefakte und
Beispiele bleiben synthetisch. Vorhandene Nutzerdaten werden weder exportiert
noch in Entwicklungsartefakte kopiert. Die Erweiterung führt keine automatische
Anonymisierung oder externe Übertragung ein.

## Abnahme und noch festzulegender Feldvertrag

Vor Implementierung werden öffentliche Parameter, Resultsets und JSON-Version,
Paket-/Schemaversion, Collectorcodes, Metrikcodes, ValueType, Unit, QualityCode,
Epochenbildung, Vorwertauswahl und atomare Schreibgrenzen vollständig festgelegt.
Dies ist der nächste konkrete Vertragsabschluss; diese Konzeptseite ist noch
kein eingefrorener öffentlicher API- oder Migrationsvertrag.

Unabhängige typisierte Sollwerte prüfen mindestens frische Installation und
Upgrade mit erhaltenen Performance-Counter-Samples, Default-Opt-out,
explizite Aktivierung, Wiederholung, aktuelle und veraltete Zielversion,
fehlende Rechte, partielle Quelle, native Leerquelle, Writecap, Softbudget,
Retention, parallele Collection und fehlgeschlagene Finalisierung. Zeit-,
Scope-, Einheiten- und Vertragswechsel sowie Reset, fehlender Vorwert,
monotoner Kandidat und verdeckter Reset brauchen getrennte Oracles.
Ein synthetischer Projektionsfall wird nicht als vollständiger nativer
Reset-Fault durch die ganze SUT ausgegeben.

Die primäre Engine ist SQL2025. Zusätzliche native Versionen werden nur am
konkreten Engine-/Berechtigungs-/Schemaschnitt gemäß
[CI-Teststrategie](../../../Documentation/Quality/CI_Test_Strategy.md)
geprüft. Ein Restartszenario oder DBCC-Reset darf ausschließlich eine eigene
isolierte Testinstanz betreffen. Unveränderte bestehende erfolgreiche Gates
werden nicht wegen eines Timers erneut ausgeführt. Ein neuer Collector mit
fehlender nativer Qualifikation bleibt als Teillieferung sichtbar.

## Wait-Spezifikationsentwurf und vorgeschalteter Schema-Vorvertrag

Konzeptreview und Review des vorgeschalteten Migrationsvertrags bestehen.
Die nachfolgende Collectorauswahl bleibt ein Entwurf und ist noch kein
gelieferter Collector. Die vorgeschaltete PackageVersion 1.1.0 führt SchemaVersion 2 ein, ohne
neue persistente Spalte oder Tabelle. Sie erweitert ausschließlich zwei
bekannte CHECK-Domänen und liefert noch keinen Wait-Collector. Der spätere
Collector wird als PackageVersion 1.2.0 mit SchemaVersion 2 konkretisiert. Neue Prozeduren und Seeds sind eine ausdrückliche Installation;
Configure führt kein implizites Upgrade aus. Ein unbekannter Versions- oder
Strukturstand wird vor Änderungen abgelehnt.

### Vorgeschaltete Schemawelle und exakte Altzustände

Die erste Produktwelle dieser Erweiterung implementiert ausschließlich die
Schema- und Deploymentvorbereitung. Der bestehende Performance-Counter-Pfad,
seine öffentlichen Parameter, MetricDefinition-Seeds und CollectorPolicy-
Werte bleiben erhalten. WAIT_STATS-Policy, Waitmetriken und neue Collector-
Helper werden erst mit der nachfolgenden Collectorlieferung installiert.
Die noch offene Typisierung von WAIT_CAPTURE_CONTEXT blockiert deshalb
keinen als Collector ausgegebenen Code in dieser vorgeschalteten Welle.

Die Migration akzeptiert ausschließlich diese bekannten Zustände:

| Paket-/Schemastand | CollectorPolicy-Domäne | Scope-Domäne | Aktion |
|---|---|---|---|
| keine Snapshotobjekte | keine | keine | Frische Installation als 1.1.0 / Schema 2. |
| 1.0.0 / Schema 1 | PERFORMANCE_COUNTERS | SERVER und PERFORMANCE_COUNTER | Datenbewahrende Erweiterung beider bekannten CHECKs. |
| 1.1.0 / Schema 2 | PERFORMANCE_COUNTERS und WAIT_STATS | SERVER, PERFORMANCE_COUNTER und WAIT_TYPE | Idempotente Wiederholung ohne Policy- oder Sampleänderung. |
| anderer, gemischter oder unbekannter Stand | beliebig | beliebig | Ablehnung vor der Migration. |

Die beiden bekannten Constraints heißen
CK_snapshot_CollectorPolicy_CollectorCode und CK_snapshot_Scope_ScopeType.
Beide müssen aktiviert, vertrauenswürdig und nicht NOT FOR REPLICATION sein.
Die genaue semantische Definitionsmenge wird anhand nativer Referenztabellen
verglichen; beliebige zusätzliche Tokens, Werte oder weitere CHECKs werden
nicht als zulässiger Altzustand umgedeutet. Name, Spaltenfacetten, Schlüssel,
Defaults und bestehende übrige Constraints müssen zum bekannten V1- oder
V2-Modell passen. Ein bloß passender Versionswert genügt nicht.

Nur für den vollständig erkannten V1-Zustand werden diese zwei CHECKs in
derselben geschützten Transaktion wie der vollständige Preflight ersetzt
und mit WITH CHECK validiert. Die vorhandenen TABLOCKX-/HOLDLOCK-Sperren
bleiben bis zum Transaktionsende erhalten; zwischen Prüfung und Änderung
wird keine ungeschützte Lücke zugelassen.
Anschließend wird die Paketversion atomar auf 1.1.0 / Schema 2 gesetzt.
Bestehende Samples, Scopes, Collector-/Retentionwerte und fremde Objekte
werden nicht gelöscht oder umgeschrieben. Unbekannte oder widersprüchliche
Struktur führt vor DDL/DML zur Ablehnung; die Migration versucht keine
Reparatur unbekannter Nutzeränderungen. Der Vertragsreview verlangt
gemeinsame Transaktionsbindung und Abbruch über alle Standalone-Batches.
Die konkrete Implementierung wird vor Integration unabhängig geprüft.

Der generierte Gesamtdeploymentweg erkennt zusätzlich zum exakten aktuellen
Modell genau das freigegebene V1-Modell mit diesen beiden abweichenden
Domänen und passender 1.0.0-/Schema-1-Metadatenzeile. Alle anderen Abweichungen
bleiben unzulässig. Die generische Zustandsprüfung wird nicht global gelockert.
Der SQLCMD-Master behält ON ERROR EXIT. Der erzeugte Target-Standaloneweg
muss über Batchgrenzen fail-closed sein: Die kanonischen Batches werden in
einem gemeinsamen bewachten Ausführungsrahmen mit getrennten notwendigen
Kompilationsebenen ausgeführt. Der erste Fehler beendet diesen Rahmen vor
jeder nachfolgenden Quelle. Er verlangt vor eigenen Transaktionsänderungen
TRANCOUNT=0 und IMPLICIT_TRANSACTIONS OFF; eine Callertransaktion wird weder
übernommen noch abgeschlossen. Eine abgelehnte Datenbank muss einschließlich
vorhandener Helperdefinitionen und SET-Metadaten unverändert bleiben. Die
Negativabnahme prüft genau diesen Standaloneweg und nicht nur SQLCMD oder
Gesamtdeployment. Die konkrete Builderumsetzung wird mit dem Produktdiff
geprüft; bloßes Entfernen von ON ERROR EXIT mit anschließender GO-Verkettung
ist für Schema 2 unzulässig.

Die Target-Quelle und der generierte Weg müssen dieselbe bekannte Migration
anwenden. Der direkte Targetweg erhält einen read-only Prüfblock, der aus
dem kanonischen Tabellenmodell und genau dieser Legacy-Auswahl generiert
wird; die erwarteten Spalten-/Schlüssel-/CHECK-Definitionen werden nicht als
zweiter handgepflegter Vertrag geführt. Der Prüfblock wird in einem eindeutig
markierten Bereich der kanonischen Targetquelle gespeichert und durch den
Builder deterministisch auf Synchronität geprüft. Sein Erzeugungshash schließt
diesen Bereich selbst aus. Eine veraltete oder veränderte generierte Prüfung
führt vor Artefakterzeugung zu Ablehnung.

Der Gesamtdeployment-Builder führt bereits seine entsprechende vollständige
Prüfung aus. Er entfernt deshalb ausschließlich diesen exakt erkannten
read-only Bereich aus seinem erzeugten Sourcebatch. Diese statische
Transformation wird im Builder geprüft; es gibt keinen zur Laufzeit durch
einen Caller fälschbaren Skip-Schalter. Die eigentliche Migration bleibt
in beiden Wegen derselbe kanonische Code. Datenbankkontextprüfung und
kritische V1-/V2-Migrationsbedingungen werden nicht entfernt. Pro Route
bleibt genau eine vollständige Strukturvorprüfung; die vorgeschriebene
strikte Nachprüfung des Gesamtdeployments bleibt zusätzlich erhalten. Eine halb erkannte Kombination aus V1- und V2-Domänen gilt nicht
als erfolgreiche frühere Installation.

Abnahme umfasst frische Installation, V1-Upgrade mit eigenen zuvor gespeicherten
Counterwerten und Policies, exakte Wiederholung, Rollback nach einem
kontrollierten Fehler sowie unveränderte fremde Objekte. Negative Kontrollen
prüfen unbekannte Version, zusätzliche Domänenwerte, fehlende beziehungsweise
nicht vertrauenswürdige oder deaktivierte Constraints, weitere CHECKs,
veränderte Spalten und gemischte V1-/V2-Domänen. Unveränderte vollständige
Werte und Struktur werden vor und nach einer abgelehnten Migration verglichen.
Diese Welle behauptet keine Wait-Quelle, Differenz, Reset- oder Collectorabnahme.

Der direkte Targetweg eröffnet bei eigenem Aufruf ohne Ambienttransaktion
eine eigene Transaktion vor dem vollständigen Preflight und beendet sie
erst nach Migration und Versionsabschluss. Innerhalb des generierten Deployments verwendet sie eine lokale
Savepointgrenze und übernimmt weder Commit noch Rollback einer äußeren
Callertransaktion. Bei einem nativen nicht mehr committable äußeren Zustand
wird dieser Fehler weitergegeben; eine pauschale Erhaltungsgarantie nach
jedem DDL-/Enginefehler wird nicht behauptet. Der generierte Installer behält
seinen vorhandenen eigenen vollständigen Rollbackweg.

Die Fehlerabnahme benötigt eine nativ bestätigte eigene Sch-S-only-Sperre
auf Scope, die den TABLOCKX-Preflight zulässt und erst den Sch-M-Zugriff des
zweiten ALTER blockiert. Die Sperrart, ihre eigene Session und der tatsächlich
abgeschlossene erste DDL-Schritt werden beobachtet. Ein vorab gehaltener
Daten-S-Lock genügt nicht, weil bereits der Preflight darauf warten würde.
Der native Fehlerabschluss muss beide CHECKs und die Paketzeile vollständig
zurücknehmen. Der Sperrmechanismus erhält zunächst eine getrennte gebundene
Probe. Ohne diesen Nachweis bleibt die Fehlerabnahme offen; ein kopierter
Projektionsblock oder ein nur behaupteter Zwischenfehler genügt nicht.
Die Wiederholung darf die vorgesehenen Installerzeitmetadaten aktualisieren,
verändert aber keine Sample-, Scope-, Collector- oder Retentionwerte.

Für den gezielten älteren Snapshotnachweis wird der vorhandene manuelle
Native-Matrixworkflow um ein ausdrücklich gewähltes Snapshot-Risikogate
für die einzelne angeforderte Engine erweitert. Bestehende Defaults und
Release-Candidate-Matrizen bleiben erhalten. Der normale zusätzliche
SQL2025-Snapshotlauf wird nicht doppelt ausgeführt. Die geänderte Workflow-
auswahl erhält eigene deterministische Negativ-/Auswahlprüfungen; der
zentrale Installer verlangt weiterhin das volle SQL2025-Gate.

Der nachfolgende Collectorentwurf ist noch nicht freigegebenes Produktverhalten.
Insbesondere benötigt WAIT_CAPTURE_CONTEXT vor Collectorcode einen exakten
JSON-Feldvertrag mit Datentypen, NULL-Regeln, Konsistenzprüfung und vollständiger
Rohsampledeckung. Fehlender, widersprüchlicher oder inkompatibler Kontext
muss Vergleiche sperren. Dieser offene Befund wird nicht durch die separate
Datenbank-Domänenmigration als erledigt ausgegeben.

Der unabhängige Vertragsreview ist nach gezielter Nachprüfung ohne
verbleibende P1-/P2-Befunde für diese vorgeschaltete Migration abgeschlossen.
Die frühere Daten-S-Lock-Annahme und die Standalone-Batchlücke wurden im
Vertrag korrigiert. Dies ist ein Spezifikationsnachweis; ausgeführter
Produktcode, native Sch-S-Probe, Migrations- und Erhaltungsabnahme bleiben
NOT_EXECUTED.

### API und ausdrückliche Aktivierung

ConfigureSnapshotTarget erhält nach seinen bisherigen 19 Parametern:

```sql
    , @CollectorCode varchar(64) = 'PERFORMANCE_COUNTERS'
    , @CollectorEnabled bit = 1
    , @UpdateSharedPolicy bit = NULL
```

RunSnapshotCollectionCycle erhält nach seinen bisherigen 13 Parametern:

```sql
    , @CollectorCode varchar(64) = 'PERFORMANCE_COUNTERS'
```

Steuerwerte werden getrimmt und großgeschrieben. Zulässig sind nur
PERFORMANCE_COUNTERS und WAIT_STATS; NULL oder unbekannte Collectorcodes
sind ungültig. Die bisherigen positionalen Aufrufe und der ausgelieferte
Performance-Counter-Default behalten ihren Verhaltensteil. WAIT_STATS wird
als deaktivierte Policy installiert und ausschließlich ausdrücklich gewählt.

UpdateSharedPolicy=NULL bedeutet für den bisherigen Default 1 und für
WAIT_STATS 0. Mit 0 muss eine passende bestehende Framework-Zielbindung
vorliegen; der Aufruf ändert nur die ausgewählte Collectorpolicy. Gemeinsame
Retention, Zielaktivierung, Zielbindung und Schedulerherkunft bleiben dann
unverändert. Mit ausdrücklich gewähltem 1 dürfen die angegebenen gemeinsamen
Werte im bestehenden Konfigurationsumfang übernommen werden. CollectorEnabled
steuert ausschließlich den ausgewählten Collector. Ein unveränderter Default-
Aufruf aktiviert oder verändert keine WAIT_STATS-Policy.

Ein altes 1.0.0-Ziel bleibt mit dem bisherigen Performance-Counter-Aufruf
nutzbar. Neue Optionen benötigen das bekannte 1.2.0-Ziel mit allen neuen
Objekten und Seeds; der Aufruf lehnt andernfalls mit TARGET_UNAVAILABLE
und präzisem Upgradehinweis ab. Alte Helpersignaturen erhalten im Legacy-
Default keine neu erfundenen Argumente. Ein WAIT_STATS-Aufruf innerhalb
einer Callertransaktion wird vor Fachzugriff oder persistentem Write als
INVALID_PARAMETER mit 51011 abgelehnt. Der Caller behält seine Transaktion,
Optionen und seine unabhängigen Änderungen.

### Ausgaben und neuer Ausführungspfad

Der neue Frameworkhelper monitor.InternalRunSnapshotWaitStatsCycle kapselt
den ausdrücklich gewählten Wait-Pfad. Der Legacy-Pfad des öffentlichen
Collection-Einstiegs bleibt getrennt erhalten. RAW und TABLE behalten die
beiden vorhandenen run-/modules-Schemas; JSON behält ContractVersion 1 mit
run-Objekt und modules-Array. Der CollectorCode im Lauf ist WAIT_STATS.
WAIT_STATS akzeptiert CONSOLE, RAW, TABLE und NONE; optionales JSON bleibt
OUTPUT. Der historische zusätzliche Ausgabeartwert JSON gilt allein für
den bisherigen Performance-Counter-Pfad.

CONSOLE des Wait-Pfads verwendet ein gemeinsames Grid aus Run und Modulstatus
mit dem kanonischen Renderer. Die native Quelltabelle enthält Scope
nvarchar(32) NOT NULL, CaptureRunId bigint NULL, CollectorCode varchar(64)
NULL, ModuleName sysname NULL, StatusCode varchar(40) NOT NULL, IsPartial
bit NOT NULL und Detail nvarchar(max) NOT NULL. Alle Textspalten verwenden
SQL_Latin1_General_CP1_CS_AS. Der Renderer ergänzt sein vorhandenes Ergebnisfeld.
Das Grid erhält Quellenfehler auch neben erhaltenem Run-Kontext.

Ungültige neue API-/TABLE-Parameter liefern regulären Diagnose-RETURN 51011,
Status und Fehler-OUTPUT sowie JSON-NULL. Vor Fachzugriff wird die gemeinsame
benannte TABLE-Zuordnung geprüft. Erwartete native Quellenfehler liefern einen
materialisierten Run-/Modulbericht mit RETURN 0; Status und Fehler-OUTPUT sind
maßgeblich. Vor erstem Zielwrite fehlgeschlagene Validierung erzeugt keinen
CaptureRun. Ein gefangener Writefehler liefert keine erfundene erfolgreiche
Finalisierung. Hilfe, Source-Opt-out und abgelehnte Ziele öffnen keine Quelle.

### Native Aufnahme und transienter Vertrag

sys.dm_os_wait_stats wird einmal vollständig in einen eigenen Cache gelesen.
Die SQL2025-Vorprobe bestätigt WaitType nvarchar(60) sowie WaitingTasksCount,
WaitTimeMs, MaxWaitTimeMs und SignalWaitTimeMs als bigint, jeweils NOT NULL.
Die Startfelder sind sqlserver_start_time datetime und
sqlserver_start_time_ms_ticks bigint, jeweils NOT NULL. Die Charakterisierung
endete absichtlich mit 57355 und eigenem erfolgreichen Labcleanup; sie ist
keine Produktabnahme.

Vor und nach dem Counterread werden native Startidentität und ServerName
verglichen. Die Identität besteht aus nativem ServerName, lokalem
sqlserver_start_time und sqlserver_start_time_ms_ticks. NULL-Kontext,
Kontextwechsel, negative Counter oder doppelte Waittypen sind keine gültige
Aufnahme. Der lokale Startzeitpunkt ist ausdrücklich keine UTC-Zeit.
WAIT_STATS lässt CaptureRun.SqlServerStartTimeUtc NULL und hält die native
Identität im versionierten Kontext. Der Performance-Counter-v1-Wert wird
weder nachträglich geraten noch umgerechnet; dessen historische Feldbenennung
bleibt als bekannte Grenze dokumentiert.

Der transiente interne JSON-Vertrag besitzt SchemaVersion 1 und resultName
SnapshotWaitStats. meta enthält measurementStartUtc, measurementEndUtc,
statusCode, isPartial, errorNumber, errorMessage, nativeRows, sourceComplete
und engineContext. engineContext enthält serverName, sqlServerStartTimeLocal
und sqlServerStartTimeMsTicks. waits enthält die fünf oben genannten Felder
mit exakter Groß-/Kleinschreibung. Ein fehlgeschlagener Read besitzt unbekannte
Counts und keine behauptete vollständige waits-Menge. Ein leerer nativer
Katalog erhält EMPTY_UNPROVEN. Explizite Quellencounter bleiben unverändert;
Timeouts werden nicht in Wiederholungsschleifen versteckt.

### Persistenz, Vorwerte und Qualitätscodes

Der neue Targethelper snapshot.InternalCompleteWaitStatsCycle schreibt nur
einen bereits eröffneten WAIT_STATS-Run. Ziel-ID, Zielname und create_date
werden vor Targetaufruf erfasst und im tatsächlichen Targetkontext vor
Writes erneut geprüft. Eine unbekannte oder geänderte Bindung erzeugt
keinen Fremdwrite. Diese Guards sind keine globale atomare Rename-/Restore-
Garantie. Ziel und vorheriger Lauf müssen denselben lokalen Paketvertrag
und denselben Collector besitzen.

Die folgenden neuen Metrikdefinitionen besitzen ContractVersion 1:

| MetricCode | ValueType | Unit | Bedeutung |
|---|---|---|---|
| WAIT_TASK_COUNT | BIGINT | count | Nativer kumulativer waiting_tasks_count. |
| WAIT_TIME_MS | BIGINT | ms | Native kumulative gesamte Waitzeit. |
| WAIT_SIGNAL_TIME_MS | BIGINT | ms | Native kumulative Signalwaitzeit. |
| WAIT_MAX_TIME_MS | BIGINT | ms | Native Maximalzeit; kein additiver Counter. |
| WAIT_TASK_COUNT_DELTA_CANDIDATE | BIGINT | count | Monotone Differenz mit unbewiesener Resetkontinuität. |
| WAIT_TIME_MS_DELTA_CANDIDATE | BIGINT | ms | Entsprechender Waitzeitkandidat. |
| WAIT_SIGNAL_TIME_MS_DELTA_CANDIDATE | BIGINT | ms | Entsprechender Signalzeitkandidat. |
| WAIT_DELTA_STATUS | STRING | status | Expliziter Grund für Kandidat oder Unterdrückung. |
| WAIT_CAPTURE_CONTEXT | STRING | json | Versionierter Aufnahme-/Vergleichskontext auf SERVER-Scope. |

Waittypen besitzen ScopeType WAIT_TYPE unter dem vorhandenen lokalen SERVER-
Scope. Scopeidentität und Hash entstehen aus exakt gebundenem Waittyp;
Metrik, Einheit, Version und ResetEpochId bleiben getrennte Vergleichsschlüssel.
WAIT_CAPTURE_CONTEXT enthält Engineidentität, Aufnahmezeiten, native und
persistierte Counts, Kappung, Vorwert-Run und die Epochenentscheidung. Sein
SchemaVersion-1-JSON bleibt unter der vorhandenen StringValue-Grenze von
4000 Zeichen. Eine Überschreitung führt zu Ablehnung statt Abschneiden.

Persistiert werden aktive Waittypen mit mindestens einem positiven Counter
sowie die Waittypen der unmittelbar vorherigen Aufnahme, soweit sie aktuell
nativ vorhanden sind. Der vollständige native Cache bleibt für Reset- und
Fehlwertprüfungen verfügbar. Fehlende Native-Waittypen werden nicht mit Null
aufgefüllt. Ein bisher nicht gespeicherter Typ erhält FIRST_OBSERVATION;
der erste Vergleich erfindet keinen früheren Nullwert. Native vollständig
beobachtete Nullzeilen für vorherige Scopes dürfen als echte Nullwerte
persistiert werden.

MaxRows begrenzt gespeicherte Waittypen, nicht Datenbanken oder den nativen
Read. Pro gespeicherten Typ entstehen vier Rohwerte, ein Status und höchstens
drei Kandidaten; hinzu kommt höchstens ein Aufnahmekontext. Die Schranke lautet
8*MaxRows+1 MetricSamples. Bei Kappung wird kein vollständiger Vergleich
behauptet; die stabil nach Waittyp ausgewählten Rohwerte und Counts bleiben
als partiell gekennzeichnete Evidenz erhalten. Softbudget, Retention und
Payloadpolicy gelten zusätzlich. Payload bleibt defaultmäßig deaktiviert.

Als Vergleichsbasis dient ausschließlich der unmittelbar vorherige finalisierte
WAIT_STATS-Run, nicht still ein älterer grüner Lauf. Er muss denselben Kontext,
dieselbe Metrikversion und eine vollständige nicht gekappte Aufnahme besitzen.
Eine fehlgeschlagene oder technisch partielle Zwischenaufnahme unterbricht
den Vergleich. Die rein fachliche Kennzeichnung der Kandidaten als
IsPartial=1 wird dabei nicht mit unvollständigem SourceRead oder Writecap
verwechselt: sourceComplete, Kappung und finalisierte Rohsampledeckung im
WAIT_CAPTURE_CONTEXT bestimmen die technische Vollständigkeit.
Das aktuelle UTC-Messfenster darf nicht vor dem vorherigen Ende beginnen;
die Endzeitdifferenz muss positiv sein. Keine Rate und kein Mittelwert wird
aus den Kandidaten abgeleitet.

Bei gleicher beobachteter Engineidentität und monotonen vollständigen Countern
bleibt die Epoche erhalten; Kandidaten erhalten QualityCode und Status
MONOTONIC_CONTINUITY_UNPROVEN mit IsPartial=1. Raw-Quality bleibt davon
getrennt MEASURED_CUMULATIVE. Der erste Lauf, Kontextwechsel, nichtpositive
Zeit, Kappung oder fehlende Basis unterdrücken Kandidatmetriken und erhalten
FIRST_OBSERVATION, ENGINE_CONTEXT_CHANGED, INTERVAL_NOT_POSITIVE,
WRITE_LIMITED, PREVIOUS_CAPTURE_PARTIAL oder PREVIOUS_CAPTURE_MISSING.
Ein fehlender früherer Typ erhält FIRST_OBSERVATION. Ein fehlender notwendiger
aktueller Typ unterbricht den gesamten Vergleich mit WAIT_TYPE_MISSING.

Ein Counterrückgang einschließlich MaxWaitTimeMs erzeugt für den ganzen
Wait-Aufnahmebereich COUNTER_DECREASE und eine neue Epoche; alle Kandidaten
bleiben unterdrückt. Diese Klassifikation beweist keine einzelne Resetursache.
Bei unbekanntem Enginekontext entsteht keine geratene gemeinsame Epoche und
kein MetricSample, dessen notwendige EpochId nur erfunden wäre. Ein neuer
beobachteter Kontext erhält erst nach erfolgreicher Aufnahme eine eigene
EpochId. Unbekannte Kandidaten werden wegen des ExactlyOneValue-Vertrags
nicht als NULL-Samples eingefügt: der Status ist vorhanden, die entsprechende
numerische Kandidatmetrik fehlt. Die fehlende Metrik bedeutet nicht Null.

### Atomarität, Betrieb und Abnahmegrenzen

Der neue Collection-Pfad prüft Aktivierung und Fälligkeit vor SourceRead und
vor neuem Purge-/Capturewrite. RunEvenIfNotDue umgeht ausschließlich Fälligkeit.
Eine gemeinsame Session-Applock mit Wartezeit 0 serialisiert alle Collector.
Der Wait-Slice berücksichtigt jeden finalisierten vorherigen Wait-Lauf für
Intervall und Vergleichsauswahl, auch einen fehlgeschlagenen; Force kann
explizit früher erneut messen. Der bestehende Performance-Counter-Intervallpfad
behält sein bisheriges Verhalten.

Der Targethelper schreibt Scopes, Samples und Modulstatus für seinen Run in
einer eigenen kurzen Transaktion. Ein Writefehler rollt nur diese eigene
Transaktion zurück; die Fehlerfinalisierung bleibt sichtbar, soweit die
Zielrechte dies erlauben. Unfinalisierte Läufe werden nicht zu Vorwerten.
Erfolg und Fehler geben die Session-Applock frei und erhalten Calleroptionen.
Quelle, Budgetstop, Versionsablehnung und leere/partielle Daten besitzen
getrennte Oracles; ein erlaubter Erfolg bedeutet keine tatsächliche Kontrolle
über konkurrierende Administratoraktionen.

Upgrade, Wiederholung, Opt-out und eigene Policies werden nativ mit zuvor
geschriebenen Performance-Counter-Samples geprüft. Alte Paket- und Helper-
Signaturen bleiben im Default nutzbar. Die neuen Metrikseeds dürfen bestehende
abweichende Definitionen nicht blind überschreiben. Kollisionen, unbekannte
Versionen oder fremde Zielstruktur erzeugen vor Änderungen einen konkreten
Konflikt. Die gespeicherten Differenzkandidaten können nach Retention ihrer
älteren Basis nicht mehr vollständig aus den Rohsamples nachgerechnet werden;
der erhaltene Kontext ist Provenienz und keine zugesagte ewige Reproduzierbarkeit.

Ein tatsächliches DBCC-Wait-Reset ist eine globale Engineaktion und gehört
nicht automatisch in den allgemein ausführbaren Release-SQL-Runner. Seine
Ende-zu-Ende-Abnahme benötigt eine getrennt nachgewiesene eigene isolierte
Labinstanz und ausdrückliches Reset-Opt-in. Die normale Fixture prüft
konstruierte Vergleichsstufen getrennt von der vollständigen SUT. Ein solcher
Stufenfall wird nicht als nativer Engine-Reset ausgegeben. Der neue Collector
selbst führt keinen Reset, Restart oder Hosteingriff aus.

Die Target-Quellen verwenden bereits den ausdrücklich gewählten und im ersten
Targetskript geprüften Installationskontext. Der allgemeine USE-Satz im
Projektkontext widerspricht diesem bestehenden Paketweg. Dieser begrenzte
TARGET_INTERNAL_CONFLICT wird vor der neuen Targetquelle durch eine enge
nachvollziehbare Ausnahme für den kanonischen Targetinstaller und seine
Targetquellen aufgelöst; gewöhnliche Frameworkquellen behalten ihren USE-
Header. Die Ausnahme erweitert keine Datenbankauswahl oder Runtimeberechtigung.

## Primärquellen

- Microsoft Learn: [Wait-Stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-os-wait-stats-transact-sql?view=sql-server-ver17).
- Microsoft Learn: [Datei-I/O-Stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-io-virtual-file-stats-transact-sql?view=sql-server-ver17).

- Microsoft Learn: [Engine-Startkontext](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-os-sys-info-transact-sql?view=sql-server-ver17).


## Schema-2-Implementierungskandidat

Der aktuelle Änderungskandidat enthält ausschließlich die vorgeschaltete
Migration und ihre drei Installationswege. Lokal bestehen auf SQL2025 die
frische Installation, die Wiederholung und das Upgrade aus dem zuvor gesicherten
tatsächlichen 1.0.0-Targetskript mit erhaltenen Counterdaten und Policies.
Der fokussierte native Deploymentvertrag besteht für drei gefüllte V1-Upgrades,
drei Wiederholungen und 19 gezielte Versions-/Strukturablehnungen. Die nachfolgenden
Callertransaktionsfälle werden am Korrekturstand gesondert nachgewiesen. Eine frühere Fixture-
Wiederherstellung versuchte einen fehlenden CHECK erneut zu löschen; dieser
Testfehler ist korrigiert. Der separate frühere 1222 vor Migration bleibt ohne
behauptete Sperrursache sichtbar.

Die eigene native Sch-S-Abnahme besteht mit dem tatsächlichen kanonischen
Targetbatch auf SQL Server 2025, ProductVersion 17.0.4075.5. Der erste CHECK-
Austausch ist über CompletedStage=1 belegt, der zweite Schritt scheitert mit
1222. Alle zehn Tabellendaten und CHECK-Definitionen bleiben nach Rollback
unverändert; die anschließende Wiederholung migriert erfolgreich. Cleanup
bestätigt die Entfernung der eigenen Container- und Volumeressourcen.
Das ist eine lokale Abnahme des benannten Kandidaten, kein Main-, PR- oder
SQL2019-Nachweis. Unabhängiger Produktreview, vollständiges SQL2025-Gate,
gezielte native SQL2019-Abnahme und reguläre PR-Integration bleiben offen.


Der Produktreview des ersten Kandidaten benennt zwei P2-Befunde: Der
Versionsread musste seine PackageVersion-Sperre bereits vor Klassifikation
halten; außerdem fehlte dem Standalone-Rahmen der gemeinsame ANSI-/
QUOTED_IDENTIFIER-/LOCK_TIMEOUT-Kontext für spätere Helperkompilationen.
Der gebündelte Korrekturpass bindet die Versionszeile zuerst mit
TABLOCKX/HOLDLOCK und setzt den kanonischen begrenzten Kompilationskontext
nach der frühen Callerablehnung. Ein positiver Gegenfall beginnt mit
QUOTED_IDENTIFIER OFF und LOCK_TIMEOUT -1 und verlangt korrekte gespeicherte
SET-Metadaten aller fünf Helper. Die frühe Ablehnung verwendet wie das
Gesamtdeployment einen getrennten XACT_ABORT-OFF-/RAISERROR-Rahmen. Der
neue Callerfall hatte zuvor den Zustand nach erwarteter Ablehnung verletzt;
sein Oracle bleibt unverändert. Folgeprüfung und native Wiederholung dieses
Korrekturstands sind noch offen.


### Abschlussstand des lokalen Korrekturpasses

Der unabhängige Folgecheck schließt beide P2 und den eng begrenzten
Callerablehnungsfix ohne neue Befunde. Die vollständige lokale Suite besteht
am ersten Kandidaten mit 74 Validatoren; alle 19 betroffenen Deployment-
Grammarprüfungen bestehen erneut am Korrekturstand. Metadaten-/Tempnamen-,
Snapshotvertrags-, Stil-, Privacy- und Regelkontextprüfung bestehen. Der
Datenschutzselbsttest besteht ebenfalls; der neue Testdatenbankkontext ist
als exakt pfad-/wertgebundener synthetischer Kontext klassifiziert.

Der korrigierte native SQL2025-Vertrag besteht für drei reale Installationswege,
V1-Upgrades, Wiederholungen, 19 Struktur-/Versionskonflikte sowie die zusätzlichen
Caller- und abweichenden Kompilationsoptionen. Der eigene Lab-Cleanup ist
bestätigt. Der korrigierte kanonische Fehlerlauf besteht auf SQL Server 2019,
ProductVersion 15.0.4480.2, einschließlich Stage 1, nativem Fehler 1222,
Rollback aller zehn Tabellen und CHECKs, Recovery und Cleanup. Die lokale
Batchbindung lautet 2427938116a1ac158c17216427bc364d5f8bb53311dd265b1ba2424b7e14bb5c.
Das frühere 53817 des Standalone-Callerfalls bleibt als fehlgeschlagener
Vorstand erhalten; sein unverändertes Oracle besteht nach der Korrektur.

Die reguläre vollständige SQL2025-Head-CI und das gezielt gewählte native
SQL2019-Snapshot-/Migrationsrisikogate sind noch auszuführen. Lokale Ergebnisse
ersetzen diese Required Checks nicht. WAIT_CAPTURE_CONTEXT und der spätere
Wait-Collector bleiben offen; neue WAIT-Policies oder Metriken werden mit
dieser Welle nicht geliefert.


### Erstes Remote-Paketgate und Installerkontextkorrektur

Das native SQL2019-Paketgate 40207013284 besteht am Lieferkandidaten f31f9fae
mit tatsächlicher Snapshot-/Migrationsrisikoauswahl. Paketvalidierung,
Core-Release-Gate, Berechtigungen, gefülltes Deployment, Snapshot- und
Nebenläufigkeitsverträge sowie Cleanup bestehen. Dieser Erfolg gehört zu
diesem Head und wird nicht still auf einen späteren Paketdigest übertragen.

Die Dokumentations-CI desselben Heads scheitert im unveränderten allgemeinen
Standalone-Installertest 191. Drei bereits in der Basis vorhandene Quellen
hatten unmittelbar nach dem führenden GO keine Leerzeile; der bestehende
Builder entfernte deshalb ihre USE-Header nicht. Je eine zusätzliche Leerzeile
in CurrentCallerPermissionAnalysis, InternalSsisScopePathMatch und
InternalSsisExecutionScopes stellt den vorgesehenen einen Installerkontext
her. Der lokale Tokenvergleich belegt identisches ausführbares T-SQL; der
unabhängige mechanische Delta-Review bestätigt dies. Die unveränderten
Installertests 191, 192 und 194 bestehen danach. Der frühere Fehllauf bleibt
erhalten; neue erforderliche Gates binden den korrigierten Lieferhead.


Die folgende CI erkennt den noch nicht neu erzeugten versionierten OPS-005-
Installer. Der vorgesehene Adapter-Builder aktualisiert ihn um genau sechs
entfallende redundante USE-/GO-Zeilen aus den drei korrigierten Quellen.
Sein unveränderter strenger Quellenvergleich besteht danach mit acht
Repräsentationsfällen. Der Test wurde nicht abgeschwächt; das abgeleitete
Artefakt und die kanonischen Quellen werden gemeinsam geliefert.
