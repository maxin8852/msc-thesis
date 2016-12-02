function Obj = DC_f(x, dc, wind)
% Obj = DC_f(x, dc, wind)
% returns the value of the objective function

    Obj = 0;
    N_t = size(wind.P_m, 1);
    
    % loop over time
    for t = 1:N_t
        % loop over generators and add generator cost at time t
        for k = 1:dc.N_G
            Obj = Obj + dc.c_qu(k) * (x(k, t))^2 + ...
                                    dc.c_li(k) * x(k, t);
        %       Obj = Obj + dc.c_us(k) * P_G(k);
        end

        % add reserve requirements costs
        Rus = 3*dc.N_G+1:4*dc.N_G;
        Rds = 4*dc.N_G+1:5*dc.N_G;
        Obj = Obj + (dc.c_us' * x(Rus, t) + dc.c_ds' * x(Rds, t));
    end
end