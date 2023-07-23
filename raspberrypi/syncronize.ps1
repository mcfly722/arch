param(
	$site = 'https://downloads.raspberrypi.org/os_list_imagingutility_v3.json'
)

function downloadFile {
	param(
		$uri,
		$headers
	)

	$file = $uri.Replace("https://", "").Replace("http://", "") 

	if (Test-Path $file) {
		write-host -ForegroundColor "yellow" "$uri - exist"
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

function getAllSubitemsRecursivelly {
	param ($items)

	foreach ($item in $items) {
		if (-not ([string]::IsNullOrEmpty($item.url))) {
			write-host -ForegroundColor green "$($item.name) -> $($item.url)"
			$item
		}
		else {
			if (-not ([string]::IsNullOrEmpty($item.subitems))) {
				getAllSubitemsRecursivelly $item.subitems
			} 
			if (-not ([string]::IsNullOrEmpty($item.subitems_url))) {
				write-host -ForegroundColor yellow "request:$($item.subitems_url)"
				$response = invoke-webrequest $item.subitems_url
				$l = ($response.Content | convertFrom-json).os_list
				getAllSubitemsRecursivelly $l
			}
		}
	}
}

$response = invoke-webrequest $site
$list = ($response.Content | convertFrom-json).os_list

$distribs = getAllSubitemsRecursivelly $list

$distribs | convertTo-json > distributives.json

$global:i = [double]0
$total = [double](($distribs | measure-object).Count)

$headers = @{"accept-encoding" = "gzip, deflate, br"; "cache-control" = "no-cache" }


foreach ($distrib in $distribs) {
	write-host $($distrib | fl * | out-string)

	$global:i++
	$percentComplete = [System.Int32]([int]($global:i * 100 / $total))
	Write-Progress -Activity "Downloading" -PercentComplete $percentComplete -Status "$percentComplete % ($global:i/$total)"

	downloadFile $distrib.url $headers
}
