#!/bin/bash

export LIBSONATA_TAG=master
export LIBSONATAREPORT_TAG=master
export NEURON_TAG=master
export NEURON_COMMIT_ID
export WORKDIR=/opt/software
export INSTALL_DIR=/opt/software/install
export USR_VENV=$WORKDIR/venv

set -ux

echo "Debugging"
ping -c 2 1.1.1.1

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
                      libhdf5-mpich-dev hdf5-tools \
                      flex libfl-dev bison ninja-build libreadline-dev \
                      environment-modules
apt-get --yes -qq clean
rm -rf /var/lib/apt/lists/*

echo "Create venv and install some basic packages"
python3 -m venv $USR_VENV
source $USR_VENV/bin/activate
pip install -U pip setuptools
pip install -U cython pytest sympy jinja2 pyyaml numpy wheel pkgconfig morphio

# export PATH=/opt/openmpi-5.0.7/bin

echo "Load openmpi module"
. /usr/share/modules/init/bash

module load mpi/openmpi-5.0.7
which mpicc
which mpic++
which mpirun

echo "Install libsonata"
CC=mpicc CXX=mpic++ pip install git+https://github.com/openbraininstitute/libsonata@$LIBSONATA_TAG

echo "Install libsonatareport"
mkdir -p $WORKDIR
cd $WORKDIR
git clone https://github.com/openbraininstitute/libsonatareport.git --recursive --depth 1 -b $LIBSONATAREPORT_TAG
cmake -B rep_build -S libsonatareport -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCMAKE_BUILD_TYPE=Release -DSONATA_REPORT_ENABLE_SUBMODULES=ON -DSONATA_REPORT_ENABLE_MPI=ON ..
cmake --build rep_build --parallel
cmake --install rep_build
rm -rf libsonatareport rep_build
export SONATAREPORT_DIR="$INSTALL_DIR"

echo "Install neuron"
source $USR_VENV/bin/activate
cd $WORKDIR
set +u
if [[ ! -z $NEURON_COMMIT_ID ]]
then
   git clone https://github.com/neuronsimulator/nrn.git
   cd nrn
    git checkout $NEURON_COMMIT_ID
    cd ..
else
    git clone https://github.com/neuronsimulator/nrn.git --depth 1 -b $NEURON_TAG
fi
set -u
cmake -B nrn_build -S nrn -DCMAKE_BUILD_TYPE=RelWithDebInfo -DPYTHON_EXECUTABLE=$(which python) -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DNRN_ENABLE_MPI=ON -DNRN_ENABLE_INTERVIEWS=OFF -DNRN_ENABLE_RX3D=OFF -DNRN_ENABLE_CORENEURON=ON -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -DCORENRN_ENABLE_REPORTING=ON -DCMAKE_PREFIX_PATH=$SONATAREPORT_DIR
cmake --build nrn_build -- -j 2
cmake --install nrn_build
rm -rf nrn nrn_build

echo "Build h5py with the local hdf5"
pip install mpi4py --no-binary=mpi4py
ARCH=$(uname -m) CC="mpicc" HDF5_MPI="ON" HDF5_INCLUDEDIR=/usr/include/hdf5/mpich HDF5_LIBDIR=/usr/lib/$ARCH-linux-gnu/hdf5/mpich \
    pip install --no-cache-dir --no-binary=h5py h5py --no-build-isolation

echo "Install neurodamus and prepare HOC_LIBRARY_PATH"
cd $WORKDIR
git clone https://github.com/openbraininstitute/neurodamus.git
cd neurodamus
pip install .

export HOC_LIBRARY_PATH="$WORKDIR/neurodamus/neurodamus/data/hoc"
export NEURODAMUS_PYTHON="$WORKDIR/neurodamus/neurodamus/data"
export NEURODAMUS_MODS_DIR="$WORKDIR/neurodamus/neurodamus/data/mod"
export PATH="$INSTALL_DIR/bin:$USR_VENV/bin:$PATH"
set +u
export PYTHONPATH="$INSTALL_DIR/lib/python:$PYTHONPATH"
set -u
export NEURODAMUS_DOCKER_DIR=$WORKDIR/neurodamus/docker

echo "Copy common bluebrain hoc and mod files from neurodamus-models, required for instantiating neurodamus"
wget -q https://raw.githubusercontent.com/openbraininstitute/neurodamus-models/refs/heads/main/common/hoc/AMPANMDAHelper.hoc -O $HOC_LIBRARY_PATH/AMPANMDAHelper.hoc
wget -q https://raw.githubusercontent.com/openbraininstitute/neurodamus-models/refs/heads/main/common/hoc/GABAABHelper.hoc -O $HOC_LIBRARY_PATH/GABAABHelper.hoc
wget -q https://raw.githubusercontent.com/openbraininstitute/neurodamus-models/refs/heads/main/common/mod/ProbAMPANMDA_EMS.mod -O $NEURODAMUS_MODS_DIR/ProbAMPANMDA_EMS.mod
wget -q https://raw.githubusercontent.com/openbraininstitute/neurodamus-models/refs/heads/main/common/mod/ProbGABAAB_EMS.mod -O $NEURODAMUS_MODS_DIR/ProbGABAAB_EMS.mod

echo "Copy neocortex mod files"
wget -q https://raw.githubusercontent.com/openbraininstitute/neurodamus-models/refs/heads/main/neocortex/mod/v6/CaDynamics_DC0.mod -O $NEURODAMUS_MODS_DIR/CaDynamics_DC0.mod
wget -q https://raw.githubusercontent.com/openbraininstitute/neurodamus-models/refs/heads/main/neocortex/mod/v6/Ca_HVA2.mod -O $NEURODAMUS_MODS_DIR/Ca_HVA2.mod
wget -q https://raw.githubusercontent.com/openbraininstitute/neurodamus-models/refs/heads/main/neocortex/mod/common/Ca_LVAst.mod -O $NEURODAMUS_MODS_DIR/Ca_LVAst.mod
wget -q https://raw.githubusercontent.com/openbraininstitute/neurodamus-models/refs/heads/main/neocortex/mod/common/Ih.mod -O $NEURODAMUS_MODS_DIR/Ih.mod
wget -q https://raw.githubusercontent.com/openbraininstitute/neurodamus-models/refs/heads/main/neocortex/mod/common/K_Pst.mod -O $NEURODAMUS_MODS_DIR/K_Pst.mod
wget -q https://raw.githubusercontent.com/openbraininstitute/neurodamus-models/refs/heads/main/neocortex/mod/common/K_Tst.mod -O $NEURODAMUS_MODS_DIR/K_Tst.mod
wget -q https://raw.githubusercontent.com/openbraininstitute/neurodamus-models/refs/heads/main/neocortex/mod/common/KdShu2007.mod -O $NEURODAMUS_MODS_DIR/KdShu2007.mod
wget -q https://raw.githubusercontent.com/openbraininstitute/neurodamus-models/refs/heads/main/neocortex/mod/v6/NaTg.mod -O $NEURODAMUS_MODS_DIR/NaTg.mod
wget -q https://raw.githubusercontent.com/openbraininstitute/neurodamus-models/refs/heads/main/neocortex/mod/common/Nap_Et2.mod -O $NEURODAMUS_MODS_DIR/Nap_Et2.mod
wget -q https://raw.githubusercontent.com/openbraininstitute/neurodamus-models/refs/heads/main/neocortex/mod/common/SK_E2.mod -O $NEURODAMUS_MODS_DIR/SK_E2.mod
wget -q https://raw.githubusercontent.com/openbraininstitute/neurodamus-models/refs/heads/main/neocortex/mod/common/SKv3_1.mod -O $NEURODAMUS_MODS_DIR/SKv3_1.mod
wget -q https://raw.githubusercontent.com/openbraininstitute/neurodamus-models/refs/heads/main/neocortex/mod/v6/StochKv3.mod -O $NEURODAMUS_MODS_DIR/StochKv3.mod
wget -q https://raw.githubusercontent.com/openbraininstitute/neurodamus-models/refs/heads/main/common/mod/TTXDynamicsSwitch.mod -O $NEURODAMUS_MODS_DIR/TTXDynamicsSwitch.mod
wget -q https://raw.githubusercontent.com/openbraininstitute/neurodamus-models/refs/heads/main/common/mod/ConductanceSource.mod -O $NEURODAMUS_MODS_DIR/ConductanceSource.mod

echo "Edit module building script and test build"
chmod +x $NEURODAMUS_DOCKER_DIR/build_neurodamus.sh
export ARCH=$(uname -m)
sed -i "s/ARCH=\"x86_64\"/ARCH=\"$ARCH\"/g" $NEURODAMUS_DOCKER_DIR/build_neurodamus.sh
cd $INSTALL_DIR
$NEURODAMUS_DOCKER_DIR/build_neurodamus.sh $NEURODAMUS_MODS_DIR
./$ARCH/special -python -c "from neuron import h; h.quit()"
./$ARCH/special -python -c "from neurodamus.core import NeuronWrapper as Nd; Nd.init(); exit()"
# rm -rf $ARCH/

echo << EOF > "${WORKDIR}/env.sh"
#!/bin/bash
export PATH=$INSTALL_DIR/$ARCH:\$PATH
export CORENEURONLIB=$INSTALL_DIR/$ARCH/libcorenrnmech.so
module load mpi/openmpi-5.0.7
EOF
