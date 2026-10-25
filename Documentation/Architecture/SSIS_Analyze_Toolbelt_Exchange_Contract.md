# SSIS Abgrenzung und Austausch zwischen Analyze und Toolbelt

**Status:** Vertrag 1.0.0 vom 24. Oktober 2026, durch ausdrücklichen Benutzerauftrag zur Umsetzung in beiden Projekten freigegeben. Erster Implementierungsschritt: 25. Oktober 2026.

**Geltung:** Zielarchitektur für den SSIS-Paketpfad; die bestehenden SQL-Schnittstellen bleiben unverändert.

**Artefakt-UID:** `urn:uuid:01a16fd0-76d2-763d-aea4-b034dd939d3b`. Die Registrierung erfolgt im Modus `DEFERRED`; eine finale lesbare Referenz ist noch nicht vergeben.

Analyze verantwortet die Diagnose von Paketdefinitionen und Laufzeitbeobachtungen.
Toolbelt verantwortet die vertiefte neutrale Paketinterpretation und die Erzeugung
von T-SQL-Prüfstufen. Ein optional übergebenes JSON-Modell verbindet beide
Aufgaben. Analyze benötigt dafür weder eine CLR-Assembly noch eine installierte
Toolbelt-Datenbank oder eine Verbindung zum Erzeuger.

Der Benutzerauftrag „Ich gebe den Vertrag frei. Setze ihn schrittweise in Analyze
und Toolbelt um“ autorisiert die beschriebenen Änderungen in beiden Projekten.
Der erste Schritt ergänzt den gemeinsamen typisierten Toolbelt-Kern, den externen
Exporthost und den nativen Analyze-Importer. Bestehende öffentliche Schnittstellen
bleiben erhalten; ihre bisherigen Ausgabe- und Sicherheitsverträge gelten weiter. Zum Lesen der aktuellen Funktionen führt der
[SSIS-Leitfaden](../Analysis_Guides/10_SSIS.md); das
[Austauschschema](../../Metadata/Quality/SSIS_Exchange_V1.schema.json) und ein
[synthetisches Beispiel](../../Metadata/Quality/SSIS_Exchange_V1.example.json)
konkretisieren das Transportformat.

## Zuständigkeiten und kanonische Quellen

| Aufgabe | Verantwortliches Projekt | Grenze |
|---|---|---|
| Begrenztes direktes Inventar aus bereits übergebenem XML | Analyze | Der bestehende T-SQL-Pfad bleibt eigenständig. Er liest Definitionen und direkte Kanten, interpretiert aber keine Komponenten- oder Ausdruckssemantik. |
| DTSX-Formatprofile, Komponentenprofile, typisierte Expressionreferenzen und Spaltenmodelle | Toolbelt | Ein kanonischer Kern verarbeitet diese Semantik für Export und Generator. Analyze implementiert keinen zweiten vertieften Parser. |
| Direkte Spaltenzuordnungen sowie abgeleitete Wert- und Zeilenabhängigkeiten | Toolbelt | Herkunft, Ableitungsregel und Teilabdeckung werden exportiert. Analyze rekonstruiert diese Beziehungen nicht aus SQL, Anzeigenamen oder CTEs. |
| Bindings, Vergleichsprofile, Lookupauswahl und T-SQL-Prüfstufen | Toolbelt | Generatorartefakte bleiben vom neutralen Paketmodell getrennt. Pragmatische SQL-Semantik wird nicht zu einer SSIS-Eigenschaft umgedeutet. |
| SSISDB- und Legacy-Protokolle, Laufzeiten, Meldungen und beobachtete Zeilenflüsse | Analyze | Toolbelt erhält dafür keinen zweiten Logdecoder oder Diagnosekatalog. |
| Risiko-, Performance-, Integritäts- und Security-Findings | Analyze | Regeln benötigen benannte statische oder beobachtete Evidenz. Generatorfehler und eigene Sicherheitsprüfungen bleiben bei Toolbelt. |
| Datei-, ZIP- und optionale ISPAC-Zulieferung | Getrennte Quellenadapter | Kein Importadapter öffnet Dateien, Netzwerkverbindungen oder Paket-Connection-Strings. Ein allgemeiner Datei-/ZIP-Helper ist kein ISPAC-Resolver. |

Die gemeinsame Regel lautet: XML-Syntax zu lesen ist noch keine semantische
Paketinterpretation. Das kleine native Inventar ist eine begrenzte Ausnahme von
der gemeinsamen Parserpflege. Seine Extraktionsregeln und gemeinsamen Sollfälle
werden einmal beschrieben; seine T-SQL-Implementierung bleibt in Analyze.
Komponentenprofile, Expressionauswertung, Spaltenauflösung und transitive Lineage
werden ausschließlich im Toolbelt-Kern gepflegt. Eine vollständige zweite
Semantikimplementierung zur Parität des nativen Pfads ist ausgeschlossen.

Die kanonische fachliche Abgrenzung liegt in diesem Dokument. Toolbelt pflegt
Schema, Format-/Lineageprofile und gemeinsame synthetische Sollfälle unter
`Modules/toolbelt.tsql.ssis-debug/Contracts/Exchange/`. Analyze übernimmt die
Dateien unverändert mit `Code/Tools/Sync_Ssis_Exchange_Contract.py`; die lokale
Provenienzdatei bindet vollständigen Toolbelt-Commit, Quellpfade und SHA-256.
Der Checkmodus benötigt nur die lokale Übernahme und kein Nachbarrepository.
Änderungen werden zuerst an der kanonischen Quelle vorgenommen. Analyze
implementiert weder eine zweite Feldliste noch eigene Parser-/Lineageregeln;
`Build_Ssis_Exchange_Rules.py` leitet seine Feldprüfungen aus der Schemakopie ab.
Der Toolbelt-Moduleinstieg verweist auf diesen Vertrag zurück.

## Betriebswege ohne obligatorische CLR

1. **Eigenständige Inventur:** `[monitor].[USP_SsisPackageAnalysis]` verarbeitet
   weiterhin nur `@PackageXml`. Ohne Austauschmodell bleiben Paket-, Task-,
   Variablen- und direkte Graphinformationen im heutigen Umfang verfügbar.
   Fehlende vertiefte Lineage ist eine Capability-Grenze und kein Installationsfehler.
2. **Optionale Modellanalyse:** Ein Caller übergibt das JSON-Modell an den
   nativen T-SQL-Importadapter `[monitor].[USP_SsisPackageModelAnalysis]` in Analyze. Der Adapter validiert und
   materialisiert das Modell, bevor fachliche Regeln darauf zugreifen. Er ruft
   weder CLR noch Toolbelt auf. Fehlende Producerdaten lösen keinen Download,
   Remoteaufruf oder automatischen Wechsel zum XML-Pfad aus.
3. **Modellerzeugung:** Toolbelt gewinnt das neutrale Modell aus seinem
   kanonischen Kern. Der bestehende SQL-CLR-Generator und ein gesondert zu
   qualifizierender externer Host verwenden denselben Kern. Ein externer Host
   ermöglicht die Zulieferung ohne CLR auf dem Analyze-Server; der erste Host ist als .NET-10-Anwendung implementiert. Seine Windows-
   Ausführung ist getrennt von der CLR-Fassade geprüft. Ein Linux-Hostlauf und
   die Veröffentlichung bleiben eigenständige Nachweise.

Das bestehende Toolbelt-Modul `toolbelt.tsql.ssis-debug` bleibt ein separater
Windows-/CLR-Generator. Es wird weder in den Analyze-Installer aufgenommen noch
vom Analyze-Setup installiert, aktiviert oder als Assembly vertraut. Für den
nativen Import bleibt SQL Server 2019 oder neuer mit Compatibility Level 150
oder höher das zu qualifizierende Ziel; Linux benötigt keinen CLR-Sonderpfad.

## Austauschformat und Versionsregeln

Das JSON-Dokument verwendet `contract = "ssis-package-model"`,
`version = "1.0.0"` und `identityProfile = "document-order-v1"`.
JSON-Eigenschaftsnamen und Kennungen sind ordinal case-sensitiv zu vergleichen;
eine Datenbankcollation darf ihre Bedeutung nicht verändern. Doppelte
Eigenschaftsnamen werden auf jeder Objektebene abgelehnt. Alle Pflichtfelder,
leeren Arrays und expliziten NULL-Werte werden übertragen.

| Feld | Bedeutung |
|---|---|
| `producer` | Produktkennung, Produktversion, vollständiger Source-Commit und SHA-256 des tatsächlich verwendeten Builds. Die Angaben beschreiben die Herkunft; sie authentifizieren den Erzeuger nicht. |
| `source` | SHA-256 und Länge der ursprünglichen DTSX-Dateibytes, beobachteter Paketformatwert und erkanntes XML-Profil. Ein Name oder eine DTSID ersetzt diese Bindung nicht. |
| `profiles` | Versionen der Format-, Komponenten- und Lineageregeln. Sie sind unabhängig von der Produkt- und Transportversion. |
| `coverage` | Genau ein Eintrag je definierter Capability mit Zustand und gegebenenfalls einem Begrenzungsgrund. |
| `nodes` | Objekte mit paketlokaler Kennung, Art, Besitzer, optionalem Anzeigenamen und typisierten Metadaten. |
| `edges` | Gerichtete Beziehungen mit Scope, Auflösungsstatus und deklarierter oder abgeleiteter Evidenz. |
| `diagnostics` | Begrenzte Parsercodes mit optionalem Objektbezug; keine operativen Findings oder freien Quellfehlermeldungen. |

Das Schema ist für V1 geschlossen. Ein Consumer unterstützt ausdrücklich
benannte Versionen; er lehnt andere Versionen ab und entfernt unbekannte Felder
nicht stillschweigend. Jeder geänderte Feld- oder Enumerationsumfang erhält eine
neue Minorversion und eine explizite Consumerfreigabe. Bedeutungsänderungen,
entfernte Felder oder neue Identitätsregeln benötigen eine Majorversion.
Eine reine redaktionelle Korrektur darf die Patchversion ändern, ohne neue
Nutzdatenformen einzuführen. Die Schemaversion der bestehenden Analyze-Resultsets
ist davon unabhängig.

## Paketbindung und Vertrauen

`source.packageSha256` ist der SHA-256-Wert der unveränderten Originalbytes,
einschließlich Encoding, BOM und Zeilenenden. Der Hash wird nicht aus einem
neu serialisierten SQL-`xml`-Wert berechnet. Abweichende Dateibytes erzeugen eine
andere Paketrevision; V1 besitzt keine XML-Kanonisierung. Die Dateilänge wird
zusätzlich geprüft und ist kein Ersatz für den Hash.

Der Importadapter erhält optional die Originalbytes als separaten
Callerparameter `@PackageBytes`. Mit diesen Bytes berechnet er Hash und Länge selbst. Das
Ergebnis heißt `PACKAGE_BYTES_MATCH` oder `PACKAGE_BYTES_MISMATCH`; ohne die
Bytes lautet es `DECLARED_ONLY`. Bei Mismatch wird das Modell vor fachlicher
Auswertung verworfen. Ein nur im JSON wiederholter Hash gilt nicht als
unabhängige Gegenprüfung. Der heutige XML-Parameter wird dafür nicht umgedeutet.

Auch `PACKAGE_BYTES_MATCH` beweist nur, dass die deklarierte Paketrevision mit
den Callerbytes übereinstimmt. Es beweist weder, dass das Modell daraus richtig
abgeleitet wurde, noch dass es unverändert vom angegebenen Erzeuger stammt.
`producerTrust` bleibt deshalb standardmäßig `UNVERIFIED`. `VERIFIED_LOCAL`
setzt einen vom Caller unabhängig belegten, qualifizierten Producerbuild und
eine nachvollziehbare lokale Übergabe genau dieses Ergebnisses voraus. Eine
Build-Allowlist oder ein selbst behauptetes Signaturfeld allein reicht nicht.
V1 definiert keine Fernsignatur oder automatische Vertrauensregistrierung.

Importierte Daten bleiben statische Producerbehauptungen. Analyze kennzeichnet
ihre Herkunft, Vertrauensstufe und Paketbindung an den davon abhängigen Findings;
ohne belegte Herkunft darf daraus keine bestätigte Betriebs- oder
Gesundheitsaussage entstehen. Native Logs bleiben eigenständige Quellen.
Eine spätere Korrelation benötigt zusätzlich eine belegte Bindung der konkreten
Ausführung an genau diese Paketrevision und eindeutige Objektzuordnungen.
Gleiche Namen, Zeitnähe, eine Execution-ID oder eine gleiche DTSID allein reichen
nicht. Fehlende Bindung erhält `RUNTIME_BINDING_UNPROVEN` und erzeugt keine
Laufzeit-Lineage.

## Objektkennungen und Beziehungen

Die Identität eines Modellobjekts ist das Tupel aus Paketbytehash,
`identityProfile` und `id`. V1 nummeriert Objekte getrennt nach Art in ihrer
XML-Dokumentreihenfolge: `pkg1`, `exe1`, `cmp1`, `port1`, `col1`, `var1`,
`par1`, `con1` und `expr1`. Das Paket besitzt genau `pkg1`. Wiederholte Namen
oder originale Lineagewerte werden nicht zusammengeführt. Kennungen bleiben
bei gleichen Bytes und gleichem Identitätsprofil reproduzierbar; über
Paketänderungen hinweg sind sie keine dauerhaften Projektkennungen.

`document-order-v1` verwendet den Namespace
`DTS = www.microsoft.com/SqlServer/Dts`; Pipelineelemente besitzen keinen
Namespace. Die folgende Auswahl legt das Objektuniversum unabhängig von
Komponentenunterstützung und angeforderter Coverage fest:

| Art | XML-Auswahl für die Zählung |
|---|---|
| Paket | Das `DTS:Executable`-Wurzelelement wird ausschließlich `pkg1`. |
| Executable | Alle weiteren `DTS:Executable`-Elemente und alle `DTS:EventHandler`-Elemente werden gemeinsam in Dokumentreihenfolge gezählt. |
| Komponente | Jedes `component` direkt unter `DTS:ObjectData/pipeline/components` wird gezählt. |
| Port | Direkte `input`- und `output`-Elemente unter den `inputs` beziehungsweise `outputs` einer gezählten Komponente werden gemeinsam gezählt. |
| Spalte | Direkte `inputColumn`, `outputColumn` und `externalMetadataColumn` unter `inputColumns`, `outputColumns` beziehungsweise `externalMetadataColumns` eines gezählten Ports werden gemeinsam gezählt. |
| Variable | Jede `DTS:Variable` direkt unter `DTS:Variables` wird gezählt, einschließlich Event-Handler-Bereichen. |
| Parameter | Jede `DTS:PackageParameter` direkt unter `DTS:PackageParameters` des Wurzelpakets wird gezählt. Externer Projektkontext gehört nicht zur Byteidentität. |
| Connection | Jeder direkte `DTS:ConnectionManager` unter `DTS:ConnectionManagers` wird gezählt. |
| Expression | Alle `DTS:PropertyExpression`-Elemente und alle namespacefreien `property`-Elemente mit exakt `name="Expression"` unter einer gezählten Komponente werden gemeinsam gezählt. Nicht interpretierbare Kandidaten behalten ihre Kennung. |

Der Producer reserviert diese IDs vor Profil- und Capabilityfilterung. Nicht
exportierte Objekte hinterlassen Lücken; vorhandene IDs werden nicht neu
nummeriert. Attribute mit Ausdruckswerten erzeugen in V1 keine zusätzlichen
Expressionobjekte und begrenzen gegebenenfalls `expressionReferences`.
Event Handler verwenden `isEventHandler = true`; struktureller Besitzer ist
jeweils der nächste erfasste Vorfahr. Eine Änderung dieser Auswahl oder
Klassifikation verlangt ein neues Identitätsprofil und eine Vertragsmajorversion.
Bei fehlenden beziehungsweise verschlüsselten XML-Teilen wird keine
Identitätskontinuität zu einem entschlüsselten Artefakt behauptet.

`parentId` bezeichnet den strukturellen Besitzer. Executables gehören zu Paket
oder Executable, Komponenten zu Executable, Ports zu Komponenten und Spalten
zu Ports. Variablen gehören zu Paket oder Executable; Parameter und Connections
zu Paket; Expressions zu ihrem definierten Besitzer. Das Paket hat keinen
Parent. Alle übrigen Parents müssen existieren; Besitzzyklen sind ungültig.
Anzeigenamen sind ausschließlich Beschriftungen.

`attributes` besitzt je Art die folgende abgeschlossene Feldmenge. Alle
genannten Felder werden mit ihrem beobachteten Wert oder explizitem NULL
übertragen; andere Attribute sind unzulässig. `typeCode` bewahrt den nativen
DTSX-Typcode als Zeichenfolge und wird nicht mit einem SQL-Typ gleichgesetzt.
`length` behält die für diesen SSIS-Typ geltende Einheit. `columnRole` trennt
Daten- von externen Metadatenspalten; unbekannte Typmetadaten bleiben NULL.

| Art | Attribute |
|---|---|
| Paket | `protectionLevel` |
| Executable | `executableType`, `isDisabled`, `isEventHandler` |
| Komponente | `componentClassId` |
| Port | `direction`, `portRole`, `synchronousInputPortId` |
| Spalte | `columnRole`, `typeCode`, `length`, `precision`, `scale`, `codePage`, `isNullable` |
| Variable | `namespace`, `typeCode`, `isReadOnly`, `evaluateAsExpression` |
| Parameter | `typeCode` |
| Connection | `connectionKind` |
| Expression | `propertyName` |

| Beziehung | Richtung und Scope | Bedeutung |
|---|---|---|
| `CONTROL_FLOW` | Executable zu Executable im gemeinsamen Paket-/Container-Scope | Eine deklarierte direkte Ablaufkante; keine beobachtete Ausführung. |
| `PIPELINE_PATH` | Output-Port zu Input-Port im selben Data-Flow-Executable | Eine deklarierte direkte Pipelinekante. |
| `COLUMN_MAP` | Spalte zu Spalte im selben Data Flow | Eine direkte deklarierte Zuordnung; keine automatische Gleichheit der Werte oder Typen. |
| `VALUE_DEPENDENCY` | Einflussgebendes Objekt zur beeinflussten Spalte | Die Zielwerte hängen nach der benannten Regel vom Quellobjekt ab. |
| `ROW_DEPENDENCY` | Einflussgebendes Objekt zum beeinflussten Port oder zur Spalte | Die Zugehörigkeit einer Zeile hängt vom Quellobjekt ab, etwa durch Lookup oder Split. |
| `EXPRESSION_REFERENCE` | Variable oder Parameter zur Expression | Eine gebundene Referenz; kein exportierter Wert und keine Ausführungsbehauptung. |

`COLUMN_MAP` besitzt zusätzlich `mappingRole`: `DATA_TRANSFER` bezeichnet
eine deklarierte Datenzuordnung, `METADATA_REFERENCE` einen Verweis auf externe
Metadaten. Andere Beziehungstypen verwenden NULL. Eine Metadatenreferenz allein
erzeugt keine Wertabhängigkeit. Direkte Kanten werden in XML-Dokumentreihenfolge
nummeriert. Danach folgen abgeleitete Kanten ordinal sortiert nach
`kind`, `scopeId`, `fromId`, `toId` und `ruleId`, mit NULL vor Zeichenfolgen.
Mehrfach deklarierte Kanten bleiben getrennt; gleiche abgeleitete Tupel werden
einmal exportiert. Die Ausgabe verwendet anschließend `edge1`, `edge2` und
fortlaufende Nummern. Edge-IDs gelten nur innerhalb dieses Modells.

Einflussgebende Objekte sind Spalten, Variablen oder Parameter. `scopeId`
referenziert für Datenflussbeziehungen das gemeinsame Data-Flow-Executable und
für Expressionreferenzen deren Paket-/Executable-Scope. Der Importer prüft
Objektarten, Besitz und Scope zusätzlich zum JSON-Schema. Spalten verschiedener
Ports bleiben auch bei gleichen Namen eigene Objekte.

`evidence = "DECLARED"` bezeichnet direkt gelesene Strukturen und verwendet
`ruleId = null`. `DERIVED` verlangt eine bekannte, versionierte `ruleId` aus dem
Toolbelt-Lineageprofil. Der Producer liefert direkte und abgeleitete
Abhängigkeiten; der Consumer führt keine eigene transitive Closure oder
Komponenteninterpretation aus. Toolbelt beschreibt jede zugelassene Regel
einmal mit Eingangsobjekten, Ausgaberichtung, Vorbedingungen und Sollfällen.
Eine nicht bekannte Regel bleibt als nicht interpretierte Beziehung sichtbar
und sperrt davon abhängige Regeln in Analyze.

Das vorgeschlagene Lineageprofil `1.0.0` erlaubt genau die folgenden
Ableitungsregeln. Ihre Qualifikation gehört zur Producerumsetzung. Andere
Regeln benötigen eine neue Profilversion und eine explizite Consumerfreigabe.

| `ruleId` | Beziehung und notwendige Vorbedingung |
|---|---|
| `MAPPED_VALUE_INPUT` | Eine aufgelöste `COLUMN_MAP` mit `mappingRole = DATA_TRANSFER` zwischen Datenspalten begründet die gleichgerichtete `VALUE_DEPENDENCY`. Dies behauptet keine Werterhaltung bei Konvertierungen. |
| `BOUND_EXPRESSION_INPUT` | Eine vollständig gebundene unterstützte Spaltenexpression begründet für jede syntaktisch referenzierte Spalte, Variable oder jeden Parameter eine `VALUE_DEPENDENCY` zur Ausgabespalte. Dynamische oder nicht aufgelöste Referenzen verhindern diese Ableitung. |
| `LOOKUP_ROW_SELECTION` | Ein qualifiziertes Lookup-Profil mit tatsächlich filterndem Match-/No-Match-Ausgang begründet vom wirksamen Eingangsschlüssel eine `ROW_DEPENDENCY` zum betreffenden Ausgangsport. Ein Lookup, der alle Zeilen weitergibt, erfüllt diese Vorbedingung nicht. |
| `SPLIT_ROW_SELECTION` | Ein qualifiziertes Split-Profil begründet von den gebundenen Eingaben der wirksamen, nach Priorität berücksichtigten Bedingungen eine `ROW_DEPENDENCY` zum betreffenden Ausgangsport. Nicht unterstützte NULL-/Fehlerdispositionen begrenzen die Abdeckung. |

V1 exportiert diese direkten Abhängigkeiten und keine transitive Closure.
Eine transitive Erweiterung würde ebenfalls im Toolbelt-Kern qualifiziert;
Analyze ergänzt sie nicht selbst. Vollständige Abdeckung eines Features
erfordert sämtliche in seinem Profil vorgeschriebenen Beziehungen für alle
betroffenen Objekte, nicht nur erfolgreich interpretierte Einzelkanten.

Eine nicht auflösbare Beziehung enthält mindestens einen bekannten Endpunkt,
setzt den unbekannten auf NULL und verwendet `resolution = "UNRESOLVED"` oder
`"UNSUPPORTED"`. Sie verweist nicht auf eine erfundene Platzhalter-ID. Eine als
`RESOLVED` bezeichnete Beziehung braucht beide vorhandenen Endpunkte. Der
Consumer darf unaufgelöste Beziehungen nicht als bestätigte Herkunft darstellen.

Die `ColumnLineage` des heutigen Generators ist kein fertiger V1-Export:
SQL-Aliasse, CTE-Stufen und durch Lookup- oder Vergleichspolicies veränderte
Debug-Semantik gehören nicht in den neutralen Graphen. Solche Ableitungen bleiben
Toolbelt-Generatorartefakte mit eigenem Kontext. Der neutrale Export enthält nur
Paketdefinitionen und explizit benannte statische Ableitungen.

## Abdeckung und fehlende Informationen

`coverage` enthält genau die acht Features `inventory`, `controlFlow`,
`pipelineGraph`, `columnMetadata`, `directColumnMapping`, `valueLineage`,
`rowLineage` und `expressionReferences`. Jedes Feature ist `COMPLETE`,
`PARTIAL`, `UNSUPPORTED` oder `NOT_REQUESTED`. Nur `COMPLETE` hat keinen
Begrenzungsgrund. `COMPLETE` bedeutet vollständig im benannten Format- und
Regelprofil, nicht Unterstützung beliebiger SSIS-Funktionen.

Leere Arrays sind nur gemeinsam mit der betreffenden Abdeckung interpretierbar.
Fehlende, verschlüsselte oder unbekannte Bereiche ergeben keinen
Abwesenheitsbeweis. Analyze führt eine Fachregel nur aus, wenn alle von ihr
benannten Features, Objektfelder und Regelversionen ausreichen. Sonst meldet
die Regel die konkrete Evidenzlücke. Bereits gültige unabhängige Bereiche bleiben
nutzbar; ein ungültiger Gesamtvertrag dagegen verwirft den gesamten Import.

Typ-, Längen-, Precision-, Scale-, Codepage- und Nullabilityangaben bleiben
beobachtete Metadaten. Nicht ermittelbare Werte sind NULL; sie erhalten keinen
erfundenen Default. Expressiontexte, SQL-Texte und Literalwerte werden nicht
benötigt, um eine solche Evidenzlücke zu kennzeichnen.

## Importprüfung und Ressourcenschutz

Der native Importadapter prüft in fester Reihenfolge Größe und JSON-Syntax,
Version und Schema, doppelte Keys, Pflichtfeatures, Mengen, Kennungseindeutigkeit,
Referenzen und Besitz, Beziehungstypen und Scope, Profilunterstützung sowie
Paketbindung. Er veröffentlicht erst danach fachliche Mengen. Eine fehlende
optionale Producerqualifikation wird als Vertrauensgrenze ausgewiesen; sie ist
kein Ersatz für die Strukturprüfung.

| Grenze pro Import | V1-Obergrenze |
|---|---|
| JSON in SQL | 16 MiB nach `DATALENGTH` des `nvarchar`-Parameters |
| Separat übergebene Originalbytes | 16 MiB; die im Modell deklarierte Länge darf diese Grenze ebenfalls nicht überschreiten |
| JSON-Verschachtelung / Besitzerhierarchie / interne Tokens | 32 Ebenen / 128 Ebenen / 1.000.000 Tokens; das Rootobjekt zählt als Ebene 1 |
| Objekte / Beziehungen / Diagnosen | 20.000 / 50.000 / 1.000 |
| ID / Anzeigename | 128 ASCII-Zeichen / 256 UTF-16-Codeeinheiten |
| Zeitbudget | Default 30 Sekunden, zulässig 1 bis 60 Sekunden; kooperative Prüfung zwischen Stufen |

Diese Höchstwerte sind Eingangsgrenzen, keine behauptete Kapazitätsmessung.
Profile dürfen kleinere Grenzen verwenden. Überschreitungen werden vor der
Auswertung mit `EXCHANGE_LIMIT_EXCEEDED` abgelehnt; sie erzeugen kein
abgeschnittenes, scheinbar vollständiges Modell. `@MaxZeilen` begrenzt erst die
Ausgabe und niemals den für die Validierung oder Regeln benötigten Graphen.
SQL-Speicher, tempdb und tatsächliche maximale Laufzeiten bleiben zu qualifizieren.

Importcodes sind `EXCHANGE_INVALID`,
`EXCHANGE_VERSION_UNSUPPORTED`, `EXCHANGE_LIMIT_EXCEEDED`,
`EXCHANGE_REFERENCE_INVALID`, `EXCHANGE_PROFILE_UNSUPPORTED`,
`EXCHANGE_SOURCE_MISMATCH` und `EXCHANGE_TIME_BUDGET_EXHAUSTED`. Sie ersetzen
keine heutigen Modulstatuswerte. Der Importer folgt dem bestehenden
Analyze-Vertrag für `CONSOLE|RAW|TABLE|NONE`, benannte Tabellenziele, JSON-OUTPUT,
Status-OUTPUTs und Callerzustand. Die [Procedure-Anleitung](../Analysis_Guides/Procedures/USP_SsisPackageModelAnalysis.md)
und das [Resultsetinventar](../../Metadata/Inventory/ResultSets.csv) beschreiben
die additive API mit acht RAW-Mengen und Schemaversion 1. Die 13 bisherigen
Paketresultsets bleiben unverändert.

## Datenschutz und Seiteneffekte

Das Modell überträgt ausschließlich die im Schema benannten Struktur- und
Typmetadaten. Freie SQL-/Expressiontexte, Parameter-/Variablenwerte,
Connection Strings, Host-/Loginwerte, physische Pfade, Credentials,
Binärpayloads und beliebige Komponentenproperties fehlen. `name` und
`componentClassId` sind beschreibende Metadaten und dürfen keine vom Producer
zusätzlich eingesetzten Laufzeitwerte enthalten. Parserdiagnosen verwenden
geschlossene Codes statt ungeprüfter Quellmeldungen.

Ein Import führt keinen Paket-, SQL-, Datei-, Netzwerk- oder Entschlüsselungsweg
aus. Er erweitert keine Berechtigungen und ändert keine Loggingkonfiguration.
Eine spätere optionale Katalog- oder Lookup-Datenprüfung bleibt eine getrennte,
explizit autorisierte Analyze-Funktion mit deren Ressourcen- und Rechteprüfung.
Ein als sicher markiertes Toolbelt-Skript ist dafür keine Ausführungsfreigabe.

Die Übertragung ist eine vom Caller ausdrücklich gewählte lokale Laufzeitaktion.
Das Modell kann trotz fehlender Secrets vertrauliche Paketstrukturen enthalten.
Reale Modelle, Originalpakete, Fingerprints und Rohbelege bleiben außerhalb von
Repository-, GitHub- und Downloadartefakten. Die JSON-Beispieldatei enthält
ausschließlich synthetische Werte. Das Datenschutz-Liefergate reduziert nicht
die bestehenden vollständigen Diagnoseausgaben aus Legacy-Logs.

## Umsetzung und Abnahme

| Schritt | Verantwortliches Projekt | Abnahmekriterium |
|---|---|---|
| Vertrag annehmen und kanonische Quellen übertragen | Beide Maintainer | Abgrenzung, Schema und gemeinsame Sollfälle besitzen eine Quelle mit unveränderter Übernahmebindung; Toolbelt übernimmt einen Rückverweis auf diesen Vertrag. |
| Neutralen Kern und Export trennen | Toolbelt | Generator und Export verwenden dieselben Parser-/Lineageregeln. Es gibt keine Kopie als eigenständigen CLI-Parser und keine SQL-Debugartefakte im neutralen Modell. Bestehende Generatorfälle bleiben erhalten. |
| Externen Host qualifizieren | Toolbelt | Derselbe Kern erzeugt ohne SQL-CLR-Host dasselbe neutrale Modell. Plattform, Build, Eingaben, Ressourcen und Cleanup werden konkret nachgewiesen. |
| Nativen Import und Diagnoseadapter ergänzen | Analyze | Import, Regelvoraussetzungen und Ausgabe funktionieren ohne Toolbelt-Installation und ohne SQL CLR. Die bestehende Inventur und beide Loganalyzer bleiben unabhängig nutzbar. |
| Gemeinsame Konformität und spätere Korrelation | Beide Projekte | Gemeinsame Parsererwartungen werden einmal gepflegt. Runtimezuordnungen benötigen zusätzliche konkrete Paketversionsbelege. |

Der gemeinsame Zielkatalog umfasst kleine synthetische Pakete für Format 6
und 8, gleiche Namen in mehreren Datenflüssen, geshadowte Variablen, direkte
Mappings, Lookup-/Split-Zeilenabhängigkeit, unbekannte Komponenten,
verschlüsselte Bereiche und nicht aufgelöste Expressions. Jeder Fall beschreibt
erwartete IDs, Kanten, Typen und Coverage. Analyze und Toolbelt übernehmen
denselben Stand dieser Erwartungen; produktbezogene Ausgabe- und
Diagnosetests bleiben in ihrem jeweiligen Projekt.

Der native Import benötigt zusätzlich negative Fälle für manipulierte
Paketbindung, nur selbst behauptete Herkunft, doppelte JSON-Keys und IDs,
Besitzzyklen, fremde Scopes, fehlende Endpunkte, unbekannte Versionen/Regeln,
überlange Eingaben und Zeitbudgetabbruch. Ausgabeparität und unveränderter
Callerzustand werden nach dem Analyze-Vertrag geprüft. Die unabhängige
Inventur ist bei nicht installiertem Toolbelt und ausgeschaltetem CLR zu testen.

Der erste Implementierungsschritt ergänzt Schema-/Beispielprüfung, Navigations- und
Dokumentationsprüfung, Datenschutzprüfung um gemeinsame Producerkonformität, native Importtests und
einen unabhängigen Review der Parser-, Referenz- und Evidenzgrenzen. Produktänderungen
verwenden die [kanonische CI-Teststrategie](../Quality/CI_Test_Strategy.md).
Am 25. Oktober 2026 sind 47 gemeinsame Modellgegenproben, 21 bestehende
Generator-Frameworkfälle und 514 native Generatorassertionen auf Windows
SQL Server 2025 lokal und zentral bestanden. Der native Analyze-Harness
besteht 60 Prüfungen auf Linux SQL Server 2025, einschließlich der eingebetteten
CI-Probe, der gemeinsamen Objekt-/Kanten-Sollwerte, aller Ausgabemodi und des
Callerzustands. Der Import ist ein T-SQL-Modul ohne CLR-Abhängigkeit. Ein
unabhängiger Review mit einem Folgeauftrag zu konkreten Befunden prüfte
gemeinsame Struktur, Referenzen, strikte JSON-Validierung und Evidenzgrenzen.
Diese begrenzten Funktionsnachweise ersetzen weder eine maximale
Ressourcenqualifikation noch einen Linux-Exporthostlauf, SDK-Parität oder
eine neue Produktveröffentlichung. Der weitere Zielkatalog bleibt offen.

## Bestehende Quellen und nächste Entscheidungen

Die unveränderten öffentlichen Analyze-Schnittstellen stehen im
[SSIS-Vertrag](SSIS_001_Phase0_Public_Contract.md). Der
[SSIS-Ausbauplan](SSIS_Package_and_Execution_Analysis_Plan.md) enthält weitere
Zielbilder; dessen spätere Parser-/Lineageabschnitte sind bei Umsetzung dieses
Vertrags gegen die hier festgelegte Zuständigkeit abzugleichen.

Die Toolbelt-Seite wird durch die öffentlichen Verträge für
[Repositorygrenzen](https://github.com/gecompat/SQL_Server_Toolbelt/blob/main/Documentation/Architecture/REPOSITORY_BOUNDARIES.md),
[Debug-SELECT](https://github.com/gecompat/SQL_Server_Toolbelt/blob/main/Documentation/Architecture/SSIS_DTSX_DEBUG_SELECT_V1_CONTRACT.md)
und das [Modulmanifest](https://github.com/gecompat/SQL_Server_Toolbelt/blob/main/Modules/toolbelt.tsql.ssis-debug/module.yaml)
beschrieben. Deren bestehende CLR-/Generatorfreigabe autorisiert keinen neuen
externen Host oder Austausch-API.

Die Annahme durch den Benutzer, kanonische Quellen und additive Import-API sind
festgehalten. Der erste Producer leitet nur `MAPPED_VALUE_INPUT` ab. Nicht
qualifizierte Expression-, Lookup- und Splitableitungen bleiben partiell und
werden nicht durch einen zweiten Analyze-Parser ergänzt. Der Import setzt
`producerTrust` weiterhin ausschließlich auf `UNVERIFIED`; eine spätere
verifizierte lokale Herkunft benötigt eine eigene geschlossene Nachweisanbindung.
