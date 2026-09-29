function output = padder(volume, paddingSize, mode)
    % PADDER Adds or removes padding from a 3D volume.
    %   output = padder(volume, paddingSize, mode) returns the volume with
    %   added or removed padding based on the specified paddingSize and mode.
    %
    % Parameters:
    %   volume      - The input 3D matrix (e.g., 9x9x9).
    %   paddingSize - The size of padding to add or remove.
    %   mode        - 'add' to add padding, 'remove' to remove padding.
    %
    % Returns:
    %   output      - The output 3D matrix with padding added or removed.

    % Check mode for adding or removing padding
    if strcmp(mode, 'add')
        % Add padding to each dimension (except the last)
        output = padarray(volume, [paddingSize, paddingSize, 0], 0, 'both');
        
    elseif strcmp(mode, 'remove')
        % Calculate new dimensions for removing padding
        if any(size(volume) < 2*paddingSize+1)
            error('Padding size too large to remove.');
        end
        
        output = volume( ...
            paddingSize+1:end-paddingSize, ...
            paddingSize+1:end-paddingSize, ...
            :); % Maintain the depth dimension
        
    else
        error('Invalid mode. Use "add" or "remove".');
    end
end
