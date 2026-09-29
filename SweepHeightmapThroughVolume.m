function SweepHeightmapThroughVolume( ...
    volume, heightmap, vis, saveimages, savefolder, viewAz, viewEl)
%SWEEPHEIGHTMAPTHROUGHVOLUME Visualize a height-map surface moving through a 3-D volume.
%
%   SweepHeightmapThroughVolume( ...
%       volume, heightmap, vis, saveimages, savefolder, viewAz, viewEl)
%
%   Displays a binary 3-D volume as a semi-transparent isosurface and
%   moves a 2-D height-map surface downward through the volume one voxel
%   at a time.
%
%   The visualization is designed for generating consistent image
%   sequences that can later be combined into a video.
%
% INPUTS
%   volume
%       M-by-N-by-Z logical or uint8 volume.
%
%       Foreground voxels are assumed to have values greater than zero.
%
%   heightmap
%       M-by-N matrix containing Z-coordinates corresponding to positions
%       in the volume.
%
%       NaN values are allowed and are treated as locations outside the
%       valid surface.
%
%   vis
%       Logical flag controlling on-screen visualization:
%           true  - display the figure.
%           false - keep the figure hidden.
%
%   saveimages
%       Logical flag controlling frame saving:
%           true  - save every sweep position.
%           false - do not save frames.
%
%   savefolder
%       Parent folder for saved images.
%
%       When saveimages = true, a new folder is created:
%
%           savefolder/sweepframes/
%
%   viewAz
%       Camera azimuth angle in degrees.
%
%   viewEl
%       Camera elevation angle in degrees.
%
% EXAMPLE
%
%   SweepHeightmapThroughVolume( ...
%       volume, ...
%       smoothUpperSurface, ...
%       true, ...
%       true, ...
%       figureFolder, ...
%       45, ...
%       30);


%% ------------------------------------------------------------------------
%  DEFAULT INPUTS
%  -------------------------------------------------------------------------

if nargin < 3 || isempty(vis)
    vis = true;
end

if nargin < 4 || isempty(saveimages)
    saveimages = false;
end

if nargin < 5
    savefolder = '';
end

% Initial camera viewpoint.
%
% These values can easily be changed later after you determine which
% viewing angle works best for the data.
if nargin < 6 || isempty(viewAz)
    viewAz = 45;
end

if nargin < 7 || isempty(viewEl)
    viewEl = 30;
end


%% ------------------------------------------------------------------------
%  VALIDATE INPUT DATA
%  -------------------------------------------------------------------------

if ndims(volume) ~= 3
    error('volume must be a 3-D array.');
end

[vol_size_y, vol_size_x, vol_size_z] = size(volume);

if ~isequal(size(heightmap), [vol_size_y, vol_size_x])
    error(['heightmap must have the same XY dimensions as volume. ' ...
           'Expected size %d-by-%d.'], ...
           vol_size_y, vol_size_x);
end


%% ------------------------------------------------------------------------
%  CREATE OUTPUT FOLDER
%  -------------------------------------------------------------------------

if saveimages

    if isempty(savefolder)
        error(['A save folder must be provided when ', ...
               'saveimages is true.']);
    end

    frameFolder = fullfile(savefolder, 'sweepframes');

    if ~exist(frameFolder, 'dir')
        mkdir(frameFolder);
    end

end


%% ------------------------------------------------------------------------
%  PREPARE VOLUME
%  -------------------------------------------------------------------------

% Convert the input to a logical segmentation mask.
%
% This works for:
%
%   logical volumes:
%       false / true
%
%   uint8 masks:
%       0 / 255
%
% or other masks where foreground values are greater than zero.
volumeMask = volume > 0;


%% ------------------------------------------------------------------------
%  VISUALIZATION SETTINGS
%  -------------------------------------------------------------------------

% These settings control the appearance of the visualization.
%
% They can later be moved to function inputs if you want more control.

% 3-D volume appearance
volumeColor = [0.75, 0.75, 0.75];
volumeOpacity = 0.20;

% Moving height-map surface appearance
surfaceColor = [1.00, 0.20, 0.10];
surfaceOpacity = 0.70;

% Figure size.
%
% Keeping this fixed guarantees identical video-frame dimensions.
figureWidth_px = 1000;
figureHeight_px = 800;

% Export resolution.
exportDPI = 100;


%% ------------------------------------------------------------------------
%  CREATE FIXED FIGURE
%  -------------------------------------------------------------------------

if vis
    figureVisibility = 'on';
else
    figureVisibility = 'off';
end

f = figure( ...
    'Units', 'pixels', ...
    'Position', [100, 100, figureWidth_px, figureHeight_px], ...
    'Visible', figureVisibility, ...
    'Color', 'black', ...
    'Resize', 'off', ...
    'MenuBar', 'none', ...
    'ToolBar', 'none', ...
    'NumberTitle', 'off', ...
    'Name', 'Height-map sweep');


%% ------------------------------------------------------------------------
%  CREATE FIXED 3-D AXES
%  -------------------------------------------------------------------------

ax = axes( ...
    'Parent', f, ...
    'Units', 'normalized', ...
    'Position', [0.03, 0.03, 0.94, 0.94], ...
    'Color', 'black');

hold(ax, 'on');


%% ------------------------------------------------------------------------
%  PLOT STATIC 3-D VOLUME
%  -------------------------------------------------------------------------

% isosurface uses the coordinate convention:
%
%   X = columns of volume
%   Y = rows of volume
%   Z = slices of volume
%
% This matches the coordinate system used below for the height map.

isoData = isosurface(volumeMask, 0.5);

volumePatch = patch( ...
    ax, ...
    isoData);

set(volumePatch, ...
    'FaceColor', volumeColor, ...
    'EdgeColor', 'none', ...
    'FaceAlpha', volumeOpacity);


%% ------------------------------------------------------------------------
%  CREATE XY COORDINATES FOR HEIGHT MAP
%  -------------------------------------------------------------------------

[X, Y] = meshgrid( ...
    1:vol_size_x, ...
    1:vol_size_y);


%% ------------------------------------------------------------------------
%  CREATE MOVING HEIGHT-MAP SURFACE
%  -------------------------------------------------------------------------

current_heightmap = double(heightmap);

surfaceHandle = surf( ...
    ax, ...
    X, ...
    Y, ...
    current_heightmap, ...
    'FaceColor', surfaceColor, ...
    'FaceAlpha', surfaceOpacity, ...
    'EdgeColor', 'none');


%% ------------------------------------------------------------------------
%  FIX AXIS DIMENSIONS
%  -------------------------------------------------------------------------

% The complete volume dimensions remain visible for every frame.
xlim(ax, [1, vol_size_x]);
ylim(ax, [1, vol_size_y]);
zlim(ax, [1, vol_size_z]);

set(ax, ...
    'XLimMode', 'manual', ...
    'YLimMode', 'manual', ...
    'ZLimMode', 'manual');

% Equal scaling means one voxel has the same visual size in X, Y and Z.
daspect(ax, [1, 1, 1]);

% Prevent MATLAB from automatically changing the 3-D camera geometry.
axis(ax, 'vis3d');


%% ------------------------------------------------------------------------
%  SET CAMERA
%  -------------------------------------------------------------------------

view(ax, viewAz, viewEl);

% Black background with no visible axis decorations.
axis(ax, 'off');

set(ax, ...
    'Color', 'black');


%% ------------------------------------------------------------------------
%  LIGHTING
%  -------------------------------------------------------------------------

% Lighting makes the semi-transparent 3-D volume easier to interpret.
lighting(ax, 'gouraud');

camlight(ax, 'headlight');

material(ax, 'dull');


%% ------------------------------------------------------------------------
%  INITIAL DRAW
%  -------------------------------------------------------------------------

drawnow;


%% ------------------------------------------------------------------------
%  PREPARE FIXED EXPORT SIZE
%  -------------------------------------------------------------------------

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


%% ------------------------------------------------------------------------
%  SWEEP HEIGHT MAP THROUGH VOLUME
%  -------------------------------------------------------------------------

frameCounter = 1;

% Continue until no valid surface point remains above the bottom of the
% volume.
while any(current_heightmap(:) >= 1)


    %% ---------------------------------------------------------------
    %  UPDATE SURFACE
    %  ---------------------------------------------------------------

    % Only the Z-coordinates are changed.
    %
    % The figure, volume, camera, axes and lighting remain completely
    % unchanged.
    surfaceHandle.ZData = current_heightmap;


    %% ---------------------------------------------------------------
    %  KEEP CAMERA AND LIMITS FIXED
    %  ---------------------------------------------------------------

    xlim(ax, [1, vol_size_x]);
    ylim(ax, [1, vol_size_y]);
    zlim(ax, [1, vol_size_z]);

    view(ax, viewAz, viewEl);

    drawnow;


    %% ---------------------------------------------------------------
    %  SAVE CURRENT FRAME
    %  ---------------------------------------------------------------

    if saveimages

        frameName = sprintf( ...
            'sweep_%05d.png', ...
            frameCounter);

        framePath = fullfile( ...
            frameFolder, ...
            frameName);

        print( ...
            f, ...
            framePath, ...
            '-dpng', ...
            sprintf('-r%d', exportDPI));

    end


    %% ---------------------------------------------------------------
    %  MOVE SURFACE ONE VOXEL DOWN
    %  ---------------------------------------------------------------

    current_heightmap = current_heightmap - 1;

    % Once an individual location passes below the volume, remove it from
    % the displayed surface.
    current_heightmap(current_heightmap < 1) = NaN;

    frameCounter = frameCounter + 1;

end


%% ------------------------------------------------------------------------
%  CLEAN UP
%  -------------------------------------------------------------------------

hold(ax, 'off');

% Hidden figures are automatically closed after exporting.
%
% When vis = true, the final figure is left open so that the viewpoint can
% be inspected and adjusted.
if ~vis
    close(f);
end

end