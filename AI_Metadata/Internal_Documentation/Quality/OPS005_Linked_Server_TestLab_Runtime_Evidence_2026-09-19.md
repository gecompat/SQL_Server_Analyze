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
