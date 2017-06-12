# devops

# ConfigureRoutingObjects.ps1
Create "routable" objects in a Citrix NetScaler Load Balancer. Requires a NetScaler configured to support Expression Based Routing. See https://medium.com/modern-stack/microservice-routing-using-the-netscaler-6fdb1bda2459 for more info.  

# SetupLocal.ps1
Configure IIS on a local machine to allow accessing sites by domain name ([BranchName].localhost.com) rather than localhost. Allows IIS on Windows 7 to host multiple sites and eases developer configuration.

# Sync_Remote_Directories.ps1
Sync a local directory to a remote server.
Script determines which local files are different from the remote server and only copies those files across the wire. 

Maintains a local copy ($DestFolder) of the Remote Server's Target Directory ($DestDirectory). Runs a ROBOCOPY DIFF of the new files on the local file system ($SourceFolder) with the local copy of the remote server ($DestFolder). This generates a "report" which is then parsed to determine what File System changes would be needed on the Remote Server. 

Normally, when you run a ROBOCOPY between a local FS and a remote FS, the process is very slow because each and every file needs to be checked across the wire. This script speeds that process up by maintaining a local cache of the remote server allowing this DIFF operation to occur much faster. 

- Note: /xd and /xf switches are present with hardcoded values.


