function vol_filled = fill_holes_2D_planes(vol_bin, holeArea_um2, voxelSize_um)
%FILL_HOLES_2D_PLANES Fill small holes in XZ and YZ planes of a 3-D mask.
%
%   vol_filled = fill_holes_2D_planes( ...
%       vol_bin, holeArea_um2, voxelSize_um)
%
%   Fills small background regions in a binary 3-D volume by processing
%   individual XZ and YZ planes.
%
%   This is a 2-D plane-by-plane operation, not a true 3-D hole-filling
%   operation.
%
% INPUTS
%   vol_bin
%       M-by-N-by-Z logical volume.
%       Foreground/object voxels should be true (1).
%
%   holeArea_um2
%       Maximum approximate hole area to fill, in square micrometres
%       [um^2].
%
%   voxelSize_um
%       Isotropic voxel size in micrometres [um/pixel].
%
% OUTPUT
%   vol_filled
%       Logical volume after small holes have been removed from the
%       background in XZ and YZ planes.
%
% NOTES
%   The method works by inverting the binary segmentation so that holes
%   become foreground objects. Small foreground components are then
%   removed with bwareaopen, after which the volume is inverted back.
%
%   Because processing is performed independently in 2-D planes, the
%   result may differ from true 3-D hole filling.


%% Validate inputs

if ndims(vol_bin) ~= 3
    error('vol_bin must be a 3-D volume.');
end

if ~(isscalar(holeArea_um2) && holeArea_um2 > 0)
    error('holeArea_um2 must be a positive scalar.');
end

if ~(isscalar(voxelSize_um) && voxelSize_um > 0)
    error('voxelSize_um must be a positive scalar.');
end


%% Convert physical hole area to pixels

% Area represented by one pixel in a 2-D plane.
%
% This assumes isotropic voxels:
%
%     voxelSizeX = voxelSizeY = voxelSizeZ
%
pixelArea_um2 = voxelSize_um^2;

% bwareaopen operates using the number of pixels in each connected object.
holeArea_pixels = max(1, round(holeArea_um2 / pixelArea_um2));


%% Convert holes/background to foreground

% bwareaopen removes small FOREGROUND components.
%
% Therefore the segmentation is inverted so that enclosed holes become
% foreground components.
background = ~logical(vol_bin);

[dim1, dim2, dim3] = size(background);


%% Fill holes in planes spanning dimensions 1 and 3
%
% For an X-Y-Z interpretation, these correspond to XZ planes.
%
% Each iteration fixes dimension 2.

for j = 1:dim2

    plane = squeeze(background(:, j, :));

    plane = bwareaopen( ...
        plane, ...
        holeArea_pixels, ...
        8);

    background(:, j, :) = reshape( ...
        plane, ...
        [dim1, 1, dim3]);

end


%% Fill holes in planes spanning dimensions 2 and 3
%
% For an X-Y-Z interpretation, these correspond to YZ planes.
%
% Each iteration fixes dimension 1.

for i = 1:dim1

    plane = squeeze(background(i, :, :));

    plane = bwareaopen( ...
        plane, ...
        holeArea_pixels, ...
        8);

    background(i, :, :) = reshape( ...
        plane, ...
        [1, dim2, dim3]);

end


%% Restore normal foreground/background convention

vol_filled = ~background;

end