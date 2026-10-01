# Reproducibility and code availability

Everything needed to check TSOpt's published results is available, as follows.

| What | Where | Access |
|:--|:--|:--|
| **The TSOpt package** (binary) | [Releases](../../../releases) | Free for everyone, with a personal licence key ([how](LICENCE_KEY.md)) |
| **Benchmark scripts and their raw results** | [`benchmark/`](../benchmark/) | Public |
| **Documentation:** guides, tutorial, walkthrough, reference manual | [`docs/`](.) | Public |
| **Measured size, time and memory limits** | [LIMITS.md](LIMITS.md) | Public |
| **Every claim with its data, effect and number of runs** | [EVIDENCE.md](EVIDENCE.md) | Public |
| **Stability policy** (when defaults may change) | [STABILITY.md](STABILITY.md) | Public |
| **The analysis scripts of a paper** | Supplemental information of the paper, and this repository at publication | Public |
| **TSOpt's source code** | On request (below) | Qualified researchers, for research use |

## Reproducing the benchmark

The scripts in [`benchmark/`](../benchmark/) run on the released TSOpt binary (with a licence key) and the
published tools they are compared with (STPGA and TSDFGS from CRAN). Besides the exported functions, they call a
few of TSOpt's internal helpers (written `TSOpt:::name`), for example the GBLUP fit that scores each training set
in the same way for every method. Each script states, at its top, the data it needs and how to run it.

* **The six public panels** are the datasets compiled by Fernández-González et al. (2023, *Theor Appl Genet*
  136:30). Obtain them from the original publication; they are not redistributed here.
* **Raw results** for every run are in [`benchmark/results/`](../benchmark/results/), so the summaries and
  figures can be checked without rerunning anything.
* **Version.** The head-to-head benchmark was run with TSOpt 0.5.0, the released version. The method
  labelled "TSOpt default (v0.5.0)" is the package's default call, with no options changed. On Spruce that
  run is incomplete, so the published comparisons use the 30 complete scenarios on five panels
  ([details](../benchmark/README.md)). The other benchmarks name the version they were run with.

## Source code for verification

PlantNura makes TSOpt's source code available to **qualified researchers, for research use**, such as
reviewers and readers who need to verify published results. This follows journal policies on code
availability.

* **To request it,** email [waseemhussain@plantnura.com](mailto:waseemhussain@plantnura.com?subject=TSOpt%20source%20code%20for%20verification)
  with your name, affiliation and purpose.
* **Access is given under a short written agreement** that permits review and verification, but not
  redistribution.
* **Reviewers** of a manuscript about TSOpt also receive a licence key at once.

## What the published results use

The results in TSOpt's papers and benchmarks use TSOpt's **default criterion (robust CDmean)**, unless a
comparison of criteria is the point. The `gain` criterion (expected genetic gain of the selected fraction) is
marked **experimental** in the package, and none of the published results depend on it.
