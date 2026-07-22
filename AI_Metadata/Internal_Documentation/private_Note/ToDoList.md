Ja. Der aktuelle `main`-Stand ist organisatorisch sauber, enthält aber weiterhin mehrere geplante Themenblöcke.



| Priorität         | Themenblock                                             | Status                                                                                                                                                                                                                                                                              |

| ----------------- | ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |

| Nächste Umsetzung | \*\*RUNTIME-001 – External Runtime und SQL CLR\*\*          | Vollständig geplant, aber noch nicht implementiert. Vorgesehen sind `USP\_ExternalRuntimeAnalysis` und `USP\_ClrAnalysis` (\[Plan](https://github.com/gecompat/SQL\_Server\_Analyze/blob/main/Documentation/Architecture/External\_Runtime\_CLR\_Analysis\_Plan.md)).                        |

| P1                | \*\*DIAG-003 – Parameter-Evidenz\*\*                        | Compile-Parameter, verfügbare Runtimeparameter, Provenienz und eindeutige Status für nicht erfassbare Werte fehlen noch.                                                                                                                                                            |

| P2                | \*\*DIAG-004/005 – Request-, Plan- und Optimizerkontext\*\* | Konsolidierter Requestkontext ohne erneute DMV-Lesung sowie zusätzliche Planwarnungen, Runtime Feedback, PSP-/OPPO- und Query-Store-Kontexte fehlen noch.                                                                                                                           |

| P2                | \*\*SQL-Server-2025-Vertiefung\*\*                          | Vector-Index-Laufzeit, JSON-Index-Inventar, TempDB Resource Governance, Statistics auf Readable Secondaries und replica-aware Query Store.                                                                                                                                          |

| P2                | \*\*Zusätzliche Betriebsdiagnosen\*\*                       | Linked Server (`OPS-005`), Datenbankportabilität (`OPS-006`) und `msdb`-Gesundheit/Retention (`OPS-008`).                                                                                                                                                                           |

| P3                | \*\*Kleinere Betriebsdiagnosen\*\*                          | Cursoranalyse (`OPS-007`) und Benutzerobjekte in Systemdatenbanken (`OPS-009`).                                                                                                                                                                                                     |

| Architektur       | \*\*COLL-001 – Collation-Portabilität\*\*                   | Das Framework ist weiterhin nur innerhalb der dokumentierten Collationgrenze freigegeben. Gemischte Server-, `tempdb`-, Framework- und Zieldatenbank-Collations sind noch nicht gehärtet und getestet.                                                                              |

| Persistenz        | \*\*SC-023 – Snapshot/Baseline-Ausbau\*\*                   | Der erste Performance-Counter-Slice ist implementiert. Wait-, I/O-, Datenbank-, Query- und Plan-Collector, Rollups sowie getrennte Scheduler-/Exportpakete fehlen noch.                                                                                                             |

| Extern            | \*\*SC-024 – Fleet Correlation\*\*                          | Design vorhanden; benötigt eine externe zentrale Komponente und eine Isolation-/Transportentscheidung.                                                                                                                                                                              |

| Extern            | \*\*SC-025 – Restore- und Host-Nachweis\*\*                 | Runbook vorhanden; tatsächliche Ausführung benötigt eine autorisierte isolierte Zielumgebung.                                                                                                                                                                                       |

| Nachweise         | \*\*Erweiterte Plattform- und Lasttests\*\*                 | Feature-positive Windows- und Azure-MI-Tests, gemischte Collations, kontrollierte Last-, Soak-, Failover- sowie externe Restore-/Storage-Nachweise fehlen weiterhin (\[Testgrenzen](https://github.com/gecompat/SQL\_Server\_Analyze/blob/main/Documentation/Quality/Test\_Matrix.md)). |



Der maschinenlesbare Future-Backlog enthält derzeit \*\*13 nicht implementierte Einträge\*\*: einen P1-, zehn P2- und zwei P3-Einträge (\[Future Enhancement Backlog](https://github.com/gecompat/SQL\_Server\_Analyze/blob/main/Metadata/Quality/Future\_Enhancement\_Backlog.csv)).



Wichtig: Es gibt aktuell \*\*keine offenen Issues, Pull Requests oder Arbeitsbranches\*\*; ausschließlich `main` ist vorhanden. Die bestehende Special-Case-Testmatrix ist abgeschlossen. Die oben genannten Punkte sind ausdrücklich zukünftige Erweiterungen beziehungsweise zusätzliche Evidence-Klassen, keine unerledigten Arbeiten aus einem offenen PR.



Meine Hauptempfehlung ist, als Nächstes \*\*RUNTIME-001\*\* umzusetzen, weil es im Repository ausdrücklich als nächstes SubProject festgelegt ist. Danach bietet sich `DIAG-003` als fachlich engere Erweiterung der bereits bestehenden Request- und Plananalyse an. Aktueller `main`: \[Commit `424d9281`](https://github.com/gecompat/SQL\_Server\_Analyze/commit/424d928121cd4086a67f358e5d388b92d2a74e55).



