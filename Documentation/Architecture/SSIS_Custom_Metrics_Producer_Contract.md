# SSIS-Vertrag für eigene Kennzahlenproduzenten

**Status:** Vertragsentwurf; nicht implementiert und keine öffentliche API.
**Geltung:** optionales, explizites Austauschformat für eigene SSIS-Laufzeitkennzahlen.
**Artefakt-UID:** `urn:uuid:01a179d8-4406-7dd2-97db-f4d82ab95e4c`.
**Registrierung:** `DEFERRED`; keine finale lesbare Referenz vergeben.

## Zweck und Grenze

Dieser Vertrag beschreibt, wie ein eigenständiger Produzent eigene Kennzahlen
als explizite, versionierte Beobachtungen bereitstellen kann. Er standardisiert
die Bedeutung der Typen `DELTA`, `CUMULATIVE`, `GAUGE` und `FINAL`, ihre
Einheiten, Modell- und Ausführungsbindung sowie den Umgang mit Epochen,
Sequenzlücken und Duplikaten. Er beschreibt keine Implementierung in Analyze
oder Toolbelt und erweitert keine bestehende Schnittstelle.

Eine spätere Übergabe muss ausdrücklich durch einen Caller erfolgen. Analyze
liest dafür weder Paketnutzdaten noch zusätzliche Laufzeitquellen, startet
oder instrumentiert keine Pakete und führt keine entfernten Producer aus.
Parser, Komponentenprofile und Lineage bleiben beim Toolbelt. Analyze bleibt
ohne SQL CLR eigenständig nutzbar; eine künftige Kennzahlenaufnahme darf diese
Grenzen nicht verschieben. Die installierte SSISDB bleibt unverändert.

## Begriffe und Producerdefinition

Ein Producer veröffentlicht vor seinen Werten eine versionierte Definition
pro Kennzahl. Die Definition enthält mindestens eine stabile, producerlokale
Kennungszeichenfolge, ihre Definitionsversion, den Typ, die kanonische Einheit,
den fachlichen Scope und die Aggregationsregel. Eine Änderung an Bedeutung,
Typ, Einheit oder Aggregation erfordert eine neue Definitionsversion. Der
Anzeigename dient nur der Darstellung und ist kein Identitätsschlüssel.

Eine Beobachtung ist eine einzelne exakte Messung innerhalb einer gebundenen
Ausführung. Sie besteht logisch aus folgenden Feldern; dies ist kein JSON-
Schema und legt keine API, Tabellenform oder Resultsetnamen fest:

| Feld | Bedeutung |
|---|---|
| `metricProducer` | Stabile Kennung des Kennzahlenproduzenten, Producer-Version, vollständiger Source-Commit und Hash des verwendeten Builds. Diese Identität ist von der `producer`-Identität des Toolbelt-Modellexports getrennt. Die Angaben beschreiben Herkunft, authentifizieren sie jedoch nicht. |
| `metric` | Stabile Kennung, Definitionsversion, Typ und Einheit aus der veröffentlichten Definition. |
| `scope` | Exakte Modellrevision und ein vorhandener Paket- oder Modellobjektbezug. Ein beobachteter Aufrufpfad darf nur verwendet werden, wenn er aus dem gebundenen Capture eindeutig aufgelöst wurde. |
| `execution` | Laufkennung und separat attestierte lokale Capture-Übergabe; die Kennung allein ist kein Laufzeitbeleg. |
| `epoch` und `sequence` | Opaquer Epochenbezeichner und streng steigende, positive Sequenznummer innerhalb der definierten Metrikserie. |
| `observedAtUtc` | Beobachtungszeitpunkt in UTC. Er ersetzt weder die Sequenz noch eine Capturebindung. |
| `value` | Kanonischer ASCII-Dezimaltext für einen nichtnegativen Ganzzahlwert oder ein ausdrücklich unbekannter Wert mit getrenntem Status und Reason-Code. Binäre Gleitkommawerte, NaN und Unendlich sind unzulässig. |

Der fachliche Serienschlüssel ist die Kombination aus gebundener Ausführung,
Producer und Producer-Version, Kennungszeichenfolge und Definitionsversion,
exaktem Scope sowie Epoche. Werte mit unterschiedlicher Einheit oder
Definition gehören zu getrennten Serien. Freie Dimensionen, Paketnamen,
Connection Strings, Parameterwerte und nicht erforderliche Textpayloads sind
nicht Bestandteil dieses Vertrags.

## Ausführungs-, Modell- und Scopebindung

Eine spätere Aufnahme darf Werte nur zusammen mit derselben unabhängigen
Herkunftskette akzeptieren, die bereits für Modellanalyse und Vergleich gilt:

- Das Modell ist der unverändert übergebene Export mit seinen Producer-,
  Source-Commit-, Buildhash-, DTSX-Bytehash-, Format- und Profilbindungen.
- Das Laufzeitcapture stammt aus einer getrennten, ausdrücklich registrierten
  lokalen Übergabe. Capture und Attest müssen dieselbe Quellbindung,
  Katalog-GUID, Projektkennung, Projekt-LSN, Archivkennung und Rootpaketdatei
  belegen.
- Vergleichsseiten benötigen bytegleiche UTF-16LE-Modelltexte und die
  bestehende Laufzeitkontextbindung. Eine abweichende oder fehlende Bindung
  macht die Beobachtung nicht vergleichbar.
- Ein Scope verweist auf eine stabile Paket- oder Modellobjektkennung. Für
  wiederholte Aufrufstellen ist zusätzlich der eindeutige, aus dem Capture
  gebundene Ausführungspfad erforderlich. Laufzeiteigene Statistik-IDs bleiben
  lokal für ihren Capture und werden nie über Ausführungen hinweg verbunden.

Der Kennzahlenbericht ist ein separates, unabhängig übergebenes Objekt. Er
ergänzt oder verändert das bytegebundene Toolbelt-Modell-JSON nicht. Seine
Referenzen binden ihn nachträglich an die bereits attestierte Modell- und
Captureherkunft; sie ersetzen kein bestehendes Feld im Modellvertrag. Ein
erster offlinefähiger Übergabepfad kann den Bericht erst nach Aufnahme und
Registrierung des Captures an dessen Handover-Kennung binden. Die
Captureaufnahme benötigt den Kennzahlenbericht nicht. So entsteht kein
gegenseitiger Verweiszyklus.

Diese Anforderungen folgen dem bestehenden Austausch-, Capture- und
Vergleichsvertrag. Eine gültige Modell-/Capturebindung bestätigt nur die
Herkunftskette des Captures; sie beweist weder Wahrheit noch Vollständigkeit
selbstberichteter Kennzahlen. Producerangaben authentifizieren keinen externen
Producer. Unbestätigte Messwerte und Herkunft bleiben unbestätigt und dürfen
nicht durch weitere Rechte, Netzwerkzugriffe oder automatische Infrastruktur
ergänzt werden.

## Typen, Werte und Einheiten

Jede Definition wählt genau einen Typ. Das Consumerverhalten darf nicht aus
Kennungsnamen, Anzeigenamen oder Wertepunkten erraten werden.

| Typ | Bedeutung pro Serie | Zulässige Aggregation für einen Lauf |
|---|---|---|
| `DELTA` | Nicht negativer Zuwachs seit der vorherigen Sequenz derselben Epoche. Ein Wert ist bereits ein Intervallzuwachs. | Summe der lückenlosen, eindeutigen Zuwächse der einzigen vollständig abgeschlossenen Epoche des Laufs. Werte werden nicht erneut differenziert. |
| `CUMULATIVE` | Nicht negativer, monotoner Stand seit dem expliziten Nullpunkt derselben Epoche. | Letzter eindeutiger Stand der einzigen vollständig abgeschlossenen Epoche des Laufs. Zwischenstände werden nicht summiert. |
| `GAUGE` | Momentaufnahme eines veränderlichen Zustands zum Beobachtungszeitpunkt. | Nur eine vorab benannte Auswahlregel, etwa letzter Wert in einem definierten Beobachtungsfenster der einzigen abgeschlossenen Epoche. Ohne gleiche Auswahlregel und vergleichbares Fenster gibt es keinen Laufvergleich. |
| `FINAL` | Ein einzelner endgültiger Skalar für eine Serie und Ausführung. Er ist kein Zwischenstand. | Genau ein eindeutiger Abschlusswert in der einzigen abgeschlossenen Epoche. Mittelwert, Summe und Auswahl des letzten unter mehreren widersprüchlichen Endwerten sind unzulässig. |

Die Einheit ist ein erforderlicher, versionsgebundener Vertragswert. Sie muss
eine kanonische Bedeutung festlegen, etwa `count`, `bytes` oder `ms`; bloße
Skalierung oder Bezeichnung als `number` genügt nicht. Zeitwerte bezeichnen
keine CPU-Zeit, sofern die Definition dies nicht fachlich und messbar
spezifiziert. Es findet keine automatische Umrechnung zwischen Einheiten,
Definitionen oder Producer-Versionen statt.

Die Erstphase akzeptiert ausschließlich nichtnegative Ganzzahlwerte im
Bereich von 0 bis 10^38−1, entsprechend `decimal(38,0)`. Der Zahlenwert wird als
kanonischer ASCII-Dezimaltext `0` oder `[1-9][0-9]{0,37}` übertragen. Vorzeichen,
führende Nullen, Dezimalpunkt, Exponent, Localeformat, Leerraum und
Gleitkommadarstellung sind unzulässig. Diese Regel gilt für alle vier Typen,
einschließlich `GAUGE` und `FINAL`. Ungültige oder nicht darstellbare Werte
werden weder gerundet noch abgeschnitten; die betroffene Serie ist für die
Auswertung begrenzt.

Ein unbekannter Wert verwendet einen getrennten Status mit Reason-Code und
besitzt keinen Zahlenwert. Er ist kein Nullwert. Fehlt eine Beobachtung ganz,
wird sie nicht als Null oder als unbekannter Einzelwert erfunden. Ein Producer,
der einen fachlichen Bruchteil messen muss, kann vor der Messung eine feinere
Ganzzahleinheit als neue Definitionsversion veröffentlichen. Consumer führen
keine automatische Umrechnung oder Rundung aus; nichtganzzahlige Metriken
bleiben außerhalb der Erstphase.

## Epochen, Sequenzen und Abschluss

Eine Epoche kennzeichnet einen ununterbrochenen Lebenszyklus der Serie. Ein
Producer beginnt eine neue Epoche bei Reset, Neustart, Überlauf, Änderung des
Messverfahrens oder Verlust der Zählerkontinuität. Sequenzen beginnen je Epoche
bei 1 und steigen strikt an. Werte aus zwei Epochen werden weder differenziert
noch summiert oder gepaart.

Ein Producer muss den erwarteten letzten Sequenzwert je abgeschlossener Epoche
melden. Ohne diesen Abschlusswasserstand kann ein Consumer keine vollständige
Reihe feststellen; die Serie bleibt für Vollständigkeitsbehauptungen partiell.
Ein Epochenwechsel darf die fehlenden Endsequenzen der vorherigen Epoche nicht
stillschweigend schließen. Für `CUMULATIVE` muss der Producer den Nullpunkt der
neuen Epoche ausdrücklich belegen; andernfalls ist der Startstand unbekannt
und eine Differenz über den Reset ausgeschlossen.

Eine Lücke bleibt sichtbar und wird nicht interpoliert. Bei `DELTA` kann eine
Summe mit Lücke keinen vollständigen Laufwert bilden. Ein `CUMULATIVE`-Endstand
mit Lücke kann als Einzelbeobachtung erhalten bleiben, belegt aber nicht die
Sequenzvollständigkeit. Ein `GAUGE` zwischen fehlenden Zeitpunkten ist kein
Ersatz für eine fehlende Momentaufnahme. `FINAL` ist nur gültig, wenn genau ein
Abschlusswert der Serie vorliegt und der Producer den Abschluss der Serie
bestätigt.

Eine Laufprojektion ist für jede Kennzahl- und Scopekombination nur zulässig,
wenn im Lauf genau eine Epoche beobachtet wurde und diese sämtliche
Abschluss-, Coverage- und Typbedingungen erfüllt. Bei mehreren beobachteten
Epochen bleiben die Einzelbeobachtungen erhalten, aber der Consumer wählt
keine Epoche aus, summiert oder kombiniert keine Epochen und erzeugt weder
Lauf- noch Baselinewert. Das gilt auch, wenn eine Epoche vollständig und eine
weitere unvollständig ist. Die Coverage nennt dafür ausdrücklich
`MULTIPLE_EPOCHS`. Über Ausführungen hinweg müssen die opaken Epochenkennungen
nicht übereinstimmen und werden nicht miteinander verglichen; jede Ausführung
muss ihre eigene einzelne qualifizierte Epoche besitzen.

## Duplikate und Konflikte

Die Eindeutigkeit gilt je Seriensschlüssel, Epoche und Sequenznummer. Ein
bytegleich identisches Duplikat derselben Beobachtung ist idempotent und wird
höchstens einmal berücksichtigt; sein Auftreten bleibt als
Duplikatabdeckung zählbar. Weichen Werte, Zeitstempel oder Definitionen für
denselben Schlüssel ab, wird die betroffene Epoche als mehrdeutig markiert.
Es gibt keine Regel „letzter Wert gewinnt“ und keine Auswahl nach
Eingangsreihenfolge.

Für `FINAL` gilt höchstens ein Abschlusswert je Serie und gebundener
Ausführung. Mehrere widersprüchliche Abschlüsse machen die Serie ungültig.
Ein erneuter identischer Abschluss darf als idempotentes Duplikat erkannt
werden. Nach dem Abschluss angenommene weitere Beobachtungen verletzen den
Producervertrag.

## Vergleich und Baseline

Eine zukünftige Vergleichs- oder Baselineauswertung darf eine Kennzahl nur
einbeziehen, wenn beide Seiten dieselbe exakte Modellrevision, Definition,
Producerkennung und Producer-Version, Einheit, Typ, Scopeidentität und
Auswahlregel erfüllen. Die bestehende Vergleichsgrenze für Ausführung,
Capture, Kontext und Coverage gilt zusätzlich. Keine dieser Bedingungen
beweist gleiche Arbeitslast, Systemgesundheit oder eine Ursache für
beobachtete Unterschiede. Eine vorhandene Vergleichs- oder Baselinebindung
erklärt die Vergleichbarkeit der Eingaben, nicht deren fachliche Wahrheit.

`DELTA` wird nur aus der einzigen vollständig qualifizierten Epoche pro Lauf
aggregiert; `CUMULATIVE` verwendet deren belegten Abschlussstand; `FINAL`
erfordert genau einen belegten Abschlusswert. `GAUGE` ist nur vergleichbar,
wenn die Definition ein gemeinsames Zeitfenster und eine identische
Auswahlregel festlegt. Andernfalls bleibt der Wert deskriptiv. Ein
Laufvergleich oder Baselinewert entsteht für keinen Typ bei mehreren
beobachteten Epochen. Unbekannte Werte,
Sequenzlücken, widersprüchliche Duplikate, fehlende Epochenabschlüsse,
mehrdeutige Scopes oder ungleiche Definitionen werden nicht zu Nullwerten und
erzeugen keine numerischen Deltas. Sie müssen als Coverageeinschränkung
erhalten bleiben.

Eine Baseline verwendet ausschließlich eine explizit ausgewählte Kohorte und
einen Kandidaten nach dem vorhandenen SSIS-Baselinevertrag. Die Kohorte wird
weder automatisch gesucht noch dauerhaft verwaltet. Für `GAUGE` darf eine
Median- oder Spannweitenbildung nur erfolgen, wenn die veröffentlichte
Auswahlregel dieselbe messbare Beobachtungsbedeutung auf allen Läufen erzeugt.

## Synthetisches Beispiel

Das folgende Fragment ist eine synthetische logische Vorlage. Kennungen,
Hashes und Werte sind erfunden. `NOT-A-REAL-COMMIT` ist absichtlich kein
gültiger Commitwert; das Fragment ist weder ein gültiges vollständiges
Übergabedokument noch ein freigegebenes JSON-Schema oder ein implementierbarer
Aufrufvertrag.

```json
{
  "metricProducer": {
    "id": "example.metrics",
    "version": "1.0.0",
    "sourceCommit": "NOT-A-REAL-COMMIT",
    "buildSha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  },
  "execution": {"id": 17, "captureHandoverId": "00000000-0000-7000-8000-000000000001"},
  "model": {"sourceSha256": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", "nodeId": "cmp1"},
  "series": [
    {"metricId": "records-written", "definitionVersion": "1.0.0", "kind": "DELTA", "unit": "count", "epoch": "e1", "sequence": 1, "expectedFinalSequence": 1, "observedAtUtc": "2026-01-01T00:00:01Z", "value": "12"},
    {"metricId": "bytes-read", "definitionVersion": "1.0.0", "kind": "CUMULATIVE", "unit": "bytes", "epoch": "e1", "sequence": 1, "expectedFinalSequence": 1, "observedAtUtc": "2026-01-01T00:00:01Z", "value": "4096"},
    {"metricId": "queue-depth", "definitionVersion": "1.0.0", "kind": "GAUGE", "unit": "count", "epoch": "e1", "sequence": 1, "expectedFinalSequence": 1, "observedAtUtc": "2026-01-01T00:00:01Z", "value": "3"},
    {"metricId": "rejected-records", "definitionVersion": "1.0.0", "kind": "FINAL", "unit": "count", "epoch": "e1", "sequence": 1, "expectedFinalSequence": 1, "observedAtUtc": "2026-01-01T00:00:02Z", "value": "0", "final": true}
  ]
}
```

## Implementierungsgrenze

Dieser Entwurf liefert keine Parser-, Transport-, Producer-, Capture-, SQL-,
Resultset-, Installer- oder Testimplementierung. Eine spätere Implementierung
benötigt einen eigenen freigegebenen Umfang und muss festlegen, wie der
logische Vertrag in versionierte Producerdefinitionen, Eingabevalidierung,
Coverage und bestehende SSIS-Capturebindungen überführt wird. Der Entwurf
autorisiert keine Änderungen an Paketen, SSISDB, Toolbelt, Netzwerk,
Installation oder Benutzerrechten.

## Bestehende Verträge

- [SSIS-Leitfaden](../Analysis_Guides/10_SSIS.md)
- [Austauschvertrag zwischen Analyze und Toolbelt](SSIS_Analyze_Toolbelt_Exchange_Contract.md)
- [Vertrag für Ausführungsvergleiche](../Analysis_Guides/Procedures/USP_SsisExecutionComparison.md)
- [Vertrag für Mehrlauf-Baselines](../Analysis_Guides/Procedures/USP_SsisExecutionBaseline.md)
