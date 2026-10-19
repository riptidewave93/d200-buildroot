# Sourced by the build scripts. Sets up Buildroot for flavour $1:
#   release (default): no SSH, no root shell, U-Boot console locked down
#   debug: release + SSH, a root shell on the UART and debug tools
# Each flavour has its own output dir: Buildroot never removes files from a
# target dir, so switching one dir from debug to release would keep debug bits.
ourpath="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
flavor="${1:-release}"
case "${flavor}" in
release|debug) ;;
*) echo "unknown flavour '${flavor}' (release or debug)" >&2; exit 1 ;;
esac

export BR2_DL_DIR="${ourpath}/preserve/dl"
export BR2_EXTERNAL="${ourpath}"
mkdir -p "${BR2_DL_DIR}"
brdir="${ourpath}/BuildEnv/buildroot"
brout="${ourpath}/BuildEnv/output-${flavor}"

br_make() { make -C "${brdir}" O="${brout}" "$@"; }

br_configure() {
    br_make ulanzi_d200_defconfig
    if [ "${flavor}" = debug ]; then
        "${brdir}/support/kconfig/merge_config.sh" -m -O "${brout}" \
            "${brout}/.config" "${ourpath}/board/ulanzi/d200/debug.fragment"
        br_make olddefconfig
    fi
}
