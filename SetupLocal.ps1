Add-Type -Path "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\Microsoft.TeamFoundation.VersionControl.Client.dll";

# Install-Module PSHosts
if (Get-Module -ListAvailable -Name Carbon) {
    Write-Host "Carbon Module exists"
} else {
    Write-Host "Carbon Module does not exist"
    Install-Module -Name 'Carbon' # -AllowClobber
}

Import-Module Carbon

if ([Environment]::GetEnvironmentVariable("CredibleLocal") -eq $null) {
    Write-Host "Creating CredibleLocal Environment Variable With Default Value";
    $WebRootFolder = "C:\inetpub\wwwroot";
    [Environment]::SetEnvironmentVariable("CredibleLocal", $WebRootFolder, "User")
} else {
    $WebRootFolder = [Environment]::GetEnvironmentVariable("CredibleLocal");
}

Write-Host $WebRootFolder;

function ConfigureLocalSite($SiteName) {

    $SiteDomain = $SiteName + ".localhost.com";
    $AppPoolName = $SiteName.replace(".", "-"); # Site Modules names would have a period in it; eg: login.branchname, ext.branchname
    $SiteDirectory = $WebRootFolder + "\" + $SiteName.replace(".", "-");

    Write-Host "Creating HOSTS entry for: " $SiteDomain;
    Set-HostsEntry -IPAddress 127.0.0.1 -HostName $SiteDomain;

    Write-Host "Configuring IIS Website for Branch: " $SiteName;
    If ( -Not (Test-Path -PathType Container -Path $SiteDirectory) ) {
        Write-Host "Creating Target Website Folder: "+$SiteDirectory;
        New-Item -ItemType Directory -Force -Path $SiteDirectory;
    }
    Install-IisAppPool -Name $AppPoolName;
    $Binding = "http:/*:80:" + $SiteDomain;
    Install-IisWebsite -Name $AppPoolName -PhysicalPath $SiteDirectory -AppPoolName $AppPoolName -Binding $Binding;
}

# Figure out what the name of the branch is
$WorkingPath = $(get-location).Path;
$ws = [Microsoft.TeamFoundation.VersionControl.Client.Workstation]::Current.GetLocalWorkspaceInfoRecursively($WorkingPath);
$BranchName = $ws.Name;
if ( [String]::IsNullOrEmpty($BranchName) ) {
    Write-Host "Branch Name could not be determined. Exiting Script";
} else {
    Write-Host "Detected Branch name: " $BranchName;
    ConfigureLocalSite $BranchName.ToLower();
    $LoginSite = "login." + $BranchName.ToLower();
    ConfigureLocalSite $LoginSite;
    IISRESET;
}

Write-Host "All Local Configuration Complete. Press any key to close this window.";
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown");