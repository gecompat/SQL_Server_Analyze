# [monitor].[USP_CheckAnalyseAccess]

**Bereich:** Common<br>
**Zweck:** Prüft, ob der aktuelle Sicherheitskontext eine Analyseklasse gemäß Framework-Policy ausführen darf.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Erlaubt die Frameworkpolicy dem aktuellen Sicherheitskontext die angeforderte Analyseklasse?** Der dokumentierte Zweck ist: Prüft, ob der aktuelle Sicherheitskontext eine Analyseklasse gemäß Framework-Policy ausführen darf. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob der gewünschte Analysepfad sicher und eindeutig vorbereitet ist oder der Fachaufruf wegen Policy, Capability oder ungültigem Scope unterbleiben muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Performance- oder Verfügbarkeitsursache und keine Aussage über Daten außerhalb des aktuellen Execution-Kontexts. Ihr Zeitvertrag lautet ausdrücklich: Momentaufnahme des aktuellen Login- und Execution-Kontexts. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CheckAnalyseAccess]
      @ResultSetArt = 'CONSOLE';
```

Für vollständige Spalten `@ResultSetArt='RAW'`; für Parameterhilfe `@Hilfe=1`.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `access` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Access-Zeile beschreibt das effektive Gate-Ergebnis für eine Analyseklasse. Policy-Zeilen beschreiben jeweils eine konfigurierte Gruppenregel.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Zuerst `IsAllowed`, danach `AccessReason`, `RelevantPolicyCount` und `MatchedGroupCount` lesen. Anschließend Original- und Effektivlogin vergleichen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

`RelevantPolicyCount > 0` und `MatchedGroupCount = 0` bedeutet: Für die Analyseklasse existieren Regeln, aber keine passende Gruppenmitgliedschaft wurde erkannt. Die Sperre ist dann erwartbares Policyverhalten und kein DMV-Defekt.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

`RelevantPolicyCount = 0` und `IsAllowed = 1` entspricht dem Frameworkvertrag: Ohne definierte Policy bleibt die Klasse offen.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** `IsAllowed=0` mit `AccessReason=NO_GROUP_MATCH` verlangt eine Prüfung der Gruppenpolicy, nicht das vorschnelle Erteilen zusätzlicher SQL-Rechte. Danach mit `USP_CheckFrameworkCapabilities` die technische Lesbarkeit prüfen.

**Ähnlich aussehender Gegenfall:** `RelevantPolicyCount = 0` und `IsAllowed = 1` entspricht dem Frameworkvertrag: Ohne definierte Policy bleibt die Klasse offen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Hilfsprocedures kann eine leere interne Zieltabelle aus bewusst leerem Filter, ungültiger Eingabe oder fehlender Policy entstehen; diese Fälle dürfen nicht zu einem ungefilterten Parentlauf zusammenfallen.

Für `USP_CheckAnalyseAccess` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

Leere Accessdaten sind nur nach Prüfung von Status, Filter und Policyumfang interpretierbar. `PERMISSION_DENIED` oder `IsPartial=1` ist keine Entwarnung.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | `@AnalyseKlasse = NULL` bewertet alle Klassen aus `VW_AnalyseAccessCurrent` und alle aktuell gültigen Policies. Für jede Policy werden Login-Token-Match und `IS_MEMBER` bestimmt. |
| Teuerster Pfad | Viele definierte Analyseklassen und aktive Gruppenpolicies mit langen Kommentaren. Datenbankzahl, Nutzdaten und Fach-DMVs beeinflussen den Pfad nicht. |
| Haupttreiber | Zahl der Analyseklassen und gültigen Policyzeilen; `sys.login_token` wird je Policy per Existenzprüfung verglichen, zusätzlich erfolgt je Gruppe ein `IS_MEMBER`-Check. |
| Skalierung | Accesszeilen wachsen mit Klassen, Policyzeilen mit Gruppenregeln. JSON/RAW übertragen zusätzlich Policykommentare; die Quellmenge bleibt Framework-/Security-Metadaten. |
| Ressourcen | Views über Frameworkpolicy, Login-Token-/Membershipprüfungen und kleine Temp-Tabellen. Keine Datenbankenumeration, Capabilityprobe oder Nutzdatenabfrage. |
| Begrenzungswirkung | `@AnalyseKlasse` ist der wirksamste Kostenscope. `@NurGesperrte` filtert die Accessausgabe, aber die für den Scope gültigen Policies werden weiterhin geprüft. Ein Max-Rows-Parameter existiert nicht. |
| Locking und Nebenwirkungen | Read-only. Policygültigkeit wird gegen `SYSUTCDATETIME()` geprüft; Gruppenmitgliedschaft oder Policy kann direkt nach dem Snapshot wechseln. Es werden keine Tokens oder Rollen verändert. |
| Schutzmechanismus | Diese Procedure entscheidet Zugänglichkeit, führt aber selbst keine Fachanalyse und kein High-Impact-Gate aus. `@AnalyseKlasse` beschränkt die zu prüfenden Klassen; `@NurGesperrte` reduziert nur die Ausgabe. Token-/Gruppenprüfung und Policies bleiben fail-closed, wenn ihre Evidenz nicht bestimmbar ist. |
| Sicherer Einsatz | Für eine Freigabeentscheidung eine konkrete dokumentierte Analyseklasse prüfen; Gesamtübersicht nur für Policy-Audits. Login- und Gruppennamen als sensible Security-Metadaten behandeln. |
| Aussagegrenze | `IsAllowed` beschreibt ausschließlich die Framework-Gruppenpolicy im aktuellen Login-Kontext. Objekt-/DMV-Berechtigungen, Datenbanksichtbarkeit und `@HighImpactConfirmed` werden hier nicht bewiesen. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Erlaubt die Frameworkpolicy dem aktuellen Sicherheitskontext die angeforderte Analyseklasse?

### Technischer Hintergrund

Das Framework besitzt eine zusätzliche Berechtigungsschiene oberhalb der SQL-Server-Quellberechtigungen. Es prüft Original- und Effektivlogin, sysadmin-Bypass sowie sichtbare Login-/Gruppentokens. Existiert für eine Analyseklasse keine Policy, bleibt sie gemäß Frameworkvertrag offen; existieren Policies, muss eine passende erlaubende Mitgliedschaft sichtbar sein.

### Datenkette

`sys.login_token`.

### Zeit- und Scope-Modell

Momentaufnahme des aktuellen Login- und Execution-Kontexts. Gruppenauflösung kann sich durch Token, Impersonation oder Verzeichniszustand vom erwarteten Benutzerbild unterscheiden.

### Bewertung und Gegenprobe

`IsAllowed`, Policyanzahl, gematchte Gruppen und AccessReason gemeinsam lesen. Ein Deny bei vorhandener Policy und ohne Match ist erwartetes Policyverhalten; SQL-Quellrechte zu erweitern würde die Frameworksperre nicht fachlich lösen.

### Typische Fehlinterpretation

`IsAllowed=1` beweist nicht, dass die benötigten DMVs tatsächlich lesbar sind. Umgekehrt ist ein leeres Fachresultset kein Beweis für Policy-Deny.

### Folgeanalyse

`USP_CheckFrameworkCapabilities` trennt anschließend Feature-, Rechte- und Queryabilityprobleme.

## Primärquellen

- [sys.login_token](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-login-token-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../01_Common.md#2-monitorusp_checkanalyseaccess)
