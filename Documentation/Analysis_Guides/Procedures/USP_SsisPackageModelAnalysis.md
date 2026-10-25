# [monitor].[USP_SsisPackageModelAnalysis]

**Bereich:** SSIS<br>
**Zweck:** Validiert ein vom Caller übergebenes neutrales SSIS-Paketmodell und zeigt seine Struktur, Herkunft und Evidenzgrenzen.<br>
**Beobachtungsart:** Statische importierte Producerbehauptungen<br>
**Kostenklasse:** LOW_MEDIUM; Eingangsgröße, Objektzahl und Beziehungen bestimmen den Aufwand.

## Entscheidungsfrage und Einsatz

Die Procedure prüft ein JSON-Modell nach dem
[Abgrenzungs- und Austauschvertrag](../../Architecture/SSIS_Analyze_Toolbelt_Exchange_Contract.md).
Der Import liest weder DTSX noch Dateien, SSISDB oder Paket-SQL. Die optionale
SQL-Metadatenprüfung liest ausschließlich ausdrücklich zugeordnete lokale Kataloge.
SQL CLR und eine Toolbelt-Installation werden auf dem Analyze-Server nicht benötigt.
Die vorhandene direkte XML-Inventur bleibt über `USP_SsisPackageAnalysis` verfügbar.

Die neue API gehört zum aktuellen Quellstand. Das bestehende Produkt-ZIP 1.1.2
enthält sie noch nicht. Der [kanonische SSIS-Quellinstaller](../../../Code/Install/Install_SSIS_Analysis.sql)
bindet sie gemeinsam mit ihren nativen Hilfsobjekten ein.

## Nicht beantwortete Fragen

Ein formal gültiges Modell beweist weder Paketerfolg noch Datenqualität oder
richtige Ableitung durch den angegebenen Producer. Producerangaben bleiben ohne kontrollierte lokale Übergabe `UNVERIFIED`.
Ein Caller kann sich nicht durch ein Trust-Flag im JSON selbst qualifizieren.
Die optionale Laufzeitkorrelation verlangt einen kontrollierten Capture.
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

## Ausführungskorrelation aus einem kontrollierten Capture

`@IncludeExecutionCorrelation=1` ergänzt `runtimeBinding` und
`executionCorrelation` für eine positive `@ExecutionId`. Korrelation allein
liefert zehn RAW-Gruppen, zusammen mit Paketsichten und Regeln sechzehn.
CONSOLE bleibt eine Modulstatusausgabe. JSON kennzeichnet den Zusatzvertrag
mit `meta.executionCorrelationSchemaVersion=1`; TABLE akzeptiert die zwei
Namen nur bei aktiviertem Flag. Die vier Korrelationseingaben müssen bei
abgeschaltetem Flag leer bleiben. `@MaxZeilen` begrenzt die Ausgabe erst
nach Prüfung und Zuordnung des gesamten Captures.

Der native Importer führt keinen SSISDB-Zugriff aus. Der optionale externe
[Katalogadapter](../../../Code/Tools/Invoke-SsisCatalogHandover.ps1) liest
Ausführung, aktuelle Projektversion, Projektarchiv und sichtbare Statistiken
in einem gebundenen Kanal. Projekt und Ordner bleiben während der begrenzten
Lesetransaktion mit `HOLDLOCK` geschützt. Die Ausführungsrevision muss der
aktuellen Projektrevision entsprechen. Nicht verfügbare alte Versionen werden
nicht durch heutige Pakete ersetzt oder wiederhergestellt. Nur der exakt
benannte ZIP-Eintrag wird im Speicher geöffnet; Pakete werden nicht ausgeführt.

Voraussetzungen sind PowerShell 7/.NET 10, ein unabhängig freigegebener
Toolbelt-Host mit Exportbundle, eine dedizierte offene SSISDB-Quellverbindung
und eine offene Analyze-Zielverbindung mit ALTER-Autorität. Beide Verbindungen
dürfen keine Callertransaktion besitzen oder gleichzeitig anderweitig verwendet
werden. Die Quelle benötigt die dokumentierten Katalog-/`catalog.get_project`-
Rechte. Die Scriptparameter verlangen Buildhash und Source-Commit. Ein optionaler
`SourceReader` ist selbst Teil der qualifizierten Vertrauensgrenze: Er führt den
vorgegebenen Gesamtbatch einmal gegen denselben frisch geprüften Quellkanal aus,
bindet dessen eindeutige `SourceBindingId` und liefert begrenzte Ergebnistabellen.
Er ist kein Importpfad für fertige fremde Captures.

Modell und Identitätssidecar stammen aus einem einzigen Toolbelt-Export.
Nur Toolbelt liest native IDs und vorhandene namespacequalifizierte `refId`-
Pfade. Zwei eigene lokale Extended Properties registrieren Modell und Capture
atomar. Der Adapter liefert `PackageModelJson`, `PackageBytes`, `LocalHandoverId`,
`ExecutionSnapshotJson` und `RuntimeHandoverId`; diese Werte werden gemeinsam
an die Procedure übergeben. Ein Laufzeitbeleg ersetzt den Modellbeleg nicht.

`runtimeBinding` nennt Ausführung, Katalog-GUID, Kanalbindungshash, Projekt-ID/-LSN,
Paketdigest, Capturezeitraum und vollständige Zeilen-/Trefferzahlen.
`RUNTIME_BOUND_CAPTURE` bestätigt diesen importierten Capture zum genannten
Zeitpunkt. Jede Statistikzeile bleibt separat erhalten. Objektzuordnung verlangt
eine im Modell eindeutige native GUID und bytegenaue Gleichheit von importiertem
Modellpaketpfad und Katalogpaketpfad. Zusätzlich muss genau eine Paketwurzel
mit passender GUID, passendem Paketpfad und dem Paketdateinamen der Ausführung
beobachtet sein. Ihr Ausführungspfad muss genau ein oberstes Pfadsegment sein.
Damit qualifiziert ein verschachtelter Paketaufruf keine Wurzel.

Der bisherige Capturevertrag `SSISDB_CURRENT_PROJECT_ROOT_SCOPE_V1` ohne
Iterationsoption erhält beide
Pfadrepräsentationen. SSISDB verwendet beispielsweise `\Package` als
Paketpfad und `\SyntheticRuntimeRoot` als Ausführungspfad derselben Wurzel.
Analyze bindet diese zwei beobachteten Wurzeln zusammen und vergleicht den
unveränderten restlichen Paketpfad innerhalb dieses Scopes exakt mit dem
Ausführungspfad. Eine Pfadsegmentgrenze ist Pflicht; `\PackageSuffix` ist
kein Kind von `\Package`. Modellanzeigenamen bestimmen die Laufzeitwurzel
nicht. Zeichen, Iterationszusätze und Kindpaketsegmente werden weder entfernt
noch normalisiert. Mehrdeutige GUIDs, fehlende Pfade und Abweichungen bleiben
unzugeordnet. Dies ist eine native Laufzeitzuordnungsregel auf bereits
zugelieferten Identitäten, kein DTSX-Parser und keine Lineageableitung.

EvidenceLevel ist `IMPORTED_CATALOG_OBSERVATION`; wegen unbekannter
Loggingabdeckung bleibt die Quelle partiell. Analyze erzeugt keine neue
Lineage. Fehlende, veränderte oder abgelaufene Captures liefern
`RUNTIME_BINDING_UNPROVEN` und leere Korrelationszeilen; das gültige statische
Modell bleibt nutzbar. Capturegrenzen sind 16 MiB, 16 JSON-Ebenen und 50000
Beobachtungen; Archivgrenzen sind 64 MiB/10000 Einträge und 16 MiB je Paket.
Das gemeinsame Importerzeitbudget bleibt wirksam. Der eigenständige statische
Pfad benötigt weder diesen Adapter noch SSISDB, Toolbelt oder SQL CLR.

Der manuelle
[Windows-Quellentest](../../../Code/Tests/Integration/216_SsisCatalogHandover_Native_Contract.ps1)
verwendet einen ausdrücklich eigenen Lab-Run mit bereits bereitgestellter
SSISDB. Sein getrennt kompilierter
[SDK-Fixtureautor](../../../Code/Tests/Fixtures/SSIS_Execution_Correlation/CreateProject.cs)
liefert die erwarteten GUIDs, Paketpfade und Originalbytes unabhängig vom
Toolbelt-Exporter. Der Test prüft einen echten Paketlauf und eine abweichende
spätere Projektrevision. Er entfernt seine eigenen Katalogobjekte und die
temporäre Analyze-Datenbank; der bereitgestellte Lab-Run verbleibt beim
Aufrufer. Private Receipts und Capturedokumente gehören nicht in Git.

## Iterationsgebundene Ausführungskorrelation

`@IncludeIterationCorrelation=1` verlangt zugleich
`@IncludeExecutionCorrelation=1`. Der Katalogadapter wird mit demselben
Schalter aufgerufen. Er verwendet den optionalen Toolbelt-Export
`--iteration-bundle`, den Identitätssidecar 1.1.0 und den Capturevertrag
`ssis-execution-snapshot` 1.1.0 mit
`method=SSISDB_CURRENT_PROJECT_ITERATION_SCOPE_V1`. Ein älterer Host wird
nicht durch einen ungeprüften Ersatzpfad ergänzt. Die Standardoptionen und
der bisherige Capture 1.0.0 bleiben unverändert.

Nur Toolbelt klassifiziert die unterstützten For-/Foreach-Container im
Booleanfeld `iterationContainer`. Analyze verwendet die gelieferten Parent-IDs
und die unveränderten nativen Pfadsegmente. Eine eindeutige native GUID,
derselbe Paketpfad, Paketdateiname, Paketdigest und eine qualifizierte
Ausführungswurzel bleiben Voraussetzung. Zwischen einem bekannten
Schleifensegment und seinem Kind ist zusätzlich ein kanonischer positiver
ASCII-Zähler in eckigen Klammern erlaubt. Der Zähler muss in `bigint` passen;
Vorzeichen, führende Nullen, Leerzeichen, zusätzliche Klammern und Unicodeziffern
qualifizieren keine Zuordnung. Im eigentlichen Objektnamen vorhandene Klammern
bleiben erhalten. Analyze leitet weder Containerrollen noch Lineage neu ab.

Jede Ausführung behält ihre `StatisticsId`, `ExecutableId`, den ursprünglichen
`ExecutionPath`, Zeitangaben und das Ergebnis in `executionCorrelation`.
Eine zusätzliche Zuordnung trägt `EXACT_GUID_AND_ITERATION_PATH`. Mehrere
Beobachtungen dürfen dieselbe `ModelNodeId` besitzen. Kindpaketsegmente und
Ereignishandler erweitern diesen Scope nicht. Mehrdeutige GUIDs und nicht
passende Pfade bleiben unzugeordnet.

Die Option ergänzt zwei RAW-/TABLE-Gruppen und JSON-Arrays. JSON kennzeichnet
sie mit `meta.iterationCorrelationSchemaVersion=1`. Mit Ausführungskorrelation
sind zwölf RAW-Gruppen vorhanden; mit sämtlichen bisherigen Optionen sind es
neunzehn. CONSOLE bleibt eine Statusgruppe, NONE liefert keine fachlichen
Resultsets, JSON bleibt ein OUTPUT-Parameter.

| Gruppe | Bedeutung und Aussagegrenze |
|---|---|
| `executionObjectSummary` | Eine Zeile je importiertem Paket-/Executableobjekt mit beobachteter Instanzzahl, Erfolgs-, Fehler-, Abbruch- und übrigen Ergebnissen sowie bekannten Dauerwerten. `UNASSIGNED_OR_NOT_OBSERVED` beweist keine Nichtausführung. |
| `executionCoverage` | Eine Zeile für den angefragten Capture mit beobachteter Loggingkonfiguration, Capturezustand und vollständigen beobachteten, zugeordneten und unzugeordneten Zeilenzahlen. `CONFIGURATION_OBSERVED` ist kein Vollständigkeitsnachweis; unbekannte Loggingwerte bleiben `UNKNOWN`. |

`InclusiveObservedDurationMs` summiert ausschließlich die bekannten,
nicht negativen Dauern der beobachteten Instanzen desselben Modellobjekts.
Fehlt eine Instanzdauer, bleibt die Summe unbekannt. Die Summe über mehrere
Container und deren Kinder ist keine Paketdauer oder kritische Pfadzeit;
verschachtelte und parallele Laufzeitanteile können sich überlagern.
`IsPartial=1` bleibt für diese importierten Laufzeitbelege erhalten.
Sichtbarkeit, Loggingkonfiguration, Aufbewahrung und der Erfassungszeitpunkt
begrenzen den Befund auch bei einer am Captureende abgeschlossenen Ausführung.
Die Procedure nimmt keine Änderungen an Logging oder Paketkonfiguration vor.

Die Zuordnung und Aggregation verwenden alle validierten Beobachtungen vor
`@MaxZeilen`. Eine Ausgabekürzung verändert die Zählungen in
`executionCoverage` nicht. Die bestehenden Größen- und Zeitgrenzen gelten
weiter. Ohne gültige Capturebindung bleiben die statischen Modellangaben
nutzbar; die Objektzusammenfassung bleibt leer und die Abdeckung nennt
`UNPROVEN`. Der manuelle Windows-Test verwendet eigene synthetische
Katalogobjekte in einer ausdrücklich vorhandenen SSISDB-Umgebung und entfernt
nur diese Consumerobjekte. Er provisioniert oder entfernt keine Labumgebung.
Der Testschalter `-IterationCases` ergänzt die mit dem SDK erzeugte For- und
Foreach-NodeList-Fixture; `-LoggingLevel 1` beziehungsweise `3` wählt Basic
oder Verbose. Nur der Testautor benötigt .NET Framework x64 sowie die
passenden SDK-Assemblies `Microsoft.SqlServer.ManagedDTS.dll` und
`Microsoft.SqlServer.ForEachNodeListEnumerator.dll`. Die native Abnahme dieser
Erweiterung bezieht sich auf Windows SQL2025 und diese synthetischen Pakete;
andere Engines und Enumeratorprofile werden dadurch nicht pauschal qualifiziert.

## Optionale lokale SQL-Metadatenprüfung

`@IncludeSqlMetadata=1` ergänzt `sqlMetadata`. Die Standardausgabe bleibt bei
acht Gruppen; Metadaten allein liefern neun, zusammen mit Paketsichten und
Objektregeln fünfzehn RAW-Gruppen. Mit zusätzlich aktivierter
Ausführungskorrelation sind es siebzehn Gruppen. CONSOLE bleibt eine Statusgruppe. JSON
verwendet `meta.sqlMetadataSchemaVersion=1`; TABLE akzeptiert `sqlMetadata`
nur bei aktiviertem Flag. Ohne Flag muss `@SqlMetadataBindingsJson` leer bleiben.

Der Caller ordnet vorhandene Modellspalten ausdrücklich lokalen SQL-Spalten
zu. Das Dokument besitzt genau `contract="ssis-sql-metadata-bindings"`,
`version="1.0.0"`, den `packageSha256` des aktuellen Modells und `bindings`.
Dieses Array enthält eine bis höchstens 1000 flache Zuordnungen mit jeweils
genau sieben Feldern:

| Feld | Vertrag |
|---|---|
| `bindingId` | Eine eindeutige ASCII-Kennung mit höchstens 64 Zeichen aus Buchstaben, Ziffern und `_.:-`. |
| `nodeId` | Die genaue ID eines vorhandenen `COLUMN`-Knotens dieses Modells. |
| `databaseName` | Der ausdrücklich benannte lokale Datenbankname; es gibt keinen impliziten CURRENT-Scope. |
| `schemaName`, `objectName`, `columnName` | Je ein nicht leerer SQL-Bezeichner mit höchstens 128 UTF-16-Codeeinheiten. |
| `keySetId` | `null` ohne Schlüsselprüfung oder eine ASCII-Kennung wie `bindingId`; derselbe Satz bezeichnet genau ein SQL-Objekt und enthält jede SQL-Spalte höchstens einmal. |

Der Importer validiert den gesamten maximal 16 MiB großen Zuordnungsvertrag
vor dem ersten Katalogzugriff. Er löst keine Connection Strings, Expressions,
Lookupabfragen oder Paket-SQL auf. Nur ausdrücklich benannte sichtbare
Datenbanken werden gelesen. Der Datenbankbezeichner stammt aus dem geprüften
lokalen Katalog und wird mit `QUOTENAME` geschützt; Objekt- und Spaltennamen
bleiben Daten. Vergleich ist ordinal einschließlich Länge. Der Caller benötigt
Zugriff auf die jeweiligen Datenbanken und Sichtbarkeit der betreffenden
Metadaten. EXECUTE allein erweitert diese Rechte nicht.

`sqlMetadata` liefert beobachtete Objekt-/Spalten-IDs, deklarierten SQL-Typ mit
Schema, Längen in Bytes, Präzision, Skala, Collation, Nullable-/Computed-/Identity-
Eigenschaften und Beobachtungszeit. `ModelTypeCode` bleibt der unveränderte
Producerwert. `NullableAgreement` vergleicht nur zwei bekannte Nullablewerte;
fehlende Werte bleiben `UNKNOWN`. `TypeCompatibilityStatus=NOT_QUALIFIED`
erteilt keine Konvertierungs- oder Ladefreigabe. Dadurch entsteht in Analyze
keine zweite SSIS-Typenregelpflege.

`UNIQUE_INDEX_OBSERVED` verlangt einen sichtbaren, aktivierten, nicht
hypothetischen und ungefilterten Unique Index mit genau der ausdrücklich
angegebenen Schlüsselspaltenmenge. Include-Spalten zählen nicht zum Schlüssel.
Ein zusammengesetzter Schlüssel beweist keine Eindeutigkeit einer Teilmenge;
gefilterte und deaktivierte Indizes qualifizieren den Satz nicht. Fehlende
Sichtbarkeit ergibt `SQL_OBJECT_NOT_VISIBLE` beziehungsweise
`SQL_COLUMN_NOT_VISIBLE`, keinen Nachweis einer tatsächlichen Objektabwesenheit.

Die Zuordnung bleibt `CALLER_EXPLICIT`, die Evidenz `LOCAL_CATALOG_METADATA`.
Paketdigest und Producervertrauen werden mitgeführt. Die Katalogbeobachtung
unter NOLOCK bleibt partiell und ist bei gleichzeitiger DDL kein konsistenter
Datenbanksnapshot. Es gibt keine Datenscans, GRANTs, DDL oder Paketabfragen.
Fehler eines Datenbankzugriffs bleiben in dieser Quelle; ungültige Zuordnungen
liefern leere Metadaten und erhalten das gültige statische Modell. Das
gemeinsame Zeitbudget bleibt wirksam. `@MaxZeilen` kürzt erst nach der
Prüfung aller Schlüsselmitglieder und kennzeichnet eine Kürzung.

## Kindpaket- und Ereignishandlerkorrelation

`@IncludeExecutionScopes=1` ist ein eigener, exklusiver Ausgabemodus. Er verlangt
`@ProjectModelsJson`, `@ScopeSnapshotJson`, `@ScopeHandoverId` und `@ExecutionId`;
die bisherigen Modell-, Regel-, Metadaten- und Korrelationsopt-ins werden dabei
nicht kombiniert. Ohne diesen Schalter bleiben die bisherigen Verträge erhalten.
Der SQL-Empfänger verwendet ausschließlich JSON und lokale Herkunftsbelege und
benötigt weder SQL CLR noch eine Toolbelt-Installation.

Der externe Katalogadapter erhält `-IncludeExecutionScopes` und führt einen
gebundenen, lesenden SSISDB-Batch aus. Vorher-/Nachherprüfung, Projekt-LSN,
Katalogdatenbankkennung und Execution-ID sichern den Quellenbezug. Nur die zur
Ausführung unverändert aktuelle Projektversion ist zulässig. Aus diesem Archiv
exportiert genau der freigegebene Toolbelt-Host die erreichbaren Pakete; jeder
Paketdigest, unveränderte Einzelmodelle und Sidecars 1.2.0 gehen in einen
hashgebundenen Paketsatz ein. Eine erneute Projektbereitstellung erlaubt keinen
Import aktueller Bytes als Modell einer historischen Ausführung.

Der lokale Attestor benötigt ALTER-Recht auf die Analyseprocedure. Seine
zeitlich begrenzte Registrierung bindet die exakten UTF-16-JSON-Dokumente.
Diese administrative Autorität, der geprüfte Hostbuild und dessen Runtime sind
die Vertrauenswurzel. Ein JSON-Trustflag oder gewöhnliches EXECUTE genügt nicht.
Der gespeicherte Capture bleibt nach einem Redeployment zeitbezogener Beleg
seiner Aufnahme; er behauptet keine aktuelle Projektversion.

| Ergebnisgruppe | Bedeutung einer Zeile |
|---|---|
| `scopeBinding` | Bindungsstatus, qualifizierte Wurzel und Herkunft dieses Captures. |
| `packageScopes` | Ein erreichbares Paketmodell mit eigener `PackageKey` und Bytehash. |
| `packageInvocations` | Eine eindeutig belegte Paketwurzelstatistik mit Elterninstanz und aufrufender Statistik-ID. |
| `scopeObservations` | Eine unveränderte Statistik- oder Ereignisidentität mit beobachteten Pfaden und optionaler Modellzuordnung. |
| `handlerActivity` | Ein dem Handlerkörper zugeordneter Einzelbeleg mit Handler- und Eigentümerknoten. |
| `scopeObjectSummary` | Beobachtete Statistikanzahlen und inklusive Dauern genau eines paketgebundenen Modellknotens. |
| `scopeCoverage` | Vollständige Quell- und Zuordnungszahlen vor dem Ausgabelimit, Logging-Level und Capturestatus. |

`CONSOLE` liefert eine fachliche Bindungsausgabe, `RAW` sieben typisierte
Resultsets, `TABLE` die ausdrücklich benannten lokalen Seed-Ziele und `NONE`
keine Resultsets. JSON wird ausschließlich über OUTPUT geliefert und enthält
`executionScopesSchemaVersion=1`. `@MaxZeilen` begrenzt jede Ergebnisgruppe erst
nach Validierung und Korrelation. `OutputTruncated` kennzeichnet eine Kürzung;
die Abdeckungszahlen bleiben dabei auf den gesamten Capture bezogen.

Unterstützt sind feste projektlokale Execute Package Tasks desselben Archivs,
Kind- und Enkelpakete sowie `OnPreExecute`, `OnPostExecute` und `OnError`.
Wiederholte, parallele und schleifengebundene Aufrufstellen benötigen exakte
beobachtete Pfade. GUIDs gelten innerhalb ihres Pakets; gleiche GUIDs in zwei
Paketen werden nicht zusammengeführt. Identische mehrdeutige Instanzpfade
bleiben unzugeordnet. Dynamische Ziele, externe Projekte, Datei-/MSDB-Pakete,
rekursive Aufrufe und andere Handlerereignisse sind nicht qualifiziert.

Ein Handlerkörper kann durch propagierte Ereignisse mehrfach denselben Pfad
besitzen. Seine Statistik- und Ereigniszeilen bleiben getrennte Belege.
`TriggerEventMessageId` bleibt unbekannt und `CausalityStatus=UNPROVEN`:
Ereignisname, Zeitnähe und Meldungstext beweisen keinen konkreten Auslöser.
Der Adapter übernimmt keine Meldungstexte oder Parameterwerte. Fehlende
Beobachtungen beweisen keine Nichtausführung. `IsPartial` bleibt wahr; Dauern
werden nicht über Objekte zu einer Paketlaufzeit addiert. Bei unbekannten oder
negativen Einzeldauern bleibt die betreffende Dauersumme unbekannt.

Der Paketsatz ist auf 16 Pakete, acht Aufrufebenen, 1024 Instanzen und zusammen
50000 Statistik-/Ereigniszeilen begrenzt. Archive enthalten höchstens 10000
Einträge, 64 MiB expandierte Paketbytes und 16 MiB je Paket; beide JSON-Dokumente
haben jeweils ein 16-MiB-Limit. Export und Modellvalidierung teilen 60 Sekunden;
der SQL-Consumer verwendet das angegebene kooperative Zeitbudget. Der
Locktimeout wird nach Eintritt in den Consumer geprüft, angewendet und
wiederhergestellt. Sperren vor dem Eintritt in eine SQL-Procedure benötigen
wie bei anderen SQL-Aufrufen einen begrenzten Caller- oder Clienttimeout. Parser,
Komponentenprofile und paketübergreifende Daten-/Parameterlineage werden nicht
in Analyze nachgebaut; solche Lineage ist nicht Bestandteil dieses Modus.

## Primärquellen

- [Freigegebener projektübergreifender Vertrag](../../Architecture/SSIS_Analyze_Toolbelt_Exchange_Contract.md)
- [Austauschschema](../../../Metadata/Quality/SSIS_Exchange_V1.schema.json)
- [Resultsetinventar](../../../Metadata/Inventory/ResultSets.csv)
- [SSISDB-Ausführungen](https://learn.microsoft.com/en-us/sql/integration-services/system-views/catalog-executions-ssisdb-database)
- [SSISDB-Executable-Statistiken](https://learn.microsoft.com/en-us/sql/integration-services/system-views/catalog-executable-statistics)
- [Indexkatalog](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-indexes-transact-sql)
- [Indexspalten und Metadatensichtbarkeit](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-index-columns-transact-sql)

[Technische Detailbeschreibung](../../Architecture/SSIS_Analyze_Toolbelt_Exchange_Contract.md)
