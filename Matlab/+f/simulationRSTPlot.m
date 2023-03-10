function simulationRSTPlot(A,B,d,Rcf,Scf,Tcf,P,Ts)
%UNTITLED6 Summary of this function goes here
%   Detailed explanation goes here
Tp = 0:Ts:10;

% output/ref : y/r = q^-d*B*T/P
YoR = tf(conv(Tcf,B),P,Ts,'variable','z^-1','IODelay',d);
stepT = step(YoR,Tp);

% input/ref : u/r = A*T/P
UoR = tf(conv(Tcf,A),P,Ts,'variable','z^-1','IODelay',d);
stepU = step(UoR,Tp);

% output/input disturbance : y/v = A*S/P
YoV = tf(conv(Scf,A),P,Ts,'variable','z^-1','IODelay',d);
stepS = step(YoV,Tp);

% input/ref : u/r = A*T/P
UoV = tf(conv(Rcf,A),P,Ts,'variable','z^-1','IODelay',d);
stepU = step(UoV,Tp);

figure()
subplot(2,2,1)
bodemag(YoR);title('YoR')
subplot(2,2,2)
bodemag(UoR);title('UoR')
subplot(2,2,3)
bodemag(YoV);title('YoV')
subplot(2,2,4)
bodemag(UoV);title('UoV')
end

