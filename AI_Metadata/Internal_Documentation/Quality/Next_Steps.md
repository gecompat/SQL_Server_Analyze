# Nächste Arbeitsschritte

**Stand:** 8. November 2026  
**Zweck:** aktueller Auftragsstatus und Einstieg in die erhaltene Entwicklungshistorie für `gecompat/SQL_Server_Analyze`.

## Aktuelle Orchestrierung

Die [Entwicklungsplanung](Development_Waves_2026-10.md) ist die einzige maßgebliche Quelle für Reihenfolge, Zuständigkeit und nächste ausführbare Welle. Dieser kurze Einstieg hält den aktuellen Stand, seine Evidenzgrenzen und die wichtigsten Fortsetzungsregeln fest. Abgeschlossene Planungs- und Ausführungsnachweise bleiben im [Historienarchiv](Next_Steps_History_2026-11-05.md).

<a id="nächste-ausführbare-welle-wirksamer-ssis-locktimeout"></a>
## Nächste ausführbare Welle: SSIS-Locktimeoutvertrag und Wrapperkompatibilität

PR #646 ist einschließlich Main-Nachprüfung abgeschlossen. Der qualifizierte Main-Stand ist `67d317897b01db91ec994343e8ae1bbfc332398f`, Baum `a23d9f285c45afc3a7574dfb4b42d82674fe0ce7`; der integrierte Head lautet `d412d021c6c2c279910414f1f60933ac882a0435`. Head [42410463597](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/42410463597) und Main [42413132789](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/42413132789) bestanden den gewählten SQL-Server-2025-Umfang 124, 110, 196, 198 und 200 bei Compatibility Level 170. Main bestand außerdem 80 statische Prüfungen mit kanonischer Neuerzeugung und Vergleich beider OPS-Installer, 18 Cleanup-Szenarien und StopSynthetic. Permission-, Regex- und Execution-Plan-Standalone-Prüfungen waren nicht ausgewählt. Der konfigurierte Übergang `ready_for_review` löste zusätzlich Registry [42411858545](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/42411858545) und den gleichen SQL-Umfang [42411858570](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/42411858570) aus; beide bestanden. Dieser zusätzliche Ausführungseffekt wird nicht als neuer Quellstand oder manueller Wiederlauf dargestellt. Ein vorheriger Mergeversuch wurde mit 405 und `registry-integrity expected` abgelehnt; nach den erfolgreichen Ready-Gates erfolgte der reguläre Merge. Eine unabhängige Container-Abwesenheitsprobe wurde nicht ausgeführt.

Der vorbereitete Abschluss von PR #647 berichtigt den Hilfevertrag. `@LockTimeoutMs` bleibt ein `int` mit Default 0 und zulässigem Bereich 0 bis 60000; NULL und Werte außerhalb des Bereichs bleiben ungültig. Der Parameter wird derzeit nur validiert und steuert die Sperrwartezeit der nachfolgenden Analyse nicht. Deren direkte Arbeit erbt die Einstellung des Aufrufers. Die gemeinsamen TABLE-Helfer behalten ihre eigenen Regeln: Für ihre anfängliche eigene Temp-DDL wird ein eingehender Wert 0 auf 1000 ms angehoben, andere Werte bleiben dort erhalten; Zieloperationen verwenden danach NOWAIT. Eine neue wirksame Timeout-Steuerung wird mit diesem Nachtrag ausdrücklich nicht geliefert.

Der noch nicht integrierte Selbstaufrufentwurf wird zurückgenommen. Im nativen Lauf [42480571828](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/42480571828) scheiterte das eingeschränkte Wrapper-Szenario mit Fehler 229 auf `monitor.USP_SsisPackageAnalysis`. Die genaue erste statische oder innere dynamische Aufrufstelle wurde nicht erfasst. Daher werden weder eine bestimmte Fehlerstelle noch zusätzliche notwendige Aufruferrechte behauptet. Die bereits bestandenen Timeout-Beobachtungen des verworfenen Entwurfs sind keine Eigenschaft des jetzt vorbereiteten unveränderten Main-Ausführungsverhaltens.

Quelle `266f6e0e707c07ad143d26cd86258faa58aed1f4` entspricht nach Rücknahme des einen Hilfesatzblocks und des erläuternden Kommentars exakt der qualifizierten Main-Quelle `8829f0f21626396b8eac46f0c199c8eec3895ae8`. Alle übrigen Anweisungen, Parameter, Status-/Fehler- und JSON-Verträge bleiben identisch. Referenz `7a838b6663dbd87c842077f96c23c37707fd659a` beschreibt die Einschränkung. Test `8fa5d859aca96fa0feaadb6c839faa26b431d86e` bewahrt die bisherigen öffentlichen Eingabe-, Ausgabe-, Dauer- und Caller-Prüfungen. Die nur zum zurückgenommenen Feature gehörende instrumentierte Prozedurkopie entfällt; sie wird nicht als Timingnachweis umgedeutet. Der strenge Wrapper-Test mit ausdrücklicher DENY-Regel, effektiver Berechtigungsprüfung, Identitäts-, OUTPUT-, RETURN-, Caller- und Bereinigungsprüfung bleibt als Kompatibilitätsbedingung erhalten. Sein Erfolg ist noch nativ zu qualifizieren und bleibt Voraussetzung für die Integration.

Der kanonische Remote-Lauf [42495116562](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/42495116562), Job `128775703528`, hat den OPS-Installer erfolgreich erzeugt und übertragen: Git-Blob-SHA `77e4dfe1ab2e03fcd926bd822ee1b166ad052747`, 6.516.316 Bytes. Vor den beiden Blob-Uploads wurden die vollständige unabhängige Modulableitung, der unveränderte Installerrest, die kanonische Bytegleichheit und die unveränderte Update-Datei geprüft. Das tatsächliche Installer-Readback entspricht der unabhängig abgeleiteten vollständigen Datei. Das Reviewenvelope ist an Blob `23d2a08228f3381fc882ffa6ea25f22105367e98` gebunden. Die zuvor gescheiterten direkten API-Übertragungen mit HTTP 500 bleiben getrennte Transporthistorie.

Der Übertragungscommit `7c4c11ad7f59f3728c7c224aebce5c45fb1a0262` bindet Main `67d317897b01db91ec994343e8ae1bbfc332398f`, die Quelle und beide unveränderten Builder. Der Lauf startete keine SQL-Instanz. Nach seinem Abschluss wurde der Hilfsbranch regulär mit `2c9f2df0effbe04aca1978cb3a4c7bcae86395cd` auf den ursprünglichen Baum `4df10207a1a5d94703a49257d1e24670b0211664` zurückgestellt. Der Produktstand enthält keine Workflowänderung.

Der vollständige Produktkandidat enthält den bestätigten Installer. Die erforderlichen Head-Gates und Cleanup sowie nach regulärem Merge die erste Main-Nachprüfung stehen noch aus. Der eingeschränkte Wrapper-Pfad bleibt bis zu seiner nativen Abnahme unqualifiziert und sperrt bei Fehler die Integration. Die bereits bereite PR erhält keinen weiteren Ready-Übergang. Datenschutzregel und Allowlist bleiben unverändert. Frühere Locktimeout-Ursachen bleiben unbekannt; eine unabhängige Gzip-Dekompression oder Container-Abwesenheitsprobe wird nicht behauptet.

Die erhaltenen Zwischenstände und ausführlichen Evidenzgrenzen stehen in der [Entwicklungsplanung](Development_Waves_2026-10.md#ausführungsnachweise-des-zurückgenommenen-entwurfs).

## NULL-Guards der internen Plananalyse

PR #640 ist einschließlich der erforderlichen Head- und Main-Gates, der nativen SQL-Server-2025- und Standalone-Verträge sowie Cleanup integriert. PR #641 ist ebenfalls integriert; der Functional-Impact-Lauf auf dem Head [42292955050](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/42292955050) und der Main-Lauf [42295380748](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/42295380748) sind erfolgreich. PR #642 ist integriert; der Head-Lauf [42302810282](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/42302810282) und der Main-Lauf [42304333989](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/42304333989) sind ebenfalls erfolgreich. PR #643 hat auch die öffentliche Quellbestätigung integriert; der Head-Lauf [42312237331](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/42312237331) und der Main-Lauf [42313478992](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/42313478992) sind erfolgreich.

Die fachliche Prüfung belegt sechs fehlende NULL-Ablehnungen. InternalCollectExecutionPlanMetadata weist NULL für QuellumgebungBestaetigt, MitPredicateHistogramMap und HighImpactConfirmed jetzt vor seinen Temp-Tabellenprüfungen als INVALID_PARAMETER zurück. InternalAnalyzeExecutionPlan lehnt NULL für PlanSource, RuntimeCounterScope und MitThreadRuntime vor Profilzugriff und Temp-Tabellenprüfungen ab. Insbesondere darf ein fehlender Thread-Schalter nicht entgegen dem Default 0 Threadzeilen erhalten. Die absichtlichen NULL-Fallbacks für Modi und die optionalen Kontextwerte bleiben erhalten; der ausdrückliche Scope UNKNOWN bleibt gültig.

Die [Entwicklungsplanung](Development_Waves_2026-10.md#null-guards-der-internen-plananalyse) bindet die Quellen, die Verhaltenstests und die Grenzen der öffentlichen Aufrufer. Die öffentliche Datenschutzkorrektur ist mit PR #641 integriert; der Head- und Main-Lauf sind oben verlinkt. Nicht-sensitive NULL-Aufrufe und absichtliche Modus-/Kontextfallbacks bleiben erhalten.

PR #643 schloss die Quellbestätigung für `CURRENT_SERVER` in 052 und 053: unabhängig von einer tatsächlichen Erhebung erfordern die öffentlichen Aufrufer 1; 0 und NULL führen zu `SOURCE_ENVIRONMENT_CONFIRMATION_REQUIRED`. 1 ist die Bestätigung des Aufrufers, kein Herkunftsnachweis und keine Berechtigung. Die integrierten Quellen sind an 052 Blob `755f786adcffd42e3b79ee34ff8f77d3acb6eeb5` und 053 Blob `3e0cbf8ad99d9b9d4c2235aee575c0383c433f4e` gebunden. `MitPredicateHistogramMap` bleibt kontextabhängig: ohne Collector-Aufruf, etwa bei `EVIDENCE_ONLY`, ist NULL unbenutzt; bei tatsächlicher Erhebung weist 049 NULL zurück und die öffentliche Evidenzverarbeitung meldet `CURRENT_METADATA_COLLECTION_LIMITED` mit Teilstatus.

PR #644 hat die öffentliche `@MitThreadRuntime`-NULL-Prüfung integriert. Head [42319073840](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/42319073840) und Main [42320804141](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/42320804141) bestanden; nativer Vertrag 120, Standalone-Vertrag 193, 80 statische Prüfungen, 18 Cleanup-Prüfungen und der synthetische SQL-Server-Stop-Vertrag bestanden ebenfalls. Der unabhängige Container-Abwesenheitsnachweis wurde nicht ausgeführt. Die frühe Prüfung verhindert den zuvor beobachteten `MitThreadRuntime`-NULL-Fehler; `MitPredicateHistogramMap=NULL` bleibt im unbenutzten `EVIDENCE_ONLY`-Pfad absichtlich gültig.

## SSIS-LockTimeoutMs-Prüfung integriert

PR #645 ist nach Review und den erforderlichen Remote-Prüfungen in Main integriert. Der integrierte Stand ist an Main-Commit `5c3cc4ef7c22d19d219f08d0565cb6dacecb1ce2` und Tree `7e873ad4ca929eb7bd7fe634dd3d418033f407bc` gebunden; der integrierte PR-Head ist `d0942dca4ee5a3669b9b7a8c605db36c85d3ffba`. Die Procedure behält Blob `0c90dc38570240449e299e9b4d2a82e3ee89493f`; der abschließende Laufzeitvertrag 200 ist Blob `972f6ecd282b55676a9ed3cb94089c8f2c31f018`, und der Diagnose-Test ist Blob `436c3049fdcfa998f062e9ef927255a60b765fcc`. Main-Lauf `42357569666`, Versuch 2, bestand Deployment, Full Core, Permission-, Regex- und Standalone-Prüfungen. Die unveränderten statischen 80 Prüfungen und 18 Cleanup-Prüfungen blieben erfolgreich. Der PR-only-Python-Lauf und die Probe wurden nicht erneut auf Main ausgeführt; ein unabhängiger Container-Abwesenheitsnachweis liegt nicht vor.

Der frühere PR-645-Kandidatenlauf scheiterte vor Laufzeitvertrag 200 in der Deploymentphase: `SnapshotSchema` meldete 53908 bei Stage 0; anschließend trat SQL-Fehler 1222 in Zeile 982 auf. Die Ursache bleibt unbekannt. Der vollständige Diagnosebericht meldete `BNC` und `errors=[]`; die separate 16-KiB-Konsolenzusammenfassung endete mit `ARTIFACT_SIZE_LIMIT`, `truncated=true` und `samples=[]`. Diese Ausgabe belegt weder einen beobachteten Blocker noch einen fehlenden Blocker. Auch der frühere Main-Fehler `202C009` mit TABLE 51010 und `LOCK_TIMEOUT` bleibt ungeklärt. Versuch 2 reproduzierte ihn nicht und klärte seine Ursache nicht. Ein früherer Snapshotlauf meldete ebenfalls 53908 und 1222; seine Ursache bleibt unbekannt. Es liegt kein unabhängiger Container-Abwesenheitsnachweis vor.

<a id="nächste-ausführbare-welle-ssis-maxdurationseconds-null-abweisung-schritt-212"></a>

## Abgeschlossener Verlauf: SSIS-MaxDurationSeconds und JSON-Paketarray

Die folgenden Zwischenstände sind historische Entwicklungsnachweise vor dem oben bezeichneten vollständigen PR-646-Abschluss; sie sind keine aktuelle Fortsetzungsfreigabe.

Der Ausgangsstand vor PR #646 ließ `@MaxDurationSeconds = NULL` durch die Bereichsprüfung passieren, weil `NOT BETWEEN 1 AND 60` bei NULL den Wert UNKNOWN liefert. Die Procedure verwendet den Parameter danach nicht für eine Frist, einen Abbruch oder eine Laufzeitbegrenzung. Schritt 212 ergänzt deshalb nur die explizite NULL-Abweisung, präzisiert den individuellen Hilfe- und Referenzvertrag und erweitert Laufzeitvertrag 200. Die Abnahme prüft NULL, 0, -1, 61, beide `int`-Grenzwerte sowie Leertext (SQL-int-Konvertierung zu 0) als `INVALID_PARAMETER` ohne Paketinventar, 1, 30 und 60 sowie den ausgelassenen Default mit nichtleerem synthetischem Paketinventar, OUTPUT-Statuswerte und Erhalt des Caller-`@@LOCK_TIMEOUT`. Der Schritt führt keine tatsächliche Zeitbegrenzung ein.

PR 646, Head `6fcfe209f36c07d2c960d306c017cca9b18fff14`, führte den ersten Step-212-Kandidaten aus. Deployment, statische 80 Prüfungen und 18 Cleanup-Prüfungen bestanden; der Laufzeitvertrag meldete SQL-Fehler 56120 in Test 200 bei der Prüfung des Caller-`@@LOCK_TIMEOUT`. Die Diagnose meldete `NO_1222`, `SQLCMD=1`, null Observerfehler und `truncated=false`.

Die erste Harness-Korrektur wurde auf Head `955629b7aa9b22a0dc96a9671bd62396d4297bbf` mit Lauf 42392415649 geprüft. Deployment, statische 80 Prüfungen, 18 Cleanup-Prüfungen und Stop-Prüfung bestanden; Laufzeitvertrag 200 scheiterte mit 56121 in Zeile 76, `invalid MaxDurationSeconds raised an unexpected SQL exception`. Die Testfassung wandelte den unerwarteten Fehler in ein Flag um, daher enthält der Lauf keinen ursprünglichen SQL-Fehlercode und belegt nicht, dass die übrigen Dauerfälle bestanden. Als source-basierte Setup-Ursache kommt die Wiederverwendung des durch den ersten TABLE-Aufruf schemaerweiterten `#ssisPackage`-Ziels infrage: `TRUNCATE` setzt die Seed-Spalte nicht zurück, während `InternalPrepareResultTables` für jeden TABLE-Aufruf ein leeres Ziel mit genau einer Seed-Spalte verlangt (Helper-Blob `ce2fec7f2291fadb294e6aab6ed8125a91715ab2`). Ein Fehler 51011 wurde im Lauf nicht gemeldet.

Der damalige Diagnose-Nachtrag wurde mit Commit `5fd090fde7b62b3602f73913c6c95b6b8603daee` in PR #646 veröffentlicht und ist an Test-Blob `6f8591f0855775e2bbb1d0707c89dde17cb61ea6` gebunden. Er teilt die zuvor kombinierte Fehlermeldung in vier feste Fehlercodes für OUTPUT-Status, Caller-`@@LOCK_TIMEOUT`, TABLE-Inventar und JSON-Paketarray auf. Die Meldungen enthalten ausschließlich den synthetischen Schleifendurchlauf, die feste Prüfkategorie und das zugehörige synthetische Ziel. Alle bisherigen Bedingungen, ihre Reihenfolge, elf Seed-Ziele, Fehler-CATCHes, gültigen Dauerfälle und äußeren Timeout-Prüfungen bleiben erhalten. Der dynamische Batch hat ein geschlossenes Zeichenfolgenliteral; diese Quellenprüfung belegt keine native Laufzeitqualifikation.

Der weitere Lauf 42397206149 am Head `9ef3e0bc39ce92ee03d5194665af750466f0ed3a` bestand Deployment, die 80 statischen Prüfungen, 18 Cleanup-Prüfungen und StopSynthetic, scheiterte aber im dynamischen Testbatch mit SQL-Fehler 105 in Zeile 158 wegen einer nicht geschlossenen Zeichenfolge. Der damalige Test-Blob `e544adc4ddf7bf371156b502fc14e401f32d17c0` enthielt am Ende des äußeren Literals ein zusätzlich maskiertes Apostroph; dadurch endete der ausgeführte Batch mit einem offenen Zeichenfolgenliteral. Dieser Lauf qualifiziert keine der darin enthaltenen LockTimeout- oder Dauerprüfungen. Der neue Testkandidat `4dbca1b744c31a681bedbbfa0198a811744007bc` korrigiert ausschließlich diese Abschlusszeile; nach dem Entpacken bleibt der fachliche Batch bis auf das entfernte Schlussapostroph identisch. Eine deterministische Zeichenfolgenprüfung ersetzt keine native SQL-Abnahme. Produktquelle, Installer, Laufzeitgrenzen und sämtliche fachlichen Testoracles bleiben unverändert; Review und erneute Remote-CI stehen aus.

Der fünfte Lauf `42399231612` auf Head `f2833f06508f03bfbba1320bccfa228490c84785` bestand Deployment, 80 statische Prüfungen, 18 Cleanup-Prüfungen und StopSynthetic. Laufzeitvertrag 200 scheiterte mit SQL-Fehler 56121 in Zeile 95 an der kombinierten MaxDurationSeconds-Assertion. Der Lauf weist weder die einzelne fehlschlagende Bedingung noch den Durchlauf aus und qualifiziert daher keine übrigen Dauerfälle. Die aktuelle Produktquelle `68fd38a3c55903e0d1de226a1febba8fcff2d7b3` enthält eine ausdrückliche NULL-Abweisung; die Quellenprüfung identifiziert keinen deterministischen Produkt- oder Erwartungsfehler. Der Diagnoseentwurf grenzt diese Mehrdeutigkeit ein, ohne einen Fehler in PASS umzuwandeln. Der veröffentlichte Diagnose-Nachtrag grenzt diese Mehrdeutigkeit ein; eine erfolgreiche neue Runtimequalifikation steht weiterhin aus.

Der Functional-Impact-Lauf [42401870972](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/42401870972) am Diagnose-Head `5fd090fde7b62b3602f73913c6c95b6b8603daee` wurde abgebrochen. Der Runtimejob endete als `cancelled`; der Schritt `Stop synthetic SQL Server` war erfolgreich. Die statischen Gates desselben Heads sind erfolgreich. Daraus entstehen weder eine bestandene Runtimequalifikation noch ein unabhängiger Nachweis der Containerabwesenheit. Der damalige Planungsabgleich änderte nur diese beiden Statusseiten; Test-Blob `6f8591f0855775e2bbb1d0707c89dde17cb61ea6`, Produktquelle `68fd38a3c55903e0d1de226a1febba8fcff2d7b3` und OPS-Installer `bd557bf96c89a74052f9c35fa060f273c91e0b3d` bleiben unverändert. Unabhängiger Review sowie erfolgreiche erforderliche Head- und Main-Gates bleiben Voraussetzung der Integration.

Der Lauf [42404276949](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/42404276949) am Head `354f36c0f395d2856e27d8712979e3d7c5d21b28` bestand Deployment, 80 statische Prüfungen, 18 Cleanup-Szenarien und StopSynthetic. Im ersten Dauerfall (`MaxDurationSeconds=NULL`) bestanden OUTPUT-Status, Caller-`@@LOCK_TIMEOUT` und leere TABLE-Ziele. Die JSON-Paketprüfung scheiterte mit 56214 in dynamischer Zeile 111. Der tatsächliche JSON-Wert wurde nicht erfasst; die genaue Ausgabeabweichung und ihre Ursache sind deshalb weiterhin unbekannt. Spätere Dauerfälle sind durch diesen Lauf nicht qualifiziert.

Der begrenzte Nachtrag prüft den fachlichen JSON-Vertrag statt einer exakten Zeichenfolge: Das Wurzel-JSON muss gültig sein und genau einen Schlüssel `package` mit Arraytyp und ohne Elemente enthalten. Zwölf synthetische Gegen- und Kontrollfälle prüfen leere Arrays mit und ohne Zwischenraum sowie NULL, fehlende oder doppelte Schlüssel, abweichende Großschreibung, JSON-null, String, Objekt, nichtleere Arrays und ungültigen JSON-Text. Die Umsetzung verwendet den vorhandenen `OPENJSON`-Typvertrag und benötigt keine neue native Engine oder die erst später eingeführte zweite `ISJSON`-Parameterform. Bei erneutem Fehler meldet der Test nur Gültigkeit, Schlüsselanzahl, Typ und Arraylänge in Bytes; Paketdaten werden nicht protokolliert. Nach erfolgreicher semantischer Prüfung gibt der erste NULL-Fall dieselben Formmerkmale sowie Länge und NULL-Kennzeichen der bisherigen JSON_QUERY-Extraktion und deren Vergleichsflag aus; diese begrenzte Formevidenz soll eine Format- oder Extraktionsabweichung unterscheiden. Test-Blob `c799fd32da3f06df91b696918901f2bd75b35fe6` bewahrt die übrigen Status-, TABLE-, Caller-, Fehler- und positiven Dauerprüfungen. Produktquelle, Guide und beide Installer bleiben unverändert. Eine Formatierungsursache wird nicht als beobachtet behauptet. Unabhängiger Review sowie die erforderlichen Head- und Main-Gates stehen für diesen Nachtrag aus.

Der anschließende Lauf [42406326297](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/42406326297) am Head `eb39163b312f11a0cc2d17df186d2cf4b9fb7142` bestand Deployment, 80 statische Prüfungen, 18 Cleanup-Szenarien und StopSynthetic. Die zwölf synthetischen Formkontrollen erzeugten keinen Fehler. Im ersten NULL-Dauerfall meldete die semantische Prüfung erneut 56214, nun in dynamischer Zeile 139: `JsonValid=1; PackageKeys=0; PackageType=-1`. Das Dokument ist damit gültiges JSON, enthält aber keinen case-sensitiven Wurzelschlüssel `package`. Dies ist keine bloße Leerzeichenabweichung. Die vorhergehenden Status-, Caller- und leeren TABLE-Prüfungen bestanden für diesen Fall; spätere Dauerfälle bleiben unqualifiziert.

Die begrenzte Produktkorrektur ergänzt in der bestehenden Paketserialisierung `COALESCE(...,N'[]')` vor `JSON_QUERY`. Ein SQL-NULL der inneren Paketserialisierung erhält damit ein explizites leeres Array, während vorhandene Paketdaten unverändert serialisiert werden. Der bereits verwendete Fallback des Variablenarrays bleibt unverändert. Der fehlende Schlüssel ist beobachtet; eine darüber hinausgehende Engineursache wird nicht behauptet. Die Quellenkorrektur ist an Blob `8829f0f21626396b8eac46f0c199c8eec3895ae8` gebunden. Eingebaute Hilfe und Referenz nennen das leere Paketarray ausdrücklich. Der abgeleitete OPS-Installer `26a0be1f7fa34daecfaf452fcbe5629312dd07f7` enthält genau den ersetzten vollständigen Paketmodultext; sein übriger Inhalt und update.sql bleiben unverändert. Die bestehende statische OPS-Prüfung erzeugt den kanonischen Installer remote erneut und vergleicht ihn. Produktkorrektur und Installer sind noch nicht durch einen neuen Lauf qualifiziert. Der semantische Test samt negativen Gegenfällen bleibt unverändert; unabhängiger Review und erforderliche Head- und Main-Gates stehen für diesen Produktnachtrag aus.

## Phasenbezogene File-IO-Fehlerausgänge

Die beiden File-IO-Fehlerausgänge sind in ihren Einzelparameterverträgen nach Prüfphase und Finalisierungspfad beschrieben. Sourcefehler können nach validierter Source auch bei einem Backendfehler einschließlich NULL oder Leertext erhalten bleiben; ein Fehler der inneren Finalisierung kann stattdessen seine eigene Diagnose ausgeben. Die SQL-Logik des Helpers bleibt unverändert; seine kommentarabhängige Fingerprintbindung im abgeleiteten Snapshot-Preflight ist nachgeführt. Die [Entwicklungsplanung](Development_Waves_2026-10.md#phasenbezogene-file-io-fehlerausgänge) bindet den Quellstand und hält die verbleibenden Evidenzgrenzen fest. Die erforderlichen Review- und Remote-Gates bleiben Voraussetzung für die Integration.

Die damals folgende fachliche NULL-Guard-Prüfung ist im aktuellen Abschnitt abgegrenzt; die öffentlichen Bestätigungs- und Datenschutzgrenzen bleiben ein eigener Folgeschritt. Fehlende Plattform- und Transaktionsevidenz bleibt ausdrücklich unbelegt.

## Snapshot-Target-Diagnose 53781

Fehler 53781 nennt nun das vom FILE_IO-Guard tatsächlich verlangte Target 1.3.1 mit Schema 3. Fehlernummer, Status und Guard bleiben unverändert; DDL-Kommentar und Objektreferenz sind abgeglichen. Die [Entwicklungsplanung](Development_Waves_2026-10.md#snapshot-target-diagnose-53781) bindet den neuen Quellstand und trennt ihn vom historischen Blobnachweis. Die erforderlichen Remote-Gates bleiben Voraussetzung für die Integration.

Die damals folgenden File-IO-Einzelverträge sind im aktuellen Abschnitt präzisiert. Die nachfolgende NULL-Guard-Prüfung steht im aktuellen Abschnitt; nicht vorhandene Plattform- und Transaktionsevidenz wird nicht als erbracht behandelt.

## SSIS-Referenzabgleich vom 6. November 2026

Der ergänzende Abgleich beschreibt alle vier zuvor offenen SSIS-Helfer mit zusammen 42 Einzelparameterverträgen. Die bezeichnete interne Kohorte umfasst damit 25 Prozeduren mit 238 Parametern; beim SSIS-Abgleich waren die bisherigen 21 Quell-Blobs und das gebundene Inventar unverändert. PR #635 und PR #636 sind einschließlich Main-Nachprüfung integriert. Die vorliegende Änderung ergänzt InternalSsisExecutionMetrics; Review und erforderliche CI-Gates bleiben die Integrationsbedingung. Es handelt sich um einen begrenzten Kommentar- und Referenzabgleich, keine allgemeine Laufzeitqualifikation. Die öffentliche Kohorte und die Nichtprozedurkohorte behalten ihre separat bezeichneten Evidenzgrenzen.

Die [Entwicklungsplanung](Development_Waves_2026-10.md#ssis-referenzabgleich-vom-6-november-2026) bindet die vier Quellen und hielt die damals belegten Lücken fest: Snapshot-Diagnosetext 53781, phasenbezogene Fehlerausgänge bei File-IO sowie die getrennte fachliche Prüfung dokumentierter NULL-Guard-Verhaltensweisen. Fehlende Windows-/Mirroring- und MSDTC-Topologieevidenz bleibt offen. Die modulare Kerninstallation ohne obligatorische LLM-Komponenten bleibt unverändert.

## Quellenstand nach PR #633

Dieser Abschnitt ist der historische Ausgangsstand; der aktuelle Folgeabgleich steht unter [SSIS-Referenzabgleich vom 6. November 2026](#ssis-referenzabgleich-vom-6-november-2026).

**Stand:** 6. November 2026.

Die interne Prozedurprüfung umfasst 21 von 25 Inventareinträgen mit 196 Parameterzeilen; die vier SSIS-Referenzeinträge sind noch nicht einzeln gegen Parameterverträge geprüft. Die bisherige öffentliche Kohorte umfasst 121 Procedures mit 2.167 Parameterzeilen. Die getrennte Nichtprozedurkohorte umfasst 57 TABLE-, VIEW- und FUNCTION-Objekte aus 47 Quelldateien. Diese Zählungen gelten jeweils nur für die gebundenen Kohorten und belegen keine globale Fehlerfreiheit oder allgemeine Laufzeitqualifikation.

Die PRs #631 bis #633 wurden mit den erforderlichen Head- und Main-Prüfungen, der vollständigen statischen Vertragssuite mit 80 Validatoren und Selbsttestauswahl `Changed`, Adapterparität und erfolgreichem TestLab-Cleanup-Vertrag integriert. Native SQL-Läufe wurden wegen reiner Kommentaränderungen übersprungen; daraus entsteht keine neue Laufzeitqualifikation. Die ausführbare Reihenfolge und der Objektstatus stehen in der [Entwicklungsplanung](Development_Waves_2026-10.md#quellenstand-nach-pr-633).

## Aktueller Stand nach Schritt 178

Der folgende Abschnitt dokumentiert den Quellenstand vom 5. November 2026 nach Schritt 178. Er bleibt als Historie erhalten; maßgeblich für den aktuellen Stand ist [NULL-Guards der internen Plananalyse](#null-guards-der-internen-plananalyse).

Die Hilfeprüfung der bisherigen Inventarkohorte erfasst 121 Procedures mit 2.167 Parameterzeilen; PR #610 bis PR #612 sind integriert. Die Nichtprozedurkohorte umfasst 57 TABLE-, VIEW- und FUNCTION-Objekte aus 47 Quelldateien. Die gebundenen DDL-Revisionen und Inventarzuordnung sind für diese Kohorte unabhängig geprüft. Diese Abschlüsse gelten ausschließlich für die bezeichneten Inventare und belegen weder globale Fehlerfreiheit noch allgemeine Laufzeit- oder Plattformqualifikation. Positive Windows-/Mirroring-Topologie, MSDTC-Dienst, externe Teilnehmer sowie Commit-/Recovery-Evidenz sind nicht belegt.

Die aktuelle Obergrenze beträgt 200 eigene PR-Schritte; bei Schritt 190 wird der Restumfang neu bewertet. Frühere Grenzen und Checkpoints setzen den aktuellen Verbrauch nicht zurück. Bestehende Einzelgrenzen und Sperren gelten fort; ein historischer Eintrag erteilt keine neue Ausführungsfreigabe. Der aktuelle Auftrag und die ausführbare Reihenfolge stehen in der [Entwicklungsplanung](Development_Waves_2026-10.md#aktueller-stand-nach-schritt-178).

## Vorheriger Checkpoint nach Schritt 43

Der vorherige integrierte Checkpoint und seine damaligen Prüfbelege sind im [Historienarchiv](Next_Steps_History_2026-11-05.md#vorheriger-checkpoint-nach-schritt-43) erhalten.

## Aktueller Checkpoint nach PR #485

Der gebundene Checkpoint nach PR #485 und seine zugehörigen Head- und Main-Prüfungen sind im [Historienarchiv](Next_Steps_History_2026-11-05.md#aktueller-checkpoint-nach-pr-485) erhalten. Neue Änderungen werden gegen den aktuellen Main-Stand und die maßgebliche Planung abgeglichen.

## Lesepfad und technische Evidenzgrenzen

Öffentliche Anwenderdokumentation bleibt der maßgebliche Ort für Produktverhalten und Bedienung; interne Pläne und Nachweisarchive ersetzen sie nicht. Inventarvollständigkeit gilt nur für die jeweils gebundene Kohorte. Produkt-, Plattform-, Berechtigungs-, Transaktions- und Laufzeitaussagen benötigen jeweils die passende unabhängige Evidenz. Fehlende Infrastruktur oder nicht ausgeführte Prüfungen bleiben ausdrücklich offen.

Installation und Ausführung folgen den modularen, dokumentierten Installationspfaden und ihren Voraussetzungen.

Die Kerninstallation muss ohne LLM-Komponenten und deren Berechtigungen oder Netzwerkzugriff funktionieren. Künftige LLM-Funktionen sind separat wählbare Zusatzmodule; fehlende oder unzulässige Voraussetzungen dürfen eine gültige Kerninstallation nicht abbrechen oder zurückrollen. Der Zusatzmodulstatus ist getrennt und ehrlich auszuweisen. Bei Einführung solcher Funktionen sind Kerninstallation ohne LLM und nicht verfügbare beziehungsweise nicht erlaubte Zusatzkomponenten gezielt remote abzunehmen. Die Inventuren installieren oder aktivieren keine externen Laufzeiten oder CLR-Komponenten; Analyze bleibt CLR-frei.

Für jeden einzelnen Parameter sind Datentyp und Eingabeform, ein ausdrücklich als Default bezeichneter Vorgabewert sowie die Bedeutung von NULL, Leerwerten und relevanten Grenzen zu erklären. Geschlossene Wertemengen werden taxativ mit sämtlichen erlaubten Werten und der Bedeutung jedes Werts beschrieben; Beispiele ersetzen diese Aufzählung nicht. Diese Abnahme gilt auch für die Nachprüfung bereits überarbeiteter Hilfen.

Für jede Regel gilt die aktuell ausgewählte maßgebliche Quelle samt ihren semantischen Abhängigkeiten; Discoverylinks allein aktivieren keine weiteren Verträge oder Prüfungen.


## Erhaltene Rückblicke auf frühere Abnahmen

Die folgenden Verweise bewahren die konkreten historischen Nachweisscopes. Sie beschreiben damalige Abnahmen und sind keine globale oder aktuelle Vollständigkeitsbehauptung.

- Der damalige Release-Nachweis umfasst alle 17 P0-, 40 P1- und 124 P2-Fälle; die abgeschlossene P0-, P1- und P2-Special-Case-Matrix gehörte zu diesem bestätigten Produktstand. Dies ist datierte, scopegebundene Release-Evidenz und keine Aussage über den heutigen Gesamtumfang. [Historischer Nachweis](Next_Steps_History_2026-11-05.md#aktueller-produktstand).
- Der archivierte Abschnitt [Abgeschlossen – SQL25-005](Next_Steps_History_2026-11-05.md#abgeschlossen--sql25-005) enthält den damaligen Befund. Die dokumentierten Bereiche `ANALYZE-LAB-001`, `OPS-005`, `OPS-006`, `OPS-008` und `COLL-001` bleiben an ihre jeweiligen damaligen Scopes gebunden.
- Das Intake WI-0010 und sein dokumentierter Themenumfang sind in der [Diagnoseabdeckungs- und Gap-Matrix](../../../Metadata/Quality/Diagnostic_Coverage_Landscape.csv) nachgewiesen; der historische Planungsstand bleibt im [Archiv](Next_Steps_History_2026-11-05.md#aktueller-produktstand) erhalten.

## Historische Abschnitte und erhaltene Anker

Die folgenden Überschriften bewahren bislang veröffentlichte Abschnittsanker und führen zum unveränderten Originaltext im Archiv.

## Historischer SSIS-Auftrag: elfte Paketwelle

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historischer-ssis-auftrag-elfte-paketwelle).

## Historischer SSIS-Auftrag: zehnte Paketwelle

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historischer-ssis-auftrag-zehnte-paketwelle).

## Historischer SSIS-Auftrag: siebte Paketwelle

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historischer-ssis-auftrag-siebte-paketwelle).

## Aktueller Gesamtauftrag: priorisierte Entwicklungswellen

Seit dem 26. Oktober 2026 bündelt dieser Auftrag die Weiterentwicklung einschließlich verbleibender SSIS-Themen als einziger Orchestrator. Die [Entwicklungsplanung](Development_Waves_2026-10.md) ist die maßgebliche Quelle für Zuständigkeit, Reihenfolge, Abschlussbedingungen und den nächsten ausführbaren Schritt. Bereits integrierte Wellen werden nicht wiederholt; neue SSIS-Schritte zählen im gemeinsamen Umfang mit. Die Obergrenze beträgt 200 eigene PR-Schritte, die Neubewertung erfolgt bei 190. Sicherheits-, Datenschutz-, Lizenz-, Identitäts-, Laufzeit- und Liefergrenzen bleiben verbindlich. Frühere Einzelaufträge und ihre damaligen Freigaben sind im [Historienarchiv](Next_Steps_History_2026-11-05.md#aktueller-gesamtauftrag-priorisierte-entwicklungswellen) dokumentiert.

## Abgeschlossen: fünf SSIS-Paketwellen vom 25. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen-f%C3%BCnf-ssis-paketwellen-vom-25-oktober-2026).

## SSIS-Welle 6: iterationsgebundene Ausführungskorrelation

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#ssis-welle-6-iterationsgebundene-ausf%C3%BChrungskorrelation).

## Separater Auftrag: STAT-DOMINANT-Fehlerdiagnose (54901)

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#separater-auftrag-stat-dominant-fehlerdiagnose-54901).

### Abgeschlossen: Diagnose aus PR #424

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen-diagnose-aus-pr-424).

### Historische Freigabe und Abnahmegrenzen

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-freigabe-und-abnahmegrenzen).

#### Freigegeben: STAT-DOMINANT-Fehlerdiagnose (54901)

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegeben-stat-dominant-fehlerdiagnose-54901).

## Integriert: SSIS-001-Pipeline-Phasenbeginnmeldungen (PR #421); Main-Abnahme offen

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#integriert-ssis-001-pipeline-phasenbeginnmeldungen-pr-421-main-abnahme-offen).

### Historische Freigabe und lokale Abnahme

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-freigabe-und-lokale-abnahme).

#### Freigegebener begrenzter SSIS-001-Schritt: Pipeline-Phasenbeginnmeldungen

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebener-begrenzter-ssis-001-schritt-pipeline-phasenbeginnmeldungen).

## Abgeschlossen: SSIS-001-Final-Commit-Meldungen (PR #419)

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen-ssis-001-final-commit-meldungen-pr-419).

### Historische Freigabe und lokale Abnahme

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-freigabe-und-lokale-abnahme-1).

## Abgeschlossen: SSIS-001-Zeilenfluss-Durchsatz (PR #417)

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen-ssis-001-zeilenfluss-durchsatz-pr-417).

### Historische Freigabe und lokale Abnahme

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-freigabe-und-lokale-abnahme-2).

## Abgeschlossen: SSIS-001-Schreibmengen (PR #415)

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen-ssis-001-schreibmengen-pr-415).

### Historische Freigabe und lokale Abnahme

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-freigabe-und-lokale-abnahme-3).

## Abgeschlossen: Release v1.1.2

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen-release-v112).

## Historische Freigaben und Sperrstände

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-freigaben-und-sperrst%C3%A4nde).

### Freigegebener Folge-PR: FIND-CORE-Diagnose

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebener-folge-pr-find-core-diagnose).

### Gestoppte Lieferung: Release 1.1.2

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#gestoppte-lieferung-release-112).

## Historische Welle: Release 1.1.0

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-welle-release-110).

## OPS-005-Quellenabgleich vom 23. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#ops-005-quellenabgleich-vom-23-oktober-2026).

## Erhaltener Stand: OPS-005-Lesepfad und Nachweishistorie

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#erhaltener-stand-ops-005-lesepfad-und-nachweishistorie).

### Dokumentationsaltlasten und Wiederaufnahme

Die drei damals bezeichneten Einstiege sind nachgeführt: Der Metadaten-Einstieg wurde mit PR #405 qualifiziert abgeschlossen. Das öffentliche TestLab-README trennt die OPS-005-Anleitung von der datierten Nachweischronologie. Der aktuelle Fortsetzungsstand ist mit dieser Migration von der erhaltenen Historie getrennt; die bisherigen Anker bleiben erreichbar. Diese Disposition betrifft ausschließlich die genannten Lesepfade und bestätigt keine vollständige Dokumentationskonformität. Die zuständigen Maintainer prüfen diese Einstiege erneut, wenn sich deren Verträge oder Pfadkonsumenten ändern. Der [damalige Altlastenstand](Next_Steps_History_2026-11-05.md#dokumentationsaltlasten-und-wiederaufnahme) bleibt historisch erhalten.

## Erhaltene Diagnosehistorie: OPS-005-Provider-Negativfall

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#erhaltene-diagnosehistorie-ops-005-provider-negativfall).

### Geplanter Windows-Fixturepfad für OPS-005

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#geplanter-windows-fixturepfad-f%C3%BCr-ops-005).

#### Plattform und Zuständigkeit

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#plattform-und-zust%C3%A4ndigkeit).

#### Voraussetzungen vor der Providerprobe

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#voraussetzungen-vor-der-providerprobe).

#### Fachlicher Abnahmeblock

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#fachlicher-abnahmeblock).

#### Cleanup, Nachweise und vorgeschlagene Freigabegrenze

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#cleanup-nachweise-und-vorgeschlagene-freigabegrenze).

#### Zulassung vor der Runanlage

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#zulassung-vor-der-runanlage).

#### Wiederaufnahme nach Integration der Lab-Korrektur

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#wiederaufnahme-nach-integration-der-lab-korrektur).

#### Windows-Abbruch am Aktivierungsintent

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#windows-abbruch-am-aktivierungsintent).

#### Zusatzrun endet an der Lab-Collation-Gastprobe

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#zusatzrun-endet-an-der-lab-collation-gastprobe).

#### Nachabnahme mit qualifizierter Lab-Korrektur

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#nachabnahme-mit-qualifizierter-lab-korrektur).

#### Markerkorrektur bestätigt; Installation am Kommentar-GO blockiert

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#markerkorrektur-best%C3%A4tigt-installation-am-kommentar-go-blockiert).

#### Installation bestätigt; Guardzustand 54890 unbekannt

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#installation-best%C3%A4tigt-guardzustand-54890-unbekannt).

#### Windows-Providerabnahme vom 22. Oktober 2026 bestanden

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#windows-providerabnahme-vom-22-oktober-2026-bestanden).

### Autorisierter Foundation-Folgeauftrag

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#autorisierter-foundation-folgeauftrag).

## Abgeschlossene Findings-Stabilisierung vom 20. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossene-findings-stabilisierung-vom-20-oktober-2026).

## Frühere Nichtqualifikation und integrierter OPS-005-Prüfschritt vom 20. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#fr%C3%BChere-nichtqualifikation-und-integrierter-ops-005-pr%C3%BCfschritt-vom-20-oktober-2026).

## Regelübernahme für Testbewertung vom 19. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#regel%C3%BCbernahme-f%C3%BCr-testbewertung-vom-19-oktober-2026).

## Freigegebene Lookup-/Cacheanalyse vom 19. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-lookup-cacheanalyse-vom-19-oktober-2026).

## Freigegebene Legacy-Lifecycle-Analyse vom 19. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-legacy-lifecycle-analyse-vom-19-oktober-2026).

## Lieferung der begrenzten Komponentenphasen-Erweiterung

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#lieferung-der-begrenzten-komponentenphasen-erweiterung).

## Freigegebene PCT_EN_2-Fortsetzung

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-pct_en_2-fortsetzung).

## Freigegebene Legacy-Komponentenphasenzeiten vom 18. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-legacy-komponentenphasenzeiten-vom-18-oktober-2026).

## Freigegebene ORPS_EN_2-Fortsetzung vom 18. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-orps_en_2-fortsetzung-vom-18-oktober-2026).

## Freigegebene Legacy-Zeilenflusserweiterung vom 18. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-legacy-zeilenflusserweiterung-vom-18-oktober-2026).

## Freigegebene Legacy-Taskerweiterung vom 18. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-legacy-taskerweiterung-vom-18-oktober-2026).

## Abgeschlossene begrenzte Legacy-Providerabnahme vom 18. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossene-begrenzte-legacy-providerabnahme-vom-18-oktober-2026).

## Ergänzender abgeschlossener Mail-Retentionsnachweis

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#erg%C3%A4nzender-abgeschlossener-mail-retentionsnachweis).

## Zurückgestellter SSIS-Backlog vom 16. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#zur%C3%BCckgestellter-ssis-backlog-vom-16-oktober-2026).

## Aktuelle SSIS-Kataloglieferung vom 16. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#aktuelle-ssis-kataloglieferung-vom-16-oktober-2026).

## WI-0009: qualifizierter portabler Kern und offenes Feature-Gate

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#wi-0009-qualifizierter-portabler-kern-und-offenes-feature-gate).

## Aktueller WI-0005-Abschluss vom 14. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#aktueller-wi-0005-abschluss-vom-14-oktober-2026).

## Aktueller Fertigstellungsauftrag vom 13. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#aktueller-fertigstellungsauftrag-vom-13-oktober-2026).

## Wiederaufnahme nach der Entwicklungspause

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#wiederaufnahme-nach-der-entwicklungspause).

## Maßgeblichkeit

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#ma%C3%9Fgeblichkeit).

## Auftrag zur autonomen Fortsetzung

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#auftrag-zur-autonomen-fortsetzung).

### Voraussetzungen und Abnahmen der Fortsetzung

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#voraussetzungen-und-abnahmen-der-fortsetzung).

## Sessionwechsel bei langer autonomer Entwicklung

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#sessionwechsel-bei-langer-autonomer-entwicklung).

## Aktueller Produktstand

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#aktueller-produktstand).

### Abgeschlossen – SQL25-005

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen--sql25-005).

## Nächste ausführbare Welle: Reifeabschluss

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#n%C3%A4chste-ausf%C3%BChrbare-welle-reifeabschluss).

## Exit-Kriterien

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#exit-kriterien).

## Freigegebene SSIS-Legacy-Umsetzung vom 16. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-ssis-legacy-umsetzung-vom-16-oktober-2026).

## Begrenzte Taskerweiterung: lokaler Abnahmeabschluss

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#begrenzte-taskerweiterung-lokaler-abnahmeabschluss).

### Verarbeitungsaufwand der SSIS-Vertrauensausnahme

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#verarbeitungsaufwand-der-ssis-vertrauensausnahme).

## Gesondert freigegebene SSIS-Dataflowkorrelation

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#gesondert-freigegebene-ssis-dataflowkorrelation).

## Freigegebene neunte SSIS-Welle

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-neunte-ssis-welle).
