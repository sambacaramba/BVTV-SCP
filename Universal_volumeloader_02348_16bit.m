% Copyright 2024 Sami Kauppinen (sami.kauppinen(at)oulu.fi)
function [vol, fname, real_size_XY] = Universal_volumeloader_02348_16bit(selpath, binning, current_data, data_amount, datatype, flipH)

%% Universal volume loader
%
% datatype means image file type / extension, for example:
%   "tif"
%   "tiff"
%   "png"
%   "bmp"
%
% This function preserves the original image class.
% If images are uint16, vol will be uint16.
% If images are uint8, vol will be uint8.

%% ---------------- Input checks ----------------

if nargin < 6
    flipH = false;
end

if nargin < 5 || isempty(datatype)
    datatype = "tif";
end

if nargin < 4
    data_amount = 1;
end

if nargin < 3
    current_data = 1;
end

if nargin < 2 || isempty(binning)
    binning = 1;
end

if ~isfolder(selpath)
    error('Selected path is not a folder: %s', selpath);
end

%% ---------------- List files ----------------

files = listImageFiles(selpath, datatype);

% Remove shadow projection files from list
if ~isempty(files)
    remv = contains({files.name}, 'spr', 'IgnoreCase', true);
    files(remv) = [];
end

if isempty(files)
    error('No image files found in folder "%s" with datatype "%s".', ...
        selpath, string(datatype));
end

files = naturalSortDirStruct(files);

%% ---------------- Filename from folder ----------------

fname = getNameFromFolder(selpath);

%% ---------------- Binning settings ----------------

switch binning
    case {0, 1}
        groupSize = 1;
        resizeFactor = 1;
        progressText = 'loading full volume';

    case 2
        groupSize = 2;
        resizeFactor = 1/2;
        progressText = 'loading full volume and resizing by 1/2';

    case 3
        groupSize = 3;
        resizeFactor = 1/3;
        progressText = 'loading full volume and resizing by 1/3';

    case 4
        groupSize = 4;
        resizeFactor = 1/4;
        progressText = 'loading full volume and resizing by 1/4';

    case 8
        groupSize = 8;
        resizeFactor = 1/8;
        progressText = 'loading full volume and resizing by 1/8';

    otherwise
        error('Unsupported binning value: %g. Use 0, 1, 2, 3, 4, or 8.', binning);
end

if binning == 0
    disp('binning set to zero')
else
    fprintf('binning set to %g\n', binning);
end

%% ---------------- Read first image for allocation info ----------------

firstPath = fullfile(files(1).folder, files(1).name);
firstImg = readImagePreserveClass(firstPath);

real_size_XY = size(firstImg);

inputClass = class(firstImg);

fprintf('Input image class detected: %s\n', inputClass);
fprintf('Original XY size: %s\n', mat2str(real_size_XY));
fprintf('Number of input slices: %d\n', numel(files));

%% ---------------- Make first output slice ----------------

startIndices = 1:groupSize:numel(files);
zdim = numel(startIndices);

firstOutSlice = makeBinnedSlice(files, startIndices(1), groupSize, resizeFactor, flipH, firstImg);

[xdim, ydim] = size(firstOutSlice);

vol = zeros(xdim, ydim, zdim, 'like', firstOutSlice);
vol(:, :, 1) = firstOutSlice;

%% ---------------- Load rest of volume ----------------

for k = 2:zdim

    j = startIndices(k);

    tmp = makeBinnedSlice(files, j, groupSize, resizeFactor, flipH, firstImg);

    if ~isequal(size(tmp), [xdim, ydim])
        error('Output slice size mismatch at output slice %d.', k);
    end

    vol(:, :, k) = tmp;

    progressPercent = min(((j + groupSize - 1) / numel(files)) * 100, 100);

    fprintf('%d/%d %s %.1f%%\n', ...
        current_data, data_amount, progressText, progressPercent);
    
end

fprintf('Loaded volume class: %s\n', class(vol));
fprintf('Loaded volume size: %s\n', mat2str(size(vol)));
fprintf('Loaded volume min/max: %.3f / %.3f\n', ...
    double(min(vol(:))), double(max(vol(:))));

end


%% ========================================================================
% Local functions
% ========================================================================

function files = listImageFiles(selpath, datatype)
% Lists image files based on datatype/extension.

    patterns = makeFilePatterns(datatype);

    files = [];

    for i = 1:numel(patterns)
        files = [files; dir(fullfile(selpath, patterns{i}))]; 
    end

    if isempty(files)
        return;
    end

    % Remove duplicates, useful on case-insensitive Windows systems
    fullPaths = fullfile({files.folder}, {files.name});
    [~, uniqueIdx] = unique(lower(fullPaths), 'stable');
    files = files(uniqueIdx);
end


function patterns = makeFilePatterns(datatype)
% Converts datatype input into dir search patterns.
%
% Examples:
%   "png"    -> "*.png", "*.PNG"
%   "tif"    -> "*.tif", "*.tiff", "*.TIF", "*.TIFF"
%   "*.png"  -> "*.png"
%   ".png"   -> "*.png"

    if iscell(datatype)
        patterns = {};
        for i = 1:numel(datatype)
            patterns = [patterns, makeFilePatterns(datatype{i})]; 
        end
        return;
    end

    datatype = char(string(datatype));
    datatype = strtrim(datatype);

    if isempty(datatype)
        error('datatype is empty.');
    end

    datatypeLower = lower(datatype);

    % If user gives "tif" or "tiff", include both common TIFF extensions.
    if strcmp(datatypeLower, 'tif') || strcmp(datatypeLower, 'tiff')
        patterns = {'*.tif', '*.tiff', '*.TIF', '*.TIFF'};
        return;
    end

    % If user already gives wildcard, use it as-is.
    if contains(datatype, '*')
        patterns = {datatype};
        return;
    end

    % If user gives ".png", convert to "*.png".
    if startsWith(datatype, '.')
        extLower = lower(datatype);
        extUpper = upper(datatype);
        patterns = {['*' extLower], ['*' extUpper]};
        return;
    end

    % If user gives "png", convert to "*.png".
    extLower = ['.' lower(datatype)];
    extUpper = ['.' upper(datatype)];

    patterns = {['*' extLower], ['*' extUpper]};
end


function img = readImagePreserveClass(filename)
% Reads image and keeps original bit depth/class.
% RGB images are converted to grayscale.

    img = imread(filename);

    if ndims(img) == 3
        img = rgb2gray(img);
    end
end


function outSlice = makeBinnedSlice(files, startIdx, groupSize, resizeFactor, flipH, templateImg)
% Creates one output slice.
%
% For binning:
%   - averages groupSize slices in Z
%   - resizes XY by resizeFactor
%   - casts back to the original image class

    nFiles = numel(files);
    endIdx = min(startIdx + groupSize - 1, nFiles);

    tmpSum = [];

    nUsed = 0;

    for idx = startIdx:endIdx

        thisPath = fullfile(files(idx).folder, files(idx).name);
        thisImg = readImagePreserveClass(thisPath);

        if ~isequal(size(thisImg), size(templateImg))
            error('Image size mismatch: %s', thisPath);
        end

        thisImg = double(thisImg);

        if isempty(tmpSum)
            tmpSum = zeros(size(thisImg));
        end

        tmpSum = tmpSum + thisImg;
        nUsed = nUsed + 1;
    end

    tmp = tmpSum ./ nUsed;

    if resizeFactor ~= 1
        tmp = imresize(tmp, resizeFactor);
    end

    outSlice = castBackToOriginalClass(tmp, templateImg);

    if flipH == 1 || flipH == true
        outSlice = flip(outSlice, 2);
    end
end


function imgOut = castBackToOriginalClass(imgDouble, templateImg)
% Casts processed image back to the original image class safely.
%
% Important:
%   This preserves uint16 data as uint16.
%   It does NOT force uint8.

    targetClass = class(templateImg);

    switch targetClass

        case 'uint8'
            imgDouble = round(imgDouble);
            imgDouble(imgDouble < 0) = 0;
            imgDouble(imgDouble > double(intmax('uint8'))) = double(intmax('uint8'));
            imgOut = uint8(imgDouble);

        case 'uint16'
            imgDouble = round(imgDouble);
            imgDouble(imgDouble < 0) = 0;
            imgDouble(imgDouble > double(intmax('uint16'))) = double(intmax('uint16'));
            imgOut = uint16(imgDouble);

        case 'uint32'
            imgDouble = round(imgDouble);
            imgDouble(imgDouble < 0) = 0;
            imgDouble(imgDouble > double(intmax('uint32'))) = double(intmax('uint32'));
            imgOut = uint32(imgDouble);

        case 'int16'
            imgDouble = round(imgDouble);
            imgDouble(imgDouble < double(intmin('int16'))) = double(intmin('int16'));
            imgDouble(imgDouble > double(intmax('int16'))) = double(intmax('int16'));
            imgOut = int16(imgDouble);

        case 'single'
            imgOut = single(imgDouble);

        case 'double'
            imgOut = imgDouble;

        case 'logical'
            imgOut = logical(imgDouble);

        otherwise
            warning('Unknown image class "%s". Returning double.', targetClass);
            imgOut = imgDouble;
    end
end


function folderName = getNameFromFolder(selpath)
% Gets filename from folder.
%
% If selpath ends in "\pli", use the parent folder name instead.
% Example:
%   E:\8bit\FEMUR\pli
% returns:
%   FEMUR
%
% Otherwise:
%   E:\8bit\FEMUR
% returns:
%   FEMUR

    [parentFolder, thisName] = fileparts(selpath);

    if strcmpi(thisName, 'pli')
        [~, folderName] = fileparts(parentFolder);
    else
        folderName = thisName;
    end
end


function filesOut = naturalSortDirStruct(filesIn)
% Natural sorting for filenames with running numbers.
%
% Example:
%   pli1.tif, pli2.tif, pli10.tif
%
% instead of:
%   pli1.tif, pli10.tif, pli2.tif

    names = {filesIn.name};
    keys = cell(size(names));

    for i = 1:numel(names)
        keys{i} = naturalSortKey(names{i});
    end

    [~, idx] = sort(lower(keys));

    filesOut = filesIn(idx);
end


function key = naturalSortKey(filename)
% Converts filename into natural-sort key.

    parts = regexp(filename, '\d+|\D+', 'match');

    key = '';

    for i = 1:numel(parts)
        token = parts{i};

        if all(isstrprop(token, 'digit'))
            key = [key, sprintf('%020d', str2double(token))]; 
        else
            key = [key, token]; 
        end
    end
end