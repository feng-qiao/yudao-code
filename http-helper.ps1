param(
    [string]$Method = 'POST',
    [string]$Url,
    [hashtable]$Headers = @{},
    [string]$Body = $null
)
Add-Type -AssemblyName System.Net.Http
$client = New-Object System.Net.Http.HttpClient
$req = New-Object System.Net.Http.HttpRequestMessage
$req.Method = New-Object System.Net.Http.HttpMethod($Method)
$req.RequestUri = New-Object System.Uri($Url)
foreach($k in $Headers.Keys){ $req.Headers.TryAddWithoutValidation($k, $Headers[$k]) | Out-Null }
if($Body){ $req.Content = New-Object System.Net.Http.StringContent($Body, [System.Text.Encoding]::UTF8, 'application/json') }
$resp = $client.SendAsync($req).Result
$status = [int]$resp.StatusCode
$content = $resp.Content.ReadAsStringAsync().Result
[PSCustomObject]@{ Status = $status; Content = $content }
