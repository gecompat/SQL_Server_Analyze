---
skill_format_version: "1.0.0"
name: "monitor.USP_SchemaDesignAnalysis"
schema_name: "monitor"
object_name: "USP_SchemaDesignAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure leitet katalogbasierte Schema-/Designfindings je ausgewählter Datenbank ab."
source_path: "Code/03_ObjectIndex/090_USP_SchemaDesignAnalysis.sql"
---

# monitor.USP_SchemaDesignAnalysis

## Zweck und Einsatz

Die Procedure leitet katalogbasierte Schema-/Designfindings je ausgewählter Datenbank ab.

## Voraussetzungen und Rechte

sys.foreign_keys, sys.foreign_key_columns, sys.check_constraints, sys.indexes, sys.index_columns, sys.identity_columns, sys.sequences, sys.schemas und sys.tables.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @IdentityWarnPercent | decimal(5,2) | nein | 80.00 |
| @MaxZeilen | int | nein | 1000 |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. Eingabe ist eine Pipe-Liste einteiliger Datenbanknamen. | trennt nur außerhalb von [ ]; ]] maskiert ] innerhalb einer Klammerung. Äußere U+0020-Elementleerzeichen werden entfernt. Jedes Rohsegment darf höchstens 4000 UTF-16-Codeeinheiten haben; leere Elemente, fehlerhafte Klammerung, ungültige PARSENAME-Namen über 128 Zeichen und case-sensitive Duplikate machen die Liste ungültig. NULL, leer oder nur äußere U+0020-Leerzeichen bedeutet keine exakte Einschränkung; ausgelassen = NULL. Eine wirksame Liste ist exklusiv zu @DatabaseNamePattern. Ungültige Liste ergibt INVALID_PARAMETER. Namen ohne passende Kandidaten erzeugen Warnungen statt eines Filterfehlers. Ohne wirksame Liste werden alle sichtbaren, online befindlichen Benutzerdatenbanken berücksichtigt, vorbehaltlich Systemdatenbank-Opt-in und Pattern.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. Bit-Eingabe 0 oder 1; 0 schließt master, tempdb, model und msdb aus, 1 lässt sie in die Kandidatenauswahl zu. NULL ist INVALID_PARAMETER; ausgelassen = 0. Wirkt auch auf Warnungen zu explizit angeforderten, ausgeschlossenen Systemdatenbanken. SQL Server bindet numerische 0 als bit 0 und von 0 verschiedene konvertierbare Zahlen als bit 1.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. Ein LIKE-Muster (einschließlich SQL-LIKE-Wildcards %, _ und [...]) oder ein Pattern mit Präfix like:, regex: oder regexi:. Präfixerkennung ist ohne Beachtung der Großschreibung; äußere U+0020-Leerzeichen werden entfernt, der Rest nach Präfixentfernung nicht nochmals getrimmt. LIKE verwendet SQL_Latin1_General_CP1_CS_AS. regex: verwendet Flag c, regexi: Flag i; Regex-Syntax wird nicht vorgeprüft. Regex erfordert SQL Server 2025 (Major-Version 17) und Compatibility Level mindestens 170 der Installationsdatenbank; andernfalls UNAVAILABLE_FEATURE. Regex filtert Kandidaten nach deren Ermittlung. NULL/ausgelassen bedeutet kein Pattern. Leer, nur U+0020-Leerzeichen oder ein leeres Präfixergebnis ist ungültig; jedes nicht-NULL Pattern zusammen mit einer wirksamen @DatabaseNames-Liste ist INVALID_PARAMETER.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. Bit-Eingabe 0 oder 1. Die Procedure prüft den Analysepfad CATALOG_DEEP; dessen Katalogeintrag hat RequiresGroupGate=1. Bei einem tatsächlich aktivierten, gruppengeschützten Pfad führt 0 zum Status HIGH_IMPACT_CONFIRMATION_REQUIRED; 1 bestätigt nur diese Anforderung und erteilt keine Freigabe. Die aktuelle Pfadfreigabe wird separat geprüft und kann DENIED_GROUP ergeben. NULL ist INVALID_PARAMETER, auch wenn kein Pfad freigegeben ist; ausgelassen = 0. SQL Server bindet numerische 0 als bit 0 und von 0 verschiedene konvertierbare Zahlen als bit 1.

**@IdentityWarnPercent:** @IdentityWarnPercent decimal(5,2); Default: 80.00. Prozentschwelle nach Bindung an decimal(5,2), zulässiger Bereich 0 bis 100; außerhalb INVALID_PARAMETER. Ausgelassen = 80.00. Identity-UsedPercent nutzt den vollen Typbereich: tinyint 0–255, smallint −32768–32767, int −2147483648–2147483647, bigint −9223372036854775808–9223372036854775807. Bei Inkrement größer oder gleich 0 wird ab Typminimum, bei negativem Inkrement ab Typmaximum gemessen. Seed, Reseed und fachlicher Wertebereich sind darin nicht berücksichtigt. Sequence-UsedPercent nutzt dagegen die konfigurierten minimum_value und maximum_value mit gleicher Richtungsunterscheidung. Findings entstehen ab UsedPercent >= Schwelle; is_exhausted=1 erzeugt ein Sequence-Finding unabhängig von der Schwelle. HIGH gilt ab 95 Prozent oder bei erschöpfter Sequence, sonst MEDIUM. NULL passiert die Bereichsprüfung: Identity-Schwellenvergleiche liefern damit kein Finding; erschöpfte Sequences können weiterhin Findings liefern. Leertext muss vor Ausführung numerisch konvertierbar sein; NULL deaktiviert keine anderen Designregeln.

**@MaxZeilen:** @MaxZeilen int; Default: 1000. Ganzzahliger Zeilenhöchstwert im int-Bereich: 0 bis 2147483647. NULL oder 0 bedeutet unbegrenzt; ausgelassen = 1000; negative Werte sind INVALID_PARAMETER. Nur RAW und JSON begrenzen Findings nach Priorität (HIGH, MEDIUM, übrige), DatabaseId, SchemaName, ObjectName und FindingCode. CONSOLE zeigt und TABLE schreibt alle Findings; NONE gibt keine Resultsets aus. Warnungen werden durch diesen Grenzwert nicht beschränkt. Das TOP-Limit begrenzt weder Katalogjoins, Findingregeln noch vorgelagerte Quellarbeit.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Nach LTRIM/RTRIM von U+0020-Leerzeichen und UPPER ausgewertet. Zulässig sind RAW (Status-Resultset, auf @MaxZeilen begrenzte Findings, danach alle Warnungen), CONSOLE (ein lesbares Resultset mit allen Findings, bei leerer Quelle eine verständliche Leerzeile; kein separates Status- oder Warnungsresultset), TABLE (schreibt alle Findings in das erforderliche Ziel und gibt kein Resultset aus) und NONE (keine Resultsets). NULL, Leerwert und andere Texte sind INVALID_PARAMETER; ausgelassen = CONSOLE. @JsonErzeugen wirkt unabhängig davon. TABLE benötigt ein gültiges @ResultTablesJson-Mapping; außerhalb TABLE löst ein nach Trim von U+0020 nicht leerer Mappingwert THROW 51011 aus.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Für TABLE ein JSON-Objekt mit genau dem Schlüssel findings und einem Stringwert für den Namen einer vorhandenen lokalen #Temp-Tabelle, z. B. N'{"findings":"#SchemaDesignAnalysis_HelpExample"}'. Das Ziel muss leer sein und genau eine Seed-Spalte besitzen; das Mapping darf keine fremden Namen/Ziele enthalten. NULL oder nach Trim von U+0020 leere Eingabe eignet sich nur außerhalb TABLE; bei TABLE schlägt der Preflight fehl. Bei RAW, CONSOLE oder NONE werden NULL/nach Trim von U+0020 leere Werte ignoriert; ein nicht leerer Wert löst Fehler 51011 aus. Ausgelassen = NULL.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Bit-Schalter: 1 erzeugt unabhängig von @ResultSetArt ein JSON-Dokument in @Json; 0 erzeugt keines. NULL wird nicht als ungültig abgewiesen und erfüllt die IF-Bedingung nicht; ausgelassen = 0. Leere Texteingabe ist nicht sinnvoll; eine explizite Nicht-Bit-Angabe muss bereits bei Parameterbindung in bit konvertierbar sein. SQL Server bindet numerische 0 als bit 0 und von 0 verschiedene konvertierbare Zahlen als bit 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Reiner OUTPUT-Parameter; Eingabewert ist nicht maßgeblich. Wird bei jedem Aufruf vor der Hilfe- und Parameterprüfung auf NULL gesetzt. Wenn @JsonErzeugen=1, enthält er ein Objekt mit meta, findings und warnings; Findings unterliegen @MaxZeilen, Warnings nicht. Sonst bleibt er NULL. Zum Empfang eine nvarchar(max)-Variable mit OUTPUT binden; bei Auslassen existiert kein empfangbarer Aufrufwert.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Unbenutzter bit-Parameter: 0, 1 und NULL beeinflussen weder Meldungen noch Resultsets; ausgelassen = 1. Konvertierbare numerische 0 bleibt bit 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. Nicht konvertierbare Eingaben scheitern bei der Parameterbindung.

**@Hilfe:** @Hilfe bit; Default: 0. Bit-Eingabe. 1 gibt die Hilfe per PRINT aus und kehrt vor Analyse, regulären Statuszuweisungen und Resultsetausgabe zurück; allerdings laufen vorher Modus-/Mappingprüfungen und @Json wird bereits auf NULL gesetzt. Andere OUTPUT-Parameter werden im Hilfezweig nicht zugewiesen. NULL wird nicht gesondert geprüft und nimmt wie 0 den normalen Analysepfad; ausgelassen = 0. 0 führt den normalen Pfad aus. Leere Texteingabe ist nicht sinnvoll; explizite Werte müssen bei Bindung in bit konvertierbar sein. SQL Server bindet numerische 0 als bit 0 und von 0 verschiedene konvertierbare Zahlen als bit 1.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfang, etwa @StatusCodeOut=@Status OUTPUT mit einer varchar(40)-Variablen. Werte: AVAILABLE (Kandidatenlauf ohne Findings und Teilwarnungen), AVAILABLE_WITH_FINDING (Findings ohne Teilwarnungen), AVAILABLE_LIMITED (Warnungen oder Teilergebnisse), DATABASE_UNAVAILABLE (keine Kandidatendatenbank), INVALID_PARAMETER (ungültige lokale oder vorbereitete Eingabe), HIGH_IMPACT_CONFIRMATION_REQUIRED (erforderliche Bestätigung fehlt), DENIED_GROUP (Pfad nicht freigegeben), UNAVAILABLE_FEATURE (benötigtes Feature fehlt), INTERNAL_ERROR (interner Vorbereitungsvertrag verletzt). DENIED_PERMISSION und ERROR_HANDLED gehören zu datenbankweisen Warnzeilen und sind keine StatusCodeOut-Werte. Die reguläre Zuweisung erfolgt nach Vorbereitung und Statusaggregation. Hilfe lässt die Variable unverändert; ein früher THROW erreicht die Zuweisung nicht. Ausgelassen beziehungsweise NULL als Anfangswert ist zulässig; ohne OUTPUT-Bindung wird kein Wert empfangen.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionaler OUTPUT-Empfang, etwa @IsPartialOut=@Partial OUTPUT mit einer bit-Variablen. 1 kennzeichnet lokale Parametervalidierungsfehler, Kandidatenwarnungen, datenbankweise Fehler oder fehlende Kandidatendatenbanken; im normalen Lauf ohne Teilfehler gilt 0. Ein abgewiesener delegierter Vorbereitungspfad, etwa HIGH_IMPACT_CONFIRMATION_REQUIRED oder DENIED_GROUP, kann 0 belassen, obwohl keine Analyse lief. Der Wert ist daher kein allgemeines Erfolgs- oder Vollständigkeitsbit. Die reguläre Zuweisung erfolgt erst nach Aggregation; Hilfe lässt die Variable unverändert und ein früher THROW umgeht die Zuweisung. Ausgelassen beziehungsweise NULL als Anfangswert ist zulässig; ohne OUTPUT-Bindung kein Empfang.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Optionaler OUTPUT-Empfang, etwa @ErrorNumberOut=@ErrorNumber OUTPUT mit einer int-Variablen. Im aktuellen normalen Lauf bleibt die lokale Fehlernummer stets NULL; datenbankweise Fehlernummern stehen separat in warnings. Zuweisung am Ende der Vorbereitung und Aggregation, vor der Ausgabe. Hilfe lässt die Variable unverändert; ein früher THROW erreicht die Zuweisung nicht. Ausgelassen oder NULL als Anfangswert ist zulässig; ohne OUTPUT-Bindung kein Empfang.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfang, etwa @ErrorMessageOut=@ErrorMessage OUTPUT mit einer nvarchar(2048)-Variablen. Der normale Lauf liefert die globale Vorbereitungs-/Parameterfehlermeldung oder NULL bei erfolgreicher Vorbereitung; datenbankweise Meldungen stehen separat in warnings. Zuweisung nach Vorbereitung und Aggregation, vor Ausgabe. Hilfe lässt die Variable unverändert; ein früher THROW erreicht die Zuweisung nicht. Ausgelassen oder NULL als Anfangswert ist zulässig; ohne OUTPUT-Bindung kein Empfang.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| findings | 1 | 1 | [DatabaseId] int NOT NULL , [DatabaseName] sysname NOT NULL , [FindingCode] varchar(100) NOT NULL , [Severity] varchar(16) NOT NULL , [ObjectType] nvarchar(60) NULL , [SchemaName] sysname NULL , [ObjectName] sysname NULL , [RelatedObjectName] sysname NULL , [MetricValue] decimal(38,4) NULL , [Evidence] nvarchar(1000) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_SchemaDesignAnalysis] @DatabaseNames=N'[ExampleDatabase]',@HighImpactConfirmed=1,@ResultSetArt='RAW';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Kein DDL und keine automatische Lösch-/Indexempfehlung. Nutzung, Workload, Filtersemantik und Änderungsrisiko separat prüfen.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_SchemaDesignAnalysis
Version      : 1.0.0
Stand        : 2026-07-17
Zweck        : Die Procedure leitet katalogbasierte Schema-/Designfindings je ausgewählter Datenbank ab.
Datenquellen : sys.foreign_keys, sys.foreign_key_columns,
               sys.check_constraints, sys.indexes, sys.index_columns,
               sys.identity_columns, sys.sequences, sys.schemas
               und sys.tables.
Prüfungen    : deaktivierte/nicht vertrauenswürdige Constraints,
               fehlender FK-Stützindex, hypothetische/deaktivierte und exakt
               gleiche Indizes sowie Identity-/Sequence-Wertebereich.
Grenzen      : Kein DDL und keine automatische Lösch-/Indexempfehlung. Nutzung,
               Workload, Filtersemantik und Änderungsrisiko separat prüfen.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_SchemaDesignAnalysis
Die Procedure liest katalogbasierte Schema-, Constraint-, Index-, Identity- und Sequence-Metadaten ausgewählter Datenbanken; sie erstellt oder ändert keine Constraints und Indizes.
Der Aufruf delegiert die Pfadprüfung als CATALOG_DEEP. Dessen aktueller Katalogeintrag sieht ein Gruppengate vor; @HighImpactConfirmed=1 bestätigt nur dieses Gate und ersetzt weder aktuelle Freigabe noch enge Scopewahl.
DECLARE @SchemaDesignJson nvarchar(max); EXEC [monitor].[USP_SchemaDesignAnalysis] @DatabaseNames=N'[ExampleDatabase]',@HighImpactConfirmed=1,@JsonErzeugen=1,@Json=@SchemaDesignJson OUTPUT; SELECT @SchemaDesignJson AS [SchemaDesignJson];
```

