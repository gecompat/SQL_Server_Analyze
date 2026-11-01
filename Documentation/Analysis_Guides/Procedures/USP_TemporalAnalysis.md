# [monitor].[USP_TemporalAnalysis]

**Bereich:** Versionsadaptive Spezialanalysen<br>
**Zweck:** Analysiert sichtbare Temporal-Current-/History-Beziehungen, Periodenmetadaten, Retention-Konfiguration, approximative Größe und History-Indizes.<br>
**Beobachtungsart:** Katalogsnapshot + aktueller Kapazitätszustand<br>
**Kostenklasse:** MEDIUM_HIGH_OPT_IN im Navigationskatalog; der SQL-Quellheader nennt MEDIUM. Beachten Sie beim Aufruf die Klasse CATALOG_DEEP und deren Bestätigungs- und Freigabeprüfung.

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche system-versioned Tabellen besitzen welche History-, Period-, Retention-, Größen- und Indexkonfiguration?** Sie unterstützt die Entscheidung, ob das Spezialfeature vorhanden und in einem auffälligen Zustand ist und welches featureeigene Diagnoseverfahren als Nächstes gebraucht wird.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Korrektheit der Featurekonfiguration, keine geschützten Inhalte und keine End-to-End-Funktionsprüfung außerhalb sichtbarer Metadaten. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_TemporalAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Der Aufrufer fordert `CATALOG_DEEP` an. Das Gruppengate greift nur, wenn der aktuelle Katalogeintrag diese Analyseklasse aktiviert und `RequiresGroupGate=1` setzt; dann genügt der Default @HighImpactConfirmed=0 nicht und die Vorbereitung liefert HIGH_IMPACT_CONFIRMATION_REQUIRED vor der Kandidatenermittlung. Bestätigung ersetzt weder die Pfadfreigabe noch einen begrenzten Datenbank- und Objekt-Scope.

Alle `Example*`-Werte im Aufruf sind synthetisch.

### Individuelle Parameterverträge

Die folgenden Einträge erklären jeden Parameter mit Datentyp, Eingabeform und ausdrücklich bezeichnetem Default. OUTPUT-Werte werden nur mit einer passenden, mit OUTPUT gebundenen Variable empfangen. TABLE-Vorprüfung und Hilfe haben die nachfolgend beschriebenen unterschiedlichen Zuweisungszeitpunkte.

| Parameter und Typ | Default | Eingabeform, Wirkung und Grenzen |
|---|---|---|
| `@DatabaseNames nvarchar(max)` | `NULL` | Exakte Datenbanknamen als bracket-aware Pipe-Liste: `\|` trennt außerhalb eckiger Klammern; `]]` maskiert darin ein schließendes `]`. Äußere U+0020-Leerzeichen je Element werden entfernt. Leere oder fehlerhaft geklammerte Elemente sind ungültig; ein Rohsegment ist auf 4000 UTF-16-Codeeinheiten begrenzt, ein geparster Name ist einteiliger PARSENAME-Text mit höchstens 128 Zeichen und keine vollständige SQL-Bezeichnergrammatik. Doppelte Namen werden case-sensitiv erkannt. NULL, leerer oder nur aus Leerzeichen bestehender Text bedeutet keine exakte Liste; ausgelassen entspricht NULL. Ohne wirksame Liste kommen sichtbare Online-Datenbanken infrage, vorbehaltlich der Systemdatenbankauswahl. Eine wirksame Liste ist mit einem nicht-NULL @DatabaseNamePattern unzulässig. Fehlende ausdrücklich angeforderte Datenbanken können DATABASE_UNAVAILABLE-Warnungen erzeugen. Ungültige Eingaben führen zu INVALID_PARAMETER. |
| `@SystemdatenbankenEinbeziehen bit` | `0` | Steuert, ob master, tempdb, model und msdb auswählbar sind: 0 schließt sie aus; 1 lässt sie zu. Bei ausdrücklich angeforderten, ausgeschlossenen Systemdatenbanken kann eine SYSTEM_DATABASE_EXCLUDED-Warnung entstehen. NULL führt zu INVALID_PARAMETER; ausgelassen gilt der Vorgabewert. Bei der Konvertierung in bit wird 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. |
| `@DatabaseNamePattern nvarchar(4000)` | `NULL` | Filtert Datenbankkandidaten mit LIKE-Syntax oder einem Präfix `like:`, `regex:` oder `regexi:`. Das Präfix wird ohne Beachtung der Groß-/Kleinschreibung erkannt. Äußere U+0020-Leerzeichen werden entfernt, der Mustertext nach dem Präfix aber nicht erneut getrimmt. NULL oder ausgelassen bedeutet kein Pattern; leerer Text oder leerer Präfixinhalt ist ungültig. LIKE verwendet SQL_Latin1_General_CP1_CS_AS. regex: verwendet Flag c, regexi: Flag i. Regex erfordert SQL Server 2025 oder neuer und Compatibility Level 170 in der Installationsdatenbank; andernfalls liefert die Kandidatenvorbereitung UNAVAILABLE_FEATURE. Das Pattern filtert die Kandidatenliste nach deren Ermittlung. Fehlerhafte Regex-Syntax wird nicht vorab validiert und kann bei der Auswertung als SQL-Fehler auftreten. Jedes nicht-NULL Pattern ist mit einer wirksamen @DatabaseNames-Liste unzulässig. |
| `@HighImpactConfirmed bit` | `0` | Bestätigt ein Gruppengate nur dann, wenn der aktuelle Katalogeintrag die tatsächlich verwendete Analyseklasse CATALOG_DEEP aktiviert hat und RequiresGroupGate=1 verlangt. 0 bestätigt nicht; 1 bestätigt dieses Gate, ersetzt aber weder die Freigabe des Analysepfads noch eine Scopebegrenzung. NULL führt auch ohne aktives Gate zu INVALID_PARAMETER; ausgelassen gilt 0. Bei der Konvertierung in bit wird 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. Ist das Gate aktiv und nicht bestätigt, endet die Vorbereitung mit HIGH_IMPACT_CONFIRMATION_REQUIRED, bevor Datenbankkandidaten ermittelt werden. |
| `@SchemaNames nvarchar(max)` | `NULL` | Exakte Schemanamen als bracket-aware Pipe-Liste mit denselben Regeln wie @DatabaseNames: `\|` trennt außerhalb eckiger Klammern, `]]` maskiert `]`, äußere Elementleerzeichen werden entfernt, Rohsegmente dürfen höchstens 4000 UTF-16-Codeeinheiten lang sein und geparste einteilige PARSENAME-Namen höchstens 128 Zeichen umfassen. Die Prüfung ist keine vollständige SQL-Bezeichnergrammatik; leere oder fehlerhafte Elemente sowie case-sensitive Duplikate sind ungültig. NULL, leerer oder nur aus Leerzeichen bestehender Text beziehungsweise eine Liste ohne wirksame Namen schränkt das Schema nicht ein. Ein roher nicht-NULL-Wert ist unabhängig von der Normalisierung mit @SchemaNamePattern und mit jedem rohen nicht-NULL @FullObjectNames unzulässig. |
| `@SchemaNamePattern nvarchar(4000)` | `NULL` | Schränkt die Schemanamen der aktuellen Tabellen mit LIKE oder `like:`, `regex:` beziehungsweise `regexi:` ein. Präfixerkennung ist nicht case-sensitiv; äußere U+0020-Leerzeichen werden entfernt, der Mustertext nicht erneut getrimmt; LIKE nutzt SQL_Latin1_General_CP1_CS_AS. NULL oder ausgelassen bedeutet kein Pattern; leerer Text oder leerer Präfixinhalt ist ungültig. regex: verwendet Flag c, regexi: Flag i. Bei Regex wird SQL Server 2025+ zunächst global geprüft; fehlt diese Version, lautet der globale Status UNAVAILABLE_VERSION. Danach muss jedes Zieldatenbank-Compatibility-Level mindestens 170 betragen; inkompatible Datenbanken erhalten UNAVAILABLE_FEATURE als Datenbankstatus und begrenzen das Gesamtergebnis auf AVAILABLE_LIMITED. Regex-Auswertungsfehler werden je Datenbank abgefangen. Ungültiges Pattern oder ein roher nicht-NULL-Wert für @SchemaNames führt zu INVALID_PARAMETER. |
| `@ObjectNames nvarchar(max)` | `NULL` | Exakte Namen aktueller Tabellen als bracket-aware Pipe-Liste mit denselben Regeln wie @SchemaNames: `\|` trennt außerhalb eckiger Klammern, `]]` maskiert `]`, äußere Elementleerzeichen werden entfernt, Rohsegmente sind auf 4000 UTF-16-Codeeinheiten und geparste einteilige PARSENAME-Namen auf 128 Zeichen begrenzt. Die Prüfung ersetzt keine vollständige SQL-Bezeichnergrammatik; leere oder ungültige Elemente sowie case-sensitive Duplikate sind unzulässig. NULL, leerer oder nur aus Leerzeichen bestehender Text beziehungsweise eine Liste ohne wirksame Namen schränkt die Objektnamen nicht ein. Ein roher nicht-NULL-Wert ist unabhängig von der Normalisierung mit @ObjectNamePattern und mit jedem rohen nicht-NULL @FullObjectNames unzulässig. |
| `@ObjectNamePattern nvarchar(4000)` | `NULL` | Schränkt die Namen aktueller Tabellen mit LIKE oder `like:`, `regex:` beziehungsweise `regexi:` ein. Präfixerkennung ist nicht case-sensitiv; äußere U+0020-Leerzeichen werden entfernt, der Mustertext nicht erneut getrimmt; LIKE nutzt SQL_Latin1_General_CP1_CS_AS. NULL oder ausgelassen bedeutet kein Pattern; leerer Text oder leerer Präfixinhalt ist ungültig. regex: verwendet Flag c, regexi: Flag i. Bei Regex wird SQL Server 2025+ zunächst global geprüft; fehlt diese Version, lautet der globale Status UNAVAILABLE_VERSION. Danach muss jedes Zieldatenbank-Compatibility-Level mindestens 170 betragen; inkompatible Datenbanken erhalten UNAVAILABLE_FEATURE als Datenbankstatus und begrenzen das Gesamtergebnis auf AVAILABLE_LIMITED. Regex-Auswertungsfehler werden je Datenbank abgefangen. Ungültiges Pattern oder ein roher nicht-NULL-Wert für @ObjectNames führt zu INVALID_PARAMETER. |
| `@FullObjectNames nvarchar(max)` | `NULL` | Bracket-aware Pipe-Liste mit optional qualifizierten Objektbezügen in den Formen Objekt, Schema.Objekt oder Datenbank.Schema.Objekt; bei drei Teilen ist ein Schema erforderlich, vierteilige Namen sind ungültig. PARSENAME liefert die Bestandteile 1 bis 3; die Prüfung ist keine vollständige SQL-Bezeichnergrammatik. `\|` trennt außerhalb eckiger Klammern, `]]` maskiert `]`, äußere Elementleerzeichen werden entfernt. Leere/fehlerhafte Elemente, Rohsegmente über 4000 UTF-16-Codeeinheiten und case-sensitive doppelte Tupel sind ungültig. NULL, leerer oder nur aus Leerzeichen bestehender Text bedeutet keinen Full-Object-Filter; ausgelassen entspricht NULL. ItemOrdinal bewahrt die Eingabereihenfolge in der Hilfstabelle, sortiert aber die Ausgabe nicht; die Einträge werden als Alternativen geprüft. Ohne Datenbankbestandteil kann ein Eintrag in jeder ausgewählten Datenbank passen; angegebene Datenbank und Schema sowie der Objektname müssen jeweils übereinstimmen. Ein roher nicht-NULL-Wert für @FullObjectNames ist mit jedem rohen nicht-NULL @SchemaNames- oder @ObjectNames-Wert unzulässig, auch wenn einer davon leer ist. Schema- und Objekt-Patterns dürfen kombiniert werden; ihre Filter werden zusätzlich angewendet und verengen den Scope. |
| `@NurProblematisch bit` | `0` | 0 gibt alle Findings und Detailobjekte aus; 1 behält nur WARN-Findings, Temporal-Tabellen mit AssessmentStatus REVIEW und deren zugehörige History-Indexzeilen. NULL führt zu INVALID_PARAMETER; ausgelassen gilt 0. Bei der Konvertierung in bit wird 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. Die Filterung erfolgt nach Inventur und Findingsberechnung und verringert die vorgelagerten Katalogabfragen nicht. Datenbank-/Quellenstatus sowie zuvor ermittelte Inventur- und Findingzähler bleiben verfügbar. |
| `@HistorySizeWarnMb decimal(19,2)` | `10240` | Nichtnegativer Schwellenwert in MB für die approximative reservierte History-Größe. Erreicht oder überschreitet HistoryReservedMb den Wert, entsteht ein INFO-Kontext-Finding, kein WARN. Bei 0 kann jeder verfügbare nichtnegative Messwert diese Informationsschwelle erreichen. NULL oder ein negativer Wert führt zu INVALID_PARAMETER; ausgelassen gilt der Vorgabewert. @NurProblematisch=1 entfernt dieses INFO-Finding, da der Filter nur WARN-Findings behält. Die Seitenwerte sind approximativ und umfassen Tabellen- und Indexspeicher; der Schwellenwert löst keine automatische Kapazitätsmaßnahme aus. |
| `@HistoryRowsWarn bigint` | `10000000` | Nichtnegativer Schwellenwert für die approximative Zeilenzahl der History-Tabelle. Erreicht oder überschreitet HistoryRowsApprox den Wert, entsteht ein INFO-Kontext-Finding, kein WARN. Bei 0 kann jeder verfügbare nichtnegative Zählerwert diese Informationsschwelle erreichen. NULL oder ein negativer Wert führt zu INVALID_PARAMETER; ausgelassen gilt der Vorgabewert. @NurProblematisch=1 entfernt dieses INFO-Finding, da der Filter nur WARN-Findings behält. Der Zähler beweist weder Wachstum noch Alter oder erfolgreichen Cleanup. |
| `@HistoryToCurrentRatioWarn decimal(19,4)` | `10` | Positiver Schwellenwert für HistoryRowsApprox geteilt durch CurrentRowsApprox. NULL oder ein Wert <=0 führt zu INVALID_PARAMETER; ausgelassen gilt der Vorgabewert. Das Verhältnis wird nur berechnet, wenn CurrentRowsApprox > 0 und CurrentIsMemoryOptimized=0 ist; sonst bleibt es NULL. Erreicht das Verhältnis den Schwellenwert und erreicht HistoryReservedMb zugleich @MinHistoryMbForRatioWarn, entsteht ein INFO-Kontext-Finding, kein WARN. @NurProblematisch=1 entfernt dieses INFO-Finding, da der Filter nur WARN-Findings behält. Das approximative Verhältnis belegt keine angemessene Retention-Tiefe. |
| `@MinHistoryMbForRatioWarn decimal(19,2)` | `100` | Nichtnegative Mindestgröße der approximativ reservierten History in MB, die vor einem INFO-Kontext-Finding zum History/Current-Zeilenverhältnis erreicht sein muss. Bei 0 entfällt diese Mindestgröße. NULL oder ein negativer Wert führt zu INVALID_PARAMETER; ausgelassen gilt der Vorgabewert. Der Wert wird zusammen mit @HistoryToCurrentRatioWarn ausgewertet und erzeugt kein eigenes Finding. |
| `@MaxZeilen int` | `2000` | Begrenzt die jeweilige anwendbare Detail- und Findings-Auswahl. Positive Werte begrenzen die bereits materialisierten Ausgaben: Findings werden nach WARN zuerst und dann FindingOrdinal geordnet; Temporal-Tabellen nach REVIEW zuerst, anschließend nach HistoryReservedMb absteigend und Namen; History-Indizes nach Datenbank, Current-Objekt und IndexId. NULL oder 0 bedeutet unbegrenzt; negative Werte führen zu INVALID_PARAMETER. Die Grenze reduziert weder die vorangehende Inventur noch Quellenabfragen oder Findingsberechnung. Sie kann Zeilen einer nichtleeren Quelle aus der sichtbaren Ausgabe ausschließen. |
| `@LockTimeoutMs int` | `0` | Zeitlimit der datenbanklokalen Child-Batches in Millisekunden, einschließlich 0 bis 60000. 0 bedeutet NOWAIT; positive Werte legen die Wartezeitgrenze des Child-Batches fest. NULL oder ein Wert außerhalb des Bereichs führt zu INVALID_PARAMETER. Das Limit gilt nicht für das vorherige TABLE-Ziel-Preflight oder sämtliche Frameworkarbeiten. Lokale TempDB-Anlage hat eigenen Sperrschutz; der SET-Wert eines untergeordneten Batches endet mit dessen Rückkehr. |
| `@ResultSetArt varchar(16)` | `'CONSOLE'` | Ausgabeart nach Entfernen äußerer Leerzeichen und Umwandlung in Großbuchstaben. Zulässige Werte: CONSOLE liefert eine beschriftete Findings-Ansicht samt verständlicher Leer-Ausgabe; RAW liefert sechs Resultsets in der Reihenfolge Modulmetadaten, Datenbankstatus, Quellenstatus, Findings, Temporal-Tabellen und History-Indizes; TABLE schreibt ausschließlich `findings` in die geprüfte lokale Ziel-Temp-Tabelle; NONE liefert keine Daten-Resultsets. NULL wird zu leerem Text und führt zu INVALID_PARAMETER; ausgelassen gilt CONSOLE. Andere Werte sind ungültig. Bei TABLE wird das Ziel vor der Hilfe geprüft; Fehler können 51011 auslösen. |
| `@ResultTablesJson nvarchar(max)` | `NULL` | JSON-Zuordnung des einzigen Resultsets `findings` zu einer lokalen # Temp-Tabelle des Aufrufers. Bei TABLE muss der Wert ein gültiges, nichtleeres JSON-Objekt sein; NULL, leerer oder nur aus Leerzeichen bestehender Text, ungültiges JSON, ein falscher Schlüssel, Duplikate, Nicht-String-Werte oder ein unzulässiges Ziel können beim Preflight 51011 auslösen. Das Ziel muss in der Aufrufersitzung existieren, leer sein, genau eine Seed-Spalte besitzen, genau einen lokalen # Namen (kein ##) mit höchstens 116 Zeichen verwenden und darf nicht mit dem reservierten Präfix #Monitor beginnen. Bei anderer Ausgabeart sind NULL/Leertext zulässig; nichtleerer Text löst vor der Hilfe 51011 aus. Ausgelassen entspricht NULL, was bei TABLE kein gültiges Mapping bereitstellt. TABLE schreibt nur Findings; JSON kann meta, databaseStatus, sourceStatus, findings, temporalTables und historyIndexes enthalten. Der Schlüssel findings muss exakt geschrieben sein und bezeichnet Prüfhinweise mit Evidenz, Grenzen und möglicher Gegenprüfung. Doppelte Schlüssel werden binär, doppelte Ziele case-insensitiv geprüft; das reservierte Präfix #Monitor ist ebenfalls case-insensitiv gesperrt. Writerablehnungen nach erfolgreichem Preflight können 51010 werfen. |
| `@JsonErzeugen bit` | `0` | 0 deaktiviert die JSON-Erzeugung; @Json bleibt NULL. 1 erzeugt das Dokument im @Json-OUTPUT-Parameter. NULL führt zu INVALID_PARAMETER; ausgelassen gilt 0. Bei der Konvertierung in bit wird 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. Die Hilfe kehrt nach dem Leeren von @Json vor einer Erzeugung zurück. Ein TABLE-Preflightfehler kann vor der Zuweisung der Diagnose-OUTPUTs auftreten. |
| `@Json nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Dokument; zum Empfang eine Aufrufervariable des deklarierten SQL-Typs mit OUTPUT binden. Der Parameter wird beim Eintritt geleert und bleibt NULL, wenn JSON deaktiviert ist oder die Hilfe zurückkehrt. Bei aktivierter Erzeugung enthält das Dokument meta sowie die Arrays databaseStatus, sourceStatus, findings, temporalTables und historyIndexes; Arrays können leer sein. Findings und Detailarrays folgen den jeweiligen Filter- und Limitregeln; Status- und Inventurzähler behalten ihren breiteren Scope. Das TABLE-Preflight erfolgt vor der Diagnose-OUTPUT-Zuweisung. Der TABLE-Writer läuft nach JSON- und Diagnosezuweisung; sein Fehler wird nicht in diesen Diagnosen abgebildet, und die Quellreihenfolge belegt nicht, ob OUTPUT-Werte nach dem Fehler beim Aufrufer ankommen. |
| `@PrintMeldungen bit` | `1` | 1 gibt bei abschließendem Status außer AVAILABLE und NOT_APPLICABLE eine Meldung niedriger Severity aus; 0 unterdrückt diese Meldung. NULL führt zu INVALID_PARAMETER; ausgelassen gilt 1. Bei der Konvertierung in bit wird 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. Strukturierte Resultsets und OUTPUT-Parameter werden davon nicht gesteuert. |
| `@Hilfe bit` | `0` | 1 druckt kurze Hinweise zu Zweck, Quellen, Filterausschlüssen, Schwellen, Ausgabearten und Datenzugriff und kehrt danach vor der Analyse zurück. 0 führt die normale Verarbeitung aus. NULL wird nicht ausdrücklich abgelehnt und führt in den normalen Pfad, da nur auf Gleichheit mit 1 geprüft wird; ausgelassen gilt 0. Bei der Konvertierung in bit wird 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. TABLE-Zielprüfung und ein möglicher Fehler 51011 geschehen vor der Hilfebehandlung. Die Hilfe lässt @Json am Eintritt auf NULL, kehrt aber vor der Zuweisung der vier Diagnose-OUTPUTs zurück; deren Aufrufervariablen bleiben unverändert. |
| `@StatusCodeOut varchar(40) OUTPUT` | `NULL` | OUTPUT-Status; zum Empfang eine Aufrufervariable des deklarierten SQL-Typs mit OUTPUT binden. AVAILABLE bedeutet abgeschlossene Analyse ohne globale Partialität und ohne WARN-Finding. AVAILABLE_WITH_FINDING bedeutet vollständige Analyse mit mindestens einem WARN-Finding. AVAILABLE_LIMITED bedeutet, dass bei sonst verfügbarem Ergebnis mindestens eine Datenbank oder Quelle partiell fehlte; dieser Status hat Vorrang vor Findings. NOT_APPLICABLE bedeutet, dass keine Datenbankkandidaten verfügbar waren oder im sichtbaren Scope keine Temporal-Funktion verwendet wird. INVALID_PARAMETER kennzeichnet einen ungültigen Eingabeparameter oder Filtervertrag. UNAVAILABLE_VERSION kennzeichnet, dass für Schema-/Objekt-Regex die erforderliche SQL-Server-Version fehlt. UNAVAILABLE_FEATURE kann aus der Datenbankkandidaten-Vorbereitung kommen, wenn Datenbankname-Regex wegen SQL-Server-Version oder Compatibility Level 170 der Installationsdatenbank nicht verfügbar ist. HIGH_IMPACT_CONFIRMATION_REQUIRED bedeutet, dass das aktive Gruppengate von CATALOG_DEEP nicht bestätigt wurde; DENIED_GROUP bedeutet, dass die aktuelle Pfadfreigabe fehlt. INTERNAL_ERROR kennzeichnet eine nicht passend prüfbare interne Temp-Tabelle in der Namens-/Kandidatenvorbereitung. TIMEOUT bedeutet dort den abgefangenen Sperrfehler 1222; DENIED_PERMISSION bezeichnet die dort abgefangenen Berechtigungsfehler 229, 262, 297, 300, 371 oder 916; ERROR_HANDLED steht dort für einen anderen abgefangenen SQL-Fehler. Ungültige Eingaben werden zuerst behandelt; bei verfügbarer Analyse gilt für den Abschluss die Priorität AVAILABLE_LIMITED, dann AVAILABLE_WITH_FINDING, dann NOT_APPLICABLE, sonst AVAILABLE. Der Datenbankname-Regexpfad prüft SQL-Version und Framework-Installations-Compatibility-Level vor der Kandidatenauswahl; Schema-/Objekt-Regex prüft zunächst die SQL-Version und danach jedes Ziel-Compatibility-Level. Ein TABLE-Preflightfehler tritt vor Diagnosezuweisung auf. Der Writer wird danach aufgerufen; sein Fehler wird nicht in diesen Status übersetzt, und Quellreihenfolge allein belegt nicht, ob OUTPUT-Werte trotz Fehler beim Aufrufer ankommen. Bei Hilfe bleibt die Aufrufervariable unverändert. |
| `@IsPartialOut bit OUTPUT` | `NULL` | OUTPUT-Partialitätskennzeichen; zum Empfang eine Variable des deklarierten Typs mit OUTPUT binden. Ungültige Parameter und Versionsgates setzen 1. Jedes nicht-AVAILABLE-Ergebnis von USP_PrepareNameFilters oder USP_PrepareDatabaseCandidates setzt ebenfalls 1; dies umfasst interne, Berechtigungs-, Timeout-, Gruppen- und Bestätigungsfehler dieser Vorbereitung. Bei ansonsten verfügbarer Analyse führen partielle Datenbank-/Quellenergebnisse zu 1. Ohne diese Bedingungen bleibt das Kennzeichen 0, auch beim abschließenden NOT_APPLICABLE. Hilfe und TABLE-Preflight liegen vor der Diagnosezuweisung und lassen den Eingangswert unverändert. Der Writer läuft danach; sein geworfener Fehler wird nicht in diese Diagnose übersetzt. Für einen geworfenen Fehler ist keine reguläre OUTPUT-Übertragung qualifiziert. |
| `@ErrorNumberOut int OUTPUT` | `NULL` | OUTPUT-Fehlernummer; zum Empfang eine Aufrufervariable des deklarierten SQL-Typs mit OUTPUT binden. Empfangen wird eine bereits ausgewählte Fehlernummer oder, falls keine vorliegt, die kleinste ErrorNumber aus partiellen SourceStatus-Zeilen; andernfalls bleibt der Wert NULL. Hilfe und ein TABLE-Preflightfehler treten vor der Diagnosezuweisung auf. Der Writer läuft danach; sein Fehler wird hier nicht abgebildet und die Quellreihenfolge belegt keine Weitergabe der OUTPUT-Werte nach einem Fehler. Die Nummernauswahl erfolgt unabhängig von der Textauswahl: MIN(ErrorNumber) und MIN(ErrorMessage) können aus verschiedenen Quellenzeilen stammen. Das ausgegebene Paar bezeichnet daher nicht zwingend dasselbe Quellenereignis. |
| `@ErrorMessageOut nvarchar(2048) OUTPUT` | `NULL` | OUTPUT-Fehlertext; zum Empfang eine Aufrufervariable des deklarierten SQL-Typs mit OUTPUT binden. Empfangen wird der Text eines globalen Gates/Fehlers oder, falls ausgewählt, einer partiellen Quellenfehlermeldung; NULL bedeutet, dass kein globaler/Quellenfehlertext ausgewählt wurde, nicht dass jede Quelle separat verifiziert ist. Hilfe und ein TABLE-Preflightfehler treten vor der Diagnosezuweisung auf. Der Writer läuft danach; sein Fehler wird hier nicht abgebildet und die Quellreihenfolge belegt keine Weitergabe der OUTPUT-Werte nach einem Fehler. Der Text wird getrennt von der Nummer ausgewählt, jeweils über einen eigenen MIN-Wert bei zuvor fehlender Diagnose. Nummer und Meldung können deshalb aus verschiedenen Quellenzeilen stammen und bilden kein garantiert zusammengehöriges Fehlerpaar. |

### Kopierbare Aufrufbeispiele

Der Hilfeaufruf benötigt keine Bestätigung. Die Analysebeispiele enthalten die ausdrückliche Bestätigung des CATALOG_DEEP-Pfads und synthetische Datenbank-/Objektnamen. Ersetzen Sie die Namen und prüfen Sie vor dem Aufruf Scope und Freigabe. Das TABLE-Beispiel legt ein leeres Seed-Ziel an und entfernt es in beiden Abschlusswegen.

```sql
EXEC [monitor].[USP_TemporalAnalysis] @Hilfe=1;
```

```sql
EXEC [monitor].[USP_TemporalAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @FullObjectNames=N'[ExampleDatabase].[ExampleSchema].[ExampleObject]', @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
```

```sql
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_TemporalAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];
```

```sql
CREATE TABLE [#TemporalAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_TemporalAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#TemporalAnalysis_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#TemporalAnalysis_HelpExample]; DROP TABLE IF EXISTS [#TemporalAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#TemporalAnalysis_HelpExample]; THROW; END CATCH;
```

```sql
EXEC [monitor].[USP_TemporalAnalysis] @DatabaseNamePattern=N'like:ExampleDatabase%', @SchemaNamePattern=N'like:Example%', @HighImpactConfirmed=1, @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `findings`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

Findings in RAW, CONSOLE, TABLE und JSON verwenden dieselbe nach @NurProblematisch gefilterte und nach @MaxZeilen begrenzte Findingsauswahl; der Filter behält bei 1 WARN-Findings und NULL/0 beim Limit bedeutet unbegrenzt. Die Begrenzung erfolgt nach der Inventur und Findingsberechnung. Statusarrays und die zuvor berechneten Datenbank-, Quellen- und Findingzähler bleiben erhalten. TABLE validiert vor der Hilfe die einzelne Zielzuordnung `findings`; ungültige Zuordnung oder fehlendes Ziel kann 51011 auslösen, bevor Diagnose-OUTPUTs zugewiesen werden. JSON enthält meta als Objekt sowie databaseStatus, sourceStatus, findings, temporalTables und historyIndexes als Arrays; TABLE schreibt nur findings.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer Temporal-Tabelle, History-Beziehung, Retention-/Cleanup-Evidenz, Index-/Kapazitätsinformation oder einem Finding.

## So lesen

Vergleichen Sie Current-/History-Zuordnung, sichtbare Periodenspalten, approximative Historygröße, Retention-Konfiguration und die führenden History-Indexspalten. Die Procedure prüft keine Zeilenkonsistenz und keinen Cleanup-Fortschritt; Wachstum erfordert wiederholte Messungen.

## Warum kann das problematisch sein?

Unbegrenzte oder wirkungslose Retention kann History stark wachsen lassen; ungeeignete Indizes verteuern Zeitabfragen und Cleanup.

## Wann ist es kein Problem?

Große History kann fachlich erforderlich und durch Partitionierung oder Archivierung kontrolliert sein.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Eine endliche History-Retention ist konfiguriert, während der datenbankweite Retention-Schalter deaktiviert ist. Das entsprechende Finding belegt diese Konfiguration; Cleanup-Ausführung und Wachstum benötigen zusätzliche Laufzeitevidenz.

**Ähnlich aussehender Gegenfall:** Große History kann fachlich erforderlich und durch Partitionierung oder Archivierung kontrolliert sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Nicht installiert, nicht aktiviert, in der gewählten Datenbank nicht verwendet und nicht abfragbar sind vier verschiedene Zustände.

Für `USP_TemporalAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM_HIGH_OPT_IN im Navigationskatalog; MEDIUM im SQL-Quellheader. CATALOG_DEEP steuert die Bestätigungs- und Freigabeprüfung. |
| Standardpfad | Eine `ExampleDatabase`, Problemscope und möglichst ein Temporal-Objektfilter; Katalogbeziehungen, approximative Partitionsgröße und History-Indexabdeckung werden gelesen. |
| Teuerster Pfad | Alle sichtbaren Datenbanken ohne Objektfilter und unbegrenzte Ausgabe bei sehr vielen Temporal-/Historytabellen, Partitionen und History-Indizes. Benutzertabellenzeilen werden auch dann nicht gelesen. |
| Haupttreiber | Zahl ausgewählter Datenbanken und Temporal-/Historytabellen, deren Partitionen und History-Indizes. Objektfilter reduzieren diese Katalogmenge früh; Zeilen aus Current- oder Historytabellen werden nicht gelesen. |
| Skalierung | Aufwand wächst mit Temporal-Paaren, ihren Partitionen und History-Indizes. `sys.dm_db_partition_stats` liefert approximative Größen ohne History-Datenscan; dynamisches SQL und Findingregeln laufen je Datenbank. |
| Ressourcen | CPU und Katalog-/Partitionsmetadaten-I/O, dynamischer Compileaufwand und kleine TempDB-/Arbeitstabellen für Temporalpaare, Indizes und Findings. |
| Begrenzungswirkung | Datenbank-/Objektfilter begrenzen Katalog- und Partitionsmetadatenarbeit. `@NurProblematisch` und `@MaxZeilen` wirken erst auf fertige Findings/Detailtabellen und begrenzen die vorgelagerte Inventur nicht. |
| Locking und Nebenwirkungen | Read-only ohne DDL oder Historydatenzugriff; gleichzeitiges `SYSTEM_VERSIONING`-/Index-DDL kann zwischen Katalog- und Größenprobe einen Mischstand erzeugen. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `CATALOG_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine bekannte `ExampleDatabase`, Problemscope und ein konkretes Temporalobjekt. Trotz `CATALOG_DEEP`-Bestätigung erst Datenbankstatus und Quellenfehler lesen, dann Größe/Indexbefund bewerten. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Katalogsnapshot + aktueller Kapazitätszustand“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche system-versioned Tabellen besitzen welche History-, Period-, Retention-, Größen- und Indexkonfiguration?

### Technischer Hintergrund

Temporal Tables schreiben bei Update/Delete frühere Rowversionen in eine History Table; Period Columns definieren Gültigkeit. System Versioning, Data Consistency Check und Retention steuern Lebenszyklus. Historyzugriffe über `FOR SYSTEM_TIME` benötigen passende Indizes/Partitionierung.

### Datenkette

`sys.columns`, `sys.databases`, `sys.dm_db_partition_stats`, `sys.index_columns`, `sys.indexes`, `sys.periods`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`.

### Source Select

System-versionierte Tabelle, History-Tabelle, Schema und Periodendefinition werden über Katalog-IDs verbunden:

```sql
SELECT
      [s].[name] AS [SchemaName]
    , [t].[name] AS [TableName]
    , [t].[temporal_type_desc]
    , [hs].[name] AS [HistorySchemaName]
    , [ht].[name] AS [HistoryTableName]
    , [p].[start_column_id]
    , [p].[end_column_id]
FROM [sys].[tables] AS [t] WITH (NOLOCK)
JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
  ON [s].[schema_id] = [t].[schema_id]
LEFT JOIN [sys].[tables] AS [ht] WITH (NOLOCK)
  ON [ht].[object_id] = [t].[history_table_id]
LEFT JOIN [sys].[schemas] AS [hs] WITH (NOLOCK)
  ON [hs].[schema_id] = [ht].[schema_id]
LEFT JOIN [sys].[periods] AS [p] WITH (NOLOCK)
  ON [p].[object_id] = [t].[object_id]
WHERE [t].[temporal_type] <> 0
  AND [s].[name] = N'ExampleSchema'
  AND [t].[name] = N'ExampleObject';
```

**Wichtig für die Eigenlast:** Legen Sie Datenbank und Objekt vor History-Größen-, Partition- und Indexanalyse fest. Berücksichtigen Sie `dm_db_partition_stats` erst für die aufgelösten Current-/History-Objekt-IDs.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den sichtbaren aktuellen Katalogstand, die Retention-Konfiguration und approximative Zeilen- und Seitenzähler. Sie liest keine Current- oder Historyzeilen und bestimmt weder deren Alter noch eine tatsächlich durchgesetzte Retention.

### Bewertung und Gegenprobe

Berücksichtigen Sie Current und History Table, Period Columns, Retention-Konfiguration, approximative Größe und Zeilenanzahl sowie die sichtbare Indexierung. Die Indexbaseline bewertet ausschließlich die führende Schlüsselreihenfolge Periodenende/Periodenstart. Workload-Eignung, Partitionierung und Cleanup-Fortschritt erfordern gesonderte Gegenproben.

### Typische Fehlinterpretation

Große History ist nicht automatisch Problem; sie kann Complianceanforderung sein. Temporal ON beweist keine erfolgreiche Retentionbereinigung.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Object/Index/Partition/Capacity, konkrete Temporal Querypläne und Retentionpolicy.

## Primärquellen

- [Temporal Tables](https://learn.microsoft.com/en-us/sql/relational-databases/tables/temporal-tables?view=sql-server-ver17)

[Technische Detailbeschreibung](../09_Version_Adaptive.md#4-monitorusp_temporalanalysis)
