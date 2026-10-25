# Effektive Berechtigungen des aktuellen Ausführungskontexts

**Stand:** 25. Oktober 2026.
**Status:** konkretisierter Folgescope vor technischer Vertragsfestlegung und Produktimplementierung.
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

Der aktuelle Kontext wird je Quelle mit SUSER_SNAME() und CURRENT_USER
beschrieben. Das sind beobachtete Kontextnamen, keine Directoryprüfung und
keine dauerhafte Identität. Kontext- und Rechteaufnahme werden zeitlich
gekoppelt; ein beobachteter Wechsel dieser Kontextnamen verwirft die betreffende
Teilmenge. Unveränderte Namen beweisen keine unveränderte Rollen- oder
Modulidentitätsmenge.
Die konkreten nativen Schemas und dieser Bindungsvertrag werden vor dem
Implementierungsbeginn im unabhängigen Vertragsreview eingefroren.

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
Materialisierung. CONSOLE liefert die Datenbankrechte als eine fachliche
Menge; der Serverumfang bleibt über RAW, TABLE und JSON erreichbar. TABLE
verwendet ausschließlich die gemeinsame benannte Mehrfachzuordnung.
Der Gesamtbefund bleibt AVAILABLE_LIMITED mit IsPartial=1, weil nur die
benannten Securableebenen im aktuellen Kontext aufgenommen werden.

Erwartete Parameter- und TABLE-Ablehnungen sowie gefangene äußere Fehler
kehren regulär mit Status, Diagnose-OUTPUT, Diagnosecode als RETURN-Wert und
JSON-NULL zurück. Der Callerzustand, seine Transaktion und sein Datenbankkontext
bleiben erhalten. Nicht gefangene Verbindungs- oder Engineabbrüche erhalten
keine erfundene Rückgabe- oder Wiederherstellungsgarantie.

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

Nach dem unabhängigen Vertragsreview werden sechs konkrete Schemas, die
Kontextbindung und die Negativ-/Fehleroracles vor der Implementierung
festgelegt. Der Benutzerauftrag autorisiert diese weitere Konkretisierung
und die anschließende kohärente Produktwelle mit Review, Tests und PR-Merge.
Objektbezogene effektive Rechte und fremde Principals bleiben offene Teile;
die erste Callerlieferung schließt Rang 6 nicht pauschal ab.

## Primärquellen

- Microsoft Learn: [sys.fn_my_permissions](https://learn.microsoft.com/en-us/sql/relational-databases/system-functions/sys-fn-my-permissions-transact-sql).
- Microsoft Learn: [Berechtigungsprüfung und Ownershipchains](https://learn.microsoft.com/en-us/sql/relational-databases/security/permissions-database-engine?view=sql-server-ver17).
- Microsoft Learn: [aktueller und ursprünglicher Kontext](https://learn.microsoft.com/en-us/sql/t-sql/functions/original-login-transact-sql?view=sql-server-ver17).
- Microsoft Learn: [aktueller Datenbankbenutzer](https://learn.microsoft.com/en-us/sql/t-sql/functions/user-transact-sql?view=sql-server-ver17).
