{
    "type": "Microsoft.VirtualMachineImages/imageTemplates",
    "apiVersion": "2022-02-14",
    "location": "<region>",
    "dependsOn": [],
    "tags": {
        "imagebuilderTemplate": "ubuntu-hpc",
        "userIdentity": "enabled"
    },
    "identity": {
        "type": "UserAssigned",
        "userAssignedIdentities": {
            "<imgBuilderId>": {}
        }
    },
    "properties": {
        "buildTimeoutInMinutes": 100,
        "vmProfile": {
            "vmSize": "Standard_D2s_v3",
            "osDiskSizeGB": 127
        },
        "source": {
            "type": "PlatformImage",
            "publisher": "microsoft-dsvm",
            "offer": "ubuntu-hpc",
            "sku": "2204",
            "version": "22.04.2025051501"
        },
        "customize": [
            {
                "type": "Shell",
                "name": "InstallNeurodamus",
                "scriptUri": "https://raw.githubusercontent.com/openbraininstitute/azure-image-builder-tests/refs/heads/neurodamus/install_neurodamus.sh"
            }
        ],
        "distribute": [
            {
                "type": "ManagedImage",
                "imageId": "/subscriptions/<subscriptionID>/resourceGroups/<rgName>/providers/Microsoft.Compute/images/<imageName>",
                "location": "<region>",
                "runOutputName": "<runOutputName>",
                "artifactTags": {
                    "source": "azVmImageBuilder",
                    "baseosimg": "ubuntu-hpc"
                }
            }
        ]
    }
}
