<a href="README-RU.md">Русская версия</a>

<h1>Template for monitoring Windows hosts with DFS Replication role installed</h1>

<h2>FEATURES</h2>
<ul>
 <li>A lot of metrics and triggers for monitoring and troubleshooting DFSR</li>
 <li>Customization via macros</li>
 <li>Descriptions and useful KB links for items and triggers</li>
 <li>Does NOT require DFS management console to be installed (RSAT-DFS-Mgmt-Con)</li>
 <li>Works with various Windows localizations</li>
 <li>Some metrics are disabled by default to minimize server load and network traffic</li>
</ul> 

<h2>REQUIREMENTS</h2>
<ul>
 <li>OS Windows 2008 R2 SP1 or above</li>
 <li>Zabbix 2.2 or above</li>
 <li><a href="https://docs.microsoft.com/en-us/powershell/scripting/windows-powershell/install/installing-windows-powershell?view=powershell-5.1">PowerShell 3.0 or above</a></li>
 <li>Zabbix Agent service account should be a member of local 'Administrators' group on each partner server. It's necessary to get 'backlog size' and 'redundancy' metrics for replicated folders</li>
 <li>Since DFSR is a distributed service, all involved servers should be monitored via this template to get complete information</li>
</ul>

<h2>HOW TO INSTALL</h2>
It is assumed that Zabbix server is already deployed and Zabbix Agent is already installed on host
<ol>
 <li>Add Zabbix Agent service account to the local 'Administrators' group on EACH of partner servers. By default, the service runs under SYSTEM account, so, the computer account should be added. Instead, you can create special AD account for Zabbix Agent service and add that account to the local 'Administrators' group on each partner server via <a href="https://morgansimonsen.com/2008/03/25/working-with-group-policy-restricted-groups-policies-2/">group policy</a>
 </li>
 <li>Copy <a href="https://github.com/perlestius/Zabbix_Templates/blob/master/DFSR/Get-DFSRObjectDiscovery.ps1">Get-DFSRObjectDiscovery.ps1</a> and <a href="https://github.com/perlestius/Zabbix_Templates/blob/master/DFSR/Get-DFSRObjectParam.ps1">Get-DFSRObjectParam.ps1</a> files to Zabbix Agent folder</li>
 <li>Add these lines to Zabbix Agent configuration file (&lt;ZabbixAgentFolder&gt; should be replaced with path to Zabbix Agent folder):
  <br>
  <code>UserParameter=dfsr.discovery[*],powershell -NoProfile -ExecutionPolicy Bypass -File "&lt;ZabbixAgentFolder&gt;\Get-DFSRObjectDiscovery.ps1" "$1"
  </code>
  <br>
  <code>
   UserParameter=dfsr.params[*],powershell -NoProfile -ExecutionPolicy Bypass -File "&lt;ZabbixAgentFolder&gt;\Get-DFSRObjectParam.ps1" "$1" "$2" "$3"
   </code>
 </li>
 <li>Restart Zabbix Agent service</li>
  <li><i>This point is for Zabbix 2.X only, because the template for Zabbix 3.X and above has these mappings included</i>
  <br>
  <a href="https://www.zabbix.com/documentation/2.2/manual/config/items/mapping">Add</a> value mappings listed below:<br>
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
 </li>
 <li><a href="https://www.zabbix.com/documentation/current/manual/xml_export_import/templates#importing">Import</a> the template to Zabbix server:
 <ul>
  <li><a href="https://github.com/perlestius/Zabbix_Templates/blob/master/DFSR/Template_App_DFSR_v1.0.1_ZBX_2.2-2.4.xml">Template_App_DFSR_v1.0.1_ZBX_2.2-2.4.xml</a> - for Zabbix version 2.2 to 2.4</li>
  <li><a href="https://github.com/perlestius/Zabbix_Templates/blob/master/DFSR/Template_App_DFSR_v1.0.1_ZBX_3.0-5.0.xml">Template_App_DFSR_v1.0.1_ZBX_3.0-5.0.xml</a> - for Zabbix version from 3.0 to 5.0</li>
 </ul> 
 </li>
 <li><a href="https://www.zabbix.com/documentation/current/manual/config/hosts/host">Add</a> the template to DFSR hosts</li>
 <li><i>(Optional).</i> Enable disabled items and item prototypes you need</li>
</ol>

<h2>FEEDBACK</h2>
It's better to use <a href="https://github.com/perlestius/Zabbix_Templates/tree/master/DFSR">GitHub</a>. Also, you can communicate with me via email: nproskuryakov[@]gmail[.]com

<h2><img src="https://habrastorage.org/webt/tp/ok/ve/tpokvey7famegbrfsgrmtk6iuju.png" alt="DONATE"/></h2>
<p>The template is free. Nevertheless, if you are generous person, I will be pleased to receive your "thank$" :)</p>
<p>WMID 927723224795<br><a href="https://pay.web.money/927723224795"</a><img src="https://www.webmoney.ru/img/icons/88x31_wm_blue.png" alt="WebMoney"></a></p>

<p><a href="https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=nproskuryakov@gmail.com&item_name=Thanks for DFSR Zabbix Template&no_shipping=1&no_note=1&tax=0&currency_code=USD&lc=US&bn=PP_DonationsBF" &target="_self"</a><img src="https://www.paypalobjects.com/digitalassets/c/website/marketing/apac/C2/logos-buttons/optimize/26_Grey_PayPal_Pill_Button.png" alt="PayPal"></a></p>
