# Nächste Arbeitsschritte

**Stand:** 7. Oktober 2026
**Zweck:** aktuelle ausführbare Entwicklungswelle für `gecompat/SQL_Server_Analyze`

## Maßgeblichkeit

Die [langfristige Weiterentwicklungsroadmap](../Architecture/Long_Term_Development_Roadmap.md) ordnet alle späteren Entwicklungsrichtungen, Abhängigkeiten und Exit-Kriterien. Dieses Dokument enthält ausschließlich den aktuellen Produktstand und die nächste ausführbare Welle.

Die Statusquellen besitzen getrennte Aufgaben:

- `Metadata/Quality/Implementation_Status.csv` trennt gelieferten und offenen Umfang je Arbeitselement.
- `Metadata/Inventory/Module_Maturity.csv` beschreibt sichtbare Modulreife und fehlende Evidenz.
- `Metadata/Quality/Test_Matrix.csv` dokumentiert tatsächlich ausgeführte Laufzeitnachweise.
- `Metadata/Quality/Future_Enhancement_Backlog.csv` enthält priorisierte noch nicht implementierte oder unvollständige Erweiterungen.

Ein vorhandener SQL-Quellpfad oder ein grüner statischer Vertrag ersetzt keinen dokumentierten Laufzeitnachweis.

## Auftrag zur autonomen Fortsetzung

Der Benutzer hat am 5. Oktober 2026 die autonome Entwicklung beauftragt und
die bereits in SQL_Server_Toolbelt und SQL_Server_Lab verwendeten
Autonomieregeln ausdrücklich herangezogen. Die Arbeit verwendet weiterhin
die vorhandene Roadmap und Statusquellen. Jeder kohärente Schritt umfasst
die betroffenen Verträge, Implementierung, Dokumentation und Tests. Es gibt
genau einen Implementierer je Schritt; ein unabhängiger Review prüft den
stabilen Stand. Vor der Fortsetzung werden `origin/main`, offene Pull Requests,
Regelkontext und vorhandene Evidenz abgeglichen. Geprüfte Schritte werden
über einen Pull Request mit erfolgreicher erforderlicher Head-CI integriert;
danach folgen Synchronisierung und ausschließlich eigener Cleanup. Nach
dem bestätigten PR-Merge nach `origin/main` werden auch die integrierten
lokalen Arbeitsbranches entfernt; der aktive Entwicklungsbranch bleibt erhalten.

Die bestehenden Produkt-, Datenschutz- und Testregeln dieses Repositorys
bleiben maßgeblich. Neue öffentliche Funktionsverträge werden vor ihrer
Implementierung konkretisiert und funktionsbezogen freigegeben. Bestehende
konkrete Freigaben werden nicht erneut abgefragt. Linked-Server-Verbindungen
zwischen ausschließlich neu erzeugten lokalen Testcontainern sind ausdrücklich
freigegeben. Bestehende, gemeinsam verwendete und produktive Systeme sind
nicht Teil dieser Freigabe. Secrets und konkrete Runtimeidentitäten bleiben
außerhalb der Repositoryartefakte.

Ein abgeschlossener Schritt oder ein zusätzlicher Benutzerauftrag beendet
die Gesamtwelle nicht. Unabhängige autorisierte Arbeit wird bei einem
isolierten Blocker fortgesetzt. Die automatische Fortsetzung dieses Chats
unterstützt die Entwicklung bis zum ausdrücklichen Benutzerstopp, regulären
Gesamtabschluss oder tatsächlichen Eingabebedarf; unveränderte,
nicht handlungsfähige Zustände erzeugen keine Statusmeldungen.

Der Fortsetzungsrhythmus ist keine Wartefrist für laufende autorisierte
Entwicklung. Sobald ein unabhängiger ausführbarer Schritt feststeht, beginnt
er unmittelbar nach den erforderlichen Vorprüfungen.

## Sessionwechsel bei langer autonomer Entwicklung

Die logische Entwicklungsrolle bleibt über Sessionwechsel erhalten. Aktueller
Repositorystand, Arbeitselemente, Entscheidungen und Validierungsevidenz sind
die Fortsetzungsquellen. Ein Wechsel wird an einer natürlichen Arbeitsgrenze
oder auf ausdrücklichen Benutzerauftrag vorbereitet; er beendet die
beauftragte Entwicklungswelle nicht.

Entscheidungen verwenden ausschließlich verfügbare deterministische
Kontextmetadaten. Unbekannte Tokenzahlen und Kontextgrenzen bleiben unbekannt.
Dieses Projekt legt derzeit keine numerischen Soft-/Hard- oder
Checkpointschwellen fest und aktiviert keinen automatischen Lifecycle-Planner.
Antwortlatenz und wiederkehrende semantische Analyse des gesamten Chats sind
keine automatischen Wechseltrigger.

Bei einem tatsächlich gewählten Checkpoint werden geänderte bestätigte Fakten
in die kanonischen Projektquellen aufgenommen. Eine Fortsetzung erhält deren
Referenzen und höchstens einen autorisierten externen Delta-Handoff seit dem
vorherigen Checkpoint. Runtime-Sessionkennungen, vollständige Chats und
Handoffinhalte werden nicht ins Repository übernommen. Ein Nachfolger lädt
die native Anweisungskette und prüft den aktuellen Repositorystand erneut.

Der Benutzer hat am 6. Oktober 2026 die aufgabenbezogene Erzeugung neuer
Orchestrator-Chats freigegeben, wenn ein Wechsel angebracht ist. Ein Wechsel
wird an einer natürlichen Arbeitsgrenze vorbereitet und verwendet eine
verfügbare Clientfunktion. Erst ein vom Client als verfügbar bestätigter
Nachfolger mit tatsächlicher `threadId` belegt die Erzeugung; eine vorgemerkte
Einrichtung bleibt ausstehend.
Ohne verfügbare Clientfunktion bleibt die Erzeugung manuell. Eine Empfehlung
oder ein Handoff allein gilt nicht als ausgeführter Sessionwechsel.

Der Nachfolger übernimmt die logische Entwicklungsrolle und lädt die aktuelle
native Anweisungskette sowie die kanonischen Projektquellen erneut. Eine kurze
Übergabe verweist auf den bestätigten Projektstand, aktuelle Arbeit und offene
Punkte; Sessionkennungen und Handoffinhalte bleiben außerhalb von Git. Bei
einem tatsächlichen Wechsel wird die bestehende automatische Fortsetzung erst
nach dieser Bereitschaftsbestätigung dem Nachfolger zugeordnet, damit nur ein
Orchestrator die autonome Arbeit steuert.
Es werden keine zusätzliche periodische Rotation und keine numerischen
Kontextschwellen aktiviert.

## Aktueller Produktstand

Der portable Frameworkkern ist für SQL Server 2019, 2022 und 2025 implementiert. Die allgemeine Lab-Provisionierung und deren Lifecycleverantwortung liegen in `gecompat/SQL_Server_Lab`. SQL Server Analyze enthält weiterhin Frameworkcode, Dokumentation, analyserspezifische Szenarien und die benutzerorientierte Beispielsteuerung.

Die kanonische Release-Evidenz umfasst alle 17 P0-, 40 P1- und 124 P2-Fälle. Die abgeschlossene P0-, P1- und P2-Special-Case-Matrix bleibt Bestandteil des bestätigten Produktstands.

### Abgeschlossen – SQL25-005

`USP_QueryStoreReplicaAnalysis` und der Query-Store-Orchestrator trennen SQL-Server-2025-Runtime-, Wait- und Plan-Forcing-Evidenz nach beobachteter Replica-Rolle. SQL Server 2019 und 2022 liefern versionssicher `UNAVAILABLE_VERSION`.

`ANALYZE-LAB-001` ist für den definierten Sieben-Beispiele-Umfang abgeschlossen. Die sechs zusätzlich katalogisierten Beispiele sind dokumentiert, über den gemeinsamen Interactive-/Verify-Runner auswählbar und auf SQL Server 2025 mit dem primären Docker-Provider runtimegeprüft. Der Project-Adapter-Slice `EXECUTION-PLAN-001` installiert zusätzlich den eigenständigen Execution-Plan-Analyse-Frameworkteil und bestand seinen SQL-Server-2025-Quick-Run unter Docker und Podman einschließlich scopegebundenem Cleanup.

Das registrierte Intake-Arbeitselement `WI-0010` hält in der neuen [Diagnoseabdeckung und Gap-Intake](../Research/SQL_Server_Diagnostic_Coverage_Landscape.md) darüber hinaus 106 implementierte, partielle, geplante, externe oder bewusst ausgeschlossene Themen fest. Es ändert die folgende ausführbare Reihenfolge nicht. Neue Kandidaten erhalten erst nach dem Reifeabschluss und einem eigenen Dossier eine Registryreferenz.

Alle 104 Procedure-Seiten besitzen den Status `DEEP_REVIEWED` nach Reviewvertrag 3. Dieser Dokumentationsanteil des Reifeabschlusses ist erledigt und ersetzt keine noch offene Laufzeitevidenz.

## Nächste ausführbare Welle: Reifeabschluss

Die nächste Welle erweitert keine öffentliche Diagnosefläche. Sie schließt die bereits implementierten Teilfunktionen und zugehörigen Reifeverträge ab.

1. `OPS-005` ergänzt die noch offene Providervarianz. Der kontrollierte MSOLEDBSQL-Verbindungserfolg zwischen zwei neuen lokalen SQL-Server-2025-Containern ist seit dem 5. Oktober 2026 belegt. Der synthetische TestLab-Adapter deckt bereits die Drei-Versionen-, Berechtigungs- und Timeoutfälle ab; zusätzliche native Erfolgsläufe folgen nur bei konkretem Versionsrisiko oder erforderlichem Release-Nachweis.
2. `OPS-006` schließt die verbleibende Evidenz einer tatsächlich nicht unterstützten Systemquelle. Der kontrollierte Feature-Nachweis auf nativen SQL Server 2019, 2022 und 2025 sowie die vorhandenen Berechtigungspfade werden nicht erneut als offene Arbeit geführt.
3. `OPS-008` ergänzt nicht leere Agent-, Mail- und Maintenance-Historien sowie tatsächlich fehlende optionale Quellen. Fünf kontrollierte Leerfälle, kurze und lange Backup- und Restorezeitfenster und kontrolliertes Dateiwachstum sind auf SQL Server 2025 belegt; die vorhandenen Berechtigungs- und Begrenzungsfälle bleiben bestätigt. Der Versuch einer optionalen Viewumbenennung scheiterte mit `15001` und schließt die Quellenabwesenheit nicht ab.
4. `OPS-007` ergänzt die verbleibende Hochlast-Evidenz. Die ressourcenpositive eigene zweite Session und der explizite Berechtigungsfehler sind auf SQL Server 2025 belegt. `OPS-009` besitzt einen nativen SQL-Server-2025-Nachweis für positives Inventar, exakte Begrenzung, eingeschränkte und selektive Sicht sowie Leerfall. Ein weiterer nativer SQL-Server-2022-Lauf folgt nur bei konkretem Versionsrisiko oder erforderlichem Release-Nachweis.
5. `COLL-001` setzt die begonnene objektbezogene Härtung fort. Die fünf OPS-Objekte, die Child-JSON-Aggregation von `USP_CurrentOverview` und der TABLE-Zielvertrag bilden den ersten statisch sowie auf der garantierten Collation nativ abgesicherten Slice. `USP_IndexOperationalStats` und `USP_Partitions` besitzen zusätzlich SQL-Server-2025-Nachweise mit abweichender Server-/`tempdb`-Collation für gezielte JSON-/TABLE-Ausgabe, Frameworkcollation im Export und native Gegenprüfung. Die lokalen Object-/Index-Arbeitstabellen sind explizit collatiert; 13 weitere TABLE-Exports und der normale ObjectAnalysis-Orchestrator bestehen auf SQL Server 2025 mit abweichender Server-/`tempdb`- und Quelldatenbankcollation. Die dabei gefundenen dynamischen Steuerwert-, JOIN- und CASE-Grenzen sind gehärtet. `USP_PerformanceCounters` besteht zusätzlich den gezielten Snapshot- und Ein-Sekunden-Samplevertrag mit TABLE-/JSON-Ausgabe und exaktem Counterfilter auf abweichender Server-/`tempdb`-Collation. `USP_BufferPoolAnalysis` besitzt zusätzlich den Memory-TABLE-/JSON-Nachweis sowie die Standard- und Opt-in-Verteilungsprüfung auf derselben gemischten Collation-Kombination. `USP_InternalContentionAnalysis` besteht zusätzlich den kumulativen und zeitbezogenen Latch-TABLE-/JSON-Vertrag mit nativer Klassenidentität und Prüfung der tatsächlichen Messdauer auf dieser Collation-Kombination. `USP_ServerSecurityConfiguration` besitzt zusätzlich einen TABLE-/JSON-Nachweis mit nativer Konfigurationsparität auf derselben gemischten Collation-Kombination. `USP_ServerHealthAnalysis` besteht zusätzlich den Modulstatus-Export und die gezielte Security- sowie erweiterte Child-JSON-Auswahl auf dieser Kombination. `USP_WorkerPressureAnalysis` besitzt zusätzlich sieben collatierte TABLE-Exporte, TABLE-/JSON-Parität und einen kontrollierten Zweikandidatenfall mit einheitlichem Requestlimit auf dieser Kombination. `USP_AuditConfigurationAnalysis` besitzt zusätzlich fünf collatierte TABLE-Exporte, native Spezifikationsparität und einheitliche TABLE-/JSON-Filter- und Limitverträge auf dieser Kombination. `USP_DatabaseIntegrityAnalysis` besitzt zusätzlich einen collatierten TABLE-Export, native Metadatenparität, einheitliche Integritätslimits und eine Gegenprüfung des optionalen LIMITED-Seitenheaders auf dieser Kombination. `USP_DatabaseCapacityAnalysis` besitzt zusätzlich neun collatierte TABLE-Textspalten, native Dateimetadatenparität auf einer eigenen schreibgeschützten Quelle und einheitliche TABLE-/JSON-Problemfilter und Limits auf dieser Kombination. `USP_CriticalEngineEvents` besitzt zusätzlich fünf collatierte TABLE-Textspalten, native XE-Ereignisparität und den vorhandenen Limit- und XML-Opt-in-Vertrag auf dieser Kombination. `USP_DiagnosticFindings` besitzt zusätzlich zehn collatierte TABLE-Textspalten, kontrollierte Parent-Zuordnung und partielle Wiederverwendung sowie einheitliche Prioritätsfilter und Limits bei unveränderten Zählern auf dieser Kombination. `USP_DatabaseConfigurationAnalysis` besitzt zusätzlich sechs collatierte TABLE-Exporte mit nativer Options- und Konfigurationsparität, kontrollierter Profilzuordnung, vollständigem dynamischem Katalogaufruf und einheitlichen Settings-/Driftlimits auf dieser Kombination. `USP_ErrorLogAnalysis` besitzt zusätzlich 22 collatierte TABLE-Textspalten und native Unicode-Logparität sowie einheitliche Detaillimits und das partielle Quelllimit auf dieser Kombination. `USP_BackupChainAnalysis` besitzt zusätzlich fünf collatierte TABLE-Textspalten und native Full-/Differentialmetadaten sowie einen positiven Ohne-Prüfsumme-Zähler und einheitliche Summary-/Backuplimits auf dieser Kombination. `USP_AgentStatus` und `USP_InfrastructureAnalysis` besitzen zusätzlich sechs collatierte TABLE-Textspalten, native Jobinventarparität und vier Modulstatus- und Child-JSON-Auswahlverträge auf dieser Kombination. `USP_ResourceGovernorAnalysis` besitzt zusätzlich fünf collatierte TABLE-Exporte mit 16 Textspalten, nativer Konfigurations-, Pool- und Gruppenparität sowie den vorhandenen Ausgabegrenzen und TempDB-Governance ohne konfiguriertes Limit auf dieser Kombination. `USP_BackupRecovery` besitzt zusätzlich vier collatierte TABLE-Textspalten, native Full-/Differential-/Copy-only-Metadaten und einheitliche Freshnesslimits auf dieser Kombination. `USP_DataCaptureStatus` besitzt zusätzlich fünf collatierte TABLE-Textspalten, native CT-Datenbank- und Tabellenparität, einen parametrisierten CDC-Batch sowie einheitliche Datenbanklimits mit erhaltenen Auswahlwarnings auf dieser Kombination. `USP_TemporalAnalysis` besitzt zusätzlich zwölf collatierte TABLE-Textspalten, native eigene Temporal-Paare mit Perioden-, Retention- und führenden Indexmetadaten, vier unterschiedliche Quellcodes sowie gemeinsame Findingsfilter und Limits bei vollständigen Zählern und erhaltenen Auswahlwarnings auf gemischtem SQL Server 2025 mit Compatibility Level 150, 160 und 170. `USP_ServiceBrokerAnalysis` besitzt zusätzlich zehn collatierte TABLE-Textspalten, native eigene leere Queue-Schalter und Servicemetadaten, sieben unterschiedliche Quellcodes sowie gemeinsame Findingsfilter und Limits bei vollständigen Zählern und erhaltenen Auswahlwarnings auf gemischtem SQL Server 2025 mit expliziten Framework- und Source-Compatibility-Levels 150, 160 und 170. `USP_FullTextAnalysis` besitzt zusätzlich einen SQL-Server-2025-Nachweis für einen eigenen leeren Full-Text-Katalogscope, zehn collatierte TABLE-Textspalten, acht unabhängige Quellcodes, die Akzeptanz von NULL-/0-/positiven Mengenparametern, die Ablehnung ungültiger Parameter und erhaltene Auswahlwarnings mit expliziten Framework- und Source-Compatibility-Levels 150, 160 und 170. Nichtleere Full-Text-Findings, positive Filter-/Limitwirkung und gegatete Laufzeitquellen bleiben für diesen Slice unbelegt. `USP_DataCaptureDeepAnalysis` besitzt zusätzlich einen CT-Metadatennachweis aus zwei eigenen leeren Unicode-Tabellen mit nativen Identitäten und Versionen sowie elf unabhängigen Quellstatus. Common 159 besteht 18 TABLE-/JSON-Fälle mit zehn collatierten Textspalten und 13-Felder-Parität auf gemischtem SQL Server 2025 bei expliziten Framework- und beiden Source-Compatibility-Levels 150, 160 und 170. Ein synthetischer Wasserstand über der aktuellen Version erzeugt Future-WARNs; deaktiviertes Auto-Cleanup liefert INFO-Kontext. Positive exakte Unicode-/Case-Filter, NULL-/0-/positive Limits, vollständige Zähler, Auswahlwarnings und ungültige Mehrdatenbank-Consumerstatus sind geprüft. RAW und CONSOLE sind nur mit Status und JSON-Zeilenanzahl geprüft. Integration 184 besteht auf denselben drei Frameworklevels; deren Quelldatenbanklevel wurden nicht separat gesetzt. CT-Retentionverlust, positive CDC-/Replikationsquellen und zusätzliche Berechtigungsnachweise bleiben offen. Der begrenzte Nachweis ist unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) dokumentiert; `COLL-001` bleibt partiell. `USP_EncryptionAnalysis` besitzt zusätzlich einen Nachweis aus drei eigenen unverschlüsselten Unicode-Datenbanken mit nativen Identitäten und leerem DEK-/Full-Backup-/AE-/Ledger-Scope. Common 160 besteht 22 TABLE-/JSON-Fälle mit 26-Felder-Parität einschließlich NULL-Properties und elf collatierten Textfeldern auf gemischtem SQL Server 2025 bei getrennt bestätigten Framework- und drei Source-Compatibility-Levels 150, 160 und 170. Die erwartete Backupverschlüsselung ohne vorhandene Backupmetadaten erzeugt MEDIUM-Hinweise; Unicode-/Case-Auswahl, NULL-/0-/positive Limits, sichere Ablehnung negativer Limits und erhaltene Auswahlwarnings bei drei unabhängig erfolgreichen Quellenstatus sind geprüft. Vier RAW-/CONSOLE-Aufrufe prüfen ausschließlich Status und JSON-Zeilenanzahl. Integration 185 besteht bei denselben drei Frameworklevels und umfasst vier synthetische Zustände, zwei echte Procedure-Aufrufe für Backup-Erwartung und Berechtigungsfehler, einen AE-Definitionsvertrag und einen separaten Privacy-Check. Positive TDE-, Zertifikat-, Backupverschlüsselungs-, AE-, Ledger- und Restore-Evidenz bleibt unbelegt. Der begrenzte Nachweis ist unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) dokumentiert; `COLL-001` bleibt partiell. `USP_MaintenanceOperations` besitzt zusätzlich 57 explizit collatierte lokale Textfelder und vier gemeinsame Exporte mit unveränderten 15/19/9/7 Feldern. Common 161 besteht 24 TABLE-/JSON-Fälle auf gemischtem SQL Server 2025 bei getrennt bestätigtem Framework- und drei Source-Compatibility-Levels 170. Drei eigene Unicode-Datenbanken ohne Nutzdaten mit einmal ADR-OFF und zweimal ADR-ON liefern native PVS-Metadaten und kontrollierte Schwellwert-0-MEDIUM-Hinweise. Acht PVS-Felder werden exakt verglichen; die veränderliche PVS-Größe wird numerisch durch unabhängige Messungen vor und nach dem Aufruf begrenzt. Das leere Resumable-TABLE-Schema bestätigt 15 Felder und acht Textcollations. Vier unabhängige Quellenstatus einschließlich Jobs `NOT_REQUESTED` sowie NULL-/0-/positive Limits und Unicode-/Case-Auswahl mit erhaltener Auswahlpartialität und vollständiger Modulbewertung vor Ausgabelimits sind geprüft. Sechs RAW-/CONSOLE-Aufrufe prüfen ausschließlich Status und begleitende JSON-Zeilenanzahl; deren Warningzeilen werden nicht separat abgefangen. Integration 186 besteht auf CL170 und enthält drei synthetische Definitionsfälle sowie einen echten Berechtigungsaufruf und Read-only-Prüfungen. Positive Resumable-TABLE-Filter-/Limitwirkung, Wartungsrequests, Jobs, Hochlast und neue Nachweise für ältere Engines oder CL150/160 bleiben offen. Der begrenzte Nachweis ist unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) dokumentiert; `COLL-001` bleibt partiell. `USP_AvailabilityDeepAnalysis` besitzt zusätzlich 46 explizit collatierte lokale Textfelder und einen gemeinsamen Replikaexport mit elf Feldern und zehn Textcollations. Common 162 besteht zehn TABLE-/JSON-Fälle, vier RAW-/CONSOLE-Statusaufrufe und zwei zusätzliche JSON-Verbraucherfälle auf gemischtem SQL Server 2025 mit nativ deaktiviertem HADR und Framework-Compatibility-Level 170; es wurde keine Quelldatenbankfixture benötigt. Unabhängig geprüft sind das leere TABLE-Schema, acht JSON-Topkeys, acht Metafelder und sieben leere Arrays sowie die Akzeptanz von NULL-/0-/positiven Limits und die sichere Ablehnung ungültiger Limit-/Queue-/Lag-/Ausgabeparameter. RAW und CONSOLE sind nur über Status und begleitende JSON-Mengen geprüft; die leeren Mengen belegen keine positive Limitwirkung. Integration 176 besteht auf CL170 und umfasst einen echten AG-NONE-Aufruf sowie drei synthetische Interpretationsfunktionen. Positive AG-/Replika-Limit-/Queue-/Cluster-/Seeding-/Seitenreparatur-/Netzwerk-/Berechtigungsevidenz sowie neue Nachweise für ältere Engines oder CL150/160 bleiben offen. Der begrenzte Nachweis ist unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) dokumentiert; `COLL-001` bleibt partiell. `USP_ExternalRuntimeAnalysis` besitzt zusätzlich 96 explizit collatierte lokale Textfelder und einen gemeinsamen Findings-Export mit 13 Feldern, zehn Textcollations und unverändertem Findingordinal. Common 163 besteht 22 TABLE-/JSON-Fälle und vier RAW-/CONSOLE-Statusaufrufe mit begleitender JSON-Zeilenanzahl auf gemischtem SQL Server 2025 bei getrennt bestätigten Framework- und beiden case-unterschiedlichen Unicode-CI_AS-Source-Compatibility-Levels 150, 160 und 170. Vorhandene native R-/Python-Standardregistrierungen bei deaktivierten Scripts liefern die bestehenden Registrierungs-WARNs und Startfähigkeits-INFOs ohne neue Registrierung oder externe Ausführung. Positive Problemfilter, NULL-/0-/positive Limits, sichere negative Ablehnung, exakte Case-Auswahl, erhaltene Auswahlpartialität und vollständige Datenbankzähler sind mit 13-Felder-TABLE-/JSON-Parität einschließlich NULL-Property-Auslassung geprüft. Sechs globale und zwei Katalogquellcodes je Datenbank sind unabhängig gegen native Konfiguration, Services, Katalogidentitäten, Poolkonfiguration und Counteridentitäten, Typen und Quellanzahlen geprüft. Integration 198 besteht auf denselben Frameworklevels und prüft die bestehenden External-Runtime-/CLR-Read-only-, JSON-, TABLE-, Routing-, Capability- und Lock-Timeout-Verträge. RAW-/CONSOLE-Zeilen werden nicht separat abgefangen; veränderliche kumulative Werte sind kein atomarer Punktvergleich. Aktive Featurematrix, Startfähigkeit, positive Libraries und Requests, Sampling sowie weitere Berechtigungs- und optionale Pfade bleiben offen. Der Slice liefert keine neuen nativen älteren Engine-Nachweise. Der begrenzte Nachweis ist unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) dokumentiert; `COLL-001` bleibt partiell und `RUNTIME-001` behält `IMPLEMENTED_EXTERNAL_EVIDENCE_PENDING`. `USP_ClrAnalysis` besitzt zusätzlich 106 explizit collatierte lokale Textfelder und einen gemeinsamen nicht identitätsgenerierten Findings-Export mit 13 Feldern und zehn Textcollations bei erhaltenen ursprünglichen Ordinalen. Common 164 besteht 24 TABLE-/JSON-Fälle und vier RAW-/CONSOLE-Statusaufrufe mit begleitender JSON-Findingsanzahl 0 auf gemischtem SQL Server 2025 bei getrennt bestätigten Framework- und beiden case-unterschiedlichen Unicode-CI_AS-Source-Compatibility-Levels 150/160/170. Das leere Findingsschema und die Parität sowie NULL-/0-/positive Limitakzeptanz, exakte und LIKE-Assemblyfilterakzeptanz, sichere Parameterablehnung, exakte Datenbankauswahl und späte Auswahlpartialität sind ohne Assemblyregistrierung, CLR-Ausführung oder Konfigurations-/Truständerung geprüft. Native Konfiguration und state/version-Properties, Memory-Clerk-Identitäten und Anzahlen sowie Counteridentitäten, Typen, Anzahlen und unabhängige Sample-0-Interpretation sind mit acht globalen und drei Katalogquellcodes je Datenbank beziehungsweise einem Katalogcode ohne Modulzuordnung gegengeprüft. Integration 198 besteht auf denselben Frameworklevels. Positive Assemblies und nichtleere Findingsfilter-/Limitwirkung, Ausführung, Trust, Sampling und weitere Berechtigungspfade bleiben offen. RAW-/CONSOLE-Zeilen werden nicht separat abgefangen; variable Speicher- und Counterwerte belegen keinen atomaren Punktvergleich. Der Slice liefert keine neuen nativen älteren Engine-Nachweise. Der begrenzte Nachweis ist unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) dokumentiert; `COLL-001` bleibt partiell und `RUNTIME-001` behält `IMPLEMENTED_EXTERNAL_EVIDENCE_PENDING`. Die drei Orchestratoren `USP_PlanCacheAnalysis`, `USP_QueryStoreAnalysis` und `USP_ExtendedEventsAnalysis` besitzen zusätzlich je sechs explizit collatierte lokale Textfelder und einen frühen gemeinsamen Modulstatusexport mit fünf Feldern und drei Textcollations. Der Nachweis auf gemischtem SQL Server 2025 mit Framework-Compatibility-Level 170 bestätigt die Reparatur des bestehenden CONSOLE-Fehlers wegen fehlender Exportquelle; die ursprünglichen TABLE-Textcollations waren bereits korrekt. Common 165 besteht 24 TABLE-/JSON-Vertragsfälle, zwölf positive und neun leere SQL-CONSOLE-Captures sowie drei direkte CONSOLE-Aufrufe. Ein zusätzlicher unabhängiger SqlClient-Capture bestätigt alle 15 positiven sechsfeldrigen und neun leeren dreifeldrigen CONSOLE-Fälle mit nativen Feldnamen, Typen, Textgrößen, ursprünglichen Ordinalen, Modulnamen, Invocationstatus und Fehlerwerten. Die Plan-Cache-JSON-Parität des vorhandenen `modules`-Arrays und die erhaltenen Query-Store-/XE-Childobjekte, Metadaten und Warnungsprojektionen sind geprüft. Die Modulstatusmenge bleibt vollständig und unbegrenzt, unabhängig von NULL-/0-/positiven Childlimits. Drei RAW-Invalid-Leerscope-Aufrufe und zwölf TABLE-Zuordnungsablehnungen bestehen. Fünf vorhandene leere dreifeldrige RequestedName-Warningproben bleiben in den drei direkten Childpfaden sichtbar. Positive RAW-Modulzeilenparität, Plan-XML, Ereignisse, `ERROR_HANDLED`- und Berechtigungspfade sowie neue native ältere Engine- oder CL150/160-Nachweise bleiben für diesen Slice unbelegt. Der begrenzte Nachweis ist unter [COLLB006](COLLB006_Mixed_Runtime_Evidence_2026-09-19.md) dokumentiert; `COLL-001` bleibt partiell. Weitere Frameworkdateien und Verbrauchervarianten bleiben offen.

## Exit-Kriterien

Die Welle ist abgeschlossen, wenn:

- vorhandener und offener Produktumfang in den kanonischen Statusquellen übereinstimmen;
- die vorgesehenen positiven, leeren, eingeschränkten und fehlerisolierten Fälle tatsächlich ausgeführt wurden;
- betroffene Procedure-Seiten den dokumentierten Reviewstatus inhaltlich erfüllen;
- keine allgemeine Lab-Verantwortung in dieses Repository zurückverlagert wurde;
- die impact-basierten statischen und funktionalen Gates erfolgreich sind.

Die SQL-Server-2025-Erweiterungen `WI-0002` bis `WI-0007` beginnen erst, wenn der Reifeabschluss einschließlich `COLL-001` keine ungeklärte gemeinsame Vertragsabweichung hinterlässt.
