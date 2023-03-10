%% Init
clear all;close all;clc
addpath('..\')

%% Edit zone %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% samplig time
Ts = 10;   % sampling time in CL (based on step response analysis)

% where to export controller 
ctrl_path = 'Z:\home\lvuser\khatanas\controlers\';
ctrl_name = {'pqp_10','rqp_10','yqp_10','pryqp_10'};

% where to store the discretized models and associated controllers
store_path = '..\store\';
file_Gds = 'ms10_Gs-disc-models-qp';
file_Ks = 'ms10_stabKqp';

%*************************************************************************%
Ts = Ts/1000;
T = 0:Ts:60;
s=tf('s');
z=tf('z',Ts);
OL = f.labviewRST(0,1,1,'solo');

%% Discretize model% load continuous time models
load([store_path 'Gs-cont-models-qp.mat'])
%*************************** PITCH ***************************************%
stepM = step(Gp,T);

% discretized model 
Gd = c2d(Gp,Ts);
Ap = Gd.Denominator{1};
Bp = Gd.Numerator{1};
dp = Gd.OutputDelay;
Gd = tf(Bp,Ap,Ts,'variable','q^-1','IODelay',dp);
stepMd = step(Gd,T);

figure()
hold on;
plot(T,stepM);stairs(T,stepMd);title('Pitch')

% store
Gpd = Gd;
save([store_path file_Gds], 'Gpd');

%*************************** ROLL ****************************************%
stepM = step(Gr,T);

% discretized model 
Gd = c2d(Gr,Ts);
Ar = Gd.Denominator{1};
Br = Gd.Numerator{1};
dr = Gd.OutputDelay;
Gd = tf(Br,Ar,Ts,'variable','q^-1','IODelay',dr);
stepMd = step(Gd,T);

figure(); 
hold on;
plot(T,stepM);stairs(T,stepMd);title('Roll')

% store
Grd = Gd;
save([store_path file_Gds], 'Grd','-append');

% %*************************** YAW ****************************************%
stepM = step(Gy,T);

% discretized model 
Gd = c2d(Gy,Ts);
Ay = Gd.Denominator{1};
By = Gd.Numerator{1};
dy = Gd.OutputDelay;
Gd = tf(By,Ay,Ts,'variable','q^-1','IODelay',dy);
stepMd = step(Gd,T);
Gyd = Gd;

figure(); 
hold on;
plot(T,stepM);stairs(T,stepMd);title('Yaw')

% store
Gyd = c2d(Gy,Ts);
save([store_path file_Gds], 'Gyd','-append');
%% RST design
close all;clc
%*************************** PITCH ***************************************%
% desired poles
wn_pd = 2*sqrt(Gp.Denominator{1}(end));   % twice OL
xsi = 0.7;                                % increase damping
p1 = -2*exp(-xsi*wn_pd*Ts)*cos(wn_pd*Ts*sqrt(1-xsi^2));
p2 = exp(-2*xsi*wn_pd*Ts);
P = [1 p1 p2];
rootsP = roots(P)

% additionnal terms
Hs = [1 -1];
Hr = [1 1];

% get Pmax
[~, ~, ~, Pmax] = f.generateRST(Ap,Bp,dp,P,Hr,Hs);

% add auxiliary poles
alpha = -0.1;
while length(P)<=Pmax
    Pf = [1 alpha];
    P = conv(P,Pf);
%     alpha = alpha+0.05;
end
Pp = P;

% get coeffs
[R0,S0] = f.generateRST(Ap,Bp,dp,P,Hr,Hs);

%% perform Q parametrization
clc;
nq = 20;
Q0 = ones(1,nq);
Mm = 0.5;
Uinf = 30;

dp = 0;
options = optimoptions('fmincon','MaxFunctionEvaluation',5e+3);

Qopt = fmincon(@(Q)objFun(Ap,Bp,dp,R0,S0,P,Hr,Hs,Q,Ts),Q0,...
    [],[],[],[],[],[],...
    @(Q)normConstr(Ap,Bp,dp,R0,S0,P,Hs,Hr,Q,Uinf,Mm,Ts),options);

% retrieve final Rcf,Scf,Tcf
[Rf,Sf,Tf] = f.generateRSTQp(Ap,Bp,dp,R0,S0,P,Hr,Hs,Qopt);
qpPitch = {Rf,Sf,Tf};

% store
save([store_path file_Ks],'qpPitch');
% export to myRIO
pitchSolo = f.labviewRST(Rf,Sf,Tf,'solo');
f.writeBin(ctrl_path,ctrl_name{1},f.labviewRST(pitchSolo,OL,OL,'trio'));

f.simulationQpPlot(Ap,Bp,dp,Rf,Sf,Tf,P,Ts,Uinf,Mm)
 %%
%*************************** ROLL ***************************************%
% desired poles
wn_rd = 2*sqrt(Gr.Denominator{1}(end));  % twice OL
xsi = 0.7;                               % increase damping
p1 = -2*exp(-xsi*wn_rd*Ts)*cos(wn_rd*Ts*sqrt(1-xsi^2));
p2 = exp(-2*xsi*wn_rd*Ts);
P = [1 p1 p2];
rootsR = roots(P)

% additionnal terms
Hs = [1 -1];
Hr = [1 1];

% get Pmax
[~, ~, ~, Pmax] = f.generateRST(Ar,Br,dr,P,Hr,Hs);

% add auxiliary poles
alpha = -0.1;
Pf = [1 alpha];

while length(P)<=Pmax
    P = conv(P,Pf);
end
Pr = P;

% get coeffs
[R0,S0,T0] = f.generateRST(Ar,Br,dr,P,Hr,Hs);
stabRoll = {R0,S0,T0};

%% perform Q parametrization
clc;
nq = 15;
Q0 = ones(1,nq);
Mm = 0.5;
Uinf = 25;

dr = 8;
options = optimoptions('fmincon','MaxFunctionEvaluation',5e+3);

Qopt = fmincon(@(Q)objFun(Ar,Br,dr,R0,S0,P,Hr,Hs,Q,Ts),Q0,...
    [],[],[],[],[],[],...
    @(Q)normConstr(Ar,Br,dr,R0,S0,P,Hs,Hr,Q,Uinf,Mm,Ts),options);

% retrieve final Rcf,Scf,Tcf
[Rf,Sf,Tf] = f.generateRSTQp(Ar,Br,dr,R0,S0,P,Hr,Hs,Qopt);
qpRoll = {Rf,Sf,Tf};

% store
save([store_path file_Ks],'qpRoll','-append');
% export to myRIO
rollSolo = f.labviewRST(Rf,Sf,Tf,'solo');
f.writeBin(ctrl_path,ctrl_name{2},f.labviewRST(OL,rollSolo,OL,'trio'));

f.simulationQpPlot(Ar,Br,dr,Rf,Sf,Tf,P,Ts,Uinf,Mm)
%%
%***************************** YAW ***************************************%
% desired poles
wn_ry = sqrt(Gp.Denominator{1}(end));   % same as pitch
xsi = 0.7;                              % increase damping
p1 = -2*exp(-xsi*wn_ry*Ts)*cos(wn_ry*Ts*sqrt(1-xsi^2));
p2 = exp(-2*xsi*wn_ry*Ts);
P = [1 p1 p2];
% rootsR = roots(P)
% p1 = -0.995;    % as slow as possible to not saturate output
% P = [1 p1];

% additionnal terms
Hs = [1 -1];
Hr = [1 1];

% get Pmax
[~, ~, ~, Pmax] = f.generateRST(Ay,By,dy,P,Hr,Hs);

% add auxiliary poles
alpha = -0.7;
% alpha = -0.5;
Pf = [1 alpha];

while length(P)<=Pmax
    P = conv(P,Pf);
end
Py = P;

% get coeffs
[R0,S0,T0] = f.generateRST(Ay,By,dy,P,Hr,Hs);
stabYaw = {R0,S0,T0};
%% perform Q parametrization
clc;
nq = 30;
Q0 = ones(1,nq);
Mm = 0.5;
Uinf = 30;

dy = 0;
options = optimoptions('fmincon','MaxFunctionEvaluation',5e+3);

Qopt = fmincon(@(Q)objFun(Ay,By,dy,R0,S0,P,Hr,Hs,Q,Ts),Q0,...
    [],[],[],[],[],[],...
    @(Q)normConstr(Ay,By,dy,R0,S0,P,Hs,Hr,Q,Uinf,Mm,Ts),options);

% retrieve final Rcf,Scf,Tcf
[Rf,Sf,Tf] = f.generateRSTQp(Ay,By,dy,R0,S0,P,Hr,Hs,Qopt);
qpYaw = {Rf,Sf,Tf};

% store
save([store_path file_Ks],'qpYaw','-append');
% export to myRIO
yawSolo = f.labviewRST(Rf,Sf,Tf,'solo');
f.writeBin(ctrl_path,ctrl_name{3},f.labviewRST(OL,OL,yawSolo,'trio'));

f.simulationQpPlot(Ay,By,dy,Rf,Sf,Tf,P,Ts,Uinf,Mm)

f.writeBin(ctrl_path,ctrl_name{4},f.labviewRST(pitchSolo,rollSolo,yawSolo,'trio'));

%% Functions used for Q-parametrization
function [cost] = objFun(A,B,d,R0,S0,P,Hr,Hs,Q,Ts)

    Rq = f.generateRSTQp(A,B,d,R0,S0,P,Hr,Hs,Q);
   
% Cost function that minimizes the norm of U(jw)
    U = tf(conv(A, Rq), P,  Ts, 'variable', 'z^-1');
    % min |U(jw)|2
    cost = norm(U);
end


function [con1, con2] = normConstr(A,B,d,R0,S0,P,Hr,Hs,Q,Uinf,Mm,Ts)

    [Rq,Sq] = f.generateRSTQp(A,B,d,R0,S0,P,Hr,Hs,Q);
    
% Function that returns constraints on modulus margin and Infinite norm of U(jw)
    S = tf(conv(A, Sq), P,  Ts, 'variable', 'z^-1');
    U = tf(conv(A, Rq), P,  Ts, 'variable', 'z^-1');
    % |Mm*S(jw)| < 1
    con1 = norm(Mm*S, 'Inf') - 1;
    % |U(jw)| < U_UB
    con2 = norm(U, 'Inf') - Uinf;
end

