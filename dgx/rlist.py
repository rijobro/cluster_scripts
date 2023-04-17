#!/usr/bin/env python3
"""Augmented runai list."""

import argparse
import json
import os
import re
import time
from datetime import datetime
from multiprocessing import Pool, cpu_count
from subprocess import run

import pandas as pd


class RList:
    """
    Wrapper around ``runai list``, printing extra info if desired.

    Args:
        extra: print extra info?
        path: path in job (same path for all jobs) with extra info saved as json file
        loop: if not ``None``, loop every x seconds
        drop: columns from the original output to drop.
    """

    def __init__(self, extras: bool, path: str, loop: int | None, drop: list[str] | None) -> None:
        self.extras = extras
        self.path = path
        self.loop = loop
        self.drop = drop

    @staticmethod
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

    @staticmethod
    def runai_list() -> pd.DataFrame:
        """Execute ``runai list`` and convert output to pandas DataFrame."""
        out = RList.run_cmd("runai list")
        # split at new lines, remove first and last lines
        rows = out.split("\n")[1:-1]
        # split columns anywhere there are two or multiple spaces
        data = [re.split(r"\s{2,}", r) for r in rows]
        return pd.DataFrame(data[1:], columns=data[0])

    def get_envs(self, job: str) -> dict:
        """Get run parameters for a single running job.

        Args:
            job: job to search.
        """
        res = RList.run_cmd(f"runai exec {job} cat {self.path}", check=False, stderr_ok=True)
        return json.loads(res) if len(res) > 0 else {}

    def get_envs_for_all_running_jobs(self, jobs) -> dict:
        """Get run parameters for all running jobs.

        Args:
            jobs: names of running jobs to search.
        """
        nproc = min(10, cpu_count(), len(jobs))
        with Pool(nproc) as p:
            results = p.map(self.get_envs, jobs)
            p.close()
            p.join()
        return dict(zip(jobs, results))

    def get_table(self) -> pd.DataFrame:
        """Run ``runai list``, and optionally search running jobs for extra environment variables to report."""
        df = self.runai_list()
        # drop some columns
        if self.drop is not None:
            df.drop(self.drop, axis=1, inplace=True)
        # rename others
        df.rename(columns={"GPUs Allocated (Requested)": "GPUs"}, inplace=True)

        if self.extras:
            running = df[df.STATUS == "Running"]
            res = self.get_envs_for_all_running_jobs(running.NAME)
            new_cols = [i for v in res.values() for i in v.keys()]
            df = df.assign(**{n: "" for n in new_cols})
            for job_name, v in res.items():
                for col_name, val in v.items():
                    df.loc[df.NAME == job_name, col_name] = val
        return df

    # @contextmanager
    def timed_loop(self):
        """Infinite loop performing a command. If elapsed time is less than ``self.loop`` then wait."""
        try:
            while True:
                t_start = time.time()
                yield
                t_end = time.time()
                t_elapsed = t_end - t_start
                t_wait = self.loop - t_elapsed
                if t_wait > 0:
                    time.sleep(t_wait)
        except KeyboardInterrupt:
            pass

    def print_info(self, clear: bool) -> None:
        """Print input arguments and table.

        Args:
            clear: should we clear screen before printing?
        """
        df = self.get_table()
        if clear:
            _ = os.system("cls" if os.name == "nt" else "clear")
        print("improved runai list.")
        print(f"    Extras   : {self.extras}.")
        print(f"    File     : {self.path}.")
        print(f"    Loop (s) : {self.loop}.")
        print(f"    Updated  : {datetime.now():%H:%M:%S%z %d/%m/%Y}\n")
        print(
            df.to_string(
                index=False,
            )
        )

    def run(self):
        """Main method."""
        # print once and end
        if self.loop is None:
            self.print_info(clear=False)
            return
        # infinite loop, catch keyboard interrupt.
        for _ in self.timed_loop():
            self.print_info(clear=True)


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


def to_list(v: str) -> list[str]:
    """Convert string to list of strings.

    Args:
        v: input string to be converted to list of strings.
    """
    return v.split(",")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("-e", "--extras", help="Get extra variables from jobs.", default=True, type=to_bool)
    parser.add_argument(
        "-p",
        "--path",
        help="Path to check in running jobs for extra variables.",
        default="/home/rbrown/.instavec_vars.json",
        type=str,
    )
    parser.add_argument("-l", "--loop", help="Loop every n seconds.", type=int)
    parser.add_argument(
        "-d",
        "--drop",
        help="Columns of ``runai list`` to drop",
        default="IMAGE,TYPE,PROJECT,USER,PODs Running (Pending),SERVICE URL(S)",
        type=to_list,
    )
    rlist = RList(**vars(parser.parse_args()))
    rlist.run()
