# Linux-cgroup-Ressourcen: begrenzter externer Beobachtungsvertrag

**Status:** Ressourcen-, Parser- und Reader-Verträge sind dokumentiert; Native-Primitiven und Reader liegen als PR-Kandidat vor. Unabhängiger Reader-Review und Linux-Native-CI stehen aus. Eine Host- oder cgroup-Grenzqualifikation liegt nicht vor.
**Artefakt-UID:** `urn:uuid:01a17804-0079-7079-9643-0c639808a4ff`.
**Registrierung:** `DEFERRED`; keine finale lesbare Arbeitselementkennung vergeben.
**Stand:** 26. Oktober 2026.

## Zweck und erster Lieferumfang

Rang 11 der [Entwicklungsplanung](../Quality/Development_Waves_2026-10.md)
trennt SQL-sichtbare Upgradehinweise von Linux-Ressourcengrenzen. Dieser
Vertrag bereitet einen extern gestarteten, lesenden cgroup-v2-Reader vor.
Er beobachtet genau einen ausdrücklich ausgewählten Prozess und dessen
sichtbare cgroup-Hierarchie. Der aktuelle Reader-Kandidat benötigt unabhängigen
Review und den ausgewiesenen Linux-Native-CI-Lauf.

`monitor.USP_OSInformation` bleibt für SQL-sichtbare Host-, Prozessspeicher-
und Dienstinformationen zuständig. Ein späterer Collector ergänzt diese
Beobachtung außerhalb der Engine. Ein SQL-Importer, eine Datenbankinstallation,
automatische Korrelation mit einer SQL-Instanz sowie eine dauerhafte Erfassung
gehören nicht zum ersten Reader. Der gemeinsame Wire- und ABI-Vertrag
steht in der öffentlichen Readerspezifikation. Dieses Dossier ist über
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
Der gemeinsame JSON-, CLI- und Native-ABI-Vertrag ist in der öffentlichen
[Readerspezifikation](../../../Documentation/Analysis_Guides/Linux_Cgroup_Reader_Contract.md)
kanonisch beschrieben.

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

Diese APIs bleiben reine Parser und sind kein Dateizugriffsadapter. Ihre
getrennte Collectorimplementierung ist in der Readerspezifikation begrenzt.
SQL-Import und native Hostqualifikation bleiben offen.
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

### Reader-Vertrag und aktueller Kandidatenstatus

Der gemeinsame Wire- und Native-ABI-Vertrag ist in der öffentlichen
[Linux-cgroup-Reader-Spezifikation](../../../Documentation/Analysis_Guides/Linux_Cgroup_Reader_Contract.md)
kanonisch festgelegt. Die vorangehenden Abschnitte dieses Dossiers bleiben für
fachliche Quellsemantik, sichtbare Hierarchie, Datenschutz und Aussagegrenzen
maßgeblich. Die öffentliche [Betriebsanleitung](../../../Documentation/Analysis_Guides/Linux_Cgroup_Reader.md)
beschreibt Voraussetzungen und Aufruf.

`Code/Tools/Linux_Cgroup_Native.py` enthält die begrenzten x86_64-Primitiven.
`Code/Tools/Linux_Cgroup_Reader.py` und sein fokussierter Validator sind im
Arbeitsstand als Kandidat umgesetzt. Die portablen Phase-A- und Reader-Oracles
laufen lokal; eine Linux-Nativeausführung wurde hier nicht vorgenommen. Die
getrennte Linux-x86_64-/Python-3.11-CI muss die ABI-/Syscallprüfungen und die
read-only Beobachtung eines eigenen Kindprozesses tatsächlich ausführen; ein
Unsupported-Ergebnis gilt nicht als Erfolg. Unabhängiger Review, dieser CI-Lauf
und danach die erforderlichen PR-Gates stehen noch aus.

Der Kandidat behauptet keine Hostqualifikation, keine konfigurierte
cgroup-Grenzwirkung und keinen SQL-Prozessbezug. SQL-Import, kontrollierte
cgroup-Limitwirkung, globale Hierarchievollständigkeit und SQL-Instanzbindung
bleiben getrennte offene Evidenzgrenzen. Die Native-CI ist auf Änderungen an
Reader, Native-Primitiven, Parserabhängigkeiten, Validator und diesem Vertrag
begrenzt; sie startet keinen SQL-Server. Die Integration in den bestehenden
statischen Runner aktiviert dessen vollständige Selbsttests. Diese notwendige
einmalige Runnergrenze wird nicht durch Verengung bestehender Gates umgangen.
