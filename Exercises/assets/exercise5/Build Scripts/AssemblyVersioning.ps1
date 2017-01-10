##-----------------------------------------------------------------------
## <copyright file="ApplyVersionToAssemblies.ps1">(c) Microsoft Corporation. This source is subject to the Microsoft Permissive License. See http://www.microsoft.com/resources/sharedsource/licensingbasics/sharedsourcelicenses.mspx. All other rights reserved.</copyright>
##-----------------------------------------------------------------------
# Look for a 0.0.0.0 pattern in the build number. 
# If found use it to version the assemblies.
#
# For example, if the 'Build number format' build process parameter 
# $(BuildDefinitionName)_$(Year:yyyy).$(Month).$(DayOfMonth)$(Rev:.r)
# then your build numbers come out like this:
# "Build HelloWorld_2013.07.19.1"
# This script would then apply version 2013.07.19.1 to your assemblies.

Param(    
    [int]$digitsSetInAssemblyVersion = 4,
    [string]$infoversionpostfix = ""
) 

# Enable -Verbose option
[CmdletBinding()]

# Regular expression pattern to find the version in the build number 
# and then apply it to the assemblies
$VersionRegex = "\d+\.\d+\.\d+\.\d+"

# If this script is not running on a build server, remind user to 
# set environment variables so that this script can be debugged
if(-not ($Env:BUILD_SOURCESDIRECTORY -and $Env:BUILD_BUILDNUMBER))
{
    Write-Error "You must set the following environment variables"
    Write-Error "to test this script interactively."
    Write-Host '$Env:BUILD_SOURCESDIRECTORY - For example, enter something like:'
    Write-Host '$Env:BUILD_SOURCESDIRECTORY = "C:\code\FabrikamTFVC\HelloWorld"'
    Write-Host '$Env:BUILD_BUILDNUMBER - For example, enter something like:'
    Write-Host '$Env:BUILD_BUILDNUMBER = "Build HelloWorld_0000.00.00.0"'
    exit 1
}

# Make sure path to source code directory is available
if (-not $Env:BUILD_SOURCESDIRECTORY)
{
    Write-Error ("BUILD_SOURCESDIRECTORY environment variable is missing.")
    exit 1
}
elseif (-not (Test-Path $Env:BUILD_SOURCESDIRECTORY))
{
    Write-Error "BUILD_SOURCESDIRECTORY does not exist: $Env:BUILD_SOURCESDIRECTORY"
    exit 1
}
Write-Host "BUILD_SOURCESDIRECTORY: $Env:BUILD_SOURCESDIRECTORY"

# Make sure there is a build number
if (-not $Env:BUILD_BUILDNUMBER)
{
    Write-Error ("BUILD_BUILDNUMBER environment variable is missing.")
    exit 1
}
Write-Host "BUILD_BUILDNUMBER: $Env:BUILD_BUILDNUMBER"

# Get and validate the version data
$VersionData = [regex]::matches($Env:BUILD_BUILDNUMBER,$VersionRegex)
switch($VersionData.Count)
{
   0        
      { 
         Write-Error "Could not find version number data in BUILD_BUILDNUMBER."
         exit 1
      }
   1 {}
   default 
      { 
         Write-Warning "Found more than instance of version data in BUILD_BUILDNUMBER." 
         Write-Warning "Will assume first instance is version."
      }
}
$NewVersion = $VersionData[0]
Write-Host "Version: $NewVersion"

#-------------------------------------------------------------------------------------------------------------
# Version Pattern Definitions. Differentiate between platform specific patterns.
#-------------------------------------------------------------------------------------------------------------
$buildNumberTokens = $NewVersion.ToString().Split('.')
$assemblyVersionThirdDigit = if($digitsSetInAssemblyVersion -gt 2){ $buildNumberTokens[2]} else {"0"}
$assemblyVersionForthDigit = if($digitsSetInAssemblyVersion -gt 3){ $buildNumberTokens[3]} else {"0"}
$infoversionpostfix = if($infoversionpostfix){[string]::Format("-{0}", $infoversionpostfix)} else { $infoversionpostfix}

$buildNumberAssemblyVersion = [string]::Format("{0}.{1}.{2}.{3}",$buildNumberTokens[0],$buildNumberTokens[1], $assemblyVersionThirdDigit, $assemblyVersionForthDigit)
$buildNumberAssemblyFileVersion = [string]::Format("{0}.{1}.{2}.{3}",$buildNumberTokens[0],$buildNumberTokens[1],$buildNumberTokens[2], $buildNumberTokens[3])
$buildNumberAssemblyInformationalVersion = ([string]::Format("{0}.{1}.{2}.{3}{4}",$buildNumberTokens[0],$buildNumberTokens[1], $buildNumberTokens[2], $buildNumberTokens[3], $infoversionpostfix)).Trim()

$buildNumberVersionCode = ([int]$buildNumberTokens[0])*10000000 + ([int]$buildNumberTokens[1])*100000 + ([int]$assemblyVersionThirdDigit)*100 + ([int]$assemblyVersionForthDigit)*1
$buildNumberVersionName = [string]::Format("{0}.{1}.{2}",$buildNumberTokens[0],$buildNumberTokens[1],$buildNumberTokens[2])

Write-Host "Assembly Version: $buildNumberAssemblyVersion"
Write-Host "Assembly File Version: $buildNumberAssemblyFileVersion"
Write-Host "Assembly File Version: $buildNumberAssemblyInformationalVersion"
Write-Host "Build Number Version Code: $buildNumberVersionCode"
Write-Host "Build Number Version Name: $buildNumberVersionName"

#-------------------------------------------------------------------------------------------------------------
# Replacement Pattern Definition
#-------------------------------------------------------------------------------------------------------------

# AssemblyInfo (*.)
[regex]$patternAssemblyVersion = "(AssemblyVersion\("")(\d+\.\d+\.\d+\.\d+)(""\))"
$replacePatternAssemblyVersion = "`${1}$($buildNumberAssemblyVersion)`${3}"
[regex]$patternAssemblyFileVersion = "(AssemblyFileVersion\("")(\d+\.\d+\.\d+\.\d+)(""\))"
$replacePatternAssemblyFileVersion = "`${1}$($buildNumberAssemblyFileVersion)`${3}"
[regex]$patternAssemblyInformationalVersion = "(AssemblyInformationalVersion\("")(\d+\.\d+\.\d+\.\d+)(""\))"
$replacePatternAssemblyInformationalVersion = "`${1}$($buildNumberAssemblyInformationalVersion)`${3}"

# NuGet (.*nuspec)
[regex]$patternPackageVersion = "(<version>)(\d+\.\d+\.\d+\.\d+)(</version>)"
$replacePatternPackageVersion = "`${1}$($buildNumberAssemblyInformationalVersion)`${3}"

# Droid (AndroidManifest.xml)
[regex]$patternAndroidVersionCode = "(android:versionCode="")(\d+)("")"
$replacePatternAndroidVersionCode = "`${1}$($buildNumberVersionCode)`${3}"
[regex]$patternAndroidVersionName = "(android:versionName="")(\d+\.\d+\.\d+)("")"
$replacePatternAndroidVersionName = "`${1}$($buildNumberVersionName)`${3}"

# iOS (Info.plist)
[regex]$patterniOSCfBundleVersion = "(<key>CFBundleVersion<\/key>)((?:.|\n|\r\n)*?)(<string>)(\d+.\d+)(<\/string>)"
$replacePatterniOSCfBundleVersion = "`${1}`${2}`${3}$($buildNumberAssemblyVersion)`${5}"
[regex]$patterniOSCfBundleShortVersion = "(<key>CFBundleVersion<\/key>)((?:.|\n|\r\n)*?)(<string>)(\d+.\d+)(<\/string>)"
$replacePatterniOSCfBundleShortVersion = "`${1}`${2}`${3}$($buildNumberVersionName)`${5}"

#-------------------------------------------------------------------------------------------------------------
# Replacement Pattern Execution
#-------------------------------------------------------------------------------------------------------------

################################
# Assembly Property Files
################################
$aifiles = gci $Env:BUILD_SOURCESDIRECTORY -recurse -include "*Properties*","My Project","_accessory" | 
    ?{ $_.PSIsContainer } | 
    foreach { gci -Path $_.FullName -Recurse -include *AssemblyInfo.* }
if($aifiles)
{
    Write-Host "Will apply $NewVersion to $($aifiles.count) assembly info files."

    foreach ($file in $aifiles) {
        $filecontent = Get-Content($file)
        attrib $file -r
        $filecontent = $filecontent -replace $patternAssemblyVersion, $replacePatternAssemblyVersion
        $filecontent = $filecontent -replace $patternAssemblyFileVersion, $replacePatternAssemblyFileVersion
        $filecontent = $filecontent -replace $patternAssemblyInformationalVersion, $replacePatternAssemblyInformationalVersion
        $filecontent | Out-File $file -Encoding UTF8
        Write-Host "$($file.FullName) - version applied"
    }
}
else
{
    Write-Warning "No assembly property files found."
}

################################
# NuGet Specification Files
################################
$specfiles = gci $Env:BUILD_SOURCESDIRECTORY -Recurse -include *.nuspec 
if($specfiles)
{
    Write-Host "Will apply $NewVersion to $($specfiles.count) package specification files."

    foreach ($file in $specfiles) {
        $filecontent = Get-Content($file)
        attrib $file -r
        $filecontent = $filecontent -replace $patternPackageVersion, $replacePatternPackageVersion
        $filecontent | Out-File $file -Encoding UTF8
        Write-Host "$($file.FullName) - version applied"
    }
}
else
{
    Write-Warning "No nuget specification files found."
}

################################
# Android Manifest Files
################################
$androidManifestFiles = gci $Env:BUILD_SOURCESDIRECTORY -Recurse -include "AndroidManifest.xml"
if($androidManifestFiles)
{
    Write-Host "Will apply $NewVersion to $($androidManifestFiles.count) android manifest files."

    foreach ($file in $androidManifestFiles) {
        $filecontent = Get-Content($file)
        attrib $file -r
        $filecontent = $filecontent -replace $patternAndroidVersionCode, $replacePatternAndroidVersionCode
        $filecontent = $filecontent -replace $patternAndroidVersionName, $replacePatternAndroidVersionName
        $filecontent | Out-File $file -Encoding UTF8
        Write-Host "$($file.FullName) - version applied"
    }
}
else
{
    Write-Warning "No android manifest.xml files found."
}

################################
# iOS Info Files
################################
$iOSInfoFiles = gci $Env:BUILD_SOURCESDIRECTORY -Recurse -include "Info.plist"
if($iOSInfoFiles)
{
    Write-Host "Will apply $NewVersion to $($iOSInfoFiles.count) iOS info files."

    foreach ($file in $iOSInfoFiles) {
        $filecontent = Get-Content($file)
        attrib $file -r
        $filecontent = $filecontent -replace $patterniOSCfBundleVersion, $replacePatterniOSCfBundleVersion
        $filecontent = $filecontent -replace $patterniOSCfBundleShortVersion, $replacePatterniOSCfBundleShortVersion
        $filecontent | Out-File $file -Encoding UTF8
        Write-Host "$($file.FullName) - version applied"
    }
}
else
{
    Write-Warning "No iOS info.plist files found."
}