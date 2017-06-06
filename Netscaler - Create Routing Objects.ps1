function CallNetscaler($Query, $Method = "Get", $Body = $null) {

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $user = "[A Valid NetScaler Username]"
    $pass = "[The Password For the NetScaler User]";
    $headers.Add("X-NITRO-USER", $user)
    $headers.Add("X-NITRO-PASS", $pass)
    $response = $null;

    $URL = "http://[IP Address of your NetScaler]/nitro/v1/config"
    If (-not [String]::IsNullOrEmpty($Query)) {
        $URL = $URL+"/"+$Query;
    }
    Write-Host "Posting to URL: " + $URL;

    $ResponseObject = ""; # dynamically determine what kind of object will be returned from the API call
    if ( $Query.Contains("/") ) {
        $ResponseObject = $Query.Substring(0, $Query.IndexOf("/"));
    } elseif ( $Query.Contains("?") ) {
        $ResponseObject = $Query.Substring(0, $Query.IndexOf("?"));
    };

    if ( $Method -eq "Get") {
        $response = try { Invoke-RestMethod -Uri $URL -ContentType "application/json" -Method $Method -Headers $headers } catch { $_.Exception.Response }
    } else {

        Write-Host "preparing to [$Method] data":
        $Pay = ToJSON($Body);
        Write-Host $Pay; #Body
        $response = Invoke-RestMethod -Uri $URL -ContentType "application/json" -Method $Method -Body $Pay -Headers $headers
    }
    
    #Write-Host 'XXXXXX';
    #Write-Host $response;
    #Write-Host $response.$ResponseObject.length;
    #Write-Host 'XXXXXX';
    if ( $response.StatusCode -eq "NotFound" ) {
        Write-Host "Object [$Query] Not Found";
        return $null
    } else {
        return $response.$ResponseObject;
    }
}
function ToJSON($InputObject) {
    return $InputObject | ConvertTo-JSON
}
function CreateRoutingObject($ObjectName, $MemberName = $null, $Port = 80) {
    $IsPath = $False; #Needed to determine what kind of monitor to attach
    If ($ObjectName.LastIndexOf("/") -gt -1) {
        $ArrObjectName = $ObjectName.Split("/"); #RoutingObject is path based, like a microservice
        $IsPath = $True;
    } else {
        $ArrObjectName = $ObjectName.Split("."); #RoutingObject is a domain name
    }

    If ($IsPath -eq $True) {
        $RouteName = $ArrObjectName[1]+"-"+$ArrObjectName[2]+"-"+$ArrObjectName[3];
    } else {
        If ( $ArrObjectName.count -eq 4) {
            if ($ArrObjectName[1] -eq "dev" -Or $ArrObjectName[1] -eq "qa" -Or $ArrObjectName[1] -eq "int") {
                $RouteName = $ArrObjectName[0]+"-"+$ArrObjectName[1]+"-"+$ArrObjectName[2];
            } else {
                $RouteName = $ArrObjectName[0]+"-"+$ArrObjectName[2];
            }
        } elseif ( $ArrObjectName.count -eq 3) {
            $RouteName = $ArrObjectName[0]+"-"+$ArrObjectName[1];
        }
    }
   
    # CREATE OUR LB vServer
    IF ( $(Callnetscaler "lbvserver/$RouteName") -eq $null ) {
        $Service = @{ lbvserver=@{ name=$RouteName; servicetype="HTTP"; lbmethod="ROUNDROBIN"; }};
        Callnetscaler "lbvserver" "POST" $Service 
    }

    #CREATE OUR SERVICE GROUP
    IF ( $(Callnetscaler "servicegroup/$RouteName") -eq $null ) {
        $Member = @{servicegroup=@{servicegroupname=$RouteName;servicetype="HTTP";}}
        CallNetscaler "servicegroup" "POST" $Member

        # BIND THE SERVICE GROUP TO THE vSERVER
        $Service = @{ lbvserver_servicegroup_binding=@{ name=$RouteName; servicegroupname=$RouteName; }};
        Callnetscaler "lbvserver_servicegroup_binding" "POST" $Service
    }

    #CREATE OUR MONITOR
    IF ( $IsPath -eq $False ) {
        IF ( $(Callnetscaler "lbmonitor/mon-$RouteName") -eq $null ) {
            $Monitor = @{lbmonitor=@{monitorname="mon-$RouteName";type="HTTP";interval=10;customheaders="host:$ObjectName`r`n"}}
            CallNetscaler "lbmonitor" "POST" $Monitor

            # BIND THE SERVICE GROUP TO THE vSERVER
            $MonitorBinding = @{ lbmonitor_servicegroup_binding=@{ monitorname="mon-$RouteName"; servicegroupname=$RouteName; }};
            Callnetscaler "lbmonitor_servicegroup_binding" "PUT" $MonitorBinding
        }
    } else {
        #TODO - Create a Path based monitor
    }


    if ( $MemberName -ne $null ) {
        Write-Host "Adding ServiceGroup Member" + $MemberName;
        $Members = @{params=@{warning="NO";onerror="CONTINUE";};servicegroup_servicegroupmember_binding=@()};

        if ($MemberName.ToString().IndexOf(",") -ge 0) {
            $MemberName.Split(",").ForEach({
                $Members.servicegroup_servicegroupmember_binding += @{servicegroupname=$RouteName; servername=$_.ToString().Trim(); port=$Port;};
            });
        } else {
            $Members.servicegroup_servicegroupmember_binding += @{servicegroupname=$RouteName; servername=$MemberName; port=$Port;};
        }
        CallNetscaler "servicegroup_servicegroupmember_binding" "PUT" $Members
    }
}

# Create a Path Based Routing Object
# CreateRoutingObject "/micro/client_info/get_info" "ORDDEVWEB01"

# Create a Path Based Routing Object with Port Translation
# CreateRoutingObject "/micro/client_info/get_info" "ORDDEVWEB01" 8080

# Create a Domain Name Based Routing Object
# CreateRoutingObject "testing.yourdomain.com" "ORDDEVWEB01"

# Create a Domain Name Based Routing Object with Port Translation
# CreateRoutingObject "testing.yourdomain.com" "ORDDEVWEB01" 8080