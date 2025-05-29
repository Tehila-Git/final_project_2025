function analyze_single_notes_precise(filePath)
    [folderPathOnly, name, ext] = fileparts(filePath);

    % Convert to WAV if needed
    if ~strcmpi(ext, '.wav')
        [audioData, sampleRate] = audioread(filePath);
        wavPath = fullfile(folderPathOnly, [name, '_converted.wav']);
        audiowrite(wavPath, audioData, sampleRate);
        filePath = wavPath;
        [folderPathOnly, name, ~] = fileparts(filePath);
    end

    % Read audio
    [audio, fs] = audioread(filePath);
    if size(audio, 2) > 1
        audio = mean(audio, 2); % Convert to mono
    end
    
    % Normalize but preserve dynamics
    max_val = max(abs(audio));
    if max_val > 0
        audio = audio / max_val;
    end
    
    %fprintf('🎹 Analyzing with advanced precise note detection...\n');
    
    % Multi-stage analysis
    detected_notes = detect_notes_precise(audio, fs);
    
    % Save results
    save_precise_results(detected_notes, folderPathOnly, name);
    
    %fprintf('✅ Precise note analysis completed!\n');
end
%%
function notes = detect_notes_precise(audio, fs)
    % הגדרות מתקדמות
    FRAME_SIZE = round(0.025 * fs);  % 25ms frames
    HOP_SIZE = round(0.01 * fs);    % 10ms hop (90% overlap)
    
    % שלב 1: זיהוי אנרגיה ופיץ' עבור כל פריים
    frames = create_frames(audio, FRAME_SIZE, HOP_SIZE);
    frame_data = analyze_frames(frames, fs);
    
    % שלב 2: זיהוי התחלות וסיומי תווים (onset/offset detection)
    events = detect_note_events(frame_data, fs, HOP_SIZE);
    
    % שלב 3: חלוקה לתווים נפרדים
    notes = segment_into_notes(events, frame_data);
    
    % שלב 4: ניקוי ומיון
    notes = clean_and_validate_notes(notes);
    
    fprintf('Detected %d note events\n', length(notes));
end
%%
function frames = create_frames(audio, frame_size, hop_size)
    num_frames = floor((length(audio) - frame_size) / hop_size) + 1;
    frames = zeros(frame_size, num_frames);
    
    for i = 1:num_frames
        start_idx = (i-1) * hop_size + 1;
        end_idx = start_idx + frame_size - 1;
        frames(:, i) = audio(start_idx:end_idx);
    end
end
%%
function frame_data = analyze_frames(frames, fs)
    [frame_size, num_frames] = size(frames);
    
    % הכנת מערכים לתוצאות
    energies = zeros(1, num_frames);
    frequencies = zeros(1, num_frames);
    spectral_centroid = zeros(1, num_frames);
    zero_crossing_rate = zeros(1, num_frames);
    spectral_rolloff = zeros(1, num_frames);
    
    % חישוב פיצ'רים לכל פריים
    for i = 1:num_frames
        frame = frames(:, i);
        
        % 1. אנרגיה
        energies(i) = sum(frame.^2) / frame_size;
        
        % 2. תדר דומיננטי משופר
        frequencies(i) = find_pitch_yin(frame, fs);
        
        % 3. Spectral Centroid
        spectral_centroid(i) = calculate_spectral_centroid(frame, fs);
        
        % 4. Zero Crossing Rate
        zero_crossing_rate(i) = calculate_zcr(frame);
        
        % 5. Spectral Rolloff
        spectral_rolloff(i) = calculate_spectral_rolloff(frame, fs);
    end
    
    % החלקה של האנרגיה
    energies = smooth_signal(energies, 3);
    
    frame_data = struct(...
        'energies', energies, ...
        'frequencies', frequencies, ...
        'spectral_centroid', spectral_centroid, ...
        'zero_crossing_rate', zero_crossing_rate, ...
        'spectral_rolloff', spectral_rolloff, ...
        'num_frames', num_frames);
end
%%
function pitch = find_pitch_yin(frame, fs)
    % YIN algorithm for better pitch detection
    frame = frame - mean(frame); % Remove DC
    
    % Autocorrelation
    max_lag = min(length(frame) - 1, round(fs / 80)); % Min freq = 80Hz
    min_lag = round(fs / 2000); % Max freq = 2000Hz
    
    if max_lag <= min_lag
        pitch = 0;
        return;
    end
    
    autocorr = zeros(1, max_lag + 1);
    for lag = 0:max_lag
        if lag == 0
            autocorr(lag + 1) = sum(frame.^2);
        else
            autocorr(lag + 1) = sum(frame(1:end-lag) .* frame(1+lag:end));
        end
    end
    
    % Find best lag
    [~, best_lag] = max(autocorr(min_lag+1:end));
    best_lag = best_lag + min_lag - 1;
    
    if best_lag > 0 && autocorr(best_lag + 1) > 0.3 * autocorr(1)
        pitch = fs / best_lag;
    else
        pitch = 0;
    end
end
%%
function centroid = calculate_spectral_centroid(frame, fs)
    % חישוב Spectral Centroid
    windowed = frame .* hamming(length(frame));
    spectrum = abs(fft(windowed));
    spectrum = spectrum(1:floor(length(spectrum)/2));
    
    freqs = (0:length(spectrum)-1) * fs / (2 * length(spectrum));
    
    if sum(spectrum) > 0
        centroid = sum(freqs .* spectrum') / sum(spectrum);
    else
        centroid = 0;
    end
end
%%
function zcr = calculate_zcr(frame)
    % Zero Crossing Rate
    signs = sign(frame);
    zcr = sum(abs(diff(signs))) / (2 * length(frame));
end
%%
function rolloff = calculate_spectral_rolloff(frame, fs)
    % Spectral Rolloff (85% של האנרגיה)
    windowed = frame .* hamming(length(frame));
    spectrum = abs(fft(windowed)).^2;
    spectrum = spectrum(1:floor(length(spectrum)/2));
    
    cumsum_spectrum = cumsum(spectrum);
    total_energy = cumsum_spectrum(end);
    
    if total_energy > 0
        rolloff_idx = find(cumsum_spectrum >= 0.85 * total_energy, 1);
        if ~isempty(rolloff_idx)
            rolloff = rolloff_idx * fs / (2 * length(spectrum));
        else
            rolloff = 0;
        end
    else
        rolloff = 0;
    end
end
%%
function smoothed = smooth_signal(signal, window_size)
    % החלקה פשוטה
    if window_size <= 1
        smoothed = signal;
        return;
    end
    
    kernel = ones(1, window_size) / window_size;
    smoothed = conv(signal, kernel, 'same');
end
%%
function events = detect_note_events(frame_data, fs, hop_size)
    energies = frame_data.energies;
    frequencies = frame_data.frequencies;
    
    % הגדרת ספים דינמיים
    energy_threshold = max(max(energies) * 0.05, median(energies) * 2);
    
    events = struct('start_time', {}, 'end_time', {}, 'duration', {}, ...
                'frequency', {}, 'energy', {}, ...
                'start_frame', {}, 'end_frame', {});
    
    % זיהוי אזורי אנרגיה גבוהה
    active_regions = energies > energy_threshold;
    
    % מציאת תחילות וסיומים
    onsets = find(diff([0, active_regions]) == 1);
    offsets = find(diff([active_regions, 0]) == -1);
    
    % וידוא שיש אותו מספר של onsets ו-offsets
    min_length = min(length(onsets), length(offsets));
    onsets = onsets(1:min_length);
    offsets = offsets(1:min_length);
    
    for i = 1:length(onsets)
        start_frame = onsets(i);
        end_frame = offsets(i);
        
        % בדיקה שהאזור מספיק ארוך
        duration_frames = end_frame - start_frame + 1;
        if duration_frames < 3 % לפחות 30ms
            continue;
        end
        
        % חישוב זמנים
        start_time = (start_frame - 1) * hop_size / fs;
        end_time = end_frame * hop_size / fs;
        
        % מציאת התדר הדומיננטי באזור
        region_freqs = frequencies(start_frame:end_frame);
        region_energies = energies(start_frame:end_frame);
        
        % תדר ממוצע משוקלל לפי אנרגיה
        valid_freqs = region_freqs(region_freqs > 0);
        valid_energies = region_energies(region_freqs > 0);
        
        if ~isempty(valid_freqs)
            if length(valid_freqs) == 1
                dominant_freq = valid_freqs(1);
            else
                dominant_freq = sum(valid_freqs .* valid_energies) / sum(valid_energies);
            end
            
            avg_energy = mean(region_energies);
            
            events(end+1) = struct(...
                'start_time', start_time, ...
                'end_time', end_time, ...
                'duration', end_time - start_time, ...
                'frequency', dominant_freq, ...
                'energy', avg_energy, ...
                'start_frame', start_frame, ...
                'end_frame', end_frame);
        end
    end
end
%%
function notes = segment_into_notes(events, frame_data)
    notes = struct('note', {}, 'frequency', {}, ...
               'start_time', {}, 'end_time', {}, ...
               'duration', {}, 'energy', {});
    
    for i = 1:length(events)
        event = events(i);
        
        % המרת תדר לתו
        [note_name, octave] = freq_to_note_precise(event.frequency);
        
        if ~isempty(note_name)
            notes(end+1) = struct(...
                'note', sprintf('%s%d', note_name, octave), ...
                'frequency', event.frequency, ...
                'start_time', event.start_time, ...
                'end_time', event.end_time, ...
                'duration', event.duration, ...
                'energy', event.energy);
        end
    end
end
%%
function [note, octave] = freq_to_note_precise(freq)
    if freq <= 0 || freq < 80 || freq > 2000
        note = '';
        octave = -1;
        return;
    end
    
    % המרה מדויקת יותר
    A4 = 440;
    note_names = {'C','C#','D','D#','E','F','F#','G','G#','A','A#','B'};
    
    % חישוב המרחק בסמיטונים מ-A4
    semitone_float = 12 * log2(freq / A4);
    semitone = round(semitone_float);
    
    % בדיקה שהתדר קרוב מספיק לתו (סובלנות של 50 סנט)
    if abs(semitone_float - semitone) > 0.5
        note = '';
        octave = -1;
        return;
    end
    
    % חישוב התו והאוקטבה
    note_index = mod(semitone + 9, 12) + 1;
    note = note_names{note_index};
    octave = 4 + floor((semitone + 9) / 12);
    
    % בדיקת טווח הגיוני
    if octave < 1 || octave > 7
        note = '';
        octave = -1;
    end
end
%%
function clean_notes = clean_and_validate_notes(raw_notes)
    if isempty(raw_notes)
        clean_notes = [];
        return;
    end
    
    % מיון לפי זמן התחלה
    [~, sort_idx] = sort([raw_notes.start_time]);
    sorted_notes = raw_notes(sort_idx);
    
    clean_notes = struct('note', {}, 'frequency', {}, ...
                         'start_time', {}, 'end_time', {}, ...
                         'duration', {}, 'energy', {});
    
    % הסרת תווים קצרים מדי
    MIN_DURATION = 0.08; % 80ms מינימום
    
    for i = 1:length(sorted_notes)
        note = sorted_notes(i);
        
        % בדיקת אורך מינימלי
        if note.duration < MIN_DURATION
            continue;
        end
        
        % בדיקת חפיפה עם התו הקודם
        if ~isempty(clean_notes)
            prev_note = clean_notes(end);
            
            % אם יש חפיפה - בחר את החזק יותר
            if note.start_time < prev_note.end_time
                if note.energy > prev_note.energy
                    clean_notes(end) = note; % החלף
                end
                continue; % דלג על התו הנוכחי
            end
            
            % אם זה אותו תו קרוב זמנית - איחד
            time_gap = note.start_time - prev_note.end_time;
            if strcmp(note.note, prev_note.note) && time_gap < 0.1
                % איחוד תווים
                merged_note = prev_note;
                merged_note.end_time = note.end_time;
                merged_note.duration = merged_note.end_time - merged_note.start_time;
                merged_note.energy = max(prev_note.energy, note.energy);
                clean_notes(end) = merged_note;
                continue;
            end
        end
        
        clean_notes(end+1) = note;
        last_note = note.note;
        last_end_time = note.end_time;
    end
end
%%
function save_precise_results(notes, folderPathOnly, name)
    outputFile = fullfile(folderPathOnly, [char(name) '_precise_notes.txt']);

    fid = fopen(outputFile, 'w');
    if fid == -1
        disp('❌ Error writing to text file');
        return;
    end

    fprintf(fid, '🎯 Precise Single Note Analysis\n');
    fprintf(fid, '==============================\n\n');

    is_valid_notes = isstruct(notes) && ~isempty(notes);

    if ~is_valid_notes
        fprintf(fid, 'No notes detected with precise method.\n');
        fprintf(fid, 'This could indicate:\n');
        fprintf(fid, '- Very quiet audio\n');
        fprintf(fid, '- No clear pitched content\n');
        fprintf(fid, '- Audio issues\n');
    else
        fprintf(fid, 'Precisely detected notes: %d\n\n', length(notes));

        fprintf(fid, 'Detailed Analysis:\n');
        fprintf(fid, '=================\n');
        for i = 1:length(notes)
            note = notes(i);
            fprintf(fid, '%2d. %s | %.3f-%.3fs (%.3fs) | %.1fHz | Energy: %.4f\n', ...
                    i, note.note, note.start_time, note.end_time, ...
                    note.duration, note.frequency, note.energy);
        end

        fprintf(fid, '\n--- Precise Note Sequence ---\n');
        sequence = {notes.note};
        fprintf(fid, '%s\n', strjoin(sequence, ' '));

        % ניתוח סטטיסטי
        durations = [notes.duration];
        frequencies = [notes.frequency];
        energies = [notes.energy];

        fprintf(fid, '\n--- Statistical Analysis ---\n');
        fprintf(fid, 'Duration stats: avg=%.3fs, min=%.3fs, max=%.3fs\n', ...
                mean(durations), min(durations), max(durations));
        fprintf(fid, 'Frequency range: %.1f-%.1f Hz\n', min(frequencies), max(frequencies));
        fprintf(fid, 'Energy range: %.4f-%.4f\n', min(energies), max(energies));
    end
    fclose(fid);

    % JSON שמירה
    if ~exist('uploads', 'dir')
        mkdir('uploads');
    end

    if is_valid_notes
        sequence = {notes.note};
    else
        sequence = {};
    end

    json_data = struct('notes', notes, ...
                       'sequence', sequence, ...
                       'count', length(notes), ...
                       'analysis_method', 'precise_multi_feature');

    jsonOutputPath = fullfile('uploads', [char(name) '_precise_notes.json']);

    fid = fopen(jsonOutputPath, 'w');
    if fid ~= -1
        fwrite(fid, jsonencode(json_data));
        fclose(fid);
    end

    % הצגת תוצאה בקונסול
    if is_valid_notes
        fprintf('\n🎼 Precise sequence:\n');
        fprintf('   %s\n', strjoin(sequence, ' → '));
    end
end
