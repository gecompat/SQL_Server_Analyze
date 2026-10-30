# [monitor].[USP_CurrentOverview]

**Bereich:** Current State, Orchestrator<br>
**Zweck:** Führt mehrere leichte Live-Analysen in definierter Reihenfolge aus.<br>
**Beobachtungsart:** nicht atomare Folge aus Snapshots und optionalen Stichproben<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Current-State-Symptome verdienen als Erstes eine spezialisierte Analyse?** Sie unterstützt die Entscheidung, ob das aktuelle Symptom im Erfassungsmoment sichtbar ist und welcher engere Live-, Verlaufs- oder Planpfad als Nächstes sinnvoll ist.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine lückenlose Historie und allein aus einem Snapshot weder Dauerhäufigkeit noch Root Cause oder zukünftige Entwicklung. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentOverview]
      @MitSqlText = 0,
      @SampleSeconds = 0,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Die Hilfe listet alle öffentlichen Parameter mit Typ, Default, Wirkung und synthetischen CONSOLE-, TABLE- und JSON-Aufrufen; vor dem Hilfezweig wird eine angeforderte TABLE-Zuordnung bereits geprüft.

Der Default `@Detailgrad = 'SUMMARY'` liefert genau ein konsolidiertes
Modul-Summary. `RELEVANT` ergänzt nicht leere diagnostisch relevante Details;
`ALL` ergänzt alle nicht leeren aktivierten Childdetails. Aktivieren Sie Sampling
und vollständige SQL-Texte nur gezielt.

`@ToolHintergrundabfragenEinbeziehen = 0` wird an Sessions, Requests, Blocking
und aktuelle Waiting Tasks weitergegeben. Mit Wert `1` werden erkannte
Tool-Hintergrundaktivitäten samt Klassifikation in allen vier Childresultaten
sichtbar. Die Blockingkette normaler Abfragen bleibt auch dann vollständig,
wenn ihr Zwischen- oder Root-Blocker ein erkanntes Tool ist.

Die Blocking-Ressourcenauflösung ist durchgereicht: `NONE` deaktiviert sie,
`STANDARD` ist der auf 100 Kandidaten begrenzte Default. `DEEP` liest zusätzlich
die Locks beteiligter Blocking-Sessions und prüft `LOCKS_DEEP`.
Gruppenfreigabe und `@HighImpactConfirmed = 1` sind erforderlich, wenn die
aktive Policy `RequiresGroupGate=1` setzt.

```sql
DECLARE @OverviewJson nvarchar(max);
EXEC [monitor].[USP_CurrentOverview]
      @BlockingObjektTiefe = 'DEEP',
      @MaxObjektAufloesungen = 500,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'NONE',
      @JsonErzeugen = 1,
      @Json = @OverviewJson OUTPUT;
SELECT JSON_QUERY(@OverviewJson, '$.blocking.locks') AS BlockingLocks;
```

Die vollständigen Deep-Lockzeilen liegen im Overview-JSON unter
`$.blocking.locks`. CONSOLE- und TABLE-Details des Orchestrators materialisieren
nur die Blockingketten. Für ein direktes Lockgrid ist
`USP_CurrentBlocking @ResultSetArt = 'RAW'` der passendere Aufruf.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parametervertrag

Die Verträge beschreiben die Parentprüfung und die Weitergabe an die jeweils aktivierten Childmodule. Eine erforderliche TABLE-Vorprüfung läuft bereits vor dem Hilfepfad; `@Hilfe=1` startet danach keine Childmodule und exportiert keine fachlichen Daten.

| Parameter | Typ, Default, Eingabeform und Wirkung |
|---|---|
| `@SessionIds` | nvarchar(max); Default=NULL. Der Parent normalisiert oder parst den Wert nicht, sondern übergibt ihn unverändert an genau sieben Children: USP_CurrentSessions, USP_CurrentRequests, USP_CurrentBlocking, USP_CurrentWaits, USP_CurrentTransactions, USP_CurrentMemoryGrants und USP_CurrentTempDB. NULL deaktiviert den ID-Filter. Eine Liste kann Pipe, Komma und Semikolon auch gemischt verwenden; Komma und Semikolon werden vor der Pipe-Zerlegung überall in Trenner umgewandelt, auch innerhalb von [...]. Pipe trennt nur außerhalb bracket-quotierter Bereiche; äußere Elementleerzeichen werden getrimmt. Jedes Element muss eine Ganzzahl sein. Leerstring ergibt EMPTY_LIST, reine Leerzeichen oder leere Elemente EMPTY_ITEM; ungültige Elemente und Bereichsverletzungen führen zu INVALID_PARAMETER. Gültige Bereiche und Duplikate unterscheiden sich je Child: Sessions, Requests, Waits und MemoryGrants akzeptieren 1..32767 und fassen Duplikate zusammen; Blocking, Transactions und TempDB akzeptieren 0..32767, lehnen Duplikate ab. Die Liste wird nicht entquotet; Klammerquotierung macht aus einem Zahlenwert keine gültige ID. |
| `@DatabaseNames` | nvarchar(max); Default=NULL. Bracket-aware Pipe-Liste exakter einteiliger Datenbanknamen mit höchstens 128 Zeichen je Name für I/O und Log; &#124; trennt nur außerhalb von [...], ein &#124; in [...] ist Teil des Namens, und ]] maskiert ein inneres ]. Verglichen wird case-sensitiv; doppelte/ungültige Einträge erzeugen Auswahlfehler oder Warnings. NULL, leer, nur gewöhnliche Leerzeichen oder ausgelassen bedeutet alle sichtbaren, zugreifbaren ONLINE-Benutzerdatenbanken. Exklusiv mit @DatabaseNamePattern; explizit nicht verfügbare Namen können Auswahlwarnings erzeugen. Nur I/O und Log erhalten diesen Filter. |
| `@SystemdatenbankenEinbeziehen` | bit; Default=0. 0 schließt master, tempdb, model und msdb aus; 1 erlaubt diese sichtbaren ONLINE-Systemdatenbanken für I/O/Log. Ausgelassen ergibt 0; NULL wird als INVALID_PARAMETER abgelehnt. Numerische Eingaben werden vor Eintritt zu bit konvertiert: 0 bleibt 0, jeder numerische Nichtnullwert wird 1. Keine Wirkung auf andere Children. |
| `@DatabaseNamePattern` | nvarchar(4000); Default=NULL. Ein nichtleeres einzelnes Pattern, exklusiv mit @DatabaseNames, für I/O und Log. Kein Präfix oder like: = case-sensitives SQL-LIKE mit %, _ und []-Klassen; regex: = case-sensitive Regex; regexi: = case-insensitive Regex. Präfixerkennung ist case-insensitiv, äußere Leerzeichen werden entfernt, Musterinhalt bleibt erhalten. NULL/ausgelassen deaktiviert; leer, nur gewöhnliche Leerzeichen oder Präfix ohne Muster ist ungültig. Regex verlangt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Andere Children verwenden das Pattern nicht. |
| `@HighImpactConfirmed` | bit; Default=0. 0/ausgelassen bestätigt keine angeforderten Hochwirkungswege; 1 bestätigt sie. Numerische Werte werden vor Eintritt zu bit konvertiert (0→0, jeder Nichtnullwert→1); NULL wird als INVALID_PARAMETER abgelehnt. Diese Bestätigung erteilt keine Zugriffsgruppenfreigabe: Children prüfen ihre eigenen erforderlichen Gruppenrechte und Gates; Parent reicht den Wert an Blocking, I/O und Log weiter. DEEP Blocking braucht zusätzlich LOCKS_DEEP. |
| `@ToolHintergrundabfragenEinbeziehen` | bit; Default=0. 0 blendet erkannte Toolaktivität in Sessions, Requests, Blocking-Blättern und aktuellen Waiting Tasks aus; 1 bezieht sie ein, ohne normale Blockingketten abzuschneiden. Ausgelassen ergibt 0; NULL ist INVALID_PARAMETER; numerisch 0 bleibt 0, jeder Nichtnullwert wird vor Procedure-Eintritt 1. Andere Children erhalten diesen Filter nicht. |
| `@Detailgrad` | varchar(16); Default='SUMMARY'. Nach TRIM/UPPER exakt SUMMARY (nur Modulstatus), RELEVANT (Status plus nichtleere als relevant markierte Childdetails) oder ALL (Status plus nichtleere Resultate aller aktivierten Children mit AVAILABLE/AVAILABLE_LIMITED). Reihenfolge folgt den neun Modulen; Zeilen innerhalb der Grids sind nicht geordnet. Ausgelassen ergibt SUMMARY; NULL/leer normalisiert zu leer und ist ungültig. Keine Reduktion der Child-Erhebungsarbeit. |
| `@MitSessions` | bit; Default=1. 1 ruft USP_CurrentSessions genau einmal mit TABLE auf; 0 überspringt es und setzt Modulstatus SKIPPED. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1 vor Eintritt. |
| `@MitRequests` | bit; Default=1. 1 ruft USP_CurrentRequests genau einmal mit TABLE auf; 0 überspringt das Child (SKIPPED). Aktiviertes Requests-Child kann Requestkontext, Statements, Batches und InputBuffers liefern. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1. |
| `@MitBlocking` | bit; Default=1. 1 ruft USP_CurrentBlocking einmal auf; 0 überspringt Blockingketten und Ressourcenauflösung (SKIPPED). DEEP-Einstellungen wirken nur bei aktiviertem Child. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1. |
| `@BlockingObjektTiefe` | varchar(16); Default='STANDARD'. Nach TRIM/UPPER exakt NONE (keine Ressourcenauflösung), STANDARD (Auflösung mit begrenzter Kandidatenzahl) oder DEEP (zusätzlich Locks beteiligter Blocking-Sessions, Prüfung von LOCKS_DEEP; Gruppenfreigabe und @HighImpactConfirmed=1 nur bei aktiver Policy RequiresGroupGate=1). Ausgelassen=STANDARD; NULL/leer/andere Werte ungültig. Wird an Blocking weitergereicht; bei deaktiviertem Blocking keine Childauswirkung. |
| `@MaxObjektAufloesungen` | int; Default=100 Kandidaten. Ganze Zahl 1 bis 1000 einschließlich; begrenzt Blocking-Ressourcenkandidaten, nicht die gesamte Ausgabe. Ausgelassen=100; NULL und Werte außerhalb des Bereichs INVALID_PARAMETER. Child verwendet diesen Wert für die Objektauflösung. |
| `@MitWaits` | bit; Default=1. 1 ruft USP_CurrentWaits auf; 0 überspringt aktuelle Waiting Tasks und Wait-Analyse. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1. |
| `@MitTransactions` | bit; Default=1. 1 ruft USP_CurrentTransactions auf; 0 überspringt das Transaktions-Child. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1. |
| `@MitMemoryGrants` | bit; Default=1. 1 ruft USP_CurrentMemoryGrants auf; 0 überspringt das Memory-Grant-Child. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1. |
| `@MitTempDB` | bit; Default=1. 1 ruft USP_CurrentTempDB auf und exportiert bei TABLE sessions, tempdbGovernance und versionStore; 0 überspringt diese Quellen/Childexports. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1. |
| `@MitIO` | bit; Default=1. 1 ruft USP_CurrentIO für Datei-I/O auf; 0 überspringt dieses datenbankbezogene Child. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1. |
| `@MitLog` | bit; Default=1. 1 ruft USP_CurrentLog für Transaktionslogzustände auf; 0 überspringt dieses datenbankbezogene Child. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1. |
| `@MitSqlText` | bit; Default=1. 1 erlaubt unterstützenden Children SQL-Text; 0 deaktiviert ihn. Parent-Snapshot materialisiert Text nur bei mindestens einem tatsächlichen Consumer; Handles werden vor DMF-Zugriff dedupliziert/begrenzt. Requests-Child muss dafür aktiviert sein, und weitere Children können den gemeinsamen Text verbrauchen. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1. |
| `@GesamtenSqlTextEinbeziehen` | bit; Default=0. 1 fordert bei Requests vollständigen Batch-/Modultext an; 0 fordert ihn nicht an. Separater Childschalter neben @MitSqlText und nur wirksam mit aktiviertem Requests-Child. Ausgelassen=0, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1. |
| `@InputBufferEinbeziehen` | bit; Default=0. 1 fordert den Input Buffer als gezielte Requests-Quelle an; 0 nicht. Input Buffer ist kein gemeinsamer Primär-Snapshot und wird nur durch das aktivierte Requests-Child erhoben. Ausgelassen=0, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1. |
| `@ModulInfoEinbeziehen` | bit; Default=1. 1 fordert Request-Modulkontext an; 0 nicht. Der gemeinsame SQL-Text-Capture berücksichtigt diesen Schalter nur bei aktiviertem Requests-Child. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1. |
| `@MaxSqlTextZeichen` | int; Default=4000 Zeichen. Nichtnegative ganze Zahl bis 2147483647; wird an die textausgebenden Children weitergereicht. Eine positive Grenze kürzt die jeweilige Textprojektion nur bei Überschreitung. NULL oder 0 hebt die durch diesen Parameter bewirkte Textbegrenzung auf; es wird dann nicht aufgrund dieses Limits gekürzt. Ausgelassen nutzt 4000. Der Parent lässt NULL passieren; negative Werte sind INVALID_PARAMETER. Das Limit ist keine Anonymisierung. |
| `@SampleSeconds` | tinyint; Default=0 Sekunden; zulässige Werte 0 bis 60. 0 deaktiviert WAITFOR-Sampling; 1 bis 60 sampelt Waits und I/O nacheinander, verlängert den Parent entsprechend und kann durch Scheduling länger dauern. Ausgelassen nutzt 0. Die Parentprüfung lässt NULL durch: Bei aktiviertem I/O wird es als INVALID_PARAMETER abgelehnt; Waits gelangt damit in den Samplingpfad mit NULL-Verzögerung und behandelt den daraus entstehenden Fehler im DeltaStatus als ERROR_HANDLED mit partieller Sicht. Bereits verfügbare Taskdaten können dabei erhalten bleiben. Werte über 60 sind INVALID_PARAMETER; die Konvertierung zu tinyint erfolgt vor Eintritt. |
| `@MaxZeilen` | int; Default=500 Zeilen je Child, nicht als Gesamtbudget. Negative Werte INVALID_PARAMETER; NULL oder 0 sind im Parent zulässig und können je Child unbegrenzt bedeuten; positive Werte werden weitergereicht und je Childstufe unterschiedlich angewandt. Ausgelassen=500. Kein globales Limit für Modulstatus oder alle Resultate zusammen. |
| `@ResultSetArt` | varchar(16); Default='CONSOLE'. Nach TRIM/UPPER exakt CONSOLE (Modulstatusgrid plus gemäß @Detailgrad gewählte nichtleere Childgrids), RAW (Modulstatus, Snapshotstatus und Warnings; keine Childdatengrids), TABLE (nur angeforderte benannte Exporte), NONE (keine fachlichen Resultsets). Ausgelassen=CONSOLE; NULL/leer wird zu '' und ist ungültig. Anders als der Modus entscheidet @Detailgrad über zusätzliche CONSOLE-Details. |
| `@ResultTablesJson` | nvarchar(max); Default=NULL. TABLE-Zuordnung als nichtleeres JSON-Objekt; die exakt case-sensitiven Key-Bedeutungen sind moduleStatus = Parent-Modulstatus, snapshotStatus = Status der Snapshotquellen, sessions = Sessionresultate, requests = Requestresultate, requestContext = Requestkontext, statements = Statementtexte, batches = Batch-/Modultexte, inputBuffers = Input-Buffer-Daten, blocking = Blockingketten, waits = aktuelle Waiting Tasks, transactions = Transaktionsresultate, memoryGrants = Memory-Grant-Resultate, tempdbSessions = TempDB-Sessionverbrauch, tempdbGovernance = TempDB-Governancewerte, versionStore = Version-Store-Werte, io = Datei-I/O-Resultate, logs = Transaktionslogzustände und warnings = Warnungen. Jeder zugehörige Wert muss ein nichtleerer JSON-String mit Name einer vorhandenen lokalen #Temp-Tabelle sein (keine ##-Temp, Name höchstens 116 Zeichen, nicht #Monitor...). Ziele müssen leer sein und genau eine Seed-Spalte haben; Resultnamen und Zieltabellen dürfen nicht doppelt vorkommen. Unbekannte Keys, ungültige JSON/Form, Typen oder Ziele schlagen im Preflight mit 51011 fehl. Für TABLE erforderlich. Außerhalb TABLE muss der Wert NULL, leer oder nach SQL-LTRIM/RTRIM nur aus gewöhnlichen Leerzeichen bestehen; eine nichtleere Map ist unzulässig. Wird bei TABLE oder nichtleerer Map vor dem Hilfezweig und vor semantischen Parentchecks validiert. Gültiges Mapping garantiert keine späteren Daten/Frische; deaktivierte Childtargets können ungeschrieben bleiben, Request-Kontext/Textziele Seed-Schema behalten. |
| `@JsonErzeugen` | bit; Default=0. 0 deaktiviert JSON; 1 baut unabhängig von @ResultSetArt ein JSON-Objekt. Ausgelassen=0; NULL und Werte außer 0/1 sind INVALID_PARAMETER. Numerische Eingaben vor Eintritt: 0→0, Nichtnull→1. Envelope: meta (resultName, schemaVersion, generatedAtUtc, statusCode, evidenceSnapshotId, isPartial, executedModules, failedModules, partialModules, toolBackgroundQueriesIncluded), moduleStatus, snapshotStatus, warnings sowie je aktiviertem Child dessen benanntes Array in Modulreihenfolge. Resultfehler können als null-Childvalue erscheinen. |
| `@Json` | nvarchar(max) OUTPUT; Default=NULL. Optionale Aufrufvariable vom Typ nvarchar(max), im EXEC mit OUTPUT zu binden. Wird bei Procedure-Eintritt immer zuerst auf NULL gesetzt; wenn @JsonErzeugen=1 wird sie mit dem JSON-Envelope befüllt, andernfalls bleibt sie NULL. Das Auslassen der Empfangsbindung verhindert das Empfangen des Werts. |
| `@PrintMeldungen` | bit; Default=1. 1 aktiviert die optionalen Status-/Warnmeldungen der aktivierten Children; 0 unterdrückt diese Meldungen, ohne Resultsets oder JSON zu deaktivieren. Ausgelassen nutzt 1. Der Parent weist NULL nicht zurück: Blocking und I/O lehnen NULL als INVALID_PARAMETER ab; Sessions, Requests, Waits, Transactions, MemoryGrants, TempDB und Log unterdrücken damit die Meldungen ihrer IF-gleich-1-Pfade. Diese Folgen betreffen nur die jeweils aktivierten Childmodule. SQL Server konvertiert numerisch 0 vor Eintritt zu bit 0 und numerische Werte ungleich 0 zu bit 1. |
| `@Hilfe` | bit; Default=0. Bei exakt 1 wird PRINT-Hilfe ausgegeben und nach einer gegebenenfalls angeforderten TABLE-Map-Vorprüfung zurückgekehrt, ohne Children oder Exporte auszuführen. 0 führt den normalen Pfad aus. Ausgelassen=0; NULL wird nicht als Hilfe erkannt und führt in den normalen Pfad, nicht zu INVALID_PARAMETER. Numerische Werte werden vor Eintritt zu bit konvertiert. |

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `moduleStatus`, `snapshotStatus`,
`sessions`, `requests`, `requestContext`, `statements`, `batches`,
`inputBuffers`, `blocking`, `waits`, `transactions`, `memoryGrants`,
`tempdbSessions`, `tempdbGovernance`, `versionStore`, `io`, `logs` und `warnings`. Status, Scope und Warnings sind
vor den Fachergebnissen zu lesen. Resultsets mit unterschiedlicher
Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden. Im
Overview-JSON liegt die Governance innerhalb des einmal erzeugten TempDB-Childs
unter `$.tempdbSessions.tempdbGovernance`; der traditionelle Version Store und
der ADR Persistent Version Store liegen unter `$.tempdbSessions.versionStore`.


RAW und CONSOLE zeigen sechs Summaryfelder je Modul. TABLE `moduleStatus`
besitzt zusätzlich Modulordinal und Resultname, insgesamt acht Felder; JSON
`moduleStatus` enthält sieben Felder ohne Ordinal. `snapshotStatus` besitzt elf
und `warnings` drei Felder. Die Summary enthält auch deaktivierte Module mit
`SKIPPED`; deren Childobjekte fehlen im JSON.

TABLE-Zuordnungen werden vor Hilfe und semantischer Parameterprüfung validiert,
wenn TABLE oder eine nichtleere Zuordnung angefordert ist. Fehlerhafte Zuordnungen
werfen 51011. Bei gültiger TABLE-Zuordnung und `INVALID_PARAMETER` werden die
angeforderten Parentstatus-Schemata ausgegeben; JSON weist diese Ablehnung ebenfalls
als partiell aus. Hilfe führt keine Childanalyse und keinen Zieleintrag aus.
Deaktivierte primäre Childziele bleiben ungeschrieben. Die angeforderten
Requestkontext- und Textziele können ohne Requestchild ihre Seed-Form behalten;
`tempdbGovernance` und `versionStore` werden nur mit aktiviertem TempDB-Child exportiert. Dieser
bedingte Vertrag erzeugt keine vollständigen leeren Childschemata für deaktivierte
Module.

## Laufinterner Primär-Snapshot

Vor den acht Snapshot-fähigen Children materialisiert der Overview-Owner nur die
dafür benötigten Primärquellen. `snapshotStatus` weist pro Quelle
`SnapshotId`, `CapturedAtUtc`, Abschlusszeit, Status, Partialität und Zeilenzahl aus.
`CapturedRowCount` zählt die für diese Quelle und Snapshot-ID materialisierten
Zeilen vor den Childfiltern und Ausgabelimits. Insbesondere zählt `SESSIONS`
die Sessiontabelle, unabhängig davon, ob Workload Groups angefordert wurden.
Der Quellenzähler kann deshalb größer als die sichtbare Sessionmenge sein.
SQL-Text wird nur bei einem tatsächlichen Consumer materialisiert;
SQL-Handles werden vor dem DMF-Zugriff dedupliziert und begrenzt. Input Buffer
bleibt eine gezielte Post-Candidate-Quelle von `USP_CurrentRequests` und gehört
noch nicht zum gemeinsamen Primär-Snapshot.

Sessions, Requests, Blocking, Waits, Transactions, Memory Grants, TempDB und
I/O erhalten dieselbe laufinterne Snapshot-ID und lesen die gemeinsam
materialisierten Quellen nicht erneut. Mit `@MitTempDB=1` umfasst dieser
Snapshot auf SQL Server 2025 auch Workload-Group-Limits, Nutzung, Peak,
Verletzungszähler und Resetzeitpunkt. Eigene, nicht überlappende Quellen wie
Locks, Instanz-Wait-Stats, Datei-I/O oder TempDB-Dateikatalog bleiben im
jeweiligen Child. Schlägt der Owner selbst fehl, wird der Fehler als
`SNAPSHOT_OWNER` ausgewiesen und die Children fallen auf frische Einzelreads
zurück.

Der aktivierte TempDB-Pfad materialisiert außerdem `TRADITIONAL_VERSION_STORE`
und `PERSISTENT_VERSION_STORE`. `versionStore` übernimmt deren Quellzeit je
Datenbank; sie ist nicht die Startzeit eines späteren Childaufrufs.

Die Snapshot-ID und alle Temp-Tabellen enden mit dem Procedure-Aufruf. Ein
späterer Einzelaufruf kann sie nicht wiederverwenden. Die Quellzeitpunkte
bleiben getrennt; dieselbe ID bedeutet einen gemeinsamen Aufrufvertrag, keine
transaktionale Atomizität.

## Eine Zeile bedeutet

Im Summary entspricht eine Zeile einem Childmodul. Status, Partialität,
Zeilenanzahl und Dauer stammen aus dem expliziten Childvertrag. In den bewusst
aktivierten Detailgraden entspricht eine Detailzeile weiterhin Session, Request,
Blockingkante, Wait, Transaktion, Grant, TempDB-Verbrauch, Datei-I/O oder
Logzustand.

## So lesen

Lesen Sie zuerst den Modulstatus und wechseln Sie danach vom konkreten Symptom zum passenden Child. Addieren Sie Resultsets nicht ungeprüft miteinander.

## Warum kann das problematisch sein?

Ein Überblick verdichtet unterschiedliche Evidenzarten. Ein auffälliger Einzelwert ohne Childkontext kann zu einer falschen Ursache führen.

## Wann ist es kein Problem?

Nicht aktivierte Childobjekte fehlen im JSON; die Summary zeigt sie als `SKIPPED`. Ein leeres Child ist nur bei erfolgreichem Status als „aktuell nichts sichtbar“ interpretierbar.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Blocking und hohe Logauslastung können dieselbe alte Transaktion als Ursache haben. Mit Blocking- und Transaktionsprocedure fokussiert nachprüfen.

**Ähnlich aussehender Gegenfall:** Nicht aktivierte Childobjekte fehlen im JSON; die Summary zeigt sie als `SKIPPED`. Ein leeres Child ist nur bei erfolgreichem Status als „aktuell nichts sichtbar“ interpretierbar. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Bei Live-DMVs kann der Zustand bereits beendet sein, bevor die Quelle gelesen wird. Eine leere Menge ist deshalb höchstens 'jetzt nicht sichtbar', nicht 'trat nicht auf'.

Für `USP_CurrentOverview` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Der Default ruft alle neun Current-State-Children einmal auf, materialisiert deren TABLE-Ergebnisse und erzeugt Childstatus/JSON. `@Detailgrad = 'SUMMARY'` verkürzt nur die sichtbare Ausgabe; er spart die Erhebung nicht ein. Mit `@SampleSeconds = 0` gibt es kein WAITFOR. |
| Teuerster Pfad | Breiter Datenbank- und Sessionscope, SQL-Text an und `@SampleSeconds = 60`: `USP_CurrentWaits` und `USP_CurrentIO` sampeln nacheinander, sodass allein die beiden WAITFOR-Intervalle den Parent um ungefähr 120 Sekunden verlängern können. |
| Haupttreiber | Zahl sichtbarer Sessions, Requests, Blockingkanten, Transaktionen, Grants und TempDB-Verbraucher sowie Datenbanken/Dateien für I/O und Log. SQL-Text verbreitert mehrere Childresultate. |
| Skalierung | Acht Children verwenden die gemeinsam materialisierten Primärquellen; Log und ergänzende Childquellen werden separat gelesen. Die Arbeit läuft sequenziell. Mehr Detailausgabe erhöht den Transfer, ändert aber nicht die bereits angefallene Childarbeit. |
| Ressourcen | Live-DMV- und Datenbankmetadatenzugriffe, Temp-Tabellen/JSON und optional zwei wartende Samplephasen. Es gibt in diesem Parent keinen XEL-, Plan-XML-, `msdb`- oder Benutzerdatenscan. |
| Begrenzungswirkung | `@MaxZeilen` wird je Child weitergereicht und ist kein globales Budget. Einige Children nutzen ein frühes Kandidatenlimit, andere begrenzen erst sortierte/aggregierte Resultate; die Quellen für Instanzwaits und Datei-I/O werden dadurch nicht vollständig vermieden. `SUMMARY` ist ausdrücklich kein Kostenlimit. |
| Locking und Nebenwirkungen | Read-only ohne absichtlich gehaltene Nutzdatenlocks. Sampling hält die aufrufende Session während jedes WAITFOR; die Children laufen nacheinander und bilden daher keinen atomaren Zustand. |
| Schutzmechanismus | `@HighImpactConfirmed` wird an datenbankbezogene Children weitergereicht und wirkt nur, wenn deren konkrete Analyseklasse ein Gate verlangt. Der Parent reicht die explizite Blocking-DEEP-Option samt Gate weiter; VLF-, PVS- und Plan-XML-Optionen aktiviert er nicht. Der Schalter begrenzt weder Laufzeit noch Ergebnisgröße. |
| Sicherer Einsatz | SQL-Text und Sampling zunächst aus, `@MaxZeilen = 100`, nicht benötigte Children abschalten und Datenbanken/Sessions eingrenzen. Nach dem Summary genau das Child separat wiederholen, das zum Symptom passt. |
| Aussagegrenze | Ein Child kann zwischen den sequenziellen Abfragen verschwinden oder neu entstehen. Ein Parentlimit kann Ranglisten abschneiden, und ein erfolgreicher Summarystatus macht die unterschiedlichen Messzeitpunkte nicht konsistent; „leer“ bedeutet nur im jeweiligen Childmoment nicht sichtbar. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Current-State-Symptome verdienen als Erstes eine spezialisierte Analyse?

### Technischer Hintergrund

Der Orchestrator ruft jedes aktivierte Child genau einmal und niemals mit
CONSOLE auf. Der eine Childaufruf materialisiert das Primärergebnis und erzeugt
den JSON-/Statusvertrag. Summary, optionale Details, JSON und TABLE-Export nutzen
diese Materialisierung weiter. Das Ausbleiben eines SQL-Fehlers wird nicht als
`AVAILABLE` interpretiert; ein fehlender oder unvollständiger Statusvertrag wird
als `STATUS_UNAVAILABLE` partiell ausgewiesen.

TABLE verwendet ausschließlich `@ResultTablesJson`. Exportierbar sind
`moduleStatus`, `snapshotStatus`, `sessions`, `requests`, `requestContext`,
`statements`, `batches`, `inputBuffers`, `blocking`, `waits`, `transactions`,
`memoryGrants`, `tempdbSessions`, `tempdbGovernance`, `versionStore`, `io`,
`logs` und `warnings`.

### Datenkette

Der Orchestrator lässt die benötigten Primärquellen durch `InternalCaptureCurrentStateSnapshot` materialisieren. Die Children verwenden diese Quellen und ergänzen ihre jeweils eigenen Detailquellen.

### Source Select

Kein einzelnes Grundselect wird verwendet. Die Procedure orchestriert `USP_CurrentSessions`, `USP_CurrentRequests`, `USP_CurrentBlocking`, `USP_CurrentWaits`, `USP_CurrentTransactions`, `USP_CurrentMemoryGrants`, `USP_CurrentTempDB`, `USP_CurrentIO` und `USP_CurrentLog`. Die direkten Quellbeziehungen stehen in den jeweiligen Child-Seiten.

**Wichtig für die Eigenlast:** Die Childmodule laufen nacheinander und bilden keinen atomaren Snapshot. `@MitSqlText = 0`, ein endliches `@MaxZeilen` und `@SampleSeconds = 0` halten den Einstieg klein. Vertiefen Sie anschließend nur den auffälligen Childpfad.

### Zeit- und Scope-Modell

Die Auswertung kombiniert nahe beieinanderliegende, aber nicht atomare Momentaufnahmen; Sampling-Childs können den Aufruf verlängern.

`@BlockingObjektTiefe = 'DEEP'` kann bei lockintensiven Systemen die Eigenlast
des Overview merklich erhöhen. Der Standardpfad bleibt dedupliziert und durch
`@MaxObjektAufloesungen` begrenzt.

### Bewertung und Gegenprobe

Prüfen Sie zuerst Modulstatus und Partialflags und vertiefen Sie danach nur auffällige Children. Eine Korrelation ist möglich, wenn dieselbe Session, Datenbank oder Datei in mehreren Children erscheint.

### Typische Fehlinterpretation

Ein unauffälliger Overview beweist nicht, dass zwischen Childaufrufen kein kurzer Vorfall auftrat. Resultsets dürfen nicht so behandelt werden, als stammten sie aus einer gemeinsamen Transaktion.

### Folgeanalyse

Führen Sie das betroffene Childmodul mit engeren Filtern erneut aus.

## Primärquellen

- [Dynamic Management Views](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/system-dynamic-management-views?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../02_Current_State.md#10-monitorusp_currentoverview)
