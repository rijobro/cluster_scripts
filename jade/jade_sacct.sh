#!/bin/bash

set -e # exit on error

ndays=$1
: ${ndays:=3}
echo Printing jobs over last $ndays days
SLURM_TIME_FORMAT="%d/%m %H:%M:%S" sacct -S now-${ndays}days -X --format="jobid,jobname%40,partition,elapsed,timelimit,state,submit,start"

