# SSIS-Paket-Analyse

## [monitor].[USP_SsisPackageAnalysis]

Der erste SSIS-001-Slice liest ausschließlich direkt übergebenes DTSX-v2-XML. Er inventarisiert Paket, Executables mit direkten Parent-Containern und direkte Precedence Constraints. Data-Flow, Verbindungen, Parameter, Expressions, Lineage, Regeln sowie Datei-, ISPAC- und SSISDB-Adapter bleiben ausdrücklich ausgenommen.
