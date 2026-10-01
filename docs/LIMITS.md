# Size, time and memory limits

Measured with `benchmark/limits.R` (each case in a fresh R process; peak resident
memory from `/usr/bin/time`) on an Apple Silicon Mac (arm64, 18 cores, R's reference
BLAS, one core used). Faster BLAS libraries (OpenBLAS, Accelerate, MKL) shorten the
dense cases several-fold.

| Case | Design | Time | Peak memory |
|---|---|---|---|
| 1,000 lines, 2,000 markers | 150 lines, robust CDmean | 1.3 s | 0.5 GB |
| 2,000 lines | 300 lines | 6.8 s | 1.0 GB |
| 5,000 lines | 500 lines | 53 s | 2.8 GB |
| 1,000 lines x 15 sites (15,000 units, factorised) | 1,500 plots, at most 3 sites per line | 2.5 min | 2.7 GB |
| 2,000 lines x 5 sites x 2 traits (20,000 units, factorised) | 1,500 plots, index, robust over 5 trait scenarios | 6.7 min | 5.6 GB |
| 20,000 lines, 3,000 markers (`tso_design_large()`) | 1,000 lines, rank 300 | 28 s | 5.8 GB |

## Rules of thumb

* **Dense designs** (`tso_design()` on line-level data): memory about
  $3 \times 8N^2$ bytes plus the contrasts ($8mN$ for $m$ targets); time grows roughly
  as $N^2 n$. Comfortable up to about 10,000 lines on a 16 GB machine.
* **Traits and environments**: dense up to 8,000 cells; above that the unit covariance
  is factorised automatically (`implicit = TRUE`), so memory is set by the line kernel
  ($8N^2$) and the search contrasts ($8m \cdot$ units, capped near 1 GB), not by
  (units)$^2$. Robust multi-trait designs keep one engine state per scenario (5 by
  default); `trait_uncertainty = "none"` divides that memory by five.
* **More than about 15,000 lines, one trait**: `tso_design_large()` works in marker space
  and never forms an $N \times N$ matrix (100,000 lines at rank 300 need about 1 GB for the
  features).
* **Haplotypes**: block strings are held as a character matrix (lines x blocks); for
  hundreds of thousands of markers use LD blocks or `window` tiles rather than
  single-marker blocks.
* **REML** (`tso_variance()`): dense, at most 6,000 records.
