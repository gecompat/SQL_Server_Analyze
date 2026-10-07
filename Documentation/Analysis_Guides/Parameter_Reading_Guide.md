# Parameter richtig lesen und sicher einsetzen

Exakte Signaturen und Defaultwerte stehen im [Procedure-Referenzhandbuch](../Reference/Procedure_Reference.md) und werden durch `EXEC [monitor].[Procedure] @Hilfe=1` ausgegeben.

## 1. Erst CONSOLE, dann RAW oder TABLE

- `CONSOLE`: sichere interaktive Orientierung.
- `RAW`: vollständige technische Spalten und stabiler Consumer-Vertrag.
- `TABLE`: semantisch benannte typisierte Ergebnisse zur SQL-internen Weiterverarbeitung in lokalen `#Temp`-Tabellen.
- `NONE`: keine fachlichen Resultsets, beispielsweise JSON-only.

## 2. Umfangsparameter

| Parametergruppe | Bedeutung | Sicherer Einstieg | Risiko |
|---|---|---|---|
| `@MaxZeilen` | Ausgabezeilen je Procedure/Child | positiven kleinen Wert verwenden | `0` oder `NULL` kann sehr große Ausgabe erzeugen |
| `@HighImpactConfirmed` | tatsächlich aktivierter Deep-Pfad | nur nach bewusster Scope-Prüfung auf `1` setzen | breite Katalog-, Cache- oder Forensikarbeit |
| `@MaxAnalyseobjekte` | XML-/Plantiefenanalyse | 1–5 Kandidaten | hohe CPU für Plan-XML |
| Zeitfenster | Query Store, XE, msdb | kurz beginnen | Retention- und Scanaufwand |
| `@SampleSeconds` | Deltaanalyse | 5–10 Sekunden | blockiert die aufrufende Session während WAITFOR |

## 3. Datenbankfilter

Frameworkweit gelten für Datenbankfilter folgende Regeln:

- `N''` oder `NULL`: alle sichtbaren Online-Benutzerdatenbanken,
- explizite Pipe-Liste: nur genannte Datenbanken.

Systemdatenbanken bleiben ohne ausdrückliches Opt-in ausgeschlossen. Prüfen Sie vor der Interpretation die Hilfe und den Status des Aufrufs.

## 4. Exakte Listen und Pattern

- Exakte Listen sind pipe-getrennt und bracket-aware.
- Listen und Pattern derselben Eigenschaft sind häufig gegenseitig exklusiv.
- SQL-Identifier bleiben case-sensitiv.
- Regexpfade benötigen passende SQL-Server-Version und Compatibility.

## 5. Tiefenoptionen

Optionen wie Plan-XML, Event-XML, Lockdetails, Histogramme, Segmente, Dictionaries, Page Details oder eine breite Vollanalyse erhöhen CPU, I/O, Ausgabe und Laufzeit. Grenzen Sie zuerst die Kandidaten ein und aktivieren Sie danach die benötigte Tiefenoption.

## 6. Textparameter

Vollständiger SQL-Text, Batchtext und Input Buffer können große und sensible Laufzeitinhalte liefern. Zeigen Sie diese Inhalte nur für die erforderliche Diagnose an und exportieren oder übertragen Sie sie nicht ungeprüft.

| Option | Daten- und Transferwirkung |
|---|---|
| `@MitSqlText = 1` | Bereits das aktuelle Statement kann Literale, Kommentare oder Anwendungsstruktur enthalten. Für eine erste ressourcenbezogene Sicht kann der Text ausgeschaltet bleiben. |
| `@GesamtenSqlTextEinbeziehen = 1` | Vollständiger Batch- oder Modulkontext kann Informationen außerhalb des aktuell ausgeführten Statements enthalten. |
| `@InputBufferEinbeziehen = 1` | Der ursprüngliche Clientaufruf kann zusätzliche Parameterwerte und Kontext enthalten. |
| `@MaxSqlTextZeichen = 0` oder `NULL` | Der Text wird nicht begrenzt. Ein positives Limit reduziert Transfer, anonymisiert aber keine Inhalte. |
| Plan-XML oder Event-Payload | Parameterdarstellungen, Ressourcen und Prozessattribute können mehrere Sessions oder Objekte verbinden; die konkrete Option steht in der Procedure-Seite. |
| JSON oder TABLE | Die gleiche fachliche Materialisierung wird weiterverarbeitbar. TABLE bleibt lokal in `#Temp`-Tabellen, Folgeexporte können den Empfängerkreis dennoch erweitern. |

Prüfen Sie vor Export oder Ticketkopie Datenumfang, Empfänger und Aufbewahrung.
`@HighImpactConfirmed` ist eine Ressourcenbestätigung und keine
Datenschutzfreigabe. Der [Datenschutzvertrag](../Architecture/Runtime_Data_Privacy.md)
gilt für alle Ausgabearten; die Optionen existieren jeweils nur nach der
konkreten Signatur des aufgerufenen Moduls.

## 7. Schwellenwerte

Jeden Schwellwert klassifizieren:

1. Framework-Default,
2. Microsoft-dokumentierte Produkteigenschaft,
3. betriebliche Heuristik,
4. keine universelle Grenze.

Ein Schwellwert priorisiert; er beweist keine Ursache.

## 8. Vor breiten Aufrufen

1. Führen Sie `USP_CheckAnalyseAccess` aus.
2. Prüfen Sie `USP_CheckFrameworkCapabilities`.
3. Begrenzen Sie den Zielscope explizit.
4. Verwenden Sie CONSOLE.
5. Aktivieren Sie erst danach RAW- und Deep-Optionen.
