param($installPath, $toolsPath, $package, $project)

#Import Modules
Import-Module (Join-Path $toolsPath "Copy-DB.psm1")
Import-Module (Join-Path $toolsPath "Copy-EcfConfigsIfNotExist.psm1")
Import-Module (Join-Path $toolsPath "Get-Config.psm1")
Import-Module (Join-Path $toolsPath "Get-ConfigPath.psm1")
Import-Module (Join-Path $toolsPath "Get-ConnectionConfigPath.psm1")
Import-Module (Join-Path $toolsPath "Get-EPiServerCommerceConnectionString.psm1")
Import-Module (Join-Path $toolsPath "Get-PackagesToolPath.psm1")
Import-Module (Join-Path $toolsPath "Set-CommerceManagerSearchIndexBasePath.psm1")
Import-Module (Join-Path $toolsPath "Set-NameSpace.psm1")

Function Get-InstalledPackage
{
	param ([string]$projectName, [string]$packageId)

	return Get-Package -ProjectName $projectName | Where-Object { $_.id -eq $packageId} | Sort-Object -Property Version -Descending | Select-Object -First 1
}

$projectFilePath = Get-ChildItem $project.Fullname

$sitePath = $projectFilePath.Directory.FullName

$WebConfigFile = Get-ConfigPath $project

$epiConnection = Get-EPiServerCommerceConnectionString($WebConfigFile)
if ($epiConnection -eq $null)
{
	Write-Host "Starting Deploy into $($project.ProjectName)"

	#Get the Framework package
	$frameworkPackage = Get-InstalledPackage $project.ProjectName "EPiServer.Framework"

	# Get EPiDeploy.exe Path
	$frameworkToolPath = Get-PackagesToolPath $installPath "EPiServer.Framework" $frameworkPackage.Version
	$deployEXEPath = Join-Path ($frameworkToolPath) "epideploy.exe"

	$episerverWebConfig = Join-Path $toolsPath "EPiServer.Commerce.config"
	# Deploy Web Config
	&$deployEXEPath  -a config -s $sitePath  -p $episerverWebConfig

	# Make unique DB name
	$seed = [GUID]::NewGuid()
	$uniqueDB = "EcfSqlConnection_" + $seed.ToString("N").Substring(0,8)

	# Copying DB -> App_Data
	Write-Host "Copying $($uniqueDB) To $($project.ProjectName) -> App_Data"
	$emptyMdfFile = Join-Path $toolsPath "EPiServer.Commerce.mdf"

	Copy-DB $toolsPath $sitePath "$($uniqueDB).mdf" $emptyMdfFile

	$connectionPath = Get-ConnectionConfigPath $sitePath
	$connectionContent = Get-Content -Path $connectionPath

    # Modify ConnectionString if version only supports LocalDB\v11.0
    $vsVersion = [System.Version]::Parse($project.DTE.Version)
    $localDBDataSource = if ($vsVersion.Major -lt 14) { "(LocalDb)\v11.0" } else { "(LocalDb)\MSSQLLocalDB" }
    $connectionContent = $connectionContent -replace "{LocalDB_DataSource}", $localDBDataSource

	# Modify ConnectionString according to seed
	$connectionContent = $connectionContent -replace "{EcfSqlConnection_SEED}", $uniqueDB

	Set-Content $connectionContent -path $connectionPath

	$commerceCorePackage = $frameworkPackage = Get-InstalledPackage $project.ProjectName "EPiServer.Commerce.Core"
	$commerceCoreToolsPath = Get-PackagesToolPath $installPath "EPiServer.Commerce.Core" $commerceCorePackage.Version
	$commerceCoreDbPath = Join-Path ($commerceCoreToolsPath) "EPiServer.Commerce.Core.sql"

	#Update search config
	$searchConfigPath = Join-Path $toolsPath "Configs\Mediachase.Search.Config"
	$searchIndexBasePath = "[appDataPath]\Search\ECApplication\"
	$searchConfig = Get-Config $searchConfigPath
	Set-CommerceManagerSearchIndexBasePath $searchConfig $searchIndexBasePath
	$searchConfig.Save($searchConfigPath)

    #Copy ecf Configs to the site if not exist
	Copy-EcfConfigsIfNotExist $project $toolsPath $sitePath

	#Modify initialization module namespace
    $infrastructureSourcePath = Join-Path $toolsPath ".\Infrastructure"
	$infrastructurePath = Join-Path $sitePath "\Infrastructure"

	#Create folder if it does not exist
	New-Item -Force -ItemType Directory -Path $infrastructurePath

	#Copy Infrastructure items, just don't overwrite.
	Get-ChildItem -Path $infrastructureSourcePath | Copy-Item -Destination $infrastructurePath -Recurse -Container

	Add-ProjectItems $project $infrastructurePath
	$initializationModulePath = Join-Path $sitePath "\Infrastructure\EPiServerCommerceInitializationModule.cs"
	Set-NameSpace $initializationModulePath $project.Properties.Item("DefaultNamespace").Value.ToString();

	# Run Script
	Write-Host "Running $($commerceCoreDbPath) into $($uniqueDB)"
	&$deployEXEPath -a sql -s $sitePath -p $commerceCoreDbPath -v false -c "EcfSqlConnection"

	Write-Host "EPiServer.Commerce is installed"
}

# SIG # Begin signature block
# MIIOLQYJKoZIhvcNAQcCoIIOHjCCDhoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU1XLBXMc+45PI8h8uODlSXI2V
# 6y+gggtkMIIFZzCCBE+gAwIBAgIRAJgvkmklxJsCm+Wj934zo1UwDQYJKoZIhvcN
# AQELBQAwfDELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3Rl
# cjEQMA4GA1UEBxMHU2FsZm9yZDEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSQw
# IgYDVQQDExtTZWN0aWdvIFJTQSBDb2RlIFNpZ25pbmcgQ0EwHhcNMTkwNTIyMDAw
# MDAwWhcNMjIwNTIxMjM1OTU5WjCBtTELMAkGA1UEBhMCU0UxDjAMBgNVBBEMBTEx
# MTU2MQ8wDQYDVQQIDAZTd2VkZW4xEjAQBgNVBAcMCVN0b2NraG9sbTEaMBgGA1UE
# CQwRUmVnZXJpbmdzZ2F0YW4gNjcxETAPBgNVBBIMCEJveCA3MDA3MRUwEwYDVQQK
# DAxFcGlzZXJ2ZXIgQUIxFDASBgNVBAsMC0VuZ2luZWVyaW5nMRUwEwYDVQQDDAxF
# cGlzZXJ2ZXIgQUIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCzINB4
# kpvfTyclYG7iRSjY0covfFRSheJU1QOBl314IschK8/iEmh3F648RFtQpB+eflYf
# iw4wSDKidpjgvtnfw4fTsGSDWssTsVfoLKhh+xfu6P//hAFs7ZER/RLcNiAXncJU
# 3mb2YrSnsOoGFmcDKu8DOTXae6Gl8PBODF74jmOi6H9/dMVlstwYVkbvSN+yYVOL
# 5K58YOHD2fLGWG9DhMP59JrydmNsI8kVEGGV7VB8gHtnOZX5g6XRZBX+0BDwfRK5
# JtfTLxekbwL/YZGnkGzZxQCmyXKee3sKQ3RDM0fgqy5MI0mYV+RzN/fwKvzufHuH
# wn0iKLQWEpw2XI63AgMBAAGjggGoMIIBpDAfBgNVHSMEGDAWgBQO4TqoUzox1Yq+
# wbutZxoDha00DjAdBgNVHQ4EFgQU/BUJomwrLBnNXS6piwNCZONBLiQwDgYDVR0P
# AQH/BAQDAgeAMAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwEQYJ
# YIZIAYb4QgEBBAQDAgQQMEAGA1UdIAQ5MDcwNQYMKwYBBAGyMQECAQMCMCUwIwYI
# KwYBBQUHAgEWF2h0dHBzOi8vc2VjdGlnby5jb20vQ1BTMEMGA1UdHwQ8MDowOKA2
# oDSGMmh0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1JTQUNvZGVTaWduaW5n
# Q0EuY3JsMHMGCCsGAQUFBwEBBGcwZTA+BggrBgEFBQcwAoYyaHR0cDovL2NydC5z
# ZWN0aWdvLmNvbS9TZWN0aWdvUlNBQ29kZVNpZ25pbmdDQS5jcnQwIwYIKwYBBQUH
# MAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28uY29tMCAGA1UdEQQZMBeBFXN1cHBvcnRA
# ZXBpc2VydmVyLmNvbTANBgkqhkiG9w0BAQsFAAOCAQEAhL8vG/WPbjHDEoAuh+Kk
# q2NFnrQDK0MEyHmuCoWjQwP+guYcHw7/R8jrqTJARYDlMdp8bx9DD8tcgAuhB9sL
# ZPlQiGyGAIQzyizHSdrPFKgo2yABSnwgodYpvlbVJEJxQ1ijbfny3ypPQnwHdpYU
# tDZ1BJks4/P8+EMETtOmrMi9otFY3YnFEE70VRBKFagAb1IrAoYCTMqfskR4uUm1
# w6En4miFfx8fiSC669pwQENAo+Slx1tA5wQBchql0wutohSs9k6DRtudA5PhVl9c
# wW0EoXPZ3prh1/x2JmFhIPDP/WKKyGMAwxBTRY7qWwzz+u3AO72rrl6rLstk3HV6
# PTCCBfUwggPdoAMCAQICEB2iSDBvmyYY0ILgln0z02owDQYJKoZIhvcNAQEMBQAw
# gYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpOZXcgSmVyc2V5MRQwEgYDVQQHEwtK
# ZXJzZXkgQ2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3b3JrMS4wLAYD
# VQQDEyVVU0VSVHJ1c3QgUlNBIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MB4XDTE4
# MTEwMjAwMDAwMFoXDTMwMTIzMTIzNTk1OVowfDELMAkGA1UEBhMCR0IxGzAZBgNV
# BAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEYMBYGA1UE
# ChMPU2VjdGlnbyBMaW1pdGVkMSQwIgYDVQQDExtTZWN0aWdvIFJTQSBDb2RlIFNp
# Z25pbmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCGIo0yhXoY
# n0nwli9jCB4t3HyfFM/jJrYlZilAhlRGdDFixRDtsocnppnLlTDAVvWkdcapDlBi
# pVGREGrgS2Ku/fD4GKyn/+4uMyD6DBmJqGx7rQDDYaHcaWVtH24nlteXUYam9Cfl
# fGqLlR5bYNV+1xaSnAAvaPeX7Wpyvjg7Y96Pv25MQV0SIAhZ6DnNj9LWzwa0VwW2
# TqE+V2sfmLzEYtYbC43HZhtKn52BxHJAteJf7wtF/6POF6YtVbC3sLxUap28jVZT
# xvC6eVBJLPcDuf4vZTXyIuosB69G2flGHNyMfHEo8/6nxhTdVZFuihEN3wYklX0P
# p6F8OtqGNWHTAgMBAAGjggFkMIIBYDAfBgNVHSMEGDAWgBRTeb9aqitKz1SA4dib
# wJ3ysgNmyzAdBgNVHQ4EFgQUDuE6qFM6MdWKvsG7rWcaA4WtNA4wDgYDVR0PAQH/
# BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0lBBYwFAYIKwYBBQUHAwMG
# CCsGAQUFBwMIMBEGA1UdIAQKMAgwBgYEVR0gADBQBgNVHR8ESTBHMEWgQ6BBhj9o
# dHRwOi8vY3JsLnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQ2VydGlmaWNhdGlv
# bkF1dGhvcml0eS5jcmwwdgYIKwYBBQUHAQEEajBoMD8GCCsGAQUFBzAChjNodHRw
# Oi8vY3J0LnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQWRkVHJ1c3RDQS5jcnQw
# JQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZIhvcN
# AQEMBQADggIBAE1jUO1HNEphpNveaiqMm/EAAB4dYns61zLC9rPgY7P7YQCImhtt
# EAcET7646ol4IusPRuzzRl5ARokS9At3WpwqQTr81vTr5/cVlTPDoYMot94v5JT3
# hTODLUpASL+awk9KsY8k9LOBN9O3ZLCmI2pZaFJCX/8E6+F0ZXkI9amT3mtxQJmW
# unjxucjiwwgWsatjWsgVgG10Xkp1fqW4w2y1z99KeYdcx0BNYzX2MNPPtQoOCwR/
# oEuuu6Ol0IQAkz5TXTSlADVpbL6fICUQDRn7UJBhvjmPeo5N9p8OHv4HURJmgyYZ
# SJXOSsnBf/M6BZv5b9+If8AjntIeQ3pFMcGcTanwWbJZGehqjSkEAnd8S0vNcL46
# slVaeD68u28DECV3FTSK+TbMQ5Lkuk/xYpMoJVcp+1EZx6ElQGqEV8aynbG8HAra
# fGd+fS7pKEwYfsR7MUFxmksp7As9V1DSyt39ngVR5UR43QHesXWYDVQk/fBO4+L4
# g71yuss9Ou7wXheSaG3IYfmm8SoKC6W59J7umDIFhZ7r+YMp08Ysfb06dy6LN0Kg
# aoLtO0qqlBCk4Q34F8W2WnkzGJLjtXX4oemOCiUe5B7xn1qHI/+fpFGe+zmAEc3b
# tcSnqIBv5VPU4OOiwtJbGvoyJi1qV3AcPKRYLqPzW0sH3DJZ84enGm1YMYICMzCC
# Ai8CAQEwgZEwfDELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hl
# c3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVk
# MSQwIgYDVQQDExtTZWN0aWdvIFJTQSBDb2RlIFNpZ25pbmcgQ0ECEQCYL5JpJcSb
# Apvlo/d+M6NVMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAA
# MBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgor
# BgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSGHNrfszfgLKljYpZTWmYKHf4AXTAN
# BgkqhkiG9w0BAQEFAASCAQBWRMpJm2ltGdSVHNwhThBWC0g35MZO/tRZV9PIE5qs
# v7K6aQaQ/wLmJ2fuSzIncGppsD9uRSLNrgswHoMzkhj9CvKALJYmpksj+FIvSlMz
# yTeOp+/Aa6c8Bax/9zBNmogEl+R1h3f2Jy2uREfIrRCwxyvOyeV/62c1axR6aT8U
# tt+EfXk9HTp57DaGCWHRE2Dz4AOKfMHiMBLIJZzVnI48IWpdTdofKwIySrWe8mnj
# LkwoefjYmuqVGehmXm+nULSe6WuBhG9CFK1BIILgMtiFzlKmP0qtOSEwpSwBfEvi
# 7qXfg7UjwEmd2NsQ0ox4RFkoqVIgpkXdJJw5h7mvuq6M
# SIG # End signature block
