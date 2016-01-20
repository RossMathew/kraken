<#
  title           :kraken-down.ps1
  description     :use docker-machine to dbring down a kraken cluster manager instance.
  author          :Samsung SDSRA
#>

Param(
  [string]$clustertype = "aws", 
  [Parameter(Mandatory=$true)] 
  [string]$dmname = "",
  [Parameter(Mandatory=$true)] 
  [string]$clustername = ""
)

# kraken root folder
$krakenRoot = "$(split-path -parent $MyInvocation.MyCommand.Definition)\.."
. "$krakenRoot\bin\utils.ps1"

If ($clustertype -eq "local") {
  error "local -clustertype is not supported"
  exit 1
}

# look for the docker machine specified 
Invoke-Expression "docker-machine ls -q | out-string -stream | findstr -s '$dmname'"

If ($LASTEXITCODE -eq 0) {
  inf "Machine $dmname already exists."
} Else {
  error "Docker Machine $dmname does not exist."
  exit 1
}

Invoke-Expression "docker-machine.exe env --shell=powershell $dmname | Invoke-Expression"

# shut down cluster
$kraken_container_name = "kraken_cluster_$clustername"
Invoke-Expression "docker inspect $kraken_container_name"
If ($LASTEXITCODE -eq 0) {
  inf "Removing old kraken_cluster container:`n   'docker rm -f $kraken_container_name'"
  Invoke-Expression "docker rm -f $kraken_container_name"
}

$success = Invoke-Expression "docker inspect kraken_data"
If ($LASTEXITCODE -ne 0) {
   warn "No terraform state available. Cluster is either not running, or kraken_data container has been removed."
   exit 0
}

$command = 	"docker run -d --name $kraken_container_name --volumes-from kraken_data " +  
			"samsung_ag/kraken bash -c `"/opt/kraken/terraform-down.sh --clustertype $clustertype --clustername $clustername`""

inf "Tearing down kraken cluster:`n  '$command'"
Invoke-Expression $command

inf "Following docker logs now. Ctrl-C to cancel."
Invoke-Expression "docker logs --follow $kraken_container_name"