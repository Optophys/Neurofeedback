% This script accompanies the neurofeedback TDT circuit, for online
% calculation of the percentiles and presentation of data.
% The RZ2 is controlled directly from the script. For assistance with 
% controlling TDT with matlab, contact TDT support. 

% Housekeeping
clear
close all; 
SDKPATH = 'C:\MatlabPrograms\TDTSDK\Streaming_from_Myles'; % path in which the file offline_percentiles.mat is located
addpath(genpath(SDKPATH));
load([SDKPATH '\offline_percentiles.mat']); %file with variable Y, which has "clean" power percentiles calculated offline on rat 206, 171205
load([SDKPATH '\offline_medians.mat']);  %file with variable MEDS, which has "clean" power medians calculated offline on rat 206, 171205
%% Initialize activeX control
DA = actxcontrol('TDevAcc.X'); %call the TDevAcc active x controls
DA.ConnectServer('Local') %connect to your local TDT server
DA.SetSysMode(2); %2 is preview, 3 is record, 0 is idle
% Some more commands appear in the example file but are not needed here
%% Setup
% ****************************************
%                                        *
session_file_name = 'G468_190618_1'; %   * change here for each session
auto_save = 0; %                         *                           
%                                        *
% ****************************************
save_dir = 'D:\mat_files';
% The events of interest should also be mentioned in the call to TDT2mat
% inside OpenExLive (around line 120)
EVENT1 = 'Powr'; %stores to be transfered from TDT to matlab
EVENT2 = 'test';
EVENT3 = 'arts';
EVENT4 = 'Locl';
t = OpenExLive();
t.VERBOSE = false;

%% Initial parameters
cfg = [];
cfg.freqs           = 15:30;    %to plot, in Hz
cfg.f_target        = [20 25];  % marked as dashed white lines on the online plot
cfg.medians_time    = 10;       %in seconds. Updated from TDT
cfg.group_delay     = 130;      %in samples
cfg.art_time        = 300;      %rejected time around artifact, in samples. Updated from TDT
cfg.do_plot         = 0;        %bool, 1 means plotting
cfg.do_LFP_artifact = 1;        %bool, 1 means do artifact removal from raw data
cfg.pause_dur       = 1;        %corresponds to "Matlab refresh" in the TDT GUI
cfg.plot_normalized = 'yes';

%% Main Loop
first_pass = true;
b = true;
n = 1;
b_to_plot = 20;
prev_samp = 0;
last_samp = 0;

whole_arts      = [];
whole_pows      = [];
whole_raws      = [];
whole_arts.LFP  = [];
whole_arts.Pix  = [];
LFP_clean       = []; % The raw LFP, with NaNs at artifact samples
Pix_clean       = []; % The power in each frequency, with NaNs at artifact samples
LFP_debt        = [];
Pix_debt        = [];
max_beta        = 0;
beta_thresh     = [];

figure(10); set(gcf,'position',[1383 555 524 553]); % power spectra relative to the percentile, astrices on bursts. Lower subplot: raw LFP trace
figure(3); set(gcf,'position',[1383 297 217 164]);  % blue: loop execution duration in ms. Ensure refresh rate is slower to avoid crash. Orange: number of samples going backwards due to artifact. 
figure(4); set(gcf,'position',[1619 297 284 164]);  % blue: the percentile. orange: current threshold. Yellow: value of the median x FOM

while b
    % slow it down
    pause(cfg.pause_dur)
    
    % get the most recent data, exit loop if the block has stopped.
    tic
    try t.update();
    catch b=0; continue; end
    
    % grab the latest events
    pows = t.get_data(EVENT1); %estimated power in 1:32 Hz    
    whole_pows = [whole_pows, pows.data];
    
    raws = t.get_data(EVENT2); %raw LFP data used to calculate power
    raws.data = raws.data(1,:); %ignore the filtered test stream
    whole_raws = [whole_raws, raws.data];
    
    arts = t.get_data(EVENT3); %boolean, artifact detected in the LFP(1) or power (2)
    new_arts.LFP = find(arts.data(1,:));
    new_arts.Pix = find(arts.data(2,:));
    whole_arts.LFP = [whole_arts.LFP, new_arts.LFP];
    whole_arts.Pix = [whole_arts.Pix, new_arts.Pix];
    
    % calculations and plotting
    if isstruct(pows) %go in only if data was grabbed
        siz = size(pows.data);
        last_samp = prev_samp + siz(2);
        samps = prev_samp+1 : last_samp;
        
        %get currect parameters from the TDT GUI
        cfg.perc            = DA.GetTargetVal('RZ2.percentile');
        cfg.medians_time    = DA.GetTargetVal('RZ2.pwr_perc_duration');
        cfg.art_time        = DA.GetTargetVal('RZ2.art_time');
        cfg.do_plot         = DA.GetTargetVal('RZ2.do_plot');
        cfg.pause_dur       = DA.GetTargetVal('RZ2.Matlab_refresh');
        cfg.FOM             = DA.GetTargetVal('RZ2.FOM');
        
        % remove artifacts
        Pix = pows.data;
        Pix (:,1:Pix_debt) = NaN; % put NaNs at the "debt" from the previous read
        Pix_debt = [];
        % Put NaNs around the artifacts
        for arin = new_arts.Pix %clean the LFP. can be removed in the end (the power is the important).
            if arin <= cfg.art_time
                Pix (:,1 : arin + cfg.art_time) = NaN;
                if ~isempty(Pix_clean) %Put NaNs also in the previous read
                    Pix_clean(:,end - (cfg.art_time-arin) : end) = NaN;
                end
            elseif arin >= (siz(2) - cfg.art_time)
                Pix (:,arin - cfg.art_time : end) = NaN;
                Pix_debt = cfg.art_time - (siz(2)-arin); %keep "NaN debt" for the nexe read
            else
                Pix (:,arin - cfg.art_time : arin + cfg.art_time) = NaN;
            end
        end
        Pix_clean = [Pix_clean, Pix];
        
        perc_samps = floor(cfg.medians_time * pows.fs);
        clean_perc_samps = perc_samps;
        if size(Pix_clean,2) > perc_samps
            % make sure to have perc_samps artifact free samples to calculate the threshold on
            art_dur = sum(isnan(Pix_clean(1,end-clean_perc_samps : end)));
            if art_dur < 0.9*(clean_perc_samps) %if tere were way too many artifacts, use the previous value
                while clean_perc_samps - art_dur < perc_samps
                    clean_perc_samps = clean_perc_samps + max(1000,art_dur);
                    if clean_perc_samps >= length(Pix_clean)-1 
                        clean_perc_samps = length(Pix_clean)-1; break
                    end
                    art_dur = sum(isnan(Pix_clean(1,end-clean_perc_samps : end)));
                end
                THRESHOLDS = prctile(Pix_clean(:,end-clean_perc_samps : end),cfg.perc,2); %takes ~5ms
                MEDS = nanmedian(Pix_clean(:,end-clean_perc_samps : end),2);
            end
        else %before having enough values, use percentiles of recorded data
            col = find(Y.percentiles == cfg.perc); %p must be in 80:0.5:99.5
            THRESHOLDS = Y.values(:,col);
        end
        %         send the thresholds to TDT (this should happen instantly)
        beta_thresh(n,1) = THRESHOLDS(b_to_plot);
        THRESHOLDS = max(THRESHOLDS,MEDS*cfg.FOM); %"static" threshold to avoid bias in quiet periods.  At least the median * cfg.FOM
        for frin = 1: length(THRESHOLDS)
            DA.SetTargetVal(['RZ2.mat_in_~' num2str(frin)],THRESHOLDS(frin));
        end
                
        if cfg.do_LFP_artifact %remove the artifacts also from the raw LFP trace
            LFP = raws.data;
            LFP (1:LFP_debt) = NaN;
            LFP_debt  = [];
            for arin = new_arts.LFP %clean the LFP. can be removed in the end (the power is the important).
                if arin <= cfg.art_time
                    LFP   (1 : arin + cfg.art_time) = NaN;
                    if ~isempty(LFP_clean) %Put NaNs also in the previous read
                        LFP_clean(end - (cfg.art_time-arin) : end) = NaN;
                    end
                elseif arin >= (siz(2) - cfg.art_time)
                    LFP   (arin - cfg.art_time : end) = NaN;
                    LFP_debt = cfg.art_time - (siz(2)-arin); %keep "NaN debt" for the nexe read
                else
                    LFP   (arin - cfg.art_time : arin + cfg.art_time) = NaN;
                end
            end
            LFP_clean = [LFP_clean, LFP];
        end
        
        if cfg.do_plot
            Locals = t.get_data(EVENT4); %read in the peaks time
            figure(10); 
            subplot(4,1,1:3);
            ts = samps / pows.fs;
            if strcmp(cfg.plot_normalized,'yes')
                imagesc(ts, cfg.freqs, pows.data(cfg.freqs,:)./ THRESHOLDS(cfg.freqs),[0 2]);
                title('Relative power');
            else
                clims = [0 5000]; %based on recordings from 206. think if makes sense to have it as input from TDT
                imagesc(ts, cfg.freqs, pows.data(cfg.freqs,:),clims);
                title('Power');
            end            
            axis xy; colormap jet; colorbar('northoutside');
            hold on
            [ii,jj] = find(Locals.data);
            ii = ii + cfg.freqs(1) - 1; %the first frequency is 15
            scatter(ts(jj),ii,50,'fill','k')
            scatter(ts(jj),ii,20,'*w')
            plot([ts(1),ts(end)],[cfg.f_target(1), cfg.f_target(1)],'--w','linewidth',1.5);
            plot([ts(1),ts(end)],[cfg.f_target(2), cfg.f_target(2)],'--w','linewidth',1.5);
            ylabel('Frequency (Hz)')
            
            subplot(414);
            % use the same time stamps for raw as for power
            try 
                plot(ts,whole_raws(:,samps - cfg.group_delay)');                 
            end
            set(gca,'xlim',[ts(1), ts(end)],'ylim',[-500 500]); %if necessary, can save the artifact value from TDT
            title('Raw'); xlabel('Time (sec)'); ylabel('\muV');              
        end
        
        prev_samp = last_samp;
        prev_samps(n) = last_samp; %used to store the data acquisition points. Useful for debugging
        beta_thresh(n,2) = THRESHOLDS(b_to_plot);
        beta_thresh(n,3) = MEDS(b_to_plot)*cfg.FOM;
        max_beta = max(max_beta,THRESHOLDS(20));
        added_samps(n) = clean_perc_samps - perc_samps; %used to plot the number of artifact samples
    end
    
    figure(4); %plot the thrshold history
    if n>61
        plot(n-60:n,beta_thresh(end-60:end,:)); %plot the last minute
        set(gca, 'xlim',[n-60,n]);
    else
        plot(beta_thresh); 
        set(gca, 'xlim',[0.99,n]);
    end    
    title('Threshold at 20 Hz');
    legend({'98','THR','fom'},'location','best','Orientation','horizontal','FontSize',8); legend boxoff    
    
    a(n) = toc;
    figure(3); %plot execution time and number of artifact samples
    if n>61
        yyaxis left
        plot(n-60:n,a(end-60:end)*1000);
        yyaxis right
        plot(n-60:n,added_samps(end-60:end));
        set(gca, 'xlim',[n-60,n]);
    else
        yyaxis left
        plot(a*1000); 
        yyaxis right
        plot(added_samps);
        set(gca, 'xlim',[0.99,n]);
    end    
    title('Matlab exec. dur.');
    n = n+1;
end
disp('Block stopped?'); % the loop is exited when data grabbing from TDT fails

% saving 
if auto_save
    file_name = careful_save (save_dir,session_file_name); %saving in the dir specified in save_dir, being careful to to override wxisting data
    save (file_name);
    disp(['Saved under ', file_name]);
else
    warning ('Dont forget to save the data!!!');
end