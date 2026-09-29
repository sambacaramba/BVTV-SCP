% Copyright 2024 Sami Kauppinen (sami.kauppinen(at)oulu.fi)

function thresh = Threshold_test(vol, savepath, filename, mult)
%THRESHOLD_TEST Calculate and visualize an Otsu-based threshold.
%
%   thresh = Threshold_test(vol, savepath, filename, mult)
%
%   Calculates a global Otsu threshold for a 3-D image volume and displays
%   several nearby threshold values for visual comparison.
%
%   For each tested threshold, three orthogonal views are shown:
%
%       Z-plane   XY cross-section
%       X-plane   ZY cross-section
%       Y-plane   XZ cross-section
%
%   The three views are combined into a single image strip so that images
%   with different dimensions can be displayed compactly without large
%   amounts of unused subplot space.
%
% INPUTS
%   vol
%       M-by-N-by-Z image volume.
%
%       Logical volumes are downsampled using nearest-neighbour
%       interpolation to preserve binary values.
%
%       Other datatypes are downsampled using linear interpolation.
%
%   savepath
%       Folder in which the threshold-comparison figure is saved.
%
%   filename
%       Sample/file name used in the figure title and output filename.
%
%   mult
%       Multiplier applied to the automatically calculated Otsu threshold.
%
%       Five multiplier values are visualized:
%
%           mult - 0.2
%           mult - 0.1
%           mult
%           mult + 0.1
%           mult + 0.2
%
% OUTPUT
%   thresh
%       Selected threshold in normalized intensity units [0,1].
%
% EXAMPLE
%   thresh = Threshold_test(vol, figureFolder, sampleName, 1.0);


%% ------------------------------------------------------------------------
%  VALIDATE INPUTS
%  -------------------------------------------------------------------------

if ndims(vol) ~= 3
    error('Input volume must be a 3-D array.');
end

if mult <= 0
    error('Threshold multiplier must be greater than zero.');
end

if ~exist(savepath, 'dir')
    mkdir(savepath);
end


%% ------------------------------------------------------------------------
%  CALCULATE OTSU THRESHOLD
%  -------------------------------------------------------------------------

% graythresh returns a normalized threshold between 0 and 1.
otsuThreshold = graythresh(vol);

% Apply the user-defined multiplier.
thresh = otsuThreshold * mult;

% Keep the threshold inside the valid range expected by imbinarize.
thresh = min(max(thresh, 0), 1);

fprintf('Otsu threshold: %.4f\n', otsuThreshold);
fprintf('Threshold multiplier: %.2f\n', mult);
fprintf('Selected threshold: %.4f\n', thresh);


%% ------------------------------------------------------------------------
%  DOWNSAMPLE VOLUME FOR VISUALIZATION
%  -------------------------------------------------------------------------

% The threshold comparison does not require the full-resolution volume.
% Downsampling substantially reduces memory usage and plotting time.
%
% Binary/logical data must use nearest-neighbour interpolation so that new
% intermediate intensity values are not introduced.
if islogical(vol)

    resizeMethod = 'nearest';

else

    resizeMethod = 'linear';

end

volSmall = imresize3( ...
    vol, ...
    0.5, ...
    'Method', resizeMethod);

% The original full-resolution volume is no longer needed inside this
% function.
clear vol;


%% ------------------------------------------------------------------------
%  DETERMINE CROSS-SECTION LOCATIONS
%  -------------------------------------------------------------------------

[dimX, dimY, dimZ] = size(volSmall);

% Z-plane: approximately halfway through the stack.
sliceZ = max(1, floor(dimZ / 2));

% X-plane: approximately halfway through the first dimension.
sliceX = max(1, floor(dimX / 2));

% Y-plane:
%
% The original function used dimY / 3.5 rather than the middle of the
% volume. This behaviour is preserved here.
sliceY = max(1, floor(dimY / 3.5));


%% ------------------------------------------------------------------------
%  EXTRACT GRAYSCALE REFERENCE VIEWS
%  -------------------------------------------------------------------------

% Z-plane: XY view.
grayZ = volSmall(:, :, sliceZ);


% X-plane: ZY view.
permutedVolumeX = permute(volSmall, [3, 2, 1]);
grayX = permutedVolumeX(:, :, sliceX);


% Y-plane: XZ view.
permutedVolumeY = permute(volSmall, [1, 3, 2]);
grayY = permutedVolumeY(:, :, sliceY);


%% ------------------------------------------------------------------------
%  DETERMINE COMMON VIEW SIZE
%  -------------------------------------------------------------------------

% Each of the three anatomical views can have different dimensions.
%
% The combined image consists of three equally sized sections:
%
%   |----- Z -----|----- X -----|----- Y -----|
%
% Each section has:
%
%   height = maximum height of the three views
%   width  = maximum width of the three views
%
% The individual images are centered inside their respective sections and
% unused pixels remain black.

viewHeights = [ ...
    size(grayZ, 1), ...
    size(grayX, 1), ...
    size(grayY, 1)];

viewWidths = [ ...
    size(grayZ, 2), ...
    size(grayX, 2), ...
    size(grayY, 2)];

maxViewHeight = max(viewHeights);
maxViewWidth  = max(viewWidths);

combinedImageWidth = 3 * maxViewWidth;


%% ------------------------------------------------------------------------
%  THRESHOLD VALUES TO VISUALIZE
%  -------------------------------------------------------------------------

% Using an explicit offset vector guarantees exactly five comparisons and
% avoids possible floating-point issues with colon notation.
testMultipliers = mult + (-2:2) * 0.1;

nThresholds = numel(testMultipliers);


%% ------------------------------------------------------------------------
%  CREATE FIGURE
%  -------------------------------------------------------------------------

screenSize = get(0, 'ScreenSize');

screenWidth  = screenSize(3);
screenHeight = screenSize(4);


% Determine an approximate figure aspect ratio from the actual montage
% dimensions.
%
% There is one three-view strip for every tested threshold.
contentWidth  = combinedImageWidth;
contentHeight = maxViewHeight * nThresholds;


% Maximum available figure size.
maxFigureWidth  = round(screenWidth  * 0.90);
maxFigureHeight = round(screenHeight * 0.90);


% Scale the figure while preserving the approximate content aspect ratio.
displayScale = min([ ...
    maxFigureWidth  / contentWidth, ...
    maxFigureHeight / contentHeight]);


figureWidth = round(contentWidth * displayScale);
figureHeight = round(contentHeight * displayScale);


% Prevent extremely small figures if the input volume has unusual
% dimensions.
figureWidth  = max(figureWidth, 600);
figureHeight = max(figureHeight, 500);


% Ensure the final figure still fits on the screen.
figureWidth  = min(figureWidth, maxFigureWidth);
figureHeight = min(figureHeight, maxFigureHeight);


f = figure( ...
    'Units', 'pixels', ...
    'Position', [ ...
        round((screenWidth - figureWidth) / 2), ...
        round((screenHeight - figureHeight) / 2), ...
        figureWidth, ...
        figureHeight], ...
    'Color', 'black', ...
    'InvertHardcopy', 'off', ...
    'Name', 'Threshold comparison', ...
    'NumberTitle', 'off');


%% ------------------------------------------------------------------------
%  CREATE COMPACT TILE LAYOUT
%  -------------------------------------------------------------------------

t = tiledlayout( ...
    f, ...
    nThresholds, ...
    1, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');


%% ------------------------------------------------------------------------
%  GENERATE THRESHOLD COMPARISONS
%  -------------------------------------------------------------------------

for k = 1:nThresholds

    currentMultiplier = testMultipliers(k);


    %% Calculate candidate threshold

    candidateThreshold = ...
        otsuThreshold * currentMultiplier;

    % Keep threshold within the valid imbinarize range.
    candidateThreshold = ...
        min(max(candidateThreshold, 0), 1);


    %% Threshold the downsampled volume

    binaryVolume = imbinarize( ...
        volSmall, ...
        candidateThreshold);


    %% ---------------------------------------------------------------
    %  Z-PLANE
    %  ---------------------------------------------------------------

    binaryZ = binaryVolume(:, :, sliceZ);

    fusedZ = imfuse( ...
        grayZ, ...
        binaryZ);


    %% ---------------------------------------------------------------
    %  X-PLANE
    %  ---------------------------------------------------------------

    permutedBinaryX = permute( ...
        binaryVolume, ...
        [3, 2, 1]);

    binaryX = permutedBinaryX(:, :, sliceX);

    fusedX = imfuse( ...
        grayX, ...
        binaryX);


    %% ---------------------------------------------------------------
    %  Y-PLANE
    %  ---------------------------------------------------------------

    permutedBinaryY = permute( ...
        binaryVolume, ...
        [1, 3, 2]);

    binaryY = permutedBinaryY(:, :, sliceY);

    fusedY = imfuse( ...
        grayY, ...
        binaryY);


    %% ---------------------------------------------------------------
    %  COMBINE THE THREE VIEWS INTO ONE IMAGE
    %  ---------------------------------------------------------------

    combinedImage = createThreeViewStrip( ...
        fusedZ, ...
        fusedX, ...
        fusedY, ...
        maxViewHeight, ...
        maxViewWidth);


    %% ---------------------------------------------------------------
    %  DISPLAY COMBINED IMAGE
    %  ---------------------------------------------------------------

    ax = nexttile(t);

    imshow( ...
        combinedImage, ...
        'Parent', ax);

    hold(ax, 'on');


    %% Add labels to each view

    % X-coordinate of the centre of each one-third section.
    zLabelX = 0.5 * maxViewWidth;
    xLabelX = 1.5 * maxViewWidth;
    yLabelX = 2.5 * maxViewWidth;

    % Place labels near the top of the combined image.
    labelY = max(5, round(maxViewHeight * 0.03));


    text( ...
        ax, ...
        zLabelX, ...
        labelY, ...
        sprintf('Threshold: %.2f   Z-plane', currentMultiplier), ...
        'Color', 'white', ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'top', ...
        'FontWeight', 'bold', ...
        'BackgroundColor', 'black', ...
        'Margin', 2);


    text( ...
        ax, ...
        xLabelX, ...
        labelY, ...
        sprintf('Threshold: %.2f   X-plane', currentMultiplier), ...
        'Color', 'white', ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'top', ...
        'FontWeight', 'bold', ...
        'BackgroundColor', 'black', ...
        'Margin', 2);


    text( ...
        ax, ...
        yLabelX, ...
        labelY, ...
        sprintf('Threshold: %.2f   Y-plane', currentMultiplier), ...
        'Color', 'white', ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'top', ...
        'FontWeight', 'bold', ...
        'BackgroundColor', 'black', ...
        'Margin', 2);


    hold(ax, 'off');

    axis(ax, 'image');
    axis(ax, 'off');

end


%% ------------------------------------------------------------------------
%  ADD OVERALL FIGURE TITLE
%  -------------------------------------------------------------------------

% Replace underscores only for visualization.
displayName = replace(filename, '_', ' ');


% Report both the selected normalized threshold and its multiplier.
sgtitle( ...
    t, ...
    { ...
        displayName, ...
        sprintf(['Chosen threshold = %.4f   |   ', ...
                 'Otsu multiplier = %.2f'], ...
                thresh, mult) ...
    }, ...
    'Color', 'white', ...
    'FontWeight', 'bold');


%% ------------------------------------------------------------------------
%  SAVE FIGURE
%  -------------------------------------------------------------------------

drawnow;

outputFile = fullfile( ...
    savepath, ...
    [filename, '_thresholds.png']);


print( ...
    f, ...
    outputFile, ...
    '-dpng', ...
    '-r300');

end



%% =========================================================================
%  LOCAL FUNCTION: COMBINE THREE VIEWS
%  =========================================================================

function combinedImage = createThreeViewStrip( ...
    imageZ, imageX, imageY, maxHeight, maxWidth)
%CREATETHREEVIEWSTRIP Center three RGB images in equal-width sections.
%
%   Produces:
%
%       |---------|---------|---------|
%       |    Z    |    X    |    Y    |
%       |         |         |         |
%       |---------|---------|---------|
%
%   Each section has dimensions:
%
%       maxHeight-by-maxWidth
%
%   Smaller images are centered within their section. All unused pixels
%   are set to black.


%% Store views in a cell array

images = {imageZ, imageX, imageY};


%% Create black RGB holder image

combinedImage = zeros( ...
    maxHeight, ...
    3 * maxWidth, ...
    3, ...
    'like', imageZ);


%% Insert each image into the centre of its section

for viewIndex = 1:3

    currentImage = images{viewIndex};

    imageHeight = size(currentImage, 1);
    imageWidth  = size(currentImage, 2);


    % Centre vertically inside the common image height.
    rowStart = ...
        floor((maxHeight - imageHeight) / 2) + 1;

    rowEnd = ...
        rowStart + imageHeight - 1;


    % Left boundary of the current one-third section.
    sectionStart = ...
        (viewIndex - 1) * maxWidth;


    % Centre horizontally inside the current one-third section.
    columnStart = ...
        sectionStart + ...
        floor((maxWidth - imageWidth) / 2) + 1;

    columnEnd = ...
        columnStart + imageWidth - 1;


    % Copy image into the black holder.
    combinedImage( ...
        rowStart:rowEnd, ...
        columnStart:columnEnd, ...
        :) = currentImage;

end

end