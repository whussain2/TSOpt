# Does designing for a non-additive genetic model pay off?
#
# Genetic values are simulated with additive and additive x additive parts,
#   g = a + aa,  a ~ N(0, s_A A),  aa ~ N(0, s_AA A#A),  y = g + e (h2 on g),
# on structured simulated panels and on the shipped example panel. Training
# sets of n lines are chosen for 60 target lines by
#   random            the mean of 5 random sets
#   additive          tso_design() default (robust CDmean, additive kernel)
#   kernels           tso_design() on tso_data(kernels = c("A", "AA")), robust shares
#   kernels_breeding  the same, value = "breeding"
# and the targets are predicted by GBLUP with the true model (known
# variances). Reported: accuracy for total genetic values cor(g_hat, g) and
# for breeding values cor(a_hat, a) on the targets.
#
# Run from the repository folder:  Rscript benchmark/kernels_benchmark.R [reps]
suppressMessages(library(TSOpt))
args <- commandArgs(TRUE); reps <- if (length(args)) as.integer(args[1]) else 30
panels <- list(
  sim_structured = function(s) tso_simulate_panel(n = 300, markers = 1500, groups = 4, fst = 0.15, seed = s),
  sim_continuum = function(s) tso_simulate_panel(n = 300, markers = 1500, groups = 1, seed = s),
  example_panel = function(s) tso_qc(tso_read(system.file("extdata", "example_panel.vcf.gz", package = "TSOpt"),
                                                verbose = FALSE), verbose = FALSE))
scen <- expand.grid(panel = names(panels), s_AA = c(0.3, 0.5), h2 = c(0.3, 0.6), n = c(40, 80), stringsAsFactors = FALSE)
predict_acc <- function(Kt, Ka, S, Tg, y, lam, g, a) {
  V <- Kt[S, S] + diag(lam, length(S)); w <- solve(V, y[S] - mean(y[S]))
  c(total = stats::cor(as.vector(Kt[Tg, S] %*% w), g[Tg]), breeding = stats::cor(as.vector(Ka[Tg, S] %*% w), a[Tg]))
}
rows <- list()
for (i in seq_len(nrow(scen))) for (r in seq_len(reps)) {
  sc <- scen[i, ]; set.seed(1000 * i + r)
  pn <- panels[[sc$panel]](r)
  kk <- tso_kernels(pn, which = c("A", "AA"))
  A <- kk$K$A; AA <- kk$K$AA; ids <- rownames(A); N <- length(ids)
  L <- function(M) { e <- eigen(M, TRUE); e$vectors %*% diag(sqrt(pmax(e$values, 0))) }
  a <- as.vector(L(A) %*% stats::rnorm(N)) * sqrt(1 - sc$s_AA)
  aa <- as.vector(L(AA) %*% stats::rnorm(N)) * sqrt(sc$s_AA)
  g <- a + aa; lam <- (1 - sc$h2) / sc$h2 * stats::var(g) / 1
  y <- g + stats::rnorm(N, 0, sqrt(lam))
  Kt <- (1 - sc$s_AA) * A + sc$s_AA * AA; Ka <- (1 - sc$s_AA) * A
  Tg <- sample.int(N, 60); tgt <- ids[Tg]
  tpA <- tso_data(pn, verbose = FALSE)
  tpK <- tso_data(pn, kernels = kk, verbose = FALSE)
  sets <- list(
    additive = tso_design(tpA, n = sc$n, target = tgt, verbose = FALSE)$selected$id,
    kernels = tso_design(tpK, n = sc$n, target = tgt, verbose = FALSE)$selected$id,
    kernels_breeding = tso_design(tpK, n = sc$n, target = tgt, value = "breeding", verbose = FALSE)$selected$id)
  pool <- setdiff(seq_len(N), Tg)
  rnd <- rowMeans(vapply(1:5, function(k) predict_acc(Kt, Ka, sample(pool, sc$n), Tg, y, lam, g, a), numeric(2)))
  res <- c(list(random = rnd), lapply(sets, function(s) predict_acc(Kt, Ka, match(s, ids), Tg, y, lam, g, a)))
  for (m in names(res)) rows[[length(rows) + 1]] <- data.frame(sc, rep = r, method = m, total = res[[m]][1],
                                                                breeding = res[[m]][2])
}
out <- do.call(rbind, rows)
dir.create("benchmark/results", showWarnings = FALSE)
utils::write.csv(out, "benchmark/results/kernels_benchmark.csv", row.names = FALSE)
summ <- stats::aggregate(cbind(total, breeding) ~ method, out, mean)
base <- summ[summ$method == "random", c("total", "breeding")]
summ$total_vs_random <- summ$total - base$total; summ$breeding_vs_random <- summ$breeding - base$breeding
print(summ, digits = 3)
w <- reshape(out[, c("panel", "s_AA", "h2", "n", "rep", "method", "total", "breeding")],
             idvar = c("panel", "s_AA", "h2", "n", "rep"), timevar = "method", direction = "wide")
cat(sprintf("\nkernels vs additive, total value:    mean %+.4f, wins %.0f%% of %d runs\n",
            mean(w$total.kernels - w$total.additive), 100 * mean(w$total.kernels > w$total.additive), nrow(w)))
cat(sprintf("kernels_breeding vs additive, breeding value: mean %+.4f, wins %.0f%%\n",
            mean(w$breeding.kernels_breeding - w$breeding.additive), 100 * mean(w$breeding.kernels_breeding > w$breeding.additive)))
cat(sprintf("kernels_breeding vs kernels, breeding value:  mean %+.4f, wins %.0f%%\n",
            mean(w$breeding.kernels_breeding - w$breeding.kernels), 100 * mean(w$breeding.kernels_breeding > w$breeding.kernels)))
by_n <- stats::aggregate(cbind(d_total = total.kernels - total.additive) ~ n + s_AA, w, mean)
print(by_n, digits = 3)
