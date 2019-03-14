<#
 # Created By:   Tyler.Filkins
 # Created Date: 2016-09-11
 #
 # Description: Calculates basic metrics and generates reports on cracked passwords.
 #>

$stopwatch = [System.Diagnostics.Stopwatch]::startNew()
$test = @()
$cracked_allusers = @()
$weakpwd_users = @()
$date = (Get-Date).GetDateTimeFormats()[5]

# Grab all users from the Kiewit OU and import cracked users
$users = Get-ADUser -Filter * -Properties company,department,office,manager,whenCreated,lastLogon,lastLogonTimestamp,mail
$cracked = Get-Content "C:\Temp\$date-cracks.txt"


<#
 Cycle through imported cracked users, find the corresponding AD user account, check for a null user object
 and do some information checking/formatting, then build the cracked_allusers and weakpwd_users lists.
#>
foreach ($c in $cracked)
{
    $username = $c.Split(':')[0]
    $password = $c.Split(':')[1]

    foreach($u in $users)
    {
        $district = "-"

        if($u.name -eq $username)
        {
            $lastLogon = ($u | select @{n='lastLogon';e={[DateTime]::FromFileTime($_.lastLogonTimestamp)}}).lastLogon

            $cracked_allusers += [pscustomobject] @{
                Username=$username
                Password=$password
                PasswordLength=$password.Length
                Manager=$u.Manager
                WhenCreated=$u.whenCreated.GetDateTimeFormats()[5]
                LastLogon=$lastLogon
                Email=$u.mail
            }

            # check for generally weak passwords
            elseif ($password -like "*password*" -OR
                    $password -like "*welcome*" -OR
                    $password -like "*summer*" -OR
                    $password -like "*winter*" -OR
                    $password -like "*fall*" -OR
                    $password -like "*spring*" -OR
                    $password -like "*$username*" -OR
                    $password.Length -le 7)
            {
                $weakpwd_users += [pscustomobject] @{
                    Username=$username
                    Password=$password
                }

                write-host "found weak password for $username" -ForegroundColor Yellow
            }
        }
    }

    [int]$percentComplete = ($cracked_allusers.count / $cracked.count) * 100
    Write-Progress -Activity "Enumerating cracked users list: $percentComplete%" -Status "on user: $username" -PercentComplete $percentComplete
}

$cracked_allusers | Export-Csv "C:\temp\$date-full-list.csv" -NoTypeInformation
$weakpwd_users | Export-Csv "C:\Temp\wp_$date.csv" -NoTypeInformation

$stopwatch.Stop()
$total_mins = $stopwatch.Elapsed.TotalMinutes
Write-Host "[*] finished generating reports!" -ForegroundColor Green
Write-Host "[*] total elapsed time (in minutes): $total_mins" -ForegroundColor Cyan
