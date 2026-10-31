# [monitor].[USP_CheckAnalyseAccess]

**Bereich:** Common<br>
**Zweck:** Prüft, ob der aktuelle Sicherheitskontext eine Analyseklasse gemäß Framework-Policy ausführen darf.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Erlaubt die Frameworkpolicy dem aktuellen Sicherheitskontext die angeforderte Analyseklasse?** Sie unterstützt die Entscheidung, ob der gewünschte Analysepfad sicher und eindeutig vorbereitet ist oder der Fachaufruf wegen Policy, Capability oder ungültigem Scope unterbleiben muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Performance- oder Verfügbarkeitsursache und keine Aussage über Daten außerhalb des aktuellen Execution-Kontexts. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CheckAnalyseAccess]
      @ResultSetArt = 'CONSOLE';
```

Für vollständige Spalten `@ResultSetArt='RAW'`; für Parameterhilfe `@Hilfe=1`.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Hilfe und Aufrufe

Die Hilfe wird bei @Hilfe=1 unabhängig von @PrintMeldungen ausgegeben; @Json wird vorher auf NULL gesetzt. Die TABLE-Zuordnung wird vor der Hilfe validiert. Bei ungültiger Zuordnung kann der Aufruf daher vor den Hilfetexten mit Fehler 51011 oder einem Preflightfehler enden.

| Parameter | Typ, Default, Eingabeform und Wirkung |
|---|---|
| `@AnalyseKlasse` | varchar(64), Default NULL. Ausgelassen oder NULL wählt alle 31 Klassen. Sonst wird der Wert mit der Katalogspalte unter SQL_Latin1_General_CP1_CS_AS verglichen; es gibt kein LTRIM/RTRIM. Groß-/Kleinschreibung zählt; SQL-Gleichheit kann nachgestellte U+0020 auffüllen. Leer oder nicht passend ergibt INVALID_PARAMETER. Wirkung: auf eine Klasse begrenzen. Zulässige Klassen mit Bedeutung:<br>`STANDARD_CURRENT` = leichte aktuelle Sessions, Requests, Blocking, Waits, Memory, TempDB und I/O<br>`EXTENDED_CURRENT` = gezielte aktuelle Vertiefung mit begrenzter SQL-Text-, Plan- und Objektauflösung<br>`PLAN_CACHE_CURRENT` = begrenzte Query-Stats- und Plan-Cache-Auswertung ohne vollständiges XML-Shredding<br>`SHOWPLAN_TARGETED` = gezielte Showplan-Extraktion/XML-Analyse für gefilterte Planhandles oder Query Hashes<br>`OBJECT_ANALYSIS_CURRENT` = gezielte Objekt-, Index-, Partitions- und Columnstore-Kataloganalyse einer Datenbank<br>`EXTERNAL_RUNTIME_CURRENT` = lesende Konfigurations-, Katalog-, Request-, Pool- und Counteranalyse externer Runtimes, ohne Testausführung<br>`CLR_CURRENT` = lesende SQL-CLR-, Host-, AppDomain-, Task-, Request- und Speicheranalyse, ohne Assemblyausführung<br>`MISSING_INDEX_CURRENT` = flüchtige begrenzte Missing-Index-Hinweise, keine automatische DDL<br>`STATISTICS_TARGETED` = gezielte Statistik-Eigenschaften gefilterter Objekte<br>`COLUMNSTORE_CURRENT` = gezielte Columnstore-Rowgroups aus Katalogen, kein Segment-/Dictionary-Vollscan<br>`LOCKS_DEEP` = detaillierte sys.dm_tran_locks-Materialisierung für relevante Sessions<br>`LOG_VLF_DEEP` = datenbankübergreifende VLF-Auswertung via sys.dm_db_log_info<br>`PLAN_CACHE_DEEP` = breite oder vollständige Query-Stats- und Plan-Cache-Analyse<br>`SHOWPLAN_XML_DEEP` = XML-Analyse gecachter/aktueller Showplans mit Warnings, Spills, Objekten, Statistiken<br>`CATALOG_DEEP` = breite Systemkatalog-, Objekt-, Index-, Statistik- und Partitionsanalyse<br>`PHYSICAL_STATS_DEEP` = explizite sys.dm_db_index_physical_stats-Auswertung in gewähltem Modus<br>`INDEX_OPERATIONAL_DEEP` = breite kumulative Index-Operational-Stats mit Lock/Latch/I/O/Page-Splits<br>`QUERY_STORE_CURRENT` = gezielte lesende Query-Store-Status-, Runtime-, Wait-, Plan-/Force-Auswertung, enges Zeit-/Zeilenlimit<br>`EXTENDED_EVENTS_CURRENT` = leichte Inventarisierung von Extended-Events-Definitionen und laufenden Sessions, ohne Targetdaten/Historie<br>`QUERY_STORE_DEEP` = breite Query-Store-Historie, Regressionen, Planwechsel und Waits<br>`CROSS_DATABASE_DEEP` = datenbankübergreifende Inventarisierung und Diagnose<br>`COLUMNSTORE_DEEP` = breite Columnstore-Analyse mit Rowgroups, Deleted Rows, Dictionaries und Segmenten<br>`EXTENDED_EVENTS_FORENSICS_DEEP` = optionale Analyse vorhandener XE-Sessions/Dateien, nie Primärquelle des Standardlaufs<br>`SERVER_HEALTH_CURRENT` = CPU-, NUMA-, Memory-, TempDB-, OS- und Dienstzustand der Instanz<br>`SERVER_CONFIGURATION_CURRENT` = lesende Serverkonfiguration, Trace Flags und Startup-Parameter<br>`SECURITY_CONFIGURATION_CURRENT` = lesende sicherheits- und dienstbezogene Betriebsparameter<br>`SQL_AGENT_CURRENT` = lesender SQL-Agent-Status, Jobs, Schedules und Historie aus msdb<br>`RESOURCE_GOVERNOR_CURRENT` = lesende Resource-Governor-Konfiguration und Laufzeit<br>`HA_DR_CURRENT` = begrenzte lesende AG-, Backup-, Log-Shipping-, Replication-, CDC- und Change-Tracking-Analyse<br>`ENTERPRISE_TOPOLOGY_DEEP` = vertiefte enterpriseweite HA/DR- und Replication-Topologie/Distribution<br>`DATA_PLATFORM_ADAPTER_CURRENT` = optionale Current-State-Anreicherung aus kundenspezifischen Data-Platform-/ETL-Logs mit isolierter Existenz-/Rechteprüfung |
| `@NurGesperrte` | bit, Default 0. 0 liefert alle Accesszeilen; 1 nur Zeilen mit IsAllowed=0. NULL wirkt im SQL-Filter ebenfalls wie 1. Filtert nur Access, nicht Policies. Ausgelassen verwendet 0. |
| `@ResultSetArt` | varchar(16), Default 'CONSOLE'. Werte: CONSOLE rendert Access und liefert Policies/Warnings zusätzlich; RAW liefert Meta, Access, Policies, Warnings als vier Resultsets; TABLE exportiert nur Access; NONE unterdrückt fachliche Resultsets. Eingabe wird mit LTRIM/RTRIM an äußeren U+0020 entfernt und mit UPPER normalisiert. NULL/sonst ungültig ergibt INVALID_PARAMETER. Ausgelassen = CONSOLE. |
| `@ResultTablesJson` | nvarchar(max), Default NULL. NULL/ausgelassen bedeutet keine Zuordnung. Für TABLE ist ein nichtleeres gültiges JSON-Objekt mit genau dem nach U+0020-Trimmen case-sensitiven Schlüssel "access" und einem nach U+0020-Trimmen nichtleeren JSON-String als Ziel erforderlich; Schlüssel und Ziele müssen eindeutig sein. Zielname: vorhandene lokale #temp-Tabelle, nie ##, höchstens LEN 116, nicht #Monitor* (case-insensitiv); muss leer sein und genau eine beliebig typisierte Seed-Spalte enthalten. Der Preflight fügt vorübergehend eine bit-NULL-Prüfspalte hinzu/entfernt sie wieder; das ist keine Seed-Typvorgabe. U+0020 außen am JSON wird für Objektklammern getrimmt; leere/ungültige JSON-Objekte, falsche Schlüssel/Werttypen, leere Namen, Duplikate, unzulässige Namen, fehlendes/gefülltes/mehrspaltiges Ziel scheitern im Preflight (bei Procedure-Aufruf THROW 51011). Außerhalb TABLE führt jede nichtleere Zuordnung zu THROW 51011. |
| `@JsonErzeugen` | bit, Default 0. 0/NULL erzeugt kein JSON; 1 erzeugt @Json mit meta sowie access-, policies- und warnings-Arrays. Ausgelassen verwendet 0. |
| `@Json` | nvarchar(max), Default NULL OUTPUT. Als OUTPUT-Variable binden, um das erzeugte Dokument zu erhalten; bei deaktiviertem JSON bleibt es NULL. Der Eingangswert wird zu Beginn vor TABLE-Preflight und Hilfe verworfen und auf NULL gesetzt. Ausgelassen ist möglich, dann wird kein Wert empfangen. |
| `@PrintMeldungen` | bit, Default 1. 1 gibt eine zusätzliche Severity-10-Meldung für behandelte Fehler aus; 0 oder NULL unterdrückt nur diese Meldung, nicht Hilfe, Resultsets, Warnings oder JSON. Ausgelassen = 1. |
| `@Hilfe` | bit, Default 0. 1 druckt die Hilfe und beendet vor der fachlichen Accessauswertung; NULL/0 führt normal aus. Hilfe ist unabhängig von @PrintMeldungen. Bei TABLE liegt der Mapping-Preflight davor und kann TempDB-Metadaten ändern oder mit 51011 abbrechen. @Json ist vorher bereits NULL. |

CONSOLE rendert ausschließlich Access; bei leerem Access zeigt der Renderer „Keine fachlichen Ergebnisse“. RAW liefert vier Resultsets: Meta, Access, Policies und Warnings. TABLE schreibt nur access mit zwölf typisierten Feldern. NONE unterdrückt fachliche Resultsets; JSON und Meldungen bleiben unabhängig. Für TABLE muss das Ziel eine vorhandene, leere lokale #temp-Tabelle mit genau einer Seed-Spalte beliebigen Datentyps sein. Der Preflight prüft die Tabellenstruktur, indem er vorübergehend eine bit-NULL-Prüfspalte hinzufügt und wieder entfernt; dies legt den Typ der Seed-Spalte nicht fest. Der Preflight kann lokale TempDB-Metadaten per DDL ändern. 

Die Entscheidung stammt aus Katalog, aktuellen Framework-Views, sys.login_token und IS_MEMBER; sie ist eine Momentaufnahme. Ungeschützte Klassen erhalten NOT_REQUIRED, Sysadmins SYSADMIN. Ohne global aktive Policy gilt OPEN_POLICY; andernfalls zählen Login-Token-Treffer vor IS_MEMBER, sonst lautet der Grund NO_MATCH. Eine aktive globale Policy kann geschützte Klassen ohne spezifische oder Wildcardregel sperren. Priority wird mitgeführt und sortiert, priorisiert aber keine Freigabe. MatchedGroupCount summiert Klassen- und Wildcardtreffer und ist keine Anzahl eindeutiger Gruppen.

~~~sql
-- Hilfe
EXEC [monitor].[USP_CheckAnalyseAccess] @Hilfe=1;
-- Standardausgabe
EXEC [monitor].[USP_CheckAnalyseAccess];
-- Scoped RAW
EXEC [monitor].[USP_CheckAnalyseAccess] @AnalyseKlasse='PLAN_CACHE_DEEP', @ResultSetArt='RAW';
-- Nur gesperrte Accesszeilen
EXEC [monitor].[USP_CheckAnalyseAccess] @NurGesperrte=1, @ResultSetArt='RAW';
-- JSON-Ausgabe
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_CheckAnalyseAccess] @JsonErzeugen=1, @Json=@Json OUTPUT;
SELECT @Json;
-- Keine fachlichen Resultsets
EXEC [monitor].[USP_CheckAnalyseAccess] @ResultSetArt='NONE', @JsonErzeugen=1;
-- TABLE-Ziel
CREATE TABLE #CheckAnalyseAccess_HelpExample (Seed bit NULL);
DECLARE @Map nvarchar(max)=N'{"access":"#CheckAnalyseAccess_HelpExample"}';
EXEC [monitor].[USP_CheckAnalyseAccess] @ResultSetArt='TABLE', @ResultTablesJson=@Map;
DROP TABLE #CheckAnalyseAccess_HelpExample;
~~~

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert ausschließlich `access`. RAW liefert zuerst Meta, danach Access, Policies und Warnings. CONSOLE rendert Access; JSON enthält den technischen Kontext in `meta`, `access`, `policies` und `warnings`. TABLE schreibt ausschließlich das benannte Accessresultset. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Eine Access-Zeile beschreibt das effektive Gate-Ergebnis für eine Analyseklasse. Policy-Zeilen beschreiben jeweils eine konfigurierte Gruppenregel.

## So lesen

Berücksichtigen Sie zuerst `IsAllowed`, danach `AccessReason`, `RelevantPolicyCount` und `MatchedGroupCount`. Vergleichen Sie anschließend Original- und Effektivlogin.

## Warum kann das problematisch sein?

`RelevantPolicyCount > 0` und `MatchedGroupCount = 0` bedeutet: Für die Analyseklasse existieren Regeln, aber keine passende Gruppenmitgliedschaft wurde erkannt. Die Sperre ist dann erwartbares Policyverhalten und kein DMV-Defekt.

## Wann ist es kein Problem?

`AccessReason=OPEN_POLICY` bedeutet, dass global keine aktive Policy vorhanden ist. Bei vorhandenen global aktiven Policies kann eine geschützte Klasse trotz `RelevantPolicyCount = 0` gesperrt sein.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** `IsAllowed=0` mit `AccessReason=NO_MATCH` verlangt eine Prüfung der Gruppenpolicy, nicht das vorschnelle Erteilen zusätzlicher SQL-Rechte. Prüfen Sie danach mit `USP_CheckFrameworkCapabilities` die technische Lesbarkeit.

**Ähnlich aussehender Gegenfall:** `RelevantPolicyCount = 0` belegt bei vorhandenen global aktiven Policies keine Freigabe. `IsAllowed` und `AccessReason` bilden den tatsächlichen Gate-Entscheid ab.

## Leere oder partielle Ausgabe

`@NurGesperrte=1` kann die Access-Ausgabe leeren, wenn im ausgewählten Klassen-Scope keine gesperrte Klasse vorliegt; die Policy-Ausgabe wird davon nicht gefiltert und kann weiterhin Zeilen enthalten. `@AnalyseKlasse` begrenzt den Klassen-Scope. Ein ungültiger Klassen- oder Ausgabeparameter erscheint als `INVALID_PARAMETER` im Meta-Status; ein behandelter Ausführungsfehler erscheint als `ERROR_HANDLED` und wird im Warning-Kontext erläutert. RAW liefert Meta und Warnings, JSON enthält `meta` und `warnings`; beide erlauben, eine leere Accessmenge vom Status her einzuordnen. CONSOLE rendert Access und zeigt bei leerer Accessmenge die Meldung „Keine fachlichen Ergebnisse“.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | `@AnalyseKlasse = NULL` bewertet alle Klassen aus `VW_AnalyseAccessCurrent` und alle aktuell gültigen Policies. Für jede Policy werden Login-Token-Match und `IS_MEMBER` bestimmt. |
| Teuerster Pfad | Viele definierte Analyseklassen und aktive Gruppenpolicies mit langen Kommentaren. Datenbankzahl, Nutzdaten und Fach-DMVs beeinflussen den Pfad nicht. |
| Haupttreiber | Zahl der Analyseklassen und gültigen Policyzeilen; `sys.login_token` wird je Policy per Existenzprüfung verglichen, zusätzlich erfolgt je Gruppe ein `IS_MEMBER`-Check. |
| Skalierung | Accesszeilen wachsen mit Klassen, Policyzeilen mit Gruppenregeln. JSON/RAW übertragen zusätzlich Policykommentare; die Quellmenge bleibt Framework-/Security-Metadaten. |
| Ressourcen | Views über Frameworkpolicy, Login-Token-/Membershipprüfungen und kleine Temp-Tabellen. Keine Datenbankenumeration, Capabilityprobe oder Nutzdatenabfrage. |
| Begrenzungswirkung | `@AnalyseKlasse` ist der wirksamste Kostenscope. `@NurGesperrte` filtert die Accessausgabe, aber die für den Scope gültigen Policies werden weiterhin geprüft.  |
| Locking und Nebenwirkungen | Die Procedure liest Framework- und Sicherheitsmetadaten und verwendet lokale Temp-Tabellen; der TABLE-Preflight kann vor der Hilfe eine Seed-Spalte temporär per DDL ergänzen und entfernen. Policygültigkeit wird gegen `SYSUTCDATETIME()` geprüft; Gruppenmitgliedschaft oder Policy kann direkt nach dem Snapshot wechseln. Es werden keine Tokens oder Rollen verändert. |
| Schutzmechanismus | Diese Procedure entscheidet Zugänglichkeit, führt aber selbst keine Fachanalyse und kein High-Impact-Gate aus. `@AnalyseKlasse` beschränkt die zu prüfenden Klassen; `@NurGesperrte` reduziert nur die Ausgabe. Ein global leerer aktiver Policybestand ist offen; bei mindestens einer global aktiven Policy kann eine geschützte Klasse ohne spezifische oder globale Regel gesperrt sein. |
| Sicherer Einsatz | Für eine Freigabeentscheidung eine konkrete dokumentierte Analyseklasse prüfen; Gesamtübersicht nur für Policy-Audits. Login- und Gruppennamen als sensible Security-Metadaten behandeln. |
| Aussagegrenze | `IsAllowed` beschreibt ausschließlich die Framework-Gruppenpolicy im aktuellen Login-Kontext. Objekt-/DMV-Berechtigungen, Datenbanksichtbarkeit und `@HighImpactConfirmed` werden hier nicht bewiesen. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Erlaubt die Frameworkpolicy dem aktuellen Sicherheitskontext die angeforderte Analyseklasse?

### Technischer Hintergrund

Das Framework besitzt eine zusätzliche Berechtigungsschiene oberhalb der SQL-Server-Quellberechtigungen. Es prüft Original- und Effektivlogin, sysadmin-Bypass sowie sichtbare Login-/Gruppentokens. Ohne global aktive Policy bleibt der Gate offen. Sobald global aktive Policies existieren, können geschützte Klassen ohne spezifische oder globale Regel gesperrt sein; ein passender Token- oder IS_MEMBER-Treffer öffnet den Gate.

### Datenkette

`sys.login_token`.

### Source Select

Die effektive Policy basiert auf aktiven Policyzeilen und Gruppen im Login-Token. Das relevante Grundselect lautet:

```sql
SELECT
      [p].[AnalysisClass]
    , [p].[ADGroupName]
    , [lt].[name] AS [MatchedLoginToken]
FROM [monitor].[VW_AnalyseAccessPolicy] AS [p]
LEFT JOIN [sys].[login_token] AS [lt] WITH (NOLOCK)
  ON UPPER(CONVERT(nvarchar(256), [lt].[name])) COLLATE Latin1_General_100_CI_AS
   = UPPER([p].[ADGroupName]) COLLATE Latin1_General_100_CI_AS
 AND [lt].[type] = N'WINDOWS GROUP'
WHERE [p].[IsEnabled] = 1
  AND [p].[AnalysisClass] IN ('PLAN_CACHE_DEEP', '*');
```

**Wichtig für die Eigenlast:** Die Mengen sind klein. Der Klassenfilter verhindert unnötige `IS_MEMBER`-Fallbackprüfungen; die öffentliche Procedure ergänzt außerdem offene Policy und sysadmin-Bypass.

### Zeit- und Scope-Modell

Die Auswertung liefert eine Momentaufnahme des aktuellen Login- und Execution-Kontexts. Gruppenauflösung kann sich durch Token, Impersonation oder Verzeichniszustand vom erwarteten Benutzerbild unterscheiden.

### Bewertung und Gegenprobe

Berücksichtigen Sie `IsAllowed`, Policyanzahl, gematchte Gruppen und AccessReason gemeinsam. Ein Deny bei vorhandener Policy und ohne Match ist erwartetes Policyverhalten; SQL-Quellrechte zu erweitern würde die Frameworksperre nicht fachlich lösen.

### Typische Fehlinterpretation

`IsAllowed=1` beweist nicht, dass die benötigten DMVs tatsächlich lesbar sind. Umgekehrt ist ein leeres Fachresultset kein Beweis für Policy-Deny.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_CheckFrameworkCapabilities` trennt anschließend Feature-, Rechte- und Queryabilityprobleme.

## Primärquellen

- [sys.login_token](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-login-token-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../01_Common.md#2-monitorusp_checkanalyseaccess)
