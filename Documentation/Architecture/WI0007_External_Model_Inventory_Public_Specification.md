# WI-0007: Aggregierte External-Model-Inventur

**Status:** APPROVED. Der Benutzer hat diesen Vertrag am 13. Oktober 2026 ausdrücklich freigegeben.

Die bestehende `monitor.USP_SpecialFeatureInventory` erhält je ausgewählter, auswertbarer Datenbank genau eine zusätzliche Featurezeile mit dem Code `EXTERNAL_MODELS`. Der Standardaufruf erfasst damit auch diese Quellenklasse. Neue Parameter, eine neue Procedure und zusätzliche Resultsets sind nicht vorgesehen. Alle vorhandenen Spalten, ihre Reihenfolge, die RAW-/CONSOLE-/TABLE-Auswahl und die JSON-Schemaversion 1 bleiben erhalten.

## Quelle und Aussage

Auf SQL Server 2025 und höher liest ein isolierter dynamischer Datenbankzugriff ausschließlich `COUNT_BIG(*)` aus `sys.external_models`. Er übernimmt weder Modellnamen noch Modellbezeichner, Locations, Parameter, Besitzer, Credentialbezüge oder Inhalte. Die Procedure ruft keine Modellfunktion und keinen Endpunkt auf und ändert keine Konfiguration.

Microsoft dokumentiert die Katalogsicht ab SQL Server 2025 sowie die begrenzte Sichtbarkeit von Metadaten. Ein erfolgreicher Nullwert ist deshalb nur ein Nullwert im für den Caller sichtbaren Scope. Er beweist keine globale Abwesenheit und keine fehlende Modellnutzung. Eine positive Anzahl belegt sichtbare Katalogobjekte, weder Erreichbarkeit noch Funktion oder Qualität eines Modells. Quelle: [sys.external_models](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-external-models-transact-sql?view=sql-server-ver17).

## Zusätzliche Featurezeile

| Vorhandene Spalte | Wert oder Regel |
|---|---|
| DatabaseName | Name der ausgewählten Quelldatenbank gemäß bestehendem Datenbankscope. |
| FeatureCode | `EXTERNAL_MODELS`. |
| FeatureFamily | `External Models`. |
| DetectionStatus | `DETECTED` bei positiver sichtbarer Anzahl; `NOT_DETECTED_VISIBLE_SCOPE` bei erfolgreicher Anzahl 0; `UNAVAILABLE_VERSION` vor Major 17; `SOURCE_UNAVAILABLE` bei unbekannter Version oder fehlgeschlagenem Zugriff. |
| DetectedItemCount | Tatsächliches `COUNT_BIG(*)`; bei Versionsfallback oder Quellenfehler `NULL`. |
| ConfigurationState | `NULL`; aus einer Kataloganzahl wird keine Betriebsbereitschaft abgeleitet. |
| SourceObjects | `sys.external_models`. |
| RecommendedModule | `NULL`; die spätere lokale External-Data-Analyse ist noch nicht implementiert. |
| RecommendedModuleStatus | Vorhandener Wert `NOT_PLANNED`; er bezeichnet hier das Fehlen eines verfügbaren Vertiefungsmoduls. |
| EvidenceLimit | Erläutert sichtbare Kataloganzahl, ausgeschlossene Details und fehlenden Nachweis von Erreichbarkeit, Ausführung und Gesundheit. |

`@NurErkannteFeatures=1` erhält die neue Zeile ausschließlich bei `DETECTED`. Das vorhandene positive Zeilenlimit greift nach dem Filter und nach derselben Sortierung `(DatabaseName, FeatureCode)`. Aufruf- und Datenbankzähler berücksichtigen die zusätzliche Zeile vor dem Ausgabelimit. Durch die neue Defaultzeile können sich diese Zähler und bei begrenzter Ausgabe die ausgewählten Featurezeilen ändern.

## Quellenfehler und Erhaltung vorhandener Ergebnisse

Vor Major 17 wird kein Zugriff auf `sys.external_models` ausgeführt; der erwartete Versionsfallback allein macht den Aufruf nicht partiell. Bei unbekanntem Major wird ebenfalls kein Katalogzugriff ausgeführt. Die neue Featurezeile verwendet `SOURCE_UNAVAILABLE` und eine unbekannte Anzahl; eine zuvor erfolgreiche Datenbankstatuszeile erhält `StatusCode=SOURCE_UNAVAILABLE`, `IsPartial=1` sowie `ErrorNumber=NULL` und `ErrorMessage=NULL`, weil kein tatsächlicher SQL-Fehler vorliegt. Ihr Detail nennt die unbekannte Engineversion. Ein bereits vorhandener Datenbankstatus mit tatsächlichem Fehler bleibt einschließlich seines Fehlerpaars erhalten. Bei erhaltenen Featurezeilen ergibt der bestehende Aggregator `AVAILABLE_LIMITED` und einen partiellen Aufruf.

Ein tatsächlicher Fehler beim neuen Zugriff wird für die betroffene Datenbank isoliert. Bereits erhobene andere Featurezeilen und Ergebnisse anderer Datenbanken bleiben erhalten. Die neue Featurezeile verwendet `SOURCE_UNAVAILABLE` und eine unbekannte Anzahl. Die bestehende Datenbankstatuszeile wird partiell und erhält den ersten tatsächlichen nativen Fehler gemäß vorhandener Klassifikation: insbesondere `DENIED_PERMISSION` für 229, `TIMEOUT` für 1222, `UNAVAILABLE_OBJECT` für 207/208 und andernfalls `ERROR_HANDLED`. Ein bereits vorhandener Fehler derselben Datenbank wird nicht überschrieben. Bei erhaltenen Featureergebnissen wird der Aufrufstatus gemäß bestehendem Vertrag `AVAILABLE_LIMITED`. Der erste native Fehler bleibt an seine betroffene Datenbank gebunden; es gibt keine pauschale Umdeutung als Versionsfallback.

## Eigenlast und Testumfang

Der zusätzliche Zugriff ist eine lokale Katalogzählung je ausgewählter Datenbank. Es gibt weder Sampling noch Benutzer- oder Nutzdatenzugriffe. Der bestehende Lock-Timeout, die vollständige Callerrestaurierung, die Collation und die Beschränkung auf sichtbare Online-Datenbanken bleiben maßgeblich.

Die Abnahme prüft den unveränderten Ausgabeaufbau, die zusätzliche Zeile, Filter und Limit, gleichaufrufbezogene TABLE-/JSON-Parität sowie die Fehlerisolation. Ein SQL-Server-2025-Test verwendet ausschließlich eigene synthetische Katalogobjekte und ruft keine AI-Funktion auf. Ein erfolgreicher nativer Positivfall muss vor und nach der Inventur an dieselben eigenen Modellobjekte gebunden sein. Falls die vorhandene Engine die notwendige lokale Kataloganlage nicht ermöglicht, bleibt dieser Positivfall offen; eine private Testdouble-Zählung ersetzt ihn nicht. Ein gezielter älterer nativer Versionslauf prüft den Fallback ohne Katalogzugriff. Kein Imagebezug, Runtimeinstallation, Endpunktaufruf oder Credentialaufbau wird dadurch autorisiert.

Die bestehende `sys.external_models`-Quellenklasse und der öffentliche Featurecode sind der Umfang dieser Freigabe. Eine spätere External-Data-Procedure benötigt einen eigenen konkreten Vertrag.
