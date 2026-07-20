# [monitor].[USP_ServerSecurityConfiguration]

**Bereich:** Server Health<br>
**Zweck:** Erzeugt Sicherheits-Reviewbefunde zu relevanten Serveroptionen.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche sicherheitsrelevanten Servereinstellungen und Prinzipal-/Endpointmuster verdienen ein Securityreview?** Der dokumentierte Zweck ist: Erzeugt Sicherheits-Reviewbefunde zu relevanten Serveroptionen. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Metadaten-/Konfigurationsstand. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerSecurityConfiguration]
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `configuration` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einer Sicherheitskonfiguration oder einem normalisierten Reviewfinding.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Scope, aktuellen Wert, Exposition, Severity, Evidence und `EvidenceLimit` gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Unsichere Optionen können Angriffsfläche oder unerwünschte Rechtepfade eröffnen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Ein Feature kann betrieblich erforderlich und durch Berechtigungen, Audit oder andere Kontrollen abgesichert sein.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** `xp_cmdshell` aktiviert ist ein Reviewbefund, aber die reale Gefährdung hängt von Berechtigungen, Nutzung und Kompensationskontrollen ab. Sicherheitskonzept und Audit prüfen.

**Ähnlich aussehender Gegenfall:** Ein Feature kann betrieblich erforderlich und durch Berechtigungen, Audit oder andere Kontrollen abgesichert sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_ServerSecurityConfiguration` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Liest sieben fest benannte sicherheitsrelevante Serveroptionen, SQL-Dienste sowie vier `SERVERPROPERTY`-/Rollenwerte. Jede Teilquelle schreibt eigenen Status. |
| Teuerster Pfad | Es gibt keinen erweiterten Modus; RAW/JSON zeigen nur mehr Projektionen derselben kleinen Quellen. Die Procedure enumeriert keine Logins, Berechtigungen, Credentials, Endpoints oder Datenbankbenutzer. |
| Haupttreiber | Feste Konfigurationsliste und Zahl der SQL-Dienste. Resultgröße ist unabhängig von Datenbanken und Loginanzahl. |
| Skalierung | Praktisch konstant. Finding-CASE-Auswertung und Sortierung sind gering; Sourcefehler werden isoliert statt durch teure Fallbacks kompensiert. |
| Ressourcen | Ein kleiner `sys.configurations`-Filter, `sys.dm_server_services`, `SERVERPROPERTY`/`IS_SRVROLEMEMBER` und Temp-Tabellen. Kein Registry-, Netzwerk- oder Dateisystemscan. |
| Begrenzungswirkung | Kein `@MaxZeilen`, weil jede Konfigurations-/Dienstzeile Teil des Security-Snapshots ist. `NONE` spart Ausgabe, nicht die Quellprüfung. |
| Locking und Nebenwirkungen | Read-only. Es werden keine Features, Logins oder Dienste geändert; konfigurierte und aktive Werte beziehungsweise Dienststatus können sich zwischen den drei Teilabfragen ändern. |
| Schutzmechanismus | Kein Gate und kein Teil-Scope. Der Sicherheitsvertrag ist fest auf sieben benannte Konfigurationen, SQL-Dienste und vier Server-/Rollenwerte begrenzt; Login-, Benutzer- und Berechtigungsinventare werden nicht geöffnet. |
| Sicherer Einsatz | CONSOLE direkt nutzen; Server-/Maschinenname und Dienstkonten aus RAW/JSON/TABLE als sensible Betriebsmetadaten behandeln. |
| Aussagegrenze | Die Auswertung ist ein enger Konfigurationscheck, kein Berechtigungs- oder Angriffsflächen-Audit. `OK_OR_CONTEXT_DEPENDENT` bestätigt weder Least Privilege noch sichere Proxy-/Credential-/Endpointkonfiguration. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche sicherheitsrelevanten Servereinstellungen und Prinzipal-/Endpointmuster verdienen ein Securityreview?

### Technischer Hintergrund

Server Principals/Roles/Permissions, Authentication, Endpoints, Service Accounts und Konfigurationsoptionen bilden mehrere Sicherheitsebenen. Metadata Visibility begrenzt die Sicht. Frameworkbefunde sollen Konfiguration inventarisieren, keine Credentials/Secrets ausgeben.

### Datenkette

`sys.configurations`, `sys.dm_server_services`.

### Zeit- und Scope-Modell

Aktueller Metadaten-/Konfigurationsstand.

### Bewertung und Gegenprobe

Finding, Scope, Severity/Confidence, betroffene Option/Rolle und dokumentierte Policy verbinden. Besonders sysadmin, CONTROL SERVER, unsichere Optionen und exponierte Endpoints mit Owner/Notwendigkeit prüfen.

### Typische Fehlinterpretation

Technischer Befund ist kein vollständiges Berechtigungsaudit und keine Aussage über organisatorische Genehmigung. Fehlende Sicht darf nicht als fehlende Berechtigung interpretiert werden.

### Folgeanalyse

Formales Security-/Identityreview, Audit und Change Governance.

## Primärquellen

- [SQL Server security best practices](https://learn.microsoft.com/en-us/sql/relational-databases/security/sql-server-security-best-practices?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#9-monitorusp_serversecurityconfiguration)
