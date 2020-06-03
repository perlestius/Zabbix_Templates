Param(
    #Объект мониторинга, для которого будем возвращать метрики
    [parameter(Mandatory=$true, Position=0)][String]$Object,
    #Дополнительные параметры, на основании которых будет возвращать метрики для объекта
    [parameter(Mandatory=$false, Position=1)]$Param1,
    [parameter(Mandatory=$false, Position=2)]$Param2
)

Set-Variable DFSNamespace -Option ReadOnly -Value "root\MicrosoftDfs" -ErrorAction Ignore

Set-Variable RoleNotInstalledText -Option ReadOnly -Value "DFS Replication role not installed" -ErrorAction Ignore

#Параметры локализации (чтобы разделителем целой и дробной части была точка, т.к. запятую заббикс не поймет)
$USCulture = [System.Globalization.CultureInfo]::GetCultureInfo("en-US")
[System.Threading.Thread]::CurrentThread.CurrentCulture = $USCulture

<#
    #Тайм-аут для получения значения (должен быть меньше таймаута в настройках заббикс-агента)
    С помощью этого параметра ограничиваем время опроса партнеров:
    Учитывая, что обычно опрос недоступного партнера занимает до 20с,
    а Timeout для заббикс-агента обычно меньше (3с по умолчанию),
    мы ограничиваем время опроса в самом скрипте, чтобы заббикс-агент не получил NoData из-за таймаута
    Это позволит вместо NoData вернуть значение, либо текст ошибки
#>
Set-Variable RequestTimeout -Option ReadOnly -Value 2 -ErrorAction Ignore

If ($PSVersionTable.PSVersion.Major -lt 3) {
    "The script requires PowerShell version 3.0 or above"
    Break
}

$DFSRRoleInstalled = (Get-WindowsFeature FS-DFS-Replication).Installed

$ErrorActionPreference = "Continue"

Switch($Object) {
    "RoleInstalled" {
        $DFSRRoleInstalled
    }
    "ServiceState" {
        $DFSRService = Get-Service DFSR -ErrorAction Ignore
        If ($DFSRService) {
            If ($DFSRService.Status -eq "Running") {
                (Get-WmiObject -Namespace $DFSNamespace -Class DfsrInfo).State
            }
            Else {
                #Если служба остановлена
                [int]100
            }
        }
        Else {
            #Если служба не найдена
            [int]101
        }
    }

    #DFS Replication service version
    "ServiceVer" {
        $DFSRConfig = Get-WmiObject -Namespace $DFSNamespace -Class DfsrConfig -ErrorAction Ignore
        If ($DFSRConfig) {
            $DFSRConfig.ServiceVersion
        }
        Else {
            "n/a"
        }
    }

    #DFS Replication provider version
    "ProvVer" {
        $DFSRConfig = Get-WmiObject -Namespace $DFSNamespace -Class DfsrConfig -ErrorAction Ignore
        If ($DFSRConfig) {
            $DFSRConfig.ProviderVersion
        }
        Else {
            "n/a"
        }
    }

    #DFS Replication monitoring provider version
    "MonProvVer" {
        $DFSRInfo = Get-WmiObject -Namespace $DFSNamespace -Class DfsrInfo -ErrorAction Ignore
        If ($DFSRInfo) {
            $DFSRInfo.ProviderVersion
        }
        Else {
            "n/a"
        }
    }

    "ServiceUptime" {
        If (!$DFSRRoleInstalled) {
            $RoleNotInstalledText
            Break
        }
        $DFSRInfo = Get-WmiObject -Namespace $DFSNamespace -Class DfsrInfo -ErrorAction Ignore
        If ($DFSRInfo) {
            #Получаем время запуска службы в WMI-формате
            $WMIStartTime = $DFSRInfo.ServiceStartTime
            #и преобразуем его в формат DateTime
            $StartTime = [Management.ManagementDateTimeConverter]::ToDateTime($WMIStartTime)
            (New-TimeSpan -Start $StartTime -End (Get-Date)).TotalSeconds
        }
        Else {
            "n/a"
        }
    }

    #Реплицируемая папка
    "RF" {
        If (!$DFSRRoleInstalled) {
            $RoleNotInstalledText
            Break
        }
        $RFID = $Param1
        $WMIQuery = "SELECT * FROM DfsrReplicatedFolderConfig WHERE ReplicatedFolderGuid='$RFID'"
        $RFConfig = Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery
        If (!$RFConfig) {
            "RF '$RFID' not found"
            Break
        }
        $RFName = $RFConfig.ReplicatedFolderName
        $RGID = $RFConfig.ReplicationGroupGuid
        #Статистику можно собирать только с Enabled-папок
        If ($RFConfig.Enabled) {
            $WMIQuery = "SELECT * FROM DfsrReplicatedFolderInfo WHERE ReplicatedFolderGuid='$RFID'"
            $RFInfo = Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery
        }
        $ErrorText = "Couldn't retrieve info for disabled RF"
        
        Switch($Param2) {
            "Enabled" {
            #Включена ли репликация для папки
                $RFConfig.Enabled
            }
            #Удалять файлы вместо перемещения в папку конфликтов
            "RemoveDeleted" {
                $RFConfig.DisableSaveDeletes
            }
            "ReadOnly" {
            #Папка работает в режиме "только чтение"
                $RFConfig.ReadOnly
            }
            #Максимальный размер, заданный для промежуточной папки, байт
            "StageQuota" {
                $RFConfig.StagingSizeInMb*1024*1024
            }
            #Максимальный размер, заданный для папки ConflictAndDeleted, байт
            "ConflictQuota" {
                $RFConfig.ConflictSizeInMb*1024*1024
            }
            "State" {
                If ($RFInfo) {
                    # 0 - Uninitialized, 1 - Initialized, 2 - Initial Sync,
                    # 3 - Auto Recovery, 4 - Normal, 5 - In Error
                    $RFInfo.State
                }
                Else {
                    "Couldn't retrieve info for disabled RF"
                }
            }
            #Текущий размер промежуточной папки, байт
            "StageSize" {
                If ($RFInfo) {
                    $RFInfo.CurrentStageSizeInMb*1024*1024
                }
                Else {
                    "Couldn't retrieve info for disabled RF"
                }
            }
            #% свободного места в промежуточной папке
            "StagePFree" {
                If ($RFInfo) {
                    ($RFConfig.StagingSizeInMb - $RFInfo.CurrentStageSizeInMb)/ `
                        $RFConfig.StagingSizeInMb*100
                }
                Else {
                    $ErrorText
                }
            }
            #Текущий размер папки ConflictAndDeleted, байт
            "ConflictSize" {
                If ($RFInfo) {
                    $RFInfo.CurrentConflictSizeInMb*1024*1024
                }
                Else {
                    $ErrorText
                }
            }
            #% свободного места в папке ConflictAndDeleted
            "ConflictPFree" {
                If ($RFInfo) {
                    ($RFConfig.ConflictSizeInMb - $RFInfo.CurrentConflictSizeInMb)/ `
                        $RFConfig.ConflictSizeInMb*100
                }
                Else {
                    $ErrorText
                }
            }
            #На скольких партнерах имеется копия папки в рабочем состоянии
            "Redundancy" {
                #Находим партнеров по группе репликации
                $WMIQuery = "SELECT * FROM DfsrConnectionConfig WHERE ReplicationGroupGuid='$RGID'"
                $PartnersByGroup = (Get-WmiObject `
                    -Namespace $DFSNamespace `
                    -Query $WMIQuery).PartnerName | Select-Object -Unique
                $n = 0
                #Проверяем наличие папки, имеющей состояние 'Normal' (4), на каждом из партнеров
                ForEach ($Partner in $PartnersByGroup) {
                    $WMIQuery = "SELECT * FROM DfsrReplicatedFolderInfo " +
                        "WHERE ReplicatedFolderGuid='$RFID' AND State=4"
                    #и подсчитываем общее количество таких папок
                    $j = Get-WmiObject -ComputerName $Partner `
                                       -Namespace $DFSNamespace `
                                       -Query $WMIQuery `
                                       -ErrorAction Ignore -AsJob
                    [void](Wait-Job $j -Timeout $RequestTimeout)
                    If ($j.State -eq "Completed") {
                        $n += @(Receive-Job $j).Count
                    }
                    #Если не можем опросить хотя одного партнера, прекращаем опрос и возвращаем ошибку
                    Else {
                        $n = -1
                        "Couldn't retrieve info from partner '$Partner'"
                        Break
                    }
                }
                #Если всё хорошо, возвращаем количество партнеров, хранящих копию папки
                If ($n -ge 0) {
                    $n
                }
            }
        }
    }

    "RFBacklog" {
        If (!$DFSRRoleInstalled) {
            $RoleNotInstalledText
            Break
        }
        $RFID = $Param1
        $RServerID = $Param2 #ID принимающего партнера
        $WMIQuery = "SELECT * FROM DfsrReplicatedFolderConfig WHERE ReplicatedFolderGuid='$RFID'"
        $RFConfig = Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery
        If (!$RFConfig) {
            "RF '$RFID' not found"
            Break
        }
        #Находим имя принимающего партнера по ID
        $WMIQuery = "SELECT * FROM DfsrConnectionConfig WHERE PartnerGuid='$RServerID' AND Inbound='False'"
        $ConnectionConfig = Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery
        If (!$ConnectionConfig) {
            "Outbound connection to partner '$RServerID' not found"
            Break
        }
        $RServerName = $ConnectionConfig.PartnerName
        #Зная ID папки, находим ее имя и имя группы, которой она принадлежит
        $WMIQuery = "SELECT * FROM DfsrReplicatedFolderInfo WHERE ReplicatedFolderGuid='$RFID'"
        #Запрашиваем у принимающего партнера информацию о папке
        $j = Get-WmiObject -ComputerName $RServerName `
                           -Namespace $DFSNamespace `
                           -Query $WMIQuery `
                           -ErrorAction Ignore -AsJob
        [void](Wait-Job $j -Timeout $RequestTimeout)
        If ($j.State -eq "Completed") {
            Try {
                #и пытаемся извлечь с этого партнера вектор версии
                $VersionVector = (Receive-Job $j).GetVersionVector().VersionVector
                #На отправляющем партнере (т.е. на локальном сервере) определяем размер бэклога для найденного вектора
                (Get-WmiObject `
                    -Namespace $DFSNamespace `
                    -Query $WMIQuery).GetOutboundBacklogFileCount($VersionVector).BacklogFileCount
                }
            Catch {
                If ($VersionVector) {
                    "Couldn't retrieve backlog info for vector '$VersionVector'"
                }
                Else {
                    "Version vector not found"
                }
            }
        }
        Else {
            "Couldn't retrieve info from partner '$RServerName'"
        }
    }

    "Connection" {
        If (!$DFSRRoleInstalled) {
            $RoleNotInstalledText
            Break
        }
        $ConnectionID = $Param1
        $WMIQuery = "SELECT * FROM DfsrConnectionConfig WHERE ConnectionGuid='$ConnectionID'"
        $ConnectionConfig = Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery
        If (!$ConnectionConfig) {
            "Connection '$ConnectionID' not found"
            Break
        }
        Switch($Param2) {
            "Enabled" {
                $ConnectionConfig.Enabled
            }
            "State" {
                #Статистику можно получить только с enabled-подключений
                If ($ConnectionConfig.Enabled) {
                    $WMIQuery = "SELECT * FROM DfsrConnectionInfo WHERE ConnectionGuid='$ConnectionID'"
                    $ConnectionInfo = Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery
                    If ($ConnectionInfo) {
                        #0 - Connecting, 1 - Online, 2 - Offline, 3 - In Error
                        $ConnectionInfo.State
                    }
                    Else {
                        "Coundn't retrieve connection info. Check availability of partner '$($ConnectionConfig.PartnerName)'"
                    }
                }
                Else {
                    "Coundn't retrieve info for disabled connection"
                }
            }
            #Если репликация полностью выключена по расписанию
            "BlankSchedule" {
                [Int]$s = 0
                $ConnectionConfig.Schedule | ForEach-Object {
                    $s += $_
                }
                #Если репликация отключена для каждого часа каждого дня, возвращаем True
                [Boolean]($s -eq 0)
            }
        }
    }

    "RG"
    {
        If (!$DFSRRoleInstalled) {
            $RoleNotInstalledText
            Break
        }
        $RGID = $Param1
        $WMIQuery = "SELECT * FROM DfsrReplicationGroupConfig WHERE ReplicationGroupGuid='$RGID'"
        $RGConfig = Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery
        If (!$RGConfig) {
            "RG '$RGID' not found"
            Break
        }
        Switch($Param2) {
            #количество папок в группе
            "RFCount" {
                $WMIQuery = "SELECT * FROM DfsrReplicatedFolderConfig WHERE ReplicationGroupGuid='$RGID'"
                @(Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery).Count
            }
            #количество входящих подключений (в т.ч. disabled) от партнеров группы
            "InConCount" {
                $WMIQuery = "SELECT * FROM DfsrConnectionConfig WHERE ReplicationGroupGuid='$RGID' AND Inbound='True'"
                @(Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery).Count
            }
            #количество исходящих подключений (в т.ч. disabled) от партнеров группы
            "OutConCount" {
                $WMIQuery = "SELECT * FROM DfsrConnectionConfig WHERE ReplicationGroupGuid='$RGID' AND Inbound='False'"
                @(Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery).Count
            }
            #Если в дефолтном расписании для группы репликация полностью выключена
            "BlankSchedule" {
                $WMIQuery = "SELECT * FROM DfsrReplicationGroupConfig WHERE ReplicationGroupGuid='$RGID'"
                $RGConfig = Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery
                If ($RGConfig) {
                    [Int]$s = 0
                    $RGConfig.DefaultSchedule | ForEach-Object {
                        $s += $_
                    }
                    #Если репликация отключена для каждого часа каждого дня, возвращаем True
                    [Boolean]($s -eq 0)
                }
            }
        }
    }

    #Количество групп репликации, в которые входит сервер
    "RGCount" {
        If (!$DFSRRoleInstalled) {
            $RoleNotInstalledText
            Break
        }
        @(Get-WmiObject -Namespace $DFSNamespace -Class DfsrReplicationGroupConfig).Count
    }
    
    "Partner" {
        If (!$DFSRRoleInstalled) {
            $RoleNotInstalledText
            Break
        }
        $PartnerID = $Param1
        $WMIQuery = "SELECT * FROM DfsrConnectionConfig WHERE PartnerGuid='$PartnerID'"
        $ConnectionConfig = Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery
        If (!$ConnectionConfig) {
            "Partner '$PartnerID' not found"
            Break
        }
        $PartnerName = (Get-WmiObject `
            -Namespace $DFSNamespace `
            -Query $WMIQuery).PartnerName | Select-Object -Unique
        Switch($Param2) {
            "PingCheckOK" {
                $CheckResult = Test-Connection -ComputerName $PartnerName `
                    -Count 1 -Delay 1 -ErrorAction Ignore
                [Boolean]($CheckResult -ne $Null)
            }
            "WMICheckOK" {
                $WMIQuery = "SELECT * FROM DfsrConfig"
                $j = Get-WmiObject -ComputerName $PartnerName `
                                   -Namespace $DFSNamespace `
                                   -Query $WMIQuery `
                                   -ErrorAction Ignore -AsJob
                [void](Wait-Job $j -Timeout $RequestTimeout)
                [Boolean]($j.State -eq "Completed")
            }
        }
    }

    "Volume" {
        If (!$DFSRRoleInstalled) {
            $RoleNotInstalledText
            Break
        }
        $VolumeID = $Param1
        $WMIQuery = "SELECT * FROM DfsrVolumeConfig WHERE VolumeGuid='$VolumeID'"
        $VolumeConfig = Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery
        If (!$VolumeConfig) {
            "Volume '$VolumeID' not found"
            Break
        }
        Switch ($Param2) {
            "State" {
                $WMIQuery = "SELECT * FROM DfsrVolumeInfo WHERE VolumeGuid='$VolumeID'"
                #0 - Initialized, 1 - Shutting Down, 2 - In Error, 3 - Auto Recovery
                (Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery).State
            }
        }
    }

    "Log" {
        If (!$DFSRRoleInstalled) {
            $RoleNotInstalledText
            Break
        }
        $ErrorActionPreference = "Stop"
        Try {
            [String]$TimeSpanAsString = $Param2
            $EndTime = Get-Date
            #Коэффициент для перевода из исходных единиц измерения в секунды
            $Multiplier = 1
            #Определяем единицы измерения (смотрим последний символ в полученной строке)
            $TimeUnits = $TimeSpanAsString[$TimeSpanAsString.Length-1]
            #Если единицы не указаны (на конце цифра),
            If ($TimeUnits -match "\d") {
                #считаем, что получили значение в секундах
                $TimeValue = ($TimeSpanAsString -as [Int])
            }
            Else {
                #Числовое значение получаем, отбросив последний символ строки
                $TimeValue = ($TimeSpanAsString.Substring(0, $TimeSpanAsString.Length - 1) -as [Int])
                #Переводим из исходных единиц измерения в секунды
                Switch ($TimeUnits) {
                    "m" {$Multiplier = 60} #минуты
                    "h" {$Multiplier = 3600} #часы
                    "d" {$Multiplier = 86400} #дни
                    "w" {$Multiplier = 604800} #недели
                }
            }
            $StartTime = $EndTime.AddSeconds(-$TimeValue*$Multiplier)

            $Filter = @{
                LogName="DFS Replication"
                StartTime=$StartTime
                EndTime=$EndTime
            }
            Switch ($Param1) {
                "WarnCount" {$Filter += @{Level=3}}
                "ErrCount" {$Filter += @{Level=2}}
                "CritCount" {$Filter += @{Level=1}}
            }
            @(Get-WinEvent -FilterHashtable $Filter -ErrorAction Ignore).Count
        }
        Catch {
            $Error[0].Exception.Message
        }
    }
}
