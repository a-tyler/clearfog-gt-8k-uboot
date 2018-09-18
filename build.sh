#!/bin/sh
ROOT=$(pwd)
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export PATH=$PATH:${PWD}/toolchain/bin

export SCP_BL2=$ROOT/binaries/mrvl_scp_bl2_mss_ap_cp1_a8040.img
export MV_DDR_PATH=$ROOT/mv-ddr
export BL33=$ROOT/uboot/u-boot.bin

if [ ! -s toolchain/bin/${CROSS_COMPILE}gcc ]; then
	echo "Downloading Toolchain :"
	wget https://releases.linaro.org/components/toolchain/binaries/latest/aarch64-linux-gnu/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu.tar.xz -O toolchain.tar.xz && \
	tar xvf toolchain.tar.xz --strip 1 -C toolchain && \
	rm -f toolchain.tar.xz
fi

git submodule update --remote

for dir in patches/*; do
	REPO=$(basename "$dir")
	cd "$ROOT/$REPO"
	git reset -q --hard && git clean -q -d -f
	for patch in "$ROOT"/"$dir"/*; do
		patch -p1 < "$patch"
	done
	cd "$ROOT"
done

echo "Building u-boot :"
cd "$ROOT/uboot" && make mvebu_clearfog_gt_8k-88f8040_defconfig && make
[ $? != 0 ] && echo "Error building uboot" && exit 1

echo "Building ATF - MV_DDR_PATH at $MV_DDR_PATH, BL33 at $BL33"
cd "$ROOT/atf" && make USE_COHERENT_MEM=0 LOG_LEVEL=20 MV_DDR_PATH="$MV_DDR_PATH" PLAT=a80x0_cf_gt_8k all fip
[ $? != 0 ] && echo "Error building atf" && exit 1
cp "$ROOT/atf/build/a80x0_cf_gt_8k/release/flash-image.bin" "$ROOT/uboot.bin"
