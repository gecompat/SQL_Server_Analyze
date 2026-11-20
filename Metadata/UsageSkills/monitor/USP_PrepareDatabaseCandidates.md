---
skill_format_version: "1.0.0"
name: "monitor.USP_PrepareDatabaseCandidates"
schema_name: "monitor"
object_name: "USP_PrepareDatabaseCandidates"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Validiert die frameworkweite Datenbankauswahl, prüft den tatsächlich aktivierten Analysepfad und befüllt lokale Kandidaten- und Warning-Temp-Tabellen des Aufrufers."
source_path: "Code/01_Common/083_USP_PrepareDatabaseCandidates.sql"
---

# monitor.USP_PrepareDatabaseCandidates

## Zweck und Einsatz

Validiert die frameworkweite Datenbankauswahl, prüft den tatsächlich aktivierten Analysepfad und befüllt lokale Kandidaten- und Warning-Temp-Tabellen des Aufrufers.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_PrepareDatabaseCandidates]. Die Quelle nennt insbesondere `[monitor].[TVF_ParseSqlNameList]`, `[sys].[sp_executesql]`, `[monitor].[TVF_ParsePattern]`, `[monitor].[InternalCheckAnalysisPath]`, `[monitor].[TVF_DatabaseCandidates]`, `[master].[sys].[databases]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @AnalysisClass | varchar(64) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @StatusCode | varchar(40) | ja | kein Default; OUTPUT |
| @ErrorMessage | nvarchar(2048) | ja | kein Default; OUTPUT |
| @CrossDatabaseRequested | bit | ja | kein Default; OUTPUT |
| @CandidateTable | sysname | nein | N'#PrepareDatabaseCandidates_Result' |
| @WarningTable | sysname | nein | NULL |
| @Hilfe | bit | nein | 0 |

**@DatabaseNames:** @DatabaseNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL, leer oder nur Leerzeichen bedeutet nicht angegeben; ausgelassen verwendet NULL. Gültige Namen begrenzen Datenbankauswahl; nicht angegebene Liste bedeutet keine exakte Einschränkung. Ungültiger Name => INVALID_PARAMETER.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen: bit, Default 0. 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. NULL => INVALID_PARAMETER; ausgelassen =0. Bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab. Wirkt auf Auswahl und SYSTEM_DATABASE_EXCLUDED-Warnung.

**@DatabaseNamePattern:** @DatabaseNamePattern: nvarchar(4000), Default NULL. LIKE-Pattern (%, _, [...]) oder Präfix like:, regex:, regexi:; Präfixerkennung ohne Beachtung der Großschreibung. NULL/ausgelassen = kein Pattern. Äußere Leerzeichen werden entfernt; Inhalt nach Präfixentfernung nicht erneut getrimmt. Leerwert oder leeres Präfixergebnis ungültig; jedes nicht-NULL Pattern zusammen mit wirksamer @DatabaseNames-Liste ungültig. LIKE nutzt SQL_Latin1_General_CP1_CS_AS. Regex-Syntax wird nicht vorgeprüft; regex: Flag c, regexi: Flag i; Ausführung benötigt SQL Server 2025 und Compatibility Level >=170 der Installationsdatenbank, sonst UNAVAILABLE_FEATURE. Regex filtert nach der Kandidatenermittlung alle Zeilen des Ziels.

**@AnalysisClass:** @AnalysisClass: varchar(64), Default NULL. NULL oder eine leere beziehungsweise nur aus U+0020-Leerzeichen bestehende Zeichenfolge schaltet die optionale Pfadprüfung aus; ausgelassen = NULL. Der Quellcode nutzt NULLIF(@AnalysisClass, ''); SQLs Auffüllvergleich behandelt eine leere oder nur aus U+0020-Leerzeichen bestehende Zeichenfolge als leer. Es gibt kein explizites Trim; führende Leerzeichen und andere Whitespace-Zeichen werden nicht normalisiert. Sonst einer der 31 Codes: 

**@HighImpactConfirmed:** @HighImpactConfirmed: bit, Default 0. 0 bestätigt nicht; 1 bestätigt nur ein Gate der tatsächlich angegebenen aktivierten Klasse. NULL => INVALID_PARAMETER auch ohne Klasse; ausgelassen =0. Bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab. Ersetzt Klassen- und Freigabeprüfung nicht.

**@StatusCode:** @StatusCode: Datentyp varchar(40); OUTPUT, ohne Default. Ein Argument ist auch bei @Hilfe=1 erforderlich, da kein Default existiert. Für den Empfang eine Aufrufervariable vom Typ varchar(40) mit OUTPUT binden, zum Beispiel @StatusCode=@CallerStatusCode OUTPUT. Ohne OUTPUT am Aufruf wird der Rückgabewert nicht empfangen. AVAILABLE bedeutet, dass die Vorbereitung ohne erkannten Fehler abgeschlossen wurde; es bestätigt nicht, dass jeder angeforderte Name als Kandidat ausgewählt wurde. INVALID_PARAMETER kennzeichnet ungültige Auswahl-/Bestätigungs-/Temp-Tabellenparameter, ungültiges Pattern oder ungültige/duplizierte Namensliste sowie einen unbekannten Analyseklassencode. INTERNAL_ERROR kennzeichnet, dass die Kandidaten-Temp-Tabelle die geprüften erwarteten Spalten DatabaseId und DatabaseName nicht bereitstellt. UNAVAILABLE_FEATURE bedeutet, dass Regex mangels erforderlicher SQL-Server-Version oder Compatibility Level nicht ausgeführt werden kann. Delegiert kann HIGH_IMPACT_CONFIRMATION_REQUIRED bedeuten, dass eine tatsächlich aktivierte Klasse mit RequiresGroupGate=1 nicht mit @HighImpactConfirmed=1 bestätigt wurde; DENIED_GROUP bedeutet, dass die aktuelle Analysepfadfreigabe fehlt. Bei @Hilfe=1 bleibt die Aufrufervariable unverändert.

**@ErrorMessage:** @ErrorMessage: Datentyp nvarchar(2048); OUTPUT, ohne Default. Ein Argument ist auch bei @Hilfe=1 erforderlich, da kein Default existiert. Für den Empfang eine Aufrufervariable vom Typ nvarchar(2048) mit OUTPUT binden, zum Beispiel @ErrorMessage=@CallerErrorMessage OUTPUT. Ohne OUTPUT am Aufruf wird der Rückgabewert nicht empfangen. Empfängt die Fehlerbeschreibung; bei erfolgreich abgeschlossener Vorbereitung ist der Wert NULL. Bei @Hilfe=1 wird er vor der Rückkehr nicht initialisiert und bleibt unverändert.

**@CrossDatabaseRequested:** @CrossDatabaseRequested: bit OUTPUT, ohne Default. Ein Argument ist auch bei Hilfe erforderlich. Für den Empfang eine bit-Variable mit OUTPUT binden; ohne OUTPUT wird der Rückgabewert nicht empfangen. 1 wenn normalisierte exakte Liste fehlt oder mehr als ein gültiges geparstes Element vorliegt, sonst 0. Beschreibt Anfrageform, keine Verfügbarkeit; vor Listenfehlerprüfung ermittelt. Bei Hilfe unverändert.

**@CandidateTable:** @CandidateTable: sysname, Default #PrepareDatabaseCandidates_Result. Name einer vorhandenen lokalen # Temp-Tabelle derselben Session; kein ##, max. 116 Zeichen. NULL/falscher Präfix/Überlänge => INVALID_PARAMETER. Spalten: DatabaseId int NOT NULL, DatabaseName sysname NOT NULL, StateDesc nvarchar(60) NULL, UserAccessDesc nvarchar(60) NULL, IsReadOnly bit NULL, CompatibilityLevel tinyint NULL, CollationName sysname NULL, RecoveryModelDesc nvarchar(60) NULL, IsSystemDatabase bit NULL, RequestedOrdinal int NULL; Textcollation SQL_Latin1_General_CP1_CS_AS. TOP(0) prüft nur DatabaseId/DatabaseName; spätere Schema-/Insertfehler können entkommen. Hängt Kandidaten an; regulär keine Löschung. Bei nicht verfügbarer Regexfunktion werden vor UNAVAILABLE_FEATURE alle Zielzeilen gelöscht; Regex filtert auch Altzeilen.

**@WarningTable:** @WarningTable: sysname, Default NULL; NULL/ausgelassen deaktiviert Warnungen. Sonst vorhandene lokale # Tabelle derselben Session, kein ##, max. 116 Zeichen; falscher Präfix/Überlänge => INVALID_PARAMETER. Spalten RequestedName sysname NULL, StatusCode varchar(40) NULL, ErrorMessage nvarchar(2048) NULL; Textcollation SQL_Latin1_General_CP1_CS_AS. Fehlende explizite Namen erhalten DATABASE_UNAVAILABLE oder SYSTEM_DATABASE_EXCLUDED. Scheiternde TOP(0)-Probe überspringt Tabelle still; späterer Insertfehler kann entkommen. Warnungen werden angehängt; Alt-Kandidaten beeinflussen Fehlend-Erkennung.

**@Hilfe:** @Hilfe: bit, Default 0. 0 verarbeitet; 1 druckt Hilfe und kehrt vor OUTPUT-Initialisierung und Tabellenverarbeitung zurück; NULL normaler Pfad. Ausgelassen =0; numerisch ungleich 0 wird bit-konvertiert zu 1. Für alle drei OUTPUT-Parameter sind auch bei Hilfe Argumente anzugeben. Für den Empfang Variable mit OUTPUT binden; im Hilfepfad bleiben die übergebenen Eingangswerte unverändert.

## Resultate und Ausgabe

Kein Fach-Resultset. Die Procedure füllt die vom Aufrufer benannte Kandidaten-Temp-Tabelle und meldet `@StatusCode varchar(40)`, `@ErrorMessage nvarchar(2048)` und `@CrossDatabaseRequested bit` per OUTPUT. Normale Kandidaten sind sichtbare, online und zugängliche Datenbanken; ausgeschlossene oder nicht auffindbare angeforderte Namen werden im zugehörigen Warnziel festgehalten. Bei nicht verfügbarer Regex-Funktion wird die Kandidatenmenge geleert und `UNAVAILABLE_FEATURE` gesetzt. Die OUTPUT-Werte sind kein Nachweis einer atomaren Datenbanksicht.

## Beispiel

```sql
EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=N'[ExampleDatabase]', @CandidateTable=N'#PrepareDatabaseCandidates_HelpExample', @WarningTable=N'#PrepareDatabaseCandidates_WarningExample', @StatusCode=@StatusCode OUTPUT, @ErrorMessage=@ErrorMessage OUTPUT, @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_PrepareDatabaseCandidates befüllt lokale Kandidaten- und optionale Warnungstabellen des Aufrufers. Sie liefert keine Analyse-Resultsets und ergänzt vorhandene Zeilen.

  STANDARD_CURRENT (leichte Sessions-, Requests-, Blocking-, Wait-, Memory-, TempDB- und I/O-Abfragen)

  EXTENDED_CURRENT (gezielte Current-State-Vertiefung mit begrenzter Text-, Plan- und Objektauflösung)

  PLAN_CACHE_CURRENT (begrenzte Query-Stats-/Plan-Cache-Auswertung ohne vollständiges XML-Shredding)

  SHOWPLAN_TARGETED (gezielte Showplan-Extraktion und XML-Analyse für gefilterte Handles/Hashes)


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_PrepareDatabaseCandidates
Version      : 2.0.2
Stand        : 2026-10-14
Typ          : Öffentlicher Vorbereitungshelfer
Zweck        : Validiert die frameworkweite Datenbankauswahl, prüft den
               tatsächlich aktivierten Analysepfad und befüllt lokale
               Kandidaten- und Warning-Temp-Tabellen des Aufrufers.
Semantik     : Ohne explizite Einschränkung alle sichtbaren, online befindlichen
               Benutzerdatenbanken. Kein CURRENT-Scope und keine Vorabbegrenzung.
High Impact  : Nur eine tatsächlich aktivierte Analyseklasse mit
               RequiresGroupGate=1 verlangt @HighImpactConfirmed=1.
Vertrag      : Die Procedure kennt keine Datenbank-Mengenbegrenzung.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_PrepareDatabaseCandidates befüllt lokale Kandidaten- und optionale Warnungstabellen des Aufrufers. Sie liefert keine Analyse-Resultsets und ergänzt vorhandene Zeilen.
  STANDARD_CURRENT (leichte Sessions-, Requests-, Blocking-, Wait-, Memory-, TempDB- und I/O-Abfragen)
  EXTENDED_CURRENT (gezielte Current-State-Vertiefung mit begrenzter Text-, Plan- und Objektauflösung)
  PLAN_CACHE_CURRENT (begrenzte Query-Stats-/Plan-Cache-Auswertung ohne vollständiges XML-Shredding)
  SHOWPLAN_TARGETED (gezielte Showplan-Extraktion und XML-Analyse für gefilterte Handles/Hashes)
  OBJECT_ANALYSIS_CURRENT (gezielte Objekt-, Index-, Partitions- und Columnstore-Kataloganalyse)
  EXTERNAL_RUNTIME_CURRENT (lesende Konfigurations-, Katalog-, Request-, Pool- und Counteranalyse externer Runtimes)
  CLR_CURRENT (lesende CLR-Katalog-, Host-, AppDomain-, Task-, Request-, Speicher- und Counteranalyse)
  MISSING_INDEX_CURRENT (begrenzte flüchtige Missing-Index-Hinweise, keine DDL)
  STATISTICS_TARGETED (gezielte Statistik-Eigenschaften gefilterter Objekte)
  COLUMNSTORE_CURRENT (gezielte Columnstore-Rowgroups ohne Segment-/Dictionary-Vollscan)
  LOCKS_DEEP (detaillierte Locks für relevante Sessions)
  LOG_VLF_DEEP (datenbankübergreifende VLF-Auswertung)
  PLAN_CACHE_DEEP (breite Query-Stats-/Plan-Cache-Analyse)
  SHOWPLAN_XML_DEEP (breite Showplan-XML-Analyse)
  CATALOG_DEEP (breite Systemkatalog-, Objekt-, Index-, Statistik- und Partitionsanalyse)
  PHYSICAL_STATS_DEEP (gezielte physische Indexstatistiken im gewählten Modus)
  INDEX_OPERATIONAL_DEEP (breite kumulative Index-Operational-Stats)
  QUERY_STORE_CURRENT (gezielte lesende Query-Store-Auswertung mit Zeit-/Zeilenlimit)
  EXTENDED_EVENTS_CURRENT (Inventar vorhandener XE-Definitionen/laufender Sessions ohne Targets/Historie)
  QUERY_STORE_DEEP (breite Query-Store-Historie, Regressionen, Planwechsel und Waits)
  CROSS_DATABASE_DEEP (datenbankübergreifende Inventarisierung und Diagnose)
  COLUMNSTORE_DEEP (breite Columnstore-Analyse einschließlich Segmenten)
  EXTENDED_EVENTS_FORENSICS_DEEP (optionale XE-Forensik aus Session/Event-Dateien)
  SERVER_HEALTH_CURRENT (CPU-, NUMA-, Memory-, TempDB-, OS- und Dienstzustand)
  SERVER_CONFIGURATION_CURRENT (lesende Serverkonfiguration, Trace Flags und Startparameter)
  SECURITY_CONFIGURATION_CURRENT (lesende Sicherheits- und Dienstparameter)
  SQL_AGENT_CURRENT (lesender SQL-Agent-Status, Jobs, Schedules und Historie)
  RESOURCE_GOVERNOR_CURRENT (lesende Resource-Governor-Konfiguration und Laufzeit)
  HA_DR_CURRENT (begrenzte lesende HA/DR-, Backup-, Replication-, CDC- und CT-Analyse)
  ENTERPRISE_TOPOLOGY_DEEP (vertiefte Enterprise-Topologie/Distribution für HA/DR und Replication)
  DATA_PLATFORM_ADAPTER_CURRENT (optionale angereicherte kundenspezifische Data-Platform-/ETL-Logginganalyse)
Beide Tabellen müssen vom Aufrufer angelegt werden. Die Procedure löscht sie im regulären Pfad nicht; wiederverwendete Ziele behalten alte Zeilen. Es gibt keine allgemeine atomare Rücknahme bei späteren Fehlern. Der Regexfilter verarbeitet alle Zeilen der Kandidatentabelle, einschließlich bereits vorhandener Zeilen. Fehlt SQL-Server-Version oder Compatibility Level für Regex, löscht die Procedure vor UNAVAILABLE_FEATURE sämtliche Zeilen aus diesem Ziel.
Beispiel: ausführbarer Aufruf mit frischen, korrekt typisierten lokalen Tabellen und synthetischem Datenbanknamen:
CREATE TABLE #PrepareDatabaseCandidates_HelpExample (DatabaseId int NOT NULL, DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, StateDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, UserAccessDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, IsReadOnly bit NULL, CompatibilityLevel tinyint NULL, CollationName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, RecoveryModelDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, IsSystemDatabase bit NULL, RequestedOrdinal int NULL);
CREATE TABLE #PrepareDatabaseCandidates_WarningExample (RequestedName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, StatusCode varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, ErrorMessage nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
DECLARE @StatusCode varchar(40), @ErrorMessage nvarchar(2048), @CrossDatabaseRequested bit;
DROP TABLE #PrepareDatabaseCandidates_WarningExample; DROP TABLE #PrepareDatabaseCandidates_HelpExample;
Parsergrenzen: PARSENAME-basierte Strukturprüfungen sind keine vollständige SQL-Bezeichnergrammatik und prüfen weder Existenz noch Berechtigungen.
```

