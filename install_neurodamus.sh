#!/bin/bash

. /usr/share/modules/init/bash
module load mpi/openmpi

mkdir -p /opt/obi
cd /opt/obi

export LIBSONATA_TAG=master
export LIBSONATAREPORT_TAG=master
export NEURON_TAG=master
export NEURON_COMMIT_ID
export NEURODAMUS_TAG=3.10.0
export NEURODAMUS_COMMIT_ID
export WORKDIR=`pwd`
export INSTALL_DIR=$WORKDIR/install
export USR_VENV=$WORKDIR/venv
UV_INSTALL_DIR=$WORKDIR/uv

CMAKE_BUILD_TYPE=RelWithDebInfo
export LD_LIBRARY_PATH=$WORKDIR/install/lib:$LD_LIBRARY_PATH

set -ux

set -e
export DEBIAN_FRONTEND=noninteractive
echo "Install needed libs"
apt-get --yes update
apt-get --yes upgrade
apt-get --yes install \
                      g++ \
                      gcc \
                      python3.10 \
                      python3-pip \
                      python3-venv \
                      git \
                      cmake \
                      wget \
                      vim \
                      hdf5-tools \
                      flex libfl-dev bison ninja-build libreadline-dev
apt-get --yes -qq clean
rm -rf /var/lib/apt/lists/*export UV_CACHE_DIR=$WORKDIR/.cache-uv

export UV_LINK_MODE=symlink
if [[ ! -f $UV_INSTALL_DIR/uv ]]; then
	curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=$UV_INSTALL_DIR sh
fi
export PATH=$UV_INSTALL_DIR:$PATH

echo "Create venv and install some basic packages"
if [[ ! -d $USR_VENV ]]; then
	uv venv $USR_VENV
fi
source $USR_VENV/bin/activate
uv pip install -U pip setuptools
uv pip install -U cython pytest sympy jinja2 pyyaml numpy wheel pkgconfig morphio

mkdir -p hdf5
cd hdf5

if [[ ! -e hdf5-1.14.3.tar.gz ]]; then
	wget https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.14/hdf5-1.14.3/src/hdf5-1.14.3.tar.gz
fi

if [[ ! -e hdf5-1.14.3 ]]; then
	tar -xzf hdf5-1.14.3.tar.gz
fi

cd hdf5-1.14.3

CXX=mpic++ CC=mpicc cmake -B "build" -GNinja \
	-DCMAKE_BUILD_TYPE=$CMAKE_BUILD_TYPE \
	-DBUILD_STATIC_LIBS=OFF \
	-DHDF5_BUILD_UTILS=OFF \
	-DHDF5_BUILD_HL_LIB=ON \
	-DHDF5_BUILD_EXAMPLES=OFF \
	-DHDF5_ENABLE_PARALLEL=ON \
	-DBUILD_TESTING=OFF \
	-DHDF5_BUILD_TOOLS=OFF \
	-DHDF5_ENABLE_SZIP_ENCODING=OFF \
	-DHDF5_ENABLE_SZIP_SUPPORT=OFF \
	-DHDF5_ENABLE_Z_LIB_SUPPORT=OFF \
	-DCMAKE_INSTALL_PREFIX="$WORKDIR/install" \
	-S .

cmake --build "build" --parallel
cmake --install "build"

export PATH=$WORKDIR/install/bin:$PATH
export LD_LIBRARY_PATH=/lib:$LD_LIBRARY_PATH

echo "Install libsonata"
mkdir -p $WORKDIR
cd $WORKDIR
if [[ ! -d libsonata ]]; then
	git clone https://github.com/openbraininstitute/libsonata --recursive --depth 1 -b $LIBSONATA_TAG
fi
SONATA_BUILD_TYPE=$CMAKE_BUILD_TYPE CC=mpicc CXX=mpic++ uv pip install libsonata

echo "Install libsonatareport"
mkdir -p $WORKDIR
cd $WORKDIR
if [[ ! -d libsonatareport ]]; then
	git clone https://github.com/openbraininstitute/libsonatareport.git --recursive --depth 1 -b $LIBSONATAREPORT_TAG
fi
cmake -B libsonatareport/build -S libsonatareport -GNinja -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCMAKE_BUILD_TYPE=$CMAKE_BUILD_TYPE -DSONATA_REPORT_ENABLE_SUBMODULES=ON -DSONATA_REPORT_ENABLE_MPI=ON -DSONATA_REPORT_ENABLE_TEST=OFF
cmake --build libsonatareport/build --parallel
cmake --install libsonatareport/build
export SONATAREPORT_DIR="$INSTALL_DIR"

echo "Install neuron"
source $USR_VENV/bin/activate
cd $WORKDIR
set +u
if [[ ! -z $NEURON_COMMIT_ID ]]; then
   git clone https://github.com/neuronsimulator/nrn.git
   cd nrn
   git checkout $NEURON_COMMIT_ID
   cd ..
else
    git clone https://github.com/neuronsimulator/nrn.git --depth 1 -b $NEURON_TAG
fi

set -u

cmake -B nrn_build -S nrn \
	-DCMAKE_BUILD_TYPE=$CMAKE_BUILD_TYPE \
	-DPYTHON_EXECUTABLE=$(which python) \
	-DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
	-DNRN_ENABLE_MPI=ON \
	-DNRN_ENABLE_INTERVIEWS=OFF \
	-DNRN_ENABLE_RX3D=OFF \
	-DNRN_ENABLE_CORENEURON=ON \
	-DCMAKE_C_COMPILER=mpicc \
	-DCMAKE_CXX_COMPILER=mpic++ \
	-DCORENRN_ENABLE_REPORTING=ON \
	-DCMAKE_PREFIX_PATH=$SONATAREPORT_DIR
cmake --build nrn_build -- -j 2
cmake --install nrn_build

echo "Build mpi4py"
CC="mpicc" uv pip install mpi4py --no-binary=mpi4py

echo "Build h5py with the local hdf5"
CC="mpicc" HDF5_MPI="ON" HDF5_INCLUDEDIR=$WORKDIR/install/include/ HDF5_LIBDIR=$WORKDIR/install/lib/ \
    uv pip install --no-binary=h5py h5py --no-build-isolation

echo "Install neurodamus and prepare HOC_LIBRARY_PATH"
set +u
cd $WORKDIR
if [[ ! -e neurodamus ]]; then
    if [[ ! -z $NEURODAMUS_COMMIT_ID ]]; then
        git clone https://github.com/openbraininstitute/neurodamus.git
        cd neurodamus
        git checkout $NEURODAMUS_COMMIT_ID
        cd ..
    else
        git clone https://github.com/openbraininstitute/neurodamus.git --depth 1 -b $NEURODAMUS_TAG
    fi
fi
uv pip install -e neurodamus

export PATH="$INSTALL_DIR/bin:$USR_VENV/bin:$PATH"
export PYTHONPATH="$INSTALL_DIR/lib/python:$PYTHONPATH"
set -u

branch=main

NEOCORTEX_MOD=$WORKDIR/neurodamus-models/
NEOCORTEX_MOD_BUILD=$NEOCORTEX_MOD/build

if [[ ! -e $NEOCORTEX_MOD ]]; then
    git clone --branch="$branch" --depth=1 https://github.com/openbraininstitute/neurodamus-models.git $NEOCORTEX_MOD
fi

DATADIR=$(python -c "import neurodamus; from pathlib import Path; print(Path(neurodamus.__file__).parent / 'data')")

cmake -B $NEOCORTEX_MOD_BUILD -S $NEOCORTEX_MOD  \
	-DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
	-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON \
	-DCMAKE_PREFIX_PATH=$SONATAREPORT_DIR \
	-DNEURODAMUS_CORE_DIR=${DATADIR} \
	-DNEURODAMUS_MECHANISMS=neocortex \
	-DNEURODAMUS_NCX_V5=ON

cmake --build $NEOCORTEX_MOD_BUILD
cmake --install $NEOCORTEX_MOD_BUILD

export ARCH=$(uname -m)

cat << EOF > "$WORKDIR/env.sh"
#!/bin/bash

. /usr/share/modules/init/bash
module load mpi/openmpi
source $USR_VENV/bin/activate

export PATH=$UV_INSTALL_DIR:$INSTALL_DIR/$ARCH/bin:\$PATH
export CORENEURONLIB=$INSTALL_DIR/$ARCH/lib/libcorenrnmech.so
export PYTHONPATH=$INSTALL_DIR/lib/python:$PYTHONPATH
export NEURODAMUS_NEOCORTEX_ROOT=$INSTALL_DIR
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:\$LD_LIBRARY_PATH
export HOC_LIBRARY_PATH=$WORKDIR/neurodamus/neurodamus/data/hoc
EOF

cd $INSTALL_DIR
. $WORKDIR/env.sh
./$ARCH/bin/special -python -c "from neuron import h; h.quit()"
./$ARCH/bin/special -python -c "from neurodamus.core import NeuronWrapper as Nd; Nd.init(); exit()"
