#!/usr/bin/env pwsh
using namespace System.Net.Http
using namespace System.Threading
using namespace System.Collections.Generic

#Requires -Modules cliHelper.env, cliHelper.xcrypt, cliHelper.xconvert

#region    Classes
class FileReadingException : System.IO.IOException {
  hidden [int] $LineNumber
  hidden [string] $ProblematicLine

  FileReadingException([string]$FullyQualifiedErrorId, [int]$lineNumber, [string]$additionalinfo) : base($FullyQualifiedErrorId) {
    $this.LineNumber = $lineNumber
    $this.ProblematicLine = $additionalinfo
  }

  FileReadingException([string]$FullyQualifiedErrorId, [int]$lineNumber, [string]$additionalinfo, [Exception]$innerException) : base($FullyQualifiedErrorId, $innerException) {
    $this.LineNumber = $lineNumber
    $this.ProblematicLine = $additionalinfo
  }
}

class QueryExecutionException : System.Exception {
  hidden [int] $IterationNumber
  QueryExecutionException([string]$message, [int]$iteration) : base($message) {
    $this.IterationNumber = $iteration
  }
  QueryExecutionException([string]$message, [int]$iteration, [Exception]$innerException) : base($message, $innerException) {
    $this.IterationNumber = $iteration
  }
}

class GraphQLInvokationException : System.Exception {
  hidden [string] $AdditionalInfo
  GraphQLInvokationException([string]$message, [string]$additionalInfo) : base($message) {
    $this.AdditionalInfo = $additionalInfo
  }
  GraphQLInvokationException([string]$message, [string]$additionalInfo, [Exception]$innerException ) : base($message, $innerException) {
    $this.AdditionalInfo = $additionalInfo
  }
}

class CsvExportException : System.Exception {
  hidden [string] $AdditionalInfo
  CsvExportException([string]$message, [string]$additionalInfo) : base($message) {
    $this.AdditionalInfo = $additionalInfo
  }
  CsvExportException([string]$message, [string]$additionalInfo, [Exception]$innerException) : base($message, $innerException) {
    $this.AdditionalInfo = $additionalInfo
  }
}

class GitRepository {
  [string]$Description
  [long]$Forks
  [string]$Language
  [datetime]$LastCommit
  [string]$Name
  [long]$OpenIssues
  [string]$Owner
  [long]$Stars
  [string]$Url
}
# Main class
class GitHubTrends {
  # .SYNOPSIS
  #     Retrieves trending GitHub repositories and exports data in CSV format.

  # .DESCRIPTION
  #     This powershell class uses the GitHub GraphQL API to fetch trending repositories based on stars, forks, and languages.
  #     It provides an interface to retrieve and process this data,
  #     making it easy to integrate into PowerShell modules or scripts. The output is CSV data, suitable for further analysis or reporting.

  # .NOTES
  #     Requires a GitHub access token stored in 'access_token.txt' in the parent directory.
  #     Ensure you have PowerShell version 5.1 or later for class support.

  # .EXAMPLE
  #     # Get top 100 starred repositories and export to CSV
  #     [GitHubTrends]::GetTrendingRepositoriesByStars() | Export-Csv -Path "Top-100-stars.csv" -NoTypeInformation

  # .EXAMPLE
  #     "Getting Top 100 Starred Repositories..."
  #     $topStarredRepos = [GitHubTrends]::GetTrendingRepositoriesByStars()
  #     [GitHubTrends]::ExportToCsv($topStarredRepos, "../Data/Top-100-stars.csv")

  #     "Getting Top 100 Forked Repositories..."
  #     $topForkedRepos = [GitHubTrends]::GetTrendingRepositoriesByForks()
  #     [GitHubTrends]::ExportToCsv($topForkedRepos, "../Data/Top-100-forks.csv")

  #     "Getting Top 100 Starred Repositories by Language..."
  #     $topLanguageRepos = [GitHubTrends]::GetAllTrendingRepositoriesByLanguage()
  #     if ($topLanguageRepos) {
  #       foreach ($language in $topLanguageRepos.Keys) {
  #         $reposForLang = $topLanguageRepos[$language]
  #         $safeLanguageName = $language -replace '[#+ ]', '_' # Make language name safe for filenames
  #         [GitHubTrends]::ExportToCsv($reposForLang, "../Data/Top-100-$safeLanguageName-stars.csv")
  #       }
  #     }

  # .EXAMPLE
  #     # Get top 100 Python starred repositories and export to CSV
  #     [GitHubTrends]::GetTrendingRepositoriesByLanguage("Python") | Export-Csv -Path "Top-100-python-stars.csv" -NoTypeInformation

  # Static Properties
  static [ValidateNotNullOrEmpty()][securestring]$accesstoken
  static [int]$BulkCount = 2
  static [string[]]$Languages = @(
    "ActionScript", "C", "CSharp", "CPP", "Clojure", "CoffeeScript", "CSS", "Dart", "DM", "Elixir", "Go", "Groovy", "Haskell", "HTML", "Java",
    "JavaScript", "Julia", "Kotlin", "Lua", "MATLAB", "Objective-C", "Perl", "PHP", "PowerShell", "Python", "R", "Ruby", "Rust", "Scala", "Shell",
    "Swift", "TeX", "TypeScript", "Vim script"
  )
  GitHubTrends() {}

  static [securestring] GetAccessToken() {
    try {
      if ($null -ne [GitHubTrends]::accesstoken) {
        return [GitHubTrends]::accesstoken
      }
      [string]$token = (Read-Env ([xcrypt]::GetUnResolvedPath(".env")) | Where-Object { $_.Name -eq "GITHUB_ACCESS_TOKEN" }).value
      if ([string]::IsNullOrWhiteSpace($token)) {
        throw [System.InvalidOperationException]::new("accesstoken not found")
      }
      [GitHubTrends]::accesstoken = $token | xconvert ToSecurestring
      return [GitHubTrends]::accesstoken
    } catch {
      throw [FileReadingException]::new($_.Exception.Message.Replace(' ', '_'), 0, '', $_.Exception)
    }
  }
  static [Object[]] InvokeGraphQLQuery([string]$GraphQLQuery) {
    $token = [GitHubTrends]::GetAccessToken() | xconvert Tostring
    if ([string]::IsNullOrWhiteSpace($token)) {
      return $null # Exit if no access token
    }
    $headers = @{
      'User-Agent'    = 'PowerShell Script'
      'Authorization' = "bearer $($token)"
      'Content-Type'  = 'application/json'
      'Accept'        = 'application/json'
    }
    $endpoint = "https://api.github.com/graphql"
    $body = @{
      query = $GraphQLQuery
    } | ConvertTo-Json

    try {
      $response = Invoke-WebRequest -Uri $endpoint -Method Post -Headers $headers -Body $body -ContentType 'application/json' -UseBasicParsing -SkipHttpErrorCheck -Verbose:$false
      if ($response.StatusCode -ne 200) { throw [HttpRequestException]::new("GraphQL API request failed with status code $($response.StatusCode): $($response.Content)") }
      return $response.Content | ConvertFrom-Json
    } catch {
      throw [GraphQLInvokationException]::new("Error invoking GraphQL query", "Endpoint: $endpoint Message: $($_.Exception.Message)", $_.Exception)
    }
  }

  static [GitRepository[]] ParseGraphQLResult([object]$GraphQLResult) {
    $repos = @()
    if ($GraphQLResult -and $GraphQLResult.data -and $GraphQLResult.data.search -and $GraphQLResult.data.search.edges) {
      foreach ($edge in $GraphQLResult.data.search.edges) {
        $repoNode = $edge.node
        $repo = [PSCustomObject]@{
          Name        = $repoNode.name
          Stars       = $repoNode.stargazerCount
          Forks       = $repoNode.forkCount
          Language    = $repoNode.primaryLanguage ? $repoNode.primaryLanguage.name : [string]::Empty
          Url         = $repoNode.url
          Owner       = $repoNode.owner.login
          OpenIssues  = $repoNode.openIssues.totalCount
          LastCommit  = $repoNode.pushedAt
          Description = $repoNode.description
        }
        $repos += $repo
      }
    }
    return $repos
  }
  static [GitRepository[]] GetTrendingRepositories([string]$QueryBase) {
    return [GitHubTrends]::GetTrendingRepositories($QueryBase, 50)
  }
  static [GitRepository[]] GetTrendingRepositories([string]$QueryBase, [int]$BulkSize) {
    $cursor = ""
    $allRepos = @()
    for ($i = 0; $i -lt [GitHubTrends]::BulkCount; $i++) {
      $graphQLQuery = @"
            query {
              search(query: "$($QueryBase)$($cursor)", type: REPOSITORY, first: $BulkSize) {
                pageInfo {
                  endCursor
                }
                edges {
                  node {
                    ... on Repository {
                      id
                      name
                      url
                      forkCount
                      stargazerCount
                      owner {
                        login
                      }
                      description
                      pushedAt
                      primaryLanguage {
                        name
                      }
                      openIssues: issues(states: OPEN) {
                        totalCount
                      }
                    }
                  }
                }
              }
            }
"@
      $graphQLResult = [GitHubTrends]::InvokeGraphQLQuery($graphQLQuery)
      if ($graphQLResult) {
        $repos = [GitHubTrends]::ParseGraphQLResult($graphQLResult)
        $allRepos += $repos
        $cursor = ", after:`"" + $graphQLResult.data.search.pageInfo.endCursor + "`"" # Prepare cursor for next page
      } else {
        throw [QueryExecutionException]::new("Data retrieval failed", $i + 1)
      }
      [Thread]::Sleep(2000) # Respect API rate limits
    }
    return $allRepos
  }

  static [GitRepository[]] GetTrendingRepositoriesByStars() {
    Write-Verbose "Fetching repositories by stars..."
    $query = "stars:>1000 sort:stars"
    return [GitHubTrends]::GetTrendingRepositories($query)
  }

  static [GitRepository[]] GetTrendingRepositoriesByForks() {
    Write-Verbose "Fetching repositories by forks..."
    $query = "forks:>1000 sort:forks"
    return [GitHubTrends]::GetTrendingRepositories($query)
  }

  static [GitRepository[]] GetTrendingRepositoriesByLanguage([string]$Language) {
    Write-Verbose "Fetching repositories by stars for language '$Language'..."
    $query = "language:`"$($Language)`" stars:>0 sort:stars"
    return [GitHubTrends]::GetTrendingRepositories($query)
  }

  static [GitRepository[]] GetAllTrendingRepositoriesByLanguage() {
    $allLanguageRepos = @{}
    foreach ($lang in [GitHubTrends]::Languages) {
      Write-Verbose "Fetching repositories for language '$lang'..."
      $allLanguageRepos[$lang] = [GitHubTrends]::GetTrendingRepositoriesByLanguage($lang)
    }
    return $allLanguageRepos
  }

  static [void] ExportToCsv([List[PSCustomObject]]$RepositoryData, [string]$FilePath) {
    if ($RepositoryData) {
      try {
        $RepositoryData | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8
        Write-Verbose "Data exported to '$FilePath'"
      } catch {
        throw [CsvExportException]::new("Error exporting to CSV", 'export_to_csv_failed', $_.Exception)
      }
    } else {
      throw [System.IO.InvalidDataException]::new("No repository data to export.")
    }
  }
}
#endregion Classes

# Types that will be available to users when they import the module.
$typestoExport = @(
  [GitHubTrends], [GitRepository], [FileReadingException], [QueryExecutionException],
  [GraphQLInvokationException], [QueryExecutionException], [FileReadingException], [CsvExportException]
)
$TypeAcceleratorsClass = [PsObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
foreach ($Type in $typestoExport) {
  if ($Type.FullName -in $TypeAcceleratorsClass::Get.Keys) {
    $Message = @(
      "Unable to register type accelerator '$($Type.FullName)'"
      'Accelerator already exists.'
    ) -join ' - '
    "TypeAcceleratorAlreadyExists $Message" | Write-Debug
  }
}
# Add type accelerators for every exportable type.
foreach ($Type in $typestoExport) {
  $TypeAcceleratorsClass::Add($Type.FullName, $Type)
}
# Remove type accelerators when the module is removed.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
  foreach ($Type in $typestoExport) {
    $TypeAcceleratorsClass::Remove($Type.FullName)
  }
}.GetNewClosure();

$scripts = @();
$Public = Get-ChildItem "$PSScriptRoot/Public" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
$scripts += Get-ChildItem "$PSScriptRoot/Private" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
$scripts += $Public

foreach ($file in $scripts) {
  Try {
    if ([string]::IsNullOrWhiteSpace($file.fullname)) { continue }
    . "$($file.fullname)"
  } Catch {
    Write-Warning "Failed to import function $($file.BaseName): $_"
    $host.UI.WriteErrorLine($_)
  }
}

$Param = @{
  Function = $Public.BaseName
  Cmdlet   = '*'
  Alias    = '*'
  Verbose  = $false
}
Export-ModuleMember @Param
