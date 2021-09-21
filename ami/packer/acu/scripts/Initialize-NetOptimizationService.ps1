Begin{

}

Process{
    if(-not([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
        $Arguments = "& '" + $MyInvocation.MyCommand.Definition + "'"
        Start-Process PowerShell.exe -Verb RunAs -ArgumentList $Arguments
        Break
    }

    Write-Output "Start optimization..."

    # Set ngen path
    $net_path = Join-Path -Path $env:windir -ChildPath "Microsoft.NET"

    $ngen_paths = @()
    if($env:PROCESSOR_ARCHITECTURE -eq "AMD64")
    {
        $ngen_path64 = Join-Path -Path $net_path -ChildPath "Framework64\ngen.exe"
        $ngen_path32 = Join-Path -Path $net_path -ChildPath "Framework\ngen.exe"
        $ngen_paths += $ngen_path64
        $ngen_paths += $ngen_path32
    }
    else
    {
        $ngen_path32 = Join-Path -Path $net_path -ChildPath "Framework\ngen.exe"
        $ngen_paths += $ngen_path32
    }

    foreach ($path in $ngen_paths) {
        Write-Output "Start optimization... $ngen_application_path"
        $ngen_application_path = (Get-ChildItem -Path $path -Filter "ngen.exe" -Recurse | Where-Object {$_.Length -gt 0} | Select-Object -Last 1).Fullname
        Set-Alias -Name ngen -Value $ngen_application_path
        # call ngen.exe and rebuild and queueed items.
        ngen executequeueditems /silent /nologo | Out-Null
        Write-Output "Finished optimization... $ngen_application_path"
    } 
}

End {
    
    foreach ($path in $ngen_paths) {
        $ngen_application_path = (Get-ChildItem -Path $path -Filter "ngen.exe" -Recurse | Where-Object {$_.Length -gt 0} | Select-Object -Last 1).Fullname
        Set-Alias -Name ngen -Value $ngen_application_path
        $status =  ngen executequeueditems /nologo 
        if ($status -ne 'All compilation targets are up to date.') {
            Write-Output "ERROR! $status"
            $exitcode = 1
        }
        else {
            Write-Output 'SUCCESS! All compilation targets are up to date.'
            $exitcode = 0
        }
    } 

    exit $exitcode

}