<#
 # Created By:   Tyler.Filkins
 # Created Date: 2017-08-11
 #
 # Description: This script recursively searches for admin group memberships for a given user.
 #
 #
 # *** BEFORE YOU USE THIS SCRIPT! ***
 # Make sure you've installed the Active Directory PowerShell Module or else the cmdlet Get-ADGroup will not work. 
 #
 #>


function findAdminGroup($group_dn)
{
    $group = ($group_dn.split('=')[1]).split(',')[0]

    # if the given group is an admin group then return true
    if ($group -in $global:admin_groups)
    {
        Write-Host "[+] admin group found!!! ----> $group" -ForegroundColor Green
        return $true
    }
    else {
        # otherwise, query AD for the group object
        $result = $false

        $grp = Get-ADGroup -Filter {name -eq $group} -Properties MemberOf
        
        # cycle through the group memberships and start the recursive search
        foreach ($grp_membership in $grp.MemberOf)
        {
            Write-Host "[*] calling recursive findAdminGroup() on $grp_membership" -ForegroundColor DarkYellow
            $result = findAdminGroup($grp_membership)

            # if result is true then add this group to the child groups and break out of the loop
            if ($result) {
                $global:child_groups += [pscustomobject] @{
                    child_group = $grp_membership
                }

                Write-Host "[*] result is true..breaking recursive loop..." -ForegroundColor Cyan
                break
            }
        }
    }
    
    # if result is true then just return result
    if ($result) {
        return $result
    }
    else {
        # otherwise return false
        return $false
    }
}


#-------------------------#
#  EXECUTION STARTS HERE  #
#-------------------------#

# setup global variable to track child groups
$global:child_groups = @()

$global:admin_groups = [pscustomobject] @(
    <#
        ENTER LIST OF ADMIN GROUPS HERE, LIKE:
        
        "domain admins",
        "super users", 
        "super dooper users",
        ...
    
    #>
)

# clear screen and prompt user for target user
clear
$input = Read-Host -Prompt "Enter user to search for"

# get the target user object
$target_user = Get-ADUser -Filter {name -eq $input} -Properties *

if ($target_user)
{
    # cycle through group memberships and recursively search for admin groups
    foreach ($group in $target_user.MemberOf)
    {
        Write-Host "[*] calling findAdminGroup() on $group" -ForegroundColor Yellow

        $result = findAdminGroup($group)

        # if result is true then added group to the child groups and break out of the loop
        if ($result)
        {
            $global:child_groups += [pscustomobject] @{
                child_group = $group
            }

            Write-Host "[*] result is true..breaking initial loop..." -ForegroundColor Cyan
            break
        }
    }

    # output result
    Write-Host "RESULT:`t$result" -ForegroundColor Magenta

    # output child groups
    $count = 1
    foreach ($cgroup in $global:child_groups.child_group)
    {
        $grp_name = ($cgroup.Split('=')[1]).Split(',')[0]

        Write-Host "$count : $grp_name" -ForegroundColor Red

        $count++
    }
}
else {
    # if the target user was not found in AD then pop smoke and bail
    Write-Host "[!] no account found for: $input" -ForegroundColor Red
}