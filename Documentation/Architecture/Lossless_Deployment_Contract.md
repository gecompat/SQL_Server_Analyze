# Verlustfreier Gesamtdeploymentweg

**Arbeitselement:** WI-0011

**Status:** implementiert und lokal nativ geprüft; erforderliche PR-Head-CI bleibt Liefergate
**Stand:** 7. Oktober 2026

## Auftrag und Geltungsbereich

Der Benutzerauftrag verlangt einen wiederholbaren, aus aktuellen kanonischen
Quellen erzeugten Deploymentweg, der die gewählten Frameworkobjekte anlegt
oder altert und vorhandene Tabelleninhalte bei Strukturänderungen erhält.
Hilfstabellen zur Datenmigration sind ausdrücklich Bestandteil dieses Auftrags.
Dieser Vertrag beschreibt den implementierten Zielumfang. Die bisherigen
Installer besitzen noch keinen allgemeinen Erhaltungs- oder Rollbacknachweis.

Die bestehenden Masterinstaller bleiben die Quelle der Objektmenge und ihrer
Abhängigkeiten. Der aktuelle Core umfasst 166 Quellen. Das optionale
Snapshotpaket umfasst fünf Framework- und sechs Targetquellen. Der allgemeine
Framework-Preflight kommt in Core und Snapshot Framework vor und wird in einem
kombinierten Deployment nur einmal ausgeführt. Der bereits im Core enthaltene
Execution-Plan-Teilabschluss wird nicht nochmals installiert. Eine zweite
handgeschriebene Objektliste oder dauerhafte Tabellenwahrheit entsteht nicht.

## Erzeugung und Datenbankkontexte

Der geplante Einstieg `Code/Install/Build-DeploymentInstaller.ps1` erzeugt
`Code/Install/generated/Deploy_All.generated.sql`. Der Build liest die aktuellen
Masterinstaller und ihre Einzelquellen. Er verwendet keine Datenbankverbindung,
ändert keine Quelldatei und liefert bei identischen Quellen und Optionen
identischen UTF-8-Inhalt. Unbekannte Include-, Batch-, DDL- oder Seedformen
führen zu einem Buildfehler, wenn ihr Erhaltungsvertrag nicht nachgewiesen ist.

Der Standardumfang bleibt Core. Die Buildoption `IncludeSnapshotBaseline`
nimmt ausschließlich das bestehende optionale Paket hinzu. Die erzeugte Datei
enthält am Anfang den ausdrücklich zu setzenden Frameworknamen als Datenwert
`@FrameworkDatabase = N'DeineDatenbank'`. Im optionalen Umfang muss der Operator
zusätzlich `@SnapshotDatabase` ausdrücklich setzen. Es gibt keinen getrennten
USE-Batch, nach dessen Fehler die Ausführung im vorherigen Kontext weiterlaufen
könnte. Datenbanknamen werden korrekt geklammert und als Daten behandelt. Der
Targetkontext wird weder aus dem aktuellen Frameworkkontext noch aus einer
bestehenden Zielbindung abgeleitet. Die Paketinstallation aktiviert keine
Zielbindung und führt weder Collection noch Purge aus.

Alle gewählten Datenbanken müssen auf derselben verbundenen Instanz bereits
existieren, zugänglich, online und beschreibbar sein. Systemdatenbanken und
eine mit der Frameworkdatenbank identische Snapshotdatenbank werden abgewiesen.
Der erste unterstützte kombinierte Transaktionsumfang schließt Availability
Groups und Datenbankspiegelung aus. Der Deploymentweg aktiviert kein MSDTC
und verändert keine Datenbankoption, Berechtigung, Job-, Login-, Benutzer-,
Server- oder Ownershipkonfiguration. Fehlende Sicht oder Rechte führen zum
Abbruch; Rechte werden nicht erweitert.

## Vorprüfung und bekannte Strukturmigrationen

Vor der ersten Änderung bestehender Produktdaten werden alle gewählten
Datenbankkontexte und sämtliche betroffenen vorhandenen Objekte geprüft.
Der Sollvertrag stammt aus den kanonischen DDLs, einschließlich konstanter
CREATE-TABLE-Texte in EXEC-Anweisungen. Geprüft werden Objekttyp, Spaltennamen,
Typen, Größen, Precision, Scale, Nullability, Collation, Identity, rowversion
sowie die relevanten Schlüssel-, Default-, Check-, Foreign-Key- und
Indexverträge. Tabellen-DML-Trigger und aktive Datenbank- oder Server-DDL-Trigger sowie
RLS, Temporal, CDC, Change Tracking, Replikation, Memory-Optimierung und
nicht kanonische Partitionierungs-, Verschlüsselungs- oder berechnete
Spaltenformen werden vor Änderungen abgewiesen. Zusätzliche Strukturen,
widersprüchliche gleichnamige Objekte und unzureichende Metadatensicht führen
ebenfalls zum Abbruch.

Die zwölf bereits in `074_WaitTypeCatalog.sql` beschriebenen Ergänzungen sind
der erste unterstützte additive Altvertrag. Die bestehenden Basisspalten und
alle schon vorhandenen Ergänzungen müssen fachlich konform sein. Neue nullable
Spalten sowie die konkret definierten NOT-NULL-Spalten mit ihren Defaults
können ergänzt werden. Bereits vorhandene Werte und Schlüssel bleiben erhalten.
Die bekannte angehängte Altspaltenreihenfolge ist zulässig; eine ausschließlich
gegen frische `column_id`-Werte gerichtete Prüfung wäre dafür falsch.

Nicht enumerierte Renames, Verengungen, Typ- oder Collationkonvertierungen und
beliebige Copy-and-Drop-Migrationen werden nicht heuristisch ausgeführt.
Eine künftige kanonische Strukturänderung benötigt einen konkret geprüften
Migrationsvertrag, bevor sie als unterstützt ausgeliefert wird.

## Ownership und Erhaltung aktiver Daten

Customzeilen bleiben mit ihren bisherigen Werten in ihrer aktiven Tabelle.
Dies gilt für Waits und Quellen, Toolregeln, Planprofile und Thresholds,
Assignments, Snapshotzielbindung, Policies sowie Capture-, Scope-, Metrik-,
Payload- und Purgedaten. `IsEnabled` bleibt bei vorhandenen Toolregeln,
Planprofilen und Planthresholds operatorverwaltet; auch ein versionsbedingtes
Update anderer Defaultfelder darf `IsEnabled=0` nicht aktivieren.
Unveränderte Snapshotkonfiguration erhält kein ersetzendes UPDATE und damit
keine neue rowversion. Identitywerte und historische Foreign-Key-Beziehungen
werden nicht neu nummeriert.

`IsFrameworkDefault` bestimmt nur dort die Änderungsgrenze, wo die kanonische
Quelle diesen Marker besitzt. Ein belegter Customschlüssel wird weder zum
Frameworkdefault umklassifiziert noch durch einen Default ersetzt. Kollisionen
zwischen erforderlichen Defaultquellen und Customordinals werden vorab
abgewiesen. Die markerlosen Build- und Lifecyclekataloge dürfen bei abweichenden
vorhandenen Werten nicht allein wegen eines bekannten Schlüssels überschrieben
werden. Gleichwerte bleiben erhalten; ungeklärte Abweichungen führen zum
kontrollierten Abbruch.

Die aktuellen Framework- und Paketversionsmetadaten werden weiterhin korrekt
geschrieben. Ihre bestehenden Installationszeitverträge bleiben ausdrücklich
berücksichtigt: ein tatsächliches Fortschreiben des Installationszeitpunkts
ist eine zu erhaltende Metadatenänderung. Andere FrameworkName-Zeilen bleiben
unverändert. Keine Versionsnummer wird wegen eines missverstandenen
Erhaltungsgebots auf einen veralteten Stand eingefroren.

Die drei vorhandenen Legacytabellen `FrameworkProcedureContract`,
`FrameworkExpectedObject` und `FrameworkInstallationHistory` bleiben am
bisherigen Ort erhalten. Der neue Weg löscht auch keine unbekannten oder lokal
angepassten Legacyobjekte allein anhand ihres Namens.

Eine weitere Ownershipgrenze betrifft die manuell gepflegte View
`monitor.VW_AnalyseAccessPolicy`. Eine vorhandene kompatible Policydefinition
bleibt erhalten; nur eine fehlende View wird aus der leeren kanonischen
Erstdefinition angelegt. Eine inkompatible Definition wird vor Änderungen
abgewiesen. Das Deployment darf durch ein leeres CREATE OR ALTER weder die
Gruppenpolicy löschen noch Deepklassen unbeabsichtigt wieder öffnen.

## Typgetreue Vorzustände und retirierte Defaults

Vor erlaubten Änderungen vorhandener Frameworkdefaults oder Versionswerte
wird ihr vollständiger Vorzustand im jeweiligen Datenbankkontext dauerhaft
gesichert. Hilfstabellen erhalten echte, aus dem geprüften Originalschema
abgeleitete Spaltentypen und explizite Spaltenlisten. NULL, Unicode,
nachgestellte Leerzeichen, Binärwerte, Originalschlüssel und ursprüngliche
Zeitwerte werden unverändert gespeichert. Identitywerte werden typgleich als
gewöhnliche Werte erhalten; Identitymerkmale bleiben separate Metadaten.
Original-rowversion wird als `binary(8)` mit ihrer ursprünglichen
Typkennzeichnung gesichert. JSON darf Schema- und Zuordnungsmetadaten
beschreiben, ersetzt aber keine typgetreue Wertpersistenz.

Die Hilfspersistenz verwendet in jedem gewählten Kontext das Schema
`monitor_deployment` mit Eigentümer `dbo` und dem Formatmarker
`SQL_Server_Analyze.DeploymentFormat=1`. Ein vorhandenes Schema ohne diesen
Marker oder mit anderem Eigentümer wird vor Änderungen abgewiesen. Jeder
Lauf erzeugt eine neue Run-ID über `NEWID()` und eigene Tabellen
`Run_<32-stellige Run-ID>` sowie `State_<32-stellige Run-ID>_<Objektordinal>`.
Eine Namenskollision führt zum Abbruch; unbekannte Hilfstabellen werden nicht
übernommen, verändert oder bereinigt.

Der Runbeleg speichert Run-ID, Formatversion, SHA-256 der gewählten Quellen,
Datenbankrolle, explizite Datenbanknamen, Start- und Belegzeit sowie ein
Schema- und Zuordnungsmanifest. Er wird auch bei einer frischen Installation
ohne Vorzustandszeilen erzeugt. Das Manifest enthält Originalschema,
Originalobjekt, Archivname, gesicherte Zeilenanzahl und Spaltenfacetten mit
Originaltyp, Länge, Precision, Scale, Nullability, Collation, Identitymerkmalen,
rowversion-Kennzeichnung sowie Schlüssel-, Default-, Check-, Index- und
Foreign-Key-Definitionen. Werte stehen ausschließlich in den typisierten
Statetabellen. Die Zeit des Belegs ist kein behaupteter Commitzeitpunkt.

Ein Vorzustand erhält damit eine eindeutige lokale Deploymentzuordnung, den
Originalobjektbezug und die zur Interpretation erforderlichen Schemafacetten.
Sicherung und zugehörige aktive Änderung liegen in derselben Transaktion.
Ein fehlgeschlagener Lauf hinterlässt weder ein vermeintlich erfolgreiches
Deployment noch verwaiste Vorzustände. Die Hilfspersistenz erhält keinen
automatischen Purge oder Retentionlauf. Sie ist betriebliche Speicherung in
der gewählten Datenbank; Runtimewerte werden nicht in Repository-, GitHub-
oder Downloadartefakte übernommen.

Die 14 kanonisch retirierte Default-Waits und ihre frameworkeigenen Quellen
dürfen erst nach der typgetreuen Vorzustandserhaltung aus der aktiven Menge
entfernt werden. Bestehende Customquellen an solchen Waits führen vorab zum
Abbruch; sie werden weder gelöscht noch einer anderen Bedeutung zugeordnet.
Defaultquellen werden vor ihren Wait-Eltern behandelt. Der bisherige
Foreign-Key-Fehler zwischen `074a` und `074f` darf bei Wiederholung nicht
entstehen. Frische Pflichtseedmengen bleiben korrekt. Die Smokeprüfung muss
Pflichtobjekte und Seeds von bewusst erhaltenen Legacy- und Customdaten
unterscheiden, ohne deren korrekte fachliche Verträge zu schwächen.

## Batchausführung, Sperren und Rollback

Der Runner besitzt genau eine Transaktion für den gewählten Gesamtumfang.
`@@TRANCOUNT` muss vor dem Lauf null sein, und implizite Transaktionen müssen
ausgeschaltet sein. Bereits laufende Callertransaktionen werden nicht
übernommen oder zurückgerollt. Dieses Gate läuft vor der eigenen Umschaltung
von XACT_ABORT und verwendet einen abbrechenden RAISERROR-/RETURN-Pfad. Die
Fehlermeldung läuft mit lokalem `XACT_ABORT OFF` in einem eigenen
`sp_executesql`-Scope; der aufrufende Scope behält seine Optionen und eine
bereits offene Transaktion bleibt committable. Vor den Datenbanksperren erhält
die eigene Transaktion eine exklusive Anwendungssperre in `tempdb` unter dem
gemeinsamen Principal `public`. Die Ressource
`SQL_Server_Analyze.DeploymentFormat1.TempMetadata` wird bis Commit oder
Rollback gehalten. Sie serialisiert alle Deploymentpaare derselben Instanz,
weil die nativen Referenz-DDL und Katalogprüfungen gemeinsame tempdb-Metadaten
verwenden. Alle gewählten Datenbankkontexte erhalten anschließend in
deterministischer Reihenfolge eine exklusive Anwendungssperre. Für jede
Anwendungssperre gilt eine Wartezeit von höchstens zehn Sekunden.
Negative Sperrrückgaben führen zum Abbruch. Zusätzlich werden die tatsächlich
zu schützenden bestehenden Tabellen beziehungsweise Zeilen vor ihrer
Struktur-/Ownershipprüfung mit getesteten transaktionalen Locks geschützt.
Anwendungssperren allein beweisen keine Isolation gegenüber normaler DML.
Strukturen werden unmittelbar vor ihrer Veränderung erneut geprüft.

GO wird lexikalisch als Clientseparator behandelt. GO in Literalen,
Identifiern oder Kommentaren trennt keinen Batch. CREATE-/ALTER-Module werden
auf einer separaten niedrigeren Ausführungsebene als erstes Statement ihres
eigenen Batches kompiliert. Jeder Batch erhält den richtigen Datenbankkontext.
Ein separat ausgeführtes dynamisches USE ist dafür nicht ausreichend.
QI-/ANSI-Einstellungen werden im äußeren Ausführungskontext vor dem inneren
Modulbatch gesetzt; ihre Wirkung wird nativ an gespeicherten Modulmetadaten
geprüft. Unbekannte SET-/Batchformen werden nicht stillschweigend verworfen.

Ein äußerer TRY/CATCH mit XACT_ABORT schützt die darunter ausgeführten
Produktbatches. Bei einem abgefangenen Fehler wird die eigene offene
Transaktion zurückgerollt und der Fehler erneut gemeldet. Spätere Seeds oder
Versionsfortschreibungen laufen danach nicht weiter. Ein spätes Compileproblem
muss auch die früheren Änderungen beider gewählter Datenbanken zurückrollen.
Clientabbruch, KILL oder Verbindungsverlust sind keine synchron abgefangenen
Erfolgs- oder Rollbacknachweise; ihr Abschlusszustand bleibt bis zur
Reconciliation unbekannt. Der Runner speichert keinen behaupteten Erfolg
vor dem tatsächlichen COMMIT. Nach Verlust der Commitantwort wird die vorher
ausgegebene Run-ID in sämtlichen gewählten Datenbanken nachgeschlagen. Nur
konsistente persistente Belege mit passender Run-ID, Quellendigest und Rollen
belegen den Commit. Fehlende oder widersprüchliche Sicht bleibt unbekannt,
bis die Ressourcen und der Transaktionsabschluss unabhängig geklärt sind.

## Abnahme und Liefergrenze

Native Gegenproben verwenden ausschließlich eigene neue lokale Testressourcen.
Sie vergleichen sämtliche vorherigen Werte und relevanten Schemafacetten,
nicht nur COUNT oder CHECKSUM. Erforderlich sind frische Installation,
Wiederholung, die bekannte Wait-Altmigration, gefüllte Core- und Legacytabellen,
Custom- und Defaultkonflikte, gefüllte Policy, separate Snapshotkontexte,
NULL-/Unicode-/Leerzeichen-/Binärwerte, Identity-/rowversion-Erhaltung sowie
die vollständige Zuordnung erlaubter Änderungen zu ihren Vorzuständen.
Negative Fälle umfassen Strukturdrift, fehlende Rechte, falschen Targetkontext,
externe Transaktion, Konkurrenz und einen injizierten späten Compilefehler.
Echte Mutationen müssen die unabhängigen Prüfer zurückweisen.

Die bisherigen Installerverträge 191, 192 und 194 bleiben aktiv. Ihre
Determinismus- und Abschlussnachweise ersetzen keine Migrationsprüfung. Eine
zentrale Installeränderung verlangt das vollständige funktionale Gate auf
SQL Server 2025; ausführbare Code09-Änderungen ergänzen die betroffenen
Compatibility Levels 150, 160 und 170. Zusätzliche native Engines folgen nur
bei konkretem Versionsrisiko gemäß der kanonischen CI-Teststrategie.

Unabhängiger Review, ehrliche Evidenz, abschließende Dokumentations- und
Privacyprüfung, erfolgreiche erforderliche CI am exakten PR-Head,
Integration, Synchronisierung und eigener Cleanup gehören zum Abschluss.
Die lokalen SQL-Server-2025-Gegenproben bestätigen den beschriebenen
Umfang bekannter Strukturänderungen, Rollback bei einem späten Compilefehler, die Ausführung
durch einen CONTROL-Grantee ohne db_owner und den kontrollierten Timeout
konkurrierender Deployments auf unterschiedlichen Datenbankpaaren.
Weitere native Engines, eine Windows-SQL-Engine, Produktionsvolumen und
Commitantwortverlust sind nicht belegt.
Ein erfolgreicher aktueller Security-Cloud-Lauf ist weiterhin nicht belegt.
