function parse_file = parse_metafiles(filename)
    raw = fileread(filename);
    %parse_file = regexp( raw , '\n', 'split'); if its not in json format
    parse_file = jsondecode(raw);
end 