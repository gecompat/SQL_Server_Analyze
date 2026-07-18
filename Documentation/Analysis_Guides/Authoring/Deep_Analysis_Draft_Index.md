# Index der technischen Deep-Analysis-Drafts

**Stand:** 18. Juli 2026  
**Status:** Authoring-Index für Draft-PR #18; nicht kanonisch  
**Aktuelle Abdeckung:** 84 von 84 öffentlichen Procedures

## Zweck

Dieser Index verbindet die konfliktfrei vorbereiteten Research-Drafts. Die Dateien sammeln Enginehintergrund, Datenquellen, Zeit-/Resetmodelle, Bewertungslogik, Gegenproben, Fehlinterpretationen und Primärquellen. Sie werden nach Abschluss paralleler Arbeiten gegen den dann aktuellen `main`-Stand geprüft und abschnittsweise in die kanonischen Analysis Guides integriert.

## Dateien und Abdeckung

| Datei | Inhalt | Procedures |
|---|---|---:|
| [Deep_Analysis_Documentation_Draft.md](Deep_Analysis_Documentation_Draft.md) | didaktisches Gesamtmodell sowie vertiefte Wait-/Query-Store-Wait-Bausteine | Querschnitt |
| [Deep_Analysis_All_Procedures_Research_Draft.md](Deep_Analysis_All_Procedures_Research_Draft.md) | vollständige 84/84-Research-Matrix | 84 |
| [Deep_Analysis_Common_CurrentState_Draft.md](Deep_Analysis_Common_CurrentState_Draft.md) | Access, Capabilities, Scope, Sessions, Requests, Blocking, Waits, Transactions, Grants, TempDB, I/O und Log | 14 |
| [Deep_Analysis_ObjectIndex_PlanCache_Draft.md](Deep_Analysis_ObjectIndex_PlanCache_Draft.md) | Objekte, Indizes, Statistics, Columnstore, Partitions, Physical Stats und Plan Cache/Showplan | 17 |
| [Deep_Analysis_QueryStore_ExtendedEvents_Draft.md](Deep_Analysis_QueryStore_ExtendedEvents_Draft.md) | Query-Store-Intervalle, Runtime, Waits, Planinterventionen sowie XE-Capture/Targets/Events | 15 |
| [Deep_Analysis_Infrastructure_Draft.md](Deep_Analysis_Infrastructure_Draft.md) | Agent, Resource Governor, AG, Backup, Log Shipping, Replication, Data Capture und Maintenance | 13 |
| [Deep_Analysis_ServerHealth_Draft.md](Deep_Analysis_ServerHealth_Draft.md) | CPU/NUMA, Memory, TempDB, Configuration, OS, Security, Integrity, Capacity, Counters und Engine Events | 17 |
| [Deep_Analysis_VersionAdaptive_Draft.md](Deep_Analysis_VersionAdaptive_Draft.md) | Capability Detection, Special Features, In-Memory OLTP, Temporal, Service Broker, Full Text, Data Capture und Encryption | 8 |
| **Familien-Deep-Drafts gesamt** | jede öffentliche Procedure genau einmal | **84** |

## Einheitlicher Section-Vertrag

Jede der 84 Procedure-Sections besitzt:

1. Leitfrage,
2. technischen Hintergrund,
3. konkrete Datenkette aus dem Repository-Systemquelleninventar,
4. Zeit-/Scope-Modell,
5. Bewertung und Gegenprobe,
6. typische Fehlinterpretation,
7. Folgeanalyse.

Die spätere kanonische Einzelpage ergänzt:

- Parameter und sichere Aufrufmuster,
- Resultset-Reihenfolge und Zeilenbedeutung,
- vollständigen RAW-Spaltenkatalog mit Datentypen,
- Quellspalte-zu-Ausgabespalte-Mapping,
- Formeln, Filter, Nenner und Aggregationslogik,
- Berechtigungs-/Versions-/Kostenpfade,
- synthetische Normal-, Problem-, Grenz- und Fehlinterpretationsbeispiele,
- Entscheidungsbaum und geprüfte weiterführende Links.

## Validierter Stand

- aktuelles `main`-Inventory: 84 Procedures,
- Familien-Deep-Drafts: 84 Sections,
- fehlende Procedures: 0,
- doppelte Procedures: 0,
- Section-Vertragsfehler: 0,
- Primärquellen-Domain: ausschließlich `learn.microsoft.com`,
- keine realen Laufzeit-, Benutzer-, Firmen- oder Umgebungswerte,
- keine Änderung bestehender T-SQL-, Test-, Metadaten- oder Dokumentationsdateien.

## Integrationsregel

Die Draft-Dateien werden nicht unverändert nach `main` übernommen. Nach Ende der parallelen Verarbeitung wird jede Familie ausgehend vom aktuellen `main` in kleinen, reviewbaren Änderungen integriert. Gemeinsame Engineerklärungen werden zentral abgelegt und von Procedure-Seiten verlinkt; procedurespezifische Formeln, Resultsets und Beispiele verbleiben bei der jeweiligen Procedure.

## Empfohlene Integrationsreihenfolge

1. gemeinsames Execution-, Zeit- und Evidenzmodell,
2. Common und Current State,
3. Object/Index/Statistics und Plan Cache,
4. Query Store und Extended Events,
5. Infrastructure,
6. Server Health,
7. Version Adaptive,
8. Vollständigkeits-, Link-, Datenschutz- und SQL-Release-Gates.
