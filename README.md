# Krk LNG Terminal — Welfare Analysis (Stata)

Difference-in-differences and synthetic control analysis of the effect of
Croatia's Krk LNG terminal on electricity prices, with a welfare estimate
for 2021–2024.

## Files

- **`January5_clean.do`** — the analysis code, cleaned and organized into
  numbered sections (data setup, DiD, synthetic control, robustness checks,
  permutation inference, welfare calculation). Start here.
- **`January5.log`** — the raw Stata session log this code was extracted
  from. Kept as a record of the actual console output/results at the time
  the analysis was run.

## Notes

- A couple of commands in the original session had typos or incomplete
  loops (e.g. a missing comma in a country list, a permutation-test loop
  that referenced an undefined variable). These are fixed in
  `January5_clean.do` and flagged with `NOTE:` comments at the point they
  occur, so the fix is visible rather than silently applied.
- The data file (`January5.csv`) referenced by `import delimited` is not
  included here — the `.do` file currently points to a local path
  (`/Users/gsobek/Desktop/January5.csv`) and will need that path updated,
  or the CSV added to this repo, to re-run end to end.
