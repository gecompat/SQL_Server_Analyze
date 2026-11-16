# [monitor].[USP_ClrAnalysis]

**Bereich:** Versionsadaptive Spezialanalysen<br>
**Zweck:** Analysiert SQL-CLR-Konfiguration, sichtbare Assemblies und Module sowie aktuelle Host-, AppDomain-, Task-, Request-, Speicher- und Counterevidenz.<br>
**Beobachtungsart:** Konfigurations-, Katalog-, Live- und Sample-Snapshot<br>
**Kostenklasse:** MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche SQL-CLR-Abhängigkeiten sind im gewählten Datenbankscope sichtbar, wie ist der CLR-Host aktuell konfiguriert und welche Liveevidenz rechtfertigt eine Sicherheits- oder Performancevertiefung?** Sie ist der Deep-Dive nach `USP_SpecialFeatureInventory`, wenn benutzerdefinierte Assemblies erkannt werden, und der gezielte Prüfpfad für `clr enabled`, `clr strict security`, AppDomains, geladene Assemblies oder aktive Managed-Code-Requests.

SQL CLR ist vom out-of-process External-Language-Pfad getrennt. Die Procedure analysiert .NET-Assemblies, die vom SQL-Server-CLR-Host verwaltet werden. C# Language Extensions, Launchpad, externe Libraries und External Resource Pools gehören zu `USP_ExternalRuntimeAnalysis`.

## Nicht beantwortete Fragen

Die Analyse führt keine Assembly aus, aktiviert CLR nicht und lädt keine Assembly. Sie bewertet keinen IL-Code, keine binären Abhängigkeiten und keine fachliche Korrektheit einer CLR-Methode. Assembly-Binärinhalt, Trusted-Assembly-Hashes, Moduldefinitionen, SQL-Texte und Pläne bleiben ausgeschlossen. Deshalb kann sie keine exakte Zuordnung einer Datenbankassembly zur serverweiten Trust List behaupten.

Eine sichtbare Katalogzeile beweist weder, dass eine Assembly aktuell geladen ist, noch dass alle Aufrufe erfolgreich sind. Eine geladene Assembly beweist keine konkrete Methodenausführung im betrachteten Zeitfenster. `creation_time` eines AppDomains ist wegen Caching nicht der Startzeitpunkt eines Requests. Active-Request- und Task-DMVs sind flüchtig und bilden keine Historie.

Owner-, `EXECUTE AS`-Principal- und Trusted-Assembly-Anzahl werden nur mit `@MitBerechtigungsanalyse = 1` gelesen. Der Pfad verlangt `CATALOG_DEEP`, die wirksame Gruppenpolicy und bei Bedarf `@HighImpactConfirmed = 1`. Login-, Host- und Programmkontext aktiver Requests bleiben standardmäßig leer und werden nur durch `@MitSitzungskontext = 1` ausgegeben.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ClrAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @SampleSeconds = 0,
      @MitModulzuordnung = 1,
      @MitBerechtigungsanalyse = 0,
      @MitSitzungskontext = 0,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch. Beginnen Sie mit einer bekannten Datenbank, ohne Counterwartezeit und ohne Identity- oder Trust-Opt-in. Nutzen Sie `@AssemblyNames` oder `@AssemblyNamePattern`, wenn der Katalog viele benutzerdefinierte Assemblies enthält.

## Parameterverträge

Jeder Eintrag erklärt den tatsächlichen Parametervertrag einschließlich NULL-Verhalten und der erlaubten Werte.

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | Default: `NULL` | NULL, N'' und nur äußere Leerzeichen bedeuten keine explizite Datenbankliste. Eine nichtleere Eingabe ist eine Pipe-Liste einteiliger SQL-Datenbanknamen: \| trennt außerhalb eckiger Klammern, \| darin bleibt Inhalt, ]] maskiert ] und Elementränder werden getrimmt. Leere Elemente, ungültige Klammerung, Rohsegmente über 4000 UTF-16-Codeeinheiten, mehrteilige oder ungültige SQL-Namen und Namen über 128 Zeichen werden abgelehnt. Duplikate bleiben parserseitig erhalten; Kandidaten werden nach CS_AS-Namen zusammengeführt. Pattern und wirksame explizite Liste sind gegenseitig ausschließend. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@SystemdatenbankenEinbeziehen` | `bit` | Default: `0` | 0 schließt Systemdatenbanken aus; 1 erlaubt ihre Aufnahme, sofern die übrige Auswahl sie erfasst. NULL ist ungültig. Das Flag vergibt weder Zugriff noch ersetzt es CLR_CURRENT-Gruppenpolicy oder High-Impact-Bestätigung. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | Default: `NULL` | NULL bedeutet kein Pattern. Äußerer Leerraum wird entfernt; regexi:, regex: und like: werden ohne Beachtung der Präfix-Großschreibung entfernt, der Inhalt danach nicht erneut getrimmt. Ohne Präfix oder mit like: gilt SQL-LIKE-Syntax, auf Datenbanknamen CS_AS angewendet. regex: nutzt Flag c, regexi: Flag i; beide erfordern SQL Server 2025 und Compatibility Level 170 in Framework- und jeder Zieldatenbank. Leer- oder nur Leerraumwerte sowie leeres Präfixergebnis wie like: sind ungültig. Nichtleere wirksame DatabaseNames schließen das Pattern aus. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@HighImpactConfirmed` | `bit` | Default: `0` | 0 bestätigt keinen High-Impact-Pfad; 1 ist die ausdrückliche Bestätigung, falls die wirksame Policy sie für die Analyseklasse verlangt. NULL ist ungültig. Das Bit ist keine Berechtigung und hebt Gruppenpolicy nicht auf. Basiskandidaten laufen über CLR_CURRENT; Owner-/Principal-/Trustanalyse verlangt zusätzlich CATALOG_DEEP und dessen Policy. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@AssemblyNames` | `nvarchar(max)` | Default: `NULL` | NULL bedeutet kein Assemblyfilter. Jede nicht-NULL-Eingabe muss eine bracket-aware Pipe-Liste gültiger einzelner SQL-Namen enthalten: \| trennt außerhalb [...], ]] maskiert ], Segmentränder werden getrimmt. Exakter Leerstring, Leerraum, leere Elemente, ungültige Klammerung, Rohsegmente über 4000 UTF-16-Codeeinheiten, ungültige oder mehrteilige SQL-Namen und Namen über 128 Zeichen führen zu INVALID_PARAMETER. Namen landen unverändert in einer CS_AS-Primärschlüsselspalte; ein exakt doppeltes Element kann daher beim Einfügen einen Fehler auslösen, der vom äußeren CATCH als ERROR_HANDLED gemeldet wird. Mit AssemblyNamePattern ist die Eingabe ungültig. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@AssemblyNamePattern` | `nvarchar(4000)` | Default: `NULL` | NULL bedeutet kein Filter. Äußerer Leerraum wird entfernt; regexi:, regex: und like: werden ohne Beachtung der Präfixschreibung erkannt, der Rest nicht erneut getrimmt. Ohne Präfix oder mit like: gilt SQL-LIKE-Matching, CS_AS. regex: nutzt Flag c, regexi: Flag i und beide brauchen SQL Server 2025 sowie Compatibility Level 170 in Framework- und Zieldatenbank. Leerer Wert oder leeres Präfixergebnis wie like: ist ungültig; Regex-Syntax wird nicht vorgeprüft. Zusammen mit AssemblyNames unzulässig; sonst wirkt es auf benutzerdefinierte Assemblies im ausgewählten Datenbankscope. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@SampleSeconds` | `tinyint` | Default: `0` | 0 liest Counterpunkt T1; Delta-Counter liefern SAMPLE_REQUIRED_FOR_DELTA_METRIC. Ganzzahlwerte 1 bis 60 warten mit WAITFOR DELAY auf T2. Die effektive Dauer basiert auf den tatsächlichen UTC-Lesezeiten und DATEDIFF_BIG in Mikrosekunden, nicht auf der angeforderten Sollzeit. Typen 272696320 und 272696576 liefern Zählerdelta je tatsächlicher Sekunde. Typ 537003264 liefert 100 mal Zählerdelta/Basisdelta; 1073874176 liefert Zählerdelta/Basisdelta. Beide Basistypen brauchen positives Sampling sowie vorhandene, steigende Basiswerte; diese Formeln teilen nicht durch Zeit. Sinkender Counter ergibt COUNTER_RESET_DURING_SAMPLE; Basistypen zusätzlich BASE_COUNTER_MISSING, BASE_COUNTER_RESET_DURING_SAMPLE oder BASE_COUNTER_DELTA_ZERO. Bei fehlendem T2 infolge isoliertem Quellenfehler wird T1 als Gegenwert verwendet, also entsteht kein echtes Delta. Unbekannte Typen sind RAW_UNINTERPRETED. NULL und Werte über 60 sind ungültig. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MitModulzuordnung` | `bit` | Default: `1` | 0 überspringt sichtbare CLR-Module, direkte Assemblyreferenzen und CLR-Typen; 1 erfasst diese Katalogzeilen für Assemblies im Filter. NULL ist ungültig. Default 1 ist Umfangssteuerung, kein Security-/Berechtigungsgate. Moduldefinitionen und Assembly-Binärinhalte werden nie gelesen. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MitBerechtigungsanalyse` | `bit` | Default: `0` | 0 lässt Assembly-Owner, EXECUTE-AS-Principals und Trust-Zeilenanzahl aus; 1 fordert diese Zusatzdaten an. NULL ist ungültig. Der Pfad verlangt separat CATALOG_DEEP und dessen Gruppen-/High-Impact-Policy. Trust wird nur als serverweite Zeilenanzahl gelesen; Hash, Beschreibung und Assembly-zu-Trust-Zuordnung bleiben ausgeschlossen. Das Flag aktiviert kein CLR. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MitSitzungskontext` | `bit` | Default: `0` | 0 lässt Login, Host und Clientprogramm aktiver Managed-Code-Requests NULL; 1 ergänzt genau diese drei Kontextspalten. NULL ist ungültig. Unabhängig vom CATALOG_DEEP-Owner-/Trustpfad. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@NurProblematisch` | `bit` | Default: `0` | 0 behält alle Findings; 1 filtert ausschließlich auf Severity=WARN. NULL ist ungültig. Der Filter wirkt auf findings in CONSOLE/RAW/TABLE und JSON-findings, nicht auf übrige Ergebnisarrays, Warnings oder Bewertung. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MaxZeilen` | `int` | Default: `100` | NULL oder 0 bedeutet unbegrenzt; positive Werte begrenzen je Resultset nach Sortierung. Negative Werte sind INVALID_PARAMETER. Begrenzte Mengen: findings nach NurProblematisch, assemblies, assemblyModules, assemblyDependencies, appDomains, loadedAssemblies, clrTasks, activeRequests, memory und performanceCounters. Unbegrenzt bleiben configuration, databaseStatus, sourceStatus, clrProperties und warnings. Die Begrenzung erfolgt nach Materialisierung und reduziert Quellkosten nicht. Der RESULTSET_TRUNCATED-Prüfblock zählt nur findings, assemblies, assemblyModules, assemblyDependencies, appDomains, loadedAssemblies und clrTasks; er deckt eine alleinige Begrenzung von activeRequests, memory oder performanceCounters nicht ab. Bei PrintMeldungen=1 wird die Warnmeldung ausgegeben, wenn diese geprüften Mengen das Limit überschreiten. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@LockTimeoutMs` | `int` | Default: `0` | 0 setzt LOCK_TIMEOUT 0; 1 bis 60000 setzt Sitzungszeitlimit in Millisekunden. NULL und Werte außerhalb des Bereichs sind ungültig. Das eingehende Sitzungssetting wird am Ende wiederhergestellt. Sampling-Wartezeit wird hierdurch nicht begrenzt; TABLE-Helfer haben eigene lokale DDL-/Metadatenbudgets. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultSetArt` | `varchar(16)` | Default: `'CONSOLE'` | Nach äußerem Trimmen und Umwandlung in Großbuchstaben sind exakt CONSOLE, RAW, TABLE und NONE erlaubt; NULL, leer oder sonstige Werte ergeben INVALID_PARAMETER. CONSOLE rendert findings. RAW liefert zuerst Meta und dann geordnete Konfigurations-, Status-, Findings-, Katalog-, Host-, Request-, Memory-, Counter- und Warning-Resultsets. TABLE exportiert nur findings ins vorbereitete lokale Ziel. NONE unterdrückt Resultsets. TABLE und CONSOLE schalten interne Ausgabe auf NONE. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultTablesJson` | `nvarchar(max)` | Default: `NULL` | NULL oder Leerraum bedeutet keine Zuordnung; TABLE benötigt ein gültiges JSON-Objekt mit dem einzigen erlaubten case-sensitiven Schlüssel findings und einem nichtleeren JSON-String als lokalem #Temp-Zielnamen. Doppelte JSON-Schlüssel, unbekannte Schlüssel, Nicht-Stringwerte, doppelte Ziele, ##-/permanente Tabellen, über 116 Zeichen oder das case-insensitive reservierte Präfix #Monitor sind ungültig; das vorhandene Ziel muss lokal und leer sein. Der Writer akzeptiert eine leere Zieltabelle mit genau einer beliebigen Seed-Spalte oder eine passende Findingsstruktur. Bei nicht-TABLE und nichtleerem Wert erfolgt THROW 51011 vor Hilfe. TABLE-Preflight kann ebenfalls vor HELP werfen; der spätere Writer läuft nach OUT-Zuweisung und RAW-/JSON-Ausgabe mit ThrowOnError=1, sodass 51010 danach auftreten kann. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@JsonErzeugen` | `bit` | Default: `0` | 0 unterdrückt Erstellung; 1 erzeugt ein JSON-Objekt mit meta als Einzelobjekt und benannten Arrays configuration, databaseStatus, sourceStatus, findings, assemblies, assemblyModules, assemblyDependencies, clrProperties, appDomains, loadedAssemblies, clrTasks, activeRequests, memory, performanceCounters und warnings. NULL ist ungültig. JSON ist unabhängig von ResultSetArt. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Json` | `nvarchar(max) OUTPUT` | Default: `NULL` | OUTPUT wird beim Einstieg auf NULL gesetzt. Bei JsonErzeugen=0 bleibt es NULL; bei 1 enthält es meta und die benannten Arrays. SQL FOR JSON lässt NULL-Eigenschaften standardmäßig aus; leere Collections werden als [] ausgegeben. Die OUTPUT-Bindung muss zum SQL-Typvertrag passen. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@PrintMeldungen` | `bit` | Default: `1` | 1 gibt Status- und Truncation-Hinweise als Severity-10-Meldungen aus; 0 unterdrückt sie. NULL ist ungültig. Beeinflusst weder Status-OUTPUT noch strukturierte Warnings. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Hilfe` | `bit` | Default: `0` | 1 druckt Kurzbeschreibung und kehrt vor Analyse/Resultsets zurück; 0 fährt normal fort. NULL wird nicht als 1 behandelt und wird nicht von der Bit-NULL-Validierung erfasst. Ein unzulässiges nichtleeres ResultTablesJson kann bereits vor diesem Zweig THROW 51011 auslösen. Beim frühen Help-Return werden die abschließenden Status-OUTPUTs nicht zugewiesen. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | Default: `NULL` | OUTPUT für den globalen Status, getrennt von Quell- und Datenbankstatus. Mögliche globale Werte: AVAILABLE, AVAILABLE_LIMITED, AVAILABLE_WITH_FINDING, NOT_APPLICABLE, FEATURE_DISABLED, INVALID_PARAMETER, UNAVAILABLE_FEATURE, HIGH_IMPACT_CONFIRMATION_REQUIRED, DENIED_GROUP, INTERNAL_ERROR, LOCK_TIMEOUT, ERROR_HANDLED. INTERNAL_ERROR kann defensiv aus der TOP(0)-Tabellenformprobe im Kandidatenhelfer stammen; keine Ursache oder Laufzeitbeobachtung daraus ableiten. Bei Help-Return keine Zuweisung. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@IsPartialOut` | `bit OUTPUT` | Default: `NULL` | OUTPUT-Bit der globalen Partialität (1 bei eingeschränkter/fehlgeschlagener Auswertung, sonst 0), getrennt von Quellen-/Datenbankpartialität. Bei Help-Return nicht zugewiesen. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@ErrorNumberOut` | `int OUTPUT` | Default: `NULL` | OUTPUT für ausgewählte SQL-Fehlernummer aus globaler CATCH- oder partieller Quellenmeldung; NULL, wenn keine gesetzt wurde. Getrennt vom Statuscode. Bei Help-Return nicht zugewiesen. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | Default: `NULL` | OUTPUT für den global ausgewählten Fehler-/Statusbeschreibungstext: kann Validierungs-, Gate- oder Quellenfehlerdetails enthalten, aus globaler CATCH oder partieller Quellenmeldung stammen, oder NULL sein. Nicht für jeden Status ist eine Fehlerursache gesetzt. Getrennt von Statuscode und strukturierten Warnungen. Bei Help-Return nicht zugewiesen. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |

## Aufrufbeispiele zu den Parameterverträgen

Die Beispiele verwenden synthetische Namen, die durch einen ausdrücklich freigegebenen Scope ersetzt werden müssen. Die Analyse aktiviert CLR nicht, erstellt keine Assembly und ruft keine CLR-Funktion auf. Der gefilterte RAW-Aufruf deaktiviert die standardmäßig aktive Modulzuordnung ausdrücklich. Das Sampling-Beispiel wartet für ein gemeinsames Messintervall von einer Sekunde; tatsächliche Messabstände und Resetbedingungen bleiben maßgeblich. Der Berechtigungsbeispielaufruf bestätigt CATALOG_DEEP ausdrücklich; Zugriffspolicy und Quellenberechtigungen werden weiterhin geprüft. Das TABLE-Beispiel verwendet eine Seedspalte und entfernt das Ziel auch im Fehlerfall.

```sql
EXEC [monitor].[USP_ClrAnalysis] @Hilfe=1;

EXEC [monitor].[USP_ClrAnalysis] @DatabaseNames=N'[ExampleDatabase]', @AssemblyNames=N'[ExampleAssembly]', @MitModulzuordnung=0, @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;

DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_ClrAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];

CREATE TABLE [#ClrAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ClrAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#ClrAnalysis_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#ClrAnalysis_HelpExample]; DROP TABLE IF EXISTS [#ClrAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#ClrAnalysis_HelpExample]; THROW; END CATCH;

EXEC [monitor].[USP_ClrAnalysis] @DatabaseNamePattern=N'like:ExampleDatabase%', @AssemblyNamePattern=N'like:ExampleAssembly%', @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;

EXEC [monitor].[USP_ClrAnalysis] @DatabaseNames=N'[ExampleDatabase]', @SampleSeconds=1, @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;

EXEC [monitor].[USP_ClrAnalysis] @DatabaseNames=N'[ExampleDatabase]', @MitBerechtigungsanalyse=1, @HighImpactConfirmed=1, @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `findings`. CONSOLE rendert diese priorisierte Struktur. Die gemeinsame Findingsmenge besitzt 13 unveränderte Felder und zehn explizit collatierte Textspalten. TABLE, CONSOLE, RAW und JSON verwenden nach vollständiger Bewertung denselben Problemfilter und dasselbe Zeilenlimit; ursprüngliche Findingordinalen bleiben erhalten. JSON lässt bestehende NULL-Properties weiterhin aus. RAW und JSON liefern zusätzlich `configuration`, `databaseStatus`, `sourceStatus`, `assemblies`, `assemblyModules`, `assemblyDependencies`, `clrProperties`, `appDomains`, `loadedAssemblies`, `clrTasks`, `activeRequests`, `memory`, `performanceCounters` und `warnings`.

Lesen Sie zuerst `sourceStatus`, weil fehlende Server-DMV-Rechte und eingeschränkte Metadata Visibility unterschiedliche Lücken erzeugen. Lesen Sie danach die Konfiguration und den Datenbankstatus. Ordnen Sie Assemblies nur innerhalb ihrer Datenbank zu. Verwenden Sie Host-, AppDomain-, Task- und Requestresultsets anschließend als flüchtigen Laufzeitkontext, nicht als Ersatz für den Katalog.

## Eine Zeile bedeutet

Eine `assemblies`-Zeile beschreibt genau eine sichtbare benutzerdefinierte Assembly in einer Datenbank. Eine `assemblyModules`-Zeile beschreibt ein sichtbares CLR-Datenbankobjekt und seine Assemblyklasse beziehungsweise Methode, ohne Definition. Eine Dependency-Zeile beschreibt entweder eine direkte Assemblyreferenz oder einen sichtbaren CLR-Typ. Eine AppDomainzeile ist ein aktuell gecachter Hostkontext. Eine Loaded-Assembly-Zeile besitzt nur dann einen belastbaren Namen, wenn `assembly_id` zusammen mit der über den AppDomain ermittelten Datenbank korreliert werden konnte. Eine Task- oder Requestzeile ist ausschließlich eine Momentaufnahme.

## So lesen

Prüfen Sie `clr enabled`, `clr strict security` und `lightweight pooling` gemeinsam. Ordnen Sie Permission Set, Datenbank-`TRUSTWORTHY`, Owner-/Signaturkontext und Plattformgrenzen getrennt ein. Verwenden Sie `assembly_id` nie serverweit als eindeutigen Schlüssel. Korrelieren Sie Tasks best effort über `sos_task_address` zu `sys.dm_os_tasks.task_address`. Bewerten Sie CLR-Memory-Clerks und Counter nur mit Servermemory, Workloadbaseline, Sampledauer und Resetstatus.

## Warum kann das problematisch sein?

Deaktiviertes `clr strict security` schwächt den modernen Sicherheitsvertrag, weil Code Access Security kein belastbarer Sicherheitsrand ist. Gleichzeitiges `clr enabled` und `lightweight pooling` ist laut Produktdokumentation nicht unterstützt. Benutzerassemblies bei deaktiviertem CLR können stillgelegte oder migrationskritische Abhängigkeiten anzeigen. Unter Linux werden für SQL CLR nur SAFE Assemblies unterstützt; sichtbare `EXTERNAL_ACCESS`- oder `UNSAFE_ACCESS`-Metadaten verlangen daher eine Plattformprüfung. `TRUSTWORTHY ON` zusammen mit hoch privilegierten Assemblies ist ein Security-Review-Signal, aber noch kein Exploitnachweis.

Aktive Managed-Code-Requests können blockiert sein wie andere Requests. Nicht zuordenbare Tasks oder geladene Assemblies können durch Lebenszeitwechsel, Systemassemblies, Filter oder fehlende Metadatensichtbarkeit entstehen. Wiederholte Unmappability im selben AppDomain- und Requestkontext rechtfertigt eine Vertiefung; ein einzelner Snapshot nicht.

## Wann ist es kein Problem?

Eine SAFE-Assembly in einer bewusst CLR-basierten Anwendung kann erwarteter Bestandteil des Designs sein. `clr enabled = 1` allein beweist weder aktuelle Nutzung noch ein Sicherheitsproblem. Ein leerer AppDomain-, Task- oder Request-Snapshot ist erwartbar, wenn zur Messzeit keine CLR-Arbeit aktiv oder gecacht ist. Hohe kumulative CLR Execution Time kann bei einer langlebigen Instanz normal sein; ohne Resetzeit, Sampledelta und Workloadvergleich ist sie keine Alarmgrenze. Fehlende Trust-Zuordnung ist im Standardpfad beabsichtigt, weil der notwendige Binärhash aus Datenschutz- und Kostenvertrag ausgeschlossen ist.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** `ExampleDatabase` ist `TRUSTWORTHY ON` und enthält `ExampleUnsafeAssembly` mit `UNSAFE_ACCESS`; zugleich ist `clr strict security` deaktiviert. Die Procedure meldet getrennte Security-Findings. Prüfen Sie Owner, Signierung, Trust List, erforderlichen Permission Set und Zielplattform. Leiten Sie daraus nicht automatisch eine Kompromittierung ab.

**Ähnlich aussehender Gegenfall:** `ExampleDatabase` enthält `ExampleSafeAssembly`, `clr strict security` ist aktiv, und aktuell sind weder Task noch Request sichtbar. Die Katalogabhängigkeit bleibt relevant für Deployment und Restore, ist aber ohne Fehler-, Blocking- oder Securityevidenz kein Betriebsdefekt.

**Korrelationsgrenze:** Eine Loaded-Assembly-Zeile mit `assembly_id = 42` darf nur gegen Katalogzeilen der AppDomain-Datenbank geprüft werden. Dieselbe ID kann in einer anderen Datenbank eine andere Assembly bezeichnen.

## Leere oder partielle Ausgabe

Der globale Status `AVAILABLE` kennzeichnet eine vollständige Auswertung ohne WARN-Finding; `AVAILABLE_WITH_FINDING` kennzeichnet mindestens ein WARN-Finding; `AVAILABLE_LIMITED` kennzeichnet partielle Quellen, Datenbankauswahl oder Kandidatenwarnings. `NOT_APPLICABLE` wird gesetzt, wenn CLR nicht aktiv ist und im ausgewerteten Scope keine benutzerdefinierte Assembly sichtbar ist; `FEATURE_DISABLED` bedeutet, dass CLR nicht aktiv ist und dennoch eine Assembly sichtbar ist. `INVALID_PARAMETER`, `UNAVAILABLE_FEATURE`, `HIGH_IMPACT_CONFIRMATION_REQUIRED`, `DENIED_GROUP`, `INTERNAL_ERROR`, `LOCK_TIMEOUT` und `ERROR_HANDLED` kennzeichnen weitere globale Pfade. `INTERNAL_ERROR` kann defensiv aus der TOP(0)-Formprobe des Kandidatenhelfers stammen; daraus folgt keine beobachtete Fehlerursache. Quell- und Datenbankstatuscodes sind vom globalen Status getrennt. Zugängliche Resultsets bleiben erhalten und sind zusammen mit `sourceStatus` zu interpretieren. Auswahlwarnings können `AVAILABLE_LIMITED` verursachen, ohne erfolgreiche Quellenstatus oder vollständige Datenbankzähler zu überschreiben.

Keine Assemblyzeile beweist bei eingeschränkter Metadata Visibility keine Abwesenheit. Keine AppDomain- oder Requestzeile beweist keine historische Nichtnutzung. `NULL` bei Trust, Owner, Mapping oder Metrik bedeutet nicht geprüft, nicht sichtbar oder nicht ableitbar. Ein positives `@MaxZeilen` begrenzt nach Sortierung findings, assemblies, assemblyModules, assemblyDependencies, appDomains, loadedAssemblies, clrTasks, activeRequests, memory und performanceCounters; die vorgelagerte Katalog- und DMV-Materialisierung bleibt davon unberührt. Für findings gilt zusätzlich `@NurProblematisch`. Die `RESULTSET_TRUNCATED`-Prüfung zählt nur findings, assemblies, assemblyModules, assemblyDependencies, appDomains, loadedAssemblies und clrTasks; sie deckt eine alleinige Begrenzung von activeRequests, memory oder performanceCounters nicht ab. NULL und 0 liefern alle Zeilen. Negative Werte werden als `INVALID_PARAMETER` abgelehnt. configuration, databaseStatus, sourceStatus, clrProperties und warnings bleiben unbegrenzt.

Common 164 prüft zwei eigene leere case-unterschiedliche Unicode-Datenbanken ohne Assemblyregistrierung, Ausführung oder Konfigurations-/Truständerung. Der Vertrag vergleicht das 13-Felder-TABLE-Schema mit zehn Textcollations, leere Findingsparität, native Konfiguration und Hostproperties sowie Quellenidentitäten und Anzahlen. Memory-Clerk-Werte und Counterwerte werden nicht als atomarer Punktvergleich behauptet; die Counterinterpretation wird für Sample 0 geprüft. Leere Findings belegen nur Filter-/Limitakzeptanz. Positive Findingsfilter-/Limitwirkung, Assemblies, aktive CLR-Ausführung, Trust und Sampling bleiben außerhalb dieses Vertrags. RAW und CONSOLE werden nur über Status und begleitendes JSON geprüft.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM |
| Standardpfad | Eine bekannte Datenbank, `@SampleSeconds = 0`, Modulzuordnung an, Owner-/Trust- und Sitzungskontext aus, höchstens 100 Ausgabezeilen. |
| Teuerster Pfad | Viele Datenbanken, breite Assemblyfilter, Modul-/Dependency-Zuordnung, Owner-/Trustanalyse, Sitzungskontext, unbegrenzte Ausgabe und 60-Sekunden-Countersample. |
| Haupttreiber | Zahl der Zieldatenbanken, benutzerdefinierten Assemblies, Assemblymodule und -referenzen, CLR-Typen, AppDomains, geladenen Assemblies, Tasks und Counterinstanzen. |
| Skalierung | Datenbankkatalogarbeit wächst mit sichtbaren CLR-Objekten. Server-DMVs werden einmal je Messpunkt materialisiert; das Sample wiederholt nur Performance Counter. |
| Ressourcen | Temporäre Tabellen, dynamisches SQL je Datenbank und optionale `WAITFOR`-Dauer. Es werden keine Assembly-Binaries, Benutzertabellen oder Moduldefinitionen gelesen. |
| Begrenzungswirkung | Datenbank- und Assemblyfilter reduzieren Katalogzeilen. `@MaxZeilen` begrenzt die Ausgabe erst nach Materialisierung und reduziert die Quellenkosten nicht vollständig. |
| Locking und Nebenwirkungen | Rein lesend mit konfigurierbarem `LOCK_TIMEOUT`; keine CLR-, Trust-, Datenbank- oder Assemblyänderung und keine Codeausführung. Live-DMVs sind nicht atomar. |
| Schutzmechanismus | `CLR_CURRENT` steuert den Basispfad. Owner-, Principal- und Trustkontext verwendet zusätzlich `CATALOG_DEEP` und je Policy `@HighImpactConfirmed = 1`. |
| Sicherer Einsatz | Beginnen Sie mit einer synthetisch dokumentierten `ExampleDatabase`, Sample 0 und Privacy-Opt-ins aus. Aktivieren Sie Trust-/Ownerkontext nur für ein konkretes Security-Review. |
| Aussagegrenze | Katalog, Hostzustand, AppDomains, Tasks, Requests, Memory und Counter besitzen unterschiedliche Zeit- und Schlüsselmodelle. Die Procedure erzeugt keinen End-to-End- oder Trustnachweis. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche SQL-CLR-Abhängigkeiten und aktuellen Hostsignale sind sichtbar, und welche Sicherheits-, Plattform- oder Laufzeithinweise benötigen eine gezielte Gegenprobe?

### Technischer Hintergrund

SQL Server hostet CLR-AppDomains pro Datenbank- und Sicherheitskontext. `sys.assemblies` und die zugehörigen Modulkataloge sind datenbankbezogen. Die CLR-DMVs sind serverweit. `assembly_id` ist deshalb nur innerhalb der AppDomain-Datenbank sinnvoll korrelierbar. Moderne SQL-Server-Versionen behandeln SAFE und EXTERNAL_ACCESS bei aktiviertem `clr strict security` sicherheitstechnisch wie UNSAFE, sofern keine Signatur- oder Trustbasis vorliegt.

### Datenkette

`sys.configurations`, `sys.databases`, `sys.assemblies`, `sys.assembly_modules`, `sys.assembly_references`, `sys.assembly_types`, `sys.dm_clr_properties`, `sys.dm_clr_appdomains`, `sys.dm_clr_loaded_assemblies`, `sys.dm_clr_tasks`, `sys.dm_os_tasks`, `sys.dm_exec_requests`, `sys.dm_exec_sessions`, `sys.dm_os_memory_clerks`, `sys.dm_os_performance_counters` und optional `sys.trusted_assemblies`.

### Source Select

Die Loaded-Assembly-Korrelation bindet die ID an den AppDomain-Datenbankkontext:

```sql
SELECT
      [loaded].[assembly_id]
    , [domain].[db_id]
    , [catalog].[name] AS [AssemblyName]
FROM [sys].[dm_clr_loaded_assemblies] AS [loaded] WITH (NOLOCK)
JOIN [sys].[dm_clr_appdomains] AS [domain] WITH (NOLOCK)
  ON [domain].[appdomain_address] = [loaded].[appdomain_address]
LEFT JOIN [ExampleDatabase].[sys].[assemblies] AS [catalog] WITH (NOLOCK)
  ON [catalog].[assembly_id] = [loaded].[assembly_id]
 AND [domain].[db_id] = DB_ID(N'ExampleDatabase');
```

**Wichtig für die Eigenlast:** Die CLR-DMVs besitzen serverweiten Scope und werden je Messpunkt einmal vollständig materialisiert. Datenbank- und Assemblyfilter begrenzen die anschließende Katalogauflösung, nicht jedoch die Arbeit dieser serverweiten DMV-Snapshots; `@MaxZeilen` wirkt erst auf die fertigen Resultsets.

Die reale Procedure verwendet dynamisch quotierte Datenbanknamen aus dem zentralen Kandidatenvertrag. Binärinhalt und Hashquellen werden nicht referenziert.

### Zeit- und Scope-Modell

Konfiguration und Datenbankkataloge sind Current State. AppDomains und geladene Assemblies können über einzelne Requests hinaus gecacht bleiben. CLR Tasks und `executing_managed_code` sind flüchtige Momentaufnahmen. Memory Clerks sind aktuelle Aggregate. CLR Performance Counter sind kumulativ; ein optionales gemeinsames Sample erzeugt nur dann eine Deltaaussage, wenn Countertyp, Messpunkte und Resetvertrag dies zulassen.

### Bewertung und Gegenprobe

Bestätigen Sie Security-Findings mit Datenbankowner, Assemblysignierung, Trust List und dokumentierter Berechtigungsanforderung. Bestätigen Sie Blocking mit `USP_CurrentBlocking`, Requestkontext mit `USP_CurrentRequests`, Memory mit `USP_ServerMemory`, Counter mit `USP_PerformanceCounters` und Hostinitialisierungsfehler mit `USP_ErrorLogAnalysis`. Ein Code- oder Penetrationstest ist ein eigener autorisierter Nachweis und kein Bestandteil dieser Procedure.

### Typische Fehlinterpretation

`permission_set_desc = SAFE_ACCESS` ist bei aktiviertem `clr strict security` kein alleiniger Trustnachweis. `TRUSTWORTHY ON` beweist keine konkrete Ausnutzbarkeit. Eine geladene Assembly ist nicht gleichbedeutend mit einem aktiven Request. AppDomain-CPU ist kumulativ und nicht automatisch einer einzelnen Methode zuordenbar. CLR Execution Time ist keine per-Request-Latenz.

### Folgeanalyse

Verwenden Sie `USP_CurrentRequests` und `USP_CurrentBlocking` für aktive Workload, `USP_ServerSecurityConfiguration` für Instanzhärtung, `USP_ServerMemory` und `USP_PerformanceCounters` für Ressourcenkontext sowie `USP_ErrorLogAnalysis` und vorhandene Extended-Events-Evidenz für Host- oder Ladefehler.

## Primärquellen

- [SQL-CLR-Programmierkonzepte und Plattformunterstützung](https://learn.microsoft.com/en-us/sql/relational-databases/clr-integration/common-language-runtime-clr-integration-programming-concepts?view=sql-server-ver17)
- [CLR Strict Security](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/clr-strict-security?view=sql-server-ver17)
- [CLR Properties](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-clr-properties-transact-sql?view=sql-server-ver17)
- [CLR AppDomains](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-clr-appdomains-transact-sql?view=sql-server-ver17)
- [Geladene CLR-Assemblies](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-clr-loaded-assemblies-transact-sql?view=sql-server-ver17)
- [CLR Tasks](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-clr-tasks-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../09_Version_Adaptive.md#11-monitorusp_clranalysis)
