# Index der technischen Deep-Analysis-Drafts

**Stand:** 20. Juli 2026
**Status:** Index des integrierten Authoring-Archivs; nicht kanonisch
**Integrierte Abdeckung:** 84 von 84 öffentlichen Procedures

## Zweck

Dieser Index dokumentiert die Research-Drafts, aus denen Enginehintergrund, Datenquellen, Zeit-/Resetmodelle, Bewertungslogik, Gegenproben und Fehlinterpretationen in die kanonischen Analysis Guides übernommen wurden. Für Nutzung und Pflege gelten [Technical_Foundations.md](../Technical_Foundations.md) und die [Procedure-Seiten](../Procedures/README.md).

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

Die kanonische Einzelpage verbindet diese Felder mit:

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
- keine Änderung des T-SQL-Runtimeverhaltens durch die Dokumentationsintegration.

## Integrationsstand

1. Das gemeinsame Execution-, Zeit- und Evidenzmodell ist in [Technical_Foundations.md](../Technical_Foundations.md) kanonisch.
2. Alle 84 Procedure-Seiten besitzen die sieben procedurespezifischen Vertiefungsfelder.
3. Bestehende sichere Aufrufe, Zeilenbedeutungen, Beispiele, Leer-/Partialgrenzen und Familienlinks blieben erhalten.
4. Die Dateien in diesem Verzeichnis bleiben als Redaktionsnachweis bestehen, sind aber keine zweite kanonische Referenz.
5. Historische Roadmaps und offene Arbeitspakete sind als abgeschlossen gekennzeichnet; neue Recherche entsteht ausschließlich über die dokumentierten Änderungs- und Versionsauslöser.
6. Kanonische Seiten verweisen nicht mehr auf Draftdateien. Versionsabhängige Aussagen werden in der [Versions- und Primärquellenmatrix](../Version_Primary_Source_Matrix.md) nachgewiesen.
