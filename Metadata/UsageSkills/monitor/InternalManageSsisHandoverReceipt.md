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

- `@Action` wählt `REGISTER_MODEL` für einen Modellbeleg mit optionalem Laufzeitbeleg, `REGISTER_SCOPE` für einen Scopebeleg oder `REVOKE` für den Widerruf. Der Vergleich folgt der lokalen Datenbankkollation. NULL, der Leerwert und andere Werte sind im Fachpfad ungültig.
- `@HandoverId` ist für jede Aktion die UUID des Modell- oder Scopebelegs beziehungsweise des zu widerrufenden Belegs. NULL ist ungültig.
- `@RuntimeHandoverId` ist nur bei `REGISTER_MODEL` mit Laufzeitaufnahme erforderlich. Andernfalls muss der Wert NULL sein.
- `@ReceiptKind` muss beim Widerruf 1 für Modell, 2 für Laufzeit oder 3 für Scope sein. Die Registrierungsaktionen erfordern NULL.
- `@ModelJson` enthält bei `REGISTER_MODEL` das qualifizierte neutrale SSIS-Paketmodell und bei `REGISTER_SCOPE` den JSON-Paketsatz. NULL und Leertext sind bei Registrierung ungültig. Widerruf erfordert NULL.
- `@PackageBytes` enthält nur bei `REGISTER_MODEL` die Originalbytes. NULL und abweichende Paketbytes werden abgelehnt. Die übrigen Aktionen erfordern NULL.
- `@CaptureJson` enthält bei `REGISTER_SCOPE` die qualifizierte Scopeaufnahme und bei Registrierung eines Laufzeitbelegs die Laufzeitaufnahme. Zulässig ist valides JSON bis 16 MiB. Bei reinem Modellbeleg und Widerruf muss der Wert NULL sein.
- `@ValidHours` ist bei Registrierung eine ganze Zahl zwischen 1 und 24. NULL ist bei Registrierung ungültig. Beim Widerruf wird der Parameter nicht ausgewertet.
- `@Hilfe` gibt mit 1 vor Fachzugriff den Usage Skill aus. 0 oder NULL aktiviert den normalen Pfad.

## Resultate und Ausgabe

Der Fachpfad erzeugt kein Resultset. Ein Modell- und ein optionaler Laufzeitbeleg werden atomar registriert. Ein Widerruf löscht die angegebene UUID der angegebenen Belegart, sofern sie vorhanden ist.

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Die Prozedur setzt im Fachpfad `ROWCOUNT 0` und `LOCK_TIMEOUT 0` im lokalen Prozedurkontext. Die Registrierung eines Modells prüft Struktur und Originalbytes. Bei einer Scopeaufnahme prüft der qualifizierte Erfassungsworkflow die Einzelmodelle vor dem Aufruf. Er speichert die Aufnahme und den Paketsatz nicht in der Belegtabelle. Eine Belegkollision bricht die Registrierung ab.
