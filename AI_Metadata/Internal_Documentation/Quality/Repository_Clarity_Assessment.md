# Dokumentationskonsistenz, Nachweise und Beitragsweg

**Stand:** 7. Oktober 2026

**Artefaktkennung:** `urn:uuid:01a11830-39c9-76e0-b6bd-054675f1e461`

**Registrierungsmodus:** `DEFERRED`

**Geltungsbereich:** begrenzter Benutzerauftrag für Dokumentations- und Nachweisklarheit

Diese Bearbeitung setzt die pausierte autonome Entwicklungswelle nicht fort.
Die bestehenden offenen Reifeverträge und Statuswerte bleiben maßgeblich.
Die öffentliche [Nachweisübersicht](../../../Documentation/Quality/Test_Matrix.md)
trennt historische Release-Evidenz, berichtete lokale Teilumfänge und fehlende
Prüfungen. Historische CSV-Nachweise werden dadurch nicht aufgewertet.

## Inventar, Installation und Versionen

Das aktuelle Inventar enthält 177 Objekte mit 105 öffentlichen Procedures.
Der Frameworkkern enthält 158 Objekte mit 102 öffentlichen Procedures;
das optionale Snapshotpaket enthält 19 Objekte mit drei öffentlichen
Procedures. Der Coreinstaller und ein Deployment mit Snapshot-Opt-in
haben deshalb unterschiedliche Installationsumfänge.

Die öffentlichen Übersichten verwenden dieselbe aus
`Metadata/Inventory/Objects.csv` geprüfte aktuelle Zusammenfassung. Die
Beschreibung vom 24. August 2026 mit 173 Objekten und 104 öffentlichen
Procedures bleibt in den Release Notes ausdrücklich als historischer
Beschreibungsstand erhalten. Der Validator `900_Validate_Analysis_Documentation.ps1`
prüft die aktuellen Summen einschließlich der Paketaufteilung und gleicht
Framework- und Vertragsversion der Release Notes mit der kanonischen
Versionsquelle ab.

Die [Objektreferenz](../../../Documentation/Reference/Object_Reference.md)
erklärt FrameworkVersion, ContractVersion, ReleaseDate, LastInstalledUtc
und Objektversionen anhand der vorhandenen Quellen. Eine allgemeine Regel
für SemVer-Sprünge oder eine rückwirkende Bedeutung aller Objektversionen
ist nicht dokumentiert. Eine solche Regel benötigt einen eigenen
Entscheidungsauftrag; diese Bearbeitung verändert keine Version.

## Ergebnis der Wartbarkeitsprüfung

Untersucht wurden die kanonischen Procedures `USP_CurrentRequests`,
`USP_CurrentBlocking` und `USP_CurrentOverview` sowie die gemeinsam
verwendeten Vorbereitungs-, Materialisierungs- und TABLE-Ausgabehelfer.
Die großen Dateien und Parameterlisten sind Suchhinweise. Sie belegen
allein weder mehrfach gepflegte Fachlogik noch einen geeigneten
Schnittstellenschnitt.

`InternalPrepareResultTables`, `InternalPrepareSingleResultTable` und
`InternalWriteResultTable` kapseln bereits Teile des gemeinsamen
TABLE-Vertrags. Die Current-State-Erfassung und ihre Parentverbraucher
verwenden vorhandene gemeinsame Capturepfade. Eine weitere Extraktion
müsste Materialisierung, Status, Filter, Mengenlimits und mehrere
Ausgabeformen gemeinsam erhalten. Aus diesem Umfang ergibt sich kein
belegter begrenzter Umbau, dessen zusätzlicher Schnittstellen- und
Validierungsaufwand durch einen konkret nachgewiesenen Nutzen gerechtfertigt
wäre. Die SQL-Implementierung bleibt daher unverändert. Die Aussage ist
eine Prüfung dieser ausgewählten Pfade und kein allgemeiner Nachweis der
Abwesenheit weiterer Wartbarkeitsprobleme.

## Externe Beiträge

Der Benutzer hat Fehlerberichte und Pull Requests am 7. Oktober 2026
ausdrücklich vorgesehen. [CONTRIBUTING.md](../../../CONTRIBUTING.md)
beschreibt dafür reproduzierbare synthetische Meldungen, den bestehenden
Datenschutzvertrag, impact-basierte Validierung und den Reviewweg gegen
`main`. Der Leitfaden definiert weder eine neue Beitragslizenz noch
zusätzliche Rechteübertragungen oder Bearbeitungsfristen.

## Entscheidungsvorlage zur Lizenz

Die maßgebliche Quelle ist die englische Fassung von
[LICENSE.md](../../../LICENSE.md). Abschnitt 1.1 beschreibt die Nutzung
einschließlich kommerzieller Tätigkeiten. Abschnitt 1.2 untersagt Gebühren
gegenüber Dritten für Zugang zu Software oder ihren Inhalten und nennt
Code, Daten sowie Ergebnisse. Abschnitt 1.3 verlangt Urheberangaben bei
Kopien, Änderungen und Weitergaben. Die folgenden Fälle benötigen eine
ausdrückliche Entscheidung des Rechteinhabers über den beabsichtigten
Vertragsumfang. Sie sind keine rechtlich geklärten Erlaubnisse oder Verbote.

| Konkreter synthetischer Fall | Betroffene Klauseln | Gezielt zu klärende Entscheidung |
|---|---|---|
| Ein Dienstleister berechnet Arbeitszeit für eine Diagnose und übergibt dem Kunden einen Bericht mit abgeleiteten Ergebnissen. | 1.1, 1.2 und bei Weitergabe 1.3 | Soll eine solche Analyseleistung zulässig sein, wenn weder Softwarezugang noch Ergebniszugang gesondert bepreist wird? Wie wird der erlaubte Leistungsumfang vom untersagten entgeltlichen Ergebniszugang abgegrenzt? |
| Ein Anwender gibt einen Diagnoseexport kostenlos an einen Empfänger weiter oder verwendet daraus abgeleitete Kennzahlen in einem bezahlten Bericht. | 1.2 und 1.3 | Welche Rohdaten, transformierten Kennzahlen und eigenständigen fachlichen Schlussfolgerungen sollen als Inhalte oder Ergebnisse erfasst werden? Wo und in welcher Form ist die Urheberangabe in einem Export oder Bericht erforderlich? |
| Eine zentrale IT verrechnet Diagnosekosten intern; eine rechtlich getrennte Konzerngesellschaft erhält Ergebnisse gegen Kostenumlage. | 1.1 und 1.2 | Soll reine Kostenverrechnung innerhalb derselben juristischen Person erfasst werden? Wie sollen getrennte Konzerngesellschaften und Umlagen ohne Gewinnabsicht behandelt werden? |
| Eine externe Person reicht eigenen Code per Pull Request ein. | Bestehende Lizenz und Rechte am Beitrag | Welche Rechte benötigt der Rechteinhaber für Aufnahme, Änderung und Weitergabe des Beitrags? Reicht der bestehende Prozess aus oder ist eine gesonderte ausdrücklich vereinbarte Beitragsregel erforderlich? |

Für jeden Fall sollte die Entscheidung den erlaubten Umfang, erforderliche
Attribution und verbleibende Ausschlüsse konkret benennen. Ein erläuterndes
Beispiel darf keine nicht vereinbarte Ausnahme schaffen. Eine gewünschte
Änderung des Lizenztextes oder des geschützten README-Blocks benötigt einen
ausdrücklichen gesonderten Auftrag. Beide Texte bleiben in dieser Lieferung
unverändert; eine rechtliche Prüfung wurde nicht vorgenommen.

## Validierung und verbleibende Grenzen

### Tatsächlich ausgeführter Collationteilumfang

Am 7. Oktober 2026 wurden zwei eigene synthetische Frameworkdatenbanken
auf einer isolierten Linux-SQL2025-Engine `17.0.4075.5` mit CL170 geprüft.
Server und `tempdb` verwendeten `Latin1_General_100_CS_AS`. Die beiden
Frameworkcollations waren `SQL_Latin1_General_CP1_CS_AS` und
`Latin1_General_100_CI_AS_SC`. Die Edition wurde nicht gesondert erhoben.
Der SQL-Quellstand war `531a7ecb2cc53eba2a74712482ec2dc4f9133615`;
die SQL-Implementierung wurde in dieser Bearbeitung nicht verändert.

Für beide Varianten bestanden der aus kanonischen Quellen gebaute
Standalone-Coreinstaller und `Code/Tests/Integration/110_Smoke_Test.sql`.
Eine zusätzliche fokussierte Probe prüfte `USP_ObjectInventory` gegen
ein eigenes synthetisches Tabellenobjekt. TABLE und JSON enthielten
jeweils genau dessen native `OBJECT_ID`, Datenbank-, Schema- und
Objektnamen. Die adaptierten TABLE-Textspalten verwendeten die explizite
Frameworkcollation. Ein nur in Kleinschreibung geänderter exakter
Objektfilter lieferte keine Treffer. Diese Aussagen bestanden auf
beiden Frameworkcollations.

| Ausgeführte Quelle | SHA-256 |
|---|---|
| Generierter Standalone-Coreinstaller | `EB55CF56D398624582285ECDA55DC033AFFB57C567D3CA53789FC54679D3A13D` |
| Kanonische Smoke-Datei | `CA92F0E291DB6C55AA8FE1423540B55C9DA240D2AF81004D9C5D15BB23F03099` |
| Generierte Probe für das synthetische CS-Ziel | `76A681A0658C7E8683195B60EDC80960516D2EA01E8389AF970AC029CD9FC73D` |
| Generierte Probe für das synthetische CI-Ziel | `B39BBFF54B3F9FB29602DEF1FE9C16728049FD3B8FDF6879A1A2133C5160D56A` |

Verwendet wurde das bereits lokal vorhandene Image
`mcr.microsoft.com/mssql/server:2025-latest` mit Image-ID
`sha256:4bab24f36c1ecd48e85f7d37df26e6bf301641d84c3fe652f9a0dcc947d512e1`.
Der eigene Container besaß keine veröffentlichten Ports, kein benanntes
Volume und kein externes Netzwerk. Die Verbindung erfolgte im Container
über eine direkte TCP-Loopback-Verbindung; ein zufälliges Testkennwort blieb ausschließlich
im Ausführungskontext. Nach Abschluss wurde die Eigentumsmarkierung
geprüft und der eigene Container erfolgreich entfernt. Ein vorhandener
Host-SQL-Dienst wurde nicht verwendet.

Die folgende Probe bildet den ausgeführten Vertragsumfang mit dem
kanonischen Datenbankplatzhalter ab. Die Hashes oben beziehen sich auf
die tatsächlich erzeugten Dateien einschließlich ihres jeweiligen
synthetischen Zielnamens und der Collationvorprüfung. Zur Wiederholung
wird auf einer eigenen isolierten Engine zunächst eine frische
Frameworkdatenbank mit einer der genannten Collations und CL170
angelegt. Danach werden Standalone-Coreinstaller, Smoke und diese Probe
in dieser Reihenfolge ausgeführt. `sqlcmd -b` muss jeweils Exitcode 0
liefern; die Abschlussmeldung der Probe muss vorliegen. Der Ausführende
ersetzt den Platzhalter lokal und entfernt ausschließlich sein eigenes
Testziel. Die Probe verändert nur die dafür angelegte synthetische
Datenbank und ist nicht für ein vorhandenes Betriebsziel bestimmt.

```sql
USE [DeineDatenbank];
SET NOCOUNT ON;
IF CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),'Collation'))
   NOT IN (N'SQL_Latin1_General_CP1_CS_AS',N'Latin1_General_100_CI_AS_SC')
    THROW 59901,'Probe database collation mismatch.',1;
IF (SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID())<>170
    THROW 59902,'Probe compatibility mismatch.',1;
CREATE TABLE dbo.ExampleClarityObject(Id int NOT NULL);
DECLARE @NativeId int=OBJECT_ID(N'dbo.ExampleClarityObject'),
        @Json nvarchar(max), @DatabaseName sysname=DB_NAME();
CREATE TABLE #ExampleClaritySeed(Dummy int NULL);
EXEC [monitor].[USP_ObjectInventory]
    @DatabaseNames=@DatabaseName, @ObjectNames=N'ExampleClarityObject',
    @MitIndizes=0, @MaxZeilen=5, @ResultSetArt='TABLE',
    @ResultTablesJson=N'{"objects":"#ExampleClaritySeed"}',
    @JsonErzeugen=1, @Json=@Json OUTPUT, @PrintMeldungen=0;
IF ISJSON(@Json)<>1 OR JSON_VALUE(@Json,'$.meta.statusCode')
   NOT IN('AVAILABLE','AVAILABLE_LIMITED')
    THROW 59903,'Probe JSON status mismatch.',1;
IF (SELECT COUNT(*) FROM #ExampleClaritySeed)<>1
   OR NOT EXISTS(SELECT 1 FROM #ExampleClaritySeed
       WHERE ObjectId=@NativeId
         AND ObjectName COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleClarityObject'
         AND SchemaName=N'dbo' AND DatabaseName=@DatabaseName)
    THROW 59904,'Probe TABLE native identity mismatch.',1;
IF (SELECT COUNT(*) FROM OPENJSON(@Json,'$.objects'))<>1
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.objects')
       WITH(ObjectId int, ObjectName nvarchar(128),
            SchemaName nvarchar(128), DatabaseName nvarchar(128))
       WHERE ObjectId=@NativeId
         AND ObjectName COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleClarityObject'
         AND SchemaName=N'dbo' AND DatabaseName=@DatabaseName)
    THROW 59905,'Probe JSON native identity mismatch.',1;
IF EXISTS(SELECT 1 FROM tempdb.sys.columns
    WHERE object_id=OBJECT_ID('tempdb..#ExampleClaritySeed')
      AND collation_name IS NOT NULL
      AND collation_name<>'SQL_Latin1_General_CP1_CS_AS')
    THROW 59906,'Probe TABLE text collation mismatch.',1;
EXEC [monitor].[USP_ObjectInventory]
    @DatabaseNames=@DatabaseName, @ObjectNames=N'exampleclarityobject',
    @MitIndizes=0, @ResultSetArt='NONE', @JsonErzeugen=1,
    @Json=@Json OUTPUT, @PrintMeldungen=0;
IF ISJSON(@Json)<>1 OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.objects'))<>0
    THROW 59907,'Probe case-sensitive filter mismatch.',1;
PRINT 'COLLATION_PROBE_PASS_JSON_TABLE_NATIVE_IDENTITY';
```

Das Ergebnis ist lokal ausgeführte fokussierte Evidenz ohne unabhängigen
Release-Review. Es belegt weder alle Procedures noch getrennte
Quelldatenbanken, Unicode-Positivfälle, weitere Ausgabeformen,
Berechtigungsprofile oder Produktionslast. Die öffentliche Garantie und
die historischen CSV-Statuswerte bleiben unverändert.

### Statische Prüfungen und offene Laufzeitgrenzen

Die neue Inventarprüfung besitzt eine unabhängige positive Fixture und
14 negative Fälle für falsche Summen, Paketaufteilungen, fehlende und
doppelte Zusammenfassungen. Der normale Dokumentationsvalidator prüft
darüber hinaus Quellpfade, Referenzen und Verlinkung.

Die vollständige lokale statische Suite wurde ausgeführt. Nach der
Korrektur der öffentlichen Dokumentationsgrenze bestand der gesondert
wiederholte Navigatorvalidator. Die Suite meldete außerdem zwei
unveränderte Adapter-Bytevergleichsfehler auf Windows für
`EXECUTION-PLAN-001` und `OPS-005`. Der private Vergleich der versionierten
mit den frisch generierten Installern ergab jeweils identischen Inhalt
nach CRLF-/LF-Normalisierung; der OPS-005-Updatevertrag war bereits
bytegleich. Die betroffenen Adapter und ihre Quellen sind gegenüber dem
Ausgangscommit unverändert. Die vollständige lokale Suite wird deshalb
nicht als bestanden ausgewiesen. Der Befund erfordert eine gesonderte
Prüfung des plattformabhängigen Bytevertrags; diese Bearbeitung schwächt
die bestehenden Hashprüfungen nicht ab und schreibt die Installer nicht um.

Die Inventarselbsttests, der normale Dokumentationsvalidator, der
Navigatorvalidator sowie Repositorydatenschutz und Dokumentationsstil
bestanden im berührten Umfang. Die geänderten PowerShell-Prüfungen und
der vorbereitete Windows-Testplan wurden mit PowerShell 7 und Windows
PowerShell 5.1 erfolgreich geparst. Der Lizenzblock am Beginn der
Root-README wurde bytegleich mit dem Aufgabenbeginn verglichen;
`LICENSE.md` blieb unverändert.

Der native Windows-Testplan in der öffentlichen Nachweisübersicht bleibt
`NOT_EXECUTED`. Ein Linuxcontainer auf einem Windows-Host liefert keinen
nativen Windows-SQL-Nachweis. Der Plan prüft einen begrenzten SQL2025-Umfang
mit Voraussetzungen, Befehlen, Erfolgskriterien und Entfernung des eigenen
synthetischen Datenbankziels. Windows-Featurepositivpfade, weitere native
Engineversionen und Produktionsvolumen bleiben ohne neuen Nachweis.
