<#
Version: 1.0
Author: James Sanderson
Cleanup disk when utilization <60GB
#> 
$storageThreshold = 60

$utilization = (Get-PSDrive | Where {$_.name -eq "C"}).free

if(($storageThreshold *1GB) -lt $utilization){exit 0}
else{exit 1}