# Installation

`Install_All.sql` ist ein schlanker SQLCMD-Installer und bindet die kanonischen Einzeldateien über `:r` ein.

Für einen eigenständigen, vollständig eingebetteten Installer:

```powershell
./Build-StandaloneInstaller.ps1
```

Die Quellen werden in exakt derselben, abhängigkeitssicheren Reihenfolge wie in
`Install_All.sql` eingebettet. Die erzeugte Datei `Install_All.generated.sql` ist
ein Build-Artefakt und wird nicht versioniert.
