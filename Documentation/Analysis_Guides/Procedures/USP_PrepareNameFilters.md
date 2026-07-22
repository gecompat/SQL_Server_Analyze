# [monitor].[USP_PrepareNameFilters]

**Bereich:** Common, interner Filtervertrag<br>
**Zweck:** Validiert und zerlegt case-sensitive, bracket-aware Namensfilter.<br>
**Beobachtungsart:** Aufrufbezogene Validierung<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Wurde eine Namenliste syntaktisch eindeutig und unter der case-sensitiven Frameworksemantik aufbereitet?** Der dokumentierte Zweck ist: Validiert und zerlegt case-sensitive, bracket-aware Namensfilter. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob der gewünschte Analysepfad sicher und eindeutig vorbereitet ist oder der Fachaufruf wegen Policy, Capability oder ungültigem Scope unterbleiben muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Performance- oder Verfügbarkeitsursache und keine Aussage über Daten außerhalb des aktuellen Execution-Kontexts. Ihr Zeitvertrag lautet ausdrücklich: Nur für den aktuellen Aufruf; keine Persistenz. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

Die Procedure erwartet eine über `@FilterTable` eindeutig benannte lokale Temp-Tabelle mit festem Schema. Benutzer rufen die jeweilige Analyse-Procedure mit deren Filterparametern auf.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Diese Hilfsprocedure besitzt bewusst keinen öffentlichen TABLE-Export. Sie befüllt die vom Parent bereitgestellten Temp-Strukturen beziehungsweise OUTPUT-Statuswerte. Zuerst sind Status und Warnungen des Parents zu lesen; erst danach darf dessen Fachresultset interpretiert werden. Ein direkter Aufruf ohne den dokumentierten Tabellenvertrag ist kein Ersatz für den Parentpfad.

## Eine Zeile bedeutet

Eine Zeile in der über `@FilterTable` benannten Tabelle entspricht einem normalisierten Filterelement, beispielsweise Schema, Objekt, Index, Statistik oder vollständig qualifiziertes Objekt.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Filtertyp, Status und tatsächliche Zeilenzahl prüfen. Bei Fehlern wird die Temp-Tabelle absichtlich geleert.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Eine leere Filtertabelle nach `INVALID_PARAMETER` darf nicht als „kein Filter“ behandelt werden. Sonst könnte eine nachfolgende Analyse versehentlich zu breit laufen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Unter der case-sensitiven Projektcollation sind `ExampleTable` und `exampletable` unterschiedliche Namen.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Doppelte identische Namen führen absichtlich zu einem Fehler; nur in Groß-/Kleinschreibung verschiedene Namen nicht. Eingabe korrigieren und den öffentlichen Aufruf wiederholen.

**Ähnlich aussehender Gegenfall:** Unter der case-sensitiven Projektcollation sind `ExampleTable` und `exampletable` unterschiedliche Namen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Hilfsprocedures kann eine leere interne Zieltabelle aus bewusst leerem Filter, ungültiger Eingabe oder fehlender Policy entstehen; diese Fälle dürfen nicht zu einem ungefilterten Parentlauf zusammenfallen.

Für `USP_PrepareNameFilters` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Parst bis zu sechs übergebene Pipe-Listen über die Framework-TVFs, validiert Exklusivität/Duplikate und schreibt gültige Zeilen in eine bereits vom Parent angelegte lokale Temp-Tabelle. Ohne Listen bleibt die Ausgabe leer. |
| Teuerster Pfad | Sehr lange Listen mit vielen bracket-aware Elementen in allen sechs Parametern; `@FullObjectNames` benötigt zusätzlich die Zerlegung in Datenbank, Schema und Objekt. Ungültige oder doppelte Werte werden erst nach der Parserarbeit erkannt. |
| Haupttreiber | Zeichenlänge und Elementzahl von Schema-, Objekt-, Full-Object-, Index-, Statistik- und Spaltenlisten. Es gibt keine Datenbankkandidaten-, Capability-, Login-Token- oder Fachquellenabfrage. |
| Skalierung | Parser- und UNION-ALL-Arbeit wächst linear mit den Elementen; die case-sensitive Duplikatprüfung gruppiert die materialisierte Worktable und kann bei sehr großen Listen zusätzliche TempDB-CPU benötigen. |
| Ressourcen | CPU für String-/Identifierparser, eine lokale Worktable und dynamisches SQL für Schema-Prüfung/Insert der vom Parent benannten lokalen Temp-Tabelle. Kein Katalog- oder Nutzdatenscan. |
| Begrenzungswirkung | Es existiert kein Zeilenlimit: Vollständige Validierung ist Teil des Sicherheitsvertrags. Begrenzen lässt sich die Arbeit nur durch kleine Eingabelisten; `@FilterTable` ist auf einen lokalen `#`-Namen mit maximal 116 Zeichen beschränkt. |
| Locking und Nebenwirkungen | Schreibt ausschließlich in lokale Temp-Tabellen der aufrufenden Session. Keine fachliche Datenänderung und kein Security-Token-Lesen; dynamisches SQL prüft nur die erwarteten Spalten der Zieltabelle und fügt validierte Werte ein. |
| Schutzmechanismus | Kein Analyse-Gate, weil dies ein interner Parser ist. Er akzeptiert nur lokale `#`-Temp-Tabellennamen bis 116 Zeichen, prüft die erwartete Zieltabelle, erzwingt die Exklusivität vollständiger versus getrennter Objektnamen und lehnt syntaktisch ungültige oder case-sensitiv doppelte Werte ab; ein Mengenbudget müssen die aufrufenden Module setzen. |
| Sicherer Einsatz | Nur nach Anlegen der dokumentierten lokalen Zieltabelle und zunächst mit einer kleinen `ExampleSchema`-/`ExampleObject`-Liste aufrufen. `INVALID_PARAMETER` muss den Parent stoppen und darf nie in ungefilterte Analyse umgedeutet werden. |
| Aussagegrenze | Die Procedure bestätigt ausschließlich Syntax, Exklusivität und case-sensitive Eindeutigkeit. Sie prüft nicht, ob Datenbank, Schema, Objekt, Index, Statistik oder Spalte tatsächlich existieren oder für den Aufrufer sichtbar sind. |

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

## Primärquellen

- [QUOTENAME](https://learn.microsoft.com/en-us/sql/t-sql/functions/quotename-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../01_Common.md#5-monitorusp_preparenamefilters)
