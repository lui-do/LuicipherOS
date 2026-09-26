#!/usr/bin/env bash
# iso/profiledef.sh — LuicipherOS netinstall archiso profile (build with mkarchiso).
# Based on the official releng profile: boots a live Arch env, pulls this
# repo over the network, and runs the unattended install flow.
# The ISO stays SMALL on purpose: packages are fetched fresh at install
# time (rolling-release correctness), never baked in.
iso_name="luicipheros-netinstall"
iso_label="LUICI_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="LuicipherOS <https://github.com/lui-do/LuicipherOS>"
iso_application="LuicipherOS netinstall"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito'
           'uefi-ia32.systemd-boot.esp' 'uefi-x64.systemd-boot.esp'
           'uefi-ia32.systemd-boot.eltorito' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/luicipheros-install"]="0:0:755"
)
