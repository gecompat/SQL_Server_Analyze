# MSDTC und verteilte Transaktionen: SQL-sichtbarer Inventarvertrag

**Stand:** 27. Oktober 2026.
**Status:** Umgesetzter Kandidat für Schritt 40; exakte SQL-Server-2025-CI-Evidenz steht bis zur Head-Prüfung aus. Das Dossier belegt weder einen positiven aktiven DTC-Datensatz noch externe Infrastrukturgesundheit oder einen Modul-Reifeabschluss.
**Artefakt-UID:** urn:uuid:01a17e47-5b00-794a-bba8-2c6be0dd2df8.
**Registrierung:** DEFERRED; eine lesbare Kennung wird erst nach diesem Dossier durch die Registry-Authority vergeben.
**Arbeitselement:** kontinuierlicher Intake WI-0010; kein neues Arbeitselement.
**Planung:** Rang 17, Schritt 39; bedingte Implementierungswelle 40.

## Diagnosefrage und Beweisgrenze

Ein read-only SQL-Server-Inventar kann drei unterschiedliche Tatsachen aus dem lokalen Engine-Kontext zeigen:

1. den aktuellen Laufzeitwert und konfigurierten Wert der veralteten Serveroption remote proc trans;
2. die sichtbare Einstellung is_remote_proc_transaction_promotion_enabled je sichtbarem Linked Server; und
3. derzeit sichtbare Einträge lokaler aktiver Transaktionen mit transaction_type = 4, einschließlich lokalem Transaktionsbezeichner, Beginn und Status.

Diese Tatsachen beschreiben Konfiguration und momentan von SQL Server dargestellte Transaktionsmetadaten. Eine positive Konfigurationsoption beweist weder eine aktive verteilte Transaktion noch eine erreichbare oder gesunde MSDTC-Instanz. Eine aktive DMV-Zeile beweist nicht, dass alle Teilnehmer erreichbar sind, ein Commit erfolgreich abgeschlossen wurde oder eine Recovery vollständig ist. Ein leeres Ergebnis beweist keine globale Abwesenheit; Metadatensicht und Berechtigungen begrenzen die Beobachtung.

Der Vertrag ist serverweit. Die drei Quellen sind nicht an eine einzelne Datenbank gebunden; eine Datenbankauswahl wäre fachlich irreführend. Ein eigener Server-Slice hält den Kontext aus der Ausführungsdatenbank unabhängig.

MSDTC-Dienstzustand, Windows-Dienststeuerung, Linux-Prozess- und mssql-conf-Einstellungen, RPC-Endpunkt, Firewall, Routing, Host- oder Clusterstatus, Netzwerkverbindung, Sicherheitsverhandlung, Recovery-Entscheidung und Teilnehmergesundheit sind externe Infrastrukturgrenzen. Der Slice prüft sie nicht. Er startet keine verteilte Transaktion und führt keinen entfernten Aufruf, keine Abfrage oder Probe aus. Eine echte positive Distributed-Commit-/Rollback-Abnahme setzt eigens verfügbares DTC- und Teilnehmerinfrastruktur voraus und bleibt außerhalb der SQL-2025-CI-Qualifikation.

## Native Quellen und Feldbindung

Der portable Produktumfang zielt auf SQL Server 2019 und höher. Die unten aufgeführten Spalten werden in den Microsoft-Referenzen für SQL Server dokumentiert. SQL Server 2022 und höher trennen die erforderlichen Serverzustandsberechtigungen; der Caller wird nicht hochgestuft. Die Abfrage läuft ohne Identitätswechsel und ohne grantierte Rechte.

| Quellgruppe | Native Quelle | Exakte verwendete Quellspalten und Typen | Projektionsgrenze |
|---|---|---|---|
| Serverkonfiguration | sys.configurations, nur name = N'remote proc trans' | name nvarchar(35), value sql_variant, value_in_use sql_variant, is_dynamic bit | Nur diese einzelne Konfiguration. Die zwei Werte werden nur bei exaktem sql_variant-Basistyp int ausgegeben; ein anderer nicht-NULL-Basistyp wird als typisiertes NULL mit fester Warnung behandelt. minimum, maximum, description, alle anderen Optionen und jede Änderung werden ausgeschlossen. |
| Linked-Server-Promotion | sys.servers, nur sichtbare Zeilen mit is_linked = 1 | server_id int, is_linked bit, is_remote_proc_transaction_promotion_enabled bit, modify_date datetime | Ausgabe nur von server_id, Promotion-Bit und Änderungszeit. Linked-Server-Name, Provider, Quelle, Katalog, Provider-String, Timeout, Login-Mapping und sonstige Topologie werden nicht ausgegeben. Alte sp_addserver-Remote-Server mit is_linked = 0 sind nicht Bestandteil dieses Einstellungsinventars. |
| Aktive verteilte Transaktionen | sys.dm_tran_active_transactions, nur transaction_type = 4 | transaction_id bigint, transaction_begin_time datetime, transaction_type int, transaction_state int | Nur die genannten vier Metadatenfelder. transaction_id ist instanzlokal, nicht instanzübergreifend eindeutig. Transaktionsname, UOW/GUID, Sitzung, Login, Anwendung, Statement-/Batchtext, Query Handle und nicht unterstützte Statusfelder bleiben ausgeschlossen. dtc_state wird nicht gelesen; Microsoft weist es als nur für Azure SQL Database geltend aus. |

Die sys.configurations-Werte value und value_in_use sind sql_variant. Nur SQL_VARIANT_PROPERTY(..., N'BaseType') = N'int' erlaubt die explizite int-Konvertierung; bloße Konvertierbarkeit reicht nicht. Native NULL-Werte bleiben NULL ohne Typwarnung. Nicht-NULL-Werte mit anderem oder nicht auswertbarem Basistyp bleiben als typisiertes NULL und erzeugen CONFIG_VALUE_TYPE_UNSUPPORTED. Die Einstellung remote proc trans ist eine rückwärtskompatible Option für Remote-Procedure-Aufrufe und wird von Microsoft für neue Entwicklung als abzulösen beschrieben. Sie ist nicht mit der Linked-Server-Option gleichzusetzen. remote proc transaction promotion bezieht sich auf Remote-Prozeduraufrufe über Linked Server; eine aktive Sitzung kann diese Beziehung beeinflussen. Distributed Queries und providerabhängige ITransactionLocal-Unterstützung werden nicht als Konfigurationsbeleg abgeleitet.

Die aktuelle sys.servers-Sicht kann je Caller eingeschränkt sein. Vor SQL Server 2022 sehen alle Logins die Linked-/Remote-Server bei der Standardzuordnung; wenn diese Zuordnung entfernt wurde, benötigen vollständige Sicht ALTER ANY LINKED SERVER oder ALTER ANY LOGIN ON SERVER oder die Mitgliedschaft in setupadmin/sysadmin. Für SQL Server 2022+ dokumentiert Microsoft VIEW SERVER SECURITY STATE, um alle Linked-/Remote-Server sehen zu können. Für die DMV ist auf SQL Server 2019 VIEW SERVER STATE, ab SQL Server 2022 VIEW SERVER PERFORMANCE STATE erforderlich. sys.configurations ist vor SQL Server 2022 über public lesbar und verlangt ab SQL Server 2022 VIEW SERVER PERFORMANCE STATE. Die jeweiligen SELECT- und Sichtbarkeitsbedingungen gelten zusätzlich. Ein Fehler einer Quellgruppe wird als Quellenfehler erfasst und nicht als leeres Resultat ausgegeben.

Auf SQL Server unter Linux wird MSDTC laut Microsoft ab SQL Server 2017 CU 16 unterstützt. Die Einrichtung benötigt externe RPC-/DTC-Konfiguration und Netzwerkregeln; dieses SQL-Inventar liest diese Werte nicht. Microsoft dokumentiert außerdem Einschränkungen für Linux-Hochverfügbarkeitsszenarien. Ein erfolgreicher SQL-2025-Containerlauf qualifiziert daher keine Host-, DTC- oder AG-Konfiguration.

## Vorgeschlagener Produktvertrag für Schritt 40

Vorgeschlagene Procedure: [monitor].[USP_DistributedTransactionInventory].
Der Slice fügt keine Auswahl nach Datenbank oder Servername, keine Callerrollen, keine Grants und keine versionierten Alternativpfade hinzu. Ausgabe ist caller-sichtbar und ausdrücklich nicht vollständig.

### Parameter

| Position | Parameter | Typ | Default / Verhalten |
|---:|---|---|---|
| 1 | @MaxZeilen | int | 1000; positiver Wert begrenzt jede der drei Inventarmengen separat und global über den jeweiligen serverweiten Bestand. NULL oder 0 bedeutet unbegrenzt; negative Werte sind ungültig. |
| 2 | @LockTimeoutMs | int | 0; zulässig sind 0 bis 60000, NULL und negative Werte sind ungültig. Der vom Caller gelieferte Zustand wird nach Erfolg oder abgefangenem Fehler wiederhergestellt. |
| 3 | @ResultSetArt | varchar(16) | CONSOLE; unterstützt RAW, TABLE und NONE nach dem Frameworkvertrag. |
| 4 | @ResultTablesJson | nvarchar(max) | NULL; Mapping nur für TABLE und ausschließlich für die sieben unten genannten Mengen. |
| 5 | @JsonErzeugen | bit | 0; optionales JSON aus derselben materialisierten Datenbasis. |
| 6 | @Json | nvarchar(max) OUTPUT | NULL. |
| 7 | @PrintMeldungen | bit | 1. |
| 8 | @Hilfe | bit | 0; Hilfe liest keine Fachdatenquellen. |
| 9 | @StatusCodeOut | varchar(40) OUTPUT | NULL; bestehender Frameworkstatus. |
| 10 | @IsPartialOut | bit OUTPUT | NULL; bei caller-beschränkter Sicht standardmäßig 1. |
| 11 | @ErrorNumberOut | int OUTPUT | NULL. |
| 12 | @ErrorMessageOut | nvarchar(2048) OUTPUT | NULL. |

Es gelten der vorhandene Fehler-, OUTPUT-, JSON-, Locktimeout- und TABLE-Mappingvertrag der Servermodule. Die Procedure übernimmt oder beendet keine Caller-Transaktion. Sie vergibt keine Rechte, verwendet kein EXECUTE AS, keine Signatur, keinen Linked Server und keine Verbindung nach außen.

### Resultset-Reihenfolge und Ausgabe

RAW liefert sieben Resultsets in dieser Reihenfolge. TABLE exportiert genau dieselben benannten Mengen und physischen Schemas. JSON verwendet schemaVersion = 1, die bestehende meta-Hülle mit resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber und errorMessage sowie Array-Schlüssel in derselben Reihenfolge. NONE unterdrückt alle fachlichen Resultsets, erhält aber OUTPUT-Status und optionales JSON. CONSOLE liefert genau eine Zusammenfassung mit folgendem Schema: StatusCode varchar(40) NOT NULL, IsPartial bit NOT NULL, ProductMajorVersion nvarchar(128) NULL, ConfiguredValue int NULL, RunningValue int NULL, LinkedServerRowsReturned bigint NOT NULL, ActiveTransactionRowsReturned bigint NOT NULL, Detail nvarchar(1000) NOT NULL. Zeilenzahlen bezeichnen ausgegebene sichtbare Zeilen nach Limit, keine Gesamtzählung. RAW/TABLE/JSON erzeugen bei leeren Fachmengen keine künstliche Datenzeile.

Alle Textfelder verwenden explizit SQL_Latin1_General_CP1_CS_AS. Die Nullable-Angaben bilden das vorgeschlagene stabile Ausgabe-ABI ab; physische TABLE-Exporte müssen sie exakt einhalten.

| Nr. / Resultset | Feldfolge und Typen |
|---|---|
| 1 moduleStatus | ModuleName sysname NOT NULL, CapturedAtUtc datetime2(3) NOT NULL, StatusCode varchar(40) NOT NULL, IsPartial bit NOT NULL, RowCount bigint NOT NULL, Detail nvarchar(1000) NOT NULL |
| 2 serverContext | ProductMajorVersion nvarchar(128) NULL, aus SERVERPROPERTY('ProductMajorVersion'); keine Server- oder Hostnamen. |
| 3 promotionConfiguration | Höchstens eine Zeile: ConfiguredValue int NULL, RunningValue int NULL, IsDynamic bit NOT NULL. |
| 4 linkedServerPromotion | ServerId int NOT NULL, RemoteProcTransactionPromotionEnabled bit NOT NULL, ModifiedAt datetime NULL. |
| 5 activeDistributedTransactions | TransactionId bigint NOT NULL, TransactionType int NOT NULL (Wert 4), TransactionBeginTime datetime NULL, TransactionState int NOT NULL. |
| 6 sourceStatus | SourceName varchar(64) NOT NULL, CaptureStartedAtUtc datetime2(3) NOT NULL, CaptureEndedAtUtc datetime2(3) NOT NULL, StatusCode varchar(40) NOT NULL, IsPartial bit NOT NULL, RowsReturned bigint NULL, LimitApplied bit NOT NULL, ErrorNumber int NULL, ErrorMessage nvarchar(2048) NULL, VisibilityLimit nvarchar(500) NOT NULL. |
| 7 warnings | WarningCode varchar(40) NOT NULL, SourceName varchar(64) NULL, Detail nvarchar(1000) NOT NULL. |

Der Status folgt dem bestehenden Servermodulvertrag. Erfolgreich lesbare Katalog-/DMV-Zeilen einschließlich null sichtbarer Zeilen bleiben AVAILABLE_LIMITED/partial, weil Metadatensicht nicht als vollständig bewiesen wird. Quellenfehler bleiben als Fehler erkennbar; ein Fehler und ein leeres Ergebnis sind nicht gleichbedeutend. Das Zeilenlimit ist je Fachinventar global über die serverweite Menge, sortiert Linked Server nach server_id und Transaktionen nach transaction_begin_time, transaction_id. Unabhängige Quellen werden mit separaten UTC-Zeitklammern aufgenommen; ihre Resultate sind keine atomare Momentaufnahme.

Das Limit begrenzt die ausgegebenen Zeilen, aber nicht garantiert den Aufwand, die Quelle zu enumerieren. Die Implementierung nutzt ausschließlich benannte native Spalten und die drei festen Quellen; sie führt keine dynamische Datenbank- oder Serverauswahl, keine externen Abfragen und keine NOLOCK-Sicht ein. Fehlende Berechtigung führt zu einem abgegrenzten Quellenfehler, nicht zu Permission-Fallback, Identitätswechsel oder vermeintlich leerem Inventar. Es gibt keinen High-Impact-Zuschlag und keine Funktion zur Änderung von Serveroptionen.

## Datenschutz und gespeicherte Werte

Laufzeitresultsets dürfen die für diesen Produktvertrag ausdrücklich benannten Diagnosefelder unverändert liefern. Repositorytext, Fixtures, Screenshots und Evidenz verwenden ausschließlich generische, eindeutig synthetische Werte. Der Vertrag speichert oder projiziert keine Transaktionsnamen, UOW/GUIDs, Statementtexte, Login-/Session-/Anwendungsidentitäten, Linked-Server-Namen, Datenquellen, Provider-Strings, Anmeldedaten, Endpunktpfade oder geschützte Inhaltsdaten. Native Fehlermeldungen verbleiben nur in der Laufzeitausgabe; gespeicherte Testbelege verwenden feste synthetische Diagnosewerte.

## Schritt 40: ausführbare Annahmekriterien und Grenzen

Der begrenzte Implementierungsschritt ist innerhalb des bereits bestehenden autonomen WI-0010-Auftrags ausführbar. Es wird kein zusätzlicher menschlicher Freigabeschritt für die hier abgegrenzte read-only-Implementierung eingeführt. Vorgesehen sind ein kohärenter SQL-Server-2025-CI-Änderungsschritt, erforderlicher unabhängiger Produktreview und die bereits vorgeschriebenen PR-Head-/Main-Gates.

Abnahme für Schritt 40:

1. Die Procedure, Installer, Navigator-/Dokumentationseinträge und Ergebnisinventare nennen dieselben sieben Resultsets, Parameter, Reihenfolgen und physischen Feldtypen.
2. Statische API-/Quellenaudits binden alle ausgewählten nativen Spalten und bestätigen, dass ausgeschlossene Namens-, UOW-, Text-, Anmelde- und Remoteabfragepfade nicht projiziert werden.
3. Der SQL-Server-2025-CI-Lauf qualifiziert die Konfigurationszeile, caller-sichtbare Linked-Server-Metadaten soweit vorhanden, den DMV-Leerfall, Status-/Fehlerbehandlung und OUTPUT-Modi. Eine leere native DMV-Sicht bleibt ein qualifizierter Leerfall und kein Beleg einer positiven DTC-Infrastruktur.
4. Die sieben Resultsets erhalten sieben unabhängige typisierte ABI-Oracles. TABLE-Exporte prüfen alle physischen Spaltenordinale sowie Typ, Länge, Präzision, Scale, NULL-Fähigkeit und Collation. Die Ziele für Vertrag 096 sind leer und besitzen je genau eine Seed-Spalte; Product-Daten werden ausschließlich über die vorgesehenen Framework-Exportpfade verglichen.
5. Die Vertragstests prüfen CONSOLE/RAW/TABLE/NONE/JSON-Parität, NULL/0/positives/negatives Zeilenlimit, deterministische globale Limits je Inventar, begrenzte feste Fehlerdiagnostik, Caller-Locktimeout-Wiederherstellung, Caller-Transaktion und Berechtigungsfehler ohne Identitätswechsel. Jede Assertion verwendet kompakte feste Diagnostik. Bei einer Testberechtigungsfixture erfolgt das Entfernen des Frameworkdatenbankbenutzers im aktuellen Frameworkkontext über sys.sp_executesql; Serverrechte und ein angelegter Testlogin werden in master aufgeräumt, ein Ziel-Datenbankbenutzer im expliziten USE-Zielkontext.
6. Ein fail-fast Quellbindungscheck stellt vor dem Lauf sicher, dass die getesteten SQL-Quellen und Revisionen dem beabsichtigten Head entsprechen. Der native Nachweis nennt nur tatsächlich gebundene Quellen, Feldprojektionen und ausgeführte Läufe. Kein nicht exportierter SQL-stdout oder fehlender PASS-Marker wird als separat gespeicherter Erfolgsmarker beschrieben.
7. Ein optional erforderlicher kontrollierter Timeoutnachweis ist ein eigenes Abnahmekriterium mit einer tatsächlich beobachteten Zeitüberschreitung; ein isoliertes DENY-229-Ergebnis belegt keinen Timeout.
8. Vor regulärer PR-Integration bestehen unabhängiger Review, SQL-Server-2025-Head-CI und die getrennten erforderlichen Main-Gates. Zusätzliche Engine- oder Compatibility-Level-Läufe benötigen ein konkretes Risiko gemäß CI-Teststrategie.

Ein sichtbarer non-empty Eintrag aus sys.dm_tran_active_transactions kann im künftigen Produktlauf positiv den lokalen SQL-Metadatensatz transaction_type = 4 qualifizieren. Die Implementierung liegt in `Code/08_ServerHealth/300_USP_DistributedTransactionInventory.sql`; die Laufzeitabnahme darf für die portable SQL-2025-CI ohne eingerichtete DTC-Teilnehmer keine positive Transaktionszeile synthetisieren, behaupten oder als Test-PASS anrechnen. Falls Produkt-Code und fachliche Leer-/Fehlerverträge auf der SQL-2025-CI nicht sauber qualifiziert werden können, bleibt das positive aktive-Transaktionsresultat ausdrücklich offen; die begrenzten lokalen Konfigurations- und leeren DMV-Verträge können dennoch umgesetzt und abgegrenzt werden. Ein tatsächlicher verteilter Commit-/Rollback-Nachweis benötigt später eine separat freigegebene, isolierte native DTC-Umgebung. Externe Dienst-, Netzwerk-, Firewall-, RPC-, Recovery-, Host-, Cluster-, Security- und Teilnehmergesundheit bleiben dauerhaft außerhalb dieses Moduls. DATABASE_MIRRORING bleibt der nächste getrennte WI-0010-Kandidat; Klassifikation und Agent-Proxies bleiben ebenfalls offen.

## Primärquellen

- Microsoft Learn: [sys.configurations](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-configurations-transact-sql?view=sql-server-ver17) — native `sql_variant`-Typen, Konfigurationswerte und Versionsrechte.
- Microsoft Learn: [sys.servers](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-servers-transact-sql?view=sql-server-ver17) — caller-sichtbare Linked-Server-Metadaten und SQL-2022+-Rechte.
- Microsoft Learn: [sys.dm_tran_active_transactions](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-tran-active-transactions-transact-sql?view=sql-server-ver17) — serverweiter aktiver Transaktionsbestand, native Typen, verteilte Transaktion transaction_type = 4, Transaktionszustände und Berechtigungen.
- Microsoft Learn: [sys.servers](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-servers-transact-sql?view=sql-server-ver16) — native Linked-Server-Spalten, Promotion-Flag, Sichtbarkeit und SQL-Server-2022-Berechtigung.
- Microsoft Learn: [sys.configurations](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-configurations-transact-sql?view=sql-server-ver16) — Typen der Konfigurationsspalten und SQL-Server-2022-Berechtigung.
- Microsoft Learn: [sp_serveroption](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-serveroption-transact-sql?view=sql-server-ver16) — Bedeutung und Grenzen von remote proc transaction promotion für Linked-Server-Remote-Prozeduraufrufe.
- Microsoft Learn: [remote proc trans-Serverkonfiguration](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/configure-the-remote-proc-trans-server-configuration-option?view=sql-server-ver16) und [SET REMOTE_PROC_TRANSACTIONS](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-remote-proc-transactions-transact-sql?view=sql-server-ver16) — Legacy-/Override-Verhalten und Abgrenzung zu Linked-Server-Abfragen.
- Microsoft Learn: [BEGIN DISTRIBUTED TRANSACTION](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/begin-distributed-transaction-transact-sql?view=sql-server-ver17) — mögliche Promotionsbedingungen für Distributed Queries; diese Infrastruktur wird nicht getestet.
- Microsoft Learn: [SERVERPROPERTY](https://learn.microsoft.com/en-us/sql/t-sql/functions/serverproperty-transact-sql?view=sql-server-ver17) — Typ und Bedeutung des optionalen ProductMajorVersion-Kontexts.
- Microsoft Learn: [MSDTC unter Linux konfigurieren](https://learn.microsoft.com/en-us/sql/linux/configure/distributed-transactions?view=sql-server-ver17) — Versionsverfügbarkeit, externe RPC-/Netzwerkvoraussetzungen und Supportgrenzen.
