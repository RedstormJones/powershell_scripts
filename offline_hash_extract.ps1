<#
 # Created By:   Tyler.Filkins
 # Created Date: 2016-12-29
 #
 # Description: This script performs username and NTLM hash extraction given a system registry hive and ntds.dit database file.
 #>

$date = (Get-Date).GetDateTimeFormats()[5]
$hashlist = @()
$SYSTEM_filepath = 'C:\temp\registry\SYSTEM'
$ntds_filepath = 'C:\temp\Active Directory\ntds.dit'
$export_filepath = "C:\temp\$date.csv"

$bootkey = Get-BootKey -SystemHivePath $SYSTEM_filepath
$ntlm_users = Get-ADDBAccount -All -DBPath $ntds_filepath -BootKey $bootkey

foreach($ntlm_user in $ntlm_users)
{
    # powershell converts the bytes of the hash values from hexadecimal to base 10 and stores them in an
    # array, so we're going to cycle through it and convert them back to hex so we can build a hash string
    $nthash = $ntlm_user.NTHash

    $hash_str = ""

    foreach($n in $nthash)
    {
        $n16 = $n.ToString('X2')

        $hash_str += $n16
    }

    # build a custom object and add it to the list
    $hashlist += [pscustomobject] @{
        'user' = $ntlm_user.SamAccountName
        'hash' = $hash_str
    }

    write-host "$($ntlm_user.SamAccountName) : $hash_str" -ForegroundColor Yellow
    
    [int]$percentcomplete  = ($hashlist.Count / $ntlm_users.Count) * 100
    Write-Progress -Activity "Parsing Hashes:`t$percentcomplete%" -Status "User: $($ntlm_user.SamAccountName)" -PercentComplete $percentcomplete
}

$hashlist | Export-Csv $export_filepath -NoTypeInformation
