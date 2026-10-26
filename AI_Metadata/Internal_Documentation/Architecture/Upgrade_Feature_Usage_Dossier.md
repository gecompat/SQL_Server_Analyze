# SQL-sichtbare Nutzung veralteter Funktionen und Upgradehinweise

**Status:** Produktkandidat mit abgeschlossenem Vertrags-, Produkt- und Fehlerfallreview; CI-Abnahme offen.
**Artefakt-UID:** `urn:uuid:01a1769e-e5e7-7f0a-bed1-d4b5988cd11f`.
**Registrierung:** `DEFERRED`; keine finale lesbare Arbeitselementkennung vergeben.
**Stand:** 26. Oktober 2026.

## Auftrag, Abdeckung und erster Abschluss

Rang 11 der [Entwicklungsplanung](../Quality/Development_Waves_2026-10.md)
autorisiert die getrennte Bearbeitung von Upgrade- und Plattformdiagnostik.
Der erste hier begrenzte Slice ergänzt native Deprecated-Features-Counter
und eine ausdrücklich begrenzte Konfigurationsregel für eine gewählte Zielversion.
Ein Implementierer und ein unabhängiger Reviewer bearbeiten einen kohärenten PR;
Die Vertragsprüfung ist abgeschlossen. Die Datei-I/O-Welle PR #458 ist
mit ihren getrennten Head- und Main-Gates integriert.

DatabasePortabilityAnalysis inventarisiert persistierte Edition-Features und
uncontained dependencies. ServerFeatureCapabilities beschreibt sichtbare
Fähigkeiten; ServerVersionInformation liefert Build-/Lifecyclekontext.
OSInformation liest SQL-sichtbare Host-, Speicher- und Dienstinformationen.
Diese Pfade werden wiederverwendet und nicht als fehlende Implementierung gezählt.
Sie liefern bisher keine gezielte Deprecated-Usage-Auswertung.

Linux-cgroup-, mssql-conf-, Kubernetes-/Host- und externe Client-/Treibernachweise
bleiben ein eigener abgegrenzter Scope. Die bereits separat bearbeiteten
SSIS-Wellen und deren erhaltene SSISDB gehören nicht zu diesem Dossier.

## Beobachtung und Aussagegrenze

Der native Deprecated-Features-Counter beschreibt Begegnungen der Engine seit
dem letzten SQL-Serverstart. Je Funktion können bereits Kompilierungen zählen.
Ein Wert ist weder Ausführungsanzahl noch Dauer oder Datenbankzuordnung. Ein
Nullwert und eine fehlende Counterzeile beweisen keine Nichtverwendung.
Ein Rückgang oder unveränderter Enginekontext beweist keine Resetkontinuität.
Es werden keine Raten, Deltas oder Summen über unterschiedliche Features berechnet.

Die Kategorien deprecated, discontinued und breaking bleiben getrennt.
Ein positiver nativer Deprecated-Counter erhält keine automatisch erfundene
Entfernungs- oder Zielversionszuordnung. Discontinued Komponenten und Breaking
Changes werden in diesem Slice als nicht allgemein beurteilt ausgewiesen.
Es entsteht kein Upgrade-ready-, Blockerfrei- oder Kompatibilitätsurteil.

Die einzige erste konfigurierte Regel betrifft lightweight pooling ab Zielmajor 17.
Microsoft beschreibt die Option und Fiber Mode ab SQL Server 2025 als deprecated.
Konfigurierter Wert und value_in_use bleiben getrennte native Beobachtungen.
Ein ausstehender Wert 1 ist keine Behauptung bereits aktiver Ausführung.
Die Regel wird ausdrücklich als begrenzte Katalogabdeckung mit Quellenlink und
Prüfdatum dargestellt; sie behauptet keine vollständige Featureliste.

## Vorgeschlagener öffentlicher Vertrag

Der neue eigene Einstieg heißt monitor.USP_UpgradeFeatureUsageAnalysis.
Er liest ausschließlich die aktuelle verbundene SQL-Server-Instanz. Es gibt
keine Datenbankfilter und keine datenbankbezogene Attribution der Counter.

| Parameter | Typ und Vertrag |
|---|---|
| TargetMajorVersion | int, Default NULL; NULL bedeutet keine gewählte Zielbewertung. Explizit sind 15, 16 und 17 zulässig, soweit die Zielversion nicht kleiner als die tatsächliche unterstützte Sourceversion ist. |
| MaxZeilen | int, Default 1000; positiver begrenzter Ausgabewert bis 100000. Der Sourcecache wird vorher vollständig im abgegrenzten Counterobjekt gelesen. |
| ResultSetArt | varchar(16), Default CONSOLE; außerdem RAW, TABLE und NONE. |
| ResultTablesJson | nvarchar(max), Default NULL; vorhandener benannter TABLE-Vertrag. |
| JsonErzeugen / Json | bit 0 / nvarchar(max) NULL OUTPUT; JSON ist optionaler OUTPUT. |
| PrintMeldungen / Hilfe | bit 1 / bit 0; Hilfe liest keine Quelle. |
| StatusCodeOut / IsPartialOut | varchar(40) / bit, jeweils NULL OUTPUT. |
| ErrorNumberOut / ErrorMessageOut | int / nvarchar(2048), jeweils NULL OUTPUT; tatsächliche erste Quellfehlerprojektion. |

Ungültige Parameter, Callertransaktionen und IMPLICIT_TRANSACTIONS ON werden
vor Temp-DDL und fachlichen DMV-/Katalogreads als regulärer INVALID_PARAMETER/51011-OUTPUT mit
RETURN 51011 abgewiesen. Die unterstützte tatsächliche Source-Major wird dafür ausschließlich mit
SERVERPROPERTY geprüft. Der Aufruf beendet oder verändert keine Callertransaktion.
Normale Quellenfehler bleiben abgefangene Diagnosezustände mit RETURN 0.
LOCK_TIMEOUT wird im gültigen Pfad auf 0 gesetzt und vor Rückkehr wiederhergestellt.

Wie beim vorhandenen benannten TABLE-Vertrag sind Parameter-, Temp-DDL- und
Ausgabefehler technische Rückkehrpfade: Sie liefern die tatsächliche technische
Fehlernummer/-meldung, JSON=NULL und einen entsprechenden Fehler-RETURN.
Die erste Quellfehlerprojektion gilt für das reguläre fachliche Ergebnis;
vorhandene sources-Diagnosen werden von einem technischen Ausgabefehler nicht
in andere Quellfehler umgeschrieben. Bereits teilweise geschriebene TABLE-Ziele
sind bei Fehler-RETURN kein bestätigter vollständiger Bericht.

## Vier benannte Ergebnisse

| Ergebnis | Inhalt und Bindung |
|---|---|
| context | Eine tatsächliche Instanzbeobachtung: Source-Major/-Build, optionale Zielmajor, native lokale Engine-Startzeit und Startticks, tatsächliches UTC-Lesefenster, Quellenmengen, Ausgabelimit und begrenzte Abdeckung. Die lokale Startzeit wird nicht als UTC bezeichnet. |
| deprecatedUsage | Native object_name, counter_name, instance_name, cntr_type und cntr_value; zusätzliche Beobachtungsqualität und ausdrückliche Aussagegrenze. Featurelabels werden nicht in eine Datenbank- oder Workloadidentität umgedeutet. |
| configuration | Tatsächlich sichtbare lightweight-pooling-Werte einschließlich value_in_use und expliziter Zielzuordnung der einen dokumentierten Regel. Ein fehlender nativer Optionsdatensatz erzeugt keine erfundene Nullkonfiguration. |
| sources | Je abgegrenztem Sourcepfad Status, tatsächlich abgefangene Fehlernummer/-meldung, bekannte native Menge oder NULL bei fehlgeschlagenem Read und Evidenzgrenze. |

RAW, TABLE, CONSOLE und JSON beschreiben dieselben nativen Ergebnisschemas.
Alle Textspalten eigener Temp- und Resulttabellen verwenden die bestehende
Frameworkcollation SQL_Latin1_General_CP1_CS_AS. MaxZeilen begrenzt ausschließlich
die sortierte Ausgabe von deprecatedUsage; tatsächliche Gesamtmenge,
Ausgabemenge und Kürzung bleiben im Kontext sichtbar. Es gibt kein TOP im
nativen Source-Read und keine erfundene Vollständigkeit durch das Limit.

Counter werden mit nativen Namen, Typ und Rohwert erhalten. Negative native
Werte werden als ungültige Beobachtung markiert und nicht als Nutzungsanzahl
interpretiert. Unbekannte native Countertypen erhalten keine berechnete Rate.
Fehlgeschlagene Reads liefern keine Nullsamples. Eine erfolgreiche SQL-Lektüre
bleibt erfolgreich, wenn erst die nachfolgende Kontextbindung scheitert;
Zahlen dürfen dann ausschließlich als ausdrücklich ungebundene Rohbeobachtung
erscheinen, ohne behaupteten Zeitraum seit dem gespeicherten Engine-Start.

## Geplante Feldtypen und Statusmatrix

Die folgenden Reihenfolgen bestimmen RAW-, TABLE- und JSON-Projektion. Interne
Sourcecache-Spalten werden daraus nicht zusätzlich öffentlich ausgegeben.
Native Textwerte besitzen nvarchar(128), sofern nachfolgend kein anderes Limit
steht; Statusfelder besitzen varchar(40), Diagnosegrenzen nvarchar(1000).

| Ergebnis | Geordnete Felder |
|---|---|
| context | CollectionTimeUtc datetime2(3), SourceMajorVersion int NULL, SourceBuild nvarchar(128) NULL, TargetMajorVersion int NULL, SqlServerStartTimeLocal datetime NULL, SqlServerStartTimeMsTicks bigint NULL, EngineContextConfirmed bit, MeasurementStartUtc datetime2(3) NULL, MeasurementEndUtc datetime2(3) NULL, CounterReadState varchar(16), NativeCounterRows bigint NULL, ReturnedCounterRows bigint, OutputLimited bit, AssessmentCoverage varchar(40), RuleCatalogVersion int, StatusCode varchar(40), IsPartial bit. |
| deprecatedUsage | ObjectName nvarchar(128), CounterName nvarchar(128), FeatureName nvarchar(128), NativeCounterType int, NativeCounterValue bigint, ObservationStatus varchar(40), TargetAssessment varchar(40), EvidenceLimit nvarchar(1000). |
| configuration | ConfigurationName nvarchar(128), ConfiguredValue int NULL, ValueInUse int NULL, IsDynamic bit NULL, TargetMajorVersion int NULL, RuleCode varchar(96), RuleCatalogVersion int, AssessmentStatus varchar(40), SourceReference nvarchar(512), EvidenceLimit nvarchar(1000). |
| sources | SourceOrdinal smallint, SourceName sysname, StatusCode varchar(40), NativeReadState varchar(16), NativeRows bigint NULL, ErrorNumber int NULL, ErrorMessage nvarchar(2048) NULL, EvidenceLimit nvarchar(1000). |

NativeCounterValue bleibt ein unveränderter Rohwert; es gibt keine zusätzliche
berechnete UsageCount-Spalte. Bei bestätigtem Enginekontext lautet die
ObservationStatus-Ausprägung OBSERVED_POSITIVE, OBSERVED_ZERO oder
INVALID_NATIVE_VALUE. Ohne bestätigte Kontextbindung lautet sie
ENGINE_CONTEXT_UNBOUND; der beobachtete Rohwert bleibt erhalten. Countertypen
werden nur benannt und nicht in Raten umgerechnet. TargetAssessment lautet
TARGET_NOT_SELECTED bei NULL und ansonsten UNMAPPED_SOURCE_FEATURE. Ein
Counterlabel wird nicht ohne eigenen Katalogbeleg zur Zielfunktionsregel.

Die Konfigurationsregel DEPRECATED_LIGHTWEIGHT_POOLING_17 besitzt Katalogversion 1.
Ohne Ziel heißt ihr Status TARGET_NOT_SELECTED, bei Zielmajor 15/16
NOT_IN_SELECTED_RULE_SCOPE, bei Zielmajor 17 und ValueInUse=1
CONFIGURED_DEPRECATED_AT_TARGET. Bei lediglich ConfiguredValue=1 lautet er
PENDING_DEPRECATED_CONFIGURATION. Bei beobachteten Werten 0/0 heißt er
NOT_CONFIGURED_IN_OBSERVATION; das ist kein Nichtverwendungsnachweis für
beliebige andere Features. Unbekannte oder nicht boolesche Optionswerte
verhindern diese Ableitung und erhalten INVALID_NATIVE_VALUE.

Erfolgreiche normale Aufnahmen liefern PARTIAL/IsPartial=1 mit
AssessmentCoverage=LIMITED_OBSERVATION. Der begrenzte Upgradeumfang wird nicht
als Vollprüfung dargestellt. Einzelne Quellen besitzen trotzdem ihren
jeweiligen tatsächlichen Status. Bekannte leere Reads tragen SUCCEEDED und
NativeRows=0 mit EMPTY_UNPROVEN, ein fehlgeschlagener Read FAILED und NativeRows=NULL.
Ein nicht gestarteter Read besitzt NOT_STARTED und NativeRows=NULL. Quellenfehler
werden unabhängig erhalten; die erste tatsächliche Fehlernummer und Meldung
werden in OUTPUT gebunden. Kontrollierte Kontextgrenzen ohne native Ausnahme
erfinden keine Fehlernummer.

NativeCounterRows zählt den vollständigen tatsächlichen Countercache,
ReturnedCounterRows die Ausgabe nach MaxZeilen. Ein nachgelagerter Bindungsfehler
ändert SUCCEEDED und die bekannte Menge nicht. Ein ungültiges Zeitfenster wird
als Paar NULL verworfen; es wird keine passende Zeit konstruiert. Enginekontext
ist nur bestätigt, wenn beide vollständigen nativen Beobachtungen passen und
das tatsächliche Gesamtfenster geordnet ist. Die Quellenzeile für diese
Kontextbeobachtung erhält die entsprechende kontrollierte Fehlergrenze.

## Quellen und kontrollierte Fehler

Ein materialisierter Read von sys.dm_os_performance_counters umfasst das
Deprecated-Features-Objekt und seine Usage-Counter. Enginebeobachtungen aus
sys.dm_os_sys_info vor und nach dem Counterread begrenzen dessen Startkontext.
Die einzelne Konfigurationsoption stammt aus sys.configurations. Sämtliche
Lesepfade sind getrennt fehlerfähig; Erfolg einer Quelle ersetzt keinen
fehlenden Beleg einer anderen. Ein fehlendes Counterobjekt wird als unbekannte
Abdeckung erhalten. Fehlernummern entstehen nur aus tatsächlichen SQL-Ausnahmen.

Es gibt keine Konfigurationsänderung, keinen Restart, keine XE-Anlage, keine
Querytextsuche, keinen Datenbanksnapshot und keinen externen Aufruf. Provider-
Connectionstrings, Credentials, Hostdateien und Benutzerinhalte werden nicht gelesen.
Die Lizenz- und Datenschutzverträge des Repositories bleiben erhalten.

## Feste Quellen und vollständige Fehleraggregation

Jeder gültig zugelassene Aufruf erzeugt genau vier sources-Zeilen in dieser
Reihenfolge; die Aufrufe bleiben voneinander unabhängig und werden auch nach
einem Fehler der vorherigen Quelle versucht:

| SourceOrdinal | SourceName | Tatsächlicher Read und Mengenbindung |
|---|---|---|
| 1 | sys.dm_os_sys_info:before | Native Enginebeobachtung vor dem Countercache; der erfolgreiche Read zählt seine tatsächlichen Zeilen und verlangt genau eine vollständige Startzeit-/Tickbeobachtung. |
| 2 | sys.dm_os_performance_counters:deprecated | Ein vollständiger materialisierter Read der abgegrenzten Usage-Counter. NativeRows ist bei SQL-Erfolg genau COUNT_BIG des tatsächlichen Caches, auch bei 0. |
| 3 | sys.dm_os_sys_info:after | Native Enginebeobachtung nach dem Countercache mit eigener tatsächlicher Zeilenzahl und eigenem Fehlerstatus. |
| 4 | sys.configurations:lightweight_pooling | Der tatsächliche abgegrenzte Optionsread; bei SQL-Erfolg ist die Menge 0 oder die beobachtete Zeilenzahl. |

NativeReadState beschreibt jeweils ausschließlich die SQL-Ausführung:
SUCCEEDED mit tatsächlicher Menge, FAILED mit unbekannter Menge oder
NOT_STARTED mit unbekannter Menge. Eine unvollständige oder nicht eindeutige
Enginebeobachtung erhält nach erfolgreichem SQL-Read ERROR_HANDLED mit
ErrorNumber=NULL und behält SUCCEEDED sowie ihre tatsächliche Menge. Ein
fehlender Optionsdatensatz oder Countercache erhält bei erfolgreichem Read
EMPTY_UNPROVEN, SUCCEEDED und NativeRows=0. Auch die unabhängige Nachher-
Enginequelle wird nach fehlgeschlagenem Counterread versucht.

Passen vollständige Enginebeobachtungen oder das geordnete Messfenster nicht,
wird die gemeinsame Bindungsgrenze an SourceOrdinal 3 als ERROR_HANDLED ohne
erfundene Fehlernummer dokumentiert. Dessen bereits vorhandener tatsächlicher
SQL-Fehler wird dabei weder überschrieben noch durch eine zweite Diagnosezeile
ersetzt. Die unbekannte gemeinsame Bindung steht zusätzlich in
EngineContextConfirmed=0. Kontext-Startzeit und Startticks bleiben dann NULL;
sie werden nicht als gültige Counterepoche angeboten. Countercache, native
Readmenge und Rohwerte bleiben erhalten und tragen ENGINE_CONTEXT_UNBOUND.

Die Gesamtstatusentscheidung in context und OUTPUT verwendet dieselbe feste
Priorität. Alle folgenden regulären Ergebnisse tragen IsPartial=1:

1. Nicht unterstützte tatsächliche Source-Major außerhalb 15/16/17 beziehungsweise
   nicht beobachtbare Source-Major ergibt UNAVAILABLE_OBJECT ohne erfundene
   SQL-Fehlernummer. Alle vier fachlichen Reads bleiben NOT_STARTED/NativeRows=NULL.
2. Existiert mindestens eine tatsächliche Counter- oder Optionsrohzeile aus
   einem erfolgreichen SQL-Read, lautet der Gesamtstatus PARTIAL. Fehlende
   andere Quellen und ungültige native Werte bleiben vollständig diagnostiziert;
   der Erfolg einer Teilquelle wird nicht zum Erfolg sämtlicher Quellen.
3. Ohne solche Rohzeilen und bei tatsächlichen SQL-Ausnahmen lautet der Status
   DENIED_PERMISSION, wenn sämtliche tatsächlichen Ausnahmen Berechtigungsfehler
   aus 229/262/297/300/371/916 sind. Sobald eine andere tatsächliche Ausnahme
   vorliegt, lautet er ERROR_HANDLED. Ein vollständiger Quellenausfall erhält
   damit niemals den normalen PARTIAL-Status.
4. Ohne Rohzeilen und ohne native Ausnahme, aber mit kontrollierter ungültiger
   Kontext-/Wertebindung lautet er ERROR_HANDLED mit ErrorNumber=NULL.
5. Verbleiben ausschließlich erfolgreiche bekannte leere fachliche Reads ohne
   weitere Fehlergrenze, lautet er EMPTY_UNPROVEN. Eine unbewiesene leere Menge
   wird nicht zur erfolgreichen Nichtverwendungsprüfung.

ErrorNumberOut und ErrorMessageOut sowie eine gegebenenfalls zusätzlich
benötigte Meta-Fehlerprojektion binden den ersten tatsächlichen SQL-Fehler nach
SourceOrdinal. Keine spätere Quelle und kein kontrollierter Kontextfehler
ersetzt dessen unveränderte Nummer oder Meldung. Ohne native Ausnahme liefern
sie die erste kontrollierte Diagnose mit ErrorNumber=NULL, andernfalls NULL/NULL.
Fehler-/Mengenzustände aller anderen sources-Zeilen bleiben unabhängig erhalten.

Die verbindlichen Gegenfälle verlangen: alle vier Quellen verweigert ergibt
DENIED_PERMISSION, unbekannte NativeRows und keine Rohzeilen; verweigerter
Counterread bei erfolgreichem Optionsread ergibt PARTIAL, Countermenge NULL
und die echte Optionszeile; ein erfolgreicher Counterread mit fehlgeschlagenem
Nachher-Enginebeleg ergibt PARTIAL, erhaltene native Countermenge/-Rohwerte,
ENGINE_CONTEXT_UNBOUND und den tatsächlichen Nachherfehler. Ein zusätzlicher
früherer nativer Fehler muss in allen Fällen die Fehlerprojektion behalten.

## Geplante unabhängige Abnahme und endliche Grenzen

Die Prüfung verbindet echte native Quellen mit gezielten synthetischen
Gegenfällen. Ein eigener Labfall erzeugt nach belegtem Native-Vorzustand einen
harmlosen dokumentierten Deprecated-Begegnungszähler; der Zuwachs wird nur
als Enginebegegnung und niemals als Anwendungs- oder Ausführungsmenge bewertet.
Die allgemeine Reproduzierbarkeit dieses positiven Signals ist vor einer
Erfolgsbehauptung auf dem tatsächlichen Lab zu prüfen.

Weitere Oracles betreffen native Mengen und Rohwerte, Ausgabeparität, Limit,
leere oder unbekannte Quellen, echte Berechtigungsverweigerung, späte
Enginebindung, TargetNULL gegenüber ausgewählter Zielversion, getrennte
Konfiguration/effective Werte und fremde Callertransaktionen. Es wird kein
lightweight pooling aktiviert und keine Hostuhr verändert. Synthetische
Konfigurations- und Driftfälle bleiben von echter Quellenabnahme getrennt.

SQL2025 ist das reguläre funktionale Gate. Eine zusätzliche native SQL2019-
Prüfung wird nur für die konkrete Counter-/Berechtigungs- und Sourceversionsgrenze
gewählt; ein routinemäßiger zusätzlicher SQL2022-Lauf ist nicht geplant.
Die private Obergrenze beträgt acht lokale native Versuche einschließlich
fehlgeschlagener Tests und Recovery. Ein weiterer Versuch benötigt neue Inputs
oder Evidenz. Hash-, Inventar- und Commitbindungen werden lokal geprüft.
Kosten-/Tokenmessung ist nicht verfügbar und wird nicht aus Laufzeit geschätzt.

## Primärquellen, geprüft am 26. Oktober 2026

- [Deprecated Features object](https://learn.microsoft.com/en-us/sql/relational-databases/performance-monitor/sql-server-deprecated-features-object?view=sql-server-ver17): native Begegnungszähler und unterschiedliche Auslöser.
- [Native Performance-Counter-DMV](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-os-performance-counters-transact-sql?view=sql-server-ver17): Rohspalten, Countertypen, Restartgrenze und versionsabhängige Rechte.
- [SQL2025-Deprecations](https://learn.microsoft.com/en-us/sql/database-engine/deprecated-database-engine-features-in-sql-server-2025?view=sql-server-ver17): abgegrenzte Zielversionsregel.
- [lightweight pooling](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/lightweight-pooling-server-configuration-option?view=sql-server-ver17): konfigurierte und wirksame Option sowie Restartbezug.
- [Discontinued features](https://learn.microsoft.com/en-us/sql/database-engine/discontinued-database-engine-functionality-in-sql-server?view=sql-server-ver17) und [Breaking Changes](https://learn.microsoft.com/en-us/sql/database-engine/breaking-changes-to-database-engine-features-in-sql-server-2025?view=sql-server-ver17): getrennte, hier nicht vollständig beurteilte Ausbaupfade.

## Vertragsreview und native Quellenprobe

Der unabhängige Erstreview meldete einen P2 zur noch offenen vollständigen
Fehleraggregation. Der gebündelte Korrekturpass legt die vier Quellen,
Readmengen, Gesamtstatuspriorität und erste tatsächliche Fehlerprojektion fest.
Die begrenzte Nachprüfung schließt diesen Befund; weitere P1/P2 bestehen nicht.
Dies ist ein Vertragsreview und keine Produkt- oder Laufzeitabnahme.

Die erste eigene SQL2025-Quellenprobe bestätigt einen vorhandenen nativen
Deprecated-Usage-Counter und dessen Zuwachs nach einem erst danach kompilierten
harmlosen DATABASEPROPERTYEX-IsFullTextEnabled-Aufruf. Native Engine-Startzeit
und Startticks stimmen vorher/nachher überein. Der eigene Labcleanup bestätigt
REMOVED. Die Probe belegt die Nutzbarkeit dieses Sourcesignals, keine Ausführung
von Benutzerworkload und keine vollständige Produktergebnisprüfung.

## Produktkandidat und gebündelte Runtimeprüfung

Die öffentliche Procedure `USP_UpgradeFeatureUsageAnalysis` und ihre vier
registrierten Ergebnisse sind im Kerninstaller, Navigator und Anwenderpfad
enthalten. Der Erstproduktreview schloss ohne offene P1/P2. Die SQL2025-
Quellenprobe und der öffentliche NONE-/JSON-Smoke bestehen.

Die acht lokalen nativen Versuche sind ausgeschöpft. Die breiteren Läufe
meldeten zunächst Fehler im Fixture: Tempdb-Prozedurcollation, unzulässig
volltypisierte TABLE-Ziele, physische statt logische Spaltenordinalen und eine
fehlende explizite Textcollation im nativen Konfigurationsoracle. Die korrigierte
Fixture besteht die ersten drei Gruppen mit vier typisierten Schemas,
TABLE-/JSON-Parität, unabhängigen nativen Rohwert-/Mengenoracles, Begegnungszuwachs,
Target-/Limitgrenze sowie Caller-, Help- und technischem TABLE-Fehlerpfad.

Die echte Rechteprobe beobachtet drei gescheiterte DMV-Reads mit nativer
Fehlernummer 300 und eine erfolgreiche Optionsquelle. Sie deckt einen
Produktfehler auf: Ohne explizites reguläres RETURN konnte SQL Server trotz
korrekter PARTIAL-/Fehlerprojektion den Wert -4 liefern. Der Produktkandidat
enthält jetzt RETURN 0 am normalen Abschluss. Der abschließende Review prüft
auch die ergänzten Vierquellen-, EngineAfter- und Mehrfehlergegenfälle. Alle
acht eigenen Labs sind nachgewiesen entfernt. Die endgültige Runtimeabnahme
bleibt bis zur tatsächlich ausgeführten CI offen; lokale Teilerfolge ersetzen
keinen vollständigen erfolgreichen Lauf.

Die reguläre Qualifizierung verwendet einen vollständigen SQL2025-PR-Lauf mit
Compatibility-Level-Risiko und eine gezielte Auswahl der nativen SQL2019-Engine
wegen der unterschiedlichen DMV-Rechte. Die vorhandene native Workflowauswahl
FULL_RELEASE ist umfangreicher als der einzelne neue Vertrag; dessen Ergebnis
und die tatsächlich ausgeführten Tests werden getrennt bewertet. SQL2022 wird
nicht zusätzlich gestartet. Nach ausdrücklicher Benutzerfreigabe dürfen höchstens fünf CI-Kandidaten für
diese Welle qualifiziert werden; neue Inputs oder Befunde sind für Wiederholungen
erforderlich. Es werden keine weiteren lokalen Labversuche begonnen.

Der gebündelte unabhängige Folgecheck schließt die Fehlerfallabdeckung ohne
weitere P1/P2. Fall 8 bindet erste Fehlernummer und Meldung in OUTPUT,
JSON-Meta und sources. Die ergänzten elf synthetischen Fälle bleiben bis zur
CI-Ausführung unqualifiziert. Der erste PR-Kandidat 23703dde stoppt im
Datenschutzgate auf einem Codepräfix zur Laufzeitgenerierung des eigenen
Logincredentials. Der exakt pfad-/regel-/wertgebundene Allowlist-Eintrag ist
unabhängig geprüft; ein kopierter Pfad, geänderter Matchtoken und ein
synthetisches Credentialliteral werden weiterhin abgelehnt. Der Hash bindet
den Matchpräfix und nicht die gesamte Erzeugungslogik. Der native SQL2019-Job
startete in diesem ersten Kandidaten nicht; seine gescheiterte Paketvorprüfung
ist kein SQL-Laufnachweis.

Die erste statische PR-CI meldet außerdem einen veralteten versionierten
OPS-005-Installer. Seine kanonische Neuerzeugung übernimmt den neuen Kernumfang;
der lokale Adaptervergleich einschließlich acht Darstellungsgegenfällen besteht.
Der zweite CI-Kandidat bündelt ausschließlich diese generierte Aktualisierung,
die geprüfte Privacy-Ausnahme und den aktuellen Nachweisstand. Die laufende
mutierende SQL2025-Prüfung des ersten Kandidaten wird nicht abgebrochen.

Die erste funktionale PR-CI besteht die native Deploymentregression und stoppt
anschließend auf CL150 in Integration189: Dem neuen Console-Branch fehlt die
verbindlich geprüfte Steuerkonvention @ConsoleResultRequested. Der Renderer
war vorhanden. Der korrigierte Branch verwendet das aus @Mode abgeleitete Bit
nun tatsächlich. Die neue Runtimefixture stand hinter dieser Fehlerstelle und
war deshalb noch nicht ausgeführt. Sie folgt im letzten Kandidaten als
unabhängiger Begleittest direkt auf Smoke; die bisherigen kanonischen Suiten
behalten ihre Reihenfolge. Der bestehende Zählvertrag bleibt bei 34 kanonischen
Suiten und zählt diese Begleitfixture nicht zusätzlich.

## Begrenzte Fortsetzung nach Benutzerfreigabe

Der Benutzer erweitert am 26. Oktober 2026 die Grenze um höchstens zwei
CI-Kandidaten. Die Gesamtgrenze dieser Welle beträgt damit fünf; die acht
lokalen Labversuche bleiben ausgeschöpft. Der dritte Kandidat besteht alle
statischen Head-Gates. Native SQL2019- und SQL2025-Läufe erreichen die neue
Fixture und scheitern nach den ersten drei Gruppen auf Fehler 4621: Das
serverweite GRANT wird im Frameworkkontext ausgeführt. Die Cleanup-Schritte
bestehen. Die Laufzeitabnahme bleibt daher offen.

Die unabhängig geprüfte Fixturekorrektur führt serverweites GRANT und REVOKE
über master.sys.sp_executesql aus. Das Objektrecht für das eigene Clonemodul
bleibt im Frameworkkontext; der äußere Datenbankkontext und die gebundene
Bereinigung bleiben erhalten. Produktcode und Oracles ändern sich nicht.
Der zusätzliche CI-Lauf ist durch diese geänderte Fixture begründet. Bereits
abgeschlossene Reviews werden nicht erneut geprüft; weitere lokale Labs und
eine zusätzliche native SQL2022-Matrix werden nicht gestartet. Der vorhandene
native Workflow bietet für dieses Core-Rechterisiko nur den umfangreicheren
FULL_RELEASE-Scope; der Snapshot-Scope wäre fachlich unzutreffend. Die tatsächlich
ausgeführten Gates und Kosten bleiben getrennt; eine Kostenmessung wird nicht
behauptet.

Der vierte Kandidat bestätigt auf SQL2019 zusätzlich die echte positive
Serverrechteprobe. Im anschließenden synthetischen Teil scheitert die zweite
Clonerstellung mit 2714, weil die gespeicherte Definition einen CREATE-Header
enthält. Die erste synthetische Leerprobe ist davor bestanden. Der abschließende
Fixture-Delta entfernt jeden vorhandenen eigenen Clone nach Prüfung von
Objekt-ID, Name und Definitionshash und erstellt ihn anschließend frisch.
Besitzflag und Bindung werden erst nach erfolgreichem DROP zurückgesetzt und
nach Neuerstellung neu erfasst. Der unabhängige Review bestätigt diesen
Lifecycle-Delta ohne Befunde. Produkt und Oracles bleiben unverändert. Der
fünfte Kandidat prüft diesen geänderten Stand; kein früherer Teilerfolg wird als
vollständige Runtimeabnahme ausgegeben.
