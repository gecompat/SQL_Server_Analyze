# Ausbau der lokalen Snapshot- und Baseline-Erfassung

**Stand:** 25. Oktober 2026.
**Status:** konkretisierter nächster unabhängiger Scope; Vertragsreview und Implementierung offen.
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

## Primärquellen

- Microsoft Learn: [Wait-Stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-os-wait-stats-transact-sql?view=sql-server-ver17).
- Microsoft Learn: [Datei-I/O-Stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-io-virtual-file-stats-transact-sql?view=sql-server-ver17).
