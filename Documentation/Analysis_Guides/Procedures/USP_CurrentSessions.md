# [monitor].[USP_CurrentSessions]

**Bereich:** Current State<br>
**Zweck:** Inventarisiert aktuelle Sessions, Verbindungskontext, kumulative Aktivität und offene Transaktionen.<br>
**Beobachtungsart:** Snapshot + kumulative Sessionzähler<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Sessions sind verbunden, welchen Kontext besitzen sie und gibt es inaktive Sessions mit fortwirkendem Zustand?** Sie unterstützt die Entscheidung, ob das aktuelle Symptom im Erfassungsmoment sichtbar ist und welcher engere Live-, Verlaufs- oder Planpfad als Nächstes sinnvoll ist.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine lückenlose Historie und allein aus einem Snapshot weder Dauerhäufigkeit noch Root Cause oder zukünftige Entwicklung. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentSessions]
      @MitSqlText = 0,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Der Einstieg erhebt Session- und Requestmetadaten ohne SQL-Text. Grenzen Sie eine
auffällige Session anschließend über `@SessionIds` ein und ergänzen Sie Text nur für
diesen Kandidaten.

Erkannte Tool-Hintergrundsessions sind im Default ausgeblendet. Mit
`@ToolHintergrundabfragenEinbeziehen = 1` werden sie samt Regelcode, Kategorie,
Erkennungsart und Konfidenz sichtbar. Die Erkennung ist eine
[konfigurierbare Diagnoseheuristik](../../Architecture/Tool_Background_Query_Filtering.md),
kein Sicherheitsmerkmal.

Alle `Example*`-Werte im Aufruf sind synthetisch.

Der ausführliche Hilfetext lässt sich mit `EXEC [monitor].[USP_CurrentSessions] @Hilfe = 1;` ausgeben; der Hilfezweig kehrt vor der regulären fachlichen Parameterprüfung und dem Quellenzugriff zurück. Die beschriebenen Zuordnungsprüfungen laufen zuvor.

## Parametervertrag

Die folgenden Verträge beschreiben jeden Parameter einzeln. Vor der Hilfe werden nichtleere Zuordnungen außerhalb von TABLE und bei TABLE das Zielmapping geprüft. Ungültige Zuordnungen können deshalb auch bei `@Hilfe = 1` den Fehler 51011 auslösen.

| Parameter | Typ, Default, Eingabeform und Wirkung |
|---|---|
| `@SessionIds` | nvarchar(max); Default=NULL. NULL deaktiviert den Filter; ausgelassen ergibt NULL. Jeder nicht-NULL-Wert wird durch TVF_ParseBigintList geparst. Die Funktion ersetzt zuerst jedes Komma und Semikolon in Pipe-Zeichen, auch innerhalb eckiger Klammern; anschließend trennt Pipe außerhalb von [...] und ]] maskiert dort eine schließende Klammer. Äußere Leerzeichen je Segment werden getrimmt; ein einzelner leerer String ergibt EMPTY_LIST, Leerzeichen oder leere Segmente ergeben EMPTY_ITEM, fehlerhafte Klammern INVALID_BRACKET_SYNTAX und Rohsegmente über 4000 UTF-16-Codeeinheiten ITEM_TOO_LONG. Doppelte und ungültige Segmente bleiben im Helper erhalten; jedes gültige Zahlenfeld wird mit TRY_CONVERT(bigint) geparst. Klammern werden nicht entquotet, daher sind bracket-quotierte Zahlen keine gültigen IDs. Die Procedure verlangt für jede Zeile IsValid=1 und NumberValue von 1 bis 32767; sonst Status INVALID_PARAMETER. Gültige Duplikate werden anschließend gruppiert. Alle drei Trenner Pipe, Komma und Semikolon können gemischt verwendet werden. |
| `@EigeneSessionsModus` | varchar(16); Default='ALLE'. NULL wird durch COALESCE zu ALLE; ausgelassen ergibt ALLE. Nach LTRIM/RTRIM und UPPER sind exakt ALLE (kein OriginalLoginName-Filter), NUR (OriginalLoginName = ORIGINAL_LOGIN()) und AUSSCHLIESSEN (ISNULL(OriginalLoginName,'') &lt;&gt; ORIGINAL_LOGIN()) zulässig; leer oder jeder andere Wert ist INVALID_PARAMETER. Die Auswahl betrifft OriginalLoginName, nicht LoginName oder einen angenommenen Effektivlogin. Bei NULL auf der Zeile lässt AUSSCHLIESSEN die Zeile passieren, NUR nicht. |
| `@AktuelleSessionEinbeziehen` | bit; Default=0. 0 und ausgelassen schließen @@SPID aus; 1 nimmt die aufrufende Session in den direkten Aufruf auf. NULL besteht die Validierung, aber das Prädikat (@AktuelleSessionEinbeziehen=1 OR session_id&lt;&gt;@@SPID) ist dann UNKNOWN für die eigene Session und schließt sie aus; andere Sessions passieren. SQL-Konvertierung numerischer Eingaben: 0→0, jeder numerische Nichtnullwert→1. USP_CurrentOverview reicht diesen Parameter nicht weiter, daher bleibt dort der Childdefault wirksam. |
| `@SystemSessionsEinbeziehen` | bit; Default=0. 0 und ausgelassen lassen nur Zeilen mit is_user_process=1 passieren; 1 lässt sichtbare System- und User-Sessions passieren. NULL ist nicht gesondert ungültig und wegen (NULL=1 OR is_user_process=1) nur bei User-Sessions TRUE; Systemzeilen werden ausgeschlossen. Numerische Eingaben werden vor Eintritt zu bit konvertiert: 0→0, jeder Nichtnullwert→1. |
| `@ToolHintergrundabfragenEinbeziehen` | bit; Default=0. 0 und ausgelassen schließen Sessions aus, die TVF_ToolBackgroundQueryInfo anhand aktivierter ToolBackgroundQueryPattern-LIKE-Regeln als Tool-Hintergrundabfrage klassifiziert; 1 lässt sie passieren und gibt Klassifikationsfelder mit aus. NULL und nach bit-Konvertierung jeder Wert außer 0/1 führen ausdrücklich zu INVALID_PARAMETER; numerisches 0→0, numerischer Nichtnullwert→1 vor Eintritt. Die Erkennung ist eine Diagnoseheuristik, keine Berechtigungs- oder Sicherheitsgrenze. |
| `@InaktiveSessionsEinbeziehen` | bit; Default=1. 1 und ausgelassen lassen auch eine Session ohne Request und ohne offene Transaktion passieren. 0 schließt genau solche Zeilen aus; ein Request oder open_transaction_count&gt;0 genügt jeweils für Aufnahme. NULL ist nicht ausdrücklich ungültig: Das Prädikat (NULL=1 OR request.session_id IS NOT NULL OR open_transaction_count&gt;0) lässt bei UNKNOWN nur Zeilen mit Request oder offener Transaktion passieren. Numerische Werte werden vor Eintritt nach bit konvertiert, 0→0 und Nichtnull→1. |
| `@LoginNames` | nvarchar(max); Default=NULL. NULL deaktiviert den Filter; ausgelassen ergibt NULL. Ein nicht-NULL-Argument wird als bracket-aware Pipe-Liste von TVF_ParseStringList geparst; auch leerer String und nur Leerzeichen sind ungültig (EMPTY_LIST bzw. EMPTY_ITEM), ebenso leere Segmente, fehlerhafte Klammerstruktur oder Rohsegmente über 4000 UTF-16-Codeeinheiten. Äußere Segmentleerzeichen werden entfernt; Pipe trennt außerhalb von [...], innerhalb ist es Literaleingabe, ]] maskiert dort ]. Bei bracket-quotierten Werten entfernt der Parser die äußeren Klammern und entmaskiert ]]; anschließend sind leere Werte ungültig. Die Procedure beschränkt jeden StringValue auf höchstens 128 Zeichen, gruppiert gültige Duplikate und vergleicht unter SQL_Latin1_General_CP1_CS_AS. Exklusiv mit @LoginNamePattern, sobald beide Argumente nicht NULL sind. NULL LoginName passiert den exakten Vergleich nicht. |
| `@LoginNamePattern` | nvarchar(4000); Default=NULL. NULL deaktiviert das Pattern; ausgelassen ergibt NULL. TVF_ParsePattern trimmt äußere Leerzeichen des gesamten Eingangs, case-insensitiv erkennt und entfernt genau regexi:, regex: oder like:, und trimmt den verbleibenden Inhalt nicht erneut. Kein Präfix bedeutet LIKE; andere Prefixtexte sind ebenfalls unpräfixierter LIKE-Inhalt. LIKE und like: sind case-sensitive SQL-LIKE mit %, _ und SQL-LIKE-Klassen. regex: liefert case-sensitive Regex-Flag c; regexi: case-insensitive Flag i. Nur leeres Gesamteingabepattern oder leeres Präfixergebnis ist EMPTY_PATTERN/INVALID_PARAMETER; Leerzeichen unmittelbar nach einem Präfix bleiben Inhalt. Exklusiv mit @LoginNames bei beiden nicht-NULL. Regex setzt SQL Server 2025/Majorversion 17 und Compatibility Level mindestens 170 der Installationsdatenbank voraus, andernfalls UNAVAILABLE_FEATURE. LIKE/Regex-Filter lassen NULL LoginName nicht passieren. |
| `@HostNames` | nvarchar(max); Default=NULL. NULL deaktiviert; ausgelassen ergibt NULL. Sonst bracket-aware Pipe-Liste gemäß TVF_ParseStringList: Pipe trennt außerhalb eckiger Klammern, ]] maskiert innen ], äußere Elementleerzeichen werden entfernt und bracket-quotierte Werte werden entklammert sowie entmaskiert. Leere Gesamteingabe (EMPTY_LIST), reine Leerzeichen/leere Segmente (EMPTY_ITEM), leere entquotete Werte, fehlerhafte Klammern und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Die aufrufende Procedure lehnt Parsefehler und Stringwerte über 128 Zeichen mit INVALID_PARAMETER ab, gruppiert gültige Duplikate und vergleicht HostName case-sensitive unter SQL_Latin1_General_CP1_CS_AS. Exklusiv mit @HostNamePattern bei beiderseitig nicht-NULL Argumenten; NULL HostName erfüllt den Filter nicht. |
| `@HostNamePattern` | nvarchar(4000); Default=NULL. NULL deaktiviert; ausgelassen ergibt NULL. TVF_ParsePattern trimmt äußere Eingabezeichen, erkennt case-insensitiv nur regexi:, regex: oder like: und entfernt das Präfix, ohne den danach verbleibenden Inhalt erneut zu trimmen; kein oder sonstiges Präfix bedeutet LIKE. LIKE und like: verwenden case-sensitive SQL-LIKE-Semantik mit %, _ und Klassen in eckigen Klammern; regex: setzt Regex-Flag c, regexi: Flag i. EMPTY_PATTERN entsteht, wenn Gesamteingabe oder Präfixrest leer ist; Leerzeichen nach dem Präfix bleiben Musterinhalt. Exklusiv mit @HostNames bei beiderseits nicht-NULL Eingaben. Regex nur auf SQL Server 2025/Majorversion 17 und Compatibility Level &gt;=170 der Installationsdatenbank, sonst UNAVAILABLE_FEATURE. NULL HostName besteht den Filter nicht. |
| `@ProgramNames` | nvarchar(max); Default=NULL. NULL deaktiviert; ausgelassen ergibt NULL. Ein nicht-NULL-Wert ist eine bracket-aware Pipe-Liste des TVF_ParseStringList: Pipe außerhalb [...] trennt, innerhalb gehört es zum Wert, ]] maskiert eine schließende Klammer; äußere Elementleerzeichen werden getrimmt, bracket-quotierte Werte entklammert und entmaskiert. Leere Eingabe (EMPTY_LIST), Leerzeichen/leere Segmente (EMPTY_ITEM), leere entquotete Werte, fehlerhafte Klammerstruktur und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Die Procedure verlangt gültige Werte bis 128 Zeichen, fasst Duplikate zusammen und vergleicht case-sensitive mit SQL_Latin1_General_CP1_CS_AS. Exklusiv mit @ProgramNamePattern, wenn beide nicht NULL sind; NULL ProgramName ist kein Treffer. |
| `@ProgramNamePattern` | nvarchar(4000); Default=NULL. NULL/ausgelassen deaktiviert. Der Helper trimmt außen, erkennt ohne Beachtung der Schreibweise genau regexi:, regex: und like:, entfernt das Präfix und trimmt den Rest nicht erneut; ohne diese Präfixe gilt LIKE. LIKE ist case-sensitive SQL-LIKE mit %, _ und []-Klassen; regex: ist case-sensitive (Flag c), regexi: case-insensitive (Flag i). Ein leeres Gesamteingabepattern oder ein leeres Präfixresultat wird EMPTY_PATTERN und in der Procedure INVALID_PARAMETER; nach Präfix verbleibende Leerzeichen sind Inhalt. Exklusiv mit @ProgramNames, sobald beide Eingaben nicht NULL sind. Regex erfordert SQL Server 2025/Majorversion 17 plus Compatibility Level mindestens 170 der Installationsdatenbank; andernfalls UNAVAILABLE_FEATURE. NULL ProgramName wird nicht als Treffer behandelt. |
| `@DatabaseNames` | nvarchar(max); Default=NULL. NULL deaktiviert; ausgelassen ergibt NULL. Sonst bracket-aware Pipe-Liste über TVF_ParseSqlNameList und TVF_ParsePipeList: Pipe trennt außerhalb von [...], ]] maskiert innen ], äußere Segmentleerzeichen werden entfernt; gleiche Segmente bleiben im Parser erhalten. Leerer String ist EMPTY_LIST; Leerzeichen oder leere Segmente sind EMPTY_ITEM; über 4000 UTF-16-Codeeinheiten ITEM_TOO_LONG; fehlerhafte Klammern werden abgelehnt. Jede gültige Eingabe muss nach PARSENAME genau einen einteiligen Namen ergeben und höchstens 128 Zeichen haben; mehrteilige Namen, ungültige SQL-Namen und zu lange Werte führen in der Procedure zu INVALID_PARAMETER. Es wird nicht gegen Datenbankexistenz geprüft. Gültige Duplikate werden nach NameValue gruppiert und unter SQL_Latin1_General_CP1_CS_AS case-sensitive verglichen. Exklusiv mit @DatabaseNamePattern, wenn beide Argumente nicht NULL sind. NULL DatabaseName erfüllt die aktive Gleichheit nicht. |
| `@DatabaseNamePattern` | nvarchar(4000); Default=NULL. NULL oder ausgelassen deaktiviert; TVF_ParsePattern trimmt äußere Zeichen, erkennt case-insensitiv genau regexi:, regex: und like:, entfernt das Präfix und trimmt den Rest nicht erneut. Ohne/bei sonstigem Präfix wird SQL-LIKE verwendet. LIKE/like: ist case-sensitive und unterstützt %, _ und []-Klassen; regex: verwendet Flag c (case-sensitive), regexi: Flag i (case-insensitive). Leerer Gesamteingang oder leerer Präfixrest führt zu EMPTY_PATTERN und dann INVALID_PARAMETER; whitespace nach Präfix bleibt Inhalt. Exklusiv mit @DatabaseNames, sobald beide nicht NULL sind. Regex ist nur mit SQL Server 2025/Majorversion 17 und Compatibility Level &gt;=170 in der Installationsdatenbank verfügbar, sonst UNAVAILABLE_FEATURE. SQL-LIKE und Regex auf NULL DatabaseName lassen die Zeile nicht passieren. |
| `@HighImpactConfirmed` | bit; Default=0. Ausgelassen ist 0; im Procedure-Body wird der Parameter nicht ausgewertet, geprüft oder weitergereicht und er bestätigt/freigibt/ändert keine Ausführung. NULL, 0 und 1 haben daher hier keine Wirkung; SQL konvertiert numerische Eingaben vor Eintritt zu bit (0→0, Nichtnull→1). Dieses Objekt besitzt dafür kein High-Impact-Gate und keine zusätzliche Berechtigungsgruppe; die tatsächliche Quellensicht folgt den festgelegten DMV-Berechtigungen. |
| `@MitSqlText` | bit; Default=0. 0/ausgelassen überspringt sys.dm_exec_sql_text und lässt CurrentStatement sowie BatchText NULL; 1 löst deduplizierte, nicht-NULL Request-sql_handle und letzte Connection-most_recent_sql_handle vor Ergebnisfiltern und Zeilenlimit auf und projektiert verfügbare Texte. NULL ist nicht als ungültig abgefangen und wirkt im IF @MitSqlText=1-Pfad wie aus; numerisch 0→0, Nichtnull→1 vor Eintritt. Text kann bei direktem Aufruf auch von einer inaktiven Session über den letzten Connection-Handle stammen; im Parent-Snapshot wird Text nur aus dem Snapshot übernommen. |
| `@MaxSqlTextZeichen` | int; Default=2000 Zeichen je CurrentStatement und BatchText. NULL oder 0 ist unbegrenzt; ausgelassen nutzt 2000; negativ führt zu INVALID_PARAMETER. Der Writer zählt Unicodezeichen einschließlich abschließender Leerzeichen und projiziert erst für behaltene Ergebniszeilen. Bei positiver Grenze wird nur ein längerer Wert auf die Grenze gekürzt; SC-Collation zählt ein Surrogatpaar als ein Zeichen und trennt das Paar nicht. NULL-Text bleibt NULL. Originalzeichen und Bytes sowie Kürzungsflag werden ausgegeben und Kürzungen über den Warnhelper gemeldet. Diese Begrenzung anonymisiert nicht und reduziert weder vorgelagerte Textauflösung noch alle Quellenarbeit. |
| `@MaxZeilen` | int; Default=500 Sessionzeilen. NULL oder 0 hebt das Ausgabelimit auf; ausgelassen nutzt 500, negative Werte sind INVALID_PARAMETER. Bei positivem N wird ohne Regex früh höchstens N+1 Kandidatenzeilen materialisiert; bei aktivem Regex wird das frühe Limit aufgehoben und erst nach Regexfilterung die sortierte Ergebnismenge auf N gekürzt. hasMoreRows=1 wird gesetzt, wenn nach Kandidaten-/Regexfilterung mehr als N passende Zeilen vorliegen. Filter- und Quellenerhebung sowie optionale Textauflösung sind dadurch nicht allgemein auf N+1 begrenzt. Dieselbe begrenzte Menge speist die Ausgabeformen. |
| `@Sortierung` | varchar(32); Default='CPU'. NULL wird via COALESCE zu CPU; Eingabe wird mit LTRIM/RTRIM und UPPER normalisiert. Zulässig sind exakt CPU (Request-CPU, sonst Session-CPU, absteigend), READS (Request-logical_reads, sonst Session-logical_reads, absteigend), WRITES (Request-writes, sonst Session-writes, absteigend), LOGIN (login_time absteigend) und SESSION (session_id aufsteigend). Ungültiger normalisierter Wert ist INVALID_PARAMETER. Gleichstände werden bei Kandidatenauswahl nach Session-ID aufgelöst; RAW sortiert nach Schlüssel und Session-ID, JSON nach Session-ID, TABLE und CONSOLE-Helper geben keine Zeilenordnung zu. |
| `@ResultSetArt` | varchar(16); Default='CONSOLE'. NULL wird bei Normalisierung zu leer und ist ungültig; sonst LTRIM/RTRIM/UPPER und exakt CONSOLE, RAW, TABLE oder NONE. CONSOLE liefert Status und danach lesbare Sessionansicht über InternalEmitConsoleResult; RAW liefert Status mit 13 Feldern und Sessiondaten mit 51 Session- plus zehn Wait-Feldern; TABLE schreibt das benannte sessions-Ziel mit 51 Sessionfeldern, ohne Reihenfolgegarantie; NONE unterdrückt Resultsets. Ausgabeart verändert nicht die Fachmenge; JSON wird unabhängig davon nur mit @JsonErzeugen gesteuert. ResultSetArt=TABLE verlangt ein gültiges Zielmapping. |
| `@ResultTablesJson` | nvarchar(max); Default=NULL. Nur in normalisiertem ResultSetArt=TABLE ist ein gültiges Mapping erforderlich: ein nichtleeres JSON-Objekt mit exakt einem case-sensitiven Key sessions und einem nichtleeren JSON-Stringwert, zum Beispiel {"sessions":"#CurrentSessions"}. Der Wert muss eine bereits vorhandene lokale #Temp-Tabelle bezeichnen; ##-Tabellen, Namen über 116 Zeichen und das case-insensitive reservierte Präfix #Monitor sind unzulässig. Zielnamen dürfen nicht doppelt vorkommen; das Ziel muss leer sein und genau eine Seed-Spalte haben. Bei Nicht-TABLE ist NULL, leer oder ausschließlich gewöhnliche Leerzeichen U+0020, die LTRIM/RTRIM entfernt zulässig; eine nichtleere Map wirft 51011. Der Nicht-TABLE-Map-Guard läuft vor Hilfe und Parameterprüfung; TABLE-Preflight läuft ebenfalls vor Hilfe und validiert JSON-Objekt, Stringtyp, erlaubten Key, Eindeutigkeit, Zielname, Existenz, Leere und Seedspaltenform. Erfolgreiches Mapping garantiert keine Zeile oder Frische; der Writer passt das leere Seed-Ziel an das sessions-Ausgabeschema an. |
| `@JsonErzeugen` | bit; Default=0. 0/ausgelassen deaktiviert JSON; exakt 1 erzeugt unabhängig von ResultSetArt das Envelope in @Json. NULL wird nicht zurückgewiesen, ist aber nicht =1 und lässt den zuvor zu NULL gesetzten OUTPUT-Wert NULL. Numerische Werte werden vor Eintritt zu bit konvertiert (0→0, jeder Nichtnullwert→1). |
| `@Json` | nvarchar(max) OUTPUT; Default=NULL. Empfangsparameter zur Bindung einer aufruferseitigen Variable vom Typ nvarchar(max); im EXEC muss die Variable mit OUTPUT gebunden werden, damit der Caller den Rückgabewert empfängt. Der Procedure-Einstieg setzt den Wert stets auf NULL; wenn @JsonErzeugen=1 wird das Envelope geschrieben, sonst bleibt er NULL. Ausgelassene Empfangsbindung stellt keinen Callerwert bereit. |
| `@PrintMeldungen` | bit; Default=1. Bei 1 und Status ungleich AVAILABLE gibt die Procedure eine Severity-10-Warnmeldung mit NOWAIT aus; 0 unterdrückt diese Zusatzmeldung. Ausgelassen ergibt 1. NULL wird nicht gesondert validiert und erfüllt IF =1 nicht, daher keine Warnung; numerische Eingaben werden vor Eintritt zu bit konvertiert (0→0, Nichtnull→1). Resultsets und JSON bleiben davon unabhängig. |
| `@Hilfe` | bit; Default=0. Nur exakt 1 aktiviert PRINT-Hilfe und Rückkehr vor fachlicher Parameterprüfung und Datenquellenzugriff; ausgelassen und NULL führen in den normalen Pfad, numerische Werte werden vor Eintritt zu bit konvertiert. Vor dem Hilfezweig läuft jedoch der Nicht-TABLE-Guard: eine nichtleere nach LTRIM/RTRIM verbleibende ResultTablesJson-Eingabe bei anderer Ausgabeart wirft 51011. Bei ResultSetArt=TABLE läuft zuvor zusätzlich das Mapping-Preflight mit den Form-, Key-, Ziel- und Seedprüfungen; ungültige Zuordnung wirft 51011 statt Hilfe zu liefern. Der Procedure-Einstieg setzt @Json bereits vor den Guards auf NULL; nach erfolgreichem Preflight erzeugt Hilfe keine fachlichen Resultsets. |
| `@ParentCurrentStateSnapshotId` | uniqueidentifier; Default=NULL. NULL oder ausgelassen wählt direkte frische Quellenreads. Eine gesetzte GUID aktiviert den internen USP_CurrentOverview-Consumerpfad und muss in dessen lokalen Snapshottabellen zur aktuellen @@SPID-Session sowie ContractVersion=2 gehören; sonst wird INVALID_PARENT_SNAPSHOT bzw. ein passender Fehlerstatus mit partieller Sicht erzeugt. Der Consumerpfad übernimmt Sessions, Requests, Connections und bei @MitSqlText=1 den SQL-Text samt Quellenstatus aus diesem aufrufinternen Snapshot; es entsteht keine Frischegarantie. Anwender sollen diesen internen Parameter nicht selbst setzen. |

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `sessions` mit 51 Feldern, 22 expliziten Framework-Textcollations und fünf nicht-nullbaren Feldern. Aktive CONSOLE-Ausgaben ergänzen das Feld `Ergebnis`; eine leere Ausgabe besitzt `Ergebnis`, `Status` und `Hinweis`. RAW ergänzt zehn Wait-Felder und stellt ein Statusresultset voran. JSON ergänzt die drei Felder `waitGroup`, `waitSeverity` und `waitMeaning` und enthält `meta`, `sessions` und `warnings`. Status und Scope sind vor den Fachwerten zu lesen. Ein Warning kann auch den Detailtext eines erfolgreichen Aufrufs enthalten.

Alle vier Ausgaben verwenden dieselbe bereits begrenzte Sessionmenge. `@MaxZeilen = NULL` oder `0` liefert sie ohne Zeilenlimit; ein positives Limit setzt bei weiteren Kandidaten `hasMoreRows`. Die Auswahl richtet sich nach `@Sortierung` und `SessionId`. RAW sortiert seine Ausgabe nach diesen Schlüsseln, JSON nach `SessionId`; TABLE und der aktive CONSOLE-Helper garantieren keine Zeilenreihenfolge.


## Snapshot-Verhalten

Ein direkter Aufruf liest die Systemquellen immer frisch.
`@ParentCurrentStateSnapshotId` ist ein interner Consumerparameter für
`USP_CurrentOverview`; Anwender sollen ihn nicht setzen. Innerhalb des
Overview-Aufrufs werden Sessions, Requests, Connections und bei Bedarf
deduplizierter SQL-Text aus demselben laufinternen Primär-Snapshot verwendet.
RAW und JSON weisen den Startzeitpunkt sowie die Snapshot-ID aus. Der Overview-Consumer reicht `@AktuelleSessionEinbeziehen` nicht weiter; die aufrufende Session bleibt dort nach dem Childdefault ausgeschlossen.

## Eine Zeile bedeutet

Eine Zeile beschreibt eine aktuell sichtbare Session mit ihrem korrelierten Verbindungskontext. Der aktuelle Request wird über die kleinste sichtbare `request_id` ausgewählt; bei einer inaktiven Session kann er fehlen. Mehrere sichtbare Connections können die Zeilengranularität beeinflussen.

## So lesen

Prüfen Sie zuerst `SessionStatus`, `RequestStatus` und `OpenTransactionCount`. Berücksichtigen Sie danach die letzte Aktivität, kumulative CPU- und I/O-Werte sowie Verbindungsinformationen. Berücksichtigen Sie bei eingeblendeten Tool-Sessions außerdem `ToolBackgroundRuleCode` und `ToolBackgroundConfidence`.

## Warum kann das problematisch sein?

`sleeping` plus offene Transaktion bedeutet: Der Client führt nichts aus, hält aber möglicherweise Locks und verhindert Log-Wiederverwendung.

## Wann ist es kein Problem?

Eine lange angemeldete sleeping Session ohne offene Transaktion ist bei Connection Pools normal. Das Login-Alter allein ist kein Befund.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Eine seit acht Stunden verbundene Session mit letzter Aktivität vor zehn Sekunden und ohne offene Transaktion ist unauffällig. Prüfen Sie dieselbe Session bei einer zwei Stunden alten Transaktion mit `USP_CurrentTransactions` und der Blockinganalyse.

**Ähnlich aussehender Gegenfall:** Eine lange angemeldete sleeping Session ohne offene Transaktion ist bei Connection Pools normal. Das Login-Alter allein ist kein Befund. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Bei Live-DMVs kann der Zustand bereits beendet sein, bevor die Quelle gelesen wird. Eine leere Menge ist deshalb höchstens 'jetzt nicht sichtbar', nicht 'trat nicht auf'.

Für `USP_CurrentSessions` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

Ein eingeschränkter Berechtigungsscope kann fremde Sessions ausblenden. Prüfen Sie vor einer Entwarnung Status, eigene Sessionfilter und Systemsessionfilter.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Maximal 500 Ergebniszeilen aus sichtbaren User-Sessions einschließlich inaktiver Sessions, ohne SQL-Text. Die aufrufende Session und erkannte Tool-Hintergrundsessions sind standardmäßig ausgeschlossen. Pro Session wird höchstens ein aktueller Request korreliert. |
| Teuerster Pfad | `@MaxZeilen = 0`, System- und inaktive Sessions, `@MitSqlText = 1` ohne Zeichenlimit sowie mehrere Regexfilter. Regex wird nach der unbeschränkten Kandidatenmaterialisierung angewandt. |
| Haupttreiber | Zahl sichtbarer Sessions und korrelierter Connections/Requests. System-/Inaktivscope, SQL-Textbreite und späte Regexfilter bestimmen, ob nur eine frühe N+1-Kandidatenmenge oder alle vorgefilterten Sessions materialisiert werden. |
| Skalierung | Ohne Regex und bei positivem Limit werden höchstens `@MaxZeilen + 1` Kandidaten materialisiert. Mit Regex entfällt dieses frühe TOP. Die Quellenreads, Joins, Filter, Sortierung und optionale SQL-Textauflösung sind damit nicht auf N+1 beschränkt. |
| Ressourcen | CPU und Arbeitsspeicher für Session-/Connection-/Request-Joins, Sortierung und optional Regex; bei SQL-Text zusätzlicher Cachezugriff und Ergebnistransfer. |
| Begrenzungswirkung | Die DMV-Quellen werden zunächst in lokale Arbeitstabellen gelesen. Exakte Listen und LIKE-Prädikate filtern den anschließenden Join vor der Kandidatenmaterialisierung. Regex filtert erst danach per `DELETE`. Das gemeinsame Zeilenlimit wirkt vor der anschließenden Unicodeprojektion der behaltenen Texte. |
| Locking und Nebenwirkungen | Read-only gegenüber Nutzdaten. Flüchtige DMVs werden nacheinander gelesen; Katalog-/SQL-Textauflösung kann kurze interne Synchronisation verursachen, erzeugt aber keinen atomaren Snapshot. |
| Schutzmechanismus | Es gibt kein Deep-Gate. `@HighImpactConfirmed` ist in der aktuellen Implementierung nur Signaturkompatibilität und wird nach der Deklaration nicht ausgewertet; wirksame Schutzgrenzen sind Sessionfilter, Defaultlimit 500 und `@MitSqlText = 0`. |
| Sicherer Einsatz | Mit User-Scope, endlichem Limit, SQL-Text aus und möglichst exakten/LIKE-Filtern beginnen. Regex und ungekürzten Text erst nach Abschätzung der sichtbaren Sessionmenge aktivieren. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot + kumulative Sessionzähler“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Sessions sind verbunden, welchen Kontext besitzen sie und gibt es inaktive Sessions mit fortwirkendem Zustand?

### Technischer Hintergrund

`sys.dm_exec_sessions` hält den Sitzungskontext, während `sys.dm_exec_connections` Transport-/Verbindungsdaten und `sys.dm_exec_requests` aktuelle Arbeit ergänzt. Sessionzähler wie CPU oder Reads akkumulieren über die Session; Connection Pools können Sessions lange offen und `sleeping` halten.

### Datenkette

`master.sys.databases`, `sys.databases`, `sys.dm_exec_connections`, `sys.dm_exec_requests`, `sys.dm_exec_sessions`, `sys.dm_exec_sql_text`, `sys.sp_executesql`.

### Source Select

Das Grundselect zeigt die Session als führende Quelle und die optional vorhandene Connection beziehungsweise den aktuellen Request:

```sql
SELECT
      [s].[session_id]
    , [s].[status] AS [SessionStatus]
    , [s].[open_transaction_count]
    , [s].[cpu_time]
    , [s].[logical_reads]
    , [c].[connect_time]
    , [r].[status] AS [RequestStatus]
    , [r].[database_id]
FROM [sys].[dm_exec_sessions] AS [s] WITH (NOLOCK)
LEFT JOIN [sys].[dm_exec_connections] AS [c] WITH (NOLOCK)
  ON [c].[session_id] = [s].[session_id]
OUTER APPLY
(
    SELECT TOP (1) [rr].*
    FROM [sys].[dm_exec_requests] AS [rr] WITH (NOLOCK)
    WHERE [rr].[session_id] = [s].[session_id]
    ORDER BY [rr].[request_id]
) AS [r]
WHERE [s].[session_id] <> @@SPID
  AND [s].[is_user_process] = 1;
```

**Wichtig für die Eigenlast:** Bei `@MitSqlText = 1` werden zunächst die eindeutigen Handles der sichtbaren Request- und Connectionquellen aufgelöst. Die Sessionfilter und das Kandidaten-TOP folgen danach. Ein kleines Ergebnislimit begrenzt deshalb weder diesen Cachezugriff noch die physische Statementextraktion. Die anschließende Unicodeprojektion bearbeitet nur die behaltenen Ergebniszeilen. Eine inaktive Session kann Text über den letzten Connectionhandle besitzen, obwohl ihre Requestfelder einschließlich `DatabaseName` NULL bleiben.

### Zeit- und Scope-Modell

Die Auswertung liefert eine Sessionmomentaufnahme mit kumulativen Zählern seit dem Sessionbeginn. Session-IDs können nach dem Ende wiederverwendet werden; Uhrzeit sowie Login- und Verbindungskontext gehören zur Identität.

### Bewertung und Gegenprobe

`sleeping` ohne offene Transaktion ist häufig normal. `sleeping` mit offener Transaktion, Locks oder wachsendem Logverbrauch ist wesentlich kritischer. Hohe kumulative CPU einer alten Poolsession beweist keine aktuelle Last.

### Typische Fehlinterpretation

`LastRequestEndTime` ist nicht automatisch Transaktionsende. Clientangaben wie Host/Program sind nicht manipulationssicher.

### Folgeanalyse

Verwenden Sie für die weitere Analyse `USP_CurrentTransactions`, bei aktiver Arbeit `USP_CurrentRequests` und bei sichtbaren Auswirkungen `USP_CurrentBlocking`.

## Primärquellen

- [sys.dm_exec_sessions](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sessions-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../02_Current_State.md#1-monitorusp_currentsessions)
