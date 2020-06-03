Param(
    #Какой тип объектов собираем
    [parameter(Mandatory=$true, Position=0)][String]$ObjectType
)


If ($PSVersionTable.PSVersion.Major -lt 3) {
    "The script requires PowerShell version 3.0 or above"
    Break
}
If (!(Get-WindowsFeature FS-DFS-Replication).Installed) {
    "DFS Replication role not installed"
    Break
}

$ErrorActionPreference = "Continue"

Set-Variable DFSNamespace -Option ReadOnly -Value "root\MicrosoftDfs" -ErrorAction Ignore

$Data = @()

#В зависимости от типа объекта собираем и возвращаем соответствующие данные в JSON
Switch($ObjectType) {
    #Счетчики производительности для реплицируемых папок
    "RFPerfCounter" {
        #Находим в реестре первый номер счетчика, относящегося к объекту "Реплицированные папки DFS" (DFS Replicated Folders)
        #(Номера генерируются системой и индивидуальны для каждого сервера)
        #Этими номерами будет оперировать заббикс
        $PerfObjectRegKey = "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\Perflib\_V2Providers\{d7b456d4-ca82-4080-a5d0-27fe1a27a851}\{bfe2736b-c79f-4f36-bd15-2897a1a91d4a}"
        $PerfObjectID = (Get-ItemProperty -Path $PerfObjectRegKey -Name "First Counter")."First Counter"
        #Получаем список экземпляров для объекта RF (т.е. список папок DFSR, для которых есть счетчики)
        Get-WmiObject -Class Win32_PerfFormattedData_Dfsr_DFSReplicatedFolders | ForEach-Object {
            #Экземпляр (в нашем случае это RF), с которого собираются данные счетчиков, имеет вид RFName-{RFID}
            #Вычленяем из него идентификатор и имя RF
            $RFName = $_.Name.Substring(0, $_.Name.IndexOf('-{'))
            $RFID = $_.Name.Substring($_.Name.IndexOf('-{') + 2, $_.Name.Length -$_.Name.IndexOf('-{') - 3)
            #Находим группу репликации, к которой относится RF
            $WMIQuery = "SELECT * FROM DfsrReplicatedFolderInfo WHERE ReplicatedFolderGuid = '$RFID'"
            $RGName = (Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery).ReplicationGroupName

            $Entry = [PSCustomObject] @{
                "{#RGNAME}" = $RGName
                "{#RFNAME}" = $_.Name.Substring(0, $_.Name.IndexOf('-{'))
                "{#RFPERFOBJECTID}" = $PerfObjectID
                "{#RFPERFINSTANCEID}" = $_.Name
                #Номера счетчиков получаем последовательным увеличением на 2 того номера, который нашли выше
                "{#RFPERFCOUNTER1ID}" = $PerfObjectID + 2 # Staging Files Generated
                "{#RFPERFCOUNTER2ID}" = $PerfObjectID + 4 # Staging Bytes Generated
                "{#RFPERFCOUNTER3ID}" = $PerfObjectID + 6 # Staging Files Cleaned up
                "{#RFPERFCOUNTER4ID}" = $PerfObjectID + 8 # Staging Bytes Cleaned up
                "{#RFPERFCOUNTER5ID}" = $PerfObjectID + 10 # Staging Space In Use
                "{#RFPERFCOUNTER6ID}" = $PerfObjectID + 12 # Conflict Files Generated
                "{#RFPERFCOUNTER7ID}" = $PerfObjectID + 14 # Conflict Bytes Generated
                "{#RFPERFCOUNTER8ID}" = $PerfObjectID + 16 # Conflict Files Cleaned up
                "{#RFPERFCOUNTER9ID}" = $PerfObjectID + 18 # Conflict Bytes Cleaned up
                "{#RFPERFCOUNTER10ID}" = $PerfObjectID + 20 # Conflict Space In Use
                "{#RFPERFCOUNTER11ID}" = $PerfObjectID + 22 # Conflict Folder Cleanups Completed
                "{#RFPERFCOUNTER12ID}" = $PerfObjectID + 24 # File Installs Succeeded
                "{#RFPERFCOUNTER13ID}" = $PerfObjectID + 26 # File Installs Retried
                "{#RFPERFCOUNTER14ID}" = $PerfObjectID + 28 # Updates Dropped
                "{#RFPERFCOUNTER15ID}" = $PerfObjectID + 30 # Deleted Files Generated
                "{#RFPERFCOUNTER16ID}" = $PerfObjectID + 32 # Deleted Bytes Generated
                "{#RFPERFCOUNTER17ID}" = $PerfObjectID + 34 # Deleted Files Cleaned up
                "{#RFPERFCOUNTER18ID}" = $PerfObjectID + 36 # Deleted Bytes Cleaned up
                "{#RFPERFCOUNTER19ID}" = $PerfObjectID + 38 # Deleted Space In Use
                "{#RFPERFCOUNTER20ID}" = $PerfObjectID + 40 # Total Files Received
                "{#RFPERFCOUNTER21ID}" = $PerfObjectID + 42 # Size of Files Received
                "{#RFPERFCOUNTER22ID}" = $PerfObjectID + 44 # Compressed Size of Files Received
                "{#RFPERFCOUNTER23ID}" = $PerfObjectID + 46 # RDC Number of Files Received
                "{#RFPERFCOUNTER24ID}" = $PerfObjectID + 48 # RDC Size of Files Received
                "{#RFPERFCOUNTER25ID}" = $PerfObjectID + 50 # RDC Compressed Size of Files Received
                "{#RFPERFCOUNTER26ID}" = $PerfObjectID + 52 # RDC Bytes Received
                "{#RFPERFCOUNTER27ID}" = $PerfObjectID + 54 # Bandwidth Savings Using DFS Replication
            }
            $Data += $Entry
        }
    }

    #Счетчики производительности для DFSR-подключений
    "ConPerfCounter" {
        #Находим в реестре первый номер счетчика, относящегося к объекту "Подключения репликации DFS" (DFS Replication Connections)
        #(Номера генерируются системой и индивидуальны для каждого сервера)
        #Этими номерами будет оперировать заббикс
        $PerfObjectRegKey = "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\Perflib\_V2Providers\{d7b456d4-ca82-4080-a5d0-27fe1a27a851}\{a689f9be-38ad-4c17-9d62-ad60492084a7}"
        $PerfObjectID = (Get-ItemProperty -Path $PerfObjectRegKey -Name "First Counter")."First Counter"
        Get-WmiObject -Class Win32_PerfFormattedData_Dfsr_DFSReplicationConnections | ForEach-Object {
            #Получаем список экземпляров для объекта RC (т.е. список подключений DFSR, для которых есть счетчики)
            #Экземпляр (в нашем случае это подключение), с которого собираются данные счетчиков, имеет вид SendingParnerFQDN-{RCID}
            #Вычленяем из него имя отправляющего сервера-партнера и ID подключения
            $SendingPartner = $_.Name.Substring(0, $_.Name.IndexOf('-{'))
            $RCID = $_.Name.Substring($_.Name.IndexOf('-{') + 2, $_.Name.Length -$_.Name.IndexOf('-{') - 3)
            #Находим группу репликации, к которой относится RC
            $WMIQuery = "SELECT * FROM DfsrConnectionInfo WHERE ConnectionGuid = '$RCID'"
            $RGName = (Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery).ReplicationGroupName

            $Entry = [PSCustomObject] @{
                "{#RGNAME}" = $RGName
                "{#RCPARTNER}" = $SendingPartner
                "{#RCPERFOBJECTID}" = $PerfObjectID
                "{#RCPERFINSTANCEID}" = $_.Name
                #Номера счетчиков получаем последовательным увеличением на 2 того номера, который нашли выше
                "{#RCPERFCOUNTER1ID}" = $PerfObjectID + 2 # Total Bytes Received
                "{#RCPERFCOUNTER2ID}" = $PerfObjectID + 4 # Total Files Received
                "{#RCPERFCOUNTER3ID}" = $PerfObjectID + 6 # Size of Files Received
                "{#RCPERFCOUNTER4ID}" = $PerfObjectID + 8 # Compressed Size of Files Received
                "{#RCPERFCOUNTER5ID}" = $PerfObjectID + 10 # Bytes Received Per Second
                "{#RCPERFCOUNTER6ID}" = $PerfObjectID + 12 # RDC Number of Files Received
                "{#RCPERFCOUNTER7ID}" = $PerfObjectID + 14 # RDC Size of Files Received
                "{#RCPERFCOUNTER8ID}" = $PerfObjectID + 16 # RDC Compressed Size of Files Received
                "{#RCPERFCOUNTER9ID}" = $PerfObjectID + 18 # RDC Bytes Received
                "{#RCPERFCOUNTER10ID}" = $PerfObjectID + 20 # Bandwidth Savings Using DFS Replication
            }
            $Data += $Entry
        }
    }

    #Счетчики производительности для томов DFSR
    "VolPerfCounter" {
        #Находим в реестре первый номер счетчика, относящегося к объекту "Тома службы репликации DFS" (DFS Replication Service Volumes)
        #(Номера генерируются системой и индивидуальны для каждого сервера)
        #Этими номерами будет оперировать заббикс
        $PerfObjectRegKey = "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\Perflib\_V2Providers\{d7b456d4-ca82-4080-a5d0-27fe1a27a851}\{3f1707df-6381-4287-affc-a60e109a4d30}"
        $PerfObjectID = (Get-ItemProperty -Path $PerfObjectRegKey -Name "First Counter")."First Counter"
        #Получаем список DFS Replication Service Volumes
        Get-WmiObject -Class Win32_PerfFormattedData_Dfsr_DFSReplicationServiceVolumes |
            ForEach-Object {
                $RV = [PSCustomObject] @{
                    "{#RVNAME}" = $_.Name
                    "{#RVPERFOBJECTID}" = $PerfObjectID
                    "{#RVPERFCOUNTER1ID}" = $PerfObjectID + 2 # USN Journal Records Read
                    "{#RVPERFCOUNTER2ID}" = $PerfObjectID + 4 # USN Journal Records Accepted
                    "{#RVPERFCOUNTER3ID}" = $PerfObjectID + 6 # USN Journal Unread Percentage
                    "{#RVPERFCOUNTER4ID}" = $PerfObjectID + 8 # Database Commits
                    "{#RVPERFCOUNTER5ID}" = $PerfObjectID + 10 # Database Lookups
                }
                $Data += $RV
        }
    }

    #Реплицируемые папки, расположенные на сервере
    "RF" {
        (Get-WmiObject -Namespace $DFSNamespace -Class DfsrReplicatedFolderConfig) |
            ForEach-Object {
                #Определяем имя группы репликации по ее ID
                $RGID = $_.ReplicationGroupGuid
                $WMIQuery = "SELECT * FROM DfsrReplicationGroupConfig WHERE ReplicationGroupGuid='$RGID'"
                $RGName = (Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery).ReplicationGroupName
                $RF = [PSCustomObject] @{
                    "{#RFID}" = $_.ReplicatedFolderGuid
                    "{#RFNAME}" = $_.ReplicatedFolderName
                    "{#RGNAME}" = $RGName
                }
                $Data += $RF
        }
    }
    
    #Бэклог исходящих файлов для каждой из реплицируемых папок
    "RFBacklog" {
        #текст-ориентир, с помощью которого будем парсить DN подписки
        $ReferenceText = ",CN=DFSR-LocalSettings,CN="
        $RFMembers = @()
        #Находим в базе AD все включенные DFSR-подписки, кроме своих
        (New-Object DirectoryServices.DirectorySearcher "ObjectClass=msDFSR-Subscription").FindAll() |
            Where-Object {($_.Properties.distinguishedname -notlike "*$ReferenceText$env:COMPUTERNAME,*") -and
                ($_.Properties."msdfsr-enabled" -eq $true)} |
                    ForEach-Object {
                    $SubscriptionDN = $_.Properties.distinguishedname
                    #имя подписанного сервера заключено в DN-строке между текстом-ориентиром
                    $TempText = $SubscriptionDN.Substring($SubscriptionDN.LastIndexOf($ReferenceText) + $ReferenceText.Length)
                    #и запятой
                    $ComputerName = $TempText.Substring(0, $TempText.IndexOf(","))
                    $RFMember = [PSCustomObject]@{
                        ComputerName = $ComputerName
                        RFID = [String]$_.Properties.name
                    }
                    $RFMembers += $RFMember
                }
        #Находим группы, в которые входит локальный сервер
        $RGs = Get-WmiObject -Namespace $DFSNamespace -Class DfsrReplicationGroupConfig
        ForEach ($RG in $RGs) {
            $RGID = $RG.ReplicationGroupGuid
            $RGName = $RG.ReplicationGroupName
            #Находим исходящие подключения, относящиеся к группе
            $WMIQuery = "SELECT * FROM DfsrConnectionConfig WHERE ReplicationGroupGuid='$RGID' AND Inbound='False'"
            $OutConnections = Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery
            #Находим на этом сервере папки (RF), относящиеся к группе,
            # кроме и отключенных и readonly-папок, т.к. у них нет бэклога исходящих файлов
            $WMIQuery = "SELECT * FROM DfsrReplicatedFolderConfig "+
                "WHERE ReplicationGroupGuid='$RGID' AND Enabled='True' AND ReadOnly='False'"
            $RFs = Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery
            #Проверяем наличие этих папок на каждом из принимающих партнеров группы
            ForEach ($Connection in $OutConnections) {
                ForEach ($RF in $RFs) {
                    $RFID = $RF.ReplicatedFolderGuid
                    $RFName = $RF.ReplicatedFolderName
                    #Если принимающий партнер содержит папку, будем создаем метрику для соответствующего бэклога
                    ForEach ($RFMember in $RFMembers) {
                        If (($RFMember.RFID -eq $RFID) -and ($RFMember.ComputerName -eq $Connection.PartnerName)) {
                            $Entry = [PSCustomObject] @{
                                "{#RGNAME}" = $RGName
                                "{#RFNAME}" = $RFName
                                "{#RFID}" = $RFID
                                "{#SSERVERNAME}" = $env:COMPUTERNAME
                                "{#RSERVERID}" = $Connection.PartnerGuid
                                "{#RSERVERNAME}" = $Connection.PartnerName
                            }
                            $Data += $Entry
                        }
                    }
                }
            }
        }
    }
    #Подключения для групп репликации
    "Connection" {
        Get-WmiObject -Namespace $DFSNamespace -Class DfsrConnectionConfig |
            ForEach-Object {
                #Определяем имя группы репликации по ее ID
                $RGID = $_.ReplicationGroupGuid
                $WMIQuery = "SELECT * FROM DfsrReplicationGroupConfig WHERE ReplicationGroupGuid='$RGID'"
                $RGName = (Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery).ReplicationGroupName
                If ($_.Inbound) {
                    $SendingServer = $_.PartnerName
                    $ReceivingServer = $env:COMPUTERNAME
                }
                Else {
                    $SendingServer = $env:COMPUTERNAME
                    $ReceivingServer = $_.PartnerName
                }
                $Connection = [PSCustomObject] @{
                    "{#CONNECTIONID}" = $_.ConnectionGuid
                    "{#RGNAME}" = $RGName
                    "{#SSERVERNAME}" = $SendingServer
                    "{#RSERVERNAME}" = $ReceivingServer
                }
                $Data += $Connection
        }
    }

    #Группы репликации
    "RG" {
        Get-WmiObject -Namespace $DFSNamespace -Class DfsrReplicationGroupConfig |
            ForEach-Object {
                $RG = [PSCustomObject] @{
                    "{#RGID}" = $_.ReplicationGroupGuid
                    "{#RGNAME}" = $_.ReplicationGroupName
                }
                $Data += $RG
        }
    }

    #Тома, на которых хранятся реплицируемые папки
    "Volume" {
        Get-WmiObject -Namespace $DFSNamespace -Class DfsrVolumeConfig |
            ForEach-Object {
                $Volume = [PSCustomObject] @{
                    "{#VOLUMEID}" = $_.VolumeGuid
                    #Путь изначально возвращается в UNC-формате, поэтому обрезаем начальные символы
                    "{#VOLUMENAME}" = $_.VolumePath.TrimStart("\\.\")
                }
                $Data += $Volume
        }
    }

    #Партнеры по группам репликации
    "Partner" {
        #Находим группы репликации
        Get-WmiObject -Namespace $DFSNamespace -Class DfsrReplicationGroupConfig |
            ForEach-Object {
                $RGID = $_.ReplicationGroupGuid
                $RGName = $_.ReplicationGroupName
                #и в каждой группе находим партнеров
                $WMIQuery = "SELECT * FROM DfsrConnectionConfig WHERE ReplicationGroupGuid='$RGID'"
                Get-WmiObject -Namespace $DFSNamespace -Query $WMIQuery |
                    Select-Object PartnerGuid, PartnerName -Unique | ForEach-Object {
                        $Partner = [PSCustomObject] @{
                            "{#PARTNERID}" = $_.PartnerGuid
                            "{#PARTNERNAME}" = $_.PartnerName
                            "{#RGNAME}" = $RGName
                            #Учетная запись, от имени которой работает служба Zabbix Agent
                            "{#NTACCOUNT}" = "$env:USERDOMAIN\$env:USERNAME"
                        }
                        $Data += $Partner
                }
        }
    }
}

@{
    "data" = $Data
} | ConvertTo-Json

