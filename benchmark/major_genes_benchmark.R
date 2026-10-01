# ----------------------------------------------------------------------------
# Major-gene protection benchmark (TSOpt v0.4)
#
# Scenario: an introgressed major gene carried by 16 of 60 targets (group G4)
# and by 8 unrelated candidates (group G1); it explains 40% of the genetic
# variance of 30 simulated traits (h2 = 0.5). Two training sets of 30 lines:
#   standard     robust CDmean (TSOpt v0.3 default)
#   major-aware  tso_data(major = "m700", major_share = 0.3, min_carriers = 3)
# Both are scored with the same prediction model a breeder would use once
# the gene is known: GBLUP with the gene as a fixed effect (when the training
# set has no carrier, the effect cannot be estimated and is dropped).
#
# Run from the repository folder:  Rscript benchmark/major_genes_benchmark.R
# Result (v0.4.0): targeted 0.232 -> 0.872 (30/30), untargeted 0.307 -> 0.694 (30/30)
# ----------------------------------------------------------------------------

library(TSOpt)
panel <- tso_simulate_panel(n = 400, markers = 1500, groups = 4, fst = 0.25, seed = 8)  # also seeds the draws below
ids <- rownames(panel$dosage)
tg <- ids[panel$groups == "G4"][1:60]
m <- "m700"
panel$dosage[, m] <- 0
panel$dosage[sample(tg, 16), m] <- 2
panel$dosage[sample(ids[panel$groups == "G1"], 8), m] <- 2
X <- panel$dosage
Kp <- tso_kinship(tso_qc(panel, verbose = FALSE))

predict_gblup_major <- function(train, y, h2 = 0.5) {
  S <- match(train, ids); d <- (1 - h2) / h2
  V <- Kp[S, S] + diag(d, length(S)); Xf <- cbind(1, X[S, m])
  if (var(X[S, m]) == 0) Xf <- Xf[, 1, drop = FALSE]
  Vi <- solve(V); b <- solve(crossprod(Xf, Vi %*% Xf), crossprod(Xf, Vi %*% y[train]))
  gpoly <- Kp[, S] %*% (Vi %*% (y[train] - Xf %*% b))
  Xall <- cbind(1, X[, m])[, seq_len(ncol(Xf)), drop = FALSE]
  setNames(as.vector(Xall %*% b + gpoly), ids)
}

tp  <- tso_data(panel, verbose = FALSE)
tpm <- tso_data(panel, major = m, major_share = 0.3, min_carriers = 3, verbose = FALSE)
for (sc in c("targeted", "untargeted")) {
  targ <- if (sc == "targeted") tg else NULL
  p0 <- tso_design(tp,  n = 30, target = targ, verbose = FALSE)
  p1 <- tso_design(tpm, n = 30, target = targ, verbose = FALSE)
  pa <- t(sapply(1:30, function(s) {
    tr <- tso_simulate_trait(panel, h2 = 0.5, n_qtl = 100, major = m, major_share = 0.4, seed = s)
    y <- setNames(tr$y, tr$id); gv <- setNames(tr$g, tr$id)
    ev <- if (is.null(targ)) setdiff(ids, c(p0$selected$id, p1$selected$id)) else tg
    c(standard = cor(predict_gblup_major(p0$selected$id, y)[ev], gv[ev]),
      major_aware = cor(predict_gblup_major(p1$selected$id, y)[ev], gv[ev]))
  }))
  cat(sprintf("%-10s carriers: standard %d, major-aware %d | accuracy %.3f -> %.3f | major-aware better in %d/30\n",
              sc, sum(X[p0$selected$id, m] > 0), sum(X[p1$selected$id, m] > 0),
              mean(pa[, 1]), mean(pa[, 2]), sum(pa[, 2] > pa[, 1])))
}
