<#
 # Created By:   Tyler.Filkins
 # Created Date: 2016-10-21
 #
 # Description: This script performs recursive queries for the members of Active Directory groups.
 #              If any group members are themselves a group, then the script will also query for 
 #              that groups members, and so on..
 #>

function getGroupMembers($group)
{
    $names_list = @()

    foreach($name in $group.Members)
    {
        if($name -like "*Groups*")
        {
            $grp = Get-ADGroup $name -Properties Members
            $names_list += getGroupMembers($grp)
        }
        else
        {
            $obj = [pscustomobject] @{
                name = ($name.Split('=')[1]).Split(',')[0]
                group = $group.name }
            $names_list += $obj
        }
    }
    return $names_list
}


#-------------------------#
#  EXECUTION STARTS HERE  #
#-------------------------#
$date = (Get-Date).GetDateTimeFormats()[5]
$group_members_list = @()
$export_filepath = "C:\temp\$date.csv"
$searchbase = "<AD_search_base>"

$groups = Get-ADGroup -Filter * -Properties * -SearchBase $searchbase

foreach($group in $groups)
{
    $group_members_list += getGroupMembers($group)
}


$group_members_list | Export-Csv $export_filepath -NoTypeInformation

