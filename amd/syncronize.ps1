param(
	$stateFile = "devices_links.json",
	$sleepBetweenQueriesSec = 3,
	$site = 'https://www.amd.com'
)

#  https://www.amd.com/en/support/

$ErrorActionPreference = "Stop"

function downloadFile {
	param(
		$uri,
		$headers
	)

	$file = $uri.Replace("https://", "").Replace("http://", "") 

	if (Test-Path $file) {
		write-host -ForegroundColor "yellow" "$uri - ok"
	}
	else {
		$fileName = ($file -split '/')[-1] + ".tmp"
		$folder = $file.replace(($file -split '/')[-1], '')

		try {
			invoke-webrequest $uri -headers $headers -DisableKeepAlive -outfile $fileName
		}
		catch {
			write-host -ForegroundColor "red" "download error for $uri - $_"
			return
		}

		try {
			New-Item -ItemType "directory" -Path $folder | Out-Null
		}
		catch {}
		write-host -ForegroundColor "green" "$uri - done"
		Move-Item $fileName $file -force
	}
}

$headers = @{"accept-encoding" = "gzip, deflate, br"; "cache-control" = "no-cache"; "Referer" = "$site/" }

$response = invoke-webrequest "$site/en/support" -headers $headers

$c = [xml]('<root>' + (($response.Content -split '<option value="" selected="selected">search all products</option>')[1] -split '</select>')[0] + '</root>')

$devices = $c.root.option | select-object @{
	label      = 'id';
	expression = { $_.'value' }
}, @{
	label      = 'name';
	expression = { $_.'#text' }
}

if (Test-Path $stateFile) {
	$links = get-content $stateFile | convertFrom-JSON -asHashtable
}
else {
	$links = @{}
}

foreach ($device in $devices) {
	$key = "$($device.id)"
	
	if (-not ($links.ContainsKey($key))) {
		
		$url = "$site/rest/support_alias/en/$($device.id)"
		$link_response = invoke-webrequest $url -headers $headers -DisableKeepAlive
		$link = (convertFrom-json ($link_response.Content)).link
		write-host "$($device.id) $($device.name) -> $link"

		if (-not ([string]::IsNullOrEmpty($link))) {
			$links[$key] = @{
				"name" = $device.name;
				"link" = $link;
			}
			$links | convertTo-json > $stateFile

		}
		start-sleep $sleepBetweenQueriesSec
	}
 else {
		write-host "$($device.id) $($links[$device.id].name) -> $($links[$device.id].link))"
	}

	if ($links.ContainsKey($key) -and ([string]::IsNullOrEmpty($links[$key].downloads))) {
		$url = "$site" + $links[$key].link
		$response = invoke-webrequest $url -headers $headers -DisableKeepAlive
		
		$tags = ($response.Content | select-string -Pattern '<a (.*)\>' -AllMatches).Matches.Value | Where-Object { $_ -match 'Download' }
		$downloads = $tags | ForEach-Object { (($_.TrimStart('<a href=').Trim('"') -split '"')[0]) } |  Where-Object { -not ($_ -match 'eula') }

		foreach ($download in $downloads) {
			write-host "`t$download"
		}
		
		if (-not([string]::IsNullOrEmpty($downloads))) {
			$links[$key].downloads = $downloads
			$links | convertTo-json > $stateFile
			start-sleep $sleepBetweenQueriesSec			
		}
		
	}

	if ($links.ContainsKey($key) -and (-not([string]::IsNullOrEmpty($links[$key].downloads)))) {
		$downloads = $links[$key].downloads | Where-Object { -not $_.endsWith('/') }

		foreach ($uri in $downloads) {
			downloadFile -uri $uri -headers $headers
		}
	}
}


