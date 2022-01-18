
function multiple_xy_graph(varargin)

global ax;
global fig;
global flexorStimValue;
global extensorStimValue;
global flexorKeyboardInput;
global extensorKeyboardInput;
global ardObject;
global stopFlag;

if ~isempty(varargin)
    block = varargin{1};
    setup(block);
else
    fprintf('\nYou can not run the program by running this M file.');
    fprintf('\nYou need to run the simulink program.');
    
    return;
end

    function setup(block)
        
        close all;
        
        block.NumInputPorts=2;
        block.NumOutputPorts=1;
        block.NumDialogPrms=2;
        block.RegBlockMethod('Start',@Start);
        block.RegBlockMethod('Outputs',@Outputs);
        block.RegBlockMethod('Terminate',@Terminate);
        %block.RegBlockMethod('readSerialData', @readSerialData);
        
        % Setup functional port properties to dynamically
        % inherited.
        block.SetPreCompInpPortInfoToDynamic;
        block.SetPreCompOutPortInfoToDynamic;
        
        % Hard-code certain port properties
        % ***This is needed! Otherwise the loop seems to run twice each
        % iteration.
        block.InputPort(1).DirectFeedthrough = false;
        block.InputPort(1).Dimensions = 25;
        block.InputPort(2).Dimensions = 7;
        block.OutputPort(1).Dimensions = 25;
        block.InputPort(2).DirectFeedthrough = false;
        block.OperatingPointCompliance = 'Default';
        block.RegBlockMethod('PostPropagationSetup',    @DoPostPropSetup);
        block.RegBlockMethod('Update', @Update);
    end

    function Start(block)
        fig=figure;
        ss = get(0, 'ScreenSize');
        % [left bottom width height]
        width = ss(3) / 2;
        height = ss(4) * 0.75;
        left = width / 2;
        bottom = height / 2;
        set(fig, 'Position', [left, bottom, width, height]);
        movegui(fig,'center');
        
        flexorStimValue = 0;
        extensorStimValue = 0;
        flexorKeyboardInput = 0;
        extensorKeyboardInput = 0;
        stopFlag = 0;
        
        %rto = get_param(gcb,'RuntimeObject');
        
        % Get base simulink model name
        modelName = bdroot;
        % Get contro mode
        h = Simulink.findBlocks(modelName,'Name','ControlModeConstant');
        
        % If EMG control, setup arduino
        controlType = get_param(h,'Value')
        
        % Get control type
        % controlType = block.InputPort(2).Data(7);
        if (str2num(controlType) == 2) % If EMG control
            % Check if arduino object exists
            newobjs = instrfind;
            if ~isempty(newobjs)
                fclose(newobjs);
            end
            
            % Get Serial COM Port
            h = Simulink.findBlocks(modelName,'Name','Serial COM Port');
            comPort = get_param(h,'Value');
            comPortStr = ['COM' num2str(comPort)];
            
            freeports = serialportlist("available");
            result = strfind(freeports, 'comPortStr');
            if isempty(result);
                fprintf('Uh oh, serial port is already in use.');
            end
            
            ardObject = serialport(comPortStr,19200);
            %configureCallback(ardObject,"byte",17,@readSerialData)
            configureCallback(ardObject,"terminator",@readSerialData);
            configureTerminator(ardObject,88);
            
        end
        
        % Set up axes for drawing arm
        ax = axes(fig);
        set(ax, 'Position', [0.1 0.175 0.8 0.8]); % [left bottom width height].
        
        % Flexor Stimulation
        btnFlexorStim = uicontrol(fig,'Style', 'ToggleButton');
        set(btnFlexorStim, 'String', 'FLEXOR');
        set(btnFlexorStim, 'Units', 'Normalized');
        set(btnFlexorStim, 'Position', [0.3 0.05 0.2 0.08]); % [left bottom width height].
        set(btnFlexorStim, 'ButtonDownFcn', @(btnFlexorStim,event) buttonDownFlexorStim(btnFlexorStim,block));
        set(btnFlexorStim,'Enable','Inactive');
        
        % Extensor Stimulation
        btnExtensorStim = uicontrol(fig,'Style', 'ToggleButton');
        set(btnExtensorStim, 'String', 'EXTENSOR');
        set(btnExtensorStim, 'Units', 'Normalized');
        set(btnExtensorStim, 'Position', [0.5 0.05 0.2 0.08]); % [left bottom width height].
        set(btnExtensorStim, 'ButtonDownFcn', @(btnExtensorStim,event) buttonDownExtensorStim(btnExtensorStim,block));
        set(btnExtensorStim,'Enable','Inactive');
        
        % Stop Button
        btnExtensorStim = uicontrol(fig,'Style', 'ToggleButton');
        set(btnExtensorStim, 'String', 'STOP');
        set(btnExtensorStim, 'Units', 'Normalized');
        set(btnExtensorStim, 'Position', [0.88 0.01 0.1 0.1]); % [left bottom width height].
        set(btnExtensorStim, 'ButtonDownFcn', @(btnStop,event) buttonDownStop(btnStop,block));
        set(btnExtensorStim,'Enable','Inactive');
        
        % Setup keyboard input
        set(fig,'KeyPressFcn',@keyBoardPressFun);
        set(fig,'KeyReleaseFcn',@keyBoardReleaseFun);
        
        
    end


    function Outputs(block)
        
        % Get control type
        controlType = block.InputPort(2).Data(7);
        if (controlType == 0) % Keyboard
            block.OutputPort(1).Data(1) = flexorKeyboardInput;
            block.OutputPort(1).Data(2) = extensorKeyboardInput;
            
            plot(-0.45, 0.42, '.', 'MarkerSize', 50);
        elseif (controlType == 1) % Mouse
            block.OutputPort(1).Data(1) = flexorStimValue;
            block.OutputPort(1).Data(2) = extensorStimValue;
        elseif (controlType == 2) % EMG
            dataOutLong = char(ardObject.UserData);
            
            len = length(dataOutLong);
            
            if ~isempty(dataOutLong)
                dataOutLong(len+1) = 'X';
            else
                fprintf('Empty!');
            end
            
            % Find last X
            tmpInd = findstr(dataOutLong, 'X');
            % Take 9 things after
            if (~isempty(tmpInd)) % && (tmpInd)
                lastX_ind = tmpInd(end);
                dataOut = dataOutLong(lastX_ind-8:lastX_ind);
            else
                dataOut = [];
                y1 = 0;
                y2 = 0;
            end
            
            % Parse out A and B serial channel data.
            len = length(dataOut);
            
            % Check to see if string input is good
            if (len >= 9)
                chk1 = strcmp(dataOut(1), 'A');
                chk2 = strcmp(dataOut(5), 'B');
                chk3 = strcmp(dataOut(9), 'X');
                chkSum = sum([chk1 chk2 chk3]);
            else
                chkSum = 0;
            end
            
            if (chkSum == 3)
                indA = findstr(dataOut, 'A');
                newStrA = dataOut(indA(1)+1:indA(1)+3);
                secondPart = dataOut(indA(1)+4:end);
                newStrB = secondPart(2:4);
                
                if ~strcmp(newStrA, '000');
                    y1 = str2num(newStrA);
                else
                    y1 = 0;
                end
                if ~strcmp(newStrB, '000');
                    y2 = str2num(newStrB);
                else
                    y2 = 0;
                end
                
            else
                y1 = 0;
                y2 = 0;
            end
            
            block.OutputPort(1).Data(1) = y1; % Flexor
            block.OutputPort(1).Data(2) = y2; % Extensor
            
        end
        
        
        block.OutputPort(1).Data(3) = stopFlag;
        
        
        if isgraphics(ax)
            cla(ax);
        else
            return;
        end
        
        % Plot Upper (Stationary) Arm
        X1 = ['block.InputPort(1).Data(' num2str(1) ')']; %shoulder
        Y1 = ['block.InputPort(1).Data(' num2str(2) ')']; %shoulder
        X2 = ['block.InputPort(1).Data(' num2str(3) ')']; %elbow
        Y2 = ['block.InputPort(1).Data(' num2str(4) ')']; %elbow
        str = ['plot(ax, [' X1 ' ' X2 '], [' Y1 ' ' Y2 '], ''-k''' ', ' '''LineWidth'', 3);'];
        eval(str);
        hold(ax,'on');
        
        % Plot Lower (moving) Arm
        X3 = ['block.InputPort(1).Data(' num2str(5) ')'];   %elbow
        Y3 = ['block.InputPort(1).Data(' num2str(6) ')'];  %elbow
        X4 = ['block.InputPort(1).Data(' num2str(7) ')'];   % wrist
        Y4 = ['block.InputPort(1).Data(' num2str(8) ')'];     % wrist
        str1 = ['plot(ax, [' X3 ' ' X4 '], [' Y3 ' ' Y4 '], ''-k''' ', ' '''LineWidth'', 3);'];
        eval(str1);
        
        % plot movement target point
        X5 = ['block.InputPort(1).Data(' num2str(9) ')']; % x
        Y5 = ['block.InputPort(1).Data(' num2str(10) ')']; % y
        str2 = ['plot(ax, ' X5 ', ' Y5 ' , ''.k'', ''MarkerSize'', 30' ');'] ;
        eval(str2);
        
        % plot starting point of movement
        X6 = ['block.InputPort(1).Data(' num2str(11) ')']; % x
        Y6 = ['block.InputPort(1).Data(' num2str(12) ')'];  % y
        str3 = ['plot(ax, ' X6 ', ' Y6 ' , ''.k'', ''MarkerSize'', 30' ');'] ;
        eval(str3);
        
        %Plot Extensor muscle
        X7 = ['block.InputPort(1).Data(' num2str(13) ')'];   % Proximal Muscle attachment point, x
        Y7 = ['block.InputPort(1).Data(' num2str(14) ')'];  % Proximal Muscle attachment point, y
        X8 = ['block.InputPort(1).Data(' num2str(15) ')'];  % Distal Muscle attachment point, x
        Y8 = ['block.InputPort(1).Data(' num2str(16) ')'];    % Distal Muscle attachment point, y
        if (block.OutputPort(1).Data(2) > 0)
            str4 = ['plot(ax, [' X7 ' ' X8 '], [' Y7 ' ' Y8 '],''-r''' ', ' '''LineWidth'', 3);'];
        else
            str4 = ['plot(ax, [' X7 ' ' X8 '], [' Y7 ' ' Y8 '],''-k''' ', ' '''LineWidth'', 3);'];
        end
        eval(str4);
        
        %Plot flexor muscle
        X9 = ['block.InputPort(1).Data(' num2str(17) ')'];  % Proximal Muscle attachment point, x
        Y9 = ['block.InputPort(1).Data(' num2str(18) ')'];  % Proximal Muscle attachment point, y
        X10 = ['block.InputPort(1).Data(' num2str(19) ')'];   % Distal Muscle attachment point, x
        Y10 = ['block.InputPort(1).Data(' num2str(20) ')'];    % Distal Muscle attachment point, y
        if (block.OutputPort(1).Data(1) > 0)
            str4 = ['plot(ax, [' X9 ' ' X10 '], [' Y9 ' ' Y10 '],''-r''' ', ' '''LineWidth'', 3);'];
        else
            str4 = ['plot(ax, [' X9 ' ' X10 '], [' Y9 ' ' Y10 '],''-k''' ', ' '''LineWidth'', 3);'];
        end
        eval(str4);
        
        % Plot extended lower arm
        X11 = ['block.InputPort(1).Data(' num2str(21) ')'];   % elbow
        Y11 = ['block.InputPort(1).Data(' num2str(22) ')'];   % elbow
        X12 = ['block.InputPort(1).Data(' num2str(23) ')'];   %Extended lower arm endpoint, x
        Y12 = ['block.InputPort(1).Data(' num2str(24) ')'];   %Extended lower arm endpoint, y
        str5 = ['plot(ax, [' X11 ' ' X12 '], [' Y11 ' ' Y12 '],''-k''' ', ' '''LineWidth'', 3);'];
        eval(str5)
        
        % Set axis limits
        XMIN = block.DialogPrm(2).Data(1); % Shoulder X
        XMAX = block.DialogPrm(2).Data(2); % Shoulder Y
        YMIN = block.DialogPrm(2).Data(3); % Elbow X
        YMAX = block.DialogPrm(2).Data(4); % Elbow Y
        
        XMIN = -0.5;
        XMAX = 0.5;
        YMIN = -0.1;
        YMAX = 0.5;
        
        axis(ax, [XMIN XMAX YMIN YMAX]);
        
        
        MovTime = block.InputPort(2).Data(1);  %Movement time
        MovTime = num2str(MovTime);
        
        TrialNum = block.InputPort(2).Data(2);  % Trial number
        TrialNum = num2str(TrialNum);
        
        
        Mes = block.InputPort(2).Data(3);    %message number
        
        IC = block.InputPort(2).Data(4);    %Detect phase 1 (time between the trial is stopped and the variables are not reset yet)
        
        Res = block.InputPort(2).Data(5);    %Detect phase 2 (time between the variables are reset but the trial has not started yet)
        
        TrialTime = block.InputPort(2).Data(6);  % Trial time
        TrialTime = num2str(TrialTime);
        
        %To display Movement time, Trial number and message during phase 1
        % (post-trial completion phase)
        if IC == 0
            text(ax,-0.45,0.42,['Trial number: ' ,TrialNum], 'FontSize', 20);
            text(ax,-0.45,0.45,['Movement time: ' ,MovTime], 'FontSize', 20);
            if Mes == 1
                text(ax,-0.45,0.35,'Time is up','color','red', 'FontSize', 20);
            elseif Mes == 2
                text(ax,-0.45,0.35,'Success!!','color',[0/255 102/255 51/255], 'FontSize', 20);
            end
        end
        
        %To display 'Get ready' message during phase 2
        % (pre-trial)
        if Res == 0 && IC == 1
            text(ax,-0.45, 0.4,'Get ready','color','blue', 'FontSize', 20);
        end
        
        % Trial is running
        if Res == 1 && IC == 1
            text(ax, -0.45, 0.4, 'Go!', 'color', 'blue', 'FontSize', 20);
            
            % Trial Time
            text(ax, 0.3, 0.4, ['T: ', TrialTime], 'color', 'blue', 'FontSize', 20);
        end
        
        
        
        drawnow limitrate
        
        
    end

    function buttonDownFlexorStim(btnFlexorStim,block)
        block.OutputPort(1).Data(1:25) = 0;
        block.OutputPort(1).Data(1) = 1;
        set(fig, 'WindowButtonUpFcn', @(btnFlexorStim,event) buttonUp(btnFlexorStim,block));
        
        flexorStimValue = 1;
    end

    function buttonDownExtensorStim(btnExtensorStim,block)
        block.OutputPort(1).Data(1:25) = 0;
        block.OutputPort(1).Data(2) = 1;
        set(fig, 'WindowButtonUpFcn', @(btnExtensorStim,event) buttonUp(btnExtensorStim,block));
        
        extensorStimValue = 1;
    end

    function buttonDownStop(btnStop,block)
         stopFlag = 1;
%         block.OutputPort(1).Data(1:25) = 0;
%         block.OutputPort(1).Data(2) = 1;
%         set(fig, 'WindowButtonUpFcn', @(btnExtensorStim,event) buttonUp(btnExtensorStim,block));
%         
%         extensorStimValue = 1;
    end

    function buttonUp(btn,block)
        block.OutputPort(1).Data(1:25) = 0;
        block.OutputPort(1).Data(1) = 0;
        block.OutputPort(1).Data(2) = 0;
        flexorStimValue = 0;
        extensorStimValue = 0;
    end




    function Terminate(block)
        % Get base simulink model name
        modelName = bdroot;
        % Get contro mode
        h = Simulink.findBlocks(modelName,'Name','ControlModeConstant');
        % If EMG control, setup arduino
        controlType = get_param(h,'Value')
        
        if (str2num(controlType) == 2) % If EMG control
            configureCallback(ardObject,"off");
            %         stopasync(ardObject);
            %         fclose(ardObject);
            
            if exist('ardObject','var');
                %         fclose(ardObject);
                delete(ardObject);
                clear('ardObject');
            end
        end
        
        
        cla(ax);
        text(ax,-0.45, 0.4,'DONE','color','blue', 'FontSize', 60);
        pause(1.5);
        
        for i=1:block.DialogPrm(1).Data
            eval(['clear global h' num2str(i)])
        end
        
        close all;
        
        %         % Find the XY Plot that shows trial progress.
        %         set(0,'ShowHiddenHandles','on');
        %         H=findobj('tag','SIMULINK_XYGRAPH_FIGURE');
        %         set(H,'menubar','figure');
        %         allAxesInFigure = findall(H,'type','axes');
        %         set(get(allAxesInFigure,'XLabel'),'String','Trial Number');
        %         set(get(allAxesInFigure,'YLabel'),'String','Movement Time (s)');
        %         set(allAxesInFigure,'XGrid', 'On');
        %         set(allAxesInFigure,'YGrid', 'On');
        %         set(allAxesInFigure,'Box', 'On');
        %         set(allAxesInFigure,'LineWidth', 0.5);
    end

    function DoPostPropSetup(block)
        block.NumDworks = 1;
        
        block.Dwork(1).Name            = 'x1';
        block.Dwork(1).Dimensions      = 25;
        block.Dwork(1).DatatypeID      = 0;      % double
        block.Dwork(1).Complexity      = 'Real'; % real
        block.Dwork(1).UsedAsDiscState = true;
    end

    function Update(block)
        %data = readline(ardObject);
        %src.UserData = data;
        
        block.Dwork(1).Data(1:25) = block.InputPort(1).Data(1:25);
    end

    function keyBoardPressFun(src,event)
        whichKey = event.Key;
        
        if strcmp(whichKey, 'leftarrow')
            flexorKeyboardInput = 1;
            extensorKeyboardInput = 0;
        elseif strcmp(whichKey, 'rightarrow')
            flexorKeyboardInput = 0;
            extensorKeyboardInput = 1;
        else
            flexorKeyboardInput = 0;
            extensorKeyboardInput = 0;
        end
    end

    function keyBoardReleaseFun(src,event)
        % whichKey = event.Key;
        flexorKeyboardInput = 0;
        extensorKeyboardInput = 0;
    end

    function readSerialData(src, evt)
        data = readline(src);
        %          data = fgets(ardObject);
        src.UserData = data;
        %          fprintf('\nFiring!');
    end
end

