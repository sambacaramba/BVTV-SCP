function saveAllOpenFigures(outputFolder)
%SAVEALLOPENFIGURES Export all currently open MATLAB figures as PNG files.
%
%   saveAllOpenFigures()
%   saveAllOpenFigures(outputFolder)
%
%   Saves all currently open MATLAB figures as PNG images.
%
%   The function first attempts to use exportgraphics. If that fails,
%   exportapp is attempted. As a final fallback, the figure is copied,
%   common UI controls are removed from the copy, and the cleaned copy is
%   exported.
%
% INPUT
%   outputFolder
%       Folder in which the figures are saved.
%
%       If omitted or empty, figures are saved in:
%
%           <current working directory>/saved_figures/
%
%       If supplied, figures are saved directly into that folder.
%
% OUTPUT
%   None.
%
% FILE NAMING
%   When a figure has a Name property, that name is used in the output
%   filename.
%
%   Examples:
%
%       01_ROI_segmentation_check.png
%       02_Trabecular_removal.png
%
%   Figures without a name receive a generic filename:
%
%       03_Figure.png


%% ------------------------------------------------------------------------
%  DETERMINE OUTPUT FOLDER
%  -------------------------------------------------------------------------

if nargin < 1 || isempty(outputFolder)

    % Default folder when none is supplied.
    outputFolder = fullfile( ...
        pwd, ...
        'saved_figures');

else

    % The supplied path is treated as the actual destination folder.
    outputFolder = char(outputFolder);

end


%% ------------------------------------------------------------------------
%  CREATE OUTPUT FOLDER
%  -------------------------------------------------------------------------

if ~exist(outputFolder, 'dir')

    [success, message] = mkdir(outputFolder);

    if ~success
        error( ...
            'saveAllOpenFigures:FolderCreationFailed', ...
            'Could not create output folder:\n%s\n%s', ...
            outputFolder, ...
            message);
    end

end


%% ------------------------------------------------------------------------
%  FIND OPEN FIGURES
%  -------------------------------------------------------------------------

figs = findall(groot, 'Type', 'figure');

% findall generally returns graphics objects in reverse creation order.
% Reverse the list so figures are usually saved oldest -> newest.
figs = flipud(figs);


%% Handle case where no figures are open

if isempty(figs)

    fprintf('No open figures found.\n');
    return;

end

fprintf( ...
    'Found %d open figure(s).\n', ...
    numel(figs));


%% ------------------------------------------------------------------------
%  EXPORT EACH FIGURE
%  -------------------------------------------------------------------------

for k = 1:numel(figs)

    fig = figs(k);


    %% --------------------------------------------------------------------
    %  CREATE OUTPUT FILENAME
    %  ---------------------------------------------------------------------

    % Use the MATLAB figure Name when available.
    figureName = '';

    try
        figureName = fig.Name;
    catch
        % Some unusual graphics objects may not expose Name normally.
    end


    if isempty(figureName)

        figureName = 'Figure';

    else

        % Convert string objects to character vectors.
        figureName = char(figureName);

        % Replace characters that are invalid or inconvenient in
        % filenames.
        figureName = regexprep( ...
            figureName, ...
            '[<>:"/\\|?*]', ...
            '_');

        % Replace repeated whitespace with underscores.
        figureName = regexprep( ...
            strtrim(figureName), ...
            '\s+', ...
            '_');

        % Avoid an empty filename after cleaning.
        if isempty(figureName)
            figureName = 'Figure';
        end

    end


    % Prefix with an index so that:
    %
    %   1. duplicate figure names remain unique
    %   2. figures sort in approximately creation order
    filenameBase = sprintf( ...
        '%02d_%s', ...
        k, ...
        figureName);


    pngFile = fullfile( ...
        outputFolder, ...
        [filenameBase, '.png']);


    %% --------------------------------------------------------------------
    %  MAKE SURE FIGURE HAS FINISHED DRAWING
    %  ---------------------------------------------------------------------

    % Ensures pending graphics updates are completed before capture.
    drawnow;


    %% --------------------------------------------------------------------
    %  METHOD 1: EXPORTGRAPHICS
    %  ---------------------------------------------------------------------

    try

        exportgraphics( ...
            fig, ...
            pngFile, ...
            'Resolution', 300);

        fprintf( ...
            'Saved: %s\n', ...
            pngFile);

        continue;

    catch ME1

        fprintf( ...
            'exportgraphics failed for figure %d: %s\n', ...
            k, ...
            ME1.message);

    end


    %% --------------------------------------------------------------------
    %  METHOD 2: EXPORTAPP
    %  ---------------------------------------------------------------------

    % exportapp can work better for some UI-based figures.
    try

        exportapp( ...
            fig, ...
            pngFile);

        fprintf( ...
            'Saved using exportapp: %s\n', ...
            pngFile);

        continue;

    catch ME2

        fprintf( ...
            'exportapp failed for figure %d: %s\n', ...
            k, ...
            ME2.message);

    end


    %% --------------------------------------------------------------------
    %  METHOD 3: COPY FIGURE AND REMOVE UI CONTROLS
    %  ---------------------------------------------------------------------

    % Initialize here so a failed copy operation cannot accidentally leave
    % a handle from a previous loop iteration.
    tempFig = [];


    try

        % Copy the figure so the original is never modified.
        tempFig = copyobj( ...
            fig, ...
            groot);

        set( ...
            tempFig, ...
            'Visible', ...
            'off');


        %% Remove common UI components from temporary copy

        delete(findall( ...
            tempFig, ...
            'Type', ...
            'uicontrol'));

        delete(findall( ...
            tempFig, ...
            'Type', ...
            'uimenu'));

        delete(findall( ...
            tempFig, ...
            'Type', ...
            'uitoolbar'));

        delete(findall( ...
            tempFig, ...
            'Type', ...
            'uitoggletool'));

        delete(findall( ...
            tempFig, ...
            'Type', ...
            'uipushtool'));


        % Ensure graphics are updated after deleting controls.
        drawnow;


        %% Export cleaned temporary copy

        exportgraphics( ...
            tempFig, ...
            pngFile, ...
            'Resolution', 300);


        %% Close temporary figure

        if isgraphics(tempFig)
            close(tempFig);
        end


        fprintf( ...
            'Saved using cleaned temporary copy: %s\n', ...
            pngFile);


    catch ME3

        warning( ...
            'saveAllOpenFigures:ExportFailed', ...
            ['Could not export figure %d using any available ', ...
             'method.\n%s'], ...
            k, ...
            ME3.message);


        % Clean up the temporary figure if it was successfully created
        % before the error occurred.
        if ~isempty(tempFig) && isgraphics(tempFig)
            close(tempFig);
        end

    end

end


%% ------------------------------------------------------------------------
%  SUMMARY
%  -------------------------------------------------------------------------

fprintf( ...
    'Figure export complete. Output folder:\n%s\n', ...
    outputFolder);

end