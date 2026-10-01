# Do haplotypes help training-set design? A benchmark on real panels.
#
# Four public panels with marker positions (Fernandez-Gonzalez et al. 2023
# datasets: maize, rice, sorghum, switchgrass), their real phenotypes, random
# targets (25% of lines) and training sets of 15% of the candidates:
#   random        mean of 5 random sets
#   A             tso_design() default: robust CDmean on the SNP kernel
#   HAP           robust CDmean on the haplotype kernel (LD blocks, or 5-marker
#                 tiles with TSO_BENCH_HAP=fixed)
#   A+HAP         both kernels, robust shares
#   haplotype     the haplotype-coverage criterion (LD blocks)
# Every set is scored by the predictive ability (correlation of GBLUP
# predictions with phenotypes on the targets), with the SNP kernel and with
# the haplotype kernel as the prediction model, and by the share of the
# targets' haplotype copies present in the training set.
#
# Run from the repository folder:
#   Rscript benchmark/haplotypes_benchmark.R [reps]
# TSO_BENCH_DATA points to the datasets (default: Datasets).
suppressMessages(library(TSOpt))
args <- commandArgs(TRUE); reps <- if (length(args)) as.integer(args[1]) else 10
data_dir <- Sys.getenv("TSO_BENCH_DATA", "Datasets")
max_markers <- as.integer(Sys.getenv("TSO_BENCH_MARKERS", "20000"))
hap_method <- Sys.getenv("TSO_BENCH_HAP", "ld")          # "ld" or "fixed" (5-marker tiles)
tag <- if (hap_method == "ld") "" else paste0("_", hap_method)
panels <- c(Maize = "^Chr([0-9]+)_([0-9]+)$", Rice = "^S([0-9]+)_([0-9]+)$", Sorghum = "^X([0-9]+)_([0-9]+)$",
            Switchgrass = "^Chr([0-9]+[ab]?)_([0-9]+)_.*$")

as_geno <- function(e, pat) {
  G <- e$geno; ids <- as.character(e$pheno$GID); rownames(G) <- ids
  keep <- grepl(pat, colnames(G)); G <- G[, keep, drop = FALSE]
  chrom <- sub(pat, "\\1", colnames(G)); pos <- as.numeric(sub(pat, "\\2", colnames(G)))
  o <- order(chrom, pos, method = "radix"); G <- G[, o]; chrom <- chrom[o]; pos <- pos[o]
  if (ncol(G) > max_markers) { s <- round(seq(1, ncol(G), length.out = max_markers)); G <- G[, s]; chrom <- chrom[s]; pos <- pos[s] }
  # the files hold centred dosages (x - 2p); shift back to 0..2
  X <- sweep(G, 2, apply(G, 2, min, na.rm = TRUE)); X <- pmin(pmax(round(X), 0), 2)
  mk <- paste0(chrom, "_", pos); mk <- make.unique(mk); colnames(X) <- mk
  map <- data.frame(marker = mk, chrom = chrom, pos = pos, stringsAsFactors = FALSE)
  g <- TSOpt:::.new_geno(X, map = map, ploidy = 2, format = "benchmark", source = "benchmark")
  tso_qc(g, maf = 0.05, verbose = FALSE)
}

rows <- list(); blk <- list()
for (ds in names(panels)) {
  e <- new.env(); load(file.path(data_dir, paste0(ds, "_sorted.RData")), envir = e)
  g <- as_geno(e, panels[[ds]]); ids <- rownames(g$dosage); N <- length(ids)
  hp <- tso_haplotypes(g, method = hap_method)
  blk[[ds]] <- data.frame(panel = ds, lines = N, markers = ncol(g$dosage), blocks = length(hp$blocks),
                          median_markers = stats::median(hp$info$markers), mean_markers = mean(hp$info$markers),
                          median_haplotypes = stats::median(hp$info$haplotypes), kind = hp$kind)
  print(blk[[ds]])
  tpA <- tso_data(g, haplotypes = hp, verbose = FALSE)
  kk <- tso_kernels(g, which = c("A", "HAP"), haplotypes = hp)
  tpH <- tso_data(g, kernels = list(HAP = kk$K$HAP), haplotypes = hp, verbose = FALSE)
  tpK <- tso_data(g, kernels = kk, haplotypes = hp, verbose = FALSE)
  KA <- tpA$K; KH <- kk$K$HAP[ids, ids]
  uc <- tpA$hap_units
  traits <- setdiff(names(e$pheno), "GID")
  for (tr in traits) for (r in seq_len(reps)) {
    set.seed(1000 * r + match(tr, traits))
    y <- stats::setNames(e$pheno[[tr]], as.character(e$pheno$GID))[ids]
    if (all(is.na(y))) next
    T <- sort(sample(N, round(0.25 * N))); tgt <- ids[T]
    cand <- setdiff(seq_len(N), T); n <- round(0.15 * length(cand))
    sets <- list(
      A = tso_design(tpA, n = n, target = tgt, verbose = FALSE)$selected$id,
      HAP = tso_design(tpH, n = n, target = tgt, verbose = FALSE)$selected$id,
      `A+HAP` = tso_design(tpK, n = n, target = tgt, verbose = FALSE)$selected$id,
      haplotype = tso_design(tpA, n = n, target = tgt, criterion = "haplotype", verbose = FALSE)$selected$id)
    score <- function(S) {
      S <- match(S, ids); ok <- S[!is.na(y[S])]
      pa <- function(K) { p <- TSOpt:::.gblup(K, ok, y[ok])$pred; stats::cor(p[T], y[T], use = "complete.obs") }
      hc <- TSOpt:::.hap_coverage(uc, S, T)
      c(pa_A = pa(KA), pa_HAP = pa(KH), hap_cov = hc$frac_copies, hap_distinct = hc$frac, hap_two = hc$frac2)
    }
    res <- lapply(sets, score)
    res$random <- rowMeans(vapply(1:5, function(k) score(ids[sample(cand, n)]), numeric(5)))
    for (m in names(res)) rows[[length(rows) + 1]] <- data.frame(panel = ds, trait = tr, rep = r, method = m,
                                                                  t(res[[m]]), row.names = NULL)
  }
  cat(ds, "done\n")
}
out <- do.call(rbind, rows)
dir.create("benchmark/results", showWarnings = FALSE)
utils::write.csv(out, paste0("benchmark/results/haplotypes_benchmark", tag, ".csv"), row.names = FALSE)
utils::write.csv(do.call(rbind, blk), paste0("benchmark/results/haplotypes_blocks", tag, ".csv"), row.names = FALSE)
summ <- stats::aggregate(cbind(pa_A, pa_HAP, hap_cov, hap_distinct, hap_two) ~ method, out, mean)
print(summ, digits = 3)
w <- reshape(out, idvar = c("panel", "trait", "rep"), timevar = "method", direction = "wide")
cmp <- function(a, b, v) { d <- w[[paste0(v, ".", a)]] - w[[paste0(v, ".", b)]]
  sprintf("%-10s vs %-6s %-7s %+.4f (SE %.4f, t %.1f), better in %.0f%% of %d", a, b, v, mean(d), sd(d) / sqrt(length(d)),
          mean(d) / (sd(d) / sqrt(length(d))), 100 * mean(d > 0), length(d)) }
for (a in c("HAP", "A+HAP", "haplotype", "A")) for (v in c("pa_A", "pa_HAP", "hap_distinct", "hap_two"))
  cat(cmp(a, if (a == "A") "random" else "A", v), "\n")
print(stats::aggregate(cbind(pa_A, pa_HAP, hap_distinct) ~ method + panel, out, mean), digits = 3)
print(do.call(rbind, blk))
