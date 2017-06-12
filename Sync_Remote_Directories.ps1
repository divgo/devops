param (
    [string]$SourceFolder = $null, # Where are the new files on the local filesystem?
    [string]$DestFolder = $null, # Where is the local snapshot of the remote directory?
    [string]$DestDirectory = $null # UNC Path to the Destination
)

if ( [System.String]::IsNullOrEmpty($SourceFolder) -or [System.String]::IsNullOrEmpty($DestFolder) -or [System.String]::IsNullOrEmpty($DestDirectory) ) {
    Write-Host "Required Parameters are Missing. Exiting";
    break;
}

Set-Location $SourceFolder
Get-Location

$DIFF = ROBOCOPY . $DestFolder /e /l /ns /njs /njh /ndl /fp /TEE /xd images textfiles /xf *.config *.asa *.asax *.au
# bundle-*.* 
$Lines = $DIFF.Split([Environment]::NewLine);
Write-Host "DIFF Found ["$Lines.Count"] Total Discrepencies";

# $DIFF
$Lines | ForEach {
    if ( [System.String]::IsNullOrEmpty($_) -eq $false ) { #Is the line empty, the DIFF command adds a blank line on top and bottom
        $Line = $_.split("`t"); # Split the line on a TAB. Double TAB would be better
        $Action = $Line[1].ToString().Trim().ToUpper(); # The First trimmed segment contains the DIFF type
        $File = $Line[4].ToString().Trim(); # this segment contains the file that is different

        #####   STRING CLEANING - Need to ensure that each side of the XCOPY command is formatted correctly
        $SourceFile = $File.Replace($SourceFolder, ""); #XCOPY needs a file path relative
        $DestFile = $DestFolder+$SourceFile
        # $SourceFile = $SourceFile.SubString(1, $SourceFile.Length-1);
        
        if ( $Action -eq "NEW FILE" -or $Action -eq "NEWER" ) {
            Write-Host "ACTION: "$Action"`t`tFILE: "$File;
            Write-Host "DestFile: "+$DestFile;

            $XC = "echo f | xcopy ""$File"" ""$DestFolder$SourceFile"" /Y" # - Build up the XCOPY command, found these switches result in false positives /S /E
            Write-Host $XC;
            cmd /c $XC

            # Copy the ChangedFile to the Ultimate Destination
            $XC = "echo f | xcopy ""$File"" ""$DestDirectory$SourceFile"" /Y" # - Build up the XCOPY command, found these switches result in false positives /S /E
            Write-Host $XC;
            cmd /c $XC
        }
        if ( $Action -eq "*EXTRA FILE" ) {
            Write-Host "FILE: "$File" Should be deleted from Remote";
        }
    }
}