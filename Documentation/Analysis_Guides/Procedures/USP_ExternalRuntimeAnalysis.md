# [monitor].[USP_ExternalRuntimeAnalysis]

**Bereich:** Versionsadaptive Spezialanalysen<br>
**Zweck:** Analysiert Konfiguration, Katalogregistrierungen und aktuelle beziehungsweise gesampelte Betriebsevidenz externer SQL-Server-Runtimes.<br>
**Beobachtungsart:** Konfigurations-, Katalog-, Live- und Sample-Snapshot<br>
**Kostenklasse:** MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Sind External Languages, Libraries und der SQL-Server-Extensibility-Pfad konsistent sichtbar, und gibt es aktuelle Hinweise auf blockierte Requests, Poolgrenzen oder Ausführungsfehler?** Sie ist der Deep-Dive nach `USP_SpecialFeatureInventory`, wenn `EXTERNAL_RUNTIME` erkannt oder `EXTERNAL_SCRIPTS` konfiguriert ist. Der Standardpfad bleibt rein lesend und führt weder R-, Python-, Java-, C#- noch anderen externen Code aus.

Die Analyse trennt vier Evidenzklassen: Serverkonfiguration und Installationsproperty, datenbankbezogene Registrierungen, flüchtige Live-Requests sowie kumulative oder gesampelte Pool- und Counterwerte. Diese Klassen dürfen nicht zu einem pauschalen Gesundheitsurteil verschmolzen werden. Eine registrierte Sprache beweist keine installierte Runtime; ein laufender Launchpad-Service beweist keine erfolgreiche Libraryinitialisierung; ein leerer Request-Snapshot beweist keine historische Inaktivität.

## Nicht beantwortete Fragen

Die Procedure beantwortet nicht, ob ein konkretes Script fachlich korrekt ist, ob ein Package außerhalb des SQL-Katalogs vollständig installiert ist oder ob Betriebssystem-, Container- und Netzwerkabhängigkeiten funktionieren. Sie liest keine Script- oder Batchtexte, Parameter, Environment Variables, Binärinhalte, Libraryinhalte oder Dateipfade. Sie startet keinen Testrequest und erzeugt deshalb keinen synthetischen Verfügbarkeitsnachweis.

Die standardmäßige Ausgabe enthält keine Login-, Host-, Programm- oder External-Worker-Identität. `@MitSitzungskontext = 1` ist ein ausdrücklicher Privacy-Opt-in. `@MitDateimetadaten = 1` liest nur Dateiname und Plattform der Language Extension beziehungsweise die Libraryplattform; Inhalte und Pfade bleiben ausgeschlossen. Ownernamen werden nur mit `@MitBerechtigungsanalyse = 1`, bestätigtem High-Impact-Pfad und der zugehörigen Policy gelesen.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ExternalRuntimeAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @SampleSeconds = 0,
      @MitDateimetadaten = 0,
      @MitBerechtigungsanalyse = 0,
      @MitSitzungskontext = 0,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch. Beginnen Sie ohne Sampling und ohne Privacy- oder Katalog-Opt-ins. Erst wenn die Momentaufnahme einen konkreten Runtime- oder Poolhinweis enthält, ist ein kurzes Sample sinnvoll.

## Parameterverträge

Jeder Eintrag erklärt den tatsächlichen Parametervertrag einschließlich NULL-Verhalten und der erlaubten Werte.

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | Default: `NULL` | NULL, leerer oder nur aus Leerzeichen bestehender Wert bedeutet keine Namensbeschränkung. Sonst Pipe-Liste einteiliger Datenbanknamen; \| trennt außerhalb eckiger Klammern, ]] maskiert darin ]. Äußere Elementleerzeichen werden entfernt. Ein Rohsegment darf vor dem Trimmen höchstens 4000 UTF-16-Codeeinheiten umfassen; Elemente müssen gültige einzelne PARSENAME-Namen bis 128 Zeichen sein. Leere Elemente, fehlerhafte Klammerung, Mehrfachnamen und exakt doppelte gültige Namen sind ungültig. Vergleich erfolgt case-sensitiv. Fehlende, nicht online befindliche, nicht zugreifbare oder ohne Systemdatenbank-Opt-in ausgeschlossene gültige Namen werden als Datenbankwarnung geführt und können den Lauf partiell machen. Exakte Namensliste und @DatabaseNamePattern sind exklusiv. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@SystemdatenbankenEinbeziehen` | `bit` | Default: `0` | 0 schließt database_id 1 bis 4 aus; 1 schließt sie ein, wenn sie sichtbar, online und zugreifbar sind. NULL ist im normalen Lauf ungültig. Der Parameterwert 0 bedeutet aus und 1 bedeutet ein; bei numerischer Übergabe wird 0 zu 0 und jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Das Opt-in setzt keine Rechte und macht eine nicht verfügbare Datenbank nicht verfügbar. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | Default: `NULL` | NULL bedeutet kein Pattern. Sonst werden äußere Leerzeichen getrimmt und das Präfix ohne Beachtung der Großschreibung erkannt: regexi: bedeutet Regex mit Flag i, regex: Regex mit Flag c, like: SQL-LIKE; ohne Präfix gilt ebenfalls LIKE. Der Rest nach einem Präfix wird nicht erneut getrimmt und darf nicht leer sein. LIKE wird case-sensitiv auf den Datenbanknamen angewandt. Regex-Syntax wird nicht vorab validiert; Regex erfordert SQL Server 2025 (Major 17) und Compatibility Level 170 in der Framework- beziehungsweise Installationsdatenbank. Die Compatibility-Level-Prüfung für Zieldatenbanken gehört zum separaten @LanguageNamePattern-Pfad. Leere Eingaben und leere Präfixinhalte sind ungültig. Exakte Namensliste und Pattern sind exklusiv. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@HighImpactConfirmed` | `bit` | Default: `0` | 0 bestätigt keinen High-Impact-Aufruf; 1 bestätigt ihn. NULL ist im normalen Lauf ungültig. Die Bestätigung ist keine Berechtigung. Der Basispfad verwendet EXTERNAL_RUNTIME_CURRENT mit RequiresGroupGate=0. Nur wenn @MitBerechtigungsanalyse=1, wird zusätzlich CATALOG_DEEP geprüft; diese Klasse verlangt Bestätigung 1 und eine aktuelle Policyfreigabe. 0 bedeutet keine Bestätigung und 1 bedeutet Bestätigung; bei numerischer Übergabe wird 0 zu 0 und jeder numerische Wert ungleich 0 zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@LanguageNames` | `nvarchar(max)` | Default: `NULL` | NULL bedeutet keine Language-Einschränkung. Sonst eine Pipe-Liste einteiliger SQL-Namen angeben; der Parameter wird direkt durch TVF_ParseSqlNameList geprüft. \| trennt außerhalb von [...], ]] maskiert darin ], Rand-Leerzeichen an Elementen werden entfernt. Rohsegmentgrenze 4000 UTF-16-Codeeinheiten, Namensgrenze 128 Zeichen. Leere Elemente, falsche Klammerung und mehrteilige Namen sind ungültig. Anders als @DatabaseNames bedeuten Leertext und Leerraumelemente keinen fehlenden Filter, sondern ungültige Eingabe. Doppelte Namen bleiben im Parser, duplizieren aber wegen des EXISTS-Abgleichs keine Ergebniszeilen. Der Language-Abgleich ist case-sensitiv. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@LanguageNamePattern` | `nvarchar(4000)` | Default: `NULL` | NULL bedeutet kein Pattern. Ansonsten gelten die Präfixe regexi: (Regex-Flag i), regex: (Regex-Flag c), like: (SQL-LIKE) sowie unpräfigiertes LIKE; Präfixerkennung ist case-insensitiv, nur äußerer Leerraum wird vorab getrimmt. LIKE-Vergleich ist case-sensitiv. Das Pattern filtert Languages, Libraries, passende aktive Requests und Execution Stats. Leerer Eingang oder leerer Präfixinhalt ist ungültig. Regex erfordert SQL Server 2025 (Major 17), Compatibility Level 170 in Framework- und Zieldatenbanken; Syntaxfehler werden erst beim Ausführen erkannt. Exklusiv zu @LanguageNames. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@SampleSeconds` | `tinyint` | Default: `0` | 0 liefert einen Momentaufnahmepunkt ohne WAITFOR oder Deltas. Jeder Wert von 1 bis 60 einschließlich fordert T1/T2-Messpunkte mit WAITFOR DELAY für die angeforderte Intervallzeit an; SQL-Abfragezeit kommt hinzu. NULL und Werte über 60 sind ungültig. Pools, Performance Counter und Execution Stats sind serverweit; der Languagefilter beschränkt nicht alle serverweiten Zugriffe. Pooldeltas verlangen gleiche statistics_start_time und pool_version sowie nicht fallende Zähler; Reset, Versionswechsel, Rückgang oder fehlendes T2 verwerfen Deltas. Execution-Stats- und Counterdeltas werden bei Reset/Rückgang oder fehlendem T2 nicht ausgewiesen. Countertyp 65792 liefert RAW_SNAPSHOT; 272696320 und 272696576 liefern bei positivem und gültigem Sample RATE_PER_SECOND. 537003264 ist als FRACTION_DELTA_PERCENT und 1073874176 als AVERAGE_DELTA_RATIO klassifiziert, aber diese Procedure übergibt keine Basiszähler; deshalb bleibt ihre Metrik NULL und der Helper meldet BASE_COUNTER_MISSING, wenn ein gültiges Sample vorliegt. Weitere Typen bleiben RAW_UNINTERPRETED. Tatsächliche Messzeitstempel und Deltas sind keine atomare Messung, kein SLA und kein Nachweis externer Prozess-CPU. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MitDateimetadaten` | `bit` | Default: `0` | 0 lässt Datei-Metadatenabfragen aus. 1 ergänzt für Language Files Dateiname und Plattform sowie für Library Files die Plattform. Datei- und Libraryinhalte, Pfade, Parameterspalten und Environment Variables werden nicht gelesen; Metadaten beweisen keine Installation oder Startfähigkeit. NULL ist im normalen Lauf ungültig. Das Opt-in aktiviert nicht CATALOG_DEEP und kein High-Impact-Gate; fehlende Rechte erscheinen als Quellenstatus. 0 wird zu 0 konvertiert, jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MitBerechtigungsanalyse` | `bit` | Default: `0` | 0 lässt Ownernamen aus. 1 ergänzt sichtbare database_principals-Namen der registrierten Languages und Libraries. Vor dem Katalogzugriff wird zusätzlich CATALOG_DEEP policygeprüft; diese Klasse erfordert @HighImpactConfirmed=1 und eine aktuelle Freigabe. Bestätigung allein erlaubt den Zugriff nicht. Eine Gateverweigerung stoppt den fachlichen Pfad. NULL ist im normalen Lauf ungültig; Metadatenrechte können die Sichtbarkeit begrenzen. 0 wird zu 0 konvertiert, jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MitSitzungskontext` | `bit` | Default: `0` | 0 projiziert Login, Host, Clientprogramm und External Worker Account für activeRequests als NULL. 1 ergänzt diese vier Felder aus dm_exec_sessions beziehungsweise dm_external_script_requests für sichtbare aktive Requests; keine historischen Identitäten. NULL ist im normalen Lauf ungültig. DMV-Rechte und Sichtbarkeit gelten unabhängig vom Opt-in. 0 wird zu 0 konvertiert, jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@NurProblematisch` | `bit` | Default: `0` | 0 übernimmt alle Findings-Schweregrade; 1 filtert ausschließlich Findings mit Severity=WARN. Dasselbe Prädikat gilt für CONSOLE, RAW, TABLE und JSON. Es filtert keine Katalog-, Request-, Pool-, Counter-, Quellenstatus-, Datenbankstatus- oder Warning-Ausgabe. NULL ist im normalen Lauf ungültig. 0 wird zu 0 konvertiert, jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MaxZeilen` | `int` | Default: `100` | NULL oder 0 bedeutet unbegrenzt. Positive Werte begrenzen nach vollständiger Materialisierung und jeweiliger Sortierung Findings, Languages, Libraries, activeRequests, externalPools, Execution Stats und Performance Counters; configuration, databaseStatus, sourceStatus und warnings sind nicht begrenzt. Findings werden nach @NurProblematisch gefiltert, WARN vor anderen Schweregraden sortiert und innerhalb dessen nach ursprünglichem FindingOrdinal begrenzt. Negative Werte setzen INVALID_PARAMETER; bei @JsonErzeugen=1 entsteht dennoch JSON mit Fehlerstatus. Die RESULTSET_TRUNCATED-Warnung zählt externalPools nicht, deshalb meldet eine alleinige Kürzung dieses Resultsets derzeit nicht zwingend eine Truncation. Ein positives Limit verringert nicht die vorgelagerte Quellarbeit. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@LockTimeoutMs` | `int` | Default: `0` | Zulässig sind 0 bis 60000 Millisekunden einschließlich. 0 setzt LOCK_TIMEOUT 0 und wartet bei blockierten fachlichen Zugriffen nicht. NULL oder andere Werte sind ungültig. Der gesetzte Wert gilt für den Lauf und die ursprüngliche Sitzungseinstellung wird danach wiederhergestellt. Isolierte Quelltimeouts erscheinen als Quellenstatus; nicht isolierte Timeouts ergeben global LOCK_TIMEOUT. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultSetArt` | `varchar(16)` | Default: `'CONSOLE'` | Zulässige Werte: CONSOLE rendert ein menschenlesbares Findingsresultset; RAW liefert zuerst Metadaten, danach configuration, databaseStatus, sourceStatus, findings, languages, libraries, activeRequests, externalPools, executionStats, performanceCounters und warnings in dieser Reihenfolge; TABLE schreibt ausschließlich findings in das lokale Ziel; NONE unterdrückt diese fachlichen Resultsets. Werte werden getrimmt und mit UPPER normalisiert. NULL oder andere Werte ergeben INVALID_PARAMETER. JSON ist unabhängig über @JsonErzeugen steuerbar. Nichtleeres @ResultTablesJson außerhalb TABLE löst 51011 vor dem Quellenzugriff aus. Leeres CONSOLE-Findingsresultat erzeugt eine verständliche Console-Zeile. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultTablesJson` | `nvarchar(max)` | Default: `NULL` | Nur mit @ResultSetArt=TABLE ist ein nichtleeres Mapping gültig. NULL, leer oder nur Leerzeichen ist kein Mapping; nichtleerer Text bei anderem ResultSetArt wirft 51011. Für die Procedure wird ein JSON-Objekt mit exakt kleingeschriebenem, case-sensitivem Schlüssel findings und JSON-String als Ziel erwartet. Das Ziel ist eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte. ##Temp, permanente Ziele, Präfix #Monitor (case-insensitiv) und Namen über 116 Zeichen sind unzulässig. Unbekannter/duplizierter Schlüssel, dupliziertes Ziel, falscher JSON-Werttyp, leeres Ziel oder ungültiges Ziel scheitert im vollständigen Preflight vor fachlichen Quellenzugriffen mit 51011. Erfolgreich schreibt der Helper die 13 findings-Spalten; späterer Writerfehler wirft 51010. Nach THROW sind OUTPUT-Übergaben nicht zugesichert. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@JsonErzeugen` | `bit` | Default: `0` | 0 erzeugt kein JSON und lässt @Json NULL. 1 erzeugt unabhängig von @ResultSetArt ein JSON-Objekt mit meta als Objekt sowie den Arrays configuration, databaseStatus, sourceStatus, findings, languages, libraries, activeRequests, externalPools, executionStats, performanceCounters und warnings. Leere Arrays sind []; NULL-Properties werden in der bestehenden FOR JSON PATH-Semantik ausgelassen. Auch bei INVALID_PARAMETER wird das JSON erzeugt, wenn 1 gewählt wurde. NULL ist im normalen Lauf ungültig. 0 wird zu 0 konvertiert, jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Json` | `nvarchar(max) OUTPUT` | Default: `NULL` | OUTPUT enthält bei @JsonErzeugen=1 das erzeugte JSON in einer nvarchar(max)-Variable, gebunden als @Json=@JsonVar OUTPUT; sonst bleibt es NULL. Es umfasst meta als Objekt und die Arrays configuration, databaseStatus, sourceStatus, findings, languages, libraries, activeRequests, externalPools, executionStats, performanceCounters und warnings; NULL-Properties sind ausgelassen. Beim Eintritt wird @Json auf NULL gesetzt. Beim frühen Hilfereturn bleibt es NULL. Vor Abschluss ausgelöste Fehler garantieren keine OUTPUT-Zustellung. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@PrintMeldungen` | `bit` | Default: `1` | 0 unterdrückt Statusmeldungen und den Hinweis RESULTSET_TRUNCATED. 1 sendet beide möglichen Meldungen per RAISERROR mit Severity 10 und NOWAIT; fachliche Resultsets und OUTPUT-Werte bleiben davon getrennt. NULL ist im normalen Lauf ungültig. 0 wird zu 0 konvertiert, jeder numerische Wert ungleich 0 wird zu 1 konvertiert. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Hilfe` | `bit` | Default: `0` | 1 gibt eingebaute PRINT-Hilfe aus und kehrt vor Parameterprüfung, Quellenzugriff, fachlichen Resultsets und OUTPUT-Zuweisung zurück; @Json wurde zuvor auf NULL gesetzt. 0 und NULL führen zum normalen Pfad, sofern dessen Eingaben gültig sind. Hilfe liefert keinen Status oder Daten-Resultset. 0 bedeutet aus und 1 bedeutet Hilfe; bei numerischer Übergabe wird 0 zu 0 und jeder numerische Wert ungleich 0 wird zu 1 konvertiert. NULL wird durch IF nicht als Hilfeaufruf behandelt. Die TABLE-Zielvorprüfung läuft davor und kann auch bei einem Hilfeaufruf Fehler 51011 auslösen. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | Default: `NULL` | OUTPUT liefert den globalen Laufstatus in einer varchar(40)-Variable, die mit @StatusCodeOut=@StatusVar OUTPUT gebunden wird; Quellen- und Datenbankstatus sind davon getrennt. AVAILABLE bedeutet Abschluss ohne Warn-Finding und ohne Partialität; AVAILABLE_WITH_FINDING meldet mindestens ein WARN-Finding; AVAILABLE_LIMITED meldet teilweise Auswertung durch Quelle, Datenbank oder Auswahlwarnung. FEATURE_DISABLED bedeutet deaktivierte Option bei sichtbarer Registrierungs- oder Execution-Stats-Evidenz; NOT_APPLICABLE bedeutet deaktivierte Option ohne diese sichtbare Evidenz. INVALID_PARAMETER meldet ungültige Eingaben; UNAVAILABLE_FEATURE unerfüllte Regexversions-/Compatibility-Voraussetzung. HIGH_IMPACT_CONFIRMATION_REQUIRED meldet fehlende Bestätigung für den aktivierten CATALOG_DEEP-Pfad; DENIED_GROUP fehlende Policyfreigabe. INTERNAL_ERROR wird übernommen, wenn der Datenbankvorbereitungshelfer einen Fehler seiner Temp-Tabellenprobe meldet; dies ist kein regulärer fachlicher Auswahlwert. Die Procedure setzt die Partialität und lässt diesen globalen Status bestehen. LOCK_TIMEOUT ist ein nicht isoliert abgefangener Locktimeout; ERROR_HANDLED ein sonstiger nicht isolierter Fehler. Quell-/Datenbankcodes wie DENIED_PERMISSION, SOURCE_UNAVAILABLE, SYSTEM_DATABASE_EXCLUDED und DATABASE_UNAVAILABLE bleiben separat. Bei @Hilfe=1 erfolgt keine Zuweisung; nach THROW, einschließlich 51011/51010, ist keine OUTPUT-Zustellung garantiert. Frühe Parameter-, Gate- und Helfercodes bleiben bestehen. Solange der Status AVAILABLE ist, haben partielle Quellen oder Datenbanken Vorrang vor WARN-Findings; danach wird bei deaktivierter External-Scripts-Option zwischen FEATURE_DISABLED und NOT_APPLICABLE anhand der sichtbaren Evidenz unterschieden. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@IsPartialOut` | `bit OUTPUT` | Default: `NULL` | OUTPUT liefert die Partialität in einer bit-Variablen, gebunden als @IsPartialOut=@PartialVar OUTPUT. 1 kennzeichnet eingeschränkte oder teilweise Auswertung, unter anderem AVAILABLE_LIMITED, ungültige Eingaben, nicht verfügbare Regexvoraussetzungen, Gateverweigerung und INTERNAL_ERROR des Kandidatenhelfers; sonst 0. Isolierte Quellenfehler fließen in die Partialitätsbewertung ein. Das Feld ist vom separat ausgewiesenen IsPartial pro Quelle und Datenbank zu unterscheiden. Bei @Hilfe=1 erfolgt keine Zuweisung; nach THROW ist keine OUTPUT-Zustellung garantiert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@ErrorNumberOut` | `int OUTPUT` | Default: `NULL` | OUTPUT liefert die Fehlernummer in einer int-Variablen, gebunden als @ErrorNumberOut=@ErrorNoVar OUTPUT. Enthalten ist ein nicht isoliert abgefangener SQL-Fehler oder, falls der globale Wert noch NULL ist, der kleinste ErrorNumber-Wert aus partiellen Quellen; sonst NULL. Validierungs- und Gatefehler können eine Meldung ohne SQL-Fehlernummer haben. Bei @Hilfe=1 erfolgt keine Zuweisung; nach THROW, einschließlich 51011/51010, ist keine OUTPUT-Zustellung garantiert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | Default: `NULL` | OUTPUT liefert die Fehlermeldung in einer nvarchar(2048)-Variable, gebunden als @ErrorMessageOut=@ErrorMsgVar OUTPUT. Enthalten ist die globale Fehlermeldung oder, falls noch keine vorhanden ist, der lexikalisch kleinste ErrorMessage-Wert einer partiellen Quelle; sonst NULL. Isolierte Details bleiben zusätzlich in sourceStatus und databaseStatus. Bei @Hilfe=1 erfolgt keine Zuweisung; nach THROW ist keine OUTPUT-Zustellung garantiert. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |

## Aufrufbeispiele zu den Parameterverträgen

Die Beispiele verwenden synthetische Namen, die durch einen ausdrücklich freigegebenen Scope ersetzt werden müssen. Sie installieren, aktivieren oder starten keine externe Runtime. Das Sampling-Beispiel wartet für ein gemeinsames Messintervall von einer Sekunde; tatsächliche Messabstände und Resetbedingungen bleiben maßgeblich. Der Berechtigungsbeispielaufruf bestätigt den zusätzlich angeforderten CATALOG_DEEP-Pfad ausdrücklich; Zugriffspolicy und Quellenberechtigungen werden weiterhin geprüft. Das TABLE-Beispiel verwendet eine Seedspalte und entfernt das Ziel auch im Fehlerfall.

```sql
EXEC [monitor].[USP_ExternalRuntimeAnalysis] @Hilfe=1;

EXEC [monitor].[USP_ExternalRuntimeAnalysis] @DatabaseNames=N'[ExampleDatabase]', @LanguageNames=N'[ExampleLanguage]', @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;

DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_ExternalRuntimeAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];

CREATE TABLE [#ExternalRuntimeAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ExternalRuntimeAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#ExternalRuntimeAnalysis_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#ExternalRuntimeAnalysis_HelpExample]; DROP TABLE IF EXISTS [#ExternalRuntimeAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#ExternalRuntimeAnalysis_HelpExample]; THROW; END CATCH;

EXEC [monitor].[USP_ExternalRuntimeAnalysis] @DatabaseNamePattern=N'like:ExampleDatabase%', @LanguageNamePattern=N'like:ExampleLanguage%', @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;

EXEC [monitor].[USP_ExternalRuntimeAnalysis] @DatabaseNames=N'[ExampleDatabase]', @SampleSeconds=1, @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;

EXEC [monitor].[USP_ExternalRuntimeAnalysis] @DatabaseNames=N'[ExampleDatabase]', @MitBerechtigungsanalyse=1, @HighImpactConfirmed=1, @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `findings`. CONSOLE rendert dieselbe priorisierte Findingstruktur. RAW und JSON liefern zusätzlich `configuration`, `databaseStatus`, `sourceStatus`, `languages`, `libraries`, `activeRequests`, `externalPools`, `executionStats`, `performanceCounters` und `warnings`.

Der gemeinsame Findings-Export besitzt 13 unveränderte Felder einschließlich `FindingOrdinal` und zehn explizit mit `SQL_Latin1_General_CP1_CS_AS` collatierte Textspalten. Nach vollständiger Sammlung und Statusbewertung werden zuerst WARNs bei `@NurProblematisch = 1` ausgewählt und anschließend nach Severity und ursprünglichem Findingordinal begrenzt. TABLE, CONSOLE, RAW und JSON verwenden dieselbe Findingsauswahl. `@MaxZeilen = NULL` und `0` bedeuten unbegrenzt; positive Werte begrenzen nach Materialisierung und jeweiliger Sortierung Findings, Languages, Libraries, activeRequests, externalPools, executionStats und performanceCounters. Configuration, databaseStatus, sourceStatus und warnings bleiben unbegrenzt. Negative Werte liefern `INVALID_PARAMETER`; JSON wird dennoch erzeugt, wenn `@JsonErzeugen = 1`. Die Truncation-Warnung zählt externalPools derzeit nicht. JSON behält die bestehende Auslassung von NULL-Properties.

Lesen Sie zuerst `sourceStatus`. Ein fachlich leeres Resultset ist nur belastbar, wenn seine Quelle `AVAILABLE` meldet. Lesen Sie danach `configuration` und `databaseStatus`, dann Registrierungen und erst anschließend Live- beziehungsweise Sampleevidenz. `findings` enthält Triageentscheidungen, ersetzt aber nicht die zugrunde liegenden Resultsets.

## Eine Zeile bedeutet

Eine Zeile in `languages` ist eine sichtbare Language-Registrierung oder bei aktiviertem Datei-Opt-in eine sichtbare plattformspezifische Dateizeile. Eine Zeile in `libraries` ist eine sichtbare Libraryregistrierung oder Plattformzeile. Eine Zeile in `activeRequests` beschreibt genau einen zum Lesezeitpunkt aktiven `external_script_request_id`; abgeschlossene Requests fehlen. Eine Poolzeile beschreibt einen External Resource Pool und optional ein resetgeprüftes Delta. Execution-Stats- und Counterzeilen besitzen eigene Zählersemantik und sind nicht mit Requestanzahlen gleichzusetzen.

## So lesen

Prüfen Sie Konfiguration, Installationsproperty und Launchpad-Status getrennt. Ordnen Sie registrierte Sprachen und Libraries der jeweiligen Datenbank zu. Korrelieren Sie aktive Requests ausschließlich über `external_script_request_id` mit `sys.dm_exec_requests`. Bewerten Sie Pooldeltas nur bei identischer `statistics_start_time` und `pool_version`. Berücksichtigen Sie bei Performance Counters stets `cntr_type`, Sampledauer und Resetstatus.

## Warum kann das problematisch sein?

Eine aktivierte Serveroption ohne sichtbare Installations- oder Serviceevidenz kann eine unvollständige Bereitstellung anzeigen. Registrierungen bei deaktiviertem External-Scripts-Pfad können auf stillgelegte Abhängigkeiten oder Migrationsrisiken hinweisen. Blockierte External Requests verlängern nicht nur die SQL-Requestdauer, sondern halten möglicherweise externe Worker und Poolkapazität. Erreicht `active_processes_count` ein konfiguriertes, von null verschiedenes `max_processes`, kann weitere Arbeit warten. Ein steigender `Execution Errors`-Counter ist ein konkreter Zeitfensterhinweis, enthält aber keine Fehlerursache.

## Wann ist es kein Problem?

Eine registrierte, aber momentan inaktive Runtime kann als bewusst bereitgestellte Plattform korrekt sein. `external scripts enabled = 0` kann in einer stillgelegten oder gehärteten Umgebung beabsichtigt sein. Ein External Pool mit `max_processes = 0` ist nach dem Quellenvertrag nicht an dieser Zahl begrenzt. Ein einzelner aktiver Prozess am Limit ist ohne Warteschlange, Dauer und wiederholte Messung noch kein Sättigungsnachweis. Fehlende Execution-Stats-Counter beweisen weder fehlende Nutzung noch Fehlerfreiheit, weil die DMV nur registrierte Featurefunktionen abbildet.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** `ExampleDatabase` enthält eine registrierte Python-Library. External Scripts ist aktiv, der sichtbare Launchpad-Status ist `STOPPED`, und ein wiederholtes Sample zeigt keine startbare Arbeit. Das Finding ist ein belastbarer Bereitstellungs- oder Betriebsverdacht; prüfen Sie Service- und Extensibility-Logs, ohne den Diagnosepfad als Funktionsprobe auszugeben.

**Ähnlich aussehender Gegenfall:** `ExampleDatabase` enthält eine Java-Language-Registrierung, der aktuelle Request-Snapshot ist leer und die Counterdeltas sind null. Das ist bei einer nur periodisch verwendeten Runtime erwartbar. Die Momentaufnahme belegt keine Störung und keine historische Inaktivität.

**Samplegrenze:** Steigt ein kumulativer Wert zwischen T1 und T2 nicht, ist das nur eine Aussage über das gemeinsame Intervall. Sinkt er oder wechselt die Poolversion beziehungsweise Resetzeit, verwirft die Procedure die Deltaaussage und kennzeichnet die Resetgrenze.

## Leere oder partielle Ausgabe

`NOT_APPLICABLE` bedeutet, dass External Scripts deaktiviert ist und im sichtbaren Scope weder Registrierungen noch Runtimeevidenz gefunden wurden. `FEATURE_DISABLED` bedeutet, dass die Option deaktiviert ist, aber Katalog- oder Zählerevidenz sichtbar bleibt. `AVAILABLE_LIMITED` bedeutet, dass mindestens eine isolierte Quelle nicht gelesen werden konnte oder eine explizit angeforderte Datenbank nicht auswertbar war. Auswahlpartialität ändert keinen erfolgreich erhobenen Quellenstatus. `DENIED_PERMISSION`, `SOURCE_UNAVAILABLE` und `LOCK_TIMEOUT` bleiben je Quelle sichtbar; zugängliche Teilresultate werden nicht verworfen.

Eine leere `activeRequests`-Liste ist ein gültiger Momentaufnahmebefund, keine Historie. Null Registrierungen gelten nur im sichtbaren Metadatenscope. `NULL` bei Konfiguration, Service oder Metrik bedeutet unbekannt oder nicht ableitbar, nicht automatisch null. Ein positives `@MaxZeilen` begrenzt die Ausgabe erst nach der Materialisierung und reduziert daher nicht die Quellarbeit.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM |
| Standardpfad | Eine bekannte Datenbank, `@SampleSeconds = 0`, keine Datei-, Owner- oder Sitzungsdaten und höchstens 100 Ausgabezeilen. |
| Teuerster Pfad | Viele Datenbanken, breite Languagefilter, Datei- und Owner-Metadaten, Sitzungskontext, unbegrenzte Ausgabe und ein 60-Sekunden-Sample. |
| Haupttreiber | Zahl der Zieldatenbanken, sichtbaren Language-/Libraryregistrierungen, aktiven Requests, External Pools und Counterinstanzen. |
| Skalierung | Katalogarbeit wächst mit Datenbanken und Registrierungen; Server-DMVs werden je Messpunkt einmal materialisiert. Das Sample verdoppelt Pool-, Execution-Stats- und Counterzugriffe, nicht die Katalogschleife. |
| Ressourcen | Temporäre Tabellen, dynamisches SQL je Datenbank und eine optionale `WAITFOR`-Dauer. Es werden keine Benutzertabellen oder externen Prozesse gestartet. |
| Begrenzungswirkung | Datenbank- und Languagefilter reduzieren Katalog- und Runtimezeilen. `@MaxZeilen` begrenzt Resultsets, aber nicht die vorgelagerte Quellmaterialisierung. |
| Locking und Nebenwirkungen | Rein lesend mit konfigurierbarem `LOCK_TIMEOUT`; kein DDL, kein Resource-Governor-Change und keine Runtimeausführung. Live-DMVs sind nicht atomar. |
| Schutzmechanismus | `EXTERNAL_RUNTIME_CURRENT` steuert den Basispfad. Ownerkontext mit `@MitBerechtigungsanalyse = 1` verwendet zusätzlich `CATALOG_DEEP` und verlangt je Policy `@HighImpactConfirmed = 1`. Der Datei-Opt-in aktiviert diesen Gatepfad nicht. |
| Sicherer Einsatz | Starten Sie mit einer synthetisch dokumentierten `ExampleDatabase`, Sample 0 und allen Privacy-Opt-ins aus. Vertiefen Sie nur eine konkrete Quelle. |
| Aussagegrenze | Registrierung, Dienststatus, Requestsnapshot und Counterdeltas sind getrennte Evidenz. Keine Kombination beweist ohne kontrollierte externe Funktionsprobe die End-to-End-Verfügbarkeit. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche External-Runtime-Komponenten sind im gewählten Scope sichtbar, und welche aktuellen Konfigurations-, Request-, Pool- oder Counterhinweise rechtfertigen eine gezielte Folgeanalyse?

### Technischer Hintergrund

SQL Server führt externe Scripts außerhalb des Engineprozesses über den Extensibility-/Launchpad-Pfad aus. Registrierungen sind datenbankbezogen; aktive Requests und Resource Pools sind serverweit. Deshalb muss die Analyse Katalog-, Host- und Laufzeitevidenz getrennt materialisieren. SQL CLR gehört nicht in diesen Pfad und wird durch `USP_ClrAnalysis` analysiert.

### Datenkette

`SERVERPROPERTY`, `sys.configurations`, `sys.dm_server_services`, `sys.external_languages`, `sys.external_language_files`, `sys.external_libraries`, `sys.external_library_files`, `sys.dm_external_script_requests`, `sys.dm_exec_requests`, `sys.dm_exec_sessions`, `sys.dm_external_script_execution_stats`, `sys.dm_resource_governor_external_resource_pools` und `sys.dm_os_performance_counters`.

### Source Select

Die aktive Korrelation verwendet den dokumentierten Requestschlüssel:

```sql
SELECT
      [er].[external_script_request_id]
    , [er].[language]
    , [r].[session_id]
    , [r].[request_id]
    , [r].[status]
    , [r].[wait_type]
FROM [sys].[dm_external_script_requests] AS [er] WITH (NOLOCK)
LEFT JOIN [sys].[dm_exec_requests] AS [r] WITH (NOLOCK)
  ON [r].[external_script_request_id] = [er].[external_script_request_id];
```

**Wichtig für die Eigenlast:** Aktive External Requests, External Resource Pools und Performance Counter besitzen serverweiten Scope und werden je Messpunkt einmal materialisiert. Datenbank- und Languagefilter begrenzen Katalog- und korrelierte Ausgabezeilen, nicht sämtliche serverweiten Quellzugriffe; `@MaxZeilen` wirkt erst nach der Materialisierung.

Die Katalogprojektionen referenzieren niemals `content`, `parameters` oder `environment_variables`. Die Liveprojektion referenziert keinen SQL- oder Scripttext.

### Zeit- und Scope-Modell

Konfiguration und Kataloge sind Current State. Active Requests sind eine flüchtige Momentaufnahme. Execution Stats und Performance Counter sind kumulativ; bei `@SampleSeconds > 0` wird nur ein resetgeprüftes Delta des gemeinsamen Intervalls ausgewiesen. Das Finding zu `Execution Errors` verwendet dieses eigene Sampledelta und nicht den aktuellen Gesamtwert. Poolwerte gelten seit `statistics_start_time`; ein Versions- oder Resetwechsel invalidiert das Delta. Linux-Poolwerte besitzen herstellerdokumentierte plattformspezifische Einheiten.

Common 163 erfasst die nativen Katalogidentitäten zweier eigener Unicode-Datenbanken ohne neue Language-/Libraryregistrierung oder externe Ausführung. Bereits vorhandene Standardsprachen können die bestehenden Registrierungs-WARNs und Startfähigkeits-INFOs für positive Findingsfilter- und Limitfälle liefern; ein leerer Languagefilter belegt nur Leerakzeptanz. Der Vertrag prüft das TABLE-Schema, alle 13 TABLE-/JSON-Felder einschließlich NULL-Auslassung, Konfiguration, Servicezustand, Quellenstatus, vollständige Datenbankzähler, Poolkonfiguration sowie Counteridentitäten, Typen und Quellanzahlen. Veränderliche kumulative Werte werden nicht als atomarer Punktvergleich behauptet. RAW und CONSOLE werden nur über Status und begleitendes JSON geprüft. Sampling, externe Prozesse, Startfähigkeit und zusätzliche Berechtigungspfade bleiben außerhalb dieses begrenzten Vertrags.

### Bewertung und Gegenprobe

Bestätigen Sie einen Konfigurationswiderspruch mit Installationsumfang und Servicezustand. Bestätigen Sie Blocking mit `USP_CurrentBlocking`, Poolgrenzen mit `USP_ResourceGovernorAnalysis`, Counter mit `USP_PerformanceCounters` und Fehlerhinweise mit `USP_ErrorLogAnalysis` oder bereits vorhandenen Extended-Events-Sessions. Führen Sie keine Produktionsprobe allein zur Diagnose aus.

### Typische Fehlinterpretation

`IsAdvancedAnalyticsInstalled = 1` ist kein Beweis für eine bestimmte Runtimeversion. Ein laufender Launchpad-Service ist kein Package-Healthcheck. Request-CPU aus `sys.dm_exec_requests` enthält keine belegte externe Prozess-CPU. `sys.dm_external_script_execution_stats` ist keine vollständige Script-Historie.

### Folgeanalyse

Prüfen Sie bei Blocking `USP_CurrentBlocking`, bei allgemeinen Requests `USP_CurrentRequests`, bei Pool- oder Workload-Governance `USP_ResourceGovernorAnalysis`, bei Countern `USP_PerformanceCounters` und bei Betriebsfehlern `USP_ErrorLogAnalysis` sowie vorhandene Extended-Events-Evidenz im selben Zeitfenster.

## Primärquellen

- [External-Script-Requests](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-external-script-requests?view=sql-server-ver17)
- [External-Script-Execution-Stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-external-script-execution-stats?view=sql-server-ver17)
- [External Resource Pools](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-resource-governor-external-resource-pools?view=sql-server-ver17)
- [External Languages](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-external-languages-transact-sql?view=sql-server-ver17)
- [External Libraries](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-external-libraries-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../09_Version_Adaptive.md#10-monitorusp_externalruntimeanalysis)
