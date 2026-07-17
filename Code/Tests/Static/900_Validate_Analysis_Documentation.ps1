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
$codeRoot = Join-Path $RepositoryRoot 'Code'
$requiredHeadings = @(
    '## Eine Zeile bedeutet',
    '## So lesen',
    '## Warum kann das problematisch sein?',
    '## Wann ist es kein Problem?'
)

$errors = [System.Collections.Generic.List[string]]::new()
$markdownAnchorCache = @{}

function ConvertTo-CanonicalParameterDeclarations {
    param([AllowEmptyString()][string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    $normalized = [regex]::Replace($Text, '(?m)--.*$', '')
    $normalized = [regex]::Replace($normalized, '(?m)\r?\n\s*,\s*', ', ')
    $normalized = [regex]::Replace($normalized, '\s+', ' ').Trim()
    $normalized = $normalized.TrimStart(',').Trim()

    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return @()
    }

    return @(
        [regex]::Split($normalized, ',\s*(?=@[A-Za-z_])') |
            ForEach-Object {
                $declaration = $_.Trim()
                $declaration = [regex]::Replace($declaration, '\s*=\s*', ' = ')
                $declaration = [regex]::Replace($declaration, '\s*,\s*', ',')
                $declaration = [regex]::Replace($declaration, '\s+', ' ')
                $declaration.Trim()
            } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function Get-ParameterName {
    param([string]$Declaration)

    $match = [regex]::Match($Declaration, '^(@[A-Za-z_][A-Za-z0-9_]*)\b')
    if (-not $match.Success) {
        return $null
    }
    return $match.Groups[1].Value
}

function ConvertTo-MarkdownAnchor {
    param([string]$Heading)

    $value = [regex]::Replace($Heading.Trim(), '<[^>]+>', '')
    $value = [regex]::Replace($value, '[`*_~]', '')
    $value = $value.ToLowerInvariant()
    $value = [regex]::Replace($value, '[^\p{L}\p{Nd}\- _]', '')
    $value = [regex]::Replace($value, '[ _]+', '-')
    $value = [regex]::Replace($value, '-{2,}', '-')
    return $value.Trim('-')
}

function Get-MarkdownAnchors {
    param([string]$MarkdownPath)

    $fullPath = [System.IO.Path]::GetFullPath($MarkdownPath)
    if ($markdownAnchorCache.ContainsKey($fullPath)) {
        return @($markdownAnchorCache[$fullPath])
    }

    $text = Get-Content -LiteralPath $fullPath -Raw -Encoding UTF8
    $counts = @{}
    $anchors = [System.Collections.Generic.List[string]]::new()
    $headingMatches = [regex]::Matches($text, '(?m)^\s{0,3}#{1,6}\s+(.+?)\s*#*\s*$')

    foreach ($headingMatch in $headingMatches) {
        $baseAnchor = ConvertTo-MarkdownAnchor $headingMatch.Groups[1].Value
        if ([string]::IsNullOrWhiteSpace($baseAnchor)) {
            continue
        }

        if ($counts.ContainsKey($baseAnchor)) {
            $suffix = [int]$counts[$baseAnchor]
            $anchors.Add("$baseAnchor-$suffix")
            $counts[$baseAnchor] = $suffix + 1
        }
        else {
            $anchors.Add($baseAnchor)
            $counts[$baseAnchor] = 1
        }
    }

    $markdownAnchorCache[$fullPath] = @($anchors)
    return @($anchors)
}

foreach ($requiredPath in @($referencePath, $objectIndexPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required documentation file not found: $requiredPath"
    }
}
foreach ($requiredDirectory in @($pagesRoot, $codeRoot)) {
    if (-not (Test-Path -LiteralPath $requiredDirectory -PathType Container)) {
        throw "Required directory not found: $requiredDirectory"
    }
}

$referenceText = Get-Content -LiteralPath $referencePath -Raw -Encoding UTF8
$objectIndexText = Get-Content -LiteralPath $objectIndexPath -Raw -Encoding UTF8
$sectionMatches = [regex]::Matches(
    $referenceText,
    '(?ms)^## `\[monitor\]\.\[(USP_[A-Za-z0-9_]+)\]`\s*$\s*(.*?)(?=^## `\[monitor\]\.\[USP_[A-Za-z0-9_]+\]`|\z)'
)

$referenceNames = @($sectionMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
$pageFiles = @(Get-ChildItem -LiteralPath $pagesRoot -Filter 'USP_*.md' -File)
$pageNames = @($pageFiles | ForEach-Object { $_.BaseName } | Sort-Object -Unique)
$parameterNamesByProcedure = @{}
$declaredSourcePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

foreach ($name in @($referenceNames | Where-Object { $_ -notin $pageNames })) {
    $errors.Add("Missing procedure page: $name")
}
foreach ($name in @($pageNames | Where-Object { $_ -notin $referenceNames })) {
    $errors.Add("Procedure page without reference entry: $name")
}

foreach ($name in $referenceNames) {
    $expectedIndexLink = "Procedures/$name.md"
    if ($objectIndexText.IndexOf($expectedIndexLink, [System.StringComparison]::Ordinal) -lt 0) {
        $errors.Add("Object index does not link procedure page: $name")
    }
}

foreach ($sectionMatch in $sectionMatches) {
    $procedureName = $sectionMatch.Groups[1].Value
    $sectionBody = $sectionMatch.Groups[2].Value
    $sourceMatch = [regex]::Match($sectionBody, '(?m)^Quelle:\s*`([^`]+)`\s*$')
    $signatureMatch = [regex]::Match($sectionBody, '(?ms)^```sql\s*$\s*(.*?)\s*^```\s*$')

    if (-not $sourceMatch.Success) {
        $errors.Add("Missing source path in procedure reference: $procedureName")
        continue
    }
    if (-not $signatureMatch.Success) {
        $errors.Add("Missing parameter signature in procedure reference: $procedureName")
        continue
    }

    $relativeSourcePath = $sourceMatch.Groups[1].Value.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $sourcePath = [System.IO.Path]::GetFullPath((Join-Path $RepositoryRoot $relativeSourcePath))
    [void]$declaredSourcePaths.Add($sourcePath)

    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        $errors.Add("Referenced SQL source does not exist: $procedureName")
        continue
    }

    $sourceText = Get-Content -LiteralPath $sourcePath -Raw -Encoding UTF8
    $sourceProcedureMatch = [regex]::Match(
        $sourceText,
        '(?ims)^\s*CREATE\s+OR\s+ALTER\s+PROCEDURE\s+\[monitor\]\.\[(USP_[A-Za-z0-9_]+)\]\s*(.*?)^\s*AS\s*$'
    )

    if (-not $sourceProcedureMatch.Success) {
        $errors.Add("CREATE OR ALTER PROCEDURE declaration not found in referenced source: $procedureName")
        continue
    }

    $sourceProcedureName = $sourceProcedureMatch.Groups[1].Value
    if (-not [string]::Equals($procedureName, $sourceProcedureName, [System.StringComparison]::Ordinal)) {
        $errors.Add("Procedure name differs between reference and source: $procedureName")
    }

    $referenceDeclarations = @(ConvertTo-CanonicalParameterDeclarations $signatureMatch.Groups[1].Value)
    $sourceDeclarations = @(ConvertTo-CanonicalParameterDeclarations $sourceProcedureMatch.Groups[2].Value)
    $referenceParameterNames = @($referenceDeclarations | ForEach-Object { Get-ParameterName $_ })
    $sourceParameterNames = @($sourceDeclarations | ForEach-Object { Get-ParameterName $_ })
    $parameterNamesByProcedure[$procedureName] = @($sourceParameterNames)

    if ($referenceDeclarations.Count -ne $sourceDeclarations.Count) {
        $errors.Add("Parameter count differs between reference and source: $procedureName")
        continue
    }

    for ($index = 0; $index -lt $referenceDeclarations.Count; $index++) {
        if (-not [string]::Equals($referenceParameterNames[$index], $sourceParameterNames[$index], [System.StringComparison]::Ordinal)) {
            $errors.Add("Parameter name or order differs at position $($index + 1): $procedureName")
            continue
        }
        if (-not [string]::Equals($referenceDeclarations[$index], $sourceDeclarations[$index], [System.StringComparison]::OrdinalIgnoreCase)) {
            $errors.Add("Parameter declaration or default differs for $($sourceParameterNames[$index]): $procedureName")
        }
    }
}

$sourceProcedureNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$sqlFiles = @(
    Get-ChildItem -LiteralPath $codeRoot -Filter '*.sql' -File -Recurse |
        Where-Object {
            $_.FullName -notmatch '[\\/](Tests|Install)[\\/]'
        }
)
foreach ($sqlFile in $sqlFiles) {
    $sqlText = Get-Content -LiteralPath $sqlFile.FullName -Raw -Encoding UTF8
    $procedureMatches = [regex]::Matches(
        $sqlText,
        '(?im)^\s*CREATE\s+OR\s+ALTER\s+PROCEDURE\s+\[monitor\]\.\[(USP_[A-Za-z0-9_]+)\]'
    )
    foreach ($procedureMatch in $procedureMatches) {
        [void]$sourceProcedureNames.Add($procedureMatch.Groups[1].Value)
    }
}

foreach ($name in @($referenceNames | Where-Object { -not $sourceProcedureNames.Contains($_) })) {
    $errors.Add("Referenced procedure not found in canonical SQL sources: $name")
}
foreach ($name in @($sourceProcedureNames | Where-Object { $_ -notin $referenceNames } | Sort-Object)) {
    $errors.Add("Canonical SQL procedure missing from procedure reference: $name")
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

    if ($parameterNamesByProcedure.ContainsKey($file.BaseName)) {
        $knownParameterNames = @($parameterNamesByProcedure[$file.BaseName])
        $procedurePattern = [regex]::Escape($file.BaseName)
        $codeBlockMatches = [regex]::Matches($text, '(?ms)```(?:sql|tsql)\s*(.*?)```')

        foreach ($codeBlockMatch in $codeBlockMatches) {
            $callMatches = [regex]::Matches(
                $codeBlockMatch.Groups[1].Value,
                "(?ims)\bEXEC(?:UTE)?\s+(?:\[monitor\]|monitor)\s*\.\s*(?:\[$procedurePattern\]|$procedurePattern)\b(?<Arguments>.*?)(?:;|\z)"
            )
            foreach ($callMatch in $callMatches) {
                $assignedParameters = [regex]::Matches($callMatch.Groups['Arguments'].Value, '(@[A-Za-z_][A-Za-z0-9_]*)\s*=')
                foreach ($assignedParameter in $assignedParameters) {
                    $parameterName = $assignedParameter.Groups[1].Value
                    if ($parameterName -notin $knownParameterNames) {
                        $errors.Add("Unknown parameter in documented EXEC example: $($file.BaseName) $parameterName")
                    }
                }
            }
        }
    }
}

$allMarkdown = @(Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot 'Documentation') -Filter '*.md' -File -Recurse)
foreach ($file in $allMarkdown) {
    $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    $relativeLinks = [regex]::Matches(
        $text,
        '\[[^\]]+\]\((?!https?://|mailto:)(?<Target>[^)#]*)(?:#(?<Fragment>[^)]+))?\)'
    )

    foreach ($match in $relativeLinks) {
        $target = [System.Uri]::UnescapeDataString($match.Groups['Target'].Value.Trim().Trim('<', '>'))
        $fragment = [System.Uri]::UnescapeDataString($match.Groups['Fragment'].Value.Trim())

        if ($target -match '^[A-Za-z][A-Za-z0-9+.-]*:') {
            continue
        }

        if ([string]::IsNullOrWhiteSpace($target)) {
            $resolved = $file.FullName
        }
        else {
            $resolved = [System.IO.Path]::GetFullPath((Join-Path $file.DirectoryName $target))
        }

        if (-not (Test-Path -LiteralPath $resolved)) {
            $errors.Add("Broken documentation link '$target': $($file.FullName)")
            continue
        }

        if (-not [string]::IsNullOrWhiteSpace($fragment) -and
            (Test-Path -LiteralPath $resolved -PathType Leaf) -and
            [System.IO.Path]::GetExtension($resolved).Equals('.md', [System.StringComparison]::OrdinalIgnoreCase)) {
            $anchors = @(Get-MarkdownAnchors $resolved)
            if ($fragment -notin $anchors) {
                $errors.Add("Broken documentation anchor '#$fragment': $($file.FullName)")
            }
        }
    }
}

Write-Host "Referenced procedures:      $($referenceNames.Count)"
Write-Host "Canonical source procedures: $($sourceProcedureNames.Count)"
Write-Host "Procedure pages:             $($pageNames.Count)"
Write-Host "Referenced source files:     $($declaredSourcePaths.Count)"

if ($referenceNames.Count -ne 79) {
    $errors.Add("Expected 79 reference procedures, found $($referenceNames.Count).")
}
if ($sourceProcedureNames.Count -ne 79) {
    $errors.Add("Expected 79 canonical SQL procedures, found $($sourceProcedureNames.Count).")
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
