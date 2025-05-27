source vars.sh

set -eux

az batch account login --name=${BATCH_ACCOUNT_NAME} --resource-group ${RG_NAME}

for x in {1..4}
do
    az batch task delete -y --job-id ${JOB_NAME} --task-id ${TASK_NAME}${x}
done
az batch job delete -y --job-id ${JOB_NAME}
az batch pool delete -y --pool-id ${POOL_NAME}
