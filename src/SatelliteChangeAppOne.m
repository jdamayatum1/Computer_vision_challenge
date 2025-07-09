classdef SatelliteChangeAppOne < matlab.apps.AppBase

    properties (Access = public)

        RegisteredImages cell
        FlickerRegisteredImage

        UIFigure matlab.ui.Figure
        LoadFolderButton matlab.ui.control.Button
        ChangeTypeGroup matlab.ui.container.ButtonGroup
        AllButton matlab.ui.control.RadioButton
        CityButton matlab.ui.control.RadioButton
        WaterButton matlab.ui.control.RadioButton
        ForestButton matlab.ui.control.RadioButton
        IceButton matlab.ui.control.RadioButton
        DesertButton matlab.ui.control.RadioButton
        FeldButton matlab.ui.control.RadioButton
        GlacierButton matlab.ui.control.RadioButton
        FrauenkircheButton matlab.ui.control.RadioButton
        OktoberfestButton matlab.ui.control.RadioButton

        VisualizationDropDown matlab.ui.control.DropDown

        InfoTextArea matlab.ui.control.TextArea
        infoPanel matlab.ui.container.Panel
        CurrentVisMode string = 'Flicker' % Default visualization mode
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

        ImageDropDown1 matlab.ui.control.DropDown
        ImageDropDown2 matlab.ui.control.DropDown
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
                case app.ForestButton
                    selectedMask = 'forest';
                case app.IceButton
                    selectedMask = 'ice';
                case app.DesertButton
                    selectedMask = 'desert';
                case app.FeldButton
                    selectedMask = 'feld';
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

        function LoadFolderButtonPushed(app, ~)
            folder = uigetdir;
            if folder == 0, return; end

            % Find all valid image files
            exts = {'*.jpg', '*.jpeg', '*.png', '*.tif', '*.tiff'};
            imageFiles = [];

            for i = 1:numel(exts)
                imageFiles = [imageFiles; dir(fullfile(folder, exts{i}))];
            end

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

            % Register all images to the first image as reference
            ref_img = app.getImageByIndex(1);
            app.RegisteredImages = cell(1, numel(imageFiles)); % preallocate

            h = uiprogressdlg(app.UIFigure, ...
                'Title', 'Registering Images', ...
                'Message', 'Please wait...', ...
                'Indeterminate', 'off', ...
                'Cancelable', 'off');

            for k = 1:numel(imageFiles)
                moving_img = app.getImageByIndex(k);

                try
                    reg = registration.registerImagesSURF(moving_img, ref_img);
                    app.RegisteredImages{k} = reg.registered;
                catch
                    app.RegisteredImages{k} = moving_img; % fallback to raw
                end

                h.Value = k / numel(imageFiles);
                h.Message = sprintf('Registering image %d of %d...', k, numel(imageFiles));
                drawnow;
            end

            close(h);

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
            app.InfoTextArea.Value = sprintf('Loaded and registered %d images.', numel(names));

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
            % Always hide playback controls on mode change
            app.PlayButton.Visible = 'off';
            app.PauseButton.Visible = 'off';
            app.SpeedSlider.Visible = 'off';
            % Optionally, stop any running playback
            onPauseButtonPressed(app);
        end

        function onVisualizeButtonPressed(app, ~)
            mode = app.VisualizationDropDown.Value;

            % Show/hide playback controls only if needed
            showPlayback = any(strcmp(mode, {'Flicker', 'Timelapse'}));
            app.PlayButton.Visible = showPlayback;
            app.PauseButton.Visible = showPlayback;
            app.SpeedSlider.Visible = showPlayback;

            % Prepare registered images once for all modes
            [img1, img2reg] = getRegisteredImagePair(app);
            if isempty(img1) || isempty(img2reg), return; end

            % Get selected mask category
            selectedMask = getSelectedMask(app);

            switch mode
                case 'Flicker'
                    app.FlickerRegisteredImage = img2reg;
                    onPlayButtonPressed(app);

                case 'Timelapse'
                    app.TimelapseFrames = {};
                    app.TimelapseFrameIndex = 1;

                    % Store registered frames between idx1 and idx2
                    idx1 = find(strcmp(app.ImageDropDown1.Items, app.ImageDropDown1.Value));
                    idx2 = find(strcmp(app.ImageDropDown2.Items, app.ImageDropDown2.Value));
                    low = min(idx1, idx2);
                    high = max(idx1, idx2);

                    app.TimelapseFrames = app.RegisteredImages(low:high); % Directly store pre-registered images
                    app.TimelapseFrameIndex = 1;

                    % Start playing automatically
                    onPlayButtonPressed(app);

                case 'Overlay'
                    blend = 0.5 * im2double(img1) + 0.5 * im2double(img2reg);
                    imshow(blend, 'Parent', app.ResultAxes, 'InitialMagnification', 'fit');
                    title(app.ResultAxes, sprintf('Registered Overlay: %s → %s', ...
                        strrep(app.ImageDropDown2.Value, '_', ' '), ...
                        strrep(app.ImageDropDown1.Value, '_', ' ')));

                case 'Absolute Difference'
                    diff_img = imabsdiff(im2double(img1), im2double(img2reg));
                    imshow(diff_img, 'Parent', app.ResultAxes, 'InitialMagnification', 'fit');
                    title(app.ResultAxes, 'Absolute Difference');

                case 'Heatmap'
                    % Get selected registered images
                    [img1, img2reg] = getRegisteredImagePair(app);
                    if isempty(img1) || isempty(img2reg), return; end

                    % Read advanced parameters from GUI
                    params = struct();
                    params.alpha = app.HeatmapAlphaSlider.Value;
                    params.gaussian_sigma = app.GaussianSigmaSlider.Value;
                    params.colormap_name = app.HeatmapColorMapDropDown.Value;

                    % Generate colormap
                    % cmap = visualization.get_heatmap_colormap(params.colormap_name);

                    % Create heatmap overlay using selected mask
                    [overlay_img, stats] = visualization.get_heatmap_overlay(img1, img2reg, selectedMask, params);

                    % Display result
                    imshow(overlay_img, 'Parent', app.ResultAxes, 'InitialMagnification', 'fit');
                    title(app.ResultAxes, sprintf('Heatmap Overlay (%s): %s → %s', ...
                        selectedMask, ...
                        strrep(app.ImageDropDown2.Value, '_', ' '), ...
                        strrep(app.ImageDropDown1.Value, '_', ' ')));

                case 'Red Overlay'
                    % Get selected registered images
                    [img1, img2reg] = getRegisteredImagePair(app);
                    if isempty(img1) || isempty(img2reg), return; end

                    % Read advanced parameters from GUI
                    params = struct();
                    params.alpha = app.HeatmapAlphaSlider.Value;
                    params.gaussian_sigma = app.GaussianSigmaSlider.Value;

                    % Generate colormap
                    % cmap = visualization.get_heatmap_colormap(params.colormap_name);

                    % Create red overlay using selected mask
                    [overlay_img, stats] = visualization.get_red_overlay(img1, img2reg, selectedMask, params);

                    % Display result
                    imshow(overlay_img, 'Parent', app.ResultAxes, 'InitialMagnification', 'fit');
                    title(app.ResultAxes, sprintf('Red Overlay (%s): %s → %s', ...
                        selectedMask, ...
                        strrep(app.ImageDropDown2.Value, '_', ' '), ...
                        strrep(app.ImageDropDown1.Value, '_', ' ')));

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

            app.IsPlaying = true;
            app.CurrentVisMode = app.VisualizationDropDown.Value;

            % Prepare/reset flicker state
            app.FlickerState = false;

            % Reset timelapse state
            if strcmp(app.CurrentVisMode, 'Timelapse')

                if isempty(app.TimelapseFrames)
                    % Initialize timelapse frames if not already done
                    idx1 = find(strcmp(app.ImageDropDown1.Items, app.ImageDropDown1.Value));
                    idx2 = find(strcmp(app.ImageDropDown2.Items, app.ImageDropDown2.Value));
                    if isempty(idx1) || isempty(idx2), return; end

                    low = min(idx1, idx2);
                    high = max(idx1, idx2);

                    app.TimelapseFrames = app.RegisteredImages(low:high);
                    app.TimelapseFrameIndex = 1;
                end

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

            switch app.CurrentVisMode
                case 'Flicker'
                    visualization.flicker_visualization(app);
                case 'Timelapse'
                    visualization.timelapse_visualization(app);
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
                'Position', [20 350 180 180]);

            % Create radio buttons for all valid categories
            app.AllButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'All', ...
                'Position', [10 150 80 20], ...
                'Value', true); % Default selection

            app.CityButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'City', ...
                'Position', [90 150 80 20]);

            app.WaterButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Water', ...
                'Position', [10 130 80 20]);

            app.ForestButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Forest', ...
                'Position', [90 130 80 20]);

            app.IceButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Ice', ...
                'Position', [10 110 80 20]);

            app.DesertButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Desert', ...
                'Position', [90 110 80 20]);

            app.FeldButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Feld', ...
                'Position', [10 90 80 20]);

            app.GlacierButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Glacier', ...
                'Position', [90 90 80 20]);

            app.FrauenkircheButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Frauenkirche', ...
                'Position', [10 70 80 20]);

            app.OktoberfestButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Oktoberfest', ...
                'Position', [90 70 80 20]);

            % Visualization Type Dropdown
            app.VisualizationDropDown = uidropdown(app.UIFigure, ...
                'Items', {'Flicker', 'Overlay', 'Absolute Difference', 'Timelapse', 'Heatmap', 'Red Overlay'}, ...
                'Value', 'Flicker', ...
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
                'Tooltip', 'Alpha transparency');

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
                'Tooltip', 'Gaussian smoothing sigma');

            % Heatmap Colormap Dropdown Label
            app.HeatmapColorMapLabel = uilabel(app.AdvancedPanel, ...
                'Text', 'Colormap:', ...
                'Position', [10 30 160 20]);

            % Heatmap Colormap Dropdown
            app.HeatmapColorMapDropDown = uidropdown(app.AdvancedPanel, ...
                'Items', {'jet', 'hot', 'parula', 'turbo'}, ...
                'Value', 'jet', ...
                'Position', [10 10 160 22], ...
                'Tooltip', 'Heatmap colormap');

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

            app.ImageDropDown2 = uidropdown(app.UIFigure, ...
                'Items', {}, ...
                'Position', [500 380 250 30]);

            app.ImageDropDown1.ValueChangedFcn = @(dd, event) updateImagePreview(app, 1);
            app.ImageDropDown2.ValueChangedFcn = @(dd, event) updateImagePreview(app, 2);

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

            % Play/Pause Controls (hidden by default)
            app.PlayButton = uibutton(app.UIFigure, 'push', ...
                'Text', char(9654), ... % Unicode play icon ►
                'Position', [400 50 50 30], ...
                'ButtonPushedFcn', @(btn, event) onPlayButtonPressed(app), ...
                'Visible', 'off');

            app.PauseButton = uibutton(app.UIFigure, 'push', ...
                'Text', char(10073), ... % Unicode pause icon ❚❚
                'Position', [460 50 50 30], ...
                'ButtonPushedFcn', @(btn, event) onPauseButtonPressed(app), ...
                'Visible', 'off');

            % Speed slider (hidden by default)
            app.SpeedSlider = uislider(app.UIFigure, ...
                'Position', [520 65 120 3], ...
                'Limits', [0.1 2], ...
                'Value', 0.5, ...
                'MajorTicks', [0.1 0.5 1 1.5 2], ...
                'Visible', 'off', ...
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
        end

    end

    methods (Access = public)

        function app = SatelliteChangeAppOne
            createComponents(app);
        end

    end

end
