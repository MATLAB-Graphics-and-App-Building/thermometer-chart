classdef thermometerChart < matlab.graphics.chartcontainer.ChartContainer
    %thermometerChart Create a chart for progress toward quantitative goals
    %   thermometerChart(areaData, max) create a thermometer chart with 
    %   maximum value max. areaData is a vector of 1D data displayed 
    %   on the thermometer chart. Each quantitity is displayed above the 
    %   last on the vertical stem, so the final chart is cumulative.
    % 
    %   thermometerChart(areaData, limits) create a thermometer chart where 
    %   limits is a 1 x 2 numerical vector which specifies minimum and 
    %   maximum values. areaData is a vector of 1D data displayed 
    %   on the thermometer chart. Each quantitity is displayed above the 
    %   last on the vertical stem, so the final chart is cumulative.
    % 
    %   thermometerChart() create a thermometer chart using only
    %   name-value pairs.
    %
    %   thermometerChart(___,Name,Value) specifies additional options
    %   for the thermometer chart using one or more name-value pair
    %   arguments. Specify the options after all other input arguments.
    %
    %   thermometerChart(parent,___) creates the thermometer chart in the
    %   specified parent.
    %
    %   h = thermometerChart(___) returns the thermometerChart object.
    %   Use h to modify properties of the plot after creating it.
    
    %   Copyright 2021 The MathWorks, Inc.

    properties
        % 1D data corresponding to filled sections of the thermometer
        AreaData (1,:) {mustBeNumeric} = []

        % Title of the thermometer chart
        TitleText (:,1) string = []

        % text labels for each element in AreaData
        AreaLabels (1,:) string = []

        % goals data and text labels for any goals
        GoalData (1,:) {mustBeNumeric} = []
        GoalLabels (1,:) string = []

        % string specifying location of goal labels ('left'/'right')
        GoalLocation char {mustBeMember(GoalLocation,{'left', 'right'})} = 'left'

        % Min, Max for vertical axis
        Limits (1,2) {mustBeNumeric, mustBeLimits} = [0, 1]
    end

    properties(Access = private,Transient,NonCopyable)
        % Width of the thermometer stem
        StemWidth (1,1) double = 0.8
    end

    properties(Access = private,Transient,NonCopyable)
        Bulb (1,:) matlab.graphics.primitive.Rectangle
        Stem (1,:) matlab.graphics.primitive.Line
        Areas (1,:) matlab.graphics.primitive.Group
        AreaLabelLines (1,:) matlab.graphics.primitive.Line
        AreaLabelText (1,:) matlab.graphics.primitive.Text
        GoalLabelLines (1,:) matlab.graphics.primitive.Line
        GoalLabelText (1,:) matlab.graphics.primitive.Text
    end

    methods
        function obj = thermometerChart(varargin)
            % Initialize list of arguments
            args = varargin;
            leadingArgs = cell(0);

            % Check if the first input argument is a graphics object to use as parent.
            if ~isempty(args) && isa(args{1},'matlab.graphics.Graphics')
                % thermometerChart(parent, ___)
                leadingArgs = args(1);
                args = args(2:end);
            end

            % Check for optional positional arguments.
            if ~isempty(args) && isnumeric(args{1})
                if numel(args) >= 2 && mod(numel(args), 2) == 0
                    areaData = args{1};

                    if numel(args{2}) == 1 && isnumeric(args{2})
                        % thermometerChart(areaData, max)
                        % thermometerChart(areaData, max, Name, Value)
                        maxVal = args{2};

                        leadingArgs = [leadingArgs {'AreaData', areaData, 'Limits', [0, maxVal]}];
                        args = args(3:end);
                    elseif numel(args{2}) == 2
                        % thermometerChart(areaData, limits)
                        % thermometerChart(areaData, limits, Name, Value)
                        limits = args{2};

                        leadingArgs = [leadingArgs {'AreaData', areaData, 'Limits', limits}];
                        args = args(3:end);
                    else
                        error('Limits must be a 1x2 numeric vector or scalar.')
                    end
                else
                    error('Invalid number of arguments for thermometerChart.')
                end
            end

            % Combine positional arguments with name/value pairs.
            args = [leadingArgs args];

            % Call superclass constructor method
            obj@matlab.graphics.chartcontainer.ChartContainer(args{:});
        end

    end

    methods(Access = protected)
        function setup(obj)
            ax = getAxes(obj);

            % Create and set properties for thermometer stem axes
            ax.PlotBoxAspectRatio = [1 20 1];
            ax.TickDir = 'out';
            ax.XAxis.Visible = 'off';
            ax.YGrid = 'on';

            % Remove the stem axes toolbar
            ax.Toolbar = [];
            disableDefaultInteractivity(ax);

            % Remove axes toolbar
            ax.Toolbar = [];
            disableDefaultInteractivity(ax);

            % Save handle for rectangle at the bottom of the thermometer
            obj.Bulb = rectangle(ax, ...
                'Curvature', [ 1 1 ],...
                'Edgecolor', 'k',...
                'FaceColor', 'white', ...
                'Clipping', 'off',...
                'Linewidth', 1);

            % Group to contain surfaces which fill the thermometer
            obj.Areas = hggroup(ax);

            % Save handle for thermometer stem (3 segment line)
            obj.Stem = line(ax, ...
                'XData', [1 1 0 0], ...
                'YData', [0 1 1 0], ...
                'Linewidth', 1);

        end

        function update(obj)
            ax = getAxes(obj);

            % Check if the sizes of AreaData and AreaLabels are the same
            if ~isempty(obj.AreaLabels) && (numel(obj.AreaData) ~= numel(obj.AreaLabels))
                error('AreaData and AreaLabels must have the same size.')
            end

            % Check if the sizes of GoalData and GoalLabels are the same
            if ~isempty(obj.GoalLabels) && numel(obj.GoalData) ~= numel(obj.GoalLabels)
                error('GoalData and GoalLabels must have the same size.')
            end

            % Delete existing text, lines, and surfaces
            delete(obj.Areas.Children);
            delete(obj.AreaLabelLines);
            delete(obj.AreaLabelText);
            delete(obj.GoalLabelLines);
            delete(obj.GoalLabelText);

            % Set the height of the thermometer bulb to be a fixed
            % proportion of the length of the stem
            bulbHeightFactor = 1 / 20;
            BulbHeight =  (obj.Limits(2) - obj.Limits(1)) * 2 * bulbHeightFactor;

            % Set the bulb's horizontal axis/radius length to be the
            % thermometer stem width
            BulbWidth =  2 * obj.StemWidth;

            % Set the X and Y limits of the plot. For YLim, set the first
            % element to be slightly less than the first element of the specified
            % thermometer lower limit so that the stem connects to the
            % bulb.
            ax.XLim = [0, obj.StemWidth];
            ax.YLim = [obj.Limits(1) - (BulbHeight / 2) * 0.2, obj.Limits(2)];

            % Specify the position of the thermometer bulb (rectangle obj)
            x = obj.StemWidth / 2;
            y = obj.Limits(1) - BulbHeight / 2;
            px = x - BulbWidth / 2;
            py = y - BulbHeight / 2;

            % Update the position of the bulb at the bottom of the
            % thermometer
            obj.Bulb.Position = [px py BulbWidth BulbHeight];

            if numel(obj.AreaData) ~= 0 && any(obj.AreaData)
                % Color in the bulb at the bottom of the thermometer stem
                co = get(ax, 'colororder');
                obj.Bulb.FaceColor = co(1,:);

                % Computations for the first surface filling the
                % thermometer (first surface should cover bulb outline)
                leftSide = 0;
                rightSide = obj.StemWidth;
                bottom = obj.Limits(1) - (BulbHeight / 2) * 0.2;
                top = obj.Limits(1) + obj.AreaData(1);
    
                % Graphics objects arrays for storing areas, area label
                % lines, and area label text.
                areaLabelLines = gobjects(0);
                areaLabelText = gobjects(0);
    
                numAreas = numel(obj.AreaData);

                % Plot each of the categorical sections in the thermometer
                for i = 1:numAreas
                    % Choose the color of the segment corresponding to a row 
                    % of co, where the row number cycles through all rows in co
                    % using mod()
                    numColors = size(co,1);
                    colorIndex = mod(i - 1, numColors) + 1;
                    color = co(colorIndex, :);

                    % Only draw the surface if it's contained within the
                    % thermometer stem
                    if bottom >= obj.Limits(2)
                        break
                    end

                    % Make sure the surface doesn't exceed the thermometer
                    % limit
                    if top > obj.Limits(2)
                        top = obj.Limits(2);
                    end
    
                    % Create surface filling themometer stem
                    surface(ax, ...
                        'XData', [ leftSide rightSide ] , ...
                        'YData', [ bottom top ], ...
                        'ZData', [ 0 0 ; 0 0 ],  ...
                        'Facecolor', color , ...
                        'Edgecolor','none', ...
                        'Parent', obj.Areas);
                    
                    % Move the bottom coordinate to plot the next surface
                    % above the current one
                    bottom = top;

                    % Top coordinate of the surface
                    if (i + 1) <= numAreas
                        top = bottom + obj.AreaData(i + 1);
                    end
                end

                bottom = obj.Limits(1);

                % Plot each of the brackets and area labels
                for i = 1:numel(obj.AreaLabels)
                    top = bottom + obj.AreaData(i);

                    if ~isempty(obj.AreaLabels) && numel(obj.AreaLabels) >= i
                        [bracketXData, bracketYData, textXPos, textYPos, fullLabel] = ...
                            areaLabelHelper(obj.StemWidth, bottom, top, obj.Limits(2), ...
                            obj.AreaLabels{i});
    
                        % Create the brackets for area labels on the right 
                        bracket = line(ax, bracketXData, bracketYData, ...
                            'Color', 'k', ...
                            'Clipping','off');
                        
                        % Add text for area labels
                        bracketLabel = text(ax, textXPos, textYPos, fullLabel, ...
                            'Rotation', -90,...
                            'Fontsize', 10,...
                            'HorizontalAlignment', 'center',...
                            'VerticalAlignment', 'bottom', ...
                            'Clipping','off');
                        
                        % Save handles 
                        if ~isempty(bracket)
                            areaLabelLines(end + 1) = bracket;
                            areaLabelText(end + 1) = bracketLabel;
                        end
                    end

                    bottom = top;

                end

            end

            if numel(obj.AreaLabels) ~= 0
                obj.AreaLabelLines = areaLabelLines;
                obj.AreaLabelText = areaLabelText;
            end

            % Goal data within the limits of the stem
            validGoalIndices = (obj.GoalData <= obj.Limits(2)) & (obj.GoalData >= obj.Limits(1));
            validGoalData = obj.GoalData(validGoalIndices);

            % Goal labels within the limits of the them
            validGoalLabels = [];

            if ~isempty(obj.GoalLabels)
                validGoalLabels = obj.GoalLabels(validGoalIndices);
                
                % For saving goal lines/text
                goalLabelLines = gobjects(1, 2 * numel(validGoalLabels));
                goalLabelText = gobjects(1, numel(validGoalLabels));
            end


            % Mark goals using tick marks and diamond markers
            for i = 1:numel(validGoalData)
                [goalXData, ~, ~] = goalLabelLoc(obj.GoalLocation);

                goalYVal = validGoalData(i);
                goalYData = [ goalYVal goalYVal ];

                % Tick mark outside the thermometer stem at the goal
                goalTick = line(ax, goalXData, goalYData, ...
                    'Color', 'k', ...
                    'Clipping', 'off');

                % Draw the goal line and write the goal label
                goalLine = line(ax, [0 obj.StemWidth], goalYData, ...
                    'Color', 'k', ...
                    'Marker', 'diamond', ...
                    'MarkerSize', 5, ...
                    'MarkerFaceColor', 'k', ...
                    'Linestyle', ':', ...
                    'Clipping', 'off');

                start_idx = 2 * (i - 1) + 1;
                end_idx = start_idx + 1;
                goalLabelLines(start_idx: end_idx) = [goalTick goalLine];
            end

            if numel(obj.GoalData) ~= 0
                obj.GoalLabelLines = goalLabelLines;
            end

            % Mark goal labels
            for i = 1:numel(validGoalLabels)
                [~, textPos, horizontalAlignment] = goalLabelLoc(obj.GoalLocation);

                goalYVal = validGoalData(i);
                goalText = validGoalLabels(i);

                % Create goal label
                goalTextHandle = text(ax, textPos, goalYVal, goalText, ...
                    'HorizontalAlignment', horizontalAlignment,...
                    'VerticalAlignment', 'middle', ...
                    'Clipping', 'off');

                goalLabelText(i) = goalTextHandle;
            end

            if numel(obj.GoalLabels) ~= 0
                obj.GoalLabelText = goalLabelText;
            end

            % Update stem position
            obj.Stem.XData = [0 0 obj.StemWidth obj.StemWidth];
            obj.Stem.YData = [(obj.Limits(1) - (BulbHeight / 2) * 0.2) obj.Limits(2) ...
                obj.Limits(2) (obj.Limits(1) - (BulbHeight / 2) * 0.2)];

            % Set title 
            title(ax, obj.TitleText);
        end
    end

    methods
        % Title method. Called in update with the TitleText property so
        % that the user can specify the title of the thermometerChart.
        function title(obj,txt)
            if nargin>=2
                obj.TitleText = txt;
            end  
        end
    end
    
end

% Helper function for adding goal labels along the left/right
function [xdata, textPos, horizontalAlignment] = goalLabelLoc(goalsLoc)
    % Input:
    %   goalsLoc -- string specifying which side of the thermometer the
    %   goal labels will be located
    % Returns:
    %   xdata -- start/end x coordinates for the small goals tick on the
    %   side of the thermometer
    %   textPos -- x position of the text for the goalLabels
    %   horizontalAlignment -- string specifying the text alignment
    %   name/value pair when adding goals label text
    if strcmp(goalsLoc, 'right')
        xdata = [ 1 1.7 ];
        textPos = 1.8;
        horizontalAlignment = 'left';
    else
        xdata = [ 0 -.4 ];
        textPos = -1.2;
        horizontalAlignment = 'right';
    end
   
end

% Helper function for adding area labels to the right
function [bracketXData, bracketYData, textXPos, textYPos, fullLabel] = ...
    areaLabelHelper(stemWidth, yStart, yEnd, yMax, labelText)
    % Input:
    %   stemWidth -- width of the thermometer stem
    %   yStart -- the bottom y-coordinate of the areaLabel
    %   yEnd -- the top y coordinate of the areaLabel
    %   labelText -- the label text to be placed above the bracket 
    % Returns:
    %   bracketXData -- xdata for the thermometer-facing bracket to the right of
    %   the thermometer stem
    %   bracketYData -- ydata for the thermometer-facing bracket to the right of
    %   the thermometer stem
    %   textXPos -- the x-position of the text to the right of the bracket
    %   textYPos -- the y-position of the text to the right of the bracket
    %   fullLabel -- the full area label string arr (with area value and text)

    % Set factors to be multiplied by the stemWidth for bracket and label
    % placement. The bracketOuterFactor is greater than the bracketInner
    % Factor such that the long, vertical portion of the bracket is farther
    % to the right of the stem than the short, horizontal portions of the
    % bracket. 
    bracketInnerFactor = 0.5;
    bracketOuterFactor = 0.7;

    % Similarly, the textPos factor is slightly greater than the
    % bracketOuterFactor such that the text label is to the right of the long,
    % vertical portion of the bracket.
    textPosFactor = 0.8;

    % Set the xdata for a bracket facing the thermometer stem on the 
    % right side of the thermometer
    xRight = stemWidth;
    in = xRight + bracketInnerFactor * stemWidth;
    out = xRight + bracketOuterFactor * stemWidth;

    % Set the position of the text to be slightly more to the right
    % than the bracket and the rotation angle of the text (vertical text)
    textXPos = xRight + textPosFactor * stemWidth;
    
    % Set the xdata and ydata for the bracket facing the thermometer based
    % on whether the maximum value is exceeded
    if yStart >= yMax
        % Bracket is outside the limits
        bracketXData = [];
        bracketYData = [];
    elseif yEnd >= yMax
        % Bracket is partially in the limits
        yEnd = yMax;
        bracketXData = [ in out out ];
        bracketYData = [ yStart yStart yEnd ];
    else
        % Bracket is fully contained within the limits
        bracketXData = [ in out out in ];
        bracketYData = [ yStart yStart yEnd yEnd ];
    end

    textYPos = (yStart + yEnd) / 2;
    labelNum = num2str(yEnd - yStart);
    
    % If the label is empty, allocate space so all labels align
    if isempty(labelText)
        labelText = ' ';
    end

    % If a text label has been specified, add it to the numerical label.
    % Otherwise set the label to the numerical label only.
    if isempty(labelText)
        fullLabel = labelNum;
    else
        fullLabel = [ labelNum newline labelText];
    end
    
end

function mustBeLimits(limits)

    if limits(2) <= limits(1)
        throwAsCaller(MException('thermometerChart:InvalidLimits', 'Specify limits as two increasing values.'))
    end

end