#!/usr/bin/env bash

set -e

# Restart script inside docker container.
if [ -z "$IN_DOCKER" ]; then
    docker run --rm -it \
        --env IN_DOCKER=1 \
        --volume $(realpath ..):/work \
        --workdir /work/test \
        --mac-address=00:ab:ab:ab:ab:ab \
        --entrypoint bash \
        ghcr.io/nikleberg/questasim:22.1 \
        -c "/work/test/run.sh"

    exit 0
fi

# Docker image contains QuestaSim in version v22.1. We require additional
# packages to run the full example.
apt-get update
apt-get install -y --no-install-recommends \
    git \
    gcc \
    libc-dev \
    openocd \
    gdb-multiarch

# Clone the NEORV32 softcore and roll-back to a specific stable commit.
if [ ! -d "./neorv32_src" ]; then
    git clone https://github.com/stnolting/neorv32 neorv32_src
    cd neorv32_src
    git reset --hard ec2e2bb
    cd ..
fi

# Copy default modelsim.ini file from the QuestaSim install directory.
vmap -c

# Create neorv32 and work libraries and link together.
vlib neorv32
vlib work
vmap neorv32 work

# Gather and compile NEORV32 design files.
NEORV32_LOCAL_RTL=./neorv32_src/rtl
FILE_LIST=`cat $NEORV32_LOCAL_RTL/file_list_soc.f`
CORE_SRCS="${FILE_LIST//NEORV32_RTL_PATH_PLACEHOLDER/"$NEORV32_LOCAL_RTL"}"
vcom -work neorv32 -autoorder $CORE_SRCS

# Compile our VHDL design files.
vcom ../fli_jtag.vhd ./tb.vhd

# Compile our C file into a shared library.
MTI_HOME=/opt/QuestaSim/22.1.2/questa_fse
gcc -shared -fPIC -o fli_jtag.so -I$MTI_HOME/include ../fli_jtag.c

# Run the simulation in the background and load library.
# -> The given function fli_jtag_init is called once on startup.
vsim -c tb -foreign "fli_jtag_init fli_jtag.so" -do "run -all" &

# Wait a bit to ensure simulation could boot and UNIX socket could be created.
sleep 2

# Run openocd in the background.
# -> If this errors out, see whats going wrong by adding debugging flag -d.
# -> If an invalid tap/device id is read: Try to increase DELAY generic in VHDL.
openocd -f openocd.cfg &

# Wait a bit longer to ensure openocd could examine hart and start gdb server.
sleep 10

# Run some debugging
gdb-multiarch --batch -x gdb.cfg

# Stop background openocd and GHDL simulation.
kill %2
sleep 1
kill %1
