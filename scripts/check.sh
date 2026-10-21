#!/bin/bash
# Quick checks without a full build (CI runs them on every pull request).
#   check.sh lint                     shellcheck, Python syntax, docs links
#   check.sh config <repo> <commit>   Buildroot check-package, defconfig sanity
#   check.sh patches                  U-Boot and Linux patches apply, shared DT files
#                                     identical, D200 DTB builds, linux.config up to date
set -e
ourpath="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
board="${ourpath}/board/ulanzi/d200"
cd "${ourpath}"

lint() {
    shellcheck -x -S warning scripts/*.sh board/ulanzi/d200/*.sh board/ulanzi/d200/rootfs-overlay/etc/init.d/* \
        package/d200-deck/S60deckd
    python3 - board/ulanzi/d200/*.py board/ulanzi/d200/logo/*.py <<'EOF'
import ast, sys
for f in sys.argv[1:]:
    ast.parse(open(f).read(), f)
EOF
    python3 scripts/check_doc_links.py README.md docs/*.md
}

config() {
    "${ourpath}/scripts/setup_builddir.sh" "$1" "$2" >/dev/null
    local br="${ourpath}/BuildEnv/buildroot"
    "${br}/utils/check-package" -b package/*/*
    for flavor in release debug; do
        local out
        out="$(mktemp -d)"
        make -s -C "${br}" O="${out}" BR2_EXTERNAL="${ourpath}" ulanzi_d200_defconfig >/dev/null
        local want=configs/ulanzi_d200_defconfig
        if [ "${flavor}" = debug ]; then
            "${br}/support/kconfig/merge_config.sh" -m -O "${out}" "${out}/.config" \
                "${board}/debug.fragment" >/dev/null
            make -s -C "${br}" O="${out}" BR2_EXTERNAL="${ourpath}" olddefconfig >/dev/null 2>&1
            want="${board}/debug.fragment"
        fi
        # every option we set must survive Kconfig (catches typos and options that moved)
        local missing
        missing="$(grep -E '^(BR2_|# BR2_.* is not set)' "${want}" | grep -vxF -f "${out}/.config" || true)"
        rm -rf "${out}"
        if [ -n "${missing}" ]; then
            echo "${flavor}: options not in the resulting .config:"
            echo "${missing}"
            exit 1
        fi
    done
    echo "config: ok"
}

patches() {
    local dl="${ourpath}/preserve/dl" work
    work="$(mktemp -d)"
    trap 'rm -rf "${work}"' EXIT
    local uver lver
    uver="$(basename "${board}"/patches/uboot/*)"
    lver="$(basename "${board}"/patches/linux/*)"
    mkdir -p "${dl}/uboot" "${dl}/linux"
    [ -f "${dl}/uboot/u-boot-${uver}.tar.bz2" ] ||
        wget -q -O "${dl}/uboot/u-boot-${uver}.tar.bz2" "https://ftp.denx.de/pub/u-boot/u-boot-${uver}.tar.bz2"
    [ -f "${dl}/linux/linux-${lver}.tar.xz" ] ||
        wget -q -O "${dl}/linux/linux-${lver}.tar.xz" \
            "https://cdn.kernel.org/pub/linux/kernel/v${lver%%.*}.x/linux-${lver}.tar.xz"
    local u="${work}/u-boot" k="${work}/linux" p
    mkdir "${u}" "${k}"
    tar -xf "${dl}/uboot/u-boot-${uver}.tar.bz2" -C "${u}" --strip-components=1
    tar -xf "${dl}/linux/linux-${lver}.tar.xz" -C "${k}" --strip-components=1
    for p in "${board}"/patches/uboot/"${uver}"/*.patch; do patch -s -p1 -N -E -t -d "${u}" < "${p}"; done
    for p in "${board}"/patches/linux/"${lver}"/*.patch; do patch -s -p1 -N -E -t -d "${k}" < "${p}"; done

    # U-Boot and Linux build the D200 from the same DT files
    local f
    for f in rk3308-ulanzi-d200.dts rk3308bs.dtsi; do
        cmp "${u}/dts/upstream/src/arm64/rockchip/${f}" "${k}/arch/arm64/boot/dts/rockchip/${f}"
    done

    local kmake=(make -s -C "${k}" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j"$(nproc)")
    cp "${board}/linux.config" "${k}/.config"
    "${kmake[@]}" olddefconfig
    "${kmake[@]}" savedefconfig
    diff -u "${board}/linux.config" "${k}/defconfig"
    "${kmake[@]}" rockchip/rk3308-ulanzi-d200.dtb
    echo "patches: ok (U-Boot ${uver}, Linux ${lver})"
}

case "$1" in
lint) lint ;;
config) config "$2" "$3" ;;
patches) patches ;;
*) echo "usage: $0 lint|config <repo> <commit>|patches" >&2; exit 1 ;;
esac
