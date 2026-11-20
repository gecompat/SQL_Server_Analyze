---
skill_format_version: "1.0.0"
name: "monitor.InternalCollectExecutionPlanMetadata"
schema_name: "monitor"
object_name: "InternalCollectExecutionPlanMetadata"
object_type: "INTERNAL_PROCEDURE"
database_role: "framework"
is_internal: true
description: "Die Procedure ermittelt zu einem Ausführungsplan Objekt-, Index- und Statistikmetadaten der ausdrücklich bestätigten Quellumgebung."
source_path: "Code/04_PlanCache/049_InternalCollectExecutionPlanMetadata.sql"
---

# monitor.InternalCollectExecutionPlanMetadata

## Zweck und Einsatz

Die Procedure ermittelt zu einem Ausführungsplan Objekt-, Index- und Statistikmetadaten der ausdrücklich bestätigten Quellumgebung. Sie kann Histogrammschritte und Zusammenfassungen sowie Zuordnungen zu Planprädikaten sammeln.

## Voraussetzungen und Rechte

Der Aufrufer legt die fünf Evidenz-Temp-Tabellen mit dem erwarteten Schema an. Je ein TOP (0)-SELECT prüft Existenz und Schemaauflösung, nicht das vollständige Schema oder die Berechtigungen. Die fünf Prüfungen erzeugen fünf leere Resultsets.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @PlanXml | xml | ja | kein Default |
| @StatistikEvidenzModus | varchar(16) | nein | 'USED' |
| @HistogrammModus | varchar(16) | nein | 'NONE' |
| @QuellumgebungBestaetigt | bit | nein | 0 |
| @MitPredicateHistogramMap | bit | nein | 1 |
| @MaxStatistiken | int | nein | 100 |
| @MaxHistogrammSchritte | int | nein | 20000 |
| @LockTimeoutMs | int | nein | 0 |
| @HighImpactConfirmed | bit | nein | 0 |
| @StatusCodeOut | varchar(40) OUTPUT | nein | NULL |
| @IsPartialOut | bit OUTPUT | nein | NULL |
| @ErrorNumberOut | int OUTPUT | nein | NULL |
| @ErrorMessageOut | nvarchar(2048) OUTPUT | nein | NULL |
| @Hilfe | bit | nein | 0 |

**@PlanXml:** @PlanXml xml, Default: keiner; obligatorisch. Eingabeform: einzelner XML-Ausführungsplan als XML-Wert oder gebundene XML-Variable; NULL ergibt INVALID_PARAMETER. Ein leeres, gültiges XML wird nicht ausdrücklich abgewiesen.

**@StatistikEvidenzModus:** @StatistikEvidenzModus varchar(16), Default: 'USED'. Eingabeform: ein einzelner Modus-Textwert, keine Liste. NULL wird zur Laufzeit zu USED; äußere Leerzeichen werden entfernt, Großschreibung angewendet. Endliche Werte: USED sammelt nur vom Plan als verwendet gemeldete Statistiken; RELEVANT ergänzt Statistiken, deren führende Spalte im Plan als SEEK, RESIDUAL, JOIN, ORDER_BY oder GROUP_BY vorkommt; OBJECT_ALL ergänzt alle Statistiken katalogauflösbarer Planobjekte. Leertext ist ungültig.

**@HistogrammModus:** @HistogrammModus varchar(16), Default: 'NONE'. Eingabeform: einzelner Modus-Textwert, keine Liste. NULL wird zur Laufzeit zu NONE; äußere Leerzeichen werden entfernt, Großschreibung angewendet. Endliche Werte: NONE sammelt im Hauptteil keine zusätzlichen Schritte; SUMMARY und STEPS sammeln Schritte und bilden Zusammenfassungen, wobei STEPS zusätzlich High-Impact-Bestätigung verlangt. Die Sammlung ist in beiden Modi gleich. Vorhandene Zeilen werden auch bei NONE zusammengefasst und können zugeordnet werden. Leertext oder nur Leerzeichen ist ungültig.

**@QuellumgebungBestaetigt:** @QuellumgebungBestaetigt bit, Default: 0. Eingabeform: einzelner SQL-bit- Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 bestätigt die Quellumgebung; 0 oder NULL ergeben INVALID_PARAMETER. Ausgelassen bindet den Default 0 und ergibt ebenfalls INVALID_PARAMETER. Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert und wie fehlende Bestätigung abgelehnt.

**@MitPredicateHistogramMap:** @MitPredicateHistogramMap bit, Default: 1. Eingabeform: einzelner SQL-bit- Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 ordnet extrahierte Planparameterwerte Histogrammschritten zu; 0 überspringt die Zuordnung. NULL ergibt INVALID_PARAMETER. Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert und überspringt die Zuordnung.

**@MaxStatistiken:** @MaxStatistiken int, Default: 100. Eingabeform: einzelner SQL-int-Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. Ganze Zahl 1 bis 1000 einschließlich; NULL und Werte außerhalb ergeben INVALID_PARAMETER. Begrenzt die insgesamt ausgewählten Kandidaten nach Priorität PLAN_USED, RELEVANT_LEADING_COLUMN, danach übrige. RELEVANT/OBJECT_ALL- Kandidaten werden vor dem Limit aus dem Katalog gelesen; ein positives Limit verhindert diese anfängliche Abfrage nicht. Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert und liegt außerhalb des gültigen Bereichs.

**@MaxHistogrammSchritte:** @MaxHistogrammSchritte int, Default: 20000. Eingabeform: einzelner SQL-int- Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. Ganze Zahl 0 bis 200000 einschließlich; NULL und Werte außerhalb ergeben INVALID_PARAMETER. Begrenzt zusätzliche Schritte global anhand der bereits in der Aufrufer-Schritttabelle vorhandenen Zeilen; der Wert 0 fügt keine neuen Schritte ein. Bei erreichtem Limit werden keine weiteren eingefügt und vorhandene Zeilen nicht entfernt. Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert und fügt keine neuen Schritte ein.

**@LockTimeoutMs:** @LockTimeoutMs int, Default: 0. Eingabeform: einzelner SQL-int-Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. Ganze Zahl 0 bis 60000 Millisekunden; NULL und Werte außerhalb ergeben INVALID_PARAMETER. Steuert LOCK_TIMEOUT im Hauptteil nach frühen Prüfungen. Die Procedure setzt zuerst LOCK_TIMEOUT 0 und speichert den Wert erst danach; am Ende wird somit 0 statt des vorherigen Aufruferwerts wiederhergestellt. Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert; 0 Millisekunden bedeutet kein Warten auf eine Sperre.

**@HighImpactConfirmed:** @HighImpactConfirmed bit, Default: 0. Eingabeform: einzelner SQL-bit-Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 bestätigt den High-Impact-Pfad, 0 nicht. Für RELEVANT, OBJECT_ALL und STEPS führt 0 zu HIGH_IMPACT_CONFIRMATION_REQUIRED; SUMMARY allein verlangt die Bestätigung nicht. NULL ergibt vor den Temp-Tabellen- Prüfungen INVALID_PARAMETER. Die lokale Bestätigungsprüfung erfolgt vor dem optionalen Gate-Aufruf; dessen Ergebnisse können außerdem HIGH_IMPACT_CONFIRMATION_REQUIRED, INVALID_PARAMETER oder DENIED_GROUP sein. Bei SQL-bit-Konvertierung kann ein numerischer Nichtnullwert ungleich 0 zu 1 werden. Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert; für einen breiten Pfad fehlt damit die Bestätigung.

**@StatusCodeOut:** @StatusCodeOut varchar(40), Default: NULL OUTPUT. Eingabeform: einzelner varchar-Wert/Skalar oder OUTPUT-Variable. Eingehendes NULL und Leertext sind erlaubt, werden ignoriert. Eingehender Wert wird ignoriert und zuerst auf AVAILABLE gesetzt. Lokal mögliche Werte: AVAILABLE, INVALID_PARAMETER, INTERNAL_ERROR, HIGH_IMPACT_CONFIRMATION_REQUIRED, PARTIAL, LOCK_TIMEOUT und ERROR_HANDLED; Gate-Statuswerte werden weitergereicht. AVAILABLE bedeutet regulär beendet ohne gesetztes Teilfehlerflag, nicht vollständige Metadaten; INVALID_PARAMETER bedeutet lokal erkannter ungültiger Parameter oder ein entsprechendes Gate-Ergebnis; INTERNAL_ERROR bedeutet Fehler einer Temp-Tabellenprobe; HIGH_IMPACT_CONFIRMATION_REQUIRED bedeutet fehlende Bestätigung des breiten Pfads; PARTIAL bedeutet verzeichneten Teilfehler bei ansonsten regulärem Ende; LOCK_TIMEOUT bedeutet Fehler 1222 im äußeren Hauptteil-CATCH; ERROR_HANDLED bedeutet einen anderen Fehler in diesem CATCH; DENIED_GROUP bedeutet vom Gate nicht freigegebenen CATALOG_DEEP-Pfad. Das Gate kann INVALID_PARAMETER insbesondere bei NULL-Bestätigung oder ungültiger/unbekannter Analyseklasse liefern. Zum Empfangen passende Variable mit OUTPUT; ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe verworfen werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@IsPartialOut:** @IsPartialOut bit, Default: NULL OUTPUT. Eingabeform: einzelner SQL-bit- Wert/Skalar oder OUTPUT-Variable; NULL ist erlaubt und wird ignoriert, leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. Eingehender Wert wird ignoriert, zuerst 0, bei Teil- oder Fehlerausgabe 1. Zum Empfangen passende Variable mit OUTPUT; ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe verworfen werden. Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert; der Eingang wird wie NULL ignoriert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorNumberOut:** @ErrorNumberOut int, Default: NULL OUTPUT. Eingabeform: einzelner SQL-int- Wert/Skalar oder OUTPUT-Variable; NULL ist erlaubt und wird ignoriert, leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. Eingehender Wert wird ignoriert, zunächst NULL. Bei abgefangenen Fehlern enthält er ERROR_NUMBER() im Hauptteil-CATCH oder der Temp-Probe; Einzelquellenfehler können PARTIAL bei weiter NULL liefern. Gewöhnliche Parameter- oder Gate-Statuswerte setzen ihn nicht neu. Zum Empfangen passende Variable mit OUTPUT; ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe verworfen werden. Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert; der Eingang wird wie NULL ignoriert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048), Default: NULL OUTPUT. Eingabeform: einzelner nvarchar-Wert/Skalar oder OUTPUT-Variable; NULL und Leertext sind erlaubt und werden ignoriert. Eingehender Wert wird ignoriert, zunächst NULL. Lokale Parameterfehler, Temp-Tabellenprobe, Gate-Rückgabe und Hauptteil-CATCH setzen die jeweilige Meldung. Bei AVAILABLE sowie PARTIAL durch Einzelquellenfehler kann er NULL bleiben; Details stehen dann im CollectionStatus. Zum Empfangen passende Variable mit OUTPUT; ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe verworfen werden. Bei SQL-bit-Konvertierungen kann ein numerischer Nichtnullwert ungleich 0 bereits zu 1 konvertiert sein. Wirkung       : Liest Planreferenzen sowie SQL-Server-Katalog- und Statistikmetadaten und schreibt in #CreateExecutionEvidenceJson_StatisticsCurrent, #CreateExecutionEvidenceJson_HistogramSteps, #CreateExecutionEvidenceJson_HistogramSummary, #CreateExecutionEvidenceJson_PredicateHistogramMappings und #CreateExecutionEvidenceJson_CollectionStatus. Diese Daten werden nicht als Resultsets ausgegeben. Histogrammrohwerte werden in lokalen Tabellen verarbeitet; Prädikatwerte liegen in einer internen Temp-Tabelle. Keine Zusage vollständiger Katalogerfassung, atomarer Änderungen oder einer über die tatsächlichen SQL-Server-Prüfungen hinausgehenden Berechtigungssicherheit. Grenzen      : SET LOCK_TIMEOUT 0 erfolgt vor allen Prüfungen und gilt innerhalb der Procedure auch auf frühen Rückgabepfaden. Die eigene Wiederherstellungsanweisung im Hauptteil verwendet den danach gespeicherten Wert 0, keine vor Eintritt gesicherte Kopie. Der optionale Gate-Aufruf und sein Katalogzugriff liegen vor dem Hauptteil-TRY; dort unerwartet weitergeworfene Fehler können ohne Umsetzung in die globalen Fehlerausgaben entweichen. Fehler        : Wenn eine referenzierte Datenbank bei der Kandidatenermittlung unzugänglich ist, wird dafür ein CollectionStatus-Eintrag geschrieben. Fehler in den Schleifen werden soweit abgefangen ebenfalls erfasst und markieren die Ausgabe als partiell. Fehler in der initialen Temp-Tabellenprobe setzen INTERNAL_ERROR und geben zurück. Gate-Ergebnisse INVALID_PARAMETER (ungültige Klasse oder Bestätigung), HIGH_IMPACT_CONFIRMATION_REQUIRED (Bestätigung fehlt) und DENIED_GROUP (Pfad nicht freigegeben) können durchgereicht werden; ErrorNumberOut kann dabei NULL bleiben. Der äußere CATCH des Hauptteils setzt LOCK_TIMEOUT bei Fehler 1222, sonst ERROR_HANDLED, samt Fehlernummer und -text. Bei einer späteren Datenbankprüfung ohne ELSE können inzwischen nicht erreichbare Datenbanken ohne eigenen Statusdatensatz bleiben. Bereits geschriebene Zeilen werden nicht zurückgerollt. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Die fünf TOP (0)-Probes der vom Aufrufer angelegten Evidenz-#Temp-Tabellen erzeugen fünf leere Schema-Resultsets. Daten werden in diese lokalen Tabellen geschrieben, darunter Objekt-/Index-/Statistikmetadaten, CollectionStatus und gegebenenfalls Histogramm- und Prädikatzuordnungen; diese Zeilen werden nicht als zusätzliche fachliche Resultsets ausgegeben. `@StatusCodeOut` (varchar(40) OUTPUT) beginnt mit AVAILABLE und kann lokal INVALID_PARAMETER, INTERNAL_ERROR, HIGH_IMPACT_CONFIRMATION_REQUIRED, PARTIAL, LOCK_TIMEOUT oder ERROR_HANDLED sowie weitergereichte Gate-Statuswerte enthalten. `@IsPartialOut` (bit OUTPUT) beginnt mit 0 und kennzeichnet Teil-/Fehlerausgabe mit 1. `@ErrorNumberOut` (int OUTPUT) und `@ErrorMessageOut` (nvarchar(2048) OUTPUT) beginnen NULL; Einzelquellenfehler können PARTIAL ohne Fehlernummer ergeben. Die fünf TOP (0)-Probes belegen keinen vollständigen Schema- oder Rechtevertrag.

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.


## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalCollectExecutionPlanMetadata';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [monitor].[InternalCollectExecutionPlanMetadata] @PlanXml=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

SET LOCK_TIMEOUT 0 erfolgt vor allen Prüfungen und gilt innerhalb der Procedure auch auf frühen Rückgabepfaden. Die eigene Wiederherstellungsanweisung im Hauptteil verwendet den danach gespeicherten Wert 0, keine vor Eintritt gesicherte Kopie. Der optionale Gate-Aufruf und sein Katalogzugriff liegen vor dem Hauptteil-TRY; dort unerwartet weitergeworfene Fehler können ohne Umsetzung in die globalen Fehlerausgaben entweichen.

Wenn eine referenzierte Datenbank bei der Kandidatenermittlung unzugänglich ist, wird dafür ein CollectionStatus-Eintrag geschrieben. Fehler in den Schleifen werden soweit abgefangen ebenfalls erfasst und markieren die Ausgabe als partiell. Fehler in der initialen Temp-Tabellenprobe setzen INTERNAL_ERROR und geben zurück. Gate-Ergebnisse INVALID_PARAMETER (ungültige Klasse oder Bestätigung), HIGH_IMPACT_CONFIRMATION_REQUIRED (Bestätigung fehlt) und DENIED_GROUP (Pfad nicht freigegeben) können durchgereicht werden; ErrorNumberOut kann dabei NULL bleiben. Der äußere CATCH des Hauptteils setzt LOCK_TIMEOUT bei Fehler 1222, sonst ERROR_HANDLED, samt Fehlernummer und -text. Bei einer späteren Datenbankprüfung ohne ELSE können inzwischen nicht erreichbare Datenbanken ohne eigenen Statusdatensatz bleiben. Bereits geschriebene Zeilen werden nicht zurückgerollt.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.InternalCollectExecutionPlanMetadata
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Interne Stored Procedure
Zweck        : Die Procedure ermittelt zu einem Ausführungsplan Objekt-,
               Index- und Statistikmetadaten der ausdrücklich bestätigten
               Quellumgebung. Sie kann Histogrammschritte und Zusammenfassungen
               sowie Zuordnungen zu Planprädikaten sammeln.
Voraussetzung: Der Aufrufer legt die fünf Evidenz-Temp-Tabellen mit dem
               erwarteten Schema an. Je ein TOP (0)-SELECT prüft Existenz und
               Schemaauflösung, nicht das vollständige Schema oder die
               Berechtigungen. Die fünf Prüfungen erzeugen fünf
               leere Resultsets.
Eingabe      :
  @PlanXml xml, Default: keiner; obligatorisch. Eingabeform: einzelner
               XML-Ausführungsplan als XML-Wert oder gebundene XML-Variable;
               NULL ergibt INVALID_PARAMETER. Ein leeres, gültiges XML wird
               nicht ausdrücklich abgewiesen.
  @StatistikEvidenzModus varchar(16), Default: 'USED'. Eingabeform: ein
               einzelner Modus-Textwert, keine Liste. NULL wird zur Laufzeit
               zu USED;
               äußere Leerzeichen werden entfernt, Großschreibung angewendet.
               Endliche Werte: USED sammelt nur vom Plan als verwendet
               gemeldete Statistiken; RELEVANT ergänzt Statistiken, deren
               führende Spalte im Plan als SEEK, RESIDUAL, JOIN, ORDER_BY oder
               GROUP_BY vorkommt; OBJECT_ALL ergänzt alle Statistiken
               katalogauflösbarer Planobjekte. Leertext ist ungültig.
  @HistogrammModus varchar(16), Default: 'NONE'. Eingabeform: einzelner
               Modus-Textwert, keine Liste. NULL wird zur Laufzeit zu NONE;
               äußere Leerzeichen werden entfernt, Großschreibung angewendet.
               Endliche Werte: NONE sammelt im Hauptteil keine zusätzlichen Schritte;
               SUMMARY und STEPS sammeln Schritte und bilden Zusammenfassungen,
               wobei STEPS zusätzlich High-Impact-Bestätigung verlangt. Die
               Sammlung ist in beiden Modi gleich. Vorhandene Zeilen werden
               auch bei NONE zusammengefasst und können zugeordnet werden.
               Leertext oder nur Leerzeichen ist ungültig.
  @QuellumgebungBestaetigt bit, Default: 0. Eingabeform: einzelner SQL-bit-
               Wert oder Variable; leere Zeichenfolge ist keine vorgesehene
               Typform und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 bestätigt die
               Quellumgebung; 0 oder NULL ergeben INVALID_PARAMETER. Ausgelassen
               bindet den Default 0 und ergibt ebenfalls INVALID_PARAMETER.
               Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert und wie
               fehlende Bestätigung abgelehnt.
  @MitPredicateHistogramMap bit, Default: 1. Eingabeform: einzelner SQL-bit-
               Wert oder Variable; leere Zeichenfolge ist keine vorgesehene
               Typform und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 ordnet
               extrahierte Planparameterwerte Histogrammschritten zu; 0
               überspringt die Zuordnung. NULL ergibt INVALID_PARAMETER.
               Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert und
               überspringt die Zuordnung.
  @MaxStatistiken int, Default: 100. Eingabeform: einzelner SQL-int-Wert oder
               Variable; leere Zeichenfolge ist keine vorgesehene Typform und
               wird vor Eintritt konvertiert. Ganze Zahl 1 bis 1000 einschließlich;
               NULL und Werte außerhalb ergeben INVALID_PARAMETER. Begrenzt
               die insgesamt ausgewählten Kandidaten nach Priorität PLAN_USED,
               RELEVANT_LEADING_COLUMN, danach übrige. RELEVANT/OBJECT_ALL-
               Kandidaten werden vor dem Limit aus dem Katalog gelesen; ein
               positives Limit verhindert diese anfängliche Abfrage nicht.
               Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert und liegt
               außerhalb des gültigen Bereichs.
  @MaxHistogrammSchritte int, Default: 20000. Eingabeform: einzelner SQL-int-
               Wert oder Variable; leere Zeichenfolge ist keine vorgesehene
               Typform und wird vor Eintritt konvertiert. Ganze Zahl 0 bis 200000
               einschließlich; NULL und Werte außerhalb ergeben
               INVALID_PARAMETER. Begrenzt zusätzliche Schritte global anhand
               der bereits in der Aufrufer-Schritttabelle vorhandenen Zeilen;
               der Wert 0 fügt keine neuen Schritte ein.
               Bei erreichtem Limit werden keine weiteren eingefügt und
               vorhandene Zeilen nicht entfernt.
               Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert und fügt
               keine neuen Schritte ein.
  @LockTimeoutMs int, Default: 0. Eingabeform: einzelner SQL-int-Wert oder
               Variable; leere Zeichenfolge ist keine vorgesehene Typform und
               wird vor Eintritt konvertiert. Ganze Zahl 0 bis 60000 Millisekunden;
               NULL und Werte außerhalb ergeben INVALID_PARAMETER. Steuert
               LOCK_TIMEOUT im Hauptteil nach frühen Prüfungen. Die Procedure
               setzt zuerst LOCK_TIMEOUT 0 und speichert den Wert erst danach;
               am Ende wird somit 0 statt des vorherigen Aufruferwerts
               wiederhergestellt.
               Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert; 0
               Millisekunden bedeutet kein Warten auf eine Sperre.
  @HighImpactConfirmed bit, Default: 0. Eingabeform: einzelner SQL-bit-Wert
               oder Variable; leere Zeichenfolge ist keine vorgesehene Typform
               und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 bestätigt den
               High-Impact-Pfad, 0 nicht. Für RELEVANT, OBJECT_ALL und STEPS
               führt 0 zu HIGH_IMPACT_CONFIRMATION_REQUIRED; SUMMARY allein
               verlangt die Bestätigung nicht. NULL ergibt vor den Temp-Tabellen-
               Prüfungen INVALID_PARAMETER. Die lokale Bestätigungsprüfung
               erfolgt vor dem optionalen Gate-Aufruf; dessen Ergebnisse können
               außerdem HIGH_IMPACT_CONFIRMATION_REQUIRED, INVALID_PARAMETER
               oder DENIED_GROUP sein. Bei SQL-bit-Konvertierung kann ein
               numerischer Nichtnullwert ungleich 0 zu 1 werden.
               Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert; für
               einen breiten Pfad fehlt damit die Bestätigung.
  @StatusCodeOut varchar(40), Default: NULL OUTPUT. Eingabeform: einzelner
               varchar-Wert/Skalar oder OUTPUT-Variable. Eingehendes NULL und
               Leertext sind erlaubt, werden ignoriert. Eingehender Wert wird
               ignoriert und zuerst auf AVAILABLE gesetzt. Lokal mögliche
               Werte: AVAILABLE, INVALID_PARAMETER, INTERNAL_ERROR,
               HIGH_IMPACT_CONFIRMATION_REQUIRED, PARTIAL, LOCK_TIMEOUT und
               ERROR_HANDLED; Gate-Statuswerte werden weitergereicht.
               AVAILABLE bedeutet regulär beendet ohne gesetztes Teilfehlerflag, nicht
               vollständige Metadaten; INVALID_PARAMETER bedeutet lokal erkannter
               ungültiger Parameter oder ein entsprechendes Gate-Ergebnis; INTERNAL_ERROR
               bedeutet Fehler einer Temp-Tabellenprobe; HIGH_IMPACT_CONFIRMATION_REQUIRED
               bedeutet fehlende Bestätigung des breiten Pfads; PARTIAL bedeutet
               verzeichneten Teilfehler bei ansonsten regulärem Ende; LOCK_TIMEOUT bedeutet
               Fehler 1222 im äußeren Hauptteil-CATCH; ERROR_HANDLED bedeutet einen anderen
               Fehler in diesem CATCH; DENIED_GROUP bedeutet vom Gate nicht freigegebenen
               CATALOG_DEEP-Pfad. Das Gate kann INVALID_PARAMETER insbesondere bei
               NULL-Bestätigung oder ungültiger/unbekannter Analyseklasse liefern. Zum Empfangen passende Variable mit OUTPUT;
               ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe
               verworfen werden.
  @IsPartialOut bit, Default: NULL OUTPUT. Eingabeform: einzelner SQL-bit-
               Wert/Skalar oder OUTPUT-Variable; NULL ist erlaubt und wird
               ignoriert, leere Zeichenfolge ist keine vorgesehene Typform und
               wird vor Eintritt konvertiert. Eingehender Wert wird ignoriert,
               zuerst 0, bei Teil- oder Fehlerausgabe 1. Zum Empfangen
               passende Variable mit OUTPUT; ohne OUTPUT kann typgerechter
               Skalar übergeben und Ausgabe verworfen werden.
               Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert; der
               Eingang wird wie NULL ignoriert.
  @ErrorNumberOut int, Default: NULL OUTPUT. Eingabeform: einzelner SQL-int-
               Wert/Skalar oder OUTPUT-Variable; NULL ist erlaubt und wird
               ignoriert, leere Zeichenfolge ist keine vorgesehene Typform und
               wird vor Eintritt konvertiert. Eingehender Wert wird ignoriert,
               zunächst NULL. Bei abgefangenen Fehlern enthält er
               ERROR_NUMBER() im Hauptteil-CATCH oder der Temp-Probe;
               Einzelquellenfehler können PARTIAL bei weiter NULL liefern.
               Gewöhnliche Parameter- oder Gate-Statuswerte setzen ihn nicht neu. Zum Empfangen passende Variable mit
               OUTPUT; ohne OUTPUT kann typgerechter Skalar übergeben und
               Ausgabe verworfen werden.
               Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert; der
               Eingang wird wie NULL ignoriert.
  @ErrorMessageOut nvarchar(2048), Default: NULL OUTPUT. Eingabeform: einzelner
               nvarchar-Wert/Skalar oder OUTPUT-Variable; NULL und Leertext
               sind erlaubt und werden ignoriert. Eingehender Wert wird
               ignoriert, zunächst NULL. Lokale Parameterfehler, Temp-Tabellenprobe, Gate-Rückgabe und
               Hauptteil-CATCH setzen die jeweilige Meldung. Bei AVAILABLE sowie
               PARTIAL durch Einzelquellenfehler kann er NULL bleiben; Details
               stehen dann im CollectionStatus. Zum Empfangen passende Variable mit OUTPUT;
               ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe
               verworfen werden.
               Bei SQL-bit-Konvertierungen kann ein numerischer Nichtnullwert
               ungleich 0 bereits zu 1 konvertiert sein.
Wirkung       : Liest Planreferenzen sowie SQL-Server-Katalog- und
               Statistikmetadaten und schreibt in
               #CreateExecutionEvidenceJson_StatisticsCurrent,
               #CreateExecutionEvidenceJson_HistogramSteps,
               #CreateExecutionEvidenceJson_HistogramSummary,
               #CreateExecutionEvidenceJson_PredicateHistogramMappings und
               #CreateExecutionEvidenceJson_CollectionStatus. Diese Daten
               werden nicht als Resultsets ausgegeben. Histogrammrohwerte
               werden in lokalen Tabellen verarbeitet; Prädikatwerte liegen
               in einer internen Temp-Tabelle. Keine Zusage vollständiger
               Katalogerfassung, atomarer Änderungen oder einer über die
               tatsächlichen SQL-Server-Prüfungen hinausgehenden
               Berechtigungssicherheit.
Grenzen      : SET LOCK_TIMEOUT 0 erfolgt vor allen Prüfungen und gilt innerhalb der
               Procedure auch auf frühen Rückgabepfaden. Die eigene
               Wiederherstellungsanweisung im Hauptteil verwendet den danach gespeicherten
               Wert 0, keine vor Eintritt gesicherte Kopie. Der optionale Gate-Aufruf und
               sein Katalogzugriff liegen vor dem Hauptteil-TRY; dort unerwartet
               weitergeworfene Fehler können ohne Umsetzung in die globalen Fehlerausgaben
               entweichen.
Fehler        : Wenn eine referenzierte Datenbank bei der Kandidatenermittlung
               unzugänglich ist, wird dafür ein CollectionStatus-Eintrag
               geschrieben. Fehler in den Schleifen werden soweit abgefangen
               ebenfalls erfasst und markieren die Ausgabe als partiell. Fehler in der initialen Temp-Tabellenprobe setzen
               INTERNAL_ERROR und geben zurück. Gate-Ergebnisse INVALID_PARAMETER (ungültige Klasse oder Bestätigung),
               HIGH_IMPACT_CONFIRMATION_REQUIRED (Bestätigung fehlt) und
               DENIED_GROUP (Pfad nicht freigegeben) können durchgereicht
               werden; ErrorNumberOut kann dabei NULL bleiben. Der äußere CATCH des Hauptteils setzt
               LOCK_TIMEOUT bei Fehler 1222, sonst ERROR_HANDLED, samt
               Fehlernummer und -text. Bei einer späteren Datenbankprüfung ohne ELSE können inzwischen nicht
               erreichbare Datenbanken ohne eigenen Statusdatensatz bleiben.
               Bereits geschriebene Zeilen werden nicht zurückgerollt.
```

