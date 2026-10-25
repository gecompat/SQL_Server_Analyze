# SSIS-Paket-Analyse

Der [Abgrenzungs- und Austauschvertrag mit Toolbelt](../Architecture/SSIS_Analyze_Toolbelt_Exchange_Contract.md)
beschreibt die gemeinsame Parser- und Lineagepflege bei weiterhin
eigenständigem Analyze-Betrieb ohne CLR. Der additive native Modellimport
verändert die bisherigen Paket- und Logschnittstellen nicht.

Die [iterationsgebundene Ausführungskorrelation](Procedures/USP_SsisPackageModelAnalysis.md#iterationsgebundene-ausführungskorrelation)
ordnet beobachtete For-/Foreach-Instanzen optional dem importierten Modell zu.
Sie zeigt Instanzzahlen, objektbezogene Dauern und die Grenzen der
Loggingbeobachtung. Die Containerklassifikation stammt aus Toolbelt;
Analyze benötigt weiterhin keine SQL-CLR-Installation.

## [monitor].[USP_SsisPackageAnalysis]

Der erste SSIS-001-Slice liest ausschließlich direkt übergebenes DTSX-v2-XML. Er inventarisiert Paket, Executables mit direkten Parent-Containern, direkte Precedence Constraints, Paket-Connection-Manager, Paketparameter, Variablendefinitionen, Pipeline-Komponenten, direkte Property-Expressions und direkte Pipeline-Komponentenlinien. Für Pipeline-Komponenten gibt er ausschließlich Namen und Klassenkennungen aus; für Expressions nur Scope und Eigenschaftsname. Connection Strings, Parameterwerte, Komponenteneigenschaften, Expressiontexte und sonstige sensitive Werte bleiben aus der Ausgabe ausgeschlossen. Weitergehende Lineage, Regeln sowie Datei-, ISPAC- und SSISDB-Adapter bleiben ausdrücklich ausgenommen.

Schema v3 ergänzt `variables` als dreizehntes RAW-Resultset. TABLE und JSON verwenden denselben begrenzten Variablenexport mit Scopezuordnung, Namespace, Name, Datentypcode und Booleanmetadaten. Event-Handler-Scope bleibt ausdrücklich begrenzt; Variablenwerte werden nicht gelesen oder ausgegeben. Der [öffentliche Vertrag](../Architecture/SSIS_001_Phase0_Public_Contract.md) beschreibt Schema, Defaults, NULL-Werte und Partialität.

## [monitor].[USP_SsisCatalogExecutionAnalysis]

Der Kataloganalyzer liest genau eine explizite lokale SSISDB-Ausführung. Er trennt Ausführungsstatus, Executable-Statistik, strukturierte Ereignisse, Parameterdefinitionen, Phasen und Row-Flow von Quellenfehlern. Meldungstexte, Parameterwerte, Pfade und Identitäten bleiben ausgeschlossen. Der [freigegebene Katalogvertrag](../Architecture/SSIS_001_Phase0_Public_Contract.md#konkreter-katalogvertrag-vom-16-oktober-2026) und die [Procedure-Anleitung](Procedures/USP_SsisCatalogExecutionAnalysis.md) beschreiben Limits, Sichtbarkeit und Aussagegrenzen. Der separate Legacy-Analyzer besitzt den nachfolgend beschriebenen freigegebenen Umfang.

## [monitor].[USP_SsisLegacyLogAnalysis]

Der Legacy-Analyzer liest eine explizite Datenbank und genau eine GUID aus einer vorhandenen sysssislog-kompatiblen Tabelle. Meldungstexte aller Ereignisarten bleiben standardmäßig erhalten. Zusätzliche Indizes sind keine Voraussetzung. Die [Anleitung](Procedures/USP_SsisLegacyLogAnalysis.md) und der [freigegebene Vertrag](../Architecture/SSIS_001_Phase0_Public_Contract.md#konkreter-legacy-vertrag-vom-16-oktober-2026) trennen beobachtete Ereignisse von konservativen Zeitpaaren. Die [begrenzte Providerabnahme](../Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#legacy-providerabnahme-vom-18-oktober-2026) bestätigt vier synthetische Paketfälle mit zwölf gebundenen Cap-Prüfungen auf Windows SQL/SSIS 17.0.1000.7; neun Einzelbelege werden aus früheren insgesamt fehlgeschlagenen Versuchen wiederverwendet. Weitere Funktionen und Rollen bleiben offen; SSIS-001 bleibt PARTIAL_PRODUCT_FUNCTION.

Version 1.1.0 ergänzt mit `@IncludeTaskAnalysis=1` beobachtete EXECUTE-/VALIDATE-
Daueraggregate und Ereignisabdeckung je Source-ID. Ohne Opt-in bleiben die
bisherigen neun Ausgabegruppen erhalten. Die [Taskintervall-Abnahme](../Architecture/SSIS_Package_and_Execution_Analysis_Plan.md#taskintervalle-und-loggingabdeckung-abnahme-vom-18-oktober-2026)
trennt synthetische Gegenproben, zwei neue native Szenarien und
Ausgabeparität. SourceType bleibt UNRESOLVED; weder vollständige Tasklisten
noch Loggingkonfiguration, Schleifenanzahl oder CPU-Zeit werden behauptet.


## [monitor].[USP_SsisPackageModelAnalysis]

Der [native Modellimport](Procedures/USP_SsisPackageModelAnalysis.md) validiert
optional übergebenes JSON ohne CLR oder Toolbelt-Installation. Er prüft Felder,
Kennungen, Scopes und Referenzen; Originalbytes erlauben einen unabhängigen
Paketbytevergleich. Die Producerherkunft bleibt UNVERIFIED. Der Importer
berechnet keine neue Lineage und führt weder Pakete noch enthaltenes SQL aus.
Mit `@IncludePackageViews=1` kommen Paketübersicht, Executables, beobachtete
Datenflussscopes, Komponenten und direkte Spaltenbeziehungen hinzu. Die
Projektionen verwenden den vollständigen validierten Graphen; das Zeilenlimit
begrenzt anschließend jede Detailausgabe.

Die Modellanalyse bietet mit `@IncludeObjectRules=1` zusätzlich
objektbezogene statische Hinweise. Die [Regelreferenz](Procedures/USP_SsisPackageModelAnalysis.md#objektbezogene-regeln)
beschreibt ihre konkreten Belege und Abdeckungsgrenzen. Die Regeln
interpretieren keine neuen Komponenten und berechnen keine Lineage.

Eine [kontrollierte lokale Übergabe](Procedures/USP_SsisPackageModelAnalysis.md#kontrollierte-lokale-übergabe)
kann den tatsächlichen Producerbuild und das konkrete Modellergebnis an die
Originalpaketbytes binden. Der Betriebsweg benötigt ausdrücklich vorhandene
Metadatenänderungsrechte des Zulieferers; gewöhnliche Analysecaller benötigen
sie nicht. Ohne Übergabe-ID bleibt die Analyse eigenständig mit `UNVERIFIED`.

Der optionale [Kindpaket-/Handlerpfad](Procedures/USP_SsisPackageModelAnalysis.md#kindpaket-und-ereignishandlerkorrelation)
verknüpft feste projektlokale Aufrufe desselben gebundenen Archivs mit
beobachteten Paketinstanzen. Er trennt Paketidentitäten und Handlerbelege;
mehrdeutige Pfade und unbekannte Auslöser bleiben ausdrücklich unbewiesen.
Die sieben eigenen Ergebnisgruppen ersetzen in diesem Opt-in die bisherigen
Einzelmodellausgaben. Analyze bleibt ohne SQL CLR eigenständig nutzbar.

Die zusätzliche [Dataflow-Korrelation](Procedures/USP_SsisPackageModelAnalysis.md#optionale-dataflow-ausführungskorrelation)
ordnet Komponentenphasen und Pfadtransfers erst nach eindeutiger Bindung einer
Statistikinstanz zu. Sie erhält Einzelintervalle und Transferzähler samt
Logginggrenzen. Komponenten-, Port- und Kantenreferenzen stammen aus dem
Toolbelt; Analyze berechnet keine zusätzliche Lineage.

Die optionale [Dataflow-Diagnose](Procedures/USP_SsisPackageModelAnalysis.md#optionale-dataflow-diagnose)
fasst diese gebundenen Einzelbelege je Aufrufinstanz zusammen. Sie zeigt
Phasenkennzahlen, Pfadtransfers und versionierte Regelhinweise mit Quellenbezug.
Fehlende Beobachtungen und unbekannte Rollen bleiben als Evidenzgrenzen sichtbar.

Der [gebundene Ausführungsvergleich](Procedures/USP_SsisExecutionComparison.md) vergleicht zwei Captures desselben exakten Modellexports. Herkunft, Version, Laufzeitkontext und Coverage begrenzen die Aussage; Parser und Lineage bleiben in Toolbelt.
