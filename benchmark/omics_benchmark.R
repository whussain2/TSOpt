# Do omics kernels help training-set design? A simulation benchmark.
#
# No public dataset combines markers, omics profiles and phenotypes for the
# same lines in a form we could redistribute, so this benchmark simulates
# them (tso_simulate_omics()): every feature is a heritable trait of the
# panel (h2 0.1-0.7) with its own non-genetic part, half the features affect
# the phenotype, and a share of the phenotype's signal runs through them.
# Settings:
#   share     0.2 or 0.5 of the signal through the profiles
#   profiles  "features" (300 transcript/metabolite-like features) or
#             "spectra" (400-point curves, one absorption band per feature,
#             with light scatter, baseline offsets and noise; SNV + first
#             derivative)
#   coverage  "all" lines profiled, or "half" (a random 50%; the rest are
#             filled from genomics by tso_data())
# Panels of 500 lines (h2 0.5): 100 random targets, 100 lines phenotyped in an
# earlier trial (the "history", known to every design), 300 candidates, of
# which 100 are chosen:
#   random        mean of 5 random sets
#   A             tso_design() default on the genomic kernel
#   A+O robust    genomic + omics kernels, omics share averaged over 10/30/50%
#   A+O estimated genomic + omics kernels, shares estimated by REML on the
#                 history (tso_variance(kernels = ), then tso_data(variance = ))
# Every set is scored by the accuracy of its predictions of the targets' true
# signal (direct genetic + omics), with two prediction models fitted on the
# phenotypes of the set and the history: GBLUP on A, and GBLUP on
# (1 - w) A + w O with the omics weight w chosen by REML on a grid
# (0, 0.25, ..., 1).
#
#   Rscript benchmark/omics_benchmark.R [reps]
suppressMessages(library(TSOpt))
args <- commandArgs(TRUE); reps <- if (length(args)) as.integer(args[1]) else 30
cores <- as.integer(Sys.getenv("TSO_BENCH_CORES", "8"))

grid <- expand.grid(rep = seq_len(reps), share = c(0.2, 0.5), profiles = c("features", "spectra"),
                    coverage = c("all", "half"), stringsAsFactors = FALSE)

# REML log-likelihood of y = mu + g + e, g ~ K, at its best h2 (eigen form)
reml_fit <- function(K, y) {
  ev <- eigen(K, symmetric = TRUE); U <- ev$vectors; d <- pmax(ev$values, 0)
  yu <- as.vector(crossprod(U, y)); xu <- colSums(U); n <- length(y)
  nll <- function(ld) { w <- 1 / (d + exp(ld)); sw <- sum(w * xu^2); b <- sum(w * xu * yu) / sw
    r <- yu - xu * b; s2 <- sum(w * r^2) / (n - 1)
    0.5 * (sum(log(d + exp(ld))) + (n - 1) * log(s2) + log(sw)) }
  o <- stats::optimize(nll, c(log(1 / 0.98 - 1), log(1 / 0.02 - 1)))
  list(nll = o$objective, delta = exp(o$minimum))
}
predict_gblup <- function(K, tr, y, te) {
  f <- TSOpt:::.gblup_fixed(K, tr, y[tr], matrix(1, length(tr), 1))
  as.vector(K[te, tr] %*% f$alpha)
}
acc_A <- function(A, O, tr, y, te, truth) stats::cor(predict_gblup(A, tr, y, te), truth[te])
acc_AO <- function(A, O, tr, y, te, truth) {
  ws <- seq(0, 1, by = 0.25)
  nl <- vapply(ws, function(w) reml_fit(((1 - w) * A + w * O)[tr, tr], y[tr])$nll, 1)
  w <- ws[which.min(nl)]
  stats::cor(predict_gblup((1 - w) * A + w * O, tr, y, te), truth[te])
}

one <- function(i) {
  s <- grid[i, ]; seed <- 1000 * s$rep + 7
  panel <- tso_simulate_panel(n = 500, markers = 1500, seed = seed)
  om <- tso_simulate_omics(panel, features = if (s$profiles == "features") 300 else 60, omics_share = s$share, h2 = 0.5,
                           causal = 0.5, type = if (s$profiles == "features") "other" else "spectra", seed = seed + 1)
  ids <- rownames(om$profiles); set.seed(seed + 2)
  prof <- if (s$coverage == "all") ids else sample(ids, 250)
  ok <- tso_omics_kernel(om$profiles[prof, , drop = FALSE], type = if (s$profiles == "features") "other" else "spectra")
  dA <- tso_data(panel, verbose = FALSE)
  dO <- tso_data(panel, kernels = ok, verbose = FALSE)
  lines <- rownames(dO$K)
  A <- dO$kernels$K$A; O <- dO$kernels$K[[ok$name]]
  tgt <- sample(lines, 100); hist <- sample(setdiff(lines, tgt), 100); cand <- setdiff(lines, c(tgt, hist))
  y <- stats::setNames(om$pheno$y, om$pheno$id)[lines]
  truth <- stats::setNames(om$truth$total, om$truth$id)[lines]
  vfit <- tso_variance(dO, data.frame(id = hist, y = y[hist]), kernels = ok, draws = 5)
  dE <- tso_data(panel, kernels = ok, variance = vfit, verbose = FALSE)
  n <- 100
  des <- function(d) setdiff(tso_design(d, n = n, target = tgt, candidates = cand, history = hist, n_random = 0,
                                        verbose = FALSE)$selected$id, hist)
  sets <- list(A = des(dA), `A+O robust` = des(dO), `A+O estimated` = des(dE))
  rnd <- lapply(1:5, function(r) sample(cand, n))
  te <- match(tgt, lines)
  score <- function(sel) { tr <- match(c(hist, sel), lines)
    c(pa_A = acc_A(A, O, tr, y, te, truth), pa_AO = acc_AO(A, O, tr, y, te, truth)) }
  res <- rbind(do.call(rbind, lapply(sets, score)), random = colMeans(do.call(rbind, lapply(rnd, score))))
  data.frame(s[rep(1, nrow(res)), ], method = rownames(res), pa_A = res[, "pa_A"], pa_AO = res[, "pa_AO"],
             share_est = unname(vfit$share[ok$name]), stringsAsFactors = FALSE, row.names = NULL)
}

t0 <- Sys.time()
res <- parallel::mclapply(seq_len(nrow(grid)), function(i) tryCatch(one(i), error = function(e) { message(i, ": ", conditionMessage(e)); NULL }),
                          mc.cores = cores)
res <- do.call(rbind, res)
dir.create("benchmark/results", showWarnings = FALSE)
utils::write.csv(res, "benchmark/results/omics_benchmark.csv", row.names = FALSE)
cat("Done in", format(round(difftime(Sys.time(), t0, units = "mins"), 1)), "-", nrow(res), "rows\n")

# ---- summary: accuracy by method, paired differences with the genomic design --------------
summ <- do.call(rbind, lapply(split(res, list(res$share, res$profiles, res$coverage), drop = TRUE), function(d) {
  w <- function(m, col) stats::setNames(d[[col]][d$method == m], d$rep[d$method == m])
  do.call(rbind, lapply(c("pa_A", "pa_AO"), function(col) {
    a <- w("A", col); r <- w("random", col)[names(a)]
    ro <- w("A+O robust", col)[names(a)]; es <- w("A+O estimated", col)[names(a)]
    tt <- function(x) mean(x) / (stats::sd(x) / sqrt(length(x)))
    data.frame(share = d$share[1], profiles = d$profiles[1], coverage = d$coverage[1],
               model = if (col == "pa_A") "GBLUP A" else "GBLUP A+O", random = mean(r), A = mean(a),
               robust_vs_A = mean(ro - a), t_robust = tt(ro - a), estimated_vs_A = mean(es - a), t_estimated = tt(es - a),
               A_vs_random = mean(a - r), share_est = mean(d$share_est[d$method == "A"]), reps = length(a))
  }))
}))
rownames(summ) <- NULL
print(format(summ, digits = 3))
utils::write.csv(summ, "benchmark/results/omics_benchmark_summary.csv", row.names = FALSE)

# ---- part 2: does profiling pay? tso_omics_plan() at three cost ratios ---------------------
# Pilot panels of 200 lines, all profiled; budget = 100 plots; a profile costs
# 5%, 20% or 50% of a plot; profile 25/50/75% of the lines (best strategy) or
# everyone, against no profiling. Realised reliability under the true profiles.
pgrid <- expand.grid(rep = seq_len(min(reps, 15)), share = c(0.2, 0.5), ratio = c(0.05, 0.2, 0.5), stringsAsFactors = FALSE)
pone <- function(i) {
  s <- pgrid[i, ]; seed <- 5000 + 1000 * s$rep
  panel <- tso_simulate_panel(n = 200, markers = 1000, seed = seed)
  om <- tso_simulate_omics(panel, features = 300, omics_share = s$share, causal = 0.5, seed = seed + 1)
  ok <- tso_omics_kernel(om$profiles, type = "other")
  op <- tso_omics_plan(panel, ok, budget = 100 * 40, profile_cost = 40 * s$ratio, plot_cost = 40, share = s$share,
                       strategy = c("coverage", "phenotyped", "targets"))
  t <- op$table; none <- t$realised[t$strategy == "none"]
  part <- t[!t$strategy %in% c("none", "all"), ]
  data.frame(s, none = none, all = if (any(t$strategy == "all")) t$realised[t$strategy == "all"] else NA_real_,
             best_partial = max(part$realised), best_partial_plan = part$plan[which.max(part$realised)],
             best = t$plan[1], stringsAsFactors = FALSE)
}
pres <- do.call(rbind, parallel::mclapply(seq_len(nrow(pgrid)), pone, mc.cores = cores))
utils::write.csv(pres, "benchmark/results/omics_plan_benchmark.csv", row.names = FALSE)
psum <- do.call(rbind, lapply(split(pres, list(pres$share, pres$ratio)), function(d)
  data.frame(share = d$share[1], ratio = d$ratio[1], none = mean(d$none), all = mean(d$all), best_partial = mean(d$best_partial),
             all_vs_none = mean(d$all - d$none), partial_vs_none = mean(d$best_partial - d$none),
             profiling_wins = mean(!grepl("^no profiling", d$best)), reps = nrow(d))))
rownames(psum) <- NULL
print(format(psum, digits = 3))
utils::write.csv(psum, "benchmark/results/omics_plan_benchmark_summary.csv", row.names = FALSE)
