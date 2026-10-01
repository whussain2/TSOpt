# Omics kernels in training-set design

`benchmark/omics_benchmark.R` (runtime about 2 minutes on 14 cores). Raw results:
`benchmark/results/omics_benchmark.csv`, `omics_plan_benchmark.csv`; summaries in
`*_summary.csv`.

**Why simulated.** We know of no public dataset that combines markers, omics profiles
and phenotypes of the same lines in a form we could redistribute with the package, so
the benchmark simulates them with `tso_simulate_omics()`:

* every feature is a heritable trait of the panel (heritability drawn uniformly
  between 0.1 and 0.7), with its own non-genetic part;
* half the features affect the phenotype;
* a share (0.2 or 0.5) of the phenotype's signal runs through the features, and the
  rest is direct genetic signal (heritability of the phenotype 0.5).

Profiles are either 300 transcript- or metabolite-like features, or near-infrared-like
spectra: 400 points, one absorption band per feature, plus light scatter, baseline
offsets and instrument noise, pre-treated by standard normal variate and a first
derivative. Every line is profiled, or a random half (the rest are predicted from
genomics by `tso_data()`).

**Part 1: design.** 30 panels of 500 lines per setting (8 settings, 240 panels).

* Each panel has 100 random targets and 100 lines phenotyped in an earlier trial. That
  history is known to every design and used by every prediction model.
* Of the other 300 candidates, 100 are chosen by four designs:
  * random (the mean of 5 sets);
  * the default design on the genomic kernel (A);
  * genomic plus omics kernels with robust shares (omics 10, 30 or 50%);
  * genomic plus omics kernels with shares estimated by REML on the history
    (`tso_variance(kernels = )`, then `tso_data(variance = )`).
* Accuracy is the correlation of the predictions with the targets' true signal. There
  are two prediction models: GBLUP on A, and GBLUP on (1 − w)A + wO, with the omics
  weight w chosen by REML.

| Omics share | Profiles | Profiled | Random | A design | A+O robust vs A | A+O estimated vs A | Omics in the prediction model (A design) |
|---|---|---|---|---|---|---|---|
| 0.2 | features | all | 0.576 | 0.599 | +0.007 (t 1.6) | +0.004 (0.6) | −0.004 (t −0.9) |
| 0.5 | features | all | 0.525 | 0.536 | +0.004 (0.7) | −0.005 (−0.7) | **+0.033 (t 2.9)** |
| 0.2 | spectra | all | 0.609 | 0.630 | +0.003 (0.5) | +0.002 (0.4) | +0.003 (0.6) |
| 0.5 | spectra | all | 0.568 | 0.579 | +0.011 (1.4) | +0.012 (1.5) | **+0.052 (t 4.0)** |
| 0.2 | features | half | 0.574 | 0.602 | +0.000 (0.0) | −0.001 (−0.1) | 0.000 (0.0) |
| 0.5 | features | half | 0.490 | 0.515 | −0.003 (−0.8) | −0.005 (−0.9) | +0.009 (1.8) |
| 0.2 | spectra | half | 0.591 | 0.610 | +0.004 (0.6) | +0.003 (0.5) | −0.003 (−1.9) |
| 0.5 | spectra | half | 0.496 | 0.526 | −0.002 (−0.2) | +0.006 (0.9) | +0.012 (3.0) |

The accuracy columns (random, A design, and the design differences) use the A+O
prediction model; the last column is the A+O model minus the A model, both on the A
design. Pooled over all settings, the omics-aware designs differ from the genomic
design by:

* robust shares: +0.002 (SE 0.0015) with the A model and +0.003 (SE 0.002) with the
  A+O model, winning 50 to 52% of the runs;
* estimated shares: 0.000 (SE 0.002) and +0.002 (SE 0.002).

The genomic design beats random by +0.022 (t 9).

**Part 2: does profiling pay?** `tso_omics_plan()` was run on 15 pilot panels of 200
lines per setting:

* budget = 100 plots;
* a profile costs 5%, 20% or 50% of a plot;
* profiling 25, 50 or 75% of the lines (best of three strategies) or every line, against
  no profiling;
* each plan is scored by its realised reliability under the true profiles.

| Omics share | Profile / plot cost | No profiling | Profile everyone | Best partial | Profiling best in |
|---|---|---|---|---|---|
| 0.2 | 5% | 0.309 | 0.300 | 0.304 | 0 of 15 |
| 0.5 | 5% | 0.209 | **0.235** | 0.217 | **15 of 15** |
| 0.2 | 20% | 0.309 | 0.247 | 0.294 | 0 of 15 |
| 0.5 | 20% | 0.209 | 0.186 | 0.198 | 0 of 15 |
| 0.2 | 50% | 0.309 | (over budget) | 0.270 | 0 of 15 |
| 0.5 | 50% | 0.209 | (over budget) | 0.180 | 0 of 15 |

**Conclusions.**

1. **Omics do not change which lines are worth phenotyping.** Designing under the
   genomic + omics model, whether with robust or estimated shares, gave the same
   accuracy as the genomic default (all differences within ±0.012, none
   significant). Epistatic and haplotype kernels behaved the same way
   (KERNELS.md, HAPLOTYPES.md). The default is unchanged. The omics-aware design is
   still the right choice when omics are part of the prediction model, because its
   reported reliabilities are then those of the model actually used, and it costs
   nothing.
2. **Omics help prediction when much of the signal runs through them and every line
   is profiled.** The gain was +0.03 to +0.05 at a 50% share; at 20% there was none.
   With half the lines profiled the gain shrank to about +0.01. Predicted profiles
   (fidelity about 0.6 to 0.7) cannot replace measured ones, because the value of a
   profile lies in its non-genetic part, which genomics cannot predict.
3. **Profiling pays only when it is cheap and the omics share is large.** Profiling
   everyone was the best plan in every run with a 50% share at 5% of a plot's cost
   (typical of near-infrared spectra of harvested grain), and in no other setting.
   Profiling part of the lines was never the best plan.

**Caveats.** These are simulations: in real data the omics share, the heritability of
the features and the transferability of profiles across environments and tissues
decide the value, so estimate the share from your own trials and run
`tso_omics_plan()` on a pilot before committing a budget. The spectra model is
stylised. Published gains from real omics over genomics alone are of the same modest
size (Riedelsheimer et al. 2012; Schrag et al. 2018; Rincent et al. 2018).
