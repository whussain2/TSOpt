# Pre-specified protocol: TSOpt versus TrainSel

Written and fixed **before** any result of this comparison is seen. Deviations
must be reported as such.

## Who runs it

TrainSel's licence allows use by universities and non-profit organisations and
forbids use by for-profit organisations without the authors' written permission.
PlantNura is a company, so this comparison is to be run by an **academic partner**
(or by PlantNura only after written permission from TrainSel's authors). The
script `benchmark/trainsel_comparison.R` refuses to run unless TrainSel is
installed and the environment variable `TSO_TRAINSEL_LICENSED=yes` confirms that
the person running it is licensed.

## Question

On the same data, candidates, targets and training-set sizes, does the TSOpt default
(robust CDmean, greedy rank-one search) give training sets that predict at least as
well as TrainSel's default optimiser (genetic algorithm + simulated annealing on its
CDmean), and how long does each take?

## Data

The six public panels of Fernandez-Gonzalez et al. (2023) already used in
`benchmark/run_benchmark.R` (maize, rice PS, rice, sorghum, switchgrass, spruce), all
traits, genotypes and relationship matrices as distributed.

## Scenarios

* Untargeted: the whole panel is the target (one run per panel).
* Targeted: 5 random splits per panel (seeds 101-105), 25% of lines as targets that
  are never phenotyped; spruce 2 splits (run time).
* Training-set size n = 15% of the candidates.

## Arms

1. **TSOpt default**: `tso_design(tso_data(kinship = K), n, target)`, nothing else set.
2. **TrainSel default**: `TrainSel(Data = MakeTrainSelData(K = K), Candidates, setsizes = n,
   settypes = "UOS", Target = targets, control = SetControlDefault(size = <by panel size>))`,
   its built-in CDmean, default control settings for the panel size.
3. **TrainSel, long run**: as 2, with 10 times the default iterations (to separate the
   criterion from the search budget).
4. **Random**: mean of 20 random sets of the same size.

## Primary endpoint

Predictive ability (PA): the correlation between GBLUP predictions (REML heritability,
fixed intercept, the panel's relationship matrix) and phenotypes on the targets,
averaged over traits. The primary comparison is arm 1 minus arm 2, paired by scenario.

## Secondary endpoints

NDCG at 10%; exact CDmean at h2 = 0.5; wall-clock time on one core; arm 1 minus arm 3.

## Analysis

* Mean paired difference with a 95% confidence interval (t distribution) over the 33
  scenarios, and a two-sided sign test.
* Per-panel differences reported, whatever their direction.
* Non-inferiority of TSOpt is concluded if the lower 95% limit of arm 1 minus arm 2 is
  above -0.01; superiority if it is above 0.
* No scenario, trait or panel is excluded after results are seen.

## Reporting

All raw rows (`benchmark/results/trainsel_comparison.csv`), the exact versions of both
packages, the machine, and this protocol unchanged.
