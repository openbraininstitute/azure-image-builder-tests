Files in this repo
==================

* `build.sh`: probably not used, older attempt at creating `build_neurodamus.sh`
* `image-builder-2.sh`: probably not used
* `image-builder.sh`: probably not used
* `image_creation_role.json.tpl`: role template to allow creation of images. Only used if the role doesn't exist yet
* `image_template.json.tpl`: defines how the image will be built, e.g. timeout, base image, customization steps, VM used during the build, ...
* `install_neurodamus.sh`: Bash script that actually installs Neurodamus. Downloaded as a customization step in `image_template.json.tpl`
* `vars.sh`: template file to get started with local builds; copy to vars_local.sh and fill in for your situation.
* `vars_local.sh`: not committed, but contains values for local builds
* `batch/cleanup.sh`: was used during manual testing to clean up batch tasks, jobs and pools
* `batch/create_batch_job.sh`: was used during manual testing to create a batch pool, resize it, create a job, and four tasks in the job
* `batch/simulation_config.json`: demo simulation config for manual batch testing
* `batch/simulation_task.json`: demo simulation task which uses simulation_config.json to run something on batch
* `batch/task.json`: another demo simulation task which uses simulation_config.json to run something on batch
* `batch/vars.sh`: template file to get started with local builds; copy to vars_local.sh and fill in for your situation.
* `batch/vars_local.sh`: not committed, but contains values for local builds

Recommendations:
* the whole `batch` folder was used to quickly run a few tasks on `batch` to test an image. If it's still useful for development it can stay.
* `image-builder-2.sh` and `image-builder.sh` should be removed - if a reference is needed for manually building an image, check the workflow under `.github` instead. These files might actually be some of the build steps extracted into bash scripts for easier local use - to be checked.

Copyright
=========

Copyright (c) 2025 Open Brain Institute

This work is licensed under `Apache 2.0 <https://www.apache.org/licenses/LICENSE-2.0.html>`_



Untracked (7)
? .gitignore
? batch/simulation_config.json
? batch/simulation_task.json
? batch/task.json
? batch/vars_local.sh
? build.sh
? vars_local.sh
