---
skill_format_version: "1.0.0"
name: "monitor.USP_ClrAnalysis"
schema_name: "monitor"
object_name: "USP_ClrAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure analysiert SQL-CLR-Konfiguration, benutzerdefinierte Assemblies, Module, Abhängigkeiten, Host Properties, AppDomains, geladene Assemblies, CLR Tasks, aktive Requests, Speicher und Counter."
source_path: "Code/09_VersionAdaptive/100_USP_ClrAnalysis.sql"
---

# monitor.USP_ClrAnalysis

## Zweck und Einsatz

Die Procedure analysiert SQL-CLR-Konfiguration, benutzerdefinierte Assemblies, Module, Abhängigkeiten, Host Properties, AppDomains, geladene Assemblies, CLR Tasks, aktive Requests, Speicher und Counter.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

sys.configurations, sys.databases, sys.assemblies, sys.assembly_modules, sys.assembly_references, sys.assembly_types, sys.dm_clr_properties, sys.dm_clr_appdomains, sys.dm_clr_loaded_assemblies, sys.dm_clr_tasks, sys.dm_os_tasks, sys.dm_exec_requests, sys.dm_exec_sessions, sys.dm_os_memory_clerks, sys.dm_os_performance_counters und optional sys.trusted_assemblies.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @AssemblyNames | nvarchar(max) | nein | NULL |
| @AssemblyNamePattern | nvarchar(4000) | nein | NULL |
| @SampleSeconds | tinyint | nein | 0 |
| @MitModulzuordnung | bit | nein | 1 |
| @MitBerechtigungsanalyse | bit | nein | 0 |
| @MitSitzungskontext | bit | nein | 0 |
| @NurProblematisch | bit | nein | 0 |
| @MaxZeilen | int | nein | 100 |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max)=NULL; Default: NULL. NULL, N'' und nur äußere Leerzeichen bedeuten keine explizite Datenbankliste. Eine nichtleere Eingabe ist eine Pipe-Liste einteiliger SQL-Datenbanknamen: | trennt außerhalb eckiger Klammern, | darin bleibt Inhalt, ]] maskiert ] und Elementränder werden getrimmt. Leere Elemente, ungültige Klammerung, Rohsegmente über 4000 UTF-16-Codeeinheiten, mehrteilige oder ungültige SQL-Namen und Namen über 128 Zeichen werden abgelehnt. Duplikate bleiben parserseitig erhalten; Kandidaten werden nach CS_AS-Namen zusammengeführt. Pattern und wirksame explizite Liste sind gegenseitig ausschließend. Bei ausgelassenem Argument gilt der angegebene Default.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit=0; Default: 0. 0 schließt Systemdatenbanken aus; 1 erlaubt ihre Aufnahme, sofern die übrige Auswahl sie erfasst. NULL ist ungültig. Das Flag vergibt weder Zugriff noch ersetzt es CLR_CURRENT-Gruppenpolicy oder High-Impact-Bestätigung. Bei ausgelassenem Argument gilt der angegebene Default.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000)=NULL; Default: NULL. NULL bedeutet kein Pattern. Äußerer Leerraum wird entfernt; regexi:, regex: und like: werden ohne Beachtung der Präfix-Großschreibung entfernt, der Inhalt danach nicht erneut getrimmt. Ohne Präfix oder mit like: gilt SQL-LIKE-Syntax, auf Datenbanknamen CS_AS angewendet. regex: nutzt Flag c, regexi: Flag i; beide erfordern SQL Server 2025 und Compatibility Level 170 in Framework- und jeder Zieldatenbank. Leer- oder nur Leerraumwerte sowie leeres Präfixergebnis wie like: sind ungültig. Nichtleere wirksame DatabaseNames schließen das Pattern aus. Bei ausgelassenem Argument gilt der angegebene Default.

**@HighImpactConfirmed:** @HighImpactConfirmed bit=0; Default: 0. 0 bestätigt keinen High-Impact-Pfad; 1 ist die ausdrückliche Bestätigung, falls die wirksame Policy sie für die Analyseklasse verlangt. NULL ist ungültig. Das Bit ist keine Berechtigung und hebt Gruppenpolicy nicht auf. Basiskandidaten laufen über CLR_CURRENT; Owner-/Principal-/Trustanalyse verlangt zusätzlich CATALOG_DEEP und dessen Policy. Bei ausgelassenem Argument gilt der angegebene Default.

**@AssemblyNames:** @AssemblyNames nvarchar(max)=NULL; Default: NULL. NULL bedeutet kein Assemblyfilter. Jede nicht-NULL-Eingabe muss eine bracket-aware Pipe-Liste gültiger einzelner SQL-Namen enthalten: | trennt außerhalb [...], ]] maskiert ], Segmentränder werden getrimmt. Exakter Leerstring, Leerraum, leere Elemente, ungültige Klammerung, Rohsegmente über 4000 UTF-16-Codeeinheiten, ungültige oder mehrteilige SQL-Namen und Namen über 128 Zeichen führen zu INVALID_PARAMETER. Namen landen unverändert in einer CS_AS-Primärschlüsselspalte; ein exakt doppeltes Element kann daher beim Einfügen einen Fehler auslösen, der vom äußeren CATCH als ERROR_HANDLED gemeldet wird. Mit AssemblyNamePattern ist die Eingabe ungültig. Bei ausgelassenem Argument gilt der angegebene Default.

**@AssemblyNamePattern:** @AssemblyNamePattern nvarchar(4000)=NULL; Default: NULL. NULL bedeutet kein Filter. Äußerer Leerraum wird entfernt; regexi:, regex: und like: werden ohne Beachtung der Präfixschreibung erkannt, der Rest nicht erneut getrimmt. Ohne Präfix oder mit like: gilt SQL-LIKE-Matching, CS_AS. regex: nutzt Flag c, regexi: Flag i und beide brauchen SQL Server 2025 sowie Compatibility Level 170 in Framework- und Zieldatenbank. Leerer Wert oder leeres Präfixergebnis wie like: ist ungültig; Regex-Syntax wird nicht vorgeprüft. Zusammen mit AssemblyNames unzulässig; sonst wirkt es auf benutzerdefinierte Assemblies im ausgewählten Datenbankscope. Bei ausgelassenem Argument gilt der angegebene Default.

**@SampleSeconds:** @SampleSeconds tinyint=0; Default: 0. 0 liest Counterpunkt T1; Delta-Counter liefern SAMPLE_REQUIRED_FOR_DELTA_METRIC. Ganzzahlwerte 1 bis 60 warten mit WAITFOR DELAY auf T2. Die effektive Dauer basiert auf den tatsächlichen UTC-Lesezeiten und DATEDIFF_BIG in Mikrosekunden, nicht auf der angeforderten Sollzeit. Typen 272696320 und 272696576 liefern Zählerdelta je tatsächlicher Sekunde. Typ 537003264 liefert 100 mal Zählerdelta/Basisdelta; 1073874176 liefert Zählerdelta/Basisdelta. Beide Basistypen brauchen positives Sampling sowie vorhandene, steigende Basiswerte; diese Formeln teilen nicht durch Zeit. Sinkender Counter ergibt COUNTER_RESET_DURING_SAMPLE; Basistypen zusätzlich BASE_COUNTER_MISSING, BASE_COUNTER_RESET_DURING_SAMPLE oder BASE_COUNTER_DELTA_ZERO. Bei fehlendem T2 infolge isoliertem Quellenfehler wird T1 als Gegenwert verwendet, also entsteht kein echtes Delta. Unbekannte Typen sind RAW_UNINTERPRETED. NULL und Werte über 60 sind ungültig. Bei ausgelassenem Argument gilt der angegebene Default.

**@MitModulzuordnung:** @MitModulzuordnung bit=1; Default: 1. 0 überspringt sichtbare CLR-Module, direkte Assemblyreferenzen und CLR-Typen; 1 erfasst diese Katalogzeilen für Assemblies im Filter. NULL ist ungültig. Default 1 ist Umfangssteuerung, kein Security-/Berechtigungsgate. Moduldefinitionen und Assembly-Binärinhalte werden nie gelesen. Bei ausgelassenem Argument gilt der angegebene Default.

**@MitBerechtigungsanalyse:** @MitBerechtigungsanalyse bit=0; Default: 0. 0 lässt Assembly-Owner, EXECUTE-AS-Principals und Trust-Zeilenanzahl aus; 1 fordert diese Zusatzdaten an. NULL ist ungültig. Der Pfad verlangt separat CATALOG_DEEP und dessen Gruppen-/High-Impact-Policy. Trust wird nur als serverweite Zeilenanzahl gelesen; Hash, Beschreibung und Assembly-zu-Trust-Zuordnung bleiben ausgeschlossen. Das Flag aktiviert kein CLR. Bei ausgelassenem Argument gilt der angegebene Default.

**@MitSitzungskontext:** @MitSitzungskontext bit=0; Default: 0. 0 lässt Login, Host und Clientprogramm aktiver Managed-Code-Requests NULL; 1 ergänzt genau diese drei Kontextspalten. NULL ist ungültig. Unabhängig vom CATALOG_DEEP-Owner-/Trustpfad. Bei ausgelassenem Argument gilt der angegebene Default.

**@NurProblematisch:** @NurProblematisch bit=0; Default: 0. 0 behält alle Findings; 1 filtert ausschließlich auf Severity=WARN. NULL ist ungültig. Der Filter wirkt auf findings in CONSOLE/RAW/TABLE und JSON-findings, nicht auf übrige Ergebnisarrays, Warnings oder Bewertung. Bei ausgelassenem Argument gilt der angegebene Default.

**@MaxZeilen:** @MaxZeilen int=100; Default: 100. NULL oder 0 bedeutet unbegrenzt; positive Werte begrenzen je Resultset nach Sortierung. Negative Werte sind INVALID_PARAMETER. Begrenzte Mengen: findings nach NurProblematisch, assemblies, assemblyModules, assemblyDependencies, appDomains, loadedAssemblies, clrTasks, activeRequests, memory und performanceCounters. Unbegrenzt bleiben configuration, databaseStatus, sourceStatus, clrProperties und warnings. Die Begrenzung erfolgt nach Materialisierung und reduziert Quellkosten nicht. Der RESULTSET_TRUNCATED-Prüfblock zählt nur findings, assemblies, assemblyModules, assemblyDependencies, appDomains, loadedAssemblies und clrTasks; er deckt eine alleinige Begrenzung von activeRequests, memory oder performanceCounters nicht ab. Bei PrintMeldungen=1 wird die Warnmeldung ausgegeben, wenn diese geprüften Mengen das Limit überschreiten. Bei ausgelassenem Argument gilt der angegebene Default.

**@LockTimeoutMs:** @LockTimeoutMs int=0; Default: 0. 0 setzt LOCK_TIMEOUT 0; 1 bis 60000 setzt Sitzungszeitlimit in Millisekunden. NULL und Werte außerhalb des Bereichs sind ungültig. Das eingehende Sitzungssetting wird am Ende wiederhergestellt. Sampling-Wartezeit wird hierdurch nicht begrenzt; TABLE-Helfer haben eigene lokale DDL-/Metadatenbudgets. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultSetArt:** @ResultSetArt akzeptiert CONSOLE, RAW, TABLE oder NONE; JSON-Erzeugung ist unabhängig davon und TABLE exportiert ausschließlich findings.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. NULL oder Leerraum bedeutet keine Zuordnung; TABLE benötigt ein gültiges JSON-Objekt mit dem einzigen erlaubten case-sensitiven Schlüssel findings und einem nichtleeren JSON-String als lokalem #Temp-Zielnamen. Doppelte JSON-Schlüssel, unbekannte Schlüssel, Nicht-Stringwerte, doppelte Ziele, ##-/permanente Tabellen, über 116 Zeichen oder das case-insensitive reservierte Präfix #Monitor sind ungültig; das vorhandene Ziel muss lokal und leer sein. Der Writer akzeptiert eine leere Zieltabelle mit genau einer beliebigen Seed-Spalte oder eine passende Findingsstruktur. Bei nicht-TABLE und nichtleerem Wert erfolgt THROW 51011 vor Hilfe. TABLE-Preflight kann ebenfalls vor HELP werfen; der spätere Writer läuft nach OUT-Zuweisung und RAW-/JSON-Ausgabe mit ThrowOnError=1, sodass 51010 danach auftreten kann. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. 0 unterdrückt Erstellung; 1 erzeugt ein JSON-Objekt mit meta als Einzelobjekt und benannten Arrays configuration, databaseStatus, sourceStatus, findings, assemblies, assemblyModules, assemblyDependencies, clrProperties, appDomains, loadedAssemblies, clrTasks, activeRequests, memory, performanceCounters und warnings. NULL ist ungültig. JSON ist unabhängig von ResultSetArt. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. OUTPUT wird beim Einstieg auf NULL gesetzt. Bei JsonErzeugen=0 bleibt es NULL; bei 1 enthält es meta und die benannten Arrays. SQL FOR JSON lässt NULL-Eigenschaften standardmäßig aus; leere Collections werden als [] ausgegeben. Die OUTPUT-Bindung muss zum SQL-Typvertrag passen. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@PrintMeldungen:** @PrintMeldungen bit=1; Default: 1. 1 gibt Status- und Truncation-Hinweise als Severity-10-Meldungen aus; 0 unterdrückt sie. NULL ist ungültig. Beeinflusst weder Status-OUTPUT noch strukturierte Warnings. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit=0; Default: 0. 1 druckt Kurzbeschreibung und kehrt vor Analyse/Resultsets zurück; 0 fährt normal fort. NULL wird nicht als 1 behandelt und wird nicht von der Bit-NULL-Validierung erfasst. Ein unzulässiges nichtleeres ResultTablesJson kann bereits vor diesem Zweig THROW 51011 auslösen. Beim frühen Help-Return werden die abschließenden Status-OUTPUTs nicht zugewiesen. Bei ausgelassenem Argument gilt der angegebene Default.

**@StatusCodeOut:** @StatusCodeOut varchar(40)=NULL OUTPUT; Default: NULL. OUTPUT für den globalen Status, getrennt von Quell- und Datenbankstatus. Mögliche globale Werte: AVAILABLE, AVAILABLE_LIMITED, AVAILABLE_WITH_FINDING, NOT_APPLICABLE, FEATURE_DISABLED, INVALID_PARAMETER, UNAVAILABLE_FEATURE, HIGH_IMPACT_CONFIRMATION_REQUIRED, DENIED_GROUP, INTERNAL_ERROR, LOCK_TIMEOUT, ERROR_HANDLED. INTERNAL_ERROR kann defensiv aus der TOP(0)-Tabellenformprobe im Kandidatenhelfer stammen; keine Ursache oder Laufzeitbeobachtung daraus ableiten. Bei Help-Return keine Zuweisung. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@IsPartialOut:** @IsPartialOut bit=NULL OUTPUT; Default: NULL. OUTPUT-Bit der globalen Partialität (1 bei eingeschränkter/fehlgeschlagener Auswertung, sonst 0), getrennt von Quellen-/Datenbankpartialität. Bei Help-Return nicht zugewiesen. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@ErrorNumberOut:** @ErrorNumberOut int=NULL OUTPUT; Default: NULL. OUTPUT für ausgewählte SQL-Fehlernummer aus globaler CATCH- oder partieller Quellenmeldung; NULL, wenn keine gesetzt wurde. Getrennt vom Statuscode. Bei Help-Return nicht zugewiesen. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048)=NULL OUTPUT; Default: NULL. OUTPUT für den global ausgewählten Fehler-/Statusbeschreibungstext: kann Validierungs-, Gate- oder Quellenfehlerdetails enthalten, aus globaler CATCH oder partieller Quellenmeldung stammen, oder NULL sein. Nicht für jeden Status ist eine Fehlerursache gesetzt. Getrennt von Statuscode und strukturierten Warnungen. Bei Help-Return nicht zugewiesen. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| findings | 1 | 1 | [FindingOrdinal] bigint NOT NULL PRIMARY KEY , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ObjectType] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ObjectName] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [Confidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [FindingCode] varchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [MetricName] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [MetricValue] decimal(38,4) NULL , [ThresholdValue] decimal(38,4) NULL , [Evidence] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [RecommendedNextCheck] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_ClrAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

assembly_id ist nur innerhalb einer Datenbank eindeutig. Ohne Binärhash ist keine exakte Zuordnung zu trusted assemblies möglich; die Analyse behauptet daher keinen Trustnachweis.

MEDIUM; Modul- und Dependency-Kataloge skalieren mit der Zahl sichtbarer CLR-Objekte. Sampling wartet höchstens 60 Sekunden.

Rein lesend; aktiviert CLR nicht und lädt keine Assembly.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_ClrAnalysis
Version      : 1.0.0
Stand        : 2026-07-22
Typ          : Stored Procedure
Zweck        : Die Procedure analysiert SQL-CLR-Konfiguration, benutzerdefinierte Assemblies,
               Module, Abhängigkeiten, Host Properties, AppDomains, geladene
               Assemblies, CLR Tasks, aktive Requests, Speicher und Counter.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.configurations, sys.databases, sys.assemblies,
               sys.assembly_modules, sys.assembly_references,
               sys.assembly_types, sys.dm_clr_properties,
               sys.dm_clr_appdomains, sys.dm_clr_loaded_assemblies,
               sys.dm_clr_tasks, sys.dm_os_tasks, sys.dm_exec_requests,
               sys.dm_exec_sessions, sys.dm_os_memory_clerks,
               sys.dm_os_performance_counters und optional
               sys.trusted_assemblies.
Datenschutz  : Liest keine Assembly-Binärinhalte, Hashes, Moduldefinitionen,
               SQL-Texte oder Pläne. Principal- und Sitzungskontext sind
               getrennte Opt-ins.
Methodik     : Jede Server-DMV wird einmal je Messpunkt materialisiert.
               Geladene Assemblies werden über AppDomain-Datenbank und
               assembly_id vorsichtig mit sichtbaren Katalogzeilen verbunden.
Grenzen      : assembly_id ist nur innerhalb einer Datenbank eindeutig. Ohne
               Binärhash ist keine exakte Zuordnung zu trusted assemblies
               möglich; die Analyse behauptet daher keinen Trustnachweis.
Kosten       : MEDIUM; Modul- und Dependency-Kataloge skalieren mit der Zahl
               sichtbarer CLR-Objekte. Sampling wartet höchstens 60 Sekunden.
Nebenwirkung : Rein lesend; aktiviert CLR nicht und lädt keine Assembly.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_ClrAnalysis
Die Analyseinventur erstellt keine CLR-Assembly, aktiviert CLR nicht und führt keine CLR-Funktion aus; Installation und Betrieb von Analyze setzen weder CLR noch eine LLM-Runtime, Netzwerkverbindung oder LLM-Berechtigungen voraus.
Die Procedure erfasst ausschließlich sichtbare SQL-CLR-Konfiguration, Katalogmetadaten und aktuelle Host-/Counterevidenz; sie lädt oder führt keine Assembly aus und aktiviert CLR nicht.
Beispiel 1: EXEC [monitor].[USP_ClrAnalysis] @Hilfe=1;
Beispiel 2: EXEC [monitor].[USP_ClrAnalysis] @DatabaseNames=N'[ExampleDatabase]', @AssemblyNames=N'[ExampleAssembly]', @MitModulzuordnung=0, @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
Beispiel 3: DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_ClrAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];
Beispiel 4: CREATE TABLE [#ClrAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ClrAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#ClrAnalysis_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#ClrAnalysis_HelpExample]; DROP TABLE IF EXISTS [#ClrAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#ClrAnalysis_HelpExample]; THROW; END CATCH;
Beispiel 5: EXEC [monitor].[USP_ClrAnalysis] @DatabaseNamePattern=N'like:ExampleDatabase%', @AssemblyNamePattern=N'like:ExampleAssembly%', @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
Beispiel 6: EXEC [monitor].[USP_ClrAnalysis] @DatabaseNames=N'[ExampleDatabase]', @SampleSeconds=1, @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
Beispiel 7: EXEC [monitor].[USP_ClrAnalysis] @DatabaseNames=N'[ExampleDatabase]', @MitBerechtigungsanalyse=1, @HighImpactConfirmed=1, @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
```

