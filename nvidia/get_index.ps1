param(
	$stateFile = "links.json",
	$site = 'https://www.nvidia.com'
)

# https://www.nvidia.com/download/index.aspx?lang=en

$ErrorActionPreference = "Stop"

$global:cache1 = @{}
if (test-path -path "1.cache") {
	$global:cache1 = get-content "1.cache" | convertfrom-JSON -AsHashtable
}

$global:cache3 = @{}
if (test-path -path "3.cache") {
	$global:cache3 = get-content "3.cache" | convertfrom-JSON -AsHashtable
}

$global:cache4 = @{}
if (test-path -path "4.cache") {
	$global:cache4 = get-content "4.cache" | convertfrom-JSON -AsHashtable
}

function getNvidiaDriversRefferencies {
	param(
		$site
	)

	$headers = @{"accept-encoding" = "gzip, deflate, br"; "cache-control" = "no-cache"; "Referer" = "$site/" }


	$url = "$site/download/API/lookupValueSearch.aspx?TypeID=1"
	write-host $url
	$response = invoke-webrequest "$site/download/API/lookupValueSearch.aspx?TypeID=1" -headers $headers
	$ProductTypes = ([xml]($response.Content)).LookupValueSearch.LookupValues.LookupValue

	ForEach ($ProductType in $ProductTypes) {
		$url = "$site/download/API/lookupValueSearch.aspx?TypeID=2&ParentId=$($ProductType.Value)"
		write-host $url
		$response = invoke-webrequest $url -headers $headers
		$ProductSeries = ([xml]($response.Content)).LookupValueSearch.LookupValues.LookupValue

		ForEach ($ProductSerie in $ProductSeries) {

			$url = "$site/download/API/lookupValueSearch.aspx?TypeID=3&ParentId=$($ProductSerie.Value)"
			write-host $url
			$response = invoke-webrequest $url -headers $headers
			$Products = ([xml]($response.Content)).LookupValueSearch.LookupValues.LookupValue

			$url = "$site/download/API/lookupValueSearch.aspx?TypeID=4&ParentId=$($ProductSerie.Value)"
			write-host $url
			$response = invoke-webrequest $url -headers $headers
			$OSs = ([xml]($response.Content)).LookupValueSearch.LookupValues.LookupValue

			$url = "$site/download/API/lookupValueSearch.aspx?TypeID=6&ParentId=$($ProductSerie.Value)"
			write-host $url
			$response = invoke-webrequest $url -headers $headers
			$DownloadTypes = ([xml]($response.Content)).LookupValueSearch.LookupValues.LookupValue


			write-host "$($Products | Format-Table | Out-String)"
			write-host "$($OSs | Format-Table | Out-String)"
			write-host "$($DownloadTypes | Format-Table | Out-String)"

			foreach ($product in $Products) {
			
				foreach ($OS in $OSs) {
			
					$form = @{
						"psid"  = $($ProductSerie.Value); # series ID
						"pfid"  = $($product.Value); # product ID
						"rpf"   = 1;
						"osid"  = $($OS.Value); # OS ID
						"lid"   = 1;
						"lang"  = "en-us";
						"ctk"   = 0;
						"dtid"  = 1
						"dtcid" = 0;
					}

					$keys = $("psid", "pfid", "rpf", "osid", "lid", "lang", "ctk", "dtid", "dtcid")

					$cgi = ($keys | ForEach-Object { $_ + "=" + $form[$_] + "&" }) -join ''
					$driver_url = "$site/download/processDriver.aspx?$cgi"

					$result1 = (1) | select-object @{
						Label   = "ProductSerie";
						Express = { $ProductSerie.Name }
					}, @{
						Label   = "ProductSerieID";
						Express = { $ProductSerie.Value }
					}, @{
						Label   = "Product";
						Express = { $product.Name }
					}, @{
						Label   = "ProductID";
						Express = { $product.Value }
					}, @{
						Label      = "OS";
						Expression = { $OS.Name }
					}, @{
						Label      = "OS_ID";
						Expression = { $OS.Value }
					}, @{
						Label      = "url1";
						Expression = { $driver_url }
					}

					$result1 | select-object *, @{
						Label      = 'url2';
						Expression = {
							if (($global:cache1).ContainsKey($_.url1)) {
								$url2 = $global:cache1[$_.url1]
								write-host "from cache: $url2" -ForegroundColor "cyan"
								$url2
							} else {
								$response = invoke-webrequest $_.url1 -headers $headers
								$url2 = $response.Content

								write-host "$($_ | Format-list | out-string)"

								if ($url2 -match 'No certified downloads were found for this configuration') {
									write-host $url2 -ForegroundColor "red"
									$global:cache1[$_.url1] = ""
								} else {
									write-host $url2 -ForegroundColor "green"
									$global:cache1[$_.url1] = $url2
									$url2
								}
							}

							write-host ""
						} 
					} 
				}

				write-host "writing cache 1" -ForegroundColor "magenta"
				$global:cache1 | ConvertTo-Json > "1.cache"
			}
		}
	}
}

if (-not(test-path -path '2.cache')) {
	$variants1 = getNvidiaDriversRefferencies $site
	convertTo-JSON -InputObject $variants1 > 2.cache
}

$variants_group = get-content '2.cache' | convertFrom-JSON | group-object url2

$i = 0
$total = ($variants_group | measure-object).Count

foreach ($variant in $variants_group) {
	$url = $($variant.Name)

	if (-not([string]::IsNullOrEmpty($url))) {
		write-host "[$i/$total] url: $url"

		if (($global:cache3).ContainsKey($url)) {
			write-host "from cache: $($global:cache3[$url])" -ForegroundColor "cyan"
		} else {
			try {
				$response = invoke-webrequest "https://www.nvidia.com/download/$url" -headers $headers

				$link = (($response.Content -split "`n" | Where-Object { $_ -match 'lnkDwnldBtn' }) -split '"')[1]
				write-host "$link" -ForegroundColor "green"
				$global:cache3[$url] = $link
			} catch {
				write-host $_ -ForegroundColor "red"
			}
		}
	}

	$i++
	if ($i % 30 -eq 0) {
		write-host "writing cache 3" -ForegroundColor "magenta"
		$global:cache3 | ConvertTo-Json > "3.cache"
	}
}

$global:cache3 | ConvertTo-Json > "3.cache"

write-host "---------------------------------------------------------------------------------------------------"

$i = 0
$total = ($global:cache3.Values | measure-object).Count

foreach ($uri in $global:cache3.Values) {
	if ((-not([string]::IsNullOrEmpty($uri))) -and ($global:cache4).ContainsKey($uri)) {
		write-host "from cache 4: $($global:cache4[$uri])" -ForegroundColor "cyan"
	} else {
		try {
			$url = "https://www.nvidia.com/$uri"

			write-host "[$i/$total] url: $url"
			
			$response = invoke-webrequest $url -headers $headers
			$link = ((($response.Content -split "`n" | Where-Object { $_ -match 'a href="//' }) -split 'a href="')[1] -split '"')[0]
			if ([string]::IsNullOrEmpty($link)) {
				write-host "could not parse $url" -ForegroundColor "red"
			} else {
				write-host "$link" -ForegroundColor "green"
				$global:cache4[$uri] = $link
			}
		} catch {
			write-host $_ -ForegroundColor "red"
		}
	}

	$i++
	if ($i % 30 -eq 0) {
		write-host "writing cache 4" -ForegroundColor "magenta"
		$global:cache4 | ConvertTo-Json > "4.cache"
	}
}

$global:cache4 | ConvertTo-Json > "4.cache"



$variants2 = get-content '2.cache' | convertFrom-JSON

$variants3 = $variants2 | select-object *, @{
	Label      = "url3";
	Expression = {
		$global:cache3[$_.url2]
	}
}

$variants = $variants3 | select-object *, @{
	Label      = "url";
	Expression = {

		$url = $global:cache4[$_.url3]
		if ($url.StartsWith("//")) {
			"https:$url"
		} else {
			$url
		}
	}
}

$variants | convertTo-JSON > index.json