# Cluster scripts

A set of scripts to help prepare, submit, run and monitor cluster jobs.

All scripts have options, so use the `-h|--help` argument for more info. If not, just run as-is for the defaults. 

## DGX

Scripts to:

1. Create a Docker image (based on the nvidia pytorch container): `create_docker_im.sh`.
2. Submit a job: `rubmit`.
3. The script that is executed when the job runs: `runai_startup.sh`.

Example:

- Create the docker image: `create_docker_im.sh --docker_push`.
- Submit with `rubmit`.
- Modify `runai_startup.sh` as necessary, this will be run once the runai job is created.

Typical submit command:

```bash
rubmit --job-name rb-train -- "cd <somewhere>\npython training.py --output_model model.pt"
```

## JADE

Scripts to:

1. Submit a job: `jubmit`.
2. View jobs (wraps `sacct`): `jlist`
3. View cluster-wide resource usage: `jtop`.

### jtop
<img width="1310" alt="image" src="https://user-images.githubusercontent.com/33289025/200618471-f3c6de7d-07ab-4fef-8f16-79217112d72f.png">

