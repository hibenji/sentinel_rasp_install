#!/bin/bash

# function to print the banner
function print_banner() {
  sleep 0.1
  clear
  printf "\n"
  printf "\e[34m"
  printf "
  ███████╗███████╗███╗   ██╗████████╗██╗███╗   ██╗███████╗██╗     
  ██╔════╝██╔════╝████╗  ██║╚══██╔══╝██║████╗  ██║██╔════╝██║     
  ███████╗█████╗  ██╔██╗ ██║   ██║   ██║██╔██╗ ██║█████╗  ██║     
  ╚════██║██╔══╝  ██║╚██╗██║   ██║   ██║██║╚██╗██║██╔══╝  ██║     
  ███████║███████╗██║ ╚████║   ██║   ██║██║ ╚████║███████╗███████╗
  ╚══════╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝ v0.3.1\n"

  printf "\e[0m"
  printf "\n"
}

print_banner

printf "Welcome to the automated Sentinel DVPN node setup script.

This script will:
- Install Docker and other required dependencies if not already installed
- Generate a TLS certificate
- Create the Sentinel DVPN node configuration
- Start the Sentinel DVPN node\n\n"


# do you want to continue?
read -p $'Do you want to proceed with the setup? (y/n) ' -r REPLY
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi

print_banner

printf "Checking dependencies...\n"

# check if docker, curl and openssl are installed
if ! [ -x "$(command -v docker)" ] || ! [ -x "$(command -v curl)" ] || ! [ -x "$(command -v openssl)" ]; then
  printf "Installing dependencies...\n"
  # install dependencies
  sudo apt-get update && \
  sudo apt-get install -y docker.io curl openssl
  printf "Dependencies have been installed.\n"
else
    printf "Dependencies are installed.\n"
fi


sleep 0.5
print_banner


printf "Please enter a moniker for your node.\n\nThis is a name that will be displayed on the Sentinel DVPN network and will also help you identify your node.\nIt needs to be between 4 and 32 characters long.\n\n"

read -p $'Enter a moniker for your node: ' -e NODENAME

# check if the moniker length is valid
if [[ ${#NODENAME} -lt 4 || ${#NODENAME} -gt 32 ]]; then
  printf "Invalid moniker length. Exiting..."
  exit 1
fi

print_banner

# check the country using ip-api.com
IPADDR=$(curl -s https://ip.me -4)

printf "Your public IP address was detected as $IPADDR.\n"
printf "Please enter your public IP address if it is different from the one detected.\n\n"

# read in public ip from user but default to the one from ip.me
read -p $'Enter your public IP address: ' -i $IPADDR -e IPADDR
# check if the IP address is valid
if [[ ! $IPADDR =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf -e "\e[31mInvalid IP address. Exiting..."
    exit 1
fi

print_banner

# ask whether to use V2Ray or WireGuard, with a selector

printf "Would you like to use V2Ray or WireGuard? (V2Ray is currently recommended)\n\n"
PS3=$'\nPlease enter your choice:'
options=("V2Ray" "WireGuard")
select opt in "${options[@]}"
do
  case $opt in
    "V2Ray")
      # printf "Selected V2Ray"
      vpn_type="v2ray"
      break
      ;;
    "WireGuard")
      # printf "Selected WireGuard"
      vpn_type="wireguard"
      break
      ;;
    *) printf "Invalid option. Please select again.";;
  esac
done

print_banner

PORT="7777"
V2RAYPORT="9999"
WIREGUARDPORT="8888"


printf "The node port will be used for your node's API.\n\n"

# check for user input on the default ports
read -p $'Enter the port for the node (default 7777): ' -i $PORT -e PORT

print_banner

# print the vpn type
printf "Selected VPN type: $vpn_type\n\n"

if [[ $vpn_type == "v2ray" ]]; then
  printf "The V2Ray port will be used for your node's V2Ray connection.\nThis will also have to be port forwarded past your router.\n\n"
  read -p $'Enter the V2Ray port for the node (default 9999): ' -i $V2RAYPORT -e V2RAYPORT
  VPNPORT=$V2RAYPORT
else
  printf "The WireGuard port will be used for your node's WireGuard connection.\nThis will also have to be port forwarded past your router.\n\n"
  read -p $'Enter the WireGuard port for the node (default 8888): ' -i $WIREGUARDPORT -e WIREGUARDPORT
  VPNPORT=$WIREGUARDPORT
fi


print_banner

# ask if ufw should be enabled
printf "Would you like to enable UFW (Uncomplicated Firewall) on the node and allow the ports?\n\n"

# list the rules that will be added
printf "The following rules will be added:\n"
printf "Allow incoming TCP on port $PORT\n"
printf "Allow incoming TCP on port $VPNPORT\n"
printf "Allow incoming TCP on port 22(ssh)\n\n"

read -p $'Do you want to enable UFW? (y/n) ' -r REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then

# check if ufw is installed
if ! [ -x "$(command -v ufw)" ]; then
  printf "Installing UFW...\n"
  sudo apt-get update && \
  sudo apt-get install -y ufw
  printf "UFW has been installed.\n"
else
  printf "UFW is already installed.\n"
fi
  sudo ufw allow $PORT/tcp
  sudo ufw allow $VPNPORT/tcp
  sudo ufw allow 22/tcp
  sudo ufw enable
  printf "UFW has been enabled and the ports have been allowed.\n\n"
fi

print_banner

# is this a residential or datacenter node?
PS3=$'\nIs this a residential or datacenter node?'
printf "If you are running on a raspberry pi or a home network, you are more than likely residential.\n"
printf "But you can check this by looking at the connection type on https://ipregistry.co/ (ISP means residential).\n\n"
options=("Residential" "Datacenter")
select opt in "${options[@]}"
do
  case $opt in
    "Residential")
      # printf "Selected Residential"
      type="Residential"
      pricing="10000000"
      break
      ;;
    "Datacenter")
      # printf "Selected Datacenter"
      type="Datacenter"
      pricing="4160000"
      break
      ;;
    *) printf "Invalid option. Please select again.";;
  esac
done


print_banner


# where do you want the files to be stored?
printf "Where would you like the configuration files to be stored?\n\n"
read -p $'Enter the folder path (default ~/.sentinel): ' -i "${HOME}/.sentinel" -e FOLDER

print_banner



# do you want to import a seed phrase?
printf "Would you like to import a seed phrase for the node?\n\n"
printf "If you dont know what this means, you should probably say no\n\n"
read -p $'Do you want to import a seed phrase? (y/n) ' -r REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
  printf "Please enter the seed phrase for the node.\n\n"
  read -p $'Enter the seed phrase: ' -e seed_phrase
fi

print_banner

# show all selected options
printf "Selected options:\n\n"
printf "Node Name: $NODENAME\n"
printf "Public IP: $IPADDR\n"
printf "VPN Type: $vpn_type\n"
printf "Type: $type\n"
printf "Pricing: $pricing\n"
printf "Port: $PORT\n"
if [[ $vpn_type == "v2ray" ]]; then
  printf "V2Ray Port: $V2RAYPORT\n"
else
  printf "WireGuard Port: $WIREGUARDPORT\n"
fi
printf "Sentinel files $FOLDER.\n\n"

# please double check the options
printf "Please double check the options above carefully.\n\n"

# port forwarding
printf "If you're hosting your node from home, make sure to enable port forwarding on your router to allow external access. To do this, access your router settings and navigate to WAN services, then add the following two IPv4 Port forwarding table entries:\n\n"

# https://docs.sentinel.co/node-setup/methods/manual/node-config#enable-port-forwarding-for-residential-nodes
# https://www.noip.com/support/knowledgebase/general-port-forwarding-guide

printf "You can use the following information to set up port forwarding on your router:\n"
printf "https://docs.sentinel.co/node-setup/methods/manual/node-config#enable-port-forwarding-for-residential-nodes\n"
printf "https://www.noip.com/support/knowledgebase/general-port-forwarding-guide\n\n"

local_ip=$(hostname -I | awk '{print $1}')

printf "Following are the ports that need to be forwarded, automatically gathered from the setup (double check if it is correct):\n\n"
printf "Name: TCP_PORT\t\tProtocol: TCP\tWAN Port: $PORT\tLAN Port: $PORT\tDestination IP: $local_ip\n"

if [[ $vpn_type == "v2ray" ]]; then
  printf "Name: V2RAY_PORT\tProtocol: TCP\tWAN Port: $V2RAYPORT\tLAN Port: $V2RAYPORT\tDestination IP: $local_ip\n\n"
else
  printf "Name: WIREGUARD_PORT\tProtocol: UDP\tWAN Port: $VPNPORT\tLAN Port: $VPNPORT\tDestination IP: $local_ip\n\n"
fi

# do you want to continue?
read -p $'Do you want to proceed with the setup? (y/n) ' -r REPLY
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi


# check if arm
if [[ $(uname -m) == "aarch64" || $(uname -m) == "arm64" ]]; then

  # getconf LONG_BIT
  if [[ $(getconf LONG_BIT) == "32" ]]; then
    sudo docker pull wajatmaka/sentinel-arm7-debian:v0.7.1
    sudo docker tag wajatmaka/sentinel-arm7-debian:v0.7.1 sentinel-dvpn-node
  else

  sudo docker pull wajatmaka/sentinel-aarch64-alpine:v0.7.1
  sudo docker tag wajatmaka/sentinel-aarch64-alpine:v0.7.1 sentinel-dvpn-node
  fi

elif [[ $(uname -m) == "armv7l" ]]; then
  sudo docker pull wajatmaka/sentinel-arm7-debian:v0.7.1
  sudo docker tag wajatmaka/sentinel-arm7-debian:v0.7.1 sentinel-dvpn-node
else
  sudo docker pull ghcr.io/sentinel-official/dvpn-node:latest
  sudo docker tag ghcr.io/sentinel-official/dvpn-node:latest sentinel-dvpn-node
fi
sudo openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -subj "/C=NA/ST=NA/L=./O=NA/OU=./CN=." -x509 -sha256 -days 365 -nodes -out "${HOME}/tls.crt" -keyout "${HOME}/tls.key"
mkdir $FOLDER
printf "Generating configuration files...\n"
sudo docker run --rm --volume "${FOLDER}:/root/.sentinelnode" sentinel-dvpn-node process config init
printf "Generating V2Ray and WireGuard configuration files...\n"
sudo docker run --rm --volume "${FOLDER}:/root/.sentinelnode" sentinel-dvpn-node process v2ray config init
sudo docker run --rm --volume "${FOLDER}:/root/.sentinelnode" sentinel-dvpn-node process wireguard config init
sudo chown -R $USER:$USER $FOLDER
chmod 755 $FOLDER -R


cat <<EOT > $FOLDER/config.toml
[chain]
gas = 200000
gas_adjustment = 1.05
gas_prices = "0.1udvpn"
id = "sentinelhub-2"
rpc_addresses="https://rpc-sentinel.whispernode.com:443,https://rpc.sentinel.quokkastake.io:443,https://rpc.mathnodes.com:443,https://sentinel-rpc.polkachu.com:443,https://rpc.sentinel.co:443"
rpc_query_timeout = 20
rpc_tx_timeout = 60
simulate_and_execute = true

[handshake]
enable = false
peers = 8

[keyring]
backend = "test"
from = "operator"

[node]
interval_set_sessions = "10s"
interval_update_sessions = "1h55m0s"
interval_update_status = "55m0s"
ipv4_address = "${IPADDR}"
listen_on = "0.0.0.0:$PORT"
moniker = "${NODENAME}"
gigabyte_prices = "52573ibc/31FEE1A2A9F9C01113F90BD0BBCCE8FD6BBB8585FAF109A2101827DD1D5B95B8,9204ibc/A8C2D23A1E6F95DA4E48BA349667E322BD7A6C996D8A4AAE8BA72E190F3D1477,1180852ibc/B1C0DDB14F25279A2026BC8794E12B259F8BDA546A3C5132CCAEE4431CE36783,122740ibc/ED07A3391A112B175915CD8FAF43A2DA8E4790EDE12566649D0C2F97716B8518,15342624udvpn"
hourly_prices = "18480ibc/31FEE1A2A9F9C01113F90BD0BBCCE8FD6BBB8585FAF109A2101827DD1D5B95B8,770ibc/A8C2D23A1E6F95DA4E48BA349667E322BD7A6C996D8A4AAE8BA72E190F3D1477,1871892ibc/B1C0DDB14F25279A2026BC8794E12B259F8BDA546A3C5132CCAEE4431CE36783,18897ibc/ED07A3391A112B175915CD8FAF43A2DA8E4790EDE12566649D0C2F97716B8518,${pricing}udvpn"
provider = ""
remote_url = "https://$IPADDR:$PORT"
type = "$vpn_type"

[qos]
max_peers = 250
EOT

sudo sed -i "5c\listen_port = $WIREGUARDPORT" $FOLDER/wireguard.toml
# set the 3rd line to the listen_port from the variable
sudo sed -i "3c\listen_port = $V2RAYPORT" $FOLDER/v2ray.toml

# give ownership of the wireguard and v2ray files to root
sudo chown root:root $FOLDER/wireguard.toml
sudo chown root:root $FOLDER/v2ray.toml

printf "Generating keys...\n"
# check if the seed phrase is set
if [[ -n $seed_phrase ]]; then
  echo "***Important*** write this mnemonic phrase in a safe place" > ${FOLDER}/node_info.txt
  echo $seed_phrase >> ${FOLDER}/node_info.txt
  echo "" >> ${FOLDER}/node_info.txt
  sudo docker run --rm --interactive --volume $FOLDER:/root/.sentinelnode  sentinel-dvpn-node process keys add --recover <<< $seed_phrase >> ${FOLDER}/node_info.txt

else
  sudo docker run --rm --interactive --tty --volume "${FOLDER}:/root/.sentinelnode" sentinel-dvpn-node process keys add > ${FOLDER}/node_info.txt
fi

############################################################################

sudo mv "${HOME}/tls.crt" "${FOLDER}/tls.crt" && \
sudo mv "${HOME}/tls.key" "${FOLDER}/tls.key"

sudo chown root:root "${FOLDER}/tls.crt" && \
sudo chown root:root "${FOLDER}/tls.key"

sudo cat <<EOT > $FOLDER/sentineldvpn
#!/bin/bash
#################################################
#
#               sentineldvpn
#
#################################################

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

sudo docker rm -f sentinel
sudo rm data.db
sudo docker run -d --restart always \\
    --volume "${FOLDER}:/root/.sentinelnode" \\
    --name sentinel \\
    -p ${PORT}:${PORT}/tcp \\
    -p ${VPNPORT}:${VPNPORT}/tcp \\
    sentinel-dvpn-node:latest process start

exit 0
EOT

sudo chmod 755 $FOLDER/sentineldvpn

print_banner

# extract the nodeoperator and nodeaddress from the keys
nodeoperator=$(cat $FOLDER/node_info.txt | grep operator | awk '{print $3}')
nodeaddress=$(cat $FOLDER/node_info.txt | grep operator | awk '{print $2}')
# for the mnemonic, we just need the second line
mnemonic=$(cat $FOLDER/node_info.txt | sed -n '2p')

# remove the last character from the nodeoperator
nodeoperator=${nodeoperator%?}

printf "The node has been successfully set up.\n\n"
printf "Please save the following information and send some DVPN (5-20 dvpn) to the node operator wallet.\n\n"

printf "The Node Operator is: \n$nodeoperator\n"
printf "The Node Address is: \n$nodeaddress\n"
printf "The Mnemonic is: \n$mnemonic\n\n"

printf "Please confirm that you have sent DVPN to the Node Operator wallet.\n\n"

read -p $'Have you sent some DVPN to the Node Operator wallet and would you like to start the node? (y/n) ' -r REPLY
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi

# run the script
$FOLDER/sentineldvpn > /dev/null 2>&1 &

printf "The node has been started.\n\n"

# check the logs by "sudo docker logs sentinel -f"
printf "You can check the logs by running 'sudo docker logs sentinel -f'.\n\n"
