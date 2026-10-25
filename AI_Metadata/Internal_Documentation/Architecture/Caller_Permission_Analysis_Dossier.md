# Effektive Berechtigungen des aktuellen Ausführungskontexts

**Stand:** 25. Oktober 2026.
**Status:** erster Caller-Slice über PR #441 integriert; SQL2025- und gezielte native SQL2019-Abnahme abgeschlossen.
**Artefakt-UID:** `urn:uuid:01a17261-e0f7-7145-9586-f332362bdc1c`.
**Registrierung:** `DEFERRED`; keine zusätzliche lesbare Kennung vergeben.
**Arbeitselement:** weiterer Teil von `WI-0012` und Rang 6 der
[Entwicklungswellen](../Quality/Development_Waves_2026-10.md).

## Diagnosefrage und Grenze

Die vorhandenen [Serverprincipal-](Server_Principal_Analysis_Dossier.md) und
[Datenbankprincipal-Berichte](Database_Principal_Analysis_Dossier.md) zeigen
sichtbare Katalogzeilen. Der nächste Bericht soll die native Bewertung von
sys.fn_my_permissions für den aktuellen Ausführungskontext auf SERVER- und
DATABASE-Ebene zeigen. Direkte, implizite und über Rollen oder Gruppen
vermittelte Rechte werden dabei durch die Engine bewertet. Es wird kein
vollständiger Berechtigungsgraph aus Katalogkanten selbst berechnet.

Der vorgeschlagene Name lautet monitor.USP_CurrentCallerPermissionAnalysis.
Der Bericht wechselt keine Identität und nimmt keinen Zielprincipalparameter
an. Ein bereits vom Aufrufer gesetzter EXECUTE-AS-Kontext oder zusätzliche
Modulidentitäten gehören zum tatsächlich aktiven Sicherheitskontext. Das
Ergebnis wird nicht auf ORIGINAL_LOGIN oder andere Principals übertragen.
Die Procedure erhält selbst kein EXECUTE AS und keine Signatur zur
Rechteerweiterung. Die Ausgabe erteilt keine Rechte und führt keine fachlichen
Probeabfragen oder Anmeldeversuche aus.

Die erste Lieferung umfasst SERVER- und DATABASE-Securables. Sie behauptet
keinen konkreten Objekt-, Spalten- oder Statementzugriff. Ein auf Datenbankebene
gemeldetes SELECT-Recht schließt einen wirksamen DENY an einem einzelnen
Objekt nicht aus. Ownershipchains, signierte Aufrufketten und spätere
Zustandsänderungen benötigen eine konkrete getrennte Zugriffsprüfung.
Linked Server, Directoryabfragen und tatsächliche Anmeldefähigkeit bleiben
ausgeschlossen.

## Auswahl und API

Ohne Filter werden alle sichtbaren Online-Benutzerdatenbanken untersucht.
Die gemeinsame Auswahl verwendet @DatabaseNames nvarchar(max)=NULL mit
bracket-aware Pipe-Listen, @SystemdatenbankenEinbeziehen bit=0 und den
getrennten @DatabaseNamePattern nvarchar(4000)=NULL. Eine implizite CURRENT-
Auswahl oder eine Datenbankvorbegrenzung wird nicht eingeführt.
@ServerrechteEinbeziehen bit=1 aktiviert zusätzlich die Serverquelle.
NULL ist für die beiden booleschen Auswahlparameter ungültig.

Die übrige API übernimmt @MaxZeilen int=1000, @LockTimeoutMs int=0,
@ResultSetArt varchar(16)='CONSOLE', @ResultTablesJson nvarchar(max)=NULL,
@JsonErzeugen bit=0, @Json nvarchar(max)=NULL OUTPUT, @PrintMeldungen bit=1,
@Hilfe bit=0 und die vier gemeinsamen Status-/Fehler-OUTPUT-Parameter.
MaxZeilen 0 oder NULL ist unbegrenzt; ein negatives Limit wird abgelehnt.
LockTimeoutMs akzeptiert 0 bis 60000; NULL oder negative Werte sind ungültig.
Die Datenbankauswahl und TABLE-Ziele werden vor fachlichem Quellenzugriff
geprüft. Die gemeinsame Regex-Capabilitygrenze bleibt erhalten.

## Quellen und Bedeutung

Die Serverquelle ruft sys.fn_my_permissions(NULL,'SERVER') einmal auf.
Die Datenbankquelle ruft sys.fn_my_permissions(NULL,'DATABASE') im jeweiligen
geprüften Zielkontext auf. Die Nativefunktion benötigt die public-Rolle;
Ausführungsrechte auf die Frameworkprocedure und der Zugang zum Ziel bleiben
separate Voraussetzungen. Quellen werden unabhängig materialisiert und mit
Beginn, Ende, Anzahl und tatsächlichem Fehlerstatus dokumentiert.

Die Funktion liefert native entity_name-, subentity_name- und
permission_name-Werte. Der Bericht übernimmt diese Werte ohne eigene
Grant-/Deny-Synthese. subentity_name ist für SERVER-/DATABASE-Securables
regulär NULL, weil diese keine Spalten besitzen. Dieser native Wert ist kein
Quellenfehler. Auch entity_name wird als nativer Wert unverändert übernommen;
seine NULL-Ausprägung erhält ohne gesonderten Pflichtwertvertrag keinen
Fehlerstatus. Leere Ergebnismengen sowie Zeilen ohne nichtleeren
permission_name erhalten eine explizite unbewiesene Grenze. Daraus entsteht
kein Negativnachweis fehlender Rechte. Ein Fehler oder Timeout wird weder in
eine leere erfolgreiche Menge noch in ein fehlendes Recht umgedeutet.

Der aktuelle Kontext wird je Quelle durch DB_ID(), SUSER_ID() und DATABASE_PRINCIPAL_ID()
ohne Namensargumente beschrieben. Die numerischen IDs werden vor und nach der
Rechteaufnahme im selben Batch verglichen. Ein beobachteter Wechsel verwirft
die betreffende Teilmenge. Eine unveränderte ID-Kombination beweist keine
unveränderte Rollen- oder Modulidentitätsmenge und keine dauerhafte Identität.
Eine fehlende Serverprincipal-ID ist bei einem lokalen Benutzerkontext
zulässig; sie wird nicht als Funktionsfehler behandelt.

Die vorbereitende SQL2025-Charakterisierung bestätigte bei einem eigenen
loginlosen Benutzer eine leere SERVER-Menge, eine nichtleere DATABASE-Menge
und eine NULL-Serverprincipal-ID. Die Namensfunktionen SUSER_SNAME und
SUSER_NAME konnten in diesem Kontext eine SID-Zeichenfolge zurückgeben.
Der Produktvertrag verwendet deshalb die numerischen Kontextfunktionen und
übernimmt keine solche Namensausgabe. Dies ist Quellencharakterisierung,
keine Produktabnahme und keine pauschale Versionsqualifikation.

Datenbank-ID, Name und erfasstes create_date werden vor und nach jedem lokalen
Read geprüft. Ein Drift verwirft die Teilmenge mit DATABASE_UNAVAILABLE und
lokaler Diagnose; daraus folgt kein atomarer Gesamt-Snapshot. Der validierte
Lock-Timeout steht im selben dynamischen Batch wie die Nativefunktion.
Table-Valued Functions erhalten keinen erfundenen NOLOCK-Hinweis. Eventuelle
native Sperr- oder Sichtbarkeitsgrenzen bleiben als Quellenstatus sichtbar.
Der Bericht liest keine Nutzdaten, Passwortwerte, SIDs oder Tokens.
Sichtbare Kontext- und Securablenamen bleiben diagnostisch erhalten;
versionierte Beispiele enthalten ausschließlich synthetische Werte.

## Vorgesehene Ausgabe und Fehlervertrag

Vorgesehen sind sechs benannte Resultsets: moduleStatus, callerContexts,
serverPermissions, databasePermissions, sourceStatus und warnings.
Die beiden Rechtemengen enthalten native Namen; die Datenbankmenge enthält
zusätzlich DatabaseId und DatabaseName. Kontext, Quellenstatus und Warnungen
werden durch MaxZeilen nicht abgeschnitten. Das Limit wirkt getrennt global
auf die beiden fachlichen Rechtemengen; ObservedRows und ReturnedRows bleiben
unterscheidbar. Eine Kürzung enthält eine ausdrückliche Limitwarnung.

RAW, CONSOLE, TABLE, NONE und optionales JSON verwenden dieselbe kanonische
Materialisierung. CONSOLE führt die beiden Rechtemengen mit einer Scope-Spalte in einer
fachlichen Ausgabemenge zusammen. SOURCE-, WARNING- und INFO-Zeilen erhalten
Quellprobleme und Aussagegrenzen auch neben erfolgreichen Rechtezeilen.
SourceKey und WarningCode bleiben getrennt von den nativen Namensfeldern.
RowCount im moduleStatus ist die Summe der beiden tatsächlich zurückgegebenen
Rechtemengen. TABLE
verwendet ausschließlich die gemeinsame benannte Mehrfachzuordnung.
Sobald mindestens eine Rechtemenge erfolgreich und nichtleer gelesen wurde,
bleibt der Gesamtbefund AVAILABLE_LIMITED mit IsPartial=1. Sind ausschließlich
leere erfolgreiche Rechtemengen verfügbar, lautet der Befund EMPTY_UNPROVEN.
Ohne ausführbares Ziel lautet er NO_TARGETS. Bei ausschließlich
fehlgeschlagenen Rechtesourcen übernimmt er den ersten konkreten Fehlerstatus.
Kontextmetadaten allein gelten dabei nicht als erfolgreiche Rechtemenge.

Erwartete Parameter- und TABLE-Ablehnungen sowie gefangene äußere Fehler
kehren regulär mit Status, Diagnose-OUTPUT, Diagnosecode als RETURN-Wert und
JSON-NULL zurück. Der Callerzustand, seine Transaktion und sein Datenbankkontext
bleiben erhalten. Nicht gefangene Verbindungs- oder Engineabbrüche erhalten
keine erfundene Rückgabe- oder Wiederherstellungsgarantie.

## Technischer Vorvertrag für die Produktimplementierung

Die API umfasst 16 Parameter in der oben beschriebenen Reihenfolge; der
zusätzliche Serverparameter folgt auf DatabaseNamePattern. Die sechs
benannten Mengen erhalten SchemaVersion 1. Alle Textspalten verwenden
explizit SQL_Latin1_General_CP1_CS_AS. Die folgenden Tabellen sind der
zu prüfende Ausgabevertrag, keine aus einer SUT-Ergebnisbeschreibung
übernommene Schemasynthese.

```sql
CREATE TABLE #Contract_moduleStatus
(
    [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [CapturedAtUtc] datetime2(3) NOT NULL,
    [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [IsPartial] bit NOT NULL,
    [RowCount] bigint NOT NULL,
    [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
CREATE TABLE #Contract_callerContexts
(
    [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [DatabaseId] int NULL,
    [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ContextDatabaseId] int NOT NULL,
    [ServerPrincipalId] int NULL,
    [DatabasePrincipalId] int NULL,
    [ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [CapturedAtUtc] datetime2(3) NOT NULL
);
CREATE TABLE #Contract_serverPermissions
(
    [EntityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [SubentityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
CREATE TABLE #Contract_databasePermissions
(
    [DatabaseId] int NOT NULL,
    [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [EntityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [SubentityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
CREATE TABLE #Contract_sourceStatus
(
    [DatabaseId] int NULL,
    [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [StartedAtUtc] datetime2(3) NOT NULL,
    [CompletedAtUtc] datetime2(3) NOT NULL,
    [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ObservedRows] bigint NULL,
    [ReturnedRows] bigint NULL,
    [IsLimited] bit NOT NULL,
    [ErrorNumber] int NULL,
    [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
CREATE TABLE #Contract_warnings
(
    [DatabaseId] int NULL,
    [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
```

Die Funktion lieferte in der vorbereitenden SQL2025-Prüfung entity_name und
subentity_name als nullable nvarchar(128) sowie permission_name als nullable
nvarchar(60). Der Vertrag erweitert das gültige permission_name verlustfrei
[auf] nvarchar(128); eine NULL- oder Leerzeile wird vor dieser Übernahme als
unbewiesene Quellenform verworfen. Reguläre NULL- und Leerwerte der beiden
Namensspalten bleiben unverändert erhalten. Die Frameworkschemas werden
gegen unabhängig deklarierte typisierte Solltabellen geprüft.

SERVER_CURRENT_PERMISSIONS und DATABASE_CURRENT_PERMISSIONS bezeichnen die
beiden NATIVE-Rechtequellen. DATABASE_CONTEXT bindet vorher ID, Name und
create_date des jeweiligen Ziels. DATABASE_SELECTION besitzt SourceKind
SELECTION. Serverzeilen haben DatabaseId und DatabaseName NULL; die lokalen
Zeilen enthalten die geprüfte Zielbindung. ContextDatabaseId enthält auch
beim Serverbefund den tatsächlichen Datenbankkontext des Funktionsaufrufs,
damit die lokale DatabasePrincipalId einen definierten Namespace besitzt.

callerContexts enthält nur erfolgreich erfasste Rechtekontexte. Nichtleere
und leere native Mengen können einen Kontext besitzen; SKIPPED- und
fehlgeschlagene Aufnahmen erzeugen keine erfundene Kontextzeile. Der Status
CAPTURED_CURRENT_IDS bedeutet, dass beide Principal-IDs vorliegen.
PARTIAL_CURRENT_IDS kennzeichnet eine fehlende Principal-ID. Beide Zustände
beweisen keine Vollständigkeit des gesamten wirksamen Sicherheitskontexts.

Eine erfolgreiche nichtleere Rechtequelle erhält AVAILABLE_LIMITED mit
VisibilityScope CURRENT_CONTEXT_ONLY. Eine erfolgreiche leere Quelle erhält
EMPTY_UNPROVEN mit ObservedRows=ReturnedRows=0 und eine ausdrückliche Warnung.
Eine unbrauchbare permission_name-Zeile verwirft die ganze betreffende
Rechtemenge mit ERROR_HANDLED und lokaler Diagnose 51014. Ein beobachteter
ID-Wechsel verwirft die Menge mit ERROR_HANDLED und lokaler Diagnose 51013.
Zieldrift verwendet DATABASE_UNAVAILABLE mit lokaler Diagnose 51012.
Diese lokalen Diagnosen sind keine nativen Enginefehler.

Native Berechtigungs-, Timeout- und Datenbankfehler bleiben nach ihrem
konkreten Ursprung getrennt erkennbar. Ihre diagnostischen Meldungen bleiben
entsprechend dem Projektvertrag vollständig; der Verzicht auf SID- und
Tokenquellen ist keine nachträgliche Anonymisierung der Laufzeitausgabe. Bei verworfenen Quellen sind
ObservedRows und ReturnedRows NULL. Das Ausgabelimit kürzt getrennt global
nach deterministischer Reihenfolge; Kontext und Status bleiben vollständig.
Die Datenbankmenge sortiert zuerst nach DatabaseId, danach nach den drei
nativen Feldern; die Servermenge sortiert nach ihren nativen Feldern.

Regulär materialisierte Berichte kehren mit RETURN 0 zurück, auch wenn eine
isolierte fachliche Quelle scheitert. Status und Error-OUTPUT sowie die
Quellenzeilen müssen deshalb geprüft werden. Erwartete API-/TABLE-Ablehnungen
und gefangene äußere Fehler liefern dagegen den dokumentierten Diagnosecode
als RETURN-Wert und JSON-NULL. Dieser Unterschied übernimmt den bestehenden
Principal-Rückgabevertrag.

## Unabhängige Abnahme und nächste Grenze

Die eigene synthetische Fixture benötigt mindestens zwei Datenbanken mit
verschiedenen Benutzerbindungen, einen kontrollierten Login, direkte und
verschachtelte Rollen sowie unabhängig arrangierte GRANT-/DENY-Sollfälle.
Sie prüft den aktiven eingeschränkten Kontext und einen Sysadminfall getrennt.
Ein Objekt-DENY bei erlaubtem Datenbank-SELECT zeigt die Aussagegrenze, ohne
Objektrechte als Teil dieses Berichts auszugeben. Die Fixture darf dafür
nur eigene Principals, Objekte und Rechte verwenden.

Native Wert- und typisierte Schemaoracles, beide Ausgabemengen, JSON-Parität,
Limits, leere beziehungsweise fehlgeschlagene Quellen, Datenbankauswahl,
Calleroptionen, Ambienttransaktion und unabhängige Sentinels gehören zur
Abnahme. Eigene Ressourcen werden über native Identitäten gebunden und auch
bei Fehlern bereinigt. Stufentests und vollständige SUT-Tests bleiben als
unterschiedliche Evidenz gekennzeichnet.

SQL2025 bleibt gemäß [CI-Teststrategie](../../../Documentation/Quality/CI_Test_Strategy.md)
die primäre Engine. Native ältere Versionen oder weitere Plattformen werden
nur bei einem konkreten verbleibenden Versions- oder Berechtigungsrisiko
ergänzt. Neue Berechtigungsnamen werden als Daten übernommen; eine feste
versionsübergreifende Anzahl wird nicht vorausgesetzt.
Für die erste Lieferung wird gezielt SQL2019 nativ ergänzt, um den lokalen
loginlosen beziehungsweise eingeschränkten Kontext an der Mindestengine zu
prüfen. Eine zusätzliche pauschale 2022- oder Plattformmatrix wird daraus
nicht abgeleitet.

Der lokale Vertrag 137 besteht auf SQL2025 einschließlich vier TABLE-/JSON-
Fällen, sechs unabhängigen typisierten Schemas, nativer Werteparität, bekannten
Rollen-/DENY-Sollfällen, Objektzugriffsgegenprobe und loginlosem Kontext. Die
Nativefunktion verwaltet ihre SELECT-Berechtigung serverweit in master; die
Fixture verwendet dafür einen eigenen gebundenen Masteruser. Sein kontrollierter
DENY weist den Ausfall aller Rechtequellen nach. Erfolgreiche Kontextmetadaten
verdecken diesen Fehler nicht. Ambienttransaktion, Sentinels und identitäts-
gebundener Cleanup bestehen. Dies ist noch keine Head- oder Versionsfreigabe.

Der unabhängige technische Vertragsreview bestätigt die sechs konkreten
Schemas, Kontextbindung und Negativ-/Fehleroracles. Diese Grundlagen sind
vor dem Beginn der Produktimplementierung festgelegt. Der Benutzerauftrag autorisiert diese weitere Konkretisierung
und die anschließende kohärente Produktwelle mit Review, Tests und PR-Merge.
Objektbezogene effektive Rechte und fremde Principals bleiben offene Teile;
die erste Callerlieferung schließt Rang 6 nicht pauschal ab.

## Gelieferter Caller-Slice und Evidenz

[PR #441](https://github.com/gecompat/SQL_Server_Analyze/pull/441) ist nach
unabhängigem Vertrags-/Produktreview und gezielten Folgechecks regulär als
`33747f6d` integriert. Der qualifizierte Lieferstand lautet
`ff8e25789b2d2b16bc7fb9ebf65eebae1e629ead`.

| Prüfung | Tatsächlich bestätigter Umfang |
|---|---|
| [SQL2025-Headgate](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40187405544) | Das vollständige funktionale Gate besteht im begrenzten zweiten Versuch. Ein zusätzlicher Enginebuild wird hier nicht ausgewiesen. |
| [Native SQL2019-Abnahme](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40187401558) | Linux, 15.0.4500.2, CL150; Releasegate, Permissionmatrix und eigener Cleanup bestehen am gleichen Liefercommit. |

Der native Maschinenbeleg bindet ZIP-SHA256
`47c7db75248c769657f2ba6bfbd6c2f6b7455d094fc479b3de666b84d736d4cb`.
SQL2022 wurde für diesen Slice nicht separat nativ ausgeführt. Windows-/Entra-
Identitäten und weitere Plattformen werden damit nicht als qualifiziert ausgegeben.
Die lokalen kombinierten Verträge 137 und 189 bestätigen zusätzlich den
Callerbericht und den kanonischen Renderer bei abweichenden Instanz-/
Frameworkcollations. RAW wird ausgeführt; eine vollständige separate
Streamzählung und ein konkurrierender vollständiger Drift-Fault sind nicht belegt.

Frühere Entwicklungs- und CI-Fehler betrafen reale Fixturekontexte,
Berechtigungsort, Benutzerbindung und Rendererintegration. Sie sind vor dem
Lieferstand korrigiert und keine bestandene Qualifikation. Der erste
SQL2025-Versuch dieses Heads traf außerdem Locktimeout 1222 im unveränderten
PrepareNameFilters beim früheren DataCapture-Gate, bevor der neue Callertest
lief. Der Blocker blieb unerfasst. Die fokussierte lokale Prüfung 184 und die
einmalige Wiederholung nur der fehlgeschlagenen Jobs bestehen; eine konkrete
Sperrursache wird daraus nicht behauptet. Ein erneuter gleicher Befund verlangt
gezielte Reproduktion statt unveränderter unbegrenzter Wiederholung.
Der getrennte [SQL2025-Main-Nachlauf](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40188946001)
besteht am Mergecommit `33747f6d` im ersten Versuch. Er reproduziert den
Timeout nicht und beweist dessen Ursache nicht.

WI-0012 bleibt PARTIAL_PRODUCT_FUNCTION. Die aktuelle Ebene ist nativ
bewertet; objekt-/spaltenbezogene Rechte, fremde Principals und externe
Identitätsprüfung bleiben offen. Die nächste vertikale Grundlieferung aus
Rang 7 steht im [Endpoint-Dossier](Endpoint_Transport_Analysis_Dossier.md).

## Primärquellen

- Microsoft Learn: [sys.fn_my_permissions](https://learn.microsoft.com/en-us/sql/relational-databases/system-functions/sys-fn-my-permissions-transact-sql).
- Microsoft Learn: [Berechtigungsprüfung und Ownershipchains](https://learn.microsoft.com/en-us/sql/relational-databases/security/permissions-database-engine?view=sql-server-ver17).
- Microsoft Learn: [Serverprincipal-ID](https://learn.microsoft.com/en-us/sql/t-sql/functions/suser-id-transact-sql?view=sql-server-ver17).
- Microsoft Learn: [Datenbankprincipal-ID](https://learn.microsoft.com/en-us/sql/t-sql/functions/database-principal-id-transact-sql?view=sql-server-ver17).
- Microsoft Learn: [aktueller und ursprünglicher Kontext](https://learn.microsoft.com/en-us/sql/t-sql/functions/original-login-transact-sql?view=sql-server-ver17).
- Microsoft Learn: [aktueller Datenbankbenutzer](https://learn.microsoft.com/en-us/sql/t-sql/functions/user-transact-sql?view=sql-server-ver17).
