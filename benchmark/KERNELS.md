# Non-additive genetic models in training-set design

`benchmark/kernels_benchmark.R` (30 replicates of 24 scenarios, 720 paired runs;
raw results in `benchmark/results/kernels_benchmark.csv`).

**Set-up.** Genetic values g = a + aa, with 30% or 50% of the genetic variance
additive x additive (a ~ N(0, A), aa ~ N(0, A#A)); h2 of 0.3 or 0.6; 40 or 80
training lines for 60 random targets; three panels: simulated with four
subpopulations, simulated continuum, and the shipped example panel. Targets are
predicted by GBLUP with the true model and variances. Methods: random (mean of 5
sets), the additive default of `tso_design()`, `tso_data(kernels = c("A", "AA"))`
with robust shares, and the same with `value = "breeding"`.

| Design | Accuracy, total value | Accuracy, breeding value |
|---|---|---|
| Random | 0.371 | 0.400 |
| Additive default | 0.427 | 0.448 |
| Kernels A + AA (robust shares) | 0.430 | 0.446 |
| Kernels, `value = "breeding"` | 0.430 | 0.451 |

* Kernels vs additive, total value: +0.0031 (SE 0.0021, t = 1.5), better in 53% of runs.
* `value = "breeding"` vs the total-value kernel design, breeding value: +0.0051
  (t = 2.0), better in 57% of runs.
* Optimisation vs random: +0.055 to +0.059.

**Conclusion.** The additive default is robust to epistasis; designing under the
epistatic model is not worse and at best slightly better. The default is therefore
unchanged. Kernels are for reporting reliability under the model the breeder
believes, for breeding-value targets (choosing parents), and, through the
single-step H, for candidates that are not genotyped yet.
