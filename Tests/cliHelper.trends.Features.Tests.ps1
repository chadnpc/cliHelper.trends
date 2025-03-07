Describe "Feature tests: cliHelper.trends" {
  Context "GitHubTrends Class" {
    It "Should retrieve trending repositories by stars" {
      $script:mockQuery = "stars:>1000 sort:stars"
      $mockResponse = @{
        data = @{
          search = @{
            edges = @(
              @{
                node = @{
                  name            = "Repo1"
                  stargazerCount  = 1000
                  forkCount       = 50
                  primaryLanguage = @{
                    name = "Python"
                  }
                  owner           = @{
                    login = "user1"
                  }
                  pushedAt        = "2023-01-01T00:00:00Z"
                  description     = "Sample description"
                  openIssues      = @{
                    totalCount = 10
                  }
                }
              }
            )
          }
        }
      }
      Mock InvokeGraphQLQuery { return $mockResponse }

      # Act
      $result = [GitHubTrends]::GetTrendingRepositoriesByStars()

      # Assert
      $result.Count | Should -Be 1
      $result[0].Name | Should -Be "Repo1"
      $result[0].Stars | Should -Be 1000
    }

    It "Should throw an error when access token is missing" {
      # Arrange
      Mock Read-Env { throw [System.IO.FileNotFoundException]::new("File not found") }
      Mock Get-Content { return $null }

      # Act & Assert
      { [GitHubTrends]::GetAccessToken() } | Should -Throw [FileReadingException]
    }

    It "Should parse valid GraphQL response into GitRepository objects" {
      # Arrange
      $mockGraphQLResult = @{
        data = @{
          search = @{
            edges = @(
              @{
                node = @{
                  name            = "Repo2"
                  stargazerCount  = 2000
                  forkCount       = 100
                  primaryLanguage = @{
                    name = "JavaScript"
                  }
                  owner           = @{
                    login = "user2"
                  }
                  pushedAt        = "2023-01-02T00:00:00Z"
                  description     = "Another repo"
                  openIssues      = @{
                    totalCount = 20
                  }
                }
              }
            )
          }
        }
      }

      # Act
      $repos = [GitHubTrends]::ParseGraphQLResult($mockGraphQLResult)

      # Assert
      $repos.Count | Should -Be 1
      $repos[0].Language | Should -Be "JavaScript"
    }

    It "Should handle invalid GraphQL responses gracefully" {
      # Arrange
      $invalidResponse = @{ data = @{ } }  # Empty search result

      # Act
      $repos = [GitHubTrends]::ParseGraphQLResult($invalidResponse)

      # Assert
      $repos.Count | Should -Be 0
    }

    It "Should throw QueryExecutionException on failed data retrieval" {
      # Arrange
      Mock InvokeGraphQLQuery { return $null }

      # Act & Assert
      { [GitHubTrends]::GetTrendingRepositoriesByForks() } | Should -Throw [QueryExecutionException]
    }
  }

  Context "CsvExportException Handling" {
    It "Should throw CsvExportException on invalid export path" {
      # Arrange
      $mockData = @(
        [PSCustomObject]@{ Name = "Repo3"; Stars = 3000 }
      )
      Mock Export-Csv { throw [System.IO.IOException]::new("Access denied") }

      # Act & Assert
      { [GitHubTrends]::ExportToCsv($mockData, "invalid:\path.csv") } | Should -Throw [CsvExportException]
    }
  }
}