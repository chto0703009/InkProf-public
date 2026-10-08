# InkProf: model, inverse and measurement strategy

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Technical discussion basis • 25 September 2026 • Version 1.0

**Proposal:** describe the overall print chain with a measured RGB forward model. Compute the inverse locally with an approximated Jacobian, damping and good starting values. Adapt the measurement to observed errors and the user's priorities.

The document summarises the discussion about the Canon PRO-2600 and InkProf. It describes a proposed method, not an implemented or experimentally verified solution. Performance, patch counts and time savings remain to be measured.

### 1. What we can actually control

> RGB → driver ink separation and rasterisation → paper → measured spectrum

We can specify RGB and measure the print's reflectance. We do not assume access to individual ink channels. The model therefore applies to a specific combination of printer, paper, media type, quality mode and other print settings. The target workflow must preserve the intended device values without an unintended extra profile conversion.

### 2. Yule-Nielsen/Neugebauer: relevant, but not the first choice

$$
\rho(\lambda)=\left[\sum_i a_i\,\rho_i(\lambda)^{1/n}\right]^n
$$

ρᵢ are spectra for paper and ink overprints, aᵢ their area coverage fractions and n a fitting parameter. Extended models have been demonstrated for inkjet prints, including with ink spreading. The model is thus not inherently unsuitable for this printing technology. [1]

The difficulty here is the hidden ink separation. We cannot readily produce all individual primaries or know their coverage. Parameters can be fitted numerically, but several different parameter sets can explain similar measurements. A good fit does not mean that the ink physics has been identified.

There are also RGB-based, Yule-Nielsen-inspired models that include the driver's behaviour. [2] They should be possible to try later as a comparison. For InkProf, an empirical RGB model that requires no assumptions about Canon's internal separation is proposed first.

## A local model from RGB to colour

### 3. The forward model

$$
\mathbf u=(r,g,b),\quad 0\le r,g,b\le1,\qquad \rho(\lambda)=F_\lambda(\mathbf u)
$$

Training data consist of the RGB values sent to the printer and measured spectra from the corresponding patches. A spectral model can be converted to XYZ and Lab for a specified illumination and observer. Fluorescent paper requires special care: an ordinary reflectance measurement does not describe all illumination-dependent fluorescence.

### Taylor approximation and polynomial regression

$$
F_\lambda(\mathbf u_0+\Delta\mathbf u)\approx F_\lambda(\mathbf u_0)+J_\lambda\Delta\mathbf u+\frac12\Delta\mathbf u^{\mathsf T}H_\lambda\Delta\mathbf u
$$

The Taylor expansion describes the function locally through slope and curvature. In practice, these can be estimated from a fitted local polynomial model, rather than through differences between individual noisy measurements.

$$
\hat\rho(\lambda)=\beta_0+\beta_1r+\beta_2g+\beta_3b+\beta_4r^2+\beta_5g^2+\beta_6b^2+\beta_7rg+\beta_8rb+\beta_9gb
$$

A second-degree polynomial has ten coefficients per wavelength. Ten measurements are not a recommended target: a stable fit and independent validation require more and well-placed patches. The coefficients can be estimated with weighted, regularised least squares. For a fixed polynomial basis, this estimation is linear in the coefficients; it does not in itself require a non-linear inverse solver.

Local models limit the risk of oscillations and large errors that a single global high-degree polynomial can give. Local weighted polynomial regression for RGB to reflectance is supported by earlier research. [3]

### The working assumption: locally smooth behaviour

A good printer should give smooth colour transitions for small RGB changes. This motivates local smoothness as a working assumption at the relevant measurement and correction scale. It is not proof of continuous derivatives at every digital level. Ink switching can change the slope without visible colour jumps.

**First implementation:** start with a local linear approximation. Introduce quadratic terms where the control measurements show that the curvature is significant. An exact Hessian is not a starting requirement.

## A manageable and stable inverse

### 4. From desired colour to RGB

$$
\min_{\mathbf u\in[0,1]^3}\frac12\left\|F(\mathbf u)-\mathbf y_{\mathrm{target}}\right\|^2
$$

F can here refer to XYZ, Lab or a weighted spectrum. The choice determines the meaning of the error measure. An ordinary squared Lab distance is not the same as ΔE00. An arbitrary target spectrum need not be reproducible with the printer's three RGB control values.

The starting value is taken from nearby patches or a preliminary inverted table. With a good starting value, a local correction may suffice. This is a working hypothesis to be verified, not a general guarantee.

$$
\begin{aligned}\mathbf e&=F(\mathbf u)-\mathbf y_{\mathrm{target}}\\(J^{\mathsf T}J+\mu I)\Delta\mathbf u&=-J^{\mathsf T}\mathbf e\end{aligned}
$$

This shows a damped Gauss-Newton step. A large μ limits the correction. The damping is reduced when the step gives the improvement the model predicts. A trust-region method similarly limits the region where the local model is used. [4] RGB limits are to be handled in the solution, not merely through uncontrolled clipping afterwards.

### Approximated Jacobian and successive sub-goals

An approximated Jacobian can be retained as long as it gives sufficiently good corrections. It is computed from the model; new prints are not needed at every numerical step. In case of difficulties, the target can be moved successively from a known, reproduced colour:

$$
\mathbf y(t)=(1-t)F(\mathbf u_0)+t\mathbf y_{\mathrm{target}},\qquad 0\le t\le1
$$

The previous solution becomes the starting point for the next sub-goal. Smaller steps are used in case of difficulties. However, such a path may pass through regions the printer cannot reproduce, even if the endpoints are reachable; the method therefore does not guarantee convergence.

### What proximity to the solution does not solve

A small residual often makes the Gauss-Newton approximation of the objective function's Hessian better. But proximity does not automatically mean low sensitivity to measurement or model errors. Near a flat or saturated region, different RGB values can give almost the same colour: the local inverse is then poorly determined.

Damping, RGB limits and continuity between neighbouring solutions give a practical choice among several equivalent answers. The aim is a useful inverse, not necessarily a unique mathematical inverse. The iterations are done when the profile is built; the result is then stored as an interpolated ICC table.

## The profile's priorities and sparse regions

### 5. Define what a good profile means

$$
E(\theta)=\sum_i w_i\,\Delta E_{00,i}(\theta)^2+\lambda S(\theta)
$$

θ here denotes the parameters of the chosen inverse or profile. The weights wᵢ express priorities and S penalises undesired irregularity. A high weight for the greyscale may improve it at the expense of other colours. Errors should therefore be reported separately for different colour regions, not just a weighted mean.

The greyscale's requirements should be divided into neutrality, lightness and a smooth, monotonic tone progression. The reference white point must be stated. An absolute quality requirement can be expressed as a tolerance instead of a high weight, if the printer can meet the tolerance.

**Distinguish description from prioritisation:** the forward model is to reproduce the measurements credibly. The user's preferences primarily govern the inverse, gamut mapping and distribution of extra measurements. The same forward model can then give several profile alternatives.

### 6. Densify where information is missing

A large gradient means that small RGB steps give large colour differences. It may require denser sampling for the desired perceptual resolution. But a steep, linear function can be interpolated exactly. The interpolation error depends particularly on curvature and the distance between points:

$$
\text{Locally neglected contribution}\approx\frac12\Delta\mathbf u^{\mathsf T}H\Delta\mathbf u
$$

Additional patches should be placed where there are large gaps, a rapidly changing Jacobian or large independent control errors. For greyscales, points are needed both along the neutral axis and around it. A higher weight cannot replace missing data.

A sparse model may itself miss a problem. Control points that are not chosen solely from the model's own estimate are therefore also needed. When errors are discovered, new training patches are added, while a separate final control set is retained.

ArgyllCMS targen can use a preliminary ICC or MPP profile to estimate perceptual distances and curvature during target generation. The tool also offers concentration around the neutral axis and dark regions. [5] This is a useful basis, but not the same as a finished error-driven feedback loop for InkProf.

## Verification, cost and next steps

### 7. Two resolutions and two feedback loops

**Measurement basis:** more relevant measurements improve knowledge of the printer. **ICC table:** more table points can reduce interpolation loss when an already known model is stored. A dense table cannot create missing measurement information. ArgyllCMS colprof has options for table resolution, also for the inverse. [6]

Fast numerical iterations take place within the model. Real feedback requires printing, stabilisation and measurement. The latter is normally the time-consuming part. A possible saving therefore comes from good starting values and targeted supplements, but must be compared experimentally with an ordinary target workflow.

### Proposed order in InkProf

1. Lock print and measurement conditions. Measure a base target with repeated patches.
2. Build and validate a simple forward model. Keep an Argyll profile as a reference.
3. Compute a damped local inverse with selectable priorities.
4. Measure control patches and supplement the target where the errors justify it.
5. Build the ICC table and also check colours between its nodes.
6. Compare colour errors, spectral errors, tone progression, patch count and total working time.

Use repeated patches to estimate noise and variation, and preferably a separate print run for final control. Stop the densification when the desired tolerance is reached or when the improvement can no longer be distinguished from the variation. Yule-Nielsen-inspired models are introduced only when they can be tested against the same control basis.

### Sources

[1] Rossier, Bugnon & Hersch (2010). Introducing Ink Spreading Within the Cellular Yule-Nielsen Modified Neugebauer Model. [Open source](https://lspwww.epfl.ch/publications/colour/iiswtcynmnm_10.pdf).

[2] Zuffi, Schettini & Mauri (2005). Spectral-Based Printer Modeling and Characterization. Journal of Electronic Imaging 14(2). [Open source](https://boa.unimib.it/handle/10281/2557).

[3] Shen et al. (2013). Adaptive Characterization Method for Desktop Color Printers. Journal of Electronic Imaging 22(2), 023012. [Open source](https://doi.org/10.1117/1.JEI.22.2.023012).

[4] MathWorks. Least-Squares (Model Fitting) Algorithms. The methods are described here; ready-made solvers belong to the Optimization Toolbox. A small solver of one's own can be built with MATLAB Base. [Open source](https://www.mathworks.com/help/optim/ug/least-squares-model-fitting-algorithms.html).

[5] ArgyllCMS. targen: adaptive target generation and pre-conditioning. [Open source](https://www.argyllcms.com/doc/targen.html).

[6] ArgyllCMS. colprof: ICC profiler and table resolution. [Open source](https://www.argyllcms.com/doc/colprof.html).

The sources support the method principles. The proposed combination and its suitability for the Canon PRO-2600 are hypotheses of the InkProf work, not results from these publications.
