function output = FillNaNs(input, window_size, name)
%FILLNANS Fill enclosed NaN regions using local median values.
%
%   output = FillNaNs(input, window_size)
%   output = FillNaNs(input, window_size, name)
%
%   Identifies enclosed NaN regions in a 2-D surface map and replaces each
%   NaN pixel inside those regions with the median of nearby valid values.
%
%   NaN regions connected to the image boundary are treated as background
%   and are NOT filled.
%
% INPUTS
%   input
%       M-by-N numeric matrix, typically a height map or surface map.
%       Missing values must be represented by NaN.
%
%   window_size
%       Width and height, in pixels, of the local neighbourhood used to
%       calculate the replacement median.
%
%       Example:
%           window_size = 101
%
%       uses approximately a 101-by-101 pixel neighbourhood around each
%       NaN location.
%
%       Both odd and even values are accepted. For even window sizes, the
%       neighbourhood is shifted by one pixel because an even-sized window
%       cannot be perfectly centred on a single pixel.
%
%   name
%       Optional text used as the title of the diagnostic figure.
%
% OUTPUT
%   output
%       Copy of input in which enclosed NaN holes have been filled whenever
%       valid neighbouring values were available.
%
% NOTES
%   This is a single-pass operation. Replacement values are calculated
%   from the ORIGINAL input surface, not from previously filled pixels.
%   This avoids propagation/order effects during interpolation.
%
%   Very large holes may therefore remain partly NaN if the selected
%   neighbourhood does not contain any valid input values.


%% ------------------------------------------------------------------------
%  VALIDATE INPUTS
%  -------------------------------------------------------------------------

if ~ismatrix(input)
    error('input must be a 2-D matrix.');
end

if ~isnumeric(input)
    error('input must be numeric.');
end

if ~(isscalar(window_size) && isfinite(window_size) && ...
        window_size >= 1 && window_size == round(window_size))

    error('window_size must be a positive integer.');

end


% Figure title is optional.
if nargin < 3 || isempty(name)
    name = 'NaN holes detected for filling';
end


%% ------------------------------------------------------------------------
%  IDENTIFY NaN REGIONS
%  -------------------------------------------------------------------------

% Logical mask containing all NaN locations.
nanMask = isnan(input);


% Identify only ENCLOSED NaN regions.
%
% imclearborder removes every connected NaN region that touches the image
% boundary. The remaining true pixels are therefore internal holes.
%
% 8-connectivity is used so diagonally connected NaN pixels belong to the
% same region.
holes = imclearborder(nanMask, 8);


%% ------------------------------------------------------------------------
%  DISPLAY DIAGNOSTIC IMAGE
%  -------------------------------------------------------------------------

figure( ...
    'Name', 'NaN hole detection', ...
    'NumberTitle', 'off');

imshowpair(holes, input);

title( ...
    name, ...
    'Interpreter', 'none');


%% ------------------------------------------------------------------------
%  INITIALIZE OUTPUT
%  -------------------------------------------------------------------------

output = input;


% Nothing more needs to be done when no enclosed NaN holes are present.
if ~any(holes(:))
    return;
end


%% ------------------------------------------------------------------------
%  DEFINE LOCAL WINDOW
%  -------------------------------------------------------------------------

% An odd-sized window can be perfectly centred around the target pixel.
%
% For an even-sized window, one side contains one additional pixel.
halfBefore = floor((window_size - 1) / 2);
halfAfter  = ceil((window_size - 1) / 2);


%% ------------------------------------------------------------------------
%  FIND NaN PIXELS THAT SHOULD BE FILLED
%  -------------------------------------------------------------------------

[rows, cols] = size(input);

[holeRows, holeCols] = find(holes);

numHolePixels = numel(holeRows);


%% ------------------------------------------------------------------------
%  FILL ENCLOSED NaN PIXELS
%  -------------------------------------------------------------------------

for k = 1:numHolePixels

    row = holeRows(k);
    col = holeCols(k);


    %% Determine neighbourhood boundaries

    rowMin = max(1, row - halfBefore);
    rowMax = min(rows, row + halfAfter);

    colMin = max(1, col - halfBefore);
    colMax = min(cols, col + halfAfter);


    %% Extract local neighbourhood

    localWindow = input( ...
        rowMin:rowMax, ...
        colMin:colMax);


    %% Remove NaN values

    validValues = localWindow(~isnan(localWindow));


    %% Fill using local median

    if ~isempty(validValues)

        % IMPORTANT:
        % Median is calculated from the original input rather than output.
        % Therefore previously interpolated pixels do not influence later
        % interpolation results.
        output(row, col) = median(validValues);

    end

end


%% ------------------------------------------------------------------------
%  REPORT UNFILLED INTERNAL HOLES
%  -------------------------------------------------------------------------

% A hole pixel can remain NaN when its complete neighbourhood contains
% only NaN values.
remainingHoles = holes & isnan(output);

numRemaining = nnz(remainingHoles);

if numRemaining > 0

    warning( ...
        'FillNaNs:UnfilledPixels', ...
        ['%d enclosed NaN pixels could not be filled because their ', ...
         'local neighbourhood contained no valid values.'], ...
        numRemaining);

end

end