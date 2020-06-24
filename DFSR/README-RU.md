<a href="README.md">English version</a>
<h1>Шаблон для мониторинга Windows-серверов с ролью DFS Replication</h1>

<h2>ОСОБЕННОСТИ</h2>
<ul>
 <li>Множество метрик и триггеров для мониторинга DFSR и выявления проблем</li>
 <li>Кастомизация настроек с помощью макросов</li>
 <li>Для большинства элементов данных и триггеров даны описания и ссылки на статьи из базы знаний Microsoft</li>
 <li>НЕ требует установки консоли для управления DFS (RSAT-DFS-Mgmt-Con)</li>
 <li>НЕ зависит от локализации ОС</li>
 <li>Изначально многие метрики в шаблоне отключены, чтобы снизить нагрузку на сервер и уменьшить сетевой трафик</li>
</ul> 

<h2>ТРЕБОВАНИЯ</h2>
<ul>
 <li>ОС Windows 2008 R2 SP1 и выше</li>
 <li>Zabbix 2.2 и выше</li>
 <li><a href="https://docs.microsoft.com/ru-ru/powershell/scripting/windows-powershell/install/installing-windows-powershell?view=powershell-5.1">PowerShell 3.0 и выше</a></li>
 <li>Учетная запись, от имени которой работает служба Zabbix Agent, должна обладать правами локального администратора на каждом из серверов-партнеров (необходимо для мониторинга бэклогов и метрики Redundancy для реплицируемых папок)</li>
 <li>Т.к. DFSR является распределенной службой, для получения полной информации мониторинг нужно настроить для всех DFSR-серверов, участвующих в репликации данных</li>
</ul>

<h2>УСТАНОВКА</h2>
Предполагается, что сервер Zabbix уже развернут и на хостах установлен Zabbix Agent
<ol>
 <li>Предоставьте учетной записи, от имени которой работает служба Zabbix Agent, права локального администратора на КАЖДОМ из серверов-партнеров. По умолчанию служба настроена на запуск от имени встроенной учетной записи SYSTEM, т.е. права нужно будет выдавать доменной учетной записи компьютера. Более удобным вариантом будет создание в Active Directory специальной учетной записи для службы Zabbix Agent и включение ее в локальную группу "Администраторы" каждого из DFSR-серверов. Последнее можно сделать централизованно с помощью <a href="https://windowsnotes.ru/windows-server-2008/dobavlyaem-domennyx-polzovatelej-v-lokalnuyu-gruppu-bezopasnosti/">групповой политики</a>
 </li>
 <li>Скопируйте файлы <a href="https://github.com/perlestius/Zabbix_Templates/blob/master/DFSR/Get-DFSRObjectDiscovery.ps1">Get-DFSRObjectDiscovery.ps1</a> и <a href="https://github.com/perlestius/Zabbix_Templates/blob/master/DFSR/Get-DFSRObjectParam.ps1">Get-DFSRObjectParam.ps1</a> в папку с установленным Zabbix Agent</li>
 <li>Добавьте в конфигурационный файл агента Zabbix строки, заменив &lt;ZabbixAgentFolder&gt; на путь к папке с Zabbix Agent:
  <br>
  <code>UserParameter=dfsr.discovery[*],powershell -NoProfile -ExecutionPolicy Bypass -File "&lt;ZabbixAgentFolder&gt;\Get-DFSRObjectDiscovery.ps1" "$1"
  </code>
  <br>
  <code>
   UserParameter=dfsr.params[*],powershell -NoProfile -ExecutionPolicy Bypass -File "&lt;ZabbixAgentFolder&gt;\Get-DFSRObjectParam.ps1" "$1" "$2" "$3"
   </code>
 </li>
 <li>Перезапустите службу Zabbix Agent</li>
 <li><i>Этот пункт только для Zabbix версий 2.X, т.к. шаблон для версий 3.X и выше уже содержит все необходимые наборы для преобразования значений</i>
  <br>
  <a href="https://www.zabbix.com/documentation/2.2/ru/manual/config/items/mapping">Создайте</a> следующие наборы преобразования значений:<br>
  <code><b>DFSR::ConnectionState</b></code><br>
  <code>0 ⇒ Connecting</code><br>
  <code>1 ⇒ Online</code><br>
  <code>2 ⇒ Offline</code><br>
  <code>3 ⇒ In Error</code><br>
  <br>
  <code><b>DFSR::RFState</b></code><br>
  <code>0 ⇒ Uninitialized</code><br>
  <code>1 ⇒ Initialized</code><br>
  <code>2 ⇒ Initial Sync</code><br>
  <code>3 ⇒ Auto Recovery</code><br>
  <code>4 ⇒ Normal</code><br>
  <code>5 ⇒ In Error</code><br>
  <br>
  <code><b>DFSR::ServiceState</b></code><br>
  <code>0 ⇒ Starting</code><br>
  <code>1 ⇒ Running</code><br>
  <code>2 ⇒ Degraded</code><br>
  <code>3 ⇒ Shutting Down</code><br>
  <code>100 ⇒ Stopped</code><br>
  <code>101 ⇒ Not Found</code><br>
  <br>
  <code><b>DFSR::VolumeState</b></code><br>
  <code>0 ⇒ Initialized</code><br>
  <code>1 ⇒ Shutting Down</code><br>
  <code>2 ⇒ In Error</code><br>
  <code>3 ⇒ Auto Recovery</code><br>
 </li>

<li><a href="https://www.zabbix.com/documentation/current/ru/manual/xml_export_import/templates#%D0%B8%D0%BC%D0%BF%D0%BE%D1%80%D1%82">Импортируйте</a> шаблон мониторинга на сервер Zabbix:
 <ul>
  <li><a href="https://github.com/perlestius/Zabbix_Templates/blob/master/DFSR/Template_App_DFSR_v1.0.2_ZBX_2.2-2.4.xml">Template_App_DFSR_v1.0.2_ZBX_2.2-2.4.xml</a> - для Zabbix от версии 2.2 до 2.4</li>
  <li><a href="https://github.com/perlestius/Zabbix_Templates/blob/master/DFSR/Template_App_DFSR_v1.0.2_ZBX_3.0-5.0.xml">Template_App_DFSR_v1.0.2_ZBX_3.0-5.0.xml</a> - для Zabbix от версии 3.0 до 5.0</li>
 </ul> 
 </li>
 <li><a href="https://www.zabbix.com/documentation/current/ru/manual/config/hosts/host">Добавьте</a> шаблон к хостам с ролью DFSR</li>
 <li><i>(Опционально).</i> Включите отключенные по умолчанию метрики (правила обнаружения, элементы данных, прототипы элементов), которые вам необходимы</li>
</ol>

<h2>ОБРАТНАЯ СВЯЗЬ</h2>
Предпочтительнее использовать <a href="https://github.com/perlestius/Zabbix_Templates/tree/master/DFSR">GitHub</a>, также можете писать на email: nproskuryakov<собака>gmail[.]com

<h2><img src="https://habrastorage.org/webt/-r/ah/ki/-rahkiabxlu7qekpm5kzibbdumm.png" alt="ОТБЛАГОДАРИТЬ"/></h2>
<p>Шаблон распространяется бесплатно, но если Вы человек щедрый, можете поддержать материально - мне будет приятно.</p>
<p>WMID 927723224795<br><a href="https://pay.web.money/927723224795"</a><img src="https://www.webmoney.ru/img/icons/88x31_wm_blue.png" alt="WebMoney"></a></p>

<p><a href="https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=nproskuryakov@gmail.com&item_name=Thanks for DFSR Zabbix Template&no_shipping=1&no_note=1&tax=0&currency_code=USD&lc=US&bn=PP_DonationsBF" &target="_self"</a><img src="https://www.paypalobjects.com/digitalassets/c/website/marketing/apac/C2/logos-buttons/optimize/26_Grey_PayPal_Pill_Button.png" alt="PayPal"></a></p>
