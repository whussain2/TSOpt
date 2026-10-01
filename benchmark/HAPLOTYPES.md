# Haplotypes in training-set design

`benchmark/haplotypes_benchmark.R`: four public panels with marker positions
(Fernandez-Gonzalez et al. 2023 datasets: maize, rice, sorghum, switchgrass;
up to 20,000 markers each, evenly thinned), their real phenotypes (all traits),
10 replicates of random targets (25% of the lines), training sets of 15% of the
candidates: 120 paired runs per block definition. Raw results:
`benchmark/results/haplotypes_benchmark.csv` (LD blocks) and
`haplotypes_benchmark_fixed.csv` (5-marker tiles; `TSO_BENCH_HAP=fixed`).

Designs: random (mean of 5 sets), the default robust CDmean on the SNP kernel
(A), robust CDmean on the haplotype kernel (HAP), both kernels with robust
shares (A+HAP), and the haplotype-coverage criterion. Predictive ability (PA)
is the correlation of GBLUP predictions (SNP kernel, REML) with the phenotypes
of the targets; haplotype coverage is the share of the targets' distinct
haplotypes present in training, and with at least two training carriers.

**Blocks.** LD blocks (mean r2 >= 0.3) are short on these thinned panels:
median 1 marker (maize 1.2, rice 2.7, sorghum 1.4, switchgrass 1.0 on
average), so the LD haplotype kernel is close to the SNP kernel there. Fixed
tiles have 5 markers and 11-36 haplotypes per block. Sorghum and switchgrass
are treated as unphased (heterozygous calls, some from mean imputation in the
source files).

| Design | PA, LD blocks | PA, 5-marker tiles | Distinct target haplotypes covered (tiles) | ... with >= 2 carriers (tiles) |
|---|---|---|---|---|
| Random | 0.398 | 0.398 | 60.7% | 43.6% |
| A (default) | 0.456 | 0.456 | 60.1% | 43.7% |
| HAP kernel | 0.457 | 0.450 | 60.1% | 43.5% |
| A + HAP | 0.457 | 0.454 | 60.1% | 43.6% |
| Haplotype criterion | 0.452 | 0.456 | 64.2% | 46.4% |

* HAP kernel vs A: PA +0.001 (LD, n.s.) and -0.006 (tiles, t = -1.8).
* Haplotype criterion vs A: PA -0.004 (LD) and 0.000 (tiles), not significant
  overall, but panel-dependent (tiles): maize +0.047 (t = 4.4), switchgrass
  +0.007, sorghum -0.019 (t = -2.1), rice -0.037 (t = -1.8). Coverage of the
  targets' distinct haplotypes +3.4 (LD) and +4.1 (tiles) points, with >= 2
  carriers +4.3 and +2.8 points, better in 100% of runs.
* Optimisation (A) vs random: PA +0.058 (t = 7.1).

**Conclusion.** Designing under a haplotype kernel does not predict better than
the SNP kernel, so the default is unchanged. The haplotype criterion does what
it is for, covering the targets' haplotypes and giving more of them a second
carrier, at no average cost in predictive ability, but with gains or losses of
up to 0.05 depending on the panel. Use it when haplotype representation is the
goal (genebank cores, reference panels, rare haplotypes that must be
learnable), or trade it off against CDmean with `tso_pareto()`.
