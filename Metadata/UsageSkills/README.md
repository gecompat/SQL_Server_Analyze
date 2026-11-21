# Usage Skills als versionierter Quellvertrag

[Parameters.csv](../Inventory/Parameters.csv) erfasst nur öffentliche Procedure-Signaturen und [ResultSets.csv](../Inventory/ResultSets.csv) normale benannte Fachausgaben. Hilfe-Skill und Dokumentkatalog sind davon getrennte Projektionen; interne Signaturen werden gegen ihre SQL-Definition gebunden.

Die Markdown-Dateien in diesem Verzeichnis beschreiben die bekannte logische Objektmenge aus [Objects.csv](../Inventory/Objects.csv). Jede Objektdatei unter `<Schema>/<Objekt>.md` trägt eine versionierte YAML-Frontmatter mit Objektidentität, Typ, Datenbankrolle, internem Status, Beschreibung und kanonischem SQL-Quellpfad. Die einzelnen Abschnitte erläutern Eingaben, normale Resultate, Rechte, Aufwand, Nebenwirkungen, Fehler und Grenzen anhand der zugehörigen Implementierung. Ein Skill-Eintrag beweist weder die Installation noch effektive Berechtigungen oder eine erfolgreiche Laufzeitausführung.

Diese Usage-Skill-Quellerweiterung ist nach dem veröffentlichten Paket v1.2.0 entstanden. Das unveränderliche v1.2.0-ZIP enthält sie nicht. Zur Verwendung in einer Datenbank sind ein neuer aus diesen Quellen gebauter Installer und dessen eigene Abnahme erforderlich.

## Drei Projektionen aus derselben Markdown-Datei

`Code/Install/usage_skill_generator.py` verwendet die Markdown-Datei als kanonischen Text. Er schreibt einen markierten, zeilenkommentierten DDL-Abschnitt in die jeweilige Objektquelle und ein direktes `nvarchar(max)`-Skill-SELECT in den frühen `@Hilfe=1`-Zweig jeder Procedure. Der Hilfezweig gibt genau ein Resultset mit `SkillFormatVersion`, `SchemaName`, `ObjectName` und `SkillMarkdown` zurück. Vorhandene PRINT-Hinweise bleiben bei den öffentlichen Procedures erhalten. SQL muss auch für Hilfe alle ohne Default deklarierten Pflichtargumente typgerecht binden; fachliche Werteprüfung und Quellenaufnahme beginnen erst im normalen Fachweg. Bei den neu um Hilfe ergänzten internen Procedures bleiben eingehende OUTPUT-Variablen im Hilfefall unverändert.

Die dritte Projektion ist `monitor_metadata.VW_ObjectUsageSkills`. Sie enthält konstante Texte und liest weder SQL-Metadaten noch Installationszustand. In der Frameworkrolle stehen alle 195 bekannten Frameworkobjekte und der Self-Skill, in der Snapshot-Zielrolle 17 Zielobjekte und derselbe Self-Skill. Die eine kanonische Self-Datei trägt `DatabaseRole=both`; alle anderen Zeilen nennen eine Rolle. Teilinstaller der gleichen Rolle liefern die feste Dokumentationsmenge und belegen damit nicht die Installation sämtlicher Fachobjekte. Die View wird in den ausdrücklich ausgewählten Datenbanken installiert und benötigt für lesende Aufrufer SELECT auf der View.

## Ableitung und Prüfung

Die folgenden Befehle arbeiten am Repositoryquellstand; ihre Ausführung aktualisiert keine veröffentlichte Release-Datei:

```powershell
python Code/Install/usage_skill_generator.py --repository-root . --write-sources
python Code/Install/usage_skill_generator.py --repository-root . --write-views
python Code/Install/deployment_generator.py --repository-root . --refresh-snapshot-guard
python Code/Install/usage_skill_generator.py --repository-root . --check
python Code/Install/deployment_generator.py --repository-root . --check-snapshot-guard
python Code/Tests/Static/1054_Validate_Usage_Skill_Contract.py --repository-root . --self-test
```

`--write-sources` ersetzt nur vorhandene eindeutige Marker für DDL-Kommentar und Hilfeprojektion, nachdem alle betroffenen Marker geprüft wurden; normale Fachstatements bleiben außerhalb der Marker. `--write-views` erstellt die beiden festen Rollen-Views. Der kanonische Snapshot-Guard wird nach diesen Quellenänderungen regeneriert und anschließend streng geprüft. `--check` vergleicht die Projektionen zeichengetreu mit dem Markdown. Die statische Prüfung bestätigt Quellgleichheit und Struktur, keine SQL-Server-Ausführung. Native Tests müssen Hilfe vor Fachzugriff, Schema, vollständige Unicode-Länge und Textparität sowie Callerzustand separat belegen. Installations- und Releasegates folgen der [CI-Teststrategie](../../Documentation/Quality/CI_Test_Strategy.md).

## Einen Skill lesen

```sql
SELECT [SchemaName], [ObjectName], [ObjectType], [DatabaseRole],
       [SkillFormatVersion], [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'monitor'
  AND [ObjectName]=N'USP_CurrentObjectPermissionAnalysis';
```

Die View dokumentiert auch nicht installierte Fachobjekte der jeweiligen festen Rolle. Vor einem Fachaufruf sind daher Installation, Signatur, Kontext und Quellenrechte gesondert zu prüfen.
