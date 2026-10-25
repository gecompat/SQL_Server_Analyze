# [monitor].[USP_SsisPackageModelAnalysis]

**Bereich:** SSIS<br>
**Zweck:** Validiert ein vom Caller übergebenes neutrales SSIS-Paketmodell und zeigt seine Struktur, Herkunft und Evidenzgrenzen.<br>
**Beobachtungsart:** Statische importierte Producerbehauptungen<br>
**Kostenklasse:** LOW_MEDIUM; Eingangsgröße, Objektzahl und Beziehungen bestimmen den Aufwand.

## Entscheidungsfrage und Einsatz

Die Procedure prüft ein JSON-Modell nach dem
[Abgrenzungs- und Austauschvertrag](../../Architecture/SSIS_Analyze_Toolbelt_Exchange_Contract.md).
Der Import liest weder DTSX noch Dateien, SSISDB, externe Quellen oder Paket-SQL.
SQL CLR und eine Toolbelt-Installation werden auf dem Analyze-Server nicht benötigt.
Die vorhandene direkte XML-Inventur bleibt über `USP_SsisPackageAnalysis` verfügbar.

Die neue API gehört zum aktuellen Quellstand. Das bestehende Produkt-ZIP 1.1.2
enthält sie noch nicht. Der [kanonische SSIS-Quellinstaller](../../../Code/Install/Install_SSIS_Analysis.sql)
bindet sie gemeinsam mit ihren nativen Hilfsobjekten ein.

## Nicht beantwortete Fragen

Ein formal gültiges Modell beweist weder Paketerfolg noch Datenqualität oder
richtige Ableitung durch den angegebenen Producer. Producerangaben bleiben ohne kontrollierte lokale Übergabe `UNVERIFIED`.
Ein Caller kann sich nicht durch ein Trust-Flag im JSON selbst qualifizieren. Laufzeitkorrelation,
Expressionauswertung und eine transitive Lineageberechnung gehören nicht zum Import.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_SsisPackageModelAnalysis] @Hilfe = 1;

-- @PackageModelJson und optional @PackageBytes stammen aus dem Caller.
EXEC [monitor].[USP_SsisPackageModelAnalysis]
      @PackageModelJson = @PackageModelJson
    , @PackageBytes = @PackageBytes
    , @MaxZeilen = 200
    , @ResultSetArt = 'CONSOLE';
```

`@PackageBytes` ist optional. Der Importer vergleicht bei Übergabe SHA-256 und
Länge der Originalbytes mit den deklarierten Paketwerten. Ein neu serialisierter
SQL-`xml`-Wert ist dafür ungeeignet. Bytes und Modell werden nicht ausgeführt.

## Resultsets und Leserichtung

RAW liefert `moduleStatus`, `sourceBinding`, `nodes`, `edges`, `coverage`,
`findings`, `sourceStatus` und `warnings`, Schemaversion 1. Lesen Sie zuerst
Modulstatus, Paketbindung und Producervertrauen. Prüfen Sie danach Coverage und
`IsInterpretable`, bevor Sie eine Beziehung als auswertbare statische Angabe verwenden.

Mit `@IncludePackageViews=1` ergänzt Version 1.1.0 fünf fachliche Gruppen in
RAW, TABLE und JSON. Ohne Opt-in bleiben die bisherigen acht Gruppen erhalten.
`meta.packageViewsSchemaVersion=1` beschreibt das zusätzliche JSON-Profil.

| Gruppe | Bedeutung |
|---|---|
| `packageOverview` | Enthält Objektzahlen, beobachtete Datenflussscopes, direkte Beziehungen, offene Referenzen und begrenzte Features des vollständigen validierten Modells. |
| `executables` | Zeigt Tasks, Container und Event Handler mit Parent, Besitzertiefe, deklarierter Art und gegebenenfalls deaktiviertem Zustand. |
| `dataFlows` | Zeigt Executable-Scopes mit gelieferten Komponenten oder Datenflusskanten und deren Objektzahlen. Ein leerer, nicht entsprechend belegter Scope wird nicht als vollständig inventarisierter Datenfluss behauptet. |
| `components` | Zeigt Klassenkennung sowie Port- und Spaltenzahlen. Analyze klassifiziert die Komponenten nicht erneut. |
| `columnRelations` | Verbindet gelieferte direkte Spaltenzuordnungen und Wertabhängigkeiten mit den Endpunkten. `FromNodeKind` unterscheidet Spalten, Variablen und Parameter; spaltenbezogene Quellfelder bleiben für andere Arten NULL. Metadatenverweise bleiben durch `MappingRole` von Datentransfers getrennt. |

Die zusätzlichen Gruppen entstehen vor jeder Ausgabekürzung. Ihre Zähler
verwenden deshalb den vollständigen Graphen. `@MaxZeilen` begrenzt jede neue
Detailgruppe auf deren erste Zeilen in Quellreihenfolge; `NodeOrdinal` und
`EdgeOrdinal` behalten ihre ursprüngliche Bedeutung. Fehlende Endpunkte und
Metadaten bleiben NULL. Die Sichten erzeugen weder transitive Lineage noch
eine neue Typkompatibilitätsbewertung. Zulässige numerische Darstellungen wie
`1e2` und `100.0` werden aus der vorhandenen exakten Zahlenvalidierung übernommen
und als 100 dargestellt. Producervertrauen und Featureabdeckung
bleiben für ihre Interpretation maßgeblich.

CONSOLE liefert eine Modulübersicht. TABLE verwendet dieselben acht benannten
Ziele in `@ResultTablesJson`; bei aktivierten Paketsichten kommen deren fünf
Namen hinzu. Der Caller legt die leeren lokalen Temp-Tabellen an.
JSON wird optional über `@JsonErzeugen=1, @Json=@Json OUTPUT` erzeugt. NONE
unterdrückt fachliche Resultsets. Ausgabearten verändern die Validierung nicht.

## Eine Zeile bedeutet

Eine `nodes`-Zeile ist ein paketlokales Objekt aus dem übergebenen Modell.
`AttributesJson` enthält ausschließlich die für dessen Objektart zulässigen
typisierten Felder. Anzeigenamen sind keine Identität. Eine `edges`-Zeile ist
eine gerichtete deklarierte oder abgeleitete Beziehung mit explizitem Scope.
Eine unbekannte Ableitungsregel erhält `IsInterpretable=0`.

`coverage` bewahrt den berichteten Status und ergänzt, ob der Importer das
Profil unterstützt. `sourceBinding` trennt `DECLARED_ONLY` von
`PACKAGE_BYTES_MATCH`. Hashgleichheit authentifiziert das Modell nicht.
Findings des ersten Slices benennen fehlende Abdeckung und unbestätigte
Producerherkunft; sie geben kein Gesundheitsurteil über eine Ausführung ab.

## So lesen

`AVAILABLE_LIMITED` bezeichnet einen erfolgreich validierten Import mit
unbestätigter Producerherkunft. Ein vollständiger Datenbestand bleibt daher
von einer bestätigten betrieblichen Aussage getrennt. Fehlende Informationen,
unbekannte Profile oder Regeln erlauben keine Aussage, dass die betreffende
SSIS-Aktivität oder Abhängigkeit nicht existiert.

## Warum kann das problematisch sein?

Ein ungeprüftes Modell kann plausible, aber falsche Paketstrukturen enthalten.
Strukturprüfung und Paketbytevergleich erkennen keine absichtlich erfundenen
semantischen Ableitungen. Die vollständige Modellherkunft und eine spätere
Ausführungszuordnung benötigen eigenständige Belege.

## Wann ist es kein Problem?

Eine begrenzte Expression- oder Zeilenlineage ist erwartbar, wenn der Producer
diese Semantik noch nicht qualifiziert hat. Direkte Struktur- und
Spaltenzuordnungen können trotzdem unabhängig nutzbar sein. Die Procedure
rekonstruiert keine fehlenden Kanten anhand ähnlicher Namen.

## Beispiele und Gegenbeispiele

```sql
EXEC [monitor].[USP_SsisPackageModelAnalysis]
      @PackageModelJson = @PackageModelJson
    , @IncludePackageViews = 1
    , @MaxZeilen = 200
    , @ResultSetArt = 'RAW';
```

Eine reduzierte Knotenausgabe darf die Komponentenanzahl einer Datenflusssicht
nicht verkleinern. Ein nicht aufgelöster Spaltenbezug erhält keinen erfundenen
Quellnamen. Dieselbe direkte Beziehung wird nicht zu einem zusätzlichen,
abgeleiteten Pfad erweitert.

Ein anderer Anzeigename bei gleicher Objektkennung ändert nicht die
Referenzauflösung. Gleiche Komponentennamen in verschiedenen Datenflüssen
werden über unterschiedliche IDs und Scopes getrennt. Dagegen ist eine
identische DTSID kein ausreichender Nachweis für dieselben Paketdateibytes.

## Leere oder partielle Ausgabe

Ungültiges JSON, unbekannte Felder, doppelte Keys oder Kennungen, falsche
Objektarten, Besitzzyklen und ungültige Beziehungen verwerfen den Import
atomar. `EXCHANGE_SOURCE_MISMATCH` verwirft ein Modell mit abweichenden
Originalbytes. Ein Quellenfehler liefert Status und Warnkontext, aber keine
teilweise bereits validierten Knoten oder Kanten. JSON behält leere Arrays.

`@MaxZeilen` begrenzt nur den Export von Knoten und Kanten. Modulzähler und
Validierung beziehen sich auf den vollständigen Bestand. `RESULT_TRUNCATED`
kennzeichnet die begrenzte Ausgabe. NULL und 0 sind unbegrenzt.

## Eigenlast und Grenzen

Kostenklasse: LOW_MEDIUM. Standardpfad: ein bereits übergebenes JSON-Modell,
ohne Katalog- oder Dateizugriff. Teuerster Pfad: 16 MiB JSON mit 20.000 Knoten
und 50.000 Kanten. Haupttreiber: Tokenisierung, Referenzen und Besitzerhierarchie.
Skalierung: mit der Modellgröße, nicht mit dem Datenbestand einer Quelldatenbank.
Ressourcen: lokale Temp-Tabellen und optionale JSON-Ausgabe.
Begrenzungswirkung: 32 JSON-Ebenen, 128 Besitzebenen, eine Million interne
Tokens und höchstens 1.000 Diagnosen. Sperrwartezeit: 0 bis 60.000 ms.
Locking und Nebenwirkungen: eigene Temp-Objekte sowie ausdrücklich zugeordnete
TABLE-Ziele; keine persistenten Paket- oder Quelländerungen.
Schutzmechanismus: Größen- und Feldprüfung vor Veröffentlichung, 1 bis 60
Sekunden kooperatives Zeitbudget, standardmäßig 30 Sekunden.
Sicherer Einsatz: ein begrenzter, bewusst ausgewählter statischer Import.
Aussagegrenze: keine harte Deadline innerhalb einer laufenden SQL-Anweisung
und keine gemessene Maximalkapazität. Eine Callertransaktion wird nicht übernommen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Entspricht das zugelieferte Modell dem vereinbarten Format und welche
statischen Beziehungen sind innerhalb seiner Abdeckung interpretierbar?

### Technischer Hintergrund

Die Feldprüfungen werden durch `Code/Tools/Build_Ssis_Exchange_Rules.py` aus
der unveränderten Toolbelt-Schemakopie generiert. Der native Importer ergänzt
Objekt-, Scope-, Referenz- und Paketbindungsprüfungen. Er enthält keinen
SSIS-Komponentenparser und keine eigene Lineageableitung.

### Datenkette

Caller-JSON → geschlossene Feldprüfung → Referenzprüfung → optionale
Paketbytebindung → einmal materialisierte Ausgaben. Der externe Toolbelt-Host
ist eine mögliche Zulieferung und keine vom Importer aufgerufene Abhängigkeit.

### Source Select

```sql
SELECT @PackageModelJson AS [CallerPackageModel];
```

Der Parameter bezeichnet die Eingabequelle. Die Procedure gibt das Rohdokument
nicht zusätzlich aus und übernimmt keine darin enthaltenen Befehle.

**Wichtig für die Eigenlast:** Die Quelle ist das bereits übergebene Modell;
es wird kein zusätzlicher Datenbank-, Datei- oder Netzwerkbestand gelesen.

### Zeit- und Scope-Modell

Die Analyse gilt für ein übergebenes Modell und dessen deklarierte Paketrevision.
Sie besitzt kein Laufzeitbeobachtungsfenster. Der Producerbytehash ist weder
eine Berechtigung noch ein Nachweis der Ausführungsrevision.

### Bewertung und Gegenprobe

Vergleichen Sie Originalbytes, Producerbuild und freigegebene Profile unabhängig.
Verwenden Sie für Betriebsbeobachtungen die getrennten SSISDB- oder Legacy-Analyser.
Die gemeinsamen synthetischen Konformitätsfälle prüfen beide Producerhosts
gegen dieselben Objekt- und Kanten-Erwartungen.

### Typische Fehlinterpretation

`PACKAGE_BYTES_MATCH` belegt keine korrekte Modellableitung und
`IsInterpretable=1` keine tatsächlich ausgeführte Datenbewegung.

### Folgeanalyse

Weitere fachliche Regeln können die validierten typisierten Metadaten nutzen,
sofern ihre Feature- und Evidenzvoraussetzungen erfüllt sind. Vertiefte
Parser- und Lineagelogik bleibt im kanonischen Toolbelt-Kern.

## Kontrollierte lokale Übergabe

`@LocalHandoverId` ist optional und benötigt zugleich `@PackageBytes`.
Ohne ID wird kein Übergabebeleg gelesen. Mit ID prüft Analyze die an dieser
Procedure gespeicherte Extended Property `SSIS_HANDOVER_<uuid-in-kleinschreibung>`.
Nur Besitzer, berechtigte DDL-Administratoren oder Principals mit ALTER/CONTROL
auf der Procedure dürfen diese Metadaten schreiben. Diese Principals bilden
zusammen mit dem lokalen Account, Adapter und der qualifizierten .NET-Runtime
die Vertrauenswurzel. Analyze erteilt keine zusätzlichen Berechtigungen.

Der [lokale Zulieferadapter](../../../Code/Tools/Invoke-SsisQualifiedHandover.ps1)
benötigt eine bereits offene Verbindung zur ausdrücklich gewählten Analyze-
Datenbank sowie unabhängig freigegebene SHA-256- und Source-Commit-Werte des
Toolbelt-Exporthosts. Die Freigabewerte dürfen nicht erst aus dem ungeprüften
Kandidaten als eigene Freigabe abgeleitet werden. Der Adapter prüft vorhandenes
ALTER-Recht, liest begrenzte private Snapshots von DLL und Paket, vergleicht den
Buildhash und führt genau diesen Hostsnapshot mit einer eigenen .NET-10-
Runtimekonfiguration aus. Der Snapshotordner besitzt vor dem Schreiben ausschließlich Accountzugriff
(unter Unix Modus 0700); Größenprüfungen begrenzen bereits jeden Kopierschritt.
Auch nach fehlgeschlagenem Prozessstart wird der eigene Ordner bereinigt.
Der Adapter kopiert keine fremden Abhängigkeiten und entfernt
DOTNET-/CoreCLR-Konfigurationsvariablen aus der Kindprozessumgebung.

```powershell
$handover = & ./Code/Tools/Invoke-SsisQualifiedHandover.ps1 `
    -ProducerAssemblyPath $qualifiedProducerAssembly `
    -ExpectedBuildSha256 $approvedBuildSha256 `
    -ExpectedSourceCommit $approvedSourceCommit `
    -PackagePath $packagePath -Connection $openAnalyzeConnection
```

Der Adapter kontrolliert die vom tatsächlichen Host gemeldete Build-/Commit-
Identität. Analyze validiert das Ergebnis und die Paketbytes bereits vor der
Registrierung. Der separat berechtigte Metadatenzugriff speichert ausschließlich
Digests, Länge, Methode und SQL-Server-Zeitstempel; er speichert keine Pakete,
Modelle, Dateipfade, Konten oder Verbindungsdaten. Der Adapter liefert Modell,
Originalbytes und Übergabe-ID an den Caller zurück. Private temporäre Snapshots
werden anschließend entfernt. Es findet keine Paket- oder Paket-SQL-Ausführung
statt; ausgeführt wird ausschließlich der ausdrücklich qualifizierte Exporthost.

Die spätere Analyse vergleicht den SHA-256 über die exakten UTF-16LE-Bytes des
übergebenen JSON-Strings sowie Paketdigest, Byteanzahl, Buildhash und Commit.
Schon eine Neuserialisierung benötigt einen neuen Beleg. `issuedUtc` und
`expiresUtc` begrenzen die Gültigkeit auf die gewählte Dauer von einer bis
höchstens 24 Stunden. Der Beleg ist ein geschlossener lokaler Vertrag
`ssis-local-handover`, Version `1.0.0`, Methode `QUALIFIED_HOST_SNAPSHOT`.
Er ist keine Fernsignatur und kein Nachweis richtiger Parsersemantik.

Nur bei erfolgreicher Gesamtprüfung wird `ProducerTrust=VERIFIED_LOCAL`
ausgegeben und an objektbezogene Hinweise weitergereicht. Diese bleiben
statische importierte Aussagen. Unbekannte, abgelaufene oder widersprüchliche
Belege ergeben `EXCHANGE_HANDOVER_INVALID` und atomar leere fachliche Gruppen.
Ein falscher Paketbytehash wird bereits als `EXCHANGE_SOURCE_MISMATCH` abgewiesen.
Für den Vertrauenszugriff gilt ein fest begrenzter Metadatenzugriff mit
`READCOMMITTEDLOCK` und dem bestehenden Lock-Timeout; ein uncommittierter Beleg
wird nicht über NOLOCK als vertrauenswürdig übernommen.

Der verantwortliche Administrator kann einen Beleg durch Entfernen seiner
Extended Property widerrufen. Abgelaufene Eigenschaften werden ignoriert,
aber nicht automatisch gelöscht. CREATE OR ALTER erhält die Eigenschaften;
ein Drop/Recreate oder ein Datenbankwechsel überträgt ihre Vertrauenswirkung
nicht automatisch. Ein anderes Datenbank- oder Laufzeitziel benötigt seine
separat kontrollierte Übergabe. Der eigenständige Pfad ohne ID und ohne SQL CLR
bleibt verfügbar.

## Objektbezogene Regeln

`@IncludeObjectRules=1` ergänzt `objectFindings` unabhängig von den
Paketsichten. Der Standard behält acht RAW-Gruppen; Regeln allein liefern neun,
Regeln mit Paketsichten vierzehn Gruppen. JSON kennzeichnet den optionalen
Vertrag mit `meta.objectRulesSchemaVersion=1`; TABLE akzeptiert den Gruppennamen
nur bei aktiviertem Flag. CONSOLE bleibt die einzelne Modulstatusausgabe.

| RuleId | Gelieferter Beleg und Aussagegrenze |
|---|---|
| `SSIS_EXECUTABLE_DISABLED` | Ein Executable besitzt ausdrücklich `isDisabled=true`. Eine tatsächliche Ausführung ist damit nicht nachgewiesen. |
| `SSIS_COMPONENT_PROFILE_UNKNOWN` | Eine Producerdiagnose `UNKNOWN_COMPONENT` verweist auf einen vorhandenen Komponentenknoten. Analyze führt keinen eigenen Komponentenkatalog. |
| `SSIS_EDGE_UNRESOLVED` | Eine konkrete Kante besitzt `resolution=UNRESOLVED`. Analyze ergänzt keine Endpunkte. |
| `SSIS_COLUMN_MULTIPLE_DIRECT_SOURCES` | Mehrere unterschiedliche gelieferte, aufgelöste `DATA_TRANSFER`-Quellen zeigen auf dieselbe Spalte im selben Scope. Das ist kein Fehlernachweis. |
| `SSIS_PORT_NO_DECLARED_PATH` | Ein regulärer gerichteter Port besitzt keine passende deklarierte Pipelinekante. Diese Abwesenheitsaussage setzt `COMPLETE` für Inventar und Pipelinegraph sowie das unterstützte Format- und Komponentenprofil voraus. Unaufgelöste oder nicht unterstützte Pipelinepfade sperren die Abwesenheitsregel im betreffenden Scope; Laufzeiterreichbarkeit und Zeilenfluss bleiben unbelegt. |

Alle Hinweise besitzen Severity `INFO` und EvidenceLevel `IMPORTED_STATIC`.
`NodeId`, `EdgeId` und `ScopeNodeId` lokalisieren den Beleg; `PackageSha256`,
`BindingStatus` und `ProducerTrust` erhalten seine Herkunft. Fehlende Namen,
unbekannte Eigenschaften und nicht vorhandene Runtimebelege werden nicht
ersetzt. Die Regeln arbeiten vor der Ausgabekürzung; `@MaxZeilen` begrenzt die
Gruppe anschließend und erzeugt bei Kürzung `RESULT_TRUNCATED`. Ungültige
Modelle liefern auch bei aktiviertem Flag keine Teilbefunde.

## Primärquellen

- [Freigegebener projektübergreifender Vertrag](../../Architecture/SSIS_Analyze_Toolbelt_Exchange_Contract.md)
- [Austauschschema](../../../Metadata/Quality/SSIS_Exchange_V1.schema.json)
- [Resultsetinventar](../../../Metadata/Inventory/ResultSets.csv)

[Technische Detailbeschreibung](../../Architecture/SSIS_Analyze_Toolbelt_Exchange_Contract.md)
