# Lesender REST-Endpunkt-Konfigurationswert im Security-Inventar

**Stand:** 15. November 2026.  
**Status:** begrenzter Source-/Fixture-Kandidat; native SQL- und Main-Abnahme stehen aus.  
**Artefakt-UID:** `urn:uuid:01a1e10d-b498-703c-940c-1f611bfcd466`.  
**Registrierung:** `DEFERRED`; keine neue lesbare Arbeitselementkennung vergeben.  
**Bezug:** bestehender CoverageKey `EXTERNAL_REST_ENDPOINT` und bestehende Procedure `monitor.USP_ServerSecurityConfiguration`.

## Diagnosefrage und bestehender Vertrag

Die bestehende [Produktquelle](../../../Code/08_ServerHealth/090_USP_ServerSecurityConfiguration.sql) liest eine kuratierte Auswahl aus `sys.configurations`. Der Kandidat ergänzt darin ausschließlich `external rest endpoint enabled`. Auf SQL Server 2025 zeigt die zusätzliche Zeile den caller-sichtbaren konfigurierten und aktiven Wert. Microsoft dokumentiert für die Option 0 oder 1 und den Default 0. Das Modul liest den tatsächlichen Wert; es setzt keinen Sollwert und ändert die Konfiguration nicht. Der vorhandene `Finding`-Zweig liefert `OK_OR_CONTEXT_DEPENDENT`. Eine sichtbare oder aktivierte Option belegt weder einen erfolgreichen REST-Aufruf noch Endpoint-Erreichbarkeit, Aufrufberechtigungen, Credentials, Ziel-URLs, Nutzungshistorie oder Sicherheitswirkung.

Der Security-Endpunkt ist bereits vorhanden; insbesondere `USP_ServerConfiguration` kann mit seinem anderen Scope Konfigurationswerte lesen. Der neue Slice beansprucht nur die bisher fehlende kuratierte Security-Sicht. Er ruft weder `sp_configure` noch `RECONFIGURE` oder `sp_invoke_external_rest_endpoint` auf. Quelle, Dienste und Servereigenschaften werden wie zuvor getrennt und nicht atomar gelesen. Die bestehenden RAW-Dienst- und Eigenschaftsdaten können ServiceAccount und MachineName enthalten; die neue Konfigurationszeile ergänzt keine URL, Identität oder Secret.

## Unveränderte API und Leserichtung

Alle zehn Parameter samt Typ, Default, SQL-Bindung, NULL-/Leerbehandlung, Optionen und OUTPUT-Regeln bleiben unverändert und stehen vollständig im [öffentlichen Guide](../../../Documentation/Analysis_Guides/Procedures/USP_ServerSecurityConfiguration.md#parameter-und-weitere-aufrufbeispiele): `@PrintMeldungen bit = 1`, `@Hilfe bit = 0`, `@ResultSetArt varchar(16) = 'CONSOLE'`, `@ResultTablesJson nvarchar(max) = NULL`, `@JsonErzeugen bit = 0`, `@Json nvarchar(max) = NULL OUTPUT`, `@StatusCodeOut varchar(40) = NULL OUTPUT`, `@IsPartialOut bit = NULL OUTPUT`, `@ErrorNumberOut int = NULL OUTPUT` und `@ErrorMessageOut nvarchar(2048) = NULL OUTPUT`. Der bestehende TABLE-Preflight, die Caller-Optionen und die Quellenstatus bleiben unberührt.

Die `configuration`-Zeile behält vier Spalten: `ConfigurationName nvarchar(128) NOT NULL`, `ConfiguredValue sql_variant NULL`, `RunningValue sql_variant NULL` und `Finding varchar(60) NOT NULL`; beide Textspalten verwenden `SQL_Latin1_General_CP1_CS_AS`. RAW liefert Modulstatus und vier technische Fachresultsets; TABLE und CONSOLE geben weiterhin nur die Konfiguration aus, NONE kein Zeilenresultset. Optionales JSON behält `meta`, `sources`, `configuration`, `services`, `properties` und `warnings`. Darin werden die zwei `sql_variant`-Werte der Konfiguration wie bisher mit `CONVERT(nvarchar(4000), ...)` als JSON-Strings serialisiert. Eine fehlende Zeile auf älteren Engines ist keine Nullmessung; `SourceStatus` und Sichtbarkeit bleiben maßgeblich.

## Native Prüfung und Grenzen

Die bestehende [Fixture 133](../../../Code/Tests/Common/133_ServerSecurity_Collation_Runtime_Contract.sql) behält ihre bidirektionalen nativen TABLE-/JSON-Mengenvergleiche, Quellenstatus- und Collation-Orakel. Sie ergänzt den Optionsnamen in der erwarteten Menge. Auf einem nativen SQL Server 2025 mit Major Version 17 verlangt sie genau eine Katalog- und TABLE-Zeile, konfigurierte und aktive Werte im Bereich 0/1, exakte Parität mit `sys.configurations` und den bestehenden `Finding`-Code `OK_OR_CONTEXT_DEPENDENT`. Die vorhandene JSON-Parität bindet dieselbe Zeile. Auf älteren Versionen kann die Option fehlen; die Fixture behauptet keine dortige Ausführung oder Unterstützung. Sie erzeugt keine aktivierte Konfiguration und führt keinen REST-Aufruf aus.

Die vorgesehene V1-Prüfung soll nur Katalogpräsenz und caller-sichtbare Werte auf dem freigegebenen SQL-Server-2025-/CL170-Ziel belegen; die native Abnahme steht aus. Die Option ist kein Test für REST-Nutzbarkeit, Policy, Rechte, Netzwerk, Endpoint oder Credential. Ein zusätzlicher nativer SQL-Server-2019-/2022-Lauf ist für diesen unveränderten Katalogschema-Filter ohne konkretes Versionsrisiko nicht ausgewählt.

## Primärquellen

- [Server Configuration Options](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/server-configuration-options-sql-server?view=sql-server-ver17)
- [sp_invoke_external_rest_endpoint und Freischaltung](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-invoke-external-rest-endpoint-transact-sql?view=sql-server-ver17)
