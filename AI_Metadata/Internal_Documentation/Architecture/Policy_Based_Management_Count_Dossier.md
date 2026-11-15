# Begrenzte PBM-Katalogzählung in der msdb-Analyse

**Stand:** 15. November 2026.  
**Status:** Source-, Guide- und nativer Fixture-Kandidat; keine neue SQL-Laufzeit- oder Main-Abnahme belegt.  
**Artefakt-UID:** `urn:uuid:01a1e04d-751d-72cf-8a16-f8c70e60541c`.  
**Registrierung:** `DEFERRED`; keine neue lesbare Arbeitselementkennung vergeben.  
**Bezug:** vorhandener WI-0010-Intake und OPS-008-Vertrag.

## Diagnosefrage und vorhandene Fläche

Der Matrixeintrag `POLICY_BASED_MANAGEMENT` fragt nach Konfiguration, Auswertung und Historie. `[monitor].[USP_MsdbHealthAnalysis]` liefert bereits eine begrenzte msdb-Dateigrößen- und Historieninventur. Die Erweiterung beantwortet nur, wie viele PBM-Policies, Conditions und Categories der aktuelle Caller über die dokumentierten Views lesen kann. Sie führt keine Policy aus und bewertet weder Regelbefolgung noch Wirksamkeit oder Gesundheit. Die übrigen PBM-Fragen bleiben offen; ein eigener öffentlicher Endpunkt und ein neues Arbeitselement entstehen nicht.

## Quelle, Rechte und Zeitgrenze

Drei zusätzliche `Area`-Zeilen heißen `PBM_POLICIES`, `PBM_CONDITIONS` und `PBM_CATEGORIES`. Ihre festen `SourceObject`-Werte sind `msdb.dbo.syspolicy_policies`, `msdb.dbo.syspolicy_conditions` und `msdb.dbo.syspolicy_policy_categories`. Jede Quelle liefert ausschließlich `COUNT_BIG(*)`. `OldestUtc`, `NewestUtc` und `SizeMb` sind in allen drei Zeilen NULL. Die Policy- und Condition-Views besitzen native `datetime`-Spalten ohne zugesicherte UTC-Semantik; die Category-View besitzt keine Datumsfelder. Das Modul liest keine dieser Zeitwerte und gibt keine PBM-Namen, Identitäten, Ausdrücke, Beschreibungen, Help-Links, Einstellungen oder Auswertungshistorien aus.

Microsoft verlangt für die drei PBM-Views die Mitgliedschaft in `PolicyAdministratorRole` der `msdb`. Das Produkt erteilt weder diese Rolle noch andere Rechte und erhöht den Caller nicht. Anders als die bestehenden optionalen Historienobjekte werden die drei PBM-Views ohne `msdb.sys.objects`-Vorprüfung direkt gelesen: Eine verborgene View darf nicht als `UNSUPPORTED` oder als leerer Count erscheinen. Ein gescheiterter Leseversuch erhält `SOURCE_UNAVAILABLE`, `RowCount = NULL`, die drei weiteren NULL-Felder und eine technische Fehlerangabe in `EvidenceLimit`; andere gelesene Areas bleiben erhalten. Ein lesbarer leerer Katalog liefert `AVAILABLE` mit `RowCount = 0`. Der Gesamtstatus wird bei einem Quellenfehler `AVAILABLE_LIMITED` und `IsPartial = 1`.

Die neuen Zählungen sind sequenziell und nicht atomar. Die PBM-Views werden direkt mit `WITH (NOLOCK)` gelesen; das bestehende Modul setzt `LOCK_TIMEOUT 0`. Die bisherigen Historienlesungen behalten ebenfalls ihr `NOLOCK`. `COUNT_BIG` kann auf großen Katalogen I/O verursachen. Die Zählwerte sind weder atomar noch eine bestätigte, konsistente Katalogaufnahme; ein sofortiger Sperrfehler bleibt als unbekannte Quelle sichtbar. `@MaxZeilen` begrenzt nach `Area` ausschließlich die Ausgabe; bei verfügbarer `msdb` und gültigen Parametern zählt `EvidenceRows` die zuvor materialisierten neun Areas. Die Quellenarbeit wird nicht verkürzt. Ein Count ist weder Retentions-, Policy-Enforcement-, Konformitäts- noch Gesundheitsurteil. Die ursprüngliche Größenzeile und alle fünf Historienquellen behalten ihre bisherigen Auswahl-, Guard-, Fehler- und Zeitregeln.

## Unveränderte öffentliche API

Die bestehende [Produktquelle](../../../Code/08_ServerHealth/210_USP_MsdbHealthAnalysis.sql) behält elf Parameter. Die Eingabe-, Typ-, Default-, NULL- und Ausgabeoptionen bleiben unverändert:

| Parameter | Typ und Default | Bestehender Eingabe- und NULL-Vertrag |
|---|---|---|
| `@MaxZeilen` | `int = 2000` | NULL wird vor der Validierung 0; 0 gibt alle nach `Area` sortierten Zeilen aus, positiv begrenzt die Ausgabe, negativ ergibt `INVALID_PARAMETER` ohne Quellenaggregation. `EvidenceRows` zählt vor der Begrenzung. |
| `@ResultSetArt` | `varchar(16) = 'CONSOLE'` | SQL bindet mehr als 16 Zeichen vor der Validierung. Nach Trim und Großschreibung bedeutet `CONSOLE` eine beschriftete Menge, `RAW` Statuskopf plus Fachzeilen, `TABLE` einen benannten Temp-Export und `NONE` keine Zeilenresultsets. NULL, leer und andere Werte sind `INVALID_PARAMETER`; TABLE/CONSOLE nutzen intern den NONE-Pfad. |
| `@ResultTablesJson` | `nvarchar(max) = NULL` | Nur TABLE verlangt genau den Schlüssel `msdbHealth` mit einer vorhandenen leeren lokalen #Temp-Seed-Tabelle. Schlüssel sind case-sensitiv, Zielnamen höchstens 116 Zeichen; `##` und das case-insensitiv reservierte `#Monitor`-Präfix sind ausgeschlossen. Außerhalb TABLE sind NULL, leer und U+0020-Leerzeichen erlaubt; andere Werte ergeben Fehler 51011. |
| `@JsonErzeugen` | `bit = 0` | 1 serialisiert das nach `@MaxZeilen` gekürzte Fachzeilenarray; NULL/0 erzeugt kein JSON. Bei SQL-Bitbindung wird ein numerischer Wert ungleich 0 zu 1. |
| `@Json` | `nvarchar(max) = NULL OUTPUT` | Optionaler OUTPUT-Empfänger. Der Eingang wird auch vor Hilfe auf NULL gesetzt; ohne `@JsonErzeugen=1` bleibt er NULL, bei leerer Fachmenge wird `[]` ausgegeben. |
| `@PrintMeldungen` | `bit = 1` | 1 druckt den Status für gewählte NONE-, CONSOLE- und TABLE-Aufrufe; RAW nicht. NULL/0 unterdrückt; ein numerisch von 0 verschiedener Wert wird als Bit 1 gebunden. Hilfe endet davor. |
| `@Hilfe` | `bit = 0` | 1 druckt Hilfe und endet vor Quellenarbeit; NULL/0 startet den Normalpfad. `@Json` wird geleert, die vier Status-/Fehler-OUTPUT-Empfänger behalten ihre Eingangswerte. |
| `@StatusCodeOut` | `varchar(40) = NULL OUTPUT` | Optionaler Empfänger: `AVAILABLE` ohne gemeldeten Quellenfehler, `AVAILABLE_LIMITED` bei mindestens einer nicht lesbaren Quelle, `UNSUPPORTED` bei fehlender `msdb`, `INVALID_PARAMETER` bei negativer Grenze oder ungültigem Modus. Fachzeilen verwenden `AVAILABLE`, `UNSUPPORTED` nur für bisherige fehlende Historienobjekte und `SOURCE_UNAVAILABLE` für Lesefehler einschließlich PBM. Hilfe lässt den Empfänger unverändert. |
| `@IsPartialOut` | `bit = NULL OUTPUT` | Optionaler Empfänger; 0 bedeutet nicht partiell, 1 begrenzte oder fehlerhafte Quellenevidenz. NULL ist nur der auslassbare Parameterdefault, kein reguläres Ergebnis. Hilfe lässt ihn unverändert. |
| `@ErrorNumberOut` | `int = NULL OUTPUT` | Optionaler Empfänger; bei regulärem Abschluss bleibt er NULL. Einzelne Quellenfehler erscheinen ausschließlich in Fachzeilen. Hilfe lässt den Eingangswert unverändert. |
| `@ErrorMessageOut` | `nvarchar(2048) = NULL OUTPUT` | Optionaler Empfänger für ungültige Parameter oder fehlende `msdb`; sonst NULL. Einzelne Quellenfehler erscheinen in Fachzeilen. Hilfe lässt den Eingangswert unverändert. |

Das bestehende Resultset besitzt exakt acht Spalten: `Area varchar(40) NOT NULL`, `SourceObject nvarchar(256) NOT NULL`, `RowCount bigint NULL`, `OldestUtc datetime2(3) NULL`, `NewestUtc datetime2(3) NULL`, `SizeMb decimal(19,2) NULL`, `StatusCode varchar(40) NOT NULL` und `EvidenceLimit nvarchar(1000) NOT NULL`. Die vier Textspalten verwenden `SQL_Latin1_General_CP1_CS_AS`. RAW behält die zwei Resultsets, TABLE das benannte Achtspaltenschema, CONSOLE eine beschriftete Menge und NONE null Zeilenresultsets. Optionales JSON bleibt ein Array derselben nach `Area` und `@MaxZeilen` ausgewählten Fachzeilen; kein neues Feld oder Envelope entsteht. Der [öffentliche Guide](../../../Documentation/Analysis_Guides/Procedures/USP_MsdbHealthAnalysis.md) führt die unveränderten Aufrufbeispiele und alle Parameter einzeln.

## Begrenzte native Fixture und Lieferung

Die [native Fixture 122](../../../Code/Tests/ServerHealth/122_OPS008_Msdb_Health_Runtime_Contract.sql) im freigegebenen isolierten SQL-Server-2025-Container prüft weiterhin die fünf Historien-Areas, `DATABASE_SIZE`, NULL-/0-/1-Limits sowie TABLE-/CONSOLE-/JSON-Parität. Sie ergänzt exakt drei PBM-Areas mit nativen Counts und NULL für Zeit und Größe. Ein eigener eingeschränkter User ohne PBM-Rolle muss unbekannte Counts als `SOURCE_UNAVAILABLE` erhalten; dies ist keine allgemeine Aussage über jeden produktiven Principal.

Für einen positiven Category-Fall legt ausschließlich die Fixture eine kollisionsgeprüfte eigene Kategorie über das dokumentierte `msdb.dbo.sp_syspolicy_add_policy_category` mit `@mandate_database_subscriptions=0` an. Die zurückgegebene ID, der Name, der native Countzuwachs um eins und das Fehlen eigener Policy- und Subscription-Referenzen werden gebunden. TABLE und JSON müssen denselben neuen Count zeigen; Policies und Conditions werden nur gegen ihre nativen, möglicherweise leeren Views gezählt. Das dokumentierte `sp_syspolicy_delete_policy_category` entfernt die eigene Kategorie anhand der ID oder des eindeutigen eigenen Namens auch nach Fehlern. Der Rückbau prüft ihre Abwesenheit und den vorherigen Count. Es werden keine Policy, Condition, Subscription, Ausführung, Agent-Job oder externe Verbindung angelegt.

Die drei Views und die beiden Category-Procedures sind dokumentierte SQL-Server-Verträge ohne erkennbaren zusätzlichen Versionszweig. Die impact-basierte Erstabnahme bleibt deshalb bei SQL Server 2025/CL170 im kanonischen 1+0+N-Modell; daraus folgt kein nativer SQL-Server-2019- oder -2022-Nachweis. Vor Veröffentlichung sind die drei neuen Systemquellen, die begrenzte Coverage und die betroffenen Lesewege zu binden. Die OPS-Installationskopie benötigt wegen der geänderten Produktquelle eine kanonische Neugenerierung.

## Primärquellen

- [PBM-Policies](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/syspolicy-policies-transact-sql?view=sql-server-ver17)
- [PBM-Conditions](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/syspolicy-conditions-transact-sql?view=sql-server-ver17)
- [PBM-Categories](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/syspolicy-policy-categories-transact-sql?view=sql-server-ver17)
- [Kategorie anlegen](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-syspolicy-add-policy-category-transact-sql?view=sql-server-ver17)
- [Kategorie entfernen](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-syspolicy-delete-policy-category-transact-sql?view=sql-server-ver17)
