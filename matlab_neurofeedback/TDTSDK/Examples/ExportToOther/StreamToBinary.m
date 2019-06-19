%% Export Continuous Data To Binary File
%
% <html>
% Import continuous data into Matlab using TDTbin2mat <br>
% Export the to a binary file (f32 floating point or 16-bit integer) <br>
% Channels are interlaced in the final output file <br>
% Good for exporting to other data analysis applications <br>
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

%% Setup the variables for the data you want to extract
% We will extract the stream stores and output them to 16-bit integer files
FORMAT = 'i16'; % i16 = 16-bit integer, f32 = 32-bit floating point
SCALE_FACTOR = 1e6; % scale factor for 16-bit integer conversion, so units are uV
% Note: The recommended scale factor for f32 is 1

%% 
% Now read channel stream data into a Matlab structure called 'data'.
data = TDTbin2mat(BLOCKPATH, 'TYPE', {'streams'});

%% 
% If you want an individual store, use the 'STORE' filter like this:
% 
%   data = TDTbin2mat(BLOCKPATH, 'TYPE', {'streams'}, 'STORE', 'Wav1');
% 

%% 
% And that's it! Your data is now in Matlab. The rest of the code is
% writing the data to disk in a new format.

% Loop through all the streams and save them to disk.
fff = fields(data.streams);
for ii = 1:numel(fff)
    thisStore = fff{ii};
    OUTFILE = fullfile(BLOCKPATH, [thisStore '.' FORMAT]);

    fid = fopen(OUTFILE, 'wb');
    if strcmpi(FORMAT, 'i16')
        fwrite(fid, SCALE_FACTOR*reshape(data.streams.(thisStore).data, 1, []), 'integer*2');
    elseif strcmpi(FORMAT, 'f32')
        fwrite(fid, SCALE_FACTOR*reshape(data.streams.(thisStore).data, 1, []), 'single');
    else
        warning('Format %s not recognized. Use i16 or f32', FORMAT);
        break
    end
    fprintf('Wrote %s to output file %s\n', thisStore, OUTFILE);
    fprintf('Sampling Rate: %.6f Hz\n', data.streams.(thisStore).fs);
    fprintf('Num Channels: %d\n', size(data.streams.(thisStore).data, 1));
    fclose(fid);
end
