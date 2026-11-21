---
skill_format_version: "1.0.0"
name: "monitor.TVF_ParseBlockingResource"
schema_name: "monitor"
object_name: "TVF_ParseBlockingResource"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Die Funktion zerlegt einen Blocking-Ressourcenwert in syntaktisch erkannte IDs und bewahrt den Eingabewert."
source_path: "Code/01_Common/086a_TVF_ParseBlockingResource.sql"
---

# monitor.TVF_ParseBlockingResource

## Zweck und Einsatz

Die Funktion zerlegt einen Blocking-Ressourcenwert in syntaktisch erkannte IDs und bewahrt den Eingabewert. Sie greift weder auf Kataloge noch auf DMVs zu.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_ParseBlockingResource]. Die Funktion verarbeitet nur den übergebenen Ressourcenwert; sie liest selbst weder Kataloge noch DMVs, fremde Datenbanken oder Dateien.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @WaitResource | nvarchar(3072) | ja | kein Default |

**@WaitResource:** Pflichtwert nvarchar(3072), kein Default. NULL und leerer beziehungsweise nur aus Leerzeichen bestehender Text liefern jeweils eine EMPTY-Zeile. Für andere Werte werden äußere Leerzeichen entfernt und nur erkannte Ressourcenteilformen zerlegt; dies ist keine vollständige SQL-Server-Grammatik.

## Resultate und Ausgabe

Die zwölf Spalten, Datentypen, NULL-Zulässigkeit und Kollationen entsprechen der RETURNS-Tabelle: RawResource       nvarchar(3072), NULL, SQL_Latin1_General_CP1_CS_AS ResourceType      nvarchar(60),   NULL, SQL_Latin1_General_CP1_CS_AS FormatCode        varchar(40),    NOT NULL, SQL_Latin1_General_CP1_CS_AS DatabaseId        int,            NULL EntityId          bigint,         NULL SubEntityId       bigint,         NULL FileId            int,            NULL PageId            bigint,         NULL RowId             int,            NULL MetadataSubtype   nvarchar(60),   NULL, SQL_Latin1_General_CP1_CS_AS ResourceQualifier nvarchar(512),  NULL, SQL_Latin1_General_CP1_CS_AS ParseStatus       varchar(40),    NOT NULL, SQL_Latin1_General_CP1_CS_AS IDs ohne explizite Kollation verwenden die Datenbankstandardkollation.


## Beispiel

```sql
SELECT * FROM [monitor].[TVF_ParseBlockingResource](N'PAGE:5:1:123');
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
