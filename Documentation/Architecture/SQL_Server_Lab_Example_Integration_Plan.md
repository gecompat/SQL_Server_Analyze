# ANALYZE-LAB-001 – Spielbare Analyze-Beispiele mit SQL_Server_Lab

**Stand:** 27. Juli 2026  
**Status:** `RESEARCHED_NOT_IMPLEMENTED`  
**Zielrepository:** `gecompat/SQL_Server_Analyze`  
**Infrastrukturprovider:** `gecompat/SQL_Server_Lab`

## 1. Ziel

`SQL_Server_Analyze` soll für vorhandene und künftige Beispiele eine einfach bedienbare Möglichkeit bereitstellen, eine passende isolierte SQL-Server-Testumgebung aufzubauen, das Framework zu installieren und ein fachliches Szenario spielbar vorzubereiten.

Der Benutzer soll ein Beispiel auswählen können, ohne vorher die dafür notwendige SQL-Version, Datenbankkonfiguration, Fixture-Reihenfolge oder Aufräumlogik auswendig kennen zu müssen.

Der angestrebte Ablauf lautet:

```text
Beispiel auswählen
  -> SQL-Version und Provider auswählen
  -> SQL_Server_Lab stellt die Umgebung bereit
  -> SQL_Server_Analyze wird installiert
  -> synthetischer Beispielzustand wird vorbereitet
  -> Benutzer führt Beobachtung und Analyse durch
  -> Beispielzustand oder vollständige Umgebung wird bereinigt
```

## 2. Verbindliche Verantwortungsgrenze

### 2.1 SQL_Server_Lab

`SQL_Server_Lab` verantwortet ausschließlich die allgemeine Testinfrastruktur:

- Docker- oder Podman-Provider;
- SQL-Server-Version 2019, 2022 oder 2025;
- Ressourcen-, Port-, Storage- und Lifecycle-Verwaltung;
- SQL-Readiness;
- lokale Secret- und Run-State-Verwaltung;
- Datenbankbereitstellung und allgemeine Skriptausführung;
- Stop, Start, Remove und Recovery der eigenen Lab-Ressourcen.

`SQL_Server_Lab` muss keine Analyze-Procedure, kein Analyze-Szenario und keine fachliche Assertion kennen.

### 2.2 SQL_Server_Analyze

`SQL_Server_Analyze` verantwortet:

- den Beispielkatalog;
- Auswahl und Bedienablauf;
- die benötigte SQL-Version und das Ressourcenprofil je Beispiel;
- Frameworkinstallation und -verifikation;
- synthetische Datenbanken, Objekte und Workloads;
- interaktive Sessionabläufe;
- Analyzer-Aufrufe;
- fachliche Assertions;
- projektspezifisches Cleanup;
- Schritt-für-Schritt-Anleitungen.

Diese Grenze verhindert, dass Analyze-Fachlogik in das allgemeine Lab-Modul verschoben wird oder eine zweite Infrastrukturimplementierung in diesem Repository entsteht.

## 3. Freigabegrenze für Änderungen an SQL_Server_Lab

Zusätzliche Funktionalität in `SQL_Server_Lab` darf nicht stillschweigend implementiert werden.

Wenn die Realisierung auf eine tatsächliche Plattformlücke stößt, ist vor jeder Änderung ein eigener Entscheidungspunkt vorzulegen. Dieser muss mindestens enthalten:

1. die konkret fehlende Funktion;
2. den betroffenen Analyze-Anwendungsfall;
3. die Begründung, warum die Funktion allgemein in das Lab und nicht projektspezifisch in Analyze gehört;
4. die kleinstmögliche Schnittstellenänderung;
5. Auswirkungen auf Docker und Podman;
6. Rückwärtskompatibilität und Tests;
7. die ausdrückliche Freigabe des Repositoryinhabers.

Ohne diese Freigabe bleibt `SQL_Server_Lab` unverändert. Projektspezifische Ablauflogik wird in `SQL_Server_Analyze` umgesetzt.

## 4. Nichtziele

ANALYZE-LAB-001 ist nicht:

- eine neue allgemeine Workflow Engine;
- eine zweite Container- oder VM-Orchestrierung;
- eine CI/CD-Plattform;
- ein Ersatz für die vorhandenen Release-Gates;
- ein Mechanismus, der beliebige Markdown-Codeblöcke ungeprüft ausführt;
- ein vollautomatisches Wegtesten interaktiver Situationen wie Blocking oder laufender Requests;
- eine Verlagerung von Analyze-Szenarien nach `SQL_Server_Lab`.

## 5. Vorgesehener Benutzereinstieg

Der spätere Haupteinstieg soll in diesem Repository liegen, beispielsweise:

```powershell
.\TestLab\Start-AnalyzeExample.ps1
```

Unbeaufsichtigter Aufruf:

```powershell
.\TestLab\Start-AnalyzeExample.ps1 `
    -Example Blocking `
    -Version 2022 `
    -Provider docker
```

Vorgesehene Kernparameter:

| Parameter | Zweck |
|---|---|
| `-Example` | stabile ID oder Kurzname des Beispiels |
| `-Version` | `2019`, `2022` oder `2025` |
| `-Provider` | `docker` oder `podman` |
| `-Mode` | `Interactive` oder `Verify` |
| `-KeepOnFailure` | Umgebung bei Fehler für lokale Diagnose erhalten |
| `-StateRoot` | optionaler lokaler, ignorierter Laufzeitbereich |

Interaktiv werden nur tatsächlich unterstützte Kombinationen angeboten.

## 6. Vorgesehene Repositorystruktur

```text
TestLab/
├── Start-AnalyzeExample.ps1
├── Test-AnalyzeExample.ps1
├── Catalog/
│   └── examples.json
├── Schemas/
│   └── analyze-example.schema.json
├── Examples/
│   ├── Blocking/
│   │   ├── example.json
│   │   ├── Setup.sql
│   │   ├── SessionA_Blocker.sql
│   │   ├── SessionB_Blocked.sql
│   │   ├── Analyze.sql
│   │   ├── Validate.sql
│   │   ├── Cleanup.sql
│   │   └── README.md
│   └── ...
└── Tests/
    └── static and synthetic runner contracts
```

Die endgültigen Pfade sind vor Implementierungsbeginn gegen vorhandene `Code/Examples`, `Code/Tests` und Dokumentationspfade abzugleichen. Doppelte fachliche Skripte sind zu vermeiden. Bestehende kanonische Test-Fixtures sollen wiederverwendet oder gezielt in ein Beispielpaket überführt werden.

## 7. Minimaler Beispielvertrag

Ein Beispielmanifest soll nur projektspezifische Informationen enthalten:

```json
{
  "id": "BLOCKING-001",
  "title": "Einfache Blocking Chain",
  "sqlVersions": ["2019", "2022", "2025"],
  "providers": ["docker", "podman"],
  "resourceProfile": "compact",
  "database": "AnalyzeExample",
  "mode": "interactive",
  "setup": ["Setup.sql"],
  "interactiveScripts": [
    "SessionA_Blocker.sql",
    "SessionB_Blocked.sql",
    "Analyze.sql"
  ],
  "validation": ["Validate.sql"],
  "cleanup": ["Cleanup.sql"],
  "timeoutSeconds": 120,
  "safetyClass": "LOW"
}
```

Nicht in das Manifest gehören:

- reale Endpunkte oder Ports;
- Credentials oder Secretwerte;
- absolute Hostpfade;
- konkrete Containerbefehle;
- Docker- oder Podman-Lifecyclelogik;
- benutzer-, kunden- oder umgebungsspezifische Werte.

Diese Werte entstehen ausschließlich lokal über `SQL_Server_Lab` und dessen Run-State.

## 8. Zwei Ausführungsmodi

### 8.1 Interactive

Der interaktive Modus baut den Zustand auf und lässt ihn bewusst bestehen. Der Benutzer erhält eine klare Reihenfolge, beispielsweise:

```text
1. SessionA_Blocker.sql in Fenster A starten.
2. SessionB_Blocked.sql in Fenster B starten.
3. Analyze.sql in Fenster C ausführen.
4. Resultate anhand README.md interpretieren.
5. Cleanup.sql ausführen oder die Umgebung entfernen.
```

Dieser Modus ist für Blocking, Waits, Memory Grants, laufende Requests, Query-Store-Verläufe und andere beobachtbare Zustände maßgeblich.

### 8.2 Verify

Der Verifikationsmodus führt ein begrenztes, reproduzierbares Szenario automatisiert aus und prüft stabile Invarianten. Er dient Regressionstests, ersetzt aber nicht die didaktische oder diagnostische Beobachtung im interaktiven Modus.

Assertions dürfen keine instabilen exakten Laufzeiten, Session IDs, LSNs, Plan Handles oder Hostwerte verlangen. Geprüft werden Statuscodes, vorhandene synthetische Objekte, erwartete Finding-Klassen, Resultsetverträge und Cleanup-Invarianten.

## 9. Erster Vertical Slice

Der erste vollständige Slice soll `BLOCKING-001` sein.

Begründung:

- für Einsteiger unmittelbar sichtbar;
- benötigt keine optionale SQL-Server-Komponente;
- funktioniert grundsätzlich auf SQL Server 2019, 2022 und 2025;
- ist unter Docker und Podman möglich;
- demonstriert mehrere zentrale Analyze-Module;
- trennt Aufbau, aktive Sessions, Beobachtung, Assertion und Cleanup klar.

Der Slice muss mindestens enthalten:

1. Auswahl über `Start-AnalyzeExample.ps1`;
2. Provisionierung über die vorhandenen öffentlichen `SQL_Server_Lab`-Cmdlets;
3. Erstellung einer synthetischen Datenbank;
4. Installation und Verifikation von `SQL_Server_Analyze`;
5. idempotentes Setup;
6. getrennte Skripte für Blocker und blockierte Session;
7. Analyse über `USP_CurrentBlocking`, `USP_CurrentRequests` und einen passenden Overview-Pfad;
8. begrenzte Verifikation stabiler Blocking-Invarianten;
9. vollständiges Cleanup im Erfolgs- und Fehlerpfad;
10. Unterstützung von Docker und Podman sowie SQL Server 2019, 2022 und 2025.

## 10. Folgende Beispielwellen

Nach dem Blocking-Slice sind Beispiele nach Wiederverwendbarkeit und Eigenlast zu priorisieren:

1. Query-Store-Nutzung und Framework-Usage;
2. TempDB-Verbrauch und TempDB-Konfiguration;
3. Statistikverteilung und Skew;
4. Memory Grants;
5. Plan Cache und Execution-Plan-Analyse;
6. Indexnutzung und fehlende Indizes;
7. Backupkette und Restore-Historie;
8. Temporal Tables;
9. In-Memory OLTP;
10. Service Broker, Full-Text, CDC und weitere optionale Features.

Optionale Features erhalten capability-adaptive `NOT_EXECUTED`- oder `UNSUPPORTED`-Ergebnisse. Eine nicht vorhandene Capability darf nicht als erfolgreicher Positivtest gewertet werden.

## 11. Wiederverwendung vorhandener Verträge

Die Realisierung soll vorhandene Bestände als Quellen verwenden:

- `Code/Install/Install_All.sql` für die Frameworkinstallation;
- `Code/Tests/Run_Release_Gate.sql` für den vollständigen Regressionstest;
- `Metadata/Quality/Special_Case_Test_Cases.csv` für vorhandene Szenario- und Invarianteninformationen;
- `Metadata/Inventory/Objects.csv` und `ResultSets.csv` für Objekt- und Ausgabeabdeckung;
- vorhandene synthetische Fixtures unter `Code/Tests`;
- vorhandene Beispiele unter `Code/Examples`;
- Procedure-Guides und Runbooks für Interpretation und Folgeanalysen.

Der neue Beispielkatalog ist die Quelle für spielbare Szenarien. Er ersetzt nicht die Release-Gate- oder Special-Case-Inventare.

## 12. Performance- und Sicherheitsregeln

- SQL-Versionen werden standardmäßig sequenziell getestet.
- High-Impact-Szenarien laufen nicht parallel.
- Jedes Szenario besitzt Timeout, Safety Class und Cleanup.
- Setup und Cleanup sind idempotent oder erkennen vorhandene fremde Objekte und brechen kontrolliert ab.
- Es werden ausschließlich klar synthetische Daten und generische Objektbezeichnungen verwendet.
- Das Cleanup löscht nur exakt registrierte projektspezifische Objekte beziehungsweise delegiert die Umgebungsentfernung an `SQL_Server_Lab`.
- Keine globale Docker-/Podman-Bereinigung, keine Wildcards und keine Mutation fremder Ressourcen.
- Vollständige SQLCMD-Ausgaben, Runtimewerte, Endpunkte und Secrets werden nicht in Repositoryartefakte übernommen.

## 13. Mögliche Lab-Gaps, die zuerst nur zu bewerten sind

Die erste Implementierungswelle muss prüfen, ob die vorhandenen Lab-Schnittstellen ausreichen. Mögliche, aber noch nicht genehmigte Erweiterungskandidaten sind:

- explizites Arbeitsverzeichnis für SQLCMD-`:r`-Includes;
- SQLCMD-Variablen als strukturierter Parameter;
- schrittbezogene Timeouts und stabile Exitcode-Rückgabe;
- strukturierte, begrenzte Skriptresultate.

Für den Blocking-Vertical-Slice sollen parallele Sessions zunächst durch die Analyze-Bedienlogik beziehungsweise separate lokale `sqlcmd`-Prozesse oder SSMS-Fenster realisiert werden. Daraus folgt nicht automatisch eine neue Lab-Funktion.

Jeder bestätigte Gap unterliegt der Freigabegrenze aus Abschnitt 3.

## 14. Abnahmekriterien für die Planungsphase

Die Planungsphase ist abgeschlossen, wenn:

- die Verantwortungsgrenze in diesem Dokument, `Next_Steps.md` und `Implementation_Status.csv` konsistent verankert ist;
- die Dokumentationsübersicht auf diesen Plan verweist;
- keine Implementierung in `SQL_Server_Lab` vorgenommen wurde;
- der erste Vertical Slice und seine Abnahmekriterien eindeutig benannt sind;
- spätere Bearbeiter erkennen, welche Entscheidungen vor einer Lab-Änderung erforderlich sind.

## 15. Abnahmekriterien für den ersten implementierten Slice

`BLOCKING-001` gilt erst als implementiert, wenn:

- Docker und Podman jeweils mindestens einen nativen Lauf bestanden haben;
- SQL Server 2019, 2022 und 2025 capability-gerecht abgedeckt sind;
- Interactive und Verify getrennt funktionieren;
- Frameworkinstallation, Setup, Analyse, Assertion und Cleanup reproduzierbar sind;
- Abbruch und `KeepOnFailure` keine fremden Ressourcen verändern;
- statische Dokumentations-, Datenschutz- und Commit-Verträge grün sind;
- die Laufzeitevidenz ausschließlich generische Zusammenfassungen enthält.

## 16. Verarbeitungsreihenfolge

1. vorhandene Beispiele, Fixtures und Special-Case-Fälle inventarisieren;
2. Beispielkatalog und JSON-Schema festlegen;
3. statischen Katalogvalidator implementieren;
4. `BLOCKING-001` als vollständigen Vertical Slice umsetzen;
5. Docker- und Podman-Läufe auf 2019, 2022 und 2025 durchführen;
6. tatsächliche Lab-Gaps dokumentieren und nur nach Freigabe im Lab bearbeiten;
7. weitere Beispiele in kleinen fachlichen Wellen übernehmen.
