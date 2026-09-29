function cleaned_volume = RemoveTrabecular_parallel( ...
    extracted_volume, smoothsurf, objsize, pixelSize_um, ...
    vis, remvperc, saveimages, savefolder)
%REMOVETRABECULAR_PARALLEL2 Remove trabecular structures from a 3-D volume.
%
%   cleaned_volume = RemoveTrabecular_parallel2( ...
%       extracted_volume, smoothsurf, objsize, pixelSize_um, ...
%       vis, remvperc, saveimages, savefolder)
%
%   The function iteratively moves downward from a supplied surface map.
%   At each depth, foreground pixels are evaluated using a circular local
%   neighbourhood. Pixels are removed when the fraction of foreground
%   pixels within that neighbourhood is below the specified threshold.
%
% INPUTS
%   extracted_volume
%       3-D volume containing the region to be cleaned.
%
%   smoothsurf
%       2-D surface map defining the starting Z-coordinate at each XY
%       location. NaN values indicate locations outside the valid ROI.
%
%   objsize
%       Radius of the circular neighbourhood, in PIXELS.
%
%   pixelSize_um
%       XY pixel size of the processed volume, in micrometres per pixel.
%       Used to display the physical size of the local neighbourhood.
%
%   vis
%       Logical flag controlling visualization:
%           true  - display each cleaning iteration.
%           false - do not display intermediate figures.
%
%   remvperc
%       Minimum foreground fraction required inside the circular
%       neighbourhood for the centre pixel to remain.
%
%       Example:
%           remvperc = 0.8
%
%       means that a pixel is removed when less than 80% of the valid
%       circular neighbourhood contains foreground pixels.
%
%   saveimages
%       Logical flag controlling whether every intermediate visualization
%       frame is saved.
%
%   savefolder
%       Parent folder for saved figures.
%
%       When saveimages = true, the function creates:
%
%           savefolder/removalframes/
%
% OUTPUT
%   cleaned_volume
%       Copy of extracted_volume after detected trabecular structures have
%       been removed.


%% ------------------------------------------------------------------------
%  VALIDATE INPUTS
%  -------------------------------------------------------------------------

% savefolder is the eighth input and is only required when frames are saved.
if nargin < 8
    savefolder = '';
end

if saveimages

    if isempty(savefolder)
        error(['A save folder must be provided when ', ...
               'saveimages is set to true.']);
    end

    % Create a dedicated folder for video frames.
    frameFolder = fullfile(savefolder, 'removalframes');

    if ~exist(frameFolder, 'dir')
        mkdir(frameFolder);
    end

end


%% ------------------------------------------------------------------------
%  INITIALIZE VOLUME
%  -------------------------------------------------------------------------

[vol_size_x, vol_size_y, vol_size_z] = size(extracted_volume);

% Work on a copy so that the original input is not modified.
cleaned_volume = extracted_volume;

% Surface map that moves one voxel deeper after every iteration.
current_heightmap = smoothsurf;


%% ------------------------------------------------------------------------
%  LOCAL NEIGHBOURHOOD SIZE
%  -------------------------------------------------------------------------

% Convert neighbourhood radius from pixels to micrometres for display.
neighborhoodRadius_um = objsize * pixelSize_um;


%% ------------------------------------------------------------------------
%  CREATE CIRCULAR NEIGHBOURHOOD MASK
%  -------------------------------------------------------------------------

se_disk = strel('disk', objsize);
circular_mask = se_disk.getnhood();

mask_size = size(circular_mask, 1);
half_mask_size = floor(mask_size / 2);


%% ------------------------------------------------------------------------
%  INITIALIZE FIXED VISUALIZATION
%  -------------------------------------------------------------------------

% A figure is needed either for visualization or for saving frames.
createFigure = vis || saveimages;

% Initialize graphics handles.
f = [];
ax = [];
titleBox = [];

if createFigure

    % Original image dimensions.
    imageHeight_px = vol_size_x;
    imageWidth_px  = vol_size_y;


    %% Determine fixed figure size

    screenSize = get(0, 'ScreenSize');

    screenWidth_px  = screenSize(3);
    screenHeight_px = screenSize(4);

    % Maximum fraction of screen occupied by the figure.
    maxFigureWidth_px  = round(screenWidth_px  * 0.80);
    maxFigureHeight_px = round(screenHeight_px * 0.80);

    % Additional vertical space for the text area.
    titleSpace_px = 120;

    % Scale image to fit the screen while preserving its XY aspect ratio.
    scaleFactor = min([ ...
        1, ...
        maxFigureWidth_px / imageWidth_px, ...
        (maxFigureHeight_px - titleSpace_px) / imageHeight_px]);

    displayWidth_px  = round(imageWidth_px  * scaleFactor);
    displayHeight_px = round(imageHeight_px * scaleFactor);

    % Fixed dimensions for the complete figure.
    figureWidth_px  = displayWidth_px;
    figureHeight_px = displayHeight_px + titleSpace_px;


    %% Determine figure visibility

    if vis
        figureVisibility = 'on';
    else
        figureVisibility = 'off';
    end


    %% Create fixed figure

    f = figure( ...
        'Units', 'pixels', ...
        'Position', [100, 100, figureWidth_px, figureHeight_px], ...
        'Visible', figureVisibility, ...
        'Color', 'black', ...
        'Resize', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'NumberTitle', 'off', ...
        'Name', 'Trabecular removal');


    %% Create fixed image axes

    % The image occupies the lower part of the figure.
    %
    % Space at the top is reserved permanently for the information text.
    ax = axes( ...
        'Parent', f, ...
        'Units', 'normalized', ...
        'Position', [0.02, 0.02, 0.96, 0.80]);


    % Lock the image view to the ORIGINAL volume dimensions.
    xlim(ax, [0.5, vol_size_y + 0.5]);
    ylim(ax, [0.5, vol_size_x + 0.5]);

    set(ax, ...
        'XLimMode', 'manual', ...
        'YLimMode', 'manual', ...
        'YDir', 'reverse', ...
        'DataAspectRatio', [1, 1, 1], ...
        'DataAspectRatioMode', 'manual');


    %% Create fixed text box

    % This annotation is created ONCE.
    %
    % Only its String property changes during processing. Therefore the
    % location and size of the text area stay identical in every frame.
    titleBox = annotation(f, 'textbox', ...
        [0.02, 0.83, 0.96, 0.16], ...
        'String', '', ...
        'Color', 'white', ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'FontSize', 11, ...
        'FontWeight', 'normal', ...
        'Interpreter', 'tex', ...
        'EdgeColor', 'none', ...
        'FitBoxToText', 'off');


    %% Fixed circle location

    % The example neighbourhood circle is always drawn at the centre of
    % the original image.
    circleCenter = [ ...
        (vol_size_y + 1) / 2, ...
        (vol_size_x + 1) / 2];

end


%% ------------------------------------------------------------------------
%  FRAME COUNTER
%  -------------------------------------------------------------------------

frameCounter = 1;


%% ------------------------------------------------------------------------
%  ITERATIVELY MOVE DOWNWARD THROUGH THE VOLUME
%  -------------------------------------------------------------------------

while any(current_heightmap(:) > 1)


    %% --------------------------------------------------------------------
    %  EXTRACT CURRENT XY CROSS-SECTION
    %  ---------------------------------------------------------------------

    orig_mask = false(vol_size_x, vol_size_y);

    for x = 1:vol_size_x
        for y = 1:vol_size_y

            z_coord = round(current_heightmap(x, y));

            % Skip locations outside the valid surface.
            if isnan(z_coord)
                continue;
            end

            % Only evaluate coordinates inside the volume.
            if z_coord > 0 && z_coord <= vol_size_z

                orig_mask(x, y) = ...
                    cleaned_volume(x, y, z_coord) > 0;

            end

        end
    end


    %% --------------------------------------------------------------------
    %  PREPARE MASKS FOR TRABECULAR REMOVAL
    %  ---------------------------------------------------------------------

    updated_mask = orig_mask;

    % Fill enclosed holes to define the region to be evaluated.
    location_mask = imfill(orig_mask, 'holes');

    % Temporary mask used during parallel processing.
    temp_mask = updated_mask;


    %% --------------------------------------------------------------------
    %  EVALUATE CIRCULAR NEIGHBOURHOODS
    %  ---------------------------------------------------------------------

    parfor x = half_mask_size + 1 : vol_size_x - half_mask_size

        % Each parallel worker modifies one complete row.
        temp_row = updated_mask(x, :);

        for y = half_mask_size + 1 : vol_size_y - half_mask_size

            % Only evaluate foreground pixels inside the valid region.
            if location_mask(x, y) && updated_mask(x, y)


                %% Extract local neighbourhood

                neighborhood = orig_mask( ...
                    x - half_mask_size : x + half_mask_size, ...
                    y - half_mask_size : y + half_mask_size);


                % Corresponding height-map neighbourhood.
                heightmap_region = current_heightmap( ...
                    x - half_mask_size : x + half_mask_size, ...
                    y - half_mask_size : y + half_mask_size);


                %% Restrict analysis to circular region

                circular_region = neighborhood(circular_mask);

                heightmap_circular_region = ...
                    heightmap_region(circular_mask);


                % Remove positions outside the valid ROI.
                valid_circular_region = circular_region( ...
                    ~isnan(heightmap_circular_region));


                %% Calculate foreground ratio

                total_elements = numel(valid_circular_region);

                if total_elements > 0

                    num_ones = sum(valid_circular_region == 1);

                    foreground_ratio = ...
                        num_ones / total_elements;

                else

                    foreground_ratio = 0;

                end


                %% Apply removal criterion

                if foreground_ratio < remvperc
                    temp_row(y) = false;
                end

            end

        end

        temp_mask(x, :) = temp_row;

    end


    % Collect results from the parallel loop.
    updated_mask = temp_mask;


    %% --------------------------------------------------------------------
    %  VISUALIZE AND/OR SAVE CURRENT ITERATION
    %  ---------------------------------------------------------------------

    if createFigure

        % Clear ONLY the axes contents.
        %
        % The figure, axes and title box themselves are preserved.
        cla(ax);


        %% Display original vs updated mask

        imshowpair( ...
            orig_mask, ...
            updated_mask, ...
            'Parent', ax);


        % imshowpair can modify axes properties, so explicitly restore the
        % original fixed field of view.
        xlim(ax, [0.5, vol_size_y + 0.5]);
        ylim(ax, [0.5, vol_size_x + 0.5]);

        set(ax, ...
            'XLimMode', 'manual', ...
            'YLimMode', 'manual', ...
            'YDir', 'reverse', ...
            'DataAspectRatio', [1, 1, 1], ...
            'DataAspectRatioMode', 'manual');


        %% Draw local-neighbourhood circle

        hold(ax, 'on');

        viscircles( ...
            ax, ...
            circleCenter, ...
            objsize, ...
            'Color', 'r', ...
            'LineWidth', 2);

        hold(ax, 'off');


        %% Update fixed information box

        % Three shorter lines are used so that the text fits even when the
        % original image is relatively narrow.
        titleBox.String = sprintf([ ...
            'Trabecular removal - frame %05d\n' ...
            'Red circle indicates local neighbourhood radius\n' ...
            '%.1f \\mum'], ...
            frameCounter, ...
            neighborhoodRadius_um);


        %% Re-lock axes

        xlim(ax, [0.5, vol_size_y + 0.5]);
        ylim(ax, [0.5, vol_size_x + 0.5]);

        drawnow;


        %% ----------------------------------------------------------------
        %  SAVE INTERMEDIATE FRAME
        %  -----------------------------------------------------------------

        if saveimages

            frameName = sprintf( ...
                'removal_%05d.png', ...
                frameCounter);

            framePath = fullfile( ...
                frameFolder, ...
                frameName);


            % Fixed export resolution.
            exportDPI = 100;


            % Set a fixed paper/output size.
            set(f, ...
                'PaperUnits', 'inches', ...
                'PaperPosition', ...
                [0, ...
                 0, ...
                 figureWidth_px / exportDPI, ...
                 figureHeight_px / exportDPI], ...
                'PaperSize', ...
                [figureWidth_px / exportDPI, ...
                 figureHeight_px / exportDPI]);


            % Export PNG frame.
            print( ...
                f, ...
                framePath, ...
                '-dpng', ...
                sprintf('-r%d', exportDPI));

        end

    end


    %% --------------------------------------------------------------------
    %  APPLY DETECTED REMOVALS TO THE 3-D VOLUME
    %  ---------------------------------------------------------------------

    for x = 1:vol_size_x
        for y = 1:vol_size_y

            z_coord = round(current_heightmap(x, y));

            % Skip locations outside the valid surface.
            if isnan(z_coord)
                continue;
            end


            if z_coord > 0 && z_coord <= vol_size_z

                % A change between the original and updated mask indicates
                % that the voxel was marked for removal.
                if orig_mask(x, y) ~= updated_mask(x, y)

                    cleaned_volume(x, y, z_coord) = 0;

                end

            end

        end
    end


    %% --------------------------------------------------------------------
    %  MOVE ONE VOXEL DEEPER
    %  ---------------------------------------------------------------------

    current_heightmap = current_heightmap - 1;

    frameCounter = frameCounter + 1;

end


%% ------------------------------------------------------------------------
%  CLEAN UP FIGURE
%  -------------------------------------------------------------------------

% If the figure was only needed for saving images, close it automatically.
%
% If vis = true, leave the final frame visible for inspection.
if createFigure && ~vis
    close(f);
end

end