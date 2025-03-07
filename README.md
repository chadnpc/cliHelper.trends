
## [cliHelper.trends](https://www.powershellgallery.com/packages/cliHelper.trends)

🔥 A module to collect trends data from different sources.

[![Build Module](https://github.com/chadnpc/cliHelper.trends/actions/workflows/build_module.yaml/badge.svg)](https://github.com/chadnpc/cliHelper.trends/actions/workflows/build_module.yaml)
[![Downloads](https://img.shields.io/powershellgallery/dt/cliHelper.trends.svg?style=flat&logo=powershell&color=blue)](https://www.powershellgallery.com/packages/cliHelper.trends)

## Usage

```PowerShell
Install-Module cliHelper.trends
```

then

```PowerShell
Import-Module cliHelper.trends

$top_python_repos = ghtrends -by Stars -language Python 10
# i.e: ghtrends is alias for the f(x) Get-GitHubTrendingRepositories
```
Output

>NOTE: This module is still in alpha phase. While "graphapi calls and types" work fine, the "trending calculation/algorithm" part is still not done.

## License

This project is licensed under the [WTFPL License](LICENSE).
