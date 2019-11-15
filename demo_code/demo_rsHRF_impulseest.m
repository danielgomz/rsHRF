%% demo code for voxel-wise HRF deconvolution
%% From NIFTI image (resting state fMRI data) to NIFTI image (HRF parameters).
%% Guo-Rong Wu, gronwu@gmail.com, SWU, 2019.10.30
%% Reference: Wu, G.; Liao, W.; Stramaglia, S.; Ding, J.; Chen, H. & Marinazzo, D..
%% A blind deconvolution approach to recover effective connectivity brain networks
%% from resting state fMRI data. Medical Image Analysis, 2013,17(3):365-374 .
clc,clear;close all;
warning off all

%%===========PARAMETERS========================
options = impulseestOptions; % see impulseestOptions.m for help 
options.RegularizationKernel = 'none'; %Regularizing kernel, used for regularized estimates of impulse response for all input-output channels. Regularization reduces variance of estimated model coefficients and produces a smoother response by trading variance for bias
para.options = options;

para.temporal_mask = []; % without mask, it means temporal_mask = ones(nobs,1); i.e. all time points included. nobs: number of observation = size(data,1). if want to exclude the first 1~5 time points, let temporal_mask(1:5)=0;

TR = .72; % THIS WILL BE READ FROM THE BIDS DATA

para.TR = TR;
para.passband=[0.01 0.08]; %bandpass filter lower and upper bound

%%% the following parameter (upsample grid) can be > 1 only for Canonical.
para.T  = 1; 
para.T0 = 1; 

min_onset_search = 4; % minimum delay allowed between event and HRF onset (seconds)
max_onset_search = 8; % maximum delay allowed between event and HRF onset (seconds)

para.dt  = para.TR/para.T; % fine scale time resolution.

para.AR_lag = 1; % AR(1) noise autocorrelation.

para.thr = 1; % (mean+) para.thr*standard deviation threshold to detect event.

para.len = 24; % length of HRF, in seconds

para.lag  = fix(min_onset_search/para.dt):fix(max_onset_search/para.dt);

%%===================================

%%===========fMRI Data========================
load voxelsample_hcp
nobs=size(bold_sig,1);
bold_sig=zscore(bold_sig);
bold_sig = rest_IdealFilter(bold_sig, para.TR, para.passband);
tic
[beta_hrf, event_bold] = rsHRF_estimation_impulseest(bold_sig,para);
hrfa = beta_hrf(1:end-1,:); %HRF

nvar = size(hrfa,2); PARA = zeros(3,nvar);

for voxel_id=1:nvar
    
    hrf1 = hrfa(:,voxel_id);
    
    [PARA(:,voxel_id)] = wgr_get_parameters(hrf1,para.TR/para.T);% estimate HRF parameter
    
end

toc
disp('Done');



disp('Deconvolving HRF ...');
tic
T = round(para.len/TR);
if para.T>1
    hrfa_TR = resample(hrfa,1,para.T);
else
    hrfa_TR = hrfa;
end
hrf=hrfa_TR;
H=fft([hrf; zeros(nobs-length(hrf),1)]);
M=fft(bold_sig(:,1));
data_deconv = ifft(conj(H).*M./(H.*conj(H)+.1*mean(H.*conj(H))));
event_number=length(event_bold{1,1});
toc
disp('Done');


%% example plots
event_plot=sparse(1,nobs);
event_plot(event_bold{1,1})=1;
figure(1);hold on;plot((1:length(hrfa(:,1)))*TR/para.T,hrfa(:,1),'b');xlabel('time (s)')
title('HRF')
figure;plot((1:nobs)*TR/para.T,zscore(bold_sig(:,1)));
hold on;plot((1:nobs)*TR/para.T,zscore(data_deconv(:,1)),'r');
stem((1:nobs)*TR/para.T,event_plot,'k');legend('BOLD','deconvolved','events');xlabel('time (s)')