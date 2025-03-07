function Get-GitHubTrendingRepositories {
  # .SYNOPSIS
  #     Retrieves trending GitHub repositories based on specified criteria.

  # .DESCRIPTION
  #     Returns repositories sorted by stars, forks, or language. Uses the GitHub GraphQL API.

  # .EXAMPLE
  #     Get-GitHubTrendingRepositories -By Stars -BulkCount 2
  #     Gets top 100 repositories sorted by stars (2 requests × 50 repos).

  # .EXAMPLE
  #     Get-GitHubTrendingRepositories -By Language -Language Python
  #     Gets trending Python repositories.
  # .LINK
  #
  [CmdletBinding()][Alias('ghtrends')][OutputType([PSCustomObject[]])]
  param(
    # Criteria to sort repositories by (Stars, Forks, or Language).
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("Stars", "Forks", "Language")]
    [string]$By,

    # Required when By is 'Language'. Specify the programming language (e.g., "Python").
    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = "Language")]
    [ValidateNotNullOrWhiteSpace()]
    [string]$Language,

    # Number of API requests to make note: BulkSize * BulkCount = total_repos
    [Parameter(Mandatory = $false, Position = 2)]
    [ValidateRange(2, 10)]
    [int]$BulkCount = [GitHubTrends]::BulkCount
  )

  begin {
    # Save and temporarily set the BulkCount
    $originalBulkCount = [GitHubTrends]::BulkCount
    [GitHubTrends]::BulkCount = $BulkCount
  }

  process {
    try {
      switch ($By) {
        "Stars" { [GitHubTrends]::GetTrendingRepositoriesByStars() }
        "Forks" { [GitHubTrends]::GetTrendingRepositoriesByForks() }
        "Language" {
          if (!$Language) {
            throw "Language is required when By='Language'"
          }
          [GitHubTrends]::GetTrendingRepositoriesByLanguage($Language)
        }
      }
    } catch {
      $PSCmdlet.ThrowTerminatingError($_)  # Rethrow exceptions (e.g., authentication errors)
    }
  }

  end {
    # Restore original BulkCount
    [GitHubTrends]::BulkCount = $originalBulkCount
  }
}