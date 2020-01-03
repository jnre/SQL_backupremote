USE [msdb]
GO

/****** Object:  Job [transaction log backup script]    Script Date: 03/01/2020 4:24:33 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 03/01/2020 4:24:33 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'transaction log backup script', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'backs up specified database transaction log script
@db0 = jojopower;
@fileLocation = D:\Program FILES\Microsoft SQL Server\MSSQL13.MESMSSQLSERVER\MSSQL\Backup\;
@remoteFileLocation = Microsoft.PowerShell.Core\FileSystem::\\;', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'Username', @job_id = @jobId OUTPUT 
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [check for disk space]    Script Date: 03/01/2020 4:24:33 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'check for disk space', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'#teams configuration channel webhook
$channel = "https://outlook.office.com/webhook/";


#check for diskspace and if fail, send msg to chat
$report = Get-WmiObject -Class Win32_logicaldisk -Filter "DriveType = 3" | Where-Object {($_.freespace/$_.size) -le ''0.1''};

if($report){

    #string msg to send to chat
    $diskNoSpace = ($report.DeviceID -join ", ").Replace('':'','''');
    $message = "disk space less than 10 percent in $diskNoSpace ";
    #got to use text for json string
    $jsonMessage = ConvertTo-Json @{text = $message};
    Invoke-RestMethod -Method Post -ContentType ''application/json'' -Body $jsonMessage -Uri $channel;

    Throw "$message";
}', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [attempt to backup keywareDB transac log]    Script Date: 03/01/2020 4:24:33 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'attempt to backup keywareDB transac log', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'--read from description of job with variables starting with @
DECLARE @paramdb0 varchar(128), @paramFile varchar(128);
DECLARE @desc nvarchar(512);
SELECT @desc = description from msdb.dbo.sysjobs where name = ''$(ESCAPE_SQUOTE(JOBNAME))'';

SELECT @paramdb0 = substring(@desc, charindex(''@db0'',@desc) + len(''@db0 = '')+1, charindex('';'',@desc,charindex(''@db0'',@desc))-charindex(''@db0'',@desc) - len(''@db0 = '')-1)
SELECT @paramFile = substring(@desc, charindex(''@fileLocation'',@desc) + len(''@fileLocation = '')+1, charindex('';'',@desc,charindex(''@fileLocation'',@desc))-charindex(''@fileLocation'',@desc) - len(''@fileLocation = '')-1)

--specify saving location and name
DECLARE @fileLocation varchar(128)

SELECT @fileLocation= (SELECT @paramFile +@paramdb0 +''transaclog''+REPLACE(CONVERT(VARCHAR(20),GETDATE(),103),''/'','''') + ''_'' + REPLACE(CONVERT(VARCHAR(20),GETDATE(),108),'':'','''') +''.bak'')
BACKUP LOG @paramdb0 to DISK =@fileLocation
WITH NOFORMAT, 
           NOINIT, 
           SKIP, 
           REWIND, 
           NOUNLOAD, 
           STATS = 10
GO', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [transfer to remote]    Script Date: 03/01/2020 4:24:33 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'transfer to remote', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'#copy files to remote server 

#teams configuration channel webhook
$channel = "https://outlook.office.com/webhook/";

$desc= Invoke-Sqlcmd -Query "SELECT description FROM msdb.dbo.sysjobs where name = ''$(ESCAPE_SQUOTE(JOBNAME))''" -ServerInstance . -DisableVariables;

$remoteFileLocation = $desc[0].SubString([int]$desc[0].IndexOf(''@remoteFileLocation'') + [int](''@remoteFileLocation = '').length,[int]$desc[0].IndexOf('';'',[int]$desc[0].IndexOf(''@remoteFileLocation'')) -[int]$desc[0].IndexOf(''@remoteFileLocation'') - [int](''@remoteFileLocation = '').length);
$fileLocation = $desc[0].SubString([int]$desc[0].IndexOf(''@fileLocation'') + [int](''@fileLocation = '').length,[int]$desc[0].IndexOf('';'',[int]$desc[0].IndexOf(''@fileLocation'')) -[int]$desc[0].IndexOf(''@fileLocation'') - [int](''@fileLocation = '').length);
$db0 = $desc[0].SubString([int]$desc[0].IndexOf(''@db0'') + [int](''@db0 = '').length,[int]$desc[0].IndexOf('';'',[int]$desc[0].IndexOf(''@db0'')) -[int]$desc[0].IndexOf(''@db0'') - [int](''@db0 = '').length);

#check for diskspace and if fail, send msg to chat
$report = Invoke-Command -ScriptBlock {
    (Get-ChildItem $remoteFileLocation -Recurse | Measure-Object -Property Length -Sum).Sum;
} 

if($report -ge 20MB ){

    #string msg to send to chat
    #$diskNoSpace = ($report.DeviceID -join ", ").Replace('':'','''');
    $message = "folder space going to exceed 10 percent of limit in backup folder (>20MB) ";
    #got to use text for json string
    $jsonMessage = ConvertTo-Json @{text = $message};
    Invoke-RestMethod -Method Post -ContentType ''application/json'' -Body $jsonMessage -Uri $channel;
    
  
}
#copy to remote 
else{
    $copyValidate = Copy-Item -Path ($fileLocation + $db0 + "transaclog*.bak") -PassThru -Destination $remoteFileLocation;
    if($copyValidate){
        $copyValidate;
        #delete in current folder
        #remove-Item -Path ($fileLocation + $db0 + "transaclog*.bak") -Force;
    }
    else{
        #copy failed
        $nocopyMessage = ConvertTo-Json @{text = "copy-Item failed to backup"};
        Invoke-RestMethod -Method Post -ContentType ''application/json'' -Body $nocopyMessage -Uri $channel;
    }
}
', 
		@database_name=N'master', 
		@flags=0, 
		@proxy_name=N'backup to remote pc'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'2hr backup', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=2, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20200102, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'315ccaaf-e60f-4efa-9eb9-7dc4db811eba'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


