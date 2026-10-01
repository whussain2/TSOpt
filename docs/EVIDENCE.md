# The evidence behind TSOpt's claims

Every claim made in the README, the guides and the tutorial, with its data, the effect
size, its uncertainty and the number of runs. "Real" means real genotypes and real
phenotypes; "simulated" means simulated genetic values (on simulated or real genotypes).
Scripts and raw results are in [`benchmark/`](../benchmark/).

## Prediction accuracy of training sets

The head-to-head rows come from the run with TSOpt 0.5.0 (33 scenarios on six panels, see
[benchmark/README.md](../benchmark/README.md)).

| Claim | Data | Effect (SE) | Runs | Source |
|---|---|---|---|---|
| The default (robust CDmean) predicts better than random | Real: 6 public panels (maize, 2 rice, sorghum, switchgrass, spruce), all traits | PA +0.066 ± 0.012 over random; beats random in 88% of scenarios | 33 scenarios | [benchmark/README.md](../benchmark/README.md) |
| ... at least as well as STPGA, about 4,000 times faster | same | +0.020 ± 0.010; wins 58% (sign test n.s.); 0.03 s vs 120 s | 33 pairs | same |
| ... at least as well as TSDFGS r-score, about 1,300 times faster | same | +0.024 ± 0.008; wins 64% (n.s.); 0.03 s vs 40 s | 33 pairs | same |
| ... and slightly better than a TrainSel-style GA + SA (our implementation, not TrainSel's code) | same | +0.006 ± 0.005; wins 70% | 33 pairs | same |
| Hedging over heritability beats one assumed h2 | same | +0.009 ± 0.006 over h2 = 0.5; wins 70%, sign test p = 0.04 | 33 pairs | same; probe of fixed h2 0.1-0.8 (earlier version) in `results/h2probe_*.csv` |
| "Most related to the target" is harmful | same | PA -0.114 vs random; beats random 27% | 33 scenarios | same |
| Forward in time: choosing this cycle's plots | Simulated programme histories (40 x 6 cycles, h2 0.3 and 0.6) | PA +0.009 over random (SE 0.003, t = 3.1); wins 61% | 200 cycle tests | `benchmark/forward_benchmark.R` |
| Forward in time: choosing the training set from history | same | PA +0.091 over random (SE 0.007, t = 13.4); wins 83% | 200 cycle tests | same |
| Forward in time: most related is harmful | same | within cycle PA -0.013 (t = -4.1) | 200 cycle tests | same |
| Protecting an introgressed major gene | Simulated gene on simulated panels | targeted accuracy 0.232 -> 0.872 (30/30 runs); untargeted 0.307 -> 0.694 (30/30) | 60 | `benchmark/major_genes_benchmark.R` |
| Modelling A x A epistasis in the design | Simulated genetic values (30-50% A x A) on 3 panels | PA +0.003 over the additive default (SE 0.002, n.s.) | 720 pairs | [KERNELS.md](../benchmark/KERNELS.md) |
| Designing for breeding values | same | breeding-value PA +0.005 (t = 2.0) | 720 pairs | same |
| Designing under a haplotype kernel | Real: 4 panels (maize, rice, sorghum, switchgrass) | PA -0.006 (tiles, t = -1.8) and +0.001 (LD blocks, n.s.) | 2 x 120 pairs | [HAPLOTYPES.md](../benchmark/HAPLOTYPES.md) |
| The haplotype criterion covers the targets' haplotypes | same | +3.4 to +4.1 percentage points of distinct target haplotypes, 100% of runs; PA 0.000 / -0.004 (n.s.), panel-dependent (maize +0.047, rice -0.037) | 2 x 120 pairs | same |
| Designing under an omics kernel | Simulated omics and phenotypes on simulated panels (500 lines, 100 plots + 100 historical) | vs the genomic design: robust shares +0.002 (SE 0.0015), estimated shares 0.000 (SE 0.002); none of 8 settings significant | 240 panels | [OMICS.md](../benchmark/OMICS.md) |
| Omics in the prediction model | same | +0.033 (features, t 2.9) and +0.052 (spectra, t 4.0) when half the signal runs through the profiles and every line is profiled; about +0.01 with half profiled; none at a 20% share | 240 panels | same |
| Whether profiling pays (`tso_omics_plan()`) | Simulated pilots of 200 lines, budget of 100 plots | profiling everyone best in 15 of 15 runs at a 50% omics share and a profile at 5% of a plot's cost; in 0 of 75 runs otherwise; partial profiling never best | 90 pilots | same |

## Exactness of the computations

Checked by the package's test suite (shipped with the source code, available on request,
see [REPRODUCIBILITY.md](REPRODUCIBILITY.md)) and by the base-R scripts in the package
(`system.file("by_hand", package = "TSOpt")`).

| Claim | Check | Result |
|---|---|---|
| The rank-one engine gives the exact CDmean | direct solve, and the base-R scripts | equal to rounding |
| Breeding-value and GCA targets are exact | direct formula after add, remove and exchange steps | equal to 1e-8 |
| Implicit (large) designs equal dense designs | same selection, CDmean, PEV, baseline, reliabilities | equal to 1e-10 |
| AI-REML reaches the REML maximum | brute-force optimiser on the same likelihood | 20 of 20 replicates within 7e-5 log-likelihood, including boundary optima |
| Progeny variance of a cross | 2,000-3,000 simulated doubled haploids per cross | predicted SD within 1-2% of empirical (correlation 0.999) |
| The haplotype kernel generalises VanRaden | single-marker blocks | equal to 1e-8 |
| Realised reliability under imputed relationships | equals CDmean when the relationships are true | equal to 1e-10 |
| Omics relationships of unprofiled lines | the single-step fill returns G exactly when the profiles are G; Savitzky-Golay derivative exact on quadratics; feature heritabilities equal one-at-a-time REML | equal to 1e-6, 1e-10, 0.01 |

## What is not yet shown

* **Forward validation on real multi-year data.** The forward results use simulated
  programme histories. `tso_backtest()` runs the same test on a programme's own data;
  results from real programmes are the next step.
* **Elite breeding populations.** The public panels are diversity panels; biparental
  and multi-parent breeding populations may behave differently.
* **An independent head-to-head with TrainSel's own code.** Its licence forbids use by
  for-profit organisations; the protocol for a comparison by an academic partner is in
  [benchmark/TRAINSEL_PROTOCOL.md](../benchmark/TRAINSEL_PROTOCOL.md).
* **Real omics data.** The omics results use simulated profiles.
* **Real multi-environment and multi-trait benchmarks.** These designs are exact under their
  model, but their realised gains have been shown on simulations only.
