# Stability of defaults across versions

Breeding programmes plan seasons with TSOpt, audit old plans, and compare designs
across years. The same inputs must therefore give the same plan unless a release
says otherwise.

## What is guaranteed

* **Same version, same inputs, same seed: the same plan**, on every platform.
  `tso_manifest(plan)` records the version, seed and MD5 fingerprints of the
  genotypes, relationships, units and settings; `tso_verify(plan, data)` checks
  a plan against the data you have.
* **Patch releases (0.5.x)** fix bugs only. A bug fix that changes a plan is
  listed in the [CHANGELOG](../CHANGELOG.md) under "Changes to results".
* **Minor releases (0.x.0)** may change defaults, but only with:
  * a benchmark showing why (in `benchmark/`), and
  * a [CHANGELOG](../CHANGELOG.md) entry under "Changes to defaults" with the old setting, so the old
    behaviour stays one argument away.

## Current defaults and the evidence behind them

| Default | Evidence |
|---|---|
| Robust CDmean (h2 = 0.2, 0.5, 0.8), greedy rank-one search | 5 public panels, 30 scenarios, TSOpt 0.5.0 ([benchmark/README.md](../benchmark/README.md)) |
| Additive kernel (kernels are opt-in) | 720 paired runs with 30-50% epistasis ([benchmark/KERNELS.md](../benchmark/KERNELS.md)) |
| SNP kernel, CDmean (haplotypes are opt-in) | 4 real panels, 120 paired runs ([benchmark/HAPLOTYPES.md](../benchmark/HAPLOTYPES.md)) |
| Stratification when the panel has discrete groups | [benchmark/README.md](../benchmark/README.md) |
| Environment and trait means opened with two units each | tests and the first-unit trap (CHANGELOG, 0.5.0) |

## Reproducing an old plan

Ask PlantNura for the binary package of the version recorded in the plan's manifest
(every release is tagged and kept); install it as in
[INSTALL.md](INSTALL.md), with that file in place of the current one.
