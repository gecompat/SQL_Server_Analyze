# WI-0006 und WI-0007: Compile-Kontext und External-Model-Inventur

**Stand:** 14. Oktober 2026  
**Umfang:** die unmittelbar freigegebenen lesenden Verträge von
`monitor.USP_CompileContextAnalysis` und `monitor.USP_SpecialFeatureInventory`.

## Qualifizierte Produktfunktion

Compile-Kontext trennt die ausgewählte Datenbankkonfiguration von serverweiten
Compile-Countern, Compile-Waits und Cachemetadaten. Snapshot und begrenztes
Sampling erhalten Scope, Zeitpunkt, Vergleichbarkeit und Resetgrenzen.
Vier TABLE-/JSON-Fälle sowie zehn synthetische Counter- und sieben synthetische
Waitprojektionen prüfen die Delta- und NULL-Regeln. Die synthetischen Werte
belegen die extrahierte Projektionslogik, keine tatsächlich ausgelösten Resets
oder Compile-Storm-Ursachen. SQL- und Planinhalte werden nicht gelesen.

Die Featureinventur ergänzt genau eine `EXTERNAL_MODELS`-Zeile je ausgewählter
Datenbank. Eigene native Modellanlage und sichtbare Anzahl eins auf SQL Server
2025 bestätigen den positiven Katalogpfad, vier Filter-/Limitfälle und
gleichaufrufbezogene TABLE-/JSON-Parität. Es wird keine Modellfunktion oder
externe Datenverbindung aufgerufen. Die positive Anzahl belegt sichtbare
Katalogobjekte, weder Erreichbarkeit noch Modellqualität. Auf SQL Server 2019
bleibt die Anzahl NULL mit `UNAVAILABLE_VERSION`; der erwartete Fallback
erzeugt keine Quellenpartialität.

Die privaten Procedurekopien prüfen eine lokale fehlende Selektorquelle mit
nativer Fehlernummer 208, unbekannte Major-Versionen, den ersten Fehler vor
einem späteren Quellenfehler und erhaltene andere Featureergebnisse. Sie sind
keine tatsächlichen Katalog-Berechtigungsfehler. Eine gezielte Schemaabweichung
prüft den Warning-Export. Hilfe, ungültige Eingaben und RAW-/CONSOLE-/NONE-
Ausgaben sind getrennt geprüft; die ungültige Kombination beider Filter besitzt
`INVALID_PARAMETER` ohne Quellenpartialität und ohne fachliche Quellenzeilen.

## Native Bindungen und Wiederverwendung

SQL Server 2025 17.0.4075.5 führt die betroffenen Verträge bei Compatibility
Levels 150, 160 und 170 aus. 182 abgeschlossene individuelle Tests aus den
früheren Läufen und der anschließend abgeschlossene Standalone-Test ergeben
183 wiederverwendete individuelle Prüfungen. Jede Wiederverwendung ist an
Produktquelle, betroffene Testdatei, unveränderte Abhängigkeiten, native Engine,
immutable Image und privat erhaltene Captures gebunden. Frühere Gesamtläufe
werden dadurch nicht zu erfolgreichen Gesamtläufen umgedeutet.

Der zehnte gemeinsame Versuch besteht nach 75.6954916 Sekunden. Er führt
ausschließlich die zuvor offenen privaten Hilfe-, Selektor-, Warning- und
Modellisolationsprüfungen aus. Danach besteht der gezielte SQL-2019-Fallback
15.0.4480.2/CL150 im elften gemeinsamen Versuch nach 49.7917702 Sekunden:
Smoke, Datenbankkandidaten, Feature-Collation, Compile-Kontext, Model-Inventur
und beide privaten Proben. SQL Server 2022 wird ohne eigenständiges neues
Versionsrisiko nicht zusätzlich gestartet.

Der qualifizierte native Producerstand ist
`0c7d53d11da401f873637f28a53b01ff4e59fd0a`. Die beiden Produktquellen besitzen
SHA256 `C6D778E778069F10C21438B5F9613E396C0916A922B02735E23D827C2BDEFE60`
und `F503D8D6416D792AD708B9AA5478C3FDC65D866F51EBE9F4889487CEEAEACE97`.
Die Resultat-SHA256 sind
`1BD0FCC674AB345CEA5AD96A01B71C4B6E450DD40482698CD609B0116D889D15`
und `E05FB1D0345C479C55B9E57EDA720B244837D99B90665324283F2850539712DE`.
Die neue Integration des bereits gelieferten WI-0005-Standes erhält diese
Produktquellen byteidentisch; der kombinierte Installer wird neu erzeugt und
das erforderliche Integrationsgate am endgültigen Head ausgeführt.

## Erhaltene Fehler und Cleanup

Alle neun früheren tatsächlichen Gesamtläufe bleiben `FAILED_NOT_QUALIFIED`.
Die ersten sechs enthalten korrigierte Smoke-/Ausgabezähler, ein zunächst
nicht ausreichend gespeichertes Modellorakel, eigene Temp-Tabellenreste und
einen ungeeigneten Standalone-Datenbankkontext. Die konkrete ursprüngliche
Modellorakelursache bleibt unbekannt. Lauf sieben scheitert am privaten
ConnectionStringBuilder-Zugriff, Lauf acht an der privaten Aufteilung eines
GO-Tokens in einem Kommentar. Der anschließend sprachbasierte Splitter erhält
die tatsächlichen Batches. Lauf neun besteht Standalone und Ausgabearten,
scheitert aber an einer falschen privaten Partialitätsassertion. Sie wird
gegen sieben gespeicherte native Fälle und vierzehn NULL-/Gegenmutationen
korrigiert; Produktcode und öffentlicher Vertrag bleiben erhalten.

Im neunten Lauf überschreibt eine private Calleraufnahme den Docker-
Vorherbestand. Dieser historische Vergleich bleibt `UNKNOWN_LOST`.
Ein neuer erfolgreicher Bestandsvergleich restauriert diesen verlorenen
Nachweis nicht. Die Wiederverwendung aus Lauf neun ist ausdrücklich auf die
vollständig abgeschlossenen fachlichen Komponenten begrenzt.

Im Integrationsgate scheitert anschließend ein bestehender DIAG-003-TABLE-Test
bei CL150 mit Fehler 53648. Ein früherer CI-Lauf mit gleichen ausführbaren
Produktquellen bestand; die konkrete Fehlerursache bleibt unbekannt, weil
seine Einzelbedingungen nicht gespeichert wurden. Der betroffene Test 121
prüfte Temp-Spalten über ein globales Namenspräfix. Die Korrektur bindet den
caller-sichtbaren eigenen Objektbezeichner, erhält alle sechs Wertbedingungen
und gibt jede entscheidende Bedingung vor der Assertion aus. Eine zusätzliche
eigene ähnlich benannte Seed-Tabelle prüft die Abgrenzung gegen unabhängige
Metadaten. Beide eigenen Tabellen werden nach Erfolg entfernt. Das enge
Review ist geschlossen; der geänderte Test muss im aktuellen Head-Gate neu
bestehen. Frühere Prüfungen dieser Testdatei werden dafür nicht wiederverwendet.
Das folgende Gate besteht Test121 bei CL150, bricht aber später im bestehenden
EV-SEVERE-Fall bei CL160 ab. Seine ursprüngliche Ursache bleibt unbekannt.
Test169 behält Ereignispredicate und Wartezeiten und ergänzt ausschließlich
vor Assertion ausgegebene Guardwerte sowie skalare native XEL-Gegenwerte am
eigenen Pfad. Ein Diagnosetypfehler für RAISERROR wird vor Ausführung korrigiert
und unabhängig geschlossen. Der nachfolgende Lauf erreicht diesen Fall nicht:
Er endet zuvor mit tatsächlichem Fehler 1222 bei eigener Temp-Anlage im
Datenbankselektor. Daraus wird keine Ursache des früheren XE-Abbruchs abgeleitet.

Der gemeinsame Selektor erhält deshalb ein getrenntes Lockwartebudget von
100 ms je eigener Temp-Anlage. Das Fenster enthält genau zwei CREATEs;
vor Parser-, Ziel- und Katalogzugriffen sowie im Fehlerweg gilt wieder NOWAIT.
Ein Fehler wird unverändert erneut ausgelöst; es gibt keine Retry-Schleife
oder Statusumdeutung und kein Gesamtlaufzeitversprechen. Test122 ergänzt
Caller0/137, positive Auswahl, Schema, Collation, fehlende Resultsets und
unveränderten äußeren SET-Scope. Der neue generische Helperstand verlangt
frische Primär-CI; frühere native Aufnahmen qualifizieren dieses Setupdelta
nicht. Der erhaltene SQL-2019-Nachweis beschreibt weiterhin die unveränderten
versionsabhängigen Produktzweige am ausdrücklich genannten Producerstand.
Das nächste Head-Gate besteht CL150 und CL160, bricht aber bei CL170 erneut
im EV-SEVERE-Fall ab. Die gespeicherten Werte zeigen gültiges JSON ohne
passendes Ereignis und einen unabhängigen XML-Lesefehler 1934. Das feste
SourceName-Label ist kein Nachweis eines falschen Dateipfads; die Ursache des
fehlenden Ereignisses bleibt unbekannt. Die Fixture erhält eine eigene
GUID-Datei, eine native Konfigurationspfadbindung und eine XE-Quelle, die nur
Fehler 50000 mit Severity16 des eigenen Callers erfasst. Die zwanzig erzeugten
Fehler, Wartezeiten, UTC-Grenzen und positive Consumerassertion bleiben
erhalten. Die unabhängige XML-Gegenprobe verwendet die von Microsoft
[vorgeschriebenen SET-Optionen](https://learn.microsoft.com/en-us/sql/relational-databases/xml/retrieve-and-query-xml-data?view=sql-server-ver17)
in einem eigenen dynamischen Scope. Sie verlangt zwanzig native Ereignisse
im Zeitfenster und unveränderte Calleroptionen; fehlende Werte oder native
Fehler erfüllen das Gate nicht. Ein neues exaktes Head-Gate qualifiziert diese
geänderte Fixture; kein früherer Fehlversuch wird nachträglich erfolgreich.

Die aktuellen erfolgreichen Läufe bestätigen Callerrestaurierung, eigene
SQL-Abwesenheit, öffentliche Bereinigung `REMOVED` mit null Fehlern,
unveränderte Quellenpins und Dockerbestände sowie abwesende eigene States.
Originale, Identitäten, Logs und Captures bleiben privat. Alle elf tatsächlichen
Versuche bleiben im gemeinsamen Budget gezählt; WI-0007 startet keine eigene
Runtime. Das unabhängige Quellen-, Fixture-, Adapter- und Ergebnisreview ist ohne offene P1/P2 abgeschlossen;
die erforderlichen Liefergates werden getrennt vom funktionalen Nachweis
abgeschlossen.

Die freigegebenen [WI-0006](../../../Documentation/Architecture/WI0006_Compile_Context_Public_Specification.md)-
und [WI-0007](../../../Documentation/Architecture/WI0007_External_Model_Inventory_Public_Specification.md)-
Verträge bestimmen den Umfang. Automatisches Tuning, Ursachenbehauptungen,
Konfigurationsänderungen und Modell-Endpunktaufrufe gehören nicht dazu.
