# Linux-cgroup-Ressourcen: begrenzter externer Beobachtungsvertrag

**Status:** unabhängig geprüfter Implementierungsvorvertrag; kein Collector implementiert und keine native Hostabnahme erfolgt.
**Artefakt-UID:** `urn:uuid:01a17804-0079-7079-9643-0c639808a4ff`.
**Registrierung:** `DEFERRED`; keine finale lesbare Arbeitselementkennung vergeben.
**Stand:** 26. Oktober 2026.

## Zweck und erster Lieferumfang

Rang 11 der [Entwicklungsplanung](../Quality/Development_Waves_2026-10.md)
trennt SQL-sichtbare Upgradehinweise von Linux-Ressourcengrenzen. Dieser
Vertrag bereitet einen extern gestarteten, lesenden cgroup-v2-Collector vor.
Er beobachtet genau einen ausdrücklich ausgewählten Prozess und dessen
sichtbare cgroup-Hierarchie. Diese Welle liefert ausschließlich den Vertrag
und den Abschlussnachweis der vorherigen Upgrade-Welle.

`monitor.USP_OSInformation` bleibt für SQL-sichtbare Host-, Prozessspeicher-
und Dienstinformationen zuständig. Ein späterer Collector ergänzt diese
Beobachtung außerhalb der Engine. Ein SQL-Importer, eine Datenbankinstallation,
automatische Korrelation mit einer SQL-Instanz sowie eine dauerhafte Erfassung
sind nicht Teil des ersten Collectors. Eine weitere Produktwelle konkretisiert
Dateien, Schema und Oracles vor der Implementierung. Dieses Dossier ist über
[Next Steps](../Quality/Next_Steps.md) erreichbar; dort wird der ausführbare
Fortsetzungsschritt gepflegt.

## Quellen und fachliche Grenzen

Die am 26. Oktober 2026 geprüfte
[Microsoft-Dokumentation](https://learn.microsoft.com/en-us/sql/linux/configure/performance-best-practices-sql-server-memory?view=sql-server-ver17)
nennt cgroup-v2-Unterstützung ab SQL Server 2025 und SQL Server 2022 CU20.
Sie unterscheidet Hostspeicher, cgroup-Limit, SQL-Prozesslimit und
max_server_memory; MSSQL_MEMORY_LIMIT_MB hat Vorrang vor mssql.conf.
Das sind dokumentierte Produktbedingungen, keine Messung dieser Installation.
Der erste Collector liest weder Umgebungsvariablen noch mssql.conf und kann
daher die SQL-seitige Konfiguration oder ihre Wirksamkeit nicht bestätigen.

Nach dem [Kernelvertrag für cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html)
bezieht sich memory.current auf die Gruppe einschließlich Nachkommen.
memory.high beschreibt Drosselung und Reclaim, memory.max eine harte Grenze
mit möglichen vorübergehenden Überschreitungen. memory.events ist ohne die
Mountoption memory_localevents hierarchisch; diese Option begrenzt die Zählung
auf die lokale Gruppe.
cpu.max enthält Quota und Periode; max bezeichnet fehlende Quotenbegrenzung.
Die Wirkung hängt vom Scheduler ab. cpuset.cpus.effective beschreibt die
aktuell gewährten Online-CPUs. Diese Felder belegen weder reservierte
SQL-Kapazität noch SQL-Prozessverbrauch oder einen bestimmten OOM-Verursacher.

[Linux-cgroup-Namespaces](https://man7.org/linux/man-pages/man7/cgroup_namespaces.7.html)
virtualisieren Mitgliedschaftspfade und können Vorfahren verbergen.
[proc_pid_mountinfo](https://man7.org/linux/man-pages/man5/proc_pid_mountinfo.5.html)
beschreibt Mount-ID, Dateisystemwurzel, Mountpunkt und Dateisystemtyp in einem
Mount-Namespace. Ein sichtbarer Wurzelpfad beweist deshalb keine globale
Hierarchievollständigkeit. Die folgenden Auswahl-, Ausgabe- und Prüfregeln
sind der hier vorgeschlagene Projektvertrag.

## Aufruf, Zuständigkeit und Vertrauensgrenze

Der geplante lokale Aufruf verlangt eine positive numerische `target_pid`.
Es gibt keinen Prozessnamenscan, keinen impliziten PID-1-Default und keine
vom Aufrufer frei angegebenen Dateipfade. Betriebssystem und `/proc` müssen
Linux sein. Der Collector liest mit den vorhandenen Rechten seines Aufrufers;
er erhöht keine Rechte, betritt keine Namespaces und öffnet keine Remoteverbindung.
Fehlende Leserechte bleiben als Beobachtungsgrenze erhalten.

Die PID wählt einen Prozess im sichtbaren Procfs aus. Sie identifiziert nicht
automatisch einen SQL-Serverdienst. Die Ausgabe führt deshalb
`target_identity=CALLER_SELECTED_PROCESS` und `sql_binding=UNVERIFIED`.
Version, Dateihash, ein syntaktisch gültiges JSON oder dieselbe PID in einer
separaten SQL-Ausgabe schaffen keine vertrauenswürdige Instanzbindung.
Auch Collector-JSON bleibt für einen späteren Consumer unbestätigte externe
Evidenz, bis ein eigener Herkunfts-, Aktualitäts- und Bindungsvertrag besteht.
Die erste Implementierung stellt keine solche Attestierung bereit.

Analyze bleibt CLR-frei. SQLCLR, xp_cmdshell, externe Skriptausführung aus SQL,
Docker-/Kubernetes-APIs, SSH, Shellkommandos und automatische Paketinstrumentierung
werden nicht verwendet. Es gibt keine Schreibzugriffe auf Procfs oder cgroup,
keine Änderung von Affinität, Limits, Diensten oder SQL-Konfiguration und keine
automatische Behebung. Allgemeine Provisionierung gehört weiterhin nach
SQL_Server_Lab; eine fehlende Lab-Fähigkeit wird vor einer dortigen Umsetzung
als gesonderter Änderungsvorschlag freigegeben.

## Begrenzte Quellenwahl und Pfadauflösung

Die erste Implementierung unterstützt ausschließlich eine eindeutige
cgroup-v2-Mitgliedschaft in nachgewiesenen normalen domain-Gruppen.
`cgroup.type` wird am Blatt und den verwendeten sichtbaren Ebenen vor und nach
der Aufnahme gelesen. Nur der native Wert `domain` erlaubt die entsprechende
gebundene Ableitung. `threaded`, `domain threaded` und `domain (invalid)`
erhalten `UNSUPPORTED_LAYOUT`; fehlende oder unlesbare Typen erhalten
`TYPE_UNVERIFIED`. Ein fehlendes cgroup.type an einer Wurzel wird nicht als
nachgewiesenes domain ergänzt. Erfolgreiche Ressourcenreads bleiben erhalten,
aber die betroffenen Hierarchieableitungen entfallen. Insbesondere beweist die
Mitgliedschaft des Threadgruppenleiters keine gemeinsame CPU-/cpuset-Grenze
aller Threads eines threaded-Prozesses. Der erste Slice liest keine fremden
Threadlisten und unterstützt keine threadweise Korrelation. cgroup v1 und
hybride Mehrdeutigkeiten bleiben `UNSUPPORTED_LAYOUT`. Zulässig sind die
folgenden Metadatenquellen:

| Quelle | Verwendungszweck |
|---|---|
| `/proc/<target_pid>/stat` | Nur PID und Startticks werden exportiert; die Prozessbezeichnung wird beim Parsen berücksichtigt und nicht als Identitätsnachweis verwendet. |
| `/proc/<target_pid>/cgroup` | Die v2-Mitgliedschaft des ausgewählten Threadgruppenleiters wird vor und nach der Aufnahme geprüft. |
| cgroup.type | Der normale domain-Typ der verwendeten Ebenen wird geprüft; fehlende Typdaten werden nicht geraten. |
| `/proc/self/mountinfo` | Nur passende cgroup2-Mountmetadaten werden zur Auflösung ausgewählt. |
| `/proc/self/ns/{pid,mnt,cgroup}` und die entsprechenden Targetlinks | Namespace-Identitäten werden verglichen und vor/nach der Aufnahme gebunden. |

Target und Collector müssen im ersten Slice dieselben PID-, Mount- und
cgroup-Namespaces erkennen. Unterschiede oder unlesbare Bindungsmetadaten
führen zu `CONTEXT_UNBOUND`; der Collector versucht weder setns noch
/proc/<pid>/root als Ersatzweg. Mountwurzel und Mitgliedschaft werden im
selben Namespace componentweise aufgelöst. Die Auswahl verlangt einen
passenden cgroup2-Mount mit der spezifischsten passenden Wurzel; gleichrangige
mehrdeutige Treffer werden abgewiesen. Mountinfo-Escapes werden vor dem
Pfadvergleich dekodiert. Relative Rücksprünge, NUL und unzulässige Komponenten
werden nicht normalisiert und anschließend als gültige Auswahl ausgegeben.

Nur die feste Feldallowlist wird relativ zum gebundenen Mount geöffnet.
Die spätere Umsetzung muss Komponenten und Dateideskriptoren gegen
Symlinkfolgen, Mountwechsel und das Verlassen der ausgewählten Wurzel prüfen;
eine bloße Zeichenkettenprüfung vor open genügt nicht. cgroup-Verzeichnis-ID,
Mountidentität und aufgelöste Mitgliedschaft werden vor und nach der Aufnahme
verglichen. Kann die Plattform diese Bindung nicht herstellen, entfällt die
abgeleitete Ressourcenbewertung mit `CONTEXT_UNBOUND`.

Die Aufnahme liest höchstens 64 sichtbare Ebenen einschließlich Blatt,
höchstens 64 KiB je Ressourcendatei, 512 KiB je Procfs-Metadatenquelle und
insgesamt 8 MiB. Ein monotones Zeitbudget von zehn Sekunden stoppt die
Zulassung weiterer Reads; es garantiert keine Unterbrechung eines bereits
blockierten Systemaufrufs. Überschreitungen erhalten `LIMIT_REACHED` oder
`DEADLINE_REACHED`. Werte, die innerhalb einer abgeschnittenen Datei stehen,
werden nicht als vollständig geparste Quelle ausgegeben. Es gibt keine
rekursive Verzeichnissuche und keine automatische Wiederholung.

## Ressourcenfelder und Darstellung

Am Blatt werden die acht folgenden Dateien unabhängig gelesen. Auf sichtbaren
Vorfahren werden ausschließlich memory.max, memory.high, memory.swap.max und
cpu.max gelesen. Fehlende Felder an einer sichtbaren Wurzel werden ausdrücklich
als fehlend berichtet und nicht durch Standardwerte ersetzt.

| Quelldatei | Geplante typisierte Projektion und Aussagegrenze |
|---|---|
| memory.max | Ein endlicher Bytewert oder UNLIMITED bleibt vom Readzustand getrennt. |
| memory.high | Ein endlicher Bytewert oder UNLIMITED wird als Drosselungsgrenze geführt. |
| memory.current | Der beobachtete Bytewert bleibt eine Gruppenaufnahme. |
| memory.swap.max | Ein endlicher Bytewert oder UNLIMITED wird separat von RAM geführt. |
| memory.events | Native Schlüssel und kumulative Werte bleiben ohne Delta oder Opferschluss erhalten. |
| cpu.max | Quota und Periodendauer in Mikrosekunden bleiben als Paar erhalten; ein endlicher Quotient wird als exakter Bruch geführt. |
| cpu.stat | Native Schlüssel und kumulative Werte werden ohne Auslastungsprozente oder Rate ausgegeben. |
| cpuset.cpus.effective | Native CPU-Liste und Anzahl der vereinigten Intervalle werden ohne Expansion großer Bereiche geführt. |

Jede Ressourcenquelle besitzt eine stabile Quellordinalzahl, Ebenenordinalzahl,
Dateikennung, Start-/Endzeit in UTC, monotone Dauer, tatsächliche Bytezahl,
`read_state`, `parse_state`, nativen Fehlercode soweit verfügbar und den
begrenzten Rohwert. Procfs-Rohtexte werden nicht exportiert. Erfolgreicher Read
und ungültiger Inhalt sind getrennte Zustände. Fehlend, verweigert, Lesefehler,
Abbruch und nicht ausgewählt werden nicht als leere erfolgreiche Quelle oder
als numerische Null zusammengeführt. Ein echter endlicher Nullwert bleibt Null;
UNLIMITED hat keinen erfundenen numerischen Maximalwert.

Der Parser verwirft negative Werte, ungültige Zahlen, Überläufe, doppelte
Schlüssel sowie unvollständige Quota-/Periodenpaare. Zahlenwerte werden im
JSON als Dezimalzeichenketten ohne Genauigkeitsverlust transportiert; eine
Quota benötigt einen positiven Nenner. Unbekannte Zählerschlüssel bleiben
mit Rohwert und `UNMAPPED_KEY` sichtbar und fließen in keine bekannte Kennzahl
ein. Für memory.events wird `event_scope=UNVERIFIED` ausgegeben: Die sichtbare
Mountoption memory_localevents wird zwar mit ihrer Beobachtungsbindung
geführt, ihre Abwesenheit in einem eingeschränkten Namespace beweist jedoch
keine globale Einstellung. Der Collector klassifiziert deshalb keine
Ereignisreichweite allein aus fehlenden Mountoptionen. CPU-Intervalle werden
validiert und vereinigt; ein leeres effective-Set
bleibt `EMPTY_OBSERVATION` ohne Behauptung einer nutzbaren CPU-Zahl von Null.
Die genaue JSON-Schemadatei und der CLI-Exitcodevertrag folgen vor Produktcode
in derselben abgegrenzten Implementierungswelle.

## Hierarchie, Zeit und Partialität

Die geplanten sichtbaren Minima heißen `visible_memory_max_ceiling_bytes`,
`visible_swap_max_ceiling_bytes` und `visible_cpu_quota_ratio`. Sie verwenden
nur erfolgreich gelesene und geparste endliche Werte derselben gebundenen
Aufnahme. Jede Ableitung nennt ihre tatsächlich verwendeten Quellordinale.
Eine Lücke, Abbruch oder ungültige relevante Ebene unterdrückt das jeweilige
Minimum. Der rein sichtbare Umfang bleibt auch bei lückenlosen Reads
`global_hierarchy=UNVERIFIED`; versteckte strengere Vorfahren sind möglich.
Sind alle sichtbaren Werte max, lautet das Ergebnis `NO_FINITE_VISIBLE_LIMIT`
und nicht global unbegrenzt. memory.high wird separat je Ebene berichtet.

Ein sichtbares Minimum ist weder garantierte Kapazität noch verfügbare
Restmenge. Der Collector berechnet insbesondere nicht memory.max minus
memory.current als freien SQL-Speicher, addiert RAM und Swap nicht und
übersetzt CPU-Quota nicht in SQL-Scheduler oder MAXDOP. Speicher-/CPU-Druck,
Ereignisse anderer Prozesse, Kernelbesonderheiten und Hostkapazität werden
daraus nicht erklärt.

Vor und nach allen Ressourcenreads werden Prozessstart, Namespaceidentitäten,
Mitgliedschaft sowie Mount-/Verzeichnisbindung geprüft. UTC-Uhrsprünge werden
gegen monotone Reihenfolge als Zeitproblem gekennzeichnet. Bei Abweichung oder
fehlendem Abschluss entstehen keine kontextgebundenen Ableitungen; erfolgreiche
Einzelreads bleiben als `CONTEXT_UNBOUND` zuordenbare Rohbeobachtungen erhalten.
Limits, cgroup.type und effective-CPU-Set werden am Ende erneut gelesen.
Abweichungen
markieren `CONFIGURATION_CHANGED` und sperren davon betroffene Ableitungen.
Unveränderte Randwerte beweisen keine zwischenzeitliche Kontinuität oder
atomare Mehrdateiaufnahme. Kumulative Counter bleiben einzelne Messpunkte.

Das Gesamtresultat bleibt eine begrenzte Beobachtung mit `partial=true`.
Fehler einer Ressource erhalten alle anderen erfolgreichen Quellen. Ein
technischer Ausgabe- oder Schemaproblem darf keinen erfolgreichen fertigen
JSON-Datensatz vortäuschen. Runtimewerte und vollständige private Prüflogs
bleiben außerhalb von Repository- und GitHub-Artefakten; synthetische Fixtures
sind klar von nativen Hostbelegen getrennt.

## Abnahme und nächster ausführbarer Schritt

Diese Vertragswelle verlangt einen unabhängigen Review der Quellen-,
Namespace-, Pfad-, Hierarchie-, Vertrauens- und Abbruchgrenzen sowie die
betroffenen statischen Dokumentations-, Metadaten-, Privacy- und Registrygates.
Sie startet keine SQL-Instanz, keinen Hostcollector und kein natives Lab.

Nach Integration folgt ein kohärenter erster Collector-Slice mit JSON-Schema,
Parser und synthetischem Dateizugriffsadapter. Seine Oracles müssen endliche
Werte und Null, max, Teilreads, fehlende/verweigerte Quellen, unbekannte Felder,
Überlauf, große und überlappende CPU-Intervalle, Mountinfo-Escapes, Bindmounts,
mehrdeutige Auflösung, Namespaceabweichung, normale domain-Gruppen,
threaded/domain-threaded/invalid/unbekannte Typen, unterschiedlich platzierte
Threads sowie memory.events mit und ohne memory_localevents und jeweils
unbestätigter Ereignisreichweite, PID-Wiederverwendung, Symlink- und
Mounttausch, Mitgliedschaftswechsel, sichtbare Vorfahrenlücken, versteckte
Vorfahren, geänderte Randkonfiguration und Budgetabbrüche unabhängig prüfen.
Ein Fixture-PASS qualifiziert nur diesen synthetischen Scope.

Ein späterer Linux-Nativnachweis benötigt ein eindeutig eigenes isoliertes
Testziel, vorhandene zulässige SQL_Server_Lab-Fähigkeiten, kontrollierte
positive endliche Limits, getrennte Read-/Bindungsnachweise und bestätigten
Cleanup. SQL-Instanzbindung und globale Hierarchievollständigkeit bleiben
auch dann offen, solange ihr eigener Vertrag und Nachweis fehlen. Allgemeine
Lab-Erweiterungen, cgroup v1, Hosttopologie, Kubernetes-, mssql.conf- und
Umgebungserfassung bleiben gesonderte Umfänge. Es wird weder eine vollständige
Linuxabdeckung noch eine abgeschlossene native SQL-Releasematrix behauptet.
