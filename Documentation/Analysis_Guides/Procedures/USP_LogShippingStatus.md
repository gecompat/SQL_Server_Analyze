# [monitor].[USP_LogShippingStatus]

**Bereich:** Infrastruktur<br>
**Zweck:** Zeigt Backup-, Copy- und Restorefortschritt von Log Shipping.<br>
**Beobachtungsart:** Konfigurationssnapshot + retentionbegrenzte Historie<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Erzeugen, kopieren und restaurieren die Log-Shipping-Jobs Backups innerhalb der konfigurierten Schwellen?** Der dokumentierte Zweck ist: Zeigt Backup-, Copy- und Restorefortschritt von Log Shipping. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Ihr Zeitvertrag lautet ausdrücklich: Monitor-Metadaten mit eigener Aktualisierungszeit plus Jobhistory. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_LogShippingStatus]
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `primary` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer Primary-/Secondary-Konfiguration, Datenbankbeziehung oder Überwachungszeile.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Zeit des letzten Backups, Kopierens und Restores, Schwellenstatus, Restore Delay und Metadatenverfügbarkeit vergleichen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Eine wachsende Differenz zeigt, ob Backup-, Transport- oder Restorephase zurückfällt.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Ein geplanter Restore Delay erzeugt absichtlich Verzögerung.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Backups aktuell, Copy 90 Minuten zurück, Restore ebenfalls zurück: Transportpfad wahrscheinlicher als Backupjob. Jobhistorie, Netzwerk, Share und Secondary prüfen.

**Ähnlich aussehender Gegenfall:** Ein geplanter Restore Delay erzeugt absichtlich Verzögerung. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Ein leerer Historypfad kann Retention/Cleanup, deaktivierte Komponente oder falschen Scope bedeuten; er beweist keine erfolgreiche Ausführung.

Für `USP_LogShippingStatus` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Gering.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Aktueller lokaler msdb-Snapshot der konfigurierten Primary- und Secondary-Monitorzeilen, jeweils bis zum Defaultlimit 5000. |
| Teuerster Pfad | `@MaxZeilen = 0` bei sehr vielen Log-Shipping-Konfigurationen. Die Procedure liest keine frei wählbare Job- oder Backuphistorie und besitzt keinen Datenbankfilter. |
| Haupttreiber | Zahl lokaler Primary-/Secondary-Konfigurationen und Monitorzeilen in msdb. Backup- oder Jobhistory wird nicht geöffnet; deshalb wächst der Pfad mit konfigurierten Log-Shipping-Beziehungen, nicht mit dem frei wählbaren Historienalter. |
| Skalierung | Nahezu linear mit den lokalen Primary-/Secondary-Monitorzeilen; Ergebnisbreite enthält auch konfigurierte Datei-/Sharefelder, bleibt aber gewöhnlich klein. |
| Ressourcen | Geringe CPU- und msdb-I/O-Last für Konfigurations-/Monitorjoins und Sortierung; keine Remoteabfrage und kein Logdateizugriff. |
| Begrenzungswirkung | `@MaxZeilen` wird als TOP in Primary- und Secondarypfad getrennt angewandt. Es ist keine gemeinsame Gesamtgrenze und kann relevante später sortierte Konfigurationen ausblenden. |
| Locking und Nebenwirkungen | Read-only; kurze Schema-Stability-Zugriffe auf msdb/Systemkataloge. Jobs, Backups oder Wartung laufen parallel weiter, daher ist das Ergebnis nicht atomar. |
| Schutzmechanismus | Kein Gate und kein Datenbankfilter. Das endliche Defaultlimit wird getrennt auf Primary- und Secondary-Monitorzeilen angewandt; der Quellpfad bleibt auf aktuelle lokale Log-Shipping-Konfiguration beschränkt und öffnet keine Job- oder Backuphistorie. |
| Sicherer Einsatz | Defaultlimit und CONSOLE; bei mehr als 5000 Konfigurationen RAW/JSON-Vollständigkeitsmarker und Sortierung prüfen, bevor das Limit erhöht wird. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Konfigurationssnapshot + retentionbegrenzte Historie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Erzeugen, kopieren und restaurieren die Log-Shipping-Jobs Backups innerhalb der konfigurierten Schwellen?

### Technischer Hintergrund

Log Shipping besteht aus Backupjob auf Primary, Copy-/Restorejobs auf Secondary und optional Monitorserver. Monitor-/Primary-/Secondarytabellen halten letzte Datei-/Zeit-/Schwellenwerte. Jede Stufe kann unabhängig zurückliegen.

### Datenkette

`msdb.dbo.log_shipping_monitor_primary`, `msdb.dbo.log_shipping_monitor_secondary`, `msdb.dbo.log_shipping_primary_databases`, `msdb.dbo.log_shipping_secondary_databases`.

### Source Select

Der Primary-Pfad verbindet Konfiguration und Monitorstatus über `primary_id`:

```sql
SELECT
      [p].[primary_database]
    , [p].[backup_directory]
    , [m].[last_backup_date]
    , [m].[last_backup_file]
    , [m].[backup_threshold]
    , [m].[threshold_alert_enabled]
FROM [msdb].[dbo].[log_shipping_primary_databases] AS [p] WITH (NOLOCK)
LEFT JOIN [msdb].[dbo].[log_shipping_monitor_primary] AS [m] WITH (NOLOCK)
  ON [m].[primary_id] = [p].[primary_id]
WHERE [p].[primary_database] = N'ExampleDatabase';
```

**Wichtig für die Eigenlast:** Primary- beziehungsweise Secondary-Datenbank vor der jeweiligen Monitoransicht filtern. Primary und Secondary sind getrennte Zeilengranularitäten und werden nicht über Namen zu einer vermeintlich atomaren Kette verschmolzen.

### Zeit- und Scope-Modell

Monitor-Metadaten mit eigener Aktualisierungszeit plus Jobhistory. Clock Skew und stale Monitor beeinflussen Interpretation.

### Bewertung und Gegenprobe

Backup-, Copy- und Restorelatenz getrennt lesen; letzte Dateinamen/Zeiten, Threshold, Alertstatus, Jobzustand und Monitoraktualität korrelieren. Restore Mode/Delay kann absichtlich verzögern.

### Typische Fehlinterpretation

Ein grüner Monitor kann stale sein. Eine alte Restorezeit ist bei konfiguriertem Delay nicht automatisch Fehler. Dateinamen allein beweisen keine lückenlose LSN-Kette.

### Folgeanalyse

Agent Jobs, Backup Chain und Secondary-/Shareprüfung.

## Primärquellen

- [Überwachen von Log Shipping](https://learn.microsoft.com/en-us/sql/database-engine/log-shipping/monitor-log-shipping-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#6-monitorusp_logshippingstatus)
