classdef SatelliteChangeAppOne < matlab.apps.AppBase

    properties (Access = public)
        UIFigure matlab.ui.Figure
        LoadFolderButton matlab.ui.control.Button
        ChangeTypeGroup matlab.ui.container.ButtonGroup
        ForestButton matlab.ui.control.RadioButton
        CityButton matlab.ui.control.RadioButton
        InfraButton matlab.ui.control.RadioButton
        WaterButton matlab.ui.control.RadioButton
        VisualizationDropDown matlab.ui.control.DropDown
        InfoTextArea matlab.ui.control.TextArea

        PlaybackTimer timer
        IsPlaying logical = false
        CurrentVisMode string = ""
        FlickerState logical = false

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

        ImageFolder string
        ImageFiles struct
        Images cell

    end

    methods (Access = private)

    function LoadFolderButtonPushed(app, ~)
        folder = uigetdir;
        if folder == 0, return; end

        app.ImageFolder = folder;
        app.ImageFiles = dir(fullfile(folder, '*.jpg'));
        if isempty(app.ImageFiles)
            uialert(app.UIFigure, 'No .jpg images found.', 'Error');
            return;
        end

        app.Images = cell(1, length(app.ImageFiles));
        names = {app.ImageFiles.name};

        for i = 1:length(app.ImageFiles)
            app.Images{i} = imread(fullfile(app.ImageFiles(i).folder, app.ImageFiles(i).name));
        end

        app.ImageDropDown1.Items = names;
        app.ImageDropDown2.Items = names;

        % Default to first two
        app.ImageDropDown1.Value = names{1};
        if length(names) >= 2
            app.ImageDropDown2.Value = names{2};
        else
            app.ImageDropDown2.Value = names{1};
        end

        % Update both previews
        updateImagePreview(app, 1);
        updateImagePreview(app, 2);

        app.InfoTextArea.Value = sprintf('Loaded %d images from folder.', length(names));

        % Force window to front and maximized
        app.UIFigure.WindowState = 'maximized'; % <-- Add this line
        drawnow; % Ensure update
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

        switch mode
            case 'Flicker'
                onPlayButtonPressed(app);
            case 'Timelapse'
                onPlayButtonPressed(app);
            case 'Overlay'
                % Implement overlay visualization here
            case 'Absolute Difference'
                % Implement difference visualization here
            case 'Heatmap'
                % Implement heatmap visualization here
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

            if isempty(app.Images) || isempty(app.ImageFiles) || isempty(dropdown.Items)
                % Show white image
                blank = ones(100, 100, 3);  % white RGB image
                imshow(blank, 'Parent', ax);
                axis(ax, 'off');
                title(ax, axTitle);
                return;
            end

            name = dropdown.Value;
            imageNames = {app.ImageFiles.name};
            matchIdx = find(strcmp(imageNames, name), 1);

            if isempty(matchIdx)
                blank = ones(100, 100, 3);  % fallback white box
                imshow(blank, 'Parent', ax);
                axis(ax, 'off');
                title(ax, [axTitle, ' (Not found)']);
                return;
            end

            imshow(app.Images{matchIdx}, 'Parent', ax);
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

            % Use SpeedSlider value for timer period (lower = faster)
            % To make higher slider value = faster playback, invert:
            minPeriod = 0.1;
            maxPeriod = 2;
            sliderVal = app.SpeedSlider.Value;
            % Map slider so that higher value = faster (lower period)
            period = maxPeriod - (sliderVal - minPeriod);

            % Clamp period to [minPeriod, maxPeriod]
            period = max(minPeriod, min(maxPeriod, period));

            % Create a new timer
            app.PlaybackTimer = timer( ...
            'ExecutionMode', 'fixedSpacing', ...
            'Period', period, ...
            'TimerFcn', @(~,~) runPlaybackStep(app));

            start(app.PlaybackTimer);
        end

        function onPauseButtonPressed(app)
            app.IsPlaying = false;
            if ~isempty(app.PlaybackTimer) && isvalid(app.PlaybackTimer)
                stop(app.PlaybackTimer);
                delete(app.PlaybackTimer);
            end
        end

        function runFlickerStep(app)
            if isempty(app.ImageDropDown1.Items), return; end

            idx1 = find(strcmp(app.ImageDropDown1.Items, app.ImageDropDown1.Value));
            idx2 = find(strcmp(app.ImageDropDown2.Items, app.ImageDropDown2.Value));
            if isempty(idx1) || isempty(idx2), return; end

            % Flicker between two
            if app.FlickerState
                imshow(app.Images{idx1}, 'Parent', app.ResultAxes);
            else
                imshow(app.Images{idx2}, 'Parent', app.ResultAxes);
            end
            app.FlickerState = ~app.FlickerState;
        end

        function runTimelapseStep(app)
            persistent frameIndex frames

            if isempty(frames)
                idx1 = find(strcmp(app.ImageDropDown1.Items, app.ImageDropDown1.Value));
                idx2 = find(strcmp(app.ImageDropDown2.Items, app.ImageDropDown2.Value));
                if isempty(idx1) || isempty(idx2), return; end

                low = min(idx1, idx2);
                high = max(idx1, idx2);

                frames = app.Images(low:high);
                frameIndex = 1;
            end

            if frameIndex <= length(frames)
                imshow(frames{frameIndex}, 'Parent', app.ResultAxes);
                frameIndex = frameIndex + 1;
            else
                frameIndex = 1; % Loop back to start
                imshow(frames{frameIndex}, 'Parent', app.ResultAxes);
                frameIndex = frameIndex + 1;
            end
        end
        function runPlaybackStep(app)
            switch app.CurrentVisMode
                case 'Flicker'
                    runFlickerStep(app);
                case 'Timelapse' % <-- Fix here
                    runTimelapseStep(app);
                otherwise
                    onPauseButtonPressed(app);
            end
        end
        function onSpeedSliderChanged(app, ~)
            if app.IsPlaying
                onPauseButtonPressed(app);   % Stop current timer
                onPlayButtonPressed(app);    % Restart with new speed
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

            % Change Type Radio Group
            app.ChangeTypeGroup = uibuttongroup(app.UIFigure, ...
                'Title', 'Type of Change', ...
                'Position', [20 400 180 120]);

            app.ForestButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Forest', ...
                'Position', [10 80 100 20]);

            app.CityButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'City', ...
                'Position', [10 60 100 20]);

            app.InfraButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Infrastructure', ...
                'Position', [10 40 100 20]);

            app.WaterButton = uiradiobutton(app.ChangeTypeGroup, ...
                'Text', 'Water', ...
                'Position', [10 20 100 20]);

            % Visualization Type Dropdown
            app.VisualizationDropDown = uidropdown(app.UIFigure, ...
                'Items', {'Flicker', 'Overlay', 'Absolute Difference', 'Timelapse', 'Heatmap'}, ...
                'Value', 'Flicker', ...
                'Position', [20 360 180 30]);

            % Info Text Area (in a panel for border)
            infoPanel = uipanel(app.UIFigure, ...
                'Position', [20 200 180 140], ...
                'BorderType', 'line', ...
                'Title', '');
            app.InfoTextArea = uitextarea(infoPanel, ...
                'Position', [1 1 178 138], ...
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
                'Position', [220 380 250 30]);  % Y = 380 aligns closely below

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
                'Position', [20 150 180 40], ... % X=20, width=180, Y=150 puts it below InfoTextArea
                'ButtonPushedFcn', @(btn, event) onVisualizeButtonPressed(app), ...
                'FontWeight', 'bold', ...
                'FontSize', 16, ...
                'BackgroundColor', [0.2 0.6 1]); % Light blue, change as desired

            % Set dropdown callback to control visibility
            app.VisualizationDropDown.ValueChangedFcn = @(dd, event) onVisualizationModeChanged(app);
        end
    end

    methods (Access = public)

        function app = SatelliteChangeAppOne
            createComponents(app);
        end
    end
end
