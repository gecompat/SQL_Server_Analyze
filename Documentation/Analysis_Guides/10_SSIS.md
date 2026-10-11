# SSIS-Paket-Analyse

## [monitor].[USP_SsisPackageAnalysis]

Der erste SSIS-001-Slice liest ausschließlich direkt übergebenes DTSX-v2-XML. Er inventarisiert Paket, Executables mit direkten Parent-Containern, direkte Precedence Constraints, Paket-Connection-Manager, Paketparameter und Pipeline-Komponenten. Für Pipeline-Komponenten gibt er ausschließlich Namen und Klassenkennungen aus. Connection Strings, Parameterwerte, Komponenteneigenschaften und sonstige sensitive Werte bleiben aus der Ausgabe ausgeschlossen. Expressions, Lineage, Regeln sowie Datei-, ISPAC- und SSISDB-Adapter bleiben ausdrücklich ausgenommen.
