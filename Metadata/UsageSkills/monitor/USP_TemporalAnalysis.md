---
skill_format_version: "1.0.0"
name: "monitor.USP_TemporalAnalysis"
schema_name: "monitor"
object_name: "USP_TemporalAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure analysiert sichtbare systemversionierte Temporal Tables, Retention-Konfiguration, ungefähre Kapazität und die Perioden-Indexabdeckung ihrer History-Tabellen."
source_path: "Code/09_VersionAdaptive/040_USP_TemporalAnalysis.sql"
---

# monitor.USP_TemporalAnalysis

## Zweck und Einsatz

Die Procedure analysiert sichtbare systemversionierte Temporal Tables, Retention-Konfiguration, ungefähre Kapazität und die Perioden-Indexabdeckung ihrer History-Tabellen.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

sys.tables, sys.schemas, sys.periods, sys.columns, sys.databases, sys.indexes, sys.index_columns und sys.dm_db_partition_stats.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @SchemaNames | nvarchar(max) | nein | NULL |
| @SchemaNamePattern | nvarchar(4000) | nein | NULL |
| @ObjectNames | nvarchar(max) | nein | NULL |
| @ObjectNamePattern | nvarchar(4000) | nein | NULL |
| @FullObjectNames | nvarchar(max) | nein | NULL |
| @NurProblematisch | bit | nein | 0 |
| @HistorySizeWarnMb | decimal(19,2) | nein | 10240 |
| @HistoryRowsWarn | bigint | nein | 10000000 |
| @HistoryToCurrentRatioWarn | decimal(19,4) | nein | 10 |
| @MinHistoryMbForRatioWarn | decimal(19,2) | nein | 100 |
| @MaxZeilen | int | nein | 2000 |
| @LockTimeoutMs | int | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
| @IsPartialOut | bit | nein | NULL OUTPUT |
| @ErrorNumberOut | int | nein | NULL OUTPUT |
| @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. Exakte Datenbanknamen als bracket-aware Pipe-Liste: `|` trennt außerhalb eckiger Klammern; `]]` maskiert darin ein schließendes `]`. Äußere U+0020-Leerzeichen je Element werden entfernt. Leere oder fehlerhaft geklammerte Elemente sind ungültig; ein Rohsegment ist auf 4000 UTF-16-Codeeinheiten begrenzt, ein geparster Name ist einteiliger PARSENAME-Text mit höchstens 128 Zeichen und keine vollständige SQL-Bezeichnergrammatik. Doppelte Namen werden case-sensitiv erkannt. NULL, leerer oder nur aus Leerzeichen bestehender Text bedeutet keine exakte Liste; ausgelassen entspricht NULL. Ohne wirksame Liste kommen sichtbare Online-Datenbanken infrage, vorbehaltlich der Systemdatenbankauswahl. Eine wirksame Liste ist mit einem nicht-NULL @DatabaseNamePattern unzulässig. Fehlende ausdrücklich angeforderte Datenbanken können DATABASE_UNAVAILABLE-Warnungen erzeugen. Ungültige Eingaben führen zu INVALID_PARAMETER. Bei ausgelassenem Argument gilt der angegebene Default.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. Steuert, ob master, tempdb, model und msdb auswählbar sind: 0 schließt sie aus; 1 lässt sie zu. Bei ausdrücklich angeforderten, ausgeschlossenen Systemdatenbanken kann eine SYSTEM_DATABASE_EXCLUDED-Warnung entstehen. NULL führt zu INVALID_PARAMETER; ausgelassen gilt der Vorgabewert. Bei der Konvertierung in bit wird 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. Filtert Datenbankkandidaten mit LIKE-Syntax oder einem Präfix `like:`, `regex:` oder `regexi:`. Das Präfix wird ohne Beachtung der Groß-/Kleinschreibung erkannt. Äußere U+0020-Leerzeichen werden entfernt, der Mustertext nach dem Präfix aber nicht erneut getrimmt. NULL oder ausgelassen bedeutet kein Pattern; leerer Text oder leerer Präfixinhalt ist ungültig. LIKE verwendet SQL_Latin1_General_CP1_CS_AS. regex: verwendet Flag c, regexi: Flag i. Regex erfordert SQL Server 2025 oder neuer und Compatibility Level 170 in der Installationsdatenbank; andernfalls liefert die Kandidatenvorbereitung UNAVAILABLE_FEATURE. Das Pattern filtert die Kandidatenliste nach deren Ermittlung. Fehlerhafte Regex-Syntax wird nicht vorab validiert und kann bei der Auswertung als SQL-Fehler auftreten. Jedes nicht-NULL Pattern ist mit einer wirksamen @DatabaseNames-Liste unzulässig. Bei ausgelassenem Argument gilt der angegebene Default.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. Bestätigt ein Gruppengate nur dann, wenn der aktuelle Katalogeintrag die tatsächlich verwendete Analyseklasse CATALOG_DEEP aktiviert hat und RequiresGroupGate=1 verlangt. 0 bestätigt nicht; 1 bestätigt dieses Gate, ersetzt aber weder die Freigabe des Analysepfads noch eine Scopebegrenzung. NULL führt auch ohne aktives Gate zu INVALID_PARAMETER; ausgelassen gilt 0. Bei der Konvertierung in bit wird 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. Ist das Gate aktiv und nicht bestätigt, endet die Vorbereitung mit HIGH_IMPACT_CONFIRMATION_REQUIRED, bevor Datenbankkandidaten ermittelt werden. Bei ausgelassenem Argument gilt der angegebene Default.

**@SchemaNames:** @SchemaNames nvarchar(max); Default: NULL. Exakte Schemanamen als bracket-aware Pipe-Liste mit denselben Regeln wie @DatabaseNames: `|` trennt außerhalb eckiger Klammern, `]]` maskiert `]`, äußere Elementleerzeichen werden entfernt, Rohsegmente dürfen höchstens 4000 UTF-16-Codeeinheiten lang sein und geparste einteilige PARSENAME-Namen höchstens 128 Zeichen umfassen. Die Prüfung ist keine vollständige SQL-Bezeichnergrammatik; leere oder fehlerhafte Elemente sowie case-sensitive Duplikate sind ungültig. NULL, leerer oder nur aus Leerzeichen bestehender Text beziehungsweise eine Liste ohne wirksame Namen schränkt das Schema nicht ein. Ein roher nicht-NULL-Wert ist unabhängig von der Normalisierung mit @SchemaNamePattern und mit jedem rohen nicht-NULL @FullObjectNames unzulässig. Bei ausgelassenem Argument gilt der angegebene Default.

**@SchemaNamePattern:** @SchemaNamePattern nvarchar(4000); Default: NULL. Schränkt die Schemanamen der aktuellen Tabellen mit LIKE oder `like:`, `regex:` beziehungsweise `regexi:` ein. Präfixerkennung ist nicht case-sensitiv; äußere U+0020-Leerzeichen werden entfernt, der Mustertext nicht erneut getrimmt; LIKE nutzt SQL_Latin1_General_CP1_CS_AS. NULL oder ausgelassen bedeutet kein Pattern; leerer Text oder leerer Präfixinhalt ist ungültig. regex: verwendet Flag c, regexi: Flag i. Bei Regex wird SQL Server 2025+ zunächst global geprüft; fehlt diese Version, lautet der globale Status UNAVAILABLE_VERSION. Danach muss jedes Zieldatenbank-Compatibility-Level mindestens 170 betragen; inkompatible Datenbanken erhalten UNAVAILABLE_FEATURE als Datenbankstatus und begrenzen das Gesamtergebnis auf AVAILABLE_LIMITED. Regex-Auswertungsfehler werden je Datenbank abgefangen. Ungültiges Pattern oder ein roher nicht-NULL-Wert für @SchemaNames führt zu INVALID_PARAMETER. Bei ausgelassenem Argument gilt der angegebene Default.

**@ObjectNames:** @ObjectNames nvarchar(max); Default: NULL. Exakte Namen aktueller Tabellen als bracket-aware Pipe-Liste mit denselben Regeln wie @SchemaNames: `|` trennt außerhalb eckiger Klammern, `]]` maskiert `]`, äußere Elementleerzeichen werden entfernt, Rohsegmente sind auf 4000 UTF-16-Codeeinheiten und geparste einteilige PARSENAME-Namen auf 128 Zeichen begrenzt. Die Prüfung ersetzt keine vollständige SQL-Bezeichnergrammatik; leere oder ungültige Elemente sowie case-sensitive Duplikate sind unzulässig. NULL, leerer oder nur aus Leerzeichen bestehender Text beziehungsweise eine Liste ohne wirksame Namen schränkt die Objektnamen nicht ein. Ein roher nicht-NULL-Wert ist unabhängig von der Normalisierung mit @ObjectNamePattern und mit jedem rohen nicht-NULL @FullObjectNames unzulässig. Bei ausgelassenem Argument gilt der angegebene Default.

**@ObjectNamePattern:** @ObjectNamePattern nvarchar(4000); Default: NULL. Schränkt die Namen aktueller Tabellen mit LIKE oder `like:`, `regex:` beziehungsweise `regexi:` ein. Präfixerkennung ist nicht case-sensitiv; äußere U+0020-Leerzeichen werden entfernt, der Mustertext nicht erneut getrimmt; LIKE nutzt SQL_Latin1_General_CP1_CS_AS. NULL oder ausgelassen bedeutet kein Pattern; leerer Text oder leerer Präfixinhalt ist ungültig. regex: verwendet Flag c, regexi: Flag i. Bei Regex wird SQL Server 2025+ zunächst global geprüft; fehlt diese Version, lautet der globale Status UNAVAILABLE_VERSION. Danach muss jedes Zieldatenbank-Compatibility-Level mindestens 170 betragen; inkompatible Datenbanken erhalten UNAVAILABLE_FEATURE als Datenbankstatus und begrenzen das Gesamtergebnis auf AVAILABLE_LIMITED. Regex-Auswertungsfehler werden je Datenbank abgefangen. Ungültiges Pattern oder ein roher nicht-NULL-Wert für @ObjectNames führt zu INVALID_PARAMETER. Bei ausgelassenem Argument gilt der angegebene Default.

**@FullObjectNames:** @FullObjectNames nvarchar(max); Default: NULL. Bracket-aware Pipe-Liste mit optional qualifizierten Objektbezügen in den Formen Objekt, Schema.Objekt oder Datenbank.Schema.Objekt; bei drei Teilen ist ein Schema erforderlich, vierteilige Namen sind ungültig. PARSENAME liefert die Bestandteile 1 bis 3; die Prüfung ist keine vollständige SQL-Bezeichnergrammatik. `|` trennt außerhalb eckiger Klammern, `]]` maskiert `]`, äußere Elementleerzeichen werden entfernt. Leere/fehlerhafte Elemente, Rohsegmente über 4000 UTF-16-Codeeinheiten und case-sensitive doppelte Tupel sind ungültig. NULL, leerer oder nur aus Leerzeichen bestehender Text bedeutet keinen Full-Object-Filter; ausgelassen entspricht NULL. ItemOrdinal bewahrt die Eingabereihenfolge in der Hilfstabelle, sortiert aber die Ausgabe nicht; die Einträge werden als Alternativen geprüft. Ohne Datenbankbestandteil kann ein Eintrag in jeder ausgewählten Datenbank passen; angegebene Datenbank und Schema sowie der Objektname müssen jeweils übereinstimmen. Ein roher nicht-NULL-Wert für @FullObjectNames ist mit jedem rohen nicht-NULL @SchemaNames- oder @ObjectNames-Wert unzulässig, auch wenn einer davon leer ist. Schema- und Objekt-Patterns dürfen kombiniert werden; ihre Filter werden zusätzlich angewendet und verengen den Scope. Bei ausgelassenem Argument gilt der angegebene Default.

**@NurProblematisch:** @NurProblematisch bit; Default: 0. 0 gibt alle Findings und Detailobjekte aus; 1 behält nur WARN-Findings, Temporal-Tabellen mit AssessmentStatus REVIEW und deren zugehörige History-Indexzeilen. NULL führt zu INVALID_PARAMETER; ausgelassen gilt 0. Bei der Konvertierung in bit wird 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. Die Filterung erfolgt nach Inventur und Findingsberechnung und verringert die vorgelagerten Katalogabfragen nicht. Datenbank-/Quellenstatus sowie zuvor ermittelte Inventur- und Findingzähler bleiben verfügbar. Bei ausgelassenem Argument gilt der angegebene Default.

**@HistorySizeWarnMb:** @HistorySizeWarnMb decimal(19,2); Default: 10240. Nichtnegativer Schwellenwert in MB für die approximative reservierte History-Größe. Erreicht oder überschreitet HistoryReservedMb den Wert, entsteht ein INFO-Kontext-Finding, kein WARN. Bei 0 kann jeder verfügbare nichtnegative Messwert diese Informationsschwelle erreichen. NULL oder ein negativer Wert führt zu INVALID_PARAMETER; ausgelassen gilt der Vorgabewert. @NurProblematisch=1 entfernt dieses INFO-Finding, da der Filter nur WARN-Findings behält. Die Seitenwerte sind approximativ und umfassen Tabellen- und Indexspeicher; der Schwellenwert löst keine automatische Kapazitätsmaßnahme aus. Bei ausgelassenem Argument gilt der angegebene Default.

**@HistoryRowsWarn:** @HistoryRowsWarn bigint; Default: 10000000. Nichtnegativer Schwellenwert für die approximative Zeilenzahl der History-Tabelle. Erreicht oder überschreitet HistoryRowsApprox den Wert, entsteht ein INFO-Kontext-Finding, kein WARN. Bei 0 kann jeder verfügbare nichtnegative Zählerwert diese Informationsschwelle erreichen. NULL oder ein negativer Wert führt zu INVALID_PARAMETER; ausgelassen gilt der Vorgabewert. @NurProblematisch=1 entfernt dieses INFO-Finding, da der Filter nur WARN-Findings behält. Der Zähler beweist weder Wachstum noch Alter oder erfolgreichen Cleanup. Bei ausgelassenem Argument gilt der angegebene Default.

**@HistoryToCurrentRatioWarn:** @HistoryToCurrentRatioWarn decimal(19,4); Default: 10. Positiver Schwellenwert für HistoryRowsApprox geteilt durch CurrentRowsApprox. NULL oder ein Wert <=0 führt zu INVALID_PARAMETER; ausgelassen gilt der Vorgabewert. Das Verhältnis wird nur berechnet, wenn CurrentRowsApprox > 0 und CurrentIsMemoryOptimized=0 ist; sonst bleibt es NULL. Erreicht das Verhältnis den Schwellenwert und erreicht HistoryReservedMb zugleich @MinHistoryMbForRatioWarn, entsteht ein INFO-Kontext-Finding, kein WARN. @NurProblematisch=1 entfernt dieses INFO-Finding, da der Filter nur WARN-Findings behält. Das approximative Verhältnis belegt keine angemessene Retention-Tiefe. Bei ausgelassenem Argument gilt der angegebene Default.

**@MinHistoryMbForRatioWarn:** @MinHistoryMbForRatioWarn decimal(19,2); Default: 100. Nichtnegative Mindestgröße der approximativ reservierten History in MB, die vor einem INFO-Kontext-Finding zum History/Current-Zeilenverhältnis erreicht sein muss. Bei 0 entfällt diese Mindestgröße. NULL oder ein negativer Wert führt zu INVALID_PARAMETER; ausgelassen gilt der Vorgabewert. Der Wert wird zusammen mit @HistoryToCurrentRatioWarn ausgewertet und erzeugt kein eigenes Finding. Bei ausgelassenem Argument gilt der angegebene Default.

**@MaxZeilen:** @MaxZeilen int; Default: 2000. Begrenzt die jeweilige anwendbare Detail- und Findings-Auswahl. Positive Werte begrenzen die bereits materialisierten Ausgaben: Findings werden nach WARN zuerst und dann FindingOrdinal geordnet; Temporal-Tabellen nach REVIEW zuerst, anschließend nach HistoryReservedMb absteigend und Namen; History-Indizes nach Datenbank, Current-Objekt und IndexId. NULL oder 0 bedeutet unbegrenzt; negative Werte führen zu INVALID_PARAMETER. Die Grenze reduziert weder die vorangehende Inventur noch Quellenabfragen oder Findingsberechnung. Sie kann Zeilen einer nichtleeren Quelle aus der sichtbaren Ausgabe ausschließen. Bei ausgelassenem Argument gilt der angegebene Default.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Zeitlimit der datenbanklokalen Child-Batches in Millisekunden, einschließlich 0 bis 60000. 0 bedeutet NOWAIT; positive Werte legen die Wartezeitgrenze des Child-Batches fest. NULL oder ein Wert außerhalb des Bereichs führt zu INVALID_PARAMETER. Das Limit gilt nicht für das vorherige TABLE-Ziel-Preflight oder sämtliche Frameworkarbeiten. Lokale TempDB-Anlage hat eigenen Sperrschutz; der SET-Wert eines untergeordneten Batches endet mit dessen Rückkehr. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Ausgabeart nach Entfernen äußerer Leerzeichen und Umwandlung in Großbuchstaben. Zulässige Werte: CONSOLE liefert eine beschriftete Findings-Ansicht samt verständlicher Leer-Ausgabe; RAW liefert sechs Resultsets in der Reihenfolge Modulmetadaten, Datenbankstatus, Quellenstatus, Findings, Temporal-Tabellen und History-Indizes; TABLE schreibt ausschließlich `findings` in die geprüfte lokale Ziel-Temp-Tabelle; NONE liefert keine Daten-Resultsets. NULL wird zu leerem Text und führt zu INVALID_PARAMETER; ausgelassen gilt CONSOLE. Andere Werte sind ungültig. Bei TABLE wird das Ziel vor der Hilfe geprüft; Fehler können 51011 auslösen. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. JSON-Zuordnung des einzigen Resultsets `findings` zu einer lokalen # Temp-Tabelle des Aufrufers. Bei TABLE muss der Wert ein gültiges, nichtleeres JSON-Objekt sein; NULL, leerer oder nur aus Leerzeichen bestehender Text, ungültiges JSON, ein falscher Schlüssel, Duplikate, Nicht-String-Werte oder ein unzulässiges Ziel können beim Preflight 51011 auslösen. Das Ziel muss in der Aufrufersitzung existieren, leer sein, genau eine Seed-Spalte besitzen, genau einen lokalen # Namen (kein ##) mit höchstens 116 Zeichen verwenden und darf nicht mit dem reservierten Präfix #Monitor beginnen. Bei anderer Ausgabeart sind NULL/Leertext zulässig; nichtleerer Text löst vor der Hilfe 51011 aus. Ausgelassen entspricht NULL, was bei TABLE kein gültiges Mapping bereitstellt. TABLE schreibt nur Findings; JSON kann meta, databaseStatus, sourceStatus, findings, temporalTables und historyIndexes enthalten. Der Schlüssel findings muss exakt geschrieben sein und bezeichnet Prüfhinweise mit Evidenz, Grenzen und möglicher Gegenprüfung. Doppelte Schlüssel werden binär, doppelte Ziele case-insensitiv geprüft; das reservierte Präfix #Monitor ist ebenfalls case-insensitiv gesperrt. Writerablehnungen nach erfolgreichem Preflight können 51010 werfen. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 0 deaktiviert die JSON-Erzeugung; @Json bleibt NULL. 1 erzeugt das Dokument im @Json-OUTPUT-Parameter. NULL führt zu INVALID_PARAMETER; ausgelassen gilt 0. Bei der Konvertierung in bit wird 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. Die Hilfe kehrt nach dem Leeren von @Json vor einer Erzeugung zurück. Ein TABLE-Preflightfehler kann vor der Zuweisung der Diagnose-OUTPUTs auftreten. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Dokument; zum Empfang eine Aufrufervariable des deklarierten SQL-Typs mit OUTPUT binden. Der Parameter wird beim Eintritt geleert und bleibt NULL, wenn JSON deaktiviert ist oder die Hilfe zurückkehrt. Bei aktivierter Erzeugung enthält das Dokument meta sowie die Arrays databaseStatus, sourceStatus, findings, temporalTables und historyIndexes; Arrays können leer sein. Findings und Detailarrays folgen den jeweiligen Filter- und Limitregeln; Status- und Inventurzähler behalten ihren breiteren Scope. Das TABLE-Preflight erfolgt vor der Diagnose-OUTPUT-Zuweisung. Der TABLE-Writer läuft nach JSON- und Diagnosezuweisung; sein Fehler wird nicht in diesen Diagnosen abgebildet, und die Quellreihenfolge belegt nicht, ob OUTPUT-Werte nach dem Fehler beim Aufrufer ankommen. Bei ausgelassenem Argument gilt der angegebene Default.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 1 gibt bei abschließendem Status außer AVAILABLE und NOT_APPLICABLE eine Meldung niedriger Severity aus; 0 unterdrückt diese Meldung. NULL führt zu INVALID_PARAMETER; ausgelassen gilt 1. Bei der Konvertierung in bit wird 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. Strukturierte Resultsets und OUTPUT-Parameter werden davon nicht gesteuert. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit; Default: 0. 1 druckt kurze Hinweise zu Zweck, Quellen, Filterausschlüssen, Schwellen, Ausgabearten und Datenzugriff und kehrt danach vor der Analyse zurück. 0 führt die normale Verarbeitung aus. NULL wird nicht ausdrücklich abgelehnt und führt in den normalen Pfad, da nur auf Gleichheit mit 1 geprüft wird; ausgelassen gilt 0. Bei der Konvertierung in bit wird 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. TABLE-Zielprüfung und ein möglicher Fehler 51011 geschehen vor der Hilfebehandlung. Die Hilfe lässt @Json am Eintritt auf NULL, kehrt aber vor der Zuweisung der vier Diagnose-OUTPUTs zurück; deren Aufrufervariablen bleiben unverändert. Bei ausgelassenem Argument gilt der angegebene Default.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT-Status; zum Empfang eine Aufrufervariable des deklarierten SQL-Typs mit OUTPUT binden. AVAILABLE bedeutet abgeschlossene Analyse ohne globale Partialität und ohne WARN-Finding. AVAILABLE_WITH_FINDING bedeutet vollständige Analyse mit mindestens einem WARN-Finding. AVAILABLE_LIMITED bedeutet, dass bei sonst verfügbarem Ergebnis mindestens eine Datenbank oder Quelle partiell fehlte; dieser Status hat Vorrang vor Findings. NOT_APPLICABLE bedeutet, dass keine Datenbankkandidaten verfügbar waren oder im sichtbaren Scope keine Temporal-Funktion verwendet wird. INVALID_PARAMETER kennzeichnet einen ungültigen Eingabeparameter oder Filtervertrag. UNAVAILABLE_VERSION kennzeichnet, dass für Schema-/Objekt-Regex die erforderliche SQL-Server-Version fehlt. UNAVAILABLE_FEATURE kann aus der Datenbankkandidaten-Vorbereitung kommen, wenn Datenbankname-Regex wegen SQL-Server-Version oder Compatibility Level 170 der Installationsdatenbank nicht verfügbar ist. HIGH_IMPACT_CONFIRMATION_REQUIRED bedeutet, dass das aktive Gruppengate von CATALOG_DEEP nicht bestätigt wurde; DENIED_GROUP bedeutet, dass die aktuelle Pfadfreigabe fehlt. INTERNAL_ERROR kennzeichnet eine nicht passend prüfbare interne Temp-Tabelle in der Namens-/Kandidatenvorbereitung. TIMEOUT bedeutet dort den abgefangenen Sperrfehler 1222; DENIED_PERMISSION bezeichnet die dort abgefangenen Berechtigungsfehler 229, 262, 297, 300, 371 oder 916; ERROR_HANDLED steht dort für einen anderen abgefangenen SQL-Fehler. Ungültige Eingaben werden zuerst behandelt; bei verfügbarer Analyse gilt für den Abschluss die Priorität AVAILABLE_LIMITED, dann AVAILABLE_WITH_FINDING, dann NOT_APPLICABLE, sonst AVAILABLE. Der Datenbankname-Regexpfad prüft SQL-Version und Framework-Installations-Compatibility-Level vor der Kandidatenauswahl; Schema-/Objekt-Regex prüft zunächst die SQL-Version und danach jedes Ziel-Compatibility-Level. Ein TABLE-Preflightfehler tritt vor Diagnosezuweisung auf. Der Writer wird danach aufgerufen; sein Fehler wird nicht in diesen Status übersetzt, und Quellreihenfolge allein belegt nicht, ob OUTPUT-Werte trotz Fehler beim Aufrufer ankommen. Bei Hilfe bleibt die Aufrufervariable unverändert. Bei ausgelassenem Argument gilt der angegebene Default.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. OUTPUT-Partialitätskennzeichen; zum Empfang eine Variable des deklarierten Typs mit OUTPUT binden. Ungültige Parameter und Versionsgates setzen 1. Jedes nicht-AVAILABLE-Ergebnis von USP_PrepareNameFilters oder USP_PrepareDatabaseCandidates setzt ebenfalls 1; dies umfasst interne, Berechtigungs-, Timeout-, Gruppen- und Bestätigungsfehler dieser Vorbereitung. Bei ansonsten verfügbarer Analyse führen partielle Datenbank-/Quellenergebnisse zu 1. Ohne diese Bedingungen bleibt das Kennzeichen 0, auch beim abschließenden NOT_APPLICABLE. Hilfe und TABLE-Preflight liegen vor der Diagnosezuweisung und lassen den Eingangswert unverändert. Der Writer läuft danach; sein geworfener Fehler wird nicht in diese Diagnose übersetzt. Für einen geworfenen Fehler ist keine reguläre OUTPUT-Übertragung qualifiziert. Bei ausgelassenem Argument gilt der angegebene Default.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT-Fehlernummer; zum Empfang eine Aufrufervariable des deklarierten SQL-Typs mit OUTPUT binden. Empfangen wird eine bereits ausgewählte Fehlernummer oder, falls keine vorliegt, die kleinste ErrorNumber aus partiellen SourceStatus-Zeilen; andernfalls bleibt der Wert NULL. Hilfe und ein TABLE-Preflightfehler treten vor der Diagnosezuweisung auf. Der Writer läuft danach; sein Fehler wird hier nicht abgebildet und die Quellreihenfolge belegt keine Weitergabe der OUTPUT-Werte nach einem Fehler. Die Nummernauswahl erfolgt unabhängig von der Textauswahl: MIN(ErrorNumber) und MIN(ErrorMessage) können aus verschiedenen Quellenzeilen stammen. Das ausgegebene Paar bezeichnet daher nicht zwingend dasselbe Quellenereignis. Bei ausgelassenem Argument gilt der angegebene Default.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT-Fehlertext; zum Empfang eine Aufrufervariable des deklarierten SQL-Typs mit OUTPUT binden. Empfangen wird der Text eines globalen Gates/Fehlers oder, falls ausgewählt, einer partiellen Quellenfehlermeldung; NULL bedeutet, dass kein globaler/Quellenfehlertext ausgewählt wurde, nicht dass jede Quelle separat verifiziert ist. Hilfe und ein TABLE-Preflightfehler treten vor der Diagnosezuweisung auf. Der Writer läuft danach; sein Fehler wird hier nicht abgebildet und die Quellreihenfolge belegt keine Weitergabe der OUTPUT-Werte nach einem Fehler. Der Text wird getrennt von der Nummer ausgewählt, jeweils über einen eigenen MIN-Wert bei zuvor fehlender Diagnose. Nummer und Meldung können deshalb aus verschiedenen Quellenzeilen stammen und bilden kein garantiert zusammengehöriges Fehlerpaar. Bei ausgelassenem Argument gilt der angegebene Default.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| findings | 1 | 1 | [FindingOrdinal] bigint IDENTITY(1,1) NOT NULL , [DatabaseName] sysname NULL , [SchemaName] sysname NULL , [ObjectName] sysname NULL , [HistorySchemaName] sysname NULL , [HistoryTableName] sysname NULL , [Severity] varchar(16) NOT NULL , [Confidence] varchar(16) NOT NULL , [FindingCode] varchar(120) NOT NULL , [MetricName] varchar(80) NOT NULL , [MetricValue] decimal(38,4) NULL , [ThresholdValue] decimal(38,4) NULL , [Evidence] nvarchar(1000) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL , [RecommendedNextCheck] nvarchar(1000) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_TemporalAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Keine Zeilen aus aktuellen oder historischen Benutzertabellen, keine DBCC-Prüfung und keine DDL. Katalog- und Größenmetadaten beweisen weder Periodenüberlappungsfreiheit noch erfolgreichen Cleanup. Nach SYSTEM_VERSIONING=OFF getrennte Tabellen sind ohne erhaltene Zuordnung nicht zuverlässig als ehemaliges Paar erkennbar.

MEDIUM; Katalogabfragen und approximative Partitionsstatistik.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_TemporalAnalysis
Version      : 1.0.0
Stand        : 2026-07-17
Typ          : Stored Procedure
Zweck        : Die Procedure analysiert sichtbare systemversionierte Temporal Tables,
               Retention-Konfiguration, ungefähre Kapazität und die
               Perioden-Indexabdeckung ihrer History-Tabellen.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.tables, sys.schemas, sys.periods, sys.columns, sys.databases,
               sys.indexes, sys.index_columns und sys.dm_db_partition_stats.
Methodik     : Der Framework-Caller fordert CATALOG_DEEP an. Nach dessen
               aktueller Freigabe und nötigem Gruppengate werden Feature-Gate
               und Quellen je Datenbank best effort ausgewertet. Erkennbare
               Teilfehler verwerfen andere zugängliche Evidenz nicht.
Grenzen      : Keine Zeilen aus aktuellen oder historischen Benutzertabellen,
               keine DBCC-Prüfung und keine DDL. Katalog- und Größenmetadaten
               beweisen weder Periodenüberlappungsfreiheit noch erfolgreichen
               Cleanup. Nach SYSTEM_VERSIONING=OFF getrennte Tabellen sind ohne
               erhaltene Zuordnung nicht zuverlässig als ehemaliges Paar
               erkennbar.
Kosten       : MEDIUM; Katalogabfragen und approximative Partitionsstatistik.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_TemporalAnalysis
Die Procedure führt eine rein lesende Tiefenanalyse sichtbarer systemversionierter Temporal Tables und zugeordneter History-Tabellen durch.
Geprüft werden Katalogzuordnung, Periodenmetadaten, Retention-Schalter, approximative Größe/Zeilen und History-Indexreihenfolge End/Start.
Exakte Namenslisten und Pattern derselben Eigenschaft sind gegenseitig exklusiv; Pattern: LIKE, regex: oder regexi:.
Grenzwerte erzeugen Prüfkontext, keine automatische Retention-, DDL- oder Kapazitätsentscheidung.
Es werden keine Zeilen aus aktuellen oder historischen Benutzertabellen gelesen und keine zeitliche Datenkonsistenz behauptet.
Die Analysebeispiele verwenden eine ausdrückliche Bestätigung und synthetische Namen. Ersetzen Sie den Datenbank-/Objektnamen und prüfen Sie vor dem Aufruf Scope und CATALOG_DEEP-Freigabe.
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_TemporalAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];
CREATE TABLE [#TemporalAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_TemporalAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#TemporalAnalysis_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#TemporalAnalysis_HelpExample]; DROP TABLE IF EXISTS [#TemporalAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#TemporalAnalysis_HelpExample]; THROW; END CATCH;
```

