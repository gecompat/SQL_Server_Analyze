# Caller-sichtbares Inventar von Datenbank-Snapshots

**Stand:** 15. November 2026.  
**Status:** Begrenzter Source-, Guide- und nativer Vertragskandidat; keine native SQL-Laufzeitqualifikation oder Main-Integration belegt.  
**Artefakt-UID:** `urn:uuid:01a1dde5-8bde-71ff-9910-3a76322589d2`.  
**Registrierung:** `DEFERRED`; keine lesbare Arbeitselementkennung vergeben.

## Diagnosefrage und vorhandene Grenze

Der P2-Eintrag `DATABASE_SNAPSHOTS` fragt nach Beziehungen zwischen Datenbank-Snapshots und ihren Quellen sowie nach Sparse-Dateikataloggrenzen. Der vorhandene `USP_DatabaseCapacityAnalysis` liest `sys.database_files`, `FILEPROPERTY` und Volumeinformationen ausgewählter normaler Datenbanken. Sein „lesender Snapshot“ beschreibt den Aufnahmezeitpunkt und ist kein Inventar persistenter Datenbank-Snapshot-Objekte. `TVF_DatabaseCandidates` schließt Datenbanken mit `source_database_id IS NOT NULL` ausdrücklich aus; `USP_PrepareDatabaseCandidates` delegiert an diese Funktion. Der neue Endpunkt muss die Snapshot-Katalogauswahl deshalb selbst durchführen. Das optionale Snapshot-/Baseline-Persistenzpaket bleibt fachlich und installatorisch getrennt.

`[monitor].[USP_DatabaseSnapshotInventory]` liest ausschließlich `master.sys.databases` und `master.sys.master_files` im Caller-Kontext. Standardmäßig werden sichtbare ONLINE-Snapshots von Benutzerdatenbankquellen ausgewählt. `@NurOnline=0` lässt andere sichtbare Katalogzustände zu; `@SystemdatenbankenEinbeziehen=1` öffnet die Auswahl für zulässige Systemquellen. `@SnapshotNames` filtert optional exakte Snapshotnamen mit dem vorhandenen bracket-aware Namensparser. Die Source-ID wird immer als native Katalog-ID ausgegeben; ein für den Caller unsichtbarer Source-Name bleibt NULL. Es gibt keine Source-Datenbank-USE-Operation und keine Rechteerhöhung.

## Quelle, Dateigrenze und Datenschutz

Ein Snapshot hat in `sys.databases` eine nicht-NULL `source_database_id`. `create_date` ist ein nativer `datetime`-Wert ohne UTC-Deutung und kann durch Umbenennung seinen ursprünglichen Erstellungszeitbezug verlieren. Der Endpunkt leitet daraus kein verlässliches Alter ab. `sys.master_files` liefert caller-sichtbare Sparse-Dateizeilen für ausgewählte Snapshot-IDs. `size` ist in 8-KiB-Seiten angegeben und beschreibt bei Datenbank-Snapshots die maximale mögliche Dateikapazität, nicht physisch belegten Speicher. Die Umrechnung in Bytes verwendet `bigint` und den Faktor 8192. Die Procedure liest keine Host-Dateien und keine DM-IO-Statistiken; sie bewertet weder tatsächliches Wachstum noch Belegung, Gesundheit, Restore-Eignung oder globale Vollständigkeit.

Die Dateikatalogsicht kann enger als die sichtbare Snapshotzeile sein. Für eine Zeile in `sys.master_files` nennt Microsoft mindestens `CREATE DATABASE`, `ALTER ANY DATABASE` oder `VIEW ANY DEFINITION`. Eine Snapshotzeile ohne sichtbare Sparse-Dateizeile erhält einen unbekannten Dateizähler und einen expliziten Quellenstatus, keinen erfolgreichen Nullbestand. Die beiden Kataloglesungen sind zeitlich getrennt, verwenden `WITH (NOLOCK)` und können bei parallelen Änderungen voneinander abweichen. `@MaxZeilen` begrenzt nur ausgegebene Snapshots; für jeden ausgegebenen Snapshot bleiben alle zuvor gelesenen sichtbaren Dateizeilen zusammen. Es ist kein Arbeitsbudget für die Katalogaufnahme.

Native Datenbank-, Source-, Datei- und Pfadidentitäten bleiben in flüchtigen RAW-, TABLE-, CONSOLE- und JSON-Ausgaben erhalten. Repository, Testfixture, Dossier und öffentlicher Guide enthalten ausschließlich synthetische Namen und keine aufgenommenen Runtimewerte. Der Produktpfad ändert keine persistenten Datenbank- oder Snapshot-Objekte und führt keinen Snapshot-Revert oder Host-Dateizugriff aus. Lokale Temp-DDL dient der Aufbereitung und TABLE-Ausgabe.

## Ausgabe und Fehler

Der Vertrag hat fünf benannte Gruppen: `moduleStatus`, `snapshots`, `snapshotFiles`, `sourceStatus` und `warnings`. RAW liefert alle fünf in dieser Reihenfolge, TABLE schreibt ausdrücklich gemappte lokale Temp-Ziele, CONSOLE eine formatierte Menge und NONE keine Resultsets. Optionales JSON enthält `meta` und alle fünf Gruppen unabhängig vom Ausgabemodus. Die 15 Parameter, Typen, Defaults, NULL-/Leerwerte und Eingabeformen stehen einzeln in der eingebauten Hilfe und im [öffentlichen Procedure-Guide](../../../Documentation/Analysis_Guides/Procedures/USP_DatabaseSnapshotInventory.md). Die normalen Statuswerte bezeichnen nur caller-sichtbare Katalogevidenz. Ein erfolgreicher leerer Filter liefert `SKIPPED`, kein globales Negativoracle. Fehlende Dateisicht, native Rechtefehler und SQL-Fehler 1222 bleiben unterscheidbar.

Der normale Pfad verweigert eine aktive Caller-Transaktion oder `IMPLICIT_TRANSACTIONS ON` vor Temp-DDL und Quellenlesung. Hilfe bleibt auch in einer Transaktion nutzbar. Der konfigurierte Lock-Timeout wird als validierter numerischer Literalwert im selben dynamischen Katalogbatch gesetzt und nach Erfolg und Fehler auf den vorherigen Callerwert zurückgestellt.

## Synthetische native Abnahme und Veröffentlichungsfolge

Die native Fixture ist für die freigegebene isolierte Remote-CI vorgesehen. Sie legt eine eigene, kollisionsgeprüfte synthetische Source-Datenbank mit zwei eigenen Datendateien sowie zwei eigene Datenbank-Snapshots mit Dateipfaden aus dem Dateikontext dieser Source an. Sie vergleicht positive Snapshot- und Sparse-Dateikatalogzeilen mit unabhängigen nativen Katalog-Oracles. Die Prüfung umfasst typisierte TABLE- und JSON-Ausgaben, die fünf RAW-Resultsetschemas für einen ausdrücklich fehlenden synthetischen Snapshot, eine einzelne CONSOLE-Menge mit eigenen Namen, einen begrenzten Snapshot bei vollständig erhaltenem Sparse-Dateisatz, einen eingeschränkten eigenen Caller gegen dessen direkte Katalogsicht, ungültige Eingaben, Hilfe und den Caller-Transaktionsguard. Auch bei Fehlern werden zuerst beide Snapshots und danach die eigene Source-Datenbank entfernt. Ein nicht erstellbarer Snapshot ist ein Testfehler, kein Produkt-PASS. Native Guards akzeptieren die konfigurierten Hauptversionen 15, 16 und 17, ohne für 2019 oder 2022 eine nicht ausgeführte Qualifikation zu behaupten. Kontrolliert erzwungene native Berechtigungsfehler, Nicht-ONLINE-Zustände und physische Speicherbelegung bleiben außerhalb der ersten positiven Fixture.

Die Source-Datei wird erst zusammen mit Installer-Include, Inventaren, Navigator, Guide und spezifischem nativen Release-Gate-Vertrag veröffentlicht. Die Installeränderung löst das vollständige funktionale SQL-Server-2025-/CL170-Gate aus. Für den stabilen Katalog-V1 ist derzeit kein konkretes zusätzliches natives Versionsrisiko belegt. Ein grüner statischer Validator oder ein Generatorlauf ist keine SQL-Laufzeitabnahme.

## Primärquellen

- [Microsoft: Datenbank-Snapshots anzeigen](https://learn.microsoft.com/en-us/sql/relational-databases/databases/view-a-database-snapshot-sql-server?view=sql-server-ver17).
- [Microsoft: sys.databases](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-databases-transact-sql?view=sql-server-ver17).
- [Microsoft: sys.master_files](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-master-files-transact-sql?view=sql-server-ver17).
- [Microsoft: SQL Server 2025 auf Linux nach Edition](https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-editions-and-components-2025?view=sql-server-ver17).
