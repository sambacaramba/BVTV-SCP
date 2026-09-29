# BVTV-SCP

**Local BV/TV-based segmentation of the subchondral plate from trabecular bone in 3-D µCT image stacks.**



## How it works

BVTV-SCP detects the upper subchondral surface, searches downward through the bone, and removes regions that do not satisfy the local bone-volume fraction criterion.

**Input → surface detection → lower boundary detection → trabecular removal → subchondral plate**

## Input orientation

Input data should be an ordered image sequence with running slice numbers, for example:

sample_0001.bmp
sample_0002.bmp
sample_0003.bmp
...
sample_NNNN.bmp

The algorithm expects the subchondral surface to be near the end of the image stack. If this is already the case, use:

flipZ = false;

If the subchondral surface is near the start of the image stack, reverse the Z direction before processing:

flipZ = true;

This ensures that surface detection starts from the correct side of the volume.

## Quick start

1. Place each µCT image stack in its own folder.
2. Open `LOCAL_BVTV_subcb_MAIN.m`.
3. Set the parameters below.
4. Run the script.
5. Select one or more sample folders when prompted.

## Main settings

| Setting | Description | Example |
|---|---|---:|
| `dataFormat` | Input image format (.png, .bmp, .tif (8 or 16bit)) | `'\*.bmp'` |
| `flipH` | Flip images horizontally | `false` |
| `flipZ` | Reverse Z direction | `false` |
| `binning` | Spatial binning: `0`, `2`, `3`, or `4` | `0` |
| `nativePixelSize_um` | Original pixel size [µm/pixel] | `14.84` |
| `radius_um` | Local BV/TV neighbourhood radius [µm] | `300` |
| `holeArea_um2` | Maximum filled hole area [µm²] | `1000` |
| `removalPercentage` | Local BV/TV removal threshold | `0.80` |
| `ratioLimit` | Initial lower-surface detection ratio | `0.50` |
| `gaussianKernelSize_px` | Surface smoothing kernel [px] | `30` |
| `nanFillParameter` | NaN-filling neighbourhood size [px] | `100` |
| `erosionRadius_px` | ROI erosion radius [px] | `3` |
| `processIn3D` | 3-D cleaning (keep largest connected component) | `true` |

Typical values for `ratioLimit` are approximately **0.3–0.7**.

## Threshold

Automatic Otsu-based thresholding:

```matlab
useAutomaticThreshold = true;
thresholdMultiplier = 1.0;
```

Or use a fixed normalized threshold:

```matlab
useAutomaticThreshold = false;
manualThreshold = 0.5;
```

The automatic mode generates a diagnostic figure showing nearby threshold choices.
<img width="533" height="1200" alt="01_Threshold_comparison_ds" src="https://github.com/user-attachments/assets/3e6a8ffd-1caf-4ce9-9c65-df1006409fee" />

An automatic output of thresholding and surface detection is shown from one slice from the middle of the stack to see if surface is detected from the correct place
<img width="1546" height="2131" alt="05_ROI_segmentation_and_surface_detection" src="https://github.com/user-attachments/assets/b4d4bb7e-0186-427f-8a64-5bacc5a11158" />


## Segmentation workflow

The segmentation is performed in four main steps:

**1. Surface detection → 2. Lower boundary estimation → 3. Volume extraction → 4. Local BV/TV cleaning**

1. **Surface detection**
   The upper surface of the subchondral bone is detected from the thresholded image stack and represented as a height map.

2. **Lower boundary estimation**
   Starting from the detected surface, the algorithm searches deeper into the bone and estimates where the dense subchondral plate transitions into trabecular bone.

3. **Volume extraction**
   The image volume between the upper and lower surfaces is extracted as the initial subchondral plate region.

4. **Local BV/TV cleaning**
   The extracted region is scanned layer by layer. At each location, the fraction of bone inside a circular local neighbourhood is calculated. Regions with a low local bone fraction are considered trabecular-like and removed.

   With:

   ```matlab
   removalPercentage = 0.80;
   ```

   a location is retained only when at least **80% of its valid local neighbourhood contains bone**.

---

## Visualization

```matlab
visualizeTrabecularRemoval = true;
saveTrabecularRemovalImages = true;
save3Dvideo = true;
```

`visualizeTrabecularRemoval` shows the local BV/TV cleaning while the algorithm is running.

`saveTrabecularRemovalImages` saves each intermediate cleaning step as an image frame. This is useful for creating an animation, but increases processing time and disk usage.

`save3Dvideo` saves frames from the 3-D visualization.

### Local BV/TV trabecular removal

You might need to try different radius sizes for your data. Although this algorithm works really well for the data we have tested, the amount of tests are still limited so play around with different settings and check what results you get. think about what is seen inside the circle (must be larger than a typical trabeculae but as small as possible to have high precision near the bone border) 
The red circle shows the local neighbourhood used for the BV/TV calculation. As the algorithm moves deeper through the volume, regions that do not meet the selected local bone-fraction threshold are removed (green).

[https://github.com/user-attachments/assets/a65ce99d-0514-4142-9800-220031b9ebe2](https://github.com/user-attachments/assets/a65ce99d-0514-4142-9800-220031b9ebe2)

---

## Output

Each sample folder receives output folders such as:

```text
Sample/
├── Figures/
│   ├── removalframes/
│   └── sweepframes/
├── Heightmaps/
└── subCB/
```

`subCB/` contains the final segmented subchondral plate image stack. 

### 3-D segmentation preview

The 3-D visualization shows the segmented volume together with the detected surfaces and can be used to inspect the segmentation from different viewing angles.

[https://github.com/user-attachments/assets/99eb28f8-4621-4c23-ac10-99e9f0df7f70](https://github.com/user-attachments/assets/99eb28f8-4621-4c23-ac10-99e9f0df7f70)


## Requirements

- MATLAB
- Image Processing Toolbox
- Parallel Computing Toolbox for parallel processing
- `uipickfiles`

## Third-party code

Folder selection uses:

> Douglas Schwarz (2026). **uipickfiles: uigetfile on steroids.** MATLAB Central File Exchange. Retrieved September 28, 2026.

https://www.mathworks.com/matlabcentral/fileexchange/10867-uipickfiles-uigetfile-on-steroids






