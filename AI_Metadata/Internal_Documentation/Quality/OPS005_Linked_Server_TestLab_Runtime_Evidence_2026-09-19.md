# OPS-005 – TestLab-Laufzeitevidenz

**Stand:** 19. September 2026
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
