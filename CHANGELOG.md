# Changelog

## TSOpt 0.5.0 (30 September 2026)

The first public release.

* **Exact, robust training-set design.** Exact CDmean with any fixed effects. The design is averaged over the
  uncertain heritability, or over REML estimates from your own trials (`tso_variance()`).
* **Every breeding system.** Inbred lines, hybrids among two or more heterotic groups, testcrosses, clones and
  polyploids, genebanks. Several traits and sites, with sparse testing in factorised form for large networks.
* **Major genes and haplotypes.** Scan or import marker effects (`tso_major_scan()`, `tso_major_effects()`);
  allele-carrier protection; haplotype blocks, the haplotype kernel and coverage.
* **Genetic models.** Dominance, epistasis, Gaussian, pedigree, single-step, haplotype and omics kernels
  (transcriptome, metabolome, spectra), with lines without a profile predicted from genomics.
* **Programme decisions.**
  * Forward validation on your own history (`tso_backtest()`).
  * Sample size and economics.
  * Season planning across stages (`tso_season()`).
  * Cross prediction (`tso_crosses()`).
  * Genotyping, imputation and omics-profiling budgets.
  * Field layouts.
* **From plan to field.** Field Book, FielDHub and Breedbase exports, BrAPI read and write-back, versioned plan
  files with an input manifest, matching analysis scripts, and the `tsopt` command-line tool.
* **Files from any locale.** Separators, decimal commas, encodings and Excel files are read automatically;
  exports open correctly in Excel everywhere.
* **Documentation.** Five step-by-step guides, a 127-page tutorial, a walkthrough with 184 automatic checks on
  your own data, and a reference manual, all shipped with the package (`tso_docs()`).
* **Free for everyone,** with a personal licence key checked offline.
