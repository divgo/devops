# devops

# Sync_Remote_Directories.ps1
Sync a local directory to a remote server.
Script determines which local files are different from the remote server and only copies those files across the wire. 

Maintains a local copy ($DestFolder) of the Remote Server's Target Directory ($DestDirectory). Runs a ROBOCOPY DIFF of the new files on the local file system ($SourceFolder) with the local copy of the remote server ($DestFolder). This generates a "report" which is then parsed to determine what File System changes would be needed on the Remote Server. 

Normally, when you run a ROBOCOPY between a local FS and a remote FS, the process is very slow because each and every file needs to be checked across the wire. This script speeds that process up by maintaining a local cache of the remote server allowing this DIFF operation to occur much faster. 

- Note: /xd and /xf switches are present with hardcoded values.


