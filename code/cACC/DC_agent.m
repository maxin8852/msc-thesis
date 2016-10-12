
classdef DC_agent < handle
    
    properties
        Obj;            % objective function
        dc;             % dc model
        wind;           % wind realizations
        C_0;            % set of initial deterministic constraints
        C_1_params;     % array with params of initial constraints
        A;              % array with params of active constraints
        L;              % set of constraints for the next iteration
        J;              % value of the objective function
        Jtilde;         % max_var of neigbouring objectives
        x_var;          % sdpvars of the decision variable
        x;              % matrix with values of x at each iteration on cols
        z;              % matrix with all incoming x`s on cols
        t;              % iteration number
        t_wind;         % wind time step
    end
    
    methods
        
        function ag = DC_agent(dc, wind, t_wind, i_start, i_end)
        % creates constraint set and objective function
            
            % INITIALIZE SDPVARS
            ag.x_var = sdpvar(5*dc.N_G, 1, 'full'); % P_G Rus Rds dus dds
            
            % create objective function
            ag.Obj = DC_f_obj(ag.x_var, dc, wind, t_wind);

            % create deterministic constraints
            ag.C_0 = DC_f_0(ag.x_var, dc, wind, t_wind);
            
            % loop over scenarios to create scenario constraints
            C_ineqs = [];
            ag.C_1_params = [];
            
            for i = i_start:i_end                    
                % inequality constraints
                [C_ineq, C_params] = DC_f_ineq(ag.x_var, i, dc, wind, t_wind);
                C_ineqs = [C_ineqs, C_ineq];
                
                % store params to inequality constraints
                ag.C_1_params = [ag.C_1_params; C_params];

            end
            
            ag.wind = wind;
            ag.dc = dc;
            ag.t_wind = t_wind;
        
            % optimize
            opt = sdpsettings('verbose', 0);
            optimize([ag.C_0, C_ineqs], ag.Obj, opt);

            % store value of objective function
            ag.J(1) = value(ag.Obj);
            ag.x(:, 1) = value(ag.x_var);
            ag.Jtilde = -1e9;
            
            % store params of active constraints
            ag.A{1} = ag.C_1_params(Ac(C_ineqs), :);

            % set t to 1
            ag.t = 1;
            
            % init L
            ag.L = [];

        end
        
        function build(ag, A_incoming, J_incoming, x_incoming)
        % builds L(t+1) and tilde J(t+1) agent by agent
            
            % add incoming A to the L(t+1)
            ag.L = [ag.L; A_incoming];
            
            % take maximum of current J(t+1) and incoming J
            ag.Jtilde = max(ag.Jtilde, J_incoming);
            
            % add the incoming values of x to z
            ag.z = [ag.z x_incoming];
        
        end
        
        function update(ag)
        % optimize, update active constraint and objective function 
        
            % check feasibility neighbours
            if isinf(ag.Jtilde)
                ag.A{ag.t + 1} = [];
                ag.J{ag.t + 1} = Inf;
                ag.L = [];
            else

                % add own last active constraints and initial constraints
                ag.L = unique([ag.L; ag.C_1_params; ag.A{ag.t}], 'rows');

                % build constraints from L
                C_L = [];
                for params = ag.L'
                    
                    % extract params
                    i = params(1);
                    j = params(2);
                    
                    % add constraints to set C_L
                    C_L = [C_L, ...
                           DC_f_ineq(ag.x_var, i, ag.dc, ag.wind, ag.t_wind, j)];
                end
                
                % average incoming x`s to form consensus variable
                Z = mean(ag.z, 2);

                % add consensus term to objective
                obj_consensus = ag.Obj + ...
                                    1/(2*(ag.t+1)) * norm(Z-ag.x_var);

                
                % check if current value for x is infeasible for the new 
                % constraints
                if any(check(C_L) < -1e-6) || any(isnan(check(C_L)))
                    
                    % if infeasible with new constraints, optimize again
                    opt = sdpsettings('verbose', 0);
                    optimize([ag.C_0, C_L], obj_consensus, opt);
                end                
                
                % update A
                ag.A{ag.t + 1} = ag.L(Ac(C_L), :);

                % update J
                ag.J(ag.t + 1) = value(obj_consensus);
                
                % update x
                ag.x(:, ag.t+1) = value(ag.x_var);

                % update iteration number
                ag.t = ag.t + 1;

                % reset L
                ag.L = [];
            end
        end
        
    end
end