function output = Sweep(volume)
%SWEEP Keep only the largest connected foreground component.
%
%   output = Sweep(volume)
%
%   Supports both 2-D and 3-D logical arrays:
%
%       2-D input -> 8-connectivity
%       3-D input -> 26-connectivity
%
% INPUT
%   volume
%       Logical 2-D image or 3-D volume.
%
% OUTPUT
%   output
%       Logical array of the same size as the input containing only the
%       largest connected foreground component.
%
%       If the input contains no foreground pixels/voxels, the output is
%       entirely false.


%% Validate input

if ~islogical(volume)
    error('volume must be a logical array.');
end

if isempty(volume)
    error('volume must not be empty.');
end


%% Determine dimensionality and connectivity

if ismatrix(volume)

    % 2-D binary image:
    %
    % 8-connectivity considers pixels connected through edges or corners.
    connectivity = 8;

elseif ndims(volume) == 3

    % 3-D binary volume:
    %
    % 26-connectivity considers voxels connected through faces, edges,
    % or corners.
    connectivity = 26;

else

    error('volume must be either a 2-D image or a 3-D volume.');

end


%% Initialize output

output = false(size(volume));


%% Find connected foreground components

connectedComponents = bwconncomp( ...
    volume, ...
    connectivity);


%% Handle input with no foreground

if connectedComponents.NumObjects == 0
    return;
end


%% Find largest connected component

componentSizes = cellfun( ...
    @numel, ...
    connectedComponents.PixelIdxList);

[~, largestComponentIndex] = max(componentSizes);


%% Keep only the largest component

output( ...
    connectedComponents.PixelIdxList{largestComponentIndex}) = true;

end