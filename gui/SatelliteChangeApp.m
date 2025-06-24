classdef SatelliteChangeApp < matlab.apps.AppBase

    properties (Access = public)
        UIFigure matlab.ui.Figure
        SelectFolderButton matlab.ui.control.Button
        ImageListBox matlab.ui.control.ListBox
        VisualizationDropDown matlab.ui.control.DropDown
        VisualizeButton matlab.ui.control.Button
        UIAxes matlab.ui.control.UIAxes

        ImageFolder string
        ImageFiles struct
        Images cell
    end

    methods (Access = private)

        function SelectFolderButtonPushed(app, ~)
            folder = uigetdir;
            if folder == 0, return; end

            app.ImageFolder = folder;
            app.ImageFiles = dir(fullfile(folder, '*.jpg')); % You can add .png, etc.
            app.Images = cell(1, length(app.ImageFiles));

            % Load images and populate listbox
            names = {app.ImageFiles.name};
            for i = 1:length(app.ImageFiles)
                app.Images{i} = imread(fullfile(app.ImageFiles(i).folder, app.ImageFiles(i).name));
            end
            app.ImageListBox.Items = names;
        end

        function VisualizeButtonPushed(app, ~)
            selected = app.ImageListBox.Value;

            if isempty(selected)
                uialert(app.UIFigure, 'Please select at least two images.', 'Error');
                return;
            end

            visType = app.VisualizationDropDown.Value;
            imageNames = {app.ImageFiles.name};
            indices = find(ismember(imageNames, selected));
            imgs = app.Images(indices);

            % Validation
            if ismember(visType, {'Difference Highlight', 'Overlay'}) && length(imgs) ~= 2
                uialert(app.UIFigure, 'Select exactly 2 images for this method.', 'Error');
                return;
            elseif strcmp(visType, 'Time-lapse') && length(imgs) < 2
                uialert(app.UIFigure, 'Select at least 2 images for timelapse.', 'Error');
                return;
            end

            % Run visualization
            switch visType
                case 'Difference Highlight'
                    img1 = rgb2gray(imgs{1});
                    img2 = rgb2gray(imgs{2});
                    diff = imabsdiff(img1, img2);
                    imshow(diff, [], 'Parent', app.UIAxes);

                case 'Overlay'
                    img1 = im2double(imgs{1});
                    img2 = im2double(imgs{2});
                    overlay = 0.5 * img1 + 0.5 * img2;
                    imshow(overlay, 'Parent', app.UIAxes);

                case 'Time-lapse'
                    for i = 1:length(imgs)
                        img = imgs{i};
                        imshow(img, 'Parent', app.UIAxes);
                        pause(0.5);
                    end
            end
        end
    end

    methods (Access = private)

        function createComponents(app)
            % Create figure
            app.UIFigure = uifigure('Position', [100 100 850 500]);
            app.UIFigure.Name = 'Satellite Change Visualizer';

            % Folder select button
            app.SelectFolderButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Select Image Folder', ...
                'Position', [30 440 180 30], ...
                'ButtonPushedFcn', @(btn, event) SelectFolderButtonPushed(app));

            % Listbox for image selection
            app.ImageListBox = uilistbox(app.UIFigure, ...
                'Multiselect', 'on', ...
                'Items', {}, ...
                'Position', [30 280 180 150]);

            % Dropdown for visualization type
            app.VisualizationDropDown = uidropdown(app.UIFigure, ...
                'Items', {'Difference Highlight', 'Overlay', 'Time-lapse'}, ...
                'Value', 'Difference Highlight', ...
                'Position', [30 240 180 30]);

            % Visualize button
            app.VisualizeButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Visualize', ...
                'Position', [30 200 180 30], ...
                'ButtonPushedFcn', @(btn, event) VisualizeButtonPushed(app));

            % Axes for showing output
            app.UIAxes = uiaxes(app.UIFigure, ...
                'Position', [250 50 570 420]);

            % Add title manually
            title(app.UIAxes, 'Change Visualization');
        end
    end

    methods (Access = public)

        function app = SatelliteChangeApp
            createComponents(app);
        end
    end
end
