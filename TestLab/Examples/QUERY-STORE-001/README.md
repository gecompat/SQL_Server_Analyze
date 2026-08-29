# QUERY-STORE-001

Das Beispiel verwendet `LAB-QS-001`, aktiviert Query Store in der synthetischen Szenariodatenbank und erzeugt wiederholte Aufrufe mit unterschiedlichen synthetischen Selektivitäten. Der Verify-Modus prüft vorhandene Query-Store-Runtimeevidenz und ruft danach `[monitor].[USP_QueryStoreAnalysis]` auf.

Im Interactive-Modus führen Sie zuerst das ausgegebene Analyseskript aus. Lesen Sie Quellenstatus und Zeitfenster vor einer Regressionsaussage. Exakte Laufzeiten, Plan-IDs und Ausführungszahlen sind keine Assertions. Das Cleanup entfernt ausschließlich die markierte Szenariodatenbank und deren Run-Kontext.
