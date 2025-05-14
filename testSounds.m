clear all; close all; clc;

% load sentences
[targ fs] = audioread('mainTaskSounds/T3_M_Charlie_Blue_1.wav');
mask1 = audioread('mainTaskSounds/T0_M_Hopper_Red_4.wav');
mask2 = audioread('mainTaskSounds/T1_M_Eagle_White_8.wav');

rms_targ = rms(targ);

% give the masks the same rms
mask1 = mask1 * rms_targ / rms(mask1);
mask2 = mask2 * rms_targ / rms(mask2);

% put the mask in the left channel
left = zeros(max([length(mask1), length(mask2)]),1);
right= zeros(length(targ),1);

for i = 1:length(mask1)
    left(i) = left(i) + mask1(i);
end

for i = 1:length(mask2)
    left(i) = left(i) + mask2(i);
end

% put the target in the right channel giving her the same rms as the left
% channel
rms_sumMask = rms(left);
right = targ * rms_sumMask / rms_targ;

new_rms_right = rms(right);
new_rms_left = rms(left);

sansBip = right;

% load alarm
alarm = audioread('mainTaskSounds/alarms(CRM_RWC_Stage)/synth_M_IRBA_107_Hz_500_ms_44100.wav');

% compute the coefficient to normalize its rms with right side for reference
rms_alarm = rms(alarm);
coef = rms(right)/rms_alarm;
alarm = alarm * coef;

new_rms_alarm = rms(alarm);

% zero padding on the alarm
z = zeros(42849,1);
alarm = [z ; alarm];

bip = alarm;

% add alarm with right side
for i = 1:length(alarm)
    right(i) = right(i) + alarm(i);
end

new_rms_right_withAlarm = rms(right);

% zeropad right to have same size
z2 = zeros(6485,1);
right = [right ; z2];

new_rms_right_withAlarm_andPadding = rms(right);

avecBip = right;

% normalize levels by max
maxVal = max([max(abs(left)), max(abs(right))]);

left = left * 0.5 / maxVal;
right = right * 0.5 / maxVal;

sansBip = sansBip * 0.5 / maxVal;
avecBip = avecBip * 0.5 / maxVal;
bip = bip * 0.5 / maxVal;

% save sounds
audiowrite('sansBip_matlab.wav',sansBip,fs);
audiowrite('avecBip_matlab.wav',avecBip,fs);
audiowrite('bip_matlab.wav',bip,fs);