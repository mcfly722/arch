param(
    $site = 'https://www.pcilookup.com/api.php?action=search'
)

$response = Invoke-WebRequest $site

$response.Content > pci_device_database.json

#$database = ConvertFrom-JSON (get-content pci_device_database.json)
