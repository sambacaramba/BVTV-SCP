function smoothsurf = smoothsurfaceGAUSS(surf, kernelsize)
%SMOOTHSURFACEGAUSS Smooth a 2-D surface using a NaN-aware Gaussian filter.
%
%   smoothsurf = smoothsurfaceGAUSS(surf, kernelsize)
%
%   Applies Gaussian smoothing to a 2-D surface while ignoring NaN values.
%   Missing values do not contribute to the local weighted average.
%
%   The output preserves NaNs at exactly the same positions as the input.
%
% INPUTS
%   surf
%       M-by-N numeric surface map.
%
%       Valid surface coordinates should contain finite numeric values.
%       Missing or invalid surface locations should be represented by NaN.
%
%   kernelsize
%       Width of the square Gaussian kernel, in pixels.
%
%       An odd value is recommended, for example:
%
%           kernelsize = 31
%
%       If an even value is supplied, it is increased by one so that the
%       kernel has a well-defined centre pixel.
%
% OUTPUT
%   smoothsurf
%       Gaussian-smoothed surface with NaNs preserved at their original
%       locations.
%
% METHOD
%   Standard convolution cannot directly handle NaN values because a
%   single NaN would contaminate neighbouring results.
%
%   This function therefore performs two convolutions:
%
%       1. Surface values, with NaNs temporarily replaced by zero.
%       2. A logical validity mask using the same Gaussian kernel.
%
%   Dividing the weighted surface values by the corresponding valid
%   Gaussian weights produces a normalized average using only available
%   surface points.
%
%   Near image boundaries, or next to NaN regions, the Gaussian kernel is
%   automatically renormalized using only available samples.


%% ------------------------------------------------------------------------
%  VALIDATE INPUTS
%  -------------------------------------------------------------------------

if ~ismatrix(surf) || isempty(surf)
    error('surf must be a non-empty 2-D matrix.');
end

if ~isnumeric(surf)
    error('surf must be numeric.');
end

if ~(isscalar(kernelsize) && ...
        isfinite(kernelsize) && ...
        kernelsize >= 1 && ...
        kernelsize == round(kernelsize))

    error('kernelsize must be a positive integer.');

end


% Surface values may contain NaN, but infinity would contaminate the
% convolution and should therefore not be accepted.
if any(isinf(surf(:)))
    error('surf must not contain Inf or -Inf values.');
end


%% ------------------------------------------------------------------------
%  ENSURE ODD KERNEL SIZE
%  -------------------------------------------------------------------------

% A Gaussian kernel should have a unique centre pixel.
if mod(kernelsize, 2) == 0
    kernelsize = kernelsize + 1;
end

kernelRadius = floor(kernelsize / 2);


%% ------------------------------------------------------------------------
%  CREATE GAUSSIAN KERNEL
%  -------------------------------------------------------------------------

% Choose sigma so that the kernel extends approximately three standard
% deviations from its centre to its edge.
%
% For example:
%
%       kernelsize = 31
%       radius     = 15 pixels
%       sigma      = 5 pixels
%
% For very small kernels, sigma is limited to at least one pixel.
sigma = max(1, kernelRadius / 3);


% Kernel coordinates centred at zero.
[xKernel, yKernel] = meshgrid( ...
    -kernelRadius:kernelRadius, ...
    -kernelRadius:kernelRadius);


% Two-dimensional Gaussian.
gaussianKernel = exp( ...
    -(xKernel.^2 + yKernel.^2) / (2 * sigma^2));


% Normalize the complete kernel so that its weights sum to one.
gaussianKernel = ...
    gaussianKernel / sum(gaussianKernel(:));


%% ------------------------------------------------------------------------
%  CREATE VALID-DATA MASK
%  -------------------------------------------------------------------------

% Valid surface locations contain finite numeric values.
validMask = ~isnan(surf);


% Replace NaNs temporarily with zero.
%
% These zeros do NOT contribute to the final average because the same
% Gaussian convolution is also applied to validMask below.
surfaceForFiltering = double(surf);

surfaceForFiltering(~validMask) = 0;


%% ------------------------------------------------------------------------
%  GAUSSIAN CONVOLUTION
%  -------------------------------------------------------------------------

% Weighted sum of available surface values.
weightedSurface = conv2( ...
    surfaceForFiltering, ...
    gaussianKernel, ...
    'same');


% Sum of Gaussian weights corresponding to valid input values.
validWeight = conv2( ...
    double(validMask), ...
    gaussianKernel, ...
    'same');


%% ------------------------------------------------------------------------
%  NORMALIZE BY AVAILABLE GAUSSIAN WEIGHT
%  -------------------------------------------------------------------------

% Initialize as NaN so locations without any valid neighbouring samples
% remain undefined.
smoothsurf = nan(size(surf));


% Locations where at least one valid input value contributed.
hasSupport = validWeight > 0;


% Normalize the weighted sum using only the Gaussian weight associated
% with valid samples.
smoothsurf(hasSupport) = ...
    weightedSurface(hasSupport) ./ validWeight(hasSupport);


%% ------------------------------------------------------------------------
%  PRESERVE ORIGINAL NaN MASK
%  -------------------------------------------------------------------------

% Smoothing should not expand the valid surface into regions that were
% originally undefined.
smoothsurf(~validMask) = NaN;

end