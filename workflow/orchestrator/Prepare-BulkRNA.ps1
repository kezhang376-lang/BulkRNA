<# 本地生成独立审查包；不连接集群、不执行分析。 #>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Config,
    [Parameter(Mandatory = $true)][string]$RunId,
    [string]$Output,
    [string]$Rscript
)
$ErrorActionPreference = 'Stop'
$taskConfig = (Resolve-Path -LiteralPath $Config).Path
if (-not $Output) {
    $Output = Join-Path (Split-Path -Parent $taskConfig) (Join-Path 'prepared' $RunId)
}
if (-not $Rscript) {
    $taskCommand = Get-Command Rscript -ErrorAction SilentlyContinue
    if ($taskCommand) { $Rscript = $taskCommand.Source }
    else {
        $taskCandidates = @(Get-ChildItem -Path (Join-Path $env:ProgramFiles 'R/R-*/bin/Rscript.exe') -ErrorAction SilentlyContinue)
        if ($taskCandidates.Count -eq 1) { $Rscript = $taskCandidates[0].FullName }
        else { throw 'Specify -Rscript with an explicit Rscript.exe path (none or multiple R installations found).' }
    }
}
if (-not (Test-Path -LiteralPath $Rscript -PathType Leaf)) { throw "Rscript not found: $Rscript" }
& $Rscript --vanilla (Join-Path $PSScriptRoot 'prepare_project.R') $taskConfig $RunId $Output
if ($LASTEXITCODE -ne 0) {
    throw "Preparation blocked or failed (exit $LASTEXITCODE). Inspect review_plan.md if a bundle was generated; no analysis was started."
}
