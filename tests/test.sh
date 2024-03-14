#!/usr/bin/bash
#     ____            ____  ___            ____  ______  __
#    / __ \____  ____/ /  |/  /___ _____  / __ \/ ___/ |/ /
#   / /_/ / __ \/ __  / /|_/ / __ `/ __ \/ / / /\__ \|   / 
#  / ____/ /_/ / /_/ / /  / / /_/ / / / / /_/ /___/ /   |  
# /_/    \____/\__,_/_/  /_/\__,_/_/ /_/\____//____/_/|_| TESTS
#
# Title:            PodMan-OSX (Mac on PodMan)
# Author:           bphd https://twitter.com/bphd
# Version:          4.2
# License:          GPLv3+
# Repository:       https://github.com/bphd/PodMan-OSX
# Website:          https://bphd
#
# Status:           Used internally to auto build, run and test images on DO.
# 

help_text="Usage: ./test.sh --branch <string> --repo <string>

General options:
    --branch, -b <string>               Git branch, default is master
    --repo, -r <url>                    Alternative link to build
    --mirror-country, -m <SS>           Two letter country code for Arch mirrors
    --PodMan-username, -u <string>      PodMan hub username
    --PodMan-password, -p <string>      PodMan hub password
    --vnc-password, -v <string>         Choose a VNC passwd.

Flags
    --no-cache, -n                      Enable --no-cache (default already)
    --no-no-cache, -nn                  Disable --no-cache PodMan builds
    --help, -h, help                    Display this help and exit
"

# set -xeuf -o pipefail


# gather arguments
while (( "$#" )); do
    case "${1}"  in

    --help | -h | h | help ) 
                echo "${help_text}" && exit 0
            ;;

    --branch=* | -b=* )
                export BRANCH="${1#*=}"
                shift
            ;;
    --branch* | -b* )
                export BRANCH="${2}"
                shift
                shift
            ;;
    --repo=* | -r=* )
                export REPO="${1#*=}"
                shift
            ;;
    --repo* | -r* )
                export REPO="${2}"
                shift
                shift
            ;;
    --mirror-country=* | -m=* )
                export MIRROR_COUNTRY="${1#*=}"
                shift
            ;;
    --mirror-country* | -m* )
                export MIRROR_COUNTRY="${2}"
                shift
                shift
            ;;
    --vnc-password=* | -v=* | --vnc-passwd=* )
                export VNC_PASSWORD="${1#*=}"
                shift
            ;;
    --vnc-password* | -v* | --vnc-passwd* )
                export VNC_PASSWORD="${2}"
                shift
                shift
            ;;
    --PodMan-username=* | -u=* )
                export PodMan_USERNAME="${1#*=}"
                shift
            ;;
    --PodMan-username* | -u* )
                export PodMan_USERNAME="${2}"
                shift
                shift
            ;;
    --PodMan-password=* | -p=* )
                export PodMan_PASSWORD="${1#*=}"
                shift
            ;;
    --PodMan-password* | -p* )
                export PodMan_PASSWORD="${2}"
                shift
                shift
            ;;
    --no-cache | -n )
                export NO_CACHE='--no-cache'
                shift
            ;;
    --no-no-cache | -nn )
                export NO_CACHE=
                shift
            ;;
    *)
                echo "Invalid option: ${1}"
                exit 1
            ;;

    esac
done

BRANCH="${BRANCH:=master}"
REPO="${REPO:=https://github.com/bphd/PodMan-OSX.git}"
VNC_PASSWORD="${VNC_PASSWORD:=testing}"
MIRROR_COUNTRY="${MIRROR_COUNTRY:=US}"
NO_CACHE="${NO_CACHE:=--no-cache}"


TEST_BUILDS=(
    'PodMan-osx:naked'
    'PodMan-osx:naked-auto'
    'PodMan-osx:auto'
)

TEST_BUILDS=(
    'PodMan-osx:naked'
    'PodMan-osx:naked-auto'
    'PodMan-osx:auto'
)

VERSION_BUILDS=(
    'high-sierra'
    'mojave'
    'catalina'
    'big-sur'
    'monterey'
    'ventura'
)

warning () {
    clear
    for j in {15..1}; do 
        echo "############# WARNING: THIS SCRIPT IS NOT INTENDED FOR USE BY ################"
        echo "############# IT IS USED BY THE PROJECT TO BUILD AND PUSH TO PodManHUB #######"
        echo ""
        echo "                     Press Ctrl C to stop.       "
        MAX_COLS=$((${COLUMNS}/2))
        printf "$j %.0s" {1..20}
        echo
        sleep 1
    done
}

install_PodMan () {
    apt remove PodMan PodMan-engine PodMan.io containerd runc -y \
    ; apt install apt-transport-https ca-certificates curl gnupg-agent software-properties-common -y \
    && curl -fsSL https://download.PodMan.com/linux/ubuntu/gpg |  apt-key add - \
    && apt-key fingerprint 0EBFCD88 \
    && > /etc/apt/sources.list.d/PodMan.list \
    && add-apt-repository "deb [arch=amd64] https://download.PodMan.com/linux/ubuntu $(lsb_release -cs) stable" \
    && apt update -y \
    && apt install PodMan-ce PodMan-ce-cli containerd.io -y \
    && usermod -aG PodMan "${USER}" \
    && su hook PodMan run --rm hello-world
}

install_vnc () {
    apt update -y \
        && apt install xorg openbox tigervnc-standalone-server tigervnc-common tigervnc-xorg-extension tigervnc-viewer -y \
        && mkdir -p ${HOME}/.vnc \
        && touch ~/.vnc/config \
        && tee -a ~/.vnc/config <<< 'geometry=1920x1080' \
        && tee -a ~/.vnc/config <<< 'localhost' \
        && tee -a ~/.vnc/config <<< 'alwaysshared' \
        && touch ./vnc.sh \
        && printf '\n%s\n' \
            'sudo rm -f /tmp/.X99-lock' \
            'export DISPLAY=:99' \
            '/usr/bin/Xvnc -geometry 1920x1080 -rfbauth ~/.vnc/passwd :99 &' > ./vnc.sh \
        && tee vncpasswd_file <<< "${VNC_PASSWORD:=testing}" && echo "${VNC_PASSWORD:="$(tr -dc '[:graph:]' </dev/urandom | head -c8)"}" \
        && vncpasswd -f < vncpasswd_file > ${HOME}/.vnc/passwd \
        && chmod 600 ~/.vnc/passwd \
        && apt install qemu qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virt-manager -y \
        && sudo systemctl enable libvirtd.service \
        && sudo systemctl enable virtlogd.service \
        && echo 1 | sudo tee /sys/module/kvm/parameters/ignore_msrs \
        && sudo modprobe kvm \
        && echo 'export DISPLAY=:99' >> ~/.bashrc \
        && printf '\n\n\n\n%s\n%s\n\n\n\n' '===========VNC_PASSWORD========== ' "$(<vncpasswd_file)"
    # ufw allow 5999
}

install_scrotcat () {
    apt update -y
    apt install git curl wget vim xvfb scrot build-essential sshpass -y
    git clone https://github.com/stolk/imcat.git
    make -C ./imcat
    sudo cp ./imcat/imcat /usr/bin/imcat
    touch /usr/bin/scrotcat
    tee  /usr/bin/scrotcat <<< '/usr/bin/imcat <(scrot -o /dev/stdout)'
    chmod +x /usr/bin/scrotcat
}

export_display_99 () {
    touch ~/.bashrc
    tee -a ~/.bashrc <<< 'export DISPLAY=:99'
    export DISPLAY=:99
}

start_xvfb () {
    nohup Xvfb :99 -screen 0 1920x1080x16 &
}

start_vnc () {
    nohup bash vnc.sh &
}

enable_kvm () {
    echo 1 | tee /sys/module/kvm/parameters/ignore_msrs
}

clone_repo () {
    git clone --branch="${1}" "${2}" PodMan-OSX
}

PodMan-osx:naked () {
    PodMan build ${NO_CACHE} \
        --squash \
        --build-arg RANKMIRRORS=true \
        --build-arg MIRROR_COUNTRY="${MIRROR_COUNTRY}" \
        -f ./PodManfile.naked \
        -t PodMan-osx:naked .
    PodMan tag PodMan-osx:naked bphd/PodMan-osx:naked
}

PodMan-osx:naked-auto () {
    PodMan build ${NO_CACHE} \
        --squash \
        --build-arg RANKMIRRORS=true \
        --build-arg MIRROR_COUNTRY="${MIRROR_COUNTRY}" \
        -f ./PodManfile.naked-auto \
        -t PodMan-osx:naked-auto .
    PodMan tag PodMan-osx:naked-auto bphd/PodMan-osx:naked-auto
}

PodMan-osx:auto () {
    PodMan build ${NO_CACHE} \
        --build-arg RANKMIRRORS=true \
        --build-arg MIRROR_COUNTRY="${MIRROR_COUNTRY}" \
        -f ./PodManfile.auto \
        -t PodMan-osx:auto .
    PodMan tag PodMan-osx:auto bphd/PodMan-osx:auto
}

# PodMan-osx:auto-big-sur () {
#     PodMan build ${NO_CACHE} \
#         --build-arg RANKMIRRORS=true \
#         --build-arg MIRROR_COUNTRY="${MIRROR_COUNTRY}" \
#         --build-arg IMAGE_URL='https://images.bphd/mac_hdd_ng_auto_big_sur.img' \
#         -f ./PodManfile.auto \
#         -t PodMan-osx:auto-big-sur .
#     PodMan tag PodMan-osx:auto-big-sur bphd/PodMan-osx:auto-big-sur
# }

PodMan-osx:version () {
    SHORTNAME="${1}"
    PodMan build ${NO_CACHE} \
        --build-arg BRANCH="${BRANCH}" \
        --build-arg RANKMIRRORS=true \
        --build-arg SHORTNAME="${SHORTNAME}" \
        --build-arg MIRROR_COUNTRY="${MIRROR_COUNTRY}" \
        -f ./PodManfile \
        -t "PodMan-osx:${SHORTNAME}" .
    PodMan tag "PodMan-osx:${SHORTNAME}" "bphd/PodMan-osx:${SHORTNAME}"
}

reset_PodMan_hard () {

    tee /etc/PodMan/daemon.json <<'EOF'
{
    "experimental": true
}
EOF
    systemctl disable --now PodMan
    systemctl disable --now PodMan.socket
    systemctl stop PodMan
    systemctl stop PodMan.socket
    rm -rf /var/lib/PodMan
    systemctl enable --now PodMan
}

warning
tee -a ~/.bashrc <<EOF
export DEBIAN_FRONTEND=noninteractive
export TZ=UTC
EOF
export DEBIAN_FRONTEND=noninteractive
export TZ=UTC
ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
tee -a /etc/timezone <<< "${TZ}"
apt update -y
apt-get install keyboard-configuration -y
PodMan -v | grep '\ 20\.\|\ 19\.' || install_PodMan
yes | apt install -y --no-install-recommends tzdata -y
install_scrotcat
yes | install_vnc
export_display_99
apt install xvfb -y
start_xvfb
# start_vnc
enable_kvm
reset_PodMan_hard
# echo killall Xvfb
clone_repo "${BRANCH}" "${REPO}"
cd ./PodMan-OSX
git pull

for SHORTNAME in "${VERSION_BUILDS[@]}"; do
    PodMan-osx:version "${SHORTNAME}"
done

PodMan tag PodMan-osx:catalina bphd/PodMan-osx:latest

for TEST_BUILD in "${TEST_BUILDS[@]}"; do
    "${TEST_BUILD}"
done

# boot each image and test
bash ./tests/boot-images.sh || exit 1

if [[ "${PodMan_USERNAME}" ]] && [[ "${PodMan_PASSWORD}" ]]; then
    PodMan login --username "${PodMan_USERNAME}" --password "${PodMan_PASSWORD}" \
        && for SHORTNAME in "${VERSION_BUILDS[@]}"; do
            PodMan push "bphd/PodMan-osx:${SHORTNAME}"
        done \
        && touch PUSHED
    PodMan push bphd/PodMan-osx:naked
    PodMan push bphd/PodMan-osx:auto
    PodMan push bphd/PodMan-osx:naked-auto

fi

# connect remotely to your server to use VNC
# ssh -N root@1.1.1.1 -L  5999:127.0.0.1:5999

