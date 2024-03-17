from keras.models import load_model
import cv2
import mediapipe as mp
import numpy as np
import pandas as pd
import math

mp_drawing = mp.solutions.drawing_utils
mp_drawing_styles = mp.solutions.drawing_styles
mp_pose = mp.solutions.pose


path_saved_model = 'model/mediapipe_model_sit_10000_stand_13000.h5'
threshold = 0.5

def video_sts(path_x):
    video_capture = path_x
    print("Opening")
    vid = cv2.VideoCapture(video_capture)

    if not vid.isOpened():
        print("Error: Couldn't open the video.")
        return
    drawing_spec = mp_drawing.DrawingSpec(thickness=2, circle_radius=2)

    torso_size_multiplier = 2.5
    n_landmarks = 33
    landmark_names = [
        'nose',
        'left_eye_inner', 'left_eye', 'left_eye_outer',
        'right_eye_inner', 'right_eye', 'right_eye_outer',
        'left_ear', 'right_ear',
        'mouth_left', 'mouth_right',
        'left_shoulder', 'right_shoulder',
        'left_elbow', 'right_elbow',
        'left_wrist', 'right_wrist',
        'left_pinky_1', 'right_pinky_1',
        'left_index_1', 'right_index_1',
        'left_thumb_2', 'right_thumb_2',
        'left_hip', 'right_hip',
        'left_knee', 'right_knee',
        'left_ankle', 'right_ankle',
        'left_heel', 'right_heel',
        'left_foot_index', 'right_foot_index',
    ]
    class_names = [
        'sit', 'stand'
    ]
    ##############

    stage = None
    counter = 0

    detection_confidence = 0.5
    tracking_confidence = 0.5

    col_names = []
    for i in range(n_landmarks):
        name = mp_pose.PoseLandmark(i).name
        name_x = name + '_X'
        name_y = name + '_Y'
        name_z = name + '_Z'
        name_v = name + '_V'
        col_names.append(name_x)
        col_names.append(name_y)
        col_names.append(name_z)
        col_names.append(name_v)

    # Load saved model
    model = load_model(path_saved_model, compile=True)

    with mp_pose.Pose(
            min_detection_confidence=detection_confidence,
            min_tracking_confidence=tracking_confidence) as pose:
        while True:
            ret, frame = vid.read()
            if not ret:
                print("End of video.")
                break
            frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = pose.process(frame)

            if results.pose_landmarks:
                frame.flags.writeable = True
                frame = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
                lm_list = []
                for landmarks in results.pose_landmarks.landmark:
                    # Preprocessing
                    max_distance = 0
                    lm_list.append(landmarks)
                center_x = (lm_list[landmark_names.index('right_hip')].x +
                            lm_list[landmark_names.index('left_hip')].x) * 0.5
                center_y = (lm_list[landmark_names.index('right_hip')].y +
                            lm_list[landmark_names.index('left_hip')].y) * 0.5

                shoulders_x = (lm_list[landmark_names.index('right_shoulder')].x +
                            lm_list[landmark_names.index('left_shoulder')].x) * 0.5
                shoulders_y = (lm_list[landmark_names.index('right_shoulder')].y +
                            lm_list[landmark_names.index('left_shoulder')].y) * 0.5

                for lm in lm_list:
                    distance = math.sqrt((lm.x - center_x) ** 2 + (lm.y - center_y) ** 2)
                    if (distance > max_distance):
                        max_distance = distance
                torso_size = math.sqrt((shoulders_x - center_x) ** 2 + (shoulders_y - center_y) ** 2)
                max_distance = max(torso_size * torso_size_multiplier, max_distance)

                pre_lm = list(np.array([[(landmark.x - center_x) / max_distance, (landmark.y - center_y) / max_distance,
                                        landmark.z / max_distance, landmark.visibility] for landmark in lm_list]).flatten())
                data = pd.DataFrame([pre_lm], columns=col_names)
                predict = model.predict(data)[0]
                if max(predict) > threshold:
                    pose_class = class_names[predict.argmax()]
                    print('predictions: ', predict)
                    print('predicted Pose Class: ', pose_class)
                else:
                    pose_class = 'Unknown Pose'
                    print('[INFO] Predictions is below given Confidence!!')
            # Show Result
                mp_drawing.draw_landmarks(
                    image=frame,
                    landmark_list=results.pose_landmarks,
                    connections=mp_pose.POSE_CONNECTIONS,
                    landmark_drawing_spec=mp_drawing_styles.get_default_pose_landmarks_style(),
                    connection_drawing_spec=drawing_spec)
                cv2.putText(
                    frame, f'{class_names[predict.argmax()]}',
                    (40, 50), cv2.FONT_HERSHEY_PLAIN,
                    2, (255, 0, 255), 2
                )
            yield frame     
    cv2.destroyAllWindows()
