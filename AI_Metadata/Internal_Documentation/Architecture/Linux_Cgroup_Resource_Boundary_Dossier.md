# Linux-cgroup-Ressourcen: begrenzter externer Beobachtungsvertrag

**Status:** Ressourcen- und Parserverträge sind unabhängig geprüft. Der nachfolgende Reader-Vertrag ist ein primärquellenbasierter, noch unabhängig zu prüfender Entwurf. Es ist kein Collector implementiert und keine native Hostabnahme erfolgt.
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
| `/proc/<target_pid>/stat` | Nur PID und Startticks werden für die Prozess-Fences geparst. Die Prozessbezeichnung und übriger Rohtext werden weder exportiert noch als Identitätsnachweis verwendet. |
| `/proc/<target_pid>/cgroup` | Die v2-Mitgliedschaft des ausgewählten Threadgruppenleiters wird vor und nach der Aufnahme geprüft. |
| cgroup.type | Der normale domain-Typ der verwendeten Ebenen wird geprüft; fehlende Typdaten werden nicht geraten. |
| `/proc/self/mountinfo` | Nur passende cgroup2-Mountmetadaten werden zur Auflösung ausgewählt; der Reader liest die Callerdatei relativ zum eng gebundenen `self`-FD. |
| `/proc/self/ns/{pid,mnt,cgroup}` und die entsprechenden Targetlinks | Namespace-Identitäten werden verglichen und vor/nach der Aufnahme gebunden. |
| `/proc/self/fdinfo/<pidfd>` | Nur der Kernelwert `Pid` wird zur Bindung des pidfd an die PID-Ansicht des verwendeten Procfs geparst; andere Felder und der Rohtext bleiben ausgeschlossen. |

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

### Parser-Schnittstelle für skalare Ressourcenwerte

Der erste Implementierungsschritt ist auf einen reinen Python-3.11-Parser
ohne Dateizugriff begrenzt. `Code/Tools/Linux_Cgroup_Values.py` stellt
`parse_resource_value(source_key: str, raw_value: str) -> dict[str, str | None]`
bereit. Zulässige `source_key`-Werte sind `memory.max`, `memory.high`,
`memory.swap.max`, `memory.current` und `cpu.max`. Unbekannte Schlüssel lösen
`ValueError`, Argumente des falschen Typs `TypeError` aus.

Jedes Ergebnis besitzt fest die Felder `source_key`, `raw_value`,
`parse_state`, `reason_code`, `value_kind`, `value`, `quota_us`, `period_us`,
`ratio_numerator` und `ratio_denominator`. `raw_value` bleibt als
unveränderter Python-String erhalten. `parse_state` ist `VALID`, `INVALID_VALUE` oder
`LIMIT_REACHED`; `reason_code` benennt den konkreten Zustand als
`FINITE_VALUE`, `UNLIMITED`, `INVALID_FORMAT`, `INVALID_TOKEN`,
`OUT_OF_RANGE`, `NON_UTF8_TEXT` oder `INPUT_TOO_LARGE`. `value_kind` ist
`FINITE`, `UNLIMITED` oder `NONE`. Endliche Speicherwerte stehen als
Dezimalzeichenkette in `value`; bei `cpu.max` stehen Quota und Periode in
`quota_us` und `period_us`. Ein endlicher CPU-Quotient wird ausschließlich als
gekürztes Paar `ratio_numerator`/`ratio_denominator` ausgegeben. Alle nicht
zutreffenden Wertfelder sind `None`; eine unbegrenzte Quote behält ihre
Periode und hat keine numerische Quote oder Ratio. Ergebnisfelder enthalten
keine Python-Ganzzahlen und sind JSON-kompatibel. Die API liefert keinen
Datei- oder Readzustand und kann fehlende Dateien oder Lesefehler nicht
feststellen.

Speicherwerte akzeptieren ASCII-Dezimalziffern von null bis
`18446744073709551615`; `max` ist nur für `memory.max`, `memory.high` und
`memory.swap.max` zulässig. `cpu.max` verlangt genau zwei Tokens mit positiver
endlicher Quote oder `max` und strikt positiver Periode, jeweils höchstens
`18446744073709551615`. Geparst wird nach Entfernen äußerer ASCII-Leerzeichen,
Tabulatoren, CR und LF. Die UTF-8-Eingabegrenze beträgt 64 KiB und wird vor
einer Ganzzahlkonvertierung geprüft. Ein Überschreiten erzeugt
`LIMIT_REACHED` ohne Zahlenwerte.

Diese API ist weder Voll-Collector-Schnittstelle noch Dateizugriffsadapter.
Namespace-/PID-/Mountauflösung, Hierarchieableitungen, CLI, SQL-Import und
native Hostqualifikation bleiben nicht implementiert.
Die Registrierung des Validators im vorhandenen statischen Runner aktiviert
bei dessen Änderung einmalig dessen bestehenden vollständigen Satz statischer
Selbsttests. Diese notwendige Runnergrenze wird nicht durch Verengung
bestehender Gates umgangen; spätere Änderungen am Parser aktivieren gezielt
den neuen fokussierten Selbsttest. Der vorhandene Dokumentationsworkflow
erhält lediglich den Modulpfad als Trigger.

### Weitere reine Parser-APIs

`Code/Tools/Linux_Cgroup_Values.py` ergänzt die unveränderte
`parse_resource_value`-API um `parse_cpuset_cpus_effective(raw_value: str)`,
`parse_memory_events(raw_value: str)`, `parse_cpu_stat(raw_value: str)` und
`parse_cgroup_type(raw_value: str)`. Alle prüfen den Argumenttyp mit
`TypeError`, bewahren `raw_value` unverändert und wenden vor jedem Parsen die
64-KiB-UTF-8-Grenze an. Fehlerhafte UTF-8-Strings, zu große Eingaben und
ungültige Inhalte erhalten reguläre Status-/Reason-Codes ohne Zahlenwerte.
Zahlen im Ergebnis sind Dezimalzeichenketten; strukturierte Arrays enthalten
ebenfalls nur Strings und fest dokumentierte Zustandsfelder. Keine API liest
Dateien oder bestimmt deren Vorhandensein oder Leserechte.

Alle neuen Ergebnisse enthalten `source_key`, `raw_value`, `parse_state` und
`reason_code`. `parse_state` verwendet `VALID`, `INVALID_VALUE`,
`LIMIT_REACHED`, `EMPTY_OBSERVATION`, `UNSUPPORTED_LAYOUT` oder
`TYPE_UNVERIFIED`. Fehlercodes sind `INVALID_FORMAT`, `INVALID_TOKEN`,
`INVALID_RANGE`, `OUT_OF_RANGE`, `DUPLICATE_KEY`, `NON_UTF8_TEXT` und
`INPUT_TOO_LARGE`; erfolgreiche CPuset- und Counterparser verwenden
`FINITE_VALUE` beziehungsweise `COUNTERS_PARSED`. Die Typklassifikation
verwendet die gleichnamigen `SUPPORTED_DOMAIN`, `UNSUPPORTED_LAYOUT` und
`TYPE_UNVERIFIED`-Codes.

`parse_cpuset_cpus_effective` liefert `source_key`, `raw_value`,
`parse_state`, `reason_code`, `intervals` und `cpu_count`. IDs und
Intervallenden liegen zwischen 0 und 2147483647. Die API sortiert und vereinigt
überlappende oder benachbarte Intervalle ohne CPU-Expansion. `intervals` führt
Objekte mit den Stringfeldern `start` und `end`; die eindeutige Anzahl steht
als Dezimalzeichenkette in `cpu_count`. Leerer Inhalt ergibt
`EMPTY_OBSERVATION` mit `cpu_count=None`, keine synthetische Null.
Die Syntax ist eine kommagetrennte Liste aus ASCII-Dezimal-IDs oder
aufsteigenden `start-end`-Intervallen; äußere ASCII-Leerzeichen, Tabulatoren,
CR und LF werden entfernt, innere Leerzeichen nicht.

`parse_memory_events` und `parse_cpu_stat` liefern `source_key`, `raw_value`,
`parse_state`, `reason_code`, `counters` und bei Memory-Events zusätzlich
`event_scope`. Jede nichtleere Zeile muss genau einen ASCII-Schlüssel und
einen unsigned64-Dezimalwert enthalten. Schlüssel erfüllen `[A-Za-z0-9_]+`;
Leerzeilen werden ignoriert, führende Nullen in Werten bleiben nur im Rohtext
erhalten. Doppelte Schlüssel oder eine fehlerhafte Zeile verwerfen die
gesamte Quelle; ungültige Dokumente liefern `counters=None`, also keine
Teilkennzahlen. Jedes gültige Counterobjekt besitzt `key`, `value`,
`raw_value`, `key_state` und `unit`; `value` ist die kanonische
Dezimalzeichenkette und `raw_value` erhält den Token unverändert. Aktuell
dokumentierte `memory.events`-Schlüssel sind
`low`, `high`, `max`, `oom`, `oom_kill`, `oom_group_kill` und
`sock_throttled`; ihre Einheit ist `events`. Bekannte `cpu.stat`-Schlüssel
`usage_usec`, `user_usec`, `system_usec`, `throttled_usec` und `burst_usec`
haben die Einheit `microseconds`; `nr_periods`, `nr_throttled` und
`nr_bursts` haben die Einheit `count`. Die Definitionen folgen der
[Kernel-Dokumentation für cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html).
Andere syntaktisch gültige Schlüssel bleiben in Dateireihenfolge als
`key_state=UNMAPPED_KEY`, mit Rohwert und `unit=None` erhalten. Es wird keine
Einheit oder Aggregation für unbekannte Schlüssel erfunden. `event_scope` ist
immer `UNVERIFIED`; die API bildet weder Deltas noch Raten, Auslastung oder
OOM-Verursachung ab.

`parse_cgroup_type` liefert `source_key`, `raw_value`, `parse_state`,
`reason_code`, `observed_type` und `layout_state`. `domain` ergibt
`SUPPORTED_DOMAIN`; `threaded`, `domain threaded`, `domain invalid` und
`domain (invalid)` ergeben `UNSUPPORTED_LAYOUT`. Leere oder andere
beobachtete Inhalte ergeben `TYPE_UNVERIFIED`, ohne einen Domain-Default zu
ergänzen.

Alle vier APIs sind reine Parser. Sie binden weder Host, Prozess, Namespace,
Mount noch Hierarchie und erzeugen keinen Collector oder SQL-Instanzbezug.

### Reine Parser für Procfs-Metadaten

`Code/Tools/Linux_Cgroup_Metadata.py` stellt
`parse_v2_membership(raw_value: str)` und
`parse_cgroup2_mountinfo(raw_value: str)` bereit. Beide APIs prüfen
Nicht-Stringargumente mit `TypeError`, akzeptieren höchstens 512 KiB UTF-8
und geben keine Rohzeilen, nativen Fehlertexte oder Readzustände aus.
Ungültige Eingaben liefern nur stabile `parse_state`- und `reason_code`-Werte
sowie betroffene 1-basierte `issue_line_ordinals`. Zahlen werden als
Dezimalzeichenketten ausgegeben. Die Ergebnisse sind begrenzte
Parserprojektionen; sie attestieren keine Dateiverfügbarkeit, Berechtigung,
Prozessidentität, Mountauswahl oder globale Hierarchievollständigkeit.
Zustände sind `VALID`, `INVALID_VALUE`, `LIMIT_REACHED`,
`UNSUPPORTED_LAYOUT`, `MISSING_MEMBERSHIP` und `DELETED_RECORD`. Stabile
Reason-Codes sind `MALFORMED_RECORD`, `INVALID_PATH`, `INVALID_TOKEN`,
`INVALID_ID`, `INVALID_ESCAPE`, `OUT_OF_RANGE`, `DUPLICATE_V2_RECORD`,
`DUPLICATE_MOUNT_ID`, `V1_ONLY`, `HYBRID_LAYOUT`,
`V2_MEMBERSHIP_MISSING`, `MEMBERSHIP_DELETED`, `NON_UTF8_TEXT` und
`INPUT_TOO_LARGE`; gültige Mountinfo-Dokumente verwenden
`MOUNTINFO_PARSED` oder `NO_CGROUP2_MOUNTS`.

`parse_v2_membership` akzeptiert genau einen Datensatz `0::<absoluter Pfad>`.
Die Rückgabe enthält fest `source_key`, `parse_state`, `reason_code`,
`record_count`, `record_ordinal`, `hierarchy_id`, `membership_path`,
`layout_state` und `issue_line_ordinals`. `record_count`, Ordinale und
`hierarchy_id` sind Dezimalzeichenketten. Bei gültiger v2-Mitgliedschaft ist
`hierarchy_id="0"`, `record_ordinal` die ursprüngliche Zeilennummer und
`membership_path` der unveränderte Pfadtext. Zusätzliche Doppelpunkte gehören
zum Pfad; Unicode-Zeichen sowie abschließende Leerzeichen oder CR bleiben
Pfadbestandteil. Nur LF trennt Datensätze. `/` ist gültig, belegt aber keine
globale Wurzel. V1-Controllerlisten akzeptieren normale ASCII-Controllerkennungen
und benannte Hierarchien in der Form `name=<Name>`; der Name muss aus mindestens
einem ASCII-Buchstaben, einer Ziffer, `_`, `.` oder `-` bestehen. V1-only und
gemischte v1/v2-Datensätze ergeben `UNSUPPORTED_LAYOUT`; fehlende v2-Zeilen
ergeben `MISSING_MEMBERSHIP` mit `membership_path=None`. Mehrere v2-Zeilen,
syntaktisch fehlerhafte Datensätze, relative Pfade, NUL sowie `.`- oder
`..`-Pfadkomponenten machen die gesamte Quelle ungültig und liefern keinen
Teilpfad. Ein terminales ` (deleted)` ergibt `DELETED_RECORD` ohne Pfad.
Leere Eingabe bedeutet fehlende Mitgliedschaft; leere Zwischenzeilen werden
ignoriert, während andere nicht interpretierbare Datensätze die gesamte
Quelle ungültig machen. UTF-8-Fehler und Überschreitung der Grenze ergeben
`INVALID_VALUE/NON_UTF8_TEXT` beziehungsweise `LIMIT_REACHED/INPUT_TOO_LARGE`.
Die Hierarchie-ID ist auf unsigned64 begrenzt; ihre Führungsnullen werden nur
im typisierten Zahlenwert kanonisiert.

`parse_cgroup2_mountinfo` liefert fest `source_key`, `parse_state`,
`reason_code`, `record_count`, `mounts`, `selection_state`,
`path_binding_state` und `issue_line_ordinals`. Jeder ausgegebene cgroup2-
Datensatz enthält `source_ordinal`, `mount_id`, `parent_id`, `major`, `minor`,
`root`, `mount_point`, `mount_options`, `super_options` und `filesystem_type`.
Ordinale und IDs sind Dezimalzeichenketten; Mount-, Parent-, Major- und
Minorwerte sind auf unsigned64 begrenzt, Mount- und Parent-ID müssen positiv
sein. Optionen sind geordnete Zeichenkettenlisten. Die 1-basierte
`source_ordinal` verweist auf die
Ursprungszeile. Unbekannte optionale Felder vor `-` werden gemäß
[proc_pid_mountinfo(5)](https://man7.org/linux/man-pages/man5/proc_pid_mountinfo.5.html)
ignoriert. Eine strukturell fehlerhafte Zeile oder doppelte Mount-ID macht die
gesamte Eingabe ungültig und setzt `mounts=None`; aus einem ungültigen Dokument
wird keine Teilauswahl ausgegeben. Nicht-cgroup2-Dateisysteme werden nach
vollständiger Strukturprüfung ausgefiltert. Keine cgroup2-Zeile ergibt
erfolgreich `mounts=[]` mit `selection_state=EMPTY_CGROUP2_SELECTION`, nicht
ein Urteil über die Betriebssystem-Capability.

Root und Mountpunkt dekodieren genau einmal die Mountinfo-Escapes `\\040`,
`\\011`, `\\012` und `\\134` für Leerzeichen, Tabulator, LF und Backslash.
Die dekodierten Pfade bleiben unverändert; insbesondere werden `.`- und
`..`-Segmente nicht normalisiert. `path_binding_state=UNVERIFIED` und
`selection_state=NOT_SELECTED` halten fest, dass die API keine Bindung oder
sichere Mountwahl trifft. Mount-ID-Dubletten werden über alle Dateisystemtypen
hinweg geprüft. Ein fehlender Elternrecord bleibt zulässig, da ein Parent
außerhalb der sichtbaren Prozesswurzel liegen kann. Diese Grenze folgt aus
[proc_pid_mountinfo(5)](https://man7.org/linux/man-pages/man5/proc_pid_mountinfo.5.html)
und der Namespaceansicht in
[cgroup_namespaces(7)](https://man7.org/linux/man-pages/man7/cgroup_namespaces.7.html).
Das Mitgliedschaftsformat `0::<Pfad>` folgt dem
[Kernelvertrag für cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html).
Die Registrierung im bestehenden Runner aktiviert bei dessen Änderung einmalig
den bereits vorhandenen vollständigen statischen Selbsttestsatz. Spätere
Änderungen am Metadatenmodul aktivieren gezielt den fokussierten Validator;
bestehende Gates bleiben unverändert.

### Entwurf des ersten lesenden Reader-Slices

Dieser Abschnitt legt den kleinsten umsetzbaren Readvertrag fest. Er ist noch
nicht implementiert und wird vor Produktcode unabhängig geprüft. Zulässig sind
zunächst ausschließlich Linux x86_64 im little-endian-64-Bit-ABI mit Python
3.11 oder neuer. Zur Laufzeit müssen alle beschriebenen Symbole, Syscalls,
Rückgabemasken und Dateisystemprüfungen vorhanden sein. Eine abweichende
Architektur, Datenordnung, Strukturgröße, fehlende Fähigkeit oder fehlende
Pflichtbits in einer Rückgabemaske ergibt `CONTEXT_UNBOUND` beziehungsweise
`UNSUPPORTED_ABI`; zusätzliche Rückgabebits werden ignoriert. Es gibt keinen `openat`, Stringpräfix-, Pfadauflösungs-,
`/proc/<pid>/root`- oder Namespacewechsel-Fallback.

Der Produktscope umfasst höchstens zwei Module:
`Code/Tools/Linux_Cgroup_Syscalls.py` enthält ausschließlich die begrenzten
Linux-ABI-Bindungen; `Code/Tools/Linux_Cgroup_Reader.py` stellt
`collect_process(target_pid: int) -> dict[str, object]` und die CLI bereit.
Der Reader verwendet ausschließlich die vorhandenen reinen Parser für
Mitgliedschaft, Mountinfo, Ressourcendateien und cgroup.type. Er akzeptiert nur
eine positive, im aufrufenden PID-Namespace sichtbare Prozess-ID. Freie Pfade,
Konfiguration, Remoteziele, Prozesssuche und erhöhte Rechte sind nicht Teil
des Vertrags.

Die Syscall-Bindung ist auf native x86_64 festgelegt. Der Laufzeit-Preflight
verlangt Linux, `platform.machine()=="x86_64"`, `sys.byteorder=="little"`,
acht Byte für `ctypes.c_long` und Zeiger, die genannten Strukturgrößen,
Alignments und Feldoffsets, `os.pidfd_open`, `libc.syscall` und `libc.fstatfs`.
`ctypes.CDLL(None, use_errno=True).syscall` erhält `restype=c_long` und
`argtypes=[c_long]`; seine variadischen Argumente werden für `openat2` als
`c_int dirfd`, `c_char_p path`, Zeiger auf `open_how` und `c_size_t size` und
für `statx` als `c_int dirfd`, `c_char_p path`, `c_int flags`, `c_uint mask`
und Zeiger auf `statx` übergeben. Die Syscallnummer steht jeweils als erstes
`c_long`-Variadicargument 437 beziehungsweise 332. `ctypes.get_errno()` wird
direkt nach einem `-1`-Rückgabewert gelesen. `openat2` verwendet x86_64-Syscall 437
mit `struct open_how` aus drei little-endian `uint64`-Feldern `flags`, `mode`
und `resolve`, Größe 24 und Alignment 8. `statx` verwendet Syscall 332 und
das UAPI-`struct statx`, Größe 256 und Alignment 8. Verwendete Feldoffsets
sind `stx_mask=0`, `stx_mode=28`, `stx_ino=32`, `stx_dev_major=136`,
`stx_dev_minor=140` und `stx_mnt_id=144`. Für FD-Prüfungen wird
`AT_EMPTY_PATH=0x1000` mit leerem Pfad benutzt; angefordert werden genau
`STATX_TYPE | STATX_MODE | STATX_INO | STATX_MNT_ID = 0x1103`. Der Reader
verlangt, dass alle vier Pflichtbits in `stx_mask` zurückkommen. Weitere vom
Kernel gesetzte Bits sind zulässig und werden ignoriert. Fehlt ein Pflichtbit,
scheitert die FD-Bindung fail-closed. `STATX_MNT_ID` ist ab Linux 5.8 verfügbar
und entspricht der Mount-ID im ersten Feld von
`/proc/self/mountinfo`.

`fstatfs(fd, struct statfs *)` wird über `libc.fstatfs` mit
`argtypes=[c_int, POINTER(Statfs)]`, `restype=c_int` und `use_errno=True`
gebunden. `errno` wird unmittelbar nach `-1` erfasst. Die x86_64-Layoutprüfung
verlangt 64-Bit-`long`, `fsblkcnt_t` und `fsfilcnt_t`,
Alignment 8 sowie die UAPI-Reihenfolge `f_type@0`, `f_bsize@8`, `f_blocks@16`,
`f_bfree@24`, `f_bavail@32`, `f_files@40`, `f_ffree@48`, zwei 32-Bit-
`fsid`-Werte ab Offset 56, `f_namelen@64`, `f_frsize@72`, `f_flags@80` und
vier `long`-Reservefelder ab Offset 88; die Größe beträgt 120 Byte. Geprüft
werden nur `f_type`-Werte
`PROC_SUPER_MAGIC=0x9fa0`, `CGROUP2_SUPER_MAGIC=0x63677270` und
`NSFS_MAGIC=0x6e736673`. Diese Werte folgen auch dem [`magic.h`-UAPI](https://github.com/torvalds/linux/blob/master/include/uapi/linux/magic.h). `os.fstat` liefert zusätzlich `st_dev`, `st_ino` und
`st_mode`. Nicht passende Werte oder Strukturprüfungen sperren die Bindung.
Die Strukturen und Masken folgen dem Linux-UAPI für
[`openat2`](https://github.com/torvalds/linux/blob/master/include/uapi/linux/openat2.h),
[`statx`](https://github.com/torvalds/linux/blob/master/include/uapi/linux/stat.h)
und [`statfs`](https://github.com/torvalds/linux/blob/master/include/uapi/asm-generic/statfs.h),
der [x86_64-Syscalltabelle](https://github.com/torvalds/linux/blob/master/arch/x86/entry/syscalls/syscall_64.tbl),
sowie [`statfs(2)`](https://man7.org/linux/man-pages/man2/statfs.2.html).
Die ABI-Definition ist kein Test- oder Nativevidenznachweis.

Der errno-Vertrag legt keine lokalen Fehlertexte offen. `EACCES` und `EPERM`
ergeben `PERMISSION_DENIED`, `ENOENT` bei einer ausgewählten Ressource
`MISSING`, `ELOOP` `SYMLINK_REJECTED`, `EXDEV` `CROSS_MOUNT_REJECTED` und
`EAGAIN` `CONTEXT_UNBOUND`. Ein pidfd-/Procfs-PID-Mismatch verwendet `PIDFD_PROCFS_MISMATCH`. `ENOSYS`, `EINVAL` oder `E2BIG` während eines
ABI-Aufrufs ergeben `UNSUPPORTED_ABI` beziehungsweise `ABI_MISMATCH` und
sperren die Bindung. Andere Fehler werden als `READ_ERROR` für Ressourcen
oder `CONTEXT_UNBOUND` für Fences eingeordnet. Der numerische errno bleibt,
wo verfügbar, allein als Dezimalzeichenkette erhalten; es gibt keinen
automatischen Retry.

Für PID-Liveness wird ausschließlich `os.pidfd_open(target_pid, 0)` verwendet;
Python stellt es ab 3.9 und Linux ab Kernel 5.3 bereit. Ein pollbarer pidfd
wird mit `select.poll` und Timeout null vor und nach dem Zugriff geprüft; `POLLIN`, `POLLHUP`, `POLLERR` oder `POLLNVAL` sperren die Bindung. Da er keine spätere
`/proc/<pid>`-Namensauflösung bindet, öffnet der Reader nach bestätigtem
Procfs-Anker den festen Magiclink `self` zu genau einem Caller-Verzeichnis-FD.
Dieses FD muss weiter `PROC_SUPER_MAGIC` und dieselbe Procfs-Mount-ID haben.
Unter diesem FD wird ausschließlich `fdinfo/<pidfd>` gelesen; dessen
dezimaler `Pid`-Wert muss mit der PID-Spalte der anschließend geöffneten
`/proc/<target_pid>/stat`-Datei übereinstimmen. `0`, `-1`, fehlende oder
zusätzliche `Pid`-Tokens, ein fehlerhafter Wert oder ein
anderer Wert sperren die Bindung. Andere fdinfo-Felder werden ignoriert und nicht geparst. So wird der PID-Namensraum des Procfs nicht
aus der Mountoption oder aus gleichem Dateisystemtyp geraten. Zusätzlich
werden `/proc/<target_pid>/stat`-Startticks vor und nach dem Read verglichen;
pidfd-Liveness, Procfs-PID und Startticks müssen gemeinsam bestehen. `stat`
und pidfd-`fdinfo` sind damit begrenzte zusätzliche Allowlistquellen: Geparst
werden nur PID, Startticks und pidfd-`Pid`; `comm`, andere fdinfo-Felder und
übriger Rohtext werden weder ausgegeben noch geloggt. Der Kernel beschreibt
`Pid` als PID des pidfd-Ziels in der PID-Namespaceansicht der Procfs-Instanz
([pidfd-Kernelimplementierung](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/fs/pidfs.c)). Python dokumentiert
[`os.pidfd_open`](https://docs.python.org/3.11/library/os.html#os.pidfd_open)
und FD-relative Öffnungen; `openat2(2)` hat keinen glibc-Wrapper und verlangt
`syscall(2)` ([Manpage](https://man7.org/linux/man-pages/man2/openat2.2.html)).

Die feste `/proc`-Ankeröffnung erfolgt vom geöffneten Root-Verzeichnis relativ
und ohne Symlink- oder Magiclinkauflösung; `fstatfs` muss Procfs bestätigen.
Danach werden ausschließlich numerische PID-Verzeichnisse und die erlaubten
Dateien unter diesem FD geöffnet. Der Eintrag `/proc/self/mountinfo` wird
relativ zum eng gebundenen Caller-FD gelesen; `statx`-Mount-ID des Procfs-FD und dessen
`PROC_SUPER_MAGIC` müssen einem Procfs-Satz dieses Dokuments entsprechen.
Prozessquellen werden ebenfalls relativ zum geprüften Anker geöffnet und
vor/nach dem Snapshot erneut gebunden. Die eng begrenzte Ausnahme für
`/proc/self` besteht nur aus einem einzelnen `openat` des fest benannten
`self`-Eintrags relativ zum verifizierten Procfs-FD. Der resultierende
Caller-FD muss per `fstatfs` Procfs und per `statx` dieselbe Procfs-Mount-ID
besitzen; jede andere magic-link-Auflösung bleibt gesperrt. Die Mountwahl
nimmt genau einen
cgroup2-Satz, dessen `root` componentweise Präfix des Membership-Pfads ist,
mit dem längsten passenden `root`; Gleichstand, ungültiger Pfad oder fehlender
Satz ergibt `CONTEXT_UNBOUND`. Der relative Blattpfad ist der Membership-
Suffix unter diesem `root`; Punkte und Rücksprünge werden nicht normalisiert,
sondern als ungültig abgewiesen. Für den ausgewählten Mountpunkt wird bei der
Ankeröffnung `openat2` mit
`RESOLVE_BENEATH | RESOLVE_NO_SYMLINKS | RESOLVE_NO_MAGICLINKS` verwendet;
`RESOLVE_NO_XDEV` bleibt dabei absichtlich aus, weil der Weg zum Mountpunkt
den legitimen Mountübertritt enthalten muss. Auf dem geöffneten Anker müssen
`fstatfs` den cgroup-v2-Dateisystemtyp und `statx` die Mount-ID des exakt
ausgewählten Mountinfo-Datensatzes bestätigen. Danach werden Membership und
sichtbare Vorfahren komponentenweise relativ zum cgroup2-FD mit
`RESOLVE_BENEATH | RESOLVE_NO_SYMLINKS | RESOLVE_NO_MAGICLINKS |
RESOLVE_NO_XDEV` geöffnet. Die UAPI-Werte sind `RESOLVE_NO_XDEV=0x01`,
`RESOLVE_NO_MAGICLINKS=0x02`, `RESOLVE_NO_SYMLINKS=0x04` und
`RESOLVE_BENEATH=0x08`; Anker verwenden `O_PATH=0x200000`,
`O_DIRECTORY=0x10000`, `O_CLOEXEC=0x80000`, Ressourcenreads `O_RDONLY=0` und
`O_CLOEXEC`. Jedes Ebenenverzeichnis und jede Ressourcendatei
wird auf Verzeichnistyp beziehungsweise regulären Dateityp, Dateisystemmagie,
Mount-ID, `st_dev` und `st_ino` geprüft. Beim Abschluss werden Membership,
Mountinfo, PID-Startticks, Namespaceidentitäten und Pfad-FD-Identitäten neu
ermittelt und verglichen. Der Vergleich erkennt beobachtete Änderungen,
beweist aber weder Zwischenzustandsfreiheit noch Schutz vor ABA-Wechseln.

Der Namespace-ioctl ist die Linux-Makroauswertung `_IO(0xb7, 0x03)=0xb703`
bei x86_64; `fcntl.ioctl` muss genau einen nichtnegativen Ganzzahltyp
zurückgeben. `CLONE_NEWPID`, `CLONE_NEWNS` und `CLONE_NEWCGROUP` werden nur als
Typ-IDs verglichen, nie als Aufrufrechte verwendet.

Die drei Namespaceeinträge `pid`, `mnt` und `cgroup` sind absichtliche
Procfs-Magiclinks. Sie werden nicht durch eine globale Magiclink-Ausnahme
geöffnet: Erst nach bestätigtem Procfs werden ausschließlich diese festen
Basenames relativ zu dessen sicher geöffnetem `/proc/<pid>/ns`-Verzeichnis
mit `os.open(..., dir_fd=...)` geöffnet. Der zurückgegebene FD muss
`NSFS_MAGIC` haben; `fstat`-Paar `st_dev`/`st_ino` bindet die Identität und
`fcntl.ioctl(fd, NS_GET_NSTYPE)` muss für PID, Mount und cgroup exakt
`CLONE_NEWPID=0x20000000`, `CLONE_NEWNS=0x00020000` und
`CLONE_NEWCGROUP=0x02000000` liefern. `NS_GET_NSTYPE` ist `_IO(0xb7, 0x03)`
(`0xb703`); die Werte folgen dem
[nsfs-UAPI](https://github.com/torvalds/linux/blob/master/include/uapi/linux/nsfs.h)
und [`ioctl_ns(2)`](https://man7.org/linux/man-pages/man2/ioctl_ns.2.html).
Die drei Identitätspaare des Ziels müssen vor und nach dem Read denen des
Aufrufers entsprechen. Unbekannte ioctl-Rückgaben, `ENOTTY`, verweigerte
Zugriffe oder ein Wechsel ergeben `CONTEXT_UNBOUND`. Es erfolgt kein `setns`.
Die begrenzte Ausnahme entspricht der dokumentierten Namespace-FD-Semantik
([`namespaces(7)`](https://man7.org/linux/man-pages/man7/namespaces.7.html)).

Die CLI akzeptiert nur `--target-pid <positive ASCII-Dezimalzahl>` bis
`2147483647`; weitere Optionen gibt es nicht. stdout enthält genau ein
kompaktes JSON-Objekt mit den festen Schlüsseln `schema_version`,
`target_pid`, `target_identity`, `partial`, `global_hierarchy`, `sql_binding`,
`event_scope`, `selection_state`, `context_state`, `resources`,
`hierarchy_metrics` und `issues`. Konstanten sind
`schema_version="linux-cgroup-observation/1"`,
`target_identity="CALLER_SELECTED_PROCESS"`, `partial=true`,
`global_hierarchy="UNVERIFIED"`, `sql_binding="UNVERIFIED"` und
`event_scope="UNVERIFIED"`. Die PID und sämtliche Zahlen sind
Dezimalzeichenketten.

Die `resources`-Liste enthält nur die acht vereinbarten Ressourcen und
`cgroup.type` an den vertraglich ausgewählten Ebenen. Jedes Element enthält
`source_ordinal`, `level_ordinal`, `observation_phase`, `source_key`,
`read_state`, `parse_state`, `reason_code`, `byte_count`, `raw_value`,
`parsed_value`, `native_errno`, `started_at_utc`, `completed_at_utc` und
`duration_ns`. Ordinale, Bytezahlen und Dauer sind Dezimalstrings; Zeitwerte
sind UTC-Texte. `observation_phase` ist `INITIAL_FENCE`, `MAIN_READ` oder
`CLOSING_FENCE`; wiederholte Fence-Reads erhalten eigene Ordinale. Bei nicht
versuchten Quellen sind Bytezahl, Rohwert, Parsewert und errno `null`,
`parse_state=NOT_ATTEMPTED` und `reason_code=null`. `raw_value` enthält nur
vollständig gelesene, begrenzte cgroup-Dateiinhalte einschließlich
`cgroup.type`, nie Procfs-Metadaten. Ein nicht vollständig gelesener Wert
liefert keinen Rohwert und wird nicht geparst.

Readzustände sind `AVAILABLE`, `NOT_SELECTED`, `MISSING`,
`PERMISSION_DENIED`, `READ_ERROR`, `CONTEXT_UNBOUND`, `LIMIT_REACHED` und
`DEADLINE_REACHED`. Erfolgreiche Reads bleiben `AVAILABLE`, auch wenn ein
späterer Fence `context_state=CONTEXT_UNBOUND` ergibt. Parsezustände und
Reason-Codes kommen bei ausgeführtem Parser unverändert aus der vorhandenen
API. `selection_state` ist `SELECTED`, `MISSING_MEMBERSHIP`,
`UNSUPPORTED_LAYOUT`, `AMBIGUOUS_MOUNT` oder `CONTEXT_UNBOUND`;
`context_state` ist `BOUND` oder `CONTEXT_UNBOUND`. `issues`-Elemente enthalten
nur `scope`, `reason_code` und optional `source_ordinal`; Scopes sind
`SELECTION`, `ABI`, `CONTEXT`, `RESOURCE`, `BUDGET` und `OUTPUT`. Stabile
Issue-Codes umfassen `UNSUPPORTED_ABI`, `ABI_MISMATCH`,
`SYSCALL_UNAVAILABLE`, `FILESYSTEM_MISMATCH`, `NAMESPACE_MISMATCH`,
`PID_EXITED`, `STARTTIME_CHANGED`, `MEMBERSHIP_CHANGED`, `MOUNT_CHANGED`,
`PIDFD_PROCFS_MISMATCH`, `DIRECTORY_CHANGED`, `SYMLINK_REJECTED`,
`CROSS_MOUNT_REJECTED`, `PERMISSION_DENIED`, `READ_ERROR`,
`RESOURCE_MISSING`, `LIMIT_REACHED`, `DEADLINE_REACHED` und `OUTPUT_ERROR`;
Parsefehler verwenden die bestehenden Parsercodes. `native_errno` ist nur der
dezimale Zahlencode als String, nie eine Fehlerbeschreibung.

Nicht gelesene oder ungültige Werte erhalten keinen synthetischen Nullwert.
Gebundene Hierarchieableitungen entfallen bei `CONTEXT_UNBOUND`.
`hierarchy_metrics` enthält `visible_memory_max_ceiling_bytes`,
`visible_swap_max_ceiling_bytes` und `visible_cpu_quota_ratio`. Jedes Element
hat `state`, `value` und `source_ordinals`; der CPU-Quotient führt zusätzlich
exakte `ratio_numerator` und `ratio_denominator`. Zustände sind `AVAILABLE`,
`NO_FINITE_VISIBLE_LIMIT` oder `UNAVAILABLE`; Werte, Quotientteile und
Ordinale sind Dezimalzeichenketten. Nicht anwendbare Werte sind `null`; jede
Ableitung nennt ihre Quellordinale.

Exitcode 0 bedeutet, dass ein vollständiges JSON-Ergebnis geschrieben wurde,
auch wenn es partiell oder ungebunden ist; 2 bezeichnet einen ungültigen
CLI-Aufruf, 3 einen Fehler, der ein vertragsgemäßes JSON-Ergebnis verhindert.
stderr enthält ausschließlich stabile Fehlercodes, keine Hostwerte oder
Rohtexte.

Die bestehenden Grenzen gelten unverändert: höchstens 64 sichtbare Ebenen
einschließlich Blatt, 64 KiB je Ressourcendatei, 512 KiB je Procfs-Quelle,
8 MiB Gesamtbudget und zehn Sekunden monotones Budget zur Zulassung weiterer
Reads. Ein bereits blockierter Systemaufruf kann durch das Zeitbudget nicht
garantiert unterbrochen werden. Fehlende Fähigkeiten sperren die Bindung;
erfolgreiche Einzelreads bleiben trotzdem erhalten. Keine Aufnahme ist ein
atomarer Snapshot oder eine Sicherheitsattestierung eines kopierten JSON.

Die Bytezählung umfasst alle tatsächlichen Reads einschließlich Prozess-,
Mount-, Namespace-, Membership-, Starttick-, Konfigurations- und Abschluss-
Fences innerhalb desselben 8-MiB-Gesamtbudgets; Readversuche werden nur
zugelassen, solange sowohl Byte- als auch Zeitbudget verbleiben. Für Procfs-
und cgroup-Pseudodateien wird `fstat`-Dateigröße nicht als EOF-Nachweis
verwendet. Ein positiver Read kann kürzer als die Anfrage sein, ohne das
Dateiende zu beweisen; nur ein tatsächlicher Null-Byte-Read zählt als EOF.
Erreicht die Bytezahl exakt das 64-KiB-, 512-KiB- oder verbleibende
Gesamtlimit, wird kein zusätzlicher Probe-Read ausgelöst. Ohne bereits
beobachtetes EOF erhält die Quelle `LIMIT_REACHED`, keinen Rohwert und keinen
Parseversuch. Diese Regel hält den Höchstwert auch dann ein, wenn der
Dateiinhalt exakt am Cap endet.

Die spätere Abnahme benötigt portable feste Parser- und Wire-Oracles sowie
einen getrennten Job im bestehenden
[`ci-functional-impact.yml`](../../../.github/workflows/ci-functional-impact.yml)
ohne Abhängigkeit zum SQL-Server-Job und ohne SQL-Instanzstart. Geänderte
Reader-/Syscallmodule und deren Validator aktivieren diesen Job. Sein
Linux-x86_64-/Python-3.11-Preflight schlägt fehl statt die Laufzeitfälle zu
überspringen, wenn Kernel, ABI oder Syscalls nicht verfügbar sind. Auf dem
Runner werden tatsächliche `openat2`,
`statx`, `fstatfs`, Namespace-FD- und pidfd-Aufrufe mit einem eigenen
Kindprozess und dessen bestehender cgroup geprüft. Temporäre synthetische
Verzeichnisfixtures prüfen Races, Symlinkablehnung, erlaubten Mountanker,
verbotene Folgemounts soweit ohne Privilegien herstellbar, Permissionfehler,
eine Rückgabemaske mit allen vier Pflichtbits plus zusätzlichen gesetzten Bits
als Erfolg sowie das Fehlen jedes einzelnen Pflichtbits als fail-closed,
EOF knapp unter und genau am Datei-/Gesamtcap ohne zusätzliche Probe-Reads,
gemeinsame Zählung von Vor-/Nachher-Fences, Read-/Byte-/Zeitbudget und Cleanup.
Injizierte ABI-, Namespace-, PID-,
Starttick-, Mount-ID- und Directory-ID-Abweichungen müssen fail-closed enden;
ein CI-Preflight für die festgelegte Architektur überspringt diese Fälle nicht.
Das kompakte Laufprotokoll enthält nur Prüf-Codes und Fallzahlen. Kein solcher
Fixture- oder Prozesslauf qualifiziert eine kontrolliert gesetzte native
cgroup-Grenze oder deren Wirkung auf SQL Server; dieser positive
Linux-/SQL-Nachweis bleibt separat offen.

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
