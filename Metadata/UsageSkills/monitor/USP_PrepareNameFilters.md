---
skill_format_version: "1.0.0"
name: "monitor.USP_PrepareNameFilters"
schema_name: "monitor"
object_name: "USP_PrepareNameFilters"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure validiert bracket-aware Pipe-Listen für einteilige SQL-Namen und vollständige Objektbezüge und befüllt die vom Aufrufer benannte Temp-Tabelle."
source_path: "Code/01_Common/084_USP_PrepareNameFilters.sql"
---

# monitor.USP_PrepareNameFilters

## Zweck und Einsatz

Die Procedure validiert bracket-aware Pipe-Listen für einteilige SQL-Namen und vollständige Objektbezüge und befüllt die vom Aufrufer benannte Temp-Tabelle.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_PrepareNameFilters] im vorgesehenen Datenbankkontext. Der Helper liest nur die im Framework installierten Namensparser und schreibt in ein ausdrücklich bereitgestelltes lokales #Ziel; er liest keine Fachobjekte der gefilterten Datenbanken.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SchemaNames | nvarchar(max) | nein | NULL |
| @ObjectNames | nvarchar(max) | nein | NULL |
| @FullObjectNames | nvarchar(max) | nein | NULL |
| @IndexNames | nvarchar(max) | nein | NULL |
| @StatisticsNames | nvarchar(max) | nein | NULL |
| @ColumnNames | nvarchar(max) | nein | NULL |
| @StatusCode | varchar(40) | ja | kein Default; OUTPUT |
| @ErrorMessage | nvarchar(2048) | ja | kein Default; OUTPUT |
| @FilterTable | sysname | nein | N'#PrepareNameFilters_Result' |
| @Hilfe | bit | nein | 0 |

**@SchemaNames:** @SchemaNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType SCHEMA in NameValue abgelegt.

**@ObjectNames:** @ObjectNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType OBJECT in NameValue abgelegt.

**@FullObjectNames:** @FullObjectNames: nvarchar(max), Default NULL. TVF_ParseFullObjectNameList: | trennt außerhalb [...], ]] maskiert ] darin; äußere Elementleerzeichen entfernt; Rohsegmente max. 4000 UTF-16-Codeeinheiten. Formen Objekt, Schema.Objekt, Datenbank.Schema.Objekt; bei 3 Teilen Schema erforderlich, 4 Teile ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Überlange PARSENAME-Bestandteile können NULL ergeben, Fehlercode nicht zugesichert. Case-sensitive Duplikate FULL_OBJECT ungültig. Keine vollständige Syntax-/Existenz-/Rechteprüfung. Exklusiv mit angegebener Schema- oder Objektliste. Gültige Teile werden in DatabaseName/SchemaName/ObjectName gespeichert.

**@IndexNames:** @IndexNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType INDEX in NameValue abgelegt.

**@StatisticsNames:** @StatisticsNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType STATISTICS in NameValue abgelegt.

**@ColumnNames:** @ColumnNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType COLUMN in NameValue abgelegt.

**@StatusCode:** @StatusCode: Datentyp varchar(40); OUTPUT, ohne Default. Ein Argument ist auch bei @Hilfe=1 erforderlich, da kein Default existiert. Für den Empfang eine Aufrufervariable vom Typ varchar(40) mit OUTPUT binden, zum Beispiel @StatusCode=@CallerStatusCode OUTPUT. Ohne OUTPUT am Aufruf wird der Rückgabewert nicht empfangen. AVAILABLE bedeutet, dass die Listenprüfung erfolgreich war und gültige Zeilen angehängt wurden; bei sechs nicht angegebenen Listen bedeutet es erfolgreich keine neuen Zeilen. INVALID_PARAMETER kennzeichnet ungültige Listenstruktur/-namen, Exklusivitätsverletzung, case-sensitive Duplikate oder ungültigen Temp-Tabellennamen. INTERNAL_ERROR kennzeichnet eine fehlende oder nicht passende Filter-Temp-Tabelle bei der Schema-Prüfung. TIMEOUT wird bei SQL-Fehler 1222 gesetzt. DENIED_PERMISSION wird bei den abgefangenen Berechtigungsfehlernummern 229, 262, 297, 300, 371 oder 916 gesetzt. ERROR_HANDLED kennzeichnet einen anderen im Listen-/Vorbereitungspfad abgefangenen SQL-Fehler; dessen SQL-Fehlertext wird in @ErrorMessage ausgegeben. Bei @Hilfe=1 bleibt die Aufrufervariable unverändert.

**@ErrorMessage:** @ErrorMessage: Datentyp nvarchar(2048); OUTPUT, ohne Default. Ein Argument ist auch bei @Hilfe=1 erforderlich, da kein Default existiert. Für den Empfang eine Aufrufervariable vom Typ nvarchar(2048) mit OUTPUT binden, zum Beispiel @ErrorMessage=@CallerErrorMessage OUTPUT. Ohne OUTPUT am Aufruf wird der Rückgabewert nicht empfangen. Bei erfolgreicher Vorbereitung ist der Wert NULL; andernfalls empfängt er die Fehlerbeschreibung beziehungsweise im abgefangenen SQL-Fehlerpfad ERROR_MESSAGE(). Bei @Hilfe=1 bleibt er unverändert.

**@FilterTable:** @FilterTable: sysname, Default #PrepareNameFilters_Result. Vorhandene lokale # Tabelle derselben Session, kein ##, max. 116 Zeichen; NULL/falscher Präfix/Überlänge ungültig. Spalten FilterType varchar(20) NOT NULL, ItemOrdinal int NOT NULL, NameValue sysname NULL, DatabaseName sysname NULL, SchemaName sysname NULL, ObjectName sysname NULL; Textcollation SQL_Latin1_General_CP1_CS_AS. Wird nicht geleert; gültige Worktable-Zeilen angehängt. Fehler vor Insert lässt Altzeilen; abschließender Insertfehler nicht umfassend abgefangen.

**@Hilfe:** @Hilfe: bit, Default 0. 0 verarbeitet; 1 druckt Hilfe und kehrt vor OUTPUT-Initialisierung/Zieltabellenverarbeitung zurück; NULL normaler Pfad. Ausgelassen =0; numerisch ungleich 0 wird bit-konvertiert zu 1. Für beide OUTPUT-Parameter sind auch bei Hilfe Argumente anzugeben. Für den Empfang Variable mit OUTPUT binden; im Hilfepfad bleiben die übergebenen Eingangswerte unverändert.

## Resultate und Ausgabe

Kein Fach-Resultset. Der Helper füllt ausschließlich die vom Aufrufer benannte Filter-Temp-Tabelle mit gültigen, case-sensitiv eindeutigen Namenseinträgen. `@StatusCode varchar(40)` und `@ErrorMessage nvarchar(2048)` sind OUTPUTs; syntaktische Fehler oder Duplikate ergeben `INVALID_PARAMETER`, abgefangene Quellfehler erhalten einen Fehlerstatus. Der Helper wählt keine Fachobjekte aus und belegt keine Existenz.

## Beispiel

```sql
EXEC [monitor].[USP_PrepareNameFilters] @SchemaNames=N'[ExampleSchema]', @ObjectNames=N'[ExampleObject]', @StatusCode=@StatusCode OUTPUT, @ErrorMessage=@ErrorMessage OUTPUT, @FilterTable=N'#PrepareNameFilters_HelpExample';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_PrepareNameFilters validiert Namenslisten und ergänzt eine vorhandene lokale Filtertabelle. Sie liefert keine Analyse-Resultsets.

Einzelne Werte werden entquotet und case-sensitiv unter SQL_Latin1_General_CP1_CS_AS verglichen. Parser prüfen Struktur und PARSENAME-Ergebnisse; das ist keine vollständige SQL-Bezeichnergrammatik. Katalogexistenz und Berechtigungen werden nicht geprüft. Duplikate je Filtertyp sind ungültig.

Die Zieltabelle wird nicht vorab geleert. Gültige Zeilen werden angehängt. Ein Fehler vor dem abschließenden Insert lässt vorhandene Zeilen bestehen; der Insert ist nicht umfassend abgefangen. NULL in allen sechs Listen fügt keine Zeilen hinzu und setzt AVAILABLE.

Beispiel: ausführbarer Aufruf mit frischer, korrekt typisierter lokaler Tabelle und synthetischen Namen:

CREATE TABLE #PrepareNameFilters_HelpExample (FilterType varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, ItemOrdinal int NOT NULL, NameValue sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, SchemaName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, ObjectName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_PrepareNameFilters
Version      : 1.0.0
Stand        : 2026-07-15
Typ          : Öffentlicher Vorbereitungshelfer
Zweck        : Die Procedure validiert bracket-aware Pipe-Listen für einteilige SQL-Namen und
               vollständige Objektbezüge und befüllt die vom Aufrufer benannte
               Temp-Tabelle.
Voraussetzung: @FilterTable(FilterType, ItemOrdinal, NameValue, DatabaseName,
               SchemaName, ObjectName).
Hinweis      : Werte werden exakt case-sensitiv unter
               SQL_Latin1_General_CP1_CS_AS behandelt.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_PrepareNameFilters validiert Namenslisten und ergänzt eine vorhandene lokale Filtertabelle. Sie liefert keine Analyse-Resultsets.
Einzelne Werte werden entquotet und case-sensitiv unter SQL_Latin1_General_CP1_CS_AS verglichen. Parser prüfen Struktur und PARSENAME-Ergebnisse; das ist keine vollständige SQL-Bezeichnergrammatik. Katalogexistenz und Berechtigungen werden nicht geprüft. Duplikate je Filtertyp sind ungültig.
Die Zieltabelle wird nicht vorab geleert. Gültige Zeilen werden angehängt. Ein Fehler vor dem abschließenden Insert lässt vorhandene Zeilen bestehen; der Insert ist nicht umfassend abgefangen. NULL in allen sechs Listen fügt keine Zeilen hinzu und setzt AVAILABLE.
Beispiel: ausführbarer Aufruf mit frischer, korrekt typisierter lokaler Tabelle und synthetischen Namen:
CREATE TABLE #PrepareNameFilters_HelpExample (FilterType varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, ItemOrdinal int NOT NULL, NameValue sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, SchemaName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, ObjectName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
DECLARE @StatusCode varchar(40), @ErrorMessage nvarchar(2048);
DROP TABLE #PrepareNameFilters_HelpExample;
Bei Fehlern vor dem Insert bleibt das Ziel unverändert; es wird nicht geleert. Eine leere Tabelle kann auch einen erfolgreichen Aufruf mit ausschließlich NULL-Listen bedeuten.
```

