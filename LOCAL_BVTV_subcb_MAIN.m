%% Subchondral plate segmentation
%
% This script:
%   1. Loads one or more image stacks.
%   2. Creates a surface height map.
%   3. Estimates the lower boundary of the subchondral plate.
%   4. Extracts the volume between the two surfaces.
%   5. Removes trabecular structures using a circular neighbourhood.
%   6. Saves the segmented volume and all generated figures.
%
% Physical dimensions are defined in micrometres whenever possible.
% Values are converted to pixels internally when required by the
% image-processing functions.

clearvars;
close all;
clc;


%% ------------------------------------------------------------------------
%  USER SETTINGS
%  ------------------------------------------------------------------------

% Input image format.
dataFormat = '\*.bmp';

% Image orientation.
flipH = false;             % true = flip images horizontally during loading
flipZ = false;              % true = reverse the Z direction after loading

% Spatial binning.
% Allowed values: 0 (no binning), 2, 3, or 4.
binning = 0;

% Native XY pixel size of the original images [micrometres/pixel].
nativePixelSize_um = 14.84;

% Radius used for trabecular-removal neighbourhood [micrometres].
%
% This replaces the old:
%     radius_size = 20;
%
% At 11.2 um/pixel, 224 um corresponds to 20 pixels.
radius_um = 300;

% Maximum hole area to fill [um^2].
holeArea_um2 = 1000;

% Fraction of voxels within the circular neighbourhood that must satisfy
% the trabecular-removal criterion.
removalPercentage = 0.80;

% Initial ratio used for detecting the lower subchondral surface.
% Typical values to test are approximately 0.3-0.7.
ratioLimit = 0.50;

% Surface smoothing parameters.
gaussianKernelSize_px = 30;

% Number of iterations/size parameter passed to FillNaNs.
nanFillParameter = 100;

% Radius of the erosion operation used to reduce the ROI mask [pixels].
erosionRadius_px = 3;

% Processing mode:
% true  = perform cleaning using the 3-D volume
% false = process in 2-D if memory is limited
processIn3D = true;

% Trabecular-removal diagnostic options.
visualizeTrabecularRemoval = true;
saveTrabecularRemovalImages = true;
save3Dvideo=true;

%% ------------------------------------------------------------------------
%  THRESHOLD SETTINGS
%  ------------------------------------------------------------------------

% Set this to true to use Threshold_test instead of a fixed threshold.
useAutomaticThreshold = true;

% Threshold used when useAutomaticThreshold = false.
manualThreshold = 0.5;

% Multiplier applied by Threshold_test when automatic thresholding is used.
thresholdMultiplier = 1.0;


%% ------------------------------------------------------------------------
%  VALIDATE SETTINGS AND CALCULATE PIXEL-BASED PARAMETERS
%  ------------------------------------------------------------------------

validBinningValues = [0, 2, 3, 4];

assert(ismember(binning, validBinningValues), ...
    'binning must be 0, 2, 3, or 4.');

assert(nativePixelSize_um > 0, ...
    'nativePixelSize_um must be greater than zero.');

assert(radius_um > 0, ...
    'radius_um must be greater than zero.');

% A binning value of 0 means no binning, i.e. a binning factor of 1.
if binning == 0
    binningFactor = 1;
else
    binningFactor = binning;
end

% Effective pixel size after binning.
%
% Example:
%   Original pixel size = 11.2 um/pixel
%   2x binning          = 22.4 um/pixel
effectivePixelSize_um = nativePixelSize_um * binningFactor;

% Convert the physical trabecular-removal radius from micrometres to pixels.
%
% RemoveTrabecular_parallel2 expects an integer pixel radius, so the
% physical radius is rounded to the nearest available pixel.
radius_size_px = max(1, round(radius_um / effectivePixelSize_um));

% Padding is required around the image because the trabecular-removal
% algorithm evaluates neighbourhoods close to the image borders.
paddingSize_px = radius_size_px * 2;

fprintf('Requested neighbourhood radius: %.1f um\n', radius_um);
fprintf('Effective pixel size: %.2f um/pixel\n', effectivePixelSize_um);
fprintf('Neighbourhood radius used: %d pixels (%.1f um)\n', ...
    radius_size_px, radius_size_px * effectivePixelSize_um);


%% ------------------------------------------------------------------------
%  SELECT SAMPLE FOLDERS
%  ------------------------------------------------------------------------

folders = uipickfiles( ...
    'FilterSpec', 'D:\', ...
    'Output', 'struct');

% Exit cleanly if no folders were selected.
if isempty(folders)
    fprintf('No folders selected. Processing cancelled.\n');
    return;
end


%% ------------------------------------------------------------------------
%  PROCESS EACH SAMPLE
%  ------------------------------------------------------------------------

for i = 1:numel(folders)

    close all;

    sampleFolder = folders(i).name;

    fprintf('\n============================================================\n');
    fprintf('Processing sample %d of %d\n', i, numel(folders));
    fprintf('%s\n', sampleFolder);
    fprintf('============================================================\n');


    %% Create output folders

    % Height maps are stored in the sample folder.
    heightmapFolder = fullfile(sampleFolder, 'Heightmaps');

    % Figures generated during processing are stored separately.
    figureFolder = fullfile(sampleFolder, 'Figures');

    if ~exist(heightmapFolder, 'dir')
        mkdir(heightmapFolder);
    end

    if ~exist(figureFolder, 'dir')
        mkdir(figureFolder);
    end


    %% Load image volume

    % The trailing file separator is retained because some of the custom
    % volume-loading functions may expect a folder path ending in "\".
    selectedPath = [sampleFolder, filesep];

    [vol, fname, ~] = Universal_volumeloader_02348_16bit( ...
        selectedPath, ...
        binning, ...
        i, ...
        numel(folders), ...
        dataFormat, ...
        flipH);

    % Reverse stack direction when required.
    if flipZ
        vol = flip(vol, 3);
    end


    %% Determine threshold

    if useAutomaticThreshold

        % Threshold_test may also generate diagnostic figures.
        thresh = Threshold_test( ...
            vol, ...
            [heightmapFolder, filesep], ...
            fname, ...
            thresholdMultiplier);

    else
        thresh = manualThreshold;
    end


    %% Pad volume

    % Padding prevents circular neighbourhood operations close to the
    % image boundaries from being truncated.
    vol = padder(vol, paddingSize_px, 'add');


    %% Extract upper surface / height map

    heightmap = Universal_roi_image_maker( ...
        vol, ...
        processIn3D, ...
        thresh);

    % Save MATLAB height-map data.
    heightmapFile = fullfile( ...
        heightmapFolder, ...
        [fname, '_heightmap.mat']);

    save(heightmapFile, 'heightmap');


    %% --------------------------------------------------------------------
    %  CREATE ROI MASK FROM HEIGHT MAP
    %  ---------------------------------------------------------------------

    % Valid height-map pixels define the initial XY region of interest.
    maskHeightmap = ~isnan(heightmap);

    % Median filtering removes isolated pixels and reduces small
    % irregularities along the mask boundary.
    filteredMask = medfilt2( ...
        maskHeightmap, ...
        [3, 3], ...
        'symmetric');

    % Erode the mask slightly to avoid unreliable measurements directly at
    % the outer edge of the sample.
    erosionSE = strel('disk', erosionRadius_px);

    erodedMask = imerode(filteredMask, erosionSE);


    %% Visualize ROI-mask processing

    figure( ...
        'Name', [fname, '_ROI_mask_erosion'], ...
        'NumberTitle', 'off');

    imshowpair(maskHeightmap, erodedMask);

    title('Original ROI mask vs. eroded ROI mask');


    %% --------------------------------------------------------------------
    %  CREATE BINARY VOLUME
    %  ---------------------------------------------------------------------

    % Threshold the grayscale volume.
    binaryVolume = imbinarize(vol, thresh);

    % Remove isolated foreground voxels.
    binaryVolume = bwmorph3(binaryVolume, 'clean');

    % Fill small holes in the volume.
    %
    % effectivePixelSize_um is used instead of the original pixel size so
    % that physical dimensions remain correct when binning is enabled.
    binaryVolume = fill_holes_2D_planes( ...
        binaryVolume, ...
        holeArea_um2, ...
        effectivePixelSize_um);


    %% --------------------------------------------------------------------
    %  ESTIMATE LOWER SUBCHONDRAL SURFACE
    %  ---------------------------------------------------------------------

    lowpoints = getlowpoints( ...
        heightmap, ...
        maskHeightmap, ...
        binaryVolume, ...
        ratioLimit);


    %% Fill missing surface values

    filledUpperSurface = FillNaNs( ...
        heightmap, ...
        nanFillParameter,'scb (average), green = NaN');

    filledLowerSurface = FillNaNs( ...
        lowpoints, ...
        nanFillParameter,'beneath scb (average), green = NaN');


    %% Smooth upper and lower surfaces

    smoothUpperSurface = smoothsurfaceGAUSS( ...
        filledUpperSurface, ...
        gaussianKernelSize_px);

    % Preserve the one-voxel offset used in the original processing
    % workflow.
    smoothUpperSurface = smoothUpperSurface + 1;

    smoothLowerSurface = smoothsurfaceGAUSS( ...
        filledLowerSurface, ...
        gaussianKernelSize_px);


    %% Restrict surfaces to the eroded ROI

    smoothLowerSurface = smoothLowerSurface .* erodedMask;
    smoothLowerSurface(smoothLowerSurface == 0) = NaN;

    smoothUpperSurface = smoothUpperSurface .* erodedMask;
    smoothUpperSurface(smoothUpperSurface == 0) = NaN;


    %% --------------------------------------------------------------------
    %  EXTRACT SUBCHONDRAL VOLUME
    %  ---------------------------------------------------------------------

    % Extract voxels located between the smoothed upper and lower surfaces.
    extractedVolume = ExtractVolume( ...
        vol, ...
        smoothUpperSurface, ...
        smoothLowerSurface);


    %% --------------------------------------------------------------------
    %  REMOVE TRABECULAR STRUCTURES
    %  ---------------------------------------------------------------------

    % The neighbourhood radius is supplied in pixels here because
    % RemoveTrabecular_parallel2 operates on image coordinates.
    %
    % radius_size_px was calculated automatically from:
    %
    %     radius_um / effectivePixelSize_um
    %

    cleanedVolume = RemoveTrabecular_parallel( ...
    extractedVolume, smoothUpperSurface, radius_size_px, effectivePixelSize_um, visualizeTrabecularRemoval, removalPercentage, saveTrabecularRemovalImages, figureFolder);
if save3Dvideo 
 SweepHeightmapThroughVolume( ...
    extractedVolume, smoothUpperSurface, 1, 1, figureFolder, 45, 20);
else 
end

    %% Remove padding

    cleanedVolume = padder( ...
        cleanedVolume, ...
        paddingSize_px, ...
        'remove');


    %% Restore original Z orientation

    if flipZ
        cleanedVolume = flip(cleanedVolume, 3);
    end


    %% --------------------------------------------------------------------
    %  SAVE SEGMENTED VOLUME
    %  ---------------------------------------------------------------------

    outputExtension = 'bmp';

    outputFolder = fullfile( ...
        sampleFolder, ...
        'subCB');

    [~, sampleName, ~] = fileparts(sampleFolder);

    SaveVolumeToFolder( ...
        cleanedVolume, ...
        outputFolder, ...
        sampleName, ...
        outputExtension);


    %% --------------------------------------------------------------------
    %  SAVE ALL OPEN FIGURES
    %  ---------------------------------------------------------------------

    % Save every figure generated while processing this sample.
    %
    % Assumption:
    % saveAllOpenFigures accepts the destination folder as its input:
    %
    %     saveAllOpenFigures(outputFolder)
    %
    % If your existing function has a different calling syntax, only this
    % line needs to be changed.
    saveAllOpenFigures(figureFolder);


    fprintf('Finished processing: %s\n', sampleName);

end


fprintf('\nAll selected samples have been processed.\n');