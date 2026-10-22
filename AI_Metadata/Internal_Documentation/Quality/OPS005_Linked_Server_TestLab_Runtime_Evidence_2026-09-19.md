# OPS-005 – TestLab-Laufzeitevidenz

**Stand:** 22. Oktober 2026
**Status:** `LOCAL_TESTLAB_RUNTIME_EVIDENCE`
**Datenbasis:** ausschließlich synthetische Fixtures

## Umfang

Der Adapter `TestLab/Adapters/OPS-005` erzeugte je Zielversion einen neuen,
scopegebundenen Docker-Lab-Run. Er installierte den kanonischen
SQL_Server_Analyze-Frameworkbestand in `LabAnalyze`, führte den
kanonischen Runtimevertrag `120_OPS005_Linked_Server_Runtime_Contract.sql`
aus, validierte dessen Marker und entfernte anschließend die
Adapterdatenbank sowie den zugehörigen Container und das zugehörige Volume.

Die Fixture prüft lokales Linked-Server-Inventar ohne Remotezugriff, die
doppelte Opt-in-Grenze, einen synthetischen nicht erreichbaren Endpunkt und
einen denied-permission-Fall. Sie verwendet keine realen Remoteendpunkte,
Passwörter oder Betriebsdaten. Die SA-Passwörter wurden für jeden Run im
Arbeitsspeicher erzeugt; Run-IDs, Ports, Containerbezeichner und vollständige
Laufzeitlogs sind nicht Teil der Repositoryevidenz.

| SQL Server | Plattform | Ergebnis | Adapter- und Infrastruktur-Cleanup |
|---|---|---|---|
| 2019 | Linux-Container über Docker | `PASS` | `REMOVED` |
| 2022 | Linux-Container über Docker | `PASS` | `REMOVED` |
| 2025 | Linux-Container über Docker | `PASS` | `REMOVED` |

## Aussagegrenze

Die Ergebnisse belegen nur den beschriebenen synthetischen
MSOLEDBSQL-Vertragsumfang auf den drei nativen Linux-Engines. Sie belegen
keinen erfolgreichen Zugriff auf ein reales Remotesystem, keine
providerübergreifende Konnektivität, keine Remoteanmeldungsdelegation und
keine Produktionsdaten- oder Betriebsumgebung.

## Ergänzender lokaler Verbindungsnachweis vom 5. Oktober 2026

Der Runner `TestLab/Invoke-Ops005LinkedServerSuccessScenario.ps1` erzeugte
zwei neue SQL-Server-2025-Linux-Container über Docker Desktop. Die Instanzen
verwendeten `Latin1_General_100_CS_AS`, die Frameworkdatenbank
`SQL_Latin1_General_CP1_CS_AS`. Der Framework-Smoke-Test sowie die
Runtimeverträge `120` und `121` bestanden. Anschließend bestand der gesonderte
Vertrag `TestLab/Adapters/OPS-005/sql/connectivity-success.sql` mit einem
synthetischen `MSOLEDBSQL`-Linked-Server und eigenem Remote-Login.

Der Standardpfad lieferte `NOT_EXECUTED`; ohne zweite Bestätigung lieferte
der Analyzer `AUTHORIZATION_REQUIRED`. Mit beiden Schaltern lieferte der
einzelne Fixture-Eintrag `SUCCEEDED`, der Gesamtaufruf `AVAILABLE` und
`IsPartial = 0`. Die Quelle meldete ProductVersion `17.0.4075.5`.
Die Verbindung verwendete obligatorische Verschlüsselung und vertraute
dem Zertifikat des neuen Testcontainers. Beide Lab-Runs einschließlich
Container, Volumes und temporärem State wurden entfernt.

Dieser ergänzende Lauf belegt den tatsächlichen Verbindungsaufbau für die
beschriebene SQL-Server-2025- und MSOLEDBSQL-Kombination. Weitere Provider,
native ältere Engines im Erfolgspfad, Delegation, verteilte Transaktionen
und fachliche Remoteabfragen bleiben außerhalb dieses Nachweises. Er ist
kein vollständiger Release-Gate-Lauf. Secrets, Laufzeitidentitäten und
vollständige Logs wurden nicht in das Repository übernommen.

## Windows-Provider-Negativfall vom 22. Oktober 2026

Der begrenzte Worker `TestLab/Invoke-Ops005UnavailableProviderScenario.ps1`
bestand am Analyze-Stand `7a578c85` mit integriertem Lab-Stand `1095f5ee`.
Ein eigener Hyper-V-Run verwendete das vorhandene schreibgeschützte
Prepared-Image mit vier vCPUs und acht GiB festem RAM. Die tatsächliche
Engine war SQL Server `17.0.1000.7`, Enterprise Developer Edition, auf Windows
mit CL170. Server, `master`, `tempdb` und Frameworkdatenbank verwendeten
`SQL_Latin1_General_CP1_CS_AS`. Die reservierte Gastadresse und eigene aktive
Lease waren vor den Consumerbatches gebunden.

Die kanonische Installation bestand in zwei Teilen mit 153 und 41 Batches.
Vor der Provideranlage bestätigte der Guard den ursprünglichen vollständigen
SHA-256 der normalisierten Prozedurdefinition und die unveränderte
13-Parameter-ABI. Die eng begrenzte Deklarationsnormalisierung wurde damit
nativ abgenommen. Genau eine synthetische Fixture eines nicht registrierten
OLE-DB-Providers wurde erzeugt und anhand ihrer Katalogidentität geprüft.

| Fall | Connectivity / HighImpact | Globaler Status | Partialität | JSON / Connectivity |
|---|---|---|---|---|
| Lokales Inventar | `0 / 0` | `AVAILABLE` | `0` | eine Fixturezeile, `NOT_EXECUTED` |
| Bestätigung ohne Connectivity | `0 / 1` | `AVAILABLE` | `0` | eine Fixturezeile, `NOT_EXECUTED` |
| Fehlende zweite Bestätigung | `1 / 0` | `AUTHORIZATION_REQUIRED` | `1` | eine Fixturezeile, `AUTHORIZATION_REQUIRED` |
| Nicht registrierter Provider | `1 / 1` | `AVAILABLE_LIMITED` | `1` | eine Fixturezeile, `FAILED` und `SOURCE_UNAVAILABLE` |
| Nach Fixtureentfernung | `0 / 0` | `AVAILABLE_EMPTY` | `0` | `[]` |

Der vierte Fall verwendete genau eine vorgeschaltete native Provider-Vorprobe.
Sie meldete Fehler 7403; Analyzerfehlernummer und gebundener Evidenzpräfix
stimmten damit überein. Alle fünf Aufrufe erhielten Locktimeout,
Sessionoptionen und Transaktionszahl. Das Oracle prüfte das JSON-Schema,
Zeilenanzahl, Katalogwerte, Status, Partialität und Fehleroutputs.

Die Providerfixture, die eigene markierte Datenbank, VM und Child-Disk waren
nach dem Lauf entfernt. Es blieb keine aktive eigene Lease zurück.
Schreibschutz und vollständiger Parenthash waren unverändert. Der
abschließende Workerbericht meldete `PASSED`.

Frühere fehlgeschlagene Windows-Einstiege und die rein lesende Diagnose von
54890, State 5, bleiben als getrennte private Belege erhalten. Die genaue
gespeicherte Headerform wurde im Diagnoserun nicht vollständig ausgegeben;
der Abnahmelauf belegt die kanonische Hashprüfung nach der begrenzten
Normalisierung. Der Linuxvertrag 120 und sein Adapter sowie Produktquellen
und Reifeflags wurden nicht geändert. Diese Windows-Abnahme belegt weder
weitere Provider und Rollen noch Delegation, verteilte Transaktionen,
Remotedatenabfragen oder ein vollständiges Release-Gate. Laufzeitidentitäten,
Hostdaten, Secrets und Rohlogs bleiben außerhalb des Repositorys.
