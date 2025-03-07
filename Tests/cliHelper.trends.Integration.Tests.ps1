Describe "Integration tests: cliHelper.trends" {
  Context "Get-GitHubTrendingRepositories Function" {
    BeforeAll {
      # Mock dependencies
      $script:mockRepos = @(
        [PSCustomObject]@{
          Name        = "Repo4"
          Stars       = 4000
          Forks       = 200
          Language    = "Go"
          Url         = "https://github.com/repo4"
          Owner       = "user3"
          OpenIssues  = 30
          LastCommit  = "2023-01-03T00:00:00Z"
          Description = "Integration test repo"
        }
      )

      Mock GetTrendingRepositoriesByStars { return $mockRepos }
      Mock GetTrendingRepositoriesByLanguage { return $mockRepos }
    }

    It "Should return repositories when querying by stars" {
      # Act
      $result = Get-GitHubTrendingRepositories -By Stars

      # Assert
      $result.Count | Should -Be 1
      $result[0].Name | Should -Be "Repo4"
    }

    It "Should return repositories for a specific language" {
      # Act
      $result = Get-GitHubTrendingRepositories -By Language -Language "Go"

      # Assert
      $result.Count | Should -Be 1
      $result[0].Language | Should -Be "Go"
    }

    It "Should throw when invalid 'By' parameter is used" {
      # Act & Assert
      { Get-GitHubTrendingRepositories -By Invalid } | Should -Throw "Specified parameter name 'Invalid' was not recognized"
    }

    It "Should require Language when By=Language" {
      # Act & Assert
      { Get-GitHubTrendingRepositories -By Language } | Should -Throw "Language is required when By='Language'"
    }
  }

  Context "Export-GitHubTrendingToCsv Function" {
    BeforeAll {
      $script:mockData = @(
        [PSCustomObject]@{
          Name     = "Repo5"
          Stars    = 5000
          Forks    = 300
          Language = "C#"
          Url      = "https://github.com/repo5"
        }
      )
    }

    It "Should export data to CSV successfully" {
      # Arrange
      $testPath = "TestDrive:\repos.csv"
      Mock Export-Csv { return $true }

      # Act
      Export-GitHubTrendingToCsv -InputObject $mockData -Path $testPath

      # Assert
      Test-Path $testPath | Should -Be $true
    }

    It "Should handle CSV export errors" {
      # Arrange
      $invalidPath = "invalid:\path.csv"
      Mock Export-Csv { throw [System.IO.IOException] }

      # Act & Assert
      { Export-GitHubTrendingToCsv -InputObject $mockData -Path $invalidPath } | Should -Throw [CsvExportException]
    }
  }

  Context "End-to-End Workflow" {
    It "Should fetch and export repositories by stars" {
      # Arrange
      $mockRepos = @(
        [PSCustomObject]@{
          Name     = "Repo6"
          Stars    = 6000
          Forks    = 400
          Language = "Rust"
        }
      )
      Mock GetTrendingRepositoriesByStars { return $mockRepos }
      Mock ExportToCsv { return $true }

      # Act
      $outputPath = "TestDrive:\end-to-end.csv"
      Get-GitHubTrendingRepositories -By Stars | Export-GitHubTrendingToCsv -Path $outputPath

      # Assert
      Test-Path $outputPath | Should -Be $true
    }
  }
}