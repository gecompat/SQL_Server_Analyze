# Betrieb des WaitTypeCatalog

Der Katalog trennt pflegbare exakte Wait-Beschreibungen von stabilen Familien-Fallbacks. Runtime-Abfragen verwenden ausschließlich lesende Lookups. Eigene Zeilen erhalten `IsFrameworkDefault=0`; dadurch bleiben sie bei Framework-Upgrades unverändert. Die SQLskills-URL wird für Framework-Defaults generisch je Wait Type gesetzt.
