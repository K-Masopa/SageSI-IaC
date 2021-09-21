<#
.Synopsis
    Adds or updates Route53 NS records from CloudFormation into CloudFlare
.DESCRIPTION
    Adds or updates Route53 NS records from CloudFormation into CloudFlare
.PARAMETER Email
    (MANDATORY) E-mail used to authenticate with CloudFlare
.PARAMETER Key
    (MANDATORY) API key used to authenticate with CloudFlare
.PARAMETER Zone
    (MANDATORY) CloudFlare Zone ID
.PARAMETER Type
    (MANDATORY) Record type
.PARAMETER Name
    (MANDATORY) Record name
.PARAMETER Content
    (MANDATORY) Record content
.PARAMETER Proxied
    (MANDATORY) Record proxied (bool)
    
.EXAMPLE
    .\Update-CloudflareRecord.ps1 -Email xxx@yyy.com -Key secret -Zone abcdef123459 -Type A -Name test -Content 127.0.0.1 -Proxied $false
.NOTES
    Author: Karl Barbour <karl.barbour@sage.com>
#>

[CmdletBinding()]
Param
(
    # CloudFlare auth email
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]
    $Email,

    # CloudFlare auth key
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]
    $Key,

    # CloudFlare Zone ID
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]
    $Zone,

    # Record Type
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]
    $Type,

    # Record Name
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]
    $Name,

    # Record Name
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]
    $Content,

    # Proxied
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [Boolean]
    $Proxied
)

# Timestamp function
function timestamp { return "[$(Get-Date)]" }

# Force TLS 1.2 - required for CloudFlare API
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "$(timestamp) Starting Script: Update Cloudflare DNS Record"

# Build CURL - Common parameters
$uri = "https://api.cloudflare.com/client/v4/zones/$($Zone)/dns_records"
$headers = @{
    "X-Auth-Email" = $Email
    "X-Auth-Key"   = $Key
}

# Check if $Name already exists
Write-Host "`r`n$(timestamp) Checking if record '$($Name)' exists in zone $($Zone)"
$propertiesGet = @{
    Uri         = $uri + "?name=$Name"
    Headers     = $headers
    ContentType = 'application/json'
    Method      = "GET"
}

$results = Invoke-RestMethod @propertiesGet

$existingId = ($results.Result).Id

if ($existingId.Count -eq 1) {
    Write-Host "$(timestamp) Existing record found with id $($existingId)"

    # Rule exists, lets update
    Write-Host "`r`n$(timestamp) Updating existing record with id $($existingId)" 
    $body = @{
        type    = $Type
        name    = $Name
        content = $Content
        proxied = $Proxied
    }
    $body = $body | ConvertTo-Json

    $propertiesPost = @{
        Uri         = $uri + "/" + $existingId
        Headers     = $headers
        ContentType = 'application/json'
        Method      = "PUT"
        Body        = $body
    }

    Write-Host "$(timestamp) Sending CURL..."
    $propertiesPost
    $postResults = Invoke-RestMethod @propertiesPost
    $postResults
}
else {
    Write-Host "$(timestamp) Existing rule not found"

    # Rule does not exist, lets create
    Write-Host "`r`n$(timestamp) Creating new record" 

    $body = @{
        type    = $Type
        name    = $Name
        content = $Content
        proxied = $Proxied
    }
    $body = $body | ConvertTo-Json

    $propertiesPost = @{
        Uri         = $uri
        Headers     = $headers
        ContentType = 'application/json'
        Method      = "POST"
        Body        = $body
    }

    Write-Host "$(timestamp) Sending CURL..."
    $propertiesPost
    $postResults = Invoke-RestMethod @propertiesPost
    $postResults
}

Write-Host "`r`n$(timestamp) Completing Script: Update CloudFlare DNS Record" -ForegroundColor Magenta
