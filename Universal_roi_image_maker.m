% Copyright 2026 Sami Kauppinen (sami.kauppinen(at)oulu.fi)

function [heightmap, T, C] = Universal_roi_image_maker(vol, dimension, threshold)
%UNIVERSAL_ROI_IMAGE_MAKER Extract the upper surface of a segmented volume.
%
%   [heightmap, T, C] = Universal_roi_image_maker(vol, dimension, threshold)
%
%   The function thresholds a 3-D image volume and estimates its upper
%   surface by finding the highest foreground voxel at each XY position.
%
%   Two cleaning approaches are available:
%
%       dimension = 0
%           Clean individual 2-D planes using bwareaopen.
%
%       dimension = 1
%           Retain only the largest connected 3-D foreground object.
%
%   A diagnostic XZ image is also generated:
%
%       Grayscale = original image data
%       Yellow    = segmented foreground
%       Red       = detected upper surface
%
%
% INPUTS
%   vol
%       M-by-N-by-Z grayscale image volume.
%
%   dimension
%       Cleaning mode:
%           0 = clean individual 2-D planes
%           1 = retain largest connected object in 3-D
%
%   threshold
%       Normalized threshold in the range [0,1], as expected by
%       imbinarize.
%
%
% OUTPUTS
%   heightmap
%       M-by-N surface map containing the detected upper Z-coordinate.
%
%       NOTE:
%       The existing pipeline uses zero-based Z-coordinates:
%
%           heightmap = MATLAB Z-index - 1
%
%       Therefore heightmap values range from 0 to Z-1.
%
%       Locations without detected foreground contain NaN.
%
%   T
%       Threshold used for segmentation.
%
%   C
%       RGB diagnostic image:
%
%           grayscale background = original image
%           yellow               = segmented foreground
%           red                  = detected surface
%
%
% REQUIREMENTS
%   MATLAB Image Processing Toolbox


%% ------------------------------------------------------------------------
%  SETTINGS
%  -------------------------------------------------------------------------

% Minimum connected-object size for the 2-D cleaning method.
minObjectArea2D_px = 1000;

% Y-position used for the diagnostic XZ cross-section.
diagnosticSliceFraction = 1 / 3;

% Transparency of the yellow segmentation overlay.
%
% 0 = fully transparent
% 1 = fully yellow
segmentationOpacity = 0.65;

% Thickness of the red surface line in the Z direction.
surfaceThickness_px = 1;


%% ------------------------------------------------------------------------
%  VALIDATE INPUTS
%  -------------------------------------------------------------------------

if ndims(vol) ~= 3
    error('vol must be a 3-D image volume.');
end

if isempty(vol)
    error('vol must not be empty.');
end

if ~(isscalar(dimension) && ismember(dimension, [0, 1]))
    error('dimension must be either 0 (2-D) or 1 (3-D).');
end

if ~(isscalar(threshold) && isfinite(threshold) && ...
        threshold >= 0 && threshold <= 1)

    error('threshold must be a scalar value between 0 and 1.');

end


%% ------------------------------------------------------------------------
%  INITIALIZE
%  -------------------------------------------------------------------------

[rows, cols, numSlices] = size(vol);

% Return the threshold used by this function.
T = threshold;


%% ------------------------------------------------------------------------
%  SELECT DIAGNOSTIC CROSS-SECTION
%  -------------------------------------------------------------------------

% Select an XZ cross-section approximately one-third through the Y
% direction.
diagnosticY = max( ...
    1, ...
    min(cols, floor(cols * diagnosticSliceFraction)));


% Extract the ORIGINAL grayscale XZ image before clearing the full volume.
%
% Input:
%       vol(row, diagnosticY, Z)
%
% Result:
%       diagnosticImage(row, Z)
diagnosticImage = permute( ...
    vol(:, diagnosticY, :), ...
    [1, 3, 2]);


%% ------------------------------------------------------------------------
%  BINARIZE VOLUME
%  -------------------------------------------------------------------------

vol_bin = imbinarize(vol, threshold);

% Remove isolated foreground voxels.
vol_bin = bwmorph3(vol_bin, 'clean');


% The full grayscale volume is no longer required.
clear vol;


%% ------------------------------------------------------------------------
%  INITIALIZE HEIGHT MAP
%  -------------------------------------------------------------------------

% NaN represents XY locations where no surface has been detected.
heightmap = nan(rows, cols);


%% ------------------------------------------------------------------------
%  CLEAN SEGMENTATION
%  -------------------------------------------------------------------------

if dimension == 0

    %% ====================================================================
    %  2-D CLEANING
    %  =====================================================================

    % Reorient the volume so each XZ plane is stored along dimension 3.
    vol_bin = permute(vol_bin, [1, 3, 2]);


    % Remove small objects independently from each 2-D plane.
    for sliceIndex = 1:size(vol_bin, 3)

        vol_bin(:, :, sliceIndex) = bwareaopen( ...
            vol_bin(:, :, sliceIndex), ...
            minObjectArea2D_px, ...
            8);

    end


    % Restore original X-Y-Z orientation.
    vol_bin = permute(vol_bin, [1, 3, 2]);


    % The cleaned binary volume is the segmentation used for surface
    % detection.
    segmentedVolume = vol_bin;


    %% Find upper surface

    for z = numSlices:-1:1

        currentSlice = segmentedVolume(:, :, z);

        % Only assign coordinates that do not yet have a detected surface.
        unassigned = isnan(heightmap);

        % Preserve the existing zero-based Z-coordinate convention.
        heightmap(unassigned & currentSlice) = z - 1;

    end


else

    %% ====================================================================
    %  3-D CLEANING
    %  =====================================================================

    % Find 3-D connected foreground components.
    connectedObjects = bwconncomp(vol_bin, 26);


    %% Handle empty segmentation

    if connectedObjects.NumObjects == 0

        warning( ...
            'Universal_roi_image_maker:NoForeground', ...
            ['No foreground objects were detected at threshold %.4f. ', ...
             'The returned heightmap contains only NaN values.'], ...
            threshold);


        % Create an empty segmentation so the diagnostic image can still
        % be generated.
        segmentedVolume = false(rows, cols, numSlices);

    else

        %% Find largest connected object

        objectSizes = cellfun( ...
            @numel, ...
            connectedObjects.PixelIdxList);

        [~, largestObjectIndex] = max(objectSizes);


        % Retain only the largest connected component.
        segmentedVolume = false(rows, cols, numSlices);

        segmentedVolume( ...
            connectedObjects.PixelIdxList{largestObjectIndex}) = true;


        %% Find upper surface

        for z = numSlices:-1:1

            currentSlice = segmentedVolume(:, :, z);

            unassigned = isnan(heightmap);

            % Preserve zero-based Z-coordinate convention.
            heightmap(unassigned & currentSlice) = z - 1;

        end

    end


    clear vol_bin connectedObjects;

end


%% ------------------------------------------------------------------------
%  CREATE DIAGNOSTIC XZ IMAGE
%  -------------------------------------------------------------------------

% Extract the cleaned binary segmentation at the same Y-coordinate as the
% original diagnostic image.
diagnosticBinary = permute( ...
    segmentedVolume(:, diagnosticY, :), ...
    [1, 3, 2]);


% Normalize the original grayscale image to [0,1] for RGB visualization.
grayImage = mat2gray(diagnosticImage);


% Convert grayscale image to RGB.
C = repmat(grayImage, [1, 1, 3]);


%% ------------------------------------------------------------------------
%  ADD YELLOW SEGMENTATION OVERLAY
%  -------------------------------------------------------------------------

% Yellow RGB:
%
%       R = 1
%       G = 1
%       B = 0
yellow = [1, 1, 0];


% Blend the segmentation with the grayscale image so the underlying
% intensity information remains visible.
for channel = 1:3

    currentChannel = C(:, :, channel);

    currentChannel(diagnosticBinary) = ...
        (1 - segmentationOpacity) .* ...
        currentChannel(diagnosticBinary) + ...
        segmentationOpacity .* yellow(channel);

    C(:, :, channel) = currentChannel;

end


%% ------------------------------------------------------------------------
%  ADD DETECTED SURFACE IN RED
%  -------------------------------------------------------------------------

% No 3-D surface volume needs to be created here.
%
% The diagnostic image is an XZ cross-section at diagnosticY, so the
% corresponding surface is simply:
%
%       heightmap(:, diagnosticY)
%
% Each value gives the Z-coordinate of the surface for a particular row.
surfaceZ = heightmap(:, diagnosticY);


% Find rows where a valid surface was detected.
validRows = find(~isnan(surfaceZ));


for i = 1:numel(validRows)

    row = validRows(i);


    % Height-map coordinates use the existing zero-based convention.
    %
    % Convert back to MATLAB's one-based array index:
    %
    %       heightmap Z = 0  -> MATLAB slice 1
    %       heightmap Z = 1  -> MATLAB slice 2
    %       ...
    zIndex = round(surfaceZ(row)) + 1;


    % Make sure the coordinate lies inside the diagnostic image.
    if zIndex >= 1 && zIndex <= numSlices

        % Give the line a small thickness so it is clearly visible in the
        % diagnostic image.
        zStart = max( ...
            1, ...
            zIndex - surfaceThickness_px);

        zEnd = min( ...
            numSlices, ...
            zIndex + surfaceThickness_px);


        % Paint surface pixels RED.
        C(row, zStart:zEnd, 1) = 1;
        C(row, zStart:zEnd, 2) = 0;
        C(row, zStart:zEnd, 3) = 0;

    end

end


%% ------------------------------------------------------------------------
%  DISPLAY DIAGNOSTIC IMAGE
%  -------------------------------------------------------------------------

figure( ...
    'Name', 'ROI segmentation and surface detection', ...
    'NumberTitle', 'off', ...
    'Color', 'black');


imshow(C);


title({ ...
    sprintf('Threshold = %.4f', threshold), ...
    'Yellow = segmented volume   |   Red = detected surface'}, ...
    'Color', 'white', ...
    'Interpreter', 'none');


%% ------------------------------------------------------------------------
%  CLEAN UP
%  -------------------------------------------------------------------------

clear segmentedVolume diagnosticBinary diagnosticImage;

end