<#
        .SYNOPSIS
            This script contains User Logon Task which starts online logon script.
 
        .DESCRIPTION
            This script should be deployed through Intune to register a Logon Task.
 
        .NOTES
            Author: Philippe Tschumi - https://techblog.ptschumi.ch
            Last Edit: 2020-10-18
            Version 1.1 - added Session Unlock trigger
#>
 

$ScheduledTaskArguments = '-WindowStyle Hidden -Command "&{winget upgrade --id Microsoft.Powershell --silent}"'
$TaskName = "UpdatePowershell_$($env:USERNAME)"
 
$TaskExists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
# If Task exist compare
if (($TaskExists)-and (Get-ScheduledTask -TaskName $TaskName).Actions[0].Arguments -eq $ScheduledTaskArguments) {
    Write-Host "Task exists, no update needed."
}
# update if different
elseif ($TaskExists) {
        $TaskExists.Actions[0].Arguments = $ScheduledTaskArguments
        $TaskExists | Set-ScheduledTask
        Write-Host "Task updated."
}
# create if not existing
else {
    $ScheduledTaskAction = New-ScheduledTaskAction -Execute "$($PSHOME)\powershell.exe" -Argument $ScheduledTaskArguments
    $ScheduledTaskTrigger1 = New-ScheduledTaskTrigger -AtLogon -User "$($env:USERDOMAIN)\$($env:USERNAME)"
    $ScheduledTaskTrigger1.Delay = "PT5S"
    $ScheduledTaskTrigger1.ExecutionTimeLimit = "PT10M"
 
    $stateChangeTrigger = Get-CimClass -Namespace ROOT\Microsoft\Windows\TaskScheduler -ClassName MSFT_TaskSessionStateChangeTrigger
    $ScheduledTaskTrigger2 = New-CimInstance -CimClass $stateChangeTrigger -ClientOnly
    $ScheduledTaskTrigger2.UserId = "$($env:USERDOMAIN)\$($env:USERNAME)"
    $ScheduledTaskTrigger2.StateChange = 8 # TASK_SESSION_STATE_CHANGE_TYPE.TASK_SESSION_UNLOCK
    $ScheduledTaskTrigger2.Delay = "PT5S"
    $ScheduledTaskTrigger2.ExecutionTimeLimit = "PT10M"
 
    $ScheduledTaskTriggers = @(
        $ScheduledTaskTrigger1,
        $ScheduledTaskTrigger2
    )
    
 
    $ScheduledTaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Compatibility Win8
    $ScheduledTaskPrincipal = New-ScheduledTaskPrincipal -UserId "$($env:USERDOMAIN)\$($env:USERNAME)"
    $ScheduledTask = New-ScheduledTask -Action $ScheduledTaskAction -Settings $ScheduledTaskSettings -Trigger $ScheduledTaskTriggers -Principal $ScheduledTaskPrincipal
    Register-ScheduledTask -InputObject $ScheduledTask -TaskName $TaskName
    Start-ScheduledTask $TaskName
    Write-Host "LogonScriptUser registered." -EntryType Information
}