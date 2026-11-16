# OBJECT-Rechte im aktuellen Ausführungskontext

**Stand:** 16. November 2026.  
**Status:** begrenzter read-only OBJECT-Bericht mit bestandener SQL-Server-2025-Head- und Main-Abnahme; der ergänzende Spalten-Grant-Fall ist noch nicht nativ abgenommen.  
**Artefakt-UID:** `urn:uuid:01a1e5ad-9c65-7006-b329-3589245b1ed0`.  
**Registrierung:** `DEFERRED`; keine zusätzliche lesbare Kennung vergeben.  
**Arbeitselement:** Teil des vorhandenen `WI-0012`; keine neue Arbeitselementnummer.

## Diagnosefrage und Abgrenzung

Die bestehende [Caller-Rechteanalyse](Caller_Permission_Analysis_Dossier.md) liefert native SERVER- und DATABASE-Rechte. `monitor.USP_CurrentObjectPermissionAnalysis` ergänzt genau ein ausdrücklich angegebenes Schema-/Objektpaar je ausgewählter Datenbank. Unter dem tatsächlich aktiven Caller liest sie `sys.fn_my_permissions` mit Klasse `OBJECT`. Eine native `subentity_name`-Spalte bleibt eine Bezeichnung im OBJECT-Ergebnis und beweist keine vollständige COLUMN-Rechte- oder Statementausführung.

Ein leerer Rückgabesatz, Metadatenunsichtbarkeit oder der native Fehler 15151 belegt weder die Abwesenheit des Objekts noch einen konkreten DENY. Der Bericht ermittelt keine Rechte anderer Principals, keine Grant-/Deny-Kette und keine Nutzdaten. Er führt weder `EXECUTE AS` noch eine Datenabfrage am Zielobjekt aus und erteilt keine Rechte.

## Auswahl und Eingabevertrag

Die gemeinsame Datenbankauswahl verarbeitet standardmäßig sichtbare ONLINE-Benutzerdatenbanken mit Zugriff und ohne Snapshots. `@DatabaseNames nvarchar(max)=NULL`, `@SystemdatenbankenEinbeziehen bit=0` und `@DatabaseNamePattern nvarchar(4000)=NULL` behalten den gemeinsamen Listen-, Pattern- und Opt-in-Vertrag. Es gibt weder einen CURRENT-Default noch `@MaxDatenbanken`. Ein genaues einteiliges `@SchemaName nvarchar(max)=NULL` und `@ObjectName nvarchar(max)=NULL` ist im regulären Pfad erforderlich; die Defaults erlauben `@Hilfe=1` ohne Namen. Leere, nur aus U+0020 bestehende oder über 256 UTF-16-Bytes lange Rohwerte sind ungültig. Die Procedure quotiert die Namen einzeln und prüft auch den zusammengesetzten Namen vor der `sysname`-Bindung auf 256 UTF-16-Bytes. Die tatsächliche Zieldatenbank-Collation bestimmt die native Objektauflösung.

`@MaxZeilen int=1000` begrenzt positiv erst nach der Quellenaufnahme; NULL und 0 sind unbegrenzt. `@LockTimeoutMs int=0` akzeptiert 0 bis 60000 Millisekunden. `@ResultSetArt varchar(16)='CONSOLE'` erlaubt CONSOLE, RAW, TABLE oder NONE. TABLE verwendet `@ResultTablesJson nvarchar(max)=NULL` und den vorhandenen lokalen Zieltabellenvertrag. `@JsonErzeugen bit=0` steuert `@Json nvarchar(max)=NULL OUTPUT`; `@PrintMeldungen bit=1` und `@Hilfe bit=0` steuern Meldungen und Hilfe. Die vier optionalen OUTPUTs `@StatusCodeOut varchar(40)`, `@IsPartialOut bit`, `@ErrorNumberOut int` und `@ErrorMessageOut nvarchar(2048)` haben jeweils Default NULL. Die [Procedure-Seite](../../../Documentation/Analysis_Guides/Procedures/USP_CurrentObjectPermissionAnalysis.md) erklärt für jeden der 17 Parameter Eingabeform, NULL, Leerwert, Default und Fehlerpfad.

## Fünf Ausgaben und Status

`moduleStatus` enthält den Berichtszustand und das angefragte Namenspaar. `callerContexts` enthält numerische IDs aus der tatsächlichen Quellenaufnahme. `objectPermissions` trägt Datenbank-ID/-Name, angefragte Namen sowie native `entity_name`, `subentity_name` und `permission_name`. `sourceStatus` zeigt Auswahl- und OBJECT-Quelle mit `ObservedRows`, `ReturnedRows`, `IsLimited`, Sichtbarkeitsgrenze und numerischem Fehler. `warnings` erklärt begrenzte Auswahl-/Quellzustände. Die [Resultsetinventur](../../../Metadata/Inventory/ResultSets.csv) bindet Typen, NULLbarkeit und Reihenfolge. RAW liefert fünf Mengen, TABLE die zugeordneten fünf lokalen Ziele, CONSOLE ein fachliches Resultset und NONE keines. Optionales JSON enthält `meta` und dieselben fünf Arrays.

Jede ausgewählte Datenbank wird isoliert gelesen. Ein nativer Fehler bleibt mit Originalnummer und -meldung im betroffenen Quellenstatus erhalten, während andere Datenbanken weiter verarbeitet werden. `EMPTY_UNPROVEN` und `ERROR_HANDLED` sind keine Existenz- oder Rechteurteile. Die Resultate sind caller-sichtbar und nicht atomar. Ein positives `@MaxZeilen` kann einzelne Rechte aus der Ausgabe nehmen, ohne die Quellenarbeit zu begrenzen.

## Native Fixture und Nachweisgrenze

Die [Native145-Fixture](../../../Code/Tests/ServerHealth/145_CurrentObjectPermission_Runtime_Contract.sql) nutzt zwei synthetische eigene Datenbanken und einen eigenen SID-gebundenen Caller. Eine Datenbank erhält eine eigene SELECT-Freigabe auf das ganze Probeobjekt, die andere einen eigenen SELECT-DENY am gleichnamigen Objekt. Ein direkter nativer 229-Gegencheck und die unabhängige `sys.fn_my_permissions`-Zeilenparität begrenzen die positive Aussage. JSON, TABLE, RAW, CONSOLE, NONE, Auswahl, Namenslängen, Callerzustand und normaler/einzelner Fehler-Rückbau werden geprüft. Die Fixture erzeugt keine reale Berechtigungs- oder Kundendatenlage. Beide Datenbanken und der Principal sind auch auf Fehlerpfaden nur bei gebundener Eigenidentität zu entfernen; andernfalls bleibt ein Recoveryfehler für den isolierten Container-Stop.

Die ursprüngliche Fixture bestand im [Head-Lauf 43961724262](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43961724262) und im [ersten Mainlauf 43964989798](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43964989798) das vollständige SQL-Server-2025-/CL170-Release-Gate einschließlich Native145, Berechtigungs-, Regex- und Standalone-Verträgen sowie StopSynthetic. Die statische [1053-Prüfung](../../../Code/Tests/Static/1053_Validate_CurrentObjectPermission_Contract.py) bindet Quellvertrag, ABI, Inventare und Release-Gate; sie ersetzt keine native Abnahme. Der zusätzliche Fixture-Kandidat legt in der eigenen Datenbank eine zweite Tabelle an und erteilt dem eigenen Testlogin ausschließlich SELECT auf deren Spalte `Value`. Unter diesem Caller fordert er eine native `fn_my_permissions`-Zeile mit nichtleerem `subentity_name=Value`; fünf im impersonierten Batch erzeugte TABLE-Ziele werden vor `REVERT` als JSON gesichert und bidirektional mit den nativen Zeilen und dem Produkt-JSON verglichen. Dieser neue Fall ist bis zum ausgewählten nativen Head- und Main-Gate unqualifiziert. Die bestandenen Gates belegen weder SQL Server 2019/2022 noch eine vollständige COLUMN- oder Statement-Rechteanalyse.

## Primärquellen

- [Microsoft Learn: sys.fn_my_permissions](https://learn.microsoft.com/en-us/sql/relational-databases/system-functions/sys-fn-my-permissions-transact-sql?view=sql-server-ver17)
- [Microsoft Learn: Metadata Visibility Configuration](https://learn.microsoft.com/en-us/sql/relational-databases/security/metadata-visibility-configuration?view=sql-server-ver17)
