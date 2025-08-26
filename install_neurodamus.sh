#!/bin/bash

export LIBSONATA_TAG=master
export LIBSONATAREPORT_TAG=master
export NEURON_TAG=master
export NEURON_COMMIT_ID
export WORKDIR=/opt/software
export INSTALL_DIR=/opt/software/install
export USR_VENV=$WORKDIR/venv

set -ux

set -e

export DEBIAN_FRONTEND=noninteractive
echo "Install needed libs"
apt-get --yes update
apt-get --yes upgrade
apt-get --yes install \
                      g++ \
                      gcc \
                      python3.11 \
                      python3-pip \
                      python3-venv \
                      git \
                      cmake \
                      wget \
                      vim \
                      mpich libmpich-dev libhdf5-mpich-dev hdf5-tools \
                      flex libfl-dev bison ninja-build libreadline-dev
apt-get --yes -qq clean
rm -rf /var/lib/apt/lists/*

echo "Create venv and install some basic packages"
python3 -m venv $USR_VENV
source $USR_VENV/bin/activate
pip install -U pip setuptools
pip install -U cython pytest sympy jinja2 pyyaml numpy wheel pkgconfig morphio

echo "Install HDF5"
export HOME=/root
set -euo pipefail
export CC=$(which mpicc)
export CXX=$(which mpic++)
mkdir hdf5
cd hdf5
curl -O https://support.hdfgroup.org/releases/hdf5/v1_14/v1_14_6/downloads/hdf5-1.14.6.tar.gz
tar xf hdf5-1.14.6.tar.gz
cd hdf5-1.14.6
set +e
./configure --enable-parallel --enable-shared --prefix=/opt/software/hdf5/hdf5-1.14.6/install
if [ $? -ne 0 ]; then cat config.log; exit 1; fi
set -e
make -j
make install
cd ..
rm -rf hdf5*

export PATH=/opt/software/hdf5/hdf5-1.14.6/install/bin:$PATH
export LD_LIBRARY_PATH=/opt/software/hdf5/hdf5-1.14.6/install/lib:$LD_LIBRARY_PATH
cd /opt/circuit_simulation
python3.11 -m venv neurodamus_venv
pip install --upgrade pip
pip install --upgrade setuptools
pip install --upgrade cython jinja2 numpy pkgconfig pytest pyyaml sympy wheel

echo "Install libsonata"
cd /opt/software
pip install git+https://github.com/openbraininstitute/libsonata@master
git clone https://github.com/openbraininstitute/libsonatareport.git --recursive --depth 1 -b master
cmake -B libsonatareport/rep_build -S libsonatareport -DCMAKE_INSTALL_PREFIX=/opt/software/install -DCMAKE_BUILD_TYPE=Release -DSONATA_REPORT_ENABLE_SUBMODULES=ON -DSONATA_REPORT_ENABLE_MPI=ON
cmake --build libsonatareport/rep_build --parallel
cmake --install libsonatareport/rep_build
rm -rf libsonatareport
# CC=mpicc CXX=mpic++ pip install git+https://github.com/openbraininstitute/libsonata@$LIBSONATA_TAG

# echo "Install libsonatareport"
# mkdir -p $WORKDIR
# cd $WORKDIR
# git clone https://github.com/openbraininstitute/libsonatareport.git --recursive --depth 1 -b $LIBSONATAREPORT_TAG
# cmake -B rep_build -S libsonatareport -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCMAKE_BUILD_TYPE=Release -DSONATA_REPORT_ENABLE_SUBMODULES=ON -DSONATA_REPORT_ENABLE_MPI=ON ..
# cmake --build rep_build --parallel
# cmake --install rep_build
# rm -rf libsonatareport rep_build
export SONATAREPORT_DIR="$INSTALL_DIR"

echo "Install neuron"
cd /opt/software
git clone https://github.com/neuronsimulator/nrn.git nrn
cd nrn
git checkout c48d7d5
cd ..
cmake -B nrn/nrn_build -S nrn --debug-output -G Ninja -DPYTHON_EXECUTABLE=$(which python) -DCMAKE_INSTALL_PREFIX=/opt/software/install \
      -DNRN_ENABLE_MPI=ON -DNRN_ENABLE_INTERVIEWS=OFF -DNRN_ENABLE_RX3D=OFF -DNRN_ENABLE_CORENEURON=ON -DCMAKE_C_COMPILER=gcc \
      -DCMAKE_CXX_COMPILER=g++ -DCORENRN_ENABLE_REPORTING=ON -DCMAKE_PREFIX_PATH=$SONATAREPORT_DIR
cmake --build nrn/nrn_build --parallel
cmake --build nrn/nrn_build --target install
rm -rf nrn

echo "Build h5py"
pip install mpi4py
export HDF5_MPI="ON"
export HDF5_INCLUDEDIR=/opt/software/hdf5/hdf5-1.14.6/install/include
export HDF5_LIBDIR=/opt/software/hdf5/hdf5-1.14.6/install/lib
pip install --no-cache-dir --no-binary=h5py h5py --no-build-isolation

echo "Install neurodamus and prepare HOC_LIBRARY_PATH"
export PATH=${USR_VENV}/bin:$PATH
export PYTHONPATH=/opt/software/install/lib/python:$PYTHONPATH
git clone https://github.com/openbraininstitute/neurodamus.git
cd neurodamus
pip install .
cd -
git clone --branch=main https://github.com/openbraininstitute/neurodamus-models.git
export DATADIR=$(python -c "import neurodamus; from pathlib import Path; print(Path(neurodamus.__file__).parent / 'data')")
cmake -B neurodamus-models/build -S neurodamus-models -DCMAKE_INSTALL_PREFIX=/opt/software/install -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON -DCMAKE_PREFIX_PATH=${SONATAREPORT_DIR} -DNEURODAMUS_CORE_DIR=${DATADIR} -DNEURODAMUS_MECHANISMS=neocortex -DNEURODAMUS_NCX_V5=ON
cmake --build neurodamus-models/build
cmake --install neurodamus-models/build

echo "#!/bin/bash" > "$WORKDIR/env.sh"
echo "export PATH=$INSTALL_DIR/$ARCH:\$PATH" >> "$WORKDIR/env.sh"
echo "export CORENEURONLIB=$INSTALL_DIR/$ARCH/libcorenrnmech.so" >> "$WORKDIR/env.sh"

echo << EOF > ${WORKDIR}/env.sh
#!/bin/bash

# Set up the environment for Neurodamus dependencies
# HDF5
export HDF5_DIR=/usr/lib/x86_64-linux-gnu/hdf5/mpich
export LD_LIBRARY_PATH=\${HDF5_DIR}/lib:\$LD_LIBRARY_PATH

# Same install dir for all OBI repo packages
export OBI_APPS_DIR=/opt/software/install
export NRDMUS_VENV=/opt/software/venv

# LibSONATA & LibSONATA-report
export SONATA_DIR=\${OBI_APPS_DIR}
export SONATAREPORT_DIR=\${OBI_APPS_DIR}

# Neuron
export NRN_DIR=\${OBI_APPS_DIR}
export PATH=\${NRN_DIR}/bin:\$PATH

# Neurodamus (only for compilation)
export NEURODAMUS_MODS_DIR=/opt/software/neurodamus/neurodamus/data/mod

# Set up runtime variables needed for Neurodamus

# Note: DATADIR should be the output of the following command,
# but for some reason it points to the install directory and not the Neurodamus repo folder:
# python -c "import neurodamus; from pathlib import Path; print(Path(neurodamus.__file__).parent / 'data')"
# --> /home/ec2-user/circuit_simulation/neurodamus_venv/lib64/python3.11/site-packages/neurodamus/data
export DATADIR=/opt/software/neurodamus/neurodamus/data

export NEURODAMUS_NEOCORTEX_ROOT=\${OBI_APPS_DIR}

export PYTHONPATH=/opt/software/install/lib/python:\$PYTHONPATH
export HOC_LIBRARY_PATH=\${NEURODAMUS_NEOCORTEX_ROOT}/share/neurodamus_neocortex/hoc
export NEURODAMUS_PYTHON=/opt/software/venv/lib64/python3.10/site-packages/neurodamus/data/
export CORENEURONLIB=\${NEURODAMUS_NEOCORTEX_ROOT}/x86_64/libcorenrnmech.so
export NRNMECH_LIB_PATH=\${NEURODAMUS_NEOCORTEX_ROOT}/x86_64/libnrnmech.so
export PATH=\${NEURODAMUS_NEOCORTEX_ROOT}/bin:\$PATH

source \${NRDMUS_VENV}/bin/activate

export PATH=/opt/software/install/x86_64:\$PATH
EOF
