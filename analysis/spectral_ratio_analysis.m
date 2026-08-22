%% compare loc stats across files
root_folder = 'D:\Tim\TF001\splitting_ratio_eval';
data = {};
% AF647 files
filelist = dir(fullfile(strcat(root_folder, '\af647') , '*.mat'));
for d = 1:length(filelist)
    temp = load(fullfile(filelist(d).folder, filelist(d).name));
    data.af647.raw(d) = temp.saveloc.loc;
end
% CF660 files
filelist = dir(fullfile(strcat(root_folder, '\cf660') , '*.mat'));
for d = 1:length(filelist)
    temp = load(fullfile(filelist(d).folder, filelist(d).name));
    data.cf660.raw(d) = temp.saveloc.loc;
end
% CF680 files
filelist = dir(fullfile(strcat(root_folder, '\cf680') , '*.mat'));
for d = 1:length(filelist)
    temp = load(fullfile(filelist(d).folder, filelist(d).name));
    data.cf680.raw(d) = temp.saveloc.loc;
end

%% grab ratios and display histogram
fn = fieldnames(data);

for k=1:numel(fn)
    temp = cat(1, data.(fn{k}).raw(:).ratio);
    temp=temp(temp ~= inf);
    data.(fn{k}).ratio =temp;

    temp=temp(temp >0);
    temp=temp(temp <=1);
    data.(fn{k}).ratio_filter =temp;

end 


% %% histogram
% f1=figure(1);
% hold on
% for k=1:numel(fn)
% 
%     histogram(data.(fn{k}).ratio);
% end 
% hold off
% xlabel('ratio');
% ylabel('N_{ratio}');
% legend(fn);
% hold off

%% histogram filtered
f2=figure(2);
hold on
for k=1:numel(fn)
    histogram(data.(fn{k}).ratio_filter, 100);
end 
xlabel('ratio');
ylabel('N_{ratio}');
xlim([0.01, 1.0]);
legend(fn);
hold off
set(f2,'Position',[100 100 700 500]);



%% histogram filtered normalised 
f3=figure(3);
hold on
for k=1:numel(fn)
    histogram(data.(fn{k}).ratio_filter, 100, 'Normalization','pdf');
end 
xlabel('ratio');
ylabel('N_{ratio}');
xlim([0.01, 1.0]);
legend(fn);
hold off
set(f3,'Position',[100 100 700 500]);
