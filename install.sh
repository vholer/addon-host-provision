#!/bin/bash

# -------------------------------------------------------------------------- #
# Copyright 2002-2018, OpenNebula Project, OpenNebula Systems                #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

ARGS=$*

usage() {
    echo
    echo "Usage: install.sh [-u install_user] [-g install_group]"
    echo "                  [-d ONE_LOCATION] [-l] [-h]"
    echo
    echo "-d: target installation directory, if not defined it'd be root. Must be"
    echo "    an absolute path. Installation will be selfcontained"
    echo "-l: creates symlinks instead of copying files, useful for development"
    echo "-h: prints this help"
}

PARAMETERS="hlu:g:d:"

if [ $(getopt --version | tr -d " ") = "--" ]; then
    TEMP_OPT=`getopt $PARAMETERS "$@"`
else
    TEMP_OPT=`getopt -o $PARAMETERS -n 'install.sh' -- "$@"`
fi

if [ $? != 0 ] ; then
    usage
    exit 1
fi

eval set -- "$TEMP_OPT"

LINK="no"
ONEADMIN_USER=`id -u`
ONEADMIN_GROUP=`id -g`
SRC_DIR=$PWD

while true ; do
    case "$1" in
        -h) usage; exit 0;;
        -d) ROOT="$2" ; shift 2 ;;
        -l) LINK="yes" ; shift ;;
        -u) ONEADMIN_USER="$2" ; shift 2;;
        -g) ONEADMIN_GROUP="$2"; shift 2;;
        --) shift ; break ;;
        *)  usage; exit 1 ;;
    esac
done

export ROOT

if [ -z "$ROOT" ]; then
    VAR_LOCATION="/var/lib/one"
    LIB_LOCATION="/usr/lib/one"
    ETC_LOCATION="/etc/one"
    SHARE_LOCATION="/usr/share/one"
    MAN_LOCATION="/usr/share/man/man1"
    BIN_LOCATION="/usr/bin"
else
    VAR_LOCATION="$ROOT/var"
    LIB_LOCATION="$ROOT/usr"
    ETC_LOCATION="$ROOT/etc"
    SHARE_LOCATION="$ROOT/share"
    MAN_LOCATION="$ROOT/share/man/man1"
    BIN_LOCATION="$ROOT/bin"
fi

do_file() {
    if [ "$UNINSTALL" = "yes" ]; then
        rm $1
    else
        if [ "$LINK" = "yes" ]; then
            if [ -L "$SRC_DIR/$1" ]; then
                mkdir -p `dirname $2`
                cp -Rd $SRC_DIR/$1 $2
            else
                ln -fs $SRC_DIR/$1 $2
            fi
        else
            cp -R $SRC_DIR/$1 $2
        fi
    fi
}

copy_files() {
    FILES=$1
    DST=$DESTDIR$2

    mkdir -p $DST

    for f in $FILES; do
        do_file $f $DST
    done
}

change_ownership() {
    DIRS=$*
    for d in $DIRS; do
        chown -R $ONEADMIN_USER:$ONEADMIN_GROUP $DESTDIR$d
    done
}

copy_files "src/pm_mad/remotes/packet/*" "$VAR_LOCATION/remotes/pm/packet"
copy_files "src/pm_mad/remotes/ec2/*" "$VAR_LOCATION/remotes/pm/ec2"
copy_files "src/pm_mad/remotes/dummy/*" "$VAR_LOCATION/remotes/pm/dummy"


copy_files "src/vmm_mad/remotes/packet/cancel" "$VAR_LOCATION/remotes/vmm/packet"
copy_files "src/vmm_mad/remotes/packet/deploy" "$VAR_LOCATION/remotes/vmm/packet"
copy_files "src/vmm_mad/remotes/packet/poll" "$VAR_LOCATION/remotes/vmm/packet"
copy_files "src/vmm_mad/remotes/packet/reboot" "$VAR_LOCATION/remotes/vmm/packet"
copy_files "src/vmm_mad/remotes/packet/reset" "$VAR_LOCATION/remotes/vmm/packet"
copy_files "src/vmm_mad/remotes/packet/shutdown" "$VAR_LOCATION/remotes/vmm/packet"
copy_files "src/vmm_mad/remotes/packet/packet_driver.rb" "$LIB_LOCATION/ruby"
copy_files "src/vmm_mad/remotes/packet/packet_driver.default" "$ETC_LOCATION"

copy_files "src/im_mad/remotes/packet.d/*" "$VAR_LOCATION/remotes/im/packet.d"

copy_files "src/cli/oneprovision" $BIN_LOCATION
copy_files "src/cli/one_helper/oneprovision_helper.rb" "$LIB_LOCATION/ruby/cli/one_helper"
copy_files "src/cli/etc/oneprovision.yaml" "$ETC_LOCATION/cli"

copy_files "share/oneprovision/ansible/*" "$SHARE_LOCATION/oneprovision/ansible"
copy_files "share/oneprovision/man/oneprovision.1" $MAN_LOCATION
copy_files "share/oneprovision/Gemfile" "$SHARE_LOCATION/oneprovision"
copy_files "share/oneprovision/install_gems" "$SHARE_LOCATION/oneprovision"

copy_files "share/vendors/ruby/gems/packethost/*" "$LIB_LOCATION/ruby/vendors/packethost"

change_ownership "$VAR_LOCATION/remotes/pm/packet" "$VAR_LOCATION/remotes/vmm/packet"
