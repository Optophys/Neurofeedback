%% Snippet Plot Example
%
% <html>
% Import snippet data into Matlab using TDTbin2mat <br>
% Sort snippets based on channel number and sort code for any number of channels and sort codes <br>
% Plot the average waveform shape and standard deviation for 16 channels and three sort codes <br>
% Good for spike sorting and first-pass visualization of sorted waveforms
% </html>

%% Housekeeping
% Clear workspace and close existing figures. Add SDK directories to Matlab
% path.
close all; clear all; clc;
[MAINEXAMPLEPATH,name,ext] = fileparts(cd); % \TDTMatlabSDK\Examples
DATAPATH = fullfile(MAINEXAMPLEPATH, 'ExampleData'); % \TDTMatlabSDK\Examples\ExampleData
[SDKPATH,name,ext] = fileparts(MAINEXAMPLEPATH); % \TDTMatlabSDK
addpath(genpath(SDKPATH));

%% Importing the Data
% This example assumes you downloaded our example data sets
% (<http://www.tdt.com/files/examples/TDTExampleData.zip link>) and extracted
% it into the \TDTMatlabSDK\Examples\ directory. To import your own data, replace
% |BLOCKPATH| with the path to your own data block.
%
% In Synapse, you can find the block path in the database. Go to Menu > History. 
% Find your block, then Right-Click > Copy path to clipboard.
BLOCKPATH = fullfile(DATAPATH,'Algernon-180308-130351');

%%
% Now read snippet data into a Matlab structure called 'data'.
data = TDTbin2mat(BLOCKPATH, 'TYPE', {'snips'});

%% 
% And that's it! Your data is now in Matlab. The rest of the code describes sorting 
% snippets based on channel number and sort code, then plotting a subselection of 
% 16 channels and three sort codes. 

%% Spike Snippet Sorting
% Collect waveforms, averages, standard deviation, and snippet times of all 
% snippets, sorted by channel and sortcode number.

% Note: If you want a pile plot of *ALL* snippets (every channel), use this:
% figure; 
% plot(samples, data.snips.eNe1.data(:,:)); 

% Pull field name as string from snip store
SNIP_STORE = fieldnames(data.snips);
SNIP_STORE = SNIP_STORE{1};

% Useful variables
numchans = single(max(data.snips.(SNIP_STORE).chan));
nsamples = length(data.snips.(SNIP_STORE).data(1,:)); 
sorts = sort(unique(data.snips.(SNIP_STORE).sortcode))';

% Declare stores for sort codes, averages, standard deviations, and timestamps
sorted_stores = cell(numchans, numel(sorts)); 
store_averages = cell(numchans, numel(sorts));
sorted_stdp = cell(numchans, numel(sorts));
sorted_stdn = cell(numchans, numel(sorts));
snip_times = cell(numchans, numel(sorts));
snip_isi = cell(numchans, numel(sorts));

% Filter based on channel and sort code
for chan = 1:numchans
    for sort_ind = 1:numel(sorts)
        sort_code = sorts(sort_ind);
        if sort_code == 0 || sort_code == 31
            continue
        end
        
        % Create index for data that matches current channel and sortcode
        i = find(data.snips.(SNIP_STORE).chan == chan & data.snips.(SNIP_STORE).sortcode == sort_code);
        sorted_stores{chan, sort_code} = 1e6*data.snips.(SNIP_STORE).data(i,:); % scaled to uV
        store_averages{chan, sort_code} = sum(sorted_stores{chan, sort_code}/length(sorted_stores{chan, sort_code}));
        sorted_stdp{chan, sort_code} = std(sorted_stores{chan, sort_code}) + store_averages{chan, sort_code};
        sorted_stdn{chan, sort_code} = store_averages{chan, sort_code} - std(sorted_stores{chan, sort_code});
        
        % Find timestamps of snips
        snip_times{chan, sort_code} = data.snips.(SNIP_STORE).ts(i);
        
        % Inter-spike Interval of sorted snips
        snip_isi{chan,sort_code} = diff(snip_times{chan,sort_code});
    end
end

% Use this code blcok to extract unsorted and outlier snips
% unsorted = cell(numchans,1);
% outliers = cell(numchans,1);
% 
% for CHANNEL = 1:numchans
%     i = data.snips.(SNIP_STORE).chan == CHANNEL & data.snips.(SNIP_STORE).sortcode == 0;
%     unsorted{CHANNEL, 1} = data.snips.(SNIP_STORE).data(i,:);
%     
%     j = data.snips.(SNIP_STORE).chan == CHANNEL & data.snips.(SNIP_STORE).sortcode == 31;
%     outliers{CHANNEL, 1} = data.snips.(SNIP_STORE).data(j,:);
% end

%% Channel 11 ISI Histograms
% Look at ISI histogram for first 3 sort codes

figure('Name','ISI Histograms','Position',[900, 100, 500, 800]);
ISI_CHANNEL = 11;
for sort_code = 1:3
    if size(snip_isi{ISI_CHANNEL, sort_code},1) == 0
        continue
    end
    subplot(3,1,sort_code)
    hist(snip_isi{sort_code})
    if sort_code == 1
        title(sprintf('Channel %d ISI Histograms',ISI_CHANNEL),'FontSize',16)
    end
    ylabel(sprintf('Sortcode %d',sort_code),'FontSize',16)
    axis square
end
xlabel('Seconds','FontSize',16)

%% Waveform Plots
% <html>
% Create filled waveform plots with channels and sortcodes <br>
% Waveforms will be the average waveform of all snippets for each sortcode
% for each channel, with a standard deviation fill around it <br>
% Note: The plot below only uses up to 16 channels and 3 sort codes but can
% be modified <br>
% </html>

% Samples array for x-axis of fill plots
sample_arr = 1:nsamples;
XX = [sample_arr, fliplr(sample_arr)];

h = figure('Name','Sorted Spike Snippets','Position', [100, 100, 800, 800]);

% Add master title to subplots using figure uicontrol
uicontrol('Style','text','String','Sorted Spike Snippets','FontSize',20','HorizontalAlignment',...
    'center', 'Units','normalized', 'Position', [0 .93 1 .05],...
    'BackgroundColor',[1 1 1]);

if numchans > 16
    error('This display function is only good for 16 channels or less')
end

% Default colors for sort codes 1, 2, 3
colors = {[0.9290, 0.6940, 0.1250],[0.6350, 0.0780, 0.1840],[0, 0.75, 0.75]};

max_axis = zeros(1,4);
ax = zeros(1, numchans);
for chan = 1:numchans
    row = floor((chan-1)/4) + 1;
    col = mod((chan-1),4) + 1;
    
    % Loop through the sort codes
    for sort_code = 1:3
        % Used for filling Std Dev in with Fill later
        YY = [sorted_stdp{chan,sort_code}, fliplr(sorted_stdn{chan,sort_code})];

        % Set position and size of 16 subplots to fill the space
        % pos = [left bottom width height]
        pos = [col/5-0.075 0.7125-(row-1)/5 1/5 1/5];
        ax(chan) = subplot('Position',pos);

        % Only add axis labels on left column and bottom row
        if row == 4 && col == 1
            xlabel('Samples','FontSize',16);
            ylabel('Amplitude (\muV)','FontSize',16);
        else
            % Get rid of the numbers but leave the ticks.
            set(gca,'Xticklabel',[]);
            set(gca,'Yticklabel',[]);
        end
        
        if store_averages{chan,sort_code}(1) == 0
            continue
        end
        
        % Std dev fill around averaged waveform
        h = fill(XX, YY, colors{sort_code});
        set(h, 'facealpha',.15);
        hold on;
        plot(store_averages{chan,sort_code},'color',colors{sort_code},'LineWidth',1);
        % Channel labels
        text(15, -400, sprintf('Ch %d',chan));
        % keep track of maximum axes so we can put all plots on same axes
        axis square; axis tight;
        max_axis(1) = min(XX);
        max_axis(2) = max(XX);
        max_axis(4) = max(max_axis(4), max(YY));
        max_axis(3) = min(max_axis(3), min(YY));
    end
end

% use same axes for all plots
for chan = 1:numchans
    axis(ax(chan), max_axis)
end
