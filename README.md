# DGX scripts
DGX scripts, including startup bash scripts.

Create the docker image with `create_docker_im.sh --docker_push`.
Submit with `runai_submit.sh`.
Modify `runai_startup.sh` as necessary, this will be run once the runai job is created.

Typical submit command:

```bash
runai_submit.sh --extra_cmds "cd ~/Documents/Code\npython training.py --output_model model.pt" --job-name rb-train
```

I've personalised things to my needs but this may be a useful template for others.
