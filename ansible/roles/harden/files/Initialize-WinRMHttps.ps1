#Requires -Version 5.1
<#
.SYNOPSIS
    Ensure a WinRM HTTPS listener on this machine, backed by a self-signed
    certificate that matches the machine's current name.

.DESCRIPTION
    Baked into the vSphere golden template by ansible/roles/harden and run at
    every boot (plus daily) by the 'Initialize-WinRMHttps' scheduled task.

    Why this runs per-machine instead of being configured once at build time:
    a certificate generated during the Packer build would carry the template
    VM's name. Every VM cloned from that template is renamed by vSphere guest
    customisation, so the baked certificate would be wrong everywhere, and all
    clones would share one private key. Generating on the guest fixes both.

    The script is idempotent. Once a listener exists whose certificate matches
    the current hostname and is not near expiry, it does nothing.

    The plaintext listener on 5985 is left alone unless -DisableHttpListener is
    passed: Packer's own provisioning connects over it, and removing it is a
    deploy-time decision rather than a template-wide one.

.NOTES
    Exits 0 even on failure. This runs at boot; a hardening step must never
    block a machine from starting. Failures are recorded in the log file.
#>
[CmdletBinding()]
param(
    [int]$Port = 5986,
    [int]$CertValidityYears = 2,
    [int]$RenewWithinDays = 30,
    [switch]$DisableHttpListener
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Certificates this script owns. Used to distinguish ours from any operator- or
# application-installed certificate, so cleanup never deletes someone else's.
$CertFriendlyName = 'Packer template WinRM HTTPS'
$LogPath = Join-Path $PSScriptRoot 'Initialize-WinRMHttps.log'

function Write-BootLog {
    param([string]$Message, [string]$Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 's'), $Level, $Message
    Write-Output $line
    # Best-effort file logging; never let a logging failure abort the boot script.
    Add-Content -Path $LogPath -Value $line -ErrorAction SilentlyContinue
}

function Get-TargetDnsName {
    <# Names the certificate must cover: short name always, FQDN when domain-joined. #>
    $names = @($env:COMPUTERNAME)
    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        if ($cs.PartOfDomain -and $cs.Domain) {
            $names += ('{0}.{1}' -f $env:COMPUTERNAME, $cs.Domain)
        }
    } catch {
        Write-BootLog "Could not determine domain membership: $($_.Exception.Message)" 'WARN'
    }
    , ($names | Select-Object -Unique)
}

function Get-HttpsListener {
    Get-ChildItem -Path WSMan:\localhost\Listener -ErrorAction SilentlyContinue |
        Where-Object { $_.Keys -contains 'Transport=HTTPS' }
}

function Test-ListenerCurrent {
    <# True when the existing listener's certificate covers this hostname and is not near expiry. #>
    param($Listener, [string[]]$RequiredNames, [int]$RenewWithinDays)

    if (-not $Listener) { return $false }

    $thumbprint = (Get-ChildItem -Path "WSMan:\localhost\Listener\$($Listener.Name)" |
        Where-Object { $_.Name -eq 'CertificateThumbprint' }).Value
    if ([string]::IsNullOrWhiteSpace($thumbprint)) { return $false }

    $cert = Get-Item -Path "Cert:\LocalMachine\My\$($thumbprint -replace '\s', '')" -ErrorAction SilentlyContinue
    if (-not $cert) {
        Write-BootLog 'Listener references a certificate that is no longer in the store.' 'WARN'
        return $false
    }

    if ($cert.NotAfter -le (Get-Date).AddDays($RenewWithinDays)) {
        Write-BootLog "Certificate expires $($cert.NotAfter) - inside the $RenewWithinDays day renewal window."
        return $false
    }

    $certNames = @($cert.DnsNameList | ForEach-Object { $_.Unicode })
    foreach ($required in $RequiredNames) {
        if ($certNames -notcontains $required) {
            Write-BootLog "Certificate does not cover '$required' (has: $($certNames -join ', ')) - machine was likely renamed."
            return $false
        }
    }

    return $true
}

function Set-HttpsListener {
    # Internal helper, always called without -WhatIf. ShouldProcess plumbing
    # would add a -WhatIf no-op path to a boot script for no benefit.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '')]
    param(
        [string[]]$DnsName,
        [int]$ListenerPort,
        [int]$ValidityYears
    )

    Write-BootLog "Creating a self-signed certificate for: $($DnsName -join ', ')"
    $cert = New-SelfSignedCertificate `
        -DnsName $DnsName `
        -CertStoreLocation 'Cert:\LocalMachine\My' `
        -FriendlyName $CertFriendlyName `
        -NotAfter (Get-Date).AddYears($ValidityYears) `
        -KeyExportPolicy NonExportable `
        -KeyUsage DigitalSignature, KeyEncipherment `
        -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.1')  # EKU: serverAuth

    Write-BootLog "Certificate thumbprint $($cert.Thumbprint), valid until $($cert.NotAfter)."

    # Remove any existing HTTPS listener before rebinding - a listener's
    # certificate cannot be swapped in place.
    Get-HttpsListener | ForEach-Object {
        Write-BootLog "Removing existing HTTPS listener '$($_.Name)'."
        Remove-Item -Path "WSMan:\localhost\Listener\$($_.Name)" -Recurse -Force
    }

    New-Item -Path WSMan:\localhost\Listener `
        -Transport HTTPS -Address * -Port $ListenerPort `
        -CertificateThumbPrint $cert.Thumbprint -Force | Out-Null
    Write-BootLog "HTTPS listener bound on port $ListenerPort."

    # Drop superseded certificates this script created previously.
    Get-ChildItem -Path Cert:\LocalMachine\My |
        Where-Object { $_.FriendlyName -eq $CertFriendlyName -and $_.Thumbprint -ne $cert.Thumbprint } |
        ForEach-Object {
            Write-BootLog "Removing superseded certificate $($_.Thumbprint)."
            Remove-Item -Path $_.PSPath -Force
        }
}

function Set-FirewallRule {
    # See Set-HttpsListener: internal helper, no -WhatIf path needed.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '')]
    param([int]$ListenerPort)

    $name = 'WINRM-HTTPS-In-TCP'
    if (Get-NetFirewallRule -Name $name -ErrorAction SilentlyContinue) { return }

    New-NetFirewallRule -Name $name `
        -DisplayName 'Windows Remote Management (HTTPS-In)' `
        -Description 'Inbound rule for WinRM over HTTPS. Added by the Packer template security baseline.' `
        -Group 'Windows Remote Management' `
        -Protocol TCP -LocalPort $ListenerPort -Direction Inbound -Action Allow -Profile Any | Out-Null
    Write-BootLog "Firewall rule '$name' created for TCP/$ListenerPort."
}

function Remove-HttpListener {
    # See Set-HttpsListener: internal helper, no -WhatIf path needed.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '')]
    param()

    $http = Get-ChildItem -Path WSMan:\localhost\Listener -ErrorAction SilentlyContinue |
        Where-Object { $_.Keys -contains 'Transport=HTTP' }
    if (-not $http) { return }

    # Refuse to remove plaintext unless HTTPS is actually listening, otherwise
    # this locks the machine out of remote management entirely.
    if (-not (Get-HttpsListener)) {
        Write-BootLog 'Refusing to remove the HTTP listener: no HTTPS listener is present.' 'WARN'
        return
    }

    $http | ForEach-Object {
        Write-BootLog "Removing plaintext HTTP listener '$($_.Name)'."
        Remove-Item -Path "WSMan:\localhost\Listener\$($_.Name)" -Recurse -Force
    }
}

try {
    if (-not (Test-Path $PSScriptRoot)) { New-Item -Path $PSScriptRoot -ItemType Directory -Force | Out-Null }

    # WinRM must be running before the WSMan: drive is usable.
    $winrm = Get-Service -Name WinRM
    if ($winrm.Status -ne 'Running') {
        Write-BootLog 'Starting the WinRM service.'
        Start-Service -Name WinRM
    }

    $targets = Get-TargetDnsName
    $listener = Get-HttpsListener

    if (Test-ListenerCurrent -Listener $listener -RequiredNames $targets -RenewWithinDays $RenewWithinDays) {
        Write-BootLog "HTTPS listener is current for $($targets -join ', ') - nothing to do."
    } else {
        Set-HttpsListener -DnsName $targets -ListenerPort $Port -ValidityYears $CertValidityYears
    }

    Set-FirewallRule -ListenerPort $Port

    if ($DisableHttpListener) { Remove-HttpListener }

    Write-BootLog 'Completed successfully.'
} catch {
    Write-BootLog "Failed: $($_.Exception.Message)" 'ERROR'
    Write-BootLog $_.ScriptStackTrace 'ERROR'
    # Deliberately exit 0 - see .NOTES.
}

exit 0
