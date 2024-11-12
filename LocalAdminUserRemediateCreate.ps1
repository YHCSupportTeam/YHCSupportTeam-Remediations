$userName = "itinstall@yhc.edu"
$userexist = (Get-LocalUser).Name -Contains $userName
if($userexist -eq $false) {
  try{ 
     New-LocalUser -Name $username -Description "Local Admin Installation Account" -NoPassword
     Exit 0
   }   
  Catch {
     Write-error $_
     Exit 1
   }
} 