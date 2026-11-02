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

Diese öffentliche Hilfsprocedure bereitet Filter einer Analyse-Procedure vor und liefert keine normalen Analyse-Resultsets. Im normalen Verarbeitungspfad erwartet sie eine vom Aufrufer angelegte lokale Temp-Tabelle mit dem vollständigen dokumentierten Schema. Die Procedure leert vorhandene Zeilen nicht, sondern hängt validierte Filter an. Der Hilfemodus kann ohne diese Tabelle aufgerufen werden, muss aber weiterhin Argumente für die Parameter ohne Default angeben. Für den Empfang der Rückgabewerte werden Variablen mit OUTPUT gebunden.

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

## Parametervertrag

Im normalen Verarbeitungspfad bei gültiger Zieltabelle erzeugt ein NULL-Listenwert keine Filterzeilen; leere Zeichenfolgen und ausschließlich aus Leerzeichen bestehende Listen sind dagegen ungültig und führen zu INVALID_PARAMETER. Die Zieltabellenprobe erfolgt vor der Exklusivitäts- und Listenprüfung. @FullObjectNames ist schon anhand von IS NOT NULL mit @SchemaNames und @ObjectNames exklusiv, auch wenn ein übergebener Wert leer ist. Bei @Hilfe=1 werden die Listen nicht verarbeitet. Ein Fehler vor dem abschließenden Insert lässt vorhandene Zielzeilen bestehen; ein leerer Listenwert darf daher nicht als Freigabe für eine ungefilterte Analyse interpretiert werden.

Die folgenden Verträge beschreiben jeden Parameter einzeln. Diese Rolle arbeitet mit typisierten Aufrufer-Tabellen und OUTPUT-Parametern; sie besitzt keine gemeinsame ResultSetArt- oder JSON-Ausgabe. Bei `@Hilfe = 1` wird vor dem normalen Vorbereitungspfad zurückgekehrt.

| Parameter | Typ, Default, Eingabeform und Wirkung |
|---|---|
| `@SchemaNames` | Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: &#124; trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType SCHEMA in NameValue abgelegt. |
| `@ObjectNames` | Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: &#124; trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType OBJECT in NameValue abgelegt. |
| `@FullObjectNames` | nvarchar(max), Default NULL. TVF_ParseFullObjectNameList: &#124; trennt außerhalb [...], ]] maskiert ] darin; äußere Elementleerzeichen entfernt; Rohsegmente max. 4000 UTF-16-Codeeinheiten. Formen Objekt, Schema.Objekt, Datenbank.Schema.Objekt; bei 3 Teilen Schema erforderlich, 4 Teile ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Überlange PARSENAME-Bestandteile können NULL ergeben, Fehlercode nicht zugesichert. Case-sensitive Duplikate FULL_OBJECT ungültig. Keine vollständige Syntax-/Existenz-/Rechteprüfung. Exklusiv mit angegebener Schema- oder Objektliste. Gültige Teile werden in DatabaseName/SchemaName/ObjectName gespeichert. |
| `@IndexNames` | Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: &#124; trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType INDEX in NameValue abgelegt. |
| `@StatisticsNames` | Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: &#124; trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType STATISTICS in NameValue abgelegt. |
| `@ColumnNames` | Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: &#124; trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType COLUMN in NameValue abgelegt. |
| `@StatusCode` | Datentyp varchar(40); OUTPUT, ohne Default. Ein Argument ist auch bei @Hilfe=1 erforderlich, da kein Default existiert. Für den Empfang eine Aufrufervariable vom Typ varchar(40) mit OUTPUT binden, zum Beispiel @StatusCode=@CallerStatusCode OUTPUT. Ohne OUTPUT am Aufruf wird der Rückgabewert nicht empfangen. AVAILABLE bedeutet, dass die Listenprüfung erfolgreich war und gültige Zeilen angehängt wurden; bei sechs nicht angegebenen Listen bedeutet es erfolgreich keine neuen Zeilen. INVALID_PARAMETER kennzeichnet ungültige Listenstruktur/-namen, Exklusivitätsverletzung, case-sensitive Duplikate oder ungültigen Temp-Tabellennamen. INTERNAL_ERROR kennzeichnet eine fehlende oder nicht passende Filter-Temp-Tabelle bei der Schema-Prüfung. TIMEOUT wird bei SQL-Fehler 1222 gesetzt. DENIED_PERMISSION wird bei den abgefangenen Berechtigungsfehlernummern 229, 262, 297, 300, 371 oder 916 gesetzt. ERROR_HANDLED kennzeichnet einen anderen im Listen-/Vorbereitungspfad abgefangenen SQL-Fehler; dessen SQL-Fehlertext wird in @ErrorMessage ausgegeben. Bei @Hilfe=1 bleibt die Aufrufervariable unverändert. |
| `@ErrorMessage` | Datentyp nvarchar(2048); OUTPUT, ohne Default. Ein Argument ist auch bei @Hilfe=1 erforderlich, da kein Default existiert. Für den Empfang eine Aufrufervariable vom Typ nvarchar(2048) mit OUTPUT binden, zum Beispiel @ErrorMessage=@CallerErrorMessage OUTPUT. Ohne OUTPUT am Aufruf wird der Rückgabewert nicht empfangen. Bei erfolgreicher Vorbereitung ist der Wert NULL; andernfalls empfängt er die Fehlerbeschreibung beziehungsweise im abgefangenen SQL-Fehlerpfad ERROR_MESSAGE(). Bei @Hilfe=1 bleibt er unverändert. |
| `@FilterTable` | sysname, Default #PrepareNameFilters_Result. Vorhandene lokale # Tabelle derselben Session, kein ##, max. 116 Zeichen; NULL/falscher Präfix/Überlänge ungültig. Spalten FilterType varchar(20) NOT NULL, ItemOrdinal int NOT NULL, NameValue sysname NULL, DatabaseName sysname NULL, SchemaName sysname NULL, ObjectName sysname NULL; Textcollation SQL_Latin1_General_CP1_CS_AS. Wird nicht geleert; gültige Worktable-Zeilen angehängt. Fehler vor Insert lässt Altzeilen; abschließender Insertfehler nicht umfassend abgefangen. |
| `@Hilfe` | bit, Default 0. 0 verarbeitet; 1 druckt Hilfe und kehrt vor OUTPUT-Initialisierung/Zieltabellenverarbeitung zurück; NULL normaler Pfad. Ausgelassen =0; numerisch ungleich 0 wird bit-konvertiert zu 1. Für beide OUTPUT-Parameter sind auch bei Hilfe Argumente anzugeben. Für den Empfang Variable mit OUTPUT binden; im Hilfepfad bleiben die übergebenen Eingangswerte unverändert. |

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
