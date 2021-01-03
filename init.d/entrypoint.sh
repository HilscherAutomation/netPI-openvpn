#!/bin/bash +e
# catch signals as PID 1 in a container

# SIGNAL-handler
term_handler() {

  exit 143; # 128 + 15 -- SIGTERM
}

# on callback, stop all started processes in term_handler
trap 'kill ${!}; term_handler' SIGINT SIGKILL SIGTERM SIGQUIT SIGTSTP SIGSTOP SIGHUP


#configre a default web proxy port if necessary
if [[ ! "${WEBPORT}" ]]; then
  WEBPORT=8080
fi

#configure the web proxy listening port 
if grep -Fq "<PORT>" /etc/nginx/sites-available/reverse-proxy.conf; then

  sed -i "s@<PORT>@$WEBPORT@g" -i /etc/nginx/sites-available/reverse-proxy.conf
fi

echo "'http://<host's ip address>:${WEBPORT}/shell' for web shell"
echo "'http://<host's ip address>:${WEBPORT}/clients' for client files web server"
echo ""

#Set Iptable ruleset to enable ip forwarding through tunnel
if [ -f "/etc/pivpn/openvpn/setupVars.conf" ] && [ -f "/usr/sbin/iptables" ]; then

   source "/etc/pivpn/openvpn/setupVars.conf"
   if iptables -t nat -C POSTROUTING -s "${pivpnNET}/${subnetClass}" -o "${IPv4dev}" -j MASQUERADE -m comment --comment "${VPN}-nat-rule" &> /dev/null; then
	echo "Iptables MASQUERADE rule is set"
   else
	echo "Setting Iptables MASQUERADE ruleset"
	iptables -t nat -I POSTROUTING -s "${pivpnNET}/${subnetClass}" -o "${IPv4dev}" -j MASQUERADE -m comment --comment "${VPN}-nat-rule"
	iptables-save > /etc/iptables/rules.v4
   fi

fi

#start openvpn service if configuration file exists
if [[ -f /etc/openvpn/server.conf ]]; then

  #make sure the openvpn group and user exist
  if ! grep -q openvpn /etc/group ; then
    groupadd openvpn
    useradd openvpn -g openvpn
  fi


  echo "Starting OpenPVN server..."
  openvpn --config /etc/openvpn/server.conf --client-config-dir /etc/openvpn/ccd &

fi

#start the lighttpd web server used to enable download of generated .ovpn files
echo "Starting web server..."
lighttpd -D -f /etc/lighttpd/lighttpd.conf &

#start the shellinabox daemon
echo "Starting web shell..."
shellinaboxd -b --disable-ssl --service /:${USER}:${USER}:${PWD}root:"PATH=${PATH} bash"

#start the reverse proxy
echo "Starting web proxy..."
nginx

#monitor .ovpn file folder for new files and update directory tree for client files web page
inotifywait -q -q -m -r -e create --format '%w%f' "/home/" | while read NEWFILE
do
   sleep 1
   tree -C -T "Clients OpenVPN config files (.ovpn)" -I "*.html" -P "*" --dirsfirst -F -r -H . /home/ > /home/index.html
   sed -i 's@</title>@</title><meta http-equiv="refresh" content="2;url=index.html">@g' -i /home/index.html 
   sed -i 's@</body>@<button onClick="window.location.reload();">Click to refresh page</button></body>@g' -i /home/index.html 
   if [ -f ${NEWFILE} ]; then
     chmod 0775 ${NEWFILE}
   fi
done

# wait forever not to exit the container
while true
do
  tail -f /dev/null & wait ${!}
done

exit 0
