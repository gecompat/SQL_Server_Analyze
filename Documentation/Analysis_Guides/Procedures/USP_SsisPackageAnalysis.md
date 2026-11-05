# [monitor].[USP_SsisPackageAnalysis]

**Bereich:** Integration<br>
**Zweck:** Inventarisiert Paket, Executables mit direkten Parent-Containern, direkte Precedence Constraints, Paket-Connection-Manager, Paketparameter, Variablendefinitionen, Pipeline-Komponenten und direkte Property-Expressions eines direkt übergebenen DTSX-v2-Dokuments.<br>
**Beobachtungsart:** Statische XML-Analyse<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet, ob ein direkt übergebenes DTSX-v2-Dokument als Paket erkannt wird, welche Executables es enthält und welchem direkten Container sie zugeordnet sind. Sie ist für eine statische Vorprüfung bestimmt und bewertet keine Paketausführung, keine Datenbewegung und keine externe Verbindung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_SsisPackageAnalysis]
      @PackageXml = @PackageXml
    , @ResultSetArt = 'CONSOLE';
```

Der Aufruf akzeptiert ausschließlich `@AnalysisDepth = 'STANDARD'`. `@ResolveSqlMetadata` und `@CheckLookupData` bleiben in diesem Slice `0`; dadurch öffnet die Procedure keine Datenbank-, Lookup-, Datei-, ISPAC- oder SSISDB-Quelle.

## Parameter und Eingabeformen

Die Beschreibung folgt dem aktuellen direkten XML-Einstieg. Reservierte Argumente aktivieren keine zukünftige Funktion. Alle Zahlen und Schalter werden skalar übergeben; Zeichenfolgen sind T-SQL-Literale oder passend typisierte Variablen. Ausgelassene Argumente verwenden den jeweils genannten Default. Die Hilfe läuft vor Mapping- und Quellenprüfung; sie setzt @Json auf NULL, erhält aber die vier Status-/Fehler-OUTPUTs. Fehler vor deren regulärer Zuweisung können ebenfalls den Eingangswert erhalten.

### @PackageXml

**Datentyp:** `xml`. Direkt übergebenes SQL-xml-Instanz; Default: NULL. Erforderlich für eine Analyse; NULL wird als ungültiger Parameter bewertet. Geprüft werden ein Executable-Wurzelelement im Namespace www.microsoft.com/SqlServer/Dts sowie ein nichtleerer ExecutableType passend zu %Package%; andere Formen ergeben UNSUPPORTED_PACKAGE_FORMAT. Eine vollständige DTSX-Schemavalidierung wird damit nicht behauptet. Es wird ausschließlich dieser Wert untersucht; die Procedure öffnet keine Datei, ISPAC-, SSISDB-, Datenbank- oder externe Verbindungsquelle. Für @Hilfe = 1 wird das Argument vor der Quellenprüfung nicht verwendet.

### @PackageParametersJson

**Datentyp:** `nvarchar(max)`. Unverwendetes Eingabeargument; Default: NULL. Die Procedure liest diesen Wert nicht, validiert weder JSON-Syntax noch Inhalt und wendet keine Paketparameter auf das XML an. NULL, Leertext, syntaktisch ungültiges JSON und sonstige Inhalte haben für den Parserpfad keine Wirkung. Paketparameter im XML werden nur als Metadaten inventarisiert; Werte werden nicht ausgegeben.

### @AnalysisDepth

**Datentyp:** `varchar(16)`. Analyseumfang; Default: STANDARD. Zulässige Form ist nach Trim und Umwandlung in Großbuchstaben ausschließlich STANDARD. Damit wird der implementierte statische Parser-Slice angefordert. NULL und jeder andere Wert sind ungültig; ein Leerwert ist ebenfalls ungültig.

### @ResolveSqlMetadata

**Datentyp:** `bit`. Reservierter Schalter für SQL-Metadatenauflösung; Default: 0. Nur 0 ist zulässig. NULL und 1 werden als ungültige Parameter bewertet. Eine Metadatenauflösung ist in diesem Parser-Slice nicht implementiert; der Schalter aktiviert keine solche Funktion. SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @CheckLookupData

**Datentyp:** `bit`. Reservierter Schalter für Lookup-Datenprüfungen; Default: 0. Nur 0 ist zulässig. NULL und 1 werden als ungültige Parameter bewertet. Lookup-Daten werden in diesem Parser-Slice nicht gelesen; der Schalter aktiviert keine Prüfung. SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @HighImpactConfirmed

**Datentyp:** `bit`. Bestätigungsschalter; Default: 0. Beide Bitwerte 0 und 1 werden angenommen; NULL wird als ungültiger Parameter bewertet. Der Wert wird nicht zur Freigabe oder Erweiterung einer Analyse verwendet und ändert den Parserumfang nicht. SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @MaxZeilen

**Datentyp:** `int`. Zeilengrenze; Default: 1000. Zulässig sind NULL, 0 oder positive Ganzzahlen von 1 bis 2147483647; negative Werte sind ungültig. NULL und 0 bedeuten unbegrenzt. Bei RAW begrenzt der Wert acht Detailgruppen (Executables, Constraints, Data-Flow-Komponenten, Connections, Parameter, Expressions, Lineage und Variablen); Modulstatus, Paket, Findings, Quellenstatus und Warnungen werden davon nicht begrenzt. Das interne Inventar wird nicht vorab auf diese Grenze beschränkt. Für TABLE und JSON begrenzt @MaxZeilen nur das Variableninventar; die übrigen Arrays/Zieltabellen werden nicht durch diesen Parameter gekürzt.

### @MaxDurationSeconds

**Datentyp:** `int`. Vorgesehene Dauergrenze in Sekunden; Default: 30. Der Code prüft Werte außerhalb 1 bis 60 als ungültig. NULL wird durch den NOT BETWEEN-Ausdruck jedoch nicht als ungültig erkannt und passiert diese Prüfung, wenn keine andere Bedingung fehlschlägt. Der Parameter wird danach nicht für eine Frist, Abbruch- oder Laufzeitbegrenzung verwendet; die geprüften Zahlen erzeugen daher kein tatsächliches Laufzeitlimit.

### @LockTimeoutMs

**Datentyp:** `int`. SQL-Sperrwartezeit in Millisekunden; Default: 0. 0 verlangt NOWAIT; 1 bis 60000 geben eine endliche Wartezeit vor. Der Code markiert Zahlen außerhalb 0 bis 60000 als INVALID_PARAMETER, führt die dynamische SET-Anweisung aber anschließend trotzdem aus; nicht verwendbare SET-Werte können daher als ungefangener SQL-Fehler enden. NULL passiert die NOT BETWEEN-Prüfung; die verkettete SET-Anweisung wird NULL. Für NULL ist keine ausdrückliche Steuerregel implementiert; verwenden Sie einen expliziten Wert 0 bis 60000. Am regulären Ende versucht der Code, den vorher gelesenen LOCK_TIMEOUT wiederherzustellen; frühe Fehler sind davon nicht abgedeckt.

### @ResultSetArt

**Datentyp:** `varchar(16)`. Ausgabeform; Default: CONSOLE. Der Wert wird getrimmt und in Großbuchstaben umgewandelt. Zulässige Werte: CONSOLE gibt die Zusammenfassung über InternalEmitConsoleResult aus; RAW gibt die dreizehn Resultsets in dokumentierter Reihenfolge aus; TABLE schreibt angeforderte Gruppen in benannte lokale #Temp-Ziele; NONE gibt keine fachlichen Resultsets dieser drei Formen aus. NULL, Leerwert und andere Werte sind ungültig. TABLE erfordert eine gültige, nichtleere Zuordnung in @ResultTablesJson. Außerhalb von TABLE muss @ResultTablesJson NULL oder leer oder nur aus U+0020-Leerzeichen bestehend sein. JSON ist keine zulässige Ausgabeart; JSON wird separat mit @JsonErzeugen angefordert.

### @ResultTablesJson

**Datentyp:** `nvarchar(max)`. JSON-Zuordnung für TABLE-Ausgabe; Default: NULL. Nur bei @ResultSetArt = TABLE wird die Eingabe als nichtleeres JSON-Objekt ausgewertet. Zulässige Schlüssel sind exakt (groß-/kleinschreibungssensitiv): moduleStatus = Zusammenfassungsstatus; package = Paketmetadaten; executables = Executable-Inventar; controlFlowConstraints = direkte Kontrollflusskanten; dataFlowComponents = Pipeline-Komponenten; connections = Connection-Manager-Metadaten; parameters = Paketparameter-Metadaten; expressions = direkte Property-Expressions; lineage = direkte Pipeline-Verbindungen; findings = Befunde; sourceStatus = Quellenstatus; warnings = Hinweise; variables = Variablendefinitionen. Jeder Wert muss ein nichtleerer Tabellenname als JSON-String sein. Jede Zuordnung muss auf eine bereits angelegte, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte zeigen; ##-Tabellen, Namen über 116 Zeichen und #Monitor*-Ziele sind unzulässig. Eine nichtleere Teilmenge der 13 Gruppen ist zulässig; nicht zugeordnete Gruppen werden nicht geschrieben. Beispiel: N'{"moduleStatus":"#SsisModuleStatus"}'. Resultsetnamen dürfen nicht doppelt vorkommen; doppelte Zielnamen und das reservierte Präfix #Monitor werden ohne Beachtung der Großschreibung geprüft; unbekannte Schlüssel werden abgelehnt. Die Zuordnung wird vor dem fachlichen XML-Parsing vollständig geprüft. Bei TABLE führen NULL, ungültiges JSON, ein leeres Objekt oder fehlende/unzulässige Ziele zum Fehler. Bei anderen Ausgabeformen wird ein nichtleerer Wert als ungültige Kombination abgewiesen; NULL und Leer-/U+0020-Leerzeichen-Text werden ignoriert.

### @JsonErzeugen

**Datentyp:** `bit`. Steuert die Ausgabe über @Json; Default: 0. 0 erzeugt kein JSON; 1 weist das erzeugte JSON @Json zu. NULL ist ungültig. Das JSON-Wurzelobjekt enthält 13 Arrays mit den Schlüsseln moduleStatus, package, executables, controlFlowConstraints, dataFlowComponents, connections, parameters, expressions, lineage, findings, sourceStatus, warnings und variables; ein zusätzliches meta-Objekt ist nicht implementiert. Nur variables wird mit INCLUDE_NULL_VALUES serialisiert. Das JSON wird unabhängig von @ResultSetArt erzeugt, sofern der reguläre Analysepfad erreicht wird. SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @Json

**Datentyp:** `nvarchar(max) OUTPUT`. OUTPUT-Parameter für das JSON-Dokument; Default: NULL OUTPUT. Beim Eintritt wird @Json stets auf NULL initialisiert. Bei @JsonErzeugen = 1 wird es im regulären Pfad an das JSON-Wurzelobjekt gebunden; andernfalls bleibt es NULL. Im Hilfezweig bleibt es NULL. Der Aufrufer muss die Ausgabe wie im Beispiel mit @Json = @Variable OUTPUT binden.

### @PrintMeldungen

**Datentyp:** `bit`. Historischer Meldungsschalter; Default: 1. Die implementierte Validierung akzeptiert 0 und 1; NULL wird als ungültig bewertet. Der Wert wird nach der NULL-Prüfung nicht weiter ausgewertet und steuert die CONSOLE-Ausgabe oder PRINT-Meldungen nicht. Die CONSOLE-Ausgabe richtet sich nach @ResultSetArt. SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @Hilfe

**Datentyp:** `bit`. Gibt die eingebaute Hilfe aus; Default: 0. Nur der Wert 1 löst die Hilfe aus: die Procedure druckt feste Hilfetexte und kehrt vor Mappingprüfung, XML-Validierung und Analyse zurück; eine Paketquelle ist dafür nicht erforderlich. Der Hilfezweig prüft diesen Parameter nicht auf NULL; NULL verhält sich daher wie kein Hilfeaufruf und führt in den regulären Pfad. SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab. 0 führt regulär fort. Die Hilfe setzt nur @Json=NULL; die vier Status-/Fehler-OUTPUTs bleiben unverändert, unabhängig von @PrintMeldungen.

### @StatusCodeOut

**Datentyp:** `varchar(40) OUTPUT`. varchar(40)-Variable mit OUTPUT am Aufruf binden; Default: NULL OUTPUT. Bei regulärer Zuweisung sind die im Code gesetzten Statuswerte AVAILABLE_LIMITED (implementiertes begrenztes Inventar), INVALID_PARAMETER (erkannte ungültige Argumente) und UNSUPPORTED_PACKAGE_FORMAT (nicht unterstützte XML-/Paketwurzel) möglich. Dies ist kein Eingabeauswahlcode; der Eingangswert wird erst bei regulärem Abschluss überschrieben. Bei Hilfe oder einem vorher entkommenden Fehler bleibt er unverändert.

### @IsPartialOut

**Datentyp:** `bit OUTPUT`. bit-Variable mit OUTPUT am Aufruf binden; Default: NULL OUTPUT. Bei regulärem Abschluss wird im aktuellen begrenzten Parser-Slice stets 1 zugewiesen; 0 wird von diesem Implementierungsstand nicht erzeugt. Ein vorgebundener 0-, 1- oder NULL-Wert hat keine Steuerwirkung. Bei Hilfe oder einem Fehler vor der Zuweisung bleibt er unverändert.

### @ErrorNumberOut

**Datentyp:** `int OUTPUT`. int-Variable mit OUTPUT am Aufruf binden; Default: NULL OUTPUT. Der aktuelle reguläre Pfad weist NULL zu; erkannte Parameter-/Formatfehler liefern einen Status und Meldungstext, aber keine interne Fehlernummer. Ein entkommender SQL-Fehler wird hier nicht allgemein abgefangen. Eingangswerte sind keine Steuerung und bleiben bei Hilfe beziehungsweise vorzeitiger Ausnahme unverändert.

### @ErrorMessageOut

**Datentyp:** `nvarchar(2048) OUTPUT`. nvarchar(2048)-Variable mit OUTPUT am Aufruf binden; Default: NULL OUTPUT. Kapazität: 2048 UTF-16-Codeeinheiten. Bei regulärem Abschluss enthält sie den Parameter-/Formatfehlertext oder NULL; sie ist kein Eingabefilter. Bei Hilfe oder einem Fehler vor der abschließenden Zuweisung bleibt ein vorgebundener Wert unverändert.

## Hilfe ohne Quellenzugriff

Die folgenden vier Aufrufe drucken ausschließlich Hilfe; keiner analysiert ein Paket oder öffnet eine externe Quelle.

```sql
EXEC [monitor].[USP_SsisPackageAnalysis] @Hilfe = 1;
EXEC [monitor].[USP_SsisPackageAnalysis] @Hilfe = 1, @PrintMeldungen = 0;
EXEC [monitor].[USP_SsisPackageAnalysis] @Hilfe = 1, @ResultSetArt = 'RAW';
DECLARE @Json nvarchar(max); EXEC [monitor].[USP_SsisPackageAnalysis] @Hilfe = 1, @JsonErzeugen = 1, @Json = @Json OUTPUT; SELECT @Json AS [Json];
```

## Resultsets und Leserichtung

Die RAW-Resultsetfolge lautet `moduleStatus`, `package`, `executables`, `controlFlowConstraints`, `dataFlowComponents`, `connections`, `parameters`, `expressions`, `lineage`, `findings`, `sourceStatus`, `warnings` und `variables`. Der erste Slice füllt Paket, Executables einschließlich ihres direkten Parent-Containers, direkte Precedence Constraints, Paket-Connection-Manager, Paketparameter, Variablendefinitionen, Pipeline-Komponenten, direkte Property-Expressions und direkte Pipeline-Komponentenlinien. `AVAILABLE_LIMITED` kennzeichnet den begrenzten Implementierungsumfang; ein leeres Gruppenarray bestätigt keine vollständige Analyse des zugehörigen SSIS-Fachbereichs. `CONSOLE` rendert die zusammenfassende Modulzeile; `TABLE` verwendet benannte Ziele aus `@ResultTablesJson`; JSON enthält ein Wurzelobjekt mit den 13 Gruppenarrays, ohne separates meta-Objekt. Nur variables übernimmt NULL-Felder; die anderen Arrays verwenden die übliche FOR-JSON-Auslassung von NULL-Feldern.

Lesen Sie zuerst `moduleStatus` und `sourceStatus`. `UNSUPPORTED_PACKAGE_FORMAT` bedeutet, dass das Dokument nicht als unterstütztes DTSX-v2-Paket erkannt wurde; daraus folgt keine Aussage über die Gültigkeit anderer XML- oder Paketformate.

## Eine Zeile bedeutet

Eine Zeile in `package` beschreibt das erkannte Wurzelpaket. Eine Zeile in `executables` beschreibt ein in der XML-Struktur vorhandenes Executable. `ParentExecutableName` bezeichnet ausschließlich dessen direkten XML-Container; die Zeile enthält keine Laufzeit- oder Erfolgsinformation. Eine Zeile in `controlFlowConstraints` beschreibt eine direkte statische Kante innerhalb eines Parent-Executables. `EvaluationOperation`, `OutcomeValue` und `LogicalAnd` bilden DTSX-Attribute ab; `HasExpression` zeigt nur das Vorhandensein eines Ausdrucks. Der Ausdruckstext wird nicht ausgegeben. Kann ein Endpunkt nicht einem sichtbaren Executable zugeordnet werden, lautet `SourceStatus` `PARTIAL_LINEAGE`. Eine Zeile in `dataFlowComponents` beschreibt Name und Klassenkennung einer Pipeline-Komponente. Eigenschaften, Ein- und Ausgänge, Spaltenmetadaten sowie Werte werden nicht gelesen oder ausgegeben. Eine Zeile in `expressions` beschreibt Scope und Eigenschaftsname einer direkten `PropertyExpression`; ihr Text wird nicht gelesen oder ausgegeben. Eine Zeile in `lineage` beschreibt eine direkte Pipeline-Verbindung zwischen den über `startId` und `endId` zugeordneten Komponenten. Nicht zuordenbare Endpunkte erhalten `PARTIAL_LINEAGE`; Ein-/Ausgangs- und Spaltenmetadaten werden nicht ausgegeben. Eine Zeile in `connections` beschreibt Name und `CreationName` eines Paket-Connection-Managers; Connection Strings werden nicht gelesen oder ausgegeben. Eine Zeile in `parameters` beschreibt Name und Scope eines Paketparameters; seine Werte und Eigenschaften werden nicht gelesen oder ausgegeben.

Eine Zeile in `variables` beschreibt eine direkte Definition in Paket-,
Container- oder Taskscope. `ScopeExecutableOrdinal` ordnet sie dem
`executables`-Inventar desselben Aufrufs zu. Namespace, Name, Datentypcode,
Schreibschutz und Ausdruckskennzeichen enthalten ausschließlich Metadaten.
Variablenwerte und Ausdruckstexte werden nicht gelesen oder ausgegeben.
Gleichnamige Variablen in unterschiedlichen Scopes bleiben getrennt.

Schema v3 hängt `variables` als dreizehntes RAW-Resultset an. TABLE verwendet
das Ziel `variables`; JSON enthält dasselbe begrenzte Array einschließlich
NULL-Feldern. NULL und 0 für `@MaxZeilen` sind unbegrenzt. Ein positives Limit
erzeugt bei abgeschnittenem Variableninventar `VARIABLES_TRUNCATED` und den
Quellenstatus TRUNCATED. CONSOLE bleibt die Modulübersicht. Bei RAW begrenzt @MaxZeilen auch die sieben weiteren Detailgruppen. TABLE und JSON exportieren diese sieben Inventare dagegen ohne Kürzung durch @MaxZeilen; das interne Parserinventar wird nicht global vorab begrenzt.

Event-Handler-Scope einschließlich untergeordneter Executables bleibt
ausgeschlossen und wird bei vorhandenem Event Handler ausdrücklich
gekennzeichnet. Fehlende Executable-Kennungen verhindern die Scopezuordnung
und liefern `VARIABLES_SCOPE_UNRESOLVED`. Lesen Sie den Quellenstatus
`DTSX variables` und IsPartial, bevor Sie ein leeres Inventar als Abwesenheit
von Variablen interpretieren. Fehlende oder nicht konvertierbare Metadaten
bleiben NULL; die spezifizierten fehlenden Namespace- und Booleanattribute
verwenden dagegen die Defaults leer beziehungsweise False. Der
[öffentliche Vertrag](../../Architecture/SSIS_001_Phase0_Public_Contract.md)
beschreibt alle acht Spalten und die Scopegrenzen.

## So lesen

`AVAILABLE_LIMITED` bestätigt den begrenzten Paket-, Executable-, direkten Constraint-, Pipeline-Komponenten-, Property-Expression-, Connection-Manager-, Paketparameter- und Variablendefinitionsscope. Leere spätere Parserresultsets bedeuten in diesem Slice keine Abwesenheit weiterer Data-Flow-Metadaten.

## Warum kann das problematisch sein?

Ein nicht erkennbares Paketformat oder eine unbekannte Struktur verhindert eine belastbare statische Aussage über enthaltene Arbeitsschritte. Eine unerwartet große Executable-Menge kann eine getrennte Detailprüfung sinnvoll machen, ist jedoch kein Fehlerbefund.

## Wann ist es kein Problem?

Ein eingeschränkter Status ist erwartbar, solange der Aufruf nur den ersten Parser-Slice nutzt. Ein nicht unterstütztes Dokument kann ein anderes gültiges XML- oder Paketformat darstellen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Ist das direkt übergebene Dokument ein unterstütztes DTSX-v2-Paket, welche Paket-Executables sind darin statisch sichtbar und wie ist ihre direkte Containerhierarchie?

### Technischer Hintergrund

DTSX verwendet ein `Executable`-Wurzelelement im SQL-Server-DTS-Namespace. Der Parser prüft diese Form und liest die für Paket- und Executable-Inventar benötigten Attribute einschließlich des direkten übergeordneten Executable-Containers.

### Datenkette

`@PackageXml` wird im Aufruf verarbeitet. Das Paketresultset liest den Wurzelknoten; das Executable-Resultset erfasst untergeordnete `DTS:Executable`-Elemente und ihren direkten Container. Constraints werden über ihre Referenzen auf diese Executables zugeordnet. Keine Server- oder externe Datenquelle ergänzt diese Kette.

### Source Select

```sql
SELECT @PackageXml AS [DirectPackageXml];
```

Der dargestellte Eingabewert steht für die direkte Aufrufquelle; er wird nicht als XML-, Paket- oder Geheimniswert ausgegeben.

**Wichtig für die Eigenlast:** Die Quelle ist die bereits im Aufruf übergebene XML-Instanz. Der Parser öffnet keine zusätzliche Datei, Datenbank oder Netzwerkverbindung.

### Zeit- und Scope-Modell

Die Analyse ist eine Momentaufnahme des beim Aufruf übergebenen XML-Dokuments. Sie besitzt keine Retention, keine externe Zeitquelle und keinen Laufzeitbeobachtungszeitraum.

### Bewertung und Gegenprobe

Vergleichen Sie `package`, `executables`, `controlFlowConstraints` und den Quellenstatus mit dem bereitgestellten Paketartefakt. Eine Ausführung, SSISDB- oder Dateiadapterprüfung benötigt einen getrennten, dafür vorgesehenen Nachweis.

### Typische Fehlinterpretation

Eine sichtbare Executable-Zeile bedeutet nicht, dass das Executable ausgeführt wurde, erfolgreich war oder Daten verarbeitet hat.

### Folgeanalyse

Nachfolgende Slices ergänzen weitere Control-Flow-Informationen, Data-Flow-Details, Parameter, Expressionauflösung und weitergehende Lineage. Laufzeitdaten bleiben den getrennten Legacy- und SSISDB-Analyzern vorbehalten.

## Datenquellen, Datenschutz und Nebenwirkungen

Die Procedure liest ausschließlich die übergebene XML-Instanz. Sie liest und exportiert keine Connection Strings, Secrets, Binärwerte, Host-, Login- oder vollständigen Pfadangaben. Sie führt kein Paket, kein darin enthaltenes SQL und keine externe Verbindung aus. Der Pfad verändert keine externe Quelle und erzeugt keine persistenten Datenbankobjekte. Eigene lokale Temp-Tabellen und ausdrücklich angeforderte TABLE-Ziele werden verarbeitet.

## Grenzen und Gegenprüfung

Weitere Control-Flow-Beziehungen, Komponentenprofile, Data-Flow-Ein- und Ausgänge, Spaltenmetadaten, Verbindungen, Parameter, Expressionauflösung, weitergehende Lineage, Regelengine sowie Legacy- und SSISDB-Laufzeitadapter gehören zu späteren Slices. Direkte Precedence Constraints und Pipeline-Linien bilden weder eine Ausführung noch ihren Erfolg ab. Prüfen Sie einen auffälligen Paketabschnitt mit einer getrennt autorisierten Paket- oder Laufzeituntersuchung.

Der isolierte SQL-Server-2025-Vertrag prüft direktes DTSX-v2-XML, TABLE- und JSON-Ausgabe sowie `UNSUPPORTED_PACKAGE_FORMAT`. Windows-, SSISDB- und weitere Paketformatnachweise bleiben offen.

## Primärquellen

- [MS-DTSX-Spezifikation](https://learn.microsoft.com/en-us/openspecs/sql_data_portability/ms-dtsx/)
- [MS-DTSX2-Spezifikation](https://learn.microsoft.com/en-us/openspecs/sql_data_portability/ms-dtsx2/)

[Technische Detailbeschreibung](../10_SSIS.md#monitorusp_ssispackageanalysis)
