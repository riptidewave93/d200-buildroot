#!/bin/bash
# Copy the files we care about to ./output/<date>-<flavour>/ plus a release
# bundle (d200-<version>-<flavour>.tar.gz), keeping the last KEEP builds of each
# flavour.
#   collect_output.sh [release|debug]
set -e
. "$(dirname "${BASH_SOURCE[0]}")/buildroot-env.sh" "${1}"
images="${brout}/images"
out="${ourpath}/output/$(date +%Y%m%d-%H%M)-${flavor}"
keep=${KEEP:-3}

mkdir -p "${out}"
files="idbloader.img u-boot.itb kernel.itb rootfs.ubifs ubi.img d200-usb-loader.bin flash-fastboot.sh
       u-boot-rockchip-usb471.bin u-boot-rockchip-usb472.bin"
for f in ${files}; do
    cp "${images}/${f}" "${out}/"
done
(cd "${out}" && sha256sum ${files} > SHA256SUMS)

# Release bundle: everything above in one archive, named by OS version
version=$(sed -n 's/^VERSION="\(.*\)"$/\1/p' "${brout}/target/usr/lib/os-release")
bundle="d200-${version:-dev}-${flavor}"
tar -C "${out}" --transform "s,^,${bundle}/," -czf "${out}/${bundle}.tar.gz" ${files} SHA256SUMS
echo "Saved build files to ${out#${ourpath}/}/ (bundle: ${bundle}.tar.gz)"

ls -d "${ourpath}"/output/2*-"${flavor}"/ | head -n -"${keep}" | xargs -r rm -rf
