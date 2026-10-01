# Installing TSOpt

TSOpt is an R package. You need **R 4.1 or later** ([download R](https://cran.r-project.org)) and, preferably,
[RStudio](https://posit.co/download/rstudio-desktop/). No compiler is needed: you install a ready-made binary
package for your system.

## 1. Get the files

* **The package:** the file for your system, from the **[Releases](../../../releases)** page of this repository.

  | Your system | File |
  |:--|:--|
  | Windows | `TSOpt_0.5.0.zip` |
  | macOS (Apple silicon or Intel) | `TSOpt_0.5.0.tgz` |
  | Linux (x86-64) | `TSOpt_0.5.0_R_x86_64-pc-linux-gnu.tar.gz` |

* **Your licence key:** request it by email ([how keys work](LICENCE_KEY.md)).

The binaries are built for the current release of R (4.5.x). If you use an older R and the installation
complains, tell us your version (`R.version.string`) and we will send a matching file.

## 2. Install

Open R or RStudio and run:

```r
# the packages TSOpt uses (once)
install.packages(c("data.table", "ggplot2", "scales", "jsonlite", "patchwork"))

# TSOpt itself: the path to the file you downloaded
install.packages("C:/Users/you/Downloads/TSOpt_0.5.0.zip", repos = NULL)          # Windows
install.packages("~/Downloads/TSOpt_0.5.0.tgz", repos = NULL)                       # macOS
install.packages("~/Downloads/TSOpt_0.5.0_R_x86_64-pc-linux-gnu.tar.gz", repos = NULL)  # Linux
```

**RStudio alternative:** Tools › Install Packages › *Install from:* **Package Archive File** › choose the file.

Then restart R (RStudio: Session › Restart R).

## 3. Activate your key, once

```r
library(TSOpt)
tso_licence("TSO1....")     # paste your whole key between the quotes
```

The key is checked on your computer and saved there, so you never need to enter it again. `tso_licence()`
shows the key that is active.

## 4. Check that everything works (about a minute)

```r
source(system.file("testing", "test_everything.R", package = "TSOpt"))
```

The script runs every function once and checks the results. It should end with **"53 of 53 checks passed.
Everything works."** Figures, a plan and a report are saved to `TSOpt_test_outputs` in your working folder.

## 5. Start

```r
tso_docs()                                 # the guides, the tutorial and the manual, offline
panel <- tso_simulate_panel()              # an example panel, or tso_data("your_file.vcf.gz")
plan  <- tso_design(panel, n = 100)
plan
```

## Optional packages

TSOpt works without these, and uses them when present:

| Package | For |
|:--|:--|
| `cluster` | Population-structure diagnostics |
| `ggrepel`, `ragg`, `svglite` | Figure labels and file formats |
| `readxl` | Excel files |
| `rmarkdown`, `knitr` | Reports and the walkthrough |
| `curl` | BrAPI breeding databases |

## Troubleshooting

| Message | What to do |
|:--|:--|
| `there is no package called 'data.table'` (or another) | Run the first `install.packages()` line in step 2 |
| `TSOpt is not activated` | Run `tso_licence("TSO1....")` once with your key |
| `the licence expired on ...` | Ask for a new key (keys are valid for 12 months) |
| `the key is damaged` | Copy the whole key, from `TSO1.` to the end, in one piece |
| `package ... was built under R version ...` | A warning only; if the package does not load, ask for a file for your R version |
| Installation fails on macOS with "cannot open file" | Use the full path, e.g. `"~/Downloads/TSOpt_0.5.0.tgz"` |

Still stuck? [Open an issue](../../../issues/new/choose) (don't include your key) or email
[waseemhussain@plantnura.com](mailto:waseemhussain@plantnura.com).
