<#
Version: 1.0
Author: James Sanderson
Cleanup disk when utilization <60GB
#> 
Get-Item -Path "C:\Windows\SoftwareDistribution.bak*" -Recurse | Remove-Item