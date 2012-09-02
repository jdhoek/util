#!/bin/bash

# AutoNFS v.1.1
#
# 2010-09-02    Jeroen Hoek <mail@jeroenhoek.nl>:
#   * Update script with helpful contributions from other users.
#   * Stop using logger, simply echo and let the system log it in /var/log/upstart.
# 2012-07-23    Martin Seener:
#   * Use rpcinfo instead of ping to check the status of the NFS server daemon, rather
#     than just the server being up.
#   * Add some useful mount options for a stable NFS mount.
# 2012-03-12    tobcro:
#   * Allow local and remote mountpoint to be different.
# 2010-01-24    Jeroen Hoek <mail@jeroenhoek.nl>:
#   * Initial script.


# Configuration parameters.

# The hostname or IP-address of the fileserver:
FILESERVER="yournfsserverhere"

# Mount Options (see mount man pages for info).
MOUNTOPTS="-o rw,hard,intr,tcp,actimeo=3"

# Check every X seconds (60 is a good default):
INTERVAL=60

# Delimeter used for separating fileserver/client shares below:
DELIMETER="|"

# The shares that need to be mounted. If the local and remote mount point
# differ, write something like "/media/remoteshare|/media/localshare", where "|" is
# the delimeter configured above. If the mount points are the same, you can also use 
# the short-hand "/media/share".
MOUNTS=( "/media/exampleRemote1|/media/exampleLocal1" "/media/exampleMount2" )

# Logging. Set to true for debugging and testing; false when everything works. Logs 
# are written to /var/log/upstart/autonfs.log.
LOG=true

# End of configuration


function log {
    if $LOG; then
        echo $1
    fi
}


log "Automatic NFS mount script started."

declare -a MOUNTP
while true; do
    # Is the NFS daemon responding?
    rpcinfo -t "$FILESERVER" nfs &>/dev/null
    if [ $? -eq 0 ]; then
        # Fileserver is up.
        log "Fileserver is up."
        for MOUNT in ${MOUNTS[@]}; do
            # Split up the share into the remote and local mount point.
            MOUNTP=(`echo ${MOUNT//$DELIMETER/ }`)
            # The second part of the mount string is the local mount point.
            # If there is no second part, local and remote are mounted on
            # the same location.
            HERE=${MOUNTP[${#MOUNTP[@]}-1]}
            THERE=${MOUNTP[0]}
            if grep -qsE "^([^ ])+ ${HERE}" /proc/mounts; then
                log "$HERE is already mounted."
            else
                # NFS mount not mounted, attempt mount
                log "NFS share not mounted; attempting to mount ${HERE}:"
                mount -t nfs ${MOUNTOPTS} ${FILESERVER}:${THERE} ${HERE}
            fi
        done
    else
        # Fileserver is down.
        log "Fileserver is down."
        for MOUNT in ${MOUNTS[@]}; do
            # Split up the share into the remote and local mount point.
            MOUNTP=(`echo ${MOUNT//$DELIMETER/ }`)
            # The second part of the mount string is the local mount point.
            # If there is no second part, local and remote are mounted on
            # the same location.
            HERE=${MOUNTP[${#MOUNTP[@]}-1]}
            THERE=${MOUNTP[0]}
            if grep -qsE "^([^ ])+ ${HERE}" /proc/mounts; then
                # NFS mount is still mounted; attempt umount
                log "Cannot reach ${FILESERVER}, unmounting NFS share ${HERE}."
                umount -f ${HERE}
            fi
        done
    fi
    sleep $INTERVAL
done
