function [accuracy, mismatches, message] = compare_notes(file1_fullpath, file2_fullpath)

    % עיבוד הקובץ הראשון (מקורי)
    analyze_single(file1_fullpath);
    [~, name1, ~] = fileparts(file1_fullpath);
    json1_path = fullfile('uploads', [char(name1) '_precise_notes.json']);
    if ~isfile(json1_path)
        accuracy = 0.0;
        mismatches = {};
        message = "No notes found in the original song.";
        return;
    end

    % עיבוד הקובץ השני (הביצוע)
    analyze_single(file2_fullpath);
    [~, name2, ~] = fileparts(file2_fullpath);
    json2_path = fullfile('uploads', [char(name2) '_precise_notes.json']);
    if ~isfile(json2_path)
        accuracy = 0.0;
        mismatches = {};
        message = "No notes found in the recording.";
        return;
    end

    % קריאת JSON
    json1_all = jsondecode(fileread(json1_path));
    json2_all = jsondecode(fileread(json2_path));

    if isempty(json1_all)
    accuracy = 0.0;
    mismatches = {};
    message = "The original melody is empty or malformed.";
    return;
end

if isempty(json2_all)
    accuracy = 0.0;
    mismatches = {};
    message = "The recording melody is empty or malformed.";
    return;
end

    % ניגש לאיבר הראשון (בהנחה שהוא מייצג את הרצף הרלוונטי)
    json1 = json1_all(1);
    json2 = json2_all(1);

    if ~isfield(json1, 'notes') || isempty(json1.notes)
        accuracy = 0.0;
        mismatches = {};
        message = "No notes found in the original song.";
        return;
    end

    if ~isfield(json2, 'notes') || isempty(json2.notes)
        accuracy = 0.0;
        mismatches = {};
        message = "No notes found in the recording.";
        return;
    end

    % חילוץ רצפי התווים
    notes1 = {json1.notes.note};
    notes2 = {json2.notes.note};

    fprintf('\n🎼 Notes from the original file:\n');
    disp(notes1);

    fprintf('\n🎼 Notes from the performed file:\n');
    disp(notes2);

    % השוואה פשוטה של הרצפים
    minLen = min(length(notes1), length(notes2));
    matches = 0;
    mismatches = {};

    for i = 1:minLen
        if strcmp(notes1{i}, notes2{i})
            matches = matches + 1;
        else
            mismatches{end+1} = struct( ...
                'Index', i, ...
                'Expected', notes1{i}, ...
                'Played', notes2{i});
        end
    end

    accuracy = matches / minLen * 100;
    message = "";

    fprintf('\n🔍 Note comparison results:\n');
    fprintf('Total notes compared: %d\n', minLen);
    fprintf('Matching notes: %d\n', matches);
    fprintf('Accuracy: %.2f%%\n', accuracy);

    if ~isempty(mismatches)
        fprintf('\n❌ Mismatches:\n');
        for i = 1:length(mismatches)
            m = mismatches{i};
            fprintf('At note #%d: expected %s but played %s\n', m.Index, m.Expected, m.Played);
        end
    else
        fprintf('\n✅ All notes matched!\n');
    end

end
