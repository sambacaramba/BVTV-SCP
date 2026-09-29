
# Parameter guide

This page provides a more detailed explanation of the user-adjustable settings in `LOCAL_BVTV_subcb_MAIN.m`.

The default values are intended as starting points. Parameters related to physical dimensions, image resolution, and local bone morphology may need to be adjusted for different datasets.

---

## `dataFormat`

```matlab
dataFormat = '\*.bmp';
```

Defines which image files are loaded from each selected sample folder.

Supported formats depend on the volume-loading function, but typical choices are:

```matlab
dataFormat = '\*.bmp';
dataFormat = '\*.png';
dataFormat = '\*.tif';
```

The image sequence should consist of consecutively numbered slices, for example:

```text
sample_0001.bmp
sample_0002.bmp
sample_0003.bmp
...
sample_1250.bmp
```

Both 8-bit and 16-bit TIFF data can be used if the volume loader preserves the original datatype correctly.

The file extension selected here must match the images in the sample folders.

---

## `flipH`

```matlab
flipH = false;
```

Controls whether every input image is flipped horizontally during loading.

```matlab
flipH = false;   % keep original horizontal orientation
flipH = true;    % mirror images horizontally
```

This does **not affect the actual segmentation principle**. It is mainly useful for maintaining a consistent visual orientation between datasets produced by different scanners or reconstruction software.

For example, different µCT systems may store reconstructed images with opposite left-right orientations. `flipH` can be used to make datasets visually comparable.

If the horizontal orientation of the dataset is already correct, leave this as:

```matlab
flipH = false;
```

---

## `flipZ`

```matlab
flipZ = false;
```

Controls the order of slices in the Z direction.

This setting is important because the algorithm expects the subchondral surface to be located toward the **end of the image stack**.

If the numbered image sequence is:

```text
0001
0002
0003
...
NNNN
```

and the subchondral surface occurs near the final slices, use:

```matlab
flipZ = false;
```

If the subchondral surface occurs near the beginning of the stack, use:

```matlab
flipZ = true;
```

The volume is then reversed before segmentation so that surface detection proceeds from the intended direction.

Incorrect Z orientation can cause the algorithm to detect the wrong surface.

---

## `binning`

```matlab
binning = 0;
```

Controls spatial downsampling of the input volume.

Allowed values are:

```text
0 = no binning
2 = 2× binning
3 = 3× binning
4 = 4× binning
```

Binning reduces the number of voxels in the dataset and therefore reduces:

- memory usage
- processing time
- computational load

The trade-off is reduced spatial resolution.

For example, with an original pixel size of:

```text
14.84 µm/pixel
```

2× binning produces an effective pixel size of:

```text
29.68 µm/pixel
```

The pipeline automatically accounts for this when converting physical parameters such as `radius_um` into pixels.

### When to use binning

Use:

```matlab
binning = 0;
```

when sufficient memory is available and maximum spatial resolution is required.

Binning can be useful for:

- very large datasets
- testing parameter combinations
- computers with limited RAM
- reducing processing time during development

Increasing binning also means that very small structures may no longer be represented accurately.

---

## `nativePixelSize_um`

```matlab
nativePixelSize_um = 14.84;
```

The physical pixel size of the **original unbinned dataset**, expressed in:

```text
µm/pixel
```

This value should come from the µCT reconstruction settings or image metadata.

It is used to convert physical parameters into image coordinates.

For example:

```matlab
nativePixelSize_um = 14.84;
radius_um = 300;
```

corresponds approximately to:

```text
300 / 14.84 ≈ 20 pixels
```

without binning.

If 2× binning is used, the effective pixel size becomes:

```text
14.84 × 2 = 29.68 µm/pixel
```

and the same physical 300 µm radius becomes approximately:

```text
300 / 29.68 ≈ 10 pixels
```

This allows the algorithm to use approximately the **same physical neighbourhood size regardless of binning**.

It is therefore important that `nativePixelSize_um` is correct.

---

## `radius_um`

```matlab
radius_um = 300;
```

Defines the **radius of the local neighbourhood** used during the local BV/TV-based trabecular-removal step.

Units:

```text
µm
```

The value is automatically converted into pixels using the effective pixel size of the processed volume.

For example:

```text
radius = 300 µm
pixel size = 14.84 µm/pixel
```

gives approximately:

```text
20 pixel radius
```

The algorithm evaluates the amount of bone inside this circular neighbourhood at each location.

### Effect of changing the radius

**Smaller radius**

The measurement becomes more sensitive to small local structures.

Possible effects:

- finer spatial response
- greater sensitivity to small trabeculae
- potentially more local variation/noise

**Larger radius**

The measurement represents a larger surrounding region.

Possible effects:

- smoother and more spatially averaged BV/TV estimate
- less sensitivity to individual small trabeculae
- potentially less accurate representation of very local structural changes

The appropriate value depends on the physical scale of the subchondral plate and trabecular architecture in the dataset.

> `radius_um` is a **radius**, not a diameter.

---

## `holeArea_um2`

```matlab
holeArea_um2 = 1000;
```

Defines the maximum area of small holes that are filled during binary-volume cleaning.

Units:

```text
µm²
```

The physical area is converted into a corresponding number of image pixels using the pixel size.

For isotropic data:

```text
pixel area = pixel size²
```

For example, at:

```text
10 µm/pixel
```

one image pixel represents:

```text
10 × 10 = 100 µm²
```

so:

```text
1000 µm²
```

corresponds to approximately:

```text
10 pixels
```

The current cleaning method operates on individual 2-D planes rather than performing true 3-D hole filling.

### Effect of changing the value

**Smaller value**

Only very small holes are filled.

**Larger value**

Larger enclosed background regions can also be filled.

Values that are too large may close real anatomical spaces, so this parameter should remain small relative to structures that need to be preserved.

---

## `removalPercentage`

```matlab
removalPercentage = 0.80;
```

Defines the local bone-fraction threshold used to distinguish dense subchondral bone from trabecular-like regions.

The algorithm evaluates a circular neighbourhood around each location.

For:

```matlab
removalPercentage = 0.80;
```

at least:

```text
80%
```

of the valid local neighbourhood must contain bone for the location to remain.

If the local foreground fraction is below 80%, the voxel is classified as trabecular-like and removed from the output mask.

### Effect of changing the value

**Lower value**, for example:

```matlab
removalPercentage = 0.70;
```

allows less-dense regions to remain.

This generally produces a more inclusive segmentation.

**Higher value**, for example:

```matlab
removalPercentage = 0.90;
```

requires a denser local bone region.

This generally produces more aggressive removal of trabecular structures.

This parameter works together with `radius_um`. A percentage threshold has different spatial meaning depending on the size of the neighbourhood over which it is calculated.

---

## `ratioLimit`

```matlab
ratioLimit = 0.50;
```

Controls the initial estimate of the **lower boundary of the subchondral plate**.

After the upper surface has been detected, the algorithm searches downward through the binary bone volume.

At each position it evaluates the fraction of foreground bone inside a small 3-D neighbourhood.

When the local bone fraction drops below `ratioLimit`, that position is used as an estimate of the transition from dense subchondral bone toward trabecular bone.

For example:

```matlab
ratioLimit = 0.50;
```

means that the lower-boundary criterion is reached when less than approximately half of the local neighbourhood consists of bone.

Typical values to test are approximately:

```text
0.3–0.7
```

### Effect of changing the value

A **higher `ratioLimit`** generally causes the transition to be detected sooner when moving away from the surface.

A **lower `ratioLimit`** allows the search to continue further into less-dense bone before the boundary is detected.

This stage is an initial estimate. The subsequent local BV/TV cleaning further separates subchondral bone from trabecular structures.

---

## `gaussianKernelSize_px`

```matlab
gaussianKernelSize_px = 30;
```

Defines the size of the Gaussian filter used to smooth the detected upper and lower surface maps.

Units:

```text
pixels
```

The smoothing reduces small local irregularities in the detected surfaces before the volume between them is extracted.

The smoothing function requires an odd kernel size. If an even value is supplied, it is automatically increased by one.

Therefore:

```matlab
gaussianKernelSize_px = 30;
```

is internally used as:

```text
31 × 31 pixels
```

### Effect of changing the value

**Smaller kernel**

- follows local surface variation more closely
- preserves small features
- may retain more segmentation noise

**Larger kernel**

- produces a smoother surface
- suppresses small irregularities
- may smooth away real local surface features if chosen too large

This parameter is currently defined in pixels, so its physical size changes when pixel resolution or binning changes.

---

## `nanFillParameter`

```matlab
nanFillParameter = 100;
```

Defines the size of the local neighbourhood used by `FillNaNs` to fill **enclosed missing regions** in the detected surface maps.

Despite the name, this is **not a number of iterations**.

It is a neighbourhood size in pixels.

For each enclosed NaN position, the function looks at nearby valid surface values and uses their median as the replacement value.

NaN regions connected to the outside of the surface remain NaN and are not filled.

### Effect of changing the value

**Smaller neighbourhood**

- uses only nearby surface values
- better preserves local variation
- may fail to fill the centre of large holes if no valid values are nearby

**Larger neighbourhood**

- can bridge larger gaps
- uses information from farther away
- may smooth over genuine local geometry if excessively large

An odd value such as:

```matlab
nanFillParameter = 101;
```

is preferable because it gives the neighbourhood a true centre pixel.

---

## `erosionRadius_px`

```matlab
erosionRadius_px = 3;
```

Controls how much the valid XY region is eroded before the final surfaces are used.

Units:

```text
pixels
```

Surface estimates near the outer boundary of the sample can be less reliable because:

- neighbourhoods may extend outside the object
- surface detection may be incomplete
- image edges may contain segmentation artefacts

The ROI mask is therefore eroded using a disk-shaped structuring element before extraction.

For:

```matlab
erosionRadius_px = 3;
```

approximately three pixels are removed around the outer boundary of the valid XY region.

### Effect of changing the value

**Smaller radius**

Preserves more of the sample near its edges.

**Larger radius**

Removes a wider boundary region and reduces the influence of edge artefacts.

A value that is too large will unnecessarily reduce the usable analysis area.

---

## `processIn3D`

```matlab
processIn3D = true;
```

Determines how disconnected structures are removed when the initial surface is detected.

### 3-D mode

```matlab
processIn3D = true;
```

The binary dataset is analysed as a complete 3-D volume.

Connected objects are identified using 3-D connectivity, and the **largest connected component is retained**.

Advantages:

- uses connectivity between neighbouring slices
- generally produces a more spatially consistent segmentation
- removes isolated objects that are not connected to the main bone structure

Disadvantage:

- requires more memory

This is the preferred mode when sufficient RAM is available.

### 2-D mode

```matlab
processIn3D = false;
```

Cleaning is performed plane-by-plane rather than on the entire connected 3-D object.

Advantages:

- lower memory requirement
- useful for very large image stacks

Disadvantages:

- does not use full 3-D connectivity
- objects may be treated differently between neighbouring planes

Use 2-D mode primarily when the complete volume is too large to process comfortably in memory.

---

## Parameter interactions

Several settings should not be interpreted independently.

### Pixel size and binning

```text
nativePixelSize_um
        +
     binning
        ↓
effective pixel size
```

The effective pixel size is then used to convert physical parameters such as `radius_um` into pixels.

### Local BV/TV segmentation

The main local segmentation behaviour is controlled by:

```text
radius_um
    +
removalPercentage
```

`radius_um` determines **how large an area is examined**, while `removalPercentage` determines **how much bone must exist inside that area**.

### Initial lower boundary

```text
ratioLimit
```

controls the preliminary estimate of where dense subchondral bone transitions toward trabecular bone.

The local BV/TV cleaning step then refines this initial extracted region.

---

## Suggested starting point

For a new dataset, first verify:

```text
1. Z orientation
2. Pixel size
3. Threshold
```

before tuning segmentation parameters.

A reasonable workflow is:

```text
Correct orientation
      ↓
Check thresholding
      ↓
Check upper/lower surfaces
      ↓
Adjust radius_um
      ↓
Adjust removalPercentage
      ↓
Fine-tune ratioLimit if necessary
```

Avoid changing many parameters simultaneously. Changing one parameter at a time makes it easier to understand its effect on the segmentation.
