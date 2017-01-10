<#------------------------------------------------------------------------------
    Jason McClary
    mcclarj@mail.amc.edu
    10 Jan 2017

    
    Description:
    Restart SQL and all dependant services on the EFR server.
        Acs.ADSyncService
        Acs.DataCollection.Server
        Acs.Portals.Service
        MSSQLSERVER
        SQLServerAgent

    
    Arguments:
    computer name
        
    Tasks:
    - Save free memory and total handle count before
    - Stop services
    - Sart Services
    - Send alerts on any issues
    - Save free memory and total handle count after



--------------------------------------------------------------------------------
                                CONSTANTS
------------------------------------------------------------------------------#>
#Date/ Time Stamp
$dtStamp = Get-Date -UFormat "%Y%m%d"     #http://ss64.com/bash/date.html#format
<#------------------------------------------------------------------------------
                                Script Variables
------------------------------------------------------------------------------#>
$ErrorActionPreference = "Stop"

## Format arguments from none, list or text file 
IF (!$args){
    $compNames = $env:computername # Get the local computer name
} ELSE {
    $passFile = Test-Path $args

    IF ($passFile -eq $True) {
        $compNames = get-content $args
    } ELSE {
        $compNames = $args
    }
}

set-variable logOutput -option Constant -value "\\edmmgt01\d$\Server_Checks\ServerReports\EFR_Services_$dtStamp.log"

$logDate = Get-Date -Format d
$logTime = Get-Date -Format T

<#------------------------------------------------------------------------------
                                FUNCTIONS
------------------------------------------------------------------------------#>

function ssService ($ServiceName, $ServiceState) {
    SWITCH ($ServiceState){
        stop {
                TRY {
                    $logTime = Get-Date -Format T
                    "$($logDate) $($logTime): Stopping $ServiceName" >> "$logOutput"
                    Get-Service -Name $ServiceName -ComputerName $compName | Stop-Service
                    $logTime = Get-Date -Format T
                    "$($logDate) $($logTime): *** SUCCESSFULLY stopped $ServiceName ***" >> "$logOutput"
                } CATCH {
                    $ErrorMessage = $_.Exception.Message
                    $logTime = Get-Date -Format T
                    "$($logDate) $($logTime): $ErrorMessage" >> "$logOutput"
                }; break
        }
        default{
                TRY {
                    $logTime = Get-Date -Format T
                    "$($logDate) $($logTime): Starting $ServiceName" >> "$logOutput"
                    Get-Service -Name $ServiceName -ComputerName $compName | Start-Service
                    $logTime = Get-Date -Format T
                    "$($logDate) $($logTime): *** SUCCESSFULLY started $ServiceName ***" >> "$logOutput"
                } CATCH {
                    $ErrorMessage = $_.Exception.Message
                    $logTime = Get-Date -Format T
                    "$($logDate) $($logTime): $ErrorMessage" >> "$logOutput"
                }; break
        }
    }
}    



<#------------------------------------------------------------------------------
                                    MAIN
------------------------------------------------------------------------------#>

FOREACH ($compName in $compNames) {
    $logTime = Get-Date -Format T
    "Restarting services on $compName - $($logDate) $($logTime)
     " >> "$logOutput"
    TRY {
        $totalHandles = (Get-Counter -Counter "\\$compName\Process(_total)\Handle Count").CounterSamples
        $totalHandles = $totalHandles[0].CookedValue
        "Total Handles in use = $totalHandles" >> "$logOutput"

        $freeMem = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $compName
        $freeMem = ([math]::round(100 - (((($freemem.TotalVisibleMemorySize - $freemem.FreePhysicalMemory) / $freemem.TotalVisibleMemorySize)) * 100), 0))
        "Percent of memory free = $freeMem%" >> "$logOutput"

        ssService -ServiceName "SQLServerAgent" -ServiceState "Stop"
        ssService -ServiceName "Acs.ADSyncService" -ServiceState "Stop"
        ssService -ServiceName "Acs.DataCollection.Server" -ServiceState "Stop"
        ssService -ServiceName "Acs.Portals.Service" -ServiceState "Stop"
        ssService -ServiceName "MSSQLSERVER" -ServiceState "Stop"
        
        ssService -ServiceName "MSSQLSERVER" -ServiceState "Start"
        ssService -ServiceName "Acs.Portals.Service" -ServiceState "Start"
        ssService -ServiceName "Acs.DataCollection.Server" -ServiceState "Start"
        ssService -ServiceName "Acs.ADSyncService" -ServiceState "Start"
        ssService -ServiceName "SQLServerAgent" -ServiceState "Start"

        $totalHandles = (Get-Counter -Counter "\\$compName\Process(_total)\Handle Count").CounterSamples
        $totalHandles = $totalHandles[0].CookedValue
        "Total Handles in Use = $totalHandles" >> "$logOutput"

        $freeMem = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $compName
        $freeMem = ([math]::round(100 - (((($freemem.TotalVisibleMemorySize - $freemem.FreePhysicalMemory) / $freemem.TotalVisibleMemorySize)) * 100), 0))
        "Percent of memory free = $freeMem%" >> "$logOutput"

    }
    CATCH {
        $ErrorMessage = $_.Exception.Message
        
        $logTime = Get-Date -Format T
        "$($logDate) $($logTime): $ErrorMessage" >> "$logOutput"
    }
    FINALLY {
        "Restarting services complete - $($logDate) $($logTime)
     ---------------------------------------------------------------------------------------
     " >> "$logOutput"
    }

}