$response = iwr https://www.pcilookup.com/api.php?action=search

$response.Content > pci_device_database.json

$database =  ConvertFrom-JSON (get-content pci_device_database.json)