---
skill_format_version: "1.0.0"
name: "monitor_metadata.VW_ObjectUsageSkills"
schema_name: "monitor_metadata"
object_name: "VW_ObjectUsageSkills"
object_type: "VIEW"
database_role: "both"
is_internal: false
description: "Liefert versionierte Usage-Skill-Texte als statischen Dokumentationskatalog für die feste bekannte Objektmenge der jeweiligen Datenbankrolle."
source_path: "Code/00_Setup/005_VW_ObjectUsageSkills.sql"
---

# monitor_metadata.VW_ObjectUsageSkills

## Zweck und Einsatz

Die View stellt für die bekannte Frameworkrolle 193 Objekt-Skills plus diesen Self-Skill und für die Snapshot-Zielrolle 17 Objekt-Skills plus diesen Self-Skill bereit. Der Text stammt aus den versionierten Markdown-Dateien unter `Metadata/UsageSkills`; die View führt keine Objektinventur und keine Laufzeitprüfung aus. Die Self-Zeile trägt `DatabaseRole=both`, weil dieselbe kanonische Markdown-Datei in beiden Rollenprojektionen enthalten ist; alle anderen Zeilen nennen ihre jeweilige Datenbankrolle. Ein Eintrag sagt weder, dass das Objekt im aktuellen Datenbankzustand noch vorhanden ist, noch dass der Aufrufer seine Fachquellen lesen oder ausführen darf.

## Voraussetzungen und Rechte

Der Installer muss das Schema `monitor_metadata` und die View in der ausdrücklich gewählten Datenbank mit den entsprechenden DDL-Rechten anlegen können. Ein lesender Aufrufer benötigt SELECT auf der View. Die View erteilt keine Rechte auf die beschriebenen Objekte und führt sie nicht aus. Ein Teilinstaller verkleinert die feste Rollenliste nicht; der Katalog belegt weder die Installation noch die Erreichbarkeit der aufgeführten Fachobjekte.

## Parameter und Eingabe

Keine Aufrufparameter. `SchemaName` und `ObjectName` wählen die dokumentierte Identität; beide Werte werden als Daten verglichen, nicht als dynamische SQL-Bezeichner ausgeführt.

## Resultate und Ausgabe

Eine Zeile je Objekt mit `SchemaName` (sysname), `ObjectName` (sysname), `ObjectType` (varchar(24)), `DatabaseRole` (varchar(24)), `IsInternal` (bit), `Description` (nvarchar(max)), `SkillFormatVersion` (varchar(16)) und `SkillMarkdown` (nvarchar(max)). `SkillMarkdown` ist zeichengetreu mit der zugehörigen versionierten Markdown-Datei. `SkillFormatVersion=1.0.0` bezeichnet nur das Skillformat, nicht Framework- oder Paketversion.

## Beispiel

```sql
SELECT [SkillFormatVersion], [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'monitor'
  AND [ObjectName]=N'USP_CurrentObjectPermissionAnalysis';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

SELECT liest konstante Unicode-Literale und verändert keinen Datenbankzustand. Ein Abruf aller langen `SkillMarkdown`-Werte kann entsprechend der Zahl und Länge der in diesem Installer enthaltenen Skills Speicher und Übertragungszeit beanspruchen. Fehler beim Anlegen oder Lesen der View folgen den üblichen DDL-, SELECT- und Ressourcenregeln von SQL Server. Die Texte sind Implementierungsdokumentation des Quellstands; aus Kataloganwesenheit folgen keine Installation, Berechtigung, fachliche Verfügbarkeit, vollständige Laufzeitevidenz oder atomare Quellsicht.
