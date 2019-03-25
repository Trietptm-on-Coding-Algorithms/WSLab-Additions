function Set-StaticIPAddressUsingWMI {
    param($IPAddress,$SubnetMask,$Gateway,$DNSServer)

    $wmi_object = Get-WmiObject win32_networkadapterconfiguration -filter “ipenabled = ‘true'”
    $wmi_object.EnableStatic($IPAddress, $SubnetMask)
    $wmi_object.SetGateways($Gateway, 1)
    $wmi_object.SetDNSServerSearchOrder($DNSServer)
}