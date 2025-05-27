#!/usr/bin/env bash
set -eu

# Assumes you already have a batch account
# Set the variables in vars.sh to your desired values

source vars.sh

az batch account login --name=${BATCH_ACCOUNT_NAME} --resource-group ${RG_NAME}

POOLS=$(az batch pool list | jq -r ".[].id")
if [[ "${POOLS}" == *"${POOL_NAME}"* ]]
then
    echo "Pool already exists - skipping create"
else
    echo "Creating pool ${POOL_NAME}"
    az batch pool create --id ${POOL_NAME} --image ${IMAGE_ID} --node-agent-sku-id "batch.node.ubuntu 22.04" --target-dedicated-nodes=2 --vm-size Standard_D2S_v3
fi

allocationState="resizing"
while [[ "${allocationState}" != "steady" ]]
do
    echo "Pool status ${allocationState} is not steady - waiting"
    sleep 5
    allocationState=$(az batch pool show --pool-id=${POOL_NAME} --query "{allocationState: allocationState}" | jq -r ".allocationState")
done

JOBS=$(az batch job list | jq -r ".[].id")
if [[ "${JOBS}" == *"${JOB_NAME}"* ]]
then
    echo "Job already exists - skipping creatae"
else
    echo "Creating job ${JOB_NAME}"
    az batch job create --id ${JOB_NAME} --pool-id=${POOL_NAME}
fi

for x in {1..4}
do
    az batch task create --task-id ${TASK_NAME}${x} --job-id ${JOB_NAME} --command-line "/bin/bash -c '/opt/software/venv/bin/neurodamus --version'"
done
