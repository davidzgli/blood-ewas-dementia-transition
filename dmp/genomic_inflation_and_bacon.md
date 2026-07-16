# Genomic Inflation, Lambda, and Bacon Correction

## Overview

In epigenome-wide association studies (EWAS), hundreds of thousands of
CpG sites are tested for association with a phenotype. Statistical
artifacts can systematically distort test statistics across the genome,
producing excess false positives. This document explains how to detect
such distortion (genomic inflation factor, lambda) and correct it
(bacon).

## Test Statistics

### From regression to z-scores

For each CpG site $i$, a regression model is fit:

$$
\text{methylation}_i = \beta_0 + \beta_1 \cdot \text{phenotype} + \beta_2 \cdot \text{covariates} + \epsilon
$$

The model yields an **estimate** $\hat{\beta}_{1,i}$ (effect size) and a
**standard error** $\text{SE}_i$. The test statistic is the z-score:

$$
z_i = \frac{\hat{\beta}_{1,i}}{\text{SE}_i}
$$

Under the null hypothesis ($\beta_1 = 0$), $z_i$ follows a standard
normal distribution:

$$
z_i \sim \mathcal{N}(0, 1)
$$

### From z-scores to p-values

The two-sided p-value is:

$$
p_i = 2 \cdot \Phi(-|z_i|)
$$

where $\Phi$ is the standard normal CDF. This relationship is
invertible — given a p-value and the sign of the effect, the z-score can
be reconstructed:

$$
z_i = \text{sign}(\hat{\beta}_{1,i}) \cdot \Phi^{-1}\!\left(1 - \frac{p_i}{2}\right)
$$

### From z-scores to chi-squared statistics

Squaring a z-score gives a chi-squared statistic with 1 degree of
freedom:

$$
\chi^2_i = z_i^2 \sim \chi^2(df = 1)
$$

The chi-squared scale is convenient because it is always positive,
making the median straightforward to compute without worrying about sign.

## Genomic Inflation Factor (Lambda)

### Definition

The genomic inflation factor $\lambda$ quantifies how much the bulk of
observed test statistics deviate from their theoretical null
distribution:

$$
\lambda = \frac{\text{median}(\chi^2_{\text{observed}})}{\text{median}(\chi^2_{\text{expected}})}
$$

### Expected median under the null

If all tests are truly null, each $\chi^2_i$ follows a $\chi^2(df=1)$
distribution. The median of this distribution is a fixed constant:

$$
\text{median}(\chi^2_{\text{expected}}) = F^{-1}_{\chi^2(1)}(0.5) = 0.4549364
$$

where $F^{-1}_{\chi^2(1)}$ is the quantile function (inverse CDF) of
the $\chi^2(df=1)$ distribution.

### Observed median

The observed median is computed directly from the data — converting all
p-values to chi-squared statistics and taking their median:

$$
\text{median}(\chi^2_{\text{observed}}) = \text{median}\!\left(\left\{F^{-1}_{\chi^2(1)}(1 - p_i) : i = 1, \ldots, m\right\}\right)
$$

where $m$ is the number of CpG sites tested.

### Why the median?

Only a small fraction of CpG sites are expected to be truly associated
with the phenotype. The **median** captures the behavior of the bulk
(null) tests and is robust to the small number of true signals in the
tail. If the mean were used instead, a few highly significant true
associations could inflate the estimate even when the null distribution
is well-calibrated.

### Interpreting lambda

| $\lambda$ | Interpretation |
|---|---|
| $\approx 1.0$ | Well-calibrated, no systematic inflation |
| $1.0 - 1.1$ | Minimal inflation, generally acceptable |
| $1.1 - 1.2$ | Moderate inflation, correction recommended |
| $> 1.2$ | Substantial inflation, correction required |

When $\lambda > 1$, the entire distribution of test statistics is wider
than expected. This means p-values are systematically too small,
producing excess "significant" results that are artifacts rather than
true biology.

### Common causes of inflation in EWAS

- **Unaccounted batch effects** — technical variation between arrays or
  processing runs
- **Residual population stratification** — genetic ancestry differences
  not fully adjusted for
- **Cell-type composition** — differences in blood cell proportions that
  correlate with the phenotype
- **Correlated probes** — nearby CpG sites on the array are not
  independent, violating the assumption of independent tests

## QQ Plots

A quantile-quantile (QQ) plot provides a visual assessment of inflation
by plotting expected vs. observed $-\log_{10}(p)$ values.

### Construction

1. Sort the $m$ observed p-values: $p_{(1)} \leq p_{(2)} \leq \cdots
   \leq p_{(m)}$
2. Generate expected p-values under the null using probability points:
   $e_j = \frac{j - 0.5}{m}$ for $j = 1, \ldots, m$
3. Plot $-\log_{10}(e_j)$ (x-axis) against $-\log_{10}(p_{(j)})$
   (y-axis)

### Interpretation

- **Points on the diagonal**: p-values follow the null distribution (no
  inflation)
- **Points above the diagonal in the bulk**: systematic inflation — the
  entire distribution of test statistics is shifted
- **Points above the diagonal only in the tail**: true biological
  signal, not inflation (this is expected and desirable)

A well-calibrated study shows points following the diagonal for most of
the distribution, with deviation only at the extreme tail where true
associations reside.

## Bacon Correction

### Motivation

Standard genomic inflation correction (e.g., dividing all $\chi^2$
statistics by $\lambda$) applies a uniform scaling factor. This is
overly simplistic because it:

- Assumes inflation is constant across the distribution
- Does not account for **bias** (a shift in the mean of the null)
- Over-corrects true signals in the tail

The **bacon** method (Bioconductor package `bacon`) provides a more
principled correction by modeling both inflation and bias.

### The empirical null framework

Under ideal conditions, the null test statistics follow
$\mathcal{N}(0, 1)$. In practice, the empirical null may be:

$$
z_{\text{null}} \sim \mathcal{N}(\delta, \sigma^2)
$$

where:

- $\delta$ is the **bias** (shift in the mean away from 0)
- $\sigma^2$ is the **inflation** (variance larger than 1)

### How bacon works

Bacon models the full distribution of z-scores as a Gibbs sampling
mixture:

$$
z_i \sim \pi_0 \cdot \mathcal{N}(\delta, \sigma^2) + (1 - \pi_0) \cdot f_{\text{signal}}
$$

where $\pi_0$ is the proportion of true nulls and
$f_{\text{signal}}$ captures the true associations. Using a Bayesian
approach with Gibbs sampling, bacon estimates $\delta$ (bias) and
$\sigma$ (inflation) from the data.

### Correction

Once $\delta$ and $\sigma$ are estimated, each z-score is corrected:

$$
z_i^{\text{corrected}} = \frac{z_i - \hat{\delta}}{\hat{\sigma}}
$$

Corrected p-values are then recomputed from the corrected z-scores:

$$
p_i^{\text{corrected}} = 2 \cdot \Phi(-|z_i^{\text{corrected}}|)
$$

### Effect on p-values

Bacon correction **changes the p-values**. Because $\hat{\sigma} > 1$
(inflation) and/or $\hat{\delta} \neq 0$ (bias), the corrected z-scores
are smaller in magnitude than the originals, producing **larger
(less significant) p-values**. The correction removes the artificial
significance introduced by inflation and bias, while preserving the
relative ranking of truly associated sites.

### Advantages over simple lambda correction

| Aspect | Simple $\lambda$ correction | Bacon |
|---|---|---|
| Inflation | Corrects (uniform scaling) | Corrects (estimated $\sigma$) |
| Bias | Does not correct | Corrects (estimated $\delta$) |
| Signal preservation | Over-corrects true signals | Separates null from signal |
| Estimation | Single summary statistic | Full Bayesian mixture model |

### Practical workflow

1. Calculate $\lambda$ for each analysis group
2. If $\lambda > 1.1$, apply bacon correction
3. Reconstruct z-scores from p-values and effect direction
4. Run `bacon(teststatistics = z_scores)` to estimate $\delta$ and
   $\sigma$
5. Extract corrected p-values with `pval(bacon_object)`
6. Recalculate $\lambda$ on corrected p-values to verify the correction
   brought it close to 1.0
7. Generate QQ plots before and after correction for visual confirmation

## References

- van Iterson, M., van Zwet, E. W., & Heijmans, B. T. (2017). Controlling bias and inflation in epigenome- and transcriptome-wide association studies using the empirical null distribution. *Genome Biology*, 18(1), 19.
- Devlin, B., & Roeder, K. (1999). Genomic control for association studies. *Biometrics*, 55(4), 997–1004.
