# [monitor].[USP_PrepareNameFilters]

**Bereich:** Common, öffentlicher Filtervorbereitungshelfer<br>
**Zweck:** Validiert und zerlegt case-sensitive, bracket-aware Namensfilter.<br>
**Beobachtungsart:** Aufrufbezogene Validierung<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Wurde eine Namenliste syntaktisch eindeutig und unter der case-sensitiven Frameworksemantik aufbereitet?** Sie unterstützt die Entscheidung, ob der gewünschte Analysepfad sicher und eindeutig vorbereitet ist oder der Fachaufruf wegen eines ungültigen Scope unterbleiben muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Performance- oder Verfügbarkeitsursache und keine Aussage über Daten außerhalb des aktuellen Execution-Kontexts. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

Diese öffentliche Hilfsprocedure bereitet Filter einer Analyse-Procedure vor und liefert keine normalen Analyse-Resultsets. Im normalen Verarbeitungspfad erwartet sie eine vom Aufrufer angelegte lokale Temp-Tabelle mit dem vollständigen dokumentierten Schema. Die Procedure leert vorhandene Zeilen nicht, sondern hängt validierte Filter an. Der Hilfemodus kann ohne diese Tabelle aufgerufen werden, muss aber weiterhin die erforderlichen OUTPUT-Parameter binden.

Alle `Example*`-Werte im Aufruf sind synthetisch.

### Hilfe anzeigen

Der Hilfemodus gibt Parameter, Listenregeln, Exklusivität und Zielschema aus, bevor er Temp-Tabellen oder Listen verarbeitet. Die erforderlichen OUTPUT-Parameter bleiben auch bei `@Hilfe=1` Teil der SQL-Signatur:

```sql
DECLARE @StatusCode varchar(40),
        @ErrorMessage nvarchar(2048);

EXEC [monitor].[USP_PrepareNameFilters]
      @StatusCode = @StatusCode OUTPUT
    , @ErrorMessage = @ErrorMessage OUTPUT
    , @Hilfe = 1;
```

Listen trennen Elemente mit | nur außerhalb geklammerter Bezeichner; ]] maskiert darin eine schließende Klammer. Für Einzelnamen verlangt der Parser einen Wert aus PARSENAME(ItemText,1) und NULL aus PARSENAME(ItemText,2); Teile 3 und 4 werden nicht gesondert geprüft. Für vollständige Bezüge zerlegt PARSENAME die Bestandteile, verlangt einen Objektteil und bei vorhandenem Teil 3 auch einen Schemanamen; Teil 4 wird abgelehnt. Bei überlangen Bestandteilen ist kein bestimmter Fehlercode zugesichert. Diese strukturellen Prüfungen sind keine vollständige SQL-Bezeichnergrammatik und belegen weder Katalogexistenz noch Berechtigungen. Doppelte Werte innerhalb desselben Filtertyps sind unter SQL_Latin1_General_CP1_CS_AS ungültig.


### Normalen Aufruf prüfen

Das Beispiel legt eine frische Tabelle mit allen sechs Spalten an. Die Namen sind synthetisch; der Helper prüft keine Katalogexistenz.

~~~sql
CREATE TABLE #PrepareNameFilters_HelpExample (
    FilterType varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    ItemOrdinal int NOT NULL,
    NameValue sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    SchemaName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    ObjectName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
DECLARE @StatusCode varchar(40), @ErrorMessage nvarchar(2048);
EXEC [monitor].[USP_PrepareNameFilters]
     @SchemaNames=N'[ExampleSchema]',
     @ObjectNames=N'[ExampleObject]',
     @StatusCode=@StatusCode OUTPUT,
     @ErrorMessage=@ErrorMessage OUTPUT,
     @FilterTable=N'#PrepareNameFilters_HelpExample';
SELECT @StatusCode AS StatusCode, @ErrorMessage AS ErrorMessage;
SELECT * FROM #PrepareNameFilters_HelpExample
ORDER BY FilterType, ItemOrdinal;
DROP TABLE #PrepareNameFilters_HelpExample;
~~~

## Resultsets und Leserichtung

Diese Hilfsprocedure besitzt bewusst keinen öffentlichen TABLE-Export. Sie befüllt die vom Parent bereitgestellten Temp-Strukturen beziehungsweise OUTPUT-Statuswerte. Zuerst sind Status und Warnungen des Parents zu lesen; erst danach darf dessen Fachresultset interpretiert werden. Ein direkter Aufruf ohne den dokumentierten Tabellenvertrag ist kein Ersatz für den Parentpfad.

## Eine Zeile bedeutet

Bei einer frisch angelegten Tabelle entspricht jede eingefügte Zeile einem normalisierten Filterelement, etwa Schema, Objekt, Index, Statistik oder vollständigem Objektbezug. Wiederverwendete Tabellen können frühere Zeilen enthalten.

## So lesen

Prüfen Sie Filtertyp, Status und die tatsächliche Zeilenzahl. Fehler vor dem abschließenden Insert lassen vorhandene Zeilen unverändert; sie werden nicht geleert. Der abschließende Insert ist nicht umfassend abgefangen.

## Warum kann das problematisch sein?

Bei `INVALID_PARAMETER` darf der Parent die vorhandene Tabelle nicht als gültigen Filter behandeln. Der Helper leert das Ziel nicht; vorhandene Zeilen bleiben erhalten.

## Wann ist es kein Problem?

Unter der case-sensitiven Projektcollation sind `ExampleTable` und `exampletable` unterschiedliche Namen.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Doppelte identische Namen führen absichtlich zu einem Fehler; Namen, die sich nur in der Groß- und Kleinschreibung unterscheiden, führen nicht dazu. Korrigieren Sie die Eingabe und wiederholen Sie den öffentlichen Aufruf.

**Ähnlich aussehender Gegenfall:** Unter der case-sensitiven Projektcollation sind `ExampleTable` und `exampletable` unterschiedliche Namen. 

## Leere oder partielle Ausgabe

Bei frisch angelegter Tabelle fügt ein erfolgreicher Aufruf mit sechs NULL-Listen keine Zeilen hinzu und liefert AVAILABLE. Ungültige Listen oder ein Exklusivitätsfehler setzen einen Fehlerstatus und lassen das Ziel unverändert. Wiederverwendete Tabellen können daher trotz eines Fehlers Zeilen aus einem früheren Aufruf enthalten. Der abschließende Insert ist nicht umfassend abgefangen; ein dortiger SQL-Fehler kann entkommen. Status, ErrorMessage und Zielinhalt sind gemeinsam zu prüfen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Parst bis zu sechs übergebene Pipe-Listen über die Framework-TVFs, validiert Exklusivität/Duplikate und hängt gültige Zeilen an eine bereits vom Aufrufer angelegte lokale Temp-Tabelle. Ohne Listen fügt der erfolgreiche Aufruf keine neuen Zeilen hinzu; vorhandene Zeilen bleiben erhalten. |
| Teuerster Pfad | Sehr lange Listen mit vielen bracket-aware Elementen in allen sechs Parametern; `@FullObjectNames` benötigt zusätzlich die Zerlegung in Datenbank, Schema und Objekt. Ungültige oder doppelte Werte werden erst nach der Parserarbeit erkannt. |
| Haupttreiber | Zeichenlänge und Elementzahl von Schema-, Objekt-, Full-Object-, Index-, Statistik- und Spaltenlisten. Es gibt keine Datenbankkandidaten-, Capability-, Login-Token- oder Fachquellenabfrage. |
| Skalierung | Parser- und UNION-ALL-Arbeit wächst linear mit den Elementen; die case-sensitive Duplikatprüfung gruppiert die materialisierte Worktable und kann bei sehr großen Listen zusätzliche TempDB-CPU benötigen. |
| Ressourcen | CPU für String-/Identifierparser, eine lokale Worktable und dynamisches SQL für Schema-Prüfung/Insert der vom Parent benannten lokalen Temp-Tabelle. Kein Katalog- oder Nutzdatenscan. |
| Begrenzungswirkung | Es existiert kein Zeilenlimit: Jedes übergebene Element wird nach den dokumentierten Parserregeln geprüft. Begrenzen lässt sich die Arbeit nur durch kleine Eingabelisten; `@FilterTable` ist auf einen lokalen `#`-Namen mit maximal 116 Zeichen beschränkt. |
| Locking und Nebenwirkungen | Schreibt ausschließlich in lokale Temp-Tabellen der aufrufenden Session. Keine fachliche Datenänderung und kein Security-Token-Lesen; dynamisches SQL prüft nur die erwarteten Spalten der Zieltabelle und fügt validierte Werte ein. |
| Schutzmechanismus | Kein Analyse-Gate, weil dies ein interner Parser ist. Er akzeptiert nur lokale `#`-Temp-Tabellennamen bis 116 Zeichen, prüft die erwarteten Zielspalten, erzwingt die Exklusivität vollständiger versus getrennter Objektnamen und lehnt Fehler der Listenstruktur, der dokumentierten PARSENAME-Prüfungen sowie case-sensitiv doppelte Werte ab; ein Mengenbudget müssen die aufrufenden Module setzen. |
| Sicherer Einsatz | Nur nach Anlegen der dokumentierten lokalen Zieltabelle und zunächst mit einer kleinen `ExampleSchema`-/`ExampleObject`-Liste aufrufen. `INVALID_PARAMETER` muss den Parent stoppen und darf nie in ungefilterte Analyse umgedeutet werden. |
| Aussagegrenze | Die Procedure bestätigt die dokumentierten PARSENAME-Strukturprüfungen, Exklusivität und case-sensitive Eindeutigkeit. Sie prüft nicht, ob Datenbank, Schema, Objekt, Index, Statistik oder Spalte tatsächlich existieren oder für den Aufrufer sichtbar sind. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wurde eine Namenliste syntaktisch eindeutig und unter der case-sensitiven Frameworksemantik aufbereitet?

### Technischer Hintergrund

Die Procedure bereitet Listenfilter auf. Die Listenparser prüfen Klammer-/Pipe-Struktur und PARSENAME-Ergebnisse. Validierte Werte werden in eine lokale Worktable geschrieben und nach erfolgreicher Prüfung an das Aufruferziel angehängt. Bei ungültigen Eingaben bleibt das Ziel unverändert; Status und ErrorMessage kennzeichnen den Fehler. Die vollständigen Statuswerte sind AVAILABLE, INVALID_PARAMETER, INTERNAL_ERROR, TIMEOUT, DENIED_PERMISSION und ERROR_HANDLED.

### Datenkette

Die Datenkette besteht aus frameworkinterner Orchestrierung und Filterlogik; die Procedure besitzt keine eigenständige Systemquelle.

### Source Select

Keine Systemquelle: Die Procedure normalisiert vom Aufrufer gelieferte Namenslisten über die Framework-TVFs. Der direkte Parserzugriff lautet:

```sql
SELECT
      [f].[ItemOrdinal]
    , [f].[DatabaseName]
    , [f].[SchemaName]
    , [f].[ObjectName]
    , [f].[IsValid]
FROM [monitor].[TVF_ParseFullObjectNameList]
     (@FullObjectNames) AS [f];
```

**Wichtig für die Eigenlast:** Der Aufwand wächst mit Zeichenlänge und Elementzahl der übergebenen Listen. Die Vorbereitung stellt exakte Namen vor nachfolgenden Katalog- oder DMF-Pfaden bereit. Pattern- und Regexfilter sind ein anderer Vertrag und ersetzen diese frühe Zielauflösung nicht.

### Zeit- und Scope-Modell

Die Filter gelten nur für den aktuellen Aufruf und werden nicht persistiert.

### Bewertung und Gegenprobe

Behandeln Sie Case-Sensitivität, Duplikate, leere Elemente und ungültige Quote-/Bracketstruktur explizit. Ein erfolgreicher Aufruf mit ausschließlich NULL-Listen fügt keine Zeilen hinzu. Ein Fehler vor dem Insert lässt vorhandene Zeilen unverändert; unterscheiden Sie diese Fälle anhand von Status und Tabelleninhalt.

### Typische Fehlinterpretation

Eine leere Filtertabelle nach `INVALID_PARAMETER` darf nie als Freigabe für eine ungefilterte breite Analyse dienen.

### Folgeanalyse

Korrigieren Sie die Eingabe und starten Sie das aufrufende Fachmodul erneut.

## Primärquellen

- [QUOTENAME](https://learn.microsoft.com/en-us/sql/t-sql/functions/quotename-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../01_Common.md#5-monitorusp_preparenamefilters)
