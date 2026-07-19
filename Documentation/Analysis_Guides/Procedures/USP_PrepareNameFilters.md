# [monitor].[USP_PrepareNameFilters]

**Bereich:** Common, interner Filtervertrag  
**Zweck:** Validiert und zerlegt case-sensitive, bracket-aware Namensfilter.

## Kein normaler Direktaufruf

Die Procedure erwartet eine lokale Temp-Tabelle mit festem Schema. Benutzer rufen die jeweilige Analyse-Procedure mit deren Filterparametern auf.

## Eine Zeile bedeutet

Eine Zeile in `#NameFilters` entspricht einem normalisierten Filterelement, beispielsweise Schema, Objekt, Index, Statistik oder vollständig qualifiziertes Objekt.

## So lesen

Filtertyp, Status und tatsächliche Zeilenzahl prüfen. Bei Fehlern wird die Temp-Tabelle absichtlich geleert.

## Warum kann das problematisch sein?

Eine leere Filtertabelle nach `INVALID_PARAMETER` darf nicht als „kein Filter“ behandelt werden. Sonst könnte eine nachfolgende Analyse versehentlich zu breit laufen.

## Wann ist es kein Problem?

Unter der case-sensitiven Projektcollation sind `ExampleTable` und `exampletable` unterschiedliche Namen.

## Beispiel und Folgeschritt

Doppelte identische Namen führen absichtlich zu einem Fehler; nur in Groß-/Kleinschreibung verschiedene Namen nicht. Eingabe korrigieren und den öffentlichen Aufruf wiederholen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wurde eine Namenliste syntaktisch eindeutig und unter der case-sensitiven Frameworksemantik aufbereitet?

### Technischer Hintergrund

Die Procedure ist ein Schutzbaustein für Filter. Quote-/Bracket-aware Parser verhindern, dass Trenner innerhalb korrekt geklammerter Namen falsch zerlegt werden. Validierte Werte werden in Temp-Strukturen geschrieben; ungültige Eingaben führen kontrolliert zu leerem/ungültigem Filterstatus.

### Datenkette

Frameworkinterne Orchestrierung/Filterlogik; keine eigenständige Systemquelle.

### Zeit- und Scope-Modell

Nur für den aktuellen Aufruf; keine Persistenz.

### Bewertung und Gegenprobe

Case-Sensitivität, Duplikate, leere Elemente und ungültige Quote-/Bracketstruktur explizit behandeln. Ein absichtlich leerer Filter und ein aufgrund von Fehler geleerter Filter müssen unterscheidbar bleiben.

### Typische Fehlinterpretation

Eine leere Filtertabelle nach `INVALID_PARAMETER` darf nie als Freigabe für eine ungefilterte breite Analyse dienen.

### Folgeanalyse

Eingabe korrigieren und das aufrufende Fachmodul erneut starten.

[Technische Detailbeschreibung](../01_Common.md#4-monitorusp_preparenamefilters)
