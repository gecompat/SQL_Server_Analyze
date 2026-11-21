USE [DeineDatenbank];
GO

/*
===============================================================================
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
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.InternalCollectExecutionPlanMetadata 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.InternalCollectExecutionPlanMetadata"
-- schema_name: "monitor"
-- object_name: "InternalCollectExecutionPlanMetadata"
-- object_type: "INTERNAL_PROCEDURE"
-- database_role: "framework"
-- is_internal: true
-- description: "Die Procedure ermittelt zu einem Ausführungsplan Objekt-, Index- und Statistikmetadaten der ausdrücklich bestätigten Quellumgebung."
-- source_path: "Code/04_PlanCache/049_InternalCollectExecutionPlanMetadata.sql"
-- ---
-- 
-- # monitor.InternalCollectExecutionPlanMetadata
-- 
-- ## Zweck und Einsatz
-- 
-- Die Procedure ermittelt zu einem Ausführungsplan Objekt-, Index- und Statistikmetadaten der ausdrücklich bestätigten Quellumgebung. Sie kann Histogrammschritte und Zusammenfassungen sowie Zuordnungen zu Planprädikaten sammeln.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der Aufrufer legt die fünf Evidenz-Temp-Tabellen mit dem erwarteten Schema an. Je ein TOP (0)-SELECT prüft Existenz und Schemaauflösung, nicht das vollständige Schema oder die Berechtigungen. Die fünf Prüfungen erzeugen fünf leere Resultsets.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @PlanXml | xml | ja | kein Default |
-- | @StatistikEvidenzModus | varchar(16) | nein | 'USED' |
-- | @HistogrammModus | varchar(16) | nein | 'NONE' |
-- | @QuellumgebungBestaetigt | bit | nein | 0 |
-- | @MitPredicateHistogramMap | bit | nein | 1 |
-- | @MaxStatistiken | int | nein | 100 |
-- | @MaxHistogrammSchritte | int | nein | 20000 |
-- | @LockTimeoutMs | int | nein | 0 |
-- | @HighImpactConfirmed | bit | nein | 0 |
-- | @StatusCodeOut | varchar(40) OUTPUT | nein | NULL |
-- | @IsPartialOut | bit OUTPUT | nein | NULL |
-- | @ErrorNumberOut | int OUTPUT | nein | NULL |
-- | @ErrorMessageOut | nvarchar(2048) OUTPUT | nein | NULL |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@PlanXml:** @PlanXml xml, Default: keiner; obligatorisch. Eingabeform: einzelner XML-Ausführungsplan als XML-Wert oder gebundene XML-Variable; NULL ergibt INVALID_PARAMETER. Ein leeres, gültiges XML wird nicht ausdrücklich abgewiesen.
-- 
-- **@StatistikEvidenzModus:** @StatistikEvidenzModus varchar(16), Default: 'USED'. Eingabeform: ein einzelner Modus-Textwert, keine Liste. NULL wird zur Laufzeit zu USED; äußere Leerzeichen werden entfernt, Großschreibung angewendet. Endliche Werte: USED sammelt nur vom Plan als verwendet gemeldete Statistiken; RELEVANT ergänzt Statistiken, deren führende Spalte im Plan als SEEK, RESIDUAL, JOIN, ORDER_BY oder GROUP_BY vorkommt; OBJECT_ALL ergänzt alle Statistiken katalogauflösbarer Planobjekte. Leertext ist ungültig.
-- 
-- **@HistogrammModus:** @HistogrammModus varchar(16), Default: 'NONE'. Eingabeform: einzelner Modus-Textwert, keine Liste. NULL wird zur Laufzeit zu NONE; äußere Leerzeichen werden entfernt, Großschreibung angewendet. Endliche Werte: NONE sammelt im Hauptteil keine zusätzlichen Schritte; SUMMARY und STEPS sammeln Schritte und bilden Zusammenfassungen, wobei STEPS zusätzlich High-Impact-Bestätigung verlangt. Die Sammlung ist in beiden Modi gleich. Vorhandene Zeilen werden auch bei NONE zusammengefasst und können zugeordnet werden. Leertext oder nur Leerzeichen ist ungültig.
-- 
-- **@QuellumgebungBestaetigt:** @QuellumgebungBestaetigt bit, Default: 0. Eingabeform: einzelner SQL-bit- Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 bestätigt die Quellumgebung; 0 oder NULL ergeben INVALID_PARAMETER. Ausgelassen bindet den Default 0 und ergibt ebenfalls INVALID_PARAMETER. Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert und wie fehlende Bestätigung abgelehnt.
-- 
-- **@MitPredicateHistogramMap:** @MitPredicateHistogramMap bit, Default: 1. Eingabeform: einzelner SQL-bit- Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 ordnet extrahierte Planparameterwerte Histogrammschritten zu; 0 überspringt die Zuordnung. NULL ergibt INVALID_PARAMETER. Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert und überspringt die Zuordnung.
-- 
-- **@MaxStatistiken:** @MaxStatistiken int, Default: 100. Eingabeform: einzelner SQL-int-Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. Ganze Zahl 1 bis 1000 einschließlich; NULL und Werte außerhalb ergeben INVALID_PARAMETER. Begrenzt die insgesamt ausgewählten Kandidaten nach Priorität PLAN_USED, RELEVANT_LEADING_COLUMN, danach übrige. RELEVANT/OBJECT_ALL- Kandidaten werden vor dem Limit aus dem Katalog gelesen; ein positives Limit verhindert diese anfängliche Abfrage nicht. Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert und liegt außerhalb des gültigen Bereichs.
-- 
-- **@MaxHistogrammSchritte:** @MaxHistogrammSchritte int, Default: 20000. Eingabeform: einzelner SQL-int- Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. Ganze Zahl 0 bis 200000 einschließlich; NULL und Werte außerhalb ergeben INVALID_PARAMETER. Begrenzt zusätzliche Schritte global anhand der bereits in der Aufrufer-Schritttabelle vorhandenen Zeilen; der Wert 0 fügt keine neuen Schritte ein. Bei erreichtem Limit werden keine weiteren eingefügt und vorhandene Zeilen nicht entfernt. Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert und fügt keine neuen Schritte ein.
-- 
-- **@LockTimeoutMs:** @LockTimeoutMs int, Default: 0. Eingabeform: einzelner SQL-int-Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. Ganze Zahl 0 bis 60000 Millisekunden; NULL und Werte außerhalb ergeben INVALID_PARAMETER. Steuert LOCK_TIMEOUT im Hauptteil nach frühen Prüfungen. Die Procedure setzt zuerst LOCK_TIMEOUT 0 und speichert den Wert erst danach; am Ende wird somit 0 statt des vorherigen Aufruferwerts wiederhergestellt. Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert; 0 Millisekunden bedeutet kein Warten auf eine Sperre.
-- 
-- **@HighImpactConfirmed:** @HighImpactConfirmed bit, Default: 0. Eingabeform: einzelner SQL-bit-Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 bestätigt den High-Impact-Pfad, 0 nicht. Für RELEVANT, OBJECT_ALL und STEPS führt 0 zu HIGH_IMPACT_CONFIRMATION_REQUIRED; SUMMARY allein verlangt die Bestätigung nicht. NULL ergibt vor den Temp-Tabellen- Prüfungen INVALID_PARAMETER. Die lokale Bestätigungsprüfung erfolgt vor dem optionalen Gate-Aufruf; dessen Ergebnisse können außerdem HIGH_IMPACT_CONFIRMATION_REQUIRED, INVALID_PARAMETER oder DENIED_GROUP sein. Bei SQL-bit-Konvertierung kann ein numerischer Nichtnullwert ungleich 0 zu 1 werden. Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert; für einen breiten Pfad fehlt damit die Bestätigung.
-- 
-- **@StatusCodeOut:** @StatusCodeOut varchar(40), Default: NULL OUTPUT. Eingabeform: einzelner varchar-Wert/Skalar oder OUTPUT-Variable. Eingehendes NULL und Leertext sind erlaubt, werden ignoriert. Eingehender Wert wird ignoriert und zuerst auf AVAILABLE gesetzt. Lokal mögliche Werte: AVAILABLE, INVALID_PARAMETER, INTERNAL_ERROR, HIGH_IMPACT_CONFIRMATION_REQUIRED, PARTIAL, LOCK_TIMEOUT und ERROR_HANDLED; Gate-Statuswerte werden weitergereicht. AVAILABLE bedeutet regulär beendet ohne gesetztes Teilfehlerflag, nicht vollständige Metadaten; INVALID_PARAMETER bedeutet lokal erkannter ungültiger Parameter oder ein entsprechendes Gate-Ergebnis; INTERNAL_ERROR bedeutet Fehler einer Temp-Tabellenprobe; HIGH_IMPACT_CONFIRMATION_REQUIRED bedeutet fehlende Bestätigung des breiten Pfads; PARTIAL bedeutet verzeichneten Teilfehler bei ansonsten regulärem Ende; LOCK_TIMEOUT bedeutet Fehler 1222 im äußeren Hauptteil-CATCH; ERROR_HANDLED bedeutet einen anderen Fehler in diesem CATCH; DENIED_GROUP bedeutet vom Gate nicht freigegebenen CATALOG_DEEP-Pfad. Das Gate kann INVALID_PARAMETER insbesondere bei NULL-Bestätigung oder ungültiger/unbekannter Analyseklasse liefern. Zum Empfangen passende Variable mit OUTPUT; ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe verworfen werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@IsPartialOut:** @IsPartialOut bit, Default: NULL OUTPUT. Eingabeform: einzelner SQL-bit- Wert/Skalar oder OUTPUT-Variable; NULL ist erlaubt und wird ignoriert, leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. Eingehender Wert wird ignoriert, zuerst 0, bei Teil- oder Fehlerausgabe 1. Zum Empfangen passende Variable mit OUTPUT; ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe verworfen werden. Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert; der Eingang wird wie NULL ignoriert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@ErrorNumberOut:** @ErrorNumberOut int, Default: NULL OUTPUT. Eingabeform: einzelner SQL-int- Wert/Skalar oder OUTPUT-Variable; NULL ist erlaubt und wird ignoriert, leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. Eingehender Wert wird ignoriert, zunächst NULL. Bei abgefangenen Fehlern enthält er ERROR_NUMBER() im Hauptteil-CATCH oder der Temp-Probe; Einzelquellenfehler können PARTIAL bei weiter NULL liefern. Gewöhnliche Parameter- oder Gate-Statuswerte setzen ihn nicht neu. Zum Empfangen passende Variable mit OUTPUT; ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe verworfen werden. Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert; der Eingang wird wie NULL ignoriert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048), Default: NULL OUTPUT. Eingabeform: einzelner nvarchar-Wert/Skalar oder OUTPUT-Variable; NULL und Leertext sind erlaubt und werden ignoriert. Eingehender Wert wird ignoriert, zunächst NULL. Lokale Parameterfehler, Temp-Tabellenprobe, Gate-Rückgabe und Hauptteil-CATCH setzen die jeweilige Meldung. Bei AVAILABLE sowie PARTIAL durch Einzelquellenfehler kann er NULL bleiben; Details stehen dann im CollectionStatus. Zum Empfangen passende Variable mit OUTPUT; ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe verworfen werden. Bei SQL-bit-Konvertierungen kann ein numerischer Nichtnullwert ungleich 0 bereits zu 1 konvertiert sein. Wirkung       : Liest Planreferenzen sowie SQL-Server-Katalog- und Statistikmetadaten und schreibt in #CreateExecutionEvidenceJson_StatisticsCurrent, #CreateExecutionEvidenceJson_HistogramSteps, #CreateExecutionEvidenceJson_HistogramSummary, #CreateExecutionEvidenceJson_PredicateHistogramMappings und #CreateExecutionEvidenceJson_CollectionStatus. Diese Daten werden nicht als Resultsets ausgegeben. Histogrammrohwerte werden in lokalen Tabellen verarbeitet; Prädikatwerte liegen in einer internen Temp-Tabelle. Keine Zusage vollständiger Katalogerfassung, atomarer Änderungen oder einer über die tatsächlichen SQL-Server-Prüfungen hinausgehenden Berechtigungssicherheit. Grenzen      : SET LOCK_TIMEOUT 0 erfolgt vor allen Prüfungen und gilt innerhalb der Procedure auch auf frühen Rückgabepfaden. Die eigene Wiederherstellungsanweisung im Hauptteil verwendet den danach gespeicherten Wert 0, keine vor Eintritt gesicherte Kopie. Der optionale Gate-Aufruf und sein Katalogzugriff liegen vor dem Hauptteil-TRY; dort unerwartet weitergeworfene Fehler können ohne Umsetzung in die globalen Fehlerausgaben entweichen. Fehler        : Wenn eine referenzierte Datenbank bei der Kandidatenermittlung unzugänglich ist, wird dafür ein CollectionStatus-Eintrag geschrieben. Fehler in den Schleifen werden soweit abgefangen ebenfalls erfasst und markieren die Ausgabe als partiell. Fehler in der initialen Temp-Tabellenprobe setzen INTERNAL_ERROR und geben zurück. Gate-Ergebnisse INVALID_PARAMETER (ungültige Klasse oder Bestätigung), HIGH_IMPACT_CONFIRMATION_REQUIRED (Bestätigung fehlt) und DENIED_GROUP (Pfad nicht freigegeben) können durchgereicht werden; ErrorNumberOut kann dabei NULL bleiben. Der äußere CATCH des Hauptteils setzt LOCK_TIMEOUT bei Fehler 1222, sonst ERROR_HANDLED, samt Fehlernummer und -text. Bei einer späteren Datenbankprüfung ohne ELSE können inzwischen nicht erreichbare Datenbanken ohne eigenen Statusdatensatz bleiben. Bereits geschriebene Zeilen werden nicht zurückgerollt. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.
-- 
-- ## Resultate und Ausgabe
-- 
-- Die fünf TOP (0)-Probes der vom Aufrufer angelegten Evidenz-#Temp-Tabellen erzeugen fünf leere Schema-Resultsets. Daten werden in diese lokalen Tabellen geschrieben, darunter Objekt-/Index-/Statistikmetadaten, CollectionStatus und gegebenenfalls Histogramm- und Prädikatzuordnungen; diese Zeilen werden nicht als zusätzliche fachliche Resultsets ausgegeben. `@StatusCodeOut` (varchar(40) OUTPUT) beginnt mit AVAILABLE und kann lokal INVALID_PARAMETER, INTERNAL_ERROR, HIGH_IMPACT_CONFIRMATION_REQUIRED, PARTIAL, LOCK_TIMEOUT oder ERROR_HANDLED sowie weitergereichte Gate-Statuswerte enthalten. `@IsPartialOut` (bit OUTPUT) beginnt mit 0 und kennzeichnet Teil-/Fehlerausgabe mit 1. `@ErrorNumberOut` (int OUTPUT) und `@ErrorMessageOut` (nvarchar(2048) OUTPUT) beginnen NULL; Einzelquellenfehler können PARTIAL ohne Fehlernummer ergeben. Die fünf TOP (0)-Probes belegen keinen vollständigen Schema- oder Rechtevertrag.
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- 
-- ## Beispiel
-- 
-- Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:
-- 
-- ```sql
-- SELECT [SkillMarkdown]
-- FROM [monitor_metadata].[VW_ObjectUsageSkills]
-- WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalCollectExecutionPlanMetadata';
-- ```
-- 
-- Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:
-- 
-- ```sql
-- EXEC [monitor].[InternalCollectExecutionPlanMetadata] @PlanXml=NULL, @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- SET LOCK_TIMEOUT 0 erfolgt vor allen Prüfungen und gilt innerhalb der Procedure auch auf frühen Rückgabepfaden. Die eigene Wiederherstellungsanweisung im Hauptteil verwendet den danach gespeicherten Wert 0, keine vor Eintritt gesicherte Kopie. Der optionale Gate-Aufruf und sein Katalogzugriff liegen vor dem Hauptteil-TRY; dort unerwartet weitergeworfene Fehler können ohne Umsetzung in die globalen Fehlerausgaben entweichen.
-- 
-- Wenn eine referenzierte Datenbank bei der Kandidatenermittlung unzugänglich ist, wird dafür ein CollectionStatus-Eintrag geschrieben. Fehler in den Schleifen werden soweit abgefangen ebenfalls erfasst und markieren die Ausgabe als partiell. Fehler in der initialen Temp-Tabellenprobe setzen INTERNAL_ERROR und geben zurück. Gate-Ergebnisse INVALID_PARAMETER (ungültige Klasse oder Bestätigung), HIGH_IMPACT_CONFIRMATION_REQUIRED (Bestätigung fehlt) und DENIED_GROUP (Pfad nicht freigegeben) können durchgereicht werden; ErrorNumberOut kann dabei NULL bleiben. Der äußere CATCH des Hauptteils setzt LOCK_TIMEOUT bei Fehler 1222, sonst ERROR_HANDLED, samt Fehlernummer und -text. Bei einer späteren Datenbankprüfung ohne ELSE können inzwischen nicht erreichbare Datenbanken ohne eigenen Statusdatensatz bleiben. Bereits geschriebene Zeilen werden nicht zurückgerollt.
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.InternalCollectExecutionPlanMetadata
-- Version      : 1.0.0
-- Stand        : 2026-07-21
-- Typ          : Interne Stored Procedure
-- Zweck        : Die Procedure ermittelt zu einem Ausführungsplan Objekt-,
--                Index- und Statistikmetadaten der ausdrücklich bestätigten
--                Quellumgebung. Sie kann Histogrammschritte und Zusammenfassungen
--                sowie Zuordnungen zu Planprädikaten sammeln.
-- Voraussetzung: Der Aufrufer legt die fünf Evidenz-Temp-Tabellen mit dem
--                erwarteten Schema an. Je ein TOP (0)-SELECT prüft Existenz und
--                Schemaauflösung, nicht das vollständige Schema oder die
--                Berechtigungen. Die fünf Prüfungen erzeugen fünf
--                leere Resultsets.
-- Eingabe      :
--   @PlanXml xml, Default: keiner; obligatorisch. Eingabeform: einzelner
--                XML-Ausführungsplan als XML-Wert oder gebundene XML-Variable;
--                NULL ergibt INVALID_PARAMETER. Ein leeres, gültiges XML wird
--                nicht ausdrücklich abgewiesen.
--   @StatistikEvidenzModus varchar(16), Default: 'USED'. Eingabeform: ein
--                einzelner Modus-Textwert, keine Liste. NULL wird zur Laufzeit
--                zu USED;
--                äußere Leerzeichen werden entfernt, Großschreibung angewendet.
--                Endliche Werte: USED sammelt nur vom Plan als verwendet
--                gemeldete Statistiken; RELEVANT ergänzt Statistiken, deren
--                führende Spalte im Plan als SEEK, RESIDUAL, JOIN, ORDER_BY oder
--                GROUP_BY vorkommt; OBJECT_ALL ergänzt alle Statistiken
--                katalogauflösbarer Planobjekte. Leertext ist ungültig.
--   @HistogrammModus varchar(16), Default: 'NONE'. Eingabeform: einzelner
--                Modus-Textwert, keine Liste. NULL wird zur Laufzeit zu NONE;
--                äußere Leerzeichen werden entfernt, Großschreibung angewendet.
--                Endliche Werte: NONE sammelt im Hauptteil keine zusätzlichen Schritte;
--                SUMMARY und STEPS sammeln Schritte und bilden Zusammenfassungen,
--                wobei STEPS zusätzlich High-Impact-Bestätigung verlangt. Die
--                Sammlung ist in beiden Modi gleich. Vorhandene Zeilen werden
--                auch bei NONE zusammengefasst und können zugeordnet werden.
--                Leertext oder nur Leerzeichen ist ungültig.
--   @QuellumgebungBestaetigt bit, Default: 0. Eingabeform: einzelner SQL-bit-
--                Wert oder Variable; leere Zeichenfolge ist keine vorgesehene
--                Typform und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 bestätigt die
--                Quellumgebung; 0 oder NULL ergeben INVALID_PARAMETER. Ausgelassen
--                bindet den Default 0 und ergibt ebenfalls INVALID_PARAMETER.
--                Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert und wie
--                fehlende Bestätigung abgelehnt.
--   @MitPredicateHistogramMap bit, Default: 1. Eingabeform: einzelner SQL-bit-
--                Wert oder Variable; leere Zeichenfolge ist keine vorgesehene
--                Typform und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 ordnet
--                extrahierte Planparameterwerte Histogrammschritten zu; 0
--                überspringt die Zuordnung. NULL ergibt INVALID_PARAMETER.
--                Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert und
--                überspringt die Zuordnung.
--   @MaxStatistiken int, Default: 100. Eingabeform: einzelner SQL-int-Wert oder
--                Variable; leere Zeichenfolge ist keine vorgesehene Typform und
--                wird vor Eintritt konvertiert. Ganze Zahl 1 bis 1000 einschließlich;
--                NULL und Werte außerhalb ergeben INVALID_PARAMETER. Begrenzt
--                die insgesamt ausgewählten Kandidaten nach Priorität PLAN_USED,
--                RELEVANT_LEADING_COLUMN, danach übrige. RELEVANT/OBJECT_ALL-
--                Kandidaten werden vor dem Limit aus dem Katalog gelesen; ein
--                positives Limit verhindert diese anfängliche Abfrage nicht.
--                Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert und liegt
--                außerhalb des gültigen Bereichs.
--   @MaxHistogrammSchritte int, Default: 20000. Eingabeform: einzelner SQL-int-
--                Wert oder Variable; leere Zeichenfolge ist keine vorgesehene
--                Typform und wird vor Eintritt konvertiert. Ganze Zahl 0 bis 200000
--                einschließlich; NULL und Werte außerhalb ergeben
--                INVALID_PARAMETER. Begrenzt zusätzliche Schritte global anhand
--                der bereits in der Aufrufer-Schritttabelle vorhandenen Zeilen;
--                der Wert 0 fügt keine neuen Schritte ein.
--                Bei erreichtem Limit werden keine weiteren eingefügt und
--                vorhandene Zeilen nicht entfernt.
--                Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert und fügt
--                keine neuen Schritte ein.
--   @LockTimeoutMs int, Default: 0. Eingabeform: einzelner SQL-int-Wert oder
--                Variable; leere Zeichenfolge ist keine vorgesehene Typform und
--                wird vor Eintritt konvertiert. Ganze Zahl 0 bis 60000 Millisekunden;
--                NULL und Werte außerhalb ergeben INVALID_PARAMETER. Steuert
--                LOCK_TIMEOUT im Hauptteil nach frühen Prüfungen. Die Procedure
--                setzt zuerst LOCK_TIMEOUT 0 und speichert den Wert erst danach;
--                am Ende wird somit 0 statt des vorherigen Aufruferwerts
--                wiederhergestellt.
--                Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert; 0
--                Millisekunden bedeutet kein Warten auf eine Sperre.
--   @HighImpactConfirmed bit, Default: 0. Eingabeform: einzelner SQL-bit-Wert
--                oder Variable; leere Zeichenfolge ist keine vorgesehene Typform
--                und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 bestätigt den
--                High-Impact-Pfad, 0 nicht. Für RELEVANT, OBJECT_ALL und STEPS
--                führt 0 zu HIGH_IMPACT_CONFIRMATION_REQUIRED; SUMMARY allein
--                verlangt die Bestätigung nicht. NULL ergibt vor den Temp-Tabellen-
--                Prüfungen INVALID_PARAMETER. Die lokale Bestätigungsprüfung
--                erfolgt vor dem optionalen Gate-Aufruf; dessen Ergebnisse können
--                außerdem HIGH_IMPACT_CONFIRMATION_REQUIRED, INVALID_PARAMETER
--                oder DENIED_GROUP sein. Bei SQL-bit-Konvertierung kann ein
--                numerischer Nichtnullwert ungleich 0 zu 1 werden.
--                Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert; für
--                einen breiten Pfad fehlt damit die Bestätigung.
--   @StatusCodeOut varchar(40), Default: NULL OUTPUT. Eingabeform: einzelner
--                varchar-Wert/Skalar oder OUTPUT-Variable. Eingehendes NULL und
--                Leertext sind erlaubt, werden ignoriert. Eingehender Wert wird
--                ignoriert und zuerst auf AVAILABLE gesetzt. Lokal mögliche
--                Werte: AVAILABLE, INVALID_PARAMETER, INTERNAL_ERROR,
--                HIGH_IMPACT_CONFIRMATION_REQUIRED, PARTIAL, LOCK_TIMEOUT und
--                ERROR_HANDLED; Gate-Statuswerte werden weitergereicht.
--                AVAILABLE bedeutet regulär beendet ohne gesetztes Teilfehlerflag, nicht
--                vollständige Metadaten; INVALID_PARAMETER bedeutet lokal erkannter
--                ungültiger Parameter oder ein entsprechendes Gate-Ergebnis; INTERNAL_ERROR
--                bedeutet Fehler einer Temp-Tabellenprobe; HIGH_IMPACT_CONFIRMATION_REQUIRED
--                bedeutet fehlende Bestätigung des breiten Pfads; PARTIAL bedeutet
--                verzeichneten Teilfehler bei ansonsten regulärem Ende; LOCK_TIMEOUT bedeutet
--                Fehler 1222 im äußeren Hauptteil-CATCH; ERROR_HANDLED bedeutet einen anderen
--                Fehler in diesem CATCH; DENIED_GROUP bedeutet vom Gate nicht freigegebenen
--                CATALOG_DEEP-Pfad. Das Gate kann INVALID_PARAMETER insbesondere bei
--                NULL-Bestätigung oder ungültiger/unbekannter Analyseklasse liefern. Zum Empfangen passende Variable mit OUTPUT;
--                ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe
--                verworfen werden.
--   @IsPartialOut bit, Default: NULL OUTPUT. Eingabeform: einzelner SQL-bit-
--                Wert/Skalar oder OUTPUT-Variable; NULL ist erlaubt und wird
--                ignoriert, leere Zeichenfolge ist keine vorgesehene Typform und
--                wird vor Eintritt konvertiert. Eingehender Wert wird ignoriert,
--                zuerst 0, bei Teil- oder Fehlerausgabe 1. Zum Empfangen
--                passende Variable mit OUTPUT; ohne OUTPUT kann typgerechter
--                Skalar übergeben und Ausgabe verworfen werden.
--                Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert; der
--                Eingang wird wie NULL ignoriert.
--   @ErrorNumberOut int, Default: NULL OUTPUT. Eingabeform: einzelner SQL-int-
--                Wert/Skalar oder OUTPUT-Variable; NULL ist erlaubt und wird
--                ignoriert, leere Zeichenfolge ist keine vorgesehene Typform und
--                wird vor Eintritt konvertiert. Eingehender Wert wird ignoriert,
--                zunächst NULL. Bei abgefangenen Fehlern enthält er
--                ERROR_NUMBER() im Hauptteil-CATCH oder der Temp-Probe;
--                Einzelquellenfehler können PARTIAL bei weiter NULL liefern.
--                Gewöhnliche Parameter- oder Gate-Statuswerte setzen ihn nicht neu. Zum Empfangen passende Variable mit
--                OUTPUT; ohne OUTPUT kann typgerechter Skalar übergeben und
--                Ausgabe verworfen werden.
--                Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert; der
--                Eingang wird wie NULL ignoriert.
--   @ErrorMessageOut nvarchar(2048), Default: NULL OUTPUT. Eingabeform: einzelner
--                nvarchar-Wert/Skalar oder OUTPUT-Variable; NULL und Leertext
--                sind erlaubt und werden ignoriert. Eingehender Wert wird
--                ignoriert, zunächst NULL. Lokale Parameterfehler, Temp-Tabellenprobe, Gate-Rückgabe und
--                Hauptteil-CATCH setzen die jeweilige Meldung. Bei AVAILABLE sowie
--                PARTIAL durch Einzelquellenfehler kann er NULL bleiben; Details
--                stehen dann im CollectionStatus. Zum Empfangen passende Variable mit OUTPUT;
--                ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe
--                verworfen werden.
--                Bei SQL-bit-Konvertierungen kann ein numerischer Nichtnullwert
--                ungleich 0 bereits zu 1 konvertiert sein.
-- Wirkung       : Liest Planreferenzen sowie SQL-Server-Katalog- und
--                Statistikmetadaten und schreibt in
--                #CreateExecutionEvidenceJson_StatisticsCurrent,
--                #CreateExecutionEvidenceJson_HistogramSteps,
--                #CreateExecutionEvidenceJson_HistogramSummary,
--                #CreateExecutionEvidenceJson_PredicateHistogramMappings und
--                #CreateExecutionEvidenceJson_CollectionStatus. Diese Daten
--                werden nicht als Resultsets ausgegeben. Histogrammrohwerte
--                werden in lokalen Tabellen verarbeitet; Prädikatwerte liegen
--                in einer internen Temp-Tabelle. Keine Zusage vollständiger
--                Katalogerfassung, atomarer Änderungen oder einer über die
--                tatsächlichen SQL-Server-Prüfungen hinausgehenden
--                Berechtigungssicherheit.
-- Grenzen      : SET LOCK_TIMEOUT 0 erfolgt vor allen Prüfungen und gilt innerhalb der
--                Procedure auch auf frühen Rückgabepfaden. Die eigene
--                Wiederherstellungsanweisung im Hauptteil verwendet den danach gespeicherten
--                Wert 0, keine vor Eintritt gesicherte Kopie. Der optionale Gate-Aufruf und
--                sein Katalogzugriff liegen vor dem Hauptteil-TRY; dort unerwartet
--                weitergeworfene Fehler können ohne Umsetzung in die globalen Fehlerausgaben
--                entweichen.
-- Fehler        : Wenn eine referenzierte Datenbank bei der Kandidatenermittlung
--                unzugänglich ist, wird dafür ein CollectionStatus-Eintrag
--                geschrieben. Fehler in den Schleifen werden soweit abgefangen
--                ebenfalls erfasst und markieren die Ausgabe als partiell. Fehler in der initialen Temp-Tabellenprobe setzen
--                INTERNAL_ERROR und geben zurück. Gate-Ergebnisse INVALID_PARAMETER (ungültige Klasse oder Bestätigung),
--                HIGH_IMPACT_CONFIRMATION_REQUIRED (Bestätigung fehlt) und
--                DENIED_GROUP (Pfad nicht freigegeben) können durchgereicht
--                werden; ErrorNumberOut kann dabei NULL bleiben. Der äußere CATCH des Hauptteils setzt
--                LOCK_TIMEOUT bei Fehler 1222, sonst ERROR_HANDLED, samt
--                Fehlernummer und -text. Bei einer späteren Datenbankprüfung ohne ELSE können inzwischen nicht
--                erreichbare Datenbanken ohne eigenen Statusdatensatz bleiben.
--                Bereits geschriebene Zeilen werden nicht zurückgerollt.
-- ```
-- 
-- USAGE_SKILL_END monitor.InternalCollectExecutionPlanMetadata
CREATE OR ALTER PROCEDURE [monitor].[InternalCollectExecutionPlanMetadata]
      @PlanXml                      xml
    , @StatistikEvidenzModus        varchar(16)    = 'USED'
    , @HistogrammModus              varchar(16)    = 'NONE'
    , @QuellumgebungBestaetigt      bit            = 0
    , @MitPredicateHistogramMap     bit            = 1
    , @MaxStatistiken               int            = 100
    , @MaxHistogrammSchritte        int            = 20000
    , @LockTimeoutMs                int            = 0
    , @HighImpactConfirmed          bit            = 0
    , @StatusCodeOut                varchar(40)     = NULL OUTPUT
    , @IsPartialOut                 bit             = NULL OUTPUT
    , @ErrorNumberOut               int             = NULL OUTPUT
    , @ErrorMessageOut              nvarchar(2048)  = NULL OUTPUT
    , @Hilfe bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF @Hilfe=1
    BEGIN
        -- USAGE_SKILL_HELP_BEGIN monitor.InternalCollectExecutionPlanMetadata
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'InternalCollectExecutionPlanMetadata') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.InternalCollectExecutionPlanMetadata"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "InternalCollectExecutionPlanMetadata"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Die Procedure ermittelt zu einem Ausführungsplan Objekt-, Index- und Statistikmetadaten der ausdrücklich bestätigten Quellumgebung."'
            + NCHAR(10)
            + N'source_path: "Code/04_PlanCache/049_InternalCollectExecutionPlanMetadata.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.InternalCollectExecutionPlanMetadata'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure ermittelt zu einem Ausführungsplan Objekt-, Index- und Statistikmetadaten der ausdrücklich bestätigten Quellumgebung. Sie kann Histogrammschritte und Zusammenfassungen sowie Zuordnungen zu Planprädikaten sammeln.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der Aufrufer legt die fünf Evidenz-Temp-Tabellen mit dem erwarteten Schema an. Je ein TOP (0)-SELECT prüft Existenz und Schemaauflösung, nicht das vollständige Schema oder die Berechtigungen. Die fünf Prüfungen erzeugen fünf leere Resultsets.'
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
            + N'| @PlanXml | xml | ja | kein Default |'
            + NCHAR(10)
            + N'| @StatistikEvidenzModus | varchar(16) | nein | ''USED'' |'
            + NCHAR(10)
            + N'| @HistogrammModus | varchar(16) | nein | ''NONE'' |'
            + NCHAR(10)
            + N'| @QuellumgebungBestaetigt | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @MitPredicateHistogramMap | bit | nein | 1 |'
            + NCHAR(10)
            + N'| @MaxStatistiken | int | nein | 100 |'
            + NCHAR(10)
            + N'| @MaxHistogrammSchritte | int | nein | 20000 |'
            + NCHAR(10)
            + N'| @LockTimeoutMs | int | nein | 0 |'
            + NCHAR(10)
            + N'| @HighImpactConfirmed | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @StatusCodeOut | varchar(40) OUTPUT | nein | NULL |'
            + NCHAR(10)
            + N'| @IsPartialOut | bit OUTPUT | nein | NULL |'
            + NCHAR(10)
            + N'| @ErrorNumberOut | int OUTPUT | nein | NULL |'
            + NCHAR(10)
            + N'| @ErrorMessageOut | nvarchar(2048) OUTPUT | nein | NULL |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PlanXml:** @PlanXml xml, Default: keiner; obligatorisch. Eingabeform: einzelner XML-Ausführungsplan als XML-Wert oder gebundene XML-Variable; NULL ergibt INVALID_PARAMETER. Ein leeres, gültiges XML wird nicht ausdrücklich abgewiesen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatistikEvidenzModus:** @StatistikEvidenzModus varchar(16), Default: ''USED''. Eingabeform: ein einzelner Modus-Textwert, keine Liste. NULL wird zur Laufzeit zu USED; äußere Leerzeichen werden entfernt, Großschreibung angewendet. Endliche Werte: USED sammelt nur vom Plan als verwendet gemeldete Statistiken; RELEVANT ergänzt Statistiken, deren führende Spalte im Plan als SEEK, RESIDUAL, JOIN, ORDER_BY oder GROUP_BY vorkommt; OBJECT_ALL ergänzt alle Statistiken katalogauflösbarer Planobjekte. Leertext ist ungültig.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@HistogrammModus:** @HistogrammModus varchar(16), Default: ''NONE''. Eingabeform: einzelner Modus-Textwert, keine Liste. NULL wird zur Laufzeit zu NONE; äußere Leerzeichen werden entfernt, Großschreibung angewendet. Endliche Werte: NONE sammelt im Hauptteil keine zusätzlichen Schritte; SUMMARY und STEPS sammeln Schritte und bilden Zusammenfassungen, wobei STEPS zusätzlich High-Impact-Bestätigung verlangt. Die Sammlung ist in beiden Modi gleich. Vorhandene Zeilen werden auch bei NONE zusammengefasst und können zugeordnet werden. Leertext oder nur Leerzeichen ist ungültig.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@QuellumgebungBestaetigt:** @QuellumgebungBestaetigt bit, Default: 0. Eingabeform: einzelner SQL-bit- Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 bestätigt die Quellumgebung; 0 oder NULL ergeben INVALID_PARAMETER. Ausgelassen bindet den Default 0 und ergibt ebenfalls INVALID_PARAMETER. Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert und wie fehlende Bestätigung abgelehnt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MitPredicateHistogramMap:** @MitPredicateHistogramMap bit, Default: 1. Eingabeform: einzelner SQL-bit- Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 ordnet extrahierte Planparameterwerte Histogrammschritten zu; 0 überspringt die Zuordnung. NULL ergibt INVALID_PARAMETER. Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert und überspringt die Zuordnung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxStatistiken:** @MaxStatistiken int, Default: 100. Eingabeform: einzelner SQL-int-Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. Ganze Zahl 1 bis 1000 einschließlich; NULL und Werte außerhalb ergeben INVALID_PARAMETER. Begrenzt die insgesamt ausgewählten Kandidaten nach Priorität PLAN_USED, RELEVANT_LEADING_COLUMN, danach übrige. RELEVANT/OBJECT_ALL- Kandidaten werden vor dem Limit aus dem Katalog gelesen; ein positives Limit verhindert diese anfängliche Abfrage nicht. Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert und liegt außerhalb des gültigen Bereichs.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxHistogrammSchritte:** @MaxHistogrammSchritte int, Default: 20000. Eingabeform: einzelner SQL-int- Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. Ganze Zahl 0 bis 200000 einschließlich; NULL und Werte außerhalb ergeben INVALID_PARAMETER. Begrenzt zusätzliche Schritte global anhand der bereits in der Aufrufer-Schritttabelle vorhandenen Zeilen; der Wert 0 fügt keine neuen Schritte ein. Bei erreichtem Limit werden keine weiteren eingefügt und vorhandene Zeilen nicht entfernt. Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert und fügt keine neuen Schritte ein.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@LockTimeoutMs:** @LockTimeoutMs int, Default: 0. Eingabeform: einzelner SQL-int-Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. Ganze Zahl 0 bis 60000 Millisekunden; NULL und Werte außerhalb ergeben INVALID_PARAMETER. Steuert LOCK_TIMEOUT im Hauptteil nach frühen Prüfungen. Die Procedure setzt zuerst LOCK_TIMEOUT 0 und speichert den Wert erst danach; am Ende wird somit 0 statt des vorherigen Aufruferwerts wiederhergestellt. Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert; 0 Millisekunden bedeutet kein Warten auf eine Sperre.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@HighImpactConfirmed:** @HighImpactConfirmed bit, Default: 0. Eingabeform: einzelner SQL-bit-Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 bestätigt den High-Impact-Pfad, 0 nicht. Für RELEVANT, OBJECT_ALL und STEPS führt 0 zu HIGH_IMPACT_CONFIRMATION_REQUIRED; SUMMARY allein verlangt die Bestätigung nicht. NULL ergibt vor den Temp-Tabellen- Prüfungen INVALID_PARAMETER. Die lokale Bestätigungsprüfung erfolgt vor dem optionalen Gate-Aufruf; dessen Ergebnisse können außerdem HIGH_IMPACT_CONFIRMATION_REQUIRED, INVALID_PARAMETER oder DENIED_GROUP sein. Bei SQL-bit-Konvertierung kann ein numerischer Nichtnullwert ungleich 0 zu 1 werden. Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert; für einen breiten Pfad fehlt damit die Bestätigung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCodeOut:** @StatusCodeOut varchar(40), Default: NULL OUTPUT. Eingabeform: einzelner varchar-Wert/Skalar oder OUTPUT-Variable. Eingehendes NULL und Leertext sind erlaubt, werden ignoriert. Eingehender Wert wird ignoriert und zuerst auf AVAILABLE gesetzt. Lokal mögliche Werte: AVAILABLE, INVALID_PARAMETER, INTERNAL_ERROR, HIGH_IMPACT_CONFIRMATION_REQUIRED, PARTIAL, LOCK_TIMEOUT und ERROR_HANDLED; Gate-Statuswerte werden weitergereicht. AVAILABLE bedeutet regulär beendet ohne gesetztes Teilfehlerflag, nicht vollständige Metadaten; INVALID_PARAMETER bedeutet lokal erkannter ungültiger Parameter oder ein entsprechendes Gate-Ergebnis; INTERNAL_ERROR bedeutet Fehler einer Temp-Tabellenprobe; HIGH_IMPACT_CONFIRMATION_REQUIRED bedeutet fehlende Bestätigung des breiten Pfads; PARTIAL bedeutet verzeichneten Teilfehler bei ansonsten regulärem Ende; LOCK_TIMEOUT bedeutet Fehler 1222 im äußeren Hauptteil-CATCH; ERROR_HANDLED bedeutet einen anderen Fehler in diesem CATCH; DENIED_GROUP bedeut'
            + N'et vom Gate nicht freigegebenen CATALOG_DEEP-Pfad. Das Gate kann INVALID_PARAMETER insbesondere bei NULL-Bestätigung oder ungültiger/unbekannter Analyseklasse liefern. Zum Empfangen passende Variable mit OUTPUT; ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe verworfen werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@IsPartialOut:** @IsPartialOut bit, Default: NULL OUTPUT. Eingabeform: einzelner SQL-bit- Wert/Skalar oder OUTPUT-Variable; NULL ist erlaubt und wird ignoriert, leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. Eingehender Wert wird ignoriert, zuerst 0, bei Teil- oder Fehlerausgabe 1. Zum Empfangen passende Variable mit OUTPUT; ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe verworfen werden. Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert; der Eingang wird wie NULL ignoriert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorNumberOut:** @ErrorNumberOut int, Default: NULL OUTPUT. Eingabeform: einzelner SQL-int- Wert/Skalar oder OUTPUT-Variable; NULL ist erlaubt und wird ignoriert, leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. Eingehender Wert wird ignoriert, zunächst NULL. Bei abgefangenen Fehlern enthält er ERROR_NUMBER() im Hauptteil-CATCH oder der Temp-Probe; Einzelquellenfehler können PARTIAL bei weiter NULL liefern. Gewöhnliche Parameter- oder Gate-Statuswerte setzen ihn nicht neu. Zum Empfangen passende Variable mit OUTPUT; ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe verworfen werden. Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert; der Eingang wird wie NULL ignoriert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048), Default: NULL OUTPUT. Eingabeform: einzelner nvarchar-Wert/Skalar oder OUTPUT-Variable; NULL und Leertext sind erlaubt und werden ignoriert. Eingehender Wert wird ignoriert, zunächst NULL. Lokale Parameterfehler, Temp-Tabellenprobe, Gate-Rückgabe und Hauptteil-CATCH setzen die jeweilige Meldung. Bei AVAILABLE sowie PARTIAL durch Einzelquellenfehler kann er NULL bleiben; Details stehen dann im CollectionStatus. Zum Empfangen passende Variable mit OUTPUT; ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe verworfen werden. Bei SQL-bit-Konvertierungen kann ein numerischer Nichtnullwert ungleich 0 bereits zu 1 konvertiert sein. Wirkung       : Liest Planreferenzen sowie SQL-Server-Katalog- und Statistikmetadaten und schreibt in #CreateExecutionEvidenceJson_StatisticsCurrent, #CreateExecutionEvidenceJson_HistogramSteps, #CreateExecutionEvidenceJson_HistogramSummary, #CreateExecutionEvidenceJson_PredicateHistogramMappings und #Cr'
            + N'eateExecutionEvidenceJson_CollectionStatus. Diese Daten werden nicht als Resultsets ausgegeben. Histogrammrohwerte werden in lokalen Tabellen verarbeitet; Prädikatwerte liegen in einer internen Temp-Tabelle. Keine Zusage vollständiger Katalogerfassung, atomarer Änderungen oder einer über die tatsächlichen SQL-Server-Prüfungen hinausgehenden Berechtigungssicherheit. Grenzen      : SET LOCK_TIMEOUT 0 erfolgt vor allen Prüfungen und gilt innerhalb der Procedure auch auf frühen Rückgabepfaden. Die eigene Wiederherstellungsanweisung im Hauptteil verwendet den danach gespeicherten Wert 0, keine vor Eintritt gesicherte Kopie. Der optionale Gate-Aufruf und sein Katalogzugriff liegen vor dem Hauptteil-TRY; dort unerwartet weitergeworfene Fehler können ohne Umsetzung in die globalen Fehlerausgaben entweichen. Fehler        : Wenn eine referenzierte Datenbank bei der Kandidatenermittlung unzugänglich ist, wird dafür ein CollectionStatus-Eintrag geschrieben. Fehler in den Schleifen werden soweit a'
            + N'bgefangen ebenfalls erfasst und markieren die Ausgabe als partiell. Fehler in der initialen Temp-Tabellenprobe setzen INTERNAL_ERROR und geben zurück. Gate-Ergebnisse INVALID_PARAMETER (ungültige Klasse oder Bestätigung), HIGH_IMPACT_CONFIRMATION_REQUIRED (Bestätigung fehlt) und DENIED_GROUP (Pfad nicht freigegeben) können durchgereicht werden; ErrorNumberOut kann dabei NULL bleiben. Der äußere CATCH des Hauptteils setzt LOCK_TIMEOUT bei Fehler 1222, sonst ERROR_HANDLED, samt Fehlernummer und -text. Bei einer späteren Datenbankprüfung ohne ELSE können inzwischen nicht erreichbare Datenbanken ohne eigenen Statusdatensatz bleiben. Bereits geschriebene Zeilen werden nicht zurückgerollt. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die fünf TOP (0)-Probes der vom Aufrufer angelegten Evidenz-#Temp-Tabellen erzeugen fünf leere Schema-Resultsets. Daten werden in diese lokalen Tabellen geschrieben, darunter Objekt-/Index-/Statistikmetadaten, CollectionStatus und gegebenenfalls Histogramm- und Prädikatzuordnungen; diese Zeilen werden nicht als zusätzliche fachliche Resultsets ausgegeben. `@StatusCodeOut` (varchar(40) OUTPUT) beginnt mit AVAILABLE und kann lokal INVALID_PARAMETER, INTERNAL_ERROR, HIGH_IMPACT_CONFIRMATION_REQUIRED, PARTIAL, LOCK_TIMEOUT oder ERROR_HANDLED sowie weitergereichte Gate-Statuswerte enthalten. `@IsPartialOut` (bit OUTPUT) beginnt mit 0 und kennzeichnet Teil-/Fehlerausgabe mit 1. `@ErrorNumberOut` (int OUTPUT) und `@ErrorMessageOut` (nvarchar(2048) OUTPUT) beginnen NULL; Einzelquellenfehler können PARTIAL ohne Fehlernummer ergeben. Die fünf TOP (0)-Probes belegen keinen vollständigen Schema- oder Rechtevertrag.'
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
            + N'WHERE [SchemaName]=N''monitor'' AND [ObjectName]=N''InternalCollectExecutionPlanMetadata'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[InternalCollectExecutionPlanMetadata] @PlanXml=NULL, @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'SET LOCK_TIMEOUT 0 erfolgt vor allen Prüfungen und gilt innerhalb der Procedure auch auf frühen Rückgabepfaden. Die eigene Wiederherstellungsanweisung im Hauptteil verwendet den danach gespeicherten Wert 0, keine vor Eintritt gesicherte Kopie. Der optionale Gate-Aufruf und sein Katalogzugriff liegen vor dem Hauptteil-TRY; dort unerwartet weitergeworfene Fehler können ohne Umsetzung in die globalen Fehlerausgaben entweichen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Wenn eine referenzierte Datenbank bei der Kandidatenermittlung unzugänglich ist, wird dafür ein CollectionStatus-Eintrag geschrieben. Fehler in den Schleifen werden soweit abgefangen ebenfalls erfasst und markieren die Ausgabe als partiell. Fehler in der initialen Temp-Tabellenprobe setzen INTERNAL_ERROR und geben zurück. Gate-Ergebnisse INVALID_PARAMETER (ungültige Klasse oder Bestätigung), HIGH_IMPACT_CONFIRMATION_REQUIRED (Bestätigung fehlt) und DENIED_GROUP (Pfad nicht freigegeben) können durchgereicht werden; ErrorNumberOut kann dabei NULL bleiben. Der äußere CATCH des Hauptteils setzt LOCK_TIMEOUT bei Fehler 1222, sonst ERROR_HANDLED, samt Fehlernummer und -text. Bei einer späteren Datenbankprüfung ohne ELSE können inzwischen nicht erreichbare Datenbanken ohne eigenen Statusdatensatz bleiben. Bereits geschriebene Zeilen werden nicht zurückgerollt.'
            + NCHAR(10)
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
            + N'Objekt       : monitor.InternalCollectExecutionPlanMetadata'
            + NCHAR(10)
            + N'Version      : 1.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-21'
            + NCHAR(10)
            + N'Typ          : Interne Stored Procedure'
            + NCHAR(10)
            + N'Zweck        : Die Procedure ermittelt zu einem Ausführungsplan Objekt-,'
            + NCHAR(10)
            + N'               Index- und Statistikmetadaten der ausdrücklich bestätigten'
            + NCHAR(10)
            + N'               Quellumgebung. Sie kann Histogrammschritte und Zusammenfassungen'
            + NCHAR(10)
            + N'               sowie Zuordnungen zu Planprädikaten sammeln.'
            + NCHAR(10)
            + N'Voraussetzung: Der Aufrufer legt die fünf Evidenz-Temp-Tabellen mit dem'
            + NCHAR(10)
            + N'               erwarteten Schema an. Je ein TOP (0)-SELECT prüft Existenz und'
            + NCHAR(10)
            + N'               Schemaauflösung, nicht das vollständige Schema oder die'
            + NCHAR(10)
            + N'               Berechtigungen. Die fünf Prüfungen erzeugen fünf'
            + NCHAR(10)
            + N'               leere Resultsets.'
            + NCHAR(10)
            + N'Eingabe      :'
            + NCHAR(10)
            + N'  @PlanXml xml, Default: keiner; obligatorisch. Eingabeform: einzelner'
            + NCHAR(10)
            + N'               XML-Ausführungsplan als XML-Wert oder gebundene XML-Variable;'
            + NCHAR(10)
            + N'               NULL ergibt INVALID_PARAMETER. Ein leeres, gültiges XML wird'
            + NCHAR(10)
            + N'               nicht ausdrücklich abgewiesen.'
            + NCHAR(10)
            + N'  @StatistikEvidenzModus varchar(16), Default: ''USED''. Eingabeform: ein'
            + NCHAR(10)
            + N'               einzelner Modus-Textwert, keine Liste. NULL wird zur Laufzeit'
            + NCHAR(10)
            + N'               zu USED;'
            + NCHAR(10)
            + N'               äußere Leerzeichen werden entfernt, Großschreibung angewendet.'
            + NCHAR(10)
            + N'               Endliche Werte: USED sammelt nur vom Plan als verwendet'
            + NCHAR(10)
            + N'               gemeldete Statistiken; RELEVANT ergänzt Statistiken, deren'
            + NCHAR(10)
            + N'               führende Spalte im Plan als SEEK, RESIDUAL, JOIN, ORDER_BY oder'
            + NCHAR(10)
            + N'               GROUP_BY vorkommt; OBJECT_ALL ergänzt alle Statistiken'
            + NCHAR(10)
            + N'               katalogauflösbarer Planobjekte. Leertext ist ungültig.'
            + NCHAR(10)
            + N'  @HistogrammModus varchar(16), Default: ''NONE''. Eingabeform: einzelner'
            + NCHAR(10)
            + N'               Modus-Textwert, keine Liste. NULL wird zur Laufzeit zu NONE;'
            + NCHAR(10)
            + N'               äußere Leerzeichen werden entfernt, Großschreibung angewendet.'
            + NCHAR(10)
            + N'               Endliche Werte: NONE sammelt im Hauptteil keine zusätzlichen Schritte;'
            + NCHAR(10)
            + N'               SUMMARY und STEPS sammeln Schritte und bilden Zusammenfassungen,'
            + NCHAR(10)
            + N'               wobei STEPS zusätzlich High-Impact-Bestätigung verlangt. Die'
            + NCHAR(10)
            + N'               Sammlung ist in beiden Modi gleich. Vorhandene Zeilen werden'
            + NCHAR(10)
            + N'               auch bei NONE zusammengefasst und können zugeordnet werden.'
            + NCHAR(10)
            + N'               Leertext oder nur Leerzeichen ist ungültig.'
            + NCHAR(10)
            + N'  @QuellumgebungBestaetigt bit, Default: 0. Eingabeform: einzelner SQL-bit-'
            + NCHAR(10)
            + N'               Wert oder Variable; leere Zeichenfolge ist keine vorgesehene'
            + NCHAR(10)
            + N'               Typform und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 bestätigt die'
            + NCHAR(10)
            + N'               Quellumgebung; 0 oder NULL ergeben INVALID_PARAMETER. Ausgelassen'
            + NCHAR(10)
            + N'               bindet den Default 0 und ergibt ebenfalls INVALID_PARAMETER.'
            + NCHAR(10)
            + N'               Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert und wie'
            + NCHAR(10)
            + N'               fehlende Bestätigung abgelehnt.'
            + NCHAR(10)
            + N'  @MitPredicateHistogramMap bit, Default: 1. Eingabeform: einzelner SQL-bit-'
            + NCHAR(10)
            + N'               Wert oder Variable; leere Zeichenfolge ist keine vorgesehene'
            + NCHAR(10)
            + N'               Typform und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 ordnet'
            + NCHAR(10)
            + N'               extrahierte Planparameterwerte Histogrammschritten zu; 0'
            + NCHAR(10)
            + N'               überspringt die Zuordnung. NULL ergibt INVALID_PARAMETER.'
            + NCHAR(10)
            + N'               Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert und'
            + NCHAR(10)
            + N'               überspringt die Zuordnung.'
            + NCHAR(10)
            + N'  @MaxStatistiken int, Default: 100. Eingabeform: einzelner SQL-int-Wert oder'
            + NCHAR(10)
            + N'               Variable; leere Zeichenfolge ist keine vorgesehene Typform und'
            + NCHAR(10)
            + N'               wird vor Eintritt konvertiert. Ganze Zahl 1 bis 1000 einschließlich;'
            + NCHAR(10)
            + N'               NULL und Werte außerhalb ergeben INVALID_PARAMETER. Begrenzt'
            + NCHAR(10)
            + N'               die insgesamt ausgewählten Kandidaten nach Priorität PLAN_USED,'
            + NCHAR(10)
            + N'               RELEVANT_LEADING_COLUMN, danach übrige. RELEVANT/OBJECT_ALL-'
            + NCHAR(10)
            + N'               Kandidaten werden vor dem Limit aus dem Katalog gelesen; ein'
            + NCHAR(10)
            + N'               positives Limit verhindert diese anfängliche Abfrage nicht.'
            + NCHAR(10)
            + N'               Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert und liegt'
            + NCHAR(10)
            + N'               außerhalb des gültigen Bereichs.'
            + NCHAR(10)
            + N'  @MaxHistogrammSchritte int, Default: 20000. Eingabeform: einzelner SQL-int-'
            + NCHAR(10)
            + N'               Wert oder Variable; leere Zeichenfolge ist keine vorgesehene'
            + NCHAR(10)
            + N'               Typform und wird vor Eintritt konvertiert. Ganze Zahl 0 bis 200000'
            + NCHAR(10)
            + N'               einschließlich; NULL und Werte außerhalb ergeben'
            + NCHAR(10)
            + N'               INVALID_PARAMETER. Begrenzt zusätzliche Schritte global anhand'
            + NCHAR(10)
            + N'               der bereits in der Aufrufer-Schritttabelle vorhandenen Zeilen;'
            + NCHAR(10)
            + N'               der Wert 0 fügt keine neuen Schritte ein.'
            + NCHAR(10)
            + N'               Bei erreichtem Limit werden keine weiteren eingefügt und'
            + NCHAR(10)
            + N'               vorhandene Zeilen nicht entfernt.'
            + NCHAR(10)
            + N'               Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert und fügt'
            + NCHAR(10)
            + N'               keine neuen Schritte ein.'
            + NCHAR(10)
            + N'  @LockTimeoutMs int, Default: 0. Eingabeform: einzelner SQL-int-Wert oder'
            + NCHAR(10)
            + N'               Variable; leere Zeichenfolge ist keine vorgesehene Typform und'
            + NCHAR(10)
            + N'               wird vor Eintritt konvertiert. Ganze Zahl 0 bis 60000 Millisekunden;'
            + NCHAR(10)
            + N'               NULL und Werte außerhalb ergeben INVALID_PARAMETER. Steuert'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT im Hauptteil nach frühen Prüfungen. Die Procedure'
            + NCHAR(10)
            + N'               setzt zuerst LOCK_TIMEOUT 0 und speichert den Wert erst danach;'
            + NCHAR(10)
            + N'               am Ende wird somit 0 statt des vorherigen Aufruferwerts'
            + NCHAR(10)
            + N'               wiederhergestellt.'
            + NCHAR(10)
            + N'               Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert; 0'
            + NCHAR(10)
            + N'               Millisekunden bedeutet kein Warten auf eine Sperre.'
            + NCHAR(10)
            + N'  @HighImpactConfirmed bit, Default: 0. Eingabeform: einzelner SQL-bit-Wert'
            + NCHAR(10)
            + N'               oder Variable; leere Zeichenfolge ist keine vorgesehene Typform'
            + NCHAR(10)
            + N'               und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 bestätigt den'
            + NCHAR(10)
            + N'               High-Impact-Pfad, 0 nicht. Für RELEVANT, OBJECT_ALL und STEPS'
            + NCHAR(10)
            + N'               führt 0 zu HIGH_IMPACT_CONFIRMATION_REQUIRED; SUMMARY allein'
            + NCHAR(10)
            + N'               verlangt die Bestätigung nicht. NULL ergibt vor den Temp-Tabellen-'
            + NCHAR(10)
            + N'               Prüfungen INVALID_PARAMETER. Die lokale Bestätigungsprüfung'
            + NCHAR(10)
            + N'               erfolgt vor dem optionalen Gate-Aufruf; dessen Ergebnisse können'
            + NCHAR(10)
            + N'               außerdem HIGH_IMPACT_CONFIRMATION_REQUIRED, INVALID_PARAMETER'
            + NCHAR(10)
            + N'               oder DENIED_GROUP sein. Bei SQL-bit-Konvertierung kann ein'
            + NCHAR(10)
            + N'               numerischer Nichtnullwert ungleich 0 zu 1 werden.'
            + NCHAR(10)
            + N'               Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert; für'
            + NCHAR(10)
            + N'               einen breiten Pfad fehlt damit die Bestätigung.'
            + NCHAR(10)
            + N'  @StatusCodeOut varchar(40), Default: NULL OUTPUT. Eingabeform: einzelner'
            + NCHAR(10)
            + N'               varchar-Wert/Skalar oder OUTPUT-Variable. Eingehendes NULL und'
            + NCHAR(10)
            + N'               Leertext sind erlaubt, werden ignoriert. Eingehender Wert wird'
            + NCHAR(10)
            + N'               ignoriert und zuerst auf AVAILABLE gesetzt. Lokal mögliche'
            + NCHAR(10)
            + N'               Werte: AVAILABLE, INVALID_PARAMETER, INTERNAL_ERROR,'
            + NCHAR(10)
            + N'               HIGH_IMPACT_CONFIRMATION_REQUIRED, PARTIAL, LOCK_TIMEOUT und'
            + NCHAR(10)
            + N'               ERROR_HANDLED; Gate-Statuswerte werden weitergereicht.'
            + NCHAR(10)
            + N'               AVAILABLE bedeutet regulär beendet ohne gesetztes Teilfehlerflag, nicht'
            + NCHAR(10)
            + N'               vollständige Metadaten; INVALID_PARAMETER bedeutet lokal erkannter'
            + NCHAR(10)
            + N'               ungültiger Parameter oder ein entsprechendes Gate-Ergebnis; INTERNAL_ERROR'
            + NCHAR(10)
            + N'               bedeutet Fehler einer Temp-Tabellenprobe; HIGH_IMPACT_CONFIRMATION_REQUIRED'
            + NCHAR(10)
            + N'               bedeutet fehlende Bestätigung des breiten Pfads; PARTIAL bedeutet'
            + NCHAR(10)
            + N'               verzeichneten Teilfehler bei ansonsten regulärem Ende; LOCK_TIMEOUT bedeutet'
            + NCHAR(10)
            + N'               Fehler 1222 im äußeren Hauptteil-CATCH; ERROR_HANDLED bedeutet einen anderen'
            + NCHAR(10)
            + N'               Fehler in diesem CATCH; DENIED_GROUP bedeutet vom Gate nicht freigegebenen'
            + NCHAR(10)
            + N'               CATALOG_DEEP-Pfad. Das Gate kann INVALID_PARAMETER insbesondere bei'
            + NCHAR(10)
            + N'               NULL-Bestätigung oder ungültiger/unbekannter Analyseklasse liefern. Zum Empfangen passende Variable mit OUTPUT;'
            + NCHAR(10)
            + N'               ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe'
            + NCHAR(10)
            + N'               verworfen werden.'
            + NCHAR(10)
            + N'  @IsPartialOut bit, Default: NULL OUTPUT. Eingabeform: einzelner SQL-bit-'
            + NCHAR(10)
            + N'               Wert/Skalar oder OUTPUT-Variable; NULL ist erlaubt und wird'
            + NCHAR(10)
            + N'               ignoriert, leere Zeichenfolge ist keine vorgesehene Typform und'
            + NCHAR(10)
            + N'               wird vor Eintritt konvertiert. Eingehender Wert wird ignoriert,'
            + NCHAR(10)
            + N'               zuerst 0, bei Teil- oder Fehlerausgabe 1. Zum Empfangen'
            + NCHAR(10)
            + N'               passende Variable mit OUTPUT; ohne OUTPUT kann typgerechter'
            + NCHAR(10)
            + N'               Skalar übergeben und Ausgabe verworfen werden.'
            + NCHAR(10)
            + N'               Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert; der'
            + NCHAR(10)
            + N'               Eingang wird wie NULL ignoriert.'
            + NCHAR(10)
            + N'  @ErrorNumberOut int, Default: NULL OUTPUT. Eingabeform: einzelner SQL-int-'
            + NCHAR(10)
            + N'               Wert/Skalar oder OUTPUT-Variable; NULL ist erlaubt und wird'
            + NCHAR(10)
            + N'               ignoriert, leere Zeichenfolge ist keine vorgesehene Typform und'
            + NCHAR(10)
            + N'               wird vor Eintritt konvertiert. Eingehender Wert wird ignoriert,'
            + NCHAR(10)
            + N'               zunächst NULL. Bei abgefangenen Fehlern enthält er'
            + NCHAR(10)
            + N'               ERROR_NUMBER() im Hauptteil-CATCH oder der Temp-Probe;'
            + NCHAR(10)
            + N'               Einzelquellenfehler können PARTIAL bei weiter NULL liefern.'
            + NCHAR(10)
            + N'               Gewöhnliche Parameter- oder Gate-Statuswerte setzen ihn nicht neu. Zum Empfangen passende Variable mit'
            + NCHAR(10)
            + N'               OUTPUT; ohne OUTPUT kann typgerechter Skalar übergeben und'
            + NCHAR(10)
            + N'               Ausgabe verworfen werden.'
            + NCHAR(10)
            + N'               Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert; der'
            + NCHAR(10)
            + N'               Eingang wird wie NULL ignoriert.'
            + NCHAR(10)
            + N'  @ErrorMessageOut nvarchar(2048), Default: NULL OUTPUT. Eingabeform: einzelner'
            + NCHAR(10)
            + N'               nvarchar-Wert/Skalar oder OUTPUT-Variable; NULL und Leertext'
            + NCHAR(10)
            + N'               sind erlaubt und werden ignoriert. Eingehender Wert wird'
            + NCHAR(10)
            + N'               ignoriert, zunächst NULL. Lokale Parameterfehler, Temp-Tabellenprobe, Gate-Rückgabe und'
            + NCHAR(10)
            + N'               Hauptteil-CATCH setzen die jeweilige Meldung. Bei AVAILABLE sowie'
            + NCHAR(10)
            + N'               PARTIAL durch Einzelquellenfehler kann er NULL bleiben; Details'
            + NCHAR(10)
            + N'               stehen dann im CollectionStatus. Zum Empfangen passende Variable mit OUTPUT;'
            + NCHAR(10)
            + N'               ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe'
            + NCHAR(10)
            + N'               verworfen werden.'
            + NCHAR(10)
            + N'               Bei SQL-bit-Konvertierungen kann ein numerischer Nichtnullwert'
            + NCHAR(10)
            + N'               ungleich 0 bereits zu 1 konvertiert sein.'
            + NCHAR(10)
            + N'Wirkung       : Liest Planreferenzen sowie SQL-Server-Katalog- und'
            + NCHAR(10)
            + N'               Statistikmetadaten und schreibt in'
            + NCHAR(10)
            + N'               #CreateExecutionEvidenceJson_StatisticsCurrent,'
            + NCHAR(10)
            + N'               #CreateExecutionEvidenceJson_HistogramSteps,'
            + NCHAR(10)
            + N'               #CreateExecutionEvidenceJson_HistogramSummary,'
            + NCHAR(10)
            + N'               #CreateExecutionEvidenceJson_PredicateHistogramMappings und'
            + NCHAR(10)
            + N'               #CreateExecutionEvidenceJson_CollectionStatus. Diese Daten'
            + NCHAR(10)
            + N'               werden nicht als Resultsets ausgegeben. Histogrammrohwerte'
            + NCHAR(10)
            + N'               werden in lokalen Tabellen verarbeitet; Prädikatwerte liegen'
            + NCHAR(10)
            + N'               in einer internen Temp-Tabelle. Keine Zusage vollständiger'
            + NCHAR(10)
            + N'               Katalogerfassung, atomarer Änderungen oder einer über die'
            + NCHAR(10)
            + N'               tatsächlichen SQL-Server-Prüfungen hinausgehenden'
            + NCHAR(10)
            + N'               Berechtigungssicherheit.'
            + NCHAR(10)
            + N'Grenzen      : SET LOCK_TIMEOUT 0 erfolgt vor allen Prüfungen und gilt innerhalb der'
            + NCHAR(10)
            + N'               Procedure auch auf frühen Rückgabepfaden. Die eigene'
            + NCHAR(10)
            + N'               Wiederherstellungsanweisung im Hauptteil verwendet den danach gespeicherten'
            + NCHAR(10)
            + N'               Wert 0, keine vor Eintritt gesicherte Kopie. Der optionale Gate-Aufruf und'
            + NCHAR(10)
            + N'               sein Katalogzugriff liegen vor dem Hauptteil-TRY; dort unerwartet'
            + NCHAR(10)
            + N'               weitergeworfene Fehler können ohne Umsetzung in die globalen Fehlerausgaben'
            + NCHAR(10)
            + N'               entweichen.'
            + NCHAR(10)
            + N'Fehler        : Wenn eine referenzierte Datenbank bei der Kandidatenermittlung'
            + NCHAR(10)
            + N'               unzugänglich ist, wird dafür ein CollectionStatus-Eintrag'
            + NCHAR(10)
            + N'               geschrieben. Fehler in den Schleifen werden soweit abgefangen'
            + NCHAR(10)
            + N'               ebenfalls erfasst und markieren die Ausgabe als partiell. Fehler in der initialen Temp-Tabellenprobe setzen'
            + NCHAR(10)
            + N'               INTERNAL_ERROR und geben zurück. Gate-Ergebnisse INVALID_PARAMETER (ungültige Klasse oder Bestätigung),'
            + NCHAR(10)
            + N'               HIGH_IMPACT_CONFIRMATION_REQUIRED (Bestätigung fehlt) und'
            + NCHAR(10)
            + N'               DENIED_GROUP (Pfad nicht freigegeben) können durchgereicht'
            + NCHAR(10)
            + N'               werden; ErrorNumberOut kann dabei NULL bleiben. Der äußere CATCH des Hauptteils setzt'
            + NCHAR(10)
            + N'               LOCK_TIMEOUT bei Fehler 1222, sonst ERROR_HANDLED, samt'
            + NCHAR(10)
            + N'               Fehlernummer und -text. Bei einer späteren Datenbankprüfung ohne ELSE können inzwischen nicht'
            + NCHAR(10)
            + N'               erreichbare Datenbanken ohne eigenen Statusdatensatz bleiben.'
            + NCHAR(10)
            + N'               Bereits geschriebene Zeilen werden nicht zurückgerollt.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.InternalCollectExecutionPlanMetadata
        RETURN;
    END;

    SET LOCK_TIMEOUT 0;

    SELECT
          @StatistikEvidenzModus=UPPER(LTRIM(RTRIM(COALESCE(@StatistikEvidenzModus,'USED'))))
        , @HistogrammModus=UPPER(LTRIM(RTRIM(COALESCE(@HistogrammModus,'NONE'))))
        , @StatusCodeOut='AVAILABLE'
        , @IsPartialOut=0
        , @ErrorNumberOut=NULL
        , @ErrorMessageOut=NULL;

    IF @PlanXml IS NULL
       OR @StatistikEvidenzModus NOT IN ('USED','RELEVANT','OBJECT_ALL')
       OR @HistogrammModus NOT IN ('NONE','SUMMARY','STEPS')
       OR @QuellumgebungBestaetigt IS NULL OR @QuellumgebungBestaetigt<>1
       OR @MitPredicateHistogramMap IS NULL OR @MitPredicateHistogramMap NOT IN (0,1)
       OR @MaxStatistiken IS NULL OR @MaxStatistiken NOT BETWEEN 1 AND 1000
       OR @MaxHistogrammSchritte IS NULL OR @MaxHistogrammSchritte NOT BETWEEN 0 AND 200000
       OR @LockTimeoutMs IS NULL OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
       OR @HighImpactConfirmed IS NULL OR @HighImpactConfirmed NOT IN (0,1)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'Ungültiger Plan-, Modus-, Bestätigungs-, Mengen- oder Lock-Timeout-Parameter.';
        RETURN;
    END;

    BEGIN TRY
        SELECT TOP (0) * FROM [#CreateExecutionEvidenceJson_StatisticsCurrent];
        SELECT TOP (0) * FROM [#CreateExecutionEvidenceJson_HistogramSteps];
        SELECT TOP (0) * FROM [#CreateExecutionEvidenceJson_HistogramSummary];
        SELECT TOP (0) * FROM [#CreateExecutionEvidenceJson_PredicateHistogramMappings];
        SELECT TOP (0) * FROM [#CreateExecutionEvidenceJson_CollectionStatus];
    END TRY
    BEGIN CATCH
        SELECT @StatusCodeOut='INTERNAL_ERROR',@IsPartialOut=1,
               @ErrorNumberOut=ERROR_NUMBER(),
               @ErrorMessageOut=N'Die erwarteten lokalen Evidenz-Temp-Tabellen fehlen oder besitzen ein unpassendes Schema.';
        RETURN;
    END CATCH;

    IF @StatistikEvidenzModus IN ('RELEVANT','OBJECT_ALL') OR @HistogrammModus='STEPS'
    BEGIN
        IF @HighImpactConfirmed<>1
        BEGIN
            SELECT @StatusCodeOut='HIGH_IMPACT_CONFIRMATION_REQUIRED',@IsPartialOut=1,
                   @ErrorMessageOut=N'Die angeforderte breite Statistik- oder Histogrammanreicherung benötigt @HighImpactConfirmed=1.';
            RETURN;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM [sys].[procedures] AS [p] WITH (NOLOCK)
            JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
              ON [s].[schema_id]=[p].[schema_id]
            WHERE [s].[name]=N'monitor'
              AND [p].[name]=N'InternalCheckAnalysisPath'
        )
        BEGIN
            DECLARE @GateStatus varchar(40),@GateMessage nvarchar(2048);
            EXEC [sys].[sp_executesql]
                  N'EXEC [monitor].[InternalCheckAnalysisPath]
                          @AnalysisClass=''CATALOG_DEEP'',
                          @HighImpactConfirmed=@HighImpactConfirmed,
                          @StatusCode=@StatusCode OUTPUT,
                          @ErrorMessage=@ErrorMessage OUTPUT;'
                , N'@HighImpactConfirmed bit,@StatusCode varchar(40) OUTPUT,@ErrorMessage nvarchar(2048) OUTPUT'
                , @HighImpactConfirmed=@HighImpactConfirmed
                , @StatusCode=@GateStatus OUTPUT
                , @ErrorMessage=@GateMessage OUTPUT;
            IF @GateStatus<>'AVAILABLE'
            BEGIN
                SELECT @StatusCodeOut=@GateStatus,@IsPartialOut=1,@ErrorMessageOut=@GateMessage;
                RETURN;
            END;
        END;
    END;

    DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT;
    DECLARE @LockTimeoutSql nvarchar(100)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N';';
    EXEC [sys].[sp_executesql] @LockTimeoutSql;

    BEGIN TRY
    CREATE TABLE [#InternalCollectExecutionPlanMetadata_ObjectReferences]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , PRIMARY KEY ([DatabaseName],[SchemaName],[ObjectName])
    );
    CREATE TABLE [#InternalCollectExecutionPlanMetadata_RelevantColumns]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , PRIMARY KEY ([DatabaseName],[SchemaName],[ObjectName],[ColumnName])
    );
    CREATE TABLE [#InternalCollectExecutionPlanMetadata_CandidateStatistics]
    (
          [CandidateId] int IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StatisticsName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CandidateSource] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , UNIQUE ([DatabaseName],[SchemaName],[ObjectName],[StatisticsName])
    );
    CREATE TABLE [#InternalCollectExecutionPlanMetadata_PredicateValues]
    (
          [PredicateReferenceId] bigint IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [StatementOrdinal] int NOT NULL
        , [NodeId] int NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [PredicateKind] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ParameterName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CompiledValueRaw] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RuntimeValueRaw] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CompiledValueNormalized] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RuntimeValueNormalized] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    INSERT [#InternalCollectExecutionPlanMetadata_ObjectReferences]([DatabaseName],[SchemaName],[ObjectName])
    SELECT [DatabaseName],[SchemaName],[ObjectName]
    FROM [monitor].[TVF_ExecutionPlanObjectReferences](@PlanXml,NULL)
    WHERE [ResolutionCapability]='CATALOG_RESOLVABLE'
      AND [DatabaseName] IS NOT NULL AND [SchemaName] IS NOT NULL AND [ObjectName] IS NOT NULL
    GROUP BY [DatabaseName],[SchemaName],[ObjectName];

    INSERT [#InternalCollectExecutionPlanMetadata_RelevantColumns]([DatabaseName],[SchemaName],[ObjectName],[ColumnName])
    SELECT [DatabaseName],[SchemaName],[ObjectName],[ColumnName]
    FROM [monitor].[TVF_ExecutionPlanColumnReferences](@PlanXml,NULL)
    WHERE [ColumnUsage] IN ('SEEK','RESIDUAL','JOIN','ORDER_BY','GROUP_BY')
      AND [DatabaseName] IS NOT NULL AND [SchemaName] IS NOT NULL
      AND [ObjectName] IS NOT NULL AND [ColumnName] IS NOT NULL
    GROUP BY [DatabaseName],[SchemaName],[ObjectName],[ColumnName];

    INSERT [#InternalCollectExecutionPlanMetadata_CandidateStatistics]
    ([DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[CandidateSource])
    SELECT [DatabaseName],[SchemaName],[ObjectName],[StatisticsName],'PLAN_USED'
    FROM [monitor].[TVF_ExecutionPlanStatisticsUsage](@PlanXml,NULL)
    WHERE [ParseStatus]='AVAILABLE'
      AND [DatabaseName] IS NOT NULL AND [SchemaName] IS NOT NULL
      AND [ObjectName] IS NOT NULL AND [StatisticsName] IS NOT NULL
    GROUP BY [DatabaseName],[SchemaName],[ObjectName],[StatisticsName];

    DECLARE @Db sysname,@Schema sysname,@Object sysname,@Sql nvarchar(max);
    DECLARE [ObjectCursor] CURSOR LOCAL FAST_FORWARD FOR
        SELECT [DatabaseName],[SchemaName],[ObjectName]
        FROM [#InternalCollectExecutionPlanMetadata_ObjectReferences]
        ORDER BY [DatabaseName],[SchemaName],[ObjectName];

    IF @StatistikEvidenzModus IN ('RELEVANT','OBJECT_ALL')
    BEGIN
        OPEN [ObjectCursor];
        FETCH NEXT FROM [ObjectCursor] INTO @Db,@Schema,@Object;
        WHILE @@FETCH_STATUS=0
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
                WHERE [d].[name]=@Db AND [d].[state]=0 AND HAS_DBACCESS([d].[name])=1
            )
            BEGIN
                BEGIN TRY
                    SET @Sql=N'USE '+QUOTENAME(@Db)+N';
INSERT [#InternalCollectExecutionPlanMetadata_CandidateStatistics]
([DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[CandidateSource])
SELECT @DatabaseName,[sc].[name],[o].[name],[st].[name],
       CASE WHEN @Mode=''OBJECT_ALL'' THEN ''OBJECT_ALL'' ELSE ''RELEVANT_LEADING_COLUMN'' END
FROM [sys].[schemas] AS [sc] WITH (NOLOCK)
JOIN [sys].[objects] AS [o] WITH (NOLOCK) ON [o].[schema_id]=[sc].[schema_id]
JOIN [sys].[stats] AS [st] WITH (NOLOCK) ON [st].[object_id]=[o].[object_id]
WHERE [sc].[name]=@SchemaName AND [o].[name]=@ObjectName
  AND
  (
      @Mode=''OBJECT_ALL''
      OR EXISTS
      (
          SELECT 1
          FROM [sys].[stats_columns] AS [stc] WITH (NOLOCK)
          JOIN [sys].[columns] AS [c] WITH (NOLOCK)
            ON [c].[object_id]=[stc].[object_id] AND [c].[column_id]=[stc].[column_id]
          JOIN [#InternalCollectExecutionPlanMetadata_RelevantColumns] AS [rc]
            ON [rc].[DatabaseName]=@DatabaseName
           AND [rc].[SchemaName]=@SchemaName
           AND [rc].[ObjectName]=@ObjectName
           AND [rc].[ColumnName]=[c].[name]
          WHERE [stc].[object_id]=[st].[object_id]
            AND [stc].[stats_id]=[st].[stats_id]
            AND [stc].[stats_column_id]=1
      )
  )
  AND NOT EXISTS
  (
      SELECT 1 FROM [#InternalCollectExecutionPlanMetadata_CandidateStatistics] AS [x]
      WHERE [x].[DatabaseName]=@DatabaseName
        AND [x].[SchemaName]=[sc].[name]
        AND [x].[ObjectName]=[o].[name]
        AND [x].[StatisticsName]=[st].[name]
  );';
                    EXEC [sys].[sp_executesql]
                          @Sql
                        , N'@DatabaseName sysname,@SchemaName sysname,@ObjectName sysname,@Mode varchar(16)'
                        , @DatabaseName=@Db,@SchemaName=@Schema,@ObjectName=@Object,@Mode=@StatistikEvidenzModus;
                END TRY
                BEGIN CATCH
                    INSERT [#CreateExecutionEvidenceJson_CollectionStatus]
                    ([DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[StatusCode],[ErrorNumber],[ErrorMessage])
                    VALUES(@Db,@Schema,@Object,NULL,'ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE());
                    SET @IsPartialOut=1;
                END CATCH;
            END
            ELSE
            BEGIN
                INSERT [#CreateExecutionEvidenceJson_CollectionStatus]
                ([DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[StatusCode],[ErrorNumber],[ErrorMessage])
                VALUES(@Db,@Schema,@Object,NULL,'DATABASE_UNAVAILABLE',NULL,N'Die im Plan referenzierte Datenbank ist in der bestätigten aktuellen Umgebung nicht zugreifbar.');
                SET @IsPartialOut=1;
            END;

            FETCH NEXT FROM [ObjectCursor] INTO @Db,@Schema,@Object;
        END;
        CLOSE [ObjectCursor];
        DEALLOCATE [ObjectCursor];
    END;

    DELETE [c]
    FROM [#InternalCollectExecutionPlanMetadata_CandidateStatistics] AS [c]
    WHERE [c].[CandidateId] NOT IN
    (
        SELECT TOP (@MaxStatistiken) [CandidateId]
        FROM [#InternalCollectExecutionPlanMetadata_CandidateStatistics]
        ORDER BY CASE [CandidateSource] WHEN 'PLAN_USED' THEN 1 WHEN 'RELEVANT_LEADING_COLUMN' THEN 2 ELSE 3 END,
                 [DatabaseName],[SchemaName],[ObjectName],[StatisticsName]
    );

    DECLARE [DatabaseCursor] CURSOR LOCAL FAST_FORWARD FOR
        SELECT [DatabaseName]
        FROM [#InternalCollectExecutionPlanMetadata_CandidateStatistics]
        GROUP BY [DatabaseName]
        ORDER BY [DatabaseName];

    OPEN [DatabaseCursor];
    FETCH NEXT FROM [DatabaseCursor] INTO @Db;
    WHILE @@FETCH_STATUS=0
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
            WHERE [d].[name]=@Db AND [d].[state]=0 AND HAS_DBACCESS([d].[name])=1
        )
        BEGIN TRY
            SET @Sql=N'USE '+QUOTENAME(@Db)+N';
INSERT [#CreateExecutionEvidenceJson_StatisticsCurrent]
(
      [DatabaseName],[SchemaName],[ObjectName],[ObjectId]
    , [StatisticsName],[StatisticsId],[IsIndexStatistics]
    , [IsAutoCreated],[IsUserCreated],[IsFiltered],[FilterDefinition]
    , [NoRecompute],[IsIncremental],[HasPersistedSample]
    , [LeadingColumnName],[LastUpdated],[Rows],[RowsSampled]
    , [SamplePercent],[Steps],[UnfilteredRows],[ModificationCounter]
    , [ModificationPercent],[PersistedSamplePercent],[CollectionStatus]
)
SELECT
      @DatabaseName,[sc].[name],[o].[name],[o].[object_id]
    , [st].[name],[st].[stats_id],CONVERT(bit,CASE WHEN [i].[index_id] IS NULL THEN 0 ELSE 1 END)
    , [st].[auto_created],[st].[user_created],[st].[has_filter],[st].[filter_definition]
    , [st].[no_recompute],[st].[is_incremental],[st].[has_persisted_sample]
    , [lc].[name],[sp].[last_updated],[sp].[rows],[sp].[rows_sampled]
    , CONVERT(decimal(19,6),CASE WHEN [sp].[rows]>0 THEN 100.0*[sp].[rows_sampled]/[sp].[rows] END)
    , [sp].[steps],[sp].[unfiltered_rows],[sp].[modification_counter]
    , CONVERT(decimal(19,6),CASE WHEN [sp].[rows]>0 THEN 100.0*[sp].[modification_counter]/[sp].[rows] END)
    , [sp].[persisted_sample_percent]
    , CASE WHEN [sp].[last_updated] IS NULL THEN ''PROPERTIES_UNAVAILABLE'' ELSE ''AVAILABLE'' END
FROM [#InternalCollectExecutionPlanMetadata_CandidateStatistics] AS [cs]
JOIN [sys].[schemas] AS [sc] WITH (NOLOCK) ON [sc].[name]=[cs].[SchemaName]
JOIN [sys].[objects] AS [o] WITH (NOLOCK) ON [o].[schema_id]=[sc].[schema_id] AND [o].[name]=[cs].[ObjectName]
JOIN [sys].[stats] AS [st] WITH (NOLOCK) ON [st].[object_id]=[o].[object_id] AND [st].[name]=[cs].[StatisticsName]
LEFT JOIN [sys].[indexes] AS [i] WITH (NOLOCK) ON [i].[object_id]=[st].[object_id] AND [i].[index_id]=[st].[stats_id]
LEFT JOIN [sys].[stats_columns] AS [stc] WITH (NOLOCK) ON [stc].[object_id]=[st].[object_id] AND [stc].[stats_id]=[st].[stats_id] AND [stc].[stats_column_id]=1
LEFT JOIN [sys].[columns] AS [lc] WITH (NOLOCK) ON [lc].[object_id]=[stc].[object_id] AND [lc].[column_id]=[stc].[column_id]
OUTER APPLY [sys].[dm_db_stats_properties]([st].[object_id],[st].[stats_id]) AS [sp]
WHERE [cs].[DatabaseName]=@DatabaseName
  AND NOT EXISTS
  (
      SELECT 1 FROM [#CreateExecutionEvidenceJson_StatisticsCurrent] AS [x]
      WHERE [x].[DatabaseName]=@DatabaseName AND [x].[SchemaName]=[sc].[name]
        AND [x].[ObjectName]=[o].[name] AND [x].[StatisticsName]=[st].[name]
  );';
            EXEC [sys].[sp_executesql] @Sql,N'@DatabaseName sysname',@DatabaseName=@Db;

            IF @HistogrammModus<>'NONE'
            BEGIN
                DECLARE @ExistingSteps int=(SELECT COUNT(*) FROM [#CreateExecutionEvidenceJson_HistogramSteps]);
                DECLARE @RemainingSteps int=@MaxHistogrammSchritte-@ExistingSteps;
                IF @RemainingSteps>0
                BEGIN
                    SET @Sql=N'USE '+QUOTENAME(@Db)+N';
INSERT [#CreateExecutionEvidenceJson_HistogramSteps]
(
      [DatabaseName],[SchemaName],[ObjectName],[StatisticsName]
    , [StatisticsId],[LeadingColumnName],[StepOrdinal],[RangeHighKeyRaw]
    , [RangeRows],[EqualRows],[DistinctRangeRows],[AverageRangeRows]
)
SELECT TOP (@RemainingSteps)
      @DatabaseName,[sc].[name],[o].[name],[st].[name]
    , [st].[stats_id],[lc].[name],[h].[step_number]
    , CONVERT(nvarchar(4000),[h].[range_high_key])
    , [h].[range_rows],[h].[equal_rows],[h].[distinct_range_rows],[h].[average_range_rows]
FROM [#InternalCollectExecutionPlanMetadata_CandidateStatistics] AS [cs]
JOIN [sys].[schemas] AS [sc] WITH (NOLOCK) ON [sc].[name]=[cs].[SchemaName]
JOIN [sys].[objects] AS [o] WITH (NOLOCK) ON [o].[schema_id]=[sc].[schema_id] AND [o].[name]=[cs].[ObjectName]
JOIN [sys].[stats] AS [st] WITH (NOLOCK) ON [st].[object_id]=[o].[object_id] AND [st].[name]=[cs].[StatisticsName]
LEFT JOIN [sys].[stats_columns] AS [stc] WITH (NOLOCK) ON [stc].[object_id]=[st].[object_id] AND [stc].[stats_id]=[st].[stats_id] AND [stc].[stats_column_id]=1
LEFT JOIN [sys].[columns] AS [lc] WITH (NOLOCK) ON [lc].[object_id]=[stc].[object_id] AND [lc].[column_id]=[stc].[column_id]
CROSS APPLY [sys].[dm_db_stats_histogram]([st].[object_id],[st].[stats_id]) AS [h]
WHERE [cs].[DatabaseName]=@DatabaseName
ORDER BY [cs].[CandidateId],[h].[step_number];';
                    EXEC [sys].[sp_executesql]
                          @Sql
                        , N'@DatabaseName sysname,@RemainingSteps int'
                        , @DatabaseName=@Db,@RemainingSteps=@RemainingSteps;
                END;
            END;
        END TRY
        BEGIN CATCH
            INSERT [#CreateExecutionEvidenceJson_CollectionStatus]
            ([DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[StatusCode],[ErrorNumber],[ErrorMessage])
            VALUES(@Db,NULL,NULL,NULL,CASE WHEN ERROR_NUMBER()=1222 THEN 'LOCK_TIMEOUT' ELSE 'ERROR_HANDLED' END,ERROR_NUMBER(),ERROR_MESSAGE());
            SET @IsPartialOut=1;
        END CATCH;

        FETCH NEXT FROM [DatabaseCursor] INTO @Db;
    END;
    CLOSE [DatabaseCursor];
    DEALLOCATE [DatabaseCursor];

    INSERT [#CreateExecutionEvidenceJson_HistogramSummary]
    (
          [DatabaseName],[SchemaName],[ObjectName],[StatisticsName]
        , [StatisticsId],[LeadingColumnName],[HistogramSteps]
        , [HistogramEstimatedRows],[MaxEqualRows],[MaxRangeRows]
        , [MaxStepRows],[DominantStepPercent],[TailStepRows],[TailStepPercent]
        , [CollectionStatus]
    )
    SELECT
          [DatabaseName],[SchemaName],[ObjectName],[StatisticsName]
        , [StatisticsId],MAX([LeadingColumnName]),COUNT(*)
        , SUM(COALESCE([RangeRows],0)+COALESCE([EqualRows],0))
        , MAX([EqualRows]),MAX([RangeRows])
        , MAX(COALESCE([RangeRows],0)+COALESCE([EqualRows],0))
        , CONVERT(decimal(19,6),100.0*MAX(COALESCE([RangeRows],0)+COALESCE([EqualRows],0))
            /NULLIF(SUM(COALESCE([RangeRows],0)+COALESCE([EqualRows],0)),0))
        , MAX(CASE WHEN [StepOrdinal]=[mx].[MaxStepOrdinal]
                   THEN COALESCE([RangeRows],0)+COALESCE([EqualRows],0) END)
        , CONVERT(decimal(19,6),100.0*MAX(CASE WHEN [StepOrdinal]=[mx].[MaxStepOrdinal]
                   THEN COALESCE([RangeRows],0)+COALESCE([EqualRows],0) END)
            /NULLIF(SUM(COALESCE([RangeRows],0)+COALESCE([EqualRows],0)),0))
        , 'AVAILABLE'
    FROM [#CreateExecutionEvidenceJson_HistogramSteps] AS [h]
    CROSS APPLY
    (
        SELECT MAX([StepOrdinal]) [MaxStepOrdinal]
        FROM [#CreateExecutionEvidenceJson_HistogramSteps] AS [h2]
        WHERE [h2].[DatabaseName]=[h].[DatabaseName]
          AND [h2].[SchemaName]=[h].[SchemaName]
          AND [h2].[ObjectName]=[h].[ObjectName]
          AND [h2].[StatisticsName]=[h].[StatisticsName]
    ) AS [mx]
    GROUP BY [DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[StatisticsId];

    /*
    Predicate-/Parameterextraktion. Die Rohwerte bleiben in dieser internen
    Temp-Tabelle und werden weder von dieser Procedure ausgegeben noch persistiert.
    */
    IF @MitPredicateHistogramMap=1 AND EXISTS(SELECT 1 FROM [#CreateExecutionEvidenceJson_HistogramSteps])
    BEGIN
        ;WITH [StatementsBase] AS
        (
            SELECT
                  [StatementXml]=[s].[n].query('.')
                , [StatementId]=TRY_CONVERT(int,NULLIF([s].[n].value('string((@StatementId)[1])','nvarchar(50)'),N''))
                , [StatementCompId]=TRY_CONVERT(int,NULLIF([s].[n].value('string((@StatementCompId)[1])','nvarchar(50)'),N''))
                , [StatementText]=NULLIF([s].[n].value('string((@StatementText)[1])','nvarchar(4000)'),N'')
            FROM @PlanXml.nodes('//*[local-name(.)="StmtSimple"]') AS [s]([n])
        ),
        [Statements] AS
        (
            SELECT
                  [StatementOrdinal]=CONVERT(int,ROW_NUMBER() OVER
                    (ORDER BY COALESCE([StatementId],2147483647),COALESCE([StatementCompId],2147483647),COALESCE([StatementText],N'')))
                , [StatementXml]
            FROM [StatementsBase]
        )
        INSERT [#InternalCollectExecutionPlanMetadata_PredicateValues]
        (
              [StatementOrdinal],[NodeId],[DatabaseName],[SchemaName],[ObjectName]
            , [ColumnName],[PredicateKind],[ParameterName]
            , [CompiledValueRaw],[RuntimeValueRaw]
            , [CompiledValueNormalized],[RuntimeValueNormalized]
        )
        SELECT DISTINCT
              [st].[StatementOrdinal]
            , TRY_CONVERT(int,NULLIF([r].[n].value('string((@NodeId)[1])','nvarchar(50)'),N''))
            , [v].[DatabaseName],[v].[SchemaName],[v].[ObjectName],[v].[ColumnName]
            , NULLIF([c].[n].value('string((@CompareOp)[1])','nvarchar(40)'),N'')
            , NULLIF([p].[ParameterName],N'')
            , NULLIF([p].[CompiledValue],N'')
            , NULLIF([p].[RuntimeValue],N'')
            , [n].[CompiledNormalized]
            , [n].[RuntimeNormalized]
        FROM [Statements] AS [st]
        CROSS APPLY [st].[StatementXml].nodes('.//*[local-name(.)="RelOp"]') AS [r]([n])
        CROSS APPLY [r].[n].nodes('./*//*[local-name(.)="Compare"]') AS [c]([n])
        CROSS APPLY
        (
            VALUES
            (
                NULLIF([c].[n].value('string((.//*[local-name(.)="ColumnReference"][@Table and not(@ParameterCompiledValue) and not(@ParameterRuntimeValue)][1]/@Database)[1])','nvarchar(256)'),N''),
                NULLIF([c].[n].value('string((.//*[local-name(.)="ColumnReference"][@Table and not(@ParameterCompiledValue) and not(@ParameterRuntimeValue)][1]/@Schema)[1])','nvarchar(256)'),N''),
                NULLIF([c].[n].value('string((.//*[local-name(.)="ColumnReference"][@Table and not(@ParameterCompiledValue) and not(@ParameterRuntimeValue)][1]/@Table)[1])','nvarchar(256)'),N''),
                NULLIF([c].[n].value('string((.//*[local-name(.)="ColumnReference"][@Table and not(@ParameterCompiledValue) and not(@ParameterRuntimeValue)][1]/@Column)[1])','nvarchar(256)'),N'')
            )
        ) AS [cr]([DatabaseRaw],[SchemaRaw],[ObjectRaw],[ColumnRaw])
        CROSS APPLY
        (
            VALUES
            (
                CASE WHEN LEFT([cr].[DatabaseRaw],1)=N'[' AND RIGHT([cr].[DatabaseRaw],1)=N']' THEN REPLACE(SUBSTRING([cr].[DatabaseRaw],2,LEN([cr].[DatabaseRaw])-2),N']]',N']') ELSE [cr].[DatabaseRaw] END,
                CASE WHEN LEFT([cr].[SchemaRaw],1)=N'[' AND RIGHT([cr].[SchemaRaw],1)=N']' THEN REPLACE(SUBSTRING([cr].[SchemaRaw],2,LEN([cr].[SchemaRaw])-2),N']]',N']') ELSE [cr].[SchemaRaw] END,
                CASE WHEN LEFT([cr].[ObjectRaw],1)=N'[' AND RIGHT([cr].[ObjectRaw],1)=N']' THEN REPLACE(SUBSTRING([cr].[ObjectRaw],2,LEN([cr].[ObjectRaw])-2),N']]',N']') ELSE [cr].[ObjectRaw] END,
                CASE WHEN LEFT([cr].[ColumnRaw],1)=N'[' AND RIGHT([cr].[ColumnRaw],1)=N']' THEN REPLACE(SUBSTRING([cr].[ColumnRaw],2,LEN([cr].[ColumnRaw])-2),N']]',N']') ELSE [cr].[ColumnRaw] END
            )
        ) AS [v]([DatabaseName],[SchemaName],[ObjectName],[ColumnName])
        CROSS APPLY
        (
            VALUES
            (
                NULLIF([c].[n].value('string((.//*[local-name(.)="ColumnReference"][@ParameterCompiledValue or @ParameterRuntimeValue][1]/@Column)[1])','nvarchar(256)'),N''),
                NULLIF([c].[n].value('string((.//*[local-name(.)="ColumnReference"][@ParameterCompiledValue or @ParameterRuntimeValue][1]/@ParameterCompiledValue)[1])','nvarchar(4000)'),N''),
                NULLIF([c].[n].value('string((.//*[local-name(.)="ColumnReference"][@ParameterCompiledValue or @ParameterRuntimeValue][1]/@ParameterRuntimeValue)[1])','nvarchar(4000)'),N'')
            )
        ) AS [p]([ParameterName],[CompiledValue],[RuntimeValue])
        CROSS APPLY
        (
            VALUES
            (
                CASE
                    WHEN LEFT([p].[CompiledValue],1)=N'(' AND RIGHT([p].[CompiledValue],1)=N')' THEN SUBSTRING([p].[CompiledValue],2,LEN([p].[CompiledValue])-2)
                    WHEN LEFT([p].[CompiledValue],2)=N'N''' AND RIGHT([p].[CompiledValue],1)=N'''' THEN SUBSTRING([p].[CompiledValue],3,LEN([p].[CompiledValue])-3)
                    WHEN LEFT([p].[CompiledValue],1)=N'''' AND RIGHT([p].[CompiledValue],1)=N'''' THEN SUBSTRING([p].[CompiledValue],2,LEN([p].[CompiledValue])-2)
                    ELSE [p].[CompiledValue] END,
                CASE
                    WHEN LEFT([p].[RuntimeValue],1)=N'(' AND RIGHT([p].[RuntimeValue],1)=N')' THEN SUBSTRING([p].[RuntimeValue],2,LEN([p].[RuntimeValue])-2)
                    WHEN LEFT([p].[RuntimeValue],2)=N'N''' AND RIGHT([p].[RuntimeValue],1)=N'''' THEN SUBSTRING([p].[RuntimeValue],3,LEN([p].[RuntimeValue])-3)
                    WHEN LEFT([p].[RuntimeValue],1)=N'''' AND RIGHT([p].[RuntimeValue],1)=N'''' THEN SUBSTRING([p].[RuntimeValue],2,LEN([p].[RuntimeValue])-2)
                    ELSE [p].[RuntimeValue] END
            )
        ) AS [n]([CompiledNormalized],[RuntimeNormalized])
        WHERE [v].[DatabaseName] IS NOT NULL AND [v].[SchemaName] IS NOT NULL
          AND [v].[ObjectName] IS NOT NULL AND [v].[ColumnName] IS NOT NULL
          AND ([p].[CompiledValue] IS NOT NULL OR [p].[RuntimeValue] IS NOT NULL);

        ;WITH [ValuesToMap] AS
        (
            SELECT [PredicateReferenceId],[StatementOrdinal],[NodeId],[DatabaseName],[SchemaName],[ObjectName],[ColumnName],
                   [PredicateKind],CONVERT(varchar(32),'COMPILED_PARAMETER') [ValueSource],[CompiledValueNormalized] [ValueText]
            FROM [#InternalCollectExecutionPlanMetadata_PredicateValues] WHERE [CompiledValueNormalized] IS NOT NULL
            UNION ALL
            SELECT [PredicateReferenceId],[StatementOrdinal],[NodeId],[DatabaseName],[SchemaName],[ObjectName],[ColumnName],
                   [PredicateKind],'RUNTIME_PARAMETER',[RuntimeValueNormalized]
            FROM [#InternalCollectExecutionPlanMetadata_PredicateValues] WHERE [RuntimeValueNormalized] IS NOT NULL
        ),
        [Candidates] AS
        (
            SELECT
                  [v].*
                , [h].[StatisticsName],[h].[StepOrdinal],[h].[RangeHighKeyRaw]
                , [NumericValue]=TRY_CONVERT(decimal(38,10),[v].[ValueText])
                , [NumericBoundary]=TRY_CONVERT(decimal(38,10),[h].[RangeHighKeyRaw])
                , [DateValue]=TRY_CONVERT(datetime2(7),[v].[ValueText])
                , [DateBoundary]=TRY_CONVERT(datetime2(7),[h].[RangeHighKeyRaw])
                , [ExactMatch]=CONVERT(bit,CASE WHEN [v].[ValueText]=[h].[RangeHighKeyRaw] THEN 1 ELSE 0 END)
            FROM [ValuesToMap] AS [v]
            JOIN [#CreateExecutionEvidenceJson_HistogramSteps] AS [h]
              ON [h].[DatabaseName]=[v].[DatabaseName]
             AND [h].[SchemaName]=[v].[SchemaName]
             AND [h].[ObjectName]=[v].[ObjectName]
             AND [h].[LeadingColumnName]=[v].[ColumnName]
        ),
        [Ranked] AS
        (
            SELECT [c].*,
                   [CandidateRank]=ROW_NUMBER() OVER
                   (
                       PARTITION BY [PredicateReferenceId],[ValueSource],[StatisticsName]
                       ORDER BY CASE WHEN [ExactMatch]=1 THEN 0
                                     WHEN [NumericValue] IS NOT NULL AND [NumericBoundary]>=[NumericValue] THEN 1
                                     WHEN [DateValue] IS NOT NULL AND [DateBoundary]>=[DateValue] THEN 1
                                     ELSE 2 END,
                                [StepOrdinal]
                   ),
                   [MinimumNumericBoundary]=MIN([NumericBoundary]) OVER (PARTITION BY [PredicateReferenceId],[ValueSource],[StatisticsName]),
                   [MaximumNumericBoundary]=MAX([NumericBoundary]) OVER (PARTITION BY [PredicateReferenceId],[ValueSource],[StatisticsName]),
                   [MinimumDateBoundary]=MIN([DateBoundary]) OVER (PARTITION BY [PredicateReferenceId],[ValueSource],[StatisticsName]),
                   [MaximumDateBoundary]=MAX([DateBoundary]) OVER (PARTITION BY [PredicateReferenceId],[ValueSource],[StatisticsName])
            FROM [Candidates] AS [c]
        )
        INSERT [#CreateExecutionEvidenceJson_PredicateHistogramMappings]
        (
              [PredicateReferenceId],[StatementOrdinal],[NodeId]
            , [DatabaseName],[SchemaName],[ObjectName],[ColumnName]
            , [StatisticsName],[PredicateKind],[ValueSource]
            , [MappingStatus],[MappingConfidence],[MatchedStepOrdinal]
            , [MatchesRangeHighKey],[IsBelowHistogram],[IsAboveHistogram]
            , [SensitiveValueStatus]
        )
        SELECT
              [PredicateReferenceId],[StatementOrdinal],[NodeId]
            , [DatabaseName],[SchemaName],[ObjectName],[ColumnName]
            , [StatisticsName],[PredicateKind],[ValueSource]
            , CASE
                WHEN [ExactMatch]=1 THEN 'EXACT_RANGE_HIGH_KEY'
                WHEN [NumericValue] IS NOT NULL AND [NumericValue]<[MinimumNumericBoundary] THEN 'BELOW_HISTOGRAM_MINIMUM'
                WHEN [NumericValue] IS NOT NULL AND [NumericValue]>[MaximumNumericBoundary] THEN 'ABOVE_HISTOGRAM_MAXIMUM'
                WHEN [DateValue] IS NOT NULL AND [DateValue]<[MinimumDateBoundary] THEN 'BELOW_HISTOGRAM_MINIMUM'
                WHEN [DateValue] IS NOT NULL AND [DateValue]>[MaximumDateBoundary] THEN 'ABOVE_HISTOGRAM_MAXIMUM'
                WHEN ([NumericValue] IS NOT NULL AND [NumericBoundary]>=[NumericValue])
                  OR ([DateValue] IS NOT NULL AND [DateBoundary]>=[DateValue]) THEN 'WITHIN_HISTOGRAM_RANGE'
                ELSE 'NOT_MAPPABLE' END
            , CASE WHEN [ExactMatch]=1 THEN 'HIGH'
                   WHEN [NumericValue] IS NOT NULL OR [DateValue] IS NOT NULL THEN 'MEDIUM'
                   ELSE 'LOW' END
            , CASE WHEN [ExactMatch]=1
                     OR ([NumericValue] IS NOT NULL AND [NumericBoundary]>=[NumericValue])
                     OR ([DateValue] IS NOT NULL AND [DateBoundary]>=[DateValue])
                   THEN [StepOrdinal] END
            , [ExactMatch]
            , CONVERT(bit,CASE WHEN ([NumericValue] IS NOT NULL AND [NumericValue]<[MinimumNumericBoundary])
                                  OR ([DateValue] IS NOT NULL AND [DateValue]<[MinimumDateBoundary]) THEN 1 ELSE 0 END)
            , CONVERT(bit,CASE WHEN ([NumericValue] IS NOT NULL AND [NumericValue]>[MaximumNumericBoundary])
                                  OR ([DateValue] IS NOT NULL AND [DateValue]>[MaximumDateBoundary]) THEN 1 ELSE 0 END)
            , 'OMITTED_DERIVED_ONLY'
        FROM [Ranked]
        WHERE [CandidateRank]=1;
    END;

    INSERT [#CreateExecutionEvidenceJson_CollectionStatus]
    ([DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[StatusCode],[ErrorNumber],[ErrorMessage])
    SELECT [DatabaseName],[SchemaName],[ObjectName],[StatisticsName],[CollectionStatus],NULL,NULL
    FROM [#CreateExecutionEvidenceJson_StatisticsCurrent]
    WHERE NOT EXISTS
    (
        SELECT 1 FROM [#CreateExecutionEvidenceJson_CollectionStatus] AS [x]
        WHERE [x].[DatabaseName]=[#CreateExecutionEvidenceJson_StatisticsCurrent].[DatabaseName]
          AND [x].[SchemaName]=[#CreateExecutionEvidenceJson_StatisticsCurrent].[SchemaName]
          AND [x].[ObjectName]=[#CreateExecutionEvidenceJson_StatisticsCurrent].[ObjectName]
          AND [x].[StatisticsName]=[#CreateExecutionEvidenceJson_StatisticsCurrent].[StatisticsName]
    );

    IF @IsPartialOut=1 AND @StatusCodeOut='AVAILABLE' SET @StatusCodeOut='PARTIAL';
    END TRY
    BEGIN CATCH
        SELECT
              @StatusCodeOut=CASE WHEN ERROR_NUMBER()=1222 THEN 'LOCK_TIMEOUT' ELSE 'ERROR_HANDLED' END
            , @IsPartialOut=1
            , @ErrorNumberOut=ERROR_NUMBER()
            , @ErrorMessageOut=ERROR_MESSAGE();
    END CATCH;

    SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @LockTimeoutSql;
END;
GO
