# Index der technischen Deep-Analysis-Drafts

**Stand:** 20. Juli 2026<br>
**Status:** Index des integrierten Authoring-Archivs; nicht kanonisch<br>
**Research-Abdeckung:** 84 von 84 öffentlichen Procedures<br>
**Fachliche Tiefenprüfung nach Qualitätsvertrag v2:** 3 von 84 Procedure-Seiten

## Zweck und Aussagegrenze

Dieser Index dokumentiert Research-Drafts, aus denen Enginehintergrund, Datenquellen, Zeit-/Resetmodelle, Bewertungslogik, Gegenproben und Fehlinterpretationen in die kanonischen Analysis Guides übernommen wurden. Eine vorhandene Research-Section belegt die thematische Erfassung, aber nicht automatisch die vollständige redaktionelle Qualität der kanonischen Einzelseite.

Für die Nutzung gelten [Technical_Foundations.md](../Technical_Foundations.md) und die [Procedure-Seiten](../Procedures/README.md). Den überprüfbaren Reifegrad je Seite definiert der [Qualitätsvertrag](../Documentation_Quality_Contract.md) zusammen mit dem [Review-Manifest](../../../Metadata/Quality/Analysis_Documentation_Review.csv).

## Dateien und Research-Abdeckung

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

## Research-Section-Vertrag

Jede der 84 Research-Sections besitzt Leitfrage, technischen Hintergrund, Datenkette, Zeit-/Scope-Modell, Bewertung und Gegenprobe, typische Fehlinterpretation sowie Folgeanalyse. Diese Felder bilden eine Arbeitsgrundlage.

Erst der Status `DEEP_REVIEWED` bestätigt zusätzlich den Abgleich der kanonischen Seite mit aktuellem T-SQL, sicheren Aufrufen, Resultsetvertrag, konkreter Leserichtung, synthetischen Beispielen, Primärquellen und vollständigem Kosten-/Grenzprofil. Aktuell erfüllen dies:

- [`USP_CurrentRequests`](../Procedures/USP_CurrentRequests.md),
- [`USP_IndexPhysicalStats`](../Procedures/USP_IndexPhysicalStats.md),
- [`USP_ExtendedEventsReadEvents`](../Procedures/USP_ExtendedEventsReadEvents.md).

## Validierter Stand

- aktuelles öffentliches Inventory: 84 Procedures,
- Familien-Research-Sections: 84,
- kanonische Procedure-Seiten: 84 `BASELINE` oder besser,
- fachlich tief geprüfte Referenzseiten: 3,
- Primärquellen-Domain im Authoring-Archiv: ausschließlich `learn.microsoft.com`,
- Beispiele verwenden keine realen Laufzeit-, Benutzer-, Firmen- oder Umgebungswerte,
- die Dokumentationsintegration ändert kein T-SQL-Runtimeverhalten.

Die Draftdateien bleiben als Redaktionsnachweis bestehen, sind aber keine zweite kanonische Referenz. Neue fachliche Freigaben werden ausschließlich über Einzelseite, Qualitätsvertrag, statische Prüfung und Review-Manifest nachvollzogen.
