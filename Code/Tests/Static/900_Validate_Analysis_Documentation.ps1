[CmdletBinding()]
param(
    [string]$RepositoryRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
}

$referencePath = Join-Path $RepositoryRoot 'Documentation/Reference/Procedure_Reference.md'
$pagesRoot = Join-Path $RepositoryRoot 'Documentation/Analysis_Guides/Procedures'
$objectIndexPath = Join-Path $RepositoryRoot 'Documentation/Analysis_Guides/Object_Index.md'
$requiredHeadings = @(
    '## Eine Zeile bedeutet',
    '## So lesen',
    '## Warum kann das problematisch sein?',
    '## Wann ist es kein Problem?'
)

$errors = [System.Collections.Generic.List[string]]::new()

foreach ($requiredPath in @($referencePath, $objectIndexPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required documentation file not found: $requiredPath"
    }
}
if (-not (Test-Path -LiteralPath $pagesRoot -PathType Container)) {
    throw "Procedure pages directory not found: $pagesRoot"
}

$referenceText = Get-Content -LiteralPath $referencePath -Raw -Encoding UTF8
$objectIndexText = Get-Content -LiteralPath $objectIndexPath -Raw -Encoding UTF8
$referenceMatches = [regex]::Matches(
    $referenceText,
    '(?m)^## `\[monitor\]\.\[(USP_[A-Za-z0-9_]+)\]`\s*$'
)
$referenceNames = @($referenceMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)

$pageFiles = @(Get-ChildItem -LiteralPath $pagesRoot -Filter 'USP_*.md' -File)
$pageNames = @($pageFiles | ForEach-Object { $_.BaseName } | Sort-Object -Unique)

$missingPages = @($referenceNames | Where-Object { $_ -notin $pageNames })
$orphanPages = @($pageNames | Where-Object { $_ -notin $referenceNames })

foreach ($name in $missingPages) {
    $errors.Add("Missing procedure page: $name")
}
foreach ($name in $orphanPages) {
    $errors.Add("Procedure page without reference entry: $name")
}

foreach ($name in $referenceNames) {
    $expectedIndexLink = "Procedures/$name.md"
    if ($objectIndexText.IndexOf($expectedIndexLink, [System.StringComparison]::Ordinal) -lt 0) {
        $errors.Add("Object index does not link procedure page: $name")
    }
}

foreach ($file in $pageFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8

    $expectedTitle = "# [monitor].[$($file.BaseName)]"
    if (-not $text.StartsWith($expectedTitle, [System.StringComparison]::Ordinal)) {
        $errors.Add("Invalid or missing title: $($file.FullName)")
    }

    foreach ($heading in $requiredHeadings) {
        if ($text.IndexOf($heading, [System.StringComparison]::Ordinal) -lt 0) {
            $errors.Add("Missing heading '$heading': $($file.FullName)")
        }
    }

    if ($text -notmatch '\[Technische Detailbeschreibung\]\(') {
        $errors.Add("Missing technical detail link: $($file.FullName)")
    }
}

$allMarkdown = @(Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot 'Documentation') -Filter '*.md' -File -Recurse)
foreach ($file in $allMarkdown) {
    $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    $relativeLinks = [regex]::Matches($text, '\[[^\]]+\]\((?!https?://|mailto:|#)([^)#]+)(?:#[^)]+)?\)')
    foreach ($match in $relativeLinks) {
        $target = $match.Groups[1].Value
        if ($target -match '^[A-Za-z]+:') { continue }
        $resolved = [System.IO.Path]::GetFullPath((Join-Path $file.DirectoryName $target))
        if (-not (Test-Path -LiteralPath $resolved)) {
            $errors.Add("Broken documentation link '$target': $($file.FullName)")
        }
    }
}

Write-Host "Referenced procedures: $($referenceNames.Count)"
Write-Host "Procedure pages:       $($pageNames.Count)"

if ($referenceNames.Count -ne 79) {
    $errors.Add("Expected 79 reference procedures, found $($referenceNames.Count).")
}
if ($pageNames.Count -ne 79) {
    $errors.Add("Expected 79 procedure pages, found $($pageNames.Count).")
}

if ($errors.Count -gt 0) {
    $errors | Sort-Object -Unique | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host 'Analysis documentation validation succeeded.'
exit 0
