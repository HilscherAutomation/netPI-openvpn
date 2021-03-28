## OpenVPN

Made for Raspberry Pi 3B architecture based devices and compatibles

### Docker repository

https://hub.docker.com/r/hilschernetpi/netpi-openvpn/

### Container features 

The image provided hereunder deploys an OpenVPN server, a web shell to configure the server and a web page to download created *.ovpn configuration files for connecting OpenVPN clients.

Base of this image builds [debian](https://hub.docker.com/_/debian) with installed [OpenVPN server](https://github.com/OpenVPN/openvpn) package and a [web proxy](https://github.com/nginx/nginx) providing access to a [web shell](https://github.com/shellinabox/shellinabox) and a [web server](https://github.com/lighttpd/lighttpd1.4) with a download page for *.ovpn files. For a guided OpenVPN configuration the [PiVPN Project](https://www.pivpn.io/) installer is preinstalled ready for immediate execution.

After configuration an OpenVPN tunnel can be established using an [OpenVPN client](https://openvpn.net/community-downloads/). The tunnel allows the access to the OpenVPN server device itself and all the devices connected to its network interfaces (e.g. eth0).

### Container hosts

The container has been successfully tested on the following hosts

* netPI, model RTE 3, product name NIOT-E-NPI3-51-EN-RE
* netPI, model CORE 3, product name NIOT-E-NPI3-EN
* netFIELD Connect, product name NIOT-E-TPI51-EN-RE/NFLD
* Raspberry Pi, model 3B
* Raspberry Pi, model 4B (arm32v7,arm64v8)

netPI devices specifically feature a restricted Docker protecting the Docker host system software's integrity by maximum. The restrictions are

* privileged mode is not automatically adding all host devices `/dev/` to a container
* volume bind mounts to rootfs is not supported
* the devices `/dev`,`/dev/mem`,`/dev/sd*`,`/dev/dm*`,`/dev/mapper`,`/dev/mmcblk*` cannot be added to a container

### Container setup

#### Network mode

The container runs in **bridge** network mode. This makes port mapping necessary.

#### Environment variable

The default port for the web proxy is `8008`. For any other port define the environment variable **WEBPORT** with the desired port number as value.

#### Port mapping

The following container ports need to be exposed to host ports

Application | Port | Protocol | Remark
:---------|:------ |:------ |:-----
*Web proxy* | **8008** | TCP | or port configured by **WEBPORT** environment variable alternatively
*OpenVPN server* | **1194** | UDP | or other port/protocol configured with PiVPN installer later

Once deployed port mapping can't be changed for a container. So make sure the mapped ports and protocols are correct prior to deployment.

#### Capabilities

To allow performing various network-related operations the capability **NET_ADMIN** needs to be set for the container.

#### Devices

To allow the registration of a network device the **/dev/net/tun** host device needs to be added to the container.

#### Privileged mode

The privileged mode lifts the standard Docker enforced container limitations: applications inside a container are getting (almost) all capabilities as if running on the host directly.

Enabling the **privileged** mode is mandatory for this container.

#### Volume mapping

To persist all the container configuration data located in the container folder **/etc/data** an outsourcing to a Docker volume (e.g. **data**) is strongly recommended.

### Container deployments

Pulling the image may take 10 minutes.

#### netPI example

STEP 1. Open netPI's web UI in your browser (https).

STEP 2. Click the Docker tile to open the [Portainer.io](http://portainer.io/) Docker management user interface.

STEP 3. Click *Volumes > + Add Volume*. Enter **data** as *Name* and click *Create the volume*. 

STEP 4. Enter the following parameters under *Containers > + Add Container*

Parameter | Value | Remark
:---------|:------ |:------
*Image* | **hilschernetpi/netpi-openvpn:latest** |
*Network > Network* | **bridge** |
*Restart policy* | **always**
*Port mapping* | *host* **8008** -> *container* **8008** **TCP** or <br> **WEBPORT** value -> *container* **WEBPORT** value **TCP/UDP** | default or alternative port/protocol
*Port mapping* | *host* **1194** -> *container* **1194** **UDP** | same port as configured with PiVPN installer at runtime
*Adv.con.set. > Env* | *name* **WEBPORT** -> *value* **any unused port** | for other port than 8008
*Adv.con.set. > Devices > +add device* | *Host path* **/dev/net/tun** -> *Container path* **/dev/net/tun** |
*Adv.con.set. > Volumes > +map additional volume* | *volume* **data** -> *container* **/etc/data** | for configuration persistence
*Capabilities > NET_ADMIN* | **Enabled** |  
*Adv.con.set. > Runt. & Res. > Privileged mode* | **On** |

STEP 5. Press the button *Actions > Start/Deploy container*

#### Docker command line example

`docker volume create data` `&&`
`docker run -d --network=bridge --privileged --device=/dev/net/tun:/dev/net/tun -v data:/etc/data -e WEBPORT=8008 -p 8008:8008/tcp -p 1194:1194/udp --cap-add=NET_ADMIN  hilschernetpi/netpi-openvpn:latest`

#### Docker compose example

    version: "2"

    services:
     openvpn:
       image: hilschernetpi/netpi-openvpn:latest
       restart: always
       privileged: true
       network_mode: bridge
       cap_add:
         - NET_ADMIN
       ports:
         - 8008:8008/tcp
         - 1194:1194/udp
       devices:
         - /dev/net/tun:/dev/net/tun
       volumes:
         - data:/etc/data
       environment:
         - WEBPORT=8008

    volumes:
      data:

### Container access

The container starts the web proxy, web shell and config files web server automatically when deployed. The OpenVPN server is started additionally if found configured.

The provided web pages can be reached with

Application | Protocol | IP address | Port | Path | Example
:---------|:--------|:------ |:------ |:----- |:-----
*Web shell* | HTTP | host's IP address | *8008* or <br>*WEBPORT* | **/shell** | `http://192.168.0.1:8008/shell`
*Config files web server* | HTTP | host's IP address | *8008* or <br>*WEBPORT* | **/config** | `http://192.168.0.1:8008/config`

### Internet Router

An Internet router interlinks between local network devices such as the OpenVPN server device and the Internet. 

Depending on your Internet provider contract the router gets either a constant Internet IP address forever which makes configuration easy or a dynamic one (usually every 24hrs). Either of the two methods influence the OpenVPN server configuration.

In latter case a DNS provider of your choice is needed first reserving you a public and constant DNS name (e.g. mypersonaladdress.dyndns.org) while providing a service that enables mappping the name to the dynamically changing IP address of your router.

#### Dynamic DNS

Enable this function in your router and enter the domain credentials received from your DNS provider. The router will then automatically report its dynamically changing Internet IP address to the provider who in turn maps it to your public DNS name and update the global Internet DNS database.

#### Port forwarding

Enable this function in your router to let it forward external Internet traffic on the specified OpenVPN server port (e.g.1194/udp) to the local IP address/port of your OpenVPN server device.

### OpenVPN server

#### Initial setup

The OpenVPN server comes unconfigured. To configure it visit the web page `.../shell` in your browser.

In the window prompt (e.g. root@42f19c945b6f:~#) enter the command `configure` and press enter to start the configuration procedure through the PiVPN installer. For detailed help visit [PiVPN help](https://docs.pi-hole.net/).

The installer will ask for several settings. Here is a typical configuration example 

Question | Answer | Remark
:---------|:------|:------
*New Username* | e.g. **openvpnuser** `<Ok>` | user needed to save the configuration
*Password* | e.g. **Fh7Klikom** `<Ok>` | any password you like
*Choose User* | **(*)openvpnuser** `<Ok>` | user created before
*Installation mode* | **OpenVPN** `<Ok>` | container designed to suppport OpenVPN not Wireguard
*Customize settings* | `<No>` | default settings like UDP, key strength etc. are suitable
*Default openvpn Port* | **1194** `<Ok>` | chose any port you like. must match mapped container port
*Confirm port* | `<Yes>` |
*DNS provider* | **(*)Custom** `<Yes>` | DNS provider of your choice
*Upstream DNS provider* | **8.8.8.8, 8.8.4.4** `<Ok>` | [Google Public DNS](https://developers.google.com/speed/public-dns/)
*Settings correct* | `<Yes>` |
*Public IP or DNS* | **(*)DNS Entry - Use a public DNS** `<Ok>` | Internet provider contract 99% 'dynamic DNS' based
*Public DNS name* | e.g. **mypersonaladdress.dyndns.org** `<Ok>` | your reserved public DNS name 
*Confirm DNS name* | `<Yes>` | 
*Unattended upgrades* | `<No>` | manual update possible when calling `configure` again
*Reboot* | `<No>` | rebooting not possible in a container. restart container instead when setup finished

After the setup the configuration files can be created.

#### Configuration files

For a secure tunnel a server and a client configuration file pair needs to be created. The server file will remain in the container whereas the matching client file is to be imported into the OpenVPN client program.

To create a file pair enter the command `pivpn add` on the web page `.../shell` and press enter. When asked enter a name and a password and server and client files will be created.

To download the corresponding client file visit the web page `.../config` (a refresh click may be necessary). In the listed directory tree locate your client *.opvn file under your given name. Click it to download it and import it into your OpenVPN client.

The OpenVPN server configuration is completed and the server can be started.

#### Server start

Restart the container after configuration to start the OpenVPN server.

### License

Copyright (c) Hilscher Gesellschaft fuer Systemautomation mbH. All rights reserved.
Licensed under the LISENSE.txt file information stored in the project's source code repository.

As with all Docker images, these likely also contain other software which may be under other licenses (such as Bash, etc from the base distribution, along with any direct or indirect dependencies of the primary software being contained).
As for any pre-built image usage, it is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.

[![N|Solid](http://www.hilscher.com/fileadmin/templates/doctima_2013/resources/Images/logo_hilscher.png)](http://www.hilscher.com)  Hilscher Gesellschaft fuer Systemautomation mbH  www.hilscher.com
