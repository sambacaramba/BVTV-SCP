function lowpoints = getlowpoints(heightmap, maskheightmap, vol_bin, ratiolim)
%GETLOWPOINTS Estimate the lower boundary of the subchondral plate.
%
%   lowpoints = getlowpoints(heightmap, maskheightmap, vol_bin, ratiolim)
%
%   Starting from the upper surface defined by heightmap, this function
%   moves downward through the binary volume and evaluates the local
%   foreground fraction inside a 3-D neighbourhood.
%
%   The first location where the foreground fraction falls below ratiolim
%   is interpreted as the lower boundary of the subchondral plate.
%
% INPUTS
%   heightmap
%       M-by-N upper-surface map.
%
%       IMPORTANT:
%       The existing processing pipeline stores these coordinates using
%       zero-based Z coordinates:
%
%           heightmap = MATLAB Z-index - 1
%
%       This function converts them internally to MATLAB's one-based
%       indexing before accessing vol_bin.
%
%   maskheightmap
%       M-by-N logical mask defining XY locations where the lower surface
%       should be searched.
%
%   vol_bin
%       M-by-N-by-Z binary volume.
%
%   ratiolim
%       Foreground-fraction threshold used to identify the lower surface.
%
%       Example:
%           ratiolim = 0.5
%
%       means that the lower surface is detected when less than 50% of
%       the local 3-D neighbourhood consists of foreground voxels.
%
% OUTPUT
%   lowpoints
%       M-by-N lower-surface map containing MATLAB-compatible one-based
%       Z-coordinates.
%
%       Locations outside the valid ROI remain NaN.


%% ------------------------------------------------------------------------
%  SETTINGS
%  -------------------------------------------------------------------------

% Half-width of the neighbourhood in X and Y.
%
% A value of 2 gives:
%
%       2 pixels left
%       centre pixel
%       2 pixels right
%
% resulting in a 5 x 5 neighbourhood.
halfWindowX = 2;
halfWindowY = 2;

% Number of slices included in the Z direction.
windowDepthZ = 5;

% Offset from the final slice of the Z-window to its centre.
%
% For a five-slice window:
%
%       z-4  z-3  z-2  z-1  z
%                  ^
%                centre
halfWindowZ = floor(windowDepthZ / 2);

% If no threshold crossing is detected, place the lower surface this
% fraction of the way from the starting surface toward the lowest
% searchable location.
fallbackFraction = 0.80;


%% ------------------------------------------------------------------------
%  VALIDATE INPUTS
%  -------------------------------------------------------------------------

if ndims(vol_bin) ~= 3
    error('vol_bin must be a 3-D volume.');
end

if ~isequal(size(heightmap), size(maskheightmap))
    error('heightmap and maskheightmap must have identical dimensions.');
end

if ~isequal(size(heightmap), size(vol_bin, [1 2]))
    error('XY dimensions of heightmap and vol_bin must match.');
end

if ~(isscalar(ratiolim) && ratiolim >= 0 && ratiolim <= 1)
    error('ratiolim must be between 0 and 1.');
end

% Ensure binary/logical representation.
vol_bin = logical(vol_bin);
maskheightmap = logical(maskheightmap);


%% ------------------------------------------------------------------------
%  INITIALIZE
%  -------------------------------------------------------------------------

[volSizeX, volSizeY, volSizeZ] = size(vol_bin);

lowpoints = nan(size(heightmap));


%% ------------------------------------------------------------------------
%  SEARCH FOR LOWER SURFACE
%  -------------------------------------------------------------------------

% Keep the complete 5 x 5 XY neighbourhood inside the volume.
%
% Since halfWindowX = 2, the first valid centre is x = 3.
for x = (halfWindowX + 1):(volSizeX - halfWindowX)

    for y = (halfWindowY + 1):(volSizeY - halfWindowY)

        % Only search within the valid surface mask.
        if ~maskheightmap(x, y)
            continue;
        end


        %% Get starting Z-coordinate

        surfaceZ = heightmap(x, y);

        if isnan(surfaceZ)
            continue;
        end


        % heightmap uses zero-based coordinates.
        %
        % Convert:
        %
        %       heightmap 0 -> MATLAB slice 1
        %       heightmap 1 -> MATLAB slice 2
        %       ...
        z = round(surfaceZ) + 1;


        % Clamp the starting coordinate to the valid volume range.
        z = min(max(z, 1), volSizeZ);


        % A complete Z-window cannot be evaluated unless z is at least
        % windowDepthZ.
        if z < windowDepthZ
            continue;
        end


        %% Store starting position

        startZ = z;

        foundLowerSurface = false;


        %% --------------------------------------------------------------
        %  MOVE DOWNWARD THROUGH VOLUME
        %  ---------------------------------------------------------------

        while z >= windowDepthZ

            % Fixed 5 x 5 XY neighbourhood.
            xRange = ...
                (x - halfWindowX):(x + halfWindowX);

            yRange = ...
                (y - halfWindowY):(y + halfWindowY);


            % Z-window ends at the current Z-coordinate.
            %
            % For windowDepthZ = 5:
            %
            %       z-4 : z
            zRange = ...
                (z - windowDepthZ + 1):z;


            %% Extract local 3-D neighbourhood

            subvolume = vol_bin( ...
                xRange, ...
                yRange, ...
                zRange);


            %% Calculate foreground fraction

            foregroundRatio = ...
                nnz(subvolume) / numel(subvolume);


            %% Determine centre of current Z-window

            centerZ = z - halfWindowZ;


            %% Check lower-surface criterion

            if foregroundRatio < ratiolim

                lowpoints(x, y) = centerZ;

                foundLowerSurface = true;

                break;

            end


            %% Move one voxel deeper

            z = z - 1;

        end


        %% --------------------------------------------------------------
        %  FALLBACK IF NO THRESHOLD CROSSING WAS FOUND
        %  ---------------------------------------------------------------

        if ~foundLowerSurface

            % Centre coordinate of the first evaluated neighbourhood.
            startCenter = ...
                startZ - halfWindowZ;


            % Lowest possible centre of a complete Z-window.
            %
            % Example for windowDepthZ = 5:
            %
            %       last window = slices 1:5
            %       centre      = slice 3
            lowestCenter = ...
                windowDepthZ - halfWindowZ;


            % Move fallbackFraction of the way from the starting surface
            % toward the lowest searchable position.
            fallbackCenter = round( ...
                startCenter + ...
                fallbackFraction * ...
                (lowestCenter - startCenter));


            % Final safety clamp.
            fallbackCenter = max( ...
                1, ...
                min(fallbackCenter, volSizeZ));


            lowpoints(x, y) = fallbackCenter;

        end

    end

end

end