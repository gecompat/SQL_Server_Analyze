# Verbindlicher Qualitätsvertrag für Analyse-Dokumentation

## Abdeckung

Jede im öffentlichen Procedure-Referenzhandbuch geführte Procedure besitzt:

1. einen Eintrag im Objektindex,
2. eine eigenständige Seite unter `Procedures/`,
3. einen technischen Abschnitt im Familienguide,
4. eine Signatur im Procedure-Referenzhandbuch.

## Didaktischer Mindestvertrag

Jede eigenständige Seite erklärt:

- Zeilengranularität,
- Zeitbezug oder Reset-/Retention-Grenze,
- sichere Leserichtung,
- technische Problembegründung,
- möglichen unkritischen Kontext,
- mindestens ein synthetisches Beispiel,
- Folgeanalyse,
- mögliche partielle/leere Ausgabe,
- Eigenlast, wenn der Pfad über LOW hinausgeht,
- eine technische Vertiefung mit Leitfrage, Enginehintergrund, Datenkette, Zeit-/Scope-Modell, Gegenprobe, Fehlinterpretationsgrenze und Folgeanalyse,
- einen Link auf das gemeinsame [Execution-, Zeit- und Evidenzmodell](Technical_Foundations.md).
- bei versionsabhängigen Aussagen einen nachvollziehbaren Eintrag oder Verweis in der [Versions- und Primärquellenmatrix](Version_Primary_Source_Matrix.md).

## Fachlicher Mindestvertrag

- Ein Einzelwert wird nicht als Root Cause dargestellt.
- Prozent und Durchschnitt besitzen einen erklärten Nenner.
- Findings werden als Triage, nicht als automatische Änderung behandelt.
- Status- und Childresultsets werden vor Fachdaten bewertet.
- Query Store, XE, Plan Cache und DMVs erhalten ihre jeweiligen Retention-/Resetgrenzen.

## Wartbarkeit

Die Strukturprüfung `Code/Tests/Static/900_Validate_Analysis_Documentation.ps1` vergleicht Referenz und Seiten, Pflichtüberschriften sowie interne Markdownlinks. `Code/Tests/Static/980_Validate_External_Documentation_Links.py` prüft externe URL-Struktur repositoryweit und erkennt im Analysis-Guide-/Quellenscope dauerhafte HTTP-Fehler. Transiente Netzwerk-, Rate-Limit- oder Serverfehler werden als Warnung gezählt, damit ein Fremdsystemausfall das Liefergate nicht fälschlich blockiert. Beide Prüfungen ersetzen keine fachliche oder Datenschutzprüfung.

## Datenschutz

Repositorybeispiele verwenden ausschließlich generische Systembegriffe und eindeutig synthetische Werte. Automatisierte Scanner sind nur unterstützend; die manuelle Prüfung des vollständigen Diffs bleibt verpflichtend.
