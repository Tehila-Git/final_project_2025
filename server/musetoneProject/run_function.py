import matlab.engine

def run_compare():
    eng = matlab.engine.start_matlab()
    eng.addpath(r'C:\Users\user1\Desktop\Piano-Note-Recognition-master')
    file1 = r'./melodies/CHUPA1.wav'
    file2 = r'./melodies/CHUPA_X.wav'
    accuracy, mismatches = eng.compare_notes(file1, file2, nargout=2)

    # Print the result
    # print(f"Playing accuracy: {accuracy:.2f}%")
    #
    # if mismatches:
    #     print("Errors found:")
    #     for m in mismatches:
    #         print(f"At note #{m['Index']}: expected {m['Expected']} but played {m['Played']}")
    # else:
    #     print("All notes match!")

    eng.quit()

if __name__ == '__main__':
    run_compare()
