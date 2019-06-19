% neurofeedbackdata process into python readable data
addpath('\npy-matlab-master\'); %github
addpath('\PStructureAndFileReading\') %to read TDT DATA
path2savematfiles='O:\archive\projects\2018_rattrack\misc\Golan_neurofeedback\mat_files_beta\';
path2allfiles='O:\archive\projects\2014_ERC\processed\Golan\Neurofeedback\G206\';
allsessions=dir([path2allfiles, 'G206_180*']);

for sessid=1:size(allsessions,1) 
    pathSingleSession=[path2allfiles,allsessions(sessid).name,'\'];  
    pathSingleSession=[path2allfiles,allsessions(sessid).name,'\',allsessions(sessid).name,'\'];
    tdt_tankfile=dir([pathSingleSession,'*.Tbk']);    
    [frame, frame_fs,~]=readStreamInBlockFile([pathSingleSession 'ERCtank_', pathSingleSession(end-13:end-1)],'fram',1);    
    reward=load([pathSingleSession(1:end-14) 'rwrd.mat']);
    reward=reward.rwrd;
    frame_times=find(frame==1)/frame_fs; %in sec    
    rwrds=[reward,reward+0.07];   
    save([path2savematfiles,'data4python_',allsessions(sessid).name,'.mat'],'rwrds','frame_times');
end
