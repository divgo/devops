# Get Connected to the ServiceFabric node running on the local machine
Connect-ServiceFabricCluster

# Get a list of all versions given the current cluster version
Get-ServiceFabricRegisteredClusterCodeVersion

# Run an upgrade using the newest cluster version available
Start-ServiceFabricClusterUpgrade -Code -CodePackageVersion 5.6.220.9494 -Monitored -FailureAction Rollback

# Monitor the progress of the upgrade
Get-ServiceFabricClusterUpgrade
#  - Keep in mind that once the upgrade hits this server, you will be disconnected from SF.
# To continue to monitor, you will need to connect to the cluster from a server in a different upgrade domain, preferrably a previously upgraded server

# An upgrade can fail for a number of reasons, including lack of disk space.
# If an upgrade fails and you skipped versions, try to upgrade to the next version before going to the newest version.