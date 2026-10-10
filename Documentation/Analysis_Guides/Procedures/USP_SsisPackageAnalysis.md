# [monitor].[USP_SsisPackageAnalysis]

**Bereich:** Integration<br>
**Zweck:** Inventarisiert Paket und Executables eines direkt übergebenen DTSX-v2-Dokuments.<br>
**Beobachtungsart:** Statische XML-Analyse<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet, ob ein direkt übergebenes DTSX-v2-Dokument als Paket erkannt wird und welche Executables es enthält. Sie ist für eine statische Vorprüfung bestimmt und bewertet keine Paketausführung, keine Datenbewegung und keine externe Verbindung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_SsisPackageAnalysis]
      @PackageXml = @PackageXml
    , @ResultSetArt = 'CONSOLE';
```

Der Aufruf akzeptiert ausschließlich `@AnalysisDepth = 'STANDARD'`. `@ResolveSqlMetadata` und `@CheckLookupData` bleiben in diesem Slice `0`; dadurch öffnet die Procedure keine Datenbank-, Lookup-, Datei-, ISPAC- oder SSISDB-Quelle.

## Resultsets und Leserichtung

Die RAW-Resultsetfolge lautet `moduleStatus`, `package`, `executables`, `dataFlowComponents`, `connections`, `parameters`, `expressions`, `lineage`, `findings`, `sourceStatus` und `warnings`. Der erste Slice füllt Paket und Executables. Die übrigen Resultsets bleiben leer und `AVAILABLE_LIMITED` weist ihre noch nicht implementierte Analyse aus. `CONSOLE` rendert die zusammenfassende Modulzeile; `TABLE` verwendet benannte Ziele aus `@ResultTablesJson`; JSON enthält denselben begrenzten Kern.

Lesen Sie zuerst `moduleStatus` und `sourceStatus`. `UNSUPPORTED_PACKAGE_FORMAT` bedeutet, dass das Dokument nicht als unterstütztes DTSX-v2-Paket erkannt wurde; daraus folgt keine Aussage über die Gültigkeit anderer XML- oder Paketformate.

## Eine Zeile bedeutet

Eine Zeile in `package` beschreibt das erkannte Wurzelpaket. Eine Zeile in `executables` beschreibt ein in der XML-Struktur vorhandenes Executable; sie enthält keine Laufzeit- oder Erfolgsinformation.

## So lesen

`AVAILABLE_LIMITED` bestätigt den begrenzten Paket- und Executable-Scope. Leere spätere Parserresultsets bedeuten in diesem Slice keine Abwesenheit von Data-Flow- oder Connection-Metadaten.

## Warum kann das problematisch sein?

Ein nicht erkennbares Paketformat oder eine unbekannte Struktur verhindert eine belastbare statische Aussage über enthaltene Arbeitsschritte. Eine unerwartet große Executable-Menge kann eine getrennte Detailprüfung sinnvoll machen, ist jedoch kein Fehlerbefund.

## Wann ist es kein Problem?

Ein eingeschränkter Status ist erwartbar, solange der Aufruf nur den ersten Parser-Slice nutzt. Ein nicht unterstütztes Dokument kann ein anderes gültiges XML- oder Paketformat darstellen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Ist das direkt übergebene Dokument ein unterstütztes DTSX-v2-Paket, und welche Paket-Executables sind darin statisch sichtbar?

### Technischer Hintergrund

DTSX verwendet ein `Executable`-Wurzelelement im SQL-Server-DTS-Namespace. Der Parser prüft diese Form und liest nur die für Paket- und Executable-Inventar benötigten Attribute.

### Datenkette

`@PackageXml` wird im Aufruf verarbeitet. Das Paketresultset liest den Wurzelknoten; das Executable-Resultset erfasst untergeordnete `DTS:Executable`-Elemente. Keine Server- oder externe Datenquelle ergänzt diese Kette.

### Source Select

```sql
SELECT @PackageXml AS [DirectPackageXml];
```

Der dargestellte Eingabewert steht für die direkte Aufrufquelle; er wird nicht als XML-, Paket- oder Geheimniswert ausgegeben.

**Wichtig für die Eigenlast:** Die Quelle ist die bereits im Aufruf übergebene XML-Instanz. Der Parser öffnet keine zusätzliche Datei, Datenbank oder Netzwerkverbindung.

### Zeit- und Scope-Modell

Die Analyse ist eine Momentaufnahme des beim Aufruf übergebenen XML-Dokuments. Sie besitzt keine Retention, keine externe Zeitquelle und keinen Laufzeitbeobachtungszeitraum.

### Bewertung und Gegenprobe

Vergleichen Sie `package`, `executables` und den Quellenstatus mit dem bereitgestellten Paketartefakt. Eine Ausführung, SSISDB- oder Dateiadapterprüfung benötigt einen getrennten, dafür vorgesehenen Nachweis.

### Typische Fehlinterpretation

Eine sichtbare Executable-Zeile bedeutet nicht, dass das Executable ausgeführt wurde, erfolgreich war oder Daten verarbeitet hat.

### Folgeanalyse

Nachfolgende Slices ergänzen Control- und Data-Flow, Komponenten, Parameter, Expressions und Lineage. Laufzeitdaten bleiben den getrennten Legacy- und SSISDB-Analyzern vorbehalten.

## Datenquellen, Datenschutz und Nebenwirkungen

Die Procedure liest ausschließlich die übergebene XML-Instanz. Sie liest und exportiert keine Connection Strings, Secrets, Binärwerte, Host-, Login- oder vollständigen Pfadangaben. Sie führt kein Paket, kein darin enthaltenes SQL und keine externe Verbindung aus. Der Pfad ist read-only und erzeugt keine persistenten Datenbankobjekte.

## Grenzen und Gegenprüfung

Control- und Data-Flow-Beziehungen, Komponentenprofile, Verbindungen, Parameter, Expressions, Lineage, Regelengine sowie Legacy- und SSISDB-Laufzeitadapter gehören zu späteren Slices. Eine vorhandene Executable-Zeile beweist weder ihre Ausführung noch ihren Erfolg. Prüfen Sie einen auffälligen Paketabschnitt mit einer getrennt autorisierten Paket- oder Laufzeituntersuchung.

Der isolierte SQL-Server-2025-Vertrag prüft direktes DTSX-v2-XML, TABLE- und JSON-Ausgabe sowie `UNSUPPORTED_PACKAGE_FORMAT`. Windows-, SSISDB- und weitere Paketformatnachweise bleiben offen.

## Primärquellen

- [MS-DTSX-Spezifikation](https://learn.microsoft.com/en-us/openspecs/sql_data_portability/ms-dtsx/)
- [MS-DTSX2-Spezifikation](https://learn.microsoft.com/en-us/openspecs/sql_data_portability/ms-dtsx2/)

[Technische Detailbeschreibung](../10_SSIS.md#monitorusp_ssispackageanalysis)
