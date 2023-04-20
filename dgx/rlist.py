#!/usr/bin/env python3
"""Augmented runai list."""

import argparse
import json
import os
import re
import time
from datetime import datetime
from subprocess import run

import pandas as pd


class RList:
    """
    Wrapper around ``runai list``, printing extra info if desired.

    Args:
        path: path in job (same path for all jobs) with extra info saved as json file
        loop: if not ``None``, loop every x seconds
        drop: columns from the original output to drop.
    """

    def __init__(self, path: str, loop: int | None, drop: list[str] | None) -> None:
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
        # split header and data
        header_w_spaces, *data = rows
        # get all points in the header with 2 or more spaces (or to end of line for last column)
        pattern = r"(.+?)(\s{2,}|$)"
        matches = list(re.finditer(pattern, header_w_spaces))
        # get headers without spaces
        header = [m.group(1) for m in matches]
        # extract the indices of the start and end of the columns. set last to be end of line (-1)
        idxs = [[m.start(), m.end() - 1] for m in matches]
        idxs[-1][-1] = -1
        # extract the stringe that lie in this range for all rows. use " ".join() to
        # replace multiple spaces with single.
        out_data = [[" ".join(d[start:end].split()) for (start, end) in idxs] for d in data]
        return pd.DataFrame(out_data, columns=header)

    def get_envs_for_all_jobs(self, df: pd.DataFrame) -> dict:
        """Search locally for ~/.<job_name>.json to get run parameters. They should have already been copied across by
        ``get_envs_for_all_running_jobs``.

        Args:
            df: pandas data frame containing jobs.
        """
        out = {}
        for name in df.NAME:
            fname = os.path.expanduser(f"{self.path}/{name}.json")
            if os.path.isfile(fname):
                with open(fname, "r", encoding="utf-8") as file:
                    out[name] = json.load(file)
        return out

    def get_table(self) -> pd.DataFrame:
        """Run ``runai list``, and optionally search running jobs for extra environment variables to report."""
        df = self.runai_list()
        # drop some columns
        if self.drop is not None:
            df.drop(self.drop, axis=1, inplace=True)
        # rename others
        df.rename(columns={"GPUs Allocated (Requested)": "GPUs"}, inplace=True)

        # get extra info
        res = self.get_envs_for_all_jobs(df)
        new_cols = [i for v in res.values() for i in v.keys()]
        df = df.assign(**{n: "" for n in new_cols})
        for job_name, v in res.items():
            for col_name, val in v.items():
                df.loc[df.NAME == job_name, col_name] = val
        return df

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
        # Gracefully exit on keyboard interrupt
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
        print(f"    Path     : {self.path}.")
        print(f"    Loop (s) : {self.loop}.")
        print(f"    Updated  : {datetime.now():%H:%M:%S%z %d/%m/%Y}\n")
        print(df.to_markdown(index=False))

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
    parser.add_argument(
        "-p",
        "--path",
        help="Path to check for files containing run parameters. E.g., if path is ``~/progress``, then a job called "
        "``test`` will have info in ``~/progress/test.json``.",
        default="/nfs/home/rbrown/Documents/Code/InstaVec/.progress",
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
