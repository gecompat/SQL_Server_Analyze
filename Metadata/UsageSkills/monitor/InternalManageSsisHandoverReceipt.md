---
skill_format_version: "1.0.0"
name: "monitor.InternalManageSsisHandoverReceipt"
schema_name: "monitor"
object_name: "InternalManageSsisHandoverReceipt"
object_type: "INTERNAL_PROCEDURE"
database_role: "framework"
is_internal: true
description: "Registriert oder widerruft einen qualifizierten lokalen SSIS-Übergabebeleg."
source_path: "Code/10_SSIS/041_InternalManageSsisHandoverReceipt.sql"
---

# monitor.InternalManageSsisHandoverReceipt

## Zweck und Einsatz

Registriert oder widerruft einen qualifizierten lokalen SSIS-Übergabebeleg.

## Voraussetzungen und Rechte

Autorisierte Aussteller benötigen `EXECUTE` auf dieser Prozedur und `ALTER` auf `monitor.USP_SsisPackageModelAnalysis`. Die Prüfung verwendet die Rechte des Aufrufers. Der gemeinsame Eigentümer erlaubt den statischen Tabellenzugriff der Prozedur. Eine aktive Aufrufertransaktion oder `IMPLICIT_TRANSACTIONS ON` verhindert die Ausführung.

## Parameter und Eingabe

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @Action | varchar(64) | nein | NULL |
| @HandoverId | uniqueidentifier | nein | NULL |
| @RuntimeHandoverId | uniqueidentifier | nein | NULL |
| @ReceiptKind | tinyint | nein | NULL |
| @ModelJson | nvarchar(max) | nein | NULL |
| @PackageBytes | varbinary(max) | nein | NULL |
| @CaptureJson | nvarchar(max) | nein | NULL |
| @ValidHours | int | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@Action:** `varchar(64)`, Default NULL. `REGISTER_MODEL` registriert einen Modellbeleg mit optionalem Laufzeitbeleg. `REGISTER_SCOPE` registriert einen Scopebeleg. `REVOKE` widerruft einen Beleg der ausdrücklich gewählten Belegart. Der Vergleich folgt der Datenbankkollation. NULL und Leertext sind im Fachpfad ungültig.

**@HandoverId:** `uniqueidentifier`, Default NULL. Jede Aktion benötigt eine UUID. Bei `REGISTER_MODEL` bezeichnet sie den Modellbeleg, bei `REGISTER_SCOPE` den Scopebeleg und bei `REVOKE` zusammen mit `@ReceiptKind` den zu widerrufenden Beleg. Zulässig ist ein typisierter Wert oder ein konvertierbares GUID-Literal. NULL ist ungültig.

**@RuntimeHandoverId:** `uniqueidentifier`, Default NULL. `REGISTER_MODEL` benötigt eine typisierte UUID oder ein konvertierbares GUID-Literal, wenn `@CaptureJson` eine Laufzeitaufnahme enthält. Ohne Laufzeitaufnahme und bei den übrigen Aktionen ist NULL erforderlich.

**@ReceiptKind:** `tinyint`, Default NULL. `REVOKE` akzeptiert 1 für Modell, 2 für Laufzeit und 3 für Scope. NULL und andere Werte sind beim Widerruf ungültig. Beide Registrierungsaktionen verlangen NULL.

**@ModelJson:** `nvarchar(max)`, Default NULL. Bei `REGISTER_MODEL` muss der Unicode-Text ein qualifiziertes neutrales SSIS-Paketmodell enthalten. Die öffentliche Analyseprozedur validiert das Modell und die Originalbytes vor der Registrierung. Bei `REGISTER_SCOPE` muss der Wert ein gültiger JSON-Paketsatz mit höchstens 16 MiB nach `DATALENGTH` sein. Ein fehlender oder leerer Text ist bei Registrierung ungültig. `REVOKE` verlangt NULL.

**@PackageBytes:** `varbinary(max)`, Default NULL. `REGISTER_MODEL` benötigt die unveränderten Originalbytes des Pakets. Die Analyse prüft Länge und Paketdigest gegen das Modell. Fehlende oder abweichende Bytes führen zur Ablehnung. `REGISTER_SCOPE` und `REVOKE` verlangen NULL.

**@CaptureJson:** `nvarchar(max)`, Default NULL. Bei `REGISTER_SCOPE` ist die qualifizierte Scopeaufnahme als Unicode-JSON erforderlich. Bei `REGISTER_MODEL` ist mit `@RuntimeHandoverId` die zugehörige Laufzeitaufnahme erforderlich. Gültiger JSON-Text darf höchstens 16 MiB nach `DATALENGTH` umfassen. Leerer Text ist ungültig. Ohne Laufzeitbeleg und beim Widerruf ist NULL erforderlich.

**@ValidHours:** `int`, Default 1. Registrierungen akzeptieren ganze Stunden von 1 bis 24 einschließlich. Die Laufzeit beginnt am UTC-Zeitstempel der Ausstellung. NULL und Werte außerhalb des Bereichs sind bei Registrierung ungültig. Beim Widerruf wird der Wert nicht ausgewertet.

**@Hilfe:** `bit`, Default 0. 1 liefert den Usage Skill vor Fachzugriff, Autorisierungsprüfung und Eingabekontrolle. 0 oder NULL aktiviert den Fachpfad. SQL konvertiert numerische Werte ungleich 0 zu 1.

## Resultate und Ausgabe

Der Fachpfad erzeugt kein Resultset. Ein Modell- und ein optionaler Laufzeitbeleg werden atomar registriert. Ein Widerruf löscht die angegebene UUID der angegebenen Belegart, sofern sie vorhanden ist.

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Die Prozedur setzt im Fachpfad `ROWCOUNT 0` und `LOCK_TIMEOUT 0` im lokalen Prozedurkontext. Die Registrierung eines Modells prüft Struktur und Originalbytes. Bei einer Scopeaufnahme prüft der qualifizierte Erfassungsworkflow die Einzelmodelle vor dem Aufruf. Er speichert die Aufnahme und den Paketsatz nicht in der Belegtabelle. Eine Belegkollision bricht die Registrierung ab.
