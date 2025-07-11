classdef SatelliteChangeAppTwo < matlab.apps.AppBase

    properties (Access = public)

        RegisteredImages cell
        FlickerRegisteredImage

        UIFigure matlab.ui.Figure
        LoadFolderButton matlab.ui.control.Button
        ChangeTypeGroup matlab.ui.container.ButtonGroup
        AllButton matlab.ui.control.RadioButton
        CityButton matlab.ui.control.RadioButton
        WaterButton matlab.ui.control.RadioButton
        RiverButton matlab.ui.control.RadioButton
        ForestButton matlab.ui.control.RadioButton
        IceButton matlab.ui.control.RadioButton
        DesertButton matlab.ui.control.RadioButton
        FieldButton matlab.ui.control.RadioButton
        GlacierButton matlab.ui.control.RadioButton
        FrauenkircheButton matlab.ui.control.RadioButton
        OktoberfestButton matlab.ui.control.RadioButton

        VisualizationDropDown matlab.ui.control.DropDown
        ReplayModeDropdown matlab.ui.control.DropDown

        InfoTextArea matlab.ui.control.TextArea
        infoPanel matlab.ui.container.Panel
        CurrentVisMode string = 'Overlay' % Default visualization mode
        PlaybackTimer timer
        IsPlaying logical = false

        FlickerState logical = false
        TimelapseFrames cell
        TimelapseFrameIndex double = 1
        HeatmapAlphaSlider matlab.ui.control.Slider
        HeatmapAlphaLabel matlab.ui.control.Label
        HeatmapColorMapDropDown matlab.ui.control.DropDown
        HeatmapColorMapLabel matlab.ui.control.Label
        GaussianSigmaSlider matlab.ui.control.Slider
        GaussianSigmaLabel matlab.ui.control.Label

        ComputedOverlays struct % Stores overlays for all visualization methods
        ComputedOverlaysStats struct % Stores stats for all visualization methods
        OverlaysComputed logical = false % Track if overlays are up-to-date

        % Global indices for easier access
        Indices struct % Contains img and imgRef fields for current image indices

        % Track active overlay type for stats access
        overlayType string = 'Heatmap' % Default overlay type for stats access

        ImageDropDown1 matlab.ui.control.DropDown
        ImageDropDown2 matlab.ui.control.DropDown
        LeftArrowButton2 matlab.ui.control.Button
        RightArrowButton2 matlab.ui.control.Button
        ImageAxes1 matlab.ui.control.UIAxes
        ImageAxes2 matlab.ui.control.UIAxes
        ResultAxes matlab.ui.control.UIAxes
        PlaybackPanel matlab.ui.container.Panel
        PlayButton matlab.ui.control.Button
        PauseButton matlab.ui.control.Button
        SpeedSlider matlab.ui.control.Slider
        VisualizeButton matlab.ui.control.Button
        AdvancedPanel matlab.ui.container.Panel
        AdvancedCheck matlab.ui.control.CheckBox
        AdvancedToggle matlab.ui.control.Button
        ShowMasksButton matlab.ui.control.Button

        ImageFolder string
        ImageFiles struct
        Images cell

    end

    methods (Access = private)

        function selectedMask = getSelectedMask(app)
            % Get the currently selected mask category from the radio button group
            selectedButton = app.ChangeTypeGroup.SelectedObject;

            if isempty(selectedButton)
                selectedMask = 'all'; % Default fallback
                return;
            end

            % Map button to mask category
            switch selectedButton
                case app.AllButton
                    selectedMask = 'all';
                case app.CityButton
                    selectedMask = 'city';
                case app.WaterButton
                    selectedMask = 'water';
                case app.RiverButton
                    selectedMask = 'river';
                case app.ForestButton
                    selectedMask = 'forest';
                case app.IceButton
                    selectedMask = 'ice';
                case app.DesertButton
                    selectedMask = 'desert';
                case app.FieldButton
                    selectedMask = 'field';
                case app.GlacierButton
                    selectedMask = 'glacier';
                case app.FrauenkircheButton
                    selectedMask = 'frauenkirche';
                case app.OktoberfestButton
                    selectedMask = 'oktoberfest';
                otherwise
                    selectedMask = 'all';
            end

        end

        function fieldName = getVisualizationFieldName(app, dropdownValue)
            % Map dropdown display names to struct field names
            switch dropdownValue
                case 'Overlay'
                    fieldName = 'Overlay';
                case 'Absolute Difference'
                    fieldName = 'AbsoluteDifference';
                case 'Heatmap'
                    fieldName = 'Heatmap';
                case 'Red Overlay'
                    fieldName = 'RedOverlay';
                otherwise
                    fieldName = 'Overlay'; % Default fallback
            end

        end

        function onMaskCategoryChanged(app, ~)
            % Callback when mask category radio button changes
            app.OverlaysComputed = false; % Mark overlays as outdated
            app.TimelapseFrames = {}; % Clear cached timelapse frames

            % Auto-recompute and display
            if ~isempty(app.RegisteredImages)
                autoRecomputeAndDisplay(app);
            end

        end

        function onParameterChanged(app, ~)
            % Callback when any overlay parameter changes (alpha, sigma, colormap)
            app.OverlaysComputed = false; % Mark overlays as outdated
            app.TimelapseFrames = {}; % Clear cached timelapse frames

            % Auto-recompute and display
            if ~isempty(app.RegisteredImages)
                autoRecomputeAndDisplay(app);
            end

        end

        function onReferenceImageChanged(app, ~)
            % Callback when reference image (ImageDropDown1) changes

            % Update global indices
            app.Indices.imgRef = find(strcmp(app.ImageDropDown1.Items, app.ImageDropDown1.Value));

            if ~isempty(app.RegisteredImages)
                % Re-register all images against the new reference
                reRegisterImagesAgainstNewReference(app);

                % Update both image previews to show the newly registered images
                updateImagePreview(app, 1);
                updateImagePreview(app, 2);

                % Mark overlays as outdated and auto-recompute
                app.OverlaysComputed = false;
                app.TimelapseFrames = {};
                autoRecomputeAndDisplay(app);
            else
                % If no registered images yet, just update the preview
                updateImagePreview(app, 1);
            end

        end

        function onComparisonImageChanged(app, ~)
            % Callback when comparison image (ImageDropDown2) changes

            % Update global indices
            app.Indices.img = find(strcmp(app.ImageDropDown2.Items, app.ImageDropDown2.Value));

            updateImagePreview(app, 2);

            % Just auto-display with existing overlays (no recomputation needed)
            if ~isempty(app.RegisteredImages) && app.OverlaysComputed
                autoDisplay(app);
            elseif ~isempty(app.RegisteredImages)
                % If overlays not computed yet, compute them first
                autoRecomputeAndDisplay(app);
            end

        end

        function onLeftArrowPressed(app, ~)
            % Navigate to previous image in ImageDropDown2
            if isempty(app.ImageDropDown2.Items)
                return;
            end

            currentIdx = find(strcmp(app.ImageDropDown2.Items, app.ImageDropDown2.Value));

            if isempty(currentIdx)
                return;
            end

            % Move to previous image (wrap around to last if at first)
            newIdx = currentIdx - 1;

            if newIdx < 1
                newIdx = length(app.ImageDropDown2.Items);
            end

            app.ImageDropDown2.Value = app.ImageDropDown2.Items{newIdx};
            onComparisonImageChanged(app);
        end

        function onRightArrowPressed(app, ~)
            % Navigate to next image in ImageDropDown2
            if isempty(app.ImageDropDown2.Items)
                return;
            end

            currentIdx = find(strcmp(app.ImageDropDown2.Items, app.ImageDropDown2.Value));

            if isempty(currentIdx)
                return;
            end

            % Move to next image (wrap around to first if at last)
            newIdx = currentIdx + 1;

            if newIdx > length(app.ImageDropDown2.Items)
                newIdx = 1;
            end

            app.ImageDropDown2.Value = app.ImageDropDown2.Items{newIdx};
            onComparisonImageChanged(app);
        end

        function LoadFolderButtonPushed(app, ~)
            folder = uigetdir;
            if folder == 0, return; end

            % Find all valid image files
            exts = {'*.jpg', '*.jpeg', '*.png', '*.tif', '*.tiff'};
            imageFilesCell = cell(1, numel(exts));

            for i = 1:numel(exts)
                imageFilesCell{i} = dir(fullfile(folder, exts{i}));
            end

            imageFiles = vertcat(imageFilesCell{:});

            if isempty(imageFiles)
                uialert(app.UIFigure, 'No supported images found.', 'Error');
                return;
            end

            % Store image file info
            app.ImageFiles = imageFiles;

            % Populate dropdowns with file names
            names = {imageFiles.name};
            app.ImageDropDown1.Items = names;
            app.ImageDropDown2.Items = names;

            % Set default selections
            app.ImageDropDown1.Value = names{1};
            app.ImageDropDown2.Value = names{min(2, numel(names))};

            % Initialize global indices
            app.Indices.imgRef = 1; % Reference image (first image)
            app.Indices.img = min(2, numel(names)); % Comparison image (second image or first if only one)

            % Register images incrementally
            app.RegisteredImages = cell(1, numel(imageFiles)); % Preallocate
            ref_img = app.getImageByIndex(1); % First image is the reference
            app.RegisteredImages{1} = ref_img; % Store the first image as-is

            h = uiprogressdlg(app.UIFigure, ...
                'Title', 'Registering Images', ...
                'Message', 'Please wait...', ...
                'Indeterminate', 'off', ...
                'Cancelable', 'off');

            for k = 2:numel(imageFiles)
                moving_img = app.getImageByIndex(k);

                try
                    reg = registration.registerImagesSURF(moving_img, app.RegisteredImages{k - 1}); % Register onto the previous image
                    app.RegisteredImages{k} = reg.registered;
                catch
                    app.RegisteredImages{k} = moving_img; % Fallback to raw image
                end

                h.Value = k / numel(imageFiles);
                h.Message = sprintf('Registering image %d of %d...', k, numel(imageFiles));
                drawnow;
            end

            close(h);

            % Reset overlay computation flag
            app.OverlaysComputed = false;
            app.TimelapseFrames = {};

            % Update previews
            updateImagePreview(app, 1);
            updateImagePreview(app, 2);

            % Link all axes for synchronized zoom and pan after images are loaded
            linkaxes([app.ImageAxes1, app.ImageAxes2, app.ResultAxes], 'xy');

            % Reset axis limits to ensure proper initial view
            axis(app.ImageAxes1, 'image');
            axis(app.ImageAxes2, 'image');
            axis(app.ResultAxes, 'image');

            % Turn off axis visibility
            axis(app.ImageAxes1, 'off');
            axis(app.ImageAxes2, 'off');
            axis(app.ResultAxes, 'off');

            % Update info
            app.InfoTextArea.Value = sprintf('Loaded and registered %d images incrementally.', numel(names));

            % Force window to front and maximized
            app.UIFigure.WindowState = 'maximized';
            drawnow;
        end

        function img = getImageByIndex(app, idx)
            filepath = fullfile(app.ImageFiles(idx).folder, app.ImageFiles(idx).name);
            img = imread(filepath);
        end

        function [img1, img2reg] = getRegisteredImagePair(app)
            idx1 = find(strcmp(app.ImageDropDown1.Items, app.ImageDropDown1.Value));
            idx2 = find(strcmp(app.ImageDropDown2.Items, app.ImageDropDown2.Value));

            if isempty(idx1) || isempty(idx2)
                img1 = [];
                img2reg = [];
                return;
            end

            img1 = app.RegisteredImages{idx1};
            img2reg = app.RegisteredImages{idx2};
        end

        function onVisualizationModeChanged(app, ~)
            % Stop any running playback
            onPauseButtonPressed(app);

            % Update overlay type for stats access
            switch app.VisualizationDropDown.Value
                case 'Heatmap'
                    app.overlayType = 'Heatmap';
                case 'Red Overlay'
                    app.overlayType = 'RedOverlay';
                otherwise
                    app.overlayType = 'Heatmap'; % Default to Heatmap for stats
            end

            % Auto-display with the new visualization mode
            if ~isempty(app.RegisteredImages) && app.OverlaysComputed
                autoDisplay(app);
            end

        end

        function ensureOverlaysComputed(app)
            % Ensure overlays are computed and up-to-date before using them
            if ~app.OverlaysComputed || isempty(app.ComputedOverlays)
                computeOverlays(app);
            end

        end

        function computeOverlays(app)
            % Stage 1: Prepare registered images
            [img1, ~] = getRegisteredImagePair(app);

            if isempty(img1) || isempty(app.RegisteredImages)
                return;
            end

            % Stage 2: Get selected mask category and parameters
            selectedMask = getSelectedMask(app);

            % Prepare parameters for heatmap and red overlay
            params = struct();
            params.alpha = app.HeatmapAlphaSlider.Value;
            params.gaussian_sigma = app.GaussianSigmaSlider.Value;
            params.colormap_name = app.HeatmapColorMapDropDown.Value;

            % Stage 3: Initialize storage for all overlay types
            numImages = numel(app.RegisteredImages);
            app.ComputedOverlays = struct('Overlay', cell(1, numImages), ...
                'AbsoluteDifference', cell(1, numImages), ...
                'Heatmap', cell(1, numImages), ...
                'RedOverlay', cell(1, numImages), ...
                'HeatmapStats', cell(1, numImages), ...
                'RedOverlayStats', cell(1, numImages));

            % Stage 4: Compute overlays for all images based on mask regions
            h = uiprogressdlg(app.UIFigure, ...
                'Title', 'Computing Overlays', ...
                'Message', 'Please wait...', ...
                'Indeterminate', 'off', ...
                'Cancelable', 'off');

            for i = 1:numImages
                img2 = app.RegisteredImages{i};

                % Basic overlay (simple blend)
                app.ComputedOverlays(i).Overlay = 0.5 * im2double(img1) + 0.5 * im2double(img2);

                % Absolute Difference
                app.ComputedOverlays(i).AbsoluteDifference = abs(im2double(img1) - im2double(img2));

                % Heatmap overlay (uses mask regions)
                try
                    [heatmapOverlay, stats] = visualization.get_heatmap_overlay(img1, img2, selectedMask, params);
                    app.ComputedOverlays(i).Heatmap = heatmapOverlay;
                    app.ComputedOverlays(i).HeatmapStats = stats;
                    fprintf('Heatmap overlay computed successfully for image %d\n', i);
                catch ME
                    % Fallback to absolute difference if heatmap fails
                    app.ComputedOverlays(i).Heatmap = app.ComputedOverlays(i).AbsoluteDifference;
                    app.ComputedOverlays(i).HeatmapStats = struct(); % Empty stats
                    warning('Heatmap computation failed for image %d: %s', i, ME.message);
                end

                % Red overlay (uses mask regions) - SAME processing flow as heatmap
                try
                    [redOverlay, stats] = visualization.get_red_overlay(img1, img2, selectedMask, params);
                    app.ComputedOverlays(i).RedOverlay = redOverlay;
                    app.ComputedOverlays(i).RedOverlayStats = stats;
                    fprintf('Red overlay computed successfully for image %d\n', i);
                catch ME
                    % Fallback to absolute difference if red overlay fails
                    app.ComputedOverlays(i).RedOverlay = app.ComputedOverlays(i).AbsoluteDifference;
                    app.ComputedOverlays(i).RedOverlayStats = struct(); % Empty stats
                    warning('Red overlay computation failed for image %d: %s', i, ME.message);
                end

                h.Value = i / numImages;
                h.Message = sprintf('Computing overlays %d of %d...', i, numImages);
                drawnow;
            end

            close(h);

            % Stage 5: Mark overlays as computed and clear cached frames
            app.OverlaysComputed = true;
            app.TimelapseFrames = {}; % Clear to force regeneration with new overlays
        end

        function prepareTimelapseFrames(app, mode)
            % Prepare timelapse frames for the selected visualization mode
            if isempty(app.ComputedOverlays)
                return;
            end

            % Map dropdown value to field name
            fieldName = getVisualizationFieldName(app, mode);

            % Extract all overlays of the selected mode into a cell array
            app.TimelapseFrames = {app.ComputedOverlays.(fieldName)};
            app.TimelapseFrameIndex = 1;
        end

        function onVisualizeButtonPressed(app, ~)
            % Ensure overlays are computed and up-to-date
            ensureOverlaysComputed(app);

            if isempty(app.ComputedOverlays)
                uialert(app.UIFigure, 'No overlays computed. Please load images first.', 'Error');
                return;
            end

            % Get selected visualization method
            mode = app.VisualizationDropDown.Value;
            fieldName = getVisualizationFieldName(app, mode);
            selectedMask = getSelectedMask(app);

            % Display the overlay for the selected second image
            idx2 = find(strcmp(app.ImageDropDown2.Items, app.ImageDropDown2.Value));

            if ~isempty(idx2) && idx2 <= numel(app.ComputedOverlays)
                % Verify the overlay exists
                if isfield(app.ComputedOverlays, fieldName) && ~isempty(app.ComputedOverlays(idx2).(fieldName))
                    overlayImage = app.ComputedOverlays(idx2).(fieldName);
                    imshow(overlayImage, 'Parent', app.ResultAxes, 'InitialMagnification', 'fit');
                    title(app.ResultAxes, sprintf('%s (%s): %s → %s', ...
                        mode, selectedMask, ...
                        strrep(app.ImageDropDown1.Value, '_', ' '), ...
                        strrep(app.ImageDropDown2.Value, '_', ' ')));
                    fprintf('Successfully displayed %s overlay for image %d\n', mode, idx2);
                else
                    uialert(app.UIFigure, sprintf('%s overlay not available. Please recompute overlays.', mode), 'Error');
                    fprintf('ERROR: %s overlay not found for image %d\n', mode, idx2);
                end

            end

        end

        function updateImagePreview(app, index)

            if index == 1
                ax = app.ImageAxes1;
                dropdown = app.ImageDropDown1;
                axTitle = 'Image 1';
            else
                ax = app.ImageAxes2;
                dropdown = app.ImageDropDown2;
                axTitle = 'Image 2';
            end

            if isempty(app.RegisteredImages) || isempty(dropdown.Items)
                blank = ones(100, 100, 3);
                imshow(blank, 'Parent', ax);
                axis(ax, 'off');
                title(ax, axTitle);
                return;
            end

            name = dropdown.Value;
            idx = find(strcmp({app.ImageFiles.name}, name), 1);

            if isempty(idx)
                blank = ones(100, 100, 3);
                imshow(blank, 'Parent', ax);
                axis(ax, 'off');
                title(ax, [axTitle, ' (Not found)']);
                return;
            end

            % Display registered image
            img = app.RegisteredImages{idx};
            imshow(img, 'Parent', ax);
            axis(ax, 'image');
            axis(ax, 'off');
            title(ax, axTitle);
        end

        function onPlayButtonPressed(app)
            % Stop if already playing
            if app.IsPlaying
                onPauseButtonPressed(app);
            end

            % Ensure overlays are computed before starting playback
            ensureOverlaysComputed(app);

            if isempty(app.ComputedOverlays)
                uialert(app.UIFigure, 'No overlays computed. Please visualize first.', 'Error');
                return;
            end

            app.CurrentVisMode = app.VisualizationDropDown.Value;

            % Handle Static mode differently - no timer needed
            if strcmp(app.ReplayModeDropdown.Value, 'Static')
                % For static mode, just run the playback step once
                runPlaybackStep(app);
                return;
            end

            app.IsPlaying = true;

            % Prepare/reset flicker state
            app.FlickerState = false;

            % Prepare timelapse frames if needed
            if strcmp(app.ReplayModeDropdown.Value, 'Timelapse')
                prepareTimelapseFrames(app, app.CurrentVisMode);
            end

            % Use SpeedSlider value for timer period (lower = faster)
            minPeriod = 0.1;
            maxPeriod = 2;
            sliderVal = app.SpeedSlider.Value;
            period = minPeriod + (maxPeriod - minPeriod) * (1 - (sliderVal - minPeriod) / (maxPeriod - minPeriod));
            period = max(minPeriod, min(maxPeriod, period));

            % Create a new timer
            app.PlaybackTimer = timer( ...
                'ExecutionMode', 'fixedSpacing', ...
                'Period', period, ...
                'TimerFcn', @(~, ~) runPlaybackStep(app));

            start(app.PlaybackTimer);
        end

        function onPauseButtonPressed(app)
            app.IsPlaying = false;

            if ~isempty(app.PlaybackTimer) && isvalid(app.PlaybackTimer)
                stop(app.PlaybackTimer);
                delete(app.PlaybackTimer);
            end

        end

        function runPlaybackStep(app)

            if isempty(app.ComputedOverlays)
                uialert(app.UIFigure, 'No overlays available for replay.', 'Error');
                return;
            end

            mode = app.VisualizationDropDown.Value;
            fieldName = getVisualizationFieldName(app, mode);
            idx2 = find(strcmp(app.ImageDropDown2.Items, app.ImageDropDown2.Value));

            switch app.ReplayModeDropdown.Value
                case 'Flicker'
                    % Flicker between the selected second image and its overlay
                    if isempty(idx2) || idx2 > numel(app.ComputedOverlays)
                        return;
                    end

                    if app.FlickerState
                        % Verify the overlay exists before using it
                        if isfield(app.ComputedOverlays, fieldName) && ~isempty(app.ComputedOverlays(idx2).(fieldName))
                            overlayImage = app.ComputedOverlays(idx2).(fieldName);
                            imshow(overlayImage, 'Parent', app.ResultAxes, 'InitialMagnification', 'fit');
                            title(app.ResultAxes, sprintf('%s Overlay', mode));
                        else
                            % Fall back to original image if overlay not available
                            imshow(app.RegisteredImages{idx2}, 'Parent', app.ResultAxes, 'InitialMagnification', 'fit');
                            title(app.ResultAxes, sprintf('%s Overlay (Not Available)', mode));
                            fprintf('WARNING: %s overlay not available for flicker, showing original image\n', mode);
                        end

                    else
                        imshow(app.RegisteredImages{idx2}, 'Parent', app.ResultAxes, 'InitialMagnification', 'fit');
                        title(app.ResultAxes, 'Original Image');
                    end

                    app.FlickerState = ~app.FlickerState;

                case 'Timelapse'
                    % Timelapse through all overlays for the chosen visualization method
                    if isempty(app.TimelapseFrames)
                        prepareTimelapseFrames(app, mode);
                    end

                    if ~isempty(app.TimelapseFrames)
                        currentFrame = app.TimelapseFrames{app.TimelapseFrameIndex};
                        imshow(currentFrame, 'Parent', app.ResultAxes, 'InitialMagnification', 'fit');
                        title(app.ResultAxes, sprintf('%s Timelapse - Frame %d/%d', ...
                            mode, app.TimelapseFrameIndex, numel(app.TimelapseFrames)));
                        app.TimelapseFrameIndex = mod(app.TimelapseFrameIndex, numel(app.TimelapseFrames)) + 1;
                    end

                case 'Static'
                    % Static mode: Use existing preprocessed overlays from cells
                    if isempty(idx2) || idx2 > numel(app.ComputedOverlays)
                        return;
                    end

                    % Just take the right image from existing preprocessed cells
                    if isfield(app.ComputedOverlays, fieldName) && ~isempty(app.ComputedOverlays(idx2).(fieldName))
                        overlayImage = app.ComputedOverlays(idx2).(fieldName);
                        imshow(overlayImage, 'Parent', app.ResultAxes, 'InitialMagnification', 'fit');
                        title(app.ResultAxes, sprintf('%s Static Overlay: %s → %s', ...
                            mode, ...
                            strrep(app.ImageDropDown1.Value, '_', ' '), ...
                            strrep(app.ImageDropDown2.Value, '_', ' ')));
                        fprintf('Static mode: Displaying preprocessed %s overlay for image %d\n', mode, idx2);
                    else
                        uialert(app.UIFigure, sprintf('%s overlay not available. Please compute overlays first.', mode), 'Error');
                        fprintf('ERROR: Static mode - %s overlay not found for image %d\n', mode, idx2);
                    end

            end

        end

        function onSpeedSliderChanged(app, ~)

            if app.IsPlaying
                onPauseButtonPressed(app); % Stop current timer
                onPlayButtonPressed(app); % Restart with new speed
            end

        end

        function toggleAdvancedPanel(app)

            if strcmp(app.AdvancedPanel.Visible, 'off')
                app.AdvancedPanel.Visible = 'on';
                app.AdvancedToggle.Text = 'Hide Advanced Settings ▲';
            else
                app.AdvancedPanel.Visible = 'off';
                app.AdvancedToggle.Text = 'Show Advanced Settings ▼';
            end

        end

        function reRegisterImagesAgainstNewReference(app)
            % Re-register all images against the newly selected reference image
            if isempty(app.RegisteredImages) || isempty(app.ImageDropDown1.Items)
                return;
            end

            % Get the index of the new reference image
            refIdx = find(strcmp(app.ImageDropDown1.Items, app.ImageDropDown1.Value));

            if isempty(refIdx)
                return;
            end

            h = uiprogressdlg(app.UIFigure, ...
                'Title', 'Re-registering Images', ...
                'Message', 'Please wait...', ...
                'Indeterminate', 'off', ...
                'Cancelable', 'off');

            % Get the new reference image (load from original file)
            ref_img = app.getImageByIndex(refIdx);

            % Clear and rebuild the registered images array
            app.RegisteredImages = cell(1, numel(app.ImageFiles));
            app.RegisteredImages{refIdx} = ref_img; % Reference image stays as-is

            % Register all other images against the new reference
            for k = 1:numel(app.ImageFiles)

                if k == refIdx
                    continue; % Skip reference image
                end

                moving_img = app.getImageByIndex(k);

                try
                    reg = registration.registerImagesSURF(moving_img, ref_img);
                    app.RegisteredImages{k} = reg.registered;
                catch
                    app.RegisteredImages{k} = moving_img; % Fallback to raw image
                end

                h.Value = k / numel(app.ImageFiles);
                h.Message = sprintf('Re-registering image %d of %d against new reference...', k, numel(app.ImageFiles));
                drawnow;
            end

            close(h);

            % Update info
            app.InfoTextArea.Value = sprintf('Re-registered %d images against new reference: %s', ...
                numel(app.ImageFiles), strrep(app.ImageDropDown1.Value, '_', ' '));
        end

        function autoRecomputeAndDisplay(app)
            % Automatically recompute overlays and display result
            computeOverlays(app);
            autoDisplay(app);
        end

        function autoDisplay(app)
            % Automatically display the current visualization without manual button press
            if isempty(app.ComputedOverlays)
                return;
            end

            % Get selected visualization method
            mode = app.VisualizationDropDown.Value;
            fieldName = getVisualizationFieldName(app, mode);
            selectedMask = getSelectedMask(app);

            % Display the overlay for the selected second image
            idx2 = find(strcmp(app.ImageDropDown2.Items, app.ImageDropDown2.Value));

            if ~isempty(idx2) && idx2 <= numel(app.ComputedOverlays)
                % Verify the overlay exists
                if isfield(app.ComputedOverlays, fieldName) && ~isempty(app.ComputedOverlays(idx2).(fieldName))
                    overlayImage = app.ComputedOverlays(idx2).(fieldName);
                    imshow(overlayImage, 'Parent', app.ResultAxes, 'InitialMagnification', 'fit');
                    title(app.ResultAxes, sprintf('%s (%s): %s → %s', ...
                        mode, selectedMask, ...
                        strrep(app.ImageDropDown1.Value, '_', ' '), ...
                        strrep(app.ImageDropDown2.Value, '_', ' ')));
                    fprintf('Auto-displayed %s overlay for image %d\n', mode, idx2);
                end

            end

        end

    end

    methods (Access = private)

        function createComponents(app)
            % Main window
            app.UIFigure = uifigure('Position', [100 100 1000 600]);
            app.UIFigure.Name = 'Satellite Change Visualizer';
            app.UIFigure.WindowState = 'maximized';

            % Load Folder Button
            app.LoadFolderButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Load Image Folder', ...
                'Position', [20 540 180 30], ...
                'ButtonPushedFcn', @(btn, event) LoadFolderButtonPushed(app));

            % Change Type Radio Group - Updated to include all mask categories
            app.ChangeTypeGroup = uibuttongroup(app.UIFigure, ...
                'Title', 'Mask Category', ...
                'Position', [20 330 180 200], ... % Adjusted position to push down
                'SelectionChangedFcn', @(bg, event) onMaskCategoryChanged(app, event)); % Add callback

            % Create radio buttons for all valid categories
            app.AllButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'All', ...
                'Position', [10 160 80 20], ...
                'Value', true); % Default selection

            app.CityButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'City', ...
                'Position', [90 160 80 20]);

            app.WaterButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Water', ...
                'Position', [10 140 80 20]);

            app.RiverButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'River', ...
                'Position', [90 140 80 20]);

            app.ForestButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Forest', ...
                'Position', [10 120 80 20]);

            app.IceButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Ice', ...
                'Position', [90 120 80 20]);

            app.DesertButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Desert', ...
                'Position', [10 100 80 20]);

            app.FieldButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Field', ...
                'Position', [90 100 80 20]);

            app.GlacierButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Glacier', ...
                'Position', [10 80 80 20]);

            app.FrauenkircheButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Frauenkirche', ...
                'Position', [90 80 80 20]);

            app.OktoberfestButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Oktoberfest', ...
                'Position', [10 60 80 20]);

            % Visualization Type Dropdown
            app.VisualizationDropDown = uidropdown(app.UIFigure, ...
                'Items', {'Overlay', 'Absolute Difference', 'Heatmap', 'Red Overlay'}, ...
                'Value', 'Overlay', ...
                'Position', [20 310 180 30]);

            % Toggle button to show/hide advanced settings
            app.AdvancedToggle = uibutton(app.UIFigure, 'push', ...
                'Text', 'Show Advanced Settings ▼', ...
                'Position', [20 270 180 30], ...
                'ButtonPushedFcn', @(btn, event) toggleAdvancedPanel(app));

            % --- Advanced Settings Collapsible Section ---
            app.AdvancedPanel = uipanel(app.UIFigure, ...
                'Position', [20 100 180 170], ... % moved down below toggle button
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.97 0.97 0.97], ...
                'Visible', 'off'); % Start collapsed

            % Heatmap Alpha Label
            app.HeatmapAlphaLabel = uilabel(app.AdvancedPanel, ...
                'Text', 'Heatmap Alpha:', ...
                'Position', [10 110 160 20]);

            % Heatmap Alpha Slider
            app.HeatmapAlphaSlider = uislider(app.AdvancedPanel, ...
                'Position', [10 100 160 3], ...
                'Limits', [0 1], ...
                'Value', 0.6, ...
                'MajorTicks', [0 0.25 0.5 0.75 1], ...
                'Tooltip', 'Alpha transparency', ...
                'ValueChangedFcn', @(slider, event) onParameterChanged(app, event)); % Add callback

            % Gaussian Sigma Label
            app.GaussianSigmaLabel = uilabel(app.AdvancedPanel, ...
                'Text', 'Gaussian Sigma:', ...
                'Position', [10 70 160 20]);

            % Gaussian Sigma Slider
            app.GaussianSigmaSlider = uislider(app.AdvancedPanel, ...
                'Position', [10 60 160 3], ...
                'Limits', [0.1 5], ...
                'Value', 1.0, ...
                'MajorTicks', [0.1 1 2 3 4 5], ...
                'Tooltip', 'Gaussian smoothing sigma', ...
                'ValueChangedFcn', @(slider, event) onParameterChanged(app, event)); % Add callback

            % Heatmap Colormap Dropdown Label
            app.HeatmapColorMapLabel = uilabel(app.AdvancedPanel, ...
                'Text', 'Colormap:', ...
                'Position', [10 30 160 20]);

            % Heatmap Colormap Dropdown
            app.HeatmapColorMapDropDown = uidropdown(app.AdvancedPanel, ...
                'Items', {'jet', 'hot', 'parula', 'turbo'}, ...
                'Value', 'jet', ...
                'Position', [10 10 160 22], ...
                'Tooltip', 'Heatmap colormap', ...
                'ValueChangedFcn', @(dropdown, event) onParameterChanged(app, event)); % Add callback

            % Info Text Area (in a panel for border)
            app.infoPanel = uipanel(app.UIFigure, ...
                'Position', [20 140 180 60], ... % Always between advanced panel and visualize button
                'BorderType', 'line', ...
                'Title', '');

            app.InfoTextArea = uitextarea(app.infoPanel, ...
                'Position', [1 1 178 58], ...
                'Editable', 'off', ...
                'Value', {'Information will appear here...'});

            % Image Preview Axes (in panels for border)
            panel1 = uipanel(app.UIFigure, ...
                'Position', [220 420 250 160], ...
                'BorderType', 'line', ...
                'Title', '');
            app.ImageAxes1 = uiaxes(panel1, ...
                'Position', [1 1 248 158], ...
                'Box', 'on');
            title(app.ImageAxes1, 'Image 1');
            axis(app.ImageAxes1, 'off');

            panel2 = uipanel(app.UIFigure, ...
                'Position', [500 420 250 160], ...
                'BorderType', 'line', ...
                'Title', '');
            app.ImageAxes2 = uiaxes(panel2, ...
                'Position', [1 1 248 158], ...
                'Box', 'on');
            title(app.ImageAxes2, 'Image 2');
            axis(app.ImageAxes2, 'off');

            % Dropdowns placed directly beneath each preview image
            app.ImageDropDown1 = uidropdown(app.UIFigure, ...
                'Items', {}, ...
                'Position', [220 380 250 30]); % Y = 380 aligns closely below

            % Image 2 navigation: Left arrow | dropdown | right arrow
            app.LeftArrowButton2 = uibutton(app.UIFigure, 'push', ...
                'Text', char(9664), ... % Unicode left arrow ◀
                'Position', [500 380 30 30], ...
                'ButtonPushedFcn', @(btn, event) onLeftArrowPressed(app), ...
                'Tooltip', 'Previous image');

            app.ImageDropDown2 = uidropdown(app.UIFigure, ...
                'Items', {}, ...
                'Position', [540 380 170 30]); % Adjusted width to align with Image 2 box

            app.RightArrowButton2 = uibutton(app.UIFigure, 'push', ...
                'Text', char(9654), ... % Unicode right arrow ▶
                'Position', [720 380 30 30], ... % Aligned with right edge of Image 2 box
                'ButtonPushedFcn', @(btn, event) onRightArrowPressed(app), ...
                'Tooltip', 'Next image');

            app.ImageDropDown1.ValueChangedFcn = @(dd, event) onReferenceImageChanged(app, event);
            app.ImageDropDown2.ValueChangedFcn = @(dd, event) onComparisonImageChanged(app, event);

            % Main Visualization Output (in a panel for border)
            resultPanel = uipanel(app.UIFigure, ...
                'Position', [220 90 550 280], ...
                'BorderType', 'line', ...
                'Title', '');
            app.ResultAxes = uiaxes(resultPanel, ...
                'Position', [1 1 548 278], ...
                'Box', 'on');
            title(app.ResultAxes, 'Visualization Output');
            axis(app.ResultAxes, 'off');

            % Add a button to display masks in the bottom right corner of the visualization output area
            app.ShowMasksButton = uibutton(resultPanel, 'push', ...
                'Text', 'Show Masks', ...
                'Position', [resultPanel.Position(3) - 110, 10, 100, 30], ... % Adjusted absolute position
                'ButtonPushedFcn', @(btn, event) onShowMasksButtonPressed(app));

            % Play/Pause Controls (hidden by default)
            app.PlayButton = uibutton(app.UIFigure, 'push', ...
                'Text', char(9654), ... % Unicode play icon ►
                'Position', [400 50 50 30], ...
                'ButtonPushedFcn', @(btn, event) onPlayButtonPressed(app), ...
                'Visible', 'on');

            app.PauseButton = uibutton(app.UIFigure, 'push', ...
                'Text', char(10073), ... % Unicode pause icon ❚❚
                'Position', [460 50 50 30], ...
                'ButtonPushedFcn', @(btn, event) onPauseButtonPressed(app), ...
                'Visible', 'on');

            % Add Replay Mode Dropdown to the left of the Play button - CHANGE: Make it open upwards
            app.ReplayModeDropdown = uidropdown(app.UIFigure, ...
                'Items', {'Flicker', 'Timelapse', 'Static'}, ...
                'Value', 'Flicker', ...
                'Position', [340 50 50 30]);
            % 'DropDirection', 'up'); % This makes the dropdown open upwards

            % Speed slider (hidden by default)
            app.SpeedSlider = uislider(app.UIFigure, ...
                'Position', [520 65 120 3], ...
                'Limits', [0.1 2], ...
                'Value', 1.5, ...
                'MajorTicks', [0.1 0.5 1 1.5 2], ...
                'Visible', 'on', ...
                'ValueChangedFcn', @(s, e) onSpeedSliderChanged(app)); % <-- Add this

            % Visualize Button (right column, always visible)
            app.VisualizeButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Visualize', ...
                'Position', [20 100 180 40], ... % X=20, width=180, Y=100 puts it below InfoTextArea
                'ButtonPushedFcn', @(btn, event) onVisualizeButtonPressed(app), ...
                'FontWeight', 'bold', ...
                'FontSize', 16, ...
                'BackgroundColor', [0.2 0.6 1]); % Light blue, change as desired

            % Set dropdown callback to control visibility
            app.VisualizationDropDown.ValueChangedFcn = @(dd, event) onVisualizationModeChanged(app);
            uistack(app.AdvancedPanel, 'top');

            % Move the ShowMasksButton to be positioned under the Visualize button
            app.ShowMasksButton.Parent = app.UIFigure;
            app.ShowMasksButton.Position = [20, 60, 180, 30];
        end

    end

    methods (Access = public)

        function app = SatelliteChangeAppTwo
            createComponents(app);

            % Initialize global indices struct
            app.Indices = struct('img', [], 'imgRef', []);

            % Initialize overlay type based on default visualization mode
            switch app.VisualizationDropDown.Value
                case 'Heatmap'
                    app.overlayType = 'Heatmap';
                case 'Red Overlay'
                    app.overlayType = 'RedOverlay';
                otherwise
                    app.overlayType = 'Heatmap'; % Default to Heatmap for stats
            end

        end

    end

end

% Define the callback function for the Show Masks button
function onShowMasksButtonPressed(app)
    % Get the selected mask category
    selectedMask = getSelectedMask(app);

    % Get the registered image pair
    [img1, img2reg] = getRegisteredImagePair(app);

    if isempty(img1) || isempty(img2reg)
        uialert(app.UIFigure, 'No images available for visualization.', 'Error');
        return;
    end

    % Ensure overlays are computed
    if ~app.OverlaysComputed || isempty(app.ComputedOverlays)
        uialert(app.UIFigure, 'Please compute overlays first by clicking Visualize.', 'Error');
        return;
    end

    % Get the current comparison image index
    if isempty(app.Indices) || ~isfield(app.Indices, 'img') || isempty(app.Indices.img)
        uialert(app.UIFigure, 'No comparison image selected.', 'Error');
        return;
    end

    imgIdx = app.Indices.img;

    % Get the img_united_mask from the stats of the active overlay type
    img_united_mask = [];
    statsFieldName = strcat(app.overlayType, 'Stats'); % e.g.,'HeatmapStats' or 'RedOverlayStats'
    fprintf('Stats field name: %s\n', statsFieldName);

    if imgIdx <= numel(app.ComputedOverlays) && ...
            isfield(app.ComputedOverlays(1), statsFieldName) && ...
            ~isempty(app.ComputedOverlays(imgIdx).(statsFieldName)) && ...
            isfield(app.ComputedOverlays(imgIdx).(statsFieldName), 'img_united_mask')

        img_united_mask = app.ComputedOverlays(imgIdx).(statsFieldName).img_united_mask;
    end

    % If no img_united_mask found in stats, fallback to generating it
    if isempty(img_united_mask)
        [img_united_mask, rgbMaskedImage] = masks.category_masks(img1, selectedMask);
    else
        % Generate RGB masked image from the retrieved mask
        rgbMaskedImage = img1;

        for c = 1:size(img1, 3)
            rgbMaskedImage(:, :, c) = img1(:, :, c) .* uint8(img_united_mask);
        end

    end

    % Generate RGB masked version of the comparison image
    rgbMaskedImage2 = img2reg;

    for c = 1:size(img2reg, 3)
        rgbMaskedImage2(:, :, c) = img2reg(:, :, c) .* uint8(img_united_mask);
    end

    % Plot in 2x2 grid layout
    figure('Name', ['Category: ', selectedMask, ' - Images: ', app.ImageDropDown1.Value, ' → ', app.ImageDropDown2.Value]);

    % Field 1: Reference image (top left)
    subplot(2, 2, 1); imshow(img1); title('Reference Image', 'FontWeight', 'bold');

    % Field 2: Binary mask (top right)
    subplot(2, 2, 2); imshow(img_united_mask); title(['Binary Mask: ', selectedMask], 'FontWeight', 'bold');

    % Field 3: RGB reference image masked (bottom left)
    subplot(2, 2, 3); imshow(rgbMaskedImage); title('RGB Reference Image Masked', 'FontWeight', 'bold');

    % Field 4: RGB image masked (bottom right)
    subplot(2, 2, 4); imshow(rgbMaskedImage2); title('RGB Image Masked', 'FontWeight', 'bold');
end
