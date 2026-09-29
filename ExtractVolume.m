function extracted_volume = ExtractVolume(vol, smoothsurf, smoothlowpoints)
%EXTRACTVOLUME Extract voxels located between two surface maps.
%
%   extracted_volume = ExtractVolume(vol, smoothsurf, smoothlowpoints)
%
%   Extracts the portion of a 3-D volume located between an upper surface
%   and a lower surface. At each XY location, voxels from the lower
%   surface through the upper surface are copied into a new volume.
%
% INPUTS
%   vol
%       M-by-N-by-Z image volume.
%
%   smoothsurf
%       M-by-N upper-surface map containing Z-coordinates.
%
%   smoothlowpoints
%       M-by-N lower-surface map containing Z-coordinates.
%
%       Both surface maps are expected to use MATLAB-compatible one-based
%       Z-coordinates:
%
%           first slice = 1
%           last slice  = size(vol,3)
%
%       NaN values indicate locations where no valid surface is available.
%
% OUTPUT
%   extracted_volume
%       M-by-N-by-Z volume containing the original voxel values between
%       the lower and upper surfaces.
%
%       Voxels outside the extracted region are set to zero.
%
% NOTES
%   Surface coordinates are rounded to the nearest integer because volume
%   indexing requires whole-number Z-coordinates.
%
%   Both boundary slices are included in the extracted region.


%% ------------------------------------------------------------------------
%  VALIDATE INPUTS
%  -------------------------------------------------------------------------

if ndims(vol) ~= 3
    error('vol must be a 3-D volume.');
end

if ~ismatrix(smoothsurf) || ~ismatrix(smoothlowpoints)
    error('smoothsurf and smoothlowpoints must be 2-D matrices.');
end

[volSizeX, volSizeY, volSizeZ] = size(vol);

expectedSurfaceSize = [volSizeX, volSizeY];

if ~isequal(size(smoothsurf), expectedSurfaceSize)
    error( ...
        'smoothsurf must match the XY dimensions of vol.');
end

if ~isequal(size(smoothlowpoints), expectedSurfaceSize)
    error( ...
        'smoothlowpoints must match the XY dimensions of vol.');
end


%% ------------------------------------------------------------------------
%  INITIALIZE OUTPUT
%  -------------------------------------------------------------------------

% Preserve the datatype of the original volume.
%
% Examples:
%   uint8   -> uint8 output
%   uint16  -> uint16 output
%   logical -> logical output
extracted_volume = zeros(size(vol), 'like', vol);


%% ------------------------------------------------------------------------
%  ROUND SURFACE COORDINATES
%  -------------------------------------------------------------------------

% Smoothing generally produces non-integer Z-coordinates.
%
% Round once here instead of repeatedly inside the nested loop.
upperSurface = round(smoothsurf);
lowerSurface = round(smoothlowpoints);


%% ------------------------------------------------------------------------
%  DETERMINE VALID XY LOCATIONS
%  -------------------------------------------------------------------------

% Both surfaces must exist.
validSurface = ...
    ~isnan(upperSurface) & ...
    ~isnan(lowerSurface);


% Both surfaces must lie completely inside the volume.
validSurface = validSurface & ...
    upperSurface >= 1 & ...
    upperSurface <= volSizeZ & ...
    lowerSurface >= 1 & ...
    lowerSurface <= volSizeZ;


% The lower surface must not be above the upper surface.
%
% The current pipeline assumes that decreasing Z moves deeper into the
% sample, therefore:
%
%       lowerSurface <= upperSurface
validSurface = validSurface & ...
    lowerSurface <= upperSurface;


%% ------------------------------------------------------------------------
%  EXTRACT VOLUME BETWEEN SURFACES
%  -------------------------------------------------------------------------

for x = 1:volSizeX

    for y = 1:volSizeY

        % Skip locations without two valid surfaces.
        if ~validSurface(x, y)
            continue;
        end


        zUpper = upperSurface(x, y);
        zLower = lowerSurface(x, y);


        % Copy all voxels between the lower and upper surfaces,
        % including both boundary slices.
        extracted_volume(x, y, zLower:zUpper) = ...
            vol(x, y, zLower:zUpper);

    end

end

end