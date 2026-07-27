# T-SQL-Szenarien und fachliche Orchestrierung

**Stand:** 27. Juli 2026  
**Status:** `DECIDED`  
**Geltungsbereich:** spielbare und reproduzierbare Beispiele in `SQL_Server_Analyze`

## 1. Architekturentscheidung

Die fachlichen Beispiele bleiben als eigenständige T-SQL-Skripte erhalten. Sie müssen ohne Jupyter Notebook und ohne Python verständlich, manuell ausführbar und analysierbar sein.

T-SQL ist die primäre fachliche Darstellung für:

- Aufbau und Vorbereitung synthetischer Zustände;
- getrennte Sessionabläufe;
- Workloads und Zustandsänderungen;
- Beobachtungs- und Diagnoseabfragen;
- fachliche Validierung;
- Reset und Cleanup.

Ein zukünftiges Jupyter Notebook darf diese Artefakte konsumieren oder aus Markdown und T-SQL generiert werden. Es ist eine optionale Präsentations- und Bedienoberfläche, keine Laufzeitvoraussetzung und keine zweite fachliche Quelle.

## 2. Source of Truth

Die kanonischen Artefakte eines Beispiels sind:

```text
README.md oder vergleichbare Anleitung
+ eigenständige *.sql-Dateien
+ Szenariometadaten
+ optional projektspezifische Orchestrierung
```

Es gelten folgende Regeln:

1. Fachliche SQL-Logik wird nicht ausschließlich in PowerShell, Python, Notebook-Zellen oder CI-Workflows abgelegt.
2. SQL-Code wird nicht dauerhaft zwischen Dokumentation, Notebook und Runner dupliziert.
3. Generierte Notebooks oder andere Komfortartefakte dürfen verworfen und aus den kanonischen Quellen neu erstellt werden.
4. Verbindungsdaten, Secrets, reale Endpunkte und lokale Run-State-Werte werden nicht in Beispieldateien oder Notebooks persistiert.

## 3. Drei Orchestrierungsstufen

### 3.1 Manuell orchestriert

Bei einfachen, didaktisch wertvollen Abläufen ist der Benutzer der Orchestrator.

Beispiel:

```text
1. Setup.sql ausführen.
2. SessionA_Blocker.sql in Fenster A starten.
3. SessionB_Blocked.sql in Fenster B starten.
4. Analyze.sql in Fenster C ausführen.
5. Cleanup.sql ausführen.
```

Dieser Modus ist zu bevorzugen, wenn Reihenfolge und Wirkung in SSMS oder einem vergleichbaren SQL-Client leicht nachvollziehbar sind. Die manuelle Bedienung ist hier Teil des Lern- und Analyseziels.

### 3.2 Runner-gestützt und interaktiv beobachtet

Komplexere Szenarien dürfen durch einen projektspezifischen Runner erzeugt und aufrechterhalten werden. Typische Anforderungen sind:

- mehrere unabhängige SQL-Verbindungen;
- definierte zeitliche Reihenfolge;
- Synchronisationspunkte zwischen Sessions;
- wiederholte oder dauerhafte Workloads;
- kontrolliert wechselnde Zustände;
- ein belastbarer Zustand `READY_FOR_OBSERVATION`;
- kontrollierter Abbruch, Reset und Cleanup.

Der Runner steuert Sessions, Timing und Wiederholungen. Die fachliche Workload und die Beobachtung bleiben nach Möglichkeit in eigenständigen T-SQL-Skripten. Der Benutzer untersucht den erzeugten Zustand weiterhin mit `SQL_Server_Analyze`, SSMS, `sqlcmd` oder einem anderen SQL-Client.

### 3.3 Vollautomatisch verifiziert

Für Smoke- und Regressionstests darf derselbe fachliche Zustand begrenzt automatisiert erzeugt, geprüft und bereinigt werden.

Dieser Modus prüft stabile Invarianten, beispielsweise:

- erwartete Objekt- oder Statusklassen;
- vorhandene synthetische Daten;
- erwartete Analyze-Findings;
- erfolgreicher Reset;
- vollständiges Cleanup.

Er ersetzt nicht den interaktiven Ablauf. Flüchtige Werte wie exakte Laufzeiten, Session IDs, LSNs, Plan Handles oder Hostwerte sind keine stabilen Assertions.

## 4. Trennung der Orchestrierungsebenen

| Ebene | Verantwortliches Repository | Aufgabe |
|---|---|---|
| Infrastruktur-Orchestrierung | `SQL_Server_Lab` | Container, VMs, SQL-Instanzen, Ressourcen, Storage, Netzwerk, Readiness und Infrastruktur-Lifecycle |
| Szenario-Orchestrierung | `SQL_Server_Analyze` | SQL-Sessions, Reihenfolge, Timing, Schleifen, Workloads, Beobachtungsbereitschaft, fachlicher Reset und Cleanup |
| Beobachtung und Interpretation | `SQL_Server_Analyze` | Diagnoseabfragen, Analyzer-Aufrufe, erwartete Befunde und Interpretationsgrenzen |

Ein projektspezifischer Runner ist keine zweite Container- oder VM-Orchestrierung. Er darf die durch `SQL_Server_Lab` bereitgestellten Endpunkte verwenden, aber nicht selbst allgemeine Docker-, Podman- oder Hyper-V-Provisionierung implementieren.

Fehlt eine allgemeine technische Fähigkeit in `SQL_Server_Lab`, wird der konkrete Gap dokumentiert und vor einer Änderung ausdrücklich freigegeben. Eine komplexe Sessionfolge allein begründet noch keine Lab-Erweiterung.

## 5. Mindestvertrag für komplexe Szenarien

Ein Runner-gestütztes Szenario beschreibt mindestens:

- stabile Szenario-ID und Lern- oder Analyseziel;
- unterstützte SQL-Server-Versionen und Provider;
- erforderliche Datenbanken und Sessionrollen;
- kanonische T-SQL-Skripte je Rolle;
- Startreihenfolge und Synchronisationsbedingungen;
- Wiederholungs- oder Dauerschleifenmodus;
- Kriterium für `READY_FOR_OBSERVATION`;
- Timeout- und Fehlerverhalten;
- erlaubte Benutzerinteraktionen während des Laufs;
- Stop-, Reset- und Cleanup-Verhalten;
- Safety Class und Ressourcenbegrenzung;
- stabile Verifikationsinvarianten;
- bekannte Plattform- und Versionsgrenzen.

## 6. Auswahlregel

Es wird stets die kleinste ausreichende Orchestrierungsstufe verwendet:

1. manuell, wenn der Zustand nachvollziehbar durch wenige T-SQL-Sessions erzeugt werden kann;
2. Runner-gestützt, wenn Timing, Parallelität oder Wiederholung sonst nicht reproduzierbar sind;
3. zusätzlich automatisiert verifiziert, wenn ein stabiler Regressionstest fachlich sinnvoll ist.

Automatisierung ist kein Selbstzweck. Sie darf den für Benutzer sichtbaren Zusammenhang zwischen Ursache, Sessionaktivität, beobachtetem Zustand und Analyze-Ergebnis nicht verdecken.

## 7. Jupyter als zukünftige Erweiterungsoption

Jupyter Notebooks sind zulässig als optionale, generierte Bedien- oder Präsentationsschicht. Dabei gelten folgende Grenzen:

- keine Jupyter-, Python- oder Kernel-Abhängigkeit für Installation und Kernbetrieb von `SQL_Server_Analyze`;
- keine exklusive Fachlogik in Notebook-Zellen;
- T-SQL-Beispiele bleiben mit üblichen SQL-Clients ausführbar;
- Markdown und T-SQL bleiben die bevorzugten Quellen;
- Notebook-Ausgaben sind keine dauerhafte Testevidenz, sofern sie lokale Endpunkte, Runtimewerte oder andere umgebungsabhängige Daten enthalten.

## 8. Auswirkungen auf die Umsetzung

Der erste Vertical Slice `BLOCKING-001` bleibt bewusst manuell orchestriert beziehungsweise kann getrennte lokale `sqlcmd`-Prozesse verwenden. Spätere Szenarien wie kontinuierliche Last, Memory-Grant-Druck, TempDB-Verbrauch, Query-Store-Verläufe oder wechselnde Blocking Chains können die Runner-gestützte Stufe benötigen.

Bei der Inventarisierung vorhandener und geplanter Beispiele ist künftig zusätzlich zu klassifizieren:

- `MANUAL`;
- `RUNNER_ASSISTED`;
- `AUTOMATED_VERIFY`;
- oder eine fachlich begründete Kombination daraus.

Diese Entscheidung ergänzt den bestehenden Plan `SQL_Server_Lab_Example_Integration_Plan.md` und ist bei Katalog, Schema, Vertical Slices und späteren Beispielwellen verbindlich zu berücksichtigen.
