<#
 # Created By:   Tyler.Filkins
 # Created Date: 2017-01-25
 #
 # Description: This script updates the SCCM systems collection file in SpectreSource with new
 #              data from the SCCM all systems report. It authenticates to the SpectreSource 
 #              API and uploads the data one system at a time (it is not very efficient or 
 #              speedy, but it works).
 #
 #>

# authenticate to the Spectre API
function authenticate()
{
    Write-Host "authenticating to Spectre API..." -ForegroundColor Magenta

    add-type -ErrorAction SilentlyContinue @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@

    # ignore warning about untrusted cert
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy -ErrorAction SilentlyContinue

    $body = @{
        username = "get_ur_own"
        password = "dont_tell_no_one"
    }

    $resource = "https://*.*.*.*/api/authenticate"

    $response = Invoke-RestMethod -Method Post -Uri $resource -Body $body

    return $response.token
}



#-------------------------#
#  EXECUTION STARTS HERE  #
#-------------------------#
$count = 0
$allsystems_report_path = '\\network_or_file\path\to\SCCM\all_systems_report'
$allsystems = Import-Csv $allsystems_report_path

# authenticate and capture JWT token
$token = authenticate

$headers = @{
    "Authorization" = "Bearer "+$token
    "Content-Type" = "application/json"
}

# clear the collections file in SpectreSource
$resource = "https://*.*.*.*/api/sccm/clear_upload"

Write-Host "clearing SCCM systems collection file..." -ForegroundColor Magenta
$response = Invoke-RestMethod -Method Get -Uri $resource -Headers $headers

if ($response.success)
{
    # set resource to upload url
    $resource = "https://*.*.*.*/api/sccm/upload"

    Write-Host "starting POST loop..." -ForegroundColor Green

    # cycle through the systems and create a custom PS object list of the data we care about
    foreach($system in $allsystems)
    {
        $data = @()

        $data += [pscustomobject] @{
            system_name = $system.SystemName
            district = $system.District
            region = $system.Region
            group = $system.Group
            owner = $system.Owner
            days_since_last_logon = $system.DaysLastLogon
            stale_45days = $system.Stale45Days
            client_status = $system.ClientStatus
            client_version = $system.ClientVersion
            operating_system = $system.OperatingSystem
            operating_system_version = $system.OperatingSystemVersion
            os_roundup = $system.OSRoundup
            os_arch = $system.OSArch
            system_role = $system.SystemRole
            serial_number = $system.SerialNumber
            chassis_type = $system.ChassisType
            manufacturer = $system.Manufacturer
            model = $system.Model
            processor = $system.Processor
            image_source = $system.ImageSource
            image_date = $system.ImageDate
            coe_compliant = $system.COECompliant
            ps_version = $system.PowerShellVersion
            patch_total = $system.PatchTotal
            patch_installed = $system.PatchInstalled
            patch_missing = $system.PatchMissing
            patch_unknown = $system.PatchUnknown
            patch_percent = $system.PatchPercent
            scep_installed = $system.SCEPInstalled
            cylance_installed = $system.CylanceInstalled
            anyconnect_installed = $system.AnyConnectInstalled
            anyconnect_websecurity = $system.AnyConnectWebSecurity
            bitlocker_status = $system.BitLockerStatus
            tpm_enabled = $system.TPM_IsEnabled
            tpm_activated = $system.TPM_IsActivated
            tpm_owned = $system.TPM_IsOwned
            ie_version = $system.IEVersion
            ad_location = $system.ADLocation
            primary_users = $system.PrimaryUsers
            last_logon_username = $system.LastLogonUserName
            ad_last_logon = $system.ADLastLogon
            ad_password_last_set = $system.ADPasswordLastSet
            ad_modified= $system.ADModified
            sccm_last_heartbeat = $system.SCCMLastHeartBeat
            sccm_management_point = $system.SCCMManagementPoint
            sccm_last_health_eval = $system.SCCMLastHealthEval
            sccm_last_health_result = $system.SCCMLastHealthResult
            report_date = $system.ReportDate
        }

        # convert it to JSON format
        $data_json = ConvertTo-Json $data

        # post it
        $response = Invoke-RestMethod -Method Post -Uri $resource -Body $data_json -Headers $headers

        # output an update
        Write-Host "System posted: $($system.SystemName)" -ForegroundColor Yellow
        [int]$percentcomplete = ($count++ / $allsystems.count) * 100
        Write-Progress -Activity "Enumerating SCCM systems in SpectreSource" -Status "Percent Complete: $percentcomplete %" -PercentComplete $percentcomplete

        # chill out for a second
        #sleep -s 1
    }

    Write-Host "* SCCM Systems to Spectre sync completed! *" -ForegroundColor Green
}
else
{
    Write-Host "Error: $($response.message)" -ForegroundColor Red
}
