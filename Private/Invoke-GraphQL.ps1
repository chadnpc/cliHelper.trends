function Invoke-GraphQL {
  param (
    [string]$Query,
    [string]$Endpoint
  )

  try {
    $response = Invoke-RestMethod -Uri $Endpoint -Body $Query
    if ($response.Errors) {
      throw [GraphQLInvokationException]::new(
        "GraphQL response contains errors",
        "Query: $Query | Errors: $($response.Errors)"
      )
    }
  } catch [System.Net.WebException] {
    throw [GraphQLInvokationException]::new(
      "Network error during GraphQL request",
      "Endpoint: $Endpoint",
      $_.Exception
    )
  }
}