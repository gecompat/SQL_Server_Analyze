# Dossier: Vertrag für eigene SSIS-Kennzahlen

**Stand:** 26. Oktober 2026.
**Status:** Vertragsentwurf; nicht implementiert.
**Artefakt-UID:** `urn:uuid:01a179d8-4f3f-793f-893c-c3987e4cfdf1`.
**Registrierung:** `DEFERRED`; keine finale lesbare Kennung vergeben.
**Intake:** `SSIS-001`, Entwicklungsrang 15; bestehender Eintrag bleibt maßgeblich.

## Bestätigte Lücke

Der aktuelle [SSIS-Leitfaden](../../../Documentation/Analysis_Guides/10_SSIS.md)
beschreibt das statische Paketinventar, den Modellimport, Objektregeln,
Ausführungskorrelation, gebundene Paarvergleiche und Mehrlauf-Baselines.
Eigene Kennzahlen eines Produzenten werden dort und in den aktuellen
Analyze-Schnittstellen nicht als Produzentenvertrag bereitgestellt.

Die Treffer `UNKNOWN_METRIC_VALUE` in den Vergleichs- und Baselinequellen sind
Ausschlussgründe für einen vorhandenen, aber unbekannten beziehungsweise
nicht verwendbaren Kennzahlenwert. Sie bezeichnen keine Unterstützung eigener
Kennzahlen. Die kanonische interne Kennzahlenprojektion bildet feste
Beobachtungen aus Status, Dauer, Komponentenphasen und Pfadtransfers.

## Geprüfte Quellenbindung

Der aktuelle Toolbelt-Austauschvertrag v1.0.0 bindet Producerkennung und
-version, Source-Commit und Buildhash, DTSX-Bytehash und -länge, Format und
Profilversionen, Modellkennungen und Coverage. Die Analyze-Seite validiert das
Modell nativ und berechnet weder Parsersemantik noch Lineage.

Vergleich und Baseline nutzen je Capture eine gesonderte, registrierte lokale
Übergabe. Die Vergleichsbindung verlangt dieselbe Quellbindung,
Katalog-GUID, Projektkennung, Projekt-LSN, Archivkennung und Rootpaketdatei;
Modelltexte müssen bytegleich als UTF-16LE sein. Native Statistik-IDs bleiben
lokal pro Capture. Der Paarvergleich nutzt zwei explizite Captures; die
Baseline nutzt eine ausdrücklich gewählte Kohorte von 1 bis 20 Basisläufen
und einem Kandidaten. Gleiche Modellbytes belegen keine Arbeitslastgleichheit.

Diese bestehenden Quellen sind die fachlichen Eingangsgrenzen für den
[öffentlichen Vertragsentwurf](../../../Documentation/Architecture/SSIS_Custom_Metrics_Producer_Contract.md).
Der Entwurf ergänzt keine der beschriebenen Schnittstellen.

Ein späterer Kennzahlenbericht bleibt ein separates Objekt und ändert das
bytegebundene Toolbelt-Modell-JSON nicht. Er kann offline nach der Capture-
Aufnahme an deren registrierte Übergabe gebunden werden; die Captureaufnahme
benötigt ihn nicht. Die gültige Capturebindung bestätigt weder Wahrheit noch
Vollständigkeit selbstberichteter Werte. Auch bei identischer Bindung wird
keine Arbeitslastgleichheit, Systemgesundheit oder Ursache abgeleitet.

Die Erstphase bildet einen Laufwert für jede Kennzahl- und Scopekombination nur aus genau einer
beobachteten, vollständig qualifizierten Epoche; mehrere Epochen bleiben als
Einzelbeobachtungen mit `MULTIPLE_EPOCHS`-Coverage erhalten. Opake Epochkennungen
werden nicht zwischen Läufen gleichgesetzt. Das Erstphasenformat ist auf
nichtnegative Ganzzahlen `decimal(38,0)` als kanonischen ASCII-Dezimaltext
beschränkt; Bruchteile benötigen eine feinere Einheit mit neuer
Definitionsversion. Die maßgeblichen Einzelregeln stehen in den Abschnitten
[Epochen und Laufprojektion](../../../Documentation/Architecture/SSIS_Custom_Metrics_Producer_Contract.md#epochen-sequenzen-und-abschluss)
und [Werteformat](../../../Documentation/Architecture/SSIS_Custom_Metrics_Producer_Contract.md#typen-werte-und-einheiten).

## Umfang dieses Änderungsschritts

Der öffentliche Vertrag legt die logischen Bedeutungen von `DELTA`,
`CUMULATIVE`, `GAUGE` und `FINAL`, exakte Werte und Einheiten,
Producer-/Modell-/Capture-/Scopebindung, Epochen, Sequenzen,
Duplikate, Lücken, Abschlusswasserstände sowie spätere Aggregations- und
Vergleichsgrenzen fest. Ein synthetisches Beispiel illustriert die Feldideen;
es ist kein Schema oder API.

Es werden weder Toolbelt-Dateien noch Analyze-Code, Pakete, Tests,
Installationsartefakte oder SSISDB-Zustand geändert. Der Schritt übernimmt
keinen neuen Arbeitselementschlüssel und ändert die von der Root-Aufgabe
verwalteten Fortsetzungs- und Wellenregister nicht.

## Begrenzter späterer Implementierungsweg

Ein späterer, eigenständig geplanter Implementierungsschritt muss zuerst die
Producerdefinitions- und Eingabeform festlegen, die genannten Bindungen aus
dem vorhandenen Aufnahmeweg verifizieren und die Coverage- und
Vergleichsauswahl gegen die vier Metriktypen implementieren. Die erste
Implementierung sollte ausschließlich bereits explizit übergebene Werte
verarbeiten. Paketänderungen, automatische Instrumentierung, zusätzliche
Quellenabfragen, Nutzdatenlesung, Remoteausführung und neue Parser-/Lineage-
Implementierungen bleiben außerhalb dieses Vertrags.

Vor einer Produktumsetzung sind die Abnahmekriterien an den bestehenden
Vergleichs- und Baselinefällen auszurichten: stabile Definitionen,
exakte Einheiten, vollständige Capturebindung, Epochengrenzen,
Ein- und Mehrepochenläufe mit vollständig sowie partiell abgeschlossenen
Epochen, Sequenzlücken, identische und widersprüchliche Duplikate, unbekannte
und nichtganzzahlige Werte, nicht vergleichbare GAUGE-Fenster und Erhaltung
der vorhandenen Laufzeit- und Modellverträge. Diese Liste ist ein Plan, kein
Testnachweis.
