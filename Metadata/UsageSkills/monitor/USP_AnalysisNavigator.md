---
skill_format_version: "1.0.0"
name: "monitor.USP_AnalysisNavigator"
schema_name: "monitor"
object_name: "USP_AnalysisNavigator"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Findet priorisierte Analyse-Procedures nach Symptom, Ziel, Fachbegriff, Themenbereich, Scope oder Navigationsrolle."
source_path: "Code/01_Common/100_USP_AnalysisNavigator.sql"
---

# monitor.USP_AnalysisNavigator

## Zweck und Einsatz

Findet priorisierte Analyse-Procedures nach Symptom, Ziel, Fachbegriff, Themenbereich, Scope oder Navigationsrolle.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

monitor.VW_AnalysisCatalog, monitor.VW_AnalysisSearchTerm, monitor.VW_AnalysisRelation, monitor.VW_AnalyseClassCatalog, sys.schemas, sys.procedures.

Nur lesender Zugriff auf Framework- und lokale Systemmetadaten.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @Suchbegriff | nvarchar(4000) | nein | NULL |
| @Bereich | varchar(40) | nein | NULL |
| @Scope | varchar(40) | nein | NULL |
| @Navigationsrolle | varchar(24) | nein | NULL |
| @NurInstallierte | bit | nein | 0 |
| @MaxZeilen | int | nein | 12 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@Suchbegriff:** @Suchbegriff nvarchar(4000), Default=NULL: freier Unicode-Suchtext; NULL, leer oder nur Rand-Leerzeichen deaktiviert die Textsuche; ohne Bereichs-, Scope- und Rollenfilter erscheint die kuratierte Startliste, mit solchen Filtern die passende Katalogmenge. Getrimmt höchstens 400 Zeichen, sonst INVALID_PARAMETER. Suche case- und accent-insensitiv; technische Namenssuche entfernt [ ] und führendes monitor.; Tokens an Leerzeichen, unter 3 Zeichen/Stoppwörter entfallen, je Token max. 200 Zeichen.

**@Bereich:** @Bereich varchar(40), Default=NULL: NULL/leer deaktiviert den Filter; sonst getrimmt, uppercase und case-/accent-insensitiv gegen PrimaryAreaCode. Nur diese Katalogcodes: NAVIGATION=Einstieg/Orientierung; FRAMEWORK=Framework/Zugriff; LIVE=akute Störung/laufende Requests sowie aktuelle Aktivität, Blocking und Ressourcen; OBJECT=Objekte/Indizes/Statistiken; PLAN=langsame Query/Ausführungsplan; QUERY_STORE=Query Store/Laufzeithistorie und Regressionen; EXTENDED_EVENTS=Extended Events/Forensik; OPERATIONS=Backup/Agent/HA-DR/Betrieb; SERVER=CPU/Memory/Worker, Serverzustand/Ressourcen, Server Health, Konfiguration und Sicherheit; SPECIAL_FEATURE=Konfiguration/Sicherheit/Spezialfeatures; SNAPSHOT=optionales Snapshot-/Baseline-Paket. Andere Werte ergeben INVALID_PARAMETER.

**@Scope:** @Scope varchar(40), Default=NULL: NULL/leer deaktiviert den Filter; sonst getrimmt, uppercase und case-/accent-insensitiv gegen ScopeCode. Katalogcodes samt Einheit: DATABASE=eine Datenbank; EVENT_HISTORY=persistierte Ereignishistorie; EVENT_SESSION=Ereignissitzung; FRAMEWORK=Frameworkmetadaten; INFRASTRUCTURE=lokale Infrastruktur; MULTI_DATABASE=mehrere Datenbanken; OBJECT=bekanntes Objekt; PLAN_XML=Ausführungsplan-XML; QUERY=Query; SERVER=Instanz; SESSION_REQUEST=Session/Request; SNAPSHOT_TARGET=Snapshotziel. Andere Werte ergeben INVALID_PARAMETER.

**@Navigationsrolle:** @Navigationsrolle varchar(24), Default=NULL: NULL/leer deaktiviert den Filter; sonst getrimmt, uppercase und case-/accent-insensitiv. ENTRY=sicherer allgemeiner Einstieg; FOLLOW_UP=Folgepfad zu einem bereits beobachteten Signal; TARGETED=gezielter Pfad mit bekanntem Ziel; SETUP=Setup-/Betriebspfad; SUPPORT=interner Unterstützungs-/Aufrufvertrag. Nur diese fünf Werte; andere ergeben INVALID_PARAMETER.

**@NurInstallierte:** @NurInstallierte bit, Default=0: NULL ist INVALID_PARAMETER; 0 zeigt alle passenden Katalogzeilen einschließlich optional nicht installierter Procedures, 1 beschränkt auf lokal im Schema monitor in sys.procedures vorhandene Procedures. Keine Prüfung von Rechten oder Featurefähigkeit.

**@MaxZeilen:** @MaxZeilen int, Default=12: NULL oder 0 bedeutet kein Ergebnislimit; 1 bis 100 begrenzt Treffer auf diese Zeilenzahl. Negative Werte und Werte über 100 ergeben INVALID_PARAMETER.

**@ResultSetArt:** @ResultSetArt varchar(16), Default=CONSOLE: nach Trim und Uppercase genau CONSOLE, RAW, TABLE oder NONE. CONSOLE rendert navigation; RAW liefert Status dann navigation; TABLE schreibt navigation ins Ziel; NONE unterdrückt Resultsets. NULL, leer und andere Werte ergeben INVALID_PARAMETER, ohne Rückfall auf CONSOLE. Ein ungültiger Ausgabewert liefert Status und navigation.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max), Default=NULL: Bei TABLE ist ein JSON-Objekt mit genau einem Schlüssel navigation und einem JSON-String als Wert erforderlich. Der String benennt eine vorhandene, leere lokale #Temp-Tabelle mit genau einer beliebigen Seed-Spalte. NULL, leer oder nur Leerzeichen ist bei TABLE ungültig; außerhalb TABLE darf nur NULL, leerer Text oder ein Text nur aus Leerzeichen stehen. Eine nichtleere Zuordnung außerhalb TABLE löst THROW 51011 aus. Zielprüfung mit Marker-DDL läuft vor Hilfe.

**@JsonErzeugen:** @JsonErzeugen bit, Default=0: 1 erzeugt @Json mit meta und navigation aus derselben Materialisierung; 0 oder NULL deaktiviert JSON. Unabhängig von @ResultSetArt.

**@Json:** @Json nvarchar(max), Default=NULL OUTPUT: optionale Bindung einer nvarchar(max)-Variablen mit OUTPUT, wenn JSON empfangen werden soll; Default NULL bedeutet keinen Eingabewert. Wird beim Eintritt auf NULL gesetzt. Bei @JsonErzeugen=1 enthält die Variable meta und navigation; bei @Hilfe=1 bleibt sie NULL.

**@PrintMeldungen:** @PrintMeldungen bit, Default=1: nur 1 aktiviert die zusätzliche Severity-10-Fehlermeldung im CATCH; 0 oder NULL unterdrückt sie. Keine Wirkung auf Hilfe, Resultsets oder JSON.

**@Hilfe:** @Hilfe bit, Default=0: nur 1 druckt diese Hilfe und beendet vor Suche/Rendering; 0 oder NULL deaktiviert sie. TABLE-Preflight läuft vorher und kann bei ungültigem Ziel abbrechen.

## Resultate und Ausgabe

RAW: Modulstatus und navigation. CONSOLE: navigation oder eine verständliche Leerzeile. TABLE: navigation. NONE: keine.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| navigation | 1 | 1 | [Rank] int NOT NULL , [RelevanceScore] int NOT NULL , [ProcedureName] sysname NOT NULL , [DisplayName] nvarchar(160) NOT NULL , [NavigationRole] varchar(24) NOT NULL , [PrimaryAreaCode] varchar(40) NOT NULL , [PrimaryAreaName] nvarchar(160) NOT NULL , [ScopeCode] varchar(40) NOT NULL , [EvidenceType] varchar(40) NOT NULL , [CostRangeCode] varchar(32) NOT NULL , [RepresentativeAnalysisClass] varchar(64) NULL , [AnalysisLevel] varchar(16) NULL , [RequiresGroupGate] bit NULL , [WhyMatched] nvarchar(500) NOT NULL , [Purpose] nvarchar(1000) NOT NULL , [PrerequisiteSummary] nvarchar(1000) NOT NULL , [RequiresKnownTarget] bit NOT NULL , [RequiresHighImpactForSafeStart] bit NOT NULL , [HighImpactPathAvailable] bit NOT NULL , [PackageCode] varchar(32) NOT NULL , [IsInstalled] bit NOT NULL , [SafeCall] nvarchar(2000) NOT NULL , [NextProcedureName] sysname NULL , [RelationType] varchar(24) NULL , [NextStep] nvarchar(700) NULL , [RunbookPath] nvarchar(400) NULL , [DocumentationPath] nvarchar(400) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_AnalysisNavigator] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_AnalysisNavigator

Der Navigator zeigt passende Katalogeinträge. Er führt keinen Treffer und keine Analyse aus.

Für bit-Parameter gelten 0 und 1 logisch; andere in bit konvertierbare Nicht-NULL-Werte werden durch T-SQL zu 1 konvertiert.

Exakte Procedure-/Anzeigenamen und Phrasen wiegen stärker als Tokenüberschneidungen; Treffer werden nach Score, Rolle und Namen geordnet. Rollen geben nur einen kleinen Bonus. Ohne Filter gilt die kuratierte DefaultRank-Liste.

CONSOLE liefert navigation, bei leerer Menge mit verständlicher Leerzeile. RAW liefert zuerst Status und dann navigation; TABLE schreibt navigation; NONE unterdrückt Resultsets.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_AnalysisNavigator
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Stored Procedure
Zweck        : Findet priorisierte Analyse-Procedures nach Symptom, Ziel,
               Fachbegriff, Themenbereich, Scope oder Navigationsrolle.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : monitor.VW_AnalysisCatalog,
               monitor.VW_AnalysisSearchTerm,
               monitor.VW_AnalysisRelation,
               monitor.VW_AnalyseClassCatalog,
               sys.schemas, sys.procedures.
Sicherheit   : Führt keine gefundene Procedure aus. Liest keine produktiven
               DMVs, Benutzerkataloge, Querytexte, Pläne oder Ereignisdaten.
Suche        : Explizit case- und accent-insensitiv; unabhängig von der
               Datenbankcollation. Deutsch- und englischsprachige Begriffe.
Resultsets   : RAW: Modulstatus und navigation. CONSOLE: navigation oder eine
               verständliche Leerzeile. TABLE: navigation. NONE: keine.
JSON         : meta, navigation.
Berechtigung : Nur lesender Zugriff auf Framework- und lokale Systemmetadaten.
Eigenlast    : Gering; ausschließlich konstanter Katalog und lokale
               Installationsprüfung.
Locking      : LOCK_TIMEOUT 0; Systemkatalogzugriffe WITH (NOLOCK).
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_AnalysisNavigator
Der Navigator zeigt passende Katalogeinträge. Er führt keinen Treffer und keine Analyse aus.
Für bit-Parameter gelten 0 und 1 logisch; andere in bit konvertierbare Nicht-NULL-Werte werden durch T-SQL zu 1 konvertiert.
Exakte Procedure-/Anzeigenamen und Phrasen wiegen stärker als Tokenüberschneidungen; Treffer werden nach Score, Rolle und Namen geordnet. Rollen geben nur einen kleinen Bonus. Ohne Filter gilt die kuratierte DefaultRank-Liste.
CONSOLE liefert navigation, bei leerer Menge mit verständlicher Leerzeile. RAW liefert zuerst Status und dann navigation; TABLE schreibt navigation; NONE unterdrückt Resultsets.
Bei leerem RAW/TABLE-Ergebnis gibt es keine künstliche navigation-Zeile. JSON enthält meta und ein leeres navigation-Array; NONE beeinflusst JSON und Meldungen nicht.
Beispiel Suche: EXEC [monitor].[USP_AnalysisNavigator] @Suchbegriff=N'Benutzer warten', @ResultSetArt='RAW';
Beispiel JSON: DECLARE @Json nvarchar(max); EXEC [monitor].[USP_AnalysisNavigator] @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json;
Beispiel TABLE: CREATE TABLE #AnalysisNavigator_HelpExample (Seed bit NULL);
DECLARE @Map nvarchar(max)=N'{"navigation":"#AnalysisNavigator_HelpExample"}'; EXEC [monitor].[USP_AnalysisNavigator] @ResultSetArt='TABLE', @ResultTablesJson=@Map; DROP TABLE #AnalysisNavigator_HelpExample;
```

