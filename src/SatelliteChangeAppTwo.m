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

                % For static mode, ensure display is updated consistently
                if strcmp(app.ReplayModeDropdown.Value, 'Static')
                    % Update display using the same approach as other modes
                    autoDisplayStaticMode(app);
                end

            end

        end

        function onParameterChanged(app, ~)
            % Callback when any overlay parameter changes (alpha, sigma, colormap)
            app.OverlaysComputed = false; % Mark overlays as outdated
            app.TimelapseFrames = {}; % Clear cached timelapse frames

            % Auto-recompute and display
            if ~isempty(app.RegisteredImages)
                autoRecomputeAndDisplay(app);

                % For static mode, ensure display is updated consistently
                if strcmp(app.ReplayModeDropdown.Value, 'Static')
                    % Update display using the same approach as other modes
                    autoDisplayStaticMode(app);
                end

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

                % For static mode, ensure display is updated consistently
                if strcmp(app.ReplayModeDropdown.Value, 'Static')
                    % Update display using the same approach as other modes
                    autoDisplayStaticMode(app);
                end

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

                % For static mode, ensure display is updated consistently
                if strcmp(app.ReplayModeDropdown.Value, 'Static')
                    % Update display using the same approach as other modes
                    autoDisplayStaticMode(app);
                end

            elseif ~isempty(app.RegisteredImages)
                % If overlays not computed yet, compute them first
                autoRecomputeAndDisplay(app);

                % For static mode, ensure display is updated consistently
                if strcmp(app.ReplayModeDropdown.Value, 'Static')
                    % Update display using the same approach as other modes
                    autoDisplayStaticMode(app);
                end

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

            % Automatically trigger mask recalculation and display after loading
            if numel(names) >= 2
                % Auto-recompute overlays and display for the new dataset
                autoRecomputeAndDisplay(app);

                % Update info to reflect that overlays have been computed
                app.InfoTextArea.Value = sprintf('Loaded and registered %d images incrementally. Overlays computed automatically.', numel(names));
            end

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

                % For static mode, ensure display is updated consistently
                if strcmp(app.ReplayModeDropdown.Value, 'Static')
                    % Update display using the same approach as other modes
                    autoDisplayStaticMode(app);
                end

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

                    % Display stats if available
                    displayStatsInGUI(app, mode, idx2);
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

                            % Display stats if available
                            displayStatsInGUI(app, mode, idx2);
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

                        % Display stats if available (use the current frame index for stats)
                        displayStatsInGUI(app, mode, app.TimelapseFrameIndex);

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

                        % Display stats if available
                        displayStatsInGUI(app, mode, idx2);
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

                    % Display stats if available
                    displayStatsInGUI(app, mode, idx2);
                end

            end

        end

        function autoDisplayStaticMode(app)
            % Automatically display the current visualization for static mode
            % This ensures consistent behavior with timelapse and flicker modes
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
                    title(app.ResultAxes, sprintf('%s Static (%s): %s → %s', ...
                        mode, selectedMask, ...
                        strrep(app.ImageDropDown1.Value, '_', ' '), ...
                        strrep(app.ImageDropDown2.Value, '_', ' ')));
                    fprintf('Auto-displayed %s static overlay for image %d\n', mode, idx2);

                    % Display stats if available
                    displayStatsInGUI(app, mode, idx2);
                else
                    uialert(app.UIFigure, sprintf('%s overlay not available. Please compute overlays first.', mode), 'Error');
                    fprintf('ERROR: Static mode - %s overlay not found for image %d\n', mode, idx2);
                end

            end

        end

        function displayStatsInGUI(app, mode, imageIndex)
            % Display statistics in the InfoTextArea for heatmap and red overlay modes

            % Only display stats for heatmap and red overlay modes
            if ~ismember(mode, {'Heatmap', 'Red Overlay'})
                return;
            end

            % Determine stats field name based on mode
            if strcmp(mode, 'Heatmap')
                statsFieldName = 'HeatmapStats';
            else % Red Overlay
                statsFieldName = 'RedOverlayStats';
            end

            % Check if stats are available
            if imageIndex <= numel(app.ComputedOverlays) && ...
                    isfield(app.ComputedOverlays(1), statsFieldName) && ...
                    ~isempty(app.ComputedOverlays(imageIndex).(statsFieldName)) && ...
                    isfield(app.ComputedOverlays(imageIndex).(statsFieldName), 'stats_text_cell')

                % Get the formatted stats text
                stats = app.ComputedOverlays(imageIndex).(statsFieldName);
                statsText = stats.stats_text_cell;

                % Display in InfoTextArea
                app.InfoTextArea.Value = statsText;
                fprintf('Displayed %s stats for image %d\n', mode, imageIndex);
            else
                % No stats available
                app.InfoTextArea.Value = {'No statistics available for this visualization mode.'};
                fprintf('No %s stats available for image %d\n', mode, imageIndex);
            end

        end

    end

    methods (Access = private)

        function createComponents(app)
            % Main window - increased size for better layout
            app.UIFigure = uifigure('Position', [100 100 1200 700]);
            app.UIFigure.Name = 'Satellite Change Visualizer';
            app.UIFigure.WindowState = 'maximized';

            % Left panel dimensions
            leftPanelWidth = 200;
            leftPanelX = 15;
            buttonHeight = 35;
            spacing = 8;

            % Current Y position tracker for left panel
            currentY = 650;

            % Load Folder Button
            app.LoadFolderButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Load Image Folder', ...
                'Position', [leftPanelX currentY - buttonHeight leftPanelWidth buttonHeight], ...
                'ButtonPushedFcn', @(btn, event) LoadFolderButtonPushed(app), ...
                'FontWeight', 'bold');

            currentY = currentY - buttonHeight - spacing;

            % Change Type Radio Group - Adjusted height and layout
            groupHeight = 220;
            app.ChangeTypeGroup = uibuttongroup(app.UIFigure, ...
                'Title', 'Mask Category', ...
                'Position', [leftPanelX currentY - groupHeight leftPanelWidth groupHeight], ...
                'SelectionChangedFcn', @(bg, event) onMaskCategoryChanged(app, event), ...
                'TitlePosition', 'centertop');

            % Radio buttons in 2 columns with better spacing
            radioButtonHeight = 18;
            radioButtonWidth = 85;
            radioSpacing = 22;

            % Column 1 (left)
            col1X = 10;
            col2X = 95;

            radioY = groupHeight - 50; % Start from top

            app.AllButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'All', ...
                'Position', [col1X radioY radioButtonWidth radioButtonHeight], ...
                'Value', true);

            app.CityButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'City', ...
                'Position', [col2X radioY radioButtonWidth radioButtonHeight]);

            radioY = radioY - radioSpacing;

            app.WaterButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Water', ...
                'Position', [col1X radioY radioButtonWidth radioButtonHeight]);

            app.RiverButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'River', ...
                'Position', [col2X radioY radioButtonWidth radioButtonHeight]);

            radioY = radioY - radioSpacing;

            app.ForestButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Forest', ...
                'Position', [col1X radioY radioButtonWidth radioButtonHeight]);

            app.IceButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Ice', ...
                'Position', [col2X radioY radioButtonWidth radioButtonHeight]);

            radioY = radioY - radioSpacing;

            app.DesertButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Desert', ...
                'Position', [col1X radioY radioButtonWidth radioButtonHeight]);

            app.FieldButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Field', ...
                'Position', [col2X radioY radioButtonWidth radioButtonHeight]);

            radioY = radioY - radioSpacing;

            app.GlacierButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Glacier', ...
                'Position', [col1X radioY radioButtonWidth radioButtonHeight]);

            app.FrauenkircheButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Frauenkirche', ...
                'Position', [col2X radioY radioButtonWidth radioButtonHeight]);

            radioY = radioY - radioSpacing;

            app.OktoberfestButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Oktoberfest', ...
                'Position', [col1X radioY radioButtonWidth radioButtonHeight]);

            currentY = currentY - groupHeight - spacing;

            % Visualization Type Dropdown
            app.VisualizationDropDown = uidropdown(app.UIFigure, ...
                'Items', {'Overlay', 'Absolute Difference', 'Heatmap', 'Red Overlay'}, ...
                'Value', 'Overlay', ...
                'Position', [leftPanelX currentY - buttonHeight leftPanelWidth buttonHeight]);

            currentY = currentY - buttonHeight - spacing;

            % Toggle button for advanced settings
            app.AdvancedToggle = uibutton(app.UIFigure, 'push', ...
                'Text', 'Show Advanced Settings ▼', ...
                'Position', [leftPanelX currentY - buttonHeight leftPanelWidth buttonHeight], ...
                'ButtonPushedFcn', @(btn, event) toggleAdvancedPanel(app), ...
                'FontWeight', 'bold');

            currentY = currentY - buttonHeight - spacing;

            % Advanced Settings Panel - Adjusted size and positioning
            advancedPanelHeight = 220;
            app.AdvancedPanel = uipanel(app.UIFigure, ...
                'Position', [leftPanelX currentY - advancedPanelHeight leftPanelWidth advancedPanelHeight], ...
                'FontWeight', 'bold', ...
                'Visible', 'off');

            % Advanced panel components with better spacing
            advY = advancedPanelHeight - 25;

            app.HeatmapAlphaLabel = uilabel(app.AdvancedPanel, ...
                'Text', 'Heatmap Alpha:', ...
                'Position', [10 advY 160 20]);

            advY = advY - 25;

            app.HeatmapAlphaSlider = uislider(app.AdvancedPanel, ...
                'Position', [10 advY 160 3], ...
                'Limits', [0 1], ...
                'Value', 0.6, ...
                'MajorTicks', [0 0.25 0.5 0.75 1], ...
                'Tooltip', 'Alpha transparency', ...
                'ValueChangedFcn', @(slider, event) onParameterChanged(app, event));

            advY = advY - 50;

            app.GaussianSigmaLabel = uilabel(app.AdvancedPanel, ...
                'Text', 'Gaussian Sigma:', ...
                'Position', [10 advY 160 20]);

            advY = advY - 25;

            app.GaussianSigmaSlider = uislider(app.AdvancedPanel, ...
                'Position', [10 advY 160 3], ...
                'Limits', [0.1 5], ...
                'Value', 1.0, ...
                'MajorTicks', [0.1 1 2 3 4 5], ...
                'Tooltip', 'Gaussian smoothing sigma', ...
                'ValueChangedFcn', @(slider, event) onParameterChanged(app, event));

            advY = advY - 50;

            app.HeatmapColorMapLabel = uilabel(app.AdvancedPanel, ...
                'Text', 'Colormap:', ...
                'Position', [10 advY 160 20]);

            advY = advY - 25;

            app.HeatmapColorMapDropDown = uidropdown(app.AdvancedPanel, ...
                'Items', {'jet', 'hot', 'parula', 'turbo'}, ...
                'Value', 'jet', ...
                'Position', [10 advY 160 25], ...
                'Tooltip', 'Heatmap colormap', ...
                'ValueChangedFcn', @(dropdown, event) onParameterChanged(app, event));

            currentY = currentY - 5; % Small spacing after advanced panel

            % Info Text Area - Position it right beneath "Show Advanced Settings"
            infoPanelHeight = 70;
            app.infoPanel = uipanel(app.UIFigure, ...
                'Position', [leftPanelX currentY - infoPanelHeight leftPanelWidth infoPanelHeight], ...
                'BorderType', 'line', ...
                'Title', '');

            app.InfoTextArea = uitextarea(app.infoPanel, ...
                'Position', [3 3 leftPanelWidth - 6 infoPanelHeight - 6], ...
                'Editable', 'off', ...
                'Value', {'Information will appear here...'});

            currentY = currentY - infoPanelHeight - spacing;

            % Show Masks Button - Position it after text field
            app.ShowMasksButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Show Masks', ...
                'Position', [leftPanelX currentY - buttonHeight leftPanelWidth buttonHeight], ...
                'ButtonPushedFcn', @(btn, event) onShowMasksButtonPressed(app));

            currentY = currentY - buttonHeight - spacing;

            % Visualize Button - Position it at the bottom
            visualizeButtonHeight = 45;
            app.VisualizeButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Visualize', ...
                'Position', [leftPanelX currentY - visualizeButtonHeight leftPanelWidth visualizeButtonHeight], ...
                'ButtonPushedFcn', @(btn, event) onVisualizeButtonPressed(app), ...
                'FontWeight', 'bold', ...
                'FontSize', 16);

            % Right side layout - Image panels and visualization
            rightPanelStartX = leftPanelX + leftPanelWidth + 20;
            availableWidth = 1200 - rightPanelStartX - 15; % Available width for right side

            % Image panels - side by side with better proportions
            imagePanelWidth = floor((availableWidth - 15) / 2); % 15px gap between panels
            imagePanelHeight = 216; % 20 % bigger (was 180)
            imagePanelY = 464; % Extended toward bottom (was 500)

            % Image 1 Panel
            panel1 = uipanel(app.UIFigure, ...
                'Position', [rightPanelStartX imagePanelY imagePanelWidth imagePanelHeight], ...
                'BorderType', 'line', ...
                'Title', '');
            app.ImageAxes1 = uiaxes(panel1, ...
                'Position', [5 5 imagePanelWidth - 10 imagePanelHeight - 10], ...
                'Box', 'on');
            title(app.ImageAxes1, 'Image 1');
            axis(app.ImageAxes1, 'off');

            % Image 2 Panel
            panel2 = uipanel(app.UIFigure, ...
                'Position', [rightPanelStartX + imagePanelWidth + 15 imagePanelY imagePanelWidth imagePanelHeight], ...
                'BorderType', 'line', ...
                'Title', '');
            app.ImageAxes2 = uiaxes(panel2, ...
                'Position', [5 5 imagePanelWidth - 10 imagePanelHeight - 10], ...
                'Box', 'on');
            title(app.ImageAxes2, 'Image 2');
            axis(app.ImageAxes2, 'off');

            % Dropdowns below image panels
            dropdownY = imagePanelY - 40;

            app.ImageDropDown1 = uidropdown(app.UIFigure, ...
                'Items', {}, ...
                'Position', [rightPanelStartX dropdownY imagePanelWidth 35]);

            % Image 2 navigation: Left arrow | dropdown | right arrow
            arrowButtonWidth = 35;
            dropdownWidth = imagePanelWidth - (2 * arrowButtonWidth) - 10;

            app.LeftArrowButton2 = uibutton(app.UIFigure, 'push', ...
                'Text', char(9664), ...
                'Position', [rightPanelStartX + imagePanelWidth + 15 dropdownY arrowButtonWidth 35], ...
                'ButtonPushedFcn', @(btn, event) onLeftArrowPressed(app), ...
                'Tooltip', 'Previous image');

            app.ImageDropDown2 = uidropdown(app.UIFigure, ...
                'Items', {}, ...
                'Position', [rightPanelStartX + imagePanelWidth + 15 + arrowButtonWidth + 5 dropdownY dropdownWidth 35]);

            app.RightArrowButton2 = uibutton(app.UIFigure, 'push', ...
                'Text', char(9654), ...
                'Position', [rightPanelStartX + imagePanelWidth + 15 + arrowButtonWidth + 5 + dropdownWidth + 5 dropdownY arrowButtonWidth 35], ...
                'ButtonPushedFcn', @(btn, event) onRightArrowPressed(app), ...
                'Tooltip', 'Next image');

            % Set dropdown callbacks
            app.ImageDropDown1.ValueChangedFcn = @(dd, event) onReferenceImageChanged(app, event);
            app.ImageDropDown2.ValueChangedFcn = @(dd, event) onComparisonImageChanged(app, event);

            % Main Visualization Output - Larger and better positioned
            resultPanelY = 90;
            resultPanelHeight = dropdownY - resultPanelY - 10;
            resultPanelWidth = availableWidth;

            resultPanel = uipanel(app.UIFigure, ...
                'Position', [rightPanelStartX resultPanelY resultPanelWidth resultPanelHeight], ...
                'BorderType', 'line', ...
                'Title', '');
            app.ResultAxes = uiaxes(resultPanel, ...
                'Position', [5 5 resultPanelWidth - 10 resultPanelHeight - 10], ...
                'Box', 'on');
            title(app.ResultAxes, 'Visualization Output');
            axis(app.ResultAxes, 'off');

            % Playback Controls - Centered at bottom
            playbackY = 50;
            playbackCenterX = rightPanelStartX + resultPanelWidth / 2;

            % Replay Mode Dropdown
            app.ReplayModeDropdown = uidropdown(app.UIFigure, ...
                'Items', {'Flicker', 'Timelapse', 'Static'}, ...
                'Value', 'Flicker', ...
                'Position', [playbackCenterX - 180 playbackY 80 35]);

            % Play Button
            app.PlayButton = uibutton(app.UIFigure, 'push', ...
                'Text', char(9654), ...
                'Position', [playbackCenterX - 90 playbackY 40 35], ...
                'ButtonPushedFcn', @(btn, event) onPlayButtonPressed(app), ...
                'Visible', 'on');

            % Pause Button
            app.PauseButton = uibutton(app.UIFigure, 'push', ...
                'Text', char(10073), ...
                'Position', [playbackCenterX - 40 playbackY 40 35], ...
                'ButtonPushedFcn', @(btn, event) onPauseButtonPressed(app), ...
                'Visible', 'on');

            % Speed slider
            app.SpeedSlider = uislider(app.UIFigure, ...
                'Position', [playbackCenterX + 10 playbackY + 16 120 3], ...
                'Limits', [0.1 2], ...
                'Value', 1.5, ...
                'MajorTicks', [0.1 0.5 1 1.5 2], ...
                'Visible', 'on', ...
                'ValueChangedFcn', @(s, e) onSpeedSliderChanged(app));

            % Set visualization dropdown callback
            app.VisualizationDropDown.ValueChangedFcn = @(dd, event) onVisualizationModeChanged(app);

            % Ensure advanced panel is on top
            uistack(app.AdvancedPanel, 'top');
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

    % Generate individual masks for both images
    [img1_mask, rgbMaskedImage1] = masks.category_masks(img1, selectedMask);
    [img2_mask, rgbMaskedImage2] = masks.category_masks(img2reg, selectedMask);

    % Generate RGB masked versions using individual masks
    rgbMaskedImage1 = img1;

    for c = 1:size(img1, 3)
        rgbMaskedImage1(:, :, c) = img1(:, :, c) .* uint8(img1_mask);
    end

    rgbMaskedImage2 = img2reg;

    for c = 1:size(img2reg, 3)
        rgbMaskedImage2(:, :, c) = img2reg(:, :, c) .* uint8(img2_mask);
    end

    % Plot in 3x3 grid layout
    figure('Name', ['Category: ', selectedMask, ' - Images: ', app.ImageDropDown1.Value, ' → ', app.ImageDropDown2.Value]);

    % Position 1: Reference image (top left)
    subplot(3, 3, 1); imshow(img1); title('Reference Image', 'FontWeight', 'bold');

    % Position 2: Comparison image (top middle)
    subplot(3, 3, 2); imshow(img2reg); title('Comparison Image', 'FontWeight', 'bold');

    % Position 3: Empty (top right)
    subplot(3, 3, 3); axis off; title('', 'FontWeight', 'bold');

    % Position 4: Binary mask for reference image (middle left)
    subplot(3, 3, 4); imshow(img1_mask); title(['Binary Mask: Reference'], 'FontWeight', 'bold');

    % Position 5: Binary mask for comparison image (middle middle)
    subplot(3, 3, 5); imshow(img2_mask); title(['Binary Mask: Comparison'], 'FontWeight', 'bold');

    % Position 6: Binary mask united (middle right)
    subplot(3, 3, 6); imshow(img_united_mask); title(['Binary Mask: United'], 'FontWeight', 'bold');

    % Position 7: Reference image masked (bottom left)
    subplot(3, 3, 7); imshow(rgbMaskedImage1); title('Reference Image Masked', 'FontWeight', 'bold');

    % Position 8: Comparison image masked (bottom middle)
    subplot(3, 3, 8); imshow(rgbMaskedImage2); title('Comparison Image Masked', 'FontWeight', 'bold');

    % Position 9: Empty (bottom right)
    subplot(3, 3, 9); axis off; title('', 'FontWeight', 'bold');
end
