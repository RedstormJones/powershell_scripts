<#
 # Created By:   Tyler.Filkins
 # Created Date: 2016-09-11
 #
 # Description: This script correlates usernames to passwords by cycling through two 
 # separate lists and searching for matching hash values. Matching hash values indicate
 # we have correctly associated a user and their password. After all matches have been
 # found we output the new list to a text file to be used in generating reports.
 #>

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# instantiate date and other variables
$date = (Get-Date).GetDatetimeFormats()[5]
$crackedlist = @()
$count = 0

# import usernames and hashes
$users_hashes = Import-Csv "C:\Temp\$date.csv"

# read in list of cracked hashes
$cracks = Get-Content "C:\Temp\cracks.txt"

# for each user-hash pair, cycle through all hash-password pairs and try to find a matching hash value
foreach($user_hash in $users_hashes)
{
    $found = $false

    foreach($crack in $cracks)
    {
        # if not found
        if(!$found)
        {
            # split off the hash and the password
            $ntlm_hash = $crack.Split(":")[0]
            $passwd = $crack.Split(":")[1]

            # this checks for bible (verse:chapter) passwords and smiley faces
            if($crack.Split(":")[2] -ne $null)
            {
                $passwd += $crack.Split(":")[2]
            }

            # check if the hashes match between the current user-hash pair and hash-password pair
            if($user_hash.hash -eq $ntlm_hash)
            {
                # if we find a match set found to true
                $found = $true

                # save off username to use in progress bar - not necessary but whatever
                $username = $user_hash.user

                # inform the humans
                write-host "hash match found for $username" -ForegroundColor Yellow

                # build custom object and add to cracked list
                $crackedlist += [pscustomobject] @{
                    username = $username
                    password = $passwd
                }
            }
        }
    }

    # keep the humans informed
    [int]$percentComplete = ($count++ / $users_hashes.count) * 100
    Write-Progress -Activity "Enumerating crackedlist: $percentComplete%" -Status "found hash match on: $username" -PercentComplete $percentComplete
}

# once the cracked list is built, cycle through it and output each item to a text file
$count = 0
foreach($crack in $crackedlist)
{
    $crack.username + ":" + $crack.password >> "C:\Temp\$date-cracks.txt"
    
    [int]$percentComplete = ($count++ / $crackedlist.count) * 100
    Write-Progress -Activity "Logging crackedlist: $percentComplete%" -Status "last user logged: $($crack.username)" -PercentComplete $percentComplete
}

$stopwatch.Stop()
$total_mins = $stopwatch.Elapsed.TotalMinutes
Write-Host "[*] hash correlation complete!" -ForegroundColor Green
Write-Host "[*] total elapsed time (in minutes): $total_mins" -ForegroundColor Cyan
