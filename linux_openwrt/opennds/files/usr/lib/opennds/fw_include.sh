#!/bin/sh
#
# Add or remove the openNDS include in /etc/config/firewall.
# The include runs restart.sh when the firewall restarts.
#
# Usage: fw_include.sh add|remove
#
# Other packages may stage firewall changes in /tmp/.uci on purpose,
# without committing them. "uci commit firewall" would write those to
# flash as well, so it is not used here.
#
# Instead, the edit is made on a private copy of /etc/config/firewall,
# saved under a different config name so no staged changes apply to it.
# The copy then replaces /etc/config/firewall.
# Staged changes from other packages stay staged.
#
# A lock stops two runs of this script editing at the same time.
# Another program could still commit the firewall config while the copy
# is being edited, so the file is compared with the snapshot before it is
# replaced. If it has changed, the edit is made again.

action="$1"
fwconfig="/etc/config/firewall"
copyname="opennds_fw"
workdir="/tmp/opennds_fw_include.$$"
lockdir="/tmp/opennds_fw_include.lock"
lock_timeout=10
max_attempts=3

uci_copy() {
	uci -q -c "$workdir/config" -t "$workdir/save" "$@"
}

get_lock() {
	local waited=0
	local lockpid

	while ! mkdir "$lockdir" 2> /dev/null; do
		lockpid=$(cat "$lockdir/pid" 2> /dev/null)

		# A lock left by a process that no longer exists is stale
		if [ -n "$lockpid" ] && ! kill -0 "$lockpid" 2> /dev/null; then
			rm -rf "$lockdir"
			continue
		fi

		if [ "$waited" -ge "$lock_timeout" ]; then
			# The lock holder has not finished in time. Treat the lock as stale.
			logger -p daemon.warn -t opennds "fw_include.sh: removing a stale lock"
			rm -rf "$lockdir"
			waited=0
			continue
		fi

		sleep 1
		waited=$((waited + 1))
	done

	echo "$$" > "$lockdir/pid"
}

release_lock() {
	rm -rf "$lockdir"
}

cleanup() {
	rm -rf "$workdir"
	release_lock
}

# Edit the private copy. Returns 0 if the firewall config must be replaced, 1 if no change is needed.
edit_copy() {
	local current

	current=$(uci_copy get "$copyname.opennds")

	if [ "$action" = "add" ]; then

		if [ "$current" = "include" ]; then
			return 1
		fi

		uci_copy batch <<-EOT
			delete $copyname.opennds
			set $copyname.opennds=include
			set $copyname.opennds.type=script
			set $copyname.opennds.path=/usr/lib/opennds/restart.sh
			commit $copyname
		EOT
	else

		if [ -z "$current" ]; then
			return 1
		fi

		uci_copy batch <<-EOT
			delete $copyname.opennds
			commit $copyname
		EOT
	fi

	return 0
}

if [ "$action" != "add" ] && [ "$action" != "remove" ]; then
	echo "Usage: $0 add|remove"
	exit 1
fi

if [ ! -f "$fwconfig" ]; then
	exit 0
fi

get_lock
trap cleanup EXIT
trap 'exit 1' INT TERM

attempt=1

while [ "$attempt" -le "$max_attempts" ]; do
	rm -rf "$workdir"
	mkdir -p "$workdir/config" "$workdir/save"
	cp -p "$fwconfig" "$workdir/snapshot"
	cp -p "$workdir/snapshot" "$workdir/config/$copyname"

	if ! edit_copy; then
		exit 0
	fi

	# Write to a temporary file in /etc/config, then rename, so the change is atomic.
	# uci ignores file names that contain a dot.
	cp -p "$workdir/config/$copyname" "/etc/config/.firewall.opennds"

	if cmp -s "$workdir/snapshot" "$fwconfig"; then
		mv "/etc/config/.firewall.opennds" "$fwconfig"
		exit 0
	fi

	# The firewall config changed while it was being edited. Edit it again.
	rm -f "/etc/config/.firewall.opennds"
	attempt=$((attempt + 1))
done

logger -p daemon.err -t opennds "fw_include.sh: /etc/config/firewall kept changing - include $action not done"
exit 1
