function [ts, samps] = time_limit_plot_inds (time_to_plot, dat, fs)
% This function gets the data input structure and time to plot and returns
% the indices which correspond to the time limits
%
% Last updated: 07/06/2018, by Golan Karvat

samp_to_plot = floor(fs * time_to_plot);
siz = size(dat);
if samp_to_plot > siz(2)
    samps = 1:siz(2);
    ts = (1:siz(2))/fs;
else
    samps = siz(2)-samp_to_plot+1 : siz(2);
    ts = samps / fs;
end

end