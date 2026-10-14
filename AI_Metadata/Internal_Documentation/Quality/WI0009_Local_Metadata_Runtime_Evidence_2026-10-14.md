# WI-0009: Begrenzte Abnahme der lokalen External-Data-Analyse

**Stand:** 14. Oktober 2026  
**Umfang:** freigegebener lokaler Metadatenvertrag von `monitor.USP_ExternalDataAnalysis`.

## Qualifizierter portabler Kern

SQL Server 2025 17.0.4075.5/CL170 und SQL Server 2019 15.0.4480.2/CL150
bestätigen jeweils vier TABLE-/JSON-Fälle an eigenen leeren nativen Katalogen.
`NULL`, `0`, `1` und `2000` als Zeilenlimits erhalten die nativen Objektcounts;
die positive Grenze reduziert nur die ausgegebenen Detailzeilen. Alle acht
physischen Exports entsprechen ihren gleichaufrufbezogenen JSON-Arrays.
Der ältere Enginezweig liefert für External Models NULL und
`UNAVAILABLE_VERSION`, ohne einen Quellenfehler zu erfinden.

Die private Testkopie ersetzt genau sechs Quellenabfragen durch ausdrücklich
synthetische Projektionen oder lokale fehlende Objekte. Vier identitätsgebundene
Tabellen unterscheiden NULL-, Nullwert-, sichtbare und unsichtbare Referenzen.
Fehlende Schema- und Spaltenquellen erhalten Tabellenidentitäten mit NULL für
die ausgefallenen Ergänzungen. Sieben Primär- und sechs Fallbackfälle prüfen
unabhängig erhobene native Fehler 208, deren erste Fehlerpaare und die Erhaltung
anderer Quellen. Diese Kopien qualifizieren die Projektions- und Fehlerlogik,
keine positiven echten External-Table-Kataloge oder tatsächlichen
Katalog-Berechtigungsfehler. Kein Modell- oder Datenendpunkt wird aufgerufen.

Die neue Procedure ist in Installer, Inventaren, Navigator und Referenzen
enthalten. Die native Primärabnahme bestätigt Smoke, TABLE-, CONSOLE- und
frameworkweite Ausgabeprüfungen sowie den Navigator. Fünf abgeschlossene
Einzeltests des ersten Laufs werden am unveränderten Produktbaum mit gleichen
Quellenpins, Abhängigkeiten, Engine und immutablem Image wiederverwendet.
Der erste Gesamtlauf bleibt `FAILED_NOT_QUALIFIED`: Sein Navigator-Test
verlangte noch 107 statt der tatsächlich neuen 108 Katalogeinträge. Die
Korrektur betrifft ausschließlich diesen Test; der zweite Primärlauf führt
den korrigierten Navigator und die zuvor offenen privaten Proben aus.

## Bindungen und Cleanup

Der qualifizierte Produktstand ist `206e43a538b95339c424c58e423b5a7f25755a16`.
Die Produktquelle 110 besitzt SHA256
`59F90287742552BA94F65CEE986C6E99A387DD04D99FE745E20863ACB2428782`.
Der zweite Primärlauf besteht nach 34.8715506 Sekunden, der einzige
SQL-2019-Fallback nach 33.7373153 Sekunden. Native Captures werden vor
Assertions privat gespeichert. Callerzustand, eigene Datenbank- und
Prozedurabwesenheit, öffentliche Bereinigung mit null Fehlern, Quellenpins
und Dockerbestände sind bestätigt; eigene Stateverzeichnisse sind abwesend.

Die Resultat-SHA256 sind
`2F43DC4B5081D132E7C8A840A03E177C70CD0F0F3A87E7CAC6E888C12898CF53`
und `CCE475424FAEEF5112009F68B157701E4C23097D138B730886AC4EB108548F6C`.
Logs, Identitäten und Originalcapturen bleiben privat. Das unabhängige
Quellen-, Fixture-, Adapter- und Ergebnisreview ist ohne offene P1/P2
abgeschlossen. Das begrenzte eigene Budget zählt drei tatsächliche Versuche;
der Fehlversuch wird nicht zurückgesetzt. Die früheren WI-0005- und
WI-0006/0007-Budgets werden dafür nicht verwendet.

## Ausstehende positive Feature-Abnahme

Eine echte External Table mit sichtbaren Datenquellen-, Dateiformat-, Schema-
und Spaltenreferenzen ist noch nicht nativ abgenommen. Microsoft dokumentiert,
dass bereits [CREATE EXTERNAL TABLE](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-table-transact-sql?view=sql-server-ver17)
eine Verbindung öffnen oder einen externen Pfad anlegen kann. Ein erfundener
oder fremder Endpunkt ist deshalb keine geeignete synthetische Testquelle.
Die öffentliche Lab-Quelle besitzt für den geprüften Stand noch keinen
ausführbaren Object-Store-/PolyBase-Lifecycle. Eine separat gebundene eigene
Quelle und ihre veröffentlichte Lab-Abnahme sind erforderlich. Bis dahin
bleibt dieses Feature-Gate ausdrücklich offen.

Die [Spezifikation](../../../Documentation/Architecture/WI0009_External_Data_Public_Specification.md)
und der Code implementieren den portablen lesenden Vertrag. Diese begrenzte
Evidenz behauptet weder positive echte External-Table-Referenzqualifikation
noch Remotezugriff, Connectivitytests oder ein allgemeines Gesundheitsurteil.
Die reguläre Lieferung wartet zusätzlich auf die vorgelagerte WI-0006/0007-
Integration und anschließend auf betroffene lokale Gates und exakte Head-CI.
