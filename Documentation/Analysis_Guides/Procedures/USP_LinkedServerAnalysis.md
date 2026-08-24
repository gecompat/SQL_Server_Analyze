# [monitor].[USP_LinkedServerAnalysis]

Inventarisiert Linked Server lokal. Ein Verbindungstest erfordert zwei ausdrückliche opt-ins.

```sql
EXEC [monitor].[USP_LinkedServerAnalysis] @ConnectivityTestEnabled = 0, @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile beschreibt einen registrierten Linked Server und den getrennten Status des Verbindungstests.

## So lesen

`NOT_EXECUTED` ist der sichere Standard; `FAILED` gilt nur für den konkreten Testzeitpunkt.

## Warum kann das problematisch sein?

Linked Server erweitern Vertrauens-, Netzwerk- und Fehlerdomänen und können verteilte Abhängigkeiten einführen.

## Wann ist es kein Problem?

Ein kontrollierter Linked Server kann eine freigegebene Integrationsschnittstelle sein.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche lokale Konfiguration benötigt eine autorisierte Konnektivitäts- oder Workloadgegenprobe?

### Technischer Hintergrund

Nur der doppelte opt-in Pfad ruft `sp_testlinkedserver` auf; fachliche Remotedaten werden nicht abgefragt.

### Datenkette

`sys.servers` → Inventar; optional `sp_testlinkedserver` → Teststatus; Waitstatistik → kumulativer Kontext.

### Source Select

```sql
SELECT [name], [product], [provider], [is_data_access_enabled], [is_rpc_out_enabled]
FROM [sys].[servers] WITH (NOLOCK)
WHERE [is_linked] = 1;
```

**Wichtig für die Eigenlast:** Lassen Sie den externen Verbindungstest standardmäßig deaktiviert.

### Zeit- und Scope-Modell

Das Inventar ist aktuell, Waitwerte sind kumulativ und der Test gilt nur für seinen Zeitpunkt.

### Bewertung und Gegenprobe

Prüfen Sie Eigentümer, Login-Mapping, Provider, Netzwerkfreigabe und reale Abfragen getrennt.

### Typische Fehlinterpretation

Ein erfolgreicher Test beweist weder Objektberechtigung noch akzeptable Laufzeit.

### Folgeanalyse

Korrelieren Sie Remote-Waits, Errorlog und Requestevidenz in einem vereinbarten Testfenster.

[Technische Detailbeschreibung](../../../Code/08_ServerHealth/220_USP_LinkedServerAnalysis.sql)
