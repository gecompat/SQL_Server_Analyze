---
skill_format_version: "1.0.0"
name: "monitor.SsisHandoverReceipt"
schema_name: "monitor"
object_name: "SsisHandoverReceipt"
object_type: "TABLE"
database_role: "framework"
is_internal: false
description: "Speichert die zeitlich begrenzten lokalen Belege für SSIS-Modelle und Laufzeitaufnahmen."
source_path: "Code/10_SSIS/033_SsisHandoverReceipt.sql"
---

# monitor.SsisHandoverReceipt

## Zweck und Einsatz

Speichert die zeitlich begrenzten lokalen Belege für SSIS-Modelle und Laufzeitaufnahmen.

## Voraussetzungen und Rechte

Die Tabelle gehört über das Schema `monitor` zu `dbo`. Registrierung und Widerruf erfolgen über `monitor.InternalManageSsisHandoverReceipt`. Die Analyseprozeduren lesen die Belege mit statischem SQL. Der Installer verweigert `public` INSERT und DELETE auf der Tabelle und UPDATE auf jeder der drei Spalten. Die Sperren gelten auch für geerbte Schreibrechte und spaltenbezogene UPDATE-Grants. Erstellung und Schreibschutz erfolgen in derselben Transaktion. Bei erneuter Installation muss eine vorhandene Tabelle den Struktur- und Berechtigungsvertrag bereits erfüllen. Der Eigentümer und entsprechend privilegierte Administratoren verwalten die Schutzgrenze.

## Parameter und Eingabe

Keine Aufrufparameter.

## Resultate und Ausgabe

`ReceiptKind` ist ein `tinyint`. 1 bezeichnet einen Modellbeleg, 2 einen Laufzeitbeleg und 3 einen Scopebeleg. Gemeinsam mit der UUID `HandoverId` bildet die Belegart den Primärschlüssel. `ReceiptJson` ist ein JSON-Text in `nvarchar(3000)` mit Vertragsversion, Hashwerten, Ausstellungszeit und Ablaufzeit. Der Modellbeleg enthält auch Paketlänge, Erzeugungsmethode, Buildhash und Source-Commit.

## Beispiel

Ein Administrator mit SELECT-Recht auf der Tabelle kann prüfen, ob ein Modellbeleg zur angegebenen UUID gespeichert ist. Die Abfrage gibt höchstens eine Zeile zurück. Ersetze die synthetische UUID durch die zu prüfende UUID. Eine gefundene Zeile belegt die Speicherung. Die fachliche Gültigkeit prüft die jeweilige Analyseprozedur anhand des Beleginhalts.

```sql
DECLARE @HandoverId uniqueidentifier = '00000000-0000-4000-8000-000000000001';

SELECT [ReceiptKind], [HandoverId]
FROM [monitor].[SsisHandoverReceipt] WITH (READCOMMITTEDLOCK)
WHERE [ReceiptKind] = 1 AND [HandoverId] = @HandoverId;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Leser suchen einen Beleg je Art und UUID mit `READCOMMITTEDLOCK`. Die Tabelle enthält keine Paketbytes, Modelle oder Laufzeitaufnahmen. Die Belegprüfung lehnt abgelaufene, widerrufene und unpassende IDs ab. Belegzeilen laufen fachlich ab. Es gibt keine automatische Löschung.
