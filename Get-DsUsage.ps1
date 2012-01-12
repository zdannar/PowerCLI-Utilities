function Get-DsUsage {
<#
.SYNOPSIS
  This commandlet provides a more complete look at a datastore than currently 
  provided by the Get-Datastore commandlet of the PowerCLI.  
.DESCRIPTION
  Currently the Get-Datastore commandlet provided by the VMWare's PowerCLI does 
  not show the provisioned space of a datastore.  If you are not familiar with 
  "Provisioned Space", this is the actual disk space that you have used/left on a 
  host machine.  Due to thin provisioning, it is often hard to tell how much space
  is actually left on a datastore. You can find the information from the storage
  view of the Vsphere client but it was not easily accessible through the PowerCLI.
  Get-DsUsage also provides the ability to choose units of measure that you would
  prefer "MB","GB","TB" or "HUMAN".  The "HUMAN" unit converts to the largest unit
  when displaying data.  There is a shortcut switch called -Human for this as well.
.PARAMETER VMHost
  A VMHost object to interrogate datastores.  This parameter can be taken from a 
  pipeline as well.
.PARAMETER Unit
  What unit to to provide the output in.  You are able to use "MB", "GB", "TB" and
  "HUMAN".  Note that "MB" is the default when a specified unit is not provided.
  A unit of "human" converts to the largest unit for display. 
.PARAMETER Human
  Simple shortcut switch for -Unit "human".
.EXAMPLE
  Get-VMHost | Get-DsUnit -h
.LINK
  Get-Datastore
  http://communities.vmware.com/community/vmtn/server/vsphere/automationtools/powercli
#>

    param(
        [Parameter(
            Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)
        ]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]
        ${VMHost},

        [Parameter(Mandatory=$false)]
        [System.String]${Unit} = 'MB',

        [Switch]${Human} = $false
    )


    begin {
    
        function Convert-Unit {
            param(
                [System.Int64] $size,
                $du = $false
            )
    
            if ($du -eq "TB") { 
                return ($size * 1MB)/1TB
            } elseif ($du -eq "GB") {
                return ($size * 1MB)/1GB
            } elseif ($du -eq "MB") {
                return $size
            } else {
                Write-Error -ErrorAction "Stop" -Message "Unknown UNIT : $du" 
            }
        }
    
        function Get-DesiredUnit { 
            param(
                [System.Int64] $size,
                $desunit = $false
            )
    
            # The default unit returned by Get-Datastore
            if ($desunit -eq $false) {
    
                return $size, 'MB'
    
            } elseif ($desunit -eq "HUMAN") {
    
                if ( (($size*1MB)/1TB) -gt 1 ) {
                    $my_unit = 'TB'
                } elseif ((($size*1MB)/1GB) -gt 1) {   
                    $my_unit = 'GB'
                } else {
                    $my_unit = 'MB'
                }
    
            } else {
    
                $my_unit = $desunit
    
            } 
            $magnitude = Convert-Unit -Size $size -Du $my_unit 
            return $magnitude, $my_unit
        }
    }    

    process {

        if ($Human) { $Unit = "HUMAN" }
        $unit = $Unit.ToUpper() 
    
        $ds_objects = @()
        Get-Datastore -VMHost $VMHost | % {
          
            $ds_obj = New-Object PsObject
     
            Add-Member -MemberType NoteProperty -InputObject $ds_obj -Name "Name" -Value $_.Name
            
            $fsize, $sz_unit =  Get-DesiredUnit -Size $_.CapacityMB -Desunit $unit
            Add-Member -MemberType NoteProperty -InputObject $ds_obj -Name "Size" -Value ('{0,0:f1} {1}' -f $fsize,$sz_unit)
    
    
    
            $used_space = $_.CapacityMB - $_.FreeSpaceMB
    
            $fu_space, $fs_unit = Get-DesiredUnit -Size $used_space -DesUnit $unit
            Add-Member -MemberType NoteProperty -InputObject $ds_obj -Name "Used" -Value ('{0,0:f1} {1}' -f $fu_space,$fs_unit)
    
            $thic_alc_percentage = "{0,0:f2}" -f ($used_space/$_.CapacityMB*100)
            Add-Member -MemberType NoteProperty -InputObject $ds_obj -Name "Used (%)" -Value $thic_alc_percentage
    
    
            # This is where the magic happens
            $ds_view = $_ | Get-View
            $ds_view.RefreshDatastoreStorageInfo()
            $act_size = (($ds_view.Summary.Capacity - $ds_view.Summary.FreeSpace) + $ds_view.Summary.Uncommitted)/1MB
    
    
            $new_act_size, $act_unit = Get-DesiredUnit -Size $act_size -Desunit $unit
            Add-Member -MemberType NoteProperty -InputObject $ds_obj -Name "Act. Used" -Value ('{0,0:f1} {1}' -f $new_act_size,$act_unit)
    
    
            $act_alloc_perc = "{0,0:f2}" -f ($act_size/$_.CapacityMB*100)
            Add-Member -MemberType NoteProperty -InputObject $ds_obj -Name "Act. Used(%)" -Value $act_alloc_perc
    
            $ds_objects += $ds_obj
        }
    
        Write-Host "`n[ VMHost : $VMHost ]"
        $ds_objects | ft -Auto @{Name = 'Name'; Expression = {$_.Name}; Alignment = 'left'},
                               @{Name = 'Size'; Expression = {$_.Size}; Alignment = 'right'},
                               @{Name = 'Used'; Expression = {$_.Used}; Alignment = 'right'},
                               @{Name = 'Used (%)'; Expression = {$_."Used (%)"}; Alignment = 'right'},
                               @{Name = 'Provisioned'; Expression = {$_."Act. Used"}; Alignment = 'right'},
                               @{Name = 'Provisioned(%)'; Expression = {$_."Act. Used(%)"}; Alignment = 'right'}
   } 
  

}
