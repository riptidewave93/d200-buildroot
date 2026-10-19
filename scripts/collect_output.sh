#!/bin/bash
# Copy the files we care about to ./output/<date>-<flavour>/ plus a release
# bundle (d200-<version>-<flavour>.tar.gz) and the update bundle
# (d200-<version>-<flavour>-update.tar), keeping the last KEEP builds of each
# flavour (default 3, 0: all).
#   collect_output.sh [release|debug]
set -e
. "$(dirname "${BASH_SOURCE[0]}")/buildroot-env.sh" "${1}"
images="${brout}/images"
out="${ourpath}/output/$(date +%Y%m%d-%H%M)-${flavor}"
keep=${KEEP:-3}

# a second build in the same minute replaces the first
rm -rf "${out}"
mkdir -p "${out}"
files="idbloader.img idbloader-x4.img u-boot.itb kernel.itb rootfs.ubifs ubi.img d200-usb-loader.bin flash-fastboot.sh
       u-boot-rockchip-usb471.bin u-boot-rockchip-usb472.bin d200-full.img rk3308_loader_wo_ftl.bin"
for f in ${files}; do
    cp "${images}/${f}" "${out}/"
done
(cd "${out}" && sha256sum ${files} > SHA256SUMS)

# Release bundle: everything above in one archive, named by OS version
version=$(sed -n 's/^VERSION="\(.*\)"$/\1/p' "${brout}/target/usr/lib/os-release")
bundle="d200-${version:-dev}-${flavor}"
tar -C "${out}" --transform "s,^,${bundle}/," -czf "${out}/${bundle}.tar.gz" ${files} SHA256SUMS

# Update bundle (docs/ota.md)
cp "${images}/update.tar" "${out}/${bundle}-update.tar"
(cd "${out}" && sha256sum "${bundle}-update.tar" >> SHA256SUMS)
echo "Saved build files to ${out#${ourpath}/}/ (bundle: ${bundle}.tar.gz, update: ${bundle}-update.tar)"

if [ "${keep}" -gt 0 ]; then
    ls -d "${ourpath}"/output/2*-"${flavor}"/ | head -n -"${keep}" | xargs -r rm -rf
fi
