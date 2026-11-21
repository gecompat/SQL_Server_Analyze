-- USAGE_SKILL_BEGIN monitor_metadata.VW_ObjectUsageSkills 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor_metadata.VW_ObjectUsageSkills"
-- schema_name: "monitor_metadata"
-- object_name: "VW_ObjectUsageSkills"
-- object_type: "VIEW"
-- database_role: "both"
-- is_internal: false
-- description: "Liefert versionierte Usage-Skill-Texte als statischen Dokumentationskatalog für die feste bekannte Objektmenge der jeweiligen Datenbankrolle."
-- source_path: "Code/00_Setup/005_VW_ObjectUsageSkills.sql"
-- ---
-- 
-- # monitor_metadata.VW_ObjectUsageSkills
-- 
-- ## Zweck und Einsatz
-- 
-- Die View stellt für die bekannte Frameworkrolle 193 Objekt-Skills plus diesen Self-Skill und für die Snapshot-Zielrolle 17 Objekt-Skills plus diesen Self-Skill bereit. Der Text stammt aus den versionierten Markdown-Dateien unter `Metadata/UsageSkills`; die View führt keine Objektinventur und keine Laufzeitprüfung aus. Die Self-Zeile trägt `DatabaseRole=both`, weil dieselbe kanonische Markdown-Datei in beiden Rollenprojektionen enthalten ist; alle anderen Zeilen nennen ihre jeweilige Datenbankrolle. Ein Eintrag sagt weder, dass das Objekt im aktuellen Datenbankzustand noch vorhanden ist, noch dass der Aufrufer seine Fachquellen lesen oder ausführen darf.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der Installer muss das Schema `monitor_metadata` und die View in der ausdrücklich gewählten Datenbank mit den entsprechenden DDL-Rechten anlegen können. Ein lesender Aufrufer benötigt SELECT auf der View. Die View erteilt keine Rechte auf die beschriebenen Objekte und führt sie nicht aus. Ein Teilinstaller verkleinert die feste Rollenliste nicht; der Katalog belegt weder die Installation noch die Erreichbarkeit der aufgeführten Fachobjekte.
-- 
-- ## Parameter und Eingabe
-- 
-- Keine Aufrufparameter. `SchemaName` und `ObjectName` wählen die dokumentierte Identität; beide Werte werden als Daten verglichen, nicht als dynamische SQL-Bezeichner ausgeführt.
-- 
-- ## Resultate und Ausgabe
-- 
-- Eine Zeile je Objekt mit `SchemaName` (sysname), `ObjectName` (sysname), `ObjectType` (varchar(24)), `DatabaseRole` (varchar(24)), `IsInternal` (bit), `Description` (nvarchar(max)), `SkillFormatVersion` (varchar(16)) und `SkillMarkdown` (nvarchar(max)). `SkillMarkdown` ist zeichengetreu mit der zugehörigen versionierten Markdown-Datei. `SkillFormatVersion=1.0.0` bezeichnet nur das Skillformat, nicht Framework- oder Paketversion.
-- 
-- ## Beispiel
-- 
-- ```sql
-- SELECT [SkillFormatVersion], [SkillMarkdown]
-- FROM [monitor_metadata].[VW_ObjectUsageSkills]
-- WHERE [SchemaName]=N'monitor'
--   AND [ObjectName]=N'USP_CurrentObjectPermissionAnalysis';
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- SELECT liest konstante Unicode-Literale und verändert keinen Datenbankzustand. Ein Abruf aller langen `SkillMarkdown`-Werte kann entsprechend der Zahl und Länge der in diesem Installer enthaltenen Skills Speicher und Übertragungszeit beanspruchen. Fehler beim Anlegen oder Lesen der View folgen den üblichen DDL-, SELECT- und Ressourcenregeln von SQL Server. Die Texte sind Implementierungsdokumentation des Quellstands; aus Kataloganwesenheit folgen keine Installation, Berechtigung, fachliche Verfügbarkeit, vollständige Laufzeitevidenz oder atomare Quellsicht.
-- USAGE_SKILL_END monitor_metadata.VW_ObjectUsageSkills
CREATE OR ALTER VIEW [monitor_metadata].[VW_ObjectUsageSkills]
AS
SELECT CONVERT(sysname,N'monitor_metadata') AS [SchemaName],CONVERT(sysname,N'VW_ObjectUsageSkills') AS [ObjectName],CONVERT(varchar(24),'VIEW') AS [ObjectType],CONVERT(varchar(24),'both') AS [DatabaseRole],CONVERT(bit,0) AS [IsInternal],CONVERT(nvarchar(max),N'Liefert versionierte Usage-Skill-Texte als statischen Dokumentationskatalog für die feste bekannte Objektmenge der jeweiligen Datenbankrolle.') AS [Description],CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor_metadata.VW_ObjectUsageSkills"'
            + NCHAR(10)
            + N'schema_name: "monitor_metadata"'
            + NCHAR(10)
            + N'object_name: "VW_ObjectUsageSkills"'
            + NCHAR(10)
            + N'object_type: "VIEW"'
            + NCHAR(10)
            + N'database_role: "both"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Liefert versionierte Usage-Skill-Texte als statischen Dokumentationskatalog für die feste bekannte Objektmenge der jeweiligen Datenbankrolle."'
            + NCHAR(10)
            + N'source_path: "Code/00_Setup/005_VW_ObjectUsageSkills.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor_metadata.VW_ObjectUsageSkills'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die View stellt für die bekannte Frameworkrolle 193 Objekt-Skills plus diesen Self-Skill und für die Snapshot-Zielrolle 17 Objekt-Skills plus diesen Self-Skill bereit. Der Text stammt aus den versionierten Markdown-Dateien unter `Metadata/UsageSkills`; die View führt keine Objektinventur und keine Laufzeitprüfung aus. Die Self-Zeile trägt `DatabaseRole=both`, weil dieselbe kanonische Markdown-Datei in beiden Rollenprojektionen enthalten ist; alle anderen Zeilen nennen ihre jeweilige Datenbankrolle. Ein Eintrag sagt weder, dass das Objekt im aktuellen Datenbankzustand noch vorhanden ist, noch dass der Aufrufer seine Fachquellen lesen oder ausführen darf.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der Installer muss das Schema `monitor_metadata` und die View in der ausdrücklich gewählten Datenbank mit den entsprechenden DDL-Rechten anlegen können. Ein lesender Aufrufer benötigt SELECT auf der View. Die View erteilt keine Rechte auf die beschriebenen Objekte und führt sie nicht aus. Ein Teilinstaller verkleinert die feste Rollenliste nicht; der Katalog belegt weder die Installation noch die Erreichbarkeit der aufgeführten Fachobjekte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Keine Aufrufparameter. `SchemaName` und `ObjectName` wählen die dokumentierte Identität; beide Werte werden als Daten verglichen, nicht als dynamische SQL-Bezeichner ausgeführt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Eine Zeile je Objekt mit `SchemaName` (sysname), `ObjectName` (sysname), `ObjectType` (varchar(24)), `DatabaseRole` (varchar(24)), `IsInternal` (bit), `Description` (nvarchar(max)), `SkillFormatVersion` (varchar(16)) und `SkillMarkdown` (nvarchar(max)). `SkillMarkdown` ist zeichengetreu mit der zugehörigen versionierten Markdown-Datei. `SkillFormatVersion=1.0.0` bezeichnet nur das Skillformat, nicht Framework- oder Paketversion.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT [SkillFormatVersion], [SkillMarkdown]'
            + NCHAR(10)
            + N'FROM [monitor_metadata].[VW_ObjectUsageSkills]'
            + NCHAR(10)
            + N'WHERE [SchemaName]=N''monitor'''
            + NCHAR(10)
            + N'  AND [ObjectName]=N''USP_CurrentObjectPermissionAnalysis'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'SELECT liest konstante Unicode-Literale und verändert keinen Datenbankzustand. Ein Abruf aller langen `SkillMarkdown`-Werte kann entsprechend der Zahl und Länge der in diesem Installer enthaltenen Skills Speicher und Übertragungszeit beanspruchen. Fehler beim Anlegen oder Lesen der View folgen den üblichen DDL-, SELECT- und Ressourcenregeln von SQL Server. Die Texte sind Implementierungsdokumentation des Quellstands; aus Kataloganwesenheit folgen keine Installation, Berechtigung, fachliche Verfügbarkeit, vollständige Laufzeitevidenz oder atomare Quellsicht.'
            + NCHAR(10) AS [SkillMarkdown]
UNION ALL
SELECT CONVERT(sysname,N'snapshot') AS [SchemaName],CONVERT(sysname,N'CaptureRun') AS [ObjectName],CONVERT(varchar(24),'TABLE') AS [ObjectType],CONVERT(varchar(24),'snapshot_target') AS [DatabaseRole],CONVERT(bit,0) AS [IsInternal],CONVERT(nvarchar(max),N'Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank.') AS [Description],CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "snapshot.CaptureRun"'
            + NCHAR(10)
            + N'schema_name: "snapshot"'
            + NCHAR(10)
            + N'object_name: "CaptureRun"'
            + NCHAR(10)
            + N'object_type: "TABLE"'
            + NCHAR(10)
            + N'database_role: "snapshot_target"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank."'
            + NCHAR(10)
            + N'source_path: "Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# snapshot.CaptureRun'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank. Das Schema speichert Erfassungsläufe, Status, Scopes, typisierte Messwerte und optionale Nutzdaten. Es startet weder Sammler noch Zeitpläne oder Retention-Purges.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das Ziel und verwendet ausschließlich den geprüften Verbindungskontext.'
            + NCHAR(10)
            + NCHAR(10)
            + N'CONTROL DATABASE und VIEW ANY DEFINITION sind für die native Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Lesender Einsatz erfordert SELECT auf [snapshot].[CaptureRun]; Installation und Aktualisierung benötigen die im Quellskript gezeigten DDL- und DML-Rechte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Keine Aufrufparameter.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Tabellenspalten und Constraints aus der eigenen CREATE-TABLE-Definition:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'('
            + NCHAR(10)
            + N'          [CaptureRunId] bigint IDENTITY(1,1) NOT NULL'
            + NCHAR(10)
            + N'        , [CollectorCode] varchar(64) NOT NULL'
            + NCHAR(10)
            + N'        , [SchedulerType] varchar(16) NOT NULL'
            + NCHAR(10)
            + N'        , [StartedAtUtc] datetime2(3) NOT NULL'
            + NCHAR(10)
            + N'        , [EndedAtUtc] datetime2(3) NULL'
            + NCHAR(10)
            + N'        , [SourceDatabaseName] sysname NOT NULL'
            + NCHAR(10)
            + N'        , [SqlServerStartTimeUtc] datetime2(3) NULL'
            + NCHAR(10)
            + N'        , [ResetEpochId] uniqueidentifier NULL'
            + NCHAR(10)
            + N'        , [ContractVersion] int NOT NULL'
            + NCHAR(10)
            + N'        , [StatusCode] varchar(40) NOT NULL'
            + NCHAR(10)
            + N'        , [IsPartial] bit NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_CaptureRun_IsPartial] DEFAULT (0)'
            + NCHAR(10)
            + N'        , [ErrorNumber] int NULL'
            + NCHAR(10)
            + N'        , [ErrorMessage] nvarchar(2048) NULL'
            + NCHAR(10)
            + N'        , [MetricSampleCount] bigint NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_CaptureRun_MetricSampleCount] DEFAULT (0)'
            + NCHAR(10)
            + N'        , [PayloadCount] bigint NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_CaptureRun_PayloadCount] DEFAULT (0)'
            + NCHAR(10)
            + N'        , CONSTRAINT [PK_snapshot_CaptureRun]'
            + NCHAR(10)
            + N'              PRIMARY KEY CLUSTERED ([CaptureRunId])'
            + NCHAR(10)
            + N'        , CONSTRAINT [FK_snapshot_CaptureRun_CollectorPolicy]'
            + NCHAR(10)
            + N'              FOREIGN KEY ([CollectorCode])'
            + NCHAR(10)
            + N'              REFERENCES [snapshot].[CollectorPolicy]([CollectorCode])'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_CaptureRun_SchedulerType]'
            + NCHAR(10)
            + N'              CHECK ([SchedulerType] IN (''MANUAL'',''EXTERNAL'',''SQL_AGENT''))'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_CaptureRun_EndedAtUtc]'
            + NCHAR(10)
            + N'              CHECK ([EndedAtUtc] IS NULL OR [EndedAtUtc] >= [StartedAtUtc])'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_CaptureRun_MetricSampleCount]'
            + NCHAR(10)
            + N'              CHECK ([MetricSampleCount] >= 0)'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_CaptureRun_PayloadCount]'
            + NCHAR(10)
            + N'              CHECK ([PayloadCount] >= 0)'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_CaptureRun_ContractVersion]'
            + NCHAR(10)
            + N'              CHECK ([ContractVersion] > 0)'
            + NCHAR(10)
            + N'    )'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT TOP (10) * FROM [snapshot].[CaptureRun];'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Das zugehörige Installationsskript enthält CREATE TABLE, INSERT, UPDATE, DELETE; ein lesendes SELECT führt diese Installationsschritte nicht aus. Constraints und NULL-Grenzen stehen in der Tabellendefinition.'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Datei        : 030_Snapshot_Target_Schema.sql'
            + NCHAR(10)
            + N'Version      : 1.2.2'
            + NCHAR(10)
            + N'Stand        : 2026-10-26'
            + NCHAR(10)
            + N'Zweck        : Erstellt und aktualisiert das versionierte Basisschema des'
            + NCHAR(10)
            + N'               optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell'
            + NCHAR(10)
            + N'               verbundenen Datenbank. Das Schema speichert Erfassungsläufe,'
            + NCHAR(10)
            + N'               Status, Scopes, typisierte Messwerte und optionale Nutzdaten.'
            + NCHAR(10)
            + N'               Es startet weder Sammler noch Zeitpläne oder Retention-Purges.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Tabellen     : PackageVersion kennzeichnet Paket- und Schemafassung sowie'
            + NCHAR(10)
            + N'               Erstinstallation und letzten Installationslauf. RetentionPolicy'
            + NCHAR(10)
            + N'               hält Aufbewahrungsfristen für Rohwerte, Nutzdaten und Rollups,'
            + NCHAR(10)
            + N'               Speicherbudget, Purge-Takt, Batchgröße und Budgetaktion.'
            + NCHAR(10)
            + N'               CollectorPolicy beschreibt Aktivierung, Intervall, Zeilenlimit,'
            + NCHAR(10)
            + N'               Nutzdatenerfassung und zugeordnete RetentionPolicy.'
            + NCHAR(10)
            + N'               CaptureRun protokolliert Sammler, Schedulerart, Start und Ende,'
            + NCHAR(10)
            + N'               Quelldatenbankname, SQL-Server-Startzeit, Reset-Epoche,'
            + NCHAR(10)
            + N'               Vertragsfassung, Status, Partialität, Fehler und Zeilenzähler.'
            + NCHAR(10)
            + N'               ModuleStatus hält je Lauf und Modul Zeitpunkt, Status, Partial-'
            + NCHAR(10)
            + N'               und Fehlerangaben sowie Evidenzgrenzen.'
            + NCHAR(10)
            + N'               Scope ordnet Messungen über Scope-Typ, optionalen Eltern-Scope,'
            + NCHAR(10)
            + N'               32-Byte-Schlüsselhash und JSON-Identität einem Erfassungsbereich'
            + NCHAR(10)
            + N'               zu. MetricDefinition beschreibt Metrikcode, Werttyp, Einheit,'
            + NCHAR(10)
            + N'               Vertragsfassung, Text, Framework-Default und Seedfassung.'
            + NCHAR(10)
            + N'               MetricSample verbindet Lauf, Scope und Metrik mit Messzeit,'
            + NCHAR(10)
            + N'               Reset-Epoche, genau einem typisierten Wert, Qualitätscode und'
            + NCHAR(10)
            + N'               Partialitätskennzeichen. PayloadSnapshot speichert optionale,'
            + NCHAR(10)
            + N'               Modulnutzdaten mit Format, Vertragsfassung, Hash'
            + NCHAR(10)
            + N'               und unkomprimierter Zeichenanzahl. PurgeRun protokolliert'
            + NCHAR(10)
            + N'               Aufräumlauf, Status, Batches, gelöschte Zeilen, Budgetmessung'
            + NCHAR(10)
            + N'               und Fehler.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Beziehungen  : Fremdschlüssel verbinden CollectorPolicy mit RetentionPolicy,'
            + NCHAR(10)
            + N'               CaptureRun mit CollectorPolicy, ModuleStatus und PayloadSnapshot'
            + NCHAR(10)
            + N'               mit CaptureRun sowie MetricSample mit CaptureRun, Scope und'
            + NCHAR(10)
            + N'               MetricDefinition. Scope kann auf einen Eltern-Scope verweisen.'
            + NCHAR(10)
            + N'               Primär- und eindeutige Schlüssel verhindern doppelte'
            + NCHAR(10)
            + N'               Policycodes, Modulstatus je Lauf/Modul sowie Messwerte je'
            + NCHAR(10)
            + N'               Lauf/Scope/Metrik. Ein gefilterter eindeutiger Index lässt'
            + NCHAR(10)
            + N'               höchstens eine RetentionPolicy als Framework-Default zu;'
            + NCHAR(10)
            + N'               Zeit- und Zuordnungsindizes unterstützen die im Schema'
            + NCHAR(10)
            + N'               vorgesehenen Lauf-, Messwert-, Nutzdaten- und Purgeabfragen.'
            + NCHAR(10)
            + N'               Die DDL definiert keine kaskadierenden Fremdschlüssel.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Werte        : UTC-Zeitfelder geben den jeweiligen Erfassungs-, Lauf- oder'
            + NCHAR(10)
            + N'               Änderungszeitpunkt an. NULL ist bei Endzeiten, optionalen'
            + NCHAR(10)
            + N'               Start-/Resetinformationen, Fehlerfeldern und alternativen'
            + NCHAR(10)
            + N'               Messwertspalten zulässig, soweit die DDL dies festlegt.'
            + NCHAR(10)
            + N'               NumericValue, BigintValue und StringValue sind Alternativen:'
            + NCHAR(10)
            + N'               MetricSample verlangt genau einen nicht-NULL-Wert. ValueType'
            + NCHAR(10)
            + N'               und Unit in MetricDefinition beschreiben dessen Interpretation;'
            + NCHAR(10)
            + N'               der Vertrag garantiert keine Umrechnung. ResetEpochId grenzt'
            + NCHAR(10)
            + N'               Zählerstände über eine Reset-Epoche ab. QualityCode, StatusCode'
            + NCHAR(10)
            + N'               und IsPartial erhalten Qualitäts-, Ablauf- und'
            + NCHAR(10)
            + N'               Vollständigkeitsangaben. ScopeIdentityJson muss JSON sein;'
            + NCHAR(10)
            + N'               ScopeKeyHash ist genau 32 Byte lang. PayloadHash ist ebenfalls'
            + NCHAR(10)
            + N'               32 Byte lang; PayloadFormat und CompressionType sind auf die'
            + NCHAR(10)
            + N'               im Schema genannten Werte beschränkt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Migration    : Die native Vorprüfung akzeptiert nur erkannte Schemaformen.'
            + NCHAR(10)
            + N'               Für erkannte Legacy- und Schema-2-Stände erweitert sie die'
            + NCHAR(10)
            + N'               CollectorCode- und ScopeType-Prüfwerte um FILE_IO'
            + NCHAR(10)
            + N'               beziehungsweise FILE_IO_FILE. Unbekannte oder abweichende'
            + NCHAR(10)
            + N'               Strukturen werden nicht beliebig repariert oder überschrieben.'
            + NCHAR(10)
            + N'               Paketversion 1.2.2 / Schema 3 kennzeichnet Installationsmetadaten,'
            + NCHAR(10)
            + N'               nicht die Laufzeitqualifikation oder Freigabe des Pakets.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Seeds        : Neue DEFAULT-Retention-, PERFORMANCE_COUNTERS-Policy- und'
            + NCHAR(10)
            + N'               Performance-Counter-Metrikzeilen werden nur eingefügt, wenn'
            + NCHAR(10)
            + N'               ihr jeweiliger Schlüssel fehlt. Vorhandene solche Zeilen bleiben'
            + NCHAR(10)
            + N'               erhalten. PackageVersion wird für SC-023 angelegt oder auf'
            + NCHAR(10)
            + N'               Paketversion 1.2.2 und Schema 3 gesetzt; InstalledAtUtc bleibt'
            + NCHAR(10)
            + N'               bei einem vorhandenen Datensatz unverändert, während'
            + NCHAR(10)
            + N'               LastInstallerRunUtc aktualisiert wird.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Voraussetzung: Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare'
            + NCHAR(10)
            + N'               Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das'
            + NCHAR(10)
            + N'               Ziel und verwendet ausschließlich den geprüften Verbindungskontext.'
            + NCHAR(10)
            + N'Datenschutz  : Die Tabellen dürfen im autorisierten Betrieb vollständige reale'
            + NCHAR(10)
            + N'               Laufzeitevidenz einschließlich optionaler Payloads speichern.'
            + NCHAR(10)
            + N'               Dieses Installationsskript enthält nur generische Seeds und'
            + NCHAR(10)
            + N'               keine Laufzeitwerte oder Datenbanknamen.'
            + NCHAR(10)
            + N'Transaktion  : Implizite Transaktionen müssen ausgeschaltet sein. Das Skript'
            + NCHAR(10)
            + N'               verwendet bei Bedarf eine eigene Transaktion, andernfalls einen'
            + NCHAR(10)
            + N'               Savepoint. Im Fehlerfall wird die eigene Transaktion bei'
            + NCHAR(10)
            + N'               XACT_STATE() ungleich 0 zurückgerollt; im Aufruferkontext nur'
            + NCHAR(10)
            + N'               bei XACT_STATE() = 1 bis zum Savepoint. Bei XACT_STATE() = -1'
            + NCHAR(10)
            + N'               kann dieser Savepoint-Rollback nicht erfolgen; ein allgemeiner'
            + NCHAR(10)
            + N'               Rollback der Aufrufertransaktion wird nicht zugesichert.'
            + NCHAR(10)
            + N'               Die gesetzten SET-Optionen gelten für die verbundene Sitzung;'
            + NCHAR(10)
            + N'               das Skript stellt deren vorherige Werte nicht wieder her.'
            + NCHAR(10)
            + N'Locking      : Die privilegierte native Strukturvorprüfung verwendet'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT 10000 und hält geprüfte Tabellen bis zum'
            + NCHAR(10)
            + N'               Transaktionsende. Die anschließende eigene DDL verwendet'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT 0 und wartet nicht auf fremde Sch-M-Sperren.'
            + NCHAR(10)
            + N'Rechte       : CONTROL DATABASE und VIEW ANY DEFINITION sind für die native'
            + NCHAR(10)
            + N'               Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown]
UNION ALL
SELECT CONVERT(sysname,N'snapshot') AS [SchemaName],CONVERT(sysname,N'CollectorPolicy') AS [ObjectName],CONVERT(varchar(24),'TABLE') AS [ObjectType],CONVERT(varchar(24),'snapshot_target') AS [DatabaseRole],CONVERT(bit,0) AS [IsInternal],CONVERT(nvarchar(max),N'Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank.') AS [Description],CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "snapshot.CollectorPolicy"'
            + NCHAR(10)
            + N'schema_name: "snapshot"'
            + NCHAR(10)
            + N'object_name: "CollectorPolicy"'
            + NCHAR(10)
            + N'object_type: "TABLE"'
            + NCHAR(10)
            + N'database_role: "snapshot_target"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank."'
            + NCHAR(10)
            + N'source_path: "Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# snapshot.CollectorPolicy'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank. Das Schema speichert Erfassungsläufe, Status, Scopes, typisierte Messwerte und optionale Nutzdaten. Es startet weder Sammler noch Zeitpläne oder Retention-Purges.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das Ziel und verwendet ausschließlich den geprüften Verbindungskontext.'
            + NCHAR(10)
            + NCHAR(10)
            + N'CONTROL DATABASE und VIEW ANY DEFINITION sind für die native Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Lesender Einsatz erfordert SELECT auf [snapshot].[CollectorPolicy]; Installation und Aktualisierung benötigen die im Quellskript gezeigten DDL- und DML-Rechte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Keine Aufrufparameter.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Tabellenspalten und Constraints aus der eigenen CREATE-TABLE-Definition:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'('
            + NCHAR(10)
            + N'          [CollectorCode] varchar(64) NOT NULL'
            + NCHAR(10)
            + N'        , [IsEnabled] bit NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_CollectorPolicy_IsEnabled] DEFAULT (1)'
            + NCHAR(10)
            + N'        , [CollectionIntervalSeconds] int NOT NULL'
            + NCHAR(10)
            + N'        , [MaxRows] int NOT NULL'
            + NCHAR(10)
            + N'        , [PayloadEnabled] bit NOT NULL'
            + NCHAR(10)
            + N'        , [RetentionPolicyCode] varchar(64) NOT NULL'
            + NCHAR(10)
            + N'        , [IsFrameworkDefault] bit NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_CollectorPolicy_IsFrameworkDefault]'
            + NCHAR(10)
            + N'              DEFAULT (0)'
            + NCHAR(10)
            + N'        , [SeedVersion] int NOT NULL'
            + NCHAR(10)
            + N'        , [LastUpdatedUtc] datetime2(3) NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_CollectorPolicy_LastUpdatedUtc]'
            + NCHAR(10)
            + N'              DEFAULT (SYSUTCDATETIME())'
            + NCHAR(10)
            + N'        , CONSTRAINT [PK_snapshot_CollectorPolicy]'
            + NCHAR(10)
            + N'              PRIMARY KEY CLUSTERED ([CollectorCode])'
            + NCHAR(10)
            + N'        , CONSTRAINT [FK_snapshot_CollectorPolicy_RetentionPolicy]'
            + NCHAR(10)
            + N'              FOREIGN KEY ([RetentionPolicyCode])'
            + NCHAR(10)
            + N'              REFERENCES [snapshot].[RetentionPolicy]([RetentionPolicyCode])'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_CollectorPolicy_CollectorCode]'
            + NCHAR(10)
            + N'              CHECK ([CollectorCode] IN (''PERFORMANCE_COUNTERS'',''WAIT_STATS'',''FILE_IO''))'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_CollectorPolicy_CollectionIntervalSeconds]'
            + NCHAR(10)
            + N'              CHECK ([CollectionIntervalSeconds] BETWEEN 1 AND 3600)'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_CollectorPolicy_MaxRows]'
            + NCHAR(10)
            + N'              CHECK ([MaxRows] BETWEEN 1 AND 100000)'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_CollectorPolicy_SeedVersion]'
            + NCHAR(10)
            + N'              CHECK ([SeedVersion] > 0)'
            + NCHAR(10)
            + N'    )'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT TOP (10) * FROM [snapshot].[CollectorPolicy];'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Das zugehörige Installationsskript enthält CREATE TABLE, INSERT, UPDATE, DELETE; ein lesendes SELECT führt diese Installationsschritte nicht aus. Constraints und NULL-Grenzen stehen in der Tabellendefinition.'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Datei        : 030_Snapshot_Target_Schema.sql'
            + NCHAR(10)
            + N'Version      : 1.2.2'
            + NCHAR(10)
            + N'Stand        : 2026-10-26'
            + NCHAR(10)
            + N'Zweck        : Erstellt und aktualisiert das versionierte Basisschema des'
            + NCHAR(10)
            + N'               optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell'
            + NCHAR(10)
            + N'               verbundenen Datenbank. Das Schema speichert Erfassungsläufe,'
            + NCHAR(10)
            + N'               Status, Scopes, typisierte Messwerte und optionale Nutzdaten.'
            + NCHAR(10)
            + N'               Es startet weder Sammler noch Zeitpläne oder Retention-Purges.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Tabellen     : PackageVersion kennzeichnet Paket- und Schemafassung sowie'
            + NCHAR(10)
            + N'               Erstinstallation und letzten Installationslauf. RetentionPolicy'
            + NCHAR(10)
            + N'               hält Aufbewahrungsfristen für Rohwerte, Nutzdaten und Rollups,'
            + NCHAR(10)
            + N'               Speicherbudget, Purge-Takt, Batchgröße und Budgetaktion.'
            + NCHAR(10)
            + N'               CollectorPolicy beschreibt Aktivierung, Intervall, Zeilenlimit,'
            + NCHAR(10)
            + N'               Nutzdatenerfassung und zugeordnete RetentionPolicy.'
            + NCHAR(10)
            + N'               CaptureRun protokolliert Sammler, Schedulerart, Start und Ende,'
            + NCHAR(10)
            + N'               Quelldatenbankname, SQL-Server-Startzeit, Reset-Epoche,'
            + NCHAR(10)
            + N'               Vertragsfassung, Status, Partialität, Fehler und Zeilenzähler.'
            + NCHAR(10)
            + N'               ModuleStatus hält je Lauf und Modul Zeitpunkt, Status, Partial-'
            + NCHAR(10)
            + N'               und Fehlerangaben sowie Evidenzgrenzen.'
            + NCHAR(10)
            + N'               Scope ordnet Messungen über Scope-Typ, optionalen Eltern-Scope,'
            + NCHAR(10)
            + N'               32-Byte-Schlüsselhash und JSON-Identität einem Erfassungsbereich'
            + NCHAR(10)
            + N'               zu. MetricDefinition beschreibt Metrikcode, Werttyp, Einheit,'
            + NCHAR(10)
            + N'               Vertragsfassung, Text, Framework-Default und Seedfassung.'
            + NCHAR(10)
            + N'               MetricSample verbindet Lauf, Scope und Metrik mit Messzeit,'
            + NCHAR(10)
            + N'               Reset-Epoche, genau einem typisierten Wert, Qualitätscode und'
            + NCHAR(10)
            + N'               Partialitätskennzeichen. PayloadSnapshot speichert optionale,'
            + NCHAR(10)
            + N'               Modulnutzdaten mit Format, Vertragsfassung, Hash'
            + NCHAR(10)
            + N'               und unkomprimierter Zeichenanzahl. PurgeRun protokolliert'
            + NCHAR(10)
            + N'               Aufräumlauf, Status, Batches, gelöschte Zeilen, Budgetmessung'
            + NCHAR(10)
            + N'               und Fehler.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Beziehungen  : Fremdschlüssel verbinden CollectorPolicy mit RetentionPolicy,'
            + NCHAR(10)
            + N'               CaptureRun mit CollectorPolicy, ModuleStatus und PayloadSnapshot'
            + NCHAR(10)
            + N'               mit CaptureRun sowie MetricSample mit CaptureRun, Scope und'
            + NCHAR(10)
            + N'               MetricDefinition. Scope kann auf einen Eltern-Scope verweisen.'
            + NCHAR(10)
            + N'               Primär- und eindeutige Schlüssel verhindern doppelte'
            + NCHAR(10)
            + N'               Policycodes, Modulstatus je Lauf/Modul sowie Messwerte je'
            + NCHAR(10)
            + N'               Lauf/Scope/Metrik. Ein gefilterter eindeutiger Index lässt'
            + NCHAR(10)
            + N'               höchstens eine RetentionPolicy als Framework-Default zu;'
            + NCHAR(10)
            + N'               Zeit- und Zuordnungsindizes unterstützen die im Schema'
            + NCHAR(10)
            + N'               vorgesehenen Lauf-, Messwert-, Nutzdaten- und Purgeabfragen.'
            + NCHAR(10)
            + N'               Die DDL definiert keine kaskadierenden Fremdschlüssel.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Werte        : UTC-Zeitfelder geben den jeweiligen Erfassungs-, Lauf- oder'
            + NCHAR(10)
            + N'               Änderungszeitpunkt an. NULL ist bei Endzeiten, optionalen'
            + NCHAR(10)
            + N'               Start-/Resetinformationen, Fehlerfeldern und alternativen'
            + NCHAR(10)
            + N'               Messwertspalten zulässig, soweit die DDL dies festlegt.'
            + NCHAR(10)
            + N'               NumericValue, BigintValue und StringValue sind Alternativen:'
            + NCHAR(10)
            + N'               MetricSample verlangt genau einen nicht-NULL-Wert. ValueType'
            + NCHAR(10)
            + N'               und Unit in MetricDefinition beschreiben dessen Interpretation;'
            + NCHAR(10)
            + N'               der Vertrag garantiert keine Umrechnung. ResetEpochId grenzt'
            + NCHAR(10)
            + N'               Zählerstände über eine Reset-Epoche ab. QualityCode, StatusCode'
            + NCHAR(10)
            + N'               und IsPartial erhalten Qualitäts-, Ablauf- und'
            + NCHAR(10)
            + N'               Vollständigkeitsangaben. ScopeIdentityJson muss JSON sein;'
            + NCHAR(10)
            + N'               ScopeKeyHash ist genau 32 Byte lang. PayloadHash ist ebenfalls'
            + NCHAR(10)
            + N'               32 Byte lang; PayloadFormat und CompressionType sind auf die'
            + NCHAR(10)
            + N'               im Schema genannten Werte beschränkt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Migration    : Die native Vorprüfung akzeptiert nur erkannte Schemaformen.'
            + NCHAR(10)
            + N'               Für erkannte Legacy- und Schema-2-Stände erweitert sie die'
            + NCHAR(10)
            + N'               CollectorCode- und ScopeType-Prüfwerte um FILE_IO'
            + NCHAR(10)
            + N'               beziehungsweise FILE_IO_FILE. Unbekannte oder abweichende'
            + NCHAR(10)
            + N'               Strukturen werden nicht beliebig repariert oder überschrieben.'
            + NCHAR(10)
            + N'               Paketversion 1.2.2 / Schema 3 kennzeichnet Installationsmetadaten,'
            + NCHAR(10)
            + N'               nicht die Laufzeitqualifikation oder Freigabe des Pakets.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Seeds        : Neue DEFAULT-Retention-, PERFORMANCE_COUNTERS-Policy- und'
            + NCHAR(10)
            + N'               Performance-Counter-Metrikzeilen werden nur eingefügt, wenn'
            + NCHAR(10)
            + N'               ihr jeweiliger Schlüssel fehlt. Vorhandene solche Zeilen bleiben'
            + NCHAR(10)
            + N'               erhalten. PackageVersion wird für SC-023 angelegt oder auf'
            + NCHAR(10)
            + N'               Paketversion 1.2.2 und Schema 3 gesetzt; InstalledAtUtc bleibt'
            + NCHAR(10)
            + N'               bei einem vorhandenen Datensatz unverändert, während'
            + NCHAR(10)
            + N'               LastInstallerRunUtc aktualisiert wird.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Voraussetzung: Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare'
            + NCHAR(10)
            + N'               Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das'
            + NCHAR(10)
            + N'               Ziel und verwendet ausschließlich den geprüften Verbindungskontext.'
            + NCHAR(10)
            + N'Datenschutz  : Die Tabellen dürfen im autorisierten Betrieb vollständige reale'
            + NCHAR(10)
            + N'               Laufzeitevidenz einschließlich optionaler Payloads speichern.'
            + NCHAR(10)
            + N'               Dieses Installationsskript enthält nur generische Seeds und'
            + NCHAR(10)
            + N'               keine Laufzeitwerte oder Datenbanknamen.'
            + NCHAR(10)
            + N'Transaktion  : Implizite Transaktionen müssen ausgeschaltet sein. Das Skript'
            + NCHAR(10)
            + N'               verwendet bei Bedarf eine eigene Transaktion, andernfalls einen'
            + NCHAR(10)
            + N'               Savepoint. Im Fehlerfall wird die eigene Transaktion bei'
            + NCHAR(10)
            + N'               XACT_STATE() ungleich 0 zurückgerollt; im Aufruferkontext nur'
            + NCHAR(10)
            + N'               bei XACT_STATE() = 1 bis zum Savepoint. Bei XACT_STATE() = -1'
            + NCHAR(10)
            + N'               kann dieser Savepoint-Rollback nicht erfolgen; ein allgemeiner'
            + NCHAR(10)
            + N'               Rollback der Aufrufertransaktion wird nicht zugesichert.'
            + NCHAR(10)
            + N'               Die gesetzten SET-Optionen gelten für die verbundene Sitzung;'
            + NCHAR(10)
            + N'               das Skript stellt deren vorherige Werte nicht wieder her.'
            + NCHAR(10)
            + N'Locking      : Die privilegierte native Strukturvorprüfung verwendet'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT 10000 und hält geprüfte Tabellen bis zum'
            + NCHAR(10)
            + N'               Transaktionsende. Die anschließende eigene DDL verwendet'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT 0 und wartet nicht auf fremde Sch-M-Sperren.'
            + NCHAR(10)
            + N'Rechte       : CONTROL DATABASE und VIEW ANY DEFINITION sind für die native'
            + NCHAR(10)
            + N'               Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown]
UNION ALL
SELECT CONVERT(sysname,N'snapshot') AS [SchemaName],CONVERT(sysname,N'InternalCompleteFileIOCycle') AS [ObjectName],CONVERT(varchar(24),'INTERNAL_PROCEDURE') AS [ObjectType],CONVERT(varchar(24),'snapshot_target') AS [DatabaseRole],CONVERT(bit,1) AS [IsInternal],CONVERT(nvarchar(max),N'Die Procedure bindet Datei-I/O-Rohwerte und Vergleichskontexte atomar an einen vorbereiteten eigenen Lauf.') AS [Description],CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "snapshot.InternalCompleteFileIOCycle"'
            + NCHAR(10)
            + N'schema_name: "snapshot"'
            + NCHAR(10)
            + N'object_name: "InternalCompleteFileIOCycle"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "snapshot_target"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Die Procedure bindet Datei-I/O-Rohwerte und Vergleichskontexte atomar an einen vorbereiteten eigenen Lauf."'
            + NCHAR(10)
            + N'source_path: "Code/10_SnapshotBaseline/057_InternalCompleteFileIOCycle.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# snapshot.InternalCompleteFileIOCycle'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure bindet Datei-I/O-Rohwerte und Vergleichskontexte atomar an einen vorbereiteten eigenen Lauf.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [snapshot].[InternalCompleteFileIOCycle]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `master.sys.databases`, `sys.databases`, `sys.database_files`, `sys.dm_os_sys_info`, `sys.dm_io_virtual_file_stats`, `[master].[sys].[databases]`, `[snapshot].[PackageVersion]`, `[snapshot].[InternalPurgeExpiredData]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| @CaptureRunId | bigint | ja | kein Default |'
            + NCHAR(10)
            + N'| @CollectorJson | nvarchar(max) | ja | kein Default |'
            + NCHAR(10)
            + N'| @ExpectedTargetDatabaseId | int | ja | kein Default |'
            + NCHAR(10)
            + N'| @ExpectedTargetDatabaseName | sysname | ja | kein Default |'
            + NCHAR(10)
            + N'| @ExpectedTargetCreateDate | datetime | ja | kein Default |'
            + NCHAR(10)
            + N'| @StatusCodeOut | varchar(40) OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @IsPartialOut | bit OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @ErrorNumberOut | int OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @ErrorMessageOut | nvarchar(2048) OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CaptureRunId:** | @CaptureRunId | bigint; > 0; ID des unbeschriebenen eigenen FILE_IO-Laufs mit Status RUNNING. NULL/0/negativ ergibt INVALID_PARAMETER / 51011; Default: kein Default |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CollectorJson:** | @CollectorJson | nvarchar(max); vollständiges JSON-Objekt gemäß Schema. NULL, Leertext und ungültiges JSON werden erst nach bestätigtem eigenem Lauf als ERROR_HANDLED / 53782 behandelt, nicht als globales INVALID_PARAMETER; Default: kein Default |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ExpectedTargetDatabaseId:** | @ExpectedTargetDatabaseId | int; einzelner typisierter Wert > 4 für die aktuelle, online befindliche, beschreibbare Zieldatenbank. NULL oder abweichende Identität ergibt TARGET_UNAVAILABLE / 53764; Default: kein Default |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ExpectedTargetDatabaseName:** | @ExpectedTargetDatabaseName | sysname; einzelner roher Datenbankname bis 128 UTF-16-Codeeinheiten. Vergleich mit dem aktuellen Katalognamen ist binär, ohne Trimmen oder Schreibweisenausgleich. NULL oder ein fehlender exakter Match ergibt TARGET_UNAVAILABLE / 53764; Default: kein Default |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ExpectedTargetCreateDate:** | @ExpectedTargetCreateDate | datetime; einzelner typisierter Erstellungszeitpunkt aus master.sys.databases.create_date für das aktuelle Target. NULL oder Abweichung ergibt TARGET_UNAVAILABLE / 53764; Default: kein Default |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCodeOut:** | @StatusCodeOut | varchar(40) OUTPUT; initial AVAILABLE. AVAILABLE: ausschließlich Initialwert, kein Abschlussnachweis; INVALID_PARAMETER: frühe Eingabe oder Lauf ungültig; TARGET_UNAVAILABLE: Target nicht verfügbar; DENIED_PERMISSION: Zugriff verweigert; UNAVAILABLE_OBJECT: durchgereichter Source-Status für ein nicht verfügbares Objekt; ERROR_HANDLED: behandelter Fehler; ein nachträglicher Fehlerabschluss ist nicht generell garantiert; PARTIAL: bestätigter regulärer Sourceabschluss unter den beschriebenen Evidenzgrenzen; FINALIZATION_UNCONFIRMED: Finalisierung unbestätigt; Default: kein Default | Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@IsPartialOut:** | @IsPartialOut | bit OUTPUT; initial 0; Fehler-, PARTIAL- und FINALIZATION_UNCONFIRMED-Pfade setzen 1; Default: kein Default | Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorNumberOut:** | @ErrorNumberOut | Der erforderliche Parameter @ErrorNumberOut ist int OUTPUT ohne Default. Er wird beim Eintritt zunächst auf NULL gesetzt. NULL, ein typisierter int-Wert oder ein ohne OUTPUT-Bindung übergebener Wert sind zulässige Argumentformen; die SQL-Typkonvertierung erfolgt vor Eintritt. Zum Erfassen muss eine int-Variable mit OUTPUT gebunden werden. Das Argument darf nicht ausgelassen werden. Bei frühen Eingabefehlern wird 51011 ausgegeben, bei der frühen Prüfung einer nicht bestätigten erwarteten Targetidentität 53764. Andere vor SourceValidated abgefangene Fehler geben grundsätzlich die tatsächliche SQL-Fehlernummer aus; 53783 bei OwnRun=0 (kein bestätigter eigener unbeschriebener Lauf) wird als 51011 zurückgegeben. Eingehende Werte werden durch die Initialisierung verworfen; leerer Text kann zuvor nach int 0 konvertiert werden. Ohne OUTPUT-Bindung wird der Rückgabewert verworfen. Nach validierter Source entspricht die Nummer dem ersten Issue mit nicht-N'
            + N'ULL ErrorNumber, ersatzweise dem ersten Issue in Issue-Arrayreihenfolge; ohne Issues ist sie NULL. META.errorNumber muss der ausgewählten Sourcefehlernummer entsprechen. Bei erfolgreichem regulären Abschluss kann PARTIAL diese Sourcefehlernummer behalten. Scheitert das Backend nach SourceValidated, gibt eine erfolgreiche getrennte Fehlerfinalisierung die Sourcefehlernummer einschließlich NULL zurück; der tatsächliche Backendfehler wird separat in ModuleStatus festgehalten, soweit diese Finalisierung persistiert. Ist die Finalisierungsgrenze unbestätigt, kann die Ausgabe weiterhin die Sourcefehlernummer enthalten, wenn die Grenzmarkierung geschrieben wird, oder bei einem Fehler in der inneren Finalisierung die Nummer dieses Finalisierungsfehlers. Source- und native Fehlernummern sind vorzeichenbehaftete SQL-int-Werte; 0 und negative Werte sind zulässig. Der Bereich wird nicht auf eine geschlossene Liste von Fehlercodes begrenzt. Eine Fehlerausgabe ist nicht für jeden Aufruf garantiert, '
            + N'weil etwa die frühe Targetabfrage vor TRY ungefangen fehlschlagen kann. | Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessageOut:** | @ErrorMessageOut | Der erforderliche Parameter @ErrorMessageOut ist nvarchar(2048) OUTPUT ohne Default und wird beim Eintritt zunächst auf NULL gesetzt. NULL oder ein typisierter nvarchar(2048)-Wert kann übergeben werden; die SQL-Typkonvertierung erfolgt vor Eintritt. Zum Erfassen muss eine nvarchar(2048)-Variable mit OUTPUT gebunden werden. Das Argument darf nicht ausgelassen werden. Ein Wert ohne OUTPUT-Bindung verwirft die Rückgabe; eingehende Werte einschließlich NULL oder Leertext werden bei Eintritt zurückgesetzt. Bei frühen Eingabefehlern wird die Meldung zu 51011 ausgegeben, bei einer früh nicht bestätigten erwarteten Targetidentität die Meldung zu 53764. Andere vor SourceValidated abgefangene Fehler geben ihre SQL-Fehlermeldung aus. Bei OwnRun=0 wird 53783 wegen eines nicht bestätigten eigenen unbeschriebenen Laufs als 51011 zurückgegeben, seine Meldung bleibt unverändert. Nach validierter Source stammt die Meldung aus demselben Issue wie @ErrorNumberOu'
            + N't: dem ersten Issue mit nicht-NULL ErrorNumber, ersatzweise dem ersten in Arrayreihenfolge. META.errorMessage muss dem Text desselben ausgewählten Issues binär exakt entsprechen. Ohne Issues sind beide META-Fehlerwerte und damit diese Sourceausgaben NULL. Die Meldung kann NULL oder Leertext sein; beides ist verschieden. Bei erfolgreichem regulären Abschluss kann PARTIAL den Sourcefehlertext unverändert behalten. Scheitert das Backend nach SourceValidated, gibt eine erfolgreiche getrennte Fehlerfinalisierung den Sourcefehlertext einschließlich NULL oder Leertext aus; der tatsächliche Backendfehler wird separat in ModuleStatus festgehalten, soweit diese Finalisierung persistiert. Ist die Finalisierungsgrenze unbestätigt, kann die Ausgabe weiterhin den Sourcefehlertext enthalten, wenn die Grenzmarkierung geschrieben wird, oder bei einem Fehler in der inneren Finalisierung die Meldung dieses Finalisierungsfehlers. Der Helper fügt keinen Vergleichscode an und filtert den Sourcefehlertext ni'
            + N'cht. Eine Fehlerausgabe ist nicht in jedem Pfad garantiert; die frühe Targetabfrage vor TRY kann ungefangen fehlschlagen. | Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Kein Fach-Resultset. `@StatusCodeOut varchar(40)`, `@IsPartialOut bit`, `@ErrorNumberOut int` und `@ErrorMessageOut nvarchar(2048)` melden den gebundenen File-I/O-Zielabschluss. Der Helper validiert CollectorJson/Targetidentität und schreibt nur zum eigenen CaptureRun; PARTIAL oder Fehler belegen keinen vollständigen Dateiquellenread.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT [SkillMarkdown]'
            + NCHAR(10)
            + N'FROM [monitor_metadata].[VW_ObjectUsageSkills]'
            + NCHAR(10)
            + N'WHERE [SchemaName]=N''snapshot'' AND [ObjectName]=N''InternalCompleteFileIOCycle'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [snapshot].[InternalCompleteFileIOCycle] @CaptureRunId=NULL, @CollectorJson=NULL, @ExpectedTargetDatabaseId=NULL, @ExpectedTargetDatabaseName=NULL, @ExpectedTargetCreateDate=NULL, @StatusCodeOut=NULL, @IsPartialOut=NULL, @ErrorNumberOut=NULL, @ErrorMessageOut=NULL, @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Alle neun Parameter sind erforderlich; die Signatur hat keine Defaults.'
            + NCHAR(10)
            + N'| Parameter | Vertrag |'
            + NCHAR(10)
            + N'|---|---|'
            + NCHAR(10)
            + N'| @CaptureRunId | bigint; > 0; ID des unbeschriebenen eigenen FILE_IO-Laufs mit Status RUNNING. NULL/0/negativ ergibt INVALID_PARAMETER / 51011; Default: kein Default |'
            + NCHAR(10)
            + N'| @CollectorJson | nvarchar(max); vollständiges JSON-Objekt gemäß Schema. NULL, Leertext und ungültiges JSON werden erst nach bestätigtem eigenem Lauf als ERROR_HANDLED / 53782 behandelt, nicht als globales INVALID_PARAMETER; Default: kein Default |'
            + NCHAR(10)
            + N'| @ExpectedTargetDatabaseId | int; einzelner typisierter Wert > 4 für die aktuelle, online befindliche, beschreibbare Zieldatenbank. NULL oder abweichende Identität ergibt TARGET_UNAVAILABLE / 53764; Default: kein Default |'
            + NCHAR(10)
            + N'| @ExpectedTargetDatabaseName | sysname; einzelner roher Datenbankname bis 128 UTF-16-Codeeinheiten. Vergleich mit dem aktuellen Katalognamen ist binär, ohne Trimmen oder Schreibweisenausgleich. NULL oder ein fehlender exakter Match ergibt TARGET_UNAVAILABLE / 53764; Default: kein Default |'
            + NCHAR(10)
            + N'| @ExpectedTargetCreateDate | datetime; einzelner typisierter Erstellungszeitpunkt aus master.sys.databases.create_date für das aktuelle Target. NULL oder Abwe'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Objekt       : snapshot.InternalCompleteFileIOCycle'
            + NCHAR(10)
            + N'Version      : 1.1.0'
            + NCHAR(10)
            + N'Stand        : 2026-10-26'
            + NCHAR(10)
            + N'Zweck        : Die Procedure bindet Datei-I/O-Rohwerte und Vergleichskontexte'
            + NCHAR(10)
            + N'               atomar an einen vorbereiteten eigenen Lauf.'
            + NCHAR(10)
            + N'Grenze       : Monotone Kandidaten beweisen keine Resetkontinuität.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Alle neun Parameter sind erforderlich; die Signatur hat keine Defaults.'
            + NCHAR(10)
            + N'| Parameter | Vertrag |'
            + NCHAR(10)
            + N'|---|---|'
            + NCHAR(10)
            + N'| @CaptureRunId | bigint; > 0; ID des unbeschriebenen eigenen FILE_IO-Laufs mit Status RUNNING. NULL/0/negativ ergibt INVALID_PARAMETER / 51011; Default: kein Default |'
            + NCHAR(10)
            + N'| @CollectorJson | nvarchar(max); vollständiges JSON-Objekt gemäß Schema. NULL, Leertext und ungültiges JSON werden erst nach bestätigtem eigenem Lauf als ERROR_HANDLED / 53782 behandelt, nicht als globales INVALID_PARAMETER; Default: kein Default |'
            + NCHAR(10)
            + N'| @ExpectedTargetDatabaseId | int; einzelner typisierter Wert > 4 für die aktuelle, online befindliche, beschreibbare Zieldatenbank. NULL oder abweichende Identität ergibt TARGET_UNAVAILABLE / 53764; Default: kein Default |'
            + NCHAR(10)
            + N'| @ExpectedTargetDatabaseName | sysname; einzelner roher Datenbankname bis 128 UTF-16-Codeeinheiten. Vergleich mit dem aktuellen Katalognamen ist binär, ohne Trimmen oder Schreibweisenausgleich. NULL oder ein fehlender exakter Match ergibt TARGET_UNAVAILABLE / 53764; Default: kein Default |'
            + NCHAR(10)
            + N'| @ExpectedTargetCreateDate | datetime; einzelner typisierter Erstellungszeitpunkt aus master.sys.databases.create_date für das aktuelle Target. NULL oder Abweichung ergibt TARGET_UNAVAILABLE / 53764; Default: kein Default |'
            + NCHAR(10)
            + N'| @StatusCodeOut | varchar(40) OUTPUT; initial AVAILABLE. AVAILABLE: ausschließlich Initialwert, kein Abschlussnachweis; INVALID_PARAMETER: frühe Eingabe oder Lauf ungültig; TARGET_UNAVAILABLE: Target nicht verfügbar; DENIED_PERMISSION: Zugriff verweigert; UNAVAILABLE_OBJECT: durchgereichter Source-Status für ein nicht verfügbares Objekt; ERROR_HANDLED: behandelter Fehler; ein nachträglicher Fehlerabschluss ist nicht generell garantiert; PARTIAL: bestätigter regulärer Sourceabschluss unter den beschriebenen Evidenzgrenzen; FINALIZATION_UNCONFIRMED: Finalisierung unbestätigt; Default: kein Default |'
            + NCHAR(10)
            + N'| @IsPartialOut | bit OUTPUT; initial 0; Fehler-, PARTIAL- und FINALIZATION_UNCONFIRMED-Pfade setzen 1; Default: kein Default |'
            + NCHAR(10)
            + N'| @ErrorNumberOut | Der erforderliche Parameter @ErrorNumberOut ist int OUTPUT ohne Default. Er wird beim Eintritt zunächst auf NULL gesetzt. NULL, ein typisierter int-Wert oder ein ohne OUTPUT-Bindung übergebener Wert sind zulässige Argumentformen; die SQL-Typkonvertierung erfolgt vor Eintritt. Zum Erfassen muss eine int-Variable mit OUTPUT gebunden werden. Das Argument darf nicht ausgelassen werden. Bei frühen Eingabefehlern wird 51011 ausgegeben, bei der frühen Prüfung einer nicht bestätigten erwarteten Targetidentität 53764. Andere vor SourceValidated abgefangene Fehler geben grundsätzlich die tatsächliche SQL-Fehlernummer aus; 53783 bei OwnRun=0 (kein bestätigter eigener unbeschriebener Lauf) wird als 51011 zurückgegeben. Eingehende Werte werden durch die Initialisierung verworfen; leerer Text kann zuvor nach int 0 konvertiert werden. Ohne OUTPUT-Bindung wird der Rückgabewert verworfen. Nach validierter Source entspricht die Nummer dem ersten Issue mit nicht-NULL ErrorNumber, ersa'
            + N'tzweise dem ersten Issue in Issue-Arrayreihenfolge; ohne Issues ist sie NULL. META.errorNumber muss der ausgewählten Sourcefehlernummer entsprechen. Bei erfolgreichem regulären Abschluss kann PARTIAL diese Sourcefehlernummer behalten. Scheitert das Backend nach SourceValidated, gibt eine erfolgreiche getrennte Fehlerfinalisierung die Sourcefehlernummer einschließlich NULL zurück; der tatsächliche Backendfehler wird separat in ModuleStatus festgehalten, soweit diese Finalisierung persistiert. Ist die Finalisierungsgrenze unbestätigt, kann die Ausgabe weiterhin die Sourcefehlernummer enthalten, wenn die Grenzmarkierung geschrieben wird, oder bei einem Fehler in der inneren Finalisierung die Nummer dieses Finalisierungsfehlers. Source- und native Fehlernummern sind vorzeichenbehaftete SQL-int-Werte; 0 und negative Werte sind zulässig. Der Bereich wird nicht auf eine geschlossene Liste von Fehlercodes begrenzt. Eine Fehlerausgabe ist nicht für jeden Aufruf garantiert, weil etwa die frühe T'
            + N'argetabfrage vor TRY ungefangen fehlschlagen kann. |'
            + NCHAR(10)
            + N'| @ErrorMessageOut | Der erforderliche Parameter @ErrorMessageOut ist nvarchar(2048) OUTPUT ohne Default und wird beim Eintritt zunächst auf NULL gesetzt. NULL oder ein typisierter nvarchar(2048)-Wert kann übergeben werden; die SQL-Typkonvertierung erfolgt vor Eintritt. Zum Erfassen muss eine nvarchar(2048)-Variable mit OUTPUT gebunden werden. Das Argument darf nicht ausgelassen werden. Ein Wert ohne OUTPUT-Bindung verwirft die Rückgabe; eingehende Werte einschließlich NULL oder Leertext werden bei Eintritt zurückgesetzt. Bei frühen Eingabefehlern wird die Meldung zu 51011 ausgegeben, bei einer früh nicht bestätigten erwarteten Targetidentität die Meldung zu 53764. Andere vor SourceValidated abgefangene Fehler geben ihre SQL-Fehlermeldung aus. Bei OwnRun=0 wird 53783 wegen eines nicht bestätigten eigenen unbeschriebenen Laufs als 51011 zurückgegeben, seine Meldung bleibt unverändert. Nach validierter Source stammt die Meldung aus demselben Issue wie @ErrorNumberOut: dem ersten Issue mi'
            + N't nicht-NULL ErrorNumber, ersatzweise dem ersten in Arrayreihenfolge. META.errorMessage muss dem Text desselben ausgewählten Issues binär exakt entsprechen. Ohne Issues sind beide META-Fehlerwerte und damit diese Sourceausgaben NULL. Die Meldung kann NULL oder Leertext sein; beides ist verschieden. Bei erfolgreichem regulären Abschluss kann PARTIAL den Sourcefehlertext unverändert behalten. Scheitert das Backend nach SourceValidated, gibt eine erfolgreiche getrennte Fehlerfinalisierung den Sourcefehlertext einschließlich NULL oder Leertext aus; der tatsächliche Backendfehler wird separat in ModuleStatus festgehalten, soweit diese Finalisierung persistiert. Ist die Finalisierungsgrenze unbestätigt, kann die Ausgabe weiterhin den Sourcefehlertext enthalten, wenn die Grenzmarkierung geschrieben wird, oder bei einem Fehler in der inneren Finalisierung die Meldung dieses Finalisierungsfehlers. Der Helper fügt keinen Vergleichscode an und filtert den Sourcefehlertext nicht. Eine Fehlerausgab'
            + N'e ist nicht in jedem Pfad garantiert; die frühe Targetabfrage vor TRY kann ungefangen fehlschlagen. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'Alle neun Argumente sind erforderlich. OUTPUT-Argumente dürfen als typisierte'
            + NCHAR(10)
            + N'Werte oder NULL ohne OUTPUT-Bindung übergeben werden; normale SQL-'
            + NCHAR(10)
            + N'Konvertierungen gelten. Eine Variable mit OUTPUT ist nur zur Erfassung nötig.'
            + NCHAR(10)
            + N'Alle vier gebundenen OUTPUT-Eingangswerte werden ignoriert; die normalen SQL-Typkonvertierungen erfolgen vor dem Eintritt. Leertext ist keine unterstützte Eingabeform für numerische oder datetime-Parameter.'
            + NCHAR(10)
            + NCHAR(10)
            + N'JSON-Sourcevertrag'
            + NCHAR(10)
            + N'Das Rootobjekt hat genau meta (Objekt), databases (Array), files (Array), issues (Array). Alle unten aufgeführten Member sind je Objekt genau einmal erforderlich; keine Zusatzmember oder Duplikate. Member werden mit BIN2 und gleicher UTF-16-Länge verglichen. OPENJSON-Typen: Objekt, Array, String, Zahl, Boolean, NULL. NULL nur wo ausgewiesen. Keine Defaults.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Objekt | Member | Typ / NULL | Format und Grenzen |'
            + NCHAR(10)
            + N'|---|---|---|---|'
            + NCHAR(10)
            + N'| META | schemaVersion; resultName; statusCode; nativeReadState; isPartial; sourceComplete | Zahl; String; String; String; Boolean; Boolean, alle nicht-null | Version exakt 1; SnapshotFileIO (max 40); Source status AVAILABLE/EMPTY_UNPROVEN/PARTIAL/DENIED_PERMISSION/UNAVAILABLE_OBJECT/ERROR_HANDLED; Readstatus NOT_STARTED/SUCCEEDED/FAILED; isPartial genau false bei AVAILABLE sonst true; sourceComplete genau true bei AVAILABLE oder EMPTY_UNPROVEN. |'
            + NCHAR(10)
            + N'| META | errorNumber; errorMessage | Zahl/NULL; String/NULL | Vorzeichenbehafteter SQL int einschließlich 0 und negative Werte; Nachricht max 2048 UTF-16-Codeeinheiten, NULL ≠ Leertext. |'
            + NCHAR(10)
            + N'| META | measurementStartUtc, measurementEndUtc; nativeReadStartUtc, nativeReadEndUtc | String/NULL | Paarweise beide NULL oder gesetzt; Reihenfolge gültig. UTC exakt yyyy-MM-ddTHH:mm:ss.fffZ. Bei nichtfatalem Status ist das Messfenster erforderlich; ein nichtfataler SUCCEEDED-Read benötigt darin ein vorhandenes Readfenster. Bei fatalem SUCCEEDED darf das geordnete Readfenster NULL sein. NOT_STARTED und FAILED besitzen kein Readfenster. |'
            + NCHAR(10)
            + N'| META | selectedNativeRows | String/NULL | Nichtnegative kanonische Dezimalzahl ohne führende Nullen, bigint-Bereich; SUCCEEDED erforderlich, FAILED NULL. |'
            + NCHAR(10)
            + N'| META | framework; selection; engine | Objekt; Objekt; Objekt/NULL | FW- und SEL-Schema unten; ENGINE bei nichtfatalen Sourcezuständen erforderlich, bei DENIED_PERMISSION/UNAVAILABLE_OBJECT/ERROR_HANDLED NULL. |'
            + NCHAR(10)
            + N'| FW | databaseId; databaseName; databaseCreateDateNative | Zahl; String; String | ID 1..2147483647; Name max 128; native datetime yyyy-MM-ddTHH:mm:ss.fff. ID, Name und CreateDateNative müssen master.sys.databases sowie CaptureRun.SourceDatabaseName treffen; das belegt keine authentische DMV-Herkunft. |'
            + NCHAR(10)
            + N'| ENGINE | serverName; sqlServerStartTimeLocal; sqlServerStartTimeMsTicks | String; String; String | Name max 128 ohne zusätzliche Mindestlänge; native datetime yyyy-MM-ddTHH:mm:ss.fff; kanonische nichtnegative Dezimalzahl im bigint-Bereich. |'
            + NCHAR(10)
            + N'| SEL | requestedDatabaseNames; requestedDatabaseNamePattern | String/NULL; String/NULL | Pattern max 4000; beide Provenienzlabels: Helper parst die Grammatik nicht erneut, filtert nicht erneut und setzt keine gegenseitige Ausschließlichkeit voraus. |'
            + NCHAR(10)
            + N'| SEL | systemDatabasesIncluded; selectedDatabaseCount; selectionSha256 | Boolean; String; String | Count kanonisch nichtnegativ im bigint-Bereich und gleich DB-Arraygröße; Hash 64 kleingeschriebene Hexzeichen ohne Präfix: SHA-256 der SQL-spezifischen FOR JSON-Serialisierung der nach DatabaseId geordneten Datenbanktripel mit den Propertynamen DatabaseId, DatabaseName, DatabaseCreateDateNative in dieser Reihenfolge, UTF-16LE. |'
            + NCHAR(10)
            + N'| DB | DatabaseId; DatabaseName; DatabaseCreateDateNative; MetadataStatusCode | Zahl; String; String; String | ID 1..2147483647 und eindeutig; Name max 128 ohne Mindestlänge; native datetime yyyy-MM-ddTHH:mm:ss.fff; Status AVAILABLE/DENIED_PERMISSION/UNAVAILABLE_OBJECT/TARGET_CHANGED/ERROR_HANDLED (TARGET_CHANGED: beobachtete DB-Identität geändert). |'
            + NCHAR(10)
            + N'| FILE | DatabaseId; FileId | Zahl; Zahl | ID jeweils 1..2147483647; DB-ID muss im DB-Array liegen; Paar eindeutig. |'
            + NCHAR(10)
            + N'| FILE | SampleMs; Reads; ReadBytes; ReadStallMs; Writes; WriteBytes; WriteStallMs; SizeOnDiskBytes | Zahl (8 Werte) | Je bigint, nichtnegative kanonische Dezimalzahl ohne führende Nullen. |'
            + NCHAR(10)
            + N'| FILE | FileHandle; MetadataBefore; MetadataAfter | String/NULL; Objekt/NULL; Objekt/NULL | Handle NULL oder 0x + 16 kleingeschriebene Hexzeichen. Metadaten NULL oder vollständiges MB/MA-Objekt. |'
            + NCHAR(10)
            + N'| MB/MA | DatabaseId; FileId; FileGuid; CreateLsn | Zahl; Zahl; String/NULL; String/NULL | IDs 1..2147483647; Abweichung von FILE-Identität macht die Beobachtung UNBOUND, aber ist kein JSON-Formfehler. GUID NULL oder kanonisch 36 Zeichen lowercase, Null-GUID zulässig; LSN NULL oder nichtnegativ kanonisch im decimal(25,0)-Bereich. |'
            + NCHAR(10)
            + N'| MB/MA | FileType; FileState; LogicalName | Zahl; Zahl; String | Beide tinyint 0..255; ROWS/LOG-Eignung nutzt Type 0/1 und State 0, andere typisierte Werte bleiben beobachtbar und können ausgeschlossen sein. LogicalName max 128, keine Mindestlänge. |'
            + NCHAR(10)
            + N'| ISSUE | ScopeType; SourceName; DatabaseName; StatusCode | String; String; String/NULL; String | ScopeType: SELECTION (Auswahl), SOURCE (Source-/Engine-Read), DATABASE (Datenbankmetadaten), FILE (Dateimetadaten/native Zeile). SourceName: DATABASE_SELECTION (Auswahlauflösung), sys.databases (Datenbankidentitätsread), sys.database_files (Dateimetadaten), sys.dm_os_sys_info (Engine), sys.dm_io_virtual_file_stats (nativer Cache), SOURCE_CONTRACT (Sourcevertragsvalidierung); alle sechs Werte max. 128 UTF-16-Codeeinheiten. DatabaseName max. 128. Status aus Issue-Katalog unten. |'
            + NCHAR(10)
            + N'| ISSUE | ErrorMessage; EvidenceLimit; DatabaseId; FileId; ErrorNumber | String/NULL; String/NULL; Zahl/NULL; Zahl/NULL; Zahl/NULL | Grenzen 2048/1000 UTF-16-Codeeinheiten; IDs NULL oder 1..2147483647; ErrorNumber NULL oder signed SQL int einschließlich 0/negativ. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'Stringzahlen: ASCII-Ziffern, nichtnegativ, keine führenden Nullen außer 0. GUID ist lowercase; Handle beginnt 0x und hat 16 lowercase Hexziffern; SHA hat 64 lowercase Hexziffern ohne 0x. UTC hat Z und Millisekunden, native datetime exakt drei Millisekunden ohne Z. Binäre Kanonizitätsprüfung. BIN2+UTF-16-Länge bei Membern bedeutet keine Zusage, dass jedes Enum mit abschließendem U+0020 eigens abgelehnt wird.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Katalog | Geschlossene Werte mit Bedeutung |'
            + NCHAR(10)
            + N'|---|---|'
            + NCHAR(10)
            + N'| Source status | AVAILABLE: vollständige Beobachtung; EMPTY_UNPROVEN: vollständig mit null ELIGIBLE-Dateien, aber kein Nachweis für null native Zeilen oder einen leeren Scope; PARTIAL: nichtfatale, nicht als vollständig bestätigte Beobachtung; DENIED_PERMISSION: Berechtigung verweigert; UNAVAILABLE_OBJECT: erforderliches Objekt fehlt; ERROR_HANDLED: sonstiger abgefangener Sourcefehler. |'
            + NCHAR(10)
            + N'| Native Read | NOT_STARTED: kein nativer Read; SUCCEEDED: vollständiger nativer Cache-Read; FAILED: nativer Read fehlgeschlagen. |'
            + NCHAR(10)
            + N'| DB MetadataStatusCode | AVAILABLE: Vorher-/Nachher-Metadatenread abgeschlossen; DENIED_PERMISSION: Zugriff verweigert; UNAVAILABLE_OBJECT: Katalogobjekt fehlt; TARGET_CHANGED: beobachtete Datenbankidentität änderte sich; ERROR_HANDLED: anderer Metadatenfehler. |'
            + NCHAR(10)
            + N'| Issue ScopeType | SELECTION: Auswahlauflösung; SOURCE: Source- oder Engine-Read; DATABASE: Datenbankmetadaten; FILE: Datei-Metadaten oder nativer Dateieintrag. |'
            + NCHAR(10)
            + N'| Issue SourceName | DATABASE_SELECTION: Auswahlauflösung; sys.databases: Datenbankidentitätsread; sys.database_files: Datei-Metadaten; sys.dm_os_sys_info: Enginekontext; sys.dm_io_virtual_file_stats: nativer Dateicache; SOURCE_CONTRACT: Sourcevertragsvalidierung. Alle sechs Werte haben maximal 128 UTF-16-Codeeinheiten. |'
            + NCHAR(10)
            + N'| Issue StatusCode | SELECTION_UNRESOLVED: Auswahl nicht bestätigt; DATABASE_CONTEXT_CHANGED: Datenbankkontext änderte sich; DENIED_PERMISSION: Zugriff verweigert; UNAVAILABLE_OBJECT: Objekt fehlt; ERROR_HANDLED: abgefangener Fehler; FILE_METADATA_UNAVAILABLE: zwei stabile Katalogbindungen fehlen; FILE_TYPE_CHANGED: Dateityp änderte sich; FILE_STATE_CHANGED: Dateistatus änderte sich; UNSUPPORTED_FILE_TYPE: außerhalb ROWS-/LOG-Scope; FILE_NOT_ONLINE: nicht ONLINE; IDENTITY_FIELD_UNKNOWN: Identitätsfeld fehlt; IDENTITY_OBSERVATION_CHANGED: Identitätsbeobachtung änderte sich; NATIVE_FILE_UNAVAILABLE: Online-ROWS-/LOG-Datei fehlt im nativen Cache. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'Fachliche Bindungen und Fehlerbehandlung'
            + NCHAR(10)
            + N'Der Helper verlangt SC-023-Version 1.3.1 / Schema 3 und den tatsächlich installierten schreibfreien Retentionshandshake. Eigener Lauf ist nur die unbeschriebene FILE_IO-CaptureRun-Zeile mit Status RUNNING. Fehlender, fremder, abgeschlossener oder bereits beschriebener Lauf ergibt INVALID_PARAMETER / 51011 und wird nicht finalisiert. Eine ungültige aktive Policy (53783) nach OwnRun=1 wird zunächst als ERROR_HANDLED behandelt; der getrennte Fehlerabschluss kann scheitern und FINALIZATION_UNCONFIRMED ergeben. Die nichtfatalen Sourcezustände AVAILABLE, EMPTY_UNPROVEN und PARTIAL verlangen Enginekontext und Messfenster; DENIED_PERMISSION, UNAVAILABLE_OBJECT und ERROR_HANDLED sind fatal und verlangen engine=NULL. NOT_STARTED: leeres databases-Array verlangt native Anzahl 0; nichtleeres Array verlangt fatalen Status und Anzahl NULL. SUCCEEDED kann bei fatalem Status die native Anzahl behalten, aber files bleibt leer; bei nichtfatalem Status entspricht FILE-Anzahl der nativen Anzahl. FAILED ve'
            + N'rlangt fatalen Status, Anzahl NULL und kein Readfenster. sourceComplete=true gilt nur bei AVAILABLE oder EMPTY_UNPROVEN; außerdem müssen alle DB-Metadaten AVAILABLE sein, UNBOUND fehlen und Issues auf UNSUPPORTED_FILE_TYPE, FILE_NOT_ONLINE, IDENTITY_OBSERVATION_CHANGED oder IDENTITY_FIELD_UNKNOWN begrenzt sein. Der Selektionshash nutzt SQL-spezifisches FOR JSON; requestedDatabaseNames und requestedDatabaseNamePattern sind unveränderte, opake Provenienzlabels. Framework-ID, -Name und -CreateDate müssen master.sys.databases und CaptureRun.SourceDatabaseName treffen; dies belegt keine authentische DMV-Herkunft. Datenbankanzahl, Identitäten, Dateien und Issues sind gebunden.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Eine identitätsunvollständige, sonst geeignete Datei kann ELIGIBLE sein und sieben numerische Rohwerte mit Partialstatus als Per-Run-Beobachtung erhalten; sie erhält keinen Differenzvergleich. UNBOUND bezeichnet dagegen eine wegen DB-/Metadaten-/Typ-/Statusabweichung nicht ausgewählte Rohzeile und erzeugt keine Raw-Messwerte. Ausgeschlossene Dateien bleiben von geeigneten unterscheidbar. MaxRows der aktiven FILE_IO-Policy ist 1..100000 und begrenzt geschriebene Dateizeilen. Pro ausgewählter Datei: sieben Rohwerte, Status und Dateikontext; bis zu sechs Differenzkandidaten nur bei belegter Vergleichbarkeit. Ein regulär abgeschlossener nichtfataler Lauf speichert zusätzlich genau ein IO_CAPTURE_CONTEXT-Sample auf dem Serverscope, auch bei null ausgewählten Dateien. Die tatsächliche Metrikzahl beträgt damit 9 × geschriebene Dateien + 6 × vergleichbare Dateien + 1: je ausgewählter Datei sieben Rohwerte, ein Status- und ein Dateikontextsample sowie sechs Kandidaten je vergleichbarer Datei. F'
            + N'atale Sourcepfade überspringen diese Metrikpersistierung. Erfolgreiche Vollaufnahme bleibt PARTIAL; weder atomare Katalog-/DMV-Sicht noch Resetkontinuität wird behauptet. Optionales GZIP nur für reguläre valide Sourcezweige.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Nach Catch rollt der Helper zurück. Getrennte Fehlerfinalisierung ohne Payload wird nur bei OwnRun=1, erneut bestätigtem Target und bestätigtem unbeschriebenen Lauf versucht. Nach validierter Source können SourceErrorNumber und SourceErrorMessage trotz Backendfehler NULL bleiben; der tatsächliche Backendfehler steht in ModuleStatus. Gebundene Sourceissues bleiben erhalten. Geschlossene Finalisierung kann ERROR_HANDLED ergeben; offene/fehlgeschlagene kann FINALIZATION_UNCONFIRMED liefern. ErrorMessageOut erhält keinen vom Helper angefügten Vergleichscode; Sourcefehlertext wird nicht gefiltert.'
            + NCHAR(10)
            + N'Kanonische JSON-Zahlen sind Ganzzahlen ohne Dezimalpunkt oder Exponent und ohne führende Nullen außer 0. ID-Werte liegen zwischen 1 und 2147483647, INT-Fehlernummern zwischen -2147483648 und 2147483647, TINY-Werte zwischen 0 und 255. Nichtnegative bigint-Werte reichen von 0 bis 9223372036854775807; Vorzeichen sind dort unzulässig. CreateLsn ist eine JSON-Zeichenfolge mit einem kanonischen nichtnegativen decimal(25,0)-Ganzzahlwert. Native Zeitzeichenfolgen sind genau 23 Zeichen lang und müssen den SQL-datetime-Rundtrip bestehen; UTC-Zeichenfolgen sind gültige datetime2(3)-Werte mit genau 24 Zeichen einschließlich abschließendem Z. Stringgrenzen beziehen sich auf UTF-16-Codeeinheiten. Issue.ScopeType hat maximal 16, Issue.StatusCode und DB.MetadataStatusCode maximal 40; META.resultName, META.statusCode und META.nativeReadState ebenfalls maximal 40.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Identitäts- und Kontextprüfungen prüfen die übergebenen Daten auf Konsistenz; sie authentifizieren die Erfassung nicht nachträglich. Die frühe Targetabfrage gegen master.sys.databases liegt vor TRY und kann einen SQL-Fehler ungefangen weiterreichen. Die Retentionsprobe muss tatsächlich AVAILABLE, Vertrag 3, keine Run-ID, keine Fehlernummer und Budgetsignal 0 zurückgeben. Die aktive FILE_IO-Policy verlangt MaxRows von 1 bis 100000 und einen nicht-NULL PayloadEnabled-Wert. Die Source-Meldung bindet den ersten Issue mit nicht-NULL Fehlernummer, ersatzweise den ersten Issue in Arrayreihenfolge; ohne Issues sind beide META-Fehlerwerte NULL. Metadatennamen und Katalogwerte sind damit auf innere Konsistenz geprüft, nicht auf eine kryptografisch authentische DMV-Herkunft.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein nachfolgender SQL-Fehler kann nach bereits validierter Source deren ursprüngliche Fehlernummer und Meldung als Ausgabe erhalten, einschließlich NULL oder Leertext; der tatsächliche SQL-Fehler wird separat in ModuleStatus festgehalten, soweit die Fehlerfinalisierung gelingt. Schlägt dieser Versuch fehl, kann FINALIZATION_UNCONFIRMED stattdessen die dabei entstandene SQL-Fehlernummer und Meldung ausgeben. Eine offene Finalisierungsgrenze ist kein erfolgreicher Runabschluss.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown]
UNION ALL
SELECT CONVERT(sysname,N'snapshot') AS [SchemaName],CONVERT(sysname,N'InternalCompletePerformanceCounterCycle') AS [ObjectName],CONVERT(varchar(24),'INTERNAL_PROCEDURE') AS [ObjectType],CONVERT(varchar(24),'snapshot_target') AS [DatabaseRole],CONVERT(bit,1) AS [IsInternal],CONVERT(nvarchar(max),N'Persistiert einen transient übergebenen Performance-Counter- JSON-Vertrag als typisierte Samples und optionales Rohpayload.') AS [Description],CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "snapshot.InternalCompletePerformanceCounterCycle"'
            + NCHAR(10)
            + N'schema_name: "snapshot"'
            + NCHAR(10)
            + N'object_name: "InternalCompletePerformanceCounterCycle"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "snapshot_target"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Persistiert einen transient übergebenen Performance-Counter- JSON-Vertrag als typisierte Samples und optionales Rohpayload."'
            + NCHAR(10)
            + N'source_path: "Code/10_SnapshotBaseline/050_InternalCompletePerformanceCounterCycle.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# snapshot.InternalCompletePerformanceCounterCycle'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Persistiert einen transient übergebenen Performance-Counter- JSON-Vertrag als typisierte Samples und optionales Rohpayload.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [snapshot].[InternalCompletePerformanceCounterCycle]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[snapshot].[CaptureRun]`, `[snapshot].[Scope]`, `[snapshot].[MetricDefinition]`, `[snapshot].[MetricSample]`, `[snapshot].[CollectorPolicy]`, `[snapshot].[PayloadSnapshot]`, `monitor.USP_PerformanceCounters`, `[snapshot].[ModuleStatus]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| @CaptureRunId | bigint | ja | kein Default |'
            + NCHAR(10)
            + N'| @CollectorJson | nvarchar(max) | ja | kein Default |'
            + NCHAR(10)
            + N'| @SourceStatusCode | varchar(40) | ja | kein Default |'
            + NCHAR(10)
            + N'| @SourceIsPartial | bit | ja | kein Default |'
            + NCHAR(10)
            + N'| @SourceErrorNumber | int | ja | kein Default |'
            + NCHAR(10)
            + N'| @SourceErrorMessage | nvarchar(2048) | ja | kein Default |'
            + NCHAR(10)
            + N'| @StatusCodeOut | varchar(40) OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @IsPartialOut | bit OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @ErrorNumberOut | int OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @ErrorMessageOut | nvarchar(2048) OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CaptureRunId:** @CaptureRunId bigint Default: Kein Default; Pflichtargument. Ordnet Samples, Payload und Modulstatus einer vorhandenen CaptureRunId zu. Leerer Text ist keine vorgesehene Ganzzahleingabe. Das Objekt erzeugt keine CaptureRun-Zeile und garantiert weder Laufexistenz, CollectorCode noch einen offenen Lauf oder Quellenbezug. NULL oder eine fehlende Zielzeile kann an Constraints scheitern; Wiederholungen können eindeutige Run-/Metrik- oder Run-/Modul-Bindungen verletzen. EndedAtUtc wird nicht gesetzt; ein separater Finalisierer schließt den Lauf.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CollectorJson:** @CollectorJson nvarchar(max) Default: Kein Default; Pflichtargument. Erwartet einen einzelnen JSON-Text, keinen Dateinamen oder Pfad. NULL, leerer Text oder ISJSON(...) <> 1 gilt als ungültig. OPENJSON projiziert aus $.counters genau diese case-sensitiven Felder und SQL-Typen: ObjectName, CounterName und InstanceName als nvarchar(128); CounterType als int; MetricValue als decimal(38,6); MetricUnit als varchar(40); AfterValue als bigint; FindingCode als varchar(80). Native Konvertierungen gelten. Es gibt keine strikte Schema- oder Array-Validierung. Zusätzliche Schlüssel werden für Samples ignoriert, bleiben aber im optionalen Rohpayload erhalten. ObjectName, CounterName, InstanceName und CounterType müssen nach der Projektion nicht-NULL sein, sonst wird die Zeile still herausgefiltert; leere Namen sind zulässig. Fehlende Counter oder Pflichtwerte können ohne Fehler oder Partial-Markierung null Samples ergeben. Gültiges JSON kann die erwartete Form dennoch verfehlen.'
            + N' MetricValue und MetricUnit stammen vom Collector, werden nicht berechnet. AfterValue erzeugt ein RAW-, MetricValue ein INTERPRETED-Sample; beides erzeugt beide. FindingCode NULL oder SQL-leer wird MEASURED, sonst ungeprüft übernommen. $.meta.sqlServerStartTime wird mit TRY_CONVERT als datetime2(3) gelesen; fehlend/ungültig ergibt NULL, ohne UTC-Umrechnung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SourceStatusCode:** @SourceStatusCode varchar(40) Default: Kein Default; Pflichtargument. Gültiges JSON leitet den Wert weiter; NULL wird initial ERROR_HANDLED, leer bleibt leer. Keine Enum-Prüfung oder geschlossene Ausgabemenge. Bei ungültigem JSON bleiben nur DENIED_PERMISSION und UNAVAILABLE_OBJECT erhalten, sonst folgt ERROR_HANDLED.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SourceIsPartial:** @SourceIsPartial bit Default: Kein Default; Pflichtargument. Akzeptiert 0 (als nicht partiell markiert), 1 (als partiell markiert) oder NULL. Leerer Text ist keine vorgesehene Bit-Eingabeform. NULL wird zur Laufzeit initial zu 1, kein SQL-Default. Ungültiges JSON setzt 1. Keine Status-/Partial-Konsistenzprüfung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SourceErrorNumber:** @SourceErrorNumber int Default: Kein Default; Pflichtargument. Akzeptiert NULL oder eine vorzeichenbehaftete int-Diagnosezahl. Leerer Text ist keine vorgesehene Ganzzahleingabe. Löst selbst keinen SQL-Fehler aus und wird initial weitergereicht. Ungültiges JSON ändert ihn nicht; ein abgefangener SQL-Fehler ersetzt ihn durch seine Fehlernummer.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SourceErrorMessage:** @SourceErrorMessage nvarchar(2048) Default: Kein Default; Pflichtargument. Akzeptiert NULL oder Aufrufertext bis nvarchar(2048); SQL-leer bleibt leer. Initiale Weitergabe. Bei ungültigem JSON ersetzt der eingebaute Text nur NULL. Ein abgefangener SQL-Fehler setzt ERROR_MESSAGE().'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT Default: Kein Default; Pflichtargument. Argumenttyp varchar(40); eingehender Variablenwert wird ignoriert und darf uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT kann das Pflichtargument übergeben und der Rückgabewert verworfen werden. Initialwert COALESCE(@SourceStatusCode,''ERROR_HANDLED''). Ungültiges JSON folgt obiger Regel. Abgefangene Fehler 229, 262, 297, 300, 371 setzen DENIED_PERMISSION, andere ERROR_HANDLED. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@IsPartialOut:** @IsPartialOut bit OUTPUT Default: Kein Default; Pflichtargument. Argumenttyp bit; eingehender Wert wird ignoriert und darf uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden. 0 markiert nicht partiell, 1 partiell; eine Vollständigkeitsprüfung erfolgt nicht. Initialwert COALESCE(@SourceIsPartial,1); ungültiges JSON und abgefangene Fehler setzen 1. Keine Konsistenzprüfung. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT Default: Kein Default; Pflichtargument. Argumenttyp int; eingehender Wert ignoriert, darf uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden. Initialwert @SourceErrorNumber; ungültiges JSON ändert ihn nicht, abgefangene Fehler überschreiben ihn. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT Default: Kein Default; Pflichtargument. Argumenttyp nvarchar(2048); eingehender Wert ignoriert, darf uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden. Initialwert @SourceErrorMessage; ungültiges JSON verwendet den eingebauten Text nur bei NULL; abgefangene Fehler überschreiben mit ERROR_MESSAGE(). Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Kein Fach-Resultset. `@StatusCodeOut varchar(40)`, `@IsPartialOut bit`, `@ErrorNumberOut int` und `@ErrorMessageOut nvarchar(2048)` melden Validierung, Speicherung und Fehler der Performance-Counter-Erfassung. Der Helper schreibt eigene Capture-/Metric-/ModuleStatus-Zeilen im Snapshot-Ziel; bei Teilstatus oder nativem Fehler ist keine vollständige Quellenaufnahme belegt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT [SkillMarkdown]'
            + NCHAR(10)
            + N'FROM [monitor_metadata].[VW_ObjectUsageSkills]'
            + NCHAR(10)
            + N'WHERE [SchemaName]=N''snapshot'' AND [ObjectName]=N''InternalCompletePerformanceCounterCycle'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [snapshot].[InternalCompletePerformanceCounterCycle] @CaptureRunId=NULL, @CollectorJson=NULL, @SourceStatusCode=NULL, @SourceIsPartial=NULL, @SourceErrorNumber=NULL, @SourceErrorMessage=NULL, @StatusCodeOut=NULL, @IsPartialOut=NULL, @ErrorNumberOut=NULL, @ErrorMessageOut=NULL, @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Vertrag'
            + NCHAR(10)
            + N'-------'
            + NCHAR(10)
            + N'Alle zehn Parameter sind Pflichtargumente; die Signatur definiert keinen'
            + NCHAR(10)
            + N'SQL-Default. Ausgelassene Argumente verursachen einen Aufruffehler. Auch'
            + NCHAR(10)
            + N'NULL-fähige Argumente müssen angegeben werden.'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Objekt       : snapshot.InternalCompletePerformanceCounterCycle'
            + NCHAR(10)
            + N'Version      : 1.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-21'
            + NCHAR(10)
            + N'Zweck        : Persistiert einen transient übergebenen Performance-Counter-'
            + NCHAR(10)
            + N'               JSON-Vertrag als typisierte Samples und optionales Rohpayload.'
            + NCHAR(10)
            + N'==============================================================================='
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'Vertrag'
            + NCHAR(10)
            + N'-------'
            + NCHAR(10)
            + N'Alle zehn Parameter sind Pflichtargumente; die Signatur definiert keinen'
            + NCHAR(10)
            + N'SQL-Default. Ausgelassene Argumente verursachen einen Aufruffehler. Auch'
            + NCHAR(10)
            + N'NULL-fähige Argumente müssen angegeben werden.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Parameter'
            + NCHAR(10)
            + N'---------'
            + NCHAR(10)
            + N'@CaptureRunId bigint'
            + NCHAR(10)
            + N'Default: Kein Default; Pflichtargument.'
            + NCHAR(10)
            + N'Ordnet Samples, Payload und Modulstatus einer vorhandenen CaptureRunId zu.'
            + NCHAR(10)
            + N'Leerer Text ist keine vorgesehene Ganzzahleingabe.'
            + NCHAR(10)
            + N'Das Objekt erzeugt keine CaptureRun-Zeile und garantiert weder Laufexistenz,'
            + NCHAR(10)
            + N'CollectorCode noch einen offenen Lauf oder Quellenbezug. NULL oder eine'
            + NCHAR(10)
            + N'fehlende Zielzeile kann an Constraints scheitern; Wiederholungen können'
            + NCHAR(10)
            + N'eindeutige Run-/Metrik- oder Run-/Modul-Bindungen verletzen. EndedAtUtc wird'
            + NCHAR(10)
            + N'nicht gesetzt; ein separater Finalisierer schließt den Lauf.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@CollectorJson nvarchar(max)'
            + NCHAR(10)
            + N'Default: Kein Default; Pflichtargument.'
            + NCHAR(10)
            + N'Erwartet einen einzelnen JSON-Text, keinen Dateinamen oder Pfad. NULL, leerer'
            + NCHAR(10)
            + N'Text oder ISJSON(...) <> 1 gilt als ungültig. OPENJSON projiziert aus'
            + NCHAR(10)
            + N'$.counters genau diese case-sensitiven Felder und SQL-Typen: ObjectName,'
            + NCHAR(10)
            + N'CounterName und InstanceName als nvarchar(128); CounterType als int;'
            + NCHAR(10)
            + N'MetricValue als decimal(38,6); MetricUnit als varchar(40); AfterValue als'
            + NCHAR(10)
            + N'bigint; FindingCode als varchar(80). Native Konvertierungen gelten. Es gibt'
            + NCHAR(10)
            + N'keine strikte Schema- oder Array-Validierung. Zusätzliche Schlüssel werden'
            + NCHAR(10)
            + N'für Samples ignoriert, bleiben aber im optionalen Rohpayload erhalten.'
            + NCHAR(10)
            + N'ObjectName, CounterName, InstanceName und CounterType müssen nach der'
            + NCHAR(10)
            + N'Projektion nicht-NULL sein, sonst wird die Zeile still herausgefiltert;'
            + NCHAR(10)
            + N'leere Namen sind zulässig. Fehlende Counter oder Pflichtwerte können ohne'
            + NCHAR(10)
            + N'Fehler oder Partial-Markierung null Samples ergeben. Gültiges JSON kann die'
            + NCHAR(10)
            + N'erwartete Form dennoch verfehlen. MetricValue und MetricUnit stammen vom'
            + NCHAR(10)
            + N'Collector, werden nicht berechnet. AfterValue erzeugt ein RAW-, MetricValue'
            + NCHAR(10)
            + N'ein INTERPRETED-Sample; beides erzeugt beide. FindingCode NULL oder SQL-leer'
            + NCHAR(10)
            + N'wird MEASURED, sonst ungeprüft übernommen. $.meta.sqlServerStartTime wird'
            + NCHAR(10)
            + N'mit TRY_CONVERT als datetime2(3) gelesen; fehlend/ungültig ergibt NULL, ohne'
            + NCHAR(10)
            + N'UTC-Umrechnung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@SourceStatusCode varchar(40)'
            + NCHAR(10)
            + N'Default: Kein Default; Pflichtargument.'
            + NCHAR(10)
            + N'Gültiges JSON leitet den Wert weiter; NULL wird initial ERROR_HANDLED, leer'
            + NCHAR(10)
            + N'bleibt leer. Keine Enum-Prüfung oder geschlossene Ausgabemenge. Bei'
            + NCHAR(10)
            + N'ungültigem JSON bleiben nur DENIED_PERMISSION und UNAVAILABLE_OBJECT'
            + NCHAR(10)
            + N'erhalten, sonst folgt ERROR_HANDLED.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@SourceIsPartial bit'
            + NCHAR(10)
            + N'Default: Kein Default; Pflichtargument.'
            + NCHAR(10)
            + N'Akzeptiert 0 (als nicht partiell markiert), 1 (als partiell markiert) oder NULL.'
            + NCHAR(10)
            + N'Leerer Text ist keine vorgesehene Bit-Eingabeform. NULL wird zur Laufzeit initial zu 1, kein SQL-Default.'
            + NCHAR(10)
            + N'Ungültiges JSON setzt 1. Keine Status-/Partial-Konsistenzprüfung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@SourceErrorNumber int'
            + NCHAR(10)
            + N'Default: Kein Default; Pflichtargument.'
            + NCHAR(10)
            + N'Akzeptiert NULL oder eine vorzeichenbehaftete int-Diagnosezahl.'
            + NCHAR(10)
            + N'Leerer Text ist keine vorgesehene Ganzzahleingabe. Löst selbst'
            + NCHAR(10)
            + N'keinen SQL-Fehler aus und wird initial weitergereicht. Ungültiges JSON ändert'
            + NCHAR(10)
            + N'ihn nicht; ein abgefangener SQL-Fehler ersetzt ihn durch seine Fehlernummer.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@SourceErrorMessage nvarchar(2048)'
            + NCHAR(10)
            + N'Default: Kein Default; Pflichtargument.'
            + NCHAR(10)
            + N'Akzeptiert NULL oder Aufrufertext bis nvarchar(2048); SQL-leer bleibt leer. Initiale Weitergabe.'
            + NCHAR(10)
            + N'Bei ungültigem JSON ersetzt der eingebaute Text nur NULL. Ein abgefangener'
            + NCHAR(10)
            + N'SQL-Fehler setzt ERROR_MESSAGE().'
            + NCHAR(10)
            + NCHAR(10)
            + N'@StatusCodeOut varchar(40) OUTPUT'
            + NCHAR(10)
            + N'Default: Kein Default; Pflichtargument.'
            + NCHAR(10)
            + N'Argumenttyp varchar(40); eingehender Variablenwert wird ignoriert und darf'
            + NCHAR(10)
            + N'uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT kann das'
            + NCHAR(10)
            + N'Pflichtargument übergeben und der Rückgabewert verworfen werden. Initialwert'
            + NCHAR(10)
            + N'COALESCE(@SourceStatusCode,''ERROR_HANDLED''). Ungültiges JSON folgt obiger'
            + NCHAR(10)
            + N'Regel. Abgefangene Fehler 229, 262, 297, 300, 371 setzen DENIED_PERMISSION,'
            + NCHAR(10)
            + N'andere ERROR_HANDLED. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@IsPartialOut bit OUTPUT'
            + NCHAR(10)
            + N'Default: Kein Default; Pflichtargument.'
            + NCHAR(10)
            + N'Argumenttyp bit; eingehender Wert wird ignoriert und darf uninitialisiert sein.'
            + NCHAR(10)
            + N'OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden.'
            + NCHAR(10)
            + N'0 markiert nicht partiell, 1 partiell; eine Vollständigkeitsprüfung erfolgt nicht.'
            + NCHAR(10)
            + N'Initialwert COALESCE(@SourceIsPartial,1); ungültiges JSON und abgefangene'
            + NCHAR(10)
            + N'Fehler setzen 1. Keine Konsistenzprüfung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@ErrorNumberOut int OUTPUT'
            + NCHAR(10)
            + N'Default: Kein Default; Pflichtargument.'
            + NCHAR(10)
            + N'Argumenttyp int; eingehender Wert ignoriert, darf uninitialisiert sein.'
            + NCHAR(10)
            + N'OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden.'
            + NCHAR(10)
            + N'Initialwert @SourceErrorNumber; ungültiges JSON ändert ihn nicht, abgefangene'
            + NCHAR(10)
            + N'Fehler überschreiben ihn. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@ErrorMessageOut nvarchar(2048) OUTPUT'
            + NCHAR(10)
            + N'Default: Kein Default; Pflichtargument.'
            + NCHAR(10)
            + N'Argumenttyp nvarchar(2048); eingehender Wert ignoriert, darf uninitialisiert'
            + NCHAR(10)
            + N'sein. OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen'
            + NCHAR(10)
            + N'werden. Initialwert @SourceErrorMessage; ungültiges JSON verwendet den'
            + NCHAR(10)
            + N'eingebauten Text nur bei NULL; abgefangene Fehler überschreiben mit'
            + NCHAR(10)
            + N'ERROR_MESSAGE(). Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Seiteneffekte und Fehlergrenzen'
            + NCHAR(10)
            + N'-------------------------------'
            + NCHAR(10)
            + N'Vor TRY initialisiert das Objekt OUTPUT-Werte und erstellt bei'
            + NCHAR(10)
            + N'LOCK_TIMEOUT 0 eine lokale Temp-Tabelle; deren Anlagefehler kann entweichen.'
            + NCHAR(10)
            + N'Im TRY-Pfad werden SERVER-/Counter-Scope-Zeilen wiederverwendet oder ergänzt,'
            + NCHAR(10)
            + N'feste RAW-/INTERPRETED-MetricDefinitionen nachgeschlagen und MetricSamples'
            + NCHAR(10)
            + N'geschrieben. Bei PERFORMANCE_COUNTERS PayloadEnabled wird das Original-JSON'
            + NCHAR(10)
            + N'ohne Kanonisierung samt Hash als GZIP-Payload gespeichert. LEN zählt Zeichen'
            + NCHAR(10)
            + N'und nicht alle Speicherbytes. CaptureRun.SqlServerStartTimeUtc wird auf die geparste Serverstartzeit'
            + NCHAR(10)
            + N'gesetzt und CaptureRun.ResetEpochId wird aktualisiert. Die Epoch stammt aus der höchsten'
            + NCHAR(10)
            + N'CaptureRunId mit gleicher Startzeit und nicht-NULL Epoch, sonst aus NEWID();'
            + NCHAR(10)
            + N'das belegt keine Quellserveridentität. ModuleStatus wird geschrieben. Es gibt'
            + NCHAR(10)
            + N'keine eigene Transaktion, Atomaritäts- oder Rollback-Zusage. Der CATCH setzt'
            + NCHAR(10)
            + N'Status/Partial/Fehlerwerte nach nativem Fehler und versucht ModuleStatus'
            + NCHAR(10)
            + N'erneut einzufügen; auch dieser INSERT kann scheitern. Fehler werden nicht'
            + NCHAR(10)
            + N'allgemein kontrolliert in Statuswerte umgewandelt. Quellmessung und'
            + NCHAR(10)
            + N'Ratenberechnung finden nicht statt. CollectorPolicy.MaxRows wird nicht'
            + NCHAR(10)
            + N'durchgesetzt und muss vom Produzenten eingehalten werden. EndedAtUtc setzt'
            + NCHAR(10)
            + N'ein separater Finalisierer.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown]
UNION ALL
SELECT CONVERT(sysname,N'snapshot') AS [SchemaName],CONVERT(sysname,N'InternalCompleteWaitStatsCycle') AS [ObjectName],CONVERT(varchar(24),'INTERNAL_PROCEDURE') AS [ObjectType],CONVERT(varchar(24),'snapshot_target') AS [DatabaseRole],CONVERT(bit,1) AS [IsInternal],CONVERT(nvarchar(max),N'Die Procedure validiert einen vollständigen internen Source-v1- Vertrag für sys.dm_os_wait_stats und finalisiert den gebundenen eigenen Wait-Run mit Rohwerten und Vergleichskandidaten.') AS [Description],CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "snapshot.InternalCompleteWaitStatsCycle"'
            + NCHAR(10)
            + N'schema_name: "snapshot"'
            + NCHAR(10)
            + N'object_name: "InternalCompleteWaitStatsCycle"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "snapshot_target"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Die Procedure validiert einen vollständigen internen Source-v1- Vertrag für sys.dm_os_wait_stats und finalisiert den gebundenen eigenen Wait-Run mit Rohwerten und Vergleichskandidaten."'
            + NCHAR(10)
            + N'source_path: "Code/10_SnapshotBaseline/055_InternalCompleteWaitStatsCycle.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# snapshot.InternalCompleteWaitStatsCycle'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure validiert einen vollständigen internen Source-v1- Vertrag für sys.dm_os_wait_stats und finalisiert den gebundenen eigenen Wait-Run mit Rohwerten und Vergleichskandidaten.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [snapshot].[InternalCompleteWaitStatsCycle]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `sys.dm_os_wait_stats`, `master.sys.databases`, `[master].[sys].[databases]`, `[snapshot].[PackageVersion]`, `[snapshot].[InternalPurgeExpiredData]`, `[snapshot].[CaptureRun]`, `[snapshot].[MetricSample]`, `[snapshot].[PayloadSnapshot]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| @CaptureRunId | bigint | ja | kein Default |'
            + NCHAR(10)
            + N'| @CollectorJson | nvarchar(max) | ja | kein Default |'
            + NCHAR(10)
            + N'| @ExpectedTargetDatabaseId | int | ja | kein Default |'
            + NCHAR(10)
            + N'| @ExpectedTargetDatabaseName | sysname | ja | kein Default |'
            + NCHAR(10)
            + N'| @ExpectedTargetCreateDate | datetime | ja | kein Default |'
            + NCHAR(10)
            + N'| @StatusCodeOut | varchar(40) OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @IsPartialOut | bit OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @ErrorNumberOut | int OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @ErrorMessageOut | nvarchar(2048) OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CaptureRunId:** - @CaptureRunId (bigint; Default: Kein Default): Erforderlich ist eine Run-ID größer als 0. NULL oder ein Wert kleiner gleich 0 sowie eine Callertransaktion oder IMPLICIT_TRANSACTIONS ON ergeben vor dem Fachzugriff INVALID_PARAMETER und RETURN 51011. Leertext ist keine unterstützte bigint-Eingabe.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CollectorJson:** - @CollectorJson (nvarchar(max); Default: Kein Default): Erforderlich ist der Source-v1-Vertrag als JSON-Text inline im Parameter. Ein Dateipfad ist kein Vertrag. NULL, Leertext oder fehlerhaftes JSON scheitern bei der Sourcevalidierung mit 53763. Die JSON-Prüfung erfolgt erst nach bestätigter Übernahme des eigenen Runs; ihr Fehler setzt ERROR_HANDLED / 53763 und löst einen Versuch der Fehlerfinalisierung aus. Eine vorher gescheiterte Runbindung kann stattdessen INVALID_PARAMETER / RETURN 51011 ergeben.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ExpectedTargetDatabaseId:** - @ExpectedTargetDatabaseId (int; Default: Kein Default): Erforderlich ist die ID der aktuellen Zieldatenbank und ein Wert größer als 4. NULL, eine andere aktuelle Datenbank oder eine abweichende ID ergeben TARGET_UNAVAILABLE und 53764. Leertext ist keine unterstützte int-Eingabe.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ExpectedTargetDatabaseName:** - @ExpectedTargetDatabaseName (sysname; Default: Kein Default): Erforderlich ist der rohe Datenbankname, der binär mit master.sys.databases.name übereinstimmt; es erfolgt kein Trimmen und kein Schreibweisenausgleich. NULL oder ein leerer beziehungsweise abweichender Name ergeben TARGET_UNAVAILABLE und 53764.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ExpectedTargetCreateDate:** - @ExpectedTargetCreateDate (datetime; Default: Kein Default): Erforderlich ist der Erstellungszeitpunkt aus master.sys.databases.create_date für dieselbe aktuelle Zieldatenbank. NULL oder eine Abweichung ergeben TARGET_UNAVAILABLE und 53764. Leertext ist keine unterstützte Datumsform.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCodeOut:** - @StatusCodeOut (varchar(40) OUTPUT; Default: Kein Default): Erforderlicher Ausgabeparameter. Der gebundene Eingabewert einschließlich NULL oder Leertext wird ignoriert; die Procedure initialisiert AVAILABLE. Ohne Variablenbindung mit OUTPUT wird der Ausgabewert verworfen. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@IsPartialOut:** - @IsPartialOut (bit OUTPUT; Default: Kein Default): Erforderlicher Ausgabeparameter. Der gebundene Eingabewert einschließlich NULL wird ignoriert; die Procedure initialisiert 0 als anfänglichen Nicht-Partialwert. Jeder fachliche Abschlussstatus meldet 1 als partiell oder nicht vollständig bestätigt. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorNumberOut:** - @ErrorNumberOut (int OUTPUT; Default: Kein Default): Erforderlicher Ausgabeparameter. Der gebundene Eingabewert einschließlich NULL wird ignoriert; die Procedure initialisiert NULL und kann bei Guards oder behandelten Fehlern eine Fehlernummer setzen; ein gültiger Source-Fehlervertrag darf NULL weiterreichen. Beim erfolgreichen gespeicherten PARTIAL-Ergebnis bleibt der Wert NULL. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessageOut:** - @ErrorMessageOut (nvarchar(2048) OUTPUT; Default: Kein Default): Erforderlicher Ausgabeparameter. Der gebundene Eingabewert einschließlich NULL oder Leertext wird ignoriert; die Procedure initialisiert NULL und kann Fehlertext, eine Guard-Meldung oder beim gespeicherten PARTIAL-Ergebnis eine Vergleichsentscheidung ausgeben. Je nach Pfad kann der Wert NULL oder leer bleiben. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Kein Fach-Resultset. `@StatusCodeOut varchar(40)`, `@IsPartialOut bit`, `@ErrorNumberOut int` und `@ErrorMessageOut nvarchar(2048)` geben die Ziel-/Quellvalidierung und Speicherung zurück. Ein PARTIAL-Ausgang enthält einen begrenzten Vergleichsgrund in `@ErrorMessageOut`; der Helper schreibt nur zum gebundenen CaptureRun im Snapshot-Ziel und beweist weder vollständige Wait-Aufnahme noch spätere Retention.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT [SkillMarkdown]'
            + NCHAR(10)
            + N'FROM [monitor_metadata].[VW_ObjectUsageSkills]'
            + NCHAR(10)
            + N'WHERE [SchemaName]=N''snapshot'' AND [ObjectName]=N''InternalCompleteWaitStatsCycle'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [snapshot].[InternalCompleteWaitStatsCycle] @CaptureRunId=NULL, @CollectorJson=NULL, @ExpectedTargetDatabaseId=NULL, @ExpectedTargetDatabaseName=NULL, @ExpectedTargetCreateDate=NULL, @StatusCodeOut=NULL, @IsPartialOut=NULL, @ErrorNumberOut=NULL, @ErrorMessageOut=NULL, @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'- @CaptureRunId (bigint; Default: Kein Default): Erforderlich ist eine Run-ID größer als 0. NULL oder ein Wert kleiner gleich 0 sowie eine Callertransaktion oder IMPLICIT_TRANSACTIONS ON ergeben vor dem Fachzugriff INVALID_PARAMETER und RETURN 51011. Leertext ist keine unterstützte bigint-Eingabe.'
            + NCHAR(10)
            + N'- @CollectorJson (nvarchar(max); Default: Kein Default): Erforderlich ist der Source-v1-Vertrag als JSON-Text inline im Parameter. Ein Dateipfad ist kein Vertrag. NULL, Leertext oder fehlerhaftes JSON scheitern bei der Sourcevalidierung mit 53763. Die JSON-Prüfung erfolgt erst nach bestätigter Übernahme des eigenen Runs; ihr Fehler setzt ERROR_HANDLED / 53763 und löst einen Versuch der Fehlerfinalisierung aus. Eine vorher gescheiterte Runbindung kann stattdessen INVALID_PARAMETER / RETURN 51011 ergeben.'
            + NCHAR(10)
            + N'- @ExpectedTargetDatabaseId (int; Default: Kein Default): Erforderlich ist die ID der aktuellen Zieldatenbank und ein Wert größer als 4. NULL, eine andere aktuelle Datenbank oder eine abweichende ID ergeben TARGET_UNAVAILABLE und 53764. Leertext ist keine unterstützte int-Eingabe.'
            + NCHAR(10)
            + N'- @ExpectedTargetDatabaseName (sysname; Default: Kein Default): Erforderlich ist der rohe Datenbankname, der b'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Objekt       : snapshot.InternalCompleteWaitStatsCycle'
            + NCHAR(10)
            + N'Version      : 1.0.1'
            + NCHAR(10)
            + N'Stand        : 2026-10-26'
            + NCHAR(10)
            + N'Zweck        : Die Procedure validiert einen vollständigen internen Source-v1-'
            + NCHAR(10)
            + N'               Vertrag für sys.dm_os_wait_stats und finalisiert den gebundenen'
            + NCHAR(10)
            + N'               eigenen Wait-Run mit Rohwerten und Vergleichskandidaten.'
            + NCHAR(10)
            + N'Grenze       : Monotonie beweist keine ununterbrochene Resetkontinuität.'
            + NCHAR(10)
            + N'==============================================================================='
            + NCHAR(10)
            + NCHAR(10)
            + N'#### InternalCompleteWaitStatsCycle – Parameterverträge'
            + NCHAR(10)
            + NCHAR(10)
            + N'Alle neun Parameter sind erforderlich; keiner besitzt einen Default. Der Aufruf kann Argumente positionsgebunden in Signaturreihenfolge oder mit Parameternamen übergeben. Auch die vier OUTPUT-Argumente sind erforderlich. Eingehende OUTPUT-Werte werden ignoriert. Ein OUTPUT-Wert wird nur in eine Variable übernommen, wenn der Aufruf eine typkompatible Variable mit OUTPUT bindet; ohne OUTPUT-Kennzeichnung wird die Ausgabe verworfen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'- @CaptureRunId (bigint; Default: Kein Default): Erforderlich ist eine Run-ID größer als 0. NULL oder ein Wert kleiner gleich 0 sowie eine Callertransaktion oder IMPLICIT_TRANSACTIONS ON ergeben vor dem Fachzugriff INVALID_PARAMETER und RETURN 51011. Leertext ist keine unterstützte bigint-Eingabe.'
            + NCHAR(10)
            + N'- @CollectorJson (nvarchar(max); Default: Kein Default): Erforderlich ist der Source-v1-Vertrag als JSON-Text inline im Parameter. Ein Dateipfad ist kein Vertrag. NULL, Leertext oder fehlerhaftes JSON scheitern bei der Sourcevalidierung mit 53763. Die JSON-Prüfung erfolgt erst nach bestätigter Übernahme des eigenen Runs; ihr Fehler setzt ERROR_HANDLED / 53763 und löst einen Versuch der Fehlerfinalisierung aus. Eine vorher gescheiterte Runbindung kann stattdessen INVALID_PARAMETER / RETURN 51011 ergeben.'
            + NCHAR(10)
            + N'- @ExpectedTargetDatabaseId (int; Default: Kein Default): Erforderlich ist die ID der aktuellen Zieldatenbank und ein Wert größer als 4. NULL, eine andere aktuelle Datenbank oder eine abweichende ID ergeben TARGET_UNAVAILABLE und 53764. Leertext ist keine unterstützte int-Eingabe.'
            + NCHAR(10)
            + N'- @ExpectedTargetDatabaseName (sysname; Default: Kein Default): Erforderlich ist der rohe Datenbankname, der binär mit master.sys.databases.name übereinstimmt; es erfolgt kein Trimmen und kein Schreibweisenausgleich. NULL oder ein leerer beziehungsweise abweichender Name ergeben TARGET_UNAVAILABLE und 53764.'
            + NCHAR(10)
            + N'- @ExpectedTargetCreateDate (datetime; Default: Kein Default): Erforderlich ist der Erstellungszeitpunkt aus master.sys.databases.create_date für dieselbe aktuelle Zieldatenbank. NULL oder eine Abweichung ergeben TARGET_UNAVAILABLE und 53764. Leertext ist keine unterstützte Datumsform.'
            + NCHAR(10)
            + N'- @StatusCodeOut (varchar(40) OUTPUT; Default: Kein Default): Erforderlicher Ausgabeparameter. Der gebundene Eingabewert einschließlich NULL oder Leertext wird ignoriert; die Procedure initialisiert AVAILABLE. Ohne Variablenbindung mit OUTPUT wird der Ausgabewert verworfen.'
            + NCHAR(10)
            + N'- @IsPartialOut (bit OUTPUT; Default: Kein Default): Erforderlicher Ausgabeparameter. Der gebundene Eingabewert einschließlich NULL wird ignoriert; die Procedure initialisiert 0 als anfänglichen Nicht-Partialwert. Jeder fachliche Abschlussstatus meldet 1 als partiell oder nicht vollständig bestätigt.'
            + NCHAR(10)
            + N'- @ErrorNumberOut (int OUTPUT; Default: Kein Default): Erforderlicher Ausgabeparameter. Der gebundene Eingabewert einschließlich NULL wird ignoriert; die Procedure initialisiert NULL und kann bei Guards oder behandelten Fehlern eine Fehlernummer setzen; ein gültiger Source-Fehlervertrag darf NULL weiterreichen. Beim erfolgreichen gespeicherten PARTIAL-Ergebnis bleibt der Wert NULL.'
            + NCHAR(10)
            + N'- @ErrorMessageOut (nvarchar(2048) OUTPUT; Default: Kein Default): Erforderlicher Ausgabeparameter. Der gebundene Eingabewert einschließlich NULL oder Leertext wird ignoriert; die Procedure initialisiert NULL und kann Fehlertext, eine Guard-Meldung oder beim gespeicherten PARTIAL-Ergebnis eine Vergleichsentscheidung ausgeben. Je nach Pfad kann der Wert NULL oder leer bleiben.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die normalen SQL-Typkonvertierungen gelten vor dem Eintritt in die Prozedur. Ohne Rückgabe darf jedes obligatorische OUTPUT-Argument als typkompatibler Skalar oder NULL gebunden werden; für numerische Typen ist Leertext keine unterstützte Eingabeform. Die Initialisierung ersetzt erst den erfolgreich gebundenen Eingangswert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'#### InternalCompleteWaitStatsCycle – Source-v1-JSON-Vertrag'
            + NCHAR(10)
            + NCHAR(10)
            + N'@CollectorJson muss ein JSON-Objekt mit genau den Eigenschaften meta (Objekt) und waits (Array) enthalten. Zusätzliche oder doppelte Eigenschaften werden abgewiesen. Eigenschaftsnamen werden binär verglichen und sind groß-/kleinschreibungsabhängig. Alle genannten Eigenschaften müssen vorhanden sein, auch wenn ihr Wert JSON null ist.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Das meta-Objekt enthält genau diese elf Eigenschaften:'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Eigenschaft | JSON-Typ und Inhalt |'
            + NCHAR(10)
            + N'|---|---|'
            + NCHAR(10)
            + N'| schemaVersion | JSON-Zahl exakt 1. |'
            + NCHAR(10)
            + N'| resultName | Zeichenfolge exakt SnapshotWaitStats. |'
            + NCHAR(10)
            + N'| measurementStartUtc | NULL oder exakt 24 Zeichen im Format YYYY-MM-DDTHH:mm:ss.fffZ. |'
            + NCHAR(10)
            + N'| measurementEndUtc | NULL oder exakt 24 Zeichen im Format YYYY-MM-DDTHH:mm:ss.fffZ. |'
            + NCHAR(10)
            + N'| statusCode | Eine der fünf unten definierten Source-Statuszeichenfolgen. |'
            + NCHAR(10)
            + N'| isPartial | JSON-Boolean true oder false. |'
            + NCHAR(10)
            + N'| errorNumber | NULL oder JSON-Ganzzahl von 1 bis 2147483647 in kanonischer Dezimalschreibweise. |'
            + NCHAR(10)
            + N'| errorMessage | NULL oder Unicode-Zeichenfolge mit höchstens 2048 UTF-16-Codeeinheiten. |'
            + NCHAR(10)
            + N'| nativeRows | NULL oder kanonische nichtnegative bigint-Dezimalzeichenfolge von 0 bis 9223372036854775807. |'
            + NCHAR(10)
            + N'| sourceComplete | JSON-Boolean true oder false. |'
            + NCHAR(10)
            + N'| engineContext | NULL oder das unten definierte Engineobjekt. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein nicht-NULL-Zeitfenster muss beide Zeitpunkte enthalten und geordnet sein. Ein vollständiger Sourcevertrag erfordert beide Zeitpunkte; der Start liegt frühestens beim Runstart und das Ende nicht nach der aktuellen UTC-Zeit.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein nicht-NULL-engineContext-Objekt enthält genau drei Eigenschaften, jeweils als JSON-Zeichenfolge: serverName mit 1 bis 128 UTF-16-Codeeinheiten; sqlServerStartTimeLocal mit exakt 23 Zeichen im lokalen DATETIME-Rundtripformat YYYY-MM-DDTHH:mm:ss.fff ohne Z; und sqlServerStartTimeMsTicks als kanonische nichtnegative bigint-Dezimalzeichenfolge von 0 bis 9223372036854775807. Für einen vollständigen Sourcevertrag ist das Engineobjekt erforderlich. Ein Fehlervertrag darf ein gültiges Engineobjekt enthalten; NULL ist dort nicht vorgeschrieben.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Jedes Element von waits muss ein Objekt mit genau fünf Eigenschaften sein: WaitType als Zeichenfolge mit 1 bis 60 UTF-16-Codeeinheiten sowie WaitingTasksCount, WaitTimeMs, MaxWaitTimeMs und SignalWaitTimeMs als JSON-Ganzzahlen von 0 bis 9223372036854775807. Die vier Zahlen müssen kanonische Dezimalinteger ohne Vorzeichen, führende Nullen, Dezimalpunkt oder Exponent sein. WaitType-Identitäten dürfen nicht doppelt vorkommen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Source-Statuswerte und ihre Bedeutung:'
            + NCHAR(10)
            + N'- AVAILABLE bezeichnet eine vollständige, nichtleere Aufnahme mit isPartial=false.'
            + NCHAR(10)
            + N'- EMPTY_UNPROVEN bezeichnet eine vollständige, leere Aufnahme, deren Leere nicht als Beweis für eine fachlich vollständige Baseline gilt; isPartial=true.'
            + NCHAR(10)
            + N'- DENIED_PERMISSION bezeichnet einen behandelten nativen Berechtigungsfehler.'
            + NCHAR(10)
            + N'- UNAVAILABLE_OBJECT bezeichnet ein nicht verfügbares natives Objekt.'
            + NCHAR(10)
            + N'- ERROR_HANDLED bezeichnet einen sonstigen behandelten Fehler bei der nativen Erfassung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Bei sourceComplete=true sind nur AVAILABLE und EMPTY_UNPROVEN zulässig. errorNumber und errorMessage müssen NULL sein; engineContext und beide geordneten Messzeitpunkte müssen vorhanden sein; nativeRows muss der tatsächlichen Zahl der Waitzeilen entsprechen. AVAILABLE verlangt mindestens eine Zeile und isPartial=false. EMPTY_UNPROVEN verlangt null Zeilen und isPartial=true. Bei sourceComplete=false sind nur DENIED_PERMISSION, UNAVAILABLE_OBJECT und ERROR_HANDLED zulässig; isPartial muss true, waits muss leer und nativeRows NULL sein. Das Fehlerobjekt muss nicht engineContext=NULL setzen; falls es vorhanden ist, muss es den vollständigen Enginevertrag erfüllen. Messzeitpunkte dürfen im Fehlerzweig gemeinsam NULL oder gemeinsam vorhanden und geordnet sein.'
            + NCHAR(10)
            + NCHAR(10)
            + N'#### InternalCompleteWaitStatsCycle – Vergleichsgründe in @ErrorMessageOut'
            + NCHAR(10)
            + NCHAR(10)
            + N'Bei einem erfolgreich gespeicherten PARTIAL-Ergebnis enthält @ErrorMessageOut genau einen der folgenden zwölf geschlossenen Vergleichsgründe. Die Auswahl folgt der Reihenfolge der ersten zutreffenden Prüfung in der Liste; die Codes sind keine Werte von @StatusCodeOut.'
            + NCHAR(10)
            + N'- SOURCE_EMPTY_UNPROVEN: Die vollständige Sourceaufnahme enthält keine Waitzeilen.'
            + NCHAR(10)
            + N'- WRITE_LIMITED: MaxRows ließ nicht alle zur Speicherung berücksichtigungsfähigen WaitTypes zur Speicherung zu.'
            + NCHAR(10)
            + N'- FIRST_OBSERVATION: Es gibt keinen früheren finalisierten Wait-Run.'
            + NCHAR(10)
            + N'- PREVIOUS_CAPTURE_PARTIAL: Der frühere Lauf war technisch partiell oder enthielt einen Fehler.'
            + NCHAR(10)
            + N'- PREVIOUS_CONTEXT_INVALID: Der frühere Vergleichskontext besteht seine Vertragsprüfung nicht.'
            + NCHAR(10)
            + N'- PREVIOUS_RAW_INCOMPLETE: Der frühere Lauf enthält nicht alle erforderlichen Rohmetriken.'
            + NCHAR(10)
            + N'- ENGINE_CONTEXT_CHANGED: Der native Enginekontext unterscheidet sich vom vorherigen.'
            + NCHAR(10)
            + N'- INTERVAL_NOT_POSITIVE: Das Fenster überlappt oder läuft rückwärts; insbesondere liegt der aktuelle Start vor dem vorherigen Ende oder das aktuelle Ende ist nicht später als das vorherige Ende.'
            + NCHAR(10)
            + N'- WAIT_TYPE_MISSING: Ein erforderlicher vorheriger WaitType fehlt in der aktuellen Aufnahme.'
            + NCHAR(10)
            + N'- COUNTER_DECREASE: Mindestens ein verglichener Counter ist gegenüber dem Vorwert gesunken.'
            + NCHAR(10)
            + N'- NO_COMPARABLE_TYPES: Es gibt keinen ausgewählten aktuellen WaitType mit passendem Vorwert.'
            + NCHAR(10)
            + N'- MONOTONIC_CONTINUITY_UNPROVEN: Vergleichbare Werte sind monoton, aber daraus folgt keine lückenlose Resetkontinuität.'
            + NCHAR(10)
            + NCHAR(10)
            + N'#### InternalCompleteWaitStatsCycle – Persistenz- und Ausgabevertrag'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Targetprüfung liegt vor TRY und verlangt die aktuelle, online befindliche und schreibbare Datenbank mit ID größer als 4 sowie exakt passendem binärem Namen und create_date; ein Fehler aus dieser Vorprüfung kann ungefangen auftreten. Danach erfordert die Procedure genau eine PackageVersion-Zeile für SC-023 mit Version 1.2.1/SchemaVersion 2 oder 1.3.0 beziehungsweise 1.3.1/SchemaVersion 3. Der read-only Retentionsvertrag muss zum Paketstand 1, 2 oder 3 entsprechen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure übernimmt ausschließlich einen unbeschriebenen eigenen WAIT_STATS-Run im Status RUNNING, ohne Endzeit oder ResetEpochId und ohne MetricSample-, PayloadSnapshot- oder ModuleStatus-Zeile. Die aktive Policy muss enabled sein; MaxRows muss 1 bis 100000 betragen und begrenzt nur die Backend-Schreibmenge. Bei auswählbaren WaitTypes werden vier rohe numerische Waitmetriken und ein Vergleichsstatus je Typ gespeichert; höchstens drei numerische Differenzkandidaten je vergleichbarem Typ sowie ein Serverkontextsample insgesamt ergänzen die Rohwerte. Der Vergleich stützt sich auf verfügbaren Vorzustand und passende Kontextentscheidungen; er beweist keine ununterbrochene Resetkontinuität und vergleicht nicht bedingungslos mit beliebigem vorherigem Zustand. Eine aktivierte Payload-Policy speichert den Sourcevertrag als JSON-Payload mit GZIP-Kompression. Backend-Schreibvorgänge und Runabschluss liegen in einer eigenen Transaktion und werden gemeinsam committet.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die sieben möglichen Werte von @StatusCodeOut sind:'
            + NCHAR(10)
            + N'- AVAILABLE ist ausschließlich der anfängliche OUTPUT-Wert und bestätigt für sich keinen abgeschlossenen Wait-Run.'
            + NCHAR(10)
            + N'- INVALID_PARAMETER bezeichnet die frühen Guards für ungültige Run-ID, Callertransaktion oder implizite Transaktionen sowie eine mit 53763 abgewiesene Runbindung vor Übernahme eines eigenen Runs. Eine Sourcevalidierung mit 53763 nach bestätigtem eigenen Run wird nicht so ausgegeben.'
            + NCHAR(10)
            + N'- TARGET_UNAVAILABLE bezeichnet eine abgewiesene Targetidentität oder einen erkannten nicht passenden Installations-/Retentionsvertrag.'
            + NCHAR(10)
            + N'- DENIED_PERMISSION bezeichnet einen behandelten Berechtigungsfehler.'
            + NCHAR(10)
            + N'- UNAVAILABLE_OBJECT übernimmt den Status eines gültigen Source-Fehlervertrags für ein nicht verfügbares Objekt.'
            + NCHAR(10)
            + N'- ERROR_HANDLED bezeichnet einen sonstigen behandelten Backend-, Vertrags-, Transaktions- oder Finalisierungsfehler; dazu gehört eine ungültige Sourcevalidierung mit 53763 nach Übernahme des eigenen Runs.'
            + NCHAR(10)
            + N'- PARTIAL bezeichnet den erfolgreich gespeicherten vollständigen oder leeren Sourceabschluss. @IsPartialOut ist dabei 1; @ErrorNumberOut ist NULL und @ErrorMessageOut enthält die Vergleichsentscheidung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Fehlerhafte Sourceverträge nach Übernahme des eigenen Runs erhalten keine Rohsamples, kein Kontextsample und keine erfundene Epoche. Ein gültiger Source-Fehlervertrag wird ohne numerische Roh- oder Kontextsamples und ohne Epoche abgeschlossen; nur dieser reguläre Fehlerpfad speichert bei aktivierter Payload-Policy auch den übergebenen Sourcevertrag als GZIP-Payload. Bei einem SQL- oder Validierungsfehler rollt der CATCH eine aktive Schreibtransaktion zurück. Nur nach Übernahme eines eigenen Runs und bei weiterhin bestätigter Targetidentität versucht er einen getrennten Fehlerabschluss mit ModuleStatus und Run-Update, ohne Payload. Dieser Versuch kann scheitern oder die nötigen Runbedingungen nicht mehr vorfinden; dann ist keine abgeschlossene Finalisierung zugesichert. Der Helper gibt keinen Status FINALIZATION_UNCONFIRMED aus. Der Sourcevertrag allein stellt keinen öffentlichen Wait-Collector bereit; Installations- und Aktivierungsgrenzen beschreibt der Snapshotvertrag.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown]
UNION ALL
SELECT CONVERT(sysname,N'snapshot') AS [SchemaName],CONVERT(sysname,N'InternalConfigureSnapshotPolicy') AS [ObjectName],CONVERT(varchar(24),'INTERNAL_PROCEDURE') AS [ObjectType],CONVERT(varchar(24),'snapshot_target') AS [DatabaseRole],CONVERT(bit,1) AS [IsInternal],CONVERT(nvarchar(max),N'Schreibt und prüft typisierte Collector- und Shared-Policies in der aktuell verbundenen Snapshot-Datenbank.') AS [Description],CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "snapshot.InternalConfigureSnapshotPolicy"'
            + NCHAR(10)
            + N'schema_name: "snapshot"'
            + NCHAR(10)
            + N'object_name: "InternalConfigureSnapshotPolicy"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "snapshot_target"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Schreibt und prüft typisierte Collector- und Shared-Policies in der aktuell verbundenen Snapshot-Datenbank."'
            + NCHAR(10)
            + N'source_path: "Code/10_SnapshotBaseline/020_InternalConfigureSnapshotPolicy.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# snapshot.InternalConfigureSnapshotPolicy'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Schreibt und prüft typisierte Collector- und Shared-Policies in der aktuell verbundenen Snapshot-Datenbank.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [snapshot].[InternalConfigureSnapshotPolicy]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[snapshot].[CollectorPolicy]`, `master.sys.databases`, `[master].[sys].[databases]`, `[snapshot].[PackageVersion]`, `[sys].[procedures]`, `[sys].[schemas]`, `[sys].[parameters]` sowie weitere tatsächlich aufgerufene Quellen. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| @CollectionIntervalSeconds | smallint | ja | kein Default |'
            + NCHAR(10)
            + N'| @MaxRows | int | ja | kein Default |'
            + NCHAR(10)
            + N'| @PayloadEnabled | bit | ja | kein Default |'
            + NCHAR(10)
            + N'| @RawRetentionDays | smallint | ja | kein Default |'
            + NCHAR(10)
            + N'| @PayloadRetentionDays | smallint | ja | kein Default |'
            + NCHAR(10)
            + N'| @RollupRetentionDays | smallint | ja | kein Default |'
            + NCHAR(10)
            + N'| @SoftBudgetMB | int | ja | kein Default |'
            + NCHAR(10)
            + N'| @PurgeIntervalMinutes | smallint | ja | kein Default |'
            + NCHAR(10)
            + N'| @PurgeBatchRows | int | ja | kein Default |'
            + NCHAR(10)
            + N'| @BudgetAction | varchar(32) | ja | kein Default |'
            + NCHAR(10)
            + N'| @StatusCodeOut | varchar(40) OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @ErrorNumberOut | int OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @ErrorMessageOut | nvarchar(2048) OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @CollectorCode | varchar(64) | nein | ''PERFORMANCE_COUNTERS'' |'
            + NCHAR(10)
            + N'| @CollectorEnabled | bit | nein | 1 |'
            + NCHAR(10)
            + N'| @UpdateSharedPolicy | bit | nein | NULL |'
            + NCHAR(10)
            + N'| @ExpectedTargetDatabaseId | int | nein | NULL |'
            + NCHAR(10)
            + N'| @ExpectedTargetDatabaseName | sysname | nein | NULL |'
            + NCHAR(10)
            + N'| @ExpectedTargetCreateDate | datetime | nein | NULL |'
            + NCHAR(10)
            + N'| @JoinFrameworkTransaction | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CollectionIntervalSeconds:** | `@CollectionIntervalSeconds` | smallint | Kein Default; Pflichtargument | Erwartet eine ganze Sekundenzahl von 1 bis 3600. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Im erweiterten Pfad wird NULL ausdrücklich zurückgewiesen. Im Legacy-Pfad gibt es keine ausdrückliche NULL-Prüfung; NULL kann die Bereichsprüfung passieren und erst beim NOT-NULL-Schreiben einen abgefangenen Fehler auslösen. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxRows:** | `@MaxRows` | int | Kein Default; Pflichtargument | Erwartet eine ganze Zeilenzahl von 1 bis 100000. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Im erweiterten Pfad wird NULL ausdrücklich zurückgewiesen. Im Legacy-Pfad gibt es keine ausdrückliche NULL-Prüfung; NULL kann die Bereichsprüfung passieren und erst beim NOT-NULL-Schreiben einen abgefangenen Fehler auslösen. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PayloadEnabled:** | `@PayloadEnabled` | bit | Kein Default; Pflichtargument | 0 speichert eine deaktivierte Payloadpolicy, 1 eine aktivierte Payloadpolicy. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Im erweiterten Pfad wird NULL ausdrücklich zurückgewiesen. Im Legacy-Pfad gibt es keine ausdrückliche NULL-Prüfung; NULL kann die Bereichsprüfung passieren und erst beim NOT-NULL-Schreiben einen abgefangenen Fehler auslösen. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@RawRetentionDays:** | `@RawRetentionDays` | smallint | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zahl von 1 bis 3650 Tagen. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PayloadRetentionDays:** | `@PayloadRetentionDays` | smallint | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zahl von 1 bis 3650 Tagen. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@RollupRetentionDays:** | `@RollupRetentionDays` | smallint | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zahl von 1 bis 3650 Tagen. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SoftBudgetMB:** | `@SoftBudgetMB` | int | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zahl von 1 bis 2147483647 MB. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PurgeIntervalMinutes:** | `@PurgeIntervalMinutes` | smallint | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zahl von 1 bis 1440 Minuten. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PurgeBatchRows:** | `@PurgeBatchRows` | int | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zeilenzahl von 1 bis 100000 als gespeicherte Purge-Batchgröße. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@BudgetAction:** | `@BudgetAction` | varchar(32) | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 ist ausschließlich `PURGE_EXPIRED_THEN_STOP` zulässig; dies bezeichnet die gespeicherte Aktion zur Bereinigung abgelaufener Daten vor einem budgetbedingten Sammelstopp. Die Procedure speichert den Wert, führt selbst jedoch keine Bereinigung aus. Das Argument darf nicht ausgelassen werden. Bei wirksamem `@UpdateSharedPolicy`=1 ist Leertext ungültig; erweiterte Aufrufe weisen NULL ausdrücklich zurück. Im Legacy-Pfad kann NULL die Dreiwertlogik der Wertprüfung passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL oder Leertext ignoriert; das Argument bleibt erforderlich. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCodeOut:** | `@StatusCodeOut` | varchar(40) OUTPUT | Kein Default; Pflichtargument | Das Argument darf nicht ausgelassen werden. Eine gebundene Variable muss mit OUTPUT übergeben werden, um den Wert zu empfangen; ohne OUTPUT wird die Ausgabe verworfen. Eingehende NULL-, Leer- oder sonstige Anfangswerte werden ignoriert; die Variable wird auf `AVAILABLE` zurückgesetzt. Geschlossene Statuswerte: `AVAILABLE` (verfügbar/erfolgreich), `INVALID_PARAMETER` (ungültiger Parameter oder Aufrufvertrag), `TARGET_UNAVAILABLE` (Zielidentität oder Paket nicht verfügbar), `DENIED_PERMISSION` (abgefangener Berechtigungsfehler), `ERROR_HANDLED` (sonstiger abgefangener Fehler). | Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorNumberOut:** | `@ErrorNumberOut` | int OUTPUT | Kein Default; Pflichtargument | Das Argument darf nicht ausgelassen werden. Eine gebundene Variable muss mit OUTPUT übergeben werden, um die Nummer oder NULL zu empfangen; ohne OUTPUT wird die Ausgabe verworfen. Eingehende NULL-, Leer- oder sonstige Anfangswerte werden ignoriert; die Variable wird auf NULL zurückgesetzt. Frühe Vertragsfehler setzen 51011 und RETURN 51011; Bereichsfehler setzen keine Fehlernummer und führen dieses RETURN nicht aus. 53764 bezeichnet eine abweichende Zielidentität, 53761 einen fehlenden erweiterten Paketvertrag und 53781 die fehlende `FILE_IO`-Version. Abgefangene Fehler 229, 262, 297, 300 und 371 ergeben `DENIED_PERMISSION`; sonstige abgefangene Fehler ergeben `ERROR_HANDLED`. Fehler 53700 bezeichnet eine fehlende Collectorzeile. Nicht alle nativen Fehler werden abgefangen; die Fehlernummer ist daher kein geschlossenes Set. | Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die '
            + N'normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessageOut:** | `@ErrorMessageOut` | nvarchar(2048) OUTPUT | Kein Default; Pflichtargument | Das Argument darf nicht ausgelassen werden. Eine gebundene Variable muss mit OUTPUT übergeben werden, um Meldung oder NULL zu empfangen; ohne OUTPUT wird die Ausgabe verworfen. Eingehende NULL-, Leer- oder sonstige Anfangswerte werden ignoriert; die Variable wird auf NULL zurückgesetzt. Bei behandelten Fehlern enthält der Parameter den Meldungstext; bei regulärem Erfolg bleibt NULL. Identitäts-, Paket- und Modulprüfungen können vor TRY zurückkehren. | Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CollectorCode:** | `@CollectorCode` | varchar(64) | `''PERFORMANCE_COUNTERS''` | Ein einzelner Code, keine Liste und kein Pattern. Beim Auslassen gilt der Default `PERFORMANCE_COUNTERS`. Normalisierung erfolgt mit UPPER(LTRIM(RTRIM(COALESCE(Wert,'''')))); getrimmt wird das SQL-Leerzeichen U+0020. NULL sowie leerer oder nur aus Leerzeichen bestehender Text werden zu leer und sind ungültig; sie lösen nicht den Default aus. Zulässige Werte und Bedeutung: `PERFORMANCE_COUNTERS` (Performance Counter), `WAIT_STATS` (Wartestatistik), `FILE_IO` (Datei-I/O). |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CollectorEnabled:** | `@CollectorEnabled` | bit | 1 | Default 1. 0 deaktiviert die Collectorpolicy, 1 aktiviert sie. NULL ist ungültig; leerer Text ist keine unterstützte Eingabeform. Das Argument kann wegen des Defaults ausgelassen werden. Der Wert konfiguriert nur die Policy und startet keine Erfassung. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@UpdateSharedPolicy:** | `@UpdateSharedPolicy` | bit | NULL | Beim Auslassen gilt Default NULL. NULL wählt automatisch 1 für `PERFORMANCE_COUNTERS` und 0 für `WAIT_STATS`/`FILE_IO`. 0 aktualisiert nur den Collector, erhält dessen bestehendes RetentionPolicyCode und ignoriert alle sieben Shared-Parameter einschließlich NULL; diese Argumente bleiben dennoch erforderlich. 1 aktualisiert die `DEFAULT`-Retentionpolicy und weist dem Collector `DEFAULT` zu; dies wirkt auf weitere Collector, die `DEFAULT` verwenden. Erweiterte Aufrufe weisen NULL für wirksame Shared-Werte ausdrücklich zurück. Im Legacy-Pfad können NULL-Werte die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Leertext ist keine unterstützte Eingabeform. Konfigurationswerte starten keine Erfassung oder Bereinigung. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ExpectedTargetDatabaseId:** | `@ExpectedTargetDatabaseId` | int | NULL | Default NULL; das Argument kann ausgelassen werden. Für `PERFORMANCE_COUNTERS` darf das gesamte Identitätstripel auch im erweiterten Pfad NULL sein. `WAIT_STATS`/`FILE_IO` benötigen ID, Name und CreateDate; sobald irgendein Identitätsfeld ungleich NULL ist, müssen alle drei vorliegen. Die ID muss größer als 4 und gleich `DB_ID()` der aktuell verbundenen Datenbank sein. Leertext ist keine unterstützte Eingabeform. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ExpectedTargetDatabaseName:** | `@ExpectedTargetDatabaseName` | sysname | NULL | Default NULL; das Argument kann ausgelassen werden. Für `PERFORMANCE_COUNTERS` darf das gesamte Identitätstripel auch im erweiterten Pfad NULL sein. `WAIT_STATS`/`FILE_IO` benötigen ID, Name und CreateDate; sobald irgendein Identitätsfeld ungleich NULL ist, müssen alle drei vorliegen. Verglichen wird der rohe Datenbankname binär exakt mit `master.sys.databases.name`, ohne Trim oder Groß-/Kleinschreibungsnormalisierung. Ein leerer Name kann den Vergleich nicht erfüllen. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ExpectedTargetCreateDate:** | `@ExpectedTargetCreateDate` | datetime | NULL | Default NULL; das Argument kann ausgelassen werden. Für `PERFORMANCE_COUNTERS` darf das gesamte Identitätstripel auch im erweiterten Pfad NULL sein. `WAIT_STATS`/`FILE_IO` benötigen ID, Name und CreateDate; sobald irgendein Identitätsfeld ungleich NULL ist, müssen alle drei vorliegen. Leertext ist keine unterstützte Datumseingabe. Erwartet wird der typisierte, als datetime erfasste Erstellungswert; er muss exakt dem als datetime erfassten `master.sys.databases.create_date` entsprechen; keine UTC-Konvertierung. Die Zieldatenbank muss ONLINE und schreibbar sein. Das Tripel schützt vor Wiederverwendung einer Datenbank; die Procedure wechselt die Datenbank nicht. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@JoinFrameworkTransaction:** | `@JoinFrameworkTransaction` | bit | 0 | Default 0; das Argument kann ausgelassen werden. NULL ist ungültig; leerer Text ist keine unterstützte Eingabeform. 1 ist nur für `WAIT_STATS`/`FILE_IO` bei wirksamem `@UpdateSharedPolicy`=1, genau einer committable Callertransaktion (`XACT_STATE()`=1) und `IMPLICIT_TRANSACTIONS` OFF zulässig. Der Eigentümer behält COMMIT/ROLLBACK; bei Join=1 erstellt die Procedure keinen Savepoint. Bei Join=0 verlangen erweiterte `WAIT_STATS`/`FILE_IO`-Aufrufe keine Callertransaktion. Alle erweiterten Aufrufe verlangen `IMPLICIT_TRANSACTIONS` OFF. Erweiterte `PERFORMANCE_COUNTERS`-Aufrufe können eine eigene Transaktion oder bei Callertransaktion einen Savepoint nutzen; Rollback zum Savepoint erfolgt ausschließlich bei `XACT_STATE()`=1. Der Legacy-Standardaufruf `PERFORMANCE_COUNTERS` mit CollectorEnabled=1, wirksamem Shared=1 (explizit oder automatisch), allen Identitätswerten NULL und Join=0 führt BEGIN TRANSACTION und bei Erfol'
            + N'g COMMIT TRANSACTION auch innerhalb einer bestehenden Transaktion aus; CATCH kann die gesamte Callertransaktion zurückrollen. Andere gültige Einstellungen wählen erweiterte Prüfungen; die optionale PC-Identität allein aktiviert sie nicht. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Kein Fach-Resultset. Die drei OUTPUTs `@StatusCodeOut varchar(40)`, `@ErrorNumberOut int`, `@ErrorMessageOut nvarchar(2048)` melden die Validierung und Aktualisierung der Snapshot-Policy. `AVAILABLE` bedeutet den bestätigten Zielschreibpfad; `INVALID_PARAMETER`, `TARGET_UNAVAILABLE`, `DENIED_PERMISSION` und `ERROR_HANDLED` begrenzen den Fehler. Der Helper schreibt nur im konfigurierten Snapshot-Ziel; ein Fehlerstatus bestätigt keinen vollständigen Rollback aller fremden Aktionen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT [SkillMarkdown]'
            + NCHAR(10)
            + N'FROM [monitor_metadata].[VW_ObjectUsageSkills]'
            + NCHAR(10)
            + N'WHERE [SchemaName]=N''snapshot'' AND [ObjectName]=N''InternalConfigureSnapshotPolicy'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [snapshot].[InternalConfigureSnapshotPolicy] @CollectionIntervalSeconds=NULL, @MaxRows=NULL, @PayloadEnabled=NULL, @RawRetentionDays=NULL, @PayloadRetentionDays=NULL, @RollupRetentionDays=NULL, @SoftBudgetMB=NULL, @PurgeIntervalMinutes=NULL, @PurgeBatchRows=NULL, @BudgetAction=NULL, @StatusCodeOut=NULL, @ErrorNumberOut=NULL, @ErrorMessageOut=NULL, @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Erweiterte Aufrufe verlangen IMPLICIT_TRANSACTIONS OFF. Erweiterte WAIT_STATS/FILE_IO-Aufrufe mit Join=0 verlangen keine Callertransaktion. Join=1 ist nur für WAIT_STATS/FILE_IO mit wirksamem @UpdateSharedPolicy=1, genau einer committable Callertransaktion (XACT_STATE()=1) und IMPLICIT_TRANSACTIONS OFF zulässig. Der Eigentümer behält COMMIT/ROLLBACK; die Procedure erstellt keinen Savepoint. Erweiterte PERFORMANCE_COUNTERS-Aufrufe können eine eigene Transaktion oder bei Callertransaktion einen Savepoint nutzen; Rollback zum Savepoint erfolgt nur bei XACT_STATE()=1. Der Legacy-Standardaufruf PERFORMANCE_COUNTERS mit @CollectorEnabled=1, wirksamem @UpdateSharedPolicy=1 (explizit oder automatisch), allen drei Identitätswerten NULL und @JoinFrameworkTransaction=0 führt BEGIN TRANSACTION und bei Erfolg COMMIT TRANSACTION auch innerhalb einer bestehenden Transaktion aus; CATCH kann die gesamte Callertransaktion zurückrollen. Andere gültige Einstellungen wählen erweiterte Prüfungen; die option'
            + N'ale vollständig NULL gesetzte PC-Identität allein aktiviert sie nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Objekt       : snapshot.InternalConfigureSnapshotPolicy'
            + NCHAR(10)
            + N'Version      : 1.2.0'
            + NCHAR(10)
            + N'Stand        : 2026-10-26'
            + NCHAR(10)
            + N'Zweck        : Schreibt und prüft typisierte Collector- und Shared-Policies in'
            + NCHAR(10)
            + N'               der aktuell verbundenen Snapshot-Datenbank.'
            + NCHAR(10)
            + N'==============================================================================='
            + NCHAR(10)
            + NCHAR(10)
            + N'Interner Aufrufvertrag'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure aktualisiert vorhandene Zeilen in [snapshot].[CollectorPolicy] und bei wirksamem Shared-Update die vorhandene DEFAULT-Zeile in [snapshot].[RetentionPolicy]. Sie fügt keine Zeilen ein, erfasst keine Daten, bereinigt keine Daten und führt kein DDL aus. Sie arbeitet in der aktuell verbundenen Snapshot-Datenbank. Defaults sind Konfigurationswerte und starten keine Erfassung oder Bereinigung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Erweiterte Aufrufe verlangen IMPLICIT_TRANSACTIONS OFF. Erweiterte WAIT_STATS/FILE_IO-Aufrufe mit Join=0 verlangen keine Callertransaktion. Join=1 ist nur für WAIT_STATS/FILE_IO mit wirksamem @UpdateSharedPolicy=1, genau einer committable Callertransaktion (XACT_STATE()=1) und IMPLICIT_TRANSACTIONS OFF zulässig. Der Eigentümer behält COMMIT/ROLLBACK; die Procedure erstellt keinen Savepoint. Erweiterte PERFORMANCE_COUNTERS-Aufrufe können eine eigene Transaktion oder bei Callertransaktion einen Savepoint nutzen; Rollback zum Savepoint erfolgt nur bei XACT_STATE()=1. Der Legacy-Standardaufruf PERFORMANCE_COUNTERS mit @CollectorEnabled=1, wirksamem @UpdateSharedPolicy=1 (explizit oder automatisch), allen drei Identitätswerten NULL und @JoinFrameworkTransaction=0 führt BEGIN TRANSACTION und bei Erfolg COMMIT TRANSACTION auch innerhalb einer bestehenden Transaktion aus; CATCH kann die gesamte Callertransaktion zurückrollen. Andere gültige Einstellungen wählen erweiterte Prüfungen; die option'
            + N'ale vollständig NULL gesetzte PC-Identität allein aktiviert sie nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Parametervertrag'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Parameter | Datentyp | Default | Eingabeform und Wirkung |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| `@CollectionIntervalSeconds` | smallint | Kein Default; Pflichtargument | Erwartet eine ganze Sekundenzahl von 1 bis 3600. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Im erweiterten Pfad wird NULL ausdrücklich zurückgewiesen. Im Legacy-Pfad gibt es keine ausdrückliche NULL-Prüfung; NULL kann die Bereichsprüfung passieren und erst beim NOT-NULL-Schreiben einen abgefangenen Fehler auslösen. |'
            + NCHAR(10)
            + N'| `@MaxRows` | int | Kein Default; Pflichtargument | Erwartet eine ganze Zeilenzahl von 1 bis 100000. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Im erweiterten Pfad wird NULL ausdrücklich zurückgewiesen. Im Legacy-Pfad gibt es keine ausdrückliche NULL-Prüfung; NULL kann die Bereichsprüfung passieren und erst beim NOT-NULL-Schreiben einen abgefangenen Fehler auslösen. |'
            + NCHAR(10)
            + N'| `@PayloadEnabled` | bit | Kein Default; Pflichtargument | 0 speichert eine deaktivierte Payloadpolicy, 1 eine aktivierte Payloadpolicy. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Im erweiterten Pfad wird NULL ausdrücklich zurückgewiesen. Im Legacy-Pfad gibt es keine ausdrückliche NULL-Prüfung; NULL kann die Bereichsprüfung passieren und erst beim NOT-NULL-Schreiben einen abgefangenen Fehler auslösen. |'
            + NCHAR(10)
            + N'| `@RawRetentionDays` | smallint | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zahl von 1 bis 3650 Tagen. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |'
            + NCHAR(10)
            + N'| `@PayloadRetentionDays` | smallint | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zahl von 1 bis 3650 Tagen. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |'
            + NCHAR(10)
            + N'| `@RollupRetentionDays` | smallint | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zahl von 1 bis 3650 Tagen. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |'
            + NCHAR(10)
            + N'| `@SoftBudgetMB` | int | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zahl von 1 bis 2147483647 MB. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |'
            + NCHAR(10)
            + N'| `@PurgeIntervalMinutes` | smallint | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zahl von 1 bis 1440 Minuten. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |'
            + NCHAR(10)
            + N'| `@PurgeBatchRows` | int | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zeilenzahl von 1 bis 100000 als gespeicherte Purge-Batchgröße. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |'
            + NCHAR(10)
            + N'| `@BudgetAction` | varchar(32) | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 ist ausschließlich `PURGE_EXPIRED_THEN_STOP` zulässig; dies bezeichnet die gespeicherte Aktion zur Bereinigung abgelaufener Daten vor einem budgetbedingten Sammelstopp. Die Procedure speichert den Wert, führt selbst jedoch keine Bereinigung aus. Das Argument darf nicht ausgelassen werden. Bei wirksamem `@UpdateSharedPolicy`=1 ist Leertext ungültig; erweiterte Aufrufe weisen NULL ausdrücklich zurück. Im Legacy-Pfad kann NULL die Dreiwertlogik der Wertprüfung passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL oder Leertext ignoriert; das Argument bleibt erforderlich. |'
            + NCHAR(10)
            + N'| `@StatusCodeOut` | varchar(40) OUTPUT | Kein Default; Pflichtargument | Das Argument darf nicht ausgelassen werden. Eine gebundene Variable muss mit OUTPUT übergeben werden, um den Wert zu empfangen; ohne OUTPUT wird die Ausgabe verworfen. Eingehende NULL-, Leer- oder sonstige Anfangswerte werden ignoriert; die Variable wird auf `AVAILABLE` zurückgesetzt. Geschlossene Statuswerte: `AVAILABLE` (verfügbar/erfolgreich), `INVALID_PARAMETER` (ungültiger Parameter oder Aufrufvertrag), `TARGET_UNAVAILABLE` (Zielidentität oder Paket nicht verfügbar), `DENIED_PERMISSION` (abgefangener Berechtigungsfehler), `ERROR_HANDLED` (sonstiger abgefangener Fehler). |'
            + NCHAR(10)
            + N'| `@ErrorNumberOut` | int OUTPUT | Kein Default; Pflichtargument | Das Argument darf nicht ausgelassen werden. Eine gebundene Variable muss mit OUTPUT übergeben werden, um die Nummer oder NULL zu empfangen; ohne OUTPUT wird die Ausgabe verworfen. Eingehende NULL-, Leer- oder sonstige Anfangswerte werden ignoriert; die Variable wird auf NULL zurückgesetzt. Frühe Vertragsfehler setzen 51011 und RETURN 51011; Bereichsfehler setzen keine Fehlernummer und führen dieses RETURN nicht aus. 53764 bezeichnet eine abweichende Zielidentität, 53761 einen fehlenden erweiterten Paketvertrag und 53781 die fehlende `FILE_IO`-Version. Abgefangene Fehler 229, 262, 297, 300 und 371 ergeben `DENIED_PERMISSION`; sonstige abgefangene Fehler ergeben `ERROR_HANDLED`. Fehler 53700 bezeichnet eine fehlende Collectorzeile. Nicht alle nativen Fehler werden abgefangen; die Fehlernummer ist daher kein geschlossenes Set. |'
            + NCHAR(10)
            + N'| `@ErrorMessageOut` | nvarchar(2048) OUTPUT | Kein Default; Pflichtargument | Das Argument darf nicht ausgelassen werden. Eine gebundene Variable muss mit OUTPUT übergeben werden, um Meldung oder NULL zu empfangen; ohne OUTPUT wird die Ausgabe verworfen. Eingehende NULL-, Leer- oder sonstige Anfangswerte werden ignoriert; die Variable wird auf NULL zurückgesetzt. Bei behandelten Fehlern enthält der Parameter den Meldungstext; bei regulärem Erfolg bleibt NULL. Identitäts-, Paket- und Modulprüfungen können vor TRY zurückkehren. |'
            + NCHAR(10)
            + N'| `@CollectorCode` | varchar(64) | `''PERFORMANCE_COUNTERS''` | Ein einzelner Code, keine Liste und kein Pattern. Beim Auslassen gilt der Default `PERFORMANCE_COUNTERS`. Normalisierung erfolgt mit UPPER(LTRIM(RTRIM(COALESCE(Wert,'''')))); getrimmt wird das SQL-Leerzeichen U+0020. NULL sowie leerer oder nur aus Leerzeichen bestehender Text werden zu leer und sind ungültig; sie lösen nicht den Default aus. Zulässige Werte und Bedeutung: `PERFORMANCE_COUNTERS` (Performance Counter), `WAIT_STATS` (Wartestatistik), `FILE_IO` (Datei-I/O). |'
            + NCHAR(10)
            + N'| `@CollectorEnabled` | bit | 1 | Default 1. 0 deaktiviert die Collectorpolicy, 1 aktiviert sie. NULL ist ungültig; leerer Text ist keine unterstützte Eingabeform. Das Argument kann wegen des Defaults ausgelassen werden. Der Wert konfiguriert nur die Policy und startet keine Erfassung. |'
            + NCHAR(10)
            + N'| `@UpdateSharedPolicy` | bit | NULL | Beim Auslassen gilt Default NULL. NULL wählt automatisch 1 für `PERFORMANCE_COUNTERS` und 0 für `WAIT_STATS`/`FILE_IO`. 0 aktualisiert nur den Collector, erhält dessen bestehendes RetentionPolicyCode und ignoriert alle sieben Shared-Parameter einschließlich NULL; diese Argumente bleiben dennoch erforderlich. 1 aktualisiert die `DEFAULT`-Retentionpolicy und weist dem Collector `DEFAULT` zu; dies wirkt auf weitere Collector, die `DEFAULT` verwenden. Erweiterte Aufrufe weisen NULL für wirksame Shared-Werte ausdrücklich zurück. Im Legacy-Pfad können NULL-Werte die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Leertext ist keine unterstützte Eingabeform. Konfigurationswerte starten keine Erfassung oder Bereinigung. |'
            + NCHAR(10)
            + N'| `@ExpectedTargetDatabaseId` | int | NULL | Default NULL; das Argument kann ausgelassen werden. Für `PERFORMANCE_COUNTERS` darf das gesamte Identitätstripel auch im erweiterten Pfad NULL sein. `WAIT_STATS`/`FILE_IO` benötigen ID, Name und CreateDate; sobald irgendein Identitätsfeld ungleich NULL ist, müssen alle drei vorliegen. Die ID muss größer als 4 und gleich `DB_ID()` der aktuell verbundenen Datenbank sein. Leertext ist keine unterstützte Eingabeform. |'
            + NCHAR(10)
            + N'| `@ExpectedTargetDatabaseName` | sysname | NULL | Default NULL; das Argument kann ausgelassen werden. Für `PERFORMANCE_COUNTERS` darf das gesamte Identitätstripel auch im erweiterten Pfad NULL sein. `WAIT_STATS`/`FILE_IO` benötigen ID, Name und CreateDate; sobald irgendein Identitätsfeld ungleich NULL ist, müssen alle drei vorliegen. Verglichen wird der rohe Datenbankname binär exakt mit `master.sys.databases.name`, ohne Trim oder Groß-/Kleinschreibungsnormalisierung. Ein leerer Name kann den Vergleich nicht erfüllen. |'
            + NCHAR(10)
            + N'| `@ExpectedTargetCreateDate` | datetime | NULL | Default NULL; das Argument kann ausgelassen werden. Für `PERFORMANCE_COUNTERS` darf das gesamte Identitätstripel auch im erweiterten Pfad NULL sein. `WAIT_STATS`/`FILE_IO` benötigen ID, Name und CreateDate; sobald irgendein Identitätsfeld ungleich NULL ist, müssen alle drei vorliegen. Leertext ist keine unterstützte Datumseingabe. Erwartet wird der typisierte, als datetime erfasste Erstellungswert; er muss exakt dem als datetime erfassten `master.sys.databases.create_date` entsprechen; keine UTC-Konvertierung. Die Zieldatenbank muss ONLINE und schreibbar sein. Das Tripel schützt vor Wiederverwendung einer Datenbank; die Procedure wechselt die Datenbank nicht. |'
            + NCHAR(10)
            + N'| `@JoinFrameworkTransaction` | bit | 0 | Default 0; das Argument kann ausgelassen werden. NULL ist ungültig; leerer Text ist keine unterstützte Eingabeform. 1 ist nur für `WAIT_STATS`/`FILE_IO` bei wirksamem `@UpdateSharedPolicy`=1, genau einer committable Callertransaktion (`XACT_STATE()`=1) und `IMPLICIT_TRANSACTIONS` OFF zulässig. Der Eigentümer behält COMMIT/ROLLBACK; bei Join=1 erstellt die Procedure keinen Savepoint. Bei Join=0 verlangen erweiterte `WAIT_STATS`/`FILE_IO`-Aufrufe keine Callertransaktion. Alle erweiterten Aufrufe verlangen `IMPLICIT_TRANSACTIONS` OFF. Erweiterte `PERFORMANCE_COUNTERS`-Aufrufe können eine eigene Transaktion oder bei Callertransaktion einen Savepoint nutzen; Rollback zum Savepoint erfolgt ausschließlich bei `XACT_STATE()`=1. Der Legacy-Standardaufruf `PERFORMANCE_COUNTERS` mit CollectorEnabled=1, wirksamem Shared=1 (explizit oder automatisch), allen Identitätswerten NULL und Join=0 führt BEGIN TRANSACTION und bei Erfolg COMMIT TRANSACTION auch inner'
            + N'halb einer bestehenden Transaktion aus; CATCH kann die gesamte Callertransaktion zurückrollen. Andere gültige Einstellungen wählen erweiterte Prüfungen; die optionale PC-Identität allein aktiviert sie nicht. |'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der erweiterte Paketvertrag erfordert genau eine SC-023-Zeile mit Version 1.2.1/Schema 2 oder 1.3.0 beziehungsweise 1.3.1/Schema 3, außerdem InternalCompleteWaitStatsCycle und InternalPurgeExpiredData mit @ContractOnly. FILE_IO erfordert Version 1.3.1/Schema 3. Die Procedure aktualisiert genau eine vorhandene CollectorPolicy-Zeile; andernfalls entsteht Fehler 53700.'
            + NCHAR(10)
            + NCHAR(10)
            + N'NULL-Prüfungen unterscheiden sich je Pfad: erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück. Im Legacy-Pfad können NULL-Werte bei den drei Collectorwerten und den Shared-Parametern wegen SQL-Dreiwertlogik Bereichsprüfungen passieren und erst beim NOT-NULL-Schreiben im CATCH scheitern. Daher gilt dafür keine einheitliche INVALID_PARAMETER-Zusage. Frühe Vertragsfehler setzen 51011 und RETURN 51011; Bereichsfehler setzen keine Fehlernummer und führen dieses RETURN nicht aus. Identitäts- und Paketprüfungen erfolgen vor TRY; nicht alle nativen Fehler werden abgefangen.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown]
UNION ALL
SELECT CONVERT(sysname,N'snapshot') AS [SchemaName],CONVERT(sysname,N'InternalFinalizeCollectionCycle') AS [ObjectName],CONVERT(varchar(24),'INTERNAL_PROCEDURE') AS [ObjectType],CONVERT(varchar(24),'snapshot_target') AS [DatabaseRole],CONVERT(bit,1) AS [IsInternal],CONVERT(nvarchar(max),N'Schreibt Abschlussstatus und Diagnosedaten in die adressierte CaptureRun-Zeile und zählt zugehörige MetricSample- und PayloadSnapshot-Zeilen.') AS [Description],CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "snapshot.InternalFinalizeCollectionCycle"'
            + NCHAR(10)
            + N'schema_name: "snapshot"'
            + NCHAR(10)
            + N'object_name: "InternalFinalizeCollectionCycle"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "snapshot_target"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Schreibt Abschlussstatus und Diagnosedaten in die adressierte CaptureRun-Zeile und zählt zugehörige MetricSample- und PayloadSnapshot-Zeilen."'
            + NCHAR(10)
            + N'source_path: "Code/10_SnapshotBaseline/060_InternalFinalizeCollectionCycle.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# snapshot.InternalFinalizeCollectionCycle'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Schreibt Abschlussstatus und Diagnosedaten in die adressierte CaptureRun-Zeile und zählt zugehörige MetricSample- und PayloadSnapshot-Zeilen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [snapshot].[InternalFinalizeCollectionCycle]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[snapshot].[CaptureRun]`, `[snapshot].[MetricSample]`, `[snapshot].[PayloadSnapshot]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| @CaptureRunId | bigint | ja | kein Default |'
            + NCHAR(10)
            + N'| @StatusCode | varchar(40) | ja | kein Default |'
            + NCHAR(10)
            + N'| @IsPartial | bit | ja | kein Default |'
            + NCHAR(10)
            + N'| @ErrorNumber | int | ja | kein Default |'
            + NCHAR(10)
            + N'| @ErrorMessage | nvarchar(2048) | ja | kein Default |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CaptureRunId:** `@CaptureRunId` bigint; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument, einzelne Lauf-ID; keine Positivitäts-/Existenzprüfung. NULL oder kein Treffer bewirkt null aktualisierte Zeilen ohne expliziten Fehler oder Ausgabe. Beendete Zeile darf erneut finalisiert werden. Fehlendes Argument scheitert beim Aufruf und ist nicht gleich NULL.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCode:** `@StatusCode` varchar(40); Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument, unveränderter, offener Statustext. CaptureRun hat keine CHECK-Wertemenge; jeder nicht-NULL-Text, auch Leertext, ist speicherbar. NULL scheitert bei Treffer an NOT NULL mit nativem SQL-Fehler. Keine Konsistenzprüfung mit IsPartial.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@IsPartial:** `@IsPartial` bit; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtschalter: 0 nicht partiell, 1 partiell. Leertext ist keine unterstützte Eingabe. Direkte Speicherung. NULL scheitert bei Treffer an NOT NULL; keine Konsistenzprüfung mit StatusCode.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorNumber:** `@ErrorNumber` int; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument für Diagnosezahl. NULL löscht den Wert; jede vorzeichenbehaftete int-Zahl wird ohne Validierung gespeichert und nicht als SQL-Fehler ausgelöst.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessage:** `@ErrorMessage` nvarchar(2048); Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument für Unicode-Diagnosetext. NULL löscht den Wert, Leertext wird gespeichert; Unveränderter Unicode-Rohtext wird weder ausgeführt noch normalisiert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Weder Fach-Resultset noch OUTPUT-Parameter. Die Procedure aktualisiert die vorhandene CaptureRun-Zeile mit StatusCode, IsPartial, ErrorNumber, ErrorMessage und Endzeit; fehlt der CaptureRun, werden null Zeilen aktualisiert und kein eigener Resultsetstatus geliefert. Die übergebenen Statuswerte werden nicht zu einer geschlossenen Fach-Wertemenge umgedeutet.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT [SkillMarkdown]'
            + NCHAR(10)
            + N'FROM [monitor_metadata].[VW_ObjectUsageSkills]'
            + NCHAR(10)
            + N'WHERE [SchemaName]=N''snapshot'' AND [ObjectName]=N''InternalFinalizeCollectionCycle'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [snapshot].[InternalFinalizeCollectionCycle] @CaptureRunId=NULL, @StatusCode=NULL, @IsPartial=NULL, @ErrorNumber=NULL, @ErrorMessage=NULL, @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Zweck: Schreibt Abschlussstatus und Diagnosedaten in die adressierte CaptureRun-Zeile und zählt zugehörige MetricSample- und PayloadSnapshot-Zeilen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Zweck: Schreibt Abschlussstatus und Diagnosedaten in die adressierte CaptureRun-Zeile und zählt zugehörige MetricSample- und PayloadSnapshot-Zeilen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Schnittstelle und Parameter'
            + NCHAR(10)
            + N'---------------------------'
            + NCHAR(10)
            + N'`@CaptureRunId` bigint; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument, einzelne'
            + NCHAR(10)
            + N'Lauf-ID; keine Positivitäts-/Existenzprüfung. NULL oder kein Treffer bewirkt'
            + NCHAR(10)
            + N'null aktualisierte Zeilen ohne expliziten Fehler oder Ausgabe. Beendete Zeile'
            + NCHAR(10)
            + N'darf erneut finalisiert werden. Fehlendes Argument scheitert beim Aufruf und'
            + NCHAR(10)
            + N'ist nicht gleich NULL.'
            + NCHAR(10)
            + NCHAR(10)
            + N'`@StatusCode` varchar(40); Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument, unveränderter, offener Statustext. CaptureRun hat keine CHECK-Wertemenge; jeder nicht-NULL-Text,'
            + NCHAR(10)
            + N'auch Leertext, ist speicherbar. NULL scheitert bei Treffer an NOT NULL mit'
            + NCHAR(10)
            + N'nativem SQL-Fehler. Keine Konsistenzprüfung mit IsPartial.'
            + NCHAR(10)
            + NCHAR(10)
            + N'`@IsPartial` bit; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtschalter: 0 nicht partiell,'
            + NCHAR(10)
            + N'1 partiell. Leertext ist keine unterstützte Eingabe. Direkte Speicherung. NULL scheitert bei Treffer an NOT NULL;'
            + NCHAR(10)
            + N'keine Konsistenzprüfung mit StatusCode.'
            + NCHAR(10)
            + NCHAR(10)
            + N'`@ErrorNumber` int; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument für Diagnosezahl.'
            + NCHAR(10)
            + N'NULL löscht den Wert; jede vorzeichenbehaftete int-Zahl wird ohne Validierung'
            + NCHAR(10)
            + N'gespeichert und nicht als SQL-Fehler ausgelöst.'
            + NCHAR(10)
            + NCHAR(10)
            + N'`@ErrorMessage` nvarchar(2048); Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument für'
            + NCHAR(10)
            + N'Unicode-Diagnosetext. NULL löscht den Wert, Leertext wird gespeichert;'
            + NCHAR(10)
            + N'Unveränderter Unicode-Rohtext wird weder ausgeführt noch normalisiert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Verhalten und Grenzen'
            + NCHAR(10)
            + N'---------------------'
            + NCHAR(10)
            + N'Aktualisiert die passende CaptureRun-Zeile: EndedAtUtc wird auf'
            + NCHAR(10)
            + N'SYSUTCDATETIME() gesetzt, StatusCode, IsPartial, ErrorNumber und ErrorMessage'
            + NCHAR(10)
            + N'übernommen. MetricSampleCount und PayloadCount werden mit COUNT_BIG aus den'
            + NCHAR(10)
            + N'zugehörigen Tabellen ermittelt. Keine Quellerfassung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Keine OUTPUT-Parameter und kein Resultset. Kein Treffer aktualisiert null'
            + NCHAR(10)
            + N'Zeilen ohne explizite Meldung. Zwei Zählabfragen garantieren keine stabile'
            + NCHAR(10)
            + N'gemeinsame Momentaufnahme bei parallelen Änderungen. Keine eigene Transaktion'
            + NCHAR(10)
            + N'und kein CATCH; native Fehler werden nicht abgefangen. Wiederholtes Finalisieren'
            + NCHAR(10)
            + N'ist nicht gesperrt oder als einmalig abgesichert.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown]
UNION ALL
SELECT CONVERT(sysname,N'snapshot') AS [SchemaName],CONVERT(sysname,N'InternalPrepareCollectionCycle') AS [ObjectName],CONVERT(varchar(24),'INTERNAL_PROCEDURE') AS [ObjectType],CONVERT(varchar(24),'snapshot_target') AS [DatabaseRole],CONVERT(bit,1) AS [IsInternal],CONVERT(nvarchar(max),N'Prüft Zielidentität, Collectorvertrag, Aktivierung, Datenbudget und Fälligkeit; eröffnet abhängig vom Collector einen Lauf.') AS [Description],CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "snapshot.InternalPrepareCollectionCycle"'
            + NCHAR(10)
            + N'schema_name: "snapshot"'
            + NCHAR(10)
            + N'object_name: "InternalPrepareCollectionCycle"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "snapshot_target"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Prüft Zielidentität, Collectorvertrag, Aktivierung, Datenbudget und Fälligkeit; eröffnet abhängig vom Collector einen Lauf."'
            + NCHAR(10)
            + N'source_path: "Code/10_SnapshotBaseline/040_InternalPrepareCollectionCycle.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# snapshot.InternalPrepareCollectionCycle'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Prüft Zielidentität, Collectorvertrag, Aktivierung, Datenbudget und Fälligkeit; eröffnet abhängig vom Collector einen Lauf.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [snapshot].[InternalPrepareCollectionCycle]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `master.sys.databases`, `sys.database_files`, `[master].[sys].[databases]`, `[snapshot].[PackageVersion]`, `[sys].[procedures]`, `[sys].[schemas]`, `[sys].[parameters]`, `[snapshot].[CollectorPolicy]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| @SourceDatabaseName | sysname | ja | kein Default |'
            + NCHAR(10)
            + N'| @SchedulerType | varchar(16) | ja | kein Default |'
            + NCHAR(10)
            + N'| @RunEvenIfNotDue | bit | ja | kein Default |'
            + NCHAR(10)
            + N'| @CaptureRunIdOut | bigint OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @ShouldCollectOut | bit OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @StatusCodeOut | varchar(40) OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @ErrorMessageOut | nvarchar(2048) OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @CollectorCode | varchar(64) | nein | ''PERFORMANCE_COUNTERS'' |'
            + NCHAR(10)
            + N'| @ExpectedTargetDatabaseId | int | nein | NULL |'
            + NCHAR(10)
            + N'| @ExpectedTargetDatabaseName | sysname | nein | NULL |'
            + NCHAR(10)
            + N'| @ExpectedTargetCreateDate | datetime | nein | NULL |'
            + NCHAR(10)
            + N'| @PolicyOnly | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SourceDatabaseName:** `@SourceDatabaseName` sysname; Default: Kein Default. Weglassen ist nicht zulässig. Obligatorischer Rohname der Quellmetadaten, ohne Datenbankwechsel oder Datenbanklookup. Leertext wird unverändert gespeichert; NULL scheitert bei einem tatsächlich ausgeführten INSERT an NOT NULL. Ohne INSERT wird er nicht geschrieben; das Argument bleibt Pflicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SchedulerType:** `@SchedulerType` varchar(16); Default: Kein Default. Weglassen ist nicht zulässig. MANUAL (manueller Aufruf), EXTERNAL (externer Scheduler), SQL_AGENT (SQL Server Agent). Nur Herkunftslabel; startet oder prüft keinen Scheduler. Keine explizite Normalisierung. NULL, Leertext oder ein anderer Wert kann beim INSERT an NOT NULL/CHECK scheitern (nativer SQL-Fehler, kein INVALID_PARAMETER); ohne INSERT bleibt der Wert ungenutzt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@RunEvenIfNotDue:** `@RunEvenIfNotDue` bit; Default: Kein Default. Weglassen ist nicht zulässig. 0 prüft Fälligkeit, 1 umgeht nur die Due-Prüfung. Leertext ist keine unterstützte Eingabe. NULL wird nicht validiert und umgeht wegen des Tests = 0 ebenfalls die Prüfung. Disabled-, Budget- und Target-Gates bleiben wirksam.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CaptureRunIdOut:** `@CaptureRunIdOut` bigint OUTPUT; Default: Kein Default. Weglassen ist nicht zulässig. Beim Eintritt NULL; Eingangswert ignoriert. Ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang eine gebundene Variable als OUTPUT-Argument angeben. Zuweisung erst nach CaptureRun-INSERT. PERFORMANCE_COUNTERS legt bei Disabled-, Budget- oder Due-Abbruch einen beendeten partiellen Lauf samt ModuleStatus an; ID beweist keine Sammlung. WAIT_STATS/FILE_IO liefern bei frühem Abbruch keine ID. PolicyOnly=1 legt nie einen Lauf an. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ShouldCollectOut:** `@ShouldCollectOut` bit OUTPUT; Default: Kein Default. Weglassen ist nicht zulässig. Beim Eintritt 0; Eingangswert ignoriert. Ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang eine gebundene Variable als OUTPUT-Argument angeben. Nach INSERT nur bei AVAILABLE 1; PolicyOnly bleibt immer 0. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCodeOut:** `@StatusCodeOut` varchar(40) OUTPUT; Default: Kein Default. Weglassen ist nicht zulässig. Eintritt AVAILABLE; Eingangswert ignoriert. Ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang eine gebundene Variable als OUTPUT-Argument angeben. Ausgaben genau: AVAILABLE (Admission bereit), INVALID_PARAMETER (Collector, PolicyOnly-Kombination oder Wait-Transaktionszustand ungültig), TARGET_UNAVAILABLE (Ziel/erforderlicher Vertrag fehlt), DISABLED (Policy deaktiviert/fehlt), STOPPED_SIZE_BUDGET (Softbudget überschritten), SKIPPED_NOT_DUE (Intervall nicht abgelaufen). RUNNING ist nur der Status der eingefügten CaptureRun-Zeile, kein Ausgabe-Status. Native Fehler werden nicht allgemein in diese Statuswerte übersetzt. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessageOut:** `@ErrorMessageOut` nvarchar(2048) OUTPUT; Default: Kein Default. Weglassen ist nicht zulässig. Eintritt NULL; Eingangswert ignoriert. Ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang eine gebundene Variable als OUTPUT-Argument angeben. Diagnose eines erkannten Statuspfads oder NULL; native SQL-Fehler können direkt abbrechen. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CollectorCode:** `@CollectorCode` varchar(64); Default: PERFORMANCE_COUNTERS. Weglassen verwendet den Default. Einzelcode; NULL wird leer, dann UPPER und äußere U+0020-Leerzeichen entfernt. Zulässig: PERFORMANCE_COUNTERS (Performance Counter), WAIT_STATS (Wait-Statistiken), FILE_IO (Datei-I/O). Leertext/anderer normalisierter Wert ergibt INVALID_PARAMETER.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ExpectedTargetDatabaseId:** `@ExpectedTargetDatabaseId` int; Default: NULL. Weglassen verwendet NULL. Teil der Zielidentität. NULL nur im identitätslosen PERFORMANCE_COUNTERS-Fall; sobald eine Komponente gesetzt ist und bei WAIT_STATS/FILE_IO alle drei Angaben erforderlich. ID >4, die ID muss DB_ID() der aktuellen Datenbank entsprechen; Ziel in master online und beschreibbar. Leertext ist keine unterstützte Ganzzahleingabe. Abweichung ergibt TARGET_UNAVAILABLE.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ExpectedTargetDatabaseName:** `@ExpectedTargetDatabaseName` sysname; Default: NULL. Weglassen verwendet den Default. Rohname der Zielidentität, binär verglichen. NULL nur beim identitätslosen PERFORMANCE_COUNTERS-Fall; sonst alle drei Werte Pflicht. Leertext passt nicht und ergibt TARGET_UNAVAILABLE.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ExpectedTargetCreateDate:** `@ExpectedTargetCreateDate` datetime; Default: NULL. Weglassen verwendet den Default. Ein typisierter datetime-Wert aus master.sys.databases.create_date, ohne UTC-Konvertierung; Leertext ist keine unterstützte Datumsangabe. NULL nur beim identitätslosen PERFORMANCE_COUNTERS-Fall; sonst alle drei Werte Pflicht. Abweichung ergibt TARGET_UNAVAILABLE.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PolicyOnly:** `@PolicyOnly` bit; Default: 0. Weglassen verwendet den Default. 0 normaler Admission-Pfad mit Budgetermittlung und vorgesehenen Writes. 1 nur WAIT_STATS/FILE_IO: Enabled und Due aus abgeschlossener Historie prüfen. Der SoftBudgetMB-Policywert wird zuvor mit der Policyquelle gelesen; Dateigrößenmessung, Budgetvergleich und Writes entfallen; keine Run-ID, ShouldCollect bleibt 0, auch bei AVAILABLE. NULL ergibt INVALID_PARAMETER; leerer Text ist keine unterstützte Eingabe. Wait-/File-Aufrufe erfordern auch hier keine Callertransaktion und keine aktivierten impliziten Transaktionen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Im Normalpfad gibt es kein fachliches Resultset. `@CaptureRunIdOut` (bigint OUTPUT) bleibt bei frühem Abbruch, PolicyOnly und den WAIT_STATS-/FILE_IO-Skipfällen NULL; eine gesetzte ID belegt einen angelegten CaptureRun, keine erfolgreiche Sammlung. `@ShouldCollectOut` (bit OUTPUT) beginnt 0 und wird nach INSERT nur bei AVAILABLE 1. `@StatusCodeOut` (varchar(40) OUTPUT) beginnt AVAILABLE und meldet bei erkannten Grenzen INVALID_PARAMETER, TARGET_UNAVAILABLE, DISABLED, STOPPED_SIZE_BUDGET oder SKIPPED_NOT_DUE; RUNNING ist nur ein persistierter CaptureRun-Zustand, kein OUTPUT-Status. `@ErrorMessageOut` (nvarchar(2048) OUTPUT) ist NULL oder erläutert einen erkannten Statuspfad. Native SQL-Fehler sind nicht generell in diese Werte übersetzt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.'
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT [SkillMarkdown]'
            + NCHAR(10)
            + N'FROM [monitor_metadata].[VW_ObjectUsageSkills]'
            + NCHAR(10)
            + N'WHERE [SchemaName]=N''snapshot'' AND [ObjectName]=N''InternalPrepareCollectionCycle'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [snapshot].[InternalPrepareCollectionCycle] @SourceDatabaseName=NULL, @SchedulerType=NULL, @RunEvenIfNotDue=NULL, @CaptureRunIdOut=NULL, @ShouldCollectOut=NULL, @StatusCodeOut=NULL, @ErrorMessageOut=NULL, @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'`@SchedulerType` varchar(16); Default: Kein Default. Weglassen ist nicht zulässig. MANUAL (manueller Aufruf),'
            + NCHAR(10)
            + N'EXTERNAL (externer Scheduler), SQL_AGENT (SQL Server Agent). Nur Herkunftslabel;'
            + NCHAR(10)
            + N'startet oder prüft keinen Scheduler. Keine explizite Normalisierung. NULL,'
            + NCHAR(10)
            + N'Leertext oder ein anderer Wert kann beim INSERT an NOT NULL/CHECK scheitern'
            + NCHAR(10)
            + N'(nativer SQL-Fehler, kein INVALID_PARAMETER); ohne'
            + NCHAR(10)
            + N'INSERT bleibt der Wert ungenutzt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Objekt       : snapshot.InternalPrepareCollectionCycle'
            + NCHAR(10)
            + N'Version      : 1.2.0'
            + NCHAR(10)
            + N'Stand        : 2026-10-26'
            + NCHAR(10)
            + N'Zweck        : Prüft Zielidentität, Collectorvertrag, Aktivierung, Datenbudget'
            + NCHAR(10)
            + N'               und Fälligkeit; eröffnet abhängig vom Collector einen Lauf.'
            + NCHAR(10)
            + N'==============================================================================='
            + NCHAR(10)
            + NCHAR(10)
            + N'Schnittstelle und Parameter'
            + NCHAR(10)
            + N'---------------------------'
            + NCHAR(10)
            + N'`@SourceDatabaseName` sysname; Default: Kein Default. Weglassen ist nicht zulässig. Obligatorischer Rohname'
            + NCHAR(10)
            + N'der Quellmetadaten, ohne Datenbankwechsel oder Datenbanklookup. Leertext wird unverändert gespeichert; NULL scheitert bei einem tatsächlich ausgeführten INSERT an'
            + NCHAR(10)
            + N'NOT NULL. Ohne INSERT wird er nicht geschrieben; das Argument bleibt Pflicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'`@SchedulerType` varchar(16); Default: Kein Default. Weglassen ist nicht zulässig. MANUAL (manueller Aufruf),'
            + NCHAR(10)
            + N'EXTERNAL (externer Scheduler), SQL_AGENT (SQL Server Agent). Nur Herkunftslabel;'
            + NCHAR(10)
            + N'startet oder prüft keinen Scheduler. Keine explizite Normalisierung. NULL,'
            + NCHAR(10)
            + N'Leertext oder ein anderer Wert kann beim INSERT an NOT NULL/CHECK scheitern'
            + NCHAR(10)
            + N'(nativer SQL-Fehler, kein INVALID_PARAMETER); ohne'
            + NCHAR(10)
            + N'INSERT bleibt der Wert ungenutzt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'`@RunEvenIfNotDue` bit; Default: Kein Default. Weglassen ist nicht zulässig. 0 prüft Fälligkeit, 1 umgeht nur'
            + NCHAR(10)
            + N'die Due-Prüfung. Leertext ist keine unterstützte Eingabe. NULL wird nicht validiert und umgeht wegen des Tests = 0'
            + NCHAR(10)
            + N'ebenfalls die Prüfung. Disabled-, Budget- und Target-Gates bleiben wirksam.'
            + NCHAR(10)
            + NCHAR(10)
            + N'`@CaptureRunIdOut` bigint OUTPUT; Default: Kein Default. Weglassen ist nicht zulässig. Beim Eintritt NULL;'
            + NCHAR(10)
            + N'Eingangswert ignoriert. Ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang eine gebundene Variable als OUTPUT-Argument angeben. Zuweisung erst nach CaptureRun-INSERT. PERFORMANCE_COUNTERS legt'
            + NCHAR(10)
            + N'bei Disabled-, Budget- oder Due-Abbruch einen beendeten partiellen Lauf samt'
            + NCHAR(10)
            + N'ModuleStatus an; ID beweist keine Sammlung. WAIT_STATS/FILE_IO liefern bei'
            + NCHAR(10)
            + N'frühem Abbruch keine ID. PolicyOnly=1 legt nie einen Lauf an.'
            + NCHAR(10)
            + NCHAR(10)
            + N'`@ShouldCollectOut` bit OUTPUT; Default: Kein Default. Weglassen ist nicht zulässig. Beim Eintritt 0;'
            + NCHAR(10)
            + N'Eingangswert ignoriert. Ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang eine gebundene Variable als OUTPUT-Argument angeben.'
            + NCHAR(10)
            + N'Nach INSERT nur bei AVAILABLE 1; PolicyOnly bleibt immer 0.'
            + NCHAR(10)
            + NCHAR(10)
            + N'`@StatusCodeOut` varchar(40) OUTPUT; Default: Kein Default. Weglassen ist nicht zulässig. Eintritt AVAILABLE;'
            + NCHAR(10)
            + N'Eingangswert ignoriert. Ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang eine gebundene Variable als OUTPUT-Argument angeben.'
            + NCHAR(10)
            + N'Ausgaben genau: AVAILABLE (Admission bereit), INVALID_PARAMETER (Collector,'
            + NCHAR(10)
            + N'PolicyOnly-Kombination oder Wait-Transaktionszustand ungültig),'
            + NCHAR(10)
            + N'TARGET_UNAVAILABLE (Ziel/erforderlicher Vertrag fehlt), DISABLED (Policy'
            + NCHAR(10)
            + N'deaktiviert/fehlt), STOPPED_SIZE_BUDGET (Softbudget überschritten),'
            + NCHAR(10)
            + N'SKIPPED_NOT_DUE (Intervall nicht abgelaufen). RUNNING ist nur der Status der'
            + NCHAR(10)
            + N'eingefügten CaptureRun-Zeile, kein Ausgabe-Status. Native Fehler werden nicht'
            + NCHAR(10)
            + N'allgemein in diese Statuswerte übersetzt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'`@ErrorMessageOut` nvarchar(2048) OUTPUT; Default: Kein Default. Weglassen ist nicht zulässig. Eintritt NULL;'
            + NCHAR(10)
            + N'Eingangswert ignoriert. Ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang eine gebundene Variable als OUTPUT-Argument angeben.'
            + NCHAR(10)
            + N'Diagnose eines erkannten Statuspfads oder NULL; native SQL-Fehler können'
            + NCHAR(10)
            + N'direkt abbrechen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'`@CollectorCode` varchar(64); Default: PERFORMANCE_COUNTERS. Weglassen verwendet den Default. Einzelcode;'
            + NCHAR(10)
            + N'NULL wird leer, dann UPPER und äußere U+0020-Leerzeichen entfernt. Zulässig:'
            + NCHAR(10)
            + N'PERFORMANCE_COUNTERS (Performance Counter), WAIT_STATS (Wait-Statistiken),'
            + NCHAR(10)
            + N'FILE_IO (Datei-I/O). Leertext/anderer normalisierter Wert ergibt'
            + NCHAR(10)
            + N'INVALID_PARAMETER.'
            + NCHAR(10)
            + NCHAR(10)
            + N'`@ExpectedTargetDatabaseId` int; Default: NULL. Weglassen verwendet NULL. Teil der Zielidentität. NULL'
            + NCHAR(10)
            + N'nur im identitätslosen PERFORMANCE_COUNTERS-Fall; sobald eine Komponente'
            + NCHAR(10)
            + N'gesetzt ist und bei WAIT_STATS/FILE_IO alle drei Angaben erforderlich. ID >4,'
            + NCHAR(10)
            + N'die ID muss DB_ID() der aktuellen Datenbank entsprechen; Ziel in master online und beschreibbar. Leertext ist keine unterstützte Ganzzahleingabe.'
            + NCHAR(10)
            + N'Abweichung ergibt TARGET_UNAVAILABLE.'
            + NCHAR(10)
            + NCHAR(10)
            + N'`@ExpectedTargetDatabaseName` sysname; Default: NULL. Weglassen verwendet den Default. Rohname der Zielidentität,'
            + NCHAR(10)
            + N'binär verglichen. NULL nur beim identitätslosen PERFORMANCE_COUNTERS-Fall;'
            + NCHAR(10)
            + N'sonst alle drei Werte Pflicht. Leertext passt nicht und ergibt'
            + NCHAR(10)
            + N'TARGET_UNAVAILABLE.'
            + NCHAR(10)
            + NCHAR(10)
            + N'`@ExpectedTargetCreateDate` datetime; Default: NULL. Weglassen verwendet den Default. Ein typisierter datetime-Wert aus master.sys.databases.create_date, ohne UTC-Konvertierung; Leertext ist keine unterstützte Datumsangabe. NULL nur beim identitätslosen PERFORMANCE_COUNTERS-Fall;'
            + NCHAR(10)
            + N'sonst alle drei Werte Pflicht. Abweichung ergibt TARGET_UNAVAILABLE.'
            + NCHAR(10)
            + NCHAR(10)
            + N'`@PolicyOnly` bit; Default: 0. Weglassen verwendet den Default. 0 normaler Admission-Pfad mit Budgetermittlung'
            + NCHAR(10)
            + N'und vorgesehenen Writes. 1 nur WAIT_STATS/FILE_IO: Enabled und Due aus'
            + NCHAR(10)
            + N'abgeschlossener Historie prüfen. Der SoftBudgetMB-Policywert wird zuvor'
            + NCHAR(10)
            + N'mit der Policyquelle gelesen; Dateigrößenmessung, Budgetvergleich und Writes entfallen; keine'
            + NCHAR(10)
            + N'Run-ID, ShouldCollect bleibt 0, auch bei AVAILABLE. NULL ergibt'
            + NCHAR(10)
            + N'INVALID_PARAMETER; leerer Text ist keine unterstützte Eingabe. Wait-/File-Aufrufe erfordern auch hier keine'
            + NCHAR(10)
            + N'Callertransaktion und keine aktivierten impliziten Transaktionen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Verhalten und Grenzen'
            + NCHAR(10)
            + N'---------------------'
            + NCHAR(10)
            + N'Erste Parameterprüfung liefert zusätzlich RETURN 51011. WAIT_STATS/FILE_IO'
            + NCHAR(10)
            + N'prüfen den installierten SC-023-Vertrag: genau eine PackageVersion mit'
            + NCHAR(10)
            + N'1.2.1/Schema 2 oder 1.3.0 beziehungsweise 1.3.1/Schema 3, außerdem'
            + NCHAR(10)
            + N'InternalCompleteWaitStatsCycle und Parameter `@ContractOnly` von'
            + NCHAR(10)
            + N'InternalPurgeExpiredData. FILE_IO benötigt zusätzlich 1.3.1/Schema 3.'
            + NCHAR(10)
            + N'Die Prüfung führt kein Purge aus.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Das Budget berechnet SUM(size) aus sys.database_files für type=0,'
            + NCHAR(10)
            + N'multipliziert mit 8.0 und dividiert durch 1024.0. Das sind allokierte'
            + NCHAR(10)
            + N'Datendatei-MB der aktuellen Datenbank. Logdateien gehen nicht in die Summe'
            + NCHAR(10)
            + N'ein; der Wert misst keine tatsächlich belegten Snapshot- oder Payloadbytes. Nur strikt größer stoppt; Gleichheit passiert. Due verwendet die jüngste'
            + NCHAR(10)
            + N'CaptureRun-ID mit EndedAtUtc. PERFORMANCE_COUNTERS zählt nur AVAILABLE/PARTIAL;'
            + NCHAR(10)
            + N'WAIT_STATS, FILE_IO und PolicyOnly jeden beendeten Lauf. RunEvenIfNotDue=1'
            + NCHAR(10)
            + N'übergeht allein diese Prüfung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'WAIT_STATS/FILE_IO kehren bei Nicht-AVAILABLE vor dem INSERT ohne Lauf zurück.'
            + NCHAR(10)
            + N'PERFORMANCE_COUNTERS schreibt bei Disabled, Budgetstopp oder Due-Skip einen'
            + NCHAR(10)
            + N'beendeten partiellen Lauf plus ModuleStatus ohne Quellread. PolicyOnly schreibt'
            + NCHAR(10)
            + N'nie. Keine eigene Transaktion, kein CATCH, keine Reservierung/Serialisierung;'
            + NCHAR(10)
            + N'Mehrstatement-Schreiben kann bei nativen Fehlern partiell sein. Keine global'
            + NCHAR(10)
            + N'exakt einmalige Admission.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown]
UNION ALL
SELECT CONVERT(sysname,N'snapshot') AS [SchemaName],CONVERT(sysname,N'InternalPurgeExpiredData') AS [ObjectName],CONVERT(varchar(24),'INTERNAL_PROCEDURE') AS [ObjectType],CONVERT(varchar(24),'snapshot_target') AS [DatabaseRole],CONVERT(bit,1) AS [IsInternal],CONVERT(nvarchar(max),N'Löscht Snapshotdaten in begrenzten Batches.') AS [Description],CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "snapshot.InternalPurgeExpiredData"'
            + NCHAR(10)
            + N'schema_name: "snapshot"'
            + NCHAR(10)
            + N'object_name: "InternalPurgeExpiredData"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "snapshot_target"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Löscht Snapshotdaten in begrenzten Batches."'
            + NCHAR(10)
            + N'source_path: "Code/10_SnapshotBaseline/070_InternalPurgeExpiredData.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# snapshot.InternalPurgeExpiredData'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Löscht Snapshotdaten in begrenzten Batches. Ablaufzeiten gelten für Messwerte, Payloads und zugehörige Läufe; verwaiste Scopes ungleich SERVER werden ohne Altersprüfung entfernt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [snapshot].[InternalPurgeExpiredData]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `master.sys.databases`, `[master].[sys].[databases]`, `[snapshot].[PackageVersion]`, `[snapshot].[RetentionPolicy]`, `[snapshot].[PurgeRun]`, `[sys].[database_files]`, `[snapshot].[MetricSample]`, `[snapshot].[PayloadSnapshot]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| @MaxBatches | int | ja | kein Default |'
            + NCHAR(10)
            + N'| @Force | bit | ja | kein Default |'
            + NCHAR(10)
            + N'| @PurgeRunIdOut | bigint OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @StatusCodeOut | varchar(40) OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @BudgetExceededOut | bit OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @ErrorNumberOut | int OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @ErrorMessageOut | nvarchar(2048) OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @ContractOnly | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @RetentionContractVersionOut | int OUTPUT | nein | NULL |'
            + NCHAR(10)
            + N'| @ExpectedTargetDatabaseId | int | nein | NULL |'
            + NCHAR(10)
            + N'| @ExpectedTargetDatabaseName | sysname | nein | NULL |'
            + NCHAR(10)
            + N'| @ExpectedTargetCreateDate | datetime | nein | NULL |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxBatches:** - @MaxBatches (int; Default: Kein Default): erforderliches Argument; Nicht-NULL als ganze Zahl 1 bis 1000. NULL macht die BETWEEN-Prüfung UNKNOWN und löst den Guard nicht aus. Falls keine frühere Rückkehr erfolgt, kann ein Receipt entstehen, die Schleife läuft nullmal und der Status kann AVAILABLE sein. Ein Nicht-NULL-Wert außerhalb 1 bis 1000 setzt INVALID_PARAMETER; ErrorNumber bleibt NULL. Leertext ist keine unterstützte Zahleneingabe. Begrenzt Schleifeniterationen, nicht Zeilen je Iteration. Bei ContractOnly=1 ignoriert, dennoch erforderlich.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Force:** - @Force (bit; Default: Kein Default): erforderlich; Werte 0 und 1, NULL wird nicht abgewiesen. Leertext ist keine unterstützte Bit-Eingabe. 0 überspringt nur, wenn zugeteilte Kapazität der Datenbankdateien Typ 0 innerhalb des Budgets liegt, ein früherer erfolgreicher Lauf AVAILABLE oder AVAILABLE_LIMITED existiert und sein Intervall noch läuft. 1 umgeht diese Überspringprüfung; NULL erfüllt Force=0 ebenfalls nicht und umgeht sie damit auch. Bei ContractOnly=1 ignoriert. Force ändert nur die Skip-Berechtigung. Es lockert keine Retention-Grenze für Messwerte, Payloads oder Läufe; die Scope-Bereinigung bleibt altersunabhängig.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PurgeRunIdOut:** - @PurgeRunIdOut (bigint OUTPUT; Default: Kein Default): erforderlich zu übergeben, auch wenn verworfen; Der gebundene Anfangswert einschließlich NULL oder Leertext wird ignoriert; anfänglich NULL. Bei normalem Lauf wird die Receipt-ID nach Vorprüfungen gesetzt; sie belegt keinen Erfolg. Bei Handshake, Skip oder frühem Abbruch bleibt sie NULL. MaxBatches= NULL kann nach Receipt-INSERT null Iterationen und AVAILABLE ergeben; ein Nicht-NULL-Bereichsfehler kehrt vor Receipt-Erstellung zurück. Empfang bigint oder kompatibel. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCodeOut:** - @StatusCodeOut (varchar(40) OUTPUT; Default: Kein Default): erforderlich zu übergeben; Der gebundene Anfangswert einschließlich NULL oder Leertext wird ignoriert; anfangs AVAILABLE, später ggf. dokumentierter Status. Ein regulär erfolgreicher Handshake belässt AVAILABLE; frühe Guards können andere Statuswerte setzen. Empfang varchar(40) oder kompatibel. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@BudgetExceededOut:** - @BudgetExceededOut (bit OUTPUT; Default: Kein Default): erforderlich zu übergeben; Der gebundene Anfangswert einschließlich NULL oder Leertext wird ignoriert; anfangs 0. Bei Handshake oder frühem ungültigem Abbruch kann 0 „nicht gemessen“ bedeuten. Beim normalen Abschluss bedeutet 1, dass die allokierte Typ-0-Dateikapazität nachher strikt über SoftBudgetMB liegt, sonst 0. Beim Intervallskip stützt sich 0 auf den Vorwert; im CATCH ist 1 konservativ und keine Messung. Empfang bit oder kompatibel. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorNumberOut:** - @ErrorNumberOut (int OUTPUT; Default: Kein Default): erforderlich zu übergeben; Der gebundene Anfangswert einschließlich NULL oder Leertext wird ignoriert; anfangs NULL, bei behandelten Fehlern Fehlernummer. Bei MaxBatches-Bereichsverletzung bleibt NULL. Empfang int oder kompatibel. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessageOut:** - @ErrorMessageOut (nvarchar(2048) OUTPUT; Default: Kein Default): erforderlich zu übergeben; Der gebundene Anfangswert einschließlich NULL oder Leertext wird ignoriert; anfangs NULL, bei behandelten Fehlern SQL-Fehlertext oder Guard-Meldung. Empfang Unicode-Variable mit bis 2048 Zeichen. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ContractOnly:** - @ContractOnly (bit; Default: 0): optional, auslassbar; Werte 0, 1 oder NULL; Leertext ist keine unterstützte Bit-Eingabe. 0 normaler Purge; NULL INVALID_PARAMETER und RETURN 51011. 1 nur Versions-Handshake: keine Löschung, kein PurgeRun-Receipt, keine Budgetgrößenmessung; liest PackageVersion und gegebenenfalls Identitätsmetadaten und setzt NOCOUNT sowie LOCK_TIMEOUT 0. Handshake erfordert IMPLICIT_TRANSACTIONS OFF. Kein @@TRANCOUNT-Guard für explizite Caller-Transaktionen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@RetentionContractVersionOut:** - @RetentionContractVersionOut (int OUTPUT; Default: NULL): optional, auslassbar oder zum Empfang bindbar. NULL-Eingabe erlaubt; Leertext ist keine unterstützte Zahleneingabe. Eingabewert ignoriert; zunächst 1, dann 3, wenn irgendeine PackageVersion-Zeile SchemaVersion 3 und PackageVersion 1.2.2, 1.3.0 oder 1.3.1 hat, sonst 1. Auslassen verwirft Ausgabe. Ausgabe 1 beweist nicht SchemaVersion 1; 3 keine vollständige Zielqualifikation. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ExpectedTargetDatabaseId:** - @ExpectedTargetDatabaseId (int): Default NULL; optional. Weglassen verwendet NULL. Erwartet eine ganze Datenbank-ID größer als 4, die DB_ID() der aktuell verbundenen Datenbank entspricht; Leertext ist keine vorgesehene Zahlenform. Alle drei Identitätswerte dürfen NULL sein, auch im Handshake; sobald irgendein Feld gesetzt ist, müssen alle drei zur gleichen online und schreibbaren Zieldatenbank passen. Sonst folgen TARGET_UNAVAILABLE und 53764. Die Datenbank wird nicht gewechselt. IMPLICIT_TRANSACTIONS OFF wird bei ContractOnly=1 oder irgendeinem gesetzten Identitätsfeld verlangt; für ContractOnly=0 mit allen drei NULL gibt es diesen Guard nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ExpectedTargetDatabaseName:** - @ExpectedTargetDatabaseName (sysname): Default NULL; optional. Weglassen verwendet NULL. Erwartet den rohen Datenbanknamen als sysname-Wert, der ohne Trimmen oder Schreibweisennormalisierung binär mit master.sys.databases.name übereinstimmt; Leertext passt nicht. Alle drei Identitätswerte dürfen NULL sein, auch im Handshake; bei irgendeinem gesetzten Feld müssen alle drei vorliegen und zur online und schreibbaren aktuellen Datenbank passen. Sonst folgen TARGET_UNAVAILABLE und 53764. Kein Datenbankwechsel. IMPLICIT_TRANSACTIONS OFF wird bei ContractOnly=1 oder einem gesetzten Identitätsfeld verlangt; bei ContractOnly=0 und vollständigem NULL-Tripel gibt es diesen Guard nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ExpectedTargetCreateDate:** - @ExpectedTargetCreateDate (datetime): Default NULL; optional. Weglassen verwendet NULL. Erwartet den typisierten datetime-Wert von master.sys.databases.create_date der Zieldatenbank, ohne UTC-Konvertierung; Leertext ist keine vorgesehene Datumsform. Alle drei Identitätswerte dürfen NULL sein, auch im Handshake; bei irgendeinem gesetzten Feld müssen alle drei zur online und schreibbaren aktuellen Datenbank passen. Eine Abweichung ergibt TARGET_UNAVAILABLE und 53764. Kein Datenbankwechsel. IMPLICIT_TRANSACTIONS OFF wird bei ContractOnly=1 oder einem gesetzten Identitätsfeld verlangt; bei ContractOnly=0 und vollständigem NULL-Tripel gibt es diesen Guard nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Im Normalpfad wird kein fachliches Resultset ausgegeben. Die erforderlichen OUTPUT-Argumente melden `@PurgeRunIdOut` (bigint: Receipt-ID nach Vorprüfungen oder NULL bei Handshake, Skip und frühem Abbruch), `@StatusCodeOut` (varchar(40): Status, anfangs AVAILABLE), `@BudgetExceededOut` (bit: Budgetkennzeichen, bei frühem Abbruch nicht zwingend gemessen), `@ErrorNumberOut` (int) und `@ErrorMessageOut` (nvarchar(2048)) für erkannte Fehler. Das optionale `@RetentionContractVersionOut` (int OUTPUT) meldet zunächst 1 und bei den bekannten Schema-3-Paketständen 3; diese Zahl allein belegt keine vollständige Zielqualifikation. `@ContractOnly=1` ist ein Versions-Handshake ohne Löschung oder Purge-Receipt. Normale Läufe löschen in begrenzten Batches und können persistente Snapshotdaten ändern.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.'
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT [SkillMarkdown]'
            + NCHAR(10)
            + N'FROM [monitor_metadata].[VW_ObjectUsageSkills]'
            + NCHAR(10)
            + N'WHERE [SchemaName]=N''snapshot'' AND [ObjectName]=N''InternalPurgeExpiredData'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [snapshot].[InternalPurgeExpiredData] @MaxBatches=NULL, @Force=NULL, @PurgeRunIdOut=NULL, @StatusCodeOut=NULL, @BudgetExceededOut=NULL, @ErrorNumberOut=NULL, @ErrorMessageOut=NULL, @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'- @MaxBatches (int; Default: Kein Default): erforderliches Argument; Nicht-NULL als ganze Zahl 1 bis 1000. NULL macht die BETWEEN-Prüfung UNKNOWN und löst den Guard nicht aus. Falls keine frühere Rückkehr erfolgt, kann ein Receipt entstehen, die Schleife läuft nullmal und der Status kann AVAILABLE sein. Ein Nicht-NULL-Wert außerhalb 1 bis 1000 setzt INVALID_PARAMETER; ErrorNumber bleibt NULL. Leertext ist keine unterstützte Zahleneingabe. Begrenzt Schleifeniterationen, nicht Zeilen je Iteration. Bei ContractOnly=1 ignoriert, dennoch erforderlich.'
            + NCHAR(10)
            + N'- @Force (bit; Default: Kein Default): erforderlich; Werte 0 und 1, NULL wird nicht abgewiesen. Leertext ist keine unterstützte Bit-Eingabe. 0 überspringt nur, wenn zugeteilte Kapazität der Datenbankdateien Typ 0 innerhalb des Budgets liegt, ein früherer erfolgreicher Lauf AVAILABLE oder AVAILABLE_LIMITED existiert und sein Intervall noch läuft. 1 umgeht diese Überspringprüfung; NULL erfüllt Force=0 ebenfalls nicht und umgeht sie damit auch. Bei ContractOnly=1 ignoriert. Force ändert nur die Skip-Berechtigung. Es lockert keine Retention-Grenze für Messwerte, Payloads oder Läufe; die Scope-Bereinigung bleibt altersunabhängig.'
            + NCHAR(10)
            + N'- @PurgeRunIdO'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Objekt       : snapshot.InternalPurgeExpiredData'
            + NCHAR(10)
            + N'Version      : 1.1.0'
            + NCHAR(10)
            + N'Stand        : 2026-10-25'
            + NCHAR(10)
            + N'Zweck        : Löscht Snapshotdaten in begrenzten Batches. Ablaufzeiten gelten'
            + NCHAR(10)
            + N'               für Messwerte, Payloads und zugehörige Läufe; verwaiste Scopes'
            + NCHAR(10)
            + N'               ungleich SERVER werden ohne Altersprüfung entfernt.'
            + NCHAR(10)
            + N'==============================================================================='
            + NCHAR(10)
            + NCHAR(10)
            + N'#### InternalPurgeExpiredData – Parameterverträge'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die ersten sieben Argumente müssen übergeben werden. OUTPUT-Argumente dürfen ohne OUTPUT-Kennzeichnung gebunden werden, wenn die Ausgabe verworfen wird; zum Empfang sind Variable und OUTPUT-Kennzeichnung erforderlich. Eingehende Werte aller OUTPUT-Parameter, auch NULL oder Leertext, werden ignoriert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'- @MaxBatches (int; Default: Kein Default): erforderliches Argument; Nicht-NULL als ganze Zahl 1 bis 1000. NULL macht die BETWEEN-Prüfung UNKNOWN und löst den Guard nicht aus. Falls keine frühere Rückkehr erfolgt, kann ein Receipt entstehen, die Schleife läuft nullmal und der Status kann AVAILABLE sein. Ein Nicht-NULL-Wert außerhalb 1 bis 1000 setzt INVALID_PARAMETER; ErrorNumber bleibt NULL. Leertext ist keine unterstützte Zahleneingabe. Begrenzt Schleifeniterationen, nicht Zeilen je Iteration. Bei ContractOnly=1 ignoriert, dennoch erforderlich.'
            + NCHAR(10)
            + N'- @Force (bit; Default: Kein Default): erforderlich; Werte 0 und 1, NULL wird nicht abgewiesen. Leertext ist keine unterstützte Bit-Eingabe. 0 überspringt nur, wenn zugeteilte Kapazität der Datenbankdateien Typ 0 innerhalb des Budgets liegt, ein früherer erfolgreicher Lauf AVAILABLE oder AVAILABLE_LIMITED existiert und sein Intervall noch läuft. 1 umgeht diese Überspringprüfung; NULL erfüllt Force=0 ebenfalls nicht und umgeht sie damit auch. Bei ContractOnly=1 ignoriert. Force ändert nur die Skip-Berechtigung. Es lockert keine Retention-Grenze für Messwerte, Payloads oder Läufe; die Scope-Bereinigung bleibt altersunabhängig.'
            + NCHAR(10)
            + N'- @PurgeRunIdOut (bigint OUTPUT; Default: Kein Default): erforderlich zu übergeben, auch wenn verworfen; Der gebundene Anfangswert einschließlich NULL oder Leertext wird ignoriert; anfänglich NULL. Bei normalem Lauf wird die Receipt-ID nach Vorprüfungen gesetzt; sie belegt keinen Erfolg. Bei Handshake, Skip oder frühem Abbruch bleibt sie NULL. MaxBatches= NULL kann nach Receipt-INSERT null Iterationen und AVAILABLE ergeben; ein Nicht-NULL-Bereichsfehler kehrt vor Receipt-Erstellung zurück. Empfang bigint oder kompatibel.'
            + NCHAR(10)
            + N'- @StatusCodeOut (varchar(40) OUTPUT; Default: Kein Default): erforderlich zu übergeben; Der gebundene Anfangswert einschließlich NULL oder Leertext wird ignoriert; anfangs AVAILABLE, später ggf. dokumentierter Status. Ein regulär erfolgreicher Handshake belässt AVAILABLE; frühe Guards können andere Statuswerte setzen. Empfang varchar(40) oder kompatibel.'
            + NCHAR(10)
            + N'- @BudgetExceededOut (bit OUTPUT; Default: Kein Default): erforderlich zu übergeben; Der gebundene Anfangswert einschließlich NULL oder Leertext wird ignoriert; anfangs 0. Bei Handshake oder frühem ungültigem Abbruch kann 0 „nicht gemessen“ bedeuten. Beim normalen Abschluss bedeutet 1, dass die allokierte Typ-0-Dateikapazität nachher strikt über SoftBudgetMB liegt, sonst 0. Beim Intervallskip stützt sich 0 auf den Vorwert; im CATCH ist 1 konservativ und keine Messung. Empfang bit oder kompatibel.'
            + NCHAR(10)
            + N'- @ErrorNumberOut (int OUTPUT; Default: Kein Default): erforderlich zu übergeben; Der gebundene Anfangswert einschließlich NULL oder Leertext wird ignoriert; anfangs NULL, bei behandelten Fehlern Fehlernummer. Bei MaxBatches-Bereichsverletzung bleibt NULL. Empfang int oder kompatibel.'
            + NCHAR(10)
            + N'- @ErrorMessageOut (nvarchar(2048) OUTPUT; Default: Kein Default): erforderlich zu übergeben; Der gebundene Anfangswert einschließlich NULL oder Leertext wird ignoriert; anfangs NULL, bei behandelten Fehlern SQL-Fehlertext oder Guard-Meldung. Empfang Unicode-Variable mit bis 2048 Zeichen.'
            + NCHAR(10)
            + N'- @ContractOnly (bit; Default: 0): optional, auslassbar; Werte 0, 1 oder NULL; Leertext ist keine unterstützte Bit-Eingabe. 0 normaler Purge; NULL INVALID_PARAMETER und RETURN 51011. 1 nur Versions-Handshake: keine Löschung, kein PurgeRun-Receipt, keine Budgetgrößenmessung; liest PackageVersion und gegebenenfalls Identitätsmetadaten und setzt NOCOUNT sowie LOCK_TIMEOUT 0. Handshake erfordert IMPLICIT_TRANSACTIONS OFF. Kein @@TRANCOUNT-Guard für explizite Caller-Transaktionen.'
            + NCHAR(10)
            + N'- @RetentionContractVersionOut (int OUTPUT; Default: NULL): optional, auslassbar oder zum Empfang bindbar. NULL-Eingabe erlaubt; Leertext ist keine unterstützte Zahleneingabe. Eingabewert ignoriert; zunächst 1, dann 3, wenn irgendeine PackageVersion-Zeile SchemaVersion 3 und PackageVersion 1.2.2, 1.3.0 oder 1.3.1 hat, sonst 1. Auslassen verwirft Ausgabe. Ausgabe 1 beweist nicht SchemaVersion 1; 3 keine vollständige Zielqualifikation.'
            + NCHAR(10)
            + N'- @ExpectedTargetDatabaseId (int): Default NULL; optional. Weglassen verwendet NULL. Erwartet eine ganze Datenbank-ID größer als 4, die DB_ID() der aktuell verbundenen Datenbank entspricht; Leertext ist keine vorgesehene Zahlenform. Alle drei Identitätswerte dürfen NULL sein, auch im Handshake; sobald irgendein Feld gesetzt ist, müssen alle drei zur gleichen online und schreibbaren Zieldatenbank passen. Sonst folgen TARGET_UNAVAILABLE und 53764. Die Datenbank wird nicht gewechselt. IMPLICIT_TRANSACTIONS OFF wird bei ContractOnly=1 oder irgendeinem gesetzten Identitätsfeld verlangt; für ContractOnly=0 mit allen drei NULL gibt es diesen Guard nicht.'
            + NCHAR(10)
            + N'- @ExpectedTargetDatabaseName (sysname): Default NULL; optional. Weglassen verwendet NULL. Erwartet den rohen Datenbanknamen als sysname-Wert, der ohne Trimmen oder Schreibweisennormalisierung binär mit master.sys.databases.name übereinstimmt; Leertext passt nicht. Alle drei Identitätswerte dürfen NULL sein, auch im Handshake; bei irgendeinem gesetzten Feld müssen alle drei vorliegen und zur online und schreibbaren aktuellen Datenbank passen. Sonst folgen TARGET_UNAVAILABLE und 53764. Kein Datenbankwechsel. IMPLICIT_TRANSACTIONS OFF wird bei ContractOnly=1 oder einem gesetzten Identitätsfeld verlangt; bei ContractOnly=0 und vollständigem NULL-Tripel gibt es diesen Guard nicht.'
            + NCHAR(10)
            + N'- @ExpectedTargetCreateDate (datetime): Default NULL; optional. Weglassen verwendet NULL. Erwartet den typisierten datetime-Wert von master.sys.databases.create_date der Zieldatenbank, ohne UTC-Konvertierung; Leertext ist keine vorgesehene Datumsform. Alle drei Identitätswerte dürfen NULL sein, auch im Handshake; bei irgendeinem gesetzten Feld müssen alle drei zur online und schreibbaren aktuellen Datenbank passen. Eine Abweichung ergibt TARGET_UNAVAILABLE und 53764. Kein Datenbankwechsel. IMPLICIT_TRANSACTIONS OFF wird bei ContractOnly=1 oder einem gesetzten Identitätsfeld verlangt; bei ContractOnly=0 und vollständigem NULL-Tripel gibt es diesen Guard nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'#### InternalPurgeExpiredData – Ausführungsvertrag'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der normale Lauf liest die DEFAULT-Aufbewahrungsrichtlinie. Messwerte folgen CollectedAtUtc/RawRetentionDays, Payloads CapturedAtUtc/PayloadRetentionDays. ModuleStatus und CaptureRun folgen StartedAtUtc/RawRetentionDays, sofern Kinddatensätze fehlen. Der neueste finalisierte WAIT_STATS-Lauf und der neueste FILE_IO-Lauf bleiben erhalten; bei FILE_IO ist Finalisierung nicht nötig. Verwaiste Scopes ungleich SERVER werden ohne Altersprüfung gelöscht. Rollups werden nicht gelöscht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Pro Iteration gilt PurgeBatchRows separat für jede Tabelle, nicht als Gesamtzeilenlimit. Jede Iteration führt BEGIN/COMMIT aus. Bei einer bestehenden Caller-Transaktion persistiert ein verschachteltes COMMIT die Iteration nicht unabhängig; ein CATCH-Rollback kann die gesamte äußere Transaktion zurückrollen. Ohne äußere Transaktion bleiben zuvor committete Iterationen bei einem späteren Fehler bestehen. Vorprüfungen, Richtlinien- und Größenlesung sowie Receipt-INSERT liegen außerhalb TRY. Das CATCH-Audit-UPDATE kann selbst fehlschlagen. Zähler können bei zurückgerollter fehlgeschlagener Iteration versuchte Zeilen enthalten.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Budgetmessung: Größen der Datenbankdateien Typ 0, Seiten zu MB umgerechnet; weder belegte Snapshot-/Payload-Bytes noch Logdateien. Kein Shrink; Budget kann nach Purge überschritten sein. Gleichheit mit SoftBudgetMB ergibt 0, nur strikt größer ergibt 1. Beim Überspringen bedeutet 0 „vorher innerhalb Budget“. CATCH setzt 1 vorsorglich, nicht als Messwert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Status- und Fehlerwerte:'
            + NCHAR(10)
            + N'- AVAILABLE: Normaler Abschluss ohne Ausschöpfung des Batches-Limits durch einen Batch mit Löschungen; der reine gültige Handshake behält den anfänglichen Wert AVAILABLE. Ein früher ungültiger Handshake-Guard kann stattdessen INVALID_PARAMETER liefern. AVAILABLE belegt keine Löschung.'
            + NCHAR(10)
            + N'- INVALID_PARAMETER: ContractOnly=NULL oder anderer früher ungültiger Guard. Ein Nicht-NULL-MaxBatches außerhalb 1 bis 1000 führt ebenfalls zu diesem Status, ohne ErrorNumber zu setzen.'
            + NCHAR(10)
            + N'- TARGET_UNAVAILABLE: Identitätsgruppe unvollständig oder Datenbank-ID, roher Name, create_date, Onlinezustand oder Schreibbarkeit stimmen nicht; ErrorNumber 53764.'
            + NCHAR(10)
            + N'- SKIPPED_NOT_DUE: Force=0 und zugeteilte Kapazität nicht über Budget, erfolgreicher Vorgängerlauf vorhanden und Intervall nicht verstrichen.'
            + NCHAR(10)
            + N'- AVAILABLE_LIMITED: Batches-Limit erreicht und letzter Batch löschte mindestens eine Zeile; kein Beleg weiterer abgelaufener Zeilen.'
            + NCHAR(10)
            + N'- DENIED_PERMISSION: CATCH erfasste Fehlernummer 229, 262, 297, 300 oder 371.'
            + NCHAR(10)
            + N'- ERROR_HANDLED: anderer im CATCH erfasster Fehler. Nicht jeder Fehler liegt im TRY/CATCH; das CATCH-Audit-UPDATE kann selbst scheitern.'
            + NCHAR(10)
            + N'RUNNING ist nur Receipt-Zustand. Gelöschte-Zeilen-Zähler im CATCH bestätigen keinen Commit.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown]
UNION ALL
SELECT CONVERT(sysname,N'snapshot') AS [SchemaName],CONVERT(sysname,N'MetricDefinition') AS [ObjectName],CONVERT(varchar(24),'TABLE') AS [ObjectType],CONVERT(varchar(24),'snapshot_target') AS [DatabaseRole],CONVERT(bit,0) AS [IsInternal],CONVERT(nvarchar(max),N'Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank.') AS [Description],CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "snapshot.MetricDefinition"'
            + NCHAR(10)
            + N'schema_name: "snapshot"'
            + NCHAR(10)
            + N'object_name: "MetricDefinition"'
            + NCHAR(10)
            + N'object_type: "TABLE"'
            + NCHAR(10)
            + N'database_role: "snapshot_target"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank."'
            + NCHAR(10)
            + N'source_path: "Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# snapshot.MetricDefinition'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank. Das Schema speichert Erfassungsläufe, Status, Scopes, typisierte Messwerte und optionale Nutzdaten. Es startet weder Sammler noch Zeitpläne oder Retention-Purges.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das Ziel und verwendet ausschließlich den geprüften Verbindungskontext.'
            + NCHAR(10)
            + NCHAR(10)
            + N'CONTROL DATABASE und VIEW ANY DEFINITION sind für die native Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Lesender Einsatz erfordert SELECT auf [snapshot].[MetricDefinition]; Installation und Aktualisierung benötigen die im Quellskript gezeigten DDL- und DML-Rechte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Keine Aufrufparameter.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Tabellenspalten und Constraints aus der eigenen CREATE-TABLE-Definition:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'('
            + NCHAR(10)
            + N'          [MetricDefinitionId] bigint IDENTITY(1,1) NOT NULL'
            + NCHAR(10)
            + N'        , [MetricCode] varchar(96) NOT NULL'
            + NCHAR(10)
            + N'        , [ValueType] varchar(24) NOT NULL'
            + NCHAR(10)
            + N'        , [Unit] varchar(40) NOT NULL'
            + NCHAR(10)
            + N'        , [ContractVersion] int NOT NULL'
            + NCHAR(10)
            + N'        , [Description] nvarchar(1000) NOT NULL'
            + NCHAR(10)
            + N'        , [IsFrameworkDefault] bit NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_MetricDefinition_IsFrameworkDefault]'
            + NCHAR(10)
            + N'              DEFAULT (0)'
            + NCHAR(10)
            + N'        , [SeedVersion] int NOT NULL'
            + NCHAR(10)
            + N'        , [LastUpdatedUtc] datetime2(3) NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_MetricDefinition_LastUpdatedUtc]'
            + NCHAR(10)
            + N'              DEFAULT (SYSUTCDATETIME())'
            + NCHAR(10)
            + N'        , CONSTRAINT [PK_snapshot_MetricDefinition]'
            + NCHAR(10)
            + N'              PRIMARY KEY CLUSTERED ([MetricDefinitionId])'
            + NCHAR(10)
            + N'        , CONSTRAINT [UQ_snapshot_MetricDefinition_MetricCode]'
            + NCHAR(10)
            + N'              UNIQUE ([MetricCode])'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_MetricDefinition_ValueType]'
            + NCHAR(10)
            + N'              CHECK ([ValueType] IN (''NUMERIC'',''BIGINT'',''STRING''))'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_MetricDefinition_ContractVersion]'
            + NCHAR(10)
            + N'              CHECK ([ContractVersion] > 0)'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_MetricDefinition_SeedVersion]'
            + NCHAR(10)
            + N'              CHECK ([SeedVersion] > 0)'
            + NCHAR(10)
            + N'    )'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT TOP (10) * FROM [snapshot].[MetricDefinition];'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Das zugehörige Installationsskript enthält CREATE TABLE, INSERT, UPDATE, DELETE; ein lesendes SELECT führt diese Installationsschritte nicht aus. Constraints und NULL-Grenzen stehen in der Tabellendefinition.'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Datei        : 030_Snapshot_Target_Schema.sql'
            + NCHAR(10)
            + N'Version      : 1.2.2'
            + NCHAR(10)
            + N'Stand        : 2026-10-26'
            + NCHAR(10)
            + N'Zweck        : Erstellt und aktualisiert das versionierte Basisschema des'
            + NCHAR(10)
            + N'               optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell'
            + NCHAR(10)
            + N'               verbundenen Datenbank. Das Schema speichert Erfassungsläufe,'
            + NCHAR(10)
            + N'               Status, Scopes, typisierte Messwerte und optionale Nutzdaten.'
            + NCHAR(10)
            + N'               Es startet weder Sammler noch Zeitpläne oder Retention-Purges.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Tabellen     : PackageVersion kennzeichnet Paket- und Schemafassung sowie'
            + NCHAR(10)
            + N'               Erstinstallation und letzten Installationslauf. RetentionPolicy'
            + NCHAR(10)
            + N'               hält Aufbewahrungsfristen für Rohwerte, Nutzdaten und Rollups,'
            + NCHAR(10)
            + N'               Speicherbudget, Purge-Takt, Batchgröße und Budgetaktion.'
            + NCHAR(10)
            + N'               CollectorPolicy beschreibt Aktivierung, Intervall, Zeilenlimit,'
            + NCHAR(10)
            + N'               Nutzdatenerfassung und zugeordnete RetentionPolicy.'
            + NCHAR(10)
            + N'               CaptureRun protokolliert Sammler, Schedulerart, Start und Ende,'
            + NCHAR(10)
            + N'               Quelldatenbankname, SQL-Server-Startzeit, Reset-Epoche,'
            + NCHAR(10)
            + N'               Vertragsfassung, Status, Partialität, Fehler und Zeilenzähler.'
            + NCHAR(10)
            + N'               ModuleStatus hält je Lauf und Modul Zeitpunkt, Status, Partial-'
            + NCHAR(10)
            + N'               und Fehlerangaben sowie Evidenzgrenzen.'
            + NCHAR(10)
            + N'               Scope ordnet Messungen über Scope-Typ, optionalen Eltern-Scope,'
            + NCHAR(10)
            + N'               32-Byte-Schlüsselhash und JSON-Identität einem Erfassungsbereich'
            + NCHAR(10)
            + N'               zu. MetricDefinition beschreibt Metrikcode, Werttyp, Einheit,'
            + NCHAR(10)
            + N'               Vertragsfassung, Text, Framework-Default und Seedfassung.'
            + NCHAR(10)
            + N'               MetricSample verbindet Lauf, Scope und Metrik mit Messzeit,'
            + NCHAR(10)
            + N'               Reset-Epoche, genau einem typisierten Wert, Qualitätscode und'
            + NCHAR(10)
            + N'               Partialitätskennzeichen. PayloadSnapshot speichert optionale,'
            + NCHAR(10)
            + N'               Modulnutzdaten mit Format, Vertragsfassung, Hash'
            + NCHAR(10)
            + N'               und unkomprimierter Zeichenanzahl. PurgeRun protokolliert'
            + NCHAR(10)
            + N'               Aufräumlauf, Status, Batches, gelöschte Zeilen, Budgetmessung'
            + NCHAR(10)
            + N'               und Fehler.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Beziehungen  : Fremdschlüssel verbinden CollectorPolicy mit RetentionPolicy,'
            + NCHAR(10)
            + N'               CaptureRun mit CollectorPolicy, ModuleStatus und PayloadSnapshot'
            + NCHAR(10)
            + N'               mit CaptureRun sowie MetricSample mit CaptureRun, Scope und'
            + NCHAR(10)
            + N'               MetricDefinition. Scope kann auf einen Eltern-Scope verweisen.'
            + NCHAR(10)
            + N'               Primär- und eindeutige Schlüssel verhindern doppelte'
            + NCHAR(10)
            + N'               Policycodes, Modulstatus je Lauf/Modul sowie Messwerte je'
            + NCHAR(10)
            + N'               Lauf/Scope/Metrik. Ein gefilterter eindeutiger Index lässt'
            + NCHAR(10)
            + N'               höchstens eine RetentionPolicy als Framework-Default zu;'
            + NCHAR(10)
            + N'               Zeit- und Zuordnungsindizes unterstützen die im Schema'
            + NCHAR(10)
            + N'               vorgesehenen Lauf-, Messwert-, Nutzdaten- und Purgeabfragen.'
            + NCHAR(10)
            + N'               Die DDL definiert keine kaskadierenden Fremdschlüssel.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Werte        : UTC-Zeitfelder geben den jeweiligen Erfassungs-, Lauf- oder'
            + NCHAR(10)
            + N'               Änderungszeitpunkt an. NULL ist bei Endzeiten, optionalen'
            + NCHAR(10)
            + N'               Start-/Resetinformationen, Fehlerfeldern und alternativen'
            + NCHAR(10)
            + N'               Messwertspalten zulässig, soweit die DDL dies festlegt.'
            + NCHAR(10)
            + N'               NumericValue, BigintValue und StringValue sind Alternativen:'
            + NCHAR(10)
            + N'               MetricSample verlangt genau einen nicht-NULL-Wert. ValueType'
            + NCHAR(10)
            + N'               und Unit in MetricDefinition beschreiben dessen Interpretation;'
            + NCHAR(10)
            + N'               der Vertrag garantiert keine Umrechnung. ResetEpochId grenzt'
            + NCHAR(10)
            + N'               Zählerstände über eine Reset-Epoche ab. QualityCode, StatusCode'
            + NCHAR(10)
            + N'               und IsPartial erhalten Qualitäts-, Ablauf- und'
            + NCHAR(10)
            + N'               Vollständigkeitsangaben. ScopeIdentityJson muss JSON sein;'
            + NCHAR(10)
            + N'               ScopeKeyHash ist genau 32 Byte lang. PayloadHash ist ebenfalls'
            + NCHAR(10)
            + N'               32 Byte lang; PayloadFormat und CompressionType sind auf die'
            + NCHAR(10)
            + N'               im Schema genannten Werte beschränkt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Migration    : Die native Vorprüfung akzeptiert nur erkannte Schemaformen.'
            + NCHAR(10)
            + N'               Für erkannte Legacy- und Schema-2-Stände erweitert sie die'
            + NCHAR(10)
            + N'               CollectorCode- und ScopeType-Prüfwerte um FILE_IO'
            + NCHAR(10)
            + N'               beziehungsweise FILE_IO_FILE. Unbekannte oder abweichende'
            + NCHAR(10)
            + N'               Strukturen werden nicht beliebig repariert oder überschrieben.'
            + NCHAR(10)
            + N'               Paketversion 1.2.2 / Schema 3 kennzeichnet Installationsmetadaten,'
            + NCHAR(10)
            + N'               nicht die Laufzeitqualifikation oder Freigabe des Pakets.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Seeds        : Neue DEFAULT-Retention-, PERFORMANCE_COUNTERS-Policy- und'
            + NCHAR(10)
            + N'               Performance-Counter-Metrikzeilen werden nur eingefügt, wenn'
            + NCHAR(10)
            + N'               ihr jeweiliger Schlüssel fehlt. Vorhandene solche Zeilen bleiben'
            + NCHAR(10)
            + N'               erhalten. PackageVersion wird für SC-023 angelegt oder auf'
            + NCHAR(10)
            + N'               Paketversion 1.2.2 und Schema 3 gesetzt; InstalledAtUtc bleibt'
            + NCHAR(10)
            + N'               bei einem vorhandenen Datensatz unverändert, während'
            + NCHAR(10)
            + N'               LastInstallerRunUtc aktualisiert wird.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Voraussetzung: Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare'
            + NCHAR(10)
            + N'               Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das'
            + NCHAR(10)
            + N'               Ziel und verwendet ausschließlich den geprüften Verbindungskontext.'
            + NCHAR(10)
            + N'Datenschutz  : Die Tabellen dürfen im autorisierten Betrieb vollständige reale'
            + NCHAR(10)
            + N'               Laufzeitevidenz einschließlich optionaler Payloads speichern.'
            + NCHAR(10)
            + N'               Dieses Installationsskript enthält nur generische Seeds und'
            + NCHAR(10)
            + N'               keine Laufzeitwerte oder Datenbanknamen.'
            + NCHAR(10)
            + N'Transaktion  : Implizite Transaktionen müssen ausgeschaltet sein. Das Skript'
            + NCHAR(10)
            + N'               verwendet bei Bedarf eine eigene Transaktion, andernfalls einen'
            + NCHAR(10)
            + N'               Savepoint. Im Fehlerfall wird die eigene Transaktion bei'
            + NCHAR(10)
            + N'               XACT_STATE() ungleich 0 zurückgerollt; im Aufruferkontext nur'
            + NCHAR(10)
            + N'               bei XACT_STATE() = 1 bis zum Savepoint. Bei XACT_STATE() = -1'
            + NCHAR(10)
            + N'               kann dieser Savepoint-Rollback nicht erfolgen; ein allgemeiner'
            + NCHAR(10)
            + N'               Rollback der Aufrufertransaktion wird nicht zugesichert.'
            + NCHAR(10)
            + N'               Die gesetzten SET-Optionen gelten für die verbundene Sitzung;'
            + NCHAR(10)
            + N'               das Skript stellt deren vorherige Werte nicht wieder her.'
            + NCHAR(10)
            + N'Locking      : Die privilegierte native Strukturvorprüfung verwendet'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT 10000 und hält geprüfte Tabellen bis zum'
            + NCHAR(10)
            + N'               Transaktionsende. Die anschließende eigene DDL verwendet'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT 0 und wartet nicht auf fremde Sch-M-Sperren.'
            + NCHAR(10)
            + N'Rechte       : CONTROL DATABASE und VIEW ANY DEFINITION sind für die native'
            + NCHAR(10)
            + N'               Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown]
UNION ALL
SELECT CONVERT(sysname,N'snapshot') AS [SchemaName],CONVERT(sysname,N'MetricSample') AS [ObjectName],CONVERT(varchar(24),'TABLE') AS [ObjectType],CONVERT(varchar(24),'snapshot_target') AS [DatabaseRole],CONVERT(bit,0) AS [IsInternal],CONVERT(nvarchar(max),N'Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank.') AS [Description],CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "snapshot.MetricSample"'
            + NCHAR(10)
            + N'schema_name: "snapshot"'
            + NCHAR(10)
            + N'object_name: "MetricSample"'
            + NCHAR(10)
            + N'object_type: "TABLE"'
            + NCHAR(10)
            + N'database_role: "snapshot_target"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank."'
            + NCHAR(10)
            + N'source_path: "Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# snapshot.MetricSample'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank. Das Schema speichert Erfassungsläufe, Status, Scopes, typisierte Messwerte und optionale Nutzdaten. Es startet weder Sammler noch Zeitpläne oder Retention-Purges.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das Ziel und verwendet ausschließlich den geprüften Verbindungskontext.'
            + NCHAR(10)
            + NCHAR(10)
            + N'CONTROL DATABASE und VIEW ANY DEFINITION sind für die native Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Lesender Einsatz erfordert SELECT auf [snapshot].[MetricSample]; Installation und Aktualisierung benötigen die im Quellskript gezeigten DDL- und DML-Rechte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Keine Aufrufparameter.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Tabellenspalten und Constraints aus der eigenen CREATE-TABLE-Definition:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'('
            + NCHAR(10)
            + N'          [MetricSampleId] bigint IDENTITY(1,1) NOT NULL'
            + NCHAR(10)
            + N'        , [CaptureRunId] bigint NOT NULL'
            + NCHAR(10)
            + N'        , [ScopeId] bigint NOT NULL'
            + NCHAR(10)
            + N'        , [MetricDefinitionId] bigint NOT NULL'
            + NCHAR(10)
            + N'        , [CollectedAtUtc] datetime2(3) NOT NULL'
            + NCHAR(10)
            + N'        , [ResetEpochId] uniqueidentifier NOT NULL'
            + NCHAR(10)
            + N'        , [NumericValue] decimal(38,6) NULL'
            + NCHAR(10)
            + N'        , [BigintValue] bigint NULL'
            + NCHAR(10)
            + N'        , [StringValue] nvarchar(4000) NULL'
            + NCHAR(10)
            + N'        , [QualityCode] varchar(80) NOT NULL'
            + NCHAR(10)
            + N'        , [IsPartial] bit NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_MetricSample_IsPartial] DEFAULT (0)'
            + NCHAR(10)
            + N'        , CONSTRAINT [PK_snapshot_MetricSample]'
            + NCHAR(10)
            + N'              PRIMARY KEY CLUSTERED ([MetricSampleId])'
            + NCHAR(10)
            + N'        , CONSTRAINT [FK_snapshot_MetricSample_CaptureRun]'
            + NCHAR(10)
            + N'              FOREIGN KEY ([CaptureRunId])'
            + NCHAR(10)
            + N'              REFERENCES [snapshot].[CaptureRun]([CaptureRunId])'
            + NCHAR(10)
            + N'        , CONSTRAINT [FK_snapshot_MetricSample_Scope]'
            + NCHAR(10)
            + N'              FOREIGN KEY ([ScopeId])'
            + NCHAR(10)
            + N'              REFERENCES [snapshot].[Scope]([ScopeId])'
            + NCHAR(10)
            + N'        , CONSTRAINT [FK_snapshot_MetricSample_MetricDefinition]'
            + NCHAR(10)
            + N'              FOREIGN KEY ([MetricDefinitionId])'
            + NCHAR(10)
            + N'              REFERENCES [snapshot].[MetricDefinition]([MetricDefinitionId])'
            + NCHAR(10)
            + N'        , CONSTRAINT [UQ_snapshot_MetricSample_RunScopeMetric]'
            + NCHAR(10)
            + N'              UNIQUE ([CaptureRunId],[ScopeId],[MetricDefinitionId])'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_MetricSample_ExactlyOneValue]'
            + NCHAR(10)
            + N'              CHECK'
            + NCHAR(10)
            + N'              ('
            + NCHAR(10)
            + N'                  (CASE WHEN [NumericValue] IS NULL THEN 0 ELSE 1 END)'
            + NCHAR(10)
            + N'                + (CASE WHEN [BigintValue] IS NULL THEN 0 ELSE 1 END)'
            + NCHAR(10)
            + N'                + (CASE WHEN [StringValue] IS NULL THEN 0 ELSE 1 END) = 1'
            + NCHAR(10)
            + N'              )'
            + NCHAR(10)
            + N'    )'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT TOP (10) * FROM [snapshot].[MetricSample];'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Das zugehörige Installationsskript enthält CREATE TABLE, INSERT, UPDATE, DELETE; ein lesendes SELECT führt diese Installationsschritte nicht aus. Constraints und NULL-Grenzen stehen in der Tabellendefinition.'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Datei        : 030_Snapshot_Target_Schema.sql'
            + NCHAR(10)
            + N'Version      : 1.2.2'
            + NCHAR(10)
            + N'Stand        : 2026-10-26'
            + NCHAR(10)
            + N'Zweck        : Erstellt und aktualisiert das versionierte Basisschema des'
            + NCHAR(10)
            + N'               optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell'
            + NCHAR(10)
            + N'               verbundenen Datenbank. Das Schema speichert Erfassungsläufe,'
            + NCHAR(10)
            + N'               Status, Scopes, typisierte Messwerte und optionale Nutzdaten.'
            + NCHAR(10)
            + N'               Es startet weder Sammler noch Zeitpläne oder Retention-Purges.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Tabellen     : PackageVersion kennzeichnet Paket- und Schemafassung sowie'
            + NCHAR(10)
            + N'               Erstinstallation und letzten Installationslauf. RetentionPolicy'
            + NCHAR(10)
            + N'               hält Aufbewahrungsfristen für Rohwerte, Nutzdaten und Rollups,'
            + NCHAR(10)
            + N'               Speicherbudget, Purge-Takt, Batchgröße und Budgetaktion.'
            + NCHAR(10)
            + N'               CollectorPolicy beschreibt Aktivierung, Intervall, Zeilenlimit,'
            + NCHAR(10)
            + N'               Nutzdatenerfassung und zugeordnete RetentionPolicy.'
            + NCHAR(10)
            + N'               CaptureRun protokolliert Sammler, Schedulerart, Start und Ende,'
            + NCHAR(10)
            + N'               Quelldatenbankname, SQL-Server-Startzeit, Reset-Epoche,'
            + NCHAR(10)
            + N'               Vertragsfassung, Status, Partialität, Fehler und Zeilenzähler.'
            + NCHAR(10)
            + N'               ModuleStatus hält je Lauf und Modul Zeitpunkt, Status, Partial-'
            + NCHAR(10)
            + N'               und Fehlerangaben sowie Evidenzgrenzen.'
            + NCHAR(10)
            + N'               Scope ordnet Messungen über Scope-Typ, optionalen Eltern-Scope,'
            + NCHAR(10)
            + N'               32-Byte-Schlüsselhash und JSON-Identität einem Erfassungsbereich'
            + NCHAR(10)
            + N'               zu. MetricDefinition beschreibt Metrikcode, Werttyp, Einheit,'
            + NCHAR(10)
            + N'               Vertragsfassung, Text, Framework-Default und Seedfassung.'
            + NCHAR(10)
            + N'               MetricSample verbindet Lauf, Scope und Metrik mit Messzeit,'
            + NCHAR(10)
            + N'               Reset-Epoche, genau einem typisierten Wert, Qualitätscode und'
            + NCHAR(10)
            + N'               Partialitätskennzeichen. PayloadSnapshot speichert optionale,'
            + NCHAR(10)
            + N'               Modulnutzdaten mit Format, Vertragsfassung, Hash'
            + NCHAR(10)
            + N'               und unkomprimierter Zeichenanzahl. PurgeRun protokolliert'
            + NCHAR(10)
            + N'               Aufräumlauf, Status, Batches, gelöschte Zeilen, Budgetmessung'
            + NCHAR(10)
            + N'               und Fehler.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Beziehungen  : Fremdschlüssel verbinden CollectorPolicy mit RetentionPolicy,'
            + NCHAR(10)
            + N'               CaptureRun mit CollectorPolicy, ModuleStatus und PayloadSnapshot'
            + NCHAR(10)
            + N'               mit CaptureRun sowie MetricSample mit CaptureRun, Scope und'
            + NCHAR(10)
            + N'               MetricDefinition. Scope kann auf einen Eltern-Scope verweisen.'
            + NCHAR(10)
            + N'               Primär- und eindeutige Schlüssel verhindern doppelte'
            + NCHAR(10)
            + N'               Policycodes, Modulstatus je Lauf/Modul sowie Messwerte je'
            + NCHAR(10)
            + N'               Lauf/Scope/Metrik. Ein gefilterter eindeutiger Index lässt'
            + NCHAR(10)
            + N'               höchstens eine RetentionPolicy als Framework-Default zu;'
            + NCHAR(10)
            + N'               Zeit- und Zuordnungsindizes unterstützen die im Schema'
            + NCHAR(10)
            + N'               vorgesehenen Lauf-, Messwert-, Nutzdaten- und Purgeabfragen.'
            + NCHAR(10)
            + N'               Die DDL definiert keine kaskadierenden Fremdschlüssel.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Werte        : UTC-Zeitfelder geben den jeweiligen Erfassungs-, Lauf- oder'
            + NCHAR(10)
            + N'               Änderungszeitpunkt an. NULL ist bei Endzeiten, optionalen'
            + NCHAR(10)
            + N'               Start-/Resetinformationen, Fehlerfeldern und alternativen'
            + NCHAR(10)
            + N'               Messwertspalten zulässig, soweit die DDL dies festlegt.'
            + NCHAR(10)
            + N'               NumericValue, BigintValue und StringValue sind Alternativen:'
            + NCHAR(10)
            + N'               MetricSample verlangt genau einen nicht-NULL-Wert. ValueType'
            + NCHAR(10)
            + N'               und Unit in MetricDefinition beschreiben dessen Interpretation;'
            + NCHAR(10)
            + N'               der Vertrag garantiert keine Umrechnung. ResetEpochId grenzt'
            + NCHAR(10)
            + N'               Zählerstände über eine Reset-Epoche ab. QualityCode, StatusCode'
            + NCHAR(10)
            + N'               und IsPartial erhalten Qualitäts-, Ablauf- und'
            + NCHAR(10)
            + N'               Vollständigkeitsangaben. ScopeIdentityJson muss JSON sein;'
            + NCHAR(10)
            + N'               ScopeKeyHash ist genau 32 Byte lang. PayloadHash ist ebenfalls'
            + NCHAR(10)
            + N'               32 Byte lang; PayloadFormat und CompressionType sind auf die'
            + NCHAR(10)
            + N'               im Schema genannten Werte beschränkt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Migration    : Die native Vorprüfung akzeptiert nur erkannte Schemaformen.'
            + NCHAR(10)
            + N'               Für erkannte Legacy- und Schema-2-Stände erweitert sie die'
            + NCHAR(10)
            + N'               CollectorCode- und ScopeType-Prüfwerte um FILE_IO'
            + NCHAR(10)
            + N'               beziehungsweise FILE_IO_FILE. Unbekannte oder abweichende'
            + NCHAR(10)
            + N'               Strukturen werden nicht beliebig repariert oder überschrieben.'
            + NCHAR(10)
            + N'               Paketversion 1.2.2 / Schema 3 kennzeichnet Installationsmetadaten,'
            + NCHAR(10)
            + N'               nicht die Laufzeitqualifikation oder Freigabe des Pakets.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Seeds        : Neue DEFAULT-Retention-, PERFORMANCE_COUNTERS-Policy- und'
            + NCHAR(10)
            + N'               Performance-Counter-Metrikzeilen werden nur eingefügt, wenn'
            + NCHAR(10)
            + N'               ihr jeweiliger Schlüssel fehlt. Vorhandene solche Zeilen bleiben'
            + NCHAR(10)
            + N'               erhalten. PackageVersion wird für SC-023 angelegt oder auf'
            + NCHAR(10)
            + N'               Paketversion 1.2.2 und Schema 3 gesetzt; InstalledAtUtc bleibt'
            + NCHAR(10)
            + N'               bei einem vorhandenen Datensatz unverändert, während'
            + NCHAR(10)
            + N'               LastInstallerRunUtc aktualisiert wird.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Voraussetzung: Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare'
            + NCHAR(10)
            + N'               Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das'
            + NCHAR(10)
            + N'               Ziel und verwendet ausschließlich den geprüften Verbindungskontext.'
            + NCHAR(10)
            + N'Datenschutz  : Die Tabellen dürfen im autorisierten Betrieb vollständige reale'
            + NCHAR(10)
            + N'               Laufzeitevidenz einschließlich optionaler Payloads speichern.'
            + NCHAR(10)
            + N'               Dieses Installationsskript enthält nur generische Seeds und'
            + NCHAR(10)
            + N'               keine Laufzeitwerte oder Datenbanknamen.'
            + NCHAR(10)
            + N'Transaktion  : Implizite Transaktionen müssen ausgeschaltet sein. Das Skript'
            + NCHAR(10)
            + N'               verwendet bei Bedarf eine eigene Transaktion, andernfalls einen'
            + NCHAR(10)
            + N'               Savepoint. Im Fehlerfall wird die eigene Transaktion bei'
            + NCHAR(10)
            + N'               XACT_STATE() ungleich 0 zurückgerollt; im Aufruferkontext nur'
            + NCHAR(10)
            + N'               bei XACT_STATE() = 1 bis zum Savepoint. Bei XACT_STATE() = -1'
            + NCHAR(10)
            + N'               kann dieser Savepoint-Rollback nicht erfolgen; ein allgemeiner'
            + NCHAR(10)
            + N'               Rollback der Aufrufertransaktion wird nicht zugesichert.'
            + NCHAR(10)
            + N'               Die gesetzten SET-Optionen gelten für die verbundene Sitzung;'
            + NCHAR(10)
            + N'               das Skript stellt deren vorherige Werte nicht wieder her.'
            + NCHAR(10)
            + N'Locking      : Die privilegierte native Strukturvorprüfung verwendet'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT 10000 und hält geprüfte Tabellen bis zum'
            + NCHAR(10)
            + N'               Transaktionsende. Die anschließende eigene DDL verwendet'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT 0 und wartet nicht auf fremde Sch-M-Sperren.'
            + NCHAR(10)
            + N'Rechte       : CONTROL DATABASE und VIEW ANY DEFINITION sind für die native'
            + NCHAR(10)
            + N'               Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown]
UNION ALL
SELECT CONVERT(sysname,N'snapshot') AS [SchemaName],CONVERT(sysname,N'ModuleStatus') AS [ObjectName],CONVERT(varchar(24),'TABLE') AS [ObjectType],CONVERT(varchar(24),'snapshot_target') AS [DatabaseRole],CONVERT(bit,0) AS [IsInternal],CONVERT(nvarchar(max),N'Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank.') AS [Description],CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "snapshot.ModuleStatus"'
            + NCHAR(10)
            + N'schema_name: "snapshot"'
            + NCHAR(10)
            + N'object_name: "ModuleStatus"'
            + NCHAR(10)
            + N'object_type: "TABLE"'
            + NCHAR(10)
            + N'database_role: "snapshot_target"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank."'
            + NCHAR(10)
            + N'source_path: "Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# snapshot.ModuleStatus'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank. Das Schema speichert Erfassungsläufe, Status, Scopes, typisierte Messwerte und optionale Nutzdaten. Es startet weder Sammler noch Zeitpläne oder Retention-Purges.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das Ziel und verwendet ausschließlich den geprüften Verbindungskontext.'
            + NCHAR(10)
            + NCHAR(10)
            + N'CONTROL DATABASE und VIEW ANY DEFINITION sind für die native Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Lesender Einsatz erfordert SELECT auf [snapshot].[ModuleStatus]; Installation und Aktualisierung benötigen die im Quellskript gezeigten DDL- und DML-Rechte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Keine Aufrufparameter.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Tabellenspalten und Constraints aus der eigenen CREATE-TABLE-Definition:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'('
            + NCHAR(10)
            + N'          [ModuleStatusId] bigint IDENTITY(1,1) NOT NULL'
            + NCHAR(10)
            + N'        , [CaptureRunId] bigint NOT NULL'
            + NCHAR(10)
            + N'        , [ModuleName] sysname NOT NULL'
            + NCHAR(10)
            + N'        , [CollectionTimeUtc] datetime2(3) NOT NULL'
            + NCHAR(10)
            + N'        , [StatusCode] varchar(40) NOT NULL'
            + NCHAR(10)
            + N'        , [IsPartial] bit NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_ModuleStatus_IsPartial] DEFAULT (0)'
            + NCHAR(10)
            + N'        , [ErrorNumber] int NULL'
            + NCHAR(10)
            + N'        , [ErrorMessage] nvarchar(2048) NULL'
            + NCHAR(10)
            + N'        , [EvidenceLimit] nvarchar(1000) NULL'
            + NCHAR(10)
            + N'        , CONSTRAINT [PK_snapshot_ModuleStatus]'
            + NCHAR(10)
            + N'              PRIMARY KEY CLUSTERED ([ModuleStatusId])'
            + NCHAR(10)
            + N'        , CONSTRAINT [FK_snapshot_ModuleStatus_CaptureRun]'
            + NCHAR(10)
            + N'              FOREIGN KEY ([CaptureRunId])'
            + NCHAR(10)
            + N'              REFERENCES [snapshot].[CaptureRun]([CaptureRunId])'
            + NCHAR(10)
            + N'        , CONSTRAINT [UQ_snapshot_ModuleStatus_RunModule]'
            + NCHAR(10)
            + N'              UNIQUE ([CaptureRunId],[ModuleName])'
            + NCHAR(10)
            + N'    )'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT TOP (10) * FROM [snapshot].[ModuleStatus];'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Das zugehörige Installationsskript enthält CREATE TABLE, INSERT, UPDATE, DELETE; ein lesendes SELECT führt diese Installationsschritte nicht aus. Constraints und NULL-Grenzen stehen in der Tabellendefinition.'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Datei        : 030_Snapshot_Target_Schema.sql'
            + NCHAR(10)
            + N'Version      : 1.2.2'
            + NCHAR(10)
            + N'Stand        : 2026-10-26'
            + NCHAR(10)
            + N'Zweck        : Erstellt und aktualisiert das versionierte Basisschema des'
            + NCHAR(10)
            + N'               optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell'
            + NCHAR(10)
            + N'               verbundenen Datenbank. Das Schema speichert Erfassungsläufe,'
            + NCHAR(10)
            + N'               Status, Scopes, typisierte Messwerte und optionale Nutzdaten.'
            + NCHAR(10)
            + N'               Es startet weder Sammler noch Zeitpläne oder Retention-Purges.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Tabellen     : PackageVersion kennzeichnet Paket- und Schemafassung sowie'
            + NCHAR(10)
            + N'               Erstinstallation und letzten Installationslauf. RetentionPolicy'
            + NCHAR(10)
            + N'               hält Aufbewahrungsfristen für Rohwerte, Nutzdaten und Rollups,'
            + NCHAR(10)
            + N'               Speicherbudget, Purge-Takt, Batchgröße und Budgetaktion.'
            + NCHAR(10)
            + N'               CollectorPolicy beschreibt Aktivierung, Intervall, Zeilenlimit,'
            + NCHAR(10)
            + N'               Nutzdatenerfassung und zugeordnete RetentionPolicy.'
            + NCHAR(10)
            + N'               CaptureRun protokolliert Sammler, Schedulerart, Start und Ende,'
            + NCHAR(10)
            + N'               Quelldatenbankname, SQL-Server-Startzeit, Reset-Epoche,'
            + NCHAR(10)
            + N'               Vertragsfassung, Status, Partialität, Fehler und Zeilenzähler.'
            + NCHAR(10)
            + N'               ModuleStatus hält je Lauf und Modul Zeitpunkt, Status, Partial-'
            + NCHAR(10)
            + N'               und Fehlerangaben sowie Evidenzgrenzen.'
            + NCHAR(10)
            + N'               Scope ordnet Messungen über Scope-Typ, optionalen Eltern-Scope,'
            + NCHAR(10)
            + N'               32-Byte-Schlüsselhash und JSON-Identität einem Erfassungsbereich'
            + NCHAR(10)
            + N'               zu. MetricDefinition beschreibt Metrikcode, Werttyp, Einheit,'
            + NCHAR(10)
            + N'               Vertragsfassung, Text, Framework-Default und Seedfassung.'
            + NCHAR(10)
            + N'               MetricSample verbindet Lauf, Scope und Metrik mit Messzeit,'
            + NCHAR(10)
            + N'               Reset-Epoche, genau einem typisierten Wert, Qualitätscode und'
            + NCHAR(10)
            + N'               Partialitätskennzeichen. PayloadSnapshot speichert optionale,'
            + NCHAR(10)
            + N'               Modulnutzdaten mit Format, Vertragsfassung, Hash'
            + NCHAR(10)
            + N'               und unkomprimierter Zeichenanzahl. PurgeRun protokolliert'
            + NCHAR(10)
            + N'               Aufräumlauf, Status, Batches, gelöschte Zeilen, Budgetmessung'
            + NCHAR(10)
            + N'               und Fehler.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Beziehungen  : Fremdschlüssel verbinden CollectorPolicy mit RetentionPolicy,'
            + NCHAR(10)
            + N'               CaptureRun mit CollectorPolicy, ModuleStatus und PayloadSnapshot'
            + NCHAR(10)
            + N'               mit CaptureRun sowie MetricSample mit CaptureRun, Scope und'
            + NCHAR(10)
            + N'               MetricDefinition. Scope kann auf einen Eltern-Scope verweisen.'
            + NCHAR(10)
            + N'               Primär- und eindeutige Schlüssel verhindern doppelte'
            + NCHAR(10)
            + N'               Policycodes, Modulstatus je Lauf/Modul sowie Messwerte je'
            + NCHAR(10)
            + N'               Lauf/Scope/Metrik. Ein gefilterter eindeutiger Index lässt'
            + NCHAR(10)
            + N'               höchstens eine RetentionPolicy als Framework-Default zu;'
            + NCHAR(10)
            + N'               Zeit- und Zuordnungsindizes unterstützen die im Schema'
            + NCHAR(10)
            + N'               vorgesehenen Lauf-, Messwert-, Nutzdaten- und Purgeabfragen.'
            + NCHAR(10)
            + N'               Die DDL definiert keine kaskadierenden Fremdschlüssel.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Werte        : UTC-Zeitfelder geben den jeweiligen Erfassungs-, Lauf- oder'
            + NCHAR(10)
            + N'               Änderungszeitpunkt an. NULL ist bei Endzeiten, optionalen'
            + NCHAR(10)
            + N'               Start-/Resetinformationen, Fehlerfeldern und alternativen'
            + NCHAR(10)
            + N'               Messwertspalten zulässig, soweit die DDL dies festlegt.'
            + NCHAR(10)
            + N'               NumericValue, BigintValue und StringValue sind Alternativen:'
            + NCHAR(10)
            + N'               MetricSample verlangt genau einen nicht-NULL-Wert. ValueType'
            + NCHAR(10)
            + N'               und Unit in MetricDefinition beschreiben dessen Interpretation;'
            + NCHAR(10)
            + N'               der Vertrag garantiert keine Umrechnung. ResetEpochId grenzt'
            + NCHAR(10)
            + N'               Zählerstände über eine Reset-Epoche ab. QualityCode, StatusCode'
            + NCHAR(10)
            + N'               und IsPartial erhalten Qualitäts-, Ablauf- und'
            + NCHAR(10)
            + N'               Vollständigkeitsangaben. ScopeIdentityJson muss JSON sein;'
            + NCHAR(10)
            + N'               ScopeKeyHash ist genau 32 Byte lang. PayloadHash ist ebenfalls'
            + NCHAR(10)
            + N'               32 Byte lang; PayloadFormat und CompressionType sind auf die'
            + NCHAR(10)
            + N'               im Schema genannten Werte beschränkt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Migration    : Die native Vorprüfung akzeptiert nur erkannte Schemaformen.'
            + NCHAR(10)
            + N'               Für erkannte Legacy- und Schema-2-Stände erweitert sie die'
            + NCHAR(10)
            + N'               CollectorCode- und ScopeType-Prüfwerte um FILE_IO'
            + NCHAR(10)
            + N'               beziehungsweise FILE_IO_FILE. Unbekannte oder abweichende'
            + NCHAR(10)
            + N'               Strukturen werden nicht beliebig repariert oder überschrieben.'
            + NCHAR(10)
            + N'               Paketversion 1.2.2 / Schema 3 kennzeichnet Installationsmetadaten,'
            + NCHAR(10)
            + N'               nicht die Laufzeitqualifikation oder Freigabe des Pakets.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Seeds        : Neue DEFAULT-Retention-, PERFORMANCE_COUNTERS-Policy- und'
            + NCHAR(10)
            + N'               Performance-Counter-Metrikzeilen werden nur eingefügt, wenn'
            + NCHAR(10)
            + N'               ihr jeweiliger Schlüssel fehlt. Vorhandene solche Zeilen bleiben'
            + NCHAR(10)
            + N'               erhalten. PackageVersion wird für SC-023 angelegt oder auf'
            + NCHAR(10)
            + N'               Paketversion 1.2.2 und Schema 3 gesetzt; InstalledAtUtc bleibt'
            + NCHAR(10)
            + N'               bei einem vorhandenen Datensatz unverändert, während'
            + NCHAR(10)
            + N'               LastInstallerRunUtc aktualisiert wird.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Voraussetzung: Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare'
            + NCHAR(10)
            + N'               Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das'
            + NCHAR(10)
            + N'               Ziel und verwendet ausschließlich den geprüften Verbindungskontext.'
            + NCHAR(10)
            + N'Datenschutz  : Die Tabellen dürfen im autorisierten Betrieb vollständige reale'
            + NCHAR(10)
            + N'               Laufzeitevidenz einschließlich optionaler Payloads speichern.'
            + NCHAR(10)
            + N'               Dieses Installationsskript enthält nur generische Seeds und'
            + NCHAR(10)
            + N'               keine Laufzeitwerte oder Datenbanknamen.'
            + NCHAR(10)
            + N'Transaktion  : Implizite Transaktionen müssen ausgeschaltet sein. Das Skript'
            + NCHAR(10)
            + N'               verwendet bei Bedarf eine eigene Transaktion, andernfalls einen'
            + NCHAR(10)
            + N'               Savepoint. Im Fehlerfall wird die eigene Transaktion bei'
            + NCHAR(10)
            + N'               XACT_STATE() ungleich 0 zurückgerollt; im Aufruferkontext nur'
            + NCHAR(10)
            + N'               bei XACT_STATE() = 1 bis zum Savepoint. Bei XACT_STATE() = -1'
            + NCHAR(10)
            + N'               kann dieser Savepoint-Rollback nicht erfolgen; ein allgemeiner'
            + NCHAR(10)
            + N'               Rollback der Aufrufertransaktion wird nicht zugesichert.'
            + NCHAR(10)
            + N'               Die gesetzten SET-Optionen gelten für die verbundene Sitzung;'
            + NCHAR(10)
            + N'               das Skript stellt deren vorherige Werte nicht wieder her.'
            + NCHAR(10)
            + N'Locking      : Die privilegierte native Strukturvorprüfung verwendet'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT 10000 und hält geprüfte Tabellen bis zum'
            + NCHAR(10)
            + N'               Transaktionsende. Die anschließende eigene DDL verwendet'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT 0 und wartet nicht auf fremde Sch-M-Sperren.'
            + NCHAR(10)
            + N'Rechte       : CONTROL DATABASE und VIEW ANY DEFINITION sind für die native'
            + NCHAR(10)
            + N'               Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown]
UNION ALL
SELECT CONVERT(sysname,N'snapshot') AS [SchemaName],CONVERT(sysname,N'PackageVersion') AS [ObjectName],CONVERT(varchar(24),'TABLE') AS [ObjectType],CONVERT(varchar(24),'snapshot_target') AS [DatabaseRole],CONVERT(bit,0) AS [IsInternal],CONVERT(nvarchar(max),N'Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank.') AS [Description],CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "snapshot.PackageVersion"'
            + NCHAR(10)
            + N'schema_name: "snapshot"'
            + NCHAR(10)
            + N'object_name: "PackageVersion"'
            + NCHAR(10)
            + N'object_type: "TABLE"'
            + NCHAR(10)
            + N'database_role: "snapshot_target"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank."'
            + NCHAR(10)
            + N'source_path: "Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# snapshot.PackageVersion'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank. Das Schema speichert Erfassungsläufe, Status, Scopes, typisierte Messwerte und optionale Nutzdaten. Es startet weder Sammler noch Zeitpläne oder Retention-Purges.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das Ziel und verwendet ausschließlich den geprüften Verbindungskontext.'
            + NCHAR(10)
            + NCHAR(10)
            + N'CONTROL DATABASE und VIEW ANY DEFINITION sind für die native Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Lesender Einsatz erfordert SELECT auf [snapshot].[PackageVersion]; Installation und Aktualisierung benötigen die im Quellskript gezeigten DDL- und DML-Rechte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Keine Aufrufparameter.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Tabellenspalten und Constraints aus der eigenen CREATE-TABLE-Definition:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'('
            + NCHAR(10)
            + N'          [PackageCode] varchar(32) NOT NULL'
            + NCHAR(10)
            + N'        , [PackageVersion] varchar(16) NOT NULL'
            + NCHAR(10)
            + N'        , [SchemaVersion] int NOT NULL'
            + NCHAR(10)
            + N'        , [InstalledAtUtc] datetime2(3) NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_PackageVersion_InstalledAtUtc]'
            + NCHAR(10)
            + N'              DEFAULT (SYSUTCDATETIME())'
            + NCHAR(10)
            + N'        , [LastInstallerRunUtc] datetime2(3) NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_PackageVersion_LastInstallerRunUtc]'
            + NCHAR(10)
            + N'              DEFAULT (SYSUTCDATETIME())'
            + NCHAR(10)
            + N'        , CONSTRAINT [PK_snapshot_PackageVersion]'
            + NCHAR(10)
            + N'              PRIMARY KEY CLUSTERED ([PackageCode])'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_PackageVersion_PackageCode]'
            + NCHAR(10)
            + N'              CHECK ([PackageCode] = ''SC-023'')'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_PackageVersion_SchemaVersion]'
            + NCHAR(10)
            + N'              CHECK ([SchemaVersion] > 0)'
            + NCHAR(10)
            + N'    )'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT TOP (10) * FROM [snapshot].[PackageVersion];'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Das zugehörige Installationsskript enthält CREATE TABLE, INSERT, UPDATE, DELETE; ein lesendes SELECT führt diese Installationsschritte nicht aus. Constraints und NULL-Grenzen stehen in der Tabellendefinition.'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Datei        : 030_Snapshot_Target_Schema.sql'
            + NCHAR(10)
            + N'Version      : 1.2.2'
            + NCHAR(10)
            + N'Stand        : 2026-10-26'
            + NCHAR(10)
            + N'Zweck        : Erstellt und aktualisiert das versionierte Basisschema des'
            + NCHAR(10)
            + N'               optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell'
            + NCHAR(10)
            + N'               verbundenen Datenbank. Das Schema speichert Erfassungsläufe,'
            + NCHAR(10)
            + N'               Status, Scopes, typisierte Messwerte und optionale Nutzdaten.'
            + NCHAR(10)
            + N'               Es startet weder Sammler noch Zeitpläne oder Retention-Purges.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Tabellen     : PackageVersion kennzeichnet Paket- und Schemafassung sowie'
            + NCHAR(10)
            + N'               Erstinstallation und letzten Installationslauf. RetentionPolicy'
            + NCHAR(10)
            + N'               hält Aufbewahrungsfristen für Rohwerte, Nutzdaten und Rollups,'
            + NCHAR(10)
            + N'               Speicherbudget, Purge-Takt, Batchgröße und Budgetaktion.'
            + NCHAR(10)
            + N'               CollectorPolicy beschreibt Aktivierung, Intervall, Zeilenlimit,'
            + NCHAR(10)
            + N'               Nutzdatenerfassung und zugeordnete RetentionPolicy.'
            + NCHAR(10)
            + N'               CaptureRun protokolliert Sammler, Schedulerart, Start und Ende,'
            + NCHAR(10)
            + N'               Quelldatenbankname, SQL-Server-Startzeit, Reset-Epoche,'
            + NCHAR(10)
            + N'               Vertragsfassung, Status, Partialität, Fehler und Zeilenzähler.'
            + NCHAR(10)
            + N'               ModuleStatus hält je Lauf und Modul Zeitpunkt, Status, Partial-'
            + NCHAR(10)
            + N'               und Fehlerangaben sowie Evidenzgrenzen.'
            + NCHAR(10)
            + N'               Scope ordnet Messungen über Scope-Typ, optionalen Eltern-Scope,'
            + NCHAR(10)
            + N'               32-Byte-Schlüsselhash und JSON-Identität einem Erfassungsbereich'
            + NCHAR(10)
            + N'               zu. MetricDefinition beschreibt Metrikcode, Werttyp, Einheit,'
            + NCHAR(10)
            + N'               Vertragsfassung, Text, Framework-Default und Seedfassung.'
            + NCHAR(10)
            + N'               MetricSample verbindet Lauf, Scope und Metrik mit Messzeit,'
            + NCHAR(10)
            + N'               Reset-Epoche, genau einem typisierten Wert, Qualitätscode und'
            + NCHAR(10)
            + N'               Partialitätskennzeichen. PayloadSnapshot speichert optionale,'
            + NCHAR(10)
            + N'               Modulnutzdaten mit Format, Vertragsfassung, Hash'
            + NCHAR(10)
            + N'               und unkomprimierter Zeichenanzahl. PurgeRun protokolliert'
            + NCHAR(10)
            + N'               Aufräumlauf, Status, Batches, gelöschte Zeilen, Budgetmessung'
            + NCHAR(10)
            + N'               und Fehler.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Beziehungen  : Fremdschlüssel verbinden CollectorPolicy mit RetentionPolicy,'
            + NCHAR(10)
            + N'               CaptureRun mit CollectorPolicy, ModuleStatus und PayloadSnapshot'
            + NCHAR(10)
            + N'               mit CaptureRun sowie MetricSample mit CaptureRun, Scope und'
            + NCHAR(10)
            + N'               MetricDefinition. Scope kann auf einen Eltern-Scope verweisen.'
            + NCHAR(10)
            + N'               Primär- und eindeutige Schlüssel verhindern doppelte'
            + NCHAR(10)
            + N'               Policycodes, Modulstatus je Lauf/Modul sowie Messwerte je'
            + NCHAR(10)
            + N'               Lauf/Scope/Metrik. Ein gefilterter eindeutiger Index lässt'
            + NCHAR(10)
            + N'               höchstens eine RetentionPolicy als Framework-Default zu;'
            + NCHAR(10)
            + N'               Zeit- und Zuordnungsindizes unterstützen die im Schema'
            + NCHAR(10)
            + N'               vorgesehenen Lauf-, Messwert-, Nutzdaten- und Purgeabfragen.'
            + NCHAR(10)
            + N'               Die DDL definiert keine kaskadierenden Fremdschlüssel.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Werte        : UTC-Zeitfelder geben den jeweiligen Erfassungs-, Lauf- oder'
            + NCHAR(10)
            + N'               Änderungszeitpunkt an. NULL ist bei Endzeiten, optionalen'
            + NCHAR(10)
            + N'               Start-/Resetinformationen, Fehlerfeldern und alternativen'
            + NCHAR(10)
            + N'               Messwertspalten zulässig, soweit die DDL dies festlegt.'
            + NCHAR(10)
            + N'               NumericValue, BigintValue und StringValue sind Alternativen:'
            + NCHAR(10)
            + N'               MetricSample verlangt genau einen nicht-NULL-Wert. ValueType'
            + NCHAR(10)
            + N'               und Unit in MetricDefinition beschreiben dessen Interpretation;'
            + NCHAR(10)
            + N'               der Vertrag garantiert keine Umrechnung. ResetEpochId grenzt'
            + NCHAR(10)
            + N'               Zählerstände über eine Reset-Epoche ab. QualityCode, StatusCode'
            + NCHAR(10)
            + N'               und IsPartial erhalten Qualitäts-, Ablauf- und'
            + NCHAR(10)
            + N'               Vollständigkeitsangaben. ScopeIdentityJson muss JSON sein;'
            + NCHAR(10)
            + N'               ScopeKeyHash ist genau 32 Byte lang. PayloadHash ist ebenfalls'
            + NCHAR(10)
            + N'               32 Byte lang; PayloadFormat und CompressionType sind auf die'
            + NCHAR(10)
            + N'               im Schema genannten Werte beschränkt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Migration    : Die native Vorprüfung akzeptiert nur erkannte Schemaformen.'
            + NCHAR(10)
            + N'               Für erkannte Legacy- und Schema-2-Stände erweitert sie die'
            + NCHAR(10)
            + N'               CollectorCode- und ScopeType-Prüfwerte um FILE_IO'
            + NCHAR(10)
            + N'               beziehungsweise FILE_IO_FILE. Unbekannte oder abweichende'
            + NCHAR(10)
            + N'               Strukturen werden nicht beliebig repariert oder überschrieben.'
            + NCHAR(10)
            + N'               Paketversion 1.2.2 / Schema 3 kennzeichnet Installationsmetadaten,'
            + NCHAR(10)
            + N'               nicht die Laufzeitqualifikation oder Freigabe des Pakets.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Seeds        : Neue DEFAULT-Retention-, PERFORMANCE_COUNTERS-Policy- und'
            + NCHAR(10)
            + N'               Performance-Counter-Metrikzeilen werden nur eingefügt, wenn'
            + NCHAR(10)
            + N'               ihr jeweiliger Schlüssel fehlt. Vorhandene solche Zeilen bleiben'
            + NCHAR(10)
            + N'               erhalten. PackageVersion wird für SC-023 angelegt oder auf'
            + NCHAR(10)
            + N'               Paketversion 1.2.2 und Schema 3 gesetzt; InstalledAtUtc bleibt'
            + NCHAR(10)
            + N'               bei einem vorhandenen Datensatz unverändert, während'
            + NCHAR(10)
            + N'               LastInstallerRunUtc aktualisiert wird.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Voraussetzung: Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare'
            + NCHAR(10)
            + N'               Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das'
            + NCHAR(10)
            + N'               Ziel und verwendet ausschließlich den geprüften Verbindungskontext.'
            + NCHAR(10)
            + N'Datenschutz  : Die Tabellen dürfen im autorisierten Betrieb vollständige reale'
            + NCHAR(10)
            + N'               Laufzeitevidenz einschließlich optionaler Payloads speichern.'
            + NCHAR(10)
            + N'               Dieses Installationsskript enthält nur generische Seeds und'
            + NCHAR(10)
            + N'               keine Laufzeitwerte oder Datenbanknamen.'
            + NCHAR(10)
            + N'Transaktion  : Implizite Transaktionen müssen ausgeschaltet sein. Das Skript'
            + NCHAR(10)
            + N'               verwendet bei Bedarf eine eigene Transaktion, andernfalls einen'
            + NCHAR(10)
            + N'               Savepoint. Im Fehlerfall wird die eigene Transaktion bei'
            + NCHAR(10)
            + N'               XACT_STATE() ungleich 0 zurückgerollt; im Aufruferkontext nur'
            + NCHAR(10)
            + N'               bei XACT_STATE() = 1 bis zum Savepoint. Bei XACT_STATE() = -1'
            + NCHAR(10)
            + N'               kann dieser Savepoint-Rollback nicht erfolgen; ein allgemeiner'
            + NCHAR(10)
            + N'               Rollback der Aufrufertransaktion wird nicht zugesichert.'
            + NCHAR(10)
            + N'               Die gesetzten SET-Optionen gelten für die verbundene Sitzung;'
            + NCHAR(10)
            + N'               das Skript stellt deren vorherige Werte nicht wieder her.'
            + NCHAR(10)
            + N'Locking      : Die privilegierte native Strukturvorprüfung verwendet'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT 10000 und hält geprüfte Tabellen bis zum'
            + NCHAR(10)
            + N'               Transaktionsende. Die anschließende eigene DDL verwendet'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT 0 und wartet nicht auf fremde Sch-M-Sperren.'
            + NCHAR(10)
            + N'Rechte       : CONTROL DATABASE und VIEW ANY DEFINITION sind für die native'
            + NCHAR(10)
            + N'               Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown]
UNION ALL
SELECT CONVERT(sysname,N'snapshot') AS [SchemaName],CONVERT(sysname,N'PayloadSnapshot') AS [ObjectName],CONVERT(varchar(24),'TABLE') AS [ObjectType],CONVERT(varchar(24),'snapshot_target') AS [DatabaseRole],CONVERT(bit,0) AS [IsInternal],CONVERT(nvarchar(max),N'Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank.') AS [Description],CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "snapshot.PayloadSnapshot"'
            + NCHAR(10)
            + N'schema_name: "snapshot"'
            + NCHAR(10)
            + N'object_name: "PayloadSnapshot"'
            + NCHAR(10)
            + N'object_type: "TABLE"'
            + NCHAR(10)
            + N'database_role: "snapshot_target"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank."'
            + NCHAR(10)
            + N'source_path: "Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# snapshot.PayloadSnapshot'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank. Das Schema speichert Erfassungsläufe, Status, Scopes, typisierte Messwerte und optionale Nutzdaten. Es startet weder Sammler noch Zeitpläne oder Retention-Purges.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das Ziel und verwendet ausschließlich den geprüften Verbindungskontext.'
            + NCHAR(10)
            + NCHAR(10)
            + N'CONTROL DATABASE und VIEW ANY DEFINITION sind für die native Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Lesender Einsatz erfordert SELECT auf [snapshot].[PayloadSnapshot]; Installation und Aktualisierung benötigen die im Quellskript gezeigten DDL- und DML-Rechte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Keine Aufrufparameter.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Tabellenspalten und Constraints aus der eigenen CREATE-TABLE-Definition:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'('
            + NCHAR(10)
            + N'          [PayloadSnapshotId] bigint IDENTITY(1,1) NOT NULL'
            + NCHAR(10)
            + N'        , [CaptureRunId] bigint NOT NULL'
            + NCHAR(10)
            + N'        , [ModuleName] sysname NOT NULL'
            + NCHAR(10)
            + N'        , [CapturedAtUtc] datetime2(3) NOT NULL'
            + NCHAR(10)
            + N'        , [PayloadFormat] varchar(40) NOT NULL'
            + NCHAR(10)
            + N'        , [PayloadContractVersion] int NOT NULL'
            + NCHAR(10)
            + N'        , [CompressionType] varchar(16) NOT NULL'
            + NCHAR(10)
            + N'        , [PayloadHash] varbinary(32) NOT NULL'
            + NCHAR(10)
            + N'        , [Payload] varbinary(max) NOT NULL'
            + NCHAR(10)
            + N'        , [UncompressedCharacterCount] bigint NOT NULL'
            + NCHAR(10)
            + N'        , CONSTRAINT [PK_snapshot_PayloadSnapshot]'
            + NCHAR(10)
            + N'              PRIMARY KEY CLUSTERED ([PayloadSnapshotId])'
            + NCHAR(10)
            + N'        , CONSTRAINT [FK_snapshot_PayloadSnapshot_CaptureRun]'
            + NCHAR(10)
            + N'              FOREIGN KEY ([CaptureRunId])'
            + NCHAR(10)
            + N'              REFERENCES [snapshot].[CaptureRun]([CaptureRunId])'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_PayloadSnapshot_PayloadFormat]'
            + NCHAR(10)
            + N'              CHECK ([PayloadFormat] IN (''JSON'',''TEXT'',''XML'',''SQL_TEXT'',''PLAN_XML'',''ERROR_CONTEXT'',''PATH''))'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_PayloadSnapshot_PayloadContractVersion]'
            + NCHAR(10)
            + N'              CHECK ([PayloadContractVersion] > 0)'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_PayloadSnapshot_CompressionType]'
            + NCHAR(10)
            + N'              CHECK ([CompressionType] IN (''NONE'',''GZIP''))'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_PayloadSnapshot_PayloadHash]'
            + NCHAR(10)
            + N'              CHECK (DATALENGTH([PayloadHash]) = 32)'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_PayloadSnapshot_UncompressedCharacterCount]'
            + NCHAR(10)
            + N'              CHECK ([UncompressedCharacterCount] >= 0)'
            + NCHAR(10)
            + N'    )'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT TOP (10) * FROM [snapshot].[PayloadSnapshot];'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Das zugehörige Installationsskript enthält CREATE TABLE, INSERT, UPDATE, DELETE; ein lesendes SELECT führt diese Installationsschritte nicht aus. Constraints und NULL-Grenzen stehen in der Tabellendefinition.'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Datei        : 030_Snapshot_Target_Schema.sql'
            + NCHAR(10)
            + N'Version      : 1.2.2'
            + NCHAR(10)
            + N'Stand        : 2026-10-26'
            + NCHAR(10)
            + N'Zweck        : Erstellt und aktualisiert das versionierte Basisschema des'
            + NCHAR(10)
            + N'               optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell'
            + NCHAR(10)
            + N'               verbundenen Datenbank. Das Schema speichert Erfassungsläufe,'
            + NCHAR(10)
            + N'               Status, Scopes, typisierte Messwerte und optionale Nutzdaten.'
            + NCHAR(10)
            + N'               Es startet weder Sammler noch Zeitpläne oder Retention-Purges.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Tabellen     : PackageVersion kennzeichnet Paket- und Schemafassung sowie'
            + NCHAR(10)
            + N'               Erstinstallation und letzten Installationslauf. RetentionPolicy'
            + NCHAR(10)
            + N'               hält Aufbewahrungsfristen für Rohwerte, Nutzdaten und Rollups,'
            + NCHAR(10)
            + N'               Speicherbudget, Purge-Takt, Batchgröße und Budgetaktion.'
            + NCHAR(10)
            + N'               CollectorPolicy beschreibt Aktivierung, Intervall, Zeilenlimit,'
            + NCHAR(10)
            + N'               Nutzdatenerfassung und zugeordnete RetentionPolicy.'
            + NCHAR(10)
            + N'               CaptureRun protokolliert Sammler, Schedulerart, Start und Ende,'
            + NCHAR(10)
            + N'               Quelldatenbankname, SQL-Server-Startzeit, Reset-Epoche,'
            + NCHAR(10)
            + N'               Vertragsfassung, Status, Partialität, Fehler und Zeilenzähler.'
            + NCHAR(10)
            + N'               ModuleStatus hält je Lauf und Modul Zeitpunkt, Status, Partial-'
            + NCHAR(10)
            + N'               und Fehlerangaben sowie Evidenzgrenzen.'
            + NCHAR(10)
            + N'               Scope ordnet Messungen über Scope-Typ, optionalen Eltern-Scope,'
            + NCHAR(10)
            + N'               32-Byte-Schlüsselhash und JSON-Identität einem Erfassungsbereich'
            + NCHAR(10)
            + N'               zu. MetricDefinition beschreibt Metrikcode, Werttyp, Einheit,'
            + NCHAR(10)
            + N'               Vertragsfassung, Text, Framework-Default und Seedfassung.'
            + NCHAR(10)
            + N'               MetricSample verbindet Lauf, Scope und Metrik mit Messzeit,'
            + NCHAR(10)
            + N'               Reset-Epoche, genau einem typisierten Wert, Qualitätscode und'
            + NCHAR(10)
            + N'               Partialitätskennzeichen. PayloadSnapshot speichert optionale,'
            + NCHAR(10)
            + N'               Modulnutzdaten mit Format, Vertragsfassung, Hash'
            + NCHAR(10)
            + N'               und unkomprimierter Zeichenanzahl. PurgeRun protokolliert'
            + NCHAR(10)
            + N'               Aufräumlauf, Status, Batches, gelöschte Zeilen, Budgetmessung'
            + NCHAR(10)
            + N'               und Fehler.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Beziehungen  : Fremdschlüssel verbinden CollectorPolicy mit RetentionPolicy,'
            + NCHAR(10)
            + N'               CaptureRun mit CollectorPolicy, ModuleStatus und PayloadSnapshot'
            + NCHAR(10)
            + N'               mit CaptureRun sowie MetricSample mit CaptureRun, Scope und'
            + NCHAR(10)
            + N'               MetricDefinition. Scope kann auf einen Eltern-Scope verweisen.'
            + NCHAR(10)
            + N'               Primär- und eindeutige Schlüssel verhindern doppelte'
            + NCHAR(10)
            + N'               Policycodes, Modulstatus je Lauf/Modul sowie Messwerte je'
            + NCHAR(10)
            + N'               Lauf/Scope/Metrik. Ein gefilterter eindeutiger Index lässt'
            + NCHAR(10)
            + N'               höchstens eine RetentionPolicy als Framework-Default zu;'
            + NCHAR(10)
            + N'               Zeit- und Zuordnungsindizes unterstützen die im Schema'
            + NCHAR(10)
            + N'               vorgesehenen Lauf-, Messwert-, Nutzdaten- und Purgeabfragen.'
            + NCHAR(10)
            + N'               Die DDL definiert keine kaskadierenden Fremdschlüssel.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Werte        : UTC-Zeitfelder geben den jeweiligen Erfassungs-, Lauf- oder'
            + NCHAR(10)
            + N'               Änderungszeitpunkt an. NULL ist bei Endzeiten, optionalen'
            + NCHAR(10)
            + N'               Start-/Resetinformationen, Fehlerfeldern und alternativen'
            + NCHAR(10)
            + N'               Messwertspalten zulässig, soweit die DDL dies festlegt.'
            + NCHAR(10)
            + N'               NumericValue, BigintValue und StringValue sind Alternativen:'
            + NCHAR(10)
            + N'               MetricSample verlangt genau einen nicht-NULL-Wert. ValueType'
            + NCHAR(10)
            + N'               und Unit in MetricDefinition beschreiben dessen Interpretation;'
            + NCHAR(10)
            + N'               der Vertrag garantiert keine Umrechnung. ResetEpochId grenzt'
            + NCHAR(10)
            + N'               Zählerstände über eine Reset-Epoche ab. QualityCode, StatusCode'
            + NCHAR(10)
            + N'               und IsPartial erhalten Qualitäts-, Ablauf- und'
            + NCHAR(10)
            + N'               Vollständigkeitsangaben. ScopeIdentityJson muss JSON sein;'
            + NCHAR(10)
            + N'               ScopeKeyHash ist genau 32 Byte lang. PayloadHash ist ebenfalls'
            + NCHAR(10)
            + N'               32 Byte lang; PayloadFormat und CompressionType sind auf die'
            + NCHAR(10)
            + N'               im Schema genannten Werte beschränkt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Migration    : Die native Vorprüfung akzeptiert nur erkannte Schemaformen.'
            + NCHAR(10)
            + N'               Für erkannte Legacy- und Schema-2-Stände erweitert sie die'
            + NCHAR(10)
            + N'               CollectorCode- und ScopeType-Prüfwerte um FILE_IO'
            + NCHAR(10)
            + N'               beziehungsweise FILE_IO_FILE. Unbekannte oder abweichende'
            + NCHAR(10)
            + N'               Strukturen werden nicht beliebig repariert oder überschrieben.'
            + NCHAR(10)
            + N'               Paketversion 1.2.2 / Schema 3 kennzeichnet Installationsmetadaten,'
            + NCHAR(10)
            + N'               nicht die Laufzeitqualifikation oder Freigabe des Pakets.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Seeds        : Neue DEFAULT-Retention-, PERFORMANCE_COUNTERS-Policy- und'
            + NCHAR(10)
            + N'               Performance-Counter-Metrikzeilen werden nur eingefügt, wenn'
            + NCHAR(10)
            + N'               ihr jeweiliger Schlüssel fehlt. Vorhandene solche Zeilen bleiben'
            + NCHAR(10)
            + N'               erhalten. PackageVersion wird für SC-023 angelegt oder auf'
            + NCHAR(10)
            + N'               Paketversion 1.2.2 und Schema 3 gesetzt; InstalledAtUtc bleibt'
            + NCHAR(10)
            + N'               bei einem vorhandenen Datensatz unverändert, während'
            + NCHAR(10)
            + N'               LastInstallerRunUtc aktualisiert wird.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Voraussetzung: Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare'
            + NCHAR(10)
            + N'               Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das'
            + NCHAR(10)
            + N'               Ziel und verwendet ausschließlich den geprüften Verbindungskontext.'
            + NCHAR(10)
            + N'Datenschutz  : Die Tabellen dürfen im autorisierten Betrieb vollständige reale'
            + NCHAR(10)
            + N'               Laufzeitevidenz einschließlich optionaler Payloads speichern.'
            + NCHAR(10)
            + N'               Dieses Installationsskript enthält nur generische Seeds und'
            + NCHAR(10)
            + N'               keine Laufzeitwerte oder Datenbanknamen.'
            + NCHAR(10)
            + N'Transaktion  : Implizite Transaktionen müssen ausgeschaltet sein. Das Skript'
            + NCHAR(10)
            + N'               verwendet bei Bedarf eine eigene Transaktion, andernfalls einen'
            + NCHAR(10)
            + N'               Savepoint. Im Fehlerfall wird die eigene Transaktion bei'
            + NCHAR(10)
            + N'               XACT_STATE() ungleich 0 zurückgerollt; im Aufruferkontext nur'
            + NCHAR(10)
            + N'               bei XACT_STATE() = 1 bis zum Savepoint. Bei XACT_STATE() = -1'
            + NCHAR(10)
            + N'               kann dieser Savepoint-Rollback nicht erfolgen; ein allgemeiner'
            + NCHAR(10)
            + N'               Rollback der Aufrufertransaktion wird nicht zugesichert.'
            + NCHAR(10)
            + N'               Die gesetzten SET-Optionen gelten für die verbundene Sitzung;'
            + NCHAR(10)
            + N'               das Skript stellt deren vorherige Werte nicht wieder her.'
            + NCHAR(10)
            + N'Locking      : Die privilegierte native Strukturvorprüfung verwendet'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT 10000 und hält geprüfte Tabellen bis zum'
            + NCHAR(10)
            + N'               Transaktionsende. Die anschließende eigene DDL verwendet'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT 0 und wartet nicht auf fremde Sch-M-Sperren.'
            + NCHAR(10)
            + N'Rechte       : CONTROL DATABASE und VIEW ANY DEFINITION sind für die native'
            + NCHAR(10)
            + N'               Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown]
UNION ALL
SELECT CONVERT(sysname,N'snapshot') AS [SchemaName],CONVERT(sysname,N'PurgeRun') AS [ObjectName],CONVERT(varchar(24),'TABLE') AS [ObjectType],CONVERT(varchar(24),'snapshot_target') AS [DatabaseRole],CONVERT(bit,0) AS [IsInternal],CONVERT(nvarchar(max),N'Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank.') AS [Description],CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "snapshot.PurgeRun"'
            + NCHAR(10)
            + N'schema_name: "snapshot"'
            + NCHAR(10)
            + N'object_name: "PurgeRun"'
            + NCHAR(10)
            + N'object_type: "TABLE"'
            + NCHAR(10)
            + N'database_role: "snapshot_target"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank."'
            + NCHAR(10)
            + N'source_path: "Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# snapshot.PurgeRun'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank. Das Schema speichert Erfassungsläufe, Status, Scopes, typisierte Messwerte und optionale Nutzdaten. Es startet weder Sammler noch Zeitpläne oder Retention-Purges.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das Ziel und verwendet ausschließlich den geprüften Verbindungskontext.'
            + NCHAR(10)
            + NCHAR(10)
            + N'CONTROL DATABASE und VIEW ANY DEFINITION sind für die native Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Lesender Einsatz erfordert SELECT auf [snapshot].[PurgeRun]; Installation und Aktualisierung benötigen die im Quellskript gezeigten DDL- und DML-Rechte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Keine Aufrufparameter.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Tabellenspalten und Constraints aus der eigenen CREATE-TABLE-Definition:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'('
            + NCHAR(10)
            + N'          [PurgeRunId] bigint IDENTITY(1,1) NOT NULL'
            + NCHAR(10)
            + N'        , [StartedAtUtc] datetime2(3) NOT NULL'
            + NCHAR(10)
            + N'        , [EndedAtUtc] datetime2(3) NULL'
            + NCHAR(10)
            + N'        , [StatusCode] varchar(40) NOT NULL'
            + NCHAR(10)
            + N'        , [BatchesExecuted] int NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_PurgeRun_BatchesExecuted] DEFAULT (0)'
            + NCHAR(10)
            + N'        , [MetricRowsDeleted] bigint NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_PurgeRun_MetricRowsDeleted] DEFAULT (0)'
            + NCHAR(10)
            + N'        , [PayloadRowsDeleted] bigint NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_PurgeRun_PayloadRowsDeleted] DEFAULT (0)'
            + NCHAR(10)
            + N'        , [ModuleRowsDeleted] bigint NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_PurgeRun_ModuleRowsDeleted] DEFAULT (0)'
            + NCHAR(10)
            + N'        , [CaptureRunsDeleted] bigint NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_PurgeRun_CaptureRunsDeleted] DEFAULT (0)'
            + NCHAR(10)
            + N'        , [ScopeRowsDeleted] bigint NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_PurgeRun_ScopeRowsDeleted] DEFAULT (0)'
            + NCHAR(10)
            + N'        , [UsedDataMbBefore] decimal(19,3) NULL'
            + NCHAR(10)
            + N'        , [UsedDataMbAfter] decimal(19,3) NULL'
            + NCHAR(10)
            + N'        , [SoftBudgetMb] bigint NOT NULL'
            + NCHAR(10)
            + N'        , [ErrorNumber] int NULL'
            + NCHAR(10)
            + N'        , [ErrorMessage] nvarchar(2048) NULL'
            + NCHAR(10)
            + N'        , CONSTRAINT [PK_snapshot_PurgeRun]'
            + NCHAR(10)
            + N'              PRIMARY KEY CLUSTERED ([PurgeRunId])'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_PurgeRun_EndedAtUtc]'
            + NCHAR(10)
            + N'              CHECK ([EndedAtUtc] IS NULL OR [EndedAtUtc] >= [StartedAtUtc])'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_PurgeRun_BatchesExecuted]'
            + NCHAR(10)
            + N'              CHECK ([BatchesExecuted] >= 0)'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_PurgeRun_DeletedRows]'
            + NCHAR(10)
            + N'              CHECK ([MetricRowsDeleted] >= 0'
            + NCHAR(10)
            + N'                 AND [PayloadRowsDeleted] >= 0'
            + NCHAR(10)
            + N'                 AND [ModuleRowsDeleted] >= 0'
            + NCHAR(10)
            + N'                 AND [CaptureRunsDeleted] >= 0'
            + NCHAR(10)
            + N'                 AND [ScopeRowsDeleted] >= 0)'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_PurgeRun_SoftBudgetMb]'
            + NCHAR(10)
            + N'              CHECK ([SoftBudgetMb] > 0)'
            + NCHAR(10)
            + N'    )'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT TOP (10) * FROM [snapshot].[PurgeRun];'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Das zugehörige Installationsskript enthält CREATE TABLE, INSERT, UPDATE, DELETE; ein lesendes SELECT führt diese Installationsschritte nicht aus. Constraints und NULL-Grenzen stehen in der Tabellendefinition.'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Datei        : 030_Snapshot_Target_Schema.sql'
            + NCHAR(10)
            + N'Version      : 1.2.2'
            + NCHAR(10)
            + N'Stand        : 2026-10-26'
            + NCHAR(10)
            + N'Zweck        : Erstellt und aktualisiert das versionierte Basisschema des'
            + NCHAR(10)
            + N'               optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell'
            + NCHAR(10)
            + N'               verbundenen Datenbank. Das Schema speichert Erfassungsläufe,'
            + NCHAR(10)
            + N'               Status, Scopes, typisierte Messwerte und optionale Nutzdaten.'
            + NCHAR(10)
            + N'               Es startet weder Sammler noch Zeitpläne oder Retention-Purges.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Tabellen     : PackageVersion kennzeichnet Paket- und Schemafassung sowie'
            + NCHAR(10)
            + N'               Erstinstallation und letzten Installationslauf. RetentionPolicy'
            + NCHAR(10)
            + N'               hält Aufbewahrungsfristen für Rohwerte, Nutzdaten und Rollups,'
            + NCHAR(10)
            + N'               Speicherbudget, Purge-Takt, Batchgröße und Budgetaktion.'
            + NCHAR(10)
            + N'               CollectorPolicy beschreibt Aktivierung, Intervall, Zeilenlimit,'
            + NCHAR(10)
            + N'               Nutzdatenerfassung und zugeordnete RetentionPolicy.'
            + NCHAR(10)
            + N'               CaptureRun protokolliert Sammler, Schedulerart, Start und Ende,'
            + NCHAR(10)
            + N'               Quelldatenbankname, SQL-Server-Startzeit, Reset-Epoche,'
            + NCHAR(10)
            + N'               Vertragsfassung, Status, Partialität, Fehler und Zeilenzähler.'
            + NCHAR(10)
            + N'               ModuleStatus hält je Lauf und Modul Zeitpunkt, Status, Partial-'
            + NCHAR(10)
            + N'               und Fehlerangaben sowie Evidenzgrenzen.'
            + NCHAR(10)
            + N'               Scope ordnet Messungen über Scope-Typ, optionalen Eltern-Scope,'
            + NCHAR(10)
            + N'               32-Byte-Schlüsselhash und JSON-Identität einem Erfassungsbereich'
            + NCHAR(10)
            + N'               zu. MetricDefinition beschreibt Metrikcode, Werttyp, Einheit,'
            + NCHAR(10)
            + N'               Vertragsfassung, Text, Framework-Default und Seedfassung.'
            + NCHAR(10)
            + N'               MetricSample verbindet Lauf, Scope und Metrik mit Messzeit,'
            + NCHAR(10)
            + N'               Reset-Epoche, genau einem typisierten Wert, Qualitätscode und'
            + NCHAR(10)
            + N'               Partialitätskennzeichen. PayloadSnapshot speichert optionale,'
            + NCHAR(10)
            + N'               Modulnutzdaten mit Format, Vertragsfassung, Hash'
            + NCHAR(10)
            + N'               und unkomprimierter Zeichenanzahl. PurgeRun protokolliert'
            + NCHAR(10)
            + N'               Aufräumlauf, Status, Batches, gelöschte Zeilen, Budgetmessung'
            + NCHAR(10)
            + N'               und Fehler.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Beziehungen  : Fremdschlüssel verbinden CollectorPolicy mit RetentionPolicy,'
            + NCHAR(10)
            + N'               CaptureRun mit CollectorPolicy, ModuleStatus und PayloadSnapshot'
            + NCHAR(10)
            + N'               mit CaptureRun sowie MetricSample mit CaptureRun, Scope und'
            + NCHAR(10)
            + N'               MetricDefinition. Scope kann auf einen Eltern-Scope verweisen.'
            + NCHAR(10)
            + N'               Primär- und eindeutige Schlüssel verhindern doppelte'
            + NCHAR(10)
            + N'               Policycodes, Modulstatus je Lauf/Modul sowie Messwerte je'
            + NCHAR(10)
            + N'               Lauf/Scope/Metrik. Ein gefilterter eindeutiger Index lässt'
            + NCHAR(10)
            + N'               höchstens eine RetentionPolicy als Framework-Default zu;'
            + NCHAR(10)
            + N'               Zeit- und Zuordnungsindizes unterstützen die im Schema'
            + NCHAR(10)
            + N'               vorgesehenen Lauf-, Messwert-, Nutzdaten- und Purgeabfragen.'
            + NCHAR(10)
            + N'               Die DDL definiert keine kaskadierenden Fremdschlüssel.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Werte        : UTC-Zeitfelder geben den jeweiligen Erfassungs-, Lauf- oder'
            + NCHAR(10)
            + N'               Änderungszeitpunkt an. NULL ist bei Endzeiten, optionalen'
            + NCHAR(10)
            + N'               Start-/Resetinformationen, Fehlerfeldern und alternativen'
            + NCHAR(10)
            + N'               Messwertspalten zulässig, soweit die DDL dies festlegt.'
            + NCHAR(10)
            + N'               NumericValue, BigintValue und StringValue sind Alternativen:'
            + NCHAR(10)
            + N'               MetricSample verlangt genau einen nicht-NULL-Wert. ValueType'
            + NCHAR(10)
            + N'               und Unit in MetricDefinition beschreiben dessen Interpretation;'
            + NCHAR(10)
            + N'               der Vertrag garantiert keine Umrechnung. ResetEpochId grenzt'
            + NCHAR(10)
            + N'               Zählerstände über eine Reset-Epoche ab. QualityCode, StatusCode'
            + NCHAR(10)
            + N'               und IsPartial erhalten Qualitäts-, Ablauf- und'
            + NCHAR(10)
            + N'               Vollständigkeitsangaben. ScopeIdentityJson muss JSON sein;'
            + NCHAR(10)
            + N'               ScopeKeyHash ist genau 32 Byte lang. PayloadHash ist ebenfalls'
            + NCHAR(10)
            + N'               32 Byte lang; PayloadFormat und CompressionType sind auf die'
            + NCHAR(10)
            + N'               im Schema genannten Werte beschränkt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Migration    : Die native Vorprüfung akzeptiert nur erkannte Schemaformen.'
            + NCHAR(10)
            + N'               Für erkannte Legacy- und Schema-2-Stände erweitert sie die'
            + NCHAR(10)
            + N'               CollectorCode- und ScopeType-Prüfwerte um FILE_IO'
            + NCHAR(10)
            + N'               beziehungsweise FILE_IO_FILE. Unbekannte oder abweichende'
            + NCHAR(10)
            + N'               Strukturen werden nicht beliebig repariert oder überschrieben.'
            + NCHAR(10)
            + N'               Paketversion 1.2.2 / Schema 3 kennzeichnet Installationsmetadaten,'
            + NCHAR(10)
            + N'               nicht die Laufzeitqualifikation oder Freigabe des Pakets.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Seeds        : Neue DEFAULT-Retention-, PERFORMANCE_COUNTERS-Policy- und'
            + NCHAR(10)
            + N'               Performance-Counter-Metrikzeilen werden nur eingefügt, wenn'
            + NCHAR(10)
            + N'               ihr jeweiliger Schlüssel fehlt. Vorhandene solche Zeilen bleiben'
            + NCHAR(10)
            + N'               erhalten. PackageVersion wird für SC-023 angelegt oder auf'
            + NCHAR(10)
            + N'               Paketversion 1.2.2 und Schema 3 gesetzt; InstalledAtUtc bleibt'
            + NCHAR(10)
            + N'               bei einem vorhandenen Datensatz unverändert, während'
            + NCHAR(10)
            + N'               LastInstallerRunUtc aktualisiert wird.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Voraussetzung: Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare'
            + NCHAR(10)
            + N'               Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das'
            + NCHAR(10)
            + N'               Ziel und verwendet ausschließlich den geprüften Verbindungskontext.'
            + NCHAR(10)
            + N'Datenschutz  : Die Tabellen dürfen im autorisierten Betrieb vollständige reale'
            + NCHAR(10)
            + N'               Laufzeitevidenz einschließlich optionaler Payloads speichern.'
            + NCHAR(10)
            + N'               Dieses Installationsskript enthält nur generische Seeds und'
            + NCHAR(10)
            + N'               keine Laufzeitwerte oder Datenbanknamen.'
            + NCHAR(10)
            + N'Transaktion  : Implizite Transaktionen müssen ausgeschaltet sein. Das Skript'
            + NCHAR(10)
            + N'               verwendet bei Bedarf eine eigene Transaktion, andernfalls einen'
            + NCHAR(10)
            + N'               Savepoint. Im Fehlerfall wird die eigene Transaktion bei'
            + NCHAR(10)
            + N'               XACT_STATE() ungleich 0 zurückgerollt; im Aufruferkontext nur'
            + NCHAR(10)
            + N'               bei XACT_STATE() = 1 bis zum Savepoint. Bei XACT_STATE() = -1'
            + NCHAR(10)
            + N'               kann dieser Savepoint-Rollback nicht erfolgen; ein allgemeiner'
            + NCHAR(10)
            + N'               Rollback der Aufrufertransaktion wird nicht zugesichert.'
            + NCHAR(10)
            + N'               Die gesetzten SET-Optionen gelten für die verbundene Sitzung;'
            + NCHAR(10)
            + N'               das Skript stellt deren vorherige Werte nicht wieder her.'
            + NCHAR(10)
            + N'Locking      : Die privilegierte native Strukturvorprüfung verwendet'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT 10000 und hält geprüfte Tabellen bis zum'
            + NCHAR(10)
            + N'               Transaktionsende. Die anschließende eigene DDL verwendet'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT 0 und wartet nicht auf fremde Sch-M-Sperren.'
            + NCHAR(10)
            + N'Rechte       : CONTROL DATABASE und VIEW ANY DEFINITION sind für die native'
            + NCHAR(10)
            + N'               Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown]
UNION ALL
SELECT CONVERT(sysname,N'snapshot') AS [SchemaName],CONVERT(sysname,N'RetentionPolicy') AS [ObjectName],CONVERT(varchar(24),'TABLE') AS [ObjectType],CONVERT(varchar(24),'snapshot_target') AS [DatabaseRole],CONVERT(bit,0) AS [IsInternal],CONVERT(nvarchar(max),N'Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank.') AS [Description],CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "snapshot.RetentionPolicy"'
            + NCHAR(10)
            + N'schema_name: "snapshot"'
            + NCHAR(10)
            + N'object_name: "RetentionPolicy"'
            + NCHAR(10)
            + N'object_type: "TABLE"'
            + NCHAR(10)
            + N'database_role: "snapshot_target"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank."'
            + NCHAR(10)
            + N'source_path: "Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# snapshot.RetentionPolicy'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank. Das Schema speichert Erfassungsläufe, Status, Scopes, typisierte Messwerte und optionale Nutzdaten. Es startet weder Sammler noch Zeitpläne oder Retention-Purges.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das Ziel und verwendet ausschließlich den geprüften Verbindungskontext.'
            + NCHAR(10)
            + NCHAR(10)
            + N'CONTROL DATABASE und VIEW ANY DEFINITION sind für die native Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Lesender Einsatz erfordert SELECT auf [snapshot].[RetentionPolicy]; Installation und Aktualisierung benötigen die im Quellskript gezeigten DDL- und DML-Rechte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Keine Aufrufparameter.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Tabellenspalten und Constraints aus der eigenen CREATE-TABLE-Definition:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'('
            + NCHAR(10)
            + N'          [RetentionPolicyCode] varchar(64) NOT NULL'
            + NCHAR(10)
            + N'        , [RawRetentionDays] smallint NOT NULL'
            + NCHAR(10)
            + N'        , [PayloadRetentionDays] smallint NOT NULL'
            + NCHAR(10)
            + N'        , [RollupRetentionDays] smallint NOT NULL'
            + NCHAR(10)
            + N'        , [SoftBudgetMB] bigint NOT NULL'
            + NCHAR(10)
            + N'        , [PurgeIntervalMinutes] int NOT NULL'
            + NCHAR(10)
            + N'        , [PurgeBatchRows] int NOT NULL'
            + NCHAR(10)
            + N'        , [BudgetAction] varchar(40) NOT NULL'
            + NCHAR(10)
            + N'        , [IsFrameworkDefault] bit NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_RetentionPolicy_IsFrameworkDefault]'
            + NCHAR(10)
            + N'              DEFAULT (0)'
            + NCHAR(10)
            + N'        , [SeedVersion] int NOT NULL'
            + NCHAR(10)
            + N'        , [LastUpdatedUtc] datetime2(3) NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_RetentionPolicy_LastUpdatedUtc]'
            + NCHAR(10)
            + N'              DEFAULT (SYSUTCDATETIME())'
            + NCHAR(10)
            + N'        , CONSTRAINT [PK_snapshot_RetentionPolicy]'
            + NCHAR(10)
            + N'              PRIMARY KEY CLUSTERED ([RetentionPolicyCode])'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_RetentionPolicy_RawRetentionDays]'
            + NCHAR(10)
            + N'              CHECK ([RawRetentionDays] BETWEEN 1 AND 36500)'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_RetentionPolicy_PayloadRetentionDays]'
            + NCHAR(10)
            + N'              CHECK ([PayloadRetentionDays] BETWEEN 1 AND 36500)'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_RetentionPolicy_RollupRetentionDays]'
            + NCHAR(10)
            + N'              CHECK ([RollupRetentionDays] BETWEEN 1 AND 36500)'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_RetentionPolicy_SoftBudgetMB]'
            + NCHAR(10)
            + N'              CHECK ([SoftBudgetMB] > 0)'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_RetentionPolicy_PurgeIntervalMinutes]'
            + NCHAR(10)
            + N'              CHECK ([PurgeIntervalMinutes] BETWEEN 1 AND 10080)'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_RetentionPolicy_PurgeBatchRows]'
            + NCHAR(10)
            + N'              CHECK ([PurgeBatchRows] BETWEEN 1 AND 100000)'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_RetentionPolicy_BudgetAction]'
            + NCHAR(10)
            + N'              CHECK ([BudgetAction] = ''PURGE_EXPIRED_THEN_STOP'')'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_RetentionPolicy_SeedVersion]'
            + NCHAR(10)
            + N'              CHECK ([SeedVersion] > 0)'
            + NCHAR(10)
            + N'    )'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT TOP (10) * FROM [snapshot].[RetentionPolicy];'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Das zugehörige Installationsskript enthält CREATE TABLE, INSERT, UPDATE, DELETE; ein lesendes SELECT führt diese Installationsschritte nicht aus. Constraints und NULL-Grenzen stehen in der Tabellendefinition.'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Datei        : 030_Snapshot_Target_Schema.sql'
            + NCHAR(10)
            + N'Version      : 1.2.2'
            + NCHAR(10)
            + N'Stand        : 2026-10-26'
            + NCHAR(10)
            + N'Zweck        : Erstellt und aktualisiert das versionierte Basisschema des'
            + NCHAR(10)
            + N'               optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell'
            + NCHAR(10)
            + N'               verbundenen Datenbank. Das Schema speichert Erfassungsläufe,'
            + NCHAR(10)
            + N'               Status, Scopes, typisierte Messwerte und optionale Nutzdaten.'
            + NCHAR(10)
            + N'               Es startet weder Sammler noch Zeitpläne oder Retention-Purges.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Tabellen     : PackageVersion kennzeichnet Paket- und Schemafassung sowie'
            + NCHAR(10)
            + N'               Erstinstallation und letzten Installationslauf. RetentionPolicy'
            + NCHAR(10)
            + N'               hält Aufbewahrungsfristen für Rohwerte, Nutzdaten und Rollups,'
            + NCHAR(10)
            + N'               Speicherbudget, Purge-Takt, Batchgröße und Budgetaktion.'
            + NCHAR(10)
            + N'               CollectorPolicy beschreibt Aktivierung, Intervall, Zeilenlimit,'
            + NCHAR(10)
            + N'               Nutzdatenerfassung und zugeordnete RetentionPolicy.'
            + NCHAR(10)
            + N'               CaptureRun protokolliert Sammler, Schedulerart, Start und Ende,'
            + NCHAR(10)
            + N'               Quelldatenbankname, SQL-Server-Startzeit, Reset-Epoche,'
            + NCHAR(10)
            + N'               Vertragsfassung, Status, Partialität, Fehler und Zeilenzähler.'
            + NCHAR(10)
            + N'               ModuleStatus hält je Lauf und Modul Zeitpunkt, Status, Partial-'
            + NCHAR(10)
            + N'               und Fehlerangaben sowie Evidenzgrenzen.'
            + NCHAR(10)
            + N'               Scope ordnet Messungen über Scope-Typ, optionalen Eltern-Scope,'
            + NCHAR(10)
            + N'               32-Byte-Schlüsselhash und JSON-Identität einem Erfassungsbereich'
            + NCHAR(10)
            + N'               zu. MetricDefinition beschreibt Metrikcode, Werttyp, Einheit,'
            + NCHAR(10)
            + N'               Vertragsfassung, Text, Framework-Default und Seedfassung.'
            + NCHAR(10)
            + N'               MetricSample verbindet Lauf, Scope und Metrik mit Messzeit,'
            + NCHAR(10)
            + N'               Reset-Epoche, genau einem typisierten Wert, Qualitätscode und'
            + NCHAR(10)
            + N'               Partialitätskennzeichen. PayloadSnapshot speichert optionale,'
            + NCHAR(10)
            + N'               Modulnutzdaten mit Format, Vertragsfassung, Hash'
            + NCHAR(10)
            + N'               und unkomprimierter Zeichenanzahl. PurgeRun protokolliert'
            + NCHAR(10)
            + N'               Aufräumlauf, Status, Batches, gelöschte Zeilen, Budgetmessung'
            + NCHAR(10)
            + N'               und Fehler.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Beziehungen  : Fremdschlüssel verbinden CollectorPolicy mit RetentionPolicy,'
            + NCHAR(10)
            + N'               CaptureRun mit CollectorPolicy, ModuleStatus und PayloadSnapshot'
            + NCHAR(10)
            + N'               mit CaptureRun sowie MetricSample mit CaptureRun, Scope und'
            + NCHAR(10)
            + N'               MetricDefinition. Scope kann auf einen Eltern-Scope verweisen.'
            + NCHAR(10)
            + N'               Primär- und eindeutige Schlüssel verhindern doppelte'
            + NCHAR(10)
            + N'               Policycodes, Modulstatus je Lauf/Modul sowie Messwerte je'
            + NCHAR(10)
            + N'               Lauf/Scope/Metrik. Ein gefilterter eindeutiger Index lässt'
            + NCHAR(10)
            + N'               höchstens eine RetentionPolicy als Framework-Default zu;'
            + NCHAR(10)
            + N'               Zeit- und Zuordnungsindizes unterstützen die im Schema'
            + NCHAR(10)
            + N'               vorgesehenen Lauf-, Messwert-, Nutzdaten- und Purgeabfragen.'
            + NCHAR(10)
            + N'               Die DDL definiert keine kaskadierenden Fremdschlüssel.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Werte        : UTC-Zeitfelder geben den jeweiligen Erfassungs-, Lauf- oder'
            + NCHAR(10)
            + N'               Änderungszeitpunkt an. NULL ist bei Endzeiten, optionalen'
            + NCHAR(10)
            + N'               Start-/Resetinformationen, Fehlerfeldern und alternativen'
            + NCHAR(10)
            + N'               Messwertspalten zulässig, soweit die DDL dies festlegt.'
            + NCHAR(10)
            + N'               NumericValue, BigintValue und StringValue sind Alternativen:'
            + NCHAR(10)
            + N'               MetricSample verlangt genau einen nicht-NULL-Wert. ValueType'
            + NCHAR(10)
            + N'               und Unit in MetricDefinition beschreiben dessen Interpretation;'
            + NCHAR(10)
            + N'               der Vertrag garantiert keine Umrechnung. ResetEpochId grenzt'
            + NCHAR(10)
            + N'               Zählerstände über eine Reset-Epoche ab. QualityCode, StatusCode'
            + NCHAR(10)
            + N'               und IsPartial erhalten Qualitäts-, Ablauf- und'
            + NCHAR(10)
            + N'               Vollständigkeitsangaben. ScopeIdentityJson muss JSON sein;'
            + NCHAR(10)
            + N'               ScopeKeyHash ist genau 32 Byte lang. PayloadHash ist ebenfalls'
            + NCHAR(10)
            + N'               32 Byte lang; PayloadFormat und CompressionType sind auf die'
            + NCHAR(10)
            + N'               im Schema genannten Werte beschränkt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Migration    : Die native Vorprüfung akzeptiert nur erkannte Schemaformen.'
            + NCHAR(10)
            + N'               Für erkannte Legacy- und Schema-2-Stände erweitert sie die'
            + NCHAR(10)
            + N'               CollectorCode- und ScopeType-Prüfwerte um FILE_IO'
            + NCHAR(10)
            + N'               beziehungsweise FILE_IO_FILE. Unbekannte oder abweichende'
            + NCHAR(10)
            + N'               Strukturen werden nicht beliebig repariert oder überschrieben.'
            + NCHAR(10)
            + N'               Paketversion 1.2.2 / Schema 3 kennzeichnet Installationsmetadaten,'
            + NCHAR(10)
            + N'               nicht die Laufzeitqualifikation oder Freigabe des Pakets.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Seeds        : Neue DEFAULT-Retention-, PERFORMANCE_COUNTERS-Policy- und'
            + NCHAR(10)
            + N'               Performance-Counter-Metrikzeilen werden nur eingefügt, wenn'
            + NCHAR(10)
            + N'               ihr jeweiliger Schlüssel fehlt. Vorhandene solche Zeilen bleiben'
            + NCHAR(10)
            + N'               erhalten. PackageVersion wird für SC-023 angelegt oder auf'
            + NCHAR(10)
            + N'               Paketversion 1.2.2 und Schema 3 gesetzt; InstalledAtUtc bleibt'
            + NCHAR(10)
            + N'               bei einem vorhandenen Datensatz unverändert, während'
            + NCHAR(10)
            + N'               LastInstallerRunUtc aktualisiert wird.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Voraussetzung: Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare'
            + NCHAR(10)
            + N'               Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das'
            + NCHAR(10)
            + N'               Ziel und verwendet ausschließlich den geprüften Verbindungskontext.'
            + NCHAR(10)
            + N'Datenschutz  : Die Tabellen dürfen im autorisierten Betrieb vollständige reale'
            + NCHAR(10)
            + N'               Laufzeitevidenz einschließlich optionaler Payloads speichern.'
            + NCHAR(10)
            + N'               Dieses Installationsskript enthält nur generische Seeds und'
            + NCHAR(10)
            + N'               keine Laufzeitwerte oder Datenbanknamen.'
            + NCHAR(10)
            + N'Transaktion  : Implizite Transaktionen müssen ausgeschaltet sein. Das Skript'
            + NCHAR(10)
            + N'               verwendet bei Bedarf eine eigene Transaktion, andernfalls einen'
            + NCHAR(10)
            + N'               Savepoint. Im Fehlerfall wird die eigene Transaktion bei'
            + NCHAR(10)
            + N'               XACT_STATE() ungleich 0 zurückgerollt; im Aufruferkontext nur'
            + NCHAR(10)
            + N'               bei XACT_STATE() = 1 bis zum Savepoint. Bei XACT_STATE() = -1'
            + NCHAR(10)
            + N'               kann dieser Savepoint-Rollback nicht erfolgen; ein allgemeiner'
            + NCHAR(10)
            + N'               Rollback der Aufrufertransaktion wird nicht zugesichert.'
            + NCHAR(10)
            + N'               Die gesetzten SET-Optionen gelten für die verbundene Sitzung;'
            + NCHAR(10)
            + N'               das Skript stellt deren vorherige Werte nicht wieder her.'
            + NCHAR(10)
            + N'Locking      : Die privilegierte native Strukturvorprüfung verwendet'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT 10000 und hält geprüfte Tabellen bis zum'
            + NCHAR(10)
            + N'               Transaktionsende. Die anschließende eigene DDL verwendet'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT 0 und wartet nicht auf fremde Sch-M-Sperren.'
            + NCHAR(10)
            + N'Rechte       : CONTROL DATABASE und VIEW ANY DEFINITION sind für die native'
            + NCHAR(10)
            + N'               Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown]
UNION ALL
SELECT CONVERT(sysname,N'snapshot') AS [SchemaName],CONVERT(sysname,N'Scope') AS [ObjectName],CONVERT(varchar(24),'TABLE') AS [ObjectType],CONVERT(varchar(24),'snapshot_target') AS [DatabaseRole],CONVERT(bit,0) AS [IsInternal],CONVERT(nvarchar(max),N'Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank.') AS [Description],CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "snapshot.Scope"'
            + NCHAR(10)
            + N'schema_name: "snapshot"'
            + NCHAR(10)
            + N'object_name: "Scope"'
            + NCHAR(10)
            + N'object_type: "TABLE"'
            + NCHAR(10)
            + N'database_role: "snapshot_target"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank."'
            + NCHAR(10)
            + N'source_path: "Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# snapshot.Scope'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Erstellt und aktualisiert das versionierte Basisschema des optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank. Das Schema speichert Erfassungsläufe, Status, Scopes, typisierte Messwerte und optionale Nutzdaten. Es startet weder Sammler noch Zeitpläne oder Retention-Purges.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das Ziel und verwendet ausschließlich den geprüften Verbindungskontext.'
            + NCHAR(10)
            + NCHAR(10)
            + N'CONTROL DATABASE und VIEW ANY DEFINITION sind für die native Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Lesender Einsatz erfordert SELECT auf [snapshot].[Scope]; Installation und Aktualisierung benötigen die im Quellskript gezeigten DDL- und DML-Rechte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Keine Aufrufparameter.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Tabellenspalten und Constraints aus der eigenen CREATE-TABLE-Definition:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'('
            + NCHAR(10)
            + N'          [ScopeId] bigint IDENTITY(1,1) NOT NULL'
            + NCHAR(10)
            + N'        , [ScopeType] varchar(40) NOT NULL'
            + NCHAR(10)
            + N'        , [ParentScopeId] bigint NULL'
            + NCHAR(10)
            + N'        , [ScopeKeyHash] varbinary(32) NOT NULL'
            + NCHAR(10)
            + N'        , [ScopeIdentityJson] nvarchar(max) NOT NULL'
            + NCHAR(10)
            + N'        , [CreatedAtUtc] datetime2(3) NOT NULL'
            + NCHAR(10)
            + N'              CONSTRAINT [DF_snapshot_Scope_CreatedAtUtc]'
            + NCHAR(10)
            + N'              DEFAULT (SYSUTCDATETIME())'
            + NCHAR(10)
            + N'        , CONSTRAINT [PK_snapshot_Scope]'
            + NCHAR(10)
            + N'              PRIMARY KEY CLUSTERED ([ScopeId])'
            + NCHAR(10)
            + N'        , CONSTRAINT [FK_snapshot_Scope_ParentScope]'
            + NCHAR(10)
            + N'              FOREIGN KEY ([ParentScopeId])'
            + NCHAR(10)
            + N'              REFERENCES [snapshot].[Scope]([ScopeId])'
            + NCHAR(10)
            + N'        , CONSTRAINT [UQ_snapshot_Scope_TypeKeyHash]'
            + NCHAR(10)
            + N'              UNIQUE ([ScopeType],[ScopeKeyHash])'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_Scope_ScopeType]'
            + NCHAR(10)
            + N'              CHECK ([ScopeType] IN (''SERVER'',''PERFORMANCE_COUNTER'',''WAIT_TYPE'',''FILE_IO_FILE''))'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_Scope_ScopeKeyHash]'
            + NCHAR(10)
            + N'              CHECK (DATALENGTH([ScopeKeyHash]) = 32)'
            + NCHAR(10)
            + N'        , CONSTRAINT [CK_snapshot_Scope_ScopeIdentityJson]'
            + NCHAR(10)
            + N'              CHECK (ISJSON([ScopeIdentityJson]) = 1)'
            + NCHAR(10)
            + N'    )'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT TOP (10) * FROM [snapshot].[Scope];'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Das zugehörige Installationsskript enthält CREATE TABLE, INSERT, UPDATE, DELETE; ein lesendes SELECT führt diese Installationsschritte nicht aus. Constraints und NULL-Grenzen stehen in der Tabellendefinition.'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Datei        : 030_Snapshot_Target_Schema.sql'
            + NCHAR(10)
            + N'Version      : 1.2.2'
            + NCHAR(10)
            + N'Stand        : 2026-10-26'
            + NCHAR(10)
            + N'Zweck        : Erstellt und aktualisiert das versionierte Basisschema des'
            + NCHAR(10)
            + N'               optionalen SC-023-Snapshot-/Baseline-Ziels in der aktuell'
            + NCHAR(10)
            + N'               verbundenen Datenbank. Das Schema speichert Erfassungsläufe,'
            + NCHAR(10)
            + N'               Status, Scopes, typisierte Messwerte und optionale Nutzdaten.'
            + NCHAR(10)
            + N'               Es startet weder Sammler noch Zeitpläne oder Retention-Purges.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Tabellen     : PackageVersion kennzeichnet Paket- und Schemafassung sowie'
            + NCHAR(10)
            + N'               Erstinstallation und letzten Installationslauf. RetentionPolicy'
            + NCHAR(10)
            + N'               hält Aufbewahrungsfristen für Rohwerte, Nutzdaten und Rollups,'
            + NCHAR(10)
            + N'               Speicherbudget, Purge-Takt, Batchgröße und Budgetaktion.'
            + NCHAR(10)
            + N'               CollectorPolicy beschreibt Aktivierung, Intervall, Zeilenlimit,'
            + NCHAR(10)
            + N'               Nutzdatenerfassung und zugeordnete RetentionPolicy.'
            + NCHAR(10)
            + N'               CaptureRun protokolliert Sammler, Schedulerart, Start und Ende,'
            + NCHAR(10)
            + N'               Quelldatenbankname, SQL-Server-Startzeit, Reset-Epoche,'
            + NCHAR(10)
            + N'               Vertragsfassung, Status, Partialität, Fehler und Zeilenzähler.'
            + NCHAR(10)
            + N'               ModuleStatus hält je Lauf und Modul Zeitpunkt, Status, Partial-'
            + NCHAR(10)
            + N'               und Fehlerangaben sowie Evidenzgrenzen.'
            + NCHAR(10)
            + N'               Scope ordnet Messungen über Scope-Typ, optionalen Eltern-Scope,'
            + NCHAR(10)
            + N'               32-Byte-Schlüsselhash und JSON-Identität einem Erfassungsbereich'
            + NCHAR(10)
            + N'               zu. MetricDefinition beschreibt Metrikcode, Werttyp, Einheit,'
            + NCHAR(10)
            + N'               Vertragsfassung, Text, Framework-Default und Seedfassung.'
            + NCHAR(10)
            + N'               MetricSample verbindet Lauf, Scope und Metrik mit Messzeit,'
            + NCHAR(10)
            + N'               Reset-Epoche, genau einem typisierten Wert, Qualitätscode und'
            + NCHAR(10)
            + N'               Partialitätskennzeichen. PayloadSnapshot speichert optionale,'
            + NCHAR(10)
            + N'               Modulnutzdaten mit Format, Vertragsfassung, Hash'
            + NCHAR(10)
            + N'               und unkomprimierter Zeichenanzahl. PurgeRun protokolliert'
            + NCHAR(10)
            + N'               Aufräumlauf, Status, Batches, gelöschte Zeilen, Budgetmessung'
            + NCHAR(10)
            + N'               und Fehler.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Beziehungen  : Fremdschlüssel verbinden CollectorPolicy mit RetentionPolicy,'
            + NCHAR(10)
            + N'               CaptureRun mit CollectorPolicy, ModuleStatus und PayloadSnapshot'
            + NCHAR(10)
            + N'               mit CaptureRun sowie MetricSample mit CaptureRun, Scope und'
            + NCHAR(10)
            + N'               MetricDefinition. Scope kann auf einen Eltern-Scope verweisen.'
            + NCHAR(10)
            + N'               Primär- und eindeutige Schlüssel verhindern doppelte'
            + NCHAR(10)
            + N'               Policycodes, Modulstatus je Lauf/Modul sowie Messwerte je'
            + NCHAR(10)
            + N'               Lauf/Scope/Metrik. Ein gefilterter eindeutiger Index lässt'
            + NCHAR(10)
            + N'               höchstens eine RetentionPolicy als Framework-Default zu;'
            + NCHAR(10)
            + N'               Zeit- und Zuordnungsindizes unterstützen die im Schema'
            + NCHAR(10)
            + N'               vorgesehenen Lauf-, Messwert-, Nutzdaten- und Purgeabfragen.'
            + NCHAR(10)
            + N'               Die DDL definiert keine kaskadierenden Fremdschlüssel.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Werte        : UTC-Zeitfelder geben den jeweiligen Erfassungs-, Lauf- oder'
            + NCHAR(10)
            + N'               Änderungszeitpunkt an. NULL ist bei Endzeiten, optionalen'
            + NCHAR(10)
            + N'               Start-/Resetinformationen, Fehlerfeldern und alternativen'
            + NCHAR(10)
            + N'               Messwertspalten zulässig, soweit die DDL dies festlegt.'
            + NCHAR(10)
            + N'               NumericValue, BigintValue und StringValue sind Alternativen:'
            + NCHAR(10)
            + N'               MetricSample verlangt genau einen nicht-NULL-Wert. ValueType'
            + NCHAR(10)
            + N'               und Unit in MetricDefinition beschreiben dessen Interpretation;'
            + NCHAR(10)
            + N'               der Vertrag garantiert keine Umrechnung. ResetEpochId grenzt'
            + NCHAR(10)
            + N'               Zählerstände über eine Reset-Epoche ab. QualityCode, StatusCode'
            + NCHAR(10)
            + N'               und IsPartial erhalten Qualitäts-, Ablauf- und'
            + NCHAR(10)
            + N'               Vollständigkeitsangaben. ScopeIdentityJson muss JSON sein;'
            + NCHAR(10)
            + N'               ScopeKeyHash ist genau 32 Byte lang. PayloadHash ist ebenfalls'
            + NCHAR(10)
            + N'               32 Byte lang; PayloadFormat und CompressionType sind auf die'
            + NCHAR(10)
            + N'               im Schema genannten Werte beschränkt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Migration    : Die native Vorprüfung akzeptiert nur erkannte Schemaformen.'
            + NCHAR(10)
            + N'               Für erkannte Legacy- und Schema-2-Stände erweitert sie die'
            + NCHAR(10)
            + N'               CollectorCode- und ScopeType-Prüfwerte um FILE_IO'
            + NCHAR(10)
            + N'               beziehungsweise FILE_IO_FILE. Unbekannte oder abweichende'
            + NCHAR(10)
            + N'               Strukturen werden nicht beliebig repariert oder überschrieben.'
            + NCHAR(10)
            + N'               Paketversion 1.2.2 / Schema 3 kennzeichnet Installationsmetadaten,'
            + NCHAR(10)
            + N'               nicht die Laufzeitqualifikation oder Freigabe des Pakets.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Seeds        : Neue DEFAULT-Retention-, PERFORMANCE_COUNTERS-Policy- und'
            + NCHAR(10)
            + N'               Performance-Counter-Metrikzeilen werden nur eingefügt, wenn'
            + NCHAR(10)
            + N'               ihr jeweiliger Schlüssel fehlt. Vorhandene solche Zeilen bleiben'
            + NCHAR(10)
            + N'               erhalten. PackageVersion wird für SC-023 angelegt oder auf'
            + NCHAR(10)
            + N'               Paketversion 1.2.2 und Schema 3 gesetzt; InstalledAtUtc bleibt'
            + NCHAR(10)
            + N'               bei einem vorhandenen Datensatz unverändert, während'
            + NCHAR(10)
            + N'               LastInstallerRunUtc aktualisiert wird.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Voraussetzung: Die Verbindung zeigt auf eine ONLINE befindliche, beschreibbare'
            + NCHAR(10)
            + N'               Nicht-Systemdatenbank. Das Skript erstellt nicht selbst das'
            + NCHAR(10)
            + N'               Ziel und verwendet ausschließlich den geprüften Verbindungskontext.'
            + NCHAR(10)
            + N'Datenschutz  : Die Tabellen dürfen im autorisierten Betrieb vollständige reale'
            + NCHAR(10)
            + N'               Laufzeitevidenz einschließlich optionaler Payloads speichern.'
            + NCHAR(10)
            + N'               Dieses Installationsskript enthält nur generische Seeds und'
            + NCHAR(10)
            + N'               keine Laufzeitwerte oder Datenbanknamen.'
            + NCHAR(10)
            + N'Transaktion  : Implizite Transaktionen müssen ausgeschaltet sein. Das Skript'
            + NCHAR(10)
            + N'               verwendet bei Bedarf eine eigene Transaktion, andernfalls einen'
            + NCHAR(10)
            + N'               Savepoint. Im Fehlerfall wird die eigene Transaktion bei'
            + NCHAR(10)
            + N'               XACT_STATE() ungleich 0 zurückgerollt; im Aufruferkontext nur'
            + NCHAR(10)
            + N'               bei XACT_STATE() = 1 bis zum Savepoint. Bei XACT_STATE() = -1'
            + NCHAR(10)
            + N'               kann dieser Savepoint-Rollback nicht erfolgen; ein allgemeiner'
            + NCHAR(10)
            + N'               Rollback der Aufrufertransaktion wird nicht zugesichert.'
            + NCHAR(10)
            + N'               Die gesetzten SET-Optionen gelten für die verbundene Sitzung;'
            + NCHAR(10)
            + N'               das Skript stellt deren vorherige Werte nicht wieder her.'
            + NCHAR(10)
            + N'Locking      : Die privilegierte native Strukturvorprüfung verwendet'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT 10000 und hält geprüfte Tabellen bis zum'
            + NCHAR(10)
            + N'               Transaktionsende. Die anschließende eigene DDL verwendet'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT 0 und wartet nicht auf fremde Sch-M-Sperren.'
            + NCHAR(10)
            + N'Rechte       : CONTROL DATABASE und VIEW ANY DEFINITION sind für die native'
            + NCHAR(10)
            + N'               Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
GO
