#!/usr/bin/env python3
"""Augmented runai list."""

import argparse
import curses
import json
import re
import time
from contextlib import contextmanager
from datetime import datetime
from functools import partial
from multiprocessing import Pool, cpu_count
from subprocess import run

import pandas as pd


def run_cmd(cmd: str, check: bool = True, stderr_ok: bool = False) -> str:
    """Run command, check stderr is empty, return stdout.

    Args:
        cmd: bash command to run
        check: if ``True``, check the return code was 0.
        stderr_ok: is it okay that there is output in stderr?
    """
    x = run(cmd.split(), capture_output=True, check=check)
    stdout, stderr = x.stdout.decode("utf-8"), x.stderr.decode("utf-8")
    if not stderr_ok:
        assert stderr == "", f"Output in stderr: {stderr}"
    return stdout


def runai_list() -> pd.DataFrame:
    """Execute ``runai list`` and convert output to pandas DataFrame."""
    out = run_cmd("runai list")
    # split at new lines, remove first and last lines
    rows = out.split("\n")[1:-1]
    # split columns anywhere there are two or multiple spaces
    data = [re.split(r"\s{2,}", r) for r in rows]
    return pd.DataFrame(data[1:], columns=data[0])


def get_envs(job: str, file: str) -> pd.DataFrame:
    """Get run parameters for a single running job.

    Args:
        job: job to search
        file: file inside of running jobs to check for extra environment variables.
    """
    res = run_cmd(f"runai exec {job} cat {file}", check=False, stderr_ok=True)
    return json.loads(res) if len(res) > 0 else {}


def get_envs_for_all_running_jobs(jobs, file: str) -> None:
    """Get run parameters for all running jobs.

    Args:
        jobs: names of running jobs to search.
        file: file inside of running jobs to check for extra environment variables.
    """
    nproc = min(10, cpu_count(), len(jobs))
    with Pool(nproc) as p:
        results = p.map(partial(get_envs, file=file), jobs)
        p.close()
        p.join()
    return dict(zip(jobs, results))


def get_table(extras: bool, file: str) -> pd.DataFrame:
    """Run ``runai list``, and optionally search running jobs for extra environment variables to report.

    Args:
        extras: if ``True``, search running jobs for extra environment variables.
        file: file inside of running jobs to check for extra environment variables.
    """
    df = runai_list()
    # drop some columns
    df.drop(["IMAGE", "TYPE", "PROJECT", "USER", "PODs Running (Pending)"], axis=1, inplace=True)

    if extras:
        running = df[df.STATUS == "Running"]
        res = get_envs_for_all_running_jobs(running.NAME, file=file)
        new_cols = [i for v in res.values() for i in v.keys()]
        df = df.assign(**{n: "" for n in new_cols})
        for job_name, v in res.items():
            for col_name, val in v.items():
                df.loc[df.NAME == job_name, col_name] = val
    return df


@contextmanager
def timed_loop(nsec: int):
    """Perform a command and if the elapsed time is less than ``nsec``, wait until the total time elapsed is ``nsec``.

    Args:
        nsec: number of seconds complete loop should take.
    """
    t_start = time.time()
    yield
    t_end = time.time()
    elapsed = t_end - t_start
    t_wait = nsec - elapsed
    if t_wait > 0:
        time.sleep(t_wait)


@contextmanager
def curses_context():
    """Curses context. Initialise on entry, reset at end."""
    try:
        stdscr = curses.initscr()
        curses.noecho()
        curses.cbreak()
        yield stdscr
    finally:
        curses.echo()
        curses.nocbreak()
        curses.endwin()


def looping_table(extras: bool, file: str, loop: int) -> None:
    """Inifnite loop every ``loop`` seconds, updating the enhanced ``runai list`` output.

    Args:
        extras: if ``True``, search running jobs for extra environment variables.
        file: file inside of running jobs to check for extra environment variables.
        nsec: number of seconds complete loop should take.
    """
    with curses_context() as stdscr:
        while True:
            with timed_loop(loop):
                df = get_table(extras=extras, file=file)
                stdscr.addstr(0, 0, f"improved runai list. Last update: {datetime.now():%H:%M:%S%z %d/%m/%Y}")
                for i, l in enumerate(df.to_string(index=False).split("\n")):
                    stdscr.addstr(i + 1, 0, l)
                stdscr.refresh()


def main(extras: bool, file: str, loop=int | None) -> None:
    """Main loop.

    Args:
        extras: if ``True``, search running jobs for extra environment variables.
        file: file inside of running jobs to check for extra environment variables.
        nsec: number of seconds complete loop should take.
    """
    if loop is None:
        df = get_table(extras=extras, file=file)
        print(df)
    else:
        looping_table(extras, file, loop)


def to_bool(v: str) -> bool:
    """Convert string to bool.

    Args:
        v: input string to be converted to boolean.
    """
    if v.lower() in ("yes", "true", "t", "y", "1"):
        return True
    if v.lower() in ("no", "false", "f", "n", "0"):
        return False
    raise argparse.ArgumentTypeError("Boolean value expected.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("-e", "--extras", help="Get extra variables from jobs.", default=True, type=to_bool)
    parser.add_argument(
        "-f",
        "--file",
        help="Path to check in running jobs for extra variables.",
        default="/home/rbrown/.instavec_vars.json",
        type=str,
    )
    parser.add_argument("-l", "--loop", help="Loop every n seconds.", type=int)
    args = vars(parser.parse_args())
    col_width = max(len(i) for i in args.keys())
    print("\nRunning augmented runai list with following arguments:")
    for arg_name, arg_val in args.items():
        print(f"  {arg_name:<{col_width}} : {arg_val}")
    print()
    main(**args)
