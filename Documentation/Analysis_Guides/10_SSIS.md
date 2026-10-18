# SSIS-Paket-Analyse

## [monitor].[USP_SsisPackageAnalysis]

Der erste SSIS-001-Slice liest ausschließlich direkt übergebenes DTSX-v2-XML. Er inventarisiert Paket, Executables mit direkten Parent-Containern, direkte Precedence Constraints, Paket-Connection-Manager, Paketparameter, Variablendefinitionen, Pipeline-Komponenten, direkte Property-Expressions und direkte Pipeline-Komponentenlinien. Für Pipeline-Komponenten gibt er ausschließlich Namen und Klassenkennungen aus; für Expressions nur Scope und Eigenschaftsname. Connection Strings, Parameterwerte, Komponenteneigenschaften, Expressiontexte und sonstige sensitive Werte bleiben aus der Ausgabe ausgeschlossen. Weitergehende Lineage, Regeln sowie Datei-, ISPAC- und SSISDB-Adapter bleiben ausdrücklich ausgenommen.

Schema v3 ergänzt `variables` als dreizehntes RAW-Resultset. TABLE und JSON verwenden denselben begrenzten Variablenexport mit Scopezuordnung, Namespace, Name, Datentypcode und Booleanmetadaten. Event-Handler-Scope bleibt ausdrücklich begrenzt; Variablenwerte werden nicht gelesen oder ausgegeben. Der [öffentliche Vertrag](../Architecture/SSIS_001_Phase0_Public_Contract.md) beschreibt Schema, Defaults, NULL-Werte und Partialität.

## [monitor].[USP_SsisCatalogExecutionAnalysis]

Der Kataloganalyzer liest genau eine explizite lokale SSISDB-Ausführung. Er trennt Ausführungsstatus, Executable-Statistik, strukturierte Ereignisse, Parameterdefinitionen, Phasen und Row-Flow von Quellenfehlern. Meldungstexte, Parameterwerte, Pfade und Identitäten bleiben ausgeschlossen. Der [freigegebene Katalogvertrag](../Architecture/SSIS_001_Phase0_Public_Contract.md#konkreter-katalogvertrag-vom-16-oktober-2026) und die [Procedure-Anleitung](Procedures/USP_SsisCatalogExecutionAnalysis.md) beschreiben Limits, Sichtbarkeit und Aussagegrenzen. Der separate Legacy-Analyzer besitzt den nachfolgend beschriebenen freigegebenen Umfang.

## [monitor].[USP_SsisLegacyLogAnalysis]

Der Legacy-Analyzer liest eine explizite Datenbank und genau eine GUID aus einer vorhandenen sysssislog-kompatiblen Tabelle. Meldungstexte aller Ereignisarten bleiben standardmäßig erhalten. Zusätzliche Indizes sind keine Voraussetzung. Die [Anleitung](Procedures/USP_SsisLegacyLogAnalysis.md) und der [freigegebene Vertrag](../Architecture/SSIS_001_Phase0_Public_Contract.md#konkreter-legacy-vertrag-vom-16-oktober-2026) trennen beobachtete Ereignisse von konservativen Zeitpaaren. Die [begrenzte Providerabnahme](../Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#legacy-providerabnahme-vom-18-oktober-2026) bestätigt vier synthetische Paketfälle mit zwölf gebundenen Cap-Prüfungen auf Windows SQL/SSIS 17.0.1000.7; neun Einzelbelege werden aus früheren insgesamt fehlgeschlagenen Versuchen wiederverwendet. Weitere Funktionen und Rollen bleiben offen; SSIS-001 bleibt PARTIAL_PRODUCT_FUNCTION.
