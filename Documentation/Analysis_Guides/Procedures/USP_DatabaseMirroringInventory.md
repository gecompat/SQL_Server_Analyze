# [monitor].[USP_DatabaseMirroringInventory]

## Zweck

Das Verfahren liefert caller-sichtbare SQL-Server-Katalogwerte zu Database Mirroring für ausgewählte Datenbanken. Es liest master.sys.databases und master.sys.database_mirroring mit NOLOCK. Das Ergebnis ist immer als begrenzte Metadatensicht markiert.

Database Mirroring ist veraltet und für eine künftige SQL-Server-Version zur Entfernung vorgesehen. Diese Analyse plant oder führt keine Migration aus. Auf SQL Server unter Linux ist Database Mirroring nicht verfügbar. Ein leeres Linux-Ergebnis ist keine positive Funktionsqualifikation.

## Auswahl und Aussagegrenzen

Ohne Filter wählt das gemeinsame Framework alle sichtbaren, ONLINE befindlichen Benutzerdatenbanken. Systemdatenbanken sind mit @SystemdatenbankenEinbeziehen=1 opt-in. @DatabaseNames und @DatabaseNamePattern verwenden die vorhandenen, voneinander getrennten Filterverträge. Nicht ONLINE befindliche Datenbanken wie eine RESTORING-Mirror-Datenbank liegen außerhalb der Auswahl. V1 belegt daher keine positive Mirror-Rollenbeobachtung auf dieser Partnerseite.

Das Verfahren liefert eine Zeile je ausgewählter Datenbank. Die native Quelle enthält auch für nicht gespiegelte Datenbanken eine Zeile; ihre mirroring_-Spalten sind dort NULL. NULL-Werte werden unverändert ausgegeben und unterscheiden keine Ursache. Metadaten sind auf für den Caller sichtbare Datenbanken beschränkt. Ein leerer Filtertreffer beweist keine instanzweite Abwesenheit.

[Microsofts sys.database_mirroring-Dokumentation](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-mirroring-transact-sql?view=sql-server-ver17) beschreibt die native Zeilen-, NULL-, Sichtbarkeits- und Versionsberechtigungssemantik. Für Datenbanken außer master und tempdb muss der Caller Datenbankbesitzer sein oder ALTER ANY DATABASE, VIEW ANY DATABASE oder CREATE DATABASE in master besitzen. Ab SQL Server 2022 ist VIEW SERVER PERFORMANCE STATE erforderlich; die Quelle spezifiziert keine weitere Serverberechtigung für SQL Server 2019. Nicht-NULL-Werte auf einer Mirror-Datenbank erfordern sysadmin. Das Framework vergibt keine Berechtigungen.

## Ausgabe

Der öffentliche Vertrag enthält genau vier Resultsets:

| Resultset | Inhalt |
|---|---|
| moduleStatus | Modulergebnis, Zeilenzahl und Begrenzungshinweis |
| databaseMirroring | Die zwölf nativen Katalogwerte |
| sourceStatus | Datenbankauswahl und Status der nativen Katalogquelle |
| warnings | Metadatensicht, NULL-Interpretation, Limit und ONLINE-Auswahlgrenze |

Die Fachmenge databaseMirroring verwendet diese stabile Feldfolge und nativen Typen:

| Feld | Typ | Bedeutung |
|---|---|---|
| DatabaseId | int NOT NULL | Datenbank-ID und Join-Schlüssel |
| DatabaseName | sysname NOT NULL | Caller-sichtbarer Datenbankname |
| MirroringState | tinyint NULL | Nativer Sitzungszustand |
| MirroringStateDesc | nvarchar(60) NULL | Native Zustandsbeschreibung |
| MirroringRole | tinyint NULL | Nativer lokaler Rollenwert |
| MirroringRoleDesc | nvarchar(60) NULL | Native Rollenbeschreibung |
| MirroringSafetyLevel | tinyint NULL | Nativer Safety-Wert |
| MirroringSafetyLevelDesc | nvarchar(60) NULL | Native Safety-Beschreibung |
| MirroringWitnessState | tinyint NULL | Nativer Witness-Zustand |
| MirroringWitnessStateDesc | nvarchar(60) NULL | Native Witness-Beschreibung |
| ConfiguredRedoQueueLimitMb | int NULL | Konfiguriertes Redo-Limit, keine beobachtete Queue |
| RedoQueueLimitType | nvarchar(60) NULL | Nativer Typ des Redo-Limits |

Partner- und Witness-Namen, GUIDs und LSNs werden nicht ausgegeben. Zustands- und Rollenwerte sind keine Gesundheits- oder Failoverbewertung. Das konfigurierte Redo-Limit ist keine aktuelle Queue-Messung. Es gibt keine externe Verbindung, Probeoperation, Schreibaktion oder Statusinferenz.

RAW liefert die vier Resultsets in Vertragsreihenfolge. TABLE verwendet ResultTablesJson für dieselben physischen Schemas. CONSOLE stellt eine formatierte Einzelansicht bereit. NONE unterdrückt Resultsets. JsonErzeugen=1 liefert unabhängig von der Ausgabeart über Json die bestehende Metahülle mit schemaVersion=1 und databaseMirroring als Array. Der JSON-Schalter erzeugt keinen zusätzlichen Resultsetnamen.

Bei erfolgreicher Quelle meldet das Modul AVAILABLE_LIMITED und IsPartial=1, auch wenn der ausgewählte Katalog keine Zeilen liefert. Quellenfehler bleiben über Status, Fehler-OUTPUT und sourceStatus sichtbar und werden nie als erfolgreiche leere Menge behandelt.

## Parameter und Aufruf

MaxZeilen begrenzt die Fachmenge nach DatabaseId; NULL oder 0 bedeutet unbegrenzt, ein negativer Wert ist ungültig. Das Limit begrenzt die Ausgabe, nicht garantiert die vorgelagerte Kataloglesearbeit. Alle Parameter, Defaults und Ausgabeoptionen stehen in Hilfe.

    EXEC [monitor].[USP_DatabaseMirroringInventory] @ResultSetArt='CONSOLE';

    EXEC [monitor].[USP_DatabaseMirroringInventory]
        @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='RAW', @JsonErzeugen=1;

Das Verfahren setzt keine Caller-Transaktion voraus und beginnt, bestätigt oder verwirft keine Transaktion. Es ändert weder Isolationsstufe noch Caller-LOCK_TIMEOUT; die Quellphase verwendet SET LOCK_TIMEOUT 0 und stellt den ursprünglichen Wert wieder her. NOLOCK kann inkonsistente, fehlende oder doppelte Zeilen liefern. Es verhindert keine Sch-S-Sperren und garantiert keine Nichtblockierung.

## Eine Zeile bedeutet

Eine Zeile in databaseMirroring gehört zu einer vom gemeinsamen Selektor gelieferten, caller-sichtbaren ONLINE-Datenbank. Sie verbindet die Datenbank-ID und den nativen Namen mit den Feldern aus sys.database_mirroring. Native NULLs bleiben unverändert. Ein fehlender Treffer belegt keine instanzweite Abwesenheit; das globale MaxZeilen-Limit wird erst nach vollständiger Kandidaten- und Quellermittlung angewendet.

## So lesen

Lies zuerst moduleStatus und sourceStatus. AVAILABLE_LIMITED und IsPartial=1 kennzeichnen die erfolgreiche, caller-sichtbare Teilansicht. Danach folgt databaseMirroring mit zwölf Feldern; warnings erläutert Metadatensicht, native NULLs, ONLINE-Auswahl und ein tatsächlich angewendetes Ausgabelimit.

RAW liefert die vier Resultsets moduleStatus, databaseMirroring, sourceStatus und warnings in dieser Reihenfolge. TABLE schreibt dieselben Schemas in vier lokale #Temp-Ziele. CONSOLE zeigt die formatierte Übersicht; NONE unterdrückt Resultsets. JsonErzeugen=1 erzeugt unabhängig davon die JSON-Metahülle mit schemaVersion=1 und denselben vier Arrays. JSON ist kein fünftes Resultset.

## Warum kann das problematisch sein?

Native mirroring_-NULLs unterscheiden nicht zwischen nicht gespiegelt, nicht verfügbar und für den Caller nicht sichtbar. Eingeschränkte Metadatensicht kann Datenbanken verbergen. Quellenfehler bleiben Fehlerstatus und dürfen nicht als erfolgreich leere Menge interpretiert werden.

NOLOCK kann inkonsistente, fehlende oder doppelte Zeilen liefern und verhindert keine Sch-S-Sperren. MirroringState und MirroringRole sind lokale Katalogwerte und belegen weder Partnergesundheit noch Synchronität, Failoverfähigkeit, Commit oder Witness-Erreichbarkeit. ConfiguredRedoQueueLimitMb ist die konfigurierte Obergrenze, keine Messung der aktuellen Redo-Queue.

## Wann ist es kein Problem?

NULL-Mirroringfelder sind für eine nicht gespiegelte Datenbank ein erwarteter nativer Wert. Ein leeres Ergebnis kann korrekt sein, wenn keine Datenbank die explizite sichtbare ONLINE-Auswahl erfüllt. Lies beide Fälle zusammen mit sourceStatus und warnings; sie beweisen keine globale Abwesenheit.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche lokalen Mirroring-Katalogwerte gehören zu den sichtbaren ONLINE-Datenbanken, die der Aufrufer ausgewählt hat?

### Technischer Hintergrund

sys.database_mirroring liefert eine native Zeile je Datenbank. Für eine nicht gespiegelte Datenbank sind Felder mit Präfix mirroring_ NULL. Eine Mirror-Datenbank im Zustand RESTORING liegt außerhalb des gemeinsamen ONLINE-Selektors; dieses Verfahren behauptet deshalb keine positive Mirroring-Rolle auf dieser Partnerseite.

### Datenkette

TVF_DatabaseCandidates → USP_PrepareDatabaseCandidates → Kandidatentabelle → master.sys.databases → LEFT JOIN master.sys.database_mirroring auf database_id → globales Ausgabelimit → vier Resultsets beziehungsweise JSON.

### Source Select

Die Quellprojektion verbindet die zuvor vollständig erstellte Kandidatenmenge mit der lokalen Datenbankzeile und übernimmt native Mirroringwerte ohne Normalisierung:

```sql
SELECT [c].[DatabaseId],[c].[DatabaseName],
       [m].[mirroring_state],[m].[mirroring_state_desc],
       [m].[mirroring_role],[m].[mirroring_role_desc],
       [m].[mirroring_safety_level],[m].[mirroring_safety_level_desc],
       [m].[mirroring_witness_state],[m].[mirroring_witness_state_desc],
       [m].[mirroring_redo_queue],[m].[mirroring_redo_queue_type]
FROM [#DatabaseMirroringInventory_Candidates] AS [c]
INNER JOIN [master].[sys].[databases] AS [d] WITH (NOLOCK)
  ON [d].[database_id]=[c].[DatabaseId]
 AND [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS
     =[c].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
LEFT JOIN [master].[sys].[database_mirroring] AS [m] WITH (NOLOCK)
  ON [m].[database_id]=[d].[database_id];
```

**Wichtig für die Eigenlast:** MaxZeilen begrenzt die Ausgabe nach der Katalogabfrage. Das Limit begrenzt weder Kandidatenermittlung noch vorgelagerte Kataloglesearbeit.

### Zeit- und Scope-Modell

Kandidatenauswahl und native Mirroringabfrage werden getrennt zeitlich geklammert. Sie bilden keinen gemeinsamen Transaktionssnapshot. Die Quellphase verwendet NOLOCK und SET LOCK_TIMEOUT 0; anschließend werden Caller-Timeout und XACT_ABORT wiederhergestellt. Das Verfahren beginnt, bestätigt oder verwirft keine Caller-Transaktion und ändert deren Isolationsstufe nicht.

### Bewertung und Gegenprobe

Vergleiche die nativen Werte bei einer gezielten Prüfung anhand der Datenbank-ID mit der [Microsoft-Dokumentation zu sys.database_mirroring](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-mirroring-transact-sql?view=sql-server-ver17). Prüfe sourceStatus und warnings, bevor du aus leeren oder partiellen Zeilen Schlüsse ziehst.

### Typische Fehlinterpretation

NULL wird als Beweis für nicht konfiguriertes Mirroring gelesen; eine nicht sichtbare RESTORING-Partnerdatenbank wird als negativer Rollenbefund behandelt; die konfigurierte Redo-Obergrenze wird als aktuelle Queue-Messung bezeichnet; oder AVAILABLE_LIMITED wird als vollständige Serverinventur missverstanden.

### Folgeanalyse

Die [Infrastructure-Analyse](USP_InfrastructureAnalysis.md) ergänzt den übrigen sichtbaren HA/DR-Kontext. Eine Mirroring-Partnerschaft, Witness-Verfügbarkeit, Failover oder aktuelle Redo-Latenz benötigt eigene geeignete Laufzeitevidenz.

[Technische Detailbeschreibung](../../Reference/Procedure_Reference.md) · [Microsoft: sys.database_mirroring](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-mirroring-transact-sql?view=sql-server-ver17)

## Qualifikationsstatus

Das Runtimefixture lässt sich in den vorhandenen nativen Release-Gates für SQL Server 2019, 2022 und 2025 ausführen; Auswahl, native NULLs, Limits, Ausgabe-ABI, Callerzustand und Cleanup laufen dort versionsübergreifend. Der gezielte Quellberechtigungstest mit VIEW SERVER PERFORMANCE STATE gilt erst ab SQL Server 2022; für SQL Server 2019 wird keine nicht dokumentierte Mindestberechtigung behauptet und dieser Teilfall ausdrücklich übersprungen. Diese Ausführbarkeit ist kein Laufnachweis: Native SQL-Server-2019- und SQL-Server-2022-Qualifikation sowie eine Windows-Mirroring-Topologie bleiben offen. Das Fixture erzeugt keine Mirroring-Partnerschaft und behauptet keine positive Mirror-Rollenzeile.
