# [monitor].[USP_DiagnosticFindings]

**Bereich:** Server Health  
**Zweck:** Konsolidiert normalisierte Findings mit Priorität, Konfidenz, Evidenz und Aussagegrenze.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DiagnosticFindings]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurAbPrioritaet = 'INFO',
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einem normalisierten Finding aus einem SourceModule. Modulstatuszeilen sind getrennt zu lesen.

## So lesen

Severity **und** Confidence mit SourceModule, Evidence, `EvidenceLimit`, RecommendedNextCheck und Modulstatus lesen.

## Warum kann das problematisch sein?

HIGH/HIGH ist starke priorisierte Evidenz. HIGH/LOW verlangt dringende Verifikation, ist aber noch keine bestätigte Ursache.

## Wann ist es kein Problem?

Keine Findings sind nur beruhigend, wenn alle relevanten SourceModules vollständig liefen.

## Beispiel und Folgeschritt

Leeres Findingsresultset plus Integritätsmodul `PERMISSION_DENIED` ist keine Entwarnung. Ein HIGH/HIGH-Suspect-Page-Finding verlangt sofortige Detailprüfung im SourceModule.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche normalisierten Befunde aus mehreren Spezialmodulen verdienen Priorität und wie stark ist die Evidenz?

### Technischer Hintergrund

Aggregator ruft Children über definierte JSON-/RAW-Verträge auf und normalisiert Category, Severity, Confidence, Scope, Evidence, EvidenceLimit und Next Check. Er reduziert Detail für Triage und muss Childstatus separat erhalten.

### Datenkette

`sys.databases`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Mix aus Child-Snapshots, Samples und Historien im selben Lauf.

### Bewertung und Gegenprobe

Severity und Confidence gemeinsam lesen, SourceModule/Scope zum Detail zurückverfolgen, EvidenceLimit nicht ausblenden. HIGH+LOW verlangt schnelle Validierung, nicht automatische Aktion.

### Typische Fehlinterpretation

Keine Findings bedeutet nur dann wenig Auffälliges, wenn alle relevanten Children vollständig erfolgreich waren. Normalisierung kann Details bewusst weglassen.

### Folgeanalyse

SourceModule direkt mit engem Scope aufrufen.

[Technische Detailbeschreibung](../08_Server_Health.md#17-monitorusp_diagnosticfindings)
