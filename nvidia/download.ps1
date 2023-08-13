param(
    $indexFile = "index.json"
)

function downloadFile {
    param(
        $uri,
        $headers
    )

    $file = $uri.Replace("https://", "").Replace("http://", "") 

    if (Test-Path $file) {
        write-host -ForegroundColor "yellow" "$uri - exist" 
    } else {
        $fileName = ($file -split '/')[-1] + ".tmp"
        $folder = $file.replace(($file -split '/')[-1], '')

        try {
            invoke-webrequest $uri -headers $headers -DisableKeepAlive -outfile $fileName
        } catch {
            throw "download error for $uri - $_"
        }

        try {
            New-Item -ItemType "directory" -Path $folder | Out-Null
        } catch {
        }
        write-host -ForegroundColor "green" "$uri - done"
        Move-Item $fileName $file -force
    }
}

$variants = get-content $indexFile | convertFrom-JSON

$i = 0
$total = ($variants | Measure-Object).Count

foreach ($variant in $variants) {
    $i++
    $percentComplete = [System.Int32]([int]($i * 100 / $total))
    Write-Progress -Activity "Downloading" -PercentComplete $percentComplete -Status "[$i/$total] $percentComplete%"

    if (-not ([string]::IsNullOrEmpty($variant.url))) {
        try {
            downloadFile $variant.url @{}
        } catch {
            write-host $_ -ForegroundColor "red"
            write-host "$($variant | convertTo-json)" "red"
        }
    }
}