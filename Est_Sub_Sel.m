function [smooth_gene_trajectories, gene_df, gene_ind] = Est_Sub_Sel(time_points, gene_expression, N, npool, plot_pool)

if nargin < 4, npool = 50;  end
if nargin < 5, plot_pool = 0;  end

%  ---------------Set up options for optimisation and cells  ---------------
options = optimset('LargeScale',  'off',  ...
                   'Display',     'off',   ...
                   'Diagnostics', 'off', ...
                   'GradObj',     'off',     ...
                   'Hessian',     'off',    ...               
                   'TolFun',      1e-8, ...
                   'TolX',        1e-8);

gexp3    = cell(N,1);
IQR    = cell(N,1);
SCR   = cell(N,1);
IND = cell(N,1);
lambda = cell(N,1);
df = cell(N,1);
gene_ind = cell(N,1);
gene_df = cell(N,1);
smooth_gene_trajectories = cell(N,1);
CROS  = cell(N,1);

for i = 1:N

    %  ---------------  set up the b-spline basis  ------------------------
    knots    = time_points';
    norder   = 3;
    nbasis   = length(time_points) + norder - 1;
    basisobj = create_bspline_basis([min(time_points) max(time_points)], nbasis, norder, knots);
    R        = eval_penalty(basisobj,2);
    
    sgenes = 1;
    %  --------------- Identify no. of crossings  ---------------
    CROS{i}  = zc(gene_expression);
    for k=1:4
        %  --------------- Obtain genes with k no of crossings  ---------------
        gexp3{i,k} = gene_expression(logical(CROS{i}==k),:);
        %  --------------- Get the IQR of the Genes with k no of corssings ---------------
        IQR{i}   = iqr(gexp3{i,k},2);
        %  --------------- Sort the Genes by IQR Largest-Smallest  ---------------
        [SCR{i},IND{i,k}] = sort(IQR{i},'descend');
        ngenes = length(IND{i,k});%min(50,length(IND{i}));
%          ngenes = min(50,length(IND{i,k}));
        pool_count = 0;
        for g=1:ngenes
            %  --------------- Obtain the lambda for the genes with k no of crossings  ---------------
            lambda{i,k,g} = fminbnd(@GCV_fun, 10.^-6, 10^6, options, eval_basis(time_points,basisobj), gexp3{i,k}(IND{i,k}(g),:)', R);
            %  --------------- Convert the lambda to the corresponding degrees of freedom  ---------------
            df{i,k,g}     = lambda2df(time_points, basisobj, ones(length(time_points),1),  2, lambda{i,k,g});
             %  --------------- If degrees of freedom are greater than no. of crossings  ---------------
              %  ---------------the gene is misclassified and does not belong to this crossing  ---------------
            if (df{i,k,g}>(k+1))
                gene_ind{i,k,pool_count+1} = IND{i,k}(g);
                gene_df{i,k,pool_count+1}  = df{i,k,g};
                pool_count = pool_count +1;
            else
                continue;
            end
            %  --------------- Only want at most npool genes in each crossing  ---------------
            if(pool_count == npool)
                break;
            end
        end
        %  --------------- Obtain the data for the sample  ---------------
        smooth_gene_trajectories{i}(sgenes:(sgenes+pool_count-1),:) = gexp3{i,k}(horzcat(gene_ind{i,k,:}),:);
        if(plot_pool == 1 && pool_count>0)
        figure(i);
        subplot(2,2,k)
        plot(smooth_gene_trajectories{i}(sgenes:(sgenes+pool_count-1),:)','--b')
        hold on;
        hline(0,'r');
        hold off;
        xlim([1,size(smooth_gene_trajectories{i}(sgenes:(sgenes+pool_count-1),:),2)])
        ylim([min(min(smooth_gene_trajectories{i}(sgenes:(sgenes+pool_count-1),:))),max(max(smooth_gene_trajectories{i}(sgenes:(sgenes+pool_count-1),:)))])
        title(['Subject ',num2str(i),' No. genes ',num2str(pool_count),' Max df ',num2str(max(horzcat(gene_df{i,k,:}))),' Min df ',num2str(min(horzcat(gene_df{i,k,:})))])
        end
        sgenes = sgenes + pool_count;
    end
    
end

end
