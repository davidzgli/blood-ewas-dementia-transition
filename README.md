# Blood DNA methylation traces a continuous epigenetic trajectory across stages of dementia progression

Analysis code and manuscript sources for an epigenome-wide association study (EWAS) of blood
DNA methylation and dementia progression in the AGES–Reykjavik cohort (n = 2,491, up to 13.4
years of follow-up).

> **Status.** This repository accompanies a manuscript that is not yet published. Citation
> details will be added on acceptance (see `CITATION.cff`).

## What this is

Baseline blood DNA methylation from 2,491 AGES–Reykjavik participants, classified into six
cognitive transition categories over up to 13.4 years of follow-up:

| Category | n | Description |
|---|---|---|
| `stable_normal` | 1,581 | Normal cognition throughout |
| `normal2mci` | 99 | Normal → MCI, no dementia |
| `stable_mci` | 49 | MCI at baseline, cognitively stable |
| `normal2incid` | 494 | Normal → incident dementia |
| `mci2incid` | 107 | MCI → incident dementia |
| `prev` | 161 | Prevalent dementia at baseline |

The analysis identifies 403 differentially methylated positions (DMPs) at *P* < 1.0 × 10⁻⁸,
projects them into VAE and UMAP latent spaces, scores a trajectory across the clinical
progression ordering, tests APOE stratification, validates against external cohorts, and runs
GO enrichment.

## Repository provenance — read before trying to reproduce

This repository is the **downstream analysis stage** of a larger workflow; the upstream cohort
assembly, methylation preprocessing, and genome-wide association scan are **not public**. It
therefore does **not** run end-to-end from a clean clone: the derived datasets it consumes must
be obtained first, and most are access-controlled. See **Data access** for how to obtain them,
and **What is not reproducible without permissions** for exactly what runs without them.

## Installation

**Requirements:** R 4.5.2, Quarto ≥ 1.8 (bundles Typst; no separate install), and Python ≥ 3.9
for the VAE step only.

### R

```bash
git clone https://github.com/davidzgli/blood-ewas-dementia-transition.git
cd blood-ewas-dementia-transition

R -q -e 'renv::restore()'
```

`renv.lock` pins every R package, including the Bioconductor ones (`clusterProfiler`,
`org.Hs.eg.db`, `AnnotationDbi`, `bacon`). `renv::restore()` configures the Bioconductor
repositories for you.

> **If R will not start.** `.Rprofile` attaches `tidyverse`/`here`/`glue` at startup. It is
> guarded, so an unrestored library prints a hint rather than failing. If you still hit a hard
> `.Rprofile` error, bypass it with `R --vanilla -e 'renv::restore()'`.

### Python / TensorFlow — Pipeline B only

Pipelines A and C need no Python.

```bash
python3 -m venv ~/.venvs/dementia-vae
~/.venvs/dementia-vae/bin/pip install -r requirements.txt      # GPU (CUDA 12)
# CPU only:
# ~/.venvs/dementia-vae/bin/pip install -r requirements-cpu.txt
```

Point the analysis at it with either:

```bash
export VAE_VIRTUALENV=~/.venvs/dementia-vae                    # this project's knob
export RETICULATE_PYTHON=~/.venvs/dementia-vae/bin/python      # reticulate's knob
```

To make it persistent, add one line to a local `.Renviron` (gitignored):

```
VAE_VIRTUALENV=~/.venvs/dementia-vae
```

If neither is set, `VAE/lite/01_vae_embedding.qmd` falls back to reticulate's default
discovery. Nothing consumes `requirements.txt` automatically, so that fallback may provision a
*different* TensorFlow than the pins below. It still runs and reports the interpreter it
found, but set `VAE_VIRTUALENV` to a virtualenv built from `requirements.txt` to guarantee the
versions the published fit used.

> **Determinism vs. reproduction.** The VAE fixes its seeds and calls
> `enable_op_determinism()`, so a re-run on the *same* GPU reproduces the fit bit-for-bit —
> verified byte-identical across TensorFlow 2.20 and 2.21, so a minor TensorFlow upgrade is
> safe. It does **not** reproduce across *hardware*: a CPU run, or a different GPU or CUDA
> build, yields the same trajectory structure on a **different basis**, whose latent dimension
> indices (`vae_N`, `umap_N`) are not comparable across runs. The published figures come from
> TensorFlow 2.20.0 / keras 3 on a CUDA 12 GPU.

## Data access

`data/` has five tiers. Only the first is in this repository.

### `data/publicly_available/` — included, CC BY 4.0

| File | Read by |
|---|---|
| `association_nlog10_p_value_lgeq5_wide.rds` | `normal2mci_focused/02`, `stable_mci_focused/02` |
| `correlation_among_demcats_various_pval_cutoffs_stable_mci_lump.rds` | `normal2mci_focused/03` |

### `data/upon_request/` — reasonable request to the corresponding author

| File | Gates |
|---|---|
| `whole_genome_wide.rds` | `validation/01,02,03,05` (all external validation) |
| `annotated_asso_wide.rds` | `normal2mci_focused/01`, `stable_mci_focused/01`, `extended_data/01,02`, `pathway_analysis/01_genes/01,02` |
| `background_great_genes.rds` | `pathway_analysis/02_gene_ontology/02` (GO background) |
| `manhattan_plot_data.rds` | `dmp/01` (Manhattan plot) |
| `dementia_relevance_for_top_genes.rds` | `normal2mci_focused/04` |

### `data/collaborator_only/` — executed Data Use Agreement with the PI

| File | Gates |
|---|---|
| `adjusted_meth/adjusted_methylation_scaled_nlog10p_gte_{7,8}.rds` | **all of Pipeline B** — VAE, UMAP, `VAE_UMAP_comb`, `APOE` |
| `covariates_and_meth_DMP_on_chr21.rds` | `demographics/01,02,03` |
| `blood_cell_composition.csv` | `demographics/02` |

### `data/private/` — most restricted

| File | Gates |
|---|---|
| `apoe_genotype.sas7bdat` | `APOE/01,06`; `demographics/03` |
| `ages1_derived_variables_nov2021.sas7bdat` | `demographics/03` |
| `gene_dmp_dementia_relevance.rds` | `dmp/01` |

### `data/published_data/` — third-party; download it yourself

**We do not hold redistribution rights for these.** Obtain them from the original sources and
place them at the paths below.

| File | Source | Gates |
|---|---|---|
| `MIAMI_AD_database/blood_AD_ADNI_AIBL.xlsx` | MIAMI-AD database | `validation/01` |
| `MIAMI_AD_database/blood_CSF_pTau.xlsx` | MIAMI-AD database | `validation/02` |
| `MIAMI_AD_database/blood_CSF_total_Tau.xlsx` | MIAMI-AD database | `validation/03` |
| `AD_EWAS_HOBX6_NeurologyofAging2020/AppendixA_AddNeuroMed_CTL_MCI_AD.xlsx` | Supplementary data of the AddNeuroMed reference | `validation/05` |

Requests for the access-controlled tiers: **Lenore J. Launer — launerl@nia.nih.gov**

### Wiring up the tiers

Drop approved files into `data/<tier>/`, or symlink a directory you already hold:

```bash
bash manage_project/setup_data_links.sh /path/to/your/data
bash manage_project/setup_data_links.sh --status
```

The script is idempotent, never touches `data/publicly_available/` (real, committed files), and
refuses to clobber a non-empty real directory. Everything under `data/` except the two public
files is gitignored.

Pointing the script at one directory does not guarantee a self-contained tree — the source may
itself contain symlinks that escape elsewhere. Check with:

```bash
find -L data -type l -print          # any output = dangling link
```

## Running

`manage_project/render_manuscript.sh` is the sole orchestrator. Run it from the project root.

```bash
bash manage_project/render_manuscript.sh --pipeline-a
bash manage_project/render_manuscript.sh --pipeline-b
bash manage_project/render_manuscript.sh --pipeline-c
bash manage_project/render_manuscript.sh --manuscript
bash manage_project/render_manuscript.sh --all          # default
```

Pipelines A, B and C are **independent** and converge only at the manuscript layer. Within a
pipeline, order matters and is fixed by each `render.sh`.

| Flag | Directories, in order | Gated by |
|---|---|---|
| `--pipeline-a` | `demographics/` → `dmp/` → `validation/` → `normal2mci_focused/` → `stable_mci_focused/` | `collaborator_only`, `private`, `upon_request`, `published_data` |
| `--pipeline-b` | `UMAP/lite/` → `VAE/lite/` → `VAE_UMAP_comb/` → `APOE/` | `collaborator_only` (+ `private` for APOE) + Python/TensorFlow |
| `--pipeline-c` | `pathway_analysis/` → `extended_data/` | `upon_request` |
| `--manuscript` | `ms/` | all three pipelines complete |

Each directory also has a standalone driver (`bash validation/render.sh`). Every pipeline writes
to `<dir>/output/`, which is gitignored.

The manuscript **text** renders with no data at all — it is prose plus placeholder floats:

```bash
quarto render ms/write-ms/dementia_EWAS.qmd --to typst
```

The figure and table documents (`ms/fig_tbl/*.qmd`) embed PNGs from `*/output/`, so they need
the pipelines to have run.

### Submission PDFs

`render_manuscript.sh --manuscript` stops at the raw Quarto output. `ms/post_process_pdf.sh` is a
second, driver-less step: it strips the auto front matter, prepends a clean title page and stamps
continuous page numbers into `ms/submission/` (gitignored). No `render.sh` calls it, so re-run it
by hand after any prose or float change — pagination shifts:

```bash
bash ms/render.sh
bash ms/post_process_pdf.sh
```

The old baked-in page number is *masked*, not removed, so verify a renumbering from the rendered
page image; `pdftotext` still shows the stale number in the text layer.

### One manual link

`normal2mci_focused/04_gene_dementia_function.qmd` is standalone and is the **one manual link in
the chain**. It writes `normal2mci_focused/output/gene_dmp_dementia_relevance.rds`, and
`dmp/01_Manhattan_plot.qmd` reads `data/private/gene_dmp_dementia_relevance.rds` — the same table,
promoted between the two locations **by hand**. No script automates that copy, so `--all` alone
will not rebuild the Manhattan plot's annotation from scratch. To regenerate it end to end:

```bash
quarto render normal2mci_focused/04_gene_dementia_function.qmd --to html   # needs data/upon_request/
cp normal2mci_focused/output/gene_dmp_dementia_relevance.rds data/private/
bash dmp/render.sh
```

Otherwise the shipped `data/private/` copy is used as-is.

## What is not reproducible without permissions

An honest accounting, from a clean clone with no additional data:

| Pipeline | Runs? | Missing |
|---|---|---|
| A — demographics | no | `collaborator_only`, `private` |
| A — dmp | no | `private`, `upon_request` |
| A — validation | no | `upon_request`, `published_data` |
| A — normal2mci `02`, `03` | **yes** | — uses shipped data |
| A — normal2mci `01`; stable_mci `01` | no | `upon_request` |
| A — stable_mci `02` | **yes** | — uses shipped data |
| B — UMAP, VAE, comb, APOE | no | `collaborator_only` (+ `private`), + TensorFlow |
| C — pathway, extended data | no | `upon_request` |
| ms — text (`dementia_EWAS.qmd`) | **yes** | — needs no data |
| ms — figures and tables | no | needs A + B + C output |

We publish the complete pipeline rather than only the runnable subset, so the exact analysis
behind every figure is inspectable even where the input data cannot be shared.

## Layout

| Directory | Role |
|---|---|
| `demographics/` | Cohort tables and baseline characteristics |
| `dmp/` | Manhattan plot |
| `validation/` | External validation: ADNI/AIBL, CSF pTau/total Tau, AddNeuroMed |
| `normal2mci_focused/` | Normal→MCI transition; effect-size correlations |
| `stable_mci_focused/` | Stable MCI; main and outlier DMP clusters |
| `UMAP/lite/`, `VAE/lite/` | Dimensionality reduction feeding the manuscript |
| `VAE_UMAP_comb/` | Cross-method ANOVA, density peaks, permutation tests |
| `APOE/` | APOE-stratified latent boxplots (reads both `*/lite/`) |
| `pathway_analysis/` | GO enrichment; transition-specific terms; keyword function categorization |
| `extended_data/` | Supplementary Data workbook |
| `custom_func/` | Shared R helpers, sourced across analyses |
| `ms/` | Manuscript text, figures/tables, bibliography |
| `manage_project/` | Orchestrator and the data-link helper |

## Licence

- **Code** — MIT (`LICENSE`)
- **Data in `data/publicly_available/`** — CC BY 4.0 (`data/LICENSE`)
- **`data/published_data/`** — third-party; not ours to license. Follow the original sources' terms.

## Citation

See `CITATION.cff`. Full details on acceptance.
