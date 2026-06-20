#!/bin/sh
# Linux-Router-Monitor :: remote collector
# Runs ON the router (Asuswrt-Merlin / BusyBox ash). Pushed to the router by
# install.sh and executed once per poll over a shared SSH ControlMaster socket.
#
# It prints a flat, easy-to-parse text dump (scalar "key=value" lines plus
# prefixed lines for repeating records). The desktop-side collector turns this
# into JSON, computes rates, and merges AdGuard Home stats. Keeping this side
# "dumb" means no jq/python dependency is required on the router.

PING_TARGET="${1:-8.8.8.8}"

# Map of wireless ifaces -> human band label. Verified on GT-AXE16000:
#   eth7=5GHz-1  eth8=5GHz-2  eth9=6GHz  eth10=2.4GHz
WLIFACES="eth7 eth8 eth9 eth10"
band_of() {
	case "$1" in
		eth7) echo "5GHz-1"; ;;
		eth8) echo "5GHz-2"; ;;
		eth9) echo "6GHz";   ;;
		eth10) echo "2.4GHz";;
		*) echo "$1";        ;;
	esac
}
wlidx_of() {
	case "$1" in
		eth7) echo 0;; eth8) echo 1;; eth9) echo 2;; eth10) echo 3;; *) echo "";;
	esac
}

echo "TS=$(date +%s)"

############ SYSTEM ############
read L1 L5 L15 PROCS REST < /proc/loadavg
echo "load1=$L1"; echo "load5=$L5"; echo "load15=$L15"; echo "procs=$PROCS"
echo "uptime=$(awk '{print $1}' /proc/uptime)"
echo "cores=$(grep -c '^processor' /proc/cpuinfo)"
# Raw cpu jiffies (desktop computes utilisation from successive samples)
grep '^cpu' /proc/stat | while read -r line; do echo "STAT $line"; done

# Memory
awk '/^MemTotal:/{print "mem_total="$2}
     /^MemFree:/{print "mem_free="$2}
     /^MemAvailable:/{print "mem_avail="$2}
     /^Buffers:/{print "mem_buffers="$2}
     /^Cached:/{print "mem_cached="$2}
     /^SwapTotal:/{print "swap_total="$2}
     /^SwapFree:/{print "swap_free="$2}' /proc/meminfo

# Temperatures (millidegree -> desktop divides)
[ -f /sys/class/thermal/thermal_zone0/temp ] && echo "cpu_temp_milli=$(cat /sys/class/thermal/thermal_zone0/temp)"

# Storage
echo "JFFS $(df /jffs 2>/dev/null | awk 'NR==2{print $2,$3,$4}')"
USBMNT=$(df 2>/dev/null | awk '/ADGUARD/{print $1,$2,$3,$4; exit}')
[ -n "$USBMNT" ] && echo "USB $USBMNT"

# Conntrack
echo "conntrack=$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null)"
echo "conntrack_max=$(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null)"

############ WAN ############
echo "wan_proto=$(nvram get wan0_proto)"
echo "wan_ip=$(nvram get wan0_ipaddr)"
echo "wan_gw=$(nvram get wan0_gateway)"
echo "wan_dns=$(nvram get wan0_dns)"
echo "wan_state=$(nvram get wan0_state_t)"
WANIF=$(nvram get wan0_pppoe_ifname); [ -z "$WANIF" ] && WANIF=$(nvram get wan0_ifname)
echo "wan_ifname=$WANIF"

############ INTERFACE COUNTERS (for rate calc) ############
# name rx_bytes tx_bytes  (desktop diffs against previous sample)
# /proc/net/dev: "<name>: <rxbytes> <rxpkts> ... <txbytes(9th)> ..."
awk -F: 'NR>2{name=$1; gsub(/[ \t]/,"",name); split($2,a," ");
            if(name!="" && a[1]!="") print "IF "name" "a[1]" "a[9]}' /proc/net/dev

############ WIRED PORT LINK ############
for p in eth0 eth1 eth2 eth3 eth4 eth5 eth6; do
	media=$(ethctl "$p" media-type 2>/dev/null | grep -i "Link is" | head -1)
	[ -n "$media" ] && echo "PORT $p ${media##*Link is }"
done

############ WIFI (per radio) ############
for ifc in $WLIFACES; do
	band=$(band_of "$ifc"); idx=$(wlidx_of "$ifc")
	st=$(wl -i "$ifc" status 2>/dev/null)
	prim=$(echo "$st" | sed -n 's/.*Primary channel: \([0-9]*\).*/\1/p' | head -1)
	width=$(echo "$st" | sed -n 's/.*channel [0-9]* \([0-9]*MHz\).*/\1/p' | head -1)
	noise=$(echo "$st" | sed -n 's/.*noise: \(-*[0-9]*\) dBm.*/\1/p' | head -1)
	ssid=$(nvram get wl${idx}_ssid)
	radio=$(nvram get wl${idx}_radio)
	txpower=$(nvram get wl${idx}_txpower)
	temp=$(wl -i "$ifc" phy_tempsense 2>/dev/null | awk '{print $1}')
	# channel-busy / interference from chanim (data line = not the header)
	cim=$(wl -i "$ifc" chanim_stats 2>/dev/null | awk 'NF>=15 && $1!="chanspec"{l=$0} END{print l}')
	busy=$(echo "$cim"   | awk '{print $15}')
	glitch=$(echo "$cim" | awk '{print $11}')
	badplcp=$(echo "$cim"| awk '{print $12}')
	txop=$(echo "$cim"   | awk '{print $8}')
	dfs=$(wl -i "$ifc" dfs_status 2>/dev/null | sed -n 's/state \([A-Za-z()-]*\).*/\1/p' | head -1)
	nclients=$(wl -i "$ifc" assoclist 2>/dev/null | grep -c .)
	echo "RADIO ifc=$ifc band=$band ssid=$ssid radio=$radio chan=$prim width=$width noise=$noise txpower=$txpower temp=$temp busy=$busy glitch=$glitch badplcp=$badplcp txop=$txop dfs=$dfs clients=$nclients"
	# per-client signal
	for mac in $(wl -i "$ifc" assoclist 2>/dev/null | awk '{print $2}'); do
		rssi=$(wl -i "$ifc" rssi "$mac" 2>/dev/null)
		si=$(wl -i "$ifc" sta_info "$mac" 2>/dev/null)
		# "rate of last tx/rx pkt: NNN kbps" -> desktop converts kbps to Mbps
		txr=$(echo "$si" | sed -n 's/.*rate of last tx pkt: \([0-9]*\) kbps.*/\1/p' | head -1)
		rxr=$(echo "$si" | sed -n 's/.*rate of last rx pkt: \([0-9]*\) kbps.*/\1/p' | head -1)
		# cumulative bytes -> desktop diffs into a live per-client throughput
		txb=$(echo "$si" | sed -n 's/.*tx total bytes: \([0-9]*\).*/\1/p' | head -1)
		rxb=$(echo "$si" | sed -n 's/.*rx data bytes: \([0-9]*\).*/\1/p' | head -1)
		echo "STA mac=$mac band=$band rssi=$rssi txrate=$txr rxrate=$rxr txbytes=$txb rxbytes=$rxb"
	done
done

############ DHCP LEASES ############
if [ -f /var/lib/misc/dnsmasq.leases ]; then
	while read -r exp mac ip name rest; do
		echo "LEASE mac=$mac ip=$ip name=$name"
	done < /var/lib/misc/dnsmasq.leases
fi

############ ARP (connected status: flags!=0x0 means reachable) ############
awk 'NR>1 && $4!="00:00:00:00:00:00"{print "ARP "$4" "$3}' /proc/net/arp

############ BLOCKED (per-MAC firewall DROP rules) ############
iptables -S FORWARD 2>/dev/null | grep -io 'mac-source [0-9A-Fa-f:]\{17\}' | awk '{print "BLOCKED "$2}'

############ AIPROTECTION (state only) ############
echo "wrs_protect=$(nvram get wrs_protect_enable)"
echo "wrs_mals=$(nvram get wrs_mals_enable)"

############ INFO ############
echo "model=$(nvram get productid)"
echo "fw=$(nvram get buildno).$(nvram get extendno)"
echo "lan_ip=$(nvram get lan_ipaddr)"

############ WAN LATENCY (from router = true WAN RTT) ############
png=$(ping -c 3 -w 4 "$PING_TARGET" 2>/dev/null)
echo "ping_loss=$(echo "$png" | sed -n 's/.*, \([0-9]*\)% packet loss.*/\1/p')"
echo "ping_rtt=$(echo "$png" | sed -n 's#.*= [0-9.]*/\([0-9.]*\)/.*#\1#p')"

echo "END=1"
