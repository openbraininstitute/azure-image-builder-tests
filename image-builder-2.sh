#!/bin/bash

set -eux

source ./vars.sh
az account set -s ${ACCOUNT_ID}

IMAGE_BUILDER_IMAGE=$(az image builder list | jq -r '.[] | select(.name == "erik-neurodamus") | .id')

# az image create --name ${IMAGE_NAME}-image --resource-group ${RESOURCE_GROUP_NAME} --source ${IMAGE_BUILDER_IMAGE} --location ${LOCATION} --os-type Linux

EXISTING_GALLERIES=$(az sig list --resource-group ${RESOURCE_GROUP_NAME} | jq -r '.[].name')
if [[ "${EXISTING_GALLERIES}" == *"${GALLERY_NAME}"* ]]
then
    echo "Image gallery ${GALLERY_NAME} already exists - skipping creation"
else
    echo "Creating image gallery ${GALLERY_NAME}"
    az sig create  --gallery-name ${GALLERY_NAME} --resource-group  ${RESOURCE_GROUP_NAME} --location ${LOCATION}
fi

EXISTING_IMAGE_DEFINITIONS=$(az sig image-definition list --gallery-name ${GALLERY_NAME} --resource-group ${RESOURCE_GROUP_NAME} | jq '.[].name')
if [[ "${EXISTING_IMAGE_DEFINITIONS}" == *"\"${IMAGE_NAME}\""* ]]
then
    echo "Image definition ${IMAGE_NAME} already exists - skipping creation"
else
    echo "Creating image definition ${IMAGE_NAME}"
    az sig image-definition create --gallery-image-definition ${IMAGE_NAME} --gallery-name ${GALLERY_NAME} --offer neurodamus --os-type Linux --publisher openbraininstitute --resource-group ${RESOURCE_GROUP_NAME} --sku ${NEURODAMUS_VERSION} --architecture x64 --description "Ubuntu with the Neurodamus stack" --location ${LOCATION} --plan-name neurodamus --plan-product ${NEURODAMUS_VERSION} --plan-publisher openbraininstitute
    provisioningState=Provisioning
    while [[ "${provisioningState}" != "Succeeded" ]]
    do
        echo "Image definition state ${provisioningState} not ready yet... waiting"
        sleep 5
        provisioningState=$(az sig image-definition list --gallery-name erik_image_gallery --resource-group erik-custom-image-rg | jq -r ".[] | select(.name == \"${IMAGE_NAME}\") | .provisioningState")
    done
fi

az sig image-version create --gallery-image-definition ${IMAGE_NAME} --gallery-image-version ${NEURODAMUS_VERSION} --gallery-name ${GALLERY_NAME} --resource-group ${RESOURCE_GROUP_NAME} --location ${LOCATION} --managed-image ${IMAGE_NAME}
