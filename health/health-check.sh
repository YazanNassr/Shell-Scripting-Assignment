system_info() {
	distro="$(cat /etc/os-release | awk '/^NAME=/')"
	distro="${distro: 6: -1}"
	uptime="$(uptime -p)"
	echo "$distro|$uptime"
}

cpu_cores() {
	echo "$(cat /proc/cpuinfo | awk "/^core id/"  | wc -l)"
}

cpu_usage() {
	idle=$(mpstat 1 1 | awk '/^Average:/ { print $NF }')
	busy=$(echo "100 - $idle" | bc)
	echo "$busy%|$idle%"
}

heaviest_processes_cpu() {
	count="$1"
	res=$(ps -eo pid,cmd,%mem,%cpu --sort=-%cpu | head -n $count)
	echo "$res"
}

mem_usage() {
	memstats="$(free -h)"
	total="$(echo "$memstats" | awk '/^Mem/ { print $2 }')"
	avail="$(echo "$memstats" | awk '/^Mem/ { print $NF }')"
	echo "$total|$avail"
}

swp_usage() {
	memstats="$(free -h)"
	total="$(echo "$memstats" | awk '/^Swap/ { print $2 }')"
	avail="$(echo "$memstats" | awk '/^Swap/ { print $NF }')"
	echo "$total|$avail"
}

disk_usage() {
	mountpoints="/ /boot /home "
	for mp in $mountpoints ; do
		rsize="$(df --output=size -h $mp | tail -n 1)"
		rfree="$(df --output=avail -h $mp | tail -n 1)"
		echo "$mp|${rsize:1}|${rfree:1}"
	done
}

print_pretty_bytes() {
	tmp="$1"

	if [ "$tmp" -lt "1024" ] ; then
		echo "${tmp}B"
	elif [ $tmp -lt 1048576 ] ; then
		echo "$(expr $tmp / 1024)K"
	elif [ $tmp -lt 1073741824 ] ; then
		echo "$(expr $tmp / 1048576)M"
	else
		echo "$(expr $tmp / 1073741824)G"
	fi
}


network_activity() {
	received="$(ifstat -pj | grep "rx_bytes" | awk -F ': ' '{sum += $2} END {print sum}')"
	transmitted="$(ifstat -pj | grep "tx_bytes" | awk -F ': ' '{sum += $2} END {print sum}')"
	received=$(print_pretty_bytes $received)
	transmitted=$(print_pretty_bytes $transmitted)
	echo "$transmitted|$received"
}

bh_helper() {
	cd "/sys/class/power_supply/BAT0"
	res=$(cat "$1")
	echo "$res"
}

battery_health() {
	capacity="$(bh_helper capacity)%"
	status="$(bh_helper status)"
	health="$(expr $(bh_helper charge_full) / $(bh_helper charge_full_design) \* 100)%"

	echo "$capacity|$status|$health"
}

service_status() {
    service_name="$1"

    if ! systemctl list-unit-files --type=service | grep -q "^$service_name"; then
        echo "Uninstalled"
        return
    fi

    if systemctl is-active --quiet "$service_name"; then
        echo "Running"
    else
        if systemctl is-enabled --quiet "$service_name"; then
            echo "Inactive"
        else
            echo "Disabled"
        fi
    fi
}

docker_status() {
	echo "$(service_status 'docker.service')"
}

gdm_status() {
	echo "$(service_status 'gdm.service')"
}

mysql_status() {
	echo "$(service_status 'mysql.service')"
}

available_updates() {
	res="-1"
	if command -v apt &> /dev/null ; then
		apt update &> /dev/null
		res="$(apt list --upgradable | wc -l)"
		res="$(expr $res - 1)"
	elif command -v dnf &> /dev/null ; then
		res="$(dnf check-update | grep "update" | wc -l)"
	fi

	echo "$res"
}


source simple-curses.sh
# from this repo: https://github.com/metal3d/bashsimplecurses

main() {
	window "System Health Check Report" "yellow" "50%"
	append_tabbed "$(system_info)" 2 "|"
	endwin

	window "Available Updates" "yellow" "50%"
	tmp="$(available_updates)"
	if [ "$tmp" != "0" ] ; then
		append "You have: $(available_updates) packages to update"
	else
		append "Your system is up to date!" 
	fi
	endwin

	window "Services" "yellow" "50%"
	append_tabbed "Name|Status" 2 "|"
	append_tabbed "Docker|$(docker_status)" 2 "|"
	append_tabbed "GDM|$(gdm_status)" 2 "|"
	append_tabbed "MySQL|$(mysql_status)" 2 "|"
	endwin

	window "Logs" "yellow" "50%"
	if [ "$EUID" -eq "0" ] ; then 
		dmesg | tail -n 7 > /dev/shm/deskbar.dmesg
		append_file /dev/shm/deskbar.dmesg
		rm -f /dev/shm/deskbar.dmesg
	else
		append "You need to be root to read kernel messages"
	fi
	endwin

	col_right
	move_up
	
	window "CPU Utilization" "green" "50%"
	append_tabbed "Cores|Usage|Idle" 3 "|"
	append_tabbed "$(cpu_cores)|$(cpu_usage)" 3 "|"
	endwin

	window "Disk Utilization" "green" "50%"
	append_tabbed "Mountpoint|Size|Available" 3 "|"
	dinfo="$(disk_usage)"
	for row in $dinfo ; do
		append_tabbed "$row" 3 "|"
	done
	endwin

	window "Memory Utilization" "green" "50%"
	append_tabbed "|Total|Available" 3 "|"
	append_tabbed "Main|$(mem_usage)" 3 "|"
	append_tabbed "Swap|$(swp_usage)" 3 "|"
	endwin

	window "Network Activity" "green" "50%"
	append_tabbed "Transmitted|Received" 2 "|"
	append_tabbed "$(network_activity)" 2 "|"
	endwin

	window "Battery Health" "green" "50%"
	append_tabbed "Capacity|Status|Health" 3 "|"
	append_tabbed "$(battery_health)" 3 "|"
	endwin
}

update() {
    # immediately exit the script
    # if you want it to update every x seconds, delete this function
    exit 0
}

main_loop -t 0.5
######################################################################
