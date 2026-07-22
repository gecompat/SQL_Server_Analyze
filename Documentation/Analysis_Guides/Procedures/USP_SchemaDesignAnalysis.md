# [monitor].[USP_SchemaDesignAnalysis]

**Bereich:** Object und Index<br>
**Zweck:** Erzeugt normalisierte Findings zu Constraints, Foreign Keys, Indizes und Identity-Risiken.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** MEDIUM–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Schemamuster verdienen ein fachliches Designreview?** Der dokumentierte Zweck ist: Erzeugt normalisierte Findings zu Constraints, Foreign Keys, Indizes und Identity-Risiken. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob ein Struktur- oder Metadatensignal eine workloadbezogene Gegenprüfung rechtfertigt, nicht ob automatisch DDL ausgeführt werden soll. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen Geschäftsnutzen einer Strukturänderung, keine repräsentative Workload und keine automatische Aussage über den optimalen Index- oder Statistikzustand. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Metadatenstand; keine Runtime-/Workloadhistorie, sofern nicht explizit angereichert. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_SchemaDesignAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Die Procedure prüft ihren gesamten Ausführungspfad als `CATALOG_DEEP`. Die Bestätigung ist daher bereits für eine einzelne Datenbank nötig und ersetzt weder den engen Scope noch die Prüfung der Datenbankgröße.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `findings` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einem Designfinding für ein betroffenes und gegebenenfalls verwandtes Objekt.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

`FindingCode`, Severity, Objekt, Related Object, Metrik, Evidence und `EvidenceLimit` gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Nicht vertrauenswürdige Constraints, fehlende FK-Unterstützung oder fast erschöpfte Identitybereiche können Optimierung, DML und Verfügbarkeit beeinträchtigen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Disabled oder ähnlich wirkende Objekte können Teil eines Lade-, Deployment- oder Constraintdesigns sein.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Ein FK ohne passenden Index ist besonders relevant, wenn Parent-Änderungen große Childscans und Blocking erzeugen. Bei statischen Tabellen kann die Priorität niedriger sein. Usage, Pläne und Änderungsrisiko prüfen.

**Ähnlich aussehender Gegenfall:** Disabled oder ähnlich wirkende Objekte können Teil eines Lade-, Deployment- oder Constraintdesigns sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Katalogpfaden sind Featureabwesenheit, Filter, Offline-/Permission-Scope und tatsächlich fehlende Objekte getrennte Erklärungen.

Für `USP_SchemaDesignAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM–HIGH_OPT_IN |
| Standardpfad | Eine explizit benannte `ExampleDatabase`; die Procedure prüft dort alle sichtbaren relevanten Constraints, Foreign Keys, Indizes, Identities und Sequences. Einen Objektfilter besitzt sie nicht. |
| Teuerster Pfad | `@DatabaseNames = NULL` über alle sichtbaren Userdatenbanken mit unbegrenzter Ausgabe bei sehr vielen Objekten, FK-Spalten und Indexspalten. Einen VOLL-Schalter gibt es nicht; bereits jeder fachliche Lauf ist `CATALOG_DEEP`. |
| Haupttreiber | Zahl gewählter Datenbanken/Objekte sowie Foreign Keys und -Spalten, Check-/Default-Constraints, Indizes und Identitymetadaten. Jeder Datenbankscope wird dynamisch katalogseitig ausgewertet; Benutzertabellenzeilen werden nicht gescannt. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_SchemaDesignAnalysis ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU, Katalogseiten und TempDB für Joins/Aggregation; bei breitem Cross-Database-Scope zusätzlicher Compile- und Ergebnistransferaufwand. |
| Begrenzungswirkung | Nur Datenbankliste/-pattern begrenzen die Quellarbeit früh. `@MaxZeilen` wirkt nach den Katalogjoins, Signaturbildung und Findingregeln und begrenzt daher ausschließlich die ausgegebenen Findings. |
| Locking und Nebenwirkungen | Read-only; Katalogabfragen nehmen üblicherweise kurze Schema-Stability-Zugriffe und können mit gleichzeitigem DDL oder Datenbankstatuswechseln konkurrieren. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `CATALOG_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Mit genau einer `ExampleDatabase` starten, deren Objekt-/Indexanzahl vorab bekannt ist. Da kein Objektfilter existiert, große Datenbanken und mehrere Datenbanken nur nacheinander außerhalb der DDL-Spitze prüfen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Katalogsnapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Schemamuster verdienen ein fachliches Designreview?

### Technischer Hintergrund

Die Procedure leitet normalisierte Findings aus Katalogmerkmalen ab, etwa Datentyp-, Schlüssel-, Index-, Nullable-, LOB- oder Constraintkonstellationen. Solche Regeln erkennen technische Gerüche, nicht die vollständige fachliche Semantik.

### Datenkette

`sys.check_constraints`, `sys.foreign_key_columns`, `sys.foreign_keys`, `sys.identity_columns`, `sys.index_columns`, `sys.indexes`, `sys.objects`, `sys.schemas`, `sys.sequences`, `sys.sp_executesql`, `sys.tables`.

### Source Select

Der Foreign-Key-Kern verbindet Constraint, Parent-/Referenztabelle, Schema und Spaltenzuordnung:

```sql
SELECT
      [ps].[name] AS [ParentSchema]
    , [pt].[name] AS [ParentTable]
    , [fk].[name] AS [ForeignKeyName]
    , [rs].[name] AS [ReferencedSchema]
    , [rt].[name] AS [ReferencedTable]
    , [fkc].[constraint_column_id]
    , [fkc].[parent_column_id]
    , [fkc].[referenced_column_id]
FROM [sys].[foreign_keys] AS [fk] WITH (NOLOCK)
JOIN [sys].[tables] AS [pt] WITH (NOLOCK)
  ON [pt].[object_id] = [fk].[parent_object_id]
JOIN [sys].[schemas] AS [ps] WITH (NOLOCK)
  ON [ps].[schema_id] = [pt].[schema_id]
JOIN [sys].[tables] AS [rt] WITH (NOLOCK)
  ON [rt].[object_id] = [fk].[referenced_object_id]
JOIN [sys].[schemas] AS [rs] WITH (NOLOCK)
  ON [rs].[schema_id] = [rt].[schema_id]
JOIN [sys].[foreign_key_columns] AS [fkc] WITH (NOLOCK)
  ON [fkc].[constraint_object_id] = [fk].[object_id]
WHERE [ps].[name] = N'ExampleSchema'
  AND [pt].[name] = N'ExampleObject';
```

**Wichtig für die Eigenlast:** Datenbank und Objekt vor Index-, Constraint-, Identity- und Sequence-Gegenprüfungen festlegen. Der breite High-Impact-Pfad liest mehrere Katalogfamilien; Findings entstehen erst danach und sind kein DDL-Auftrag.

### Zeit- und Scope-Modell

Aktueller Metadatenstand; keine Runtime-/Workloadhistorie, sofern nicht explizit angereichert.

### Bewertung und Gegenprobe

Severity/Confidence, Objektgröße, Workload, Datenqualität, Abhängigkeiten und Migrationsaufwand zusammen betrachten. Ein Finding mit hoher technischer Plausibilität kann fachlich bewusst sein.

### Typische Fehlinterpretation

Heuristik ist kein Beweis. Breite Spalten, fehlender PK oder bestimmter Datentyp können durch externe Verträge oder Stagingzweck begründet sein.

### Folgeanalyse

Object Inventory, Querypläne, Datenprofiling und fachliches Schemaowner-Review.

## Primärquellen

- [SQL-Server-Katalogsichten](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/catalog-views-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../03_Object_Index.md#10-monitorusp_schemadesignanalysis)
