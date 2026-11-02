# [monitor].[USP_DataCaptureDeepAnalysis]

**Bereich:** Versionsadaptive Spezialanalysen<br>
**Zweck:** Bewertet Change-Tracking-Versionen, CDC-Capture/Cleanup und lokal erreichbare Replikationsmetadaten, ohne Nutzdaten, Change-Zeilen, Replikationsbefehle oder Konfiguration zu verändern.<br>
**Beobachtungsart:** Snapshot + retentionbegrenzte Metadatenhistorie<br>
**Kostenklasse:** MEDIUM (SQL-Header); statische Navigationsklassifikation: MEDIUM_HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche sichtbaren CT-, CDC- und lokalen Replikationsmetadaten liegen vor, und welche konfigurierbaren Prüfhinweise ergeben sich daraus?** Sie stellt Consumer-Wasserstand, Versionsgrenzen, abgeleitete CDC-Zeitgrenzen und lokale Agenten-/Fehleraggregate in ihren jeweiligen Scope. Ein CT-Verlusthinweis setzt einen passenden übergebenen Consumer-Wasserstand voraus; CDC-Consumer-Vollständigkeit und entfernte Replikationsgesundheit werden nicht nachgewiesen.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Korrektheit der Featurekonfiguration, keine geschützten Inhalte und keine End-to-End-Funktionsprüfung außerhalb sichtbarer Metadaten. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DataCaptureDeepAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurProblematisch = 1,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Prüfen Sie einen Change-Tracking-Consumer nur mit seinem echten, zuletzt bestätigten Wasserstand:

```sql
EXEC [monitor].[USP_DataCaptureDeepAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @ChangeTrackingClientVersion = 100,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'RAW';
```

Der Zahlenwert ist synthetisch. Der Parameter ist datenbankspezifisch und erzwingt genau eine ausgewählte Datenbank. Wasserstände verschiedener Consumer dürfen fachlich nicht vermischt werden.

Beide fachlichen Pfade sind als `CATALOG_DEEP` klassifiziert. Die Bestätigung erfüllt das Gruppengate, ersetzt aber weder den Einzeldatenbank-Scope noch einen fachlich verifizierten Consumer-Wasserstand.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameterverträge

Jeder Eintrag erklärt den tatsächlichen Parametervertrag einschließlich NULL-Verhalten und der erlaubten Werte.

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | Default: `NULL` | Wählt eine oder mehrere Datenbanken als exakte, pipe-getrennte SQL-Namensliste. NULL oder nur Leerraum bedeutet keine explizite Liste; Leerraum allein wird daher wie NULL behandelt. Eine nichtleere Liste ist mit @DatabaseNamePattern exklusiv, darf jeden Datenbanknamen nur einmal case-sensitiv enthalten und muss vollständig gültig sein. Pro Element gilt höchstens 4000 Zeichen im Rohtext und höchstens 128 Zeichen für den Namen; einteilige Namen können geklammert werden, ein äußeres Paar eckiger Klammern wird durch PARSENAME ausgewertet. Ein senkrechter Strich innerhalb eines geklammerten Namens ist möglich; schließende Klammern werden als ]] maskiert. Vierteilige oder mehrteilige Datenbanknamen sind nicht zulässig. Ungültige oder doppelte Einträge liefern INVALID_PARAMETER. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@SystemdatenbankenEinbeziehen` | `bit` | Default: `0` | Steuert, ob master, tempdb, model und msdb in den Datenbankkandidaten enthalten sein dürfen. Ein numerisch gebundener Wert 0 wird zu 0 und schließt sie aus; ein numerisch von 0 verschiedener Wert wird zu 1 und schließt sie ein. Bei 0 erzeugt der Helper für ausdrücklich angeforderte ausgeschlossene Systemdatenbanken eine Auswahlwarnung. NULL ist im Aufrufer ungültig und ergibt INVALID_PARAMETER. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | Default: `NULL` | Filtert die Datenbankkandidaten mit einem Pattern; NULL bedeutet kein Pattern. Ein explizites Präfix LIKE: verwendet SQL-LIKE-Syntax, REGEX: regulären Ausdruck mit case-sensitiver Auswertung und REGEXI: regulären Ausdruck mit case-insensitiver Auswertung; Präfixe werden ohne Beachtung ihrer Groß-/Kleinschreibung erkannt. Ohne Präfix wird der Text als LIKE-Pattern behandelt. Der Wert nach einem Präfix darf nicht leer sein. Das Pattern ist mit @DatabaseNames exklusiv. REGEX/REGEXI benötigen SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank; sonst meldet der Helper UNAVAILABLE_FEATURE. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@HighImpactConfirmed` | `bit` | Default: `0` | Bestätigt für die gewählte Analyseklasse den erforderlichen High-Impact-Aufrufpfad. Ein numerisch gebundener Wert 0 wird zu 0 und gibt keine Bestätigung; ein numerisch von 0 verschiedener Wert wird zu 1 und bestätigt den Pfad. NULL ist ungültig. Die Bestätigung ersetzt weder die Zielauswahl noch eine Berechtigung und erklärt keine Analyse unabhängig von der Zugriffspolitik für freigegeben. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@SchemaNames` | `nvarchar(max)` | Default: `NULL` | Beschränkt CT- und CDC-Quelltabellen auf die angegebene pipe-getrennte, case-sensitive Liste einteiliger Schemanamen; NULL bedeutet kein exakter Schemascope. Nur Leerraum ist ein nichtleeres, ungültiges Element. Namenselemente dürfen höchstens 4000 Zeichen im Rohtext und der SQL-Name höchstens 128 Zeichen umfassen. Pipe trennt Elemente, außer innerhalb eines geklammerten Namens; ]] maskiert darin eine schließende Klammer. Doppelte Werte werden case-sensitiv erkannt und abgewiesen. Mit @SchemaNamePattern ist die Liste exklusiv. Sie filtert weder das Feature-Gate noch Replikationsrollen oder -agenten. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@SchemaNamePattern` | `nvarchar(4000)` | Default: `NULL` | Beschränkt CT- und CDC-Quelltabellen nach Schema auf ein Pattern; NULL bedeutet kein Pattern. LIKE:, REGEX: und REGEXI: haben dieselbe Syntax wie @DatabaseNamePattern. Präfixerkennung ist case-insensitiv; ohne Präfix gilt LIKE-Syntax. Ein Präfix ohne nachfolgenden Inhalt ist ungültig. Für Schema-/Objektregex setzt eine SQL-Server-Version unter 17 global UNAVAILABLE_VERSION. Compatibility-Level unter 170 in einer ausgewählten Zieldatenbank setzt deren DatabaseStatus auf UNAVAILABLE_FEATURE und markiert sie partiell; die globale Aggregation wird dadurch AVAILABLE_LIMITED. Diese Ziel-DB-Anforderung ist von der Installationsdatenbankanforderung des @DatabaseNamePattern getrennt. Das Pattern ist mit @SchemaNames exklusiv und wirkt nicht auf Feature-Gate oder Replikationsobjekte. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ObjectNames` | `nvarchar(max)` | Default: `NULL` | Beschränkt CT- und CDC-Quelltabellen auf die angegebene pipe-getrennte, case-sensitive Liste einteiliger Objektnamen; NULL bedeutet kein exakter Objektscope. Nur Leerraum ist ungültig. Rohes Element maximal 4000 Zeichen, SQL-Name maximal 128 Zeichen; Klammerquotierung erlaubt ein Pipe-Zeichen im Namen und ]] maskiert eine schließende Klammer. PARSENAME muss genau einen Namensbestandteil ergeben; schemaqualifizierte Namen sind hier unzulässig. Case-sensitive Duplikate werden abgewiesen. Mit @ObjectNamePattern ist die Liste exklusiv. Der Filter schränkt weder das Feature-Gate noch Replikationsmetadaten ein. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ObjectNamePattern` | `nvarchar(4000)` | Default: `NULL` | Beschränkt CT- und CDC-Quelltabellen nach Objektname anhand eines Patterns; NULL bedeutet kein Pattern. LIKE:, REGEX: und REGEXI: haben dieselbe Syntax wie @DatabaseNamePattern. Präfixerkennung ist case-insensitiv; ungekennzeichnete Texte nutzen LIKE. Ein leeres Pattern nach dem Präfix ist ungültig. Für Schema-/Objektregex setzt eine SQL-Server-Version unter 17 global UNAVAILABLE_VERSION. Compatibility-Level unter 170 in einer ausgewählten Zieldatenbank setzt deren DatabaseStatus auf UNAVAILABLE_FEATURE und markiert sie partiell; die globale Aggregation wird dadurch AVAILABLE_LIMITED. Diese Ziel-DB-Anforderung ist von der Installationsdatenbankanforderung des @DatabaseNamePattern getrennt. Mit @ObjectNames ist das Pattern exklusiv. Es filtert weder Feature-Gate noch Replikationsmetadaten. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@FullObjectNames` | `nvarchar(max)` | Default: `NULL` | Beschränkt CT- und CDC-Quelltabellen anhand vollständiger ein-, zwei- oder dreiteiliger Objektbezüge database.schema.object, schema.object oder object; NULL bedeutet kein solcher Filter. Eine übergebene leere oder nur aus Leerraum bestehende Liste ist ungültig und ergibt INVALID_PARAMETER. Dreiteilige Bezüge müssen das Schema enthalten; vierteilige Linked-Server-Namen sind unzulässig. Je Namensbestandteil höchstens 128 Zeichen, rohes Listenelement höchstens 4000 Zeichen. Die Pipe-Liste behandelt geklammerte Namen und ]] wie die anderen Namenslisten; case-sensitive Duplikate sind ungültig. Diese Liste ist laut Helper ausschließlich und darf nicht zusammen mit @SchemaNames oder @ObjectNames angegeben werden. Sie kann mit Schema- oder Objektpattern kombiniert werden; die jeweilige Patternbedingung wird zusätzlich angewandt. Filterwirkung nur auf CT-/CDC-Tabellen, nicht auf Feature-Gate oder Replikation. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@NurProblematisch` | `bit` | Default: `0` | Steuert Findings, Change-Tracking-Tabellen, CDC-Capture-Instanzen und Replikationsagenten: 0 lässt diese Kategorien ungefiltert; ein numerisch von 0 verschiedener Wert wird zu 1 und behält bei Findings nur Severity=WARN sowie bei CT-/CDC-/Agentzeilen nur AssessmentStatus=REVIEW. Der Schalter filtert CDC-Scan-Sitzungen, CDC-Fehlergruppen, CDC-Jobs, Replikationsfehlergruppen und DatabaseStatus-/SourceStatus-Statusresultsets nicht. Davon unabhängig begrenzt @MaxZeilen die vier genannten CDC-/Replikationsfachresultsets per TOP; DatabaseStatus und SourceStatus bleiben unbegrenzt. NULL ist ungültig. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ChangeTrackingClientVersion` | `bigint` | Default: `NULL` | Gibt einen echten, zuletzt erfolgreich bestätigten Consumer-Wasserstand an, der für alle ausgewerteten Change-Tracking-Tabellen der einzigen ausgewählten Datenbank gilt. NULL bedeutet: keinen Consumervergleich durchführen und keinen Synchronisationsverlust behaupten. Der zulässige Zahlenbereich ist 0 bis 9223372036854775807; negative Werte sind ungültig. 0 ist ein expliziter Wasserstand und wird mit dem tabellenspezifischen MinValidVersion-Wert und dem datenbankweiten CurrentVersion-Wert verglichen; ein höherer Stand als CurrentVersion wird als inkonsistent bewertet. Ein Stand unter einer Tabelle-MinValidVersion kann für diesen Consumer und diese Tabelle eine vollständige inkrementelle Enumeration unmöglich machen. Mehrere Datenbanken oder unterschiedliche Consumer-Wasserstände lassen sich mit diesem einen Parameter nicht ausdrücken; bei mehr als einer ausgewählten Datenbank wird INVALID_PARAMETER gesetzt. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@CdcLatencyWarnSeconds` | `bigint` | Default: `300` | Schwelle in Sekunden für die aggregierte CDC-Scan-Latenz. Zulässig sind 0 bis 315360000 einschließlich; NULL oder außerhalb des Bereichs ist INVALID_PARAMETER. 0 aktiviert den Vergleich ab Latenz 0; bei einer verfügbaren Session-0-Zeile mit SQL-NULL-Latenz greift der Vergleich nicht. Wird die Schwelle erreicht, ergibt ein CDC-Capture-Job mit IsContinuous=1 oder NULL den Finding-Status WARN und Confidence MEDIUM; bei IsContinuous=0 entsteht INFO mit Confidence LOW als Kontext für zeitgesteuertes Capture. Die DMV ist eine Momentaufnahme und kein lückenloser Verlauf. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@CdcCleanupGraceMinutes` | `bigint` | Default: `60` | Zusätzliche Toleranz in Minuten auf die konfigurierte CDC-Cleanup-Retention, nicht Ersatz der Retention. Zulässig sind 0 bis 52560000 einschließlich; NULL oder außerhalb ungültig. 0 addiert keine Toleranz; positive Werte erlauben genau diesen Zusatz. Die Heuristik vergleicht Alter des ältesten verfügbaren CDC-LSN gegen Retention plus Toleranz und behauptet allein keinen Verlust. Ein WARN erfordert eine bekannte CleanupRetentionMinutes und OldestAvailableAgeMinutes strikt größer als CleanupRetentionMinutes plus Toleranz; Gleichheit genügt nicht. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ErrorLookbackHours` | `int` | Default: `24` | Zeitfenster in Stunden für CDC-Fehler aus sys.dm_cdc_errors und Replikationsfehler aus MSrepl_errors relativ zur Erfassungszeit @Now=SYSUTCDATETIME(). Zulässig sind 0 bis 876000 einschließlich; NULL oder außerhalb ungültig. 0 setzt die untere Zeitgrenze auf @Now; positive Werte verschieben sie um die angegebene Stundenzahl zurück. Beide Prädikate enthalten nur die Untergrenze und keine obere Zeitgrenze, daher können zukünftige Quellzeitstempel enthalten sein. Der Parameter wird nicht auf Distribution-Agenthistorie angewandt; deren Alter und Rückstand werden separat beurteilt. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ReplicationLatencyWarnSeconds` | `bigint` | Default: `300` | Warnschwelle für aus lokaler Distribution-Agenthistorie abgeleitete Delivery-Latenz in Sekunden. Zulässig sind 0 bis 315360000 einschließlich; NULL oder außerhalb ungültig. 0 vergleicht ab 0, positive Werte mit >= Schwelle. Nur lokal aggregierte Agenthistorie wird verwendet; Remote-Distributor-/Subscriber-Zustand wird nicht daraus abgeleitet. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ReplicationPendingCommandWarn` | `bigint` | Default: `10000` | Warnschwelle für PendingCommandCount eines lokal sichtbaren Distribution-Agents. Zulässig sind 0 bis 9223372036854775807; NULL und negative Werte sind ungültig. Die Finding-Bedingung gilt ausschließlich für AgentType=DISTRIBUTION und PendingCommandCount >= Schwelle. Bei 0 erfüllt jeder nicht-NULL-Wert ab 0 die Schwelle; ein SQL-NULL-Zähler erfüllt den Vergleich nicht. Keine Remote-Distribution oder Subscriber-Daten werden abgefragt. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ReplicationAgentStaleWarnMinutes` | `bigint` | Default: `15` | Schwelle in Minuten für LastHistoryAgeMinutes lokaler Distribution-Agents. Zulässig sind 0 bis 52560000 einschließlich; NULL oder außerhalb ungültig. Ein Finding erfordert zugleich AgentType=DISTRIBUTION, LastHistoryAgeMinutes >= Schwelle und COALESCE(PendingCommandCount,0)>0. Bei 0 gilt die Altersbedingung für nichtnegative Alterswerte; ein zukünftiger History-Zeitstempel kann negatives Alter ergeben und die Bedingung verfehlen. NULL im Alterswert erfüllt den Vergleich nicht. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MaxZeilen` | `int` | Default: `2000` | Begrenzt die Findings-Auswahl und die fachlichen Datenresultsets je Ausgabe. NULL und 0 bedeuten unbegrenzt; positive Werte sind die jeweilige TOP-Grenze; negative Werte sind ungültig. Findings werden nach dem Problemscope zuerst nach WARN-Priorität und dann FindingOrdinal ausgewählt und sortiert. Statuskopf, DatabaseStatus und SourceStatus bleiben in RAW und JSON unbegrenzt; fachliche Datenresultsets unterliegen TOP(@Limit) und ihren ausgewiesenen Sortierungen. Das Limit wird nach Quellenlesen und Aggregation angewandt und begrenzt diese Arbeit nicht. Der positive int-Bereich reicht von 1 bis 2147483647. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@LockTimeoutMs` | `int` | Default: `0` | Setzt das Lock-Timeout in Millisekunden für dynamische Datenbank- und lokale Distributionsabfragen. Zulässig sind 0 bis 60000 einschließlich; NULL oder außerhalb ungültig. 0 bedeutet NOWAIT, positive Werte warten höchstens die angegebene Zeit auf Sperren; bei Timeout kann die betroffene Teilquelle als Fehler erfasst und die Gesamtausgabe partiell werden. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultSetArt` | `varchar(16)` | Default: `'CONSOLE'` | Wählt die Ausgabeart nach Trim und Umwandlung in Großbuchstaben: CONSOLE rendert Findings in einer Console-Zeile je Finding bzw. eine verständliche Leerzeile; RAW gibt in fester Reihenfolge den Statuskopf, DatabaseStatus, SourceStatus, Findings, ChangeTrackingTable, CdcCaptureInstance, CdcScanSession, CdcErrorGroup, CdcJob, ReplicationAgent und ReplicationErrorGroup aus; TABLE schreibt ausschließlich das einzelne Resultset findings in ein Ziel aus @ResultTablesJson; NONE unterdrückt Resultsetausgabe. NULL und leere Zeichenfolge normalisieren auf einen ungültigen Wert; nur CONSOLE, RAW, TABLE und NONE sind zulässig. @ResultTablesJson ist ausschließlich mit TABLE erlaubt. JSON-Erzeugung über @JsonErzeugen/@Json ist davon unabhängig. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultTablesJson` | `nvarchar(max)` | Default: `NULL` | Enthält für TABLE ausschließlich ein JSON-Objekt mit dem Schlüssel findings und einem JSON-Stringwert als lokalem Zieltabellennamen. Leeres oder fehlendes Mapping, zusätzliche Schlüssel, nichtstringige Werte, unbekannte Resultsetnamen, case-sensitiv doppelte Resultsetnamen und case-insensitiv doppelte Ziele sind ungültig. Der einzige erlaubte Seed ist eine leere lokale #Temp-Tabelle mit genau einer beliebigen Seed-Spalte. Zielnamen höchstens 116 Zeichen, beginnend mit #, ohne ## und ohne case-insensitives Präfix #Monitor. Preflight prüft Ziel und Seed vor HELP; ungültige Zuordnung wirft 51011. Der Writer überträgt nach der regulären OUTPUT-Zuweisung und wirft bei Fehlern 51010. TABLE-Zeilen werden nicht per OUTPUT-Parameter zurückgegeben. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@JsonErzeugen` | `bit` | Default: `0` | Steuert zusätzliche JSON-Erzeugung. Ein numerisch gebundener Wert 0 wird zu 0 und unterlässt das Befüllen von @Json; ein numerisch von 0 verschiedener Wert wird zu 1 und erzeugt ein JSON-Objekt. NULL ist ungültig. JSON enthält meta als eingebettetes JSON-Objekt mit module, collectedAtUtc, statusCode, isPartial, errorNumber und errorMessage sowie benannte Arrays databaseStatus, sourceStatus, findings, changeTrackingTables, cdcCaptureInstances, cdcScanSessions, cdcErrors, cdcJobs, replicationAgents und replicationErrors; leere Arrays bleiben []. Die jeweilige Sortierung und @NurProblematisch-/@MaxZeilen-Wirkung folgt den einzelnen SELECTs. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Json` | `nvarchar(max) OUTPUT` | Default: `NULL` | OUTPUT-Parameter für das von @JsonErzeugen angeforderte JSON-Dokument; im Aufruf ist eine nvarchar(max)-Variable mit OUTPUT zu binden. Zu Beginn wird der Parameter auf NULL gesetzt; wenn JSON-Erzeugung aktiv ist, enthält er das JSON-Objekt samt meta und Ergebnisarrays. Bei deaktivierter Erzeugung und beim Help-Return bleibt er NULL. Er ist kein Rückgabekanal für TABLE-Zeilen; bei einem späteren THROW ist keine OUTPUT-Zustellung zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@PrintMeldungen` | `bit` | Default: `1` | Steuert ergänzende Severity-10-Statusmeldung bei einem Status außerhalb AVAILABLE und NOT_APPLICABLE. Ein numerisch gebundener Wert 0 wird zu 0 und unterdrückt die Meldung; ein numerisch von 0 verschiedener Wert wird zu 1 und gibt sie mit RAISERROR(...,10,1) WITH NOWAIT aus. NULL ist ungültig. Die strukturierte Ausgabe und OUTPUT-Statuswerte werden davon nicht unterdrückt. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Hilfe` | `bit` | Default: `0` | Fordert die eingebaute PRINT-Hilfe mit Zweck, sämtlichen Parameterverträgen und Beispielaufrufen an. Nach numerischer Konvertierung nach bit führt 0 die Analyse aus; ein Wert ungleich 0 wird zu 1 und löst den Help-Return aus. NULL löst ihn nicht aus und wird nicht in der allgemeinen NULL-Prüfung erfasst. Vor dem Hilfezweig wird die TABLE-Zuordnung geprüft und @Json auf NULL gesetzt. Bei der frühen Rückkehr werden die vier Diagnose-OUTPUT-Parameter nicht neu zugewiesen. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | Default: `NULL` | OUTPUT liefert den globalen Statuscode in eine Aufrufer-Variable vom Typ varchar(40), die mit OUTPUT gebunden wird; bei einem späteren THROW ist keine OUTPUT-Zustellung zugesichert. Die 13 global erreichbaren Codes sind: AVAILABLE (alle ausgewerteten Datenbank- und Quellenpfade ohne Partialität; kein WARN-Finding), AVAILABLE_LIMITED (mindestens eine Datenbank oder Teilquelle ist eingeschränkt; Ergebnis ist partiell), AVAILABLE_WITH_FINDING (mindestens ein WARN-Finding bei sonst vollständiger Evidenz), NOT_APPLICABLE (kein auswertbarer Datenbankscope oder keine anwendbare Analyse), INVALID_PARAMETER (ungültige Parameter, Kombination oder CT-Wasserstand für mehr als eine ausgewählte Datenbank), UNAVAILABLE_VERSION (Schema-/Objektregex wurde auf SQL Server vor Version 17 angefordert), UNAVAILABLE_FEATURE (globaler Rückgabecode des Datenbankkandidaten-Helpers, wenn DatabaseNamePattern mit Regex auf Engine vor Version 17 oder Installationsdatenbank-Compatibility-Level unter 170 nicht verfügbar ist), ERROR_HANDLED (direkt propagierter Fehlerstatus des Namensfilter-Helpers 084 nach einem sonstigen behandelten Fehler), TIMEOUT (direkt propagierter Sperrtimeoutstatus des Namensfilter-Helpers 084), DENIED_PERMISSION (direkt propagierter Berechtigungsstatus des Namensfilter-Helpers 084), INTERNAL_ERROR (interner Fehlerstatus eines aufgerufenen Vorbereitungshelpers), HIGH_IMPACT_CONFIRMATION_REQUIRED (die Analyseklassenrichtlinie verlangt eine High-Impact-Bestätigung, die fehlt) und DENIED_GROUP (die Zugriffspolitik verweigert die Gruppe für die Analyseklasse). Schema-/Objektregex auf einer ausgewählten Zieldatenbank mit Compatibility-Level unter 170 setzt deren DatabaseStatus auf UNAVAILABLE_FEATURE und macht sie partiell; global wird dieser Ziel-Datenbankfall als AVAILABLE_LIMITED aggregiert. Andere Datenbank- und Quellenfehler werden in DatabaseStatus/SourceStatus und Partialität abgebildet, nicht als die drei direkt propagierten 084-Codes. Die reguläre OUTPUT-Zuweisung erfolgt vor CONSOLE-/TABLE-Finalisierung; beim Help-Return wird der Parameter nicht neu zugewiesen. Bei einem späteren THROW ist keine Zustellung zugesichert. Frühe Parameter-, Gate- und Helfercodes bleiben maßgeblich. Solange der Status AVAILABLE ist, haben partielle Ergebnisse Vorrang vor WARN-Findings, danach folgt ein fehlender anwendbarer Scope, sonst AVAILABLE. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@IsPartialOut` | `bit OUTPUT` | Default: `NULL` | OUTPUT-Bit, das anzeigt, ob mindestens eine Teilquelle oder Datenbank fehlt/eingeschränkt ist; im Aufruf ist eine bit-Variable mit OUTPUT zu binden. 0 bedeutet, dass der globale Lauf keine Partialität markiert hat; 1 bedeutet unvollständige Evidenz, auch wenn andere Resultsets nutzbare Daten enthalten. Regulär folgt der Wert dem globalen Status und wird vor CONSOLE-/TABLE-Finalisierung zugewiesen. Beim Help-Return wird er nicht neu zugewiesen; bei späterem THROW ist keine OUTPUT-Zustellung zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@ErrorNumberOut` | `int OUTPUT` | Default: `NULL` | OUTPUT für die unabhängige SQL-Fehlernummer; im Aufruf ist eine int-Variable mit OUTPUT zu binden. NULL bedeutet, dass der globale Analysepfad keine solche Fehlernummer gesetzt hat. Der Wert ist von @StatusCodeOut unabhängig: ein Status kann eine Quellenlücke kennzeichnen, während die Nummer NULL bleibt. Regulär vor CONSOLE-/TABLE-Finalisierung zugewiesen; beim Help-Return nicht neu zugewiesen, und bei späterem THROW ist keine OUTPUT-Zustellung zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | Default: `NULL` | OUTPUT für den unabhängig vom Statuscode gehaltenen Fehler-/Hinweistext; im Aufruf ist eine nvarchar(2048)-Variable mit OUTPUT zu binden. NULL bedeutet, dass kein globaler Fehlertext gesetzt ist. Der Code initialisiert die Meldung auf NULL und setzt sie für ungültige Parameter/Scope oder bestimmte Quellenfehler; Code und Text sind getrennte Felder. Regulär vor CONSOLE-/TABLE-Finalisierung zugewiesen; beim Help-Return nicht neu zugewiesen, und bei späterem THROW ist keine OUTPUT-Zustellung zugesichert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |

## Aufrufbeispiele zu den Parameterverträgen

Die Beispiele verwenden synthetische Namen, die durch einen ausdrücklich freigegebenen Scope ersetzt werden müssen. Die Analyseaufrufe bestätigen CATALOG_DEEP; Gruppenfreigabe und Quellenberechtigungen werden weiterhin geprüft. Das TABLE-Beispiel verwendet eine Seedspalte und räumt das Ziel auch im Fehlerfall auf. Der letzte Aufruf verwendet einen synthetischen CT-Consumer-Wasserstand; verwenden Sie einen für den gewählten Datenbereich belegten Consumer-Wasserstand.

```sql
EXEC [monitor].[USP_DataCaptureDeepAnalysis] @Hilfe=1;

EXEC [monitor].[USP_DataCaptureDeepAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @FullObjectNames=N'[ExampleDatabase].[ExampleSchema].[ExampleTable]', @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;

DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_DataCaptureDeepAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];

CREATE TABLE [#DataCaptureDeepAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_DataCaptureDeepAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#DataCaptureDeepAnalysis_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#DataCaptureDeepAnalysis_HelpExample]; DROP TABLE IF EXISTS [#DataCaptureDeepAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#DataCaptureDeepAnalysis_HelpExample]; THROW; END CATCH;

EXEC [monitor].[USP_DataCaptureDeepAnalysis] @DatabaseNamePattern=N'like:ExampleDatabase%', @SchemaNamePattern=N'like:Example%', @HighImpactConfirmed=1, @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;

EXEC [monitor].[USP_DataCaptureDeepAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @ChangeTrackingClientVersion=100, @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `findings`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

Die 13 Findings-Felder stammen bei RAW, CONSOLE, TABLE und JSON innerhalb eines Aufrufs aus derselben Exportmenge. `@NurProblematisch = 1` wählt WARN-Findings; `@MaxZeilen` begrenzt diese Auswahl nach Warnpriorität und `FindingOrdinal`. NULL und 0 bedeuten unbegrenzt; negative Werte sind ungültig. Die zehn Textfelder verwenden `SQL_Latin1_General_CP1_CS_AS`, auch wenn Quelle oder TempDB eine andere Collation besitzen. `FindingCount` wird vor dem Ausgabefilter und Limit bestimmt. `CtTableCount` stammt aus dem unfiltrierten Feature-Gate; Schema- und Objektfilter können die ausgegebenen CT-Tabellen und die darauf bezogenen Findings weiter einschränken.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem Datenbankstatus, isolierten Quellenstatus, Finding, einer Change-Tracking-Tabelle, CDC-Capture-Instanz, CDC-Scan-Sitzung, aggregierten CDC-Fehlergruppe, CDC-Jobkonfiguration, lokal sichtbaren Replikationsagenten oder aggregierten Replikationsfehlergruppe.

## So lesen

Prüfen Sie zuerst `StatusCode`, `IsPartial` und `SourceStatus`. Lesen Sie danach die drei Funktionsbereiche getrennt:

- Change Tracking: `ClientVersion` pro Consumer gegen `MinValidVersion` und `CurrentVersion`.
- CDC: Capture-Instanzen, Jobs, aggregierte Scan-Latenz und Fehler gemeinsam.
- Replikation: Agentstatus, lokaler Rückstand, Latenz und Fehler im selben Zeitfenster.

`REPLICATION_TOPOLOGY_NOT_LOCALLY_OBSERVABLE` ist eine Evidenzlücke. Sie darf nie als gesunder Replikationszustand interpretiert werden.

## Warum kann das problematisch sein?

Ein CT-Wasserstand unter `MinValidVersion` kann nicht mehr vollständig inkrementell enumeriert werden. Fehlende oder deaktivierte CDC-Jobs, wiederholte Scanfehler oder anhaltende Capture-Latenz können die Datenbereitstellung verzögern. Hohe undistributed-command-Zahlen, Retry/Fail-Agentstatus und lokale Replikationsfehler können auf einen Zustellrückstand hinweisen.

## Wann ist es kein Problem?

Ohne echten CT-Consumer-Wasserstand ist kein Synchronisationsverlust beweisbar. CDC mit nicht kontinuierlichem Capture kann zwischen geplanten Läufen erwartbar hohe Latenz zeigen. Ein Replikationsagent im Zustand `Idle` ist ohne Rückstand kein Fehler. Einzelne DMV- oder History-Zeilen sind keine lückenlose Zeitreihe.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Ein CT-Wasserstand unter `MinValidVersion` kann nicht mehr vollständig inkrementell enumeriert werden. Fehlende oder deaktivierte CDC-Jobs, wiederholte Scanfehler oder anhaltende Capture-Latenz können die Datenbereitstellung verzögern. Hohe undistributed-command-Zahlen, Retry/Fail-Agentstatus und lokale Replikationsfehler können auf einen Zustellrückstand hinweisen.

**Ähnlich aussehender Gegenfall:** Ohne echten CT-Consumer-Wasserstand ist kein Synchronisationsverlust beweisbar. CDC mit nicht kontinuierlichem Capture kann zwischen geplanten Läufen erwartbar hohe Latenz zeigen. Ein Replikationsagent im Zustand `Idle` ist ohne Rückstand kein Fehler. Einzelne DMV- oder History-Zeilen sind keine lückenlose Zeitreihe. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Nicht installiert, nicht aktiviert, in der gewählten Datenbank nicht verwendet und nicht abfragbar sind vier verschiedene Zustände.

Für `USP_DataCaptureDeepAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

Eine leere CDC-Scan-DMV kann nach Neustart/Failover oder auf einer AG-Sekundärreplik auftreten. Alle in `msdb` sichtbaren lokalen Distributionsdatenbanken werden getrennt gelesen und in Agent- und Fehlerzeilen ausgewiesen; lokale Distributionstabellen zeigen dennoch keinen Remote Distributor. Fehlende Rechte werden pro Quelle als `AVAILABLE_LIMITED` erhalten; zugängliche andere Evidenz bleibt gültig.

Eine nicht verfügbare explizit gewählte Datenbank behält ihren Auswahlwarning samt Partialität und Fehlerzählung. Ein Consumer-Wasserstand für mehrere auswertbare Datenbanken bleibt `INVALID_PARAMETER`, auch in deren Datenbankstatus. Objektfilter entfernen das datenbankweite INFO zu deaktiviertem Auto-Cleanup nicht; der Problemscope blendet es bei der Ausgabe aus.

## Eigenlast und Grenzen

Die SQL-Kostenklasse ist MEDIUM: sichtbare Kataloge, kleine CDC-DMVs, msdb-Jobmetadaten und aggregierte lokale Distributionstabellen. MEDIUM_HIGH_OPT_IN ist die separate statische Navigationsklassifikation. Das Modul liest keine CHANGETABLE-Ergebnisse, CDC-Change-Table-Zeilen, Replikationscommands, Kommentare, Fehlertexte, Credentials oder Agentjob-Commands. Für die älteste verfügbare CDC-Zeitgrenze ermittelt es intern die minimale LSN einer Capture-Instanz und bildet sie auf einen Zeitpunkt ab; rohe LSN-Werte werden nicht ausgegeben. Laufzeitnamen bleiben für die Diagnose vollständig sichtbar und sind bei Export oder Weitergabe zu schützen.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM (SQL-Header); statische Navigationsklassifikation: MEDIUM_HIGH_OPT_IN |
| Standardpfad | Eine `ExampleDatabase`, `@NurProblematisch = 1`, 24 Stunden Fehlerlookback und endliches Limit. Change-Tracking-Verlust wird nur bewertet, wenn ein echter Consumer-Wasserstand explizit übergeben wurde. |
| Teuerster Pfad | Alle sichtbaren Datenbanken ohne Objektfilter, sehr langer Fehlerlookback und unbegrenzte Ausgabe; zusätzlich große lokale CDC-/msdb- und Distributionsmetadatenbestände mit vielen Agents und Fehlergruppen. |
| Haupttreiber | Zahl gewählter Datenbanken, Change-Tracking-Tabellen, CDC-Capture-Instanzen/-Jobs und lokal sichtbarer Replikationsobjekte plus deren msdb-Jobhistory im Lookback. Change-Zeilen und Replikationsbefehle werden nicht gelesen. |
| Skalierung | Katalogpfade wachsen mit Datenbanken und erfassten Tabellen; CDC-/Replikationspfade zusätzlich mit Scan-Sessions, Fehlergruppen, Jobs und lokal erreichbaren Agentmetadaten im Lookback. |
| Ressourcen | CPU und Katalog-/msdb-/lokales Distribution-DB-I/O, dynamisches SQL je Datenbank sowie TempDB/Arbeitsspeicher für isolierte Quelltabellen, Aggregation und Findings. |
| Begrenzungswirkung | Datenbank- und Objektfilter begrenzen lokale Katalogarbeit. `@ErrorLookbackHours` begrenzt Fehlerhistorie. `@MaxZeilen` wird erst beim Ausgeben jedes Resultsets angewandt und begrenzt die vorherige Quellenlesung und Findingerzeugung nicht. |
| Locking und Nebenwirkungen | Read-only; keine Change-Table-Zeilen, Replikationscommands oder Agentbefehle werden gelesen. Katalog-, msdb- und lokale Distribution-DB-Zugriffe können mit Cleanup/Agentaktivität zeitlich überlappen; die Teilquellen sind nicht atomar. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `CATALOG_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine bekannte `ExampleDatabase`, Problemscope und kurzer Lookback. Einen Consumer-Wasserstand nur datenbankspezifisch und fachlich verifiziert übergeben; danach Quellenstatus vor Findings lesen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot + retentionbegrenzte Metadatenhistorie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche sichtbaren CT-, CDC- und lokalen Replikationsmetadaten liegen vor, und welche konfigurierbaren Prüfhinweise ergeben sich daraus?

### Technischer Hintergrund

CDC Capture liest das Transaktionslog in Change Tables; Cleanup verschiebt `min_lsn`. Consumer müssen ihren LSN-Checkpoint vor Cleanup verarbeiten. Change Tracking speichert Versionsmarken; `CHANGE_TRACKING_MIN_VALID_VERSION` bestimmt, ob ein Consumer reinitialisieren muss. Replication nutzt Logreader/Distributoragenten und eigene History.

### Datenkette

`msdb.dbo.agent_datetime`, `msdb.dbo.sysjobhistory`, `msdb.dbo.sysjobs`, `sys.change_tracking_databases`, `sys.change_tracking_tables`, `sys.databases`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`, `cdc.change_tables`, `msdb.dbo.cdc_jobs`, `msdb.dbo.MSdistributiondbs`, `distribution.dbo.MSdistribution_agents`, `distribution.dbo.MSdistribution_history`, `distribution.dbo.MSdistribution_status`, `distribution.dbo.MSsubscriptions`, `distribution.dbo.MSlogreader_agents`, `distribution.dbo.MSlogreader_history`, `distribution.dbo.MSmerge_agents`, `distribution.dbo.MSmerge_sessions`, `distribution.dbo.MSrepl_errors`, `sys.dm_cdc_errors`, `sys.dm_cdc_log_scan_sessions`, `sys.fn_cdc_get_min_lsn`, `sys.fn_cdc_map_lsn_to_time`, `CHANGE_TRACKING_CURRENT_VERSION`, `CHANGE_TRACKING_MIN_VALID_VERSION`.

### Source Select

Die Procedure besitzt getrennte Pfade für Change Tracking, CDC und Replication. Der folgende Katalogkern zeigt die Beziehung der Change-Tracking-Tabellen:

```sql
SELECT
      [s].[name] AS [SchemaName]
    , [t].[name] AS [TableName]
    , [ct].[begin_version]
    , [ct].[cleanup_version]
    , CHANGE_TRACKING_MIN_VALID_VERSION([ct].[object_id]) AS [MinValidVersion]
FROM [sys].[change_tracking_tables] AS [ct] WITH (NOLOCK)
JOIN [sys].[tables] AS [t] WITH (NOLOCK)
  ON [t].[object_id] = [ct].[object_id]
JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
  ON [s].[schema_id] = [t].[schema_id]
WHERE [s].[name] = N'ExampleSchema'
  AND [t].[name] = N'ExampleObject';
```

**Wichtig für die Eigenlast:** Legen Sie Datenbank und Objekt vor CDC-Logscan- und Distribution-Historie fest. Berücksichtigen Sie `sys.dm_cdc_log_scan_sessions`, `sys.dm_cdc_errors` und Distributionstabellen nur im fachlich benötigten, bestätigten Tiefenpfad und mit engem Zeitfenster.

### Zeit- und Scope-Modell

Die Auswertung beschreibt sichtbares Enablement, Job- und Sessionmetadaten, CT-Versionswerte, abgeleitete CDC-Zeitgrenzen und begrenzte Fehler- beziehungsweise Agentenaggregate. Rohe LSN-Werte und ein CDC-Consumer-Checkpoint gehören nicht zur Ausgabe.

### Bewertung und Gegenprobe

Korrelieren Sie Capture Instance, Start/End LSN, Min/Max, Consumercheckpoint, Cleanup Retention, Log Scan Sessions/Errors, Change Tracking Current/Min Valid Version und Replicationagenten. Bewerten Sie Lag als Abstand und Zeit.

### Typische Fehlinterpretation

Enabled und laufender Job beweisen keine lückenlose Konsumierbarkeit. Wenn Consumercheckpoint älter als Min Valid/Min LSN ist, helfen weitere Reads nicht; Reinitialisierungsstrategie nötig.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Agent Monitoring, Replication, Log/Capacity und Consumerstatus.

## Primärquellen

- [Change Data Capture](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-data-capture-sql-server?view=sql-server-ver17)

[Technische Detailbeschreibung](../09_Version_Adaptive.md#7-monitorusp_datacapturedeepanalysis)
