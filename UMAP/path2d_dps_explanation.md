# Path2D DPS: Algorithm and Biological Rationale

**Source:** `custom_func/compute_spatial_dps.R:44-67`

## Overview

Path2D DPS (Dementia Progression Score) is a signed metric in $[-1, 1]$ that quantifies how well a sequence of 2D centroid positions traces a smooth, directionally consistent path through embedding space. It is the product of two components: an unsigned **path efficiency** ratio and a signed **mean directional cosine**.

## Input

A sequence of $n = 6$ centroid coordinates $(x_i, y_i)$ for $i = 1, \ldots, 6$, ordered by the expected dementia progression:

1. normal2mci
2. stable_normal
3. stable_mci
4. normal2incid
5. mci2incid
6. prev_dementia

Each centroid is the **mean position of the high-density grid points** — the top 10% of the kernel
density surface (`density_threshold = 0.9`) — of a dementia category's distribution in a particular 2D
UMAP dimension pair, computed from seed-averaged embeddings. It is *not* the single densest point:
`DPS/01_density_peak_analysis.qmd:155-159` takes `x_mean = mean(x_highest_densities)` over that
region, and `02_dps_path2d.qmd:78` passes those means on. The distinction matters for a skewed or
multi-modal category, where the mean of the high-density region and the mode diverge.

## Algorithm

### Step 1: Compute Step Vectors

For each consecutive pair of centroids, compute the displacement vector and its Euclidean length:

$$\Delta x_i = x_{i+1} - x_i, \quad \Delta y_i = y_{i+1} - y_i, \quad d_i = \sqrt{\Delta x_i^2 + \Delta y_i^2}$$

for $i = 1, \ldots, n-1$ (5 steps for 6 centroids).

### Step 2: Path Efficiency (Unsigned Component)

Compute the total path length (sum of all step distances) and the direct end-to-end distance:

$$L_{\text{path}} = \sum_{i=1}^{n-1} d_i$$

$$L_{\text{direct}} = \sqrt{(x_n - x_1)^2 + (y_n - y_1)^2}$$

The path efficiency ratio is:

$$E = \frac{L_{\text{direct}}}{L_{\text{path}}}$$

This ratio lies in $[0, 1]$. By the triangle inequality, $L_{\text{direct}} \leq L_{\text{path}}$, so $E \leq 1$. Equality holds when all centroids are collinear and in the correct order (no backtracking). The ratio approaches 0 when the path zigzags extensively, making $L_{\text{path}} \gg L_{\text{direct}}$.

**Edge case:** If $L_{\text{path}} = 0$ or $L_{\text{direct}} = 0$, the function returns 0 (all centroids coincide or the first and last centroid are the same point).

### Step 3: Mean Directional Cosine (Signed Component)

Define the **progression direction** as the unit vector from the first centroid to the last:

$$\hat{\mathbf{p}} = \frac{1}{L_{\text{direct}}} \begin{pmatrix} x_n - x_1 \\ y_n - y_1 \end{pmatrix}$$

For each step $i$, compute the projection of the step vector onto the progression direction and normalize by the step length to obtain the cosine of the angle $\theta_i$ between the step and the progression direction:

$$\text{proj}_i = \Delta x_i \cdot \hat{p}_x + \Delta y_i \cdot \hat{p}_y$$

$$\cos \theta_i = \frac{\text{proj}_i}{d_i}$$

If $d_i = 0$ (consecutive centroids coincide), $\cos \theta_i$ is set to 0.

The signed component is the mean directional cosine across all steps:

$$C = \frac{1}{n-1} \sum_{i=1}^{n-1} \cos \theta_i$$

This lies in $[-1, 1]$:

- $C = +1$: every step is perfectly aligned with the progression direction (all $\theta_i = 0$).
- $C = 0$: forward and backward steps cancel, or steps are perpendicular to progression.
- $C = -1$: every step is perfectly anti-aligned (all $\theta_i = \pi$).

### Step 4: Final Score

$$\text{Path2D DPS} = E \times C = \frac{L_{\text{direct}}}{L_{\text{path}}} \times \frac{1}{n-1} \sum_{i=1}^{n-1} \cos \theta_i$$

The final score lies in $[-1, 1]$.

## Interpretation

| Score Range | Interpretation |
|-------------|----------------|
| $\approx +1$ | All centroids on a straight line in the correct progression order. The path is maximally efficient and every step advances forward. |
| $+0.3$ to $+0.7$ | Moderate progression signal. Steps mostly go forward but with some deviation (zigzag or off-axis drift). |
| $\approx 0$ | No net progression. Either the centroids cluster together ($E \to 0$), or forward and backward steps cancel ($C \to 0$). |
| $-0.3$ to $-0.7$ | The path is moderately efficient but runs in the wrong direction. The embedding reverses the expected biological order. |
| $\approx -1$ | Perfect straight-line path in fully reversed order. |

### Why Two Components?

Neither component alone is sufficient:

- **Efficiency alone** ($E$) cannot distinguish a perfect forward path from a perfect backward path (both give $E = 1$).
- **Directional cosine alone** ($C$) can be high even for a wildly zigzagging path that happens to have slightly more forward steps than backward ones.

The product $E \times C$ rewards paths that are simultaneously efficient (short, straight) and correctly oriented (forward-progressing). A path must satisfy both criteria to score near $+1$.

## Geometric Intuition

Consider 6 centroids in 2D space. Draw the walking path through them in progression order (1 $\to$ 2 $\to$ ... $\to$ 6):

- **Ideal case ($+1$):** The centroids lie along a straight line, evenly spaced, with each step moving in the same direction. The walking path equals the shortest path. Every step cosine is $+1$.

- **Zigzag case ($\approx 0$):** The centroids alternate position (step forward, step backward). $L_{\text{path}}$ is much larger than $L_{\text{direct}}$, driving $E$ toward 0. Some step cosines are negative, driving $C$ toward 0. The product is near 0.

- **Reversed case ($-1$):** Same as ideal but the progression runs in reverse. $E = 1$ but every step cosine is $-1$, so $C = -1$.

- **Clustered case ($\approx 0$):** All centroids are very close together. Both $L_{\text{direct}}$ and $L_{\text{path}}$ are tiny, and the function returns 0 by the edge-case guard.

## Biological Relevance to Dementia Progression

### The Biological Model

The six dementia trajectory categories represent clinically distinct stages along the cognitive decline spectrum, ordered from early/mild to severe:

1. **normal2mci** -- individuals transitioning from normal cognition to mild cognitive impairment
2. **stable_normal** -- cognitively normal individuals who remain stable
3. **stable_mci** -- individuals with stable MCI (not progressing further)
4. **normal2incid** -- individuals who progress from normal to incident dementia
5. **mci2incid** -- individuals who progress from MCI to incident dementia
6. **prev_dementia** -- individuals with prevalent (established) dementia

The UMAP embedding projects high-dimensional DNA methylation data (epigenome-wide CpG sites) into 2D space. Each dimension pair captures different aspects of the epigenetic variation.

### What Path2D DPS Measures Biologically

Path2D DPS answers a specific biological question: **Do the epigenetic signatures of these six dementia stages form a smooth, directional gradient in embedding space?**

A high positive score ($\approx +1$) for a given UMAP dimension pair indicates:

1. **Continuous epigenetic deterioration.** The methylation profiles change gradually across dementia stages. Adjacent stages (e.g., stable_mci $\to$ normal2incid) have more similar epigenetic signatures than distant stages (e.g., stable_normal $\to$ prev_dementia). This is captured by the path efficiency: no intermediate stage "jumps back" to look like an earlier stage.

2. **Monotonic biological ordering.** The UMAP dimensions encode a disease axis along which the six categories are monotonically ordered. This is captured by the directional cosine: each step from a milder stage to a more severe stage moves consistently in the same direction through embedding space.

3. **Recoverable disease signal.** The fact that a dimensionality reduction method (UMAP) organizes categories this way from methylation data alone suggests the underlying biology contains a strong, recoverable dementia progression signal in the epigenome.

### Why a Negative Score Is Informative

A negative Path2D DPS does not necessarily mean the dimension pair is uninformative. It could mean:

- The embedding captures the progression axis but with **inverted orientation** (UMAP dimensions have arbitrary sign). This is biologically equivalent to a positive score of the same magnitude.
- The dimension pair captures a **different biological axis** (e.g., age, sex, cell composition) that conflicts with the dementia ordering.

In practice, the absolute value $|$Path2D DPS$|$ may be more relevant for dimension pair selection, but the sign provides additional information about axis orientation.

### Comparison with Ordering-Based DPS Metrics

The ordering-based metrics (Kendall, Violation, Efficiency, Rank) evaluate progression along each UMAP dimension independently (1D), then average the x and y scores. Path2D DPS operates on both dimensions jointly (2D), capturing spatial relationships that 1D metrics miss:

| Property | Ordering-based (1D) | Path2D (2D) |
|----------|---------------------|-------------|
| Dimensionality | Each axis independently | Joint 2D path |
| Backtracking detection | Along one axis only | In any 2D direction |
| Diagonal progressions | Missed (requires both axes) | Captured naturally |
| Scale | $[0, 1]$ (unsigned) | $[-1, 1]$ (signed) |

A dimension pair could have low 1D DPS scores (centroids not monotonically ordered along either axis individually) but high Path2D DPS (centroids follow a smooth diagonal trajectory through the 2D space). This makes Path2D DPS particularly valuable for detecting oblique progression axes that are invisible to per-axis analysis.
