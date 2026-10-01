# Security policy

## Reporting a vulnerability

Please report security problems **privately**, not in a public issue. Send them by email to
[waseemhussain@plantnura.com](mailto:waseemhussain@plantnura.com?subject=TSOpt%20security%20report), with:

* what you found, and how to reproduce it;
* the TSOpt version (`packageVersion("TSOpt")`), R version and operating system;
* whether you believe it is being exploited.

We will acknowledge your report within **5 working days** and keep you informed until it is resolved. Please
give us reasonable time to release a fix before you disclose the problem. We credit reporters who wish to be
named.

## Supported versions

| Version | Supported |
|:--|:--:|
| 0.5.x | ✅ |
| < 0.5 | ❌ (please upgrade) |

## What TSOpt does with your data

* **Everything runs on your computer.** TSOpt sends no data, telemetry or usage information anywhere.
* **The licence key is checked offline,** against a public key built into the package. No server is contacted.
* **Network access** happens only when you ask for it: when you connect to a BrAPI breeding database
  (`tso_brapi_connect()`), using the address and token you provide.
* **Outputs** (plans, plan files, reports) record your licence ID, never your key.

## Keeping your installation safe

* Install TSOpt only from this repository's **Releases** page, or from files PlantNura sends you.
* Keep your licence key private. If it is exposed, tell us and we will replace it.
* Keep R and the packages TSOpt uses up to date (`update.packages()`).
* The optional command-line tool and web interface (`tsopt`, plumber) are meant for use inside your
  organisation. Do not expose them to the internet.

## In scope

* The TSOpt package and its licence-key verification.
* The command-line tool and the plumber interface shipped with the package.
* The documentation and release files in this repository.

## Out of scope

* Vulnerabilities in R itself or in third-party packages (please report those to their maintainers).
* Problems that need an attacker already in control of your computer.
