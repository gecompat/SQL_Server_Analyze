# Wait-Stats-Methodik

Die Implementierung kombiniert die bewährten Prinzipien aus dem vorhandenen historische Analysequelle-Modul und der SQLskills-Waits-and-Queues-Methodik.

1. Aktuelle Task-Waits werden nicht durch eine historische Ausschlussliste verborgen.
2. Instanz-Waits werden bevorzugt als Delta zwischen zwei Snapshots bewertet.
3. Ohne Messfenster werden kumulative Werte ausdrücklich als Kontext seit Start/Reset gekennzeichnet.
4. Benigne Hintergrund-Waits werden nur im Standardranking ausgeblendet und können eingeblendet werden.
5. Das Ranking zeigt standardmäßig die Waits, die zusammen bis zu 95 Prozent der Wartezeit erklären.
6. Resource-, Signal- und Gesamtwartezeit sowie Durchschnittswerte werden getrennt ausgewiesen.
7. Jeder Wait erhält Gruppe, Bedeutung, typisches Auftreten, mögliche Folgen, empfohlene Folgeprüfungen und eine direkte SQLskills-URL.
8. Neue/unbekannte Wait Types erhalten einen stabilen Fallback statt NULL.

Referenzen:
- https://www.sqlskills.com/blogs/paul/wait-statistics-or-please-tell-me-where-it-hurts/
- https://www.sqlskills.com/help/waits/
