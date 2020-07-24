tar_filesystem=(
fs_skeleton.tbz2
)

toolchain=(
http://releases.linaro.org/15.05/components/toolchain/binaries/arm-linux-gnueabihf/gcc-linaro-4.9-2015.05-x86_64_arm-linux-gnueabihf.tar.xz
)

paths=(
# name
# path

outputs
${PATH__ROOT}/outputs

toolchain
${PATH__ROOT}/toolchain

filesystem
${PATH__ROOT}/fs

tftp
${PATH__ROOT}/tftp

downloads
${PATH__ROOT}/downloads

src
${PATH__ROOT}/src

compat_wireless
${PATH__ROOT}/src/compat_wireless

#debugging
#${PATH__ROOT}/debugging

configuration
${PATH__ROOT}/configuration
)

repositories=(
# name
# url
# branch

kernel
git://git.ti.com/wilink8-wlan/wilink8-wlan-ti-linux-kernel.git
processor-sdk-linux-02.00.01

openssl
git://github.com/openssl/openssl
OpenSSL_1_1_1b

libnl
#git://github.com/tgraf/libnl.git <-- old path
git://github.com/thom311/libnl.git
libnl3_4_0

crda
git://git.ti.com/wilink8-wlan/crda.git
master

wireless_regdb
git://git.kernel.org/pub/scm/linux/kernel/git/sforshee/wireless-regdb.git
master-2017-03-07

driver
git://git.ti.com/wilink8-wlan/wl18xx.git
upstream_44

hostap
git://git.ti.com/wilink8-wlan/hostap.git
upstream_29_rebase

ti_utils
git://git.ti.com/wilink8-wlan/18xx-ti-utils.git
master

fw_download
git://git.ti.com/wilink8-wlan/wl18xx_fw.git
master

scripts_download
git://git.ti.com/wilink8-wlan/wl18xx-target-scripts.git
sitara-scripts

backports
git://git.ti.com/wilink8-wlan/backports.git
upstream_44

iw
git://git.kernel.org/pub/scm/linux/kernel/git/jberg/iw.git
v4.1

uim
git://git.ti.com/ti-bt/uim.git
master

bt-firmware
git://git.ti.com/ti-bt/service-packs.git
master

)
