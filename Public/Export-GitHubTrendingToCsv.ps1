function Export-GitHubTrendingToCsv {
  # .SYNOPSIS
  #     Exports GitHub repository data to a CSV file.

  # .DESCRIPTION
  #     Takes repository data from Get-GitHubTrendingRepositories and writes it to a CSV file.

  # .PARAMETER InputObject
  #     PSCustomObject array of repositories (from Get-GitHubTrendingRepositories).

  # .PARAMETER Path
  #     Full path to the output CSV file (e.g., "C:\data\repos.csv").

  # .EXAMPLE
  #     Get-GitHubTrendingRepositories -By Stars | Export-GitHubTrendingToCsv -Path "Top-100-stars.csv"

  # .EXAMPLE
  #     $repos = Get-GitHubTrendingRepositories -By Language -Language Python
  #     Export-GitHubTrendingToCsv -InputObject $repos -Path "Python-repos.csv"

  # .NOTES
  #     Requires UTF-8 encoding and no type information.
  # .LINK
  #
  [CmdletBinding()][Alias('GhTrend-ToCsv')][OutputType([void])]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [PSCustomObject[]]$InputObject,

    [Parameter(Mandatory = $false)]
    [string]$Path = "repos.csv"
  )

  process {
    try {
      $repoList = [System.Collections.Generic.List[PSCustomObject]]::new($InputObject)
      [void][GitHubTrends]::ExportToCsv($repoList, $Path)
      Write-Verbose "Exported to '$Path'"
    } catch {
      $PSCmdlet.WriteError("Failed to export to CSV: $Path. Error: $($_.Exception.Message)")
    }
  }
}