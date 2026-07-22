# Unterstützte Plattform- und Nachweismatrix

**Stand:** 21. Juli 2026
**Frameworkrelease:** `1.1.0-special.13`
**Maschinenlesbare Detailmatrix:** `Metadata/Quality/Test_Matrix.csv`

## Nachweisregel

Nur eine tatsächlich ausgeführte Kombination mit dokumentiertem Ergebnis ist ein Laufzeitnachweis. `NOT_EXECUTED` bedeutet ausdrücklich nicht getestet. `PASS_WITH_LIMITATIONS` bedeutet, dass der geprüfte Vertragsumfang bestanden ist, aber die in dieser Seite genannten Plattform- oder Featuregrenzen fortbestehen.

## Nachgewiesene Kernziele

| SQL Server | ProductVersion | Compatibility Level | Plattform | Ergebnis |
|---|---|---:|---|---|
| 2019 | `15.0.4480.2` | 150 | Linux, synthetisches Ziel | `PASS_WITH_LIMITATIONS` |
| 2022 | `16.0.4265.3` | 160 | Linux, synthetisches Ziel | `PASS_WITH_LIMITATIONS` |
| 2025 | `17.0.4065.4` | 170 | Linux, synthetisches Ziel | `PASS_WITH_LIMITATIONS`; zusätzlicher Regexvertrag bestanden |

Die Zielcollation ist `SQL_Latin1_General_CP1_CS_AS` für Server, `tempdb` und Installationsdatenbank. Andere Collations sind derzeit nicht freigegeben.

## Abgedeckte Vertragsbereiche

Die Kernziele prüfen:

- vollständige Installation und Objektbestand;
- Parameter-, Filter-, Listen-, Pattern- und Limitverträge;
- Common, Current State, Object/Index, Plan Cache, Query Store, Extended Events, Infrastruktur und Server Health;
- Capability-, Berechtigungs-, Leer-, Teil- und Fehlerstatus;
- RAW, CONSOLE, TABLE, NONE und JSON;
- typisierte TABLE-Schemas und lokale Zieltabellen;
- Unicode-, Textkürzungs-, XML- und JSON-Verträge;
- P0-/P1-/P2-Spezialfälle mit synthetischen, rücksetzbaren Zuständen;
- eigenständige Execution-Plan-Analyse und deren Teilinstaller;
- versionsabhängige Regexunterstützung auf SQL Server 2025.

Für den Analysis Navigator definiert das Release-Gate zusätzlich einen Metadaten- und Suchvertrag: Vollständigkeit aller öffentlichen Procedures, DE/EN-Begriffe, gültige Beziehungen, case-/accent-insensitive Suche, Paketstatus und RAW/CONSOLE/TABLE/JSON-Ausgabe. Eine Matrixzeile weist diesen Zusatzvertrag nur nach, wenn ihr `CommitSha` einen Frameworkstand mit dem Navigator bezeichnet; die oben aufgeführten Nachweise stammen aus dem vorherigen Frameworkstand.

## Feature- und Aussagegrenzen

| Bereich | Nachweisgrenze |
|---|---|
| Memory Pressure | kein künstlich erzwungener realer Speicherdruck oder Resource-Semaphore-Waiter; bedingte Interpretation aktueller Evidenz |
| interne Contention | kein erzwungener produktionsähnlicher PAGELATCH-Hotspot; opt-in- und Deltavertrag |
| Backup/Restore | synthetische Backupkette; kein externer Restore auf unabhängigem Host |
| Availability | HADR-Abwesenheit real; Queue-/Suspend-/Seedingklassifikation ohne operatives Failover oder Seeding |
| SQL Agent | Leer- und Klassifikationszustände ohne Änderung realer Jobs, Alerts, Operatoren oder Mail |
| In-Memory OLTP | kein erzwungener realer Speicherdruck; breiter Hashkettenpfad bleibt opt-in |
| Temporal | keine Prüfung realer History-Nutzzeilen oder Periodenüberlappungen |
| Service Broker | keine Nachrichtenkörper, Queue-Payloads oder Conversation-Mutationen |
| Full-Text | Linux kann feature-positive Full-Text-Komponenten begrenzen; keine indizierten Inhalte |
| Data Capture | lokale Metadaten und Klassifikation; keine Remote-Subscriber-/Distributor-Netzpfade |
| Verschlüsselung | keine Schlüssel- oder Medieninhalte und kein externer Restorebeweis |
| Wartung | keine operative Wartungsänderung |
| Last | keine allgemeine Produktionslast-, Skalierungs- oder Langzeitzusage |

## Nicht durch die Kernmatrix abgedeckt

- Windows-spezifische Feature-Positivpfade;
- Azure SQL Managed Instance;
- abweichende Server-/`tempdb`-Collations;
- reale Unternehmens-, Kunden- oder Produktionsdaten;
- vollständige Last-, Soak-, Chaos- oder Failovertests;
- jede mögliche Edition, Patchstufe, Topologie und Permissionkombination;
- externe Restore-, Schlüssel-, Netzwerk- oder Storage-Nachweise.

Diese Fälle dürfen nicht aus dem Kernnachweis abgeleitet werden. Vor Verwendung in einer abweichenden Zielkombination sind Installation, Smoke-Test, Capabilities und die benötigten Procedures kontrolliert zu prüfen.

## Berechtigungsprofile

Die Matrix trennt technische Profile ohne konkrete Principalnamen:

- Installationskontext mit DDL-Rechten;
- Laufzeitkontext mit den für die gewählte Quelle erforderlichen Server-/Datenbankrechten;
- absichtlich eingeschränkter Kontext für `PERMISSION_DENIED`, `AVAILABLE_LIMITED` und `DENIED_GROUP`;
- sysadmin nur für ausdrücklich notwendige technische Vergleichspfade.

Die interne Gruppenpolicy und SQL-Server-Rechte werden getrennt geprüft. Keine erfolgreiche Matrixzeile bedeutet, dass jeder Login automatisch alle Resultsets sehen kann.

## Bewertungsstatus

| Status | Bedeutung |
|---|---|
| `PASS` | der definierte Ziel- und Vertragsumfang ist ohne bekannte Einschränkung bestanden |
| `PASS_WITH_LIMITATIONS` | der definierte Umfang ist bestanden; dokumentierte Feature-, Plattform- oder Evidenzgrenzen bleiben |
| `FAIL` | mindestens ein verbindlicher Vertrag ist nicht bestanden |
| `NOT_EXECUTED` | kein Laufzeitnachweis |

## Verwandte Dokumente

- [Bekannte Einschränkungen](Known_Issues.md)
- [Performance- und Risikobewertung](Performance_and_Risk_Assessment.md)
- [Installation](../Reference/Installation.md)
- [Versionsadaptive Features](../Operations/Version_Adaptive_Features.md)
- [Execution-Plan-Analyse](../Architecture/Execution_Plan_Analysis_Design.md)
