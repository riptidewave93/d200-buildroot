#!/bin/bash
# Copy the files we care about to ./output/<date>-<flavour>/, plus the release
# downloads, keeping the last KEEP builds of each flavour (default 3, 0: all):
#   d200-<version>-<flavour>.zip             the fastboot set (flashing.md)
#   d200-<version>-<flavour>-maskrom.tar.xz  d200-full.img and the loader that
#                                            rkdeveloptool needs (install.md)
#   d200-<version>-<flavour>-update.tar      for the update page (ota.md)
#   collect_output.sh [release|debug]
set -e
. "$(dirname "${BASH_SOURCE[0]}")/buildroot-env.sh" "${1}"
images="${brout}/images"
out="${ourpath}/output/$(date +%Y%m%d-%H%M)-${flavor}"
keep=${KEEP:-3}

# a second build in the same minute replaces the first
rm -rf "${out}"
mkdir -p "${out}"
fastboot="idbloader.img idbloader-x4.img u-boot.itb kernel.itb rootfs.ubifs ubi.img d200-usb-loader.bin flash-fastboot.sh
          u-boot-rockchip-usb471.bin u-boot-rockchip-usb472.bin"
maskrom="d200-full.img rk3308_loader_wo_ftl.bin"
files="${fastboot} ${maskrom}"
for f in ${files}; do
    cp "${images}/${f}" "${out}/"
done
(cd "${out}" && sha256sum ${files} > SHA256SUMS)

# Release downloads, named by OS version
version=$(sed -n 's/^VERSION="\(.*\)"$/\1/p' "${brout}/target/usr/lib/os-release")
bundle="d200-${version:-dev}-${flavor}"
stage=$(mktemp -d)
mkdir "${stage}/${bundle}"
(cd "${out}" && cp ${fastboot} "${stage}/${bundle}/" && sha256sum ${fastboot} > "${stage}/${bundle}/SHA256SUMS")
(cd "${stage}" && zip -qrX "${out}/${bundle}.zip" "${bundle}")
rm -rf "${stage}"
tar -C "${out}" --transform "s,^,${bundle}-maskrom/," -cJf "${out}/${bundle}-maskrom.tar.xz" ${maskrom}
cp "${images}/update.tar" "${out}/${bundle}-update.tar"
(cd "${out}" && sha256sum "${bundle}.zip" "${bundle}-maskrom.tar.xz" "${bundle}-update.tar" >> SHA256SUMS)
echo "Saved build files to ${out#${ourpath}/}/ (${bundle}.zip, ${bundle}-maskrom.tar.xz, ${bundle}-update.tar)"

if [ "${keep}" -gt 0 ]; then
    ls -d "${ourpath}"/output/2*-"${flavor}"/ | head -n -"${keep}" | xargs -r rm -rf
fi
