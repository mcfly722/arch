param(
	$stateFile = "devices_links.json"
)

#  https://www.amd.com/en/support/


$headers = @{"accept-encoding"="gzip, deflate, br"; "cache-control"="no-cache";}

$response = iwr "https://www.amd.com/en/support" -headers $headers

$c=[xml]('<root>'+(($response.Content -split '<option value="" selected="selected">search all products</option>')[1] -split '</select>')[0]+'</root>')

$devices = $c.root.option | select-object @{
	label='id';
	expression={$_.'value'}
},@{
	label='name';
	expression={$_.'#text'}
}

if (Test-Path $stateFile) {
	$links = get-content $stateFile | convertFrom-JSON -asHashtable
} else {
	$links = @{}
}

$devices | % {
	$key = "$($_.id)"
	
	if (-not ($links.ContainsKey($key))) {
		
		$url = "https://www.amd.com/rest/support_alias/en/$($_.id)"
		$link_response = iwr $url -headers $headers -DisableKeepAlive
		$link = (convertFrom-json ($link_response.Content)).link
		write-host "$($_.id) $($_.name) -> $link"

		if (-not ([string]::IsNullOrEmpty($link))){
			$links[$key] = @{
				"name" = $_.name;
				"link" = $link;
				}
			$links | convertTo-json > $stateFile

		}
		sleep 5
	} else {
		write-host "$($_.id) $($links[$_.id].name) -> $($links[$_.id].link))"
	}
}


