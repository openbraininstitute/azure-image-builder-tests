#!/bin/bash

export RESOURCE_GROUP_NAME=
export LOCATION=
export SUBSCRIPTION_ID=$(az account show --query id --output tsv)
export IDENTITY_NAME=
export IMAGE_NAME=
export RUN_OUTPUT_NAME=
export GALLERY_NAME=
export NEURODAMUS_VERSION=3.8.1  # github: IMAGE_VERSION
export ACCOUNT_ID=
export IMAGE_ROLE_DEF_NAME=
# The user identity URI that's needed for the template
export TEMPLATE_IMAGE_BUILDER_ID=/subscriptions/${SUBSCRIPTION_ID}/resourcegroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${IDENTITY_NAME}
