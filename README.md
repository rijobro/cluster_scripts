# Cluster scripts

A set of scripts to help prepare, submit and run cluster jobs.

## DGX

Scripts to:

1. Create a Docker image (based on the nvidia pytorch container): `create_docker_im.sh`.
2. Submit a job: `runai_submit.sh`.
3. The script that is executed when the job runs: `runai_startup.sh`.

All of these have options, so use the `-h` argument for more info. If not, just run as-is for the defaults. 

Example:

Create the docker image: `create_docker_im.sh --docker_push`.
Submit with `runai_submit.sh`.
Modify `runai_startup.sh` as necessary, this will be run once the runai job is created.

Typical submit command:

```bash
runai_submit.sh --extra_cmds "cd ~/Documents/Code\npython training.py --output_model model.pt" --job-name rb-train
```

Without `--extra_cmds`, the default is `sleep infinity`, allowing you to connect to the job and do whatever you want.

I've personalised things to my needs but this may be a useful template for others.

## JADE

The main script here is `submit.sh`. Use the `-h` argument for more options.