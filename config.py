# Add these variables to track time


# Define global variables
sit_start_time = None
stand_start_time = None
sit_stand_transition_time = None
count = 0
first_sit_pose_detected = False
current_pose_state = None
sit_to_stand_start_time = None
timer = []

col_names = [
    "0_X",
    "0_Y",
    "1_X",
    "1_Y",
    "2_X",
    "2_Y",
    "3_X",
    "3_Y",
    "4_X",
    "4_Y",
    "5_X",
    "5_Y",
    "6_X",
    "6_Y",
    "7_X",
    "7_Y",
    "8_X",
    "8_Y",
    "9_X",
    "9_Y",
    "10_X",
    "10_Y",
    "11_X",
    "11_Y",
    "12_X",
    "12_Y",
    "13_X",
    "13_Y",
    "14_X",
    "14_Y",
    "15_X",
    "15_Y",
    "16_X",
    "16_Y",
]