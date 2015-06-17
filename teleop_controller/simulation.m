clear all

%% Choose controller scheme

% set_position_position_controller
% set_position_force_controller
% set_force_position_controller
set_force_force_controller


master_controller = @(x_m, xd_m, xdd_m, f_m, x_s, xd_s, xdd_s, f_s) ((K_mpm * x_m + K_mpm_d * xd_m + K_mpm_dd * xdd_m + K_mfm * f_m) - ...
        (K_mps * x_s + K_mps_d * xd_s + K_mps_dd * xdd_s + K_mfs * f_s));
slave_controller = @(x_m, xd_m, xdd_m, f_m, x_s, xd_s, xdd_s, f_s) ((K_spm * x_m + K_spm_d * xd_m + K_spm_dd * xdd_m + K_sfm * f_m) - ...
        (K_sps * x_s + K_sps_d * xd_s + K_sps_dd * xdd_s + K_sfs * f_s));

%% operator input function
input_force = @(t) ( 5-5*cos(4*pi*t));
% input_force = @(t) ( 5-5*cos(1*pi*t));
% input_force = @(t) (1);

%% init simulation
dt = 0.001;
comm_delay = 200; % 100 dt steps
sim_time = 10;
t = linspace(0, sim_time, sim_time/dt);

x_m_log = zeros(size(t));
x_s_log = zeros(size(t));
f_m_log = zeros(size(t));
f_s_log = zeros(size(t));

%% initial condition
x_m_delayed = 0;
xd_m_delayed = 0;
xdd_m_delayed = 0;
f_m_delayed = 0;
x_s_delayed = 0;
xd_s_delayed = 0;
xdd_s_delayed = 0;
f_s_delayed = 0;


%% simulation start
tau_op = input_force(t(1));
[x_m, xd_m, xdd_m, f_m] = master_simulation(x_s_delayed, xd_s_delayed, xdd_s_delayed, f_s_delayed,...
    tau_op, dt, master_controller);
[x_s, xd_s, xdd_s, f_s] = slave_simulation(x_m_delayed, xd_m_delayed, xdd_m_delayed, f_m_delayed,...
    dt, slave_controller);

buffer_master_to_slave = [x_m, xd_m, xdd_m, f_m];
buffer_slave_to_master = [x_s, xd_s, xdd_s, f_s];

for i = 2:length(t)
    if size(buffer_master_to_slave,1) > comm_delay
        from_master = buffer_master_to_slave(1,:);
        buffer_master_to_slave = buffer_master_to_slave(2:end,:);
        x_m_delayed = from_master(1);
        xd_m_delayed = from_master(2);
        xdd_m_delayed = from_master(3);
        f_m_delayed = from_master(4);
    end
    if size(buffer_slave_to_master,1) > comm_delay
        from_slave = buffer_slave_to_master(1,:);
        buffer_slave_to_master = buffer_slave_to_master(2:end,:);
        x_s_delayed = from_slave(1);
        xd_s_delayed = from_slave(2);
        xdd_s_delayed = from_slave(3);
        f_s_delayed = from_slave(4);
    end
    
    tau_op = input_force(t(i));
    [x_m, xd_m, xdd_m, f_m] = master_simulation(x_s_delayed, xd_s_delayed, xdd_s_delayed, f_s_delayed, ...
        tau_op, dt, master_controller);
    [x_s, xd_s, xdd_s, f_s] = slave_simulation(x_m_delayed, xd_m_delayed, xdd_m_delayed, f_m_delayed,...
        dt, slave_controller); 
    
    buffer_master_to_slave(end+1, :) = [x_m, xd_m, xdd_m, f_m];
    buffer_slave_to_master(end+1, :) = [x_s, xd_s, xdd_s, f_s];
    
    % logging
    x_m_log(i) = x_m;
    x_s_log(i) = x_s;
    f_m_log(i) = f_m;
    f_s_log(i) = f_s;
end

%% plotting
figure(1);
subplot(1,2,1);
plot(t, x_m_log, 'r--','linewidth',2);
hold on; grid on;
plot(t, x_s_log, 'b','linewidth',2);
hold off;
xlabel('t(sec)','fontsize',15); ylabel('position(m)','fontsize',15)
legend('master', 'slave');
title(strcat(controller_type.name,'(position response)'),'fontsize',20);


subplot(1,2,2);
plot(t, f_m_log, 'r--','linewidth',2);
hold on; grid on;
plot(t, f_s_log, 'b','linewidth',2);
hold off;
xlabel('t(sec)','fontsize',15); ylabel('force(N)','fontsize',15)
legend('master', 'slave');
title(strcat(controller_type.name,'(force response)'),'fontsize',20);

