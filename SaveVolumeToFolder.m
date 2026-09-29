function SaveVolumeToFolder(vol, outputFolder, basename, ext)
%SAVEVOLUMETOFOLDER Save a 3-D volume as a numbered image stack.
%
%   SaveVolumeToFolder(vol, outputFolder, basename, ext)
%
%   Saves each Z-slice of a 3-D volume as a separate image file.
%
% INPUTS
%   vol
%       M-by-N-by-Z image volume.
%
%       Supported datatypes:
%           logical
%               Saved as an 8-bit binary mask:
%                   false -> 0
%                   true  -> 255
%
%           uint8
%               Saved without modification.
%
%       Other datatypes are rejected to avoid accidental loss of intensity
%       information through implicit conversion to uint8.
%
%   outputFolder
%       Folder in which the image stack will be saved.
%
%       The folder is created if it does not already exist.
%
%       Existing files matching:
%
%           basename_*.ext
%
%       are removed before saving so that old slices from a previous run
%       cannot remain in the output stack.
%
%   basename
%       Base filename used for every output slice.
%
%       Example:
%           basename = 'sample01'
%
%       produces:
%           sample01_0001.bmp
%           sample01_0002.bmp
%           ...
%
%   ext
%       Output image extension, with or without a leading period.
%
%       Examples:
%           'bmp'
%           '.bmp'
%           'png'
%
% OUTPUT
%   None.


%% ------------------------------------------------------------------------
%  VALIDATE INPUTS
%  -------------------------------------------------------------------------

if ndims(vol) ~= 3
    error('vol must be a 3-D image volume.');
end

if isempty(vol)
    error('vol must not be empty.');
end

if isempty(outputFolder)
    error('outputFolder must not be empty.');
end

if isempty(basename)
    error('basename must not be empty.');
end

if isempty(ext)
    error('ext must not be empty.');
end


%% ------------------------------------------------------------------------
%  NORMALIZE TEXT INPUTS
%  -------------------------------------------------------------------------

% Convert string inputs to character vectors for consistent filename
% handling.
outputFolder = char(outputFolder);
basename     = char(basename);
ext          = char(ext);


% Accept extensions both with and without the leading period.
if ~startsWith(ext, '.')
    ext = ['.', ext];
end


%% ------------------------------------------------------------------------
%  CREATE OUTPUT DIRECTORY
%  -------------------------------------------------------------------------

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end


%% ------------------------------------------------------------------------
%  REMOVE PREVIOUS STACK FROM THIS SAMPLE
%  -------------------------------------------------------------------------

% Delete only files belonging to this image stack rather than recursively
% deleting the complete output directory.
%
% This prevents unrelated files in outputFolder from being accidentally
% removed.
existingFiles = dir( ...
    fullfile(outputFolder, [basename, '_*', ext]));

for i = 1:numel(existingFiles)

    delete(fullfile( ...
        existingFiles(i).folder, ...
        existingFiles(i).name));

end


%% ------------------------------------------------------------------------
%  PREPARE VOLUME FOR SAVING
%  -------------------------------------------------------------------------

if islogical(vol)

    % Convert logical segmentation to a standard 8-bit binary image:
    %
    %       false ->   0
    %       true  -> 255
    volToSave = uint8(vol) .* 255;


elseif isa(vol, 'uint8')

    % Preserve original 8-bit intensities.
    volToSave = vol;


else

    error( ...
        'SaveVolumeToFolder:UnsupportedDatatype', ...
        ['Volume datatype "%s" is not supported. ', ...
         'Expected logical or uint8 data. ', ...
         'Convert or scale the volume explicitly before saving.'], ...
        class(vol));

end


%% ------------------------------------------------------------------------
%  SAVE IMAGE STACK
%  -------------------------------------------------------------------------

numSlices = size(volToSave, 3);

for sliceIndex = 1:numSlices

    imageFilename = sprintf( ...
        '%s_%04d%s', ...
        basename, ...
        sliceIndex, ...
        ext);

    fullFilename = fullfile( ...
        outputFolder, ...
        imageFilename);

    imwrite( ...
        volToSave(:, :, sliceIndex), ...
        fullFilename);

end

end