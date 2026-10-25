# Serverprincipals, Rollen und Login-Lifecycle

**Stand:** 25. Oktober 2026.
**Status:** Analyse und erster Schnittstellenvorschlag; nicht implementiert.
**Artefakt-UID:** `urn:uuid:01a17168-ab02-76fd-9f7c-5816187aeeef`.
**Registrierung:** `DEFERRED`; noch keine finale lesbare Referenz vergeben.
**Planung:** Rang 6 der [Entwicklungswellen](../Quality/Development_Waves_2026-10.md),
unter dem bestehenden Intake `WI-0010`.

## Diagnosefrage und vorhandene Abdeckung

Die Analyse soll zeigen, welche Serverprincipals der Caller sieht, welche
direkten Rollenmitgliedschaften und expliziten Serverberechtigungen sichtbar
sind und welche SQL-Login-Policies konfiguriert sind. Sichtbare Katalogzeilen
werden von der Vollständigkeit der Metadatensicht und von tatsächlich
wirksamen Berechtigungen getrennt.

`USP_ServerSecurityConfiguration` liest Serveroptionen, Dienste und
Servereigenschaften. `USP_AuditConfigurationAnalysis` untersucht die
Auditkonfiguration; `USP_EncryptionAnalysis` untersucht Verschlüsselungsmetadaten.
Keine dieser Funktionen liefert das hier benötigte Principal-/Rollenmodell.
Eine eigene eng begrenzte Procedure wird vorgeschlagen, damit deren
serverweiter Scope und zusammenhängende Resultsets die vorhandene
Konfigurationsausgabe nicht verändern.

Der erste Implementierungsschritt betrifft ausschließlich Servermetadaten.
Datenbankprincipals, enthaltene Benutzer, Datenbankownership, verwaiste
Benutzerbindungen und effektive Berechtigungsauswertung bleiben weitere
ausdrücklich offene Teile von Rang 6. Die neue Procedure allein würde daher
keinen vollständigen Reifeabschluss dieses Rangs begründen.

## Quellen und Beweisgrenzen

| Quelle | Benötigte Projektion | Aussagegrenze |
|---|---|---|
| `sys.server_principals` | Lokale Principal-ID, Name, Typ, deaktivierter Zustand, Erstellungs-/Änderungszeit und Rollenownership | Eine leere oder eingeschränkte Sicht beweist keine Abwesenheit weiterer Principals. IDs sind lokale Momentaufnahmebindungen. |
| `sys.server_role_members` | Direkte Rollen-ID und Mitglied-ID | Keine AD-/Entra-Gruppenexpansion und keine transitive oder effektive Rechteaussage. Sichtbare Kanten bleiben bei fehlendem Namenslookup erhalten. |
| `sys.server_permissions` | Grantee-/Grantor-ID, Klasse, Major-/Minor-ID, Recht und Zustand | Implizite Rechte fester Rollen sind nicht vollständig als explizite Zeilen enthalten. GRANT und DENY werden nicht zu einem selbst berechneten effektiven Ergebnis verdichtet. |
| `sys.sql_logins` | Principal-ID, `is_policy_checked` und `is_expiration_checked` | Die Schalter beweisen weder Passwortstärke noch letzte Nutzung, Kompromittierung oder tatsächliche externe Loginfähigkeit. |

Jede Quelle wird getrennt materialisiert und erhält eine UTC-Zeitklammer.
Die vier Aufnahmen bilden keine atomare Sicherheitstransaktion. Es gibt keine
Abfrage von `password_hash`, Credentials, Tokens, Schlüsselmaterial,
Passwortwerten, Paket- oder Anwendungsinhalten. Namen und fachlich benötigte
Identitätsmetadaten bleiben in Laufzeitausgaben erhalten; gespeicherte Beispiele,
Tests und Evidenzzusammenfassungen verwenden ausschließlich synthetische Werte.

## Vorgeschlagener öffentlicher Vertrag

Der Vorschlag lautet `[monitor].[USP_ServerPrincipalAnalysis]`. Der übernommene
Benutzerauftrag gibt den beschriebenen fachlichen Umfang zur autonomen
Umsetzung frei. Diese bestehende funktionsbezogene Freigabe wird nicht erneut
angefragt. Die technische Konkretisierung wird vor Implementierung fertiggestellt
und unabhängig fachlich geprüft. Tatsächlich zusätzliche Grenzen wie externe
Identitätsabfragen, Rechteerweiterungen oder Eingriffe in bestehende Systeme
werden dadurch nicht freigegeben.

| Parameter | Default und Bedeutung |
|---|---|
| `@MaxZeilen int` | `1000`; begrenzt jedes fachliche Resultset getrennt. `0` oder `NULL` bedeutet unbeschränkt, negative Werte sind ungültig. |
| `@LockTimeoutMs int` | `0`; keine unbeschränkte Wartezeit und keine Änderung des Callerwerts nach Abschluss oder Fehler. |
| `@ResultSetArt varchar(16)` | `CONSOLE`; zusätzlich RAW, TABLE und NONE gemäß Frameworkvertrag. |
| `@ResultTablesJson nvarchar(max)` | `NULL`; nur TABLE und ausschließlich die unten benannten Resultsets. |
| `@JsonErzeugen bit`, `@Json nvarchar(max) OUTPUT` | `0` beziehungsweise `NULL`; separates versioniertes JSON aus derselben materialisierten Datenbasis. |
| `@PrintMeldungen bit`, `@Hilfe bit` | `1` beziehungsweise `0`; Hilfe liest keine fachlichen Quellen. |
| Status-/Fehler-OUTPUT-Parameter | Bestehende Namen `@StatusCodeOut`, `@IsPartialOut`, `@ErrorNumberOut`, `@ErrorMessageOut`. |

RAW und TABLE erhalten native Schemas. CONSOLE liefert genau ein fachliches
Resultset mit einer verständlichen Leerzeile; NONE unterdrückt sämtliche
Resultsets und kann weiterhin JSON beziehungsweise Status über OUTPUT liefern.
TABLE-Ziele bleiben lokale Temp-Tabellen mit dem vorhandenen Mappingvertrag.

| Benanntes Resultset | Vorgesehene Fachfelder |
|---|---|
| `moduleStatus` | Modul, Aufnahmezeit, Status, Partialität, Gesamtumfang und Aussagegrenze. |
| `principals` | `PrincipalId int`, `PrincipalName sysname`, `PrincipalType char(1)`, `PrincipalTypeDescription nvarchar(60)`, `IsDisabled bit`, `CreatedAt datetime`, `ModifiedAt datetime`, `IsFixedRole bit`, `OwningPrincipalId int`. |
| `roleMemberships` | `RolePrincipalId int`, `RoleName sysname NULL`, `MemberPrincipalId int`, `MemberName sysname NULL`; sichtbare Kanten werden nicht durch innere Namensjoins entfernt. |
| `permissions` | Grantee-/Grantor-ID und optional sichtbare Namen, `Class tinyint`, `ClassDescription nvarchar(60)`, `MajorId int`, `MinorId int`, `PermissionName nvarchar(128)`, `PermissionState char(1)`, `PermissionStateDescription nvarchar(60)`. |
| `loginPolicies` | `PrincipalId int`, sichtbarer Loginname sowie `IsPolicyChecked bit` und `IsExpirationChecked bit`. Fehlende Sicht bleibt von ausdrücklich deaktivierten Schaltern unterscheidbar. |
| `sourceStatus` | Quellschlüssel, Beginn/Ende der Aufnahme, Status, Sichtbarkeitsgrenze, beobachtete und ausgegebene Zeilenzahl, Limitstatus sowie native Fehlerdaten. |
| `warnings` | Warncode, Quellbezug und konkrete Evidenzgrenze; keine automatische Sicherheitsfreigabe oder DDL-Empfehlung. |

SchemaVersion beginnt bei 1. Die endgültige Feldfolge, Nullbarkeit,
Zeichentypen und Textcollations werden vor Produktimplementierung in den
Resultsetvertrag übernommen und unabhängig geprüft. Die aufgeführten Fachfelder
sind noch kein veröffentlichter API-Vertrag.

## Sichtbarkeit, Berechtigungen und Eigenlast

Die Procedure läuft im Caller-Kontext ohne `EXECUTE AS OWNER`, Signatur,
Rechtevergabe, Linked Server oder Remotezugriff. Ein erfolgreiches SELECT ist
kein Vollständigkeitsnachweis. Quelle und Modul müssen eingeschränkte oder
nicht bewiesene Sicht ausdrücklich ausweisen; ein pauschaler erfolgreicher
HAS_PERMS_BY_NAME-Aufruf ersetzt keine quellenspezifische Prüfung.

Der erste sichere Vertrag kann ausschließlich sichtbare Metadaten mit
`VISIBLE_ONLY` ausgeben und die Vollständigkeit ausdrücklich unbewiesen lassen.
Ein späterer stärkerer Vollständigkeitsstatus benötigt einen gesondert
qualifizierten Kontext. Verweigerte Quelle, erfolgreicher Leerfall und
eingeschränkte sichtbare Teilmenge bleiben unterscheidbar.

Die vier lokalen Katalogquellen besitzen keine Nutzdatenscans. Limits werden
sichtbar und deterministisch nach nativen Identitätsschlüsseln angewendet;
ausgegebene Quellmengen, Namensauflösung und Mengenbasis dürfen sich dabei nicht
gegenseitig verfälschen. Ein Ausgabelimit ist keine Garantie einer entsprechend
begrenzten Kataloglesearbeit. Callertransaktion, LOCK_TIMEOUT und XACT_ABORT
werden erhalten; Fehlerpfade dürfen eine vorhandene Transaktion nicht übernehmen.

## Unabhängige Abnahme und Integration

Die Produktabnahme prüft native Sollwerte direkt gegen eigene synthetische
Principals, Rollen und Grants. Erwartungswerte werden nicht aus dem
Procedure-JSON abgeleitet. Erforderlich sind insbesondere direkte und
verschachtelte Rollen als getrennte Kanten, GRANT/DENY/GRANT_WITH_GRANT_OPTION,
deaktivierte Logins, beide Policyflags, fehlende Namenssicht, leere Auswahl,
Limitüberschreitung, Quellfehler und eingeschränkte Caller.

RAW, TABLE, CONSOLE, NONE und JSON benötigen Mengen-, Schema-, Null- und
Werteparität im tatsächlich definierten Umfang. Hilfe und ungültige Parameter
lesen keine fachlichen Quellen. Die vorhandenen synthetischen Tests prüfen
keine echten AD-/Entra-Anmeldungen oder Passwortfunktion. Eigene Principals,
Rollen, Grants und Testdatenbanken werden über gebundene Ownership vollständig
bereinigt; fremde Ressourcen bleiben unverändert.

SQL Server 2025 ist die primäre Engine. Wegen der nativen Unterschiede in
Metadatensichtbarkeit und Securitypermissions werden betroffene ältere native
Engines gezielt gemäß CI-Teststrategie qualifiziert; Compatibility Levels
ersetzen diese Prüfung nicht. Eine breite Plattformmatrix ohne konkretes Risiko
ist nicht vorgesehen.

Zur vertikalen Lieferung gehören Einzelquelle, Installer, Inventare,
Navigator/Hilfe, Procedure-Seite, relevante Leitfäden und betroffene Tests.
Erst tatsächliche Abnahme ändert Produktstatus oder Reife. Der eigenständige
SSIS-Strang ist kein Implementierungs-, Test- oder Lababhängiger dieses Scopes.

## Primärquellen

Die Quellen wurden am 25. Oktober 2026 gelesen. Sie belegen Katalogbedeutung
und Sichtbarkeitsgrenzen; sie sind keine Laufzeitevidenz des vorgeschlagenen Moduls.

- [Serverprincipals](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-principals-transact-sql?view=sql-server-ver17).
- [Direkte Serverrollenmitgliedschaften](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-role-members-transact-sql?view=sql-server-ver17).
- [Explizite Serverberechtigungen](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-permissions-transact-sql?view=sql-server-ver17).
- [SQL-Login-Policies](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-logins-transact-sql?view=sql-server-ver17).
- [Metadatensichtbarkeit](https://learn.microsoft.com/en-us/sql/relational-databases/security/metadata-visibility-configuration?view=sql-server-ver17).
