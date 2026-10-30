# [monitor].[USP_CurrentRequests]

**Bereich:** Current State<br>
**Zweck:** Ordnet aktuell laufende Requests nach Laufzeit, CPU, I/O, Wait, Blocking, Memory Grant und Ausführungskontext ein.<br>`@Hilfe=1` erläutert den vollständigen Parametervertrag und zeigt kopierbare CONSOLE-, TABLE- und JSON-Aufrufe.<br>
**Beobachtungsart:** flüchtige Instanz-Momentaufnahme<br>
**Kostenklasse:** `LOW` bis `MEDIUM`

## Entscheidungsfrage und Einsatz

Diese Auswertung beantwortet: **Welche Requests sind genau jetzt aktiv, worin ist ihre bisherige Laufzeit gebunden und welche nächste Analyse ist dafür sinnvoll?** Sie ist der Einstieg bei einem akuten Hänger, plötzlich hoher CPU, sichtbarem Blocking, wartenden Memory Grants oder einer einzelnen unerwartet langen Ausführung.

Das Ergebnis soll noch keine Änderung auslösen. Es trennt zunächst vier Arbeitsrichtungen:

- überwiegend CPU und viele Reads → Query-/Plan- und Datenmengenkontext prüfen,
- überwiegend Warten mit Blocker → Blockingkette und offene Transaktion prüfen,
- wartender oder übergroßer Grant → Memory-Grant- und Kardinalitätsevidenz prüfen,
- kurze, erwartete Arbeit ohne Konkurrenzwirkung → möglicherweise kein Problem.

## Nicht beantwortete Fragen

Die Procedure zeigt keine beendeten Requests und keine verlässliche Historie. Ein Request, der zwischen zwei Aufrufen startet und endet, bleibt unsichtbar. Sie beweist weder die Root Cause eines Waits noch die Qualität eines Ausführungsplans, die Geschäftsauswirkung oder das übliche Lastniveau.

`BlockingSessionId` zeigt den unmittelbaren Blocker, nicht zwingend den Root Blocker. `CurrentStatement`, `BatchText`, Handles und Query Hashes liefern Korrelationsschlüssel, aber keinen Planinhalt. Für Trends oder bereits abgeschlossene Ausführungen sind Query Store, Extended Events oder eine geplante Stichprobe geeigneter.

## Sicherer Einstieg

`@MitSqlText`, `@GesamtenSqlTextEinbeziehen` und `@InputBufferEinbeziehen`
können SQL-Literale, Modulkontext und Clientaufrufe offenlegen. Der folgende
erste Aufruf deaktiviert diese Textpfade. Vor einer Erweiterung oder einem
Export sind Empfänger und Aufbewahrung gemäß dem
[Datenschutzvertrag](../../Architecture/Runtime_Data_Privacy.md) festzulegen;
`@MaxSqlTextZeichen` ist eine Transfergrenze und keine Anonymisierung.

Der erste Lauf reduziert Text-, Modul- und Input-Buffer-Arbeit und begrenzt die Ergebnismenge:

```sql
EXEC [monitor].[USP_CurrentRequests]
      @MaxZeilen = 50,
      @MitSqlText = 0,
      @ModulInfoEinbeziehen = 0,
      @InputBufferEinbeziehen = 0,
      @ResultSetArt = 'CONSOLE';
```

Erst danach einen auffälligen Request gezielt mit Textkontext nachlesen. Die Variable ist ausdrücklich synthetisch:

```sql
DECLARE @ExampleSessionId smallint = 57;
DECLARE @ExampleSessionIds nvarchar(max) = CONVERT(nvarchar(10), @ExampleSessionId);

EXEC [monitor].[USP_CurrentRequests]
      @SessionIds = @ExampleSessionIds,
      @MitSqlText = 1,
      @GesamtenSqlTextEinbeziehen = 0,
      @InputBufferEinbeziehen = 0,
      @ModulInfoEinbeziehen = 1,
      @MaxSqlTextZeichen = 4000,
      @ResultSetArt = 'RAW';
```

SQL-Text, Login, Host, Programm, Clientadresse und Input Buffer können in einer realen Laufzeitumgebung schutzbedürftige Inhalte enthalten. Zeigen Sie Ergebnisse nur im erforderlichen Umfang an und exportieren oder übermitteln Sie diese nicht ungeprüft.

Object-Explorer-, Copilot- und SQL-Prompt-Hintergrundrequests sind
standardmäßig ausgeblendet. Für eine bewusste Vollansicht gilt:

```sql
EXEC [monitor].[USP_CurrentRequests]
      @ToolHintergrundabfragenEinbeziehen = 1,
      @ResultSetArt = 'CONSOLE';
```

Die [LIKE-Regeln und ihre Grenzen](../../Architecture/Tool_Background_Query_Filtering.md)
sind zentral dokumentiert. Die clientseitige Kennzeichnung ist keine
Sicherheitsidentität.


## Parametervertrag

Die folgenden Verträge beschreiben den normalen Ausführungspfad. Mit `@Hilfe=1` kehrt die Procedure vor der TABLE-Zielvorbereitung und regulären fachlichen Parameterprüfung zurück. Bereits davor weist sie jedoch eine nichtleere `@ResultTablesJson`-Zuordnung außerhalb von TABLE mit Fehler 51011 zurück. `@Json` wird zuvor auf NULL gesetzt. Die Werte und Grenzen gelten je Parameter, einschließlich der ausdrücklich genannten NULL-Fälle.

| Parameter | Typ, Default, Eingabeform und Wirkung |
|---|---|
| `@SessionIds` | Typ nvarchar(max); Default NULL. Zulässig ist eine Liste ganzzahliger IDs 1 bis 32767. Pipe, Komma und Semikolon dürfen gemischt werden; Komma/Semikolon werden vor Pipe-Aufteilung überall, auch in Klammern, zu Trennern. Äußere Elementleerzeichen werden getrimmt, Duplikate zusammengeführt; Klammerquotierung macht keine gültige Zahl. NULL deaktiviert den Filter; ausgelassen nutzt NULL. Leerstring ist EMPTY_LIST; leere/ungültige Elemente, Nichtzahl oder Bereichsverletzung ergeben INVALID_PARAMETER. Wirkung: Beschränkt auf die genannten Session-IDs. |
| `@EigeneSessionsModus` | Typ varchar(16); Default ALLE. Geschlossene Menge nach äußerem Trim und Großschreibung: ALLE lässt alle Original-Logins zu; NUR behält Sessions mit Original-Login gleich ORIGINAL_LOGIN(); AUSSCHLIESSEN entfernt diese. NULL wird ALLE; ausgelassen nutzt ALLE. Leer oder unbekannter Wert ist INVALID_PARAMETER. Wirkung: Filtert nach ORIGINAL_LOGIN(), nicht nach effektivem Login. |
| `@AktuelleSessionEinbeziehen` | Typ bit; Default 0. SQL-konvertierter Schalter: numerisch 0 bleibt 0, numerischer Wert ungleich 0 wird 1. NULL wird in der tatsächlichen Bedingung wie 0 behandelt; ausgelassen nutzt 0. Wirkung: 1 erlaubt die aufrufende Session @@SPID, 0/NULL schließt sie aus. |
| `@SystemSessionsEinbeziehen` | Typ bit; Default 0. Numerischer 0/1-Schalter; numerischer Wert ungleich 0 wird vor Eintritt zu 1 konvertiert. NULL wirkt in der Filterbedingung wie 0; ausgelassen nutzt 0. Wirkung: 1 nimmt Nicht-User-Sessions auf; 0/NULL beschränkt auf is_user_process=1. |
| `@ToolHintergrundabfragenEinbeziehen` | Typ bit; Default 0. Numerischer Schalter, Wert ungleich 0 wird zu 1 konvertiert. NULL ist INVALID_PARAMETER; ausgelassen nutzt 0. Wirkung: 1 nimmt erkannte Object-Explorer-, Copilot- und SQL-Prompt-Hintergrundrequests auf, 0 blendet sie aus. Die metadatengetriebene LIKE-Erkennung ist eine Heuristik und keine Sicherheitsidentität. |
| `@NurBlockierte` | Typ bit; Default 0. Numerischer Schalter nach SQL-bit-Konvertierung: 0 deaktiviert den Filter, 1 behält Requests mit blocking_session_id ungleich 0. NULL ist kein Parameterfehler und deaktiviert den Filter nicht: passende blockierte Requests bleiben erhalten, nicht passende werden wegen der dreistelligen SQL-Logik verworfen. Auslassen nutzt 0; numerische Werte ungleich 0 werden zu 1 konvertiert. |
| `@NurMitWait` | Typ bit; Default 0. 0 deaktiviert den Filter; 1 behält Requests mit Request-Wait (wait_type IS NOT NULL) oder mindestens einem Waiting Task derselben Session. Bei mehreren gleichzeitigen Requests dieser Session kann der Task zu einem anderen Request gehören. NULL ist kein Parameterfehler und wirkt hinsichtlich der behaltenen Menge wie 1: Requests, die mindestens eine der beiden Bedingungen erfüllen, bleiben erhalten, nicht passende werden verworfen. Auslassen nutzt 0; numerische Werte ungleich 0 werden vor Eintritt zu 1 konvertiert. |
| `@MinLaufzeitSekunden` | Typ int; Default NULL. Nichtnegative ganze Sekunden von 0 bis 2147483647; vor Multiplikation mit 1000 wird nach bigint konvertiert. NULL deaktiviert den Mindestdauerfilter; ausgelassen nutzt NULL. Negative Werte sind INVALID_PARAMETER; leer ist keine int-Eingabe. Wirkung: Mindestdauer seit Requeststart. |
| `@MinCpuMs` | Typ bigint; Default NULL. Nichtnegative ganzzahlige Millisekunden von 0 bis 9223372036854775807. NULL deaktiviert den Filter; ausgelassen nutzt NULL. Negative Werte sind INVALID_PARAMETER; leer ist keine bigint-Eingabe. Wirkung: Behält Requests ab dieser kumulierten CPU-Zeit. |
| `@MinLogicalReads` | Typ bigint; Default NULL. Nichtnegative ganze Logical Reads von 0 bis 9223372036854775807. NULL deaktiviert den Filter; ausgelassen nutzt NULL. Negative Werte sind INVALID_PARAMETER; leer ist keine bigint-Eingabe. Wirkung: Behält Requests ab diesem kumulierten Logical-Read-Wert. |
| `@LoginNames` | Typ nvarchar(max); Default NULL. Exakte Textliste, höchstens 128 Zeichen je entquotetem Wert. Pipe trennt nur außerhalb eckiger Klammern; ]] maskiert darin eine schließende Klammer. Elementränder werden getrimmt; vollständig geklammerte Werte entquotet. NULL deaktiviert; ausgelassen nutzt NULL. Leerstring, leeres/ungültiges Element, leeres entquotetes Ergebnis, fehlerhafte Klammerung oder Überlänge ergibt INVALID_PARAMETER. Wirkung: Case-sensitive Gleichheit unter SQL_Latin1_General_CP1_CS_AS; Duplikate werden zusammengeführt. Ungültig in Kombination mit nicht-NULL @LoginNamePattern. |
| `@LoginNamePattern` | Typ nvarchar(4000); Default NULL. Einzelpattern: außen trimmen, Präfix like:, regex: oder regexi: case-insensitiv erkennen; Rest nicht erneut trimmen. Unpräfixiert und like: verwenden SQL-LIKE-Syntax unverändert (%, _ und [] sind Wildcards; keine Wildcards werden ergänzt). regex: ist case-sensitive (Flag c), regexi: case-insensitive (Flag i). NULL deaktiviert; ausgelassen nutzt NULL. Leerstring/leeres Präfix ergibt INVALID_PARAMETER. Wirkung: Filtert Login; ungültig bei nicht-NULL @LoginNames. Regex erfordert SQL Server 2025 und Compatibility Level 170; Engine behandelt Regexsyntax. |
| `@HostNames` | Typ nvarchar(max); Default NULL. Exakte Textliste, höchstens 128 Zeichen je entquotetem Wert; Pipe trennt nur außerhalb eckiger Klammern, ]] maskiert ] innerhalb; Elementränder getrimmt, geklammerte Werte entquotet. NULL deaktiviert; ausgelassen nutzt NULL. Leerstring, leeres/ungültiges Element, falsche Klammerung, leeres Ergebnis oder Überlänge ergibt INVALID_PARAMETER. Wirkung: Case-sensitive Gleichheit zu HostName; Duplikate zusammengeführt. Ungültig mit nicht-NULL @HostNamePattern. |
| `@HostNamePattern` | Typ nvarchar(4000); Default NULL. Außen trimmen; like:, regex:, regexi: ohne Beachtung der Großschreibung erkennen; Rest nicht erneut trimmen. Unpräfixiert/like: nutzt unveränderte SQL-LIKE-Wildcards %, _ und [], ohne automatische Wildcards; regex: Flag c, regexi: Flag i. NULL deaktiviert; ausgelassen nutzt NULL. Leerstring/leeres Präfix ungültig. Wirkung: Filtert HostName; ungültig mit nicht-NULL @HostNames. Regex nur SQL Server 2025/Compatibility Level 170. |
| `@ProgramNames` | Typ nvarchar(max); Default NULL. Exakte Textliste, höchstens 128 Zeichen je entquotetem Wert; Pipe nur außerhalb eckiger Klammern, ]] maskiert ] darin; Trim und Entquotung geklammerter Werte. NULL deaktiviert; ausgelassen nutzt NULL. Leere/ungültige Elemente, falsche Klammerung, leeres Ergebnis oder Überlänge ergibt INVALID_PARAMETER. Wirkung: Case-sensitive Gleichheit zu ProgramName; Duplikate zusammengeführt. Ungültig mit nicht-NULL @ProgramNamePattern. |
| `@ProgramNamePattern` | Typ nvarchar(4000); Default NULL. Außen trimmen; Präfix like:, regex:, regexi: case-insensitiv erkennen; Rest nicht erneut trimmen. Unpräfixiert/like: nutzt unveränderte SQL-LIKE-Wildcards %, _ und [], ohne Wildcardergänzung; regex: Flag c, regexi: Flag i. NULL deaktiviert; ausgelassen nutzt NULL. Leerstring/leeres Präfix ungültig. Wirkung: Filtert ProgramName; ungültig mit nicht-NULL @ProgramNames. Regex nur SQL Server 2025/CL170. |
| `@DatabaseNames` | Typ nvarchar(max); Default NULL. Bracket-aware Pipe-Liste einteiliger SQL-Namen nach PARSENAME; &#124; trennt nur außerhalb [...], ]] maskiert ]; Elementränder getrimmt; Name maximal 128 Zeichen. NULL deaktiviert; ausgelassen nutzt NULL. Leerstring/leeres Element, fehlerhafte Klammerung, ungültiger oder mehrteiliger Name und Überlänge ergeben INVALID_PARAMETER. Wirkung: Case-sensitive Gleichheit zu Datenbankname. Ungültig mit nicht-NULL @DatabaseNamePattern. |
| `@DatabaseNamePattern` | Typ nvarchar(4000); Default NULL. Außen trimmen; Präfix like:, regex:, regexi: case-insensitiv erkennen; Rest nicht erneut trimmen. Unpräfixiert/like: nutzt unveränderte SQL-LIKE-Wildcards %, _ und [], keine Ergänzung; regex: Flag c, regexi: Flag i. NULL deaktiviert; ausgelassen nutzt NULL. Leerstring/leeres Präfix ungültig. Wirkung: Filtert Datenbanknamen; ungültig mit nicht-NULL @DatabaseNames. Regex nur SQL Server 2025/CL170. |
| `@HighImpactConfirmed` | Typ bit; Default 0. Numerischer SQL-bit-Schalter; numerischer Wert ungleich 0 wird 1. NULL und Auslassen ändern nichts. Der Procedurekörper liest den Parameter nicht; er bestätigt oder aktiviert keinen Zugriff und erteilt keine Berechtigung. Caller-Sicht und Serverrechte bleiben eigenständig; es gibt hier kein separates Gruppenautorisierungsargument. |
| `@TextPattern` | Typ nvarchar(4000); Default NULL. Einzelpattern mit denselben Außen-Trim- und Präfixregeln: like:, regex:, regexi: case-insensitiv; Rest nicht erneut trimmen. LIKE-Wildcards werden unverändert ohne Ergänzung angewendet; regex: Flag c, regexi: Flag i. NULL deaktiviert; ausgelassen nutzt NULL. Leerstring/leeres Präfix ist INVALID_PARAMETER. Wirkung: Durchsucht aktuelles Statement oder Batchtext; kann Text bei @MitSqlText=0 intern lesen. Regex nur SQL Server 2025/CL170. |
| `@MitSqlText` | Typ bit; Default 1. Numerischer Schalter; Wert ungleich 0 wird zu 1. NULL ist INVALID_PARAMETER; ausgelassen nutzt 1. Wirkung: 1 gibt das Statement anhand gültiger Request-Offsets aus; 0 unterdrückt diese Ausgabe. Patternfilter und Modulauflösung können SQL-Text unabhängig davon intern lesen. |
| `@GesamtenSqlTextEinbeziehen` | Typ bit; Default 0. Numerischer Schalter; Wert ungleich 0 wird zu 1. NULL ist INVALID_PARAMETER; ausgelassen nutzt 0. Wirkung: 1 gibt Batch-/Modultext zusätzlich aus; 0 unterdrückt dessen Ausgabe. TextPattern kann den Text trotzdem intern lesen. Es wird kein Showplan abgerufen. |
| `@InputBufferEinbeziehen` | Typ bit; Default 0. Numerischer Schalter; Wert ungleich 0 wird zu 1. NULL ist INVALID_PARAMETER; ausgelassen nutzt 0. Wirkung: 1 liest sys.dm_exec_input_buffer erst nach Kandidatenfiltern und Zeilenlimit für behaltene Requests. Der Clientbefehl ist nicht zwingend das aktuelle Statement. |
| `@ModulInfoEinbeziehen` | Typ bit; Default 1. Numerischer Schalter; Wert ungleich 0 wird zu 1. NULL ist INVALID_PARAMETER; ausgelassen nutzt 1. Wirkung: 1 löst Textdatenbank und Objekt über Systemkataloge auf; Berechtigungsfehler oder Timeout können PARTIAL_RESULT ergeben. Dies ruft keinen Plan ab und erteilt keine Rechte. |
| `@MaxSqlTextZeichen` | Typ int; Default 4000. Nichtnegative int-Zeichenanzahl je Statement, Batch und Input Buffer; 0 bedeutet ungekürzt. NULL/0 ungekürzt; ausgelassen 4000; negative Werte INVALID_PARAMETER. Begrenzt ausgegebenen Text, nicht interne Lesung und nicht Anonymisierung. |
| `@MaxZeilen` | Typ int; Default 500. Positive Limits 1 bis 2147483647. NULL oder 0 bedeutet unbegrenzt; ausgelassen 500; negative Werte INVALID_PARAMETER. Gilt nach Filterung und Sortierung für alle Ausgabearten, vor Modulauflösung und Input Buffer. HasMoreRows zeigt weitere Kandidaten. |
| `@Sortierung` | Typ varchar(32); Default RELEVANZ. Außen trimmen und großschreiben. Taxative Werte: RELEVANZ priorisiert blockierte Requests mit blocking_session_id ungleich 0 vor solchen mit wait_type IS NOT NULL vor den übrigen; dies identifiziert keinen Root-Blocker. CPU ordnet CpuMs absteigend; READS LogicalReads absteigend; DAUER ElapsedMs absteigend; SESSION nach SessionId, RequestId. NULL wird zu RELEVANZ; ausgelassen nutzt RELEVANZ. Leer oder unbekannter Wert ist INVALID_PARAMETER. In allen Modi sind SessionId und RequestId die Tie-Breaker. |
| `@ResultSetArt` | Typ varchar(16); Default CONSOLE. Außen trimmen und großschreiben. Taxative Werte: CONSOLE beschriftete Sicht; RAW Status und sieben Resultsets; TABLE ausschließlich explizit benannte Ziele; NONE keine fachlichen Resultsets. NULL wird leer und ist ungültig; ausgelassen CONSOLE; leer/unbekannt INVALID_PARAMETER. TABLE-Vorprüfung geschieht vor semantischer Parameterprüfung; JSON ist unabhängig schaltbar. |
| `@ResultTablesJson` | Typ nvarchar(max); Default NULL. Im normalen Ausführungspfad bei TABLE ein nichtleeres JSON-Objekt mit Schlüssel aus der exakten Menge requests (Requestzeilen), requestContext (Requestkontext), snapshotStatus (Status je Snapshotquelle), statements (Statementtexte und Evidenz), batches (Batchtexte und Evidenz), inputBuffers (Input-Buffer-Evidenz), warnings (Warnungen) und einem JSON-String als Name einer vorhandenen lokalen #Temp-Tabelle. Keine unbekannten/duplizierten Namen oder Ziele und keine globale ##Temp. Jedes Ziel muss leer und mit genau einer Seed-Spalte angelegt sein. NULL/leer/fehlende Zuordnung in TABLE ungültig. Außerhalb TABLE NULL/leer zulässig; nichtleer löst Fehler 51011 aus. Auslassen nutzt NULL. Nur benannte Ziele werden befüllt. Vorprüfung belegt keine Frische oder Herkunft; sie erfolgt vor semantischer Validierung. Die Ablehnung einer nichtleeren Zuordnung außerhalb TABLE erfolgt auch vor dem Hilfepfad. |
| `@JsonErzeugen` | Typ bit; Default 0. Numerischer Schalter, Wert ungleich 0 wird zu 1. NULL ist INVALID_PARAMETER; ausgelassen nutzt 0. Wirkung: 1 erzeugt unabhängig von ResultSetArt JSON Schema 4 mit meta, requests, requestContext, snapshotStatus, statements, batches, inputBuffers und warnings. |
| `@Json` | Typ nvarchar(max) OUTPUT; Default NULL. Wenn verwendet, muss EXEC an eine beschreibbare nvarchar(max)-Variable mit OUTPUT gebunden werden; kein Literal. Beim Procedureintritt wird der gebundene Wert auf NULL gesetzt. Ohne @JsonErzeugen=1 bleibt er NULL; Auslassen zulässig, sofern JSON nicht angefordert ist. Bei @JsonErzeugen=1 enthält er das Envelope. Resultset und JSON sind unabhängig. |
| `@PrintMeldungen` | Typ bit; Default 1. Numerischer Schalter, Wert ungleich 0 wird zu 1. NULL unterdrückt wie 0; ausgelassen nutzt 1. Bei Status ungleich AVAILABLE sendet 1 eine Severity-10-Meldung mit Status und Fehler/Hinweis; 0/NULL unterdrückt sie. |
| `@Hilfe` | Typ bit; Default 0. 1 druckt die Hilfe und kehrt vor TABLE-Zielvorbereitung, regulärer fachlicher Parameterprüfung und Quellenaufnahme zurück. Bereits davor wird eine nichtleere @ResultTablesJson-Zuordnung außerhalb TABLE mit 51011 abgelehnt, auch bei Hilfe=1. @Json wird zuvor auf NULL gesetzt. 0 oder NULL führt den normalen Pfad aus; ausgelassen nutzt 0. Numerische Werte ungleich 0 werden vor Eintritt zu 1 konvertiert. |
| `@ParentCurrentStateSnapshotId` | Typ uniqueidentifier; Default NULL. Einzelne GUID, ausschließlich für den internen Consumer USP_CurrentOverview, der sie während derselben laufenden Snapshotaufnahme erzeugt. NULL erzwingt eine frische Einzelaufnahme; ausgelassen nutzt NULL. Nicht-NULL muss einen Parent mit OwnerSessionId=@@SPID und ContractVersion=2 bezeichnen; fehlender/fremder Snapshot wird INVALID_PARENT_SNAPSHOT. Übernommene Quellzeitpunkte bleiben Parent-Zeitpunkte. |

## Snapshot-Verhalten

Der vollständige [Current-Request-Context-Vertrag](../../Architecture/Current_Request_Context_Contract.md)
dokumentiert Resultsets, Provenienz, Zeitsemantik und Nichtverfügbarkeitsstatus.

Ein direkter Aufruf liest Sessions, Requests, Connections, Waiting Tasks,
Memory Grants, Resource-Governor-Zuordnung, Tasks,
Scheduler, Transaktionen, TempDB-Verbrauch und angeforderte Textquellen frisch.
`@ParentCurrentStateSnapshotId` ist ausschließlich der interne
Consumervertrag von `USP_CurrentOverview`; Anwender sollen ihn nicht setzen.
Im Overview werden die gemeinsamen Primärquellen einmal materialisiert und
SQL-Handles vor dem Textzugriff dedupliziert. Input Buffer bleibt bewusst eine
Post-Candidate-Quelle: Er wird nur für die nach Filtern und Limit verbliebenen
Requests und nur bei `@InputBufferEinbeziehen = 1` gelesen. RAW und JSON weisen
Snapshot-ID, Quellzeitpunkte, Abschlusszeit, Zeilenzahl und Quellenstatus aus.

## Resultsets und Leserichtung

- `CONSOLE` liefert genau ein fachliches Resultset aus der materialisierten Requestmenge. Es eignet sich für die erste Sichtung.
- `RAW` liefert Modulstatus, das kompatible Legacy-Resultset `requests`, danach `requestContext`, `snapshotStatus`, `statements`, `batches`, `inputBuffers` und `warnings`.
- `TABLE` exportiert jeden dieser stabilen Namen gezielt über `@ResultTablesJson`; nicht benannte Ziele werden nicht geschrieben. Die sieben Schemata besitzen 93/73/11/19/15/13/6 Felder und zusammen 66 explizite Framework-Textcollations. `requests` enthält 93 Felder; RAW ergänzt zwölf Wait-Katalogfelder, JSON verwendet eine eigene 52-Feldprojektion. CONSOLE ergänzt der materialisierten 93-Feldmenge das Ergebnislabel.
- `@JsonErzeugen = 1` verwendet dieselben Materialisierungen und ergänzt das Schema 4 additiv um `requestContext` und `snapshotStatus`.

Gültige TABLE-Zuordnungen werden vor der semantischen Parameterprüfung vorbereitet. Auch eine anschließend abgelehnte Zeilen-, Text-, CPU- oder Sessionangabe erfüllt die angeforderten vollständigen Zielschema-Verträge. Request-, Kontext- und Textmengen bleiben leer; vorhandene Status- und Warnungsevidenz bleibt erhalten. Nicht angeforderte Ziele bleiben unberührt. Der Sekundenvergleich konvertiert vor der Multiplikation nach bigint; auch der größte gültige int-Sekundenwert verursacht dadurch keinen Multiplikationsüberlauf.

Eine Zeile in `requestContext` bündelt die zum Request korrelierbaren
Connection-, Wait-, Task-, Scheduler-, Transaktions-, Memory-, TempDB- und
Resource-Governor-Felder. `snapshotStatus` besitzt dagegen eine Zeile je
Quelle. `statements`, `batches` und `inputBuffers` erzeugen je behaltenem
Request eine Evidenzzeile, auch wenn der Text mit `NOT_COLLECTED`, `ENCRYPTED`,
`INVALID_OFFSETS`, `TEXT_UNAVAILABLE`, `TEXT_TRUNCATED` oder
`REQUEST_FINISHED` abgegrenzt werden muss.

## Eine Zeile bedeutet

Eine Zeile in `requests` entspricht der zum Lesezeitpunkt sichtbaren Kombination aus `SessionId` und `RequestId`. Sie ist kein Task und kein historischer Ausführungsdatensatz. Ein paralleler Request kann mehrere Tasks und gleichzeitig unterschiedliche Task-Waits besitzen, bleibt aber eine Requestzeile.

Die Zähler `ElapsedMs`, `CpuMs`, `LogicalReads`, `Reads`, `Writes` und `RowCount` gelten für die bisherige Lebensdauer dieses Requests. Sie sind keine Rate pro Sekunde. `WaitTimeMs` beschreibt den aktuell auf `sys.dm_exec_requests` sichtbaren Request-Wait; `WaitingTaskCount`, `MaxTaskWaitMs` und `TaskWaitTypes` werden zusätzlich aus Waiting Tasks für die Session aggregiert. Bei mehreren gleichzeitigen Requests derselben Session, etwa durch MARS, ist diese Sessionaggregation nicht exklusiv einem einzelnen Request zuzurechnen.

## So lesen

1. **Vollständigkeit:** Prüfen Sie in `RAW` den Status, die partielle Sicht und das Zeilenlimit. Ohne vollständige Server-State-Berechtigung kann die Engine nur eingeschränkte Sessions zeigen.
2. **Identität und Scope:** Bestimmen Sie `SessionId`, `RequestId`, Datenbank, Command und Startzeit. Die aktuelle eigene Session, System-Sessions und erkannte Tool-Hintergrundrequests sind standardmäßig ausgeschlossen. Prüfen Sie bei einem Opt-in den Regelcode und die Konfidenz.
3. **Zeitaufteilung:** Vergleichen Sie `ElapsedMs` mit `CpuMs`. CPU ist verbrauchte Rechenzeit, Elapsed ist verstrichene Wanduhrzeit. Die Differenz ist nicht automatisch ein einzelner Wait, sondern kann verschiedene Warte- und Runnable-Phasen enthalten.
4. **Arbeit:** Berücksichtigen Sie `LogicalReads`, physische `Reads`, `Writes` und `RowCount` gemeinsam. Viele Logical Reads zeigen Seitenzugriffe im Buffer Pool, nicht automatisch langsames Storage. Bei parallelen Row-Mode-Requests weist Microsoft darauf hin, dass bestimmte Zähler in `sys.dm_exec_requests` nur am Coordinator sichtbar und dort nicht für alle Worker fortgeschrieben werden; sie sind dann keine vollständige Tasksumme.
5. **Warten und Blocking:** Bewerten Sie `WaitType`, `WaitTimeMs`, `TaskWaitTypes`, `BlockingSessionId` und `WaitResource` gemeinsam. Der Wait-Katalog liefert eine Einordnung, keine Root-Cause-Garantie.
6. **Memory und Parallelität:** Vergleichen Sie den angeforderten, gewährten und verwendeten Grant sowie `Dop` und `ParallelWorkerCount`. `NULL` kann bedeuten, dass kein Query-Execution-Memory-Grant existiert; 0 ist ein tatsächlich gelieferter Zahlenwert.
7. **Text und Modul:** Berücksichtigen Sie den aktiven Statementausschnitt vor dem Batchtext. Prüfen Sie `CurrentStatementIsTruncated`, Offsetgültigkeit und Verschlüsselung, bevor Sie aus fehlendem oder abgeschnittenem Text Schlussfolgerungen ziehen.

## Warum kann das problematisch sein?

Ein Request mit hoher Elapsed-Zeit und sehr wenig CPU kann Durchsatz oder Antwortzeit beeinträchtigen, wenn er auf einen Lock, I/O, einen Grant oder Schedulerzeit wartet. Ein Blocker kann weitere Sessions kaskadenartig zurückhalten. Hohe CPU zusammen mit hohen Logical Reads kann Konkurrenz um Scheduler und Buffer Pool erzeugen. Ein wartender Memory Grant kann eine Queue aufbauen, obwohl der Request selbst noch kaum CPU verbraucht hat.

Die Auswirkung entsteht aber nicht aus dem Einzelwert allein. Entscheidend sind Parallelität, Zahl betroffener Sessions, Dauer, SLA und ob die Arbeit erwartet ist. Auch die Diagnoseabfrage selbst aggregiert Waiting Tasks, sortiert Kandidaten und kann SQL-Text materialisieren; bei sehr vielen aktiven Requests ist sie nicht kostenlos.

## Wann ist es kein Problem?

Hohe CPU kann bei einer erwarteten, kurzen analytischen Abfrage produktive Arbeit sein. Viele Logical Reads können für einen kontrollierten Scan mit passender Laufzeit und ohne Konkurrenz akzeptabel sein. Ein kurzer Lock-Wait ist im normalen Transaktionsbetrieb üblich. Ein großer gewährter Grant ist nicht automatisch schädlich, wenn genügend Speicher verfügbar ist, keine Queue besteht und die tatsächliche Nutzung plausibel ist.

Ebenso ist `PercentComplete = NULL` kein Fehler: SQL Server liefert Fortschritt nur für bestimmte Commands. Ein fehlender Blocker bei einem Wait ist nicht widersprüchlich; viele Waitarten besitzen keinen Sessionblocker.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall `ExampleBlockedRequest`:** `ElapsedMs = 180000`, `CpuMs = 900`, `WaitType = LCK_M_X`, `WaitTimeMs = 176000` und `BlockingSessionId = 57`. Beobachtung: Fast die gesamte Wanduhrzeit wurde nicht als CPU verbraucht, und aktuell ist ein inkompatibler Lock sichtbar. Hypothese: Blocking dominiert die Antwortzeit. Gegenprobe: Prüfen Sie mit `USP_CurrentBlocking` die vollständige Kette und mit `USP_CurrentTransactions` Alter und Logwirkung der Root-Transaktion. Beenden Sie noch keine Session.

**Ähnlich auffällig, aber nicht automatisch problematisch `ExampleExpectedAnalytics`:** `ElapsedMs = 180000`, `CpuMs = 162000`, hohe Logical Reads, kein Wait und kein Blocker. Das ist CPU-/datenintensive Arbeit, aber noch kein Beweis für einen schlechten Plan. Erwartete Ausführung, DOP, gleichzeitige Konkurrenz, Query-Store-Vergleich und Planoperatoren entscheiden über die Bewertung.

**Nicht entscheidbarer Grantfall `ExampleGrant`:** `RequestedMemoryMb = 2048`, `GrantedMemoryMb = 2048`, `UsedMemoryMb = 180`. Die Differenz kann auf eine Überschätzung hinweisen, beweist sie aber nicht aus einem Snapshot. Wiederholbarkeit, Spillhinweise, Kardinalitätsschätzungen und konkurrierende Grants sind die Gegenprobe.

## Leere oder partielle Ausgabe

Keine Requestzeile bedeutet nur: Zum Snapshot war nach allen Filtern kein sichtbarer Request übrig. Mögliche Erklärungen sind ein tatsächlich ruhiger Moment, ein bereits beendeter Request, Ausschluss der eigenen oder von System-Sessions, ein zu enger Zeit-/Text-/Namensfilter, ein Zeilenlimit oder eingeschränkte Berechtigungen.

`AVAILABLE_LIMITED` weist auf eingeschränkte Server-Sicht hin. `PARTIAL_RESULT` kann entstehen, wenn Requests gelesen wurden, aber eine optionale Modulauflösung in einer Datenbank fehlschlug. Fehlender SQL-Text kann außerdem durch deaktivierte Textoptionen, ein verschlüsseltes Modul, ein nicht mehr gültiges Handle oder fehlenden Textkontext entstehen. `HasMoreRows = 1` bedeutet, dass der gewählte Ergebnis-Scope gekürzt wurde.

Ein zweiter Aufruf kann eine andere Menge liefern, ohne dass der erste falsch war: Die beteiligten DMVs werden nacheinander gelesen, während Requests und Tasks ihren Zustand ändern.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | `LOW` bis `MEDIUM`; kein physischer Benutzertabellenscan, aber variable Live-DMV-, Text-, Aggregations- und Sortierarbeit |
| Standardpfad | Der oben dokumentierte Lauf mit 50 Zeilen ohne SQL-Text, Modulauflösung und Input Buffer ist `LOW`. |
| Teuerster Pfad | Unbegrenzte Ausgabe mit vielen aktiven Requests, mehreren Regexfiltern, vollständigem Batchtext, Input Buffers, datenbankübergreifender Modulauflösung und JSON-Erzeugung ist `MEDIUM`. |
| Haupttreiber | Zahl aktiver Requests und Waiting Tasks, Textlänge, Anzahl aufzulösender Moduldatenbanken, Regexprüfung, Sortierung und Ausgabebreite |
| Skalierung | CPU und Speicher wachsen mit Aggregation/Sortierung; Metadatenzugriffe mit Moduldatenbanken; Transfer und Clientspeicher mit Text, JSON und Zeilenzahl. |
| Ressourcen | primär CPU, Arbeitsspeicher/Memory Grant der Diagnose, Metadatenzugriffe und Ergebnistransfer; nur temporäre eigene Datenstrukturen |
| Begrenzungswirkung | Ohne Regex materialisiert die Procedure höchstens `@MaxZeilen + 1` sortierte Kandidaten. Das garantiert wegen Filterung, Waiting-Task-Aggregation und Sortierung keinen entsprechend kleinen DMV-Quellzugriff. Bei Regex werden zunächst alle Kandidaten materialisiert und erst danach gelöscht und gekürzt. |
| Locking und Nebenwirkungen | Eigene lokale Temp-Tabellen werden in drei DDL-Blöcken mit `LOCK_TIMEOUT 1000` angelegt. Quelllesungen und die Prüfung fremder Zieltabellen bleiben bei `LOCK_TIMEOUT 0`; DMV-/Kataloglesungen verwenden überwiegend `NOLOCK`. Eine anhaltende TempDB-Metadatenkollision kann weiterhin einen Timeout auslösen. Es werden keine Benutzerdaten geändert. Ausgabe kann jedoch schutzbedürftigen Laufzeittext enthalten. |
| Schutzmechanismus | endliches Defaultlimit, Ausschluss der eigenen und von System-Sessions sowie abschaltbare Textpfade; kein zusätzlicher High-Impact-Gate-Pfad in dieser Procedure |
| Sicherer Einsatz | erst kleine CONSOLE-Sicht ohne Texte, danach einzelne synthetisch identifizierte Session in RAW vertiefen; unlimitierte Text-/Regexläufe auf stark belasteten Instanzen vermeiden |
| Aussagegrenze | Snapshot ist nicht atomar oder historisch; Limit und Filter können relevante Requests ausblenden; Session-Waitaggregation kann bei mehreren Requests breiter als die Requestzeile sein. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Was führt SQL Server im Erfassungsmoment aus, worin wurde bisher Zeit und Arbeit investiert, und welche unabhängige Evidenz soll als Nächstes erhoben werden?

### Technischer Hintergrund

`sys.dm_exec_requests` liefert den Requestkern: Status, Command, bisherige Zeit-/I/O-Zähler, aktuellen Wait, Blocker, Handles und Statementoffsets. Sessions und Connections ergänzen Herkunft und Verbindung. Waiting Tasks verdichten das Taskbild, Query Memory Grants den Workspace-Memory-Zustand, Resource Governor die Workloadgruppe. `sys.dm_exec_sql_text` und `TVF_StatementText` trennen den aktiven Statementausschnitt vom gesamten Batch.

Die Quellen werden nicht in einem transaktional konsistenten Snapshot eingefroren. Der Request kann zwischen Kernlesung, optionaler Modulauflösung und Input-Buffer-Ergänzung weiterlaufen oder enden. Darum sind kleine Abweichungen zwischen Status, Wait und Taskbild erwartbar.

### Datenkette

1. Listen- und Patternfilter werden validiert; Regex ist erst ab dem dafür vorgesehenen SQL-Server-/Compatibility-Level verfügbar.
2. `sys.dm_exec_requests` wird mit `sys.dm_exec_sessions`, `sys.dm_exec_connections` und `sys.databases` verbunden.
3. Pro sichtbarer Session werden Waiting Tasks aggregiert; Memory Grants und Resource-Governor-Zuordnung werden ergänzt.
4. Nur wenn Text oder Modulkontext benötigt wird, werden SQL-Text und Statementoffsets aufgelöst.
5. Exakte und LIKE-Filter wirken in der Quellabfrage. Regexfilter wirken nach der Materialisierung in der Temp-Tabelle.
6. Das Ergebnis wird nach Relevanz, CPU, Reads oder Dauer sortiert und auf die gewünschte Zeilenzahl gekürzt.
7. Optional folgen je betroffener Datenbank die Modulauflösung und je verbliebener Request der Input Buffer; Texte werden erst danach auf `@MaxSqlTextZeichen` gekürzt.
8. Ausgabe erfolgt als CONSOLE, RAW, TABLE und/oder JSON.

### Source Select

Das zentrale Select verbindet zuvor materialisierte Requests mit Session und Connection. SQL-Text wird bei Bedarf vor den Consumerfiltern für deduplizierte Handles gelesen; Modulauflösung und Input Buffer folgen erst nach dem Ergebnislimit:

```sql
SELECT
      [r].[session_id]
    , [r].[request_id]
    , [r].[status]
    , [r].[command]
    , [r].[total_elapsed_time]
    , [r].[cpu_time]
    , [r].[logical_reads]
    , [r].[wait_type]
    , [r].[blocking_session_id]
    , [s].[program_name]
    , [c].[client_net_address]
FROM [#CurrentRequests_SourceRequests] AS [r]
JOIN [#CurrentRequests_SourceSessions] AS [s]
  ON [s].[session_id] = [r].[session_id]
LEFT JOIN [#CurrentRequests_SourceConnections] AS [c]
  ON [c].[session_id] = [r].[session_id]
WHERE [r].[session_id] <> @@SPID
  AND [s].[is_user_process] = 1
  AND (@MinLaufzeitSekunden IS NULL OR CONVERT(bigint, [r].[total_elapsed_time]) >= CONVERT(bigint, @MinLaufzeitSekunden) * 1000);
```

**Wichtig für die Eigenlast:** Exakte Session-, Datenbank- und Dauerfilter begrenzen die Consumerkandidaten, aber nicht die vorherige DMV-Materialisierung oder die SQL-Textlesung für deduplizierte Requesthandles. Modulauflösung, Input Buffer und die anschließende Unicodeprojektion betreffen nur die behaltene Menge. Regex wirkt nach der Kandidatenmaterialisierung; zusätzliche Join-, Filter-, Sortier- und Statementextraktionsarbeit ist dadurch nicht auf N+1 begrenzt.

### Zeit- und Scope-Modell

Die Auswertung liefert eine instanzweite Live-Momentaufnahme der sichtbaren aktiven Requests. Zähler beginnen mit dem jeweiligen Request; sie besitzen keinen gemeinsamen globalen Resetzeitpunkt. Session-IDs können nach dem Sessionende wiederverwendet werden. Führen Sie daher für spätere Korrelationen mindestens die Startzeit und `RequestId` mit. Das Ergebnis enthält standardmäßig User-Requests außer der aufrufenden Session; Filter verengen diesen Scope.

### Bewertung und Gegenprobe

Elapsed, CPU, Reads/Writes, aktueller Wait, Task-Waits, Blocking, Grant und DOP bilden zusammen eine Hypothese. Blocking wird mit Blockingkette/Transaktion bestätigt; CPU/Reads mit Query Store und Plan; Grants mit `USP_CurrentMemoryGrants`; I/O-Vermutungen mit Datei- und Betriebssystemevidenz. Eine zweite Quelle sollte einen anderen Messmechanismus besitzen und nicht nur dieselbe DMV anders sortieren.

### Typische Fehlinterpretation

`ElapsedMs - CpuMs` ist keine exakt gemessene Waitzeit. `WaitType` ist ein Momentwert, der letzte oder parallele Phasen nicht vollständig beschreibt. Ein hoher kumulierter Read-Wert beweist keinen aktuellen Storageengpass; bei parallelem Row Mode können Requestzähler außerdem die Workerarbeit unvollständig repräsentieren. Batchtext ist nicht automatisch das aktive Statement. `NOLOCK` macht die nacheinander gelesenen DMVs nicht atomar.

### Folgeanalyse

Verwenden Sie abhängig vom Befund die folgenden Folgeanalysen:

- Blocking: `USP_CurrentBlocking` und `USP_CurrentTransactions`
- Memory Grant: `USP_CurrentMemoryGrants`
- CPU/Reads und Verlauf: `USP_QueryStats` oder Query Store, anschließend `USP_ShowplanAnalysis`
- Dateilatenz: `USP_CurrentIO`
- Wiederholt sehr kurzer Zustand: geplante XE- oder Stichprobenerfassung statt manuellem Polling

## Primärquellen

- [sys.dm_exec_requests](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-exec-requests-transact-sql?view=sql-server-ver17)
- [sys.dm_os_waiting_tasks](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-waiting-tasks-transact-sql?view=sql-server-ver17)
- [sys.dm_exec_query_memory_grants](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-exec-query-memory-grants-transact-sql?view=sql-server-ver17)
- [sys.dm_exec_sql_text](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sql-text-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../02_Current_State.md#2-monitorusp_currentrequests)
