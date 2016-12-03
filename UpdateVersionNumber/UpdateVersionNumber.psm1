function Update-VersionNumber {
    [CmdletBinding()]
    param (
    [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
    [Alias('define')]
    [String]$VersionNumber = "*.*.*.+",
    [Parameter(Mandatory=$false)]
    [Alias('Current','c')]
    [Switch]$CurrentVersion
    )
    process {  
    
        if ($CurrentVersion -and (Test-Path -Path $PriorVersionFile)) {
            Write-Output "Current Version: "(Get-Content $PriorVersionFile)
            exit  
        }
    
        if ($VersionNumber -notmatch "(\d+|\*|\+|\-)\.(\d+|\*|\+|\-)\.(\d+|\*|\+|\-)\.(\d+|\*|\+|\-)") {
            Throw "'$VersionNumber' is not a valid version number. Please enter a version number with the format x.x.x.x"
        }

        $VersionRegex = "\d+\.\d+\.\d+\.\d+"
        $SubVersionRegex = "\d+|\*|\+|\-"

        $Folder = $Env:BUILD_SOURCESDIRECTORY
        $Files = "$Folder\FILE1",
                    "$Folder\FILE2",
                    "$Folder\FILE3",
        $WixSetupFile = "$Folder\WIXFILE.wixproj"
        $PriorVersionFile = "$Folder\currentversion.txt"
        $PriorFullVersionNumber = ""

        if (Test-Path -Path $PriorVersionFile) {
            $PriorFullVersionNumber = Get-Content $PriorVersionFile    
        } else {
            if ($VersionNumber -match "\d+\.\d+\.\d+\.\d+") {
                $PriorFullVersionNumber = $VersionNumber
            } else {
                $PriorFullVersionNumber = "0.0.0.0"
            }

            Set-Content -Path $PriorVersionFile -Value $PriorFullVersionNumber
        }
   
        [xml]$WixXml = Get-Content -path $WixSetupFile
    
        $PriorSubVersionNumbers = $PriorFullVersionNumber | Select-String -Pattern $SubVersionRegex -AllMatches
        $CustomSubVersionNumbers = $VersionNumber | Select-String -Pattern $SubVersionRegex -AllMatches
    
        $i = 0
        $NewVersionNumber = ($CustomSubVersionNumbers.Matches | ForEach-Object{
            if ($_.value -eq "*") {
                $PriorSubVersionNumbers.Matches[$i].value.ToString()

            } elseif ($_.value -eq "+"){
                ($PriorSubVersionNumbers.Matches[$i].ToString()).toint32($overflow) + 1

            } elseif ($_.value -eq "-"){
                if (($PriorSubVersionNumbers.Matches[$i].ToString()).toint32($overflow) -eq 0) {
                    ($PriorSubVersionNumbers.Matches[$i].ToString()).toint32($overflow)

                } else {
                    ($PriorSubVersionNumbers.Matches[$i].ToString()).toint32($overflow) - 1
                }

            } else {
                $CustomSubVersionNumbers.Matches[$i].value.ToString()
            }
            $i++
        }) -join "."

        if ($NewVersionNumber -match $VersionRegex) {
            $WixXml.Project.PropertyGroup[0].OutputName = "EPMA $NewVersionNumber"
            $WixXml.save($WixSetupFile)

            ForEach ($File in $Files) {
                (get-content -path "$File") -Replace $VersionRegex,$NewVersionNumber | Out-File -filepath $File
            }

            Set-Content -Path $PriorVersionFile -Value $NewVersionNumber
            Write-Output "New Version Number: "$NewVersionNumber

        } else {
            Write-Error "Version number outside of bounds"
        }
    }
}

Export-ModuleMember -Function Update-VersionNumber