classdef MosaicApp < matlab.apps.AppBase
    % =====================================================
    % Secure Mosaic Image App
    % Correct PIN -> Secret image
    % Wrong PIN   -> Scrambled mosaic
    % =====================================================

    %% ---------------- UI COMPONENTS ----------------
    properties (Access = public)
        UIFigure              matlab.ui.Figure
        TabGroup              matlab.ui.container.TabGroup

        % Sender
        SenderTab             matlab.ui.container.Tab
        SecretButton          matlab.ui.control.Button
        SecretLabel           matlab.ui.control.Label
        TargetButton          matlab.ui.control.Button
        TargetLabel           matlab.ui.control.Label
        PINEditField          matlab.ui.control.EditField
        WatermarkEditField    matlab.ui.control.EditField
        AlphaSlider           matlab.ui.control.Slider
        GroupSizeField        matlab.ui.control.NumericEditField
        BlockSizeField        matlab.ui.control.NumericEditField
        RunSenderButton       matlab.ui.control.Button
        SenderLogArea         matlab.ui.control.TextArea

        % Receiver
        ReceiverTab           matlab.ui.container.Tab
        KeyButton             matlab.ui.control.Button
        KeyLabel              matlab.ui.control.Label
        EncButton             matlab.ui.control.Button
        EncLabel              matlab.ui.control.Label
        PINReceiverField      matlab.ui.control.EditField
        RunReceiverButton     matlab.ui.control.Button
        ReceiverLogArea       matlab.ui.control.TextArea
    end

    %% ---------------- INTERNAL DATA ----------------
    properties (Access = private)
        secretFile char = ''
        targetFile char = ''
        keyFile    char = ''
        encFile    char = ''
    end

    %% ---------------- APP LIFE CYCLE ----------------
    methods (Access = public)
        function app = MosaicApp
            createComponents(app)
            registerApp(app, app.UIFigure)
            app.logSender('App started');
            app.logReceiver('App started');
        end

        function delete(app)
            if isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end

    %% ---------------- CALLBACKS ----------------
    methods (Access = private)

        % -------- Sender --------
        function onSecretChoose(app,~,~)
            [f,p] = uigetfile({'*.png;*.jpg;*.jpeg'});
            if isequal(f,0), return; end
            app.secretFile = fullfile(p,f);
            app.SecretLabel.Text = ['Secret: ' f];
            app.logSender('Secret image selected');
        end

        function onTargetChoose(app,~,~)
            [f,p] = uigetfile({'*.png;*.jpg;*.jpeg'});
            if isequal(f,0), return; end
            app.targetFile = fullfile(p,f);
            app.TargetLabel.Text = ['Target: ' f];
            app.logSender('Target image selected');
        end

        function onRunSender(app,~,~)
            if isempty(app.secretFile) || isempty(app.targetFile)
                app.logSender('Select secret & target images');
                return;
            end

            params.secretFile = app.secretFile;
            params.targetFile = app.targetFile;
            params.pin        = app.PINEditField.Value;
            params.wm_text    = app.WatermarkEditField.Value;
            params.alpha      = round(app.AlphaSlider.Value);
            params.groupSize  = app.GroupSizeField.Value;
            params.blockSize  = app.BlockSizeField.Value;

            app.logSender('Running sender...');
            create_mosaic_sender(params);
            app.logSender('Encrypted image & key saved');
        end

        % -------- Receiver --------
        function onKeyChoose(app,~,~)
            [f,p] = uigetfile('*.mat');
            if isequal(f,0), return; end
            app.keyFile = fullfile(p,f);
            app.KeyLabel.Text = ['Key: ' f];
            app.logReceiver('Key file selected');
        end

        function onEncChoose(app,~,~)
            [f,p] = uigetfile({'*.png;*.jpg;*.jpeg'});
            if isequal(f,0), return; end
            app.encFile = fullfile(p,f);
            app.EncLabel.Text = ['Encrypted: ' f];
            app.logReceiver('Encrypted image selected');
        end

        function onRunReceiver(app,~,~)
            if isempty(app.keyFile) || isempty(app.encFile)
                app.logReceiver('Select key & encrypted image');
                return;
            end

            pin = app.PINReceiverField.Value;
            app.logReceiver('Running receiver...');

            [mosaic_decrypted, recovered_text] = ...
                recover_mosaic_receiver(pin, app.keyFile, app.encFile);

            % ---- DISPLAY RESULT (NO HEADING) ----
            figs = findall(0,'Type','figure','Name','Recovered Mosaic');
            if ~isempty(figs), close(figs); end

            figure('Name','Recovered Mosaic','NumberTitle','off');
            imshow(uint8(mosaic_decrypted),[]);

            if isempty(recovered_text)
                app.logReceiver('Wrong PIN → scrambled mosaic shown');
            else
                app.logReceiver('Correct PIN → secret image recovered');
            end
        end
    end

    %% ---------------- UI CREATION ----------------
    methods (Access = private)

        function createComponents(app)

            % -------- Main Figure --------
            app.UIFigure = uifigure( ...
                'Position',[100 100 900 520], ...
                'Name','Secure Mosaic App');

            app.TabGroup = uitabgroup(app.UIFigure,...
                'Position',[10 10 880 500]);

            % ================= Sender Tab =================
            app.SenderTab = uitab(app.TabGroup,'Title','Sender');

            app.SecretButton = uibutton(app.SenderTab,'push',...
                'Text','Choose Secret','Position',[20 420 120 30],...
                'ButtonPushedFcn',@app.onSecretChoose);

            app.SecretLabel = uilabel(app.SenderTab,...
                'Position',[160 425 400 22],'Text','Secret: none');

            app.TargetButton = uibutton(app.SenderTab,'push',...
                'Text','Choose Target','Position',[20 380 120 30],...
                'ButtonPushedFcn',@app.onTargetChoose);

            app.TargetLabel = uilabel(app.SenderTab,...
                'Position',[160 385 400 22],'Text','Target: none');

            uilabel(app.SenderTab,'Position',[20 330 80 22],'Text','PIN');
            app.PINEditField = uieditfield(app.SenderTab,'text',...
                'Position',[120 330 200 24]);

            uilabel(app.SenderTab,'Position',[20 290 80 22],'Text','Watermark');
            app.WatermarkEditField = uieditfield(app.SenderTab,'text',...
                'Position',[120 290 300 24]);

            uilabel(app.SenderTab,'Position',[20 250 80 22],'Text','Alpha');
            app.AlphaSlider = uislider(app.SenderTab,...
                'Position',[120 260 200 3],'Limits',[1 20],'Value',6);

            uilabel(app.SenderTab,'Position',[350 250 80 22],'Text','Group');
            app.GroupSizeField = uieditfield(app.SenderTab,'numeric',...
                'Position',[430 250 80 24],'Value',16);

            uilabel(app.SenderTab,'Position',[20 210 80 22],'Text','Block');
            app.BlockSizeField = uieditfield(app.SenderTab,'numeric',...
                'Position',[120 210 80 24],'Value',16);

            app.RunSenderButton = uibutton(app.SenderTab,'push',...
                'Text','Run Sender','Position',[20 160 120 36],...
                'ButtonPushedFcn',@app.onRunSender);

            app.SenderLogArea = uitextarea(app.SenderTab,...
                'Position',[20 20 820 120],'Editable','off');

            % ================= Receiver Tab =================
            app.ReceiverTab = uitab(app.TabGroup,'Title','Receiver');

            app.KeyButton = uibutton(app.ReceiverTab,'push',...
                'Text','Choose Key','Position',[20 420 120 30],...
                'ButtonPushedFcn',@app.onKeyChoose);

            app.KeyLabel = uilabel(app.ReceiverTab,...
                'Position',[160 425 400 22],'Text','Key: none');

            app.EncButton = uibutton(app.ReceiverTab,'push',...
                'Text','Choose Encrypted','Position',[20 380 120 30],...
                'ButtonPushedFcn',@app.onEncChoose);

            app.EncLabel = uilabel(app.ReceiverTab,...
                'Position',[160 385 400 22],'Text','Encrypted: none');

            uilabel(app.ReceiverTab,'Position',[20 330 80 22],'Text','PIN');
            app.PINReceiverField = uieditfield(app.ReceiverTab,'text',...
                'Position',[120 330 200 24]);

            app.RunReceiverButton = uibutton(app.ReceiverTab,'push',...
                'Text','Run Receiver','Position',[20 280 120 36],...
                'ButtonPushedFcn',@app.onRunReceiver);

            app.ReceiverLogArea = uitextarea(app.ReceiverTab,...
                'Position',[20 20 820 240],'Editable','off');
        end

        %% -------- Logging --------
        function logSender(app,msg)
            ts = datestr(now,'HH:MM:SS');
            app.SenderLogArea.Value = ...
                [app.SenderLogArea.Value; {['[' ts '] ' msg]}];
        end

        function logReceiver(app,msg)
            ts = datestr(now,'HH:MM:SS');
            app.ReceiverLogArea.Value = ...
                [app.ReceiverLogArea.Value; {['[' ts '] ' msg]}];
        end
    end
end

