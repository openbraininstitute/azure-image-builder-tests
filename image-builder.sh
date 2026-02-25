#!/bin/bash

# https://learn.microsoft.com/en-us/azure/virtual-machines/windows/image-builder

set -eu

# set variables
source ./vars.sh

EXISTING_RESOURCE_GROUPS=$(az group list | jq -r '.[].name')
if [[ "${EXISTING_RESOURCE_GROUPS}" == *"${RESOURCE_GROUP_NAME}"* ]]
then
    echo "Resource group ${RESOURCE_GROUP_NAME} already exists - skipping create"
else
    echo "Create resource group ${RESOURCE_GROUP_NAME}"
    az group create --name=${RESOURCE_GROUP_NAME} --location=${LOCATION} --tags "OBI_components=common"
fi

# create identity
EXISTING_IDENTITIES=$(az identity list | jq '.[].name')
if [[ "${EXISTING_IDENTITIES}" == *"${IDENTITY_NAME}"* ]]
then
    echo "Identity ${IDENTITY_NAME} already exists - skipping create"
else
    echo "Create managed identity"
    az identity create -g ${RESOURCE_GROUP_NAME} -n ${IDENTITY_NAME}
fi

# Get the identity ID
export image_builder_id=$(az identity show -g ${RESOURCE_GROUP_NAME} -n ${IDENTITY_NAME} --query clientId -o tsv)
echo "Image builder ID is ${image_builder_id}"

# Update the definition
cp image_creation_role.json.tpl image_creation_role.json
sed -i -e "s%<subscriptionID>%${SUBSCRIPTION_ID}%g" image_creation_role.json
sed -i -e "s%<rgName>%${RESOURCE_GROUP_NAME}%g" image_creation_role.json
sed -i -e "s%Azure Image Builder Service Image Creation Role%${IMAGE_ROLE_DEF_NAME}%g" image_creation_role.json

# Create role definitions
az role definition create --role-definition ./image_creation_role.json

sleep 5  # sigh

# Grant a role definition to the user-assigned identity
az role assignment create --assignee ${image_builder_id} --role "${IMAGE_ROLE_DEF_NAME}" --scope /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}

cp image_template.json.tpl image_template.json
sed -i -e "s%<subscriptionID>%${SUBSCRIPTION_ID}%g" image_template.json
sed -i -e "s%<rgName>%${RESOURCE_GROUP_NAME}%g" image_template.json
sed -i -e "s%<region>%${LOCATION}%g" image_template.json
sed -i -e "s%<imageName>%${IMAGE_NAME}%g" image_template.json
sed -i -e "s%<runOutputName>%${RUN_OUTPUT_NAME}%g" image_template.json
sed -i -e "s%<imgBuilderId>%${TEMPLATE_IMAGE_BUILDER_ID}%g" image_template.json

az resource create --resource-group ${RESOURCE_GROUP_NAME} --properties '@image_template.json' --is-full-object --resource-type Microsoft.VirtualMachineImages/imageTemplates --name erik-neurodamus

az image builder run --name ${IMAGE_NAME} --no-wait --subscription ${SUBSCRIPTION_ID} --resource-group ${RESOURCE_GROUP_NAME}

