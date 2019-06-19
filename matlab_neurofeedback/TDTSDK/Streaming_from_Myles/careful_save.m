function file_name = careful_save (save_dir,session_file_name)

if save_dir(end) ~= '\'
    save_dir = [save_dir '\'];
end
file_name_1 = [save_dir session_file_name '.mat'];
if exist(file_name_1, 'file')
    careful = 1;
    n_temp = 2;
    while careful
        file_name_2 = [file_name_1(1:end-4) '_' num2str(n_temp) '.mat'];
        if exist(file_name_2, 'file')
            n_temp = n_temp+1;
        else
            careful = 0;
            file_name = file_name_2; 
        end
    end
else
    file_name = file_name_1;
end
