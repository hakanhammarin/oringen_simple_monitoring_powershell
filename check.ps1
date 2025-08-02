add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@

[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

$jsonFilePath = 'C:\monitoring\cis.json'
$resutlJsonFilePath = 'C:\monitoring\result\result.json'
$logCsvFilePath = 'C:\monitoring\monitor-logs\'
$days = '30'
$intervals = '10'
$timeout = '600'
$thold =  4 # $intervals * 6 makes aprox 60 seconds downtime
$apiusername = "root"
$apipassword = "00000000"

# Since our password is plaintext we must convert it to a secure string
# before creating a PSCredential object
$securePassword = ConvertTo-SecureString -String $apipassword -AsPlainText -Force
$credential = [PSCredential]::new($apiusername, $securePassword)


$jsonDataCounter = Get-Content -Path $jsonFilePath | ConvertFrom-Json
#Register-EngineEvent  -SourceIdentifier PowerShell.Exiting -Action { PromptBeforeExit }

for(;;) {

$jsonData = Get-Content -Path $jsonFilePath | ConvertFrom-Json

$jsonData | ForEach-Object {
$baseStatus = $_.status

### FUEL START

if ($_.type -eq "FUEL") {

$status = Invoke-RestMethod -Method Get -Uri https://10.0.0.231:1880/api/v1/fuel -Credential $credential 
$status.location
$status.fuel
[string]$fuellevel = $status.fuel
$fuel = [int]$fuellevel
[string]$fuellevel = $status.fuel + '%'


if ($fuel -ge '50') {
write '>50'

        $_.status = '10'
	$_.count = 0
    $jsonDataCounter[$_.index - 1].count = 0
 }

 if ($fuel -le '50') {
write '<50'

        $_.status = '20'
        }
 

if ($fuel -le '10') {
write '<10'

        if ($jsonDataCounter[$_.index - 1].count -eq $thold) {
        $now = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"
        $jsonDataCounter[$_.index - 1].downtime = $now.tostring()}
    
        $_.status = '40'

	$jsonDataCounter[$_.index - 1].count = $jsonDataCounter[$_.index - 1].count + 1
    $_.downtime =    $jsonDataCounter[$_.index - 1].downtime
	$_.count = $jsonDataCounter[$_.index - 1].count
 }

    $now = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"
    $_.time = $now.tostring()
    $_.ip = 'Fuel level: ' + $fuellevel
    $_.rtt = ''
}

### FUEL END ###

### OLA SERVER START

if ($_.type -eq "OLA") {
$fuel = '0'
$_.ip

$status = Invoke-WebRequest -UseBasicParsing -Method Get -Uri $_.ip -TimeoutSec 2
$status.statuscode
$status.loc
[string]$fuellevel = $status.statuscode
$fuel = [int]$fuellevel
#[string]$fuellevel = $status.statuscode + ' ' + $status.StatusDescription


if ($fuel -eq '200') {
write 'OLA SERVER - 200 OK'

        $_.status = '10'
	$_.count = 0
    $jsonDataCounter[$_.index - 1].count = 0
 }

 

if ($fuel -ne '200') {
write 'OLA SERVER DOWN'

        if ($jsonDataCounter[$_.index - 1].count -eq $thold) {
        $now = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"
        $jsonDataCounter[$_.index - 1].downtime = $now.tostring()}
    
        $_.status = '40'

	$jsonDataCounter[$_.index - 1].count = $jsonDataCounter[$_.index - 1].count + 1
    $_.downtime =    $jsonDataCounter[$_.index - 1].downtime
	$_.count = $jsonDataCounter[$_.index - 1].count
 }

    $now = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"
    $_.time = $now.tostring()
    $_.ip = 'Status: ' + $fuellevel
    $_.rtt = ''
}

### OLA SERVER END ###

### ICMP START ###

if ($_.type -eq "icmp") {

try {
$captureCiData = [System.Net.NetworkInformation.Ping]::new().SendPingAsync($_.ip, $timeout)
# $captureCiData = Test-NetConnection -ComputerName $_.ip -InformationLevel Detailed
#$_.ip + $captureCiData.Result.Status.ToString() + $captureCiData.Result.RoundtripTime.ToString()+$baseStatus
}
catch {
}




$_.status = $captureCiData.Result.Status.ToString()
$_.rtt = $captureCiData.Result.RoundtripTime.ToString() + ' ms'

if ($captureCiData.Result.Status.ToString() -eq 'DestinationHostUnreachable') {
    $_.status = 'TimedOut'
}
if ($captureCiData.Result.Status.ToString() -eq 'DestinationNetworkUnreachable') {
    $_.status = 'TimedOut'
}


if ($_.status -eq 'TimedOut') {
    if ($baseStatus -eq 'PORTABLE') {
        $_.status = '30'
    	$jsonDataCounter[$_.index - 1].count = $jsonDataCounter[$_.index - 1].count + 1
   
	$_.count = $jsonDataCounter[$_.index - 1].count
    $_.rtt = ''
 }
 }
if ($_.status -eq 'TimedOut') {
        #$jsonDataCounter[$_.index - 1]
        #$_.index
        if ($jsonDataCounter[$_.index - 1].count -eq $thold) {
        $now = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"
        $jsonDataCounter[$_.index - 1].downtime = $now.tostring()}
    
        if ($jsonDataCounter[$_.index - 1].count -lt $thold) {
        $_.status = '20'}
        else {
        $_.status = '40'}
	$jsonDataCounter[$_.index - 1].count = $jsonDataCounter[$_.index - 1].count + 1
    $_.downtime =    $jsonDataCounter[$_.index - 1].downtime
	$_.count = $jsonDataCounter[$_.index - 1].count
    $_.rtt = ''
 }
if ($_.status -eq 'Success') {
        $_.status = '10'
	$_.count = 0
    $jsonDataCounter[$_.index - 1].count = 0
 }


$now = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"
$_.time = $now.tostring()
}

### ICMP END ###

### LOGGING START ###

$today = Get-Date -UFormat "%Y-%m-%d"
$logCsvFile = $logCsvFilePath + $today + '-monitoring-log.csv'

if ($_.status -ge '30') {
$_ | Sort-Object -Property status,name | Export-Csv $logCsvFile -Append
}
#if ($captureCiData.Result.Status.ToString() -eq 'DestinationHostUnreachable') {
#$_ | Sort-Object -Property status,name | Export-Csv $logCsvFile -Append
#}
if ($captureCiData.Result.RoundtripTime -gt 500) {
$_ | Sort-Object -Property status,name | Export-Csv $logCsvFile -Append
}

}

$jsonData | Sort-Object -Property @{Expression = "status"; Descending = $true},@{Expression = "name"; Descending = $false} | ConvertTo-Json | Set-Content $resutlJsonFilePath
$jsonData | Sort-Object -Property @{Expression = "status"; Descending = $true},@{Expression = "name"; Descending = $false} | Format-Table
#name | Sort-Object -Property status -Descending | Format-Table

#LOGGING ROTATION

$cutoffdate = (get-date).adddays(-$days)
# $cutoffdate
Get-ChildItem -Path $logCsvFilePath -File | Where-Object { $_.LastWriteTime -lt $cutoffdate} | Remove-Item -Force -Verbose

Start-Sleep -Seconds $intervals
}
