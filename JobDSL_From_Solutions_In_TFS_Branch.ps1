param(
    [String]$WorkspacePath=$null,
    [String]$RootFolder=$null
);

# MSBuild Reference allows us to interprete .SLN and *.PROJ files as Objects
Add-Type -Path (${env:ProgramFiles(x86)} + '\Reference Assemblies\Microsoft\MSBuild\v14.0\Microsoft.Build.dll')
# Add-Type -Path "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\Microsoft.TeamFoundation.VersionControl.Client.dll";
# Add-Type -AssemblyName 'Microsoft.Build, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a'

# The following is a means of getting the Branch name from the current workspace. It is very particular though and is somewhat unreliable
#$ws = [Microsoft.TeamFoundation.VersionControl.Client.Workstation]::Current.GetLocalWorkspaceInfo("C:\Credible\branches\development\Source\WebApi\SureScriptsDirect\ResponseManager\ResponseManager.csproj");
#$WSI = $ws.GetWorkspace([Microsoft.TeamFoundation.Client.TfsTeamProjectCollection]$ws.ServerUri);
#$WSI.Folders[0].ServerItem
#$BranchName = $ws.Name;
#Write-Host $BranchName;
Write-Host "Workspace Path: "$WorkspacePath;

$CurrentWorkingFolder = $WorkspacePath+"\Source";
if (-not [String]::IsNullOrEmpty($CurrentWorkingFolder) ) {
    CD $CurrentWorkingFolder;
}

# Create Our master XML Document which contains the Branch Build Info
[System.Xml.XmlDocument] $BranchStructure =New-Object System.XML.XMLDocument
$RootNode = $BranchStructure.CreateElement("BranchStructure");
$RootNode.SetAttribute("BranchName", $RootFolder);
$BranchStructure.AppendChild($RootNode) | out-null; ### | out-null -- these look weird, but they are used to clean up output. without them, node info is printed to the console


# List of Project Folders in TFS to ignore
$ExcludeFolders = Get-Content "$WorkspacePath\ExcludedProjectsList.txt";
$ExcludeFolders;
Write-Host "Workspace Path: $WorkspacePath";
Write-Host "Current Working Folder: $CurrentWorkingFolder";
Write-Host "Working TFS Branch Name: $RootFolder";

dir . -Exclude $ExcludeFolders;
# return;

Function GetSolutionInfo($Solution) {
        $Output = [String]::Format("Directory:{0}`t`t`tSolution Name:{1}", $Solution.Directory, $Solution.Name);
        Write-Host $Output -ForegroundColor DarkMagenta;
        Return @{
            Path=$Solution.Directory;
            SolutionName=$Solution.Name;
            DisplayName=$Solution.Name.Replace(".sln", "");
        };
}

Get-ChildItem -Exclude $ExcludeFolders -Directory | ForEach {
    Write-Host "Physical Folder: $_.Name";

    $Folder = $BranchStructure.CreateElement("BranchFolder");
    $Folder.SetAttribute("FolderName", $_.Name.ToString());

    $ExcludeSolutions = ("*BIUserSync*");
    dir $_.FullName -Include ("*.sln") -Exclude $ExcludeSolutions -Recurse | ForEach-Object {

            $SLN = GetSolutionInfo($_);

            $SolutionInfo = $BranchStructure.CreateElement("Solution");
            $SolutionInfo.SetAttribute("Name", $SLN.SolutionName);
            $SolutionInfo.SetAttribute("DisplayName", $SLN.DisplayName);
            $SolutionInfo.SetAttribute("PhysicalPath", $_.FullName);
            $SlnRelative = $_.FullName -Replace [regex]::escape($CurrentWorkingFolder.ToString().SubString(0, $CurrentWorkingFolder.ToString().LastIndexOf("\"))), ""; # Need to derive the relative physical path to the project
            $SlnRelative = "/"+$RootFolder.ToString()+$SlnRelative.ToString().Replace("\", "/");
            $SolutionInfo.SetAttribute("RelativePath", $SlnRelative);

            $Folder.AppendChild($SolutionInfo) | out-null;
    }

    $BranchStructure.DocumentElement.AppendChild($Folder) | out-null;
}

CD "../"
If ( (Test-Path -Path "$WorkspacePath\BranchStructure.xml") ) { #Bad Paths, References and missing commits can blow things up. Check for Project File before opening it
    Remove-Item "$WorkspacePath\BranchStructure.xml";
}

$BranchStructure.Save("$WorkspacePath\BranchStructure.xml");

If ( (Test-Path -Path "$WorkspacePath\JobDSL.groovy") ) { #Bad Paths, References and missing commits can blow things up. Check for Project File before opening it
    Remove-Item "$WorkspacePath\JobDSL.groovy";
}

Function WriteDSL($StrOut) {
    $StrOut | Out-File "$WorkspacePath\JobDSL.groovy" -Append -Encoding ASCII;
}

# This part is ugly. Given the data we collected about all the solutions in the Branch, lets create the needed DLS scripts to generate the jobs in Jenkins
Function ProjectNodeToDSL($ProjectNode, $ParentFolder) {

    $Job = New-Object -TypeName "System.Text.StringBuilder";
    $TFSCollectionURL = "http://X.X.X.X:8080/tfs/DefaultCollection";

    $ProjectPath = $ProjectNode.Attributes.GetNamedItem("RelativePath").value;
    $SCMPath = $ProjectPath.SubString(0, $ProjectPath.LastIndexOf("/"));
    $SolutionFile = $ProjectNode.Attributes.GetNamedItem("Name").value;

    #[void]$Job.AppendFormat("folder('{0}', ", $ParentFolder);
    # $("-" * 100)
    [void]$Job.AppendFormat("job('{0}') {{`n", $ParentFolder);
    [void]$Job.AppendFormat($("`t" * 1)+"description '{0}'`n", "Build Solution:" + $ProjectNode.Attributes.GetNamedItem("DisplayName").value);
    [void]$Job.AppendFormat($("`t"*1)+"customWorkspace('E:\\Branches{0}')`n", $SCMpath.Replace("/", "\\"))
    # Remove the existing SCM node since we need to build ours up
    [void]$Job.AppendLine($("`t" * 1)+"configure { project -> project.remove(project / scm) }");

    [void]$Job.AppendLine($("`t" * 1)+"configure { project ->");
    [void]$Job.AppendLine($("`t" * 2)+"project / scm (class: 'hudson.plugins.tfs.TeamFoundationServerScm', plugin: 'tfs@5.2.1') {");
    [void]$Job.AppendFormat($("`t" * 3)+"serverUrl('{0}')", $TFSCollectionURL);
    [void]$Job.AppendFormat($("`t" * 3)+"projectPath('$/CredibleCore{0}')`n", $SCMPath);
    [void]$Job.AppendLine($("`t" * 3)+"cloakedPaths(class:'list')");
    [void]$Job.AppendLine($("`t" * 3)+"localPath('.')");
    [void]$Job.AppendLine($("`t" * 3)+"workspaceName('Hudson-`${JOB_NAME}-`${NODE_NAME}-DEV')");
    [void]$Job.AppendLine($("`t" * 3)+"credentialsConfigurer (class:'hudson.plugins.tfs.model.AutomaticCredentialsConfigurer')");
    [void]$Job.AppendLine($("`t" * 3)+"useUpdate('true')");
    [void]$Job.AppendLine($("`t" * 2)+"}");
    [void]$Job.AppendLine($("`t" * 1)+"}");

    # Steps
    [void]$Job.AppendLine($("`t" * 1)+"steps {");

    [void]$Job.AppendFormat($("`t" * 2)+"batchFile('E:\\AutomatedBuildFiles\\Nuget\\nuget.exe restore {0}')`n", $SolutionFile);

    [void]$Job.AppendLine($("`t" * 2)+"msBuild {");
    [void]$Job.AppendFormat($("`t" * 3)+"buildFile('{0}')`n", $SolutionFile);
    [void]$Job.AppendLine($("`t" * 2)+"}");

    [void]$Job.AppendLine($("`t" * 1)+"}"); # End OF Steps bracket

#            msBuildInstallation('MSBuild 1.8')
#            buildFile('dir1/build.proj')
#            args('check')
#            args('another')
#            passBuildVariables()
#            continueOnBuildFailure()
#            unstableIfWarnings()
#        }

    [void]$Job.AppendLine("}");
    $StrOut = $Job.ToString()
    Write-Host $StrOut;
    $Job = $null;
    Return $StrOut;
}

$DSLRoot = $BranchStructure.DocumentElement.GetAttribute("BranchName");
Write-Host $DSLRoot
WriteDSL("folder('$DSLRoot')");

$BranchStructure.DocumentElement.ChildNodes | ForEach {
    
    $P = $_;
    $ParentFolder = $P.Attributes.GetNamedItem("FolderName").Value;
    $DSLFolder = [String]::Format("{0}/{1}", $DSLRoot, $ParentFolder);
    Write-Host "Parent: $DSLFolder";
    # $JobDSL.AppendLine([String]::Format("folder('{0}/{1}')", $RootFolder, $ParentFolder));
    WriteDSL([String]::Format("folder('{0}')", $DSLFolder));

    $P.ChildNodes | ForEach {

        $FolderPath = $ParentFolder
        $Node = $_;
        #$ChildFolder = $Node.Attributes.GetNamedItem("Name").Value;
        $ChildFolder = [String]::Format("{0}/{1}", $DSLFolder, $Node.Attributes.GetNamedItem("DisplayName").Value);
        Write-Host "Child: $ChildFolder";
        # $ProjectFolderPath = [String]::Format("{0}/{1}", $ParentFolder, $ChildFolder);
        # WriteDSL([String]::Format("folder('{0}')", $ChildFolder));

        #$Node.SelectNodes("Solution") | ForEach {
            Write-Host "Solution: $($_.Attributes.GetNamedItem("DisplayName").value) ($Parent)" -ForegroundColor Yellow;
            $DSL = ProjectNodeToDSL $_ $ChildFolder; # ProjectFolderPath;
            WriteDSL($DSL);
        #}

    }
}

