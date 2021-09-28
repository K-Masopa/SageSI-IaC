[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    $Environment
)

######

# Functions
function Get-TimeStamp {
   return "[$(Get-Date)]"   
}

# Get env file
$envFile = "./env/$($Environment).json"
Write-Host "$(Get-Timestamp) Attempting to open env file: $($envFile)"
$envJson = Get-Content $envFile -ErrorAction Stop | ConvertFrom-Json

# Create output location
if (Test-Path "./parameters-final/") { 
   Remove-Item "./parameters-final/" -Recurse -Force
} 
New-Item "./parameters-final" -ItemType Directory -Force 

# Loop through param files and replace
foreach ($stack in $envJson.PSObject.Properties.Name) {
   Write-Host "$(Get-Timestamp) Processing stack: $stack"

   # Open parameter file
   $paramFile = "./parameters/$($stack).json"
   Write-Host "$(Get-Timestamp) > Attempting to open param file: $($paramFile)"
   $paramContent = Get-Content $paramFile 

   # Replace key-values in file
   Write-Host "$(Get-TimeStamp) > Replacing values in param file: $($paramFile)"
   foreach ($param in $envJson.$stack.PSObject.Properties) {
      Write-Host "- $($param.Name)"
      $paramContent = $paramContent -Replace "#{$($param.Name)}#", "$($param.Value)"
   }

   # Output temporary file
   $outFile = "./parameters-final/$($stack).json"
   Write-Host "$(Get-TimeStamp) > Outputting final file: $($outFile)"
   $paramContent | Out-File $outFile
}

Write-Host "$(Get-Timestamp) Done"