# SSIS-Paket-Analyse

## [monitor].[USP_SsisPackageAnalysis]

Der erste SSIS-001-Slice liest ausschließlich direkt übergebenes DTSX-v2-XML. Er inventarisiert Paket, Executables mit direkten Parent-Containern, direkte Precedence Constraints, Paket-Connection-Manager, Paketparameter, Variablendefinitionen, Pipeline-Komponenten, direkte Property-Expressions und direkte Pipeline-Komponentenlinien. Für Pipeline-Komponenten gibt er ausschließlich Namen und Klassenkennungen aus; für Expressions nur Scope und Eigenschaftsname. Connection Strings, Parameterwerte, Komponenteneigenschaften, Expressiontexte und sonstige sensitive Werte bleiben aus der Ausgabe ausgeschlossen. Weitergehende Lineage, Regeln sowie Datei-, ISPAC- und SSISDB-Adapter bleiben ausdrücklich ausgenommen.

Schema v3 ergänzt `variables` als dreizehntes RAW-Resultset. TABLE und JSON verwenden denselben begrenzten Variablenexport mit Scopezuordnung, Namespace, Name, Datentypcode und Booleanmetadaten. Event-Handler-Scope bleibt ausdrücklich begrenzt; Variablenwerte werden nicht gelesen oder ausgegeben. Der [öffentliche Vertrag](../Architecture/SSIS_001_Phase0_Public_Contract.md) beschreibt Schema, Defaults, NULL-Werte und Partialität.
