#!/bin/bash

# set variables
export rg=erik-custom-image-rg
export location=EastUS2
export subscription=$(az account show --query id --output tsv)
export identity_name=erik-image-builder-id
export image_name=erik-neurodamus
export run_output_name=erik-run-output
echo $subscription

az group create --name=${rg} --location=${location}

# create identity
az identity create -g ${rg} -n ${identity_name}
# Get the identity ID
export image_builder_id=$(az identity show -g ${rg} -n ${erik-image-builder-id} --query clientId -o tsv)

# Get the user identity URI that's needed for the template
export image_builder_id=/subscriptions/${subscription}/resourcegroups/${rg}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${identity_name}

export image_role_def_name="Azure Image Builder Image Def"

# Update the definition
cp image_creation_role.json.tpl image_creation_role.json
sed -i -e "s/<subscriptionID>/${subscription}/g" image_creation_role.json
sed -i -e "s/<rgName>/${rg}/g" image_creation_role.json
sed -i -e "s/Azure Image Builder Service Image Creation Role/${image_role_def_name}/g" image_creation_role.json

# Create role definitions
az role definition create --role-definition ./image_creation_role.json

# Grant a role definition to the user-assigned identity
az role assignment create --assignee ${image_builder_id} --role "${image_role_def_name}" --scope /subscriptions/${subscription}/resourceGroups/${rg}

cp image_template.json.tpl image_template.json
sed -i -e "s/<subscriptionID>/${subscription}/g" image_template.json
sed -i -e "s/<rgName>/${rg}/g" image_template.json
sed -i -e "s/<region>/${location}/g" image_template.json
sed -i -e "s/<imageName>/${image_name}/g" image_template.json
sed -i -e "s/<runOutputName>/${run_output_name}/g" image_template.json
sed -i -e "s/<imgBuilderId>/${image_builder_id}/g" image_template.json

az resource create --resource-group ${rg} --properties '@image_template.json' --is-full-object --resource-type Microsoft.VirtualMachineImages/imageTemplates --name erik-neurodamus
