clear all 
close all
clc
path(path,'C:\GAMS\win64\24.2')
clear gamso;
 load Spot2013
 load Imbalance2013
 load Profiles2012
 load Scenarios

 
%{
------------------------------------------------------------------
P_g= price electricity grid (spotprice)
P_c= price electricity consumption
P_i= price electricity imbalance
P_n= price natural gas
P_st= price startup

E_i0= electricity demand imbalance
E_b= electricity demand bidding

Q_H= heat demand house

Nb= thermal efficiency boiler
Ns= thermal efficiency storage
Ae= electrical efficiency CHP
Aq= thermal efficiency CHP

Pi_s= probability scenario

Ecap_lo= minimal electric energy supply CHP
Ecap_up= maximal electric energy supply CHP

Qcap_up= maximal thermal energy supply boiler

Cs= storage tank capacity
Cu= maximum number of CHP's
S= number of scenario's

x1= Heat output from the CHP 
X2= Auxiliary boiler output 
qst=Level of the heat storage tank 
qstout= Output of the heat storage 
%}


%---------------------------------------------
%% VARIABLES

%-----------------------------------
%LOADING VARIABLES 
%Input variables
%-----------------------------------

%Input constants
%---------------

Ae0 = 0.4; % CHP electrical efficiency
Aq0 = 0.45; % CHP thermal efficiency
Nb0 = 0.98; % Boiler thermal efficiency
Ns0 = 0.998; % Storage heat efficiency

Cu_sh = 2; % shown chp
S_sh = 3; % shown scenario

%Input time (i)
%--------------

%General
week = 3; % week of the year

quarters = 4; % quarters per hour
hours = 24; % hours per day
days_w = 7; % days per week
days_y = 365; % days per year

timestep = 1/quarters; % [hours] 15 minutes

sample_h = 2*24; % [hours] sample duration
sample_q = sample_h * quarters; % [quarters] sample duration

period_h = week * days_w * hours; % [hours] period of the year
period_q = period_h * quarters; % [quarters] period of the year

%Postprocessing
time_i = (1:sample_q)'; % time index vector sample
time_q = time_i/quarters; % [quarters] time vector sample

sample_i = [1:sample_q] + period_q; % sample period index

total_q=period_q+(sample_q-1); % [quarters] period before and during sample period

%Input scenarios (s)
%-------------------

S = size(Error,2);
% Imbalance
imbal_y = repmat(Error*100,days_y,1);
imbal_s = imbal_y(sample_i,:);

Pi_st = Prob';

%Input price
%-----------

% All input prices are for November 2013 unless stated otherwise

% Gas
gasPrice = 0.040/2; % [�/kWh] gas price (http://epp.eurostat.ec.europa.eu/statistics_explained/index.php/Electricity_and_natural_gas_price_statistics;http://appsso.eurostat.ec.europa.eu/nui/show.do?dataset=nrg_pc_204&lang=en;http://appsso.eurostat.ec.europa.eu/nui/show.do?dataset=nrg_pc_205&lang=en;http://appsso.eurostat.ec.europa.eu/nui/show.do?dataset=nrg_pc_202&lang=en;http://appsso.eurostat.ec.europa.eu/nui/show.do?dataset=nrg_pc_203&lang=en)
price_gas_y = gasPrice*ones(days_y*hours*quarters,1); % [�/kWh] gas price during the year
price_gas_s = price_gas_y(sample_i); % [�/kWh] gas price during the sample duration

% Consumption
price_elecC_d = reshape(repmat([0.15 0.15 0.15 0.15 0.15 0.15 0.15 0.22 0.22 0.22 0.22 0.22 0.22 0.22 0.22 0.22 0.22 0.22 0.22 0.22 0.22 0.22 0.15 0.15],quarters,1),hours*quarters,1); % [�/kWh] electricity price (day/night, one day)
price_elecC_y = repmat(price_elecC_d, days_y, 1); % [�/kWh] consumption electricity price during the year
price_elecC_s = price_elecC_y(sample_i); % [�/kWh] consumption electricity price during the sample duration

% Grid (spotprice)
price_elecS_y = reshape(repmat(spot/1000,quarters,1),days_y*hours*quarters,1); % [�/kWh] spot electricity price during the year
price_elecS_s = price_elecS_y(sample_i); % [�/kWh] spot electricity price during the sample duration

% Imbalance
price_imbal_y = repmat(price_elecS_y*2,1,S); % [�/kWh] imbalance electricity price during the year
price_imbal_s = price_imbal_y(sample_i,S); % [�/kWh] imbalance electricity price during the sample duration

% Input CHP's
%------------

Cs0 = 1000; % [kWh] Storage tank capacity

Cu = 6; % Maximum amount of CHP's

amount = zeros(Cu,200);
thermalload = zeros(Cu,200);

[amount(1,:), thermalload(1,:)] = hist(mhouse1h,200);
[amount(2,:), thermalload(2,:)] = hist(mhouse2h,200);
[amount(3,:), thermalload(3,:)] = hist(mhouse3h,200);
[amount(4,:), thermalload(4,:)] = hist(mhouse4h,200);
[amount(5,:), thermalload(5,:)] = hist(mhouse5h,200);
[amount(6,:), thermalload(6,:)] = hist(mhouse6h,200);

duration = cumsum(flipud(amount'),1);
thermalload = flipud(thermalload');

duration_opt = zeros(Cu,1);
thermalload_opt = zeros(Cu,1);

for k=1:Cu
    loadsquares = duration(:,k).*thermalload(:,k);
    square_max = max(loadsquares);
    j = find(loadsquares==square_max);
    duration_opt(k) = duration(j,k);
    thermalload_opt(k) = thermalload(j,k);
end

figure(1)
hold on
p1=plot(duration(:,Cu_sh),thermalload(:,Cu_sh));
h2=rectangle('Position',[0,0,duration_opt(Cu_sh),thermalload_opt(Cu_sh)]);
p2=plot(nan,nan,'s','markeredgecolor',get(h2,'edgecolor'));
legend([p1,p2],'Thermal load','Largest rectangle');
title(['Heat-load duration diagram for unit ',num2str(Cu_sh)]);
xlabel('Load duration [h]');
ylabel('Thermal load [kWt]');

%Input heat demand
%-----------------

heatD_y = [ reshape(repmat(mhouse1h',quarters,1),days_y*hours*quarters,1),...
            reshape(repmat(mhouse2h',quarters,1),days_y*hours*quarters,1),...
            reshape(repmat(mhouse3h',quarters,1),days_y*hours*quarters,1),...
            reshape(repmat(mhouse4h',quarters,1),days_y*hours*quarters,1),...
            reshape(repmat(mhouse5h',quarters,1),days_y*hours*quarters,1),...
            reshape(repmat(mhouse6h',quarters,1),days_y*hours*quarters,1)]; % [kWh] heat demand during the year
        
heatD_s = heatD_y(sample_i,:); % [kWh] heat demand during the sample duration
            
tank_cap = 2*[max(heatD_y,[],1)]; % [kWh] Storage tank capacity

%Input energy demand
%-------------------

% House electricity demand
energy_y = reshape(repmat(mhouse1e+mhouse2e+mhouse3e,quarters,1),days_y*hours*quarters,1);
energy_s = energy_y(sample_i);

% Capacity restrictions
Ecap_upVar = 1/quarters*thermalload_opt/Aq0*Ae0;
Ecap_loVar = 0.5*Ecap_upVar;
Qcap_upVar = max(heatD_y,[],1)';

%-----------------------------------
%INITIALIZATION 
%Input variables in structure form 
%-----------------------------------

%Input sets
%----------

i.name='i'; %Time
%final.val= 1:15;
i.uels = {{1:sample_q}};             
i.type ='set';

n.name='n'; %Unit
%unit.val= 1:15;
n.uels = {{1:Cu}};             
n.type ='set';

s.name='s'; %Scenario
%unit.val= 1:15;
s.uels = {{1:S}};             
s.type ='set';

%Input parameters
%----------------

P_g.name='P_g'; %price electricity grid (spotprice)
P_g.val=price_elecS_s; % [�/kWh]
P_g.form = 'full';
P_g.type = 'parameter';
P_g.dim =1;

P_c.name='P_c'; %price electricity consumption
P_c.val= price_elecC_s; % Constant price
P_c.form = 'full';
P_c.type = 'parameter';
P_c.dim =1;

P_i.name='P_i'; %price electricity imbalance
P_i.val= price_imbal_s;
P_i.form = 'full';
P_i.type = 'parameter';
P_i.dim =1;

P_n.name='P_n'; %price natural gas
P_n.val=price_gas_s;
P_n.form = 'full';
P_n.type = 'parameter';
P_n.dim =1;

P_st.name='P_st'; %price startup
P_st.val=100*ones(Cu,1);
P_st.form = 'full';
P_st.type = 'parameter';
P_st.dim =1;


E_i0.name='E_i0'; %electricity demand imbalance
E_i0.val=imbal_s;
E_i0.form = 'full';
E_i0.type = 'parameter';
E_i0.dim =2;

E_i1.name='E_i1'; %electricity demand imbalance
E_i1.val=sign(imbal_s);
E_i1.form = 'full';
E_i1.type = 'parameter';
E_i1.dim =2;

Q_H.name='Q_H'; %heat demand house
Q_H.val=heatD_s;
Q_H.form = 'full';
Q_H.type = 'parameter';
Q_H.dim =2;


Nb.name='Nb'; %thermal efficiency boiler
Nb.val=Nb0*ones(Cu,1);
Nb.form = 'full';
Nb.type = 'parameter';
Nb.dim =1;

Ns.name='Ns'; %thermal efficiency storage
Ns.val=Ns0*ones(Cu,1);
Ns.form = 'full';
Ns.type = 'parameter';
Ns.dim =1;

Ae.name='Ae'; %electrical efficiency CHP
Ae.val=Ae0*ones(Cu,1);
Ae.form = 'full';
Ae.type = 'parameter';
Ae.dim =1;

Aq.name='Aq'; %thermal efficiency CHP
Aq.val=Aq0*ones(Cu,1);
Aq.form = 'full';
Aq.type = 'parameter';
Aq.dim =1;

Pi_s.name='Pi_s'; %probability scenario
Pi_s.val=Pi_st;
Pi_s.form = 'full';
Pi_s.type = 'parameter';
Pi_s.dim =1;

Ecap_lo.name='Ecap_lo'; %minimal electric energy supply CHP
Ecap_lo.val=Ecap_loVar;
Ecap_lo.form = 'full';
Ecap_lo.type = 'parameter';
Ecap_lo.dim =1;

Ecap_up.name='Ecap_up'; %maximal electric energy supply CHP
Ecap_up.val=Ecap_upVar;
Ecap_up.form = 'full';
Ecap_up.type = 'parameter';
Ecap_up.dim =1;

Qcap_up.name='Qcap_up'; %maximal thermal energy supply boiler
Qcap_up.val=Qcap_upVar;
Qcap_up.form = 'full';
Qcap_up.type = 'parameter';
Qcap_up.dim =1;

Cs.name='Cs'; %storage tank capacity
Cs.val=tank_cap;
Cs.form = 'full';
Cs.type = 'parameter';
Cs.dim =1;

dt.name='dt'; %delta t for the storage time period analyzed 0.25for 15 min
dt.val=1/quarters;
dt.type = 'parameter';
dt.dim=0;

% BUYst.name='BUYst'; %storage tank capacity
% BUYst.val=[ones(1,Cust) zeros(1,Cu-Cust)];
% BUYst.form = 'full';
% BUYst.type = 'parameter';
% BUYst.dim =1;

index=0;
indexp=0;
index_m=0;

%% CALL GAMS 

%-----------------------------------
%OPTIMIZATION
%Calls GAMS routine 
%-----------------------------------

% Calculate investment costs (optimal)
%-------------------------------------

o2 = 0;
down = 1;

% while true
%     BUYst.val=[ones(1,Cust) zeros(1,Cu-Cust)];
%     wgdx('inputs', i,n,s,P_g,P_c,P_i,P_n,P_st,E_i0,E_i1,Q_H,Nb,Ns,Ae,Aq,Pi_s,Ecap_lo,Ecap_up,Qcap_up,Cs,dt,BUYst);
%     path(path,'C:\GAMS\win64\24.2')
%     gams('CHP');%LOCAL PRICE IS TAKEN INTO ACCOUNT 
%     
%     rs.name = 'obj';
%     r = rgdx ('results', rs);
%     obj=r.val(:,1);
%     o1 = obj/Cust;
%     [obj Cust o1]
%     
%     o1
%     break;
%     
%     if o1 >= o2
%         o2 = o1;
%         if down == 1
%             Cust = Cust - 1;
%             if Cust == 0; break; end;
%         else
%             Cust = Cust + 1;
%             if Cust > Cu; break; end;
%         end
%     else
%         if down == 1
%             Cust = Cust + 2;
%             if Cust > Cu; break; end;
%             down = 0;
%         else
%             break;
%         end
%     end
% end

% Custopt = Cust;

% Calculate investment costs 
%---------------------------

% Optimal is of course one CHP. Every CHP you add will have a slightly
% higher investment cost (imbalance remaining is less and thus more
% expensive to compensate). This part of the code let you calculate a
% random case (you can select one from the output of the previous part).

Cust = Cu; % Custopt;

BUYst.val=[ones(1,Cust) zeros(1,Cu-Cust)];
    wgdx('inputs', i,n,s,P_g,P_c,P_i,P_n,P_st,E_i0,E_i1,Q_H,Nb,Ns,Ae,Aq,Pi_s,Ecap_lo,Ecap_up,Qcap_up,Cs,dt);

    gams('CHP');%LOCAL PRICE IS TAKEN INTO ACCOUNT 
    
    rs.name = 'obj';
    r = rgdx ('results', rs);
    obj=r.val(:,1);
    o1 = obj/Cust;
    [obj Cust o1]

%% RESULTS 

%-----------------------------------
%LOADING RESULTS
%Reading parameters
%-----------------------------------

% Objective
rs.name = 'obj';
r = rgdx ('results', rs);
obj=r.val(:,1); 

% Bidding revenue
rs.name = 'R_b';
r = rgdx ('results', rs);
R_b(time_i,1)=r.val(time_i,2);

% Imbalance reduction revenue
rs.name = 'R_ir';
r = rgdx ('results', rs);
R_ir(time_i,1)=r.val(time_i,2);

% Boiler and CHP fuelcost
rs.name = 'FC_bc';
r = rgdx ('results', rs);
FC_bc(time_i,1)=r.val(time_i,2);

% CHP fuelflow
rs.name = 'm_fCHP';
r = rgdx ('results', rs);
m_fCHP = zeros(sample_q,Cu,S);
for j=1:Cu
    for k=1:S
        m_fCHP(time_i,j,k)=r.val((time_i-1)*Cu*S+(j-1)*S+k,4);
    end
end

% Boiler fuelflow
rs.name = 'm_fB';
r = rgdx ('results', rs);
m_fB = zeros(sample_q,Cu,S);
for j=1:Cu
    for k=1:S
        m_fB(time_i,j,k)=r.val((time_i-1)*Cu*S+(j-1)*S+k,4);
    end
end

% CHP heat supply
rs.name = 'Q_CHP'; 
r = rgdx ('results', rs);
Q_CHP = zeros(sample_q,Cu,S);
for j=1:Cu
    for k=1:S
        Q_CHP(time_i,j,k)=r.val((time_i-1)*Cu*S+(j-1)*S+k,4);
    end
end

% Boiler heat supply
rs.name = 'Q_B';
r = rgdx ('results', rs);
Q_B = zeros(sample_q,Cu,S);
for j=1:Cu
    for k=1:S
        Q_B(time_i,j,k)=r.val((time_i-1)*Cu*S+(j-1)*S+k,4);
    end
end
 
% Storage heat supply
rs.name = 'DeltaQ_S';
r = rgdx ('results', rs); 
DeltaQ_S = zeros(sample_q,Cu,S);
for j=1:Cu
    for k=1:S
        DeltaQ_S(time_i,j,k)=r.val((time_i-1)*Cu*S+(j-1)*S+k,4);
    end
end

% Storage heat volume
rs.name = 'Q_S';
r = rgdx ('results', rs);
Q_S = zeros(sample_q,Cu,S);
for j=1:Cu
    for k=1:S
        Q_S(time_i,j,k)=r.val((time_i-1)*Cu*S+(j-1)*S+k,4);
    end
end

% CHP energy supply
rs.name = 'E_CHP';
r = rgdx ('results', rs);
E_CHP = zeros(sample_q,Cu,S);
for j=1:Cu
    for k=1:S
        E_CHP(time_i,j,k)=r.val((time_i-1)*Cu*S+(j-1)*S+k,4);
    end
end

% Imbalance reduction
rs.name = 'E_i';
r = rgdx ('results', rs);
E_i = zeros(sample_q,S);
for j=1:S
    E_i(time_i,j)=r.val((time_i-1)*S+j,3);
end

% Bidding price
rs.name = 'E_b';
r = rgdx ('results', rs);
E_b=r.val*ones(size(sample_i')); % Array to make it easier for plotting

rs.name = 'ON';
r = rgdx ('results', rs);
ON = zeros(sample_q,Cu,S);
for j=1:Cu
    for k=1:S
        ON(time_i,j,k)=r.val((time_i-1)*Cu*S+(j-1)*S+k,4);
    end
end

rs.name = 'BUY';
r = rgdx ('results', rs);
BUY=r.val(:,2);

%-----------------------------------
%POSTPROCESSING RESULTS
%Postproces data
%-----------------------------------

%R_b = E_b.*P_g.val;
%R_i = abs(E_i*Pi_s.val).*P_i.val;

profit = R_b + R_ir - FC_bc;

profit_t = sum(profit,1) % [�] total profit

%-----------------------------------
%SHOWING RESULTS
%Making figures
%-----------------------------------

figure(2)
plot(time_q,[E_i0.val(:,S_sh), E_b, E_i(:,S_sh)])
title(['Imbalance for scenario ',num2str(S_sh)]);
legend('Wind imbalance','Bidding','Imbalance reduction');

figure(3)
subplot(2,1,1)
plot(time_q,Q_S(:,:,S_sh))
title(['Storage for scenario ',num2str(S_sh), ' (all units)']);
subplot(2,1,2)
plot(time_q,DeltaQ_S(:,:,S_sh))
title(['Storage heat supply for scenario ',num2str(S_sh), ' (all units)']);

figure(4)
plot(time_q,[Q_S(:,Cu_sh,S_sh),DeltaQ_S(:,Cu_sh,S_sh)]);
legend('Storage','Storage heat supply');
title(['Storage unit ',num2str(Cu_sh),' for scenario ',num2str(S_sh)]);
xlabel('Time [h]');
ylabel('Heat [kWh]');

figure(5)
subplot(2,1,1)
plot(time_q,E_CHP(:,:,S_sh))
title(['CHP energy supply for scenario ',num2str(S_sh)]);
xlabel('Time [h]');
ylabel('Energy [kWh]');
subplot(2,1,2)
plot(time_q,Q_CHP(:,:,S_sh))
title(['CHP heat supply for scenario ',num2str(S_sh)]);
xlabel('Time [h]');
ylabel('Heat [kWh]');

figure(6)
plot(time_q,[Q_H.val(:,Cu_sh),Q_B(:,Cu_sh,S_sh),Q_CHP(:,Cu_sh,S_sh)])
legend('House heat demand','Boiler heat supply','CHP heat supply');
title(['Heating unit ',num2str(Cu_sh),' for scenario ',num2str(S_sh)]);
xlabel('Time [h]');
ylabel('Heat [kWh]');

figure(7)
plot(time_q,[sum(m_fB(:,:,S_sh),2),sum(m_fCHP(:,:,S_sh),2)])
legend('Total fuelflow Boilers','Total fuelflow CHPs');
title(['Total fuelflow for scenario ',num2str(S_sh)]);
xlabel('Time [h]');
ylabel('Fuelflow [kWh]');

figure(8)
plot(time_q,[E_i0.val(:,S_sh),E_CHP(:,Cu_sh,S_sh),E_b(:),E_i(:,S_sh)])
legend('Imbalance','CHP energy supply unit 1','Bidding','Total imbalance reduction');
title(['Energy unit ',num2str(Cu_sh),' for scenario ',num2str(S_sh)]);
xlabel('Time [h]');
ylabel('Energy [kWh]');

figure(9)
plot(time_q,[E_i0.val*Pi_s.val,permute(sum(E_CHP,2),[1 3 2])*Pi_s.val,E_b(:),E_i*Pi_s.val])
legend('Imbalance','CHP energy supply','Bidding','Imbalance reduction');
title(['Energy for scenario ',num2str(S_sh)]);
xlabel('Time [h]');
ylabel('Energy [kWh]');

figure(10)
plot(time_q,[FC_bc,R_b,R_ir,profit]);
legend('Fuel consumption cost','Bidding revenue','Imbalance reduction revenue','profit');
title('Total profit');
xlabel('Time [h]');
ylabel('Money [�]');

% figure(1)
% subplot(2,1,1);
% plot(i,d1,'c')
% hold on 
% plot(i,CHP_thermal1,'r')
% hold on 
% plot(i,boiler1,'g')
% hold on
% plot(i,charge1)
% xlabel('Time [h]')
% legend('House heat demand', 'CHP heat supply', 'Boiler heat supply', 'Storage heat supply')

% subplot(2,1,2);
% plot(i,-charge1)
% hold on 
% plot(i,qst1,'k--')
% xlabel('Time [h]')
% legend('Heatflow to storage', 'Storage')